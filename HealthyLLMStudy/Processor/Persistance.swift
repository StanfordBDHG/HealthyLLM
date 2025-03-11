//
//  Persistance.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import Spezi
import CoreData
import os
import SpeziQuestionnaire
import SwiftUI


class Persistance: ObservableObject {
    static let shared = Persistance()
    
    private let logger = Logger(subsystem: "HealthyLLM", category: "Persistance")

    let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext

    init() {
        container = NSPersistentContainer(name: "HealthyLLM")
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error as NSError? {
                print("[Persistance ERROR]", error.localizedDescription)
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        backgroundContext = container.newBackgroundContext()
    }
    
    func save() {
        container.viewContext.saveOrRollback()
        backgroundContext.saveOrRollback()
    }
    
    func saveChatMessage(id: UUID = UUID(), type: String, role: String, message: String, timestamp: Date = .now) {
        let chatMessage = ChatMessage(context: backgroundContext)
        chatMessage.id = id
        chatMessage.type = type
        chatMessage.role = role
        chatMessage.message = message
        chatMessage.timestamp = timestamp
        
        backgroundContext.saveOrRollback()
    }
    
    func savePerformace(
        timestamp: Date = .now,
        cpu: Double,
        memory: Double,
        thermalState: String,
        batteryLevel: Double,
        batteryState: String
    ) {
        let performace = Performance(context: backgroundContext)
        performace.timestamp = timestamp
        performace.cpu = cpu
        performace.memory = memory
        performace.thermalState = thermalState
        performace.batteryLevel = batteryLevel
        performace.batteryState = batteryState
        
        backgroundContext.saveOrRollback()
    }
    
    func saveMetadata(participantId: Int, age: Int, sex: String) {
        let metadata = Metadata(context: backgroundContext)
        metadata.id = UUID()
        metadata.participantId = Double(participantId)
        metadata.age = Double(age)
        metadata.sex = sex
        metadata.device = PerformanceProcessor.deviceIdentifier
        metadata.timestamp = .now
        metadata.os = UIDevice.current.systemVersion
        metadata.totalMemory = String(ProcessInfo.processInfo.physicalMemory)
        metadata.freeStorage = PerformanceProcessor.freeDiskSpace
        metadata.totalStorage = PerformanceProcessor.totalDiskSpace
        
        backgroundContext.saveOrRollback()
    }
    
    func saveAnswer(
        id: String,
        answer _answer: String,
        timestamp: Date?
    ) {
        let answer = Answer(context: backgroundContext)
        answer.id = id
        answer.answer = _answer
        answer.timestamp = timestamp ?? .now
        
        backgroundContext.saveOrRollback()
    }
    
    func saveQuestionnaire(questionnaireResponse: QuestionnaireResponse) {
        guard let id = questionnaireResponse.id?.value?.string,
            let items = questionnaireResponse.item else {
            return
        }
        
        for (index, item) in items.enumerated() {
            saveAnswer(
                id: item.linkId.value?.string ?? "\(id)-\(index)",
                answer: item.answer?.first?.value.toString() ?? "N/A",
                timestamp: try? questionnaireResponse.authored?.value?.asNSDate()
            )
        }
    }
    
    func export() async throws -> Exportable {
        let answers = try container.viewContext.fetch(Answer.fetchRequest())
        let metadata = try container.viewContext.fetch(Metadata.fetchRequest())
        let chatMessages = try container.viewContext.fetch(ChatMessage.fetchRequest())
        let performance = try container.viewContext.fetch(Performance.fetchRequest())
        let healthKitData = await HealthDataFetcher.shared.countAllHealthKitData()
        let healthKitDatabaseAge = await HealthDataFetcher.shared.fetchOldestOverallSample()
        
        return .init(
            answers: answers,
            metadata: metadata,
            chatMessages: chatMessages,
            performance: performance,
            healthKitValues: healthKitData,
            healthKitDatabaseAge: healthKitDatabaseAge
        )
    }
    
    func exportDetails() -> ExportDetails {
        let answerCount = try? container.viewContext.count(for: Answer.fetchRequest())
        let metadataCount = try? container.viewContext.count(for: Metadata.fetchRequest())
        let chatMessageCount = try? container.viewContext.count(for: ChatMessage.fetchRequest())
        let performanceCount = try? container.viewContext.count(for: Performance.fetchRequest())
        
        return .init(
            chat: chatMessageCount ?? 0,
            questions: answerCount ?? 0,
            metadata: metadataCount ?? 0,
            performance: performanceCount ?? 0
        )
    }
    
    func deleteAll() throws {
        for entity in ["Performance", "Answer", "ChatMessage", "Metadata"] {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try container.viewContext.execute(request)
        }
    }
}

struct Exportable: Encodable {
    let answers: [Answer]
    let metadata: [Metadata]
    let chatMessages: [ChatMessage]
    let performance: [Performance]
    let healthKitValues: [String: Int]
    let healthKitDatabaseAge: [String: Date]
}

