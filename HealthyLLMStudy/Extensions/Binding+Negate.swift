//
//  Binding+negate.swift
//  HealthyLLM
//
//  Created by Leon Nissen on 1/7/25.
//

import SwiftUI

extension Binding where Value == Bool {
    /// Negates a `Binding`.
    prefix static func ! (value: Binding<Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { !value.wrappedValue },
            set: { value.wrappedValue = !$0 }
        )
    }
}
