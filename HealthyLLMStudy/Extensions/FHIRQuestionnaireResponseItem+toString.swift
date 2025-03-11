//
//  FHIRQuestionnaireResponseItem+toString.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 2/21/25.
//

import ModelsR4

extension ModelsR4.QuestionnaireResponseItemAnswer.ValueX {
    func toString() -> String? {
        switch self {
        case .boolean(let boolValue):
            return boolValue.value?.bool.description
        case .date(let date):
            return date.value?.description
        case .dateTime(let dateTime):
            return dateTime.value?.description
        case .decimal(let decimal):
            return decimal.value.debugDescription
        case .integer(let integer):
            return integer.value.debugDescription
        case .string(let string):
            return string.value?.string
        case .coding(let coding):
            return coding.code?.value?.string
        default:
            return nil
        }
    }
}

extension Optional where Wrapped == ModelsR4.QuestionnaireResponseItemAnswer.ValueX {
    func toString() -> String {
        switch self {
        case .some(let valueX):
            return valueX.toString() ?? "nil"
        case .none:
            return "nil"
        }
    }
}
