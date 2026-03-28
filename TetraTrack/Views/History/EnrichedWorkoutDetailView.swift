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
import Photos
import CoreLocation

struct EnrichedWorkoutDetailView: View {
    let workout: ExternalWorkout

    @State private var enrichment: WorkoutEnrichment?
    @State private var insights: [WorkoutInsight] = []
    @State private var photos: [PHAsset] = []
    @State private var isLoading = true

    private let photoService = RidePhotoService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                summaryStats

                if !insights.isEmpty {
                    insightsSection
                }

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
                        }

                        if let metrics = enrichment.cyclingMetrics {
                            cyclingMetricsSection(metrics)
                        }

                        // Show HR zone summary for types without specific metrics
                        if enrichment.walkingMetrics == nil &&
                           enrichment.runningMetrics == nil &&
                           enrichment.swimmingMetrics == nil &&
                           enrichment.cyclingMetrics == nil,
                           let general = enrichment.generalMetrics {
                            heartRateZoneSummary(general)
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
            .padding()
        }
        .navigationTitle(workout.activityName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
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

    private func heartRateZoneSummary(_ metrics: WorkoutEnrichment.GeneralMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Summary")
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

        // Fetch enrichment and photos concurrently
        async let enrichTask = WorkoutEnrichmentService.shared.enrich(
            workoutId: workout.id,
            startDate: workout.startDate,
            endDate: workout.endDate,
            activityType: workout.activityType
        )

        async let photosTask = loadPhotos()

        enrichment = await enrichTask
        photos = await photosTask

        // Generate insights after enrichment is loaded
        if let enrichment {
            insights = await WorkoutInsightsGenerator.shared.generateInsights(
                for: workout,
                enrichment: enrichment
            )
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
