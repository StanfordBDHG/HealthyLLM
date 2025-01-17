//
//  Questionnaire+sus+rating.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/7/25.
//

import Foundation
import ModelsR4

extension Questionnaire {
    static var final: Questionnaire {
        load(name: "final")
    }
    
    static var rating: Questionnaire {
        load(name: "rating")
    }
    
    private static func load(name: String) -> Questionnaire {
        guard let resourceURL = Bundle.main.url(forResource: name, withExtension: "json") else {
            preconditionFailure("Could not find the resource \"\(name)\".json in the FHIRQuestionnaires Resources folder.")
        }
        
        do {
            let resourceData = try Data(contentsOf: resourceURL)
            return try JSONDecoder().decode(Questionnaire.self, from: resourceData)
        } catch {
            preconditionFailure("Could not decode the FHIR questionnaire named \"\(name).json\": \(error)")
        }
    }
}
