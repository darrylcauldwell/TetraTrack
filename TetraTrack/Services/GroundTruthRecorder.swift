//
//  GroundTruthRecorder.swift
//  TetraTrack
//
//  Records observer-provided ground truth gait labels during live tracking

import Foundation
import Observation

@Observable
final class GroundTruthRecorder {

    struct GroundTruthLabel: Codable, Identifiable {
        let id: UUID
        let timestamp: Date
        let gaitType: String
    }

    private(set) var labels: [GroundTruthLabel] = []
    private(set) var isRecording: Bool = false
    var currentGait: GaitType = .stationary

    func startRecording() {
        labels.removeAll()
        isRecording = true
        recordLabel(gait: currentGait)
    }

    func stopRecording() {
        isRecording = false
    }

    func selectGait(_ gait: GaitType) {
        guard isRecording, gait != currentGait else { return }
        currentGait = gait
        recordLabel(gait: gait)
    }

    private func recordLabel(gait: GaitType) {
        labels.append(GroundTruthLabel(
            id: UUID(),
            timestamp: Date(),
            gaitType: gait.rawValue
        ))
    }

    /// Export labels as JSON Data for sharing
    func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        struct ExportPayload: Encodable {
            let format: String
            let version: Int
            let recordedAt: Date
            let labelCount: Int
            let labels: [ExportLabel]

            enum CodingKeys: String, CodingKey {
                case format
                case version
                case recordedAt = "recorded_at"
                case labelCount = "label_count"
                case labels
            }
        }

        struct ExportLabel: Encodable {
            let timestamp: Date
            let gait: String
        }

        let payload = ExportPayload(
            format: "TetraTrack Ground Truth",
            version: 1,
            recordedAt: Date(),
            labelCount: labels.count,
            labels: labels.map { ExportLabel(timestamp: $0.timestamp, gait: $0.gaitType) }
        )

        return try? encoder.encode(payload)
    }
}
