//
//  EnrichedWorkoutDetailView.swift
//  TetraTrack
//
//  Rich detail view for HealthKit workouts showing route map, HR chart,
//  pace splits, walking metrics, elevation, and photos taken during the workout.
//

import SwiftUI
import MapKit
import Charts
import HealthKit
import Photos
import CoreLocation

struct EnrichedWorkoutDetailView: View {
    let workout: ExternalWorkout
    var prebuiltEnrichment: WorkoutEnrichment?

    @State private var enrichment: WorkoutEnrichment?
    @State private var insights: [WorkoutInsight] = []
    @State private var domainScores: [SkillDomainScore] = []
    @State private var pillarCards: [PillarCardData] = []
    @State private var photos: [PHAsset] = []
    @State private var isLoading = true

    private let skillDomainService = SkillDomainService()

    private let photoService = RidePhotoService.shared
    @State private var selectedTab: DetailTab = .session

    enum DetailTab: String, CaseIterable {
        case session = "Session"
        case insights = "Insights"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 20) {
                    if selectedTab == .session {
                        sessionTabContent
                    } else {
                        insightsTabContent
                    }
                }
                .padding()
            }
        }
        .navigationTitle(workout.activityName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    // MARK: - Session Tab

    private var sessionTabContent: some View {
        VStack(spacing: 20) {
            headerSection
            summaryStats

            if isLoading {
                ProgressView("Loading workout data...")
                    .padding(.vertical, 32)
            } else {
                    if let enrichment {
                        if !enrichment.routeLocations.isEmpty {
                            routeMapSection(enrichment.routeLocations)
                        }

                        if !enrichment.heartRateSamples.isEmpty {
                            heartRateChartSection(enrichment.heartRateSamples)
                        }

                        if !enrichment.splits.isEmpty {
                            splitsSection(enrichment.splits)
                        }

                        if let metrics = enrichment.walkingMetrics {
                            walkingMetricsSection(metrics)
                        }

                        if let metrics = enrichment.runningMetrics {
                            runningMetricsSection(metrics)
                        }

                        if let metrics = enrichment.swimmingMetrics {
                            swimmingMetricsSection(metrics)

                            if !metrics.laps.isEmpty {
                                swimmingLapBreakdown(metrics.laps)
                            }

                            if metrics.averageSpO2 != nil || metrics.averageBreathingRate != nil {
                                swimmingPhysiologySection(metrics)
                            }
                        }

                        if let metrics = enrichment.cyclingMetrics {
                            cyclingMetricsSection(metrics)
                        }

                        // HR zones — shown for all workout types with HR data
                        if !enrichment.heartRateSamples.isEmpty {
                            heartRateZoneSummary(enrichment.heartRateSamples)
                        }

                        // HR summary (min/avg/max) for all types
                        if let general = enrichment.generalMetrics {
                            heartRateZoneSummaryStats(general)
                        }

                        if let gain = enrichment.elevationGain, gain > 0 {
                            elevationSection(gain: gain, loss: enrichment.elevationLoss ?? 0)
                        }
                    }

                    if !photos.isEmpty {
                        photosSection
                    }

                    sourceSection
                }
            }
        }

    private var insightsTabContent: some View {
        VStack(spacing: 20) {
            if !pillarCards.isEmpty {
                pillarCardsSection
            }

            if !insights.isEmpty {
                insightsSection
            }

            if pillarCards.isEmpty && insights.isEmpty {
                if isLoading {
                    ProgressView("Loading insights...")
                        .padding(.vertical, 32)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No insights available")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Insights are generated from workout metrics like heart rate, cadence, and pace.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: workout.activityIcon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text(workout.activityName)
                .font(.title2.bold())

            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Duration", value: workout.formattedDuration, icon: "clock")

            if let distance = workout.formattedDistance {
                statCard(title: "Distance", value: distance, icon: "ruler")
            }

            if let calories = workout.formattedCalories {
                statCard(title: "Calories", value: calories, icon: "flame.fill")
            }

            if let hr = workout.averageHeartRate {
                statCard(title: "Avg HR", value: "\(Int(hr)) bpm", icon: "heart.fill")
            }

            if let pace = averagePace {
                statCard(title: "Avg Pace", value: pace, icon: "speedometer")
            }
        }
    }

    // MARK: - Route Map

    private func routeMapSection(_ locations: [CLLocation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.headline)

            let coords = locations.map(\.coordinate)
            Map {
                MapPolyline(coordinates: coords)
                    .stroke(.blue, lineWidth: 3)
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Heart Rate Chart

    private func heartRateChartSection(_ samples: [WorkoutEnrichment.HeartRateSamplePoint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate")
                .font(.headline)

            let minHR = samples.map(\.bpm).min() ?? 0
            let maxHR = samples.map(\.bpm).max() ?? 0

            HStack {
                Label("\(Int(minHR))", systemImage: "heart")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(Int(maxHR)) max", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Chart(samples, id: \.date) { sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(.red.opacity(0.2))

                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartYScale(domain: max(0, minHR - 10)...(maxHR + 10))
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .frame(height: 180)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // HR Zone Distribution
            let zones = heartRateZones(from: samples)
            if zones.values.contains(where: { $0 > 0 }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time in Zones")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(zones.sorted(by: { $0.key < $1.key }), id: \.key) { zone, percentage in
                        HStack(spacing: 8) {
                            Text("Z\(zone)")
                                .font(.caption.bold().monospacedDigit())
                                .frame(width: 24)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(zoneColor(zone))
                                    .frame(width: geo.size.width * percentage / 100)
                            }
                            .frame(height: 14)

                            Text(String(format: "%.0f%%", percentage))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func heartRateZones(from samples: [WorkoutEnrichment.HeartRateSamplePoint]) -> [Int: Double] {
        // Standard 5-zone model based on max HR estimate (220-age fallback: use max observed)
        let maxObserved = samples.map(\.bpm).max() ?? 190
        let estimatedMax = max(maxObserved, 180) // Use at least 180 as floor

        var zoneCounts: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        for sample in samples {
            let pct = sample.bpm / estimatedMax * 100
            switch pct {
            case ..<60: zoneCounts[1, default: 0] += 1
            case 60..<70: zoneCounts[2, default: 0] += 1
            case 70..<80: zoneCounts[3, default: 0] += 1
            case 80..<90: zoneCounts[4, default: 0] += 1
            default: zoneCounts[5, default: 0] += 1
            }
        }

        let total = Double(samples.count)
        guard total > 0 else { return [:] }
        return zoneCounts.mapValues { Double($0) / total * 100 }
    }

    private func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: .gray
        case 2: .blue
        case 3: .green
        case 4: .orange
        case 5: .red
        default: .gray
        }
    }

    // MARK: - Pace Splits

    private func splitsSection(_ splits: [WorkoutEnrichment.PaceSplit]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Splits")
                .font(.headline)

            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("KM")
                        .font(.caption.bold())
                        .frame(width: 40, alignment: .leading)
                    Text("Pace")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Time")
                        .font(.caption.bold())
                        .frame(width: 70, alignment: .trailing)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 6)

                Divider()

                ForEach(splits) { split in
                    HStack {
                        Text(split.distance >= 1000 ? "\(split.id)" : String(format: "%.1fkm", split.distance / 1000))
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 40, alignment: .leading)

                        Text(formatPace(split.pace))
                            .font(.subheadline.bold().monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(formatSplitDuration(split.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if split.id != splits.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Walking Metrics

    private func walkingMetricsSection(_ metrics: WorkoutEnrichment.WalkingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Walking Metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let cadence = metrics.averageCadence {
                    metricCard(title: "Cadence", value: String(format: "%.0f spm", cadence), icon: "metronome")
                }

                if let speed = metrics.averageSpeed {
                    let kmh = speed * 3.6
                    metricCard(title: "Speed", value: String(format: "%.1f km/h", kmh), icon: "gauge.with.needle")
                }

                if let stepLength = metrics.averageStepLength {
                    let cm = stepLength * 100
                    metricCard(title: "Step Length", value: String(format: "%.0f cm", cm), icon: "ruler")
                }

                if let asymmetry = metrics.asymmetryPercent {
                    metricCard(title: "Asymmetry", value: String(format: "%.1f%%", asymmetry), icon: "arrow.left.arrow.right")
                }

                if let doubleSupport = metrics.doubleSupportPercent {
                    metricCard(title: "Double Support", value: String(format: "%.1f%%", doubleSupport), icon: "figure.stand")
                }

                if let steadiness = metrics.steadiness {
                    metricCard(title: "Steadiness", value: String(format: "%.0f%%", steadiness), icon: "waveform.path")
                }
            }
        }
    }

    // MARK: - Running Metrics

    private func runningMetricsSection(_ metrics: WorkoutEnrichment.RunningMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Running Metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let cadence = metrics.averageCadence {
                    metricCard(title: "Cadence", value: String(format: "%.0f spm", cadence), icon: "metronome")
                }

                if let stride = metrics.averageStrideLength {
                    let cm = stride * 100
                    metricCard(title: "Stride Length", value: String(format: "%.0f cm", cm), icon: "ruler")
                }

                if let gct = metrics.averageGroundContactTime {
                    metricCard(title: "Ground Contact", value: String(format: "%.0f ms", gct), icon: "arrow.down.to.line")
                }

                if let vo = metrics.averageVerticalOscillation {
                    metricCard(title: "Vert. Oscillation", value: String(format: "%.1f cm", vo), icon: "arrow.up.arrow.down")
                }

                if let power = metrics.averagePower {
                    metricCard(title: "Power", value: String(format: "%.0f W", power), icon: "bolt.fill")
                }

                if let speed = metrics.averageSpeed {
                    let pacePerKm = 1000 / speed
                    metricCard(title: "Avg Pace", value: formatPace(pacePerKm), icon: "speedometer")
                }
            }
        }
    }

    // MARK: - Swimming Metrics

    private func swimmingMetricsSection(_ metrics: WorkoutEnrichment.SwimmingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Swimming Metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let laps = metrics.lapCount {
                    metricCard(title: "Laps", value: "\(laps)", icon: "arrow.triangle.2.circlepath")
                }

                if let poolLength = metrics.poolLength {
                    metricCard(title: "Pool Length", value: String(format: "%.0f m", poolLength), icon: "water.waves")
                }

                if let strokes = metrics.totalStrokeCount {
                    metricCard(title: "Total Strokes", value: String(format: "%.0f", strokes), icon: "figure.pool.swim")
                }

                if let swolf = metrics.averageSWOLF {
                    metricCard(title: "SWOLF", value: String(format: "%.0f", swolf), icon: "gauge.with.needle")
                }
            }
        }
    }

    // MARK: - Swimming Lap Breakdown

    private func swimmingLapBreakdown(_ laps: [WorkoutEnrichment.SwimLap]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lap Breakdown")
                .font(.headline)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Lap")
                        .font(.caption.bold())
                        .frame(width: 32, alignment: .leading)
                    Text("Time")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Strokes")
                        .font(.caption.bold())
                        .frame(width: 55, alignment: .center)
                    Text("SWOLF")
                        .font(.caption.bold())
                        .frame(width: 50, alignment: .trailing)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 6)

                Divider()

                ForEach(laps) { lap in
                    HStack {
                        Text("\(lap.id)")
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 32, alignment: .leading)

                        Text(formatSplitDuration(lap.duration))
                            .font(.subheadline.bold().monospacedDigit())
                            .frame(maxWidth: .infinity, alignment: .center)

                        Text(lap.strokeCount.map { "\($0)" } ?? "-")
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 55, alignment: .center)

                        Text(lap.swolf.map { String(format: "%.0f", $0) } ?? "-")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                    if lap.id != laps.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Swimming Physiology

    private func swimmingPhysiologySection(_ metrics: WorkoutEnrichment.SwimmingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Physiology")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let spo2 = metrics.averageSpO2 {
                    metricCard(title: "SpO2", value: String(format: "%.0f%%", spo2), icon: "lungs.fill")
                }

                if let breathing = metrics.averageBreathingRate {
                    metricCard(title: "Breathing", value: String(format: "%.0f bpm", breathing), icon: "wind")
                }
            }
        }
    }

    // MARK: - Cycling Metrics

    private func cyclingMetricsSection(_ metrics: WorkoutEnrichment.CyclingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cycling Metrics")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let cadence = metrics.averageCadence {
                    metricCard(title: "Cadence", value: String(format: "%.0f rpm", cadence), icon: "metronome")
                }

                if let power = metrics.averagePower {
                    metricCard(title: "Power", value: String(format: "%.0f W", power), icon: "bolt.fill")
                }

                if let speed = metrics.averageSpeed {
                    let kmh = speed * 3.6
                    metricCard(title: "Avg Speed", value: String(format: "%.1f km/h", kmh), icon: "speedometer")
                }
            }
        }
    }

    // MARK: - Heart Rate Zone Summary (for generic workouts)

    private func heartRateZoneSummary(_ samples: [WorkoutEnrichment.HeartRateSamplePoint]) -> some View {
        let zones = heartRateZones(from: samples)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Time in Zones")
                .font(.headline)

            ForEach(zones.sorted(by: { $0.key < $1.key }), id: \.key) { zone, percentage in
                if percentage > 0 {
                    HStack(spacing: 8) {
                        Text("Z\(zone)")
                            .font(.caption.bold().monospacedDigit())
                            .frame(width: 24)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(zoneColor(zone))
                                .frame(width: geo.size.width * percentage / 100)
                        }
                        .frame(height: 14)

                        Text(String(format: "%.0f%%", percentage))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func heartRateZoneSummaryStats(_ metrics: WorkoutEnrichment.GeneralMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let min = metrics.minHeartRate {
                    metricCard(title: "Min", value: "\(Int(min)) bpm", icon: "heart")
                }

                if let avg = metrics.averageHeartRate {
                    metricCard(title: "Average", value: "\(Int(avg)) bpm", icon: "heart.fill")
                }

                if let max = metrics.maxHeartRate {
                    metricCard(title: "Max", value: "\(Int(max)) bpm", icon: "heart.bolt.fill")
                }
            }
        }
    }

    // MARK: - Elevation

    private func elevationSection(gain: Double, loss: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Elevation")
                .font(.headline)

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(.green)
                    Text(String(format: "%.0f m", gain))
                        .font(.subheadline.bold().monospacedDigit())
                    Text("gain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.right")
                        .foregroundStyle(.red)
                    Text(String(format: "%.0f m", loss))
                        .font(.subheadline.bold().monospacedDigit())
                    Text("loss")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Photos

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photos (\(photos.count))")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(photos, id: \.localIdentifier) { asset in
                        PhotoThumbnailView(asset: asset)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 1) // Prevent clipping
            }
        }
    }

    // MARK: - Biomechanical Pillar Cards

    struct PillarCardData: Identifiable {
        let id = UUID()
        let pillar: BiomechanicalPillar
        let subtitle: String
        let score: Double
        let keyMetric: String
        let tip: String
    }

    private var pillarCardsSection: some View {
        VStack(spacing: 16) {
            // Overall score header
            let scores = pillarCards.map(\.score).filter { $0 > 0 }
            if !scores.isEmpty {
                OverallBiomechanicalScore(
                    stabilityScore: pillarCards.first(where: { $0.pillar == .stability })?.score ?? 0,
                    rhythmScore: pillarCards.first(where: { $0.pillar == .rhythm })?.score ?? 0,
                    symmetryScore: pillarCards.first(where: { $0.pillar == .symmetry })?.score ?? 0,
                    economyScore: pillarCards.first(where: { $0.pillar == .economy })?.score ?? 0
                )
            }

            // Individual pillar cards
            ForEach(pillarCards) { card in
                PillarScoreCard(
                    pillar: card.pillar,
                    subtitle: card.subtitle,
                    score: card.score,
                    keyMetric: card.keyMetric,
                    tip: card.tip
                )
            }

            // Physiology card (always shown — score may be 0 if no HR data)
            PhysiologySectionCard(
                score: pillarPhysiologyScore,
                keyMetric: pillarPhysiologyMetric,
                tip: pillarPhysiologyTip
            )
        }
    }

    // MARK: - Pillar Card Computation

    private func computePillarCards() -> [PillarCardData] {
        switch workout.activityType {
        case .running, .hiking:
            return computeRunningPillarCards()
        case .walking:
            return computeWalkingPillarCards()
        case .swimming:
            return computeSwimmingPillarCards()
        case .cycling:
            return computeCyclingPillarCards()
        default:
            return computeGeneralPillarCards()
        }
    }

    private func computeRunningPillarCards() -> [PillarCardData] {
        let rm = enrichment?.runningMetrics
        var cards: [PillarCardData] = []

        // Stability — vertical oscillation
        let vo = rm?.averageVerticalOscillation ?? 0
        let stabilityScore = vo > 0 ? Swift.max(0, Swift.min(100, (12 - vo) / 4 * 100)) : 0
        cards.append(PillarCardData(
            pillar: .stability,
            subtitle: "Posture & Oscillation",
            score: stabilityScore,
            keyMetric: vo > 0 ? String(format: "%.1f cm bounce", vo) : "Needs Apple Watch",
            tip: vo > 10 ? "Focus on running tall — imagine a string pulling you up"
                : vo > 8 ? "Good height, try engaging core more"
                : vo > 0 ? "Maintain your tall posture"
                : "Run with Apple Watch to measure vertical oscillation"
        ))

        // Rhythm — cadence
        let cadence = rm?.averageCadence ?? 0
        let rhythmScore = cadence > 0 ? Swift.max(0, 100 - abs(cadence - 180) / 180 * 200) : 0
        cards.append(PillarCardData(
            pillar: .rhythm,
            subtitle: "Cadence & Tempo",
            score: rhythmScore,
            keyMetric: cadence > 0 ? String(format: "%.0f spm", cadence) : "Needs motion data",
            tip: cadence > 0 && cadence < 170 ? "Aim for quicker, lighter steps (170-180 spm)"
                : cadence > 190 ? "Cadence is high — ensure you're not overstriding"
                : cadence > 0 ? "Maintain your light, quick rhythm"
                : "Carry phone or wear Apple Watch to track cadence"
        ))

        // Symmetry — GCT
        let gct = rm?.averageGroundContactTime ?? 0
        let symmetryScore = gct > 0 ? Swift.max(0, Swift.min(100, (300 - gct) / 100 * 100)) : 0
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Stride & Balance",
            score: symmetryScore,
            keyMetric: gct > 0 ? String(format: "%.0f ms contact", gct) : "Needs Apple Watch",
            tip: gct > 300 ? "Spend less time on ground — think 'hot coals'"
                : gct > 250 ? "Good contact time, keep feet moving"
                : gct > 0 ? "Good alignment — maintain forward lean"
                : "Apple Watch measures ground contact time"
        ))

        // Economy — composite from splits
        let economyScore = computeSplitConsistencyScore()
        cards.append(PillarCardData(
            pillar: .economy,
            subtitle: "Running Economy",
            score: economyScore,
            keyMetric: economyScore > 0 ? "\(Int(economyScore))% economy" : "Building baseline",
            tip: economyScore < 50 ? "Focus on relaxed shoulders, bent elbows, smooth arm swing"
                : economyScore < 70 ? "Good flow — keep movements compact and circular"
                : economyScore > 0 ? "Smooth running — maintain efficiency"
                : "Economy score builds from cadence, GCT, and oscillation data"
        ))

        return cards
    }

    private func computeWalkingPillarCards() -> [PillarCardData] {
        let wm = enrichment?.walkingMetrics
        var cards: [PillarCardData] = []

        // Stability — steadiness
        let steadiness = wm?.steadiness ?? 0
        cards.append(PillarCardData(
            pillar: .stability,
            subtitle: "Walking Steadiness",
            score: steadiness,
            keyMetric: steadiness > 0 ? String(format: "%.0f%% steady", steadiness) : "Needs Apple Watch",
            tip: steadiness > 80 ? "Excellent steadiness — your balance is strong"
                : steadiness > 60 ? "Good balance, try uneven terrain to challenge it"
                : steadiness > 0 ? "Steadiness below average — consider fatigue or terrain"
                : "Apple Watch measures walking steadiness automatically"
        ))

        // Rhythm — cadence
        let cadence = wm?.averageCadence ?? 0
        let rhythmScore = cadence > 0 ? Swift.min(100, cadence / 1.3) : 0
        cards.append(PillarCardData(
            pillar: .rhythm,
            subtitle: "Step Cadence",
            score: rhythmScore,
            keyMetric: cadence > 0 ? String(format: "%.0f spm", cadence) : "Needs motion data",
            tip: cadence > 120 ? "Brisk cadence — great for cardiovascular fitness"
                : cadence > 100 ? "Good walking pace, try to maintain consistency"
                : cadence > 0 ? "Try picking up the pace slightly"
                : "Walk with Apple Watch to track step cadence"
        ))

        // Symmetry — asymmetry
        let asymmetry = wm?.asymmetryPercent ?? 0
        let symmetryScore = asymmetry >= 0 ? Swift.max(0, 100 - asymmetry * 5) : 0
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Gait Balance",
            score: asymmetry > 0 ? symmetryScore : 0,
            keyMetric: asymmetry > 0 ? String(format: "%.1f%% asymmetry", asymmetry) : "Needs Apple Watch",
            tip: asymmetry > 8 ? "Work on single-leg strength to improve balance"
                : asymmetry > 5 ? "Slight imbalance — focus on even footstrikes"
                : asymmetry > 0 ? "Well balanced gait — maintain this"
                : "Apple Watch measures gait asymmetry automatically"
        ))

        // Economy — speed vs effort
        let speed = wm?.averageSpeed ?? 0
        let economyScore = speed > 0 ? Swift.min(100, speed * 3.6 / 6.0 * 100) : 0
        cards.append(PillarCardData(
            pillar: .economy,
            subtitle: "Walking Efficiency",
            score: economyScore,
            keyMetric: speed > 0 ? String(format: "%.1f km/h", speed * 3.6) : "Building baseline",
            tip: economyScore > 70 ? "Efficient walking pace — great aerobic work"
                : economyScore > 40 ? "Moderate pace — good for recovery sessions"
                : economyScore > 0 ? "Easy walk — good for active recovery"
                : "Walk longer to build an efficiency baseline"
        ))

        return cards
    }

    private func computeSwimmingPillarCards() -> [PillarCardData] {
        let sm = enrichment?.swimmingMetrics
        var cards: [PillarCardData] = []

        // Stability — stroke consistency (from lap SWOLF variance)
        let laps = sm?.laps ?? []
        let swolfValues = laps.compactMap(\.swolf)
        var stabilityScore: Double = 0
        if swolfValues.count >= 3 {
            let mean = swolfValues.reduce(0, +) / Double(swolfValues.count)
            let cv = mean > 0 ? sqrt(swolfValues.reduce(0) { $0 + pow($1 - mean, 2) } / Double(swolfValues.count)) / mean : 0
            stabilityScore = Swift.max(0, 100 - cv * 500)
        }
        cards.append(PillarCardData(
            pillar: .stability,
            subtitle: "Stroke Consistency",
            score: stabilityScore,
            keyMetric: swolfValues.count >= 3 ? String(format: "%.0f avg SWOLF", swolfValues.reduce(0, +) / Double(swolfValues.count)) : "Needs more laps",
            tip: stabilityScore > 80 ? "Very consistent strokes — excellent technique"
                : stabilityScore > 50 ? "Good consistency, work on maintaining form when tired"
                : stabilityScore > 0 ? "Stroke varies between laps — focus on technique drills"
                : "Swim at least 3 laps for consistency analysis"
        ))

        // Rhythm — SWOLF (lower = better)
        let swolf = sm?.averageSWOLF ?? 0
        let rhythmScore = swolf > 0 ? Swift.max(0, Swift.min(100, (80 - swolf) / 40 * 100)) : 0
        cards.append(PillarCardData(
            pillar: .rhythm,
            subtitle: "Stroke Efficiency",
            score: rhythmScore,
            keyMetric: swolf > 0 ? String(format: "SWOLF %.0f", swolf) : "Needs stroke data",
            tip: swolf > 0 && swolf < 40 ? "Excellent SWOLF — elite-level efficiency"
                : swolf < 55 ? "Good SWOLF — maintain long, powerful strokes"
                : swolf > 0 ? "High SWOLF — focus on fewer, longer strokes per lap"
                : "SWOLF = time + strokes per lap (lower is better)"
        ))

        // Symmetry — stroke count consistency
        let strokeCounts = laps.compactMap(\.strokeCount).map { Double($0) }
        var symScore: Double = 0
        if strokeCounts.count >= 3 {
            let mean = strokeCounts.reduce(0, +) / Double(strokeCounts.count)
            let cv = mean > 0 ? sqrt(strokeCounts.reduce(0) { $0 + pow($1 - mean, 2) } / Double(strokeCounts.count)) / mean : 0
            symScore = Swift.max(0, 100 - cv * 500)
        }
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Lap Consistency",
            score: symScore,
            keyMetric: strokeCounts.count >= 3 ? String(format: "%.0f avg strokes/lap", strokeCounts.reduce(0, +) / Double(strokeCounts.count)) : "Needs more laps",
            tip: symScore > 80 ? "Consistent stroke count across laps — strong technique"
                : symScore > 50 ? "Some variation — watch for form breakdown in later laps"
                : symScore > 0 ? "Stroke count varies — focus on maintaining rhythm"
                : "Swim at least 3 laps for consistency analysis"
        ))

        // Economy — total strokes vs distance
        let totalStrokes = sm?.totalStrokeCount ?? 0
        let distance = workout.totalDistance ?? 0
        var econScore: Double = 0
        if totalStrokes > 0 && distance > 0 {
            let strokesPer100m = totalStrokes / (distance / 100)
            econScore = Swift.max(0, Swift.min(100, (40 - strokesPer100m) / 20 * 100))
        }
        cards.append(PillarCardData(
            pillar: .economy,
            subtitle: "Swim Economy",
            score: econScore,
            keyMetric: totalStrokes > 0 && distance > 0 ? String(format: "%.0f strokes/100m", totalStrokes / (distance / 100)) : "Needs distance data",
            tip: econScore > 70 ? "Efficient stroke count — long, powerful pulls"
                : econScore > 40 ? "Good economy, try reducing strokes per length"
                : econScore > 0 ? "High stroke count — focus on catch and pull technique"
                : "Economy builds from stroke count and distance data"
        ))

        return cards
    }

    private func computeCyclingPillarCards() -> [PillarCardData] {
        let cm = enrichment?.cyclingMetrics
        var cards: [PillarCardData] = []

        // Stability — core engagement (approximated from power consistency)
        let stabilityScore = computeSplitConsistencyScore()
        cards.append(PillarCardData(
            pillar: .stability,
            subtitle: "Riding Stability",
            score: stabilityScore,
            keyMetric: stabilityScore > 0 ? "\(Int(stabilityScore))% consistent" : "Building baseline",
            tip: stabilityScore > 70 ? "Stable power output — good core engagement"
                : stabilityScore > 40 ? "Some variation — work on maintaining seated position"
                : "Ride longer for stability analysis"
        ))

        // Rhythm — cadence
        let cadence = cm?.averageCadence ?? 0
        let rhythmScore = cadence > 0 ? Swift.max(0, 100 - abs(cadence - 90) / 90 * 200) : 0
        cards.append(PillarCardData(
            pillar: .rhythm,
            subtitle: "Pedal Cadence",
            score: rhythmScore,
            keyMetric: cadence > 0 ? String(format: "%.0f rpm", cadence) : "Needs cadence sensor",
            tip: cadence > 0 && cadence < 80 ? "Try spinning faster in a lighter gear (aim ~90 rpm)"
                : cadence > 100 ? "High cadence — ensure you're generating power"
                : cadence > 0 ? "Good cadence — maintain smooth pedalling"
                : "Use cadence sensor or power meter for rhythm data"
        ))

        // Symmetry + Economy use split consistency
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Power Balance",
            score: 0,
            keyMetric: "Needs L/R power meter",
            tip: "Dual-sided power meter measures left/right balance"
        ))

        let speed = cm?.averageSpeed ?? 0
        let econScore = speed > 0 ? Swift.min(100, speed * 3.6 / 35 * 100) : 0
        cards.append(PillarCardData(
            pillar: .economy,
            subtitle: "Cycling Efficiency",
            score: econScore,
            keyMetric: speed > 0 ? String(format: "%.1f km/h avg", speed * 3.6) : "Building baseline",
            tip: econScore > 70 ? "Strong pace — efficient riding"
                : econScore > 40 ? "Moderate pace — good endurance work"
                : econScore > 0 ? "Easy ride — good for recovery"
                : "Ride longer for efficiency analysis"
        ))

        return cards
    }

    private func computeGeneralPillarCards() -> [PillarCardData] {
        // For yoga, HIIT, strength, etc. — show what we can from HR/duration
        let econScore = Swift.min(100, workout.duration / 3600 * 100)
        return [
            PillarCardData(
                pillar: .stability, subtitle: "Core & Balance", score: 0,
                keyMetric: "Activity-specific", tip: "This workout type builds stability through \(workout.activityName.lowercased())"
            ),
            PillarCardData(
                pillar: .rhythm, subtitle: "Movement Tempo", score: 0,
                keyMetric: "Activity-specific", tip: "Focus on controlled, rhythmic movement"
            ),
            PillarCardData(
                pillar: .symmetry, subtitle: "Bilateral Balance", score: 0,
                keyMetric: "Activity-specific", tip: "Include exercises on both sides equally"
            ),
            PillarCardData(
                pillar: .economy, subtitle: "Movement Efficiency", score: econScore,
                keyMetric: String(format: "%.0f min session", workout.duration / 60),
                tip: econScore > 70 ? "Good session length for building fitness" : "Try gradually extending session duration"
            ),
        ]
    }

    // MARK: - Physiology Helpers

    private var pillarPhysiologyScore: Double {
        guard let general = enrichment?.generalMetrics,
              let avgHR = general.averageHeartRate, let maxHR = general.maxHeartRate,
              avgHR > 0, maxHR > 0 else { return 0 }
        let hrRange = maxHR - (general.minHeartRate ?? avgHR)
        return Swift.max(0, Swift.min(100, 100 - hrRange / maxHR * 150))
    }

    private var pillarPhysiologyMetric: String {
        guard let general = enrichment?.generalMetrics else { return "Needs HR data" }
        if let avg = general.averageHeartRate {
            return "\(Int(avg)) avg bpm"
        }
        return "Needs HR data"
    }

    private var pillarPhysiologyTip: String {
        guard let general = enrichment?.generalMetrics,
              let maxHR = general.maxHeartRate else {
            return "Wear Apple Watch for heart rate monitoring"
        }
        if maxHR > 185 { return "High max HR — ensure adequate recovery before next session" }
        if let avg = general.averageHeartRate, avg > 160 { return "Intense session — plan an easy day tomorrow" }
        return "Good cardiovascular effort — maintain consistent training"
    }

    // MARK: - Split Consistency Score

    private func computeSplitConsistencyScore() -> Double {
        guard let splits = enrichment?.splits, splits.count >= 3 else { return 0 }
        let paces = splits.map(\.pace)
        let mean = paces.reduce(0, +) / Double(paces.count)
        guard mean > 0 else { return 0 }
        let variance = paces.reduce(0) { $0 + pow($1 - mean, 2) } / Double(paces.count)
        let cv = sqrt(variance) / mean * 100
        if cv < 3 { return 95 }
        if cv < 6 { return 75 }
        if cv < 10 { return 50 }
        return 30
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(.headline)

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.title3)
                        .foregroundStyle(insightColor(insight.sentiment))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.subheadline.bold())

                        Text(insight.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(insightColor(insight.sentiment).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func insightColor(_ sentiment: WorkoutInsight.Sentiment) -> Color {
        switch sentiment {
        case .positive: .green
        case .neutral: .blue
        case .attention: .orange
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)

            HStack {
                Image(systemName: "app.badge")
                    .foregroundStyle(.secondary)
                Text(workout.sourceName)
                    .font(.body)
                Spacer()
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title3.bold().monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)

            Text(value)
                .font(.subheadline.bold().monospacedDigit())

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: workout.startDate)
    }

    private var averagePace: String? {
        guard let distance = workout.totalDistance, distance > 0 else { return nil }
        let paceSecondsPerKm = workout.duration / (distance / 1000)
        return formatPace(paceSecondsPerKm)
    }

    private func formatPace(_ secondsPerKm: TimeInterval) -> String {
        let minutes = Int(secondsPerKm) / 60
        let seconds = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private func formatSplitDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Use prebuilt enrichment (from legacy model data) or fetch from HealthKit
        if let prebuilt = prebuiltEnrichment {
            enrichment = prebuilt
        } else {
            enrichment = await WorkoutEnrichmentService.shared.enrich(
                workoutId: workout.id,
                startDate: workout.startDate,
                endDate: workout.endDate,
                activityType: workout.activityType
            )
        }

        // Merge: if prebuilt had data but HealthKit has more, prefer HealthKit enrichment
        // For legacy sessions, prebuilt is the primary source
        // For Apple Watch sessions, HealthKit query is primary

        photos = await loadPhotos()

        // Generate insights and pillar cards
        if let enrichment {
            insights = await WorkoutInsightsGenerator.shared.generateInsights(
                for: workout,
                enrichment: enrichment
            )

            pillarCards = computePillarCards()
        }
    }

    private func loadPhotos() async -> [PHAsset] {
        guard photoService.isAuthorized else { return [] }

        let bufferedStart = workout.startDate.addingTimeInterval(-300)
        let bufferedEnd = workout.endDate.addingTimeInterval(300)

        let media = await photoService.findMediaForDateRange(from: bufferedStart, to: bufferedEnd)
        return media.photos
    }
}

// MARK: - Photo Thumbnail

private struct PhotoThumbnailView: View {
    let asset: PHAsset

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let photoService = RidePhotoService.shared

        // Check cache first
        if let cached = photoService.getCachedThumbnail(for: asset.localIdentifier) {
            image = cached
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        let size = CGSize(width: 240, height: 240)

        let result: UIImage? = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        if let result {
            photoService.cacheThumbnail(result, for: asset.localIdentifier)
            image = result
        }
    }
}
