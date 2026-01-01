//
//  GroundTruthOverlay.swift
//  TetraTrack
//
//  Observer ground truth gait recording overlay for live tracking

import SwiftUI
import os

struct GroundTruthOverlay: View {
    @Bindable var recorder: GroundTruthRecorder
    let detectedGait: GaitType

    @State private var showingShareSheet = false
    @State private var exportURL: URL?

    private let gaits: [GaitType] = [.stationary, .walk, .trot, .canter, .gallop]

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Ground Truth Recording")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if recorder.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Detected vs selected comparison
            HStack {
                Text("App detects:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detectedGait.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColors.gait(detectedGait).opacity(0.2))
                    .clipShape(Capsule())

                Spacer()

                Text("You see:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(recorder.currentGait.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppColors.gait(recorder.currentGait).opacity(0.2))
                    .clipShape(Capsule())
            }

            // Gait buttons
            HStack(spacing: 8) {
                ForEach(gaits, id: \.self) { gait in
                    Button {
                        recorder.selectGait(gait)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: gait.icon)
                                .font(.title3)
                            Text(shortName(for: gait))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            recorder.currentGait == gait
                                ? AppColors.gait(gait)
                                : AppColors.gait(gait).opacity(0.15)
                        )
                        .foregroundStyle(recorder.currentGait == gait ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    recorder.currentGait == gait ? .white.opacity(0.5) : .clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .disabled(!recorder.isRecording)
                }
            }

            // Footer
            HStack {
                Text("\(recorder.labels.count) labels recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    exportGroundTruth()
                } label: {
                    Label("Stop & Export", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .disabled(!recorder.isRecording || recorder.labels.isEmpty)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func shortName(for gait: GaitType) -> String {
        switch gait {
        case .stationary: return "Stop"
        case .walk: return "Walk"
        case .trot: return "Trot"
        case .canter: return "Cntr"
        case .gallop: return "Glp"
        }
    }

    private func exportGroundTruth() {
        recorder.stopRecording()

        guard let jsonData = recorder.exportJSON() else { return }

        let fileName = "ground_truth_\(Formatters.fileNameDateTime(Date())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try jsonData.write(to: tempURL)
            exportURL = tempURL
            showingShareSheet = true
        } catch {
            Log.app.error("Failed to write ground truth export: \(error)")
        }
    }
}
