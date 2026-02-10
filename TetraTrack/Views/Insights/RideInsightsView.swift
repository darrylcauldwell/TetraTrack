//
//  RideInsightsView.swift
//  TetraTrack
//
//  Adaptive ride insights - shows GPS-based metrics for all users,
//  with enhanced Watch metrics when available.
//

import SwiftUI
import Charts

struct RideInsightsView: View {
    let ride: Ride

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Watch Detection

    /// Whether Apple Watch data is available for this ride
    private var hasWatchData: Bool {
        ride.averageHeartRate > 0
    }

    // MARK: - GPS-Based Scores (work for everyone)

    /// Pace consistency from GPS speed variability
    private var paceConsistencyScore: Double {
        let points = ride.sortedLocationPoints
        guard points.count > 10 else { return 0 }

        let speeds = points.map { $0.speed }.filter { $0 > 0.5 } // Ignore stationary
        guard speeds.count > 5 else { return 0 }

        let mean = speeds.reduce(0, +) / Double(speeds.count)
        guard mean > 0 else { return 0 }

        let variance = speeds.reduce(0) { $0 + pow($1 - mean, 2) } / Double(speeds.count)
        let cv = (sqrt(variance) / mean) * 100

        // Lower CV = more consistent pace = higher score
        if cv < 15 { return 90 }
        if cv < 25 { return 75 }
        if cv < 35 { return 60 }
        if cv < 50 { return 45 }
        return 30
    }

    /// Intensity score from speed zones (GPS-based)
    private var intensityScore: Double {
        let zones = computeSpeedZones()
        guard zones.total > 30 else { return 0 }

        // Good training has mix of zones, primarily working zone
        let workingPct = zones.zone2Pct
        let fastPct = zones.zone3Pct

        if workingPct >= 50 && workingPct <= 80 { return 85 }
        if workingPct >= 30 && fastPct >= 10 { return 75 }
        if workingPct >= 20 { return 60 }
        return 45 // Mostly easy/stationary
    }

    // MARK: - Watch-Enhanced Scores

    /// Rhythm score based on heart rate consistency
    private var rhythmScore: Double {
        guard ride.averageHeartRate > 0 else { return 0 }
        let samples = ride.heartRateSamples
        guard samples.count > 5 else { return 0 }

        let hrs = samples.map { Double($0.bpm) }
        let mean = hrs.reduce(0, +) / Double(hrs.count)
        let variance = hrs.reduce(0) { $0 + pow($1 - mean, 2) } / Double(hrs.count)
        let cv = mean > 0 ? (sqrt(variance) / mean) * 100 : 0

        if cv < 5 { return 95 }
        if cv < 10 { return 80 }
        if cv < 15 { return 65 }
        if cv < 20 { return 50 }
        return 35
    }

    /// Effort score based on HR zones
    private var effortScore: Double {
        guard ride.averageHeartRate > 0, ride.maxHeartRate > 0 else { return 0 }
        let avgHR = Double(ride.averageHeartRate)
        let maxHR = Double(ride.maxHeartRate)
        let intensity = (avgHR / maxHR) * 100

        if intensity >= 65 && intensity <= 80 { return 85 }
        if intensity >= 55 && intensity < 65 { return 70 }
        if intensity > 80 && intensity <= 85 { return 75 }
        if intensity > 85 { return 60 }
        return 50
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("Ride Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .presentationBackground(Color.black)
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 20) {
            overallRideScore
            intensityZonesCard

            if hasWatchData {
                // With Watch: Show all metrics
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    rhythmCard
                    effortCard
                }
            } else {
                // GPS only: Show what we can measure
                paceConsistencyCard
                watchPromptCard
            }
        }
        .padding(24)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            overallRideScore
            intensityZonesCard

            if hasWatchData {
                // With Watch: Show all metrics
                rhythmCard
                effortCard
            } else {
                // GPS only: Show what we can measure
                paceConsistencyCard
                watchPromptCard
            }
        }
        .padding()
    }

    // MARK: - Overall Score

    private var overallRideScore: some View {
        let scores: [Double]
        if hasWatchData {
            scores = [rhythmScore, effortScore].filter { $0 > 0 }
        } else {
            scores = [paceConsistencyScore, intensityScore].filter { $0 > 0 }
        }
        let overall = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        return VStack(spacing: 8) {
            Text("Ride Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(Int(overall))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(overall))

            if hasWatchData {
                HStack(spacing: 20) {
                    pillarMini("R", score: rhythmScore)
                    pillarMini("E", score: effortScore)
                }
            } else {
                HStack(spacing: 20) {
                    pillarMini("P", score: paceConsistencyScore)
                    pillarMini("I", score: intensityScore)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func pillarMini(_ letter: String, score: Double) -> some View {
        VStack(spacing: 4) {
            Text(letter)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(score > 0 ? "\(Int(score))" : "-")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .orange
        }
    }

    // MARK: - Intensity Zones Card (GPS Speed-based)

    private var intensityZonesCard: some View {
        let zones = computeSpeedZones()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundStyle(.blue)
                Text("Intensity Zones")
                    .font(.headline)
                Spacer()
                Text(ride.totalDuration.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if zones.total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if zones.zone1Pct > 0 {
                            Rectangle().fill(.green).frame(width: geo.size.width * zones.zone1Pct / 100)
                        }
                        if zones.zone2Pct > 0 {
                            Rectangle().fill(.blue).frame(width: geo.size.width * zones.zone2Pct / 100)
                        }
                        if zones.zone3Pct > 0 {
                            Rectangle().fill(.orange).frame(width: geo.size.width * zones.zone3Pct / 100)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 12)

                HStack(spacing: 16) {
                    zoneLegend("Easy", pct: zones.zone1Pct, color: .green)
                    zoneLegend("Working", pct: zones.zone2Pct, color: .blue)
                    zoneLegend("Fast", pct: zones.zone3Pct, color: .orange)
                }
                .font(.caption)
            } else {
                Text("GPS data needed for intensity zones")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func zoneLegend(_ name: String, pct: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(name) \(Int(pct))%")
                .foregroundStyle(.secondary)
        }
    }

    private func computeSpeedZones() -> (zone1Pct: Double, zone2Pct: Double, zone3Pct: Double, total: TimeInterval) {
        let points = ride.sortedLocationPoints
        guard points.count > 1 else { return (0, 0, 0, 0) }

        var zone1: TimeInterval = 0
        var zone2: TimeInterval = 0
        var zone3: TimeInterval = 0

        for i in 1..<points.count {
            let duration = points[i].timestamp.timeIntervalSince(points[i-1].timestamp)
            let speed = points[i].speed

            if speed < 1.94 { zone1 += duration }
            else if speed < 5.56 { zone2 += duration }
            else { zone3 += duration }
        }

        let total = zone1 + zone2 + zone3
        guard total > 0 else { return (0, 0, 0, 0) }

        return (
            zone1Pct: (zone1 / total) * 100,
            zone2Pct: (zone2 / total) * 100,
            zone3Pct: (zone3 / total) * 100,
            total: total
        )
    }

    // MARK: - GPS-Only Cards

    private var paceConsistencyCard: some View {
        let hasData = paceConsistencyScore > 0

        let keyMetric: String = {
            if hasData { return "\(Int(paceConsistencyScore))% consistent" }
            return "Needs GPS data"
        }()

        let tip: String = {
            if !hasData { return "GPS tracks pace consistency throughout ride" }
            if paceConsistencyScore >= 80 { return "Very steady pace - good control" }
            if paceConsistencyScore >= 60 { return "Reasonably consistent - some pace changes" }
            return "Variable pace - work on maintaining steady speed"
        }()

        return pillarCard(
            letter: "P",
            title: "Pace",
            subtitle: "Speed Consistency",
            score: paceConsistencyScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "gauge.with.dots.needle.bottom.50percent",
            color: .purple
        )
    }

    // MARK: - Watch-Enhanced Cards

    private var rhythmCard: some View {
        let keyMetric = "\(ride.averageHeartRate) avg bpm"

        let tip: String = {
            if rhythmScore >= 80 { return "Excellent consistency - steady effort throughout" }
            if rhythmScore >= 60 { return "Good rhythm - minor HR fluctuations" }
            return "Variable effort - focus on maintaining steady pace"
        }()

        return pillarCard(
            letter: "R",
            title: "Rhythm",
            subtitle: "Effort Consistency",
            score: rhythmScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "heart.fill",
            color: .purple
        )
    }

    private var effortCard: some View {
        let intensity = ride.maxHeartRate > 0 ? (Double(ride.averageHeartRate) / Double(ride.maxHeartRate)) * 100 : 0
        let keyMetric = "\(Int(intensity))% of max HR"

        let tip: String = {
            if intensity >= 65 && intensity <= 80 { return "Ideal training zone - building fitness" }
            if intensity > 85 { return "High intensity - allow recovery tomorrow" }
            if intensity < 55 { return "Light session - good for recovery days" }
            return "Moderate effort - consider pushing a bit more"
        }()

        return pillarCard(
            letter: "E",
            title: "Effort",
            subtitle: "Training Intensity",
            score: effortScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "flame.fill",
            color: .orange
        )
    }

    // MARK: - Watch Prompt Card

    private var watchPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Get More Insights")
                    .font(.headline)
            }

            Text("Wear Apple Watch while riding to unlock:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                watchBenefit(icon: "heart.fill", text: "Heart rate rhythm & effort zones")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func watchBenefit(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Pillar Card Template

    private func pillarCard(
        letter: String,
        title: String,
        subtitle: String,
        score: Double,
        keyMetric: String,
        tip: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(letter)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(score > 0 ? "\(Int(score))" : "-")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(score > 0 ? scoreColor(score) : .secondary)
            }

            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(keyMetric)
                    .font(.subheadline)
            }

            Text(tip)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Supporting Types

enum InsightSection: String, CaseIterable {
    case rhythm
    case effort
    case leadQuality
}

struct BalanceDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let duration: TimeInterval
}

// MARK: - Preview

#Preview("With Watch Data") {
    NavigationStack {
        RideInsightsView(ride: {
            let ride = Ride()
            ride.totalDuration = 3600
            ride.totalDistance = 8000
            ride.averageHeartRate = 135
            ride.maxHeartRate = 175
            return ride
        }())
    }
}

#Preview("GPS Only") {
    NavigationStack {
        RideInsightsView(ride: {
            let ride = Ride()
            ride.totalDuration = 3600
            ride.totalDistance = 8000
            return ride
        }())
    }
}
