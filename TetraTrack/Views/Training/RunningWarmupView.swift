//
//  RunningWarmupView.swift
//  TetraTrack
//
//  Pre-race warmup plan for 1500m tetrathlon running
//

import SwiftUI

struct RunningWarmupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.2))
                                .frame(width: 64, height: 64)
                            Image(systemName: "figure.run")
                                .font(.title2)
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("1500m Race Warmup")
                                .font(.title2.bold())
                            Text("Complete 25-30 minutes before race start")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Warmup steps
                    ForEach(Array(warmupSteps.enumerated()), id: \.offset) { index, step in
                        WarmupStepRow(step: step, number: index + 1)
                    }

                    // Tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
                            .font(.headline)

                        tipRow(icon: "drop.fill", text: "Sip water during warmup but stop 10 minutes before race")
                        tipRow(icon: "thermometer.sun.fill", text: "In cold weather, add an extra 5 minutes of easy jogging")
                        tipRow(icon: "clock.fill", text: "Finish warmup 3-5 minutes before your start time")
                        tipRow(icon: "brain.head.profile.fill", text: "Use the last few minutes to focus and visualise your race plan")
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Warmup Plan Data

    private var warmupSteps: [WarmupStep] {
        [
            WarmupStep(
                title: "Easy Jog",
                duration: "5-8 min",
                description: "Gentle jog at conversational pace to raise heart rate and body temperature.",
                purpose: "Increases blood flow to muscles and prepares joints"
            ),
            WarmupStep(
                title: "Dynamic Stretches",
                duration: "3-4 min",
                description: "Leg swings (forward/back and side-to-side), high knees, butt kicks, walking lunges, and ankle circles.",
                purpose: "Mobilises hips, knees, and ankles through full range of motion"
            ),
            WarmupStep(
                title: "Strides",
                duration: "4-5 min",
                description: "4-6 strides of 60-80m, building to about 90% effort. Walk back to recover between each.",
                purpose: "Activates fast-twitch muscle fibres and rehearses race pace mechanics"
            ),
            WarmupStep(
                title: "Race Pace Effort",
                duration: "2 min",
                description: "One 200-300m run at target race pace. Focus on relaxed, efficient form.",
                purpose: "Locks in race rhythm and breathing pattern"
            ),
            WarmupStep(
                title: "Easy Jog and Shake Out",
                duration: "2-3 min",
                description: "Very light jog followed by gentle shaking of legs and arms. Stay loose.",
                purpose: "Keeps muscles warm while allowing heart rate to settle"
            ),
            WarmupStep(
                title: "Mental Preparation",
                duration: "2-3 min",
                description: "Stand still, take deep breaths. Visualise your race plan: start controlled, build through the middle, finish strong.",
                purpose: "Calms nerves and focuses attention on execution"
            ),
        ]
    }
}

// MARK: - Supporting Types

private struct WarmupStep {
    let title: String
    let duration: String
    let description: String
    let purpose: String
}

private struct WarmupStepRow: View {
    let step: WarmupStep
    let number: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Step number
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(step.title)
                        .font(.headline)
                    Spacer()
                    Text(step.duration)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Text(step.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "target")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(step.purpose)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    RunningWarmupView()
}
