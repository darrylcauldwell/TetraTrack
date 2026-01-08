//
//  RideControlView.swift
//  TrackRide Watch App
//
//  Main ride control view with large glove-friendly buttons
//

import SwiftUI

struct RideControlView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var isPaused: Bool = false

    var body: some View {
        TabView {
            // Page 1: Main controls
            mainControlsPage

            // Page 2: Discipline-specific metrics (only when riding)
            if connectivityService.isRiding {
                disciplineMetricsPage
            }

            // Page 3: Heart rate (only when riding)
            if connectivityService.isRiding {
                heartRatePage
            }
        }
        .tabViewStyle(.verticalPage)
    }

    // MARK: - Main Controls Page

    private var mainControlsPage: some View {
        VStack(spacing: 8) {
            // Horse and ride type header
            headerView

            // Stats display when riding
            if connectivityService.isRiding {
                VStack(spacing: 4) {
                    // Duration
                    Text(connectivityService.formattedDuration)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(isPaused ? .secondary : .primary)

                    // Paused indicator
                    if isPaused {
                        Text("PAUSED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }

                    // Distance and speed
                    HStack(spacing: 16) {
                        VStack {
                            Text(connectivityService.formattedDistance)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        VStack {
                            Text(connectivityService.formattedSpeed)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Speed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Current gait
                    Text(connectivityService.gait)
                        .font(.caption)
                        .foregroundStyle(gaitColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(gaitColor.opacity(0.2))
                        .clipShape(Capsule())
                }
            } else {
                // Idle state
                VStack(spacing: 8) {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)

                    Text("TrackRide")
                        .font(.headline)

                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Control buttons
            controlButtons
        }
        .padding()
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 2) {
            if let horseName = connectivityService.horseName {
                Text(horseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let rideType = connectivityService.rideType {
                Text(rideType)
                    .font(.caption2)
                    .foregroundStyle(disciplineColor)
            }
        }
    }

    // MARK: - Control Buttons

    @ViewBuilder
    private var controlButtons: some View {
        if connectivityService.isRiding {
            // Pause/Resume and Stop buttons when riding
            HStack(spacing: 20) {
                // Pause/Resume button
                Button(action: togglePause) {
                    ZStack {
                        Circle()
                            .fill(isPaused ? Color.green : Color.orange)
                            .frame(width: 60, height: 60)

                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                // Stop button
                Button(action: stopRide) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 60, height: 60)

                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        } else {
            // Start button when idle
            Button(action: startRide) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 80, height: 80)

                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Discipline Metrics Page

    private var disciplineMetricsPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                switch connectivityService.rideType?.lowercased() {
                case "hacking":
                    hackingMetricsView
                case "flatwork":
                    flatworkMetricsView
                case "cross-country", "xc":
                    crossCountryMetricsView
                default:
                    // Generic metrics for unknown discipline
                    genericMetricsView
                }
            }
            .padding()
        }
    }

    // MARK: - Hacking Metrics

    private var hackingMetricsView: some View {
        VStack(spacing: 8) {
            Text("Hacking")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Gait percentages as bars
            VStack(spacing: 4) {
                gaitBar(label: "Walk", percent: connectivityService.walkPercent, color: .teal)
                gaitBar(label: "Trot", percent: connectivityService.trotPercent, color: .blue)
                gaitBar(label: "Canter", percent: connectivityService.canterPercent, color: .purple)
            }

            Divider()

            // Distance and elevation
            HStack {
                VStack {
                    Text(connectivityService.formattedDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text(String(format: "%.0fm", connectivityService.elevation))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Elevation")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Flatwork Metrics

    private var flatworkMetricsView: some View {
        VStack(spacing: 8) {
            Text("Flatwork")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Gait breakdown
            VStack(spacing: 4) {
                gaitBar(label: "Walk", percent: connectivityService.walkPercent, color: .teal)
                gaitBar(label: "Trot", percent: connectivityService.trotPercent, color: .blue)
                gaitBar(label: "Canter", percent: connectivityService.canterPercent, color: .purple)
            }

            Divider()

            // Lead balance
            VStack(spacing: 2) {
                Text("Lead Balance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                balanceBar(
                    leftLabel: "L",
                    leftValue: connectivityService.leftLeadPercent,
                    rightLabel: "R",
                    rightValue: connectivityService.rightLeadPercent
                )
            }

            // Rein balance
            VStack(spacing: 2) {
                Text("Rein Balance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                balanceBar(
                    leftLabel: "L",
                    leftValue: connectivityService.leftReinPercent,
                    rightLabel: "R",
                    rightValue: connectivityService.rightReinPercent
                )
            }

            Divider()

            // Turn counts
            HStack {
                VStack {
                    Text("\(connectivityService.leftTurnCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("L Turns")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(connectivityService.rightTurnCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("R Turns")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Scores
            HStack {
                VStack {
                    Text(String(format: "%.0f", connectivityService.symmetryScore))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor(connectivityService.symmetryScore))
                    Text("Symmetry")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text(String(format: "%.0f", connectivityService.rhythmScore))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor(connectivityService.rhythmScore))
                    Text("Rhythm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Cross-Country Metrics

    private var crossCountryMetricsView: some View {
        VStack(spacing: 8) {
            Text("Cross-Country")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Optimal time display
            VStack(spacing: 4) {
                Text("Optimal Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatTime(connectivityService.optimalTime))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
            }

            Divider()

            // Current vs optimal
            VStack(spacing: 4) {
                Text("Current")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(connectivityService.formattedDuration)
                    .font(.system(.headline, design: .monospaced))
                    .fontWeight(.bold)
            }

            // Time difference
            VStack(spacing: 2) {
                Text("Difference")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 2) {
                    Text(connectivityService.timeDifference >= 0 ? "+" : "")
                    Text(formatTime(abs(connectivityService.timeDifference)))
                }
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(timeDifferenceColor)
            }

            Divider()

            // Gait percentages (simplified)
            HStack(spacing: 8) {
                VStack {
                    Text(String(format: "%.0f%%", connectivityService.trotPercent))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("Trot")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f%%", connectivityService.canterPercent))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("Canter")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text(String(format: "%.0f%%", connectivityService.gallopPercent))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text("Gallop")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Distance
            VStack {
                Text(connectivityService.formattedDistance)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Generic Metrics

    private var genericMetricsView: some View {
        VStack(spacing: 8) {
            Text("Ride Metrics")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Gait percentages
            VStack(spacing: 4) {
                gaitBar(label: "Walk", percent: connectivityService.walkPercent, color: .teal)
                gaitBar(label: "Trot", percent: connectivityService.trotPercent, color: .blue)
                gaitBar(label: "Canter", percent: connectivityService.canterPercent, color: .purple)
                if connectivityService.gallopPercent > 0 {
                    gaitBar(label: "Gallop", percent: connectivityService.gallopPercent, color: .indigo)
                }
            }

            Divider()

            HStack {
                VStack {
                    Text(connectivityService.formattedDistance)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text(connectivityService.formattedSpeed)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Speed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Heart Rate Page

    private var heartRatePage: some View {
        VStack(spacing: 12) {
            Text("Heart Rate")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Current heart rate with zone color
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(heartRateZoneColor)
                Text("\(connectivityService.heartRate)")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                Text("bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Zone indicator
            Text("Zone \(connectivityService.heartRateZone)")
                .font(.caption)
                .foregroundStyle(heartRateZoneColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(heartRateZoneColor.opacity(0.2))
                .clipShape(Capsule())

            Divider()

            // Avg and Max
            HStack {
                VStack {
                    Text("\(connectivityService.averageHeartRate)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Avg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack {
                    Text("\(connectivityService.maxHeartRate)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    Text("Max")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Helper Views

    private func gaitBar(label: String, percent: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .clipShape(Capsule())

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percent / 100), height: 8)
                        .clipShape(Capsule())
                }
            }
            .frame(height: 8)

            Text(String(format: "%.0f%%", percent))
                .font(.caption2)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func balanceBar(leftLabel: String, leftValue: Double, rightLabel: String, rightValue: Double) -> some View {
        HStack(spacing: 4) {
            Text(leftLabel)
                .font(.caption2)
            Text(String(format: "%.0f%%", leftValue))
                .font(.caption2)
                .foregroundStyle(leftValue > 55 ? .orange : (leftValue < 45 ? .blue : .primary))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .clipShape(Capsule())

                    // Center marker
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: 10)
                        .position(x: geometry.size.width / 2, y: 5)

                    // Balance indicator
                    Circle()
                        .fill(abs(leftValue - 50) > 10 ? Color.orange : Color.green)
                        .frame(width: 10, height: 10)
                        .position(x: geometry.size.width * CGFloat(leftValue / 100), y: 5)
                }
            }
            .frame(height: 10)

            Text(String(format: "%.0f%%", rightValue))
                .font(.caption2)
                .foregroundStyle(rightValue > 55 ? .orange : (rightValue < 45 ? .blue : .primary))
            Text(rightLabel)
                .font(.caption2)
        }
    }

    // MARK: - Actions

    private func startRide() {
        Task {
            await workoutManager.startWorkout()
            connectivityService.sendStartRide()
            isPaused = false
        }
    }

    private func stopRide() {
        Task {
            await workoutManager.stopWorkout()
            connectivityService.sendStopRide()
            isPaused = false
        }
    }

    private func togglePause() {
        Task {
            if isPaused {
                await workoutManager.resumeWorkout()
                connectivityService.sendResumeRide()
            } else {
                await workoutManager.pauseWorkout()
                connectivityService.sendPauseRide()
            }
            isPaused.toggle()
        }
    }

    // MARK: - Helpers

    private var gaitColor: Color {
        switch connectivityService.gait.lowercased() {
        case "walk": return .teal
        case "trot": return .blue
        case "canter": return .purple
        case "gallop": return .indigo
        default: return .gray
        }
    }

    private var disciplineColor: Color {
        switch connectivityService.rideType?.lowercased() {
        case "hacking": return .green
        case "flatwork": return .purple
        case "cross-country", "xc": return .orange
        default: return .blue
        }
    }

    private var heartRateZoneColor: Color {
        switch connectivityService.heartRateZone {
        case 1: return .gray
        case 2: return .blue
        case 3: return .green
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .orange
    }

    private var timeDifferenceColor: Color {
        let diff = connectivityService.timeDifference
        if abs(diff) < 5 { return .green }
        if abs(diff) < 15 { return .yellow }
        return .red
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RideControlView()
        .environment(WorkoutManager())
        .environment(WatchConnectivityService.shared)
}
