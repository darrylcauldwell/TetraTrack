//
//  RideInsightsView.swift
//  TetraTrack
//
//  Ride insights using the GRACE framework.
//  Pillars: Grow (ride tall/smoothness), Rhythm (gait rhythm),
//  Align (balance), Circle (connection), Enjoy (effort).
//  Adapts to GPS-only or Watch-enhanced data.
//

import SwiftUI
import Charts

struct RideInsightsView: View {
    let ride: Ride

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Watch Detection

    private var hasWatchData: Bool {
        ride.averageHeartRate > 0
    }

    // MARK: - GRACE Scores

    /// G: Grow — ride tall, measured by speed smoothness (less jerkiness = better posture)
    private var growScore: Double {
        let points = ride.sortedLocationPoints
        guard points.count > 20 else { return 0 }

        let speeds = points.map { $0.speed }.filter { $0 > 0.5 }
        guard speeds.count > 10 else { return 0 }

        // Measure average absolute speed change between points
        var totalJerk: Double = 0
        for i in 1..<speeds.count {
            totalJerk += abs(speeds[i] - speeds[i - 1])
        }
        let avgJerk = totalJerk / Double(speeds.count - 1)

        // Lower jerk = smoother riding = higher score
        if avgJerk < 0.3 { return 95 }
        if avgJerk < 0.5 { return 85 }
        if avgJerk < 1.0 { return 70 }
        if avgJerk < 2.0 { return 55 }
        return 40
    }

    /// R: Rhythm — gait rhythm from HR consistency (Watch) or pace consistency (GPS)
    private var rhythmScore: Double {
        if hasWatchData {
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
        } else {
            return paceConsistencyScore
        }
    }

    /// A: Align — balance from speed zone transition smoothness
    private var alignScore: Double {
        let points = ride.sortedLocationPoints
        guard points.count > 10 else { return 0 }

        let speeds = points.compactMap { $0.speed > 0.5 ? $0.speed : nil }
        guard speeds.count > 5 else { return 0 }

        // Count zone transitions — fewer per point = more balanced riding
        var transitions = 0
        for i in 1..<speeds.count {
            let prevZone = speedZone(speeds[i - 1])
            let currZone = speedZone(speeds[i])
            if prevZone != currZone { transitions += 1 }
        }
        let transitionsPerPoint = Double(transitions) / Double(speeds.count)

        if transitionsPerPoint < 0.05 { return 90 }
        if transitionsPerPoint < 0.10 { return 80 }
        if transitionsPerPoint < 0.15 { return 70 }
        if transitionsPerPoint < 0.25 { return 55 }
        return 40
    }

    /// C: Circle — connection from pace consistency (GPS speed variability)
    private var circleScore: Double {
        paceConsistencyScore
    }

    /// E: Enjoy — effort from HR zones (Watch) or speed zone intensity (GPS)
    private var enjoyScore: Double {
        if hasWatchData {
            guard ride.averageHeartRate > 0, ride.maxHeartRate > 0 else { return 0 }
            let avgHR = Double(ride.averageHeartRate)
            let maxHR = Double(ride.maxHeartRate)
            let intensity = (avgHR / maxHR) * 100

            if intensity >= 65 && intensity <= 80 { return 85 }
            if intensity >= 55 && intensity < 65 { return 70 }
            if intensity > 80 && intensity <= 85 { return 75 }
            if intensity > 85 { return 60 }
            return 50
        } else {
            return intensityScore
        }
    }

    // MARK: - Underlying GPS Scores

    private var paceConsistencyScore: Double {
        let points = ride.sortedLocationPoints
        guard points.count > 10 else { return 0 }

        let speeds = points.map { $0.speed }.filter { $0 > 0.5 }
        guard speeds.count > 5 else { return 0 }

        let mean = speeds.reduce(0, +) / Double(speeds.count)
        guard mean > 0 else { return 0 }

        let variance = speeds.reduce(0) { $0 + pow($1 - mean, 2) } / Double(speeds.count)
        let cv = (sqrt(variance) / mean) * 100

        if cv < 15 { return 90 }
        if cv < 25 { return 75 }
        if cv < 35 { return 60 }
        if cv < 50 { return 45 }
        return 30
    }

    private var intensityScore: Double {
        let zones = computeSpeedZones()
        guard zones.total > 30 else { return 0 }

        let workingPct = zones.zone2Pct
        let fastPct = zones.zone3Pct

        if workingPct >= 50 && workingPct <= 80 { return 85 }
        if workingPct >= 30 && fastPct >= 10 { return 75 }
        if workingPct >= 20 { return 60 }
        return 45
    }

    private func speedZone(_ speed: Double) -> Int {
        if speed < 1.94 { return 0 }      // Easy/walk
        else if speed < 5.56 { return 1 }  // Working/trot
        else { return 2 }                  // Fast/canter
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("GRACE Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .presentationBackground(Color.black)
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 20) {
            overallGraceScore

            // Phase timeline (showjumping rides)
            if !ride.sortedPhases.isEmpty {
                PhaseTimelineCard(phases: ride.sortedPhases)
            }

            // Dressage test scoresheet
            if let execution = ride.dressageTestExecution {
                DressageTestScoresheetCard(execution: execution)
            }

            // Coaching notes
            if !ride.coachingNotes.isEmpty {
                CoachingNotesCard(notes: ride.coachingNotes, rideStartDate: ride.startDate)
            }

            intensityZonesCard
            ElevationProfileView(profile: ride.elevationProfile)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                growCard
                rhythmCard
                alignCard
                circleCard
            }

            enjoyCard

            if !hasWatchData {
                watchPromptCard
            }
        }
        .padding(24)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            overallGraceScore

            // Phase timeline (showjumping rides)
            if !ride.sortedPhases.isEmpty {
                PhaseTimelineCard(phases: ride.sortedPhases)
            }

            // Dressage test scoresheet
            if let execution = ride.dressageTestExecution {
                DressageTestScoresheetCard(execution: execution)
            }

            // Coaching notes
            if !ride.coachingNotes.isEmpty {
                CoachingNotesCard(notes: ride.coachingNotes, rideStartDate: ride.startDate)
            }

            intensityZonesCard
            ElevationProfileView(profile: ride.elevationProfile)
            growCard
            rhythmCard
            alignCard
            circleCard
            enjoyCard

            if !hasWatchData {
                watchPromptCard
            }
        }
        .padding()
    }

    // MARK: - Overall Score

    private var overallGraceScore: some View {
        let scores = [growScore, rhythmScore, alignScore, circleScore, enjoyScore].filter { $0 > 0 }
        let overall = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        return VStack(spacing: 8) {
            Text("GRACE Score")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(Int(overall))")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor(overall))

            HStack(spacing: 16) {
                pillarMini("G", score: growScore)
                pillarMini("R", score: rhythmScore)
                pillarMini("A", score: alignScore)
                pillarMini("C", score: circleScore)
                pillarMini("E", score: enjoyScore)
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

    // MARK: - G: Grow Card

    private var growCard: some View {
        let hasData = growScore > 0

        let keyMetric: String = {
            if hasData { return "\(Int(growScore))% smooth" }
            return "Needs GPS data"
        }()

        let tip: String = {
            if !hasData { return "GPS tracks speed smoothness throughout ride" }
            if growScore >= 80 { return "Very smooth riding — excellent posture and seat" }
            if growScore >= 60 { return "Good smoothness — minor speed fluctuations" }
            return "Jerky transitions — focus on smooth gait changes and steady seat"
        }()

        return pillarCard(
            letter: "G",
            title: "Grow",
            subtitle: "Ride Tall",
            score: growScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.up.circle.fill",
            color: .green
        )
    }

    // MARK: - R: Rhythm Card

    private var rhythmCard: some View {
        let keyMetric: String = {
            if hasWatchData {
                return "\(ride.averageHeartRate) avg bpm"
            }
            if rhythmScore > 0 { return "\(Int(rhythmScore))% consistent" }
            return "Needs GPS data"
        }()

        let tip: String = {
            if rhythmScore >= 80 { return "Excellent consistency — steady effort throughout" }
            if rhythmScore >= 60 { return "Good rhythm — minor fluctuations" }
            if rhythmScore > 0 { return "Variable effort — focus on maintaining steady pace" }
            return "GPS tracks rhythm through pace consistency"
        }()

        return pillarCard(
            letter: "R",
            title: "Rhythm",
            subtitle: "Gait Rhythm",
            score: rhythmScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "metronome.fill",
            color: .indigo
        )
    }

    // MARK: - A: Align Card

    private var alignCard: some View {
        let hasData = alignScore > 0

        let keyMetric: String = {
            if hasData { return "\(Int(alignScore))% balanced" }
            return "Needs GPS data"
        }()

        let tip: String = {
            if !hasData { return "GPS measures balance through gait transition smoothness" }
            if alignScore >= 80 { return "Excellent balance — smooth transitions between gaits" }
            if alignScore >= 60 { return "Good balance — some abrupt speed changes" }
            return "Frequent zone changes — work on gradual gait transitions"
        }()

        return pillarCard(
            letter: "A",
            title: "Align",
            subtitle: "Balance",
            score: alignScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "figure.equestrian.sports",
            color: .orange
        )
    }

    // MARK: - C: Circle Card

    private var circleCard: some View {
        let hasData = circleScore > 0

        let keyMetric: String = {
            if hasData { return "\(Int(circleScore))% connected" }
            return "Needs GPS data"
        }()

        let tip: String = {
            if !hasData { return "GPS tracks overall pace consistency" }
            if circleScore >= 80 { return "Very steady pace — great connection with your horse" }
            if circleScore >= 60 { return "Reasonably consistent — some pace changes" }
            return "Variable pace — work on maintaining steady speed"
        }()

        return pillarCard(
            letter: "C",
            title: "Circle",
            subtitle: "Connection",
            score: circleScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "arrow.triangle.2.circlepath",
            color: .purple
        )
    }

    // MARK: - E: Enjoy Card

    private var enjoyCard: some View {
        let keyMetric: String = {
            if hasWatchData {
                let intensity = ride.maxHeartRate > 0 ? (Double(ride.averageHeartRate) / Double(ride.maxHeartRate)) * 100 : 0
                return "\(Int(intensity))% of max HR"
            }
            if enjoyScore > 0 { return "\(Int(enjoyScore))% intensity" }
            return "Needs data"
        }()

        let tip: String = {
            if hasWatchData {
                let intensity = ride.maxHeartRate > 0 ? (Double(ride.averageHeartRate) / Double(ride.maxHeartRate)) * 100 : 0
                if intensity >= 65 && intensity <= 80 { return "Ideal training zone — building fitness" }
                if intensity > 85 { return "High intensity — allow recovery tomorrow" }
                if intensity < 55 { return "Light session — good for recovery days" }
                return "Moderate effort — consider pushing a bit more"
            }
            if enjoyScore >= 80 { return "Good training intensity — well-balanced zones" }
            if enjoyScore >= 60 { return "Moderate intensity — consider more working trot" }
            return "Mostly easy pace — push into working zones for training effect"
        }()

        return pillarCard(
            letter: "E",
            title: "Enjoy",
            subtitle: "Effort",
            score: enjoyScore,
            keyMetric: keyMetric,
            tip: tip,
            icon: "heart.fill",
            color: .red
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
