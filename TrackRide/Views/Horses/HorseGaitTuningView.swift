//
//  HorseGaitTuningView.swift
//  TrackRide
//
//  Allows users to fine-tune gait detection parameters for individual horses.
//  Horses have unique movement characteristics that may not match breed averages.

import SwiftUI
import SwiftData

struct HorseGaitTuningView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var horse: Horse

    @State private var showingResetConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Explanation Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Gait Detection Tuning", systemImage: "waveform.path.ecg")
                            .font(.headline)

                        Text("If gait detection isn't accurate for \(horse.name), adjust these settings. Changes apply to future rides only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                }

                // Stride Frequency Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stride Frequency Offset")
                            Spacer()
                            Text(frequencyOffsetText)
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $horse.gaitFrequencyOffset,
                            in: -0.5...0.5,
                            step: 0.05
                        )
                        .tint(horse.gaitFrequencyOffset == 0 ? .gray : .blue)

                        Text("Adjust if gait is detected incorrectly at all speeds. Positive = faster stride, Negative = slower stride.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Stride Frequency")
                } footer: {
                    Text("Based on \(horse.typedBreed.displayName) breed profile")
                }

                // Speed Thresholds Section
                Section("Speed Thresholds") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Walk to Trot Transition")
                            Spacer()
                            Text(thresholdText(horse.walkTrotThreshold))
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $horse.walkTrotThreshold,
                            in: -1.0...1.0,
                            step: 0.1
                        )
                        .tint(horse.walkTrotThreshold == 0 ? .gray : .orange)

                        Text("Positive = needs higher speed for trot detection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Trot to Canter Transition")
                            Spacer()
                            Text(thresholdText(horse.trotCanterThreshold))
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $horse.trotCanterThreshold,
                            in: -1.0...1.0,
                            step: 0.1
                        )
                        .tint(horse.trotCanterThreshold == 0 ? .gray : .orange)

                        Text("Positive = needs higher speed for canter detection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Sensitivity Section
                Section("Detection Sensitivity") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Canter Sensitivity")
                            Spacer()
                            Text(sensitivityText(horse.canterSensitivity))
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $horse.canterSensitivity,
                            in: 0.5...1.5,
                            step: 0.05
                        )
                        .tint(horse.canterSensitivity == 1.0 ? .gray : .green)

                        Text("Higher = more likely to detect canter. Lower = requires clearer canter movement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transition Speed")
                            Spacer()
                            Text(transitionSpeedText)
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $horse.gaitTransitionSpeed,
                            in: 0.5...1.5,
                            step: 0.05
                        )
                        .tint(horse.gaitTransitionSpeed == 1.0 ? .gray : .purple)

                        Text("Higher = faster response to gait changes. Lower = more stable, slower transitions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Speed Sensitivity Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed Sensitivity")
                            Spacer()
                            Text(speedSensitivityText)
                                .foregroundStyle(.secondary)
                        }

                        Slider(
                            value: $horse.gaitSpeedSensitivity,
                            in: -0.5...0.5,
                            step: 0.05
                        )
                        .tint(horse.gaitSpeedSensitivity == 0 ? .gray : .blue)

                        Text("Adjust if horse has unusual speed for its gait. Positive = faster gaits at lower speeds.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Overall Speed Adjustment")
                }

                // Common Issues Section
                Section("Troubleshooting") {
                    DisclosureGroup("Canter often detected as trot") {
                        Text("Try increasing Canter Sensitivity and lowering Trot to Canter Transition threshold.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("Trot often detected as walk") {
                        Text("Try lowering Walk to Trot Transition threshold or adjusting Stride Frequency to positive.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("Gait changes too slowly") {
                        Text("Increase Transition Speed. Note: too high may cause flickering between gaits.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("Gait flickers between states") {
                        Text("Decrease Transition Speed for more stable detection.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Reset Section
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset to Breed Defaults", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Gait Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Reset Gait Settings",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset to Defaults", role: .destructive) {
                    horse.resetGaitTuning()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all gait detection settings to the default values for \(horse.typedBreed.displayName).")
            }
        }
    }

    // MARK: - Computed Properties

    private var frequencyOffsetText: String {
        if horse.gaitFrequencyOffset == 0 {
            return "Default"
        }
        let sign = horse.gaitFrequencyOffset > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", horse.gaitFrequencyOffset)) Hz"
    }

    private func thresholdText(_ value: Double) -> String {
        if value == 0 {
            return "Default"
        }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) m/s"
    }

    private func sensitivityText(_ value: Double) -> String {
        if abs(value - 1.0) < 0.01 {
            return "Normal"
        }
        if value < 1.0 {
            return "Lower (\(String(format: "%.0f", value * 100))%)"
        }
        return "Higher (\(String(format: "%.0f", value * 100))%)"
    }

    private var transitionSpeedText: String {
        if abs(horse.gaitTransitionSpeed - 1.0) < 0.01 {
            return "Normal"
        }
        if horse.gaitTransitionSpeed < 1.0 {
            return "Slower"
        }
        return "Faster"
    }

    private var speedSensitivityText: String {
        if horse.gaitSpeedSensitivity == 0 {
            return "Default"
        }
        let sign = horse.gaitSpeedSensitivity > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", horse.gaitSpeedSensitivity))"
    }

    // MARK: - Actions

    private func saveSettings() {
        // Mark as custom if any setting differs from default
        horse.hasCustomGaitSettings = horse.gaitFrequencyOffset != 0 ||
            horse.gaitSpeedSensitivity != 0 ||
            horse.gaitTransitionSpeed != 1.0 ||
            horse.canterSensitivity != 1.0 ||
            horse.walkTrotThreshold != 0 ||
            horse.trotCanterThreshold != 0

        horse.updatedAt = Date()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Horse.self, configurations: config)
    let horse = Horse()
    horse.name = "Thunder"
    horse.breedType = HorseBreed.thoroughbred.rawValue
    container.mainContext.insert(horse)

    return HorseGaitTuningView(horse: horse)
        .modelContainer(container)
}
