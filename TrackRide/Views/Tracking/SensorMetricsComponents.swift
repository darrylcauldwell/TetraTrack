//
//  SensorMetricsComponents.swift
//  TrackRide
//
//  UI components for displaying Watch sensor metrics during live sessions.
//

import SwiftUI

// MARK: - Rider Sensor Metrics (for Riding)

/// Displays sensor-based rider metrics during rides
struct RiderSensorMetricsView: View {
    let fatigueScore: Double
    let postureStability: Double
    let breathingRate: Double
    let jumpCount: Int
    let activePercent: Double
    var rideType: RideType = .hack

    private var showJumpCount: Bool {
        rideType == .crossCountry
    }

    var body: some View {
        VStack(spacing: 16) {
            // Fatigue and Posture gauges
            HStack(spacing: 24) {
                SensorGauge(
                    label: "Fatigue",
                    value: fatigueScore,
                    icon: "figure.walk",
                    invertColor: true  // Low = good
                )

                SensorGauge(
                    label: "Posture",
                    value: postureStability,
                    icon: "figure.equestrian.sports",
                    invertColor: false  // High = good
                )
            }

            // Jump count (for XC and Show Jumping)
            if showJumpCount && jumpCount > 0 {
                JumpCountBadge(count: jumpCount)
            }

            // Activity breakdown bar
            ActivityBreakdownBar(activePercent: activePercent)

            // Breathing rate indicator
            if breathingRate > 0 {
                BreathingRateIndicator(rate: breathingRate)
            }
        }
    }
}

// MARK: - Sensor Gauge

struct SensorGauge: View {
    let label: String
    let value: Double
    let icon: String
    var invertColor: Bool = false

    private var color: Color {
        let effectiveValue = invertColor ? (100 - value) : value
        switch effectiveValue {
        case 0..<40: return .red
        case 40..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: value / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            Text(String(format: "%.0f", value))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Jump Count Badge

struct JumpCountBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.equestrian.sports")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Jumps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Activity Breakdown Bar

struct ActivityBreakdownBar: View {
    let activePercent: Double

    private var passivePercent: Double {
        100 - activePercent
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Rider Activity")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(.green)
                        .frame(width: geometry.size.width * (activePercent / 100))
                    Rectangle()
                        .fill(.blue.opacity(0.5))
                        .frame(width: geometry.size.width * (passivePercent / 100))
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 10)

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Active \(Int(activePercent))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Passive \(Int(passivePercent))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(.blue.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Breathing Rate Indicator

struct BreathingRateIndicator: View {
    let rate: Double

    private var rateCategory: String {
        switch rate {
        case 0..<12: return "Relaxed"
        case 12..<18: return "Normal"
        case 18..<24: return "Elevated"
        default: return "High"
        }
    }

    private var rateColor: Color {
        switch rate {
        case 0..<12: return .green
        case 12..<18: return .blue
        case 18..<24: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lungs.fill")
                .font(.title3)
                .foregroundStyle(rateColor)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: 2) {
                Text("Breathing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Text(String(format: "%.0f", rate))
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(rateCategory)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(rateColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(rateColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal)
    }
}

// MARK: - Running Sensor Metrics

struct RunningSensorMetricsView: View {
    let elevationGain: Double
    let elevationLoss: Double
    let breathingRate: Double
    let breathingTrend: Double
    let spo2: Double
    let minSpo2: Double
    let postureStability: Double
    let fatigueScore: Double

    var body: some View {
        VStack(spacing: 16) {
            // Elevation metrics
            ElevationMetricsRow(gain: elevationGain, loss: elevationLoss)

            // Breathing and SpO2
            HStack(spacing: 24) {
                if breathingRate > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "lungs.fill")
                                .foregroundStyle(.blue)
                            Text(String(format: "%.0f", breathingRate))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Text("Breathing")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if breathingTrend != 0 {
                            HStack(spacing: 2) {
                                Image(systemName: breathingTrend > 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                Text("Trend")
                                    .font(.caption2)
                            }
                            .foregroundStyle(breathingTrend > 0 ? .orange : .green)
                        }
                    }
                }

                if spo2 > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(spo2 >= 95 ? .green : (spo2 >= 90 ? .orange : .red))
                            Text(String(format: "%.0f%%", spo2))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Text("SpO2")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if minSpo2 < spo2 {
                            Text(String(format: "Min: %.0f%%", minSpo2))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Fatigue and Posture
            HStack(spacing: 24) {
                SensorGauge(
                    label: "Form",
                    value: postureStability,
                    icon: "figure.run",
                    invertColor: false
                )

                SensorGauge(
                    label: "Fatigue",
                    value: fatigueScore,
                    icon: "bolt.fill",
                    invertColor: true
                )
            }
        }
    }
}

// MARK: - Elevation Metrics Row

struct ElevationMetricsRow: View {
    let gain: Double
    let loss: Double

    var body: some View {
        HStack(spacing: 32) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.green)
                    Text(String(format: "%.0fm", gain))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Text("Gain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.right")
                        .foregroundStyle(.red)
                    Text(String(format: "%.0fm", loss))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Text("Loss")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Swimming Sensor Metrics

struct SwimmingSensorMetricsView: View {
    let isSubmerged: Bool
    let submergedTime: TimeInterval
    let submersionCount: Int
    let spo2: Double
    let minSpo2: Double
    let recoveryQuality: Double

    private var submergedTimeFormatted: String {
        let minutes = Int(submergedTime) / 60
        let seconds = Int(submergedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Submersion status
            HStack(spacing: 16) {
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(isSubmerged ? .blue : .gray)
                        .frame(width: 12, height: 12)
                    Text(isSubmerged ? "In Water" : "Above Water")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                // Submersion count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(submersionCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Laps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            // Swim time
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(submergedTimeFormatted)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    Text("Swim Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if spo2 > 0 {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(spo2 >= 95 ? .green : (spo2 >= 90 ? .orange : .red))
                            Text(String(format: "%.0f%%", spo2))
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Text("SpO2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Recovery quality
            SensorGauge(
                label: "Recovery",
                value: recoveryQuality,
                icon: "heart.fill",
                invertColor: false
            )
        }
    }
}

// MARK: - Shooting Sensor Metrics

struct ShootingSensorMetricsView: View {
    let tremorLevel: Double
    let breathingRate: Double
    let posturePitch: Double
    let postureRoll: Double
    let postureStability: Double
    let stillnessScore: Double

    private var tremorColor: Color {
        switch tremorLevel {
        case 0..<20: return .green
        case 20..<40: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var stillnessColor: Color {
        switch stillnessScore {
        case 80...: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Main stability indicators
            HStack(spacing: 32) {
                // Tremor gauge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(tremorColor.opacity(0.2), lineWidth: 10)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: (100 - tremorLevel) / 100)
                            .stroke(tremorColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Image(systemName: "hand.raised.fill")
                                .font(.title3)
                                .foregroundStyle(tremorColor)
                            Text(String(format: "%.0f", 100 - tremorLevel))
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                    Text("Stability")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Stillness gauge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(stillnessColor.opacity(0.2), lineWidth: 10)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: stillnessScore / 100)
                            .stroke(stillnessColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Image(systemName: "scope")
                                .font(.title3)
                                .foregroundStyle(stillnessColor)
                            Text(String(format: "%.0f", stillnessScore))
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                    }
                    Text("Stillness")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Posture indicator
            PostureIndicator(pitch: posturePitch, roll: postureRoll)

            // Breathing for shot timing
            if breathingRate > 0 {
                BreathingForShotView(rate: breathingRate)
            }
        }
    }
}

// MARK: - Posture Indicator

struct PostureIndicator: View {
    let pitch: Double  // Forward/back
    let roll: Double   // Left/right

    private var isGoodPosture: Bool {
        abs(pitch) < 15 && abs(roll) < 10
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Stance")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                // Reference grid
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 60, height: 60)

                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 30, height: 30)

                // Center target
                Circle()
                    .fill(isGoodPosture ? .green : .orange)
                    .frame(width: 8, height: 8)

                // Current position
                Circle()
                    .fill(.blue)
                    .frame(width: 12, height: 12)
                    .offset(
                        x: CGFloat(roll).clamped(to: -30...30),
                        y: CGFloat(pitch).clamped(to: -30...30)
                    )
            }
            .frame(width: 70, height: 70)

            Text(isGoodPosture ? "Aligned" : "Adjust")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isGoodPosture ? .green : .orange)
        }
    }
}

// MARK: - Breathing for Shot View

struct BreathingForShotView: View {
    let rate: Double

    private var breathPhase: String {
        // Simplified - in real app would track actual breath cycle
        rate < 10 ? "Hold" : "Breathe"
    }

    private var isGoodForShot: Bool {
        rate < 12  // Low breathing rate = good time to shoot
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lungs.fill")
                .font(.title2)
                .foregroundStyle(isGoodForShot ? .green : .blue)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f bpm", rate))
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Breathing Rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGoodForShot {
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isGoodForShot ? .green.opacity(0.1) : .blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// MARK: - Training Load Summary View

struct TrainingLoadSummaryView: View {
    let totalLoad: Double
    let fatigueScore: Double
    let recoveryQuality: Double
    let averageIntensity: Double
    let breathingTrend: Double
    let spo2Trend: Double

    private var loadLevel: String {
        switch totalLoad {
        case 0..<30: return "Light"
        case 30..<60: return "Moderate"
        case 60..<90: return "Hard"
        default: return "Very Hard"
        }
    }

    private var loadColor: Color {
        switch totalLoad {
        case 0..<30: return .green
        case 30..<60: return .blue
        case 60..<90: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Training Load")
                .font(.headline)
                .fontWeight(.semibold)

            // Main load gauge
            ZStack {
                Circle()
                    .stroke(loadColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: min(totalLoad / 120, 1))
                    .stroke(loadColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", totalLoad))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(loadLevel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Sub-metrics
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(String(format: "%.0f", fatigueScore))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(fatigueScore > 60 ? .orange : .primary)
                    Text("Fatigue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", recoveryQuality))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(recoveryQuality > 70 ? .green : .orange)
                    Text("Recovery")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Text(String(format: "%.0f", averageIntensity))
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Intensity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Trends
            HStack(spacing: 16) {
                if breathingTrend != 0 {
                    TrendIndicator(
                        label: "Breathing",
                        trend: breathingTrend,
                        icon: "lungs"
                    )
                }

                if spo2Trend != 0 {
                    TrendIndicator(
                        label: "SpO2",
                        trend: spo2Trend,
                        icon: "drop"
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Trend Indicator

struct TrendIndicator: View {
    let label: String
    let trend: Double
    let icon: String

    private var isPositive: Bool {
        // For breathing, increasing is bad; for SpO2, increasing is good
        label == "SpO2" ? trend > 0 : trend < 0
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Image(systemName: trend > 0 ? "arrow.up" : "arrow.down")
                .font(.caption2)
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(isPositive ? .green : .orange)
    }
}

// MARK: - Helper Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Previews

#Preview("Riding Sensors") {
    RiderSensorMetricsView(
        fatigueScore: 35,
        postureStability: 78,
        breathingRate: 16,
        jumpCount: 3,
        activePercent: 65,
        rideType: .crossCountry
    )
    .padding()
}

#Preview("Running Sensors") {
    RunningSensorMetricsView(
        elevationGain: 125,
        elevationLoss: 85,
        breathingRate: 22,
        breathingTrend: 2.5,
        spo2: 96,
        minSpo2: 93,
        postureStability: 72,
        fatigueScore: 45
    )
    .padding()
}

#Preview("Swimming Sensors") {
    SwimmingSensorMetricsView(
        isSubmerged: true,
        submergedTime: 185,
        submersionCount: 8,
        spo2: 97,
        minSpo2: 94,
        recoveryQuality: 85
    )
    .padding()
}

#Preview("Shooting Sensors") {
    ShootingSensorMetricsView(
        tremorLevel: 25,
        breathingRate: 10,
        posturePitch: 5,
        postureRoll: -3,
        postureStability: 85,
        stillnessScore: 78
    )
    .padding()
}

#Preview("Training Load") {
    TrainingLoadSummaryView(
        totalLoad: 65,
        fatigueScore: 48,
        recoveryQuality: 72,
        averageIntensity: 55,
        breathingTrend: 1.5,
        spo2Trend: -0.5
    )
    .padding()
}
