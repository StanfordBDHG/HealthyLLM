//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2024 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

enum HealthDataFetcherError: Error {
    case unsupportedAggregationStyle
    case noValueAvailable
    case quantityTypeIdentifierNotFound
}
