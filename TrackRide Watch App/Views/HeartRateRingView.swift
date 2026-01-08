//
//  HeartRateRingView.swift
//  TrackRide Watch App
//
//  Animated heart rate display with zone coloring
//

import SwiftUI

struct HeartRateRingView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityService.self) private var connectivityService

    @State private var animateHeart = false

    var body: some View {
        VStack(spacing: 8) {
            // Heart rate ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.2)
                    .foregroundStyle(zoneColor)

                // Progress ring
                Circle()
                    .trim(from: 0, to: zoneProgress)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .foregroundStyle(zoneColor)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: zoneProgress)

                // Heart icon and BPM
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(zoneColor)
                        .scaleEffect(animateHeart ? 1.2 : 1.0)
                        .animation(
                            heartRate > 0 ?
                                .easeInOut(duration: 60.0 / Double(max(heartRate, 60)))
                                    .repeatForever(autoreverses: true) :
                                .default,
                            value: animateHeart
                        )

                    Text("\(heartRate)")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()

                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            .onAppear {
                animateHeart = true
            }

            // Zone indicator
            Text(zoneName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(zoneColor)

            // Stats row
            if workoutManager.isWorkoutActive {
                HStack(spacing: 20) {
                    VStack {
                        Text("\(workoutManager.averageHeartRate)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Avg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    VStack {
                        Text("\(workoutManager.maxHeartRate)")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text("Max")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var heartRate: Int {
        // Prefer local workout manager data, fallback to connectivity data
        if workoutManager.isWorkoutActive {
            return workoutManager.currentHeartRate
        }
        return connectivityService.heartRate
    }

    private var zone: Int {
        if workoutManager.isWorkoutActive {
            // Calculate zone from current HR (assuming max HR around 180)
            let maxHR = 180
            let percentage = Double(heartRate) / Double(maxHR)
            switch percentage {
            case ..<0.60: return 1
            case 0.60..<0.70: return 2
            case 0.70..<0.80: return 3
            case 0.80..<0.90: return 4
            default: return 5
            }
        }
        return connectivityService.heartRateZone
    }

    private var zoneProgress: CGFloat {
        CGFloat(zone) / 5.0
    }

    private var zoneName: String {
        switch zone {
        case 1: return "Recovery"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Maximum"
        default: return "---"
        }
    }

    private var zoneColor: Color {
        switch zone {
        case 1: return .gray
        case 2: return .blue
        case 3: return .green
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

#Preview {
    HeartRateRingView()
        .environment(WorkoutManager())
        .environment(WatchConnectivityService.shared)
}
