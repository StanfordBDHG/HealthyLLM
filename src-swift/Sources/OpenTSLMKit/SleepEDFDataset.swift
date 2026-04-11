import Foundation

public final class SleepEDFDataset {

    public enum Split: String {
        case train
        case validation
        case test
    }

    public static let prePrompt = """
    You are given a 30-second EEG time series segment. Your task is to classify the sleep stage based on the signal's characteristics.

    """

    public static let postPrompt = """
    Possible sleep stages are:
            Wake, Non-REM stage 1, Non-REM stage 2, Non-REM stage 3, REM sleep, Movement

    First, describe the key features of this EEG signal (amplitude, frequency, presence of specific waveforms). Then, based on your analysis, classify the sleep stage.

    Answer:
    """

    private let samples: [OpenTSLMSPSample]

    public init(csvURL: URL, split: Split = .test, seed: UInt64 = 42) throws {
        let rows = try Self.readRows(from: csvURL)
        let splitRows = Self.stratifiedSplit(rows: rows, split: split, seed: seed)
        self.samples = try splitRows.map(Self.convertRow)
    }

    public var count: Int { samples.count }

    public func sample(at index: Int) -> OpenTSLMSPSample {
        precondition(index >= 0 && index < samples.count, "sample index out of range")
        return samples[index]
    }
}

private extension SleepEDFDataset {

    struct Row {
        let timeSeries: String
        let label: String
        let rationale: String
    }

    static func readRows(from csvURL: URL) throws -> [Row] {
        let csv = try String(contentsOf: csvURL, encoding: .utf8)
        let records = parseCSV(csv)
        guard let header = records.first else {
            throw NSError(domain: "SleepEDFDataset", code: 1, userInfo: [NSLocalizedDescriptionKey: "CSV has no header"])
        }

        let columnIndex = Dictionary(uniqueKeysWithValues: header.enumerated().map { ($1, $0) })
        guard let timeSeriesIdx = columnIndex["time_series"],
              let labelIdx = columnIndex["label"]
        else {
            throw NSError(domain: "SleepEDFDataset", code: 2, userInfo: [NSLocalizedDescriptionKey: "CSV must include 'time_series' and 'label' columns"])
        }

        let rationaleIdx = columnIndex["rationale"]

        var rows: [Row] = []
        rows.reserveCapacity(max(records.count - 1, 0))

        for record in records.dropFirst() where !record.isEmpty {
            guard timeSeriesIdx < record.count, labelIdx < record.count else { continue }
            let rationale = (rationaleIdx != nil && rationaleIdx! < record.count) ? record[rationaleIdx!] : ""
            rows.append(Row(timeSeries: record[timeSeriesIdx], label: record[labelIdx], rationale: rationale))
        }

        return rows
    }

    static func convertRow(_ row: Row) throws -> OpenTSLMSPSample {
        let rawSeries = try parseTimeSeries(row.timeSeries)
        let normalized = zNormalize(rawSeries)

        let mean = rawSeries.reduce(0, +) / Float(max(rawSeries.count, 1))
        let variance = rawSeries.reduce(0) { partial, value in
            let d = value - mean
            return partial + d * d
        } / Float(max(rawSeries.count, 1))
        let std = max(sqrt(variance), 1e-6)

        return OpenTSLMSPSample(
            prePrompt: SleepEDFDataset.prePrompt,
            timeSeriesText: [
                "The following is the EEG time series, it has mean \(String(format: "%.4f", mean)) and std \(String(format: "%.4f", std)):"
            ],
            timeSeries: [normalized],
            postPrompt: SleepEDFDataset.postPrompt,
            label: row.label,
            answer: row.rationale
        )
    }

    static func zNormalize(_ values: [Float]) -> [Float] {
        let mean = values.reduce(0, +) / Float(max(values.count, 1))
        let variance = values.reduce(0) { partial, value in
            let d = value - mean
            return partial + d * d
        } / Float(max(values.count, 1))
        let std = max(sqrt(variance), 1e-6)
        return values.map { ($0 - mean) / std }
    }

    static func parseTimeSeries(_ raw: String) throws -> [Float] {
        guard let data = raw.data(using: .utf8) else {
            throw NSError(domain: "SleepEDFDataset", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8 in time_series"])
        }

        let parsed = try JSONSerialization.jsonObject(with: data)

        if let one = parsed as? [Double] {
            return one.map(Float.init)
        }

        if let two = parsed as? [[Double]], let first = two.first {
            return first.map(Float.init)
        }

        throw NSError(domain: "SleepEDFDataset", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unsupported time_series JSON shape"])
    }

    static func stratifiedSplit(rows: [Row], split: SleepEDFDataset.Split, seed: UInt64) -> [Row] {
        var groups: [String: [Row]] = [:]
        for row in rows {
            groups[row.label, default: []].append(row)
        }

        var selected: [Row] = []
        var generator = SeededGenerator(seed: seed)

        for labelRows in groups.values {
            var shuffled = labelRows
            shuffled.shuffle(using: &generator)

            let total = shuffled.count
            let testCount = Int((Double(total) * 0.1).rounded())
            let trainValCount = max(total - testCount, 0)
            let validationCount = Int((Double(trainValCount) * (1.0 / 9.0)).rounded())
            let trainCount = max(trainValCount - validationCount, 0)

            let train = Array(shuffled[0 ..< min(trainCount, total)])
            let validationStart = min(trainCount, total)
            let validationEnd = min(validationStart + validationCount, total)
            let validation = Array(shuffled[validationStart ..< validationEnd])
            let test = Array(shuffled[validationEnd ..< total])

            switch split {
            case .train:
                selected.append(contentsOf: train)
            case .validation:
                selected.append(contentsOf: validation)
            case .test:
                selected.append(contentsOf: test)
            }
        }

        return selected
    }

    static func parseCSV(_ csv: String) -> [[String]] {
        var records: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false

        var i = csv.startIndex
        while i < csv.endIndex {
            let ch = csv[i]
            if ch == "\"" {
                let nextIndex = csv.index(after: i)
                if insideQuotes && nextIndex < csv.endIndex && csv[nextIndex] == "\"" {
                    field.append("\"")
                    i = csv.index(after: nextIndex)
                    continue
                }
                insideQuotes.toggle()
                i = nextIndex
                continue
            }

            if ch == "," && !insideQuotes {
                row.append(field)
                field.removeAll(keepingCapacity: true)
                i = csv.index(after: i)
                continue
            }

            if (ch == "\n" || ch == "\r") && !insideQuotes {
                row.append(field)
                field.removeAll(keepingCapacity: true)
                if !row.isEmpty {
                    records.append(row)
                }
                row.removeAll(keepingCapacity: true)

                if ch == "\r" {
                    let nextIndex = csv.index(after: i)
                    if nextIndex < csv.endIndex && csv[nextIndex] == "\n" {
                        i = csv.index(after: nextIndex)
                        continue
                    }
                }

                i = csv.index(after: i)
                continue
            }

            field.append(ch)
            i = csv.index(after: i)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            records.append(row)
        }

        return records
    }
}

private struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}
