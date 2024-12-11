//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

extension Encodable {
    func asJSONRepresentation(_ outputFormat: JSONEncoder.OutputFormatting? = nil) -> String? {
        let encoder = JSONEncoder()
        if let outputFormat {
            encoder.outputFormatting = outputFormat
        }
        
        guard let encoded = try? encoder.encode(self) else {
            return nil
        }
        return String(data: encoded, encoding: .utf8)
    }
}
