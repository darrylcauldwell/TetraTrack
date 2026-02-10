//
//  HeartRateData.swift
//  TetraTrackShared
//
//  Heart rate data structures and zone calculations
//

import Foundation

// MARK: - Heart Rate Sample

public struct HeartRateSample: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let bpm: Int
    public let zone: HeartRateZone

    public init(timestamp: Date = Date(), bpm: Int, maxHeartRate: Int) {
        self.id = UUID()
        self.timestamp = timestamp
        self.bpm = bpm
        self.zone = HeartRateZone.zone(for: bpm, maxHR: maxHeartRate)
    }
}

// MARK: - Heart Rate Zone

public enum HeartRateZone: Int, Codable, CaseIterable, Sendable {
    case zone1 = 1  // 50-60% - Very light (warm-up/recovery)
    case zone2 = 2  // 60-70% - Light (fat burn)
    case zone3 = 3  // 70-80% - Moderate (aerobic)
    case zone4 = 4  // 80-90% - Hard (anaerobic)
    case zone5 = 5  // 90-100% - Maximum (peak)

    public var name: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Light"
        case .zone3: return "Moderate"
        case .zone4: return "Hard"
        case .zone5: return "Maximum"
        }
    }

    public var description: String {
        switch self {
        case .zone1: return "Warm-up & recovery"
        case .zone2: return "Light activity, fat burning"
        case .zone3: return "Aerobic endurance"
        case .zone4: return "Anaerobic training"
        case .zone5: return "Peak performance"
        }
    }

    public var percentageRange: ClosedRange<Double> {
        switch self {
        case .zone1: return 0.50...0.60
        case .zone2: return 0.60...0.70
        case .zone3: return 0.70...0.80
        case .zone4: return 0.80...0.90
        case .zone5: return 0.90...1.00
        }
    }

    public var colorName: String {
        switch self {
        case .zone1: return "gray"
        case .zone2: return "blue"
        case .zone3: return "green"
        case .zone4: return "orange"
        case .zone5: return "red"
        }
    }

    /// Calculate zone for a given heart rate
    public static func zone(for bpm: Int, maxHR: Int) -> HeartRateZone {
        guard maxHR > 0 else { return .zone1 }
        let percentage = Double(bpm) / Double(maxHR)

        switch percentage {
        case ..<0.50: return .zone1
        case 0.50..<0.60: return .zone1
        case 0.60..<0.70: return .zone2
        case 0.70..<0.80: return .zone3
        case 0.80..<0.90: return .zone4
        default: return .zone5
        }
    }

    /// Calculate zone boundaries for a max HR
    public static func zoneBoundaries(for maxHR: Int) -> [(zone: HeartRateZone, minBPM: Int, maxBPM: Int)] {
        HeartRateZone.allCases.map { zone in
            let minBPM = Int(Double(maxHR) * zone.percentageRange.lowerBound)
            let maxBPM = Int(Double(maxHR) * zone.percentageRange.upperBound)
            return (zone, minBPM, maxBPM)
        }
    }
}

// MARK: - Heart Rate Statistics

public struct HeartRateStatistics: Codable, Sendable {
    public let minBPM: Int
    public let maxBPM: Int
    public let averageBPM: Int
    public let samples: [HeartRateSample]
    public let zoneDurations: [HeartRateZone: TimeInterval]

    public init(samples: [HeartRateSample]) {
        self.samples = samples

        if samples.isEmpty {
            self.minBPM = 0
            self.maxBPM = 0
            self.averageBPM = 0
            self.zoneDurations = [:]
        } else {
            self.minBPM = samples.map(\.bpm).min() ?? 0
            self.maxBPM = samples.map(\.bpm).max() ?? 0
            self.averageBPM = samples.map(\.bpm).reduce(0, +) / samples.count

            // Calculate time in each zone
            var durations: [HeartRateZone: TimeInterval] = [:]
            for zone in HeartRateZone.allCases {
                durations[zone] = 0
            }

            // Estimate duration between samples
            let sortedSamples = samples.sorted { $0.timestamp < $1.timestamp }
            for i in 0..<sortedSamples.count {
                let sample = sortedSamples[i]
                let duration: TimeInterval
                if i < sortedSamples.count - 1 {
                    duration = sortedSamples[i + 1].timestamp.timeIntervalSince(sample.timestamp)
                } else {
                    duration = 1.0 // Assume 1 second for last sample
                }
                durations[sample.zone, default: 0] += duration
            }
            self.zoneDurations = durations
        }
    }

    public var totalDuration: TimeInterval {
        zoneDurations.values.reduce(0, +)
    }

    public func zonePercentage(for zone: HeartRateZone) -> Double {
        guard totalDuration > 0 else { return 0 }
        return (zoneDurations[zone] ?? 0) / totalDuration * 100
    }

    public var primaryZone: HeartRateZone {
        zoneDurations.max { $0.value < $1.value }?.key ?? .zone2
    }
}

// MARK: - Max Heart Rate Calculation

public struct MaxHeartRateCalculator {
    /// Tanaka formula: 208 - (0.7 x age)
    /// More accurate for older adults than 220 - age
    public static func tanaka(age: Int) -> Int {
        return Int(208.0 - (0.7 * Double(age)))
    }

    /// Traditional formula: 220 - age
    public static func traditional(age: Int) -> Int {
        return 220 - age
    }

    /// Gulati formula for women: 206 - (0.88 x age)
    public static func gulati(age: Int) -> Int {
        return Int(206.0 - (0.88 * Double(age)))
    }
}

// MARK: - Codable Helpers for Zone Durations

extension HeartRateStatistics {
    enum CodingKeys: String, CodingKey {
        case minBPM, maxBPM, averageBPM, samples, zoneDurationsData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minBPM = try container.decode(Int.self, forKey: .minBPM)
        maxBPM = try container.decode(Int.self, forKey: .maxBPM)
        averageBPM = try container.decode(Int.self, forKey: .averageBPM)
        samples = try container.decode([HeartRateSample].self, forKey: .samples)

        let durationsData = try container.decode([Int: TimeInterval].self, forKey: .zoneDurationsData)
        var durations: [HeartRateZone: TimeInterval] = [:]
        for (rawValue, duration) in durationsData {
            if let zone = HeartRateZone(rawValue: rawValue) {
                durations[zone] = duration
            }
        }
        zoneDurations = durations
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minBPM, forKey: .minBPM)
        try container.encode(maxBPM, forKey: .maxBPM)
        try container.encode(averageBPM, forKey: .averageBPM)
        try container.encode(samples, forKey: .samples)

        var durationsData: [Int: TimeInterval] = [:]
        for (zone, duration) in zoneDurations {
            durationsData[zone.rawValue] = duration
        }
        try container.encode(durationsData, forKey: .zoneDurationsData)
    }
}
