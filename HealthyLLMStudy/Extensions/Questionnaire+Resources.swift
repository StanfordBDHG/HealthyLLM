//
//  Questionnaire+sus+rating.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/7/25.
//

import Foundation
import ModelsR4

extension Questionnaire {
    static var demographics_health_privacy: Questionnaire {
        load(name: "demographics+health+privacy-questions")
    }
    
    static var rating: Questionnaire {
        load(name: "rating")
    }
    
    static var sus: Questionnaire {
        load(name: "sus")
    }
    
    static var additionalQuestions: Questionnaire {
        load(name: "additional-questions")
    }
    
    static var additionalSpecificQuestions: Questionnaire {
        load(name: "additional-specific-questions")
    }
    
    private static func load(name: String) -> Questionnaire {
        guard let resourceURL = Bundle.main.url(forResource: name, withExtension: "json") else {
            preconditionFailure("Could not find the resource \"\(name).json\" in the FHIRQuestionnaires Resources folder.")
        }
        
        do {
            let resourceData = try Data(contentsOf: resourceURL)
            return try JSONDecoder().decode(Questionnaire.self, from: resourceData)
        } catch {
            preconditionFailure("Could not decode the FHIR questionnaire named \"\(name).json\": \(error)")
        }
    }
}
