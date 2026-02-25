//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import os
import Spezi
import SpeziChat
import SpeziLLM
import SpeziLLMLocal


@Observable
class FunctionCallingProcessor: EnvironmentAccessible, DefaultInitializable, Module, ChatProcessor {
    @ObservationIgnored private let logger = Logger(subsystem: "HealthyLLMStudy", category: "FunctionCallingProcessor")
    @ObservationIgnored @Dependency(SharedLocalLLM.self) private var llm
    
    private(set) var chat: Chat = []
    var sufficientUsage: Bool {
        !chat.contains { $0.role == .user }
    }
    
    required init() {
        setupFunctionRegistry()
    }
    
    func query(with chat: Chat) async throws {
        await MainActor.run {
            PerformanceProcessor.shared.start()
        }
        guard let userInput = chat.last,
              userInput.role == .user,
              !userInput.content.isEmpty else {
            logger.error("No user input found")
            return
        }
        
        // 1. Add the user message to context.
        self.chat.append(userInput)
        Persistance.shared.saveChatMessage(
            type: "FunctionCalling",
            role: userInput.role.rawValue,
            message: userInput.content
        )
        
        try await startInference()
    }
    
    func stop() {
        llm.cancel()
        PerformanceProcessor.shared.stop()
    }
    
    func reset() {
        llm.cancel()
        chat = []
    }
    
    private func setupFunctionRegistry() {
        ToolRegistry.shared.register(
            name: ActivityDataHandler.name,
            handler: ActivityDataHandler()
        )
        
        ToolRegistry.shared.register(
            name: ActivityOverviewDataHandler.name,
            handler: ActivityOverviewDataHandler()
        )
        
        ToolRegistry.shared.register(
            name: GeneralHealthMetricsHandler.name,
            handler: GeneralHealthMetricsHandler()
        )
        
        ToolRegistry.shared.register(
            name: SleepDataHandler.name,
            handler: SleepDataHandler()
        )
        
        ToolRegistry.shared.register(
            name: VitalSignsHandler.name,
            handler: VitalSignsHandler()
        )
        
        ToolRegistry.shared.register(
            name: WorkoutDataHandler.name,
            handler: WorkoutDataHandler()
        )
    }
    
    private func checkToolNeeded(prompt: String) async throws -> ToolCall {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        let systemPrompt = """
        You select health data functions only. Reply with function name and params only.

        AVAILABLE FUNCTIONS:
        - getVitalSigns(type, weeksToAverage) - heartRate/restingHeartRate/bloodPressure/respiratoryRate/oxygenSaturation
        - getGeneralHealthMetrics(type) - weight/bmi/bodyFat/height
        - getActivity(type, maxDays) - steps/distance/flightsClimbed/activeEnergy/basalEnergy/standHours/exerciseMinutes
        - getActivityOverview(activityType) - same types as getActivity, shows yearly trend
        - getRecentWorkouts(maxDays) - workout details
        - getSleep(maxDays) - sleep analysis
        - getNutrition(type, maxDays) - calories/protein/fat/water/carbohydrates

        EXAMPLES:
        User: "What was my average heart rate last week?"
        Response: getVitalSigns with type="heartRate" and weeksToAverage="1"

        User: "How many calories did I burn during workouts last month?"
        Response: getRecentWorkouts with maxDays="30"

        User: "Can you recommend some exercises for weight loss?"
        Response: NO_FUNCTION_NEEDED

        User: "How has my sleep been this week?"
        Response: getSleep with maxDays="7"

        User: "How have my daily steps changed over the year?"
        Response: getActivityOverview with activityType="steps"

        User: "What's my current BMI?"
        Response: getGeneralHealthMetrics with type="bmi"
        
        Remember: Keep your decision process simple and focused only on determining the appropriate \
        function call. A separate process will handle the actual data retrieval and response generation.
        """
        
        let tools = loadTools()
        
        let context: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
        ]
        
        let output = try await llm.oneShot(
            customContext: context,
            parameters: .init(maxOutputLength: 100),
            samplingParameters: .init(),
            tools: tools
        )
        
        llm.clearCache()
        logger.info("Check tool needed output: \(output ?? "N/A)")")
        
        guard let toolCallData = output?.data(using: .utf8),
              let toolCall = try? JSONDecoder().decode(ToolCall.self, from: toolCallData) else {
            logError(message: "NOT_DECODABLE")
            throw ToolCallError.invalidData
        }
        logger.info("Tool Decodable")
        
        // Check if the function exists
        guard ToolRegistry.shared.hasFunction(named: toolCall.name) else {
            logError(message: "NO_TOOL_MATCH: \(toolCall.name)")
            throw ToolCallError.toolNotFound
        }
        logger.info("Tool Matched")
        
        return toolCall
    }
    
    private func appendToChat(role: ChatEntity.Role, content: String) {
        let entity = ChatEntity(role: role, content: content)
        chat.append(entity)
        Persistance.shared.saveChatMessage(
            type: "FunctionCalling",
            role: entity.role.rawValue,
            message: entity.content
        )
    }
    
    
    @MainActor
    private func startInference() async throws {
        logger.info("Start inference")
        
        let parameters: LLMLocalParameters = .init(maxOutputLength: 512)
        let samplingParameters: LLMLocalSamplingParameters = .init()
        
        if chat.isEmpty || chat[0].role != .hidden(type: .system) {
            injectSystemPrompt()
        }
        
        // 2. Check if the prompt requires a tool call.
        if let last = chat.last,
           last.role == .user,
           let tool = try? await checkToolNeeded(prompt: last.content) {
            appendToChat(role: .hidden(type: .assistantToolCall), content: tool.asJSONString() ?? "N/A")
            
            // 3. If a tool call is returned, execute it and add the tool's response to the context.
            await executeFunctionCall(with: tool)
        }
        
        // 4. Call the model using the updated context (without tools) to get the final answer.
        let output = try await llm.oneShotStream(
            customContext: chat.asDictionaryRepresentation(),
            parameters: parameters,
            samplingParameters: samplingParameters
        )
        
        for try await stringPiece in output {
            if let last = chat.last,
               last.role != .assistant {
                chat.append(.init(role: .assistant, content: stringPiece, complete: false))
                continue
            }
            
            guard let last = chat.last else {
                return
            }

            chat[chat.count - 1] = .init(
                role: last.role,
                content: last.content + stringPiece,
                complete: false,
                id: last.id,
                date: last.date
            )
        }

        guard let last = chat.last else {
            return
        }
        
        chat[chat.count - 1] = .init(
            role: last.role,
            content: last.content,
            complete: true,
            id: last.id,
            date: last.date
        )
        
        llm.clearCache()
        
        Persistance.shared.saveChatMessage(
            type: "FunctionCalling",
            role: last.role.rawValue,
            message: last.content
        )
    }
    
    
    func executeFunctionCall(with tool: ToolCall) async {
        logger.info("Execute tool")
        do {
            // Get the function handler and execute it
            guard let handler = ToolRegistry.shared.handler(for: tool.name) else {
                logError(message: "NO_HANDLER: \(tool.name)")
                return
            }
            logger.info("Got tool handler")
            
            let responseContent = try await handler.execute(parameters: tool.parameters)
            logger.info("Got tool response: \(responseContent)")
            
            appendToChat(role: .hidden(type: .assistantToolResponse), content: responseContent)
        } catch {
            logError(message: "TOOL_EXECUTION_ERROR: \(error.localizedDescription)")
        }
    }
    
    /// Log an error to persistence
    /// - Parameter message: The error message
    private func logError(message: String) {
        logger.error("Error: \(message)")
        Persistance.shared.saveChatMessage(
            type: "FunctionCalling",
            role: "ERROR",
            message: message
        )
    }
    
    private func loadTools() -> [[String: any Sendable]] {
        guard let url = Bundle.main.url(forResource: "tools", withExtension: "json"),
        let data = try? Data(contentsOf: url),
        let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: any Sendable]] else {
            return [[:]]
        }
         
        return json
    }
    
    private func injectSystemPrompt() {
        let interpretationSystemPrompt = LocalizedStringResource("INTERPRETATION_SYSTEM_PROMPT").localizedString()
        let age = if UserDefaults.standard.integer(forKey: StorageKeys.age) == 0 { "unknown" } else {
            String(UserDefaults.standard.integer(forKey: StorageKeys.age))
        }
        let sex = UserDefaults.standard.string(forKey: StorageKeys.sex) ?? "unknown"
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        
        let systemPrompt = """
        \(interpretationSystemPrompt)
        
        Today's Date: \(formatter.string(from: .now))
        
        ## User Health Profile
        
        Age: \(age)
        Sex: \(sex)
        """
        
        chat.insert(
            .init(
                role: .hidden(type: .system),
                content: systemPrompt
            ),
            at: 0
        )
    }
    
    static func createDateIntervalsString() -> String {
        // Use a Gregorian calendar with Sunday as the first day of the week
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1  // Sunday

        // Formatter to convert Date to "yyyy-MM-dd" string format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // "Today" and "Yesterday"
        let today = Date()
        let todayStr = dateFormatter.string(from: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let yesterdayStr = dateFormatter.string(from: yesterday)
        
        // "This week": get the start of the week (Sunday) then add 6 days for the end
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        let thisWeekStartStr = dateFormatter.string(from: startOfWeek)
        let thisWeekEndStr = dateFormatter.string(from: endOfWeek)
        
        // "Last week": subtract one week from this week's start, then add 6 days for the end
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfWeek)!
        let lastWeekEnd = calendar.date(byAdding: .day, value: 6, to: lastWeekStart)!
        let lastWeekStartStr = dateFormatter.string(from: lastWeekStart)
        let lastWeekEndStr = dateFormatter.string(from: lastWeekEnd)
        
        // "This month": from the first day of this month to today.
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let thisMonthStartStr = dateFormatter.string(from: startOfMonth)
        let thisMonthEndStr = todayStr  // Use today as the end date

        // "Last month": subtract one month from the start of this month,
        // then compute the first and last day of that month.
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: startOfMonth)!
        let lastMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonthDate))!
        // The end of last month is one day before the first day of the current month.
        let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: startOfMonth)!
        let lastMonthStartStr = dateFormatter.string(from: lastMonthStart)
        let lastMonthEndStr = dateFormatter.string(from: lastMonthEnd)
        
        // "This year": from the first day of the current year to today.
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today))!
        let thisYearStartStr = dateFormatter.string(from: startOfYear)
        let thisYearEndStr = todayStr

        // "Last year": determine the previous year interval.
        let lastYearStart = calendar.date(byAdding: .year, value: -1, to: startOfYear)!
        // The end of last year is one day before the start of this year.
        let lastYearEnd = calendar.date(byAdding: .day, value: -1, to: startOfYear)!
        let lastYearStartStr = dateFormatter.string(from: lastYearStart)
        let lastYearEndStr = dateFormatter.string(from: lastYearEnd)
        
        // Create the final string using a multiline string literal.
        let result = """
        - "Today" means \(todayStr)
        - "Yesterday" means \(yesterdayStr)
        - "This week" means \(thisWeekStartStr) to \(thisWeekEndStr)
        - "Last week" means \(lastWeekStartStr) to \(lastWeekEndStr)
        - "This month" means \(thisMonthStartStr) to \(thisMonthEndStr)
        - "Last month" means \(lastMonthStartStr) to \(lastMonthEndStr)
        - "This year" means \(thisYearStartStr) to \(thisYearEndStr)
        - "Last year" means \(lastYearStartStr) to \(lastYearEndStr)
        """
        
        return result
    }
}

extension ChatEntity.HiddenMessageType {
    static let assistantToolCall = ChatEntity.HiddenMessageType(name: "assistantToolCall")
    static let assistantToolResponse = ChatEntity.HiddenMessageType(name: "assistantToolResponse")
}
