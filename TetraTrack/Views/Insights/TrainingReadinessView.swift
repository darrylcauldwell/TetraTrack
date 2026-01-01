//
//  TrainingReadinessView.swift
//  TetraTrack
//
//  Training readiness dashboard using HealthKit data (HRV, RHR, Sleep, VO2 Max)
//

import SwiftUI
import Charts

struct TrainingReadinessView: View {
    @State private var fitnessMetrics: HealthKitFitnessMetrics?
    @State private var isLoading = true
    @State private var lastRefresh = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading HealthKit data...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let metrics = fitnessMetrics {
                    // Readiness Score Card
                    readinessScoreCard(metrics)

                    // Recovery Metrics Grid
                    recoveryMetricsGrid(metrics)

                    // Resting Heart Rate Trend
                    if !metrics.restingHeartRateTrend.isEmpty {
                        rhrTrendChart(metrics)
                    }

                    // Sleep Analysis
                    if let sleep = metrics.lastNightSleep {
                        sleepCard(sleep)
                    }

                    // VO2 Max Card
                    if let vo2 = metrics.vo2Max {
                        vo2MaxCard(vo2)
                    }

                    // Data freshness
                    Text("Last updated: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    noDataView
                }
            }
            .padding()
        }
        .navigationTitle("Training Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await refreshData()
        }
    }

    // MARK: - Readiness Score Card

    private func readinessScoreCard(_ metrics: HealthKitFitnessMetrics) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gauge.with.needle")
                    .font(.title2)
                    .foregroundStyle(readinessColor(metrics.trainingReadinessScore))
                Text("Training Readiness")
                    .font(.headline)
                Spacer()
            }

            if let score = metrics.trainingReadinessScore {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(readinessColor(score))
                    Text("/ 100")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(metrics.readinessDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Readiness bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(readinessColor(score))
                            .frame(width: geo.size.width * CGFloat(score) / 100)
                    }
                }
                .frame(height: 12)
            } else {
                Text("Insufficient data for readiness score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recovery Metrics Grid

    private func recoveryMetricsGrid(_ metrics: HealthKitFitnessMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // HRV Card
            metricCard(
                icon: "waveform.path.ecg",
                title: "HRV",
                value: metrics.heartRateVariability.map { String(format: "%.0f ms", $0) } ?? "--",
                subtitle: hrvStatus(metrics.heartRateVariability),
                color: hrvColor(metrics.heartRateVariability)
            )

            // Resting HR Card
            metricCard(
                icon: "heart.fill",
                title: "Resting HR",
                value: metrics.restingHeartRate.map { "\($0) bpm" } ?? "--",
                subtitle: rhrStatus(metrics.restingHeartRate),
                color: rhrColor(metrics.restingHeartRate)
            )
        }
    }

    private func metricCard(icon: String, title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - RHR Trend Chart

    private func rhrTrendChart(_ metrics: HealthKitFitnessMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.red)
                Text("Resting Heart Rate Trend")
                    .font(.headline)
            }

            let sortedData = metrics.restingHeartRateTrend.sorted { $0.key < $1.key }

            Chart(sortedData, id: \.key) { item in
                LineMark(
                    x: .value("Date", item.key),
                    y: .value("BPM", item.value)
                )
                .foregroundStyle(.red)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", item.key),
                    y: .value("BPM", item.value)
                )
                .foregroundStyle(.red)
            }
            .frame(height: 150)
            .chartYScale(domain: .automatic(includesZero: false))

            if sortedData.count >= 3 {
                let recent = sortedData.suffix(3).map(\.value)
                let older = sortedData.prefix(3).map(\.value)
                let recentAvg = recent.reduce(0, +) / recent.count
                let olderAvg = older.reduce(0, +) / older.count
                let diff = recentAvg - olderAvg

                HStack {
                    Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(diff > 3 ? .red : (diff < -3 ? .green : .secondary))
                    Text(diff > 3 ? "Elevated - consider recovery" : (diff < -3 ? "Improving fitness" : "Stable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sleep Card

    private func sleepCard(_ sleep: SleepAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.indigo)
                Text("Last Night's Sleep")
                    .font(.headline)
                Spacer()
                Text(sleep.qualityDescription)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sleepQualityColor(sleep).opacity(0.2))
                    .foregroundStyle(sleepQualityColor(sleep))
                    .clipShape(Capsule())
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(String(format: "%.1f hrs", sleep.totalSleepHours))
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Total Sleep")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(String(format: "%.0f%%", sleep.sleepEfficiency))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("Efficiency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Sleep stages
            HStack(spacing: 12) {
                sleepStageIndicator(label: "Deep", hours: sleep.deepHours, color: .indigo)
                sleepStageIndicator(label: "Core", hours: sleep.coreHours, color: .blue)
                sleepStageIndicator(label: "REM", hours: sleep.remHours, color: .cyan)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sleepStageIndicator(label: String, hours: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", hours))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - VO2 Max Card

    private func vo2MaxCard(_ vo2: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundStyle(.orange)
                Text("VO2 Max")
                    .font(.headline)
                Spacer()
                Text(vo2FitnessLevel(vo2))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vo2Color(vo2).opacity(0.2))
                    .foregroundStyle(vo2Color(vo2))
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", vo2))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("mL/kg/min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Cardiorespiratory fitness measured during outdoor runs")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - No Data View

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No HealthKit Data Available")
                .font(.headline)

            Text("Training readiness requires data from Apple Watch:\n• Heart Rate Variability\n• Resting Heart Rate\n• Sleep Analysis\n• VO2 Max")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Health App") {
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Data Loading

    private func refreshData() async {
        isLoading = true
        fitnessMetrics = await HealthKitManager.shared.fetchFitnessMetrics()
        lastRefresh = Date()
        isLoading = false
    }

    // MARK: - Color Helpers

    private func readinessColor(_ score: Int?) -> Color {
        guard let score else { return .secondary }
        switch score {
        case 85...100: return .green
        case 70..<85: return .blue
        case 55..<70: return .yellow
        case 40..<55: return .orange
        default: return .red
        }
    }

    private func hrvStatus(_ hrv: Double?) -> String {
        guard let hrv else { return "No data" }
        switch hrv {
        case 50...: return "Excellent recovery"
        case 35..<50: return "Good recovery"
        case 20..<35: return "Fair"
        default: return "Low - rest advised"
        }
    }

    private func hrvColor(_ hrv: Double?) -> Color {
        guard let hrv else { return .secondary }
        switch hrv {
        case 50...: return .green
        case 35..<50: return .blue
        case 20..<35: return .yellow
        default: return .red
        }
    }

    private func rhrStatus(_ rhr: Int?) -> String {
        guard let rhr else { return "No data" }
        switch rhr {
        case ..<50: return "Athletic"
        case 50..<60: return "Excellent"
        case 60..<70: return "Good"
        case 70..<80: return "Average"
        default: return "Elevated"
        }
    }

    private func rhrColor(_ rhr: Int?) -> Color {
        guard let rhr else { return .secondary }
        switch rhr {
        case ..<60: return .green
        case 60..<70: return .blue
        case 70..<80: return .yellow
        default: return .orange
        }
    }

    private func sleepQualityColor(_ sleep: SleepAnalysis) -> Color {
        switch sleep.qualityDescription {
        case "Excellent": return .green
        case "Good": return .blue
        case "Fair": return .yellow
        default: return .red
        }
    }

    private func vo2FitnessLevel(_ vo2: Double) -> String {
        // Based on general population norms
        switch vo2 {
        case 50...: return "Superior"
        case 42..<50: return "Excellent"
        case 35..<42: return "Good"
        case 30..<35: return "Fair"
        default: return "Below Average"
        }
    }

    private func vo2Color(_ vo2: Double) -> Color {
        switch vo2 {
        case 50...: return .green
        case 42..<50: return .blue
        case 35..<42: return .teal
        case 30..<35: return .yellow
        default: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        TrainingReadinessView()
    }
}
