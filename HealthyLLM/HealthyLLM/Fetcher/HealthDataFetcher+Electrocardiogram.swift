//
// This source file is part of the HealthyLLM based on the Stanford Spezi Template Application project
//
// SPDX-FileCopyrightText: 2026 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import HealthKit
import SpeziHealthKit

extension HealthDataFetcher {
    func fetchElectrocardiograms(
        _ healthKit: HealthKit,
        limit: Int = 1
    ) async throws -> [ElectrocardiogramData] {
        let samples = try await fetchElectrocardiogramSamples(healthKit, limit: limit)

        var records: [ElectrocardiogramData] = []
        for sample in samples {
            let voltages = try await fetchVoltageMeasurements(for: sample, healthKit: healthKit)
            records.append(
                .init(
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    classification: String(describing: sample.classification),
                    symptomsStatus: String(describing: sample.symptomsStatus),
                    averageHeartRate: sample.averageHeartRate?.doubleValue(
                        for: .count().unitDivided(by: .minute())
                    ),
                    samplingFrequency: sample.samplingFrequency?.doubleValue(for: .hertz()),
                    numberOfVoltageMeasurements: voltages.count,
                    voltages: voltages
                )
            )
        }

        return records
    }

    private func fetchElectrocardiogramSamples(
        _ healthKit: HealthKit,
        limit: Int
    ) async throws -> [HKElectrocardiogram] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.electrocardiogramType(),
                predicate: nil,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples as? [HKElectrocardiogram] ?? [])
            }

            healthKit.healthStore.execute(query)
        }
    }

    private func fetchVoltageMeasurements(
        for sample: HKElectrocardiogram,
        healthKit: HealthKit
    ) async throws -> [Double] {
        try await withCheckedThrowingContinuation { continuation in
            var voltages: [Double] = []
            var didResume = false

            let query = HKElectrocardiogramQuery(electrocardiogram: sample) { _, measurement, done, error in
                if let error, !didResume {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }

                if let measurement,
                   let voltageQuantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                    voltages.append(voltageQuantity.doubleValue(for: .volt()))
                }

                if done, !didResume {
                    didResume = true
                    continuation.resume(returning: voltages)
                }
            }

            healthKit.healthStore.execute(query)
        }
    }
}