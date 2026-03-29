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
import SwiftData

struct EnrichedWorkoutDetailView: View {
    let workout: ExternalWorkout
    var prebuiltEnrichment: WorkoutEnrichment?

    @State private var enrichment: WorkoutEnrichment?
    @State private var insights: [WorkoutInsight] = []
    @State private var domainScores: [SkillDomainScore] = []
    @State private var pillarCards: [PillarCardData] = []
    @State private var photos: [PHAsset] = []
    @State private var isLoading = true

    // Historical trend queries for cross-session comparison
    @Query(sort: \RunningSession.startDate, order: .reverse) private var recentRuns: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var recentSwims: [SwimmingSession]

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

                        // Fatigue trend — first half vs second half comparison
                        fatigueTrendSection(enrichment)

                        if enrichment.startWeatherDescription != nil || enrichment.temperature != nil {
                            weatherSection(enrichment)
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
                    metricCard(title: "Avg SpO2", value: String(format: "%.0f%%", spo2), icon: "lungs.fill")
                }

                if let minSpo2 = metrics.minSpO2 {
                    metricCard(title: "Min SpO2", value: String(format: "%.0f%%", minSpo2), icon: "lungs")
                }

                if let breathing = metrics.averageBreathingRate {
                    metricCard(title: "Breathing", value: String(format: "%.0f bpm", breathing), icon: "wind")
                }

                if let submergedTime = metrics.totalSubmergedTime {
                    let mins = Int(submergedTime) / 60
                    let secs = Int(submergedTime) % 60
                    metricCard(title: "Submerged", value: String(format: "%d:%02d", mins, secs), icon: "water.waves.and.arrow.down")
                }

                if let count = metrics.submersionCount {
                    metricCard(title: "Submersions", value: "\(count)", icon: "arrow.down.to.line")
                }

                if let recovery = metrics.recoveryQuality {
                    metricCard(title: "Recovery", value: String(format: "%.0f", recovery), icon: "heart.circle")
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
        VStack(alignment: .leading, spacing: 12) {
            // HR Summary
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

                if let recovery = metrics.heartRateRecovery, recovery > 0 {
                    metricCard(title: "Recovery", value: String(format: "%.0f bpm drop", recovery), icon: "heart.circle")
                }

                if let restingHR = metrics.restingHeartRate {
                    metricCard(title: "Resting HR", value: "\(Int(restingHR)) bpm", icon: "bed.double.fill")
                }
            }

            // Fitness Indicators (if any available)
            let hasFitnessData = metrics.vo2Max != nil || metrics.hrvSDNN != nil || metrics.activeCalories != nil || metrics.flightsClimbed != nil || metrics.averageBreathingRate != nil || metrics.averageSpO2 != nil

            if hasFitnessData {
                Text("Physiology")
                    .font(.headline)
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let vo2 = metrics.vo2Max {
                        metricCard(title: "VO\u{2082} Max", value: String(format: "%.1f", vo2), icon: "lungs.fill")
                    }

                    if let hrv = metrics.hrvSDNN {
                        metricCard(title: "HRV", value: String(format: "%.0f ms", hrv), icon: "waveform.path.ecg")
                    }

                    if let breathing = metrics.averageBreathingRate {
                        metricCard(title: "Breathing", value: String(format: "%.0f bpm", breathing), icon: "wind")
                    }

                    if let spo2 = metrics.averageSpO2 {
                        metricCard(title: "SpO\u{2082}", value: String(format: "%.0f%%", spo2), icon: "drop.fill")
                    }

                    if let cal = metrics.activeCalories {
                        metricCard(title: "Calories", value: String(format: "%.0f kcal", cal), icon: "flame.fill")
                    }

                    if let flights = metrics.flightsClimbed, flights > 0 {
                        metricCard(title: "Flights", value: String(format: "%.0f", flights), icon: "figure.stairs")
                    }
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

    // MARK: - Fatigue Trend

    @ViewBuilder
    private func fatigueTrendSection(_ enrichment: WorkoutEnrichment) -> some View {
        let hrAnalysis = computeHRFatigueTrend(enrichment.heartRateSamples)
        let paceAnalysis = computePaceFatigueTrend(enrichment.splits)

        if let hr = hrAnalysis {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.orange)
                    Text("Fatigue Trend")
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 0) {
                    // First half
                    VStack(spacing: 4) {
                        Text("First Half")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(hr.firstHalfAvg))")
                            .font(.title2.bold().monospacedDigit())
                        Text("avg bpm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Trend arrow
                    VStack(spacing: 4) {
                        Image(systemName: hr.driftDetected ? "arrow.up.right" : "arrow.right")
                            .font(.title3.bold())
                            .foregroundStyle(hr.driftDetected ? .orange : .green)
                        Text(hr.driftDetected ? "+\(Int(hr.secondHalfAvg - hr.firstHalfAvg))" : "±\(Int(abs(hr.secondHalfAvg - hr.firstHalfAvg)))")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(hr.driftDetected ? .orange : .green)
                    }

                    // Second half
                    VStack(spacing: 4) {
                        Text("Second Half")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(hr.secondHalfAvg))")
                            .font(.title2.bold().monospacedDigit())
                        Text("avg bpm")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Coach insight
                Text(hr.driftDetected
                    ? "HR drift detected — cardiac fatigue. Consider shorter intervals or better pacing."
                    : "Steady heart rate throughout — good cardiovascular endurance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                // Pace fade (if also available)
                if let pace = paceAnalysis {
                    Divider()

                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("First Half")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatPace(pace.firstHalfAvgPace))
                                .font(.headline.bold().monospacedDigit())
                            Text("/km")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Image(systemName: pace.fadeDetected ? "arrow.down.right" : "arrow.right")
                                .font(.title3.bold())
                                .foregroundStyle(pace.fadeDetected ? .red : .green)
                        }

                        VStack(spacing: 4) {
                            Text("Second Half")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatPace(pace.secondHalfAvgPace))
                                .font(.headline.bold().monospacedDigit())
                            Text("/km")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text(pace.fadeDetected
                        ? "Pace fade detected — second half \(Int(pace.fadePercent))% slower. Build endurance with negative splits."
                        : "Even pacing — well-managed effort distribution.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let pace = paceAnalysis {
            // Pace-only fatigue trend (no HR data)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundStyle(.orange)
                    Text("Fatigue Trend")
                        .font(.headline)
                    Spacer()
                }

                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("First Half")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatPace(pace.firstHalfAvgPace))
                            .font(.title2.bold().monospacedDigit())
                        Text("/km")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Image(systemName: pace.fadeDetected ? "arrow.down.right" : "arrow.right")
                            .font(.title3.bold())
                            .foregroundStyle(pace.fadeDetected ? .red : .green)
                    }

                    VStack(spacing: 4) {
                        Text("Second Half")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatPace(pace.secondHalfAvgPace))
                            .font(.title2.bold().monospacedDigit())
                        Text("/km")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text(pace.fadeDetected
                    ? "Pace fade detected — second half \(Int(pace.fadePercent))% slower. Build endurance with negative splits."
                    : "Even pacing — well-managed effort distribution.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private struct HRFatigueTrend {
        let firstHalfAvg: Double
        let secondHalfAvg: Double
        let driftDetected: Bool
    }

    private struct PaceFatigueTrend {
        let firstHalfAvgPace: TimeInterval
        let secondHalfAvgPace: TimeInterval
        let fadeDetected: Bool
        let fadePercent: Double
    }

    private func computeHRFatigueTrend(_ samples: [WorkoutEnrichment.HeartRateSamplePoint]) -> HRFatigueTrend? {
        guard samples.count > 10 else { return nil }

        let sorted = samples.sorted { $0.date < $1.date }
        let midpoint = sorted.count / 2
        let firstHalf = sorted[..<midpoint]
        let secondHalf = sorted[midpoint...]

        let firstAvg = firstHalf.map(\.bpm).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.bpm).reduce(0, +) / Double(secondHalf.count)

        let driftDetected = secondAvg > firstAvg + 5

        return HRFatigueTrend(
            firstHalfAvg: firstAvg,
            secondHalfAvg: secondAvg,
            driftDetected: driftDetected
        )
    }

    private func computePaceFatigueTrend(_ splits: [WorkoutEnrichment.PaceSplit]) -> PaceFatigueTrend? {
        guard splits.count > 3 else { return nil }

        let midpoint = splits.count / 2
        let firstHalf = splits[..<midpoint]
        let secondHalf = splits[midpoint...]

        let firstAvgPace = firstHalf.map(\.pace).reduce(0, +) / Double(firstHalf.count)
        let secondAvgPace = secondHalf.map(\.pace).reduce(0, +) / Double(secondHalf.count)

        guard firstAvgPace > 0 else { return nil }

        let fadePercent = ((secondAvgPace - firstAvgPace) / firstAvgPace) * 100
        let fadeDetected = fadePercent > 5

        return PaceFatigueTrend(
            firstHalfAvgPace: firstAvgPace,
            secondHalfAvgPace: secondAvgPace,
            fadeDetected: fadeDetected,
            fadePercent: fadePercent
        )
    }

    // MARK: - Weather

    private func weatherSection(_ enrichment: WorkoutEnrichment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weather")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let condition = enrichment.startWeatherDescription {
                    metricCard(title: "Conditions", value: condition, icon: "cloud.sun.fill")
                }

                if let temp = enrichment.temperature {
                    metricCard(title: "Temperature", value: String(format: "%.0f\u{00B0}C", temp), icon: "thermometer.medium")
                }

                if let humidity = enrichment.humidity {
                    metricCard(title: "Humidity", value: String(format: "%.0f%%", humidity), icon: "humidity.fill")
                }

                if let wind = enrichment.windSpeed {
                    let kmh = wind * 3.6
                    metricCard(title: "Wind", value: String(format: "%.0f km/h", kmh), icon: "wind")
                }

                if let endCondition = enrichment.endWeatherDescription,
                   endCondition != enrichment.startWeatherDescription {
                    metricCard(title: "End Conditions", value: endCondition, icon: "cloud.fill")
                }
            }
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

    // MARK: - Historical Trend Helper

    /// Returns a short trend suffix comparing the current value to the average of recent sessions.
    /// When `inverted` is true, a lower value is better (e.g. vertical oscillation, asymmetry).
    private func trendSuffix(current: Double, recentValues: [Double], metric: String, inverted: Bool = false) -> String {
        let filtered = recentValues.filter { $0 > 0 }
        guard filtered.count >= 3 else { return "" }
        let avg = filtered.reduce(0, +) / Double(filtered.count)
        let threshold = avg * 0.05
        if !inverted {
            if current > avg + threshold { return " Improving from avg \(metric)." }
            if current < avg - threshold { return " Below recent avg \(metric)." }
        } else {
            if current < avg - threshold { return " Improving from avg \(metric)." }
            if current > avg + threshold { return " Above recent avg \(metric)." }
        }
        return " Consistent with recent sessions."
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
        let recentRunData = Array(recentRuns.prefix(5))
        var cards: [PillarCardData] = []

        // Stability — vertical oscillation
        let vo = rm?.averageVerticalOscillation ?? 0
        let stabilityScore = vo > 0 ? Swift.max(0, Swift.min(100, (12 - vo) / 4 * 100)) : 0
        let voBaseTip: String = vo > 10 ? "Focus on running tall — imagine a string pulling you up"
            : vo > 8 ? "Good height, try engaging core more"
            : vo > 0 ? "Maintain your tall posture"
            : "Run with Apple Watch to measure vertical oscillation"
        let recentVO = recentRunData.map { $0.averageVerticalOscillation }
        let voFiltered = recentVO.filter { $0 > 0 }
        let voAvg = voFiltered.isEmpty ? 0.0 : voFiltered.reduce(0, +) / Double(voFiltered.count)
        let voTrend = vo > 0 ? trendSuffix(current: vo, recentValues: recentVO, metric: String(format: "%.1f cm", voAvg), inverted: true) : ""
        cards.append(PillarCardData(
            pillar: .stability,
            subtitle: "Posture & Oscillation",
            score: stabilityScore,
            keyMetric: vo > 0 ? String(format: "%.1f cm bounce", vo) : "Needs Apple Watch",
            tip: voBaseTip + voTrend
        ))

        // Rhythm — cadence
        let cadence = rm?.averageCadence ?? 0
        let rhythmScore = cadence > 0 ? Swift.max(0, 100 - abs(cadence - 180) / 180 * 200) : 0
        let cadenceBaseTip: String = cadence > 0 && cadence < 170 ? "Aim for quicker, lighter steps (170-180 spm)"
            : cadence > 190 ? "Cadence is high — ensure you're not overstriding"
            : cadence > 0 ? "Maintain your light, quick rhythm"
            : "Carry phone or wear Apple Watch to track cadence"
        let recentCadence = recentRunData.map { Double($0.averageCadence) }
        let cadenceFiltered = recentCadence.filter { $0 > 0 }
        let cadenceAvg = cadenceFiltered.isEmpty ? 0.0 : cadenceFiltered.reduce(0, +) / Double(cadenceFiltered.count)
        let cadenceTrend = cadence > 0 ? trendSuffix(current: cadence, recentValues: recentCadence, metric: String(format: "%.0f spm", cadenceAvg)) : ""
        cards.append(PillarCardData(
            pillar: .rhythm,
            subtitle: "Cadence & Tempo",
            score: rhythmScore,
            keyMetric: cadence > 0 ? String(format: "%.0f spm", cadence) : "Needs motion data",
            tip: cadenceBaseTip + cadenceTrend
        ))

        // Symmetry — stride length balance & asymmetry
        // Use stride length for form symmetry; GCT moves to Economy as efficiency metric
        let stride = rm?.averageStrideLength ?? 0
        let gct = rm?.averageGroundContactTime ?? 0
        let symmetryScore: Double = {
            // Stride length ratio: ideal is 2.2-2.6x leg length (~0.8-1.2m)
            if stride > 0 {
                let idealRange = stride > 0.8 && stride < 1.3
                return idealRange ? 85 : (stride > 0.6 ? 65 : 45)
            }
            // Fallback: use split consistency as proxy for balanced running
            if !enrichment!.splits.isEmpty { return computeSplitConsistencyScore() }
            return 0
        }()
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Stride Balance",
            score: symmetryScore,
            keyMetric: {
                if stride > 0 && gct > 0 {
                    return String(format: "%.2fm stride, %.0fms GCT", stride, gct)
                }
                if stride > 0 { return String(format: "%.2f m stride length", stride) }
                if gct > 0 { return String(format: "%.0f ms ground contact", gct) }
                return "Needs Apple Watch"
            }(),
            tip: {
                if stride > 1.3 { return "Long stride — ensure you're not overstriding, land under hips" }
                if stride > 0.8 { return "Good stride length — balanced and efficient" }
                if stride > 0 { return "Short stride — work on hip extension and flexibility" }
                if gct > 300 { return "High ground contact — focus on quick, light footstrikes" }
                if gct > 0 { return "Good ground contact time — maintain light feet" }
                return "Apple Watch measures stride length and ground contact balance"
            }()
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
        let recentRunData = Array(recentRuns.prefix(5))
        var cards: [PillarCardData] = []

        // Stability — steadiness
        let steadiness = wm?.steadiness ?? 0
        let steadinessBaseTip: String = steadiness > 80 ? "Excellent steadiness — your balance is strong"
            : steadiness > 60 ? "Good balance, try uneven terrain to challenge it"
            : steadiness > 0 ? "Steadiness below average — consider fatigue or terrain"
            : "Apple Watch measures walking steadiness automatically"
        let recentSteadiness = recentRunData.compactMap { $0.healthKitWalkingSteadiness }
        let steadinessFiltered = recentSteadiness.filter { $0 > 0 }
        let steadinessAvg = steadinessFiltered.isEmpty ? 0.0 : steadinessFiltered.reduce(0, +) / Double(steadinessFiltered.count)
        let steadinessTrend = steadiness > 0 ? trendSuffix(current: steadiness, recentValues: recentSteadiness, metric: String(format: "%.0f%%", steadinessAvg)) : ""
        cards.append(PillarCardData(
            pillar: .stability,
            subtitle: "Walking Steadiness",
            score: steadiness,
            keyMetric: steadiness > 0 ? String(format: "%.0f%% steady", steadiness) : "Needs Apple Watch",
            tip: steadinessBaseTip + steadinessTrend
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
        let asymmetryBaseTip: String = asymmetry > 8 ? "Work on single-leg strength to improve balance"
            : asymmetry > 5 ? "Slight imbalance — focus on even footstrikes"
            : asymmetry > 0 ? "Well balanced gait — maintain this"
            : "Apple Watch measures gait asymmetry automatically"
        let recentAsymmetry = recentRunData.compactMap { $0.healthKitAsymmetry }
        let asymmetryFiltered = recentAsymmetry.filter { $0 > 0 }
        let asymmetryAvg = asymmetryFiltered.isEmpty ? 0.0 : asymmetryFiltered.reduce(0, +) / Double(asymmetryFiltered.count)
        let asymmetryTrend = asymmetry > 0 ? trendSuffix(current: asymmetry, recentValues: recentAsymmetry, metric: String(format: "%.1f%%", asymmetryAvg), inverted: true) : ""
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Gait Balance",
            score: asymmetry > 0 ? symmetryScore : 0,
            keyMetric: asymmetry > 0 ? String(format: "%.1f%% asymmetry", asymmetry) : "Needs Apple Watch",
            tip: asymmetryBaseTip + asymmetryTrend
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
        let recentSwimData = Array(recentSwims.prefix(5))
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
        // Rhythm — lap time consistency (are you holding a steady pace?)
        let lapTimes = laps.map(\.duration)
        var rhythmScore: Double = 0
        if lapTimes.count >= 3 {
            let mean = lapTimes.reduce(0, +) / Double(lapTimes.count)
            let cv = mean > 0 ? sqrt(lapTimes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(lapTimes.count)) / mean : 0
            rhythmScore = Swift.max(0, 100 - cv * 500)
        }
        let avgLapTime = lapTimes.isEmpty ? 0 : lapTimes.reduce(0, +) / Double(lapTimes.count)
        let recentAvgLapTimes = recentSwimData.compactMap { swim -> Double? in
            let swimLaps = swim.laps ?? []
            guard !swimLaps.isEmpty else { return nil }
            let totalDur = swimLaps.reduce(0.0) { $0 + $1.duration }
            return totalDur / Double(swimLaps.count)
        }
        let lapTimeFiltered = recentAvgLapTimes.filter { $0 > 0 }
        let lapTimeAvg = lapTimeFiltered.isEmpty ? 0.0 : lapTimeFiltered.reduce(0, +) / Double(lapTimeFiltered.count)
        let lapTimeMetric = String(format: "%d:%02d", Int(lapTimeAvg) / 60, Int(lapTimeAvg) % 60)
        let lapTimeTrend = avgLapTime > 0 ? trendSuffix(current: avgLapTime, recentValues: recentAvgLapTimes, metric: lapTimeMetric, inverted: true) : ""
        let rhythmBaseTip: String = rhythmScore > 80 ? "Very consistent lap times — excellent pacing discipline"
            : rhythmScore > 50 ? "Good timing — some variation between laps"
            : rhythmScore > 0 ? "Lap times vary — try to hold a steady pace each length"
            : "Swim at least 3 laps for timing analysis"
        let rhythmKeyMetric: String
        if avgLapTime > 0 {
            let mins = Int(avgLapTime) / 60
            let secs = Int(avgLapTime) % 60
            rhythmKeyMetric = String(format: "%d:%02d avg lap", mins, secs)
        } else {
            rhythmKeyMetric = "Needs lap data"
        }
        cards.append(PillarCardData(
            pillar: .rhythm,
            subtitle: "Lap Timing",
            score: rhythmScore,
            keyMetric: rhythmKeyMetric,
            tip: rhythmBaseTip + lapTimeTrend
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

        // Economy — SWOLF + strokes per distance
        let swolf = sm?.averageSWOLF ?? 0
        let totalStrokes = sm?.totalStrokeCount ?? 0
        let distance = workout.totalDistance ?? 0
        var econScore: Double = 0
        if swolf > 0 {
            econScore = Swift.max(0, Swift.min(100, (80 - swolf) / 40 * 100))
        } else if totalStrokes > 0 && distance > 0 {
            let strokesPer100m = totalStrokes / (distance / 100)
            econScore = Swift.max(0, Swift.min(100, (40 - strokesPer100m) / 20 * 100))
        }
        cards.append(PillarCardData(
            pillar: .economy,
            subtitle: "Stroke Economy",
            score: econScore,
            keyMetric: {
                if swolf > 0 && totalStrokes > 0 && distance > 0 {
                    return String(format: "SWOLF %.0f · %.0f strokes/100m", swolf, totalStrokes / (distance / 100))
                }
                if swolf > 0 { return String(format: "SWOLF %.0f", swolf) }
                if totalStrokes > 0 && distance > 0 { return String(format: "%.0f strokes/100m", totalStrokes / (distance / 100)) }
                return "Needs stroke data"
            }(),
            tip: {
                let baseTip: String
                if swolf > 0 && swolf < 40 { baseTip = "Excellent SWOLF — elite-level efficiency per lap" }
                else if swolf > 0 && swolf < 55 { baseTip = "Good SWOLF — maintain long, powerful strokes" }
                else if swolf > 0 { baseTip = "High SWOLF — focus on fewer, longer strokes per lap" }
                else if econScore > 70 { baseTip = "Efficient stroke count — good distance per pull" }
                else if econScore > 0 { baseTip = "Try reducing strokes per length while maintaining speed" }
                else { baseTip = "SWOLF = lap time + strokes (lower is more efficient)" }
                let recentSwolf = recentSwimData.map { $0.averageSwolf }
                let swolfFiltered = recentSwolf.filter { $0 > 0 }
                let swolfAvg = swolfFiltered.isEmpty ? 0.0 : swolfFiltered.reduce(0, +) / Double(swolfFiltered.count)
                let swolfTrend = swolf > 0 ? trendSuffix(current: swolf, recentValues: recentSwolf, metric: String(format: "%.0f SWOLF", swolfAvg), inverted: true) : ""
                return baseTip + swolfTrend
            }()
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

        // Symmetry — effort consistency across the ride (even pacing = balanced effort)
        let symScore = computeSplitConsistencyScore()
        cards.append(PillarCardData(
            pillar: .symmetry,
            subtitle: "Effort Balance",
            score: symScore,
            keyMetric: symScore > 0 ? "\(Int(symScore))% balanced effort" : "Needs split data",
            tip: symScore > 80 ? "Very even effort — well-paced throughout the ride"
                : symScore > 50 ? "Good pacing — some effort variation between splits"
                : symScore > 0 ? "Uneven effort — try to pace yourself more evenly"
                : "Ride longer with GPS for effort balance analysis"
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
        // For yoga, HIIT, strength, etc. — use HR data when available
        let general = enrichment?.generalMetrics
        let hrSamples = enrichment?.heartRateSamples ?? []
        let duration = workout.duration
        let activityName = workout.activityName

        // Stability — HR steadiness (lower variability = calmer, more controlled)
        let stabilityScore: Double = {
            guard hrSamples.count > 10 else { return 0 }
            let bpms = hrSamples.map(\.bpm)
            let mean = bpms.reduce(0, +) / Double(bpms.count)
            guard mean > 0 else { return 0 }
            let cv = sqrt(bpms.reduce(0) { $0 + pow($1 - mean, 2) } / Double(bpms.count)) / mean * 100
            if cv < 8 { return 90 }   // Very steady — yoga, strength
            if cv < 15 { return 70 }  // Moderate — mixed cardio
            if cv < 25 { return 50 }  // Variable — HIIT (expected)
            return 35
        }()

        // Rhythm — session structure (duration relative to typical)
        let rhythmScore = Swift.min(100, duration / 2700 * 100) // 45 min = 100

        // Symmetry — HR recovery between efforts (for HIIT/intervals)
        let symScore: Double = {
            guard hrSamples.count > 20 else { return 0 }
            let bpms = hrSamples.map(\.bpm)
            let maxHR = bpms.max() ?? 0
            let minHR = bpms.min() ?? 0
            guard maxHR > 0 else { return 0 }
            // Good range means you worked hard AND recovered — balanced effort
            let range = maxHR - minHR
            if range > 60 { return 85 }  // Wide range — good interval effort
            if range > 40 { return 70 }  // Moderate range
            if range > 20 { return 55 }  // Narrow range — steady state
            return 40
        }()

        // Economy — duration + calories efficiency
        let econScore = Swift.min(100, duration / 3600 * 100)

        return [
            PillarCardData(
                pillar: .stability,
                subtitle: "Effort Control",
                score: stabilityScore,
                keyMetric: {
                    if let avg = general?.averageHeartRate {
                        return "\(Int(avg)) avg bpm"
                    }
                    return String(format: "%.0f min %@", duration / 60, activityName.lowercased())
                }(),
                tip: stabilityScore > 80 ? "Very controlled effort — steady heart rate throughout"
                    : stabilityScore > 50 ? "Moderate HR variation — good mix of effort and recovery"
                    : stabilityScore > 0 ? "High HR variability — typical for interval-style training"
                    : "Wear Apple Watch for heart rate-based stability analysis"
            ),
            PillarCardData(
                pillar: .rhythm,
                subtitle: "Session Structure",
                score: rhythmScore,
                keyMetric: String(format: "%.0f min session", duration / 60),
                tip: rhythmScore > 80 ? "Solid session length — great for building fitness"
                    : rhythmScore > 50 ? "Good workout — consistency builds results"
                    : "Try to build toward 30-45 minute sessions gradually"
            ),
            PillarCardData(
                pillar: .symmetry,
                subtitle: "Effort Distribution",
                score: symScore,
                keyMetric: {
                    if let max = general?.maxHeartRate, let min = general?.minHeartRate {
                        return "\(Int(min))-\(Int(max)) bpm range"
                    }
                    return "Needs HR data"
                }(),
                tip: symScore > 80 ? "Great effort range — good balance of intensity and recovery"
                    : symScore > 50 ? "Moderate effort variation — well-structured session"
                    : symScore > 0 ? "Narrow HR range — try adding some higher intensity intervals"
                    : "Apple Watch measures effort distribution through heart rate"
            ),
            PillarCardData(
                pillar: .economy,
                subtitle: "Training Volume",
                score: econScore,
                keyMetric: {
                    if let cal = workout.totalEnergyBurned {
                        return String(format: "%.0f kcal in %.0f min", cal, duration / 60)
                    }
                    return String(format: "%.0f min session", duration / 60)
                }(),
                tip: econScore > 70 ? "Good session volume — contributing to weekly training load"
                    : econScore > 40 ? "Moderate session — every bit of movement counts"
                    : "Short session — try to build duration gradually"
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
