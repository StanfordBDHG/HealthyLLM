//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

extension Encodable {
    func asJSONRepresentation(_ outputFormat: JSONEncoder.OutputFormatting? = .prettyPrinted) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let outputFormat {
            encoder.outputFormatting = outputFormat
        }
        
        guard let encoded = try? encoder.encode(self) else {
            return nil
        }
        return encoded
    }
    
    func asJSONString(_ outputFormat: JSONEncoder.OutputFormatting? = .prettyPrinted) -> String? {
        guard let json = self.asJSONRepresentation() else { return nil }
        
        return String(data: json, encoding: .utf8)
    }
}
