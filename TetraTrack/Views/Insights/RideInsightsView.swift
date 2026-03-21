//
//  RideInsightsView.swift
//  TetraTrack
//
//  Ride insights using biomechanical pillars.
//  Pillars: Stability (speed smoothness), Rhythm (HR/pace consistency),
//  Symmetry (zone transition smoothness), Economy (pace consistency).
//  Physiology section covers HR intensity zones.
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

    // MARK: - Biomechanical Scores

    /// Stability — speed smoothness (less jerkiness = better posture)
    private var stabilityScore: Double {
        let points = ride.sortedLocationPoints
        guard points.count > 20 else { return 0 }

        let speeds = points.map { $0.speed }.filter { $0 > 0.5 }
        guard speeds.count > 10 else { return 0 }

        var totalJerk: Double = 0
        for i in 1..<speeds.count {
            totalJerk += abs(speeds[i] - speeds[i - 1])
        }
        let avgJerk = totalJerk / Double(speeds.count - 1)

        if avgJerk < 0.3 { return 95 }
        if avgJerk < 0.5 { return 85 }
        if avgJerk < 1.0 { return 70 }
        if avgJerk < 2.0 { return 55 }
        return 40
    }

    /// Rhythm — HR consistency (Watch) or pace consistency (GPS)
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

    /// Symmetry — balance from speed zone transition smoothness
    private var symmetryScore: Double {
        let points = ride.sortedLocationPoints
        guard points.count > 10 else { return 0 }

        let speeds = points.compactMap { $0.speed > 0.5 ? $0.speed : nil }
        guard speeds.count > 5 else { return 0 }

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

    /// Economy — pace consistency (GPS speed variability)
    private var economyScore: Double {
        paceConsistencyScore
    }

    /// Physiology — effort from HR zones (Watch) or speed zone intensity (GPS)
    private var physiologyScore: Double {
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
        if speed < 1.94 { return 0 }
        else if speed < 5.56 { return 1 }
        else { return 2 }
    }

    // MARK: - Symmetry Drift Data (#18)

    private var symmetryDriftData: (start: Double, mid: Double, end: Double)? {
        let segments = ride.sortedGaitSegments
        guard segments.count >= 3 else { return nil }

        // Divide segments into thirds by time
        let totalDuration = segments.reduce(0) { $0 + $1.duration }
        guard totalDuration > 30 else { return nil }

        let thirdDuration = totalDuration / 3.0
        var cumulative: TimeInterval = 0
        var startCoherences: [Double] = []
        var midCoherences: [Double] = []
        var endCoherences: [Double] = []

        for segment in segments {
            let coherence = segment.verticalYawCoherence
            guard coherence > 0 else {
                cumulative += segment.duration
                continue
            }

            if cumulative < thirdDuration {
                startCoherences.append(coherence)
            } else if cumulative < thirdDuration * 2 {
                midCoherences.append(coherence)
            } else {
                endCoherences.append(coherence)
            }
            cumulative += segment.duration
        }

        guard !startCoherences.isEmpty, !endCoherences.isEmpty else { return nil }

        let start = (startCoherences.reduce(0, +) / Double(startCoherences.count)) * 100
        let mid = midCoherences.isEmpty ? (start) : (midCoherences.reduce(0, +) / Double(midCoherences.count)) * 100
        let end = (endCoherences.reduce(0, +) / Double(endCoherences.count)) * 100

        return (start: start, mid: mid, end: end)
    }

    // MARK: - Per-Rein by Gait Data (#20)

    private var reinByGaitData: [(gait: String, leftRhythm: Double, rightRhythm: Double, leftSymmetry: Double, rightSymmetry: Double)] {
        let gaitSegments = ride.sortedGaitSegments
        let reinSegments = ride.sortedReinSegments
        guard !gaitSegments.isEmpty, !reinSegments.isEmpty else { return [] }

        var results: [(gait: String, leftRhythm: Double, rightRhythm: Double, leftSymmetry: Double, rightSymmetry: Double)] = []

        for gait in [GaitType.walk, .trot, .canter] {
            let gaitSegs = gaitSegments.filter { $0.gait == gait }
            guard !gaitSegs.isEmpty else { continue }

            var leftRhythms: [Double] = []
            var rightRhythms: [Double] = []
            var leftSymmetries: [Double] = []
            var rightSymmetries: [Double] = []

            for reinSeg in reinSegments {
                guard let reinEnd = reinSeg.endTime else { continue }
                // Check overlap with gait segments
                for gaitSeg in gaitSegs {
                    guard let gaitEnd = gaitSeg.endTime else { continue }
                    let overlapStart = max(reinSeg.startTime, gaitSeg.startTime)
                    let overlapEnd = min(reinEnd, gaitEnd)
                    guard overlapEnd > overlapStart else { continue }

                    if reinSeg.reinDirection == .left {
                        if gaitSeg.rhythmScore > 0 { leftRhythms.append(gaitSeg.rhythmScore) }
                        if gaitSeg.verticalYawCoherence > 0 { leftSymmetries.append(gaitSeg.verticalYawCoherence * 100) }
                    } else if reinSeg.reinDirection == .right {
                        if gaitSeg.rhythmScore > 0 { rightRhythms.append(gaitSeg.rhythmScore) }
                        if gaitSeg.verticalYawCoherence > 0 { rightSymmetries.append(gaitSeg.verticalYawCoherence * 100) }
                    }
                }
            }

            guard !leftRhythms.isEmpty || !rightRhythms.isEmpty else { continue }

            let avgLR = leftRhythms.isEmpty ? 0 : leftRhythms.reduce(0, +) / Double(leftRhythms.count)
            let avgRR = rightRhythms.isEmpty ? 0 : rightRhythms.reduce(0, +) / Double(rightRhythms.count)
            let avgLS = leftSymmetries.isEmpty ? 0 : leftSymmetries.reduce(0, +) / Double(leftSymmetries.count)
            let avgRS = rightSymmetries.isEmpty ? 0 : rightSymmetries.reduce(0, +) / Double(rightSymmetries.count)

            results.append((gait: gait.rawValue.capitalized, leftRhythm: avgLR, rightRhythm: avgRR, leftSymmetry: avgLS, rightSymmetry: avgRS))
        }

        return results
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("Session Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .sheetBackground()
    }

    // MARK: - iPad Layout

    private var iPadContent: some View {
        VStack(spacing: 20) {
            OverallBiomechanicalScore(
                stabilityScore: stabilityScore,
                rhythmScore: rhythmScore,
                symmetryScore: symmetryScore,
                economyScore: economyScore
            )

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
                stabilityCard
                rhythmCard
                symmetryCard
                economyCard
            }

            // Analytics: Symmetry drift over ride duration (#18)
            if let driftData = symmetryDriftData {
                SymmetryDriftChart(
                    startSymmetry: driftData.start,
                    midSymmetry: driftData.mid,
                    endSymmetry: driftData.end
                )
                .glassCard()
            }

            // Analytics: Per-rein metrics by gait type (#20)
            if !reinByGaitData.isEmpty {
                ReinByGaitBreakdownCard(reinGaitData: reinByGaitData)
                    .glassCard()
            }

            physiologyCard

            if !hasWatchData {
                watchPromptCard
            }
        }
        .padding(24)
    }

    // MARK: - iPhone Layout

    private var iPhoneContent: some View {
        VStack(spacing: 16) {
            OverallBiomechanicalScore(
                stabilityScore: stabilityScore,
                rhythmScore: rhythmScore,
                symmetryScore: symmetryScore,
                economyScore: economyScore
            )

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
            stabilityCard
            rhythmCard
            symmetryCard
            economyCard

            // Analytics: Symmetry drift over ride duration (#18)
            if let driftData = symmetryDriftData {
                SymmetryDriftChart(
                    startSymmetry: driftData.start,
                    midSymmetry: driftData.mid,
                    endSymmetry: driftData.end
                )
                .glassCard()
            }

            // Analytics: Per-rein metrics by gait type (#20)
            if !reinByGaitData.isEmpty {
                ReinByGaitBreakdownCard(reinGaitData: reinByGaitData)
                    .glassCard()
            }

            physiologyCard

            if !hasWatchData {
                watchPromptCard
            }
        }
        .padding()
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

    // MARK: - Stability Card

    private var stabilityCard: some View {
        let hasData = stabilityScore > 0

        return PillarScoreCard(
            pillar: .stability,
            subtitle: "Speed Smoothness",
            score: stabilityScore,
            keyMetric: hasData ? "\(Int(stabilityScore))% smooth" : "Needs GPS data",
            tip: {
                if !hasData { return "GPS tracks speed smoothness throughout ride" }
                if stabilityScore >= 80 { return "Very smooth riding — excellent posture and seat" }
                if stabilityScore >= 60 { return "Good smoothness — minor speed fluctuations" }
                return "Jerky transitions — focus on smooth gait changes and steady seat"
            }()
        )
    }

    // MARK: - Rhythm Card

    private var rhythmCard: some View {
        PillarScoreCard(
            pillar: .rhythm,
            subtitle: "Gait Rhythm",
            score: rhythmScore,
            keyMetric: {
                if hasWatchData { return "\(ride.averageHeartRate) avg bpm" }
                if rhythmScore > 0 { return "\(Int(rhythmScore))% consistent" }
                return "Needs GPS data"
            }(),
            tip: {
                if rhythmScore >= 80 { return "Excellent consistency — steady effort throughout" }
                if rhythmScore >= 60 { return "Good rhythm — minor fluctuations" }
                if rhythmScore > 0 { return "Variable effort — focus on maintaining steady pace" }
                return "GPS tracks rhythm through pace consistency"
            }()
        )
    }

    // MARK: - Symmetry Card

    private var symmetryCard: some View {
        let hasData = symmetryScore > 0

        return PillarScoreCard(
            pillar: .symmetry,
            subtitle: "Gait Balance",
            score: symmetryScore,
            keyMetric: hasData ? "\(Int(symmetryScore))% balanced" : "Needs GPS data",
            tip: {
                if !hasData { return "GPS measures balance through gait transition smoothness" }
                if symmetryScore >= 80 { return "Excellent balance — smooth transitions between gaits" }
                if symmetryScore >= 60 { return "Good balance — some abrupt speed changes" }
                return "Frequent zone changes — work on gradual gait transitions"
            }()
        )
    }

    // MARK: - Economy Card

    private var economyCard: some View {
        let hasData = economyScore > 0

        return PillarScoreCard(
            pillar: .economy,
            subtitle: "Pace Consistency",
            score: economyScore,
            keyMetric: hasData ? "\(Int(economyScore))% connected" : "Needs GPS data",
            tip: {
                if !hasData { return "GPS tracks overall pace consistency" }
                if economyScore >= 80 { return "Very steady pace — great connection with your horse" }
                if economyScore >= 60 { return "Reasonably consistent — some pace changes" }
                return "Variable pace — work on maintaining steady speed"
            }()
        )
    }

    // MARK: - Physiology Card

    private var physiologyCard: some View {
        PhysiologySectionCard(
            score: physiologyScore,
            keyMetric: {
                if hasWatchData {
                    let intensity = ride.maxHeartRate > 0 ? (Double(ride.averageHeartRate) / Double(ride.maxHeartRate)) * 100 : 0
                    return "\(Int(intensity))% of max HR"
                }
                if physiologyScore > 0 { return "\(Int(physiologyScore))% intensity" }
                return "Needs data"
            }(),
            tip: {
                if hasWatchData {
                    let intensity = ride.maxHeartRate > 0 ? (Double(ride.averageHeartRate) / Double(ride.maxHeartRate)) * 100 : 0
                    if intensity >= 65 && intensity <= 80 { return "Ideal training zone — building fitness" }
                    if intensity > 85 { return "High intensity — allow recovery tomorrow" }
                    if intensity < 55 { return "Light session — good for recovery days" }
                    return "Moderate effort — consider pushing a bit more"
                }
                if physiologyScore >= 80 { return "Good training intensity — well-balanced zones" }
                if physiologyScore >= 60 { return "Moderate intensity — consider more working trot" }
                return "Mostly easy pace — push into working zones for training effect"
            }(),
            subtitle: "HR Intensity"
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
