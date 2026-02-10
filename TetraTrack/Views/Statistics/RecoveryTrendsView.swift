//
//  RecoveryTrendsView.swift
//  TetraTrack
//
//  Display HRV and fatigue trends over time
//

import SwiftUI
import SwiftData
import Charts

struct RecoveryTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FatigueIndicator.recordedAt, order: .reverse) private var indicators: [FatigueIndicator]

    @State private var showingAddEntry = false
    @State private var timeRange: TimeRange = .week
    @State private var aiInsights: RecoveryInsights?
    @State private var isLoadingInsights = false

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    var filteredIndicators: [FatigueIndicator] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
        return indicators.filter { $0.recordedAt >= cutoff }
    }

    var latestIndicator: FatigueIndicator? {
        indicators.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's readiness
                    if let latest = latestIndicator, Calendar.current.isDateInToday(latest.recordedAt) {
                        ReadinessCard(indicator: latest)
                    } else {
                        // Prompt to add entry
                        VStack(spacing: 12) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 40))
                                .foregroundStyle(AppColors.primary)

                            Text("No entry for today")
                                .font(.headline)

                            Text("Track your readiness to optimize your training")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Add Entry") {
                                showingAddEntry = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // AI Insights Section
                    if let latest = latestIndicator {
                        RecoveryAIInsightsView(
                            indicator: latest,
                            weeklyIndicators: filteredIndicators,
                            insights: aiInsights,
                            isLoading: isLoadingInsights,
                            onRefresh: { generateAIInsights() }
                        )
                    }

                    // Time range picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Readiness trend chart
                    if !filteredIndicators.isEmpty {
                        TrendSection(title: "Readiness Score", icon: "chart.line.uptrend.xyaxis") {
                            Chart(filteredIndicators.reversed()) { indicator in
                                LineMark(
                                    x: .value("Date", indicator.recordedAt),
                                    y: .value("Score", indicator.readinessScore)
                                )
                                .foregroundStyle(AppColors.primary)

                                PointMark(
                                    x: .value("Date", indicator.recordedAt),
                                    y: .value("Score", indicator.readinessScore)
                                )
                                .foregroundStyle(AppColors.primary)
                            }
                            .chartYScale(domain: 0...100)
                            .chartYAxis {
                                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100])
                            }
                            .frame(height: 200)
                            .accessibleChart("Readiness score trend over \(timeRange.rawValue.lowercased()). Average score: \(String(format: "%.0f", averageReadiness)), best score: \(String(format: "%.0f", bestReadiness))")
                        }

                        // HRV trend
                        let hrvData = filteredIndicators.filter { $0.hrvValue > 0 }
                        if !hrvData.isEmpty {
                            TrendSection(title: "HRV (RMSSD)", icon: "waveform.path.ecg") {
                                Chart(hrvData.reversed()) { indicator in
                                    LineMark(
                                        x: .value("Date", indicator.recordedAt),
                                        y: .value("HRV", indicator.hrvValue)
                                    )
                                    .foregroundStyle(.blue)

                                    if indicator.hrvBaseline > 0 {
                                        RuleMark(y: .value("Baseline", indicator.hrvBaseline))
                                            .foregroundStyle(.gray.opacity(0.5))
                                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                                    }
                                }
                                .frame(height: 150)
                            }
                        }

                        // Resting HR trend
                        let rhrData = filteredIndicators.filter { $0.restingHeartRate > 0 }
                        if !rhrData.isEmpty {
                            TrendSection(title: "Resting Heart Rate", icon: "heart.fill") {
                                Chart(rhrData.reversed()) { indicator in
                                    LineMark(
                                        x: .value("Date", indicator.recordedAt),
                                        y: .value("RHR", indicator.restingHeartRate)
                                    )
                                    .foregroundStyle(.red)
                                }
                                .frame(height: 150)
                            }
                        }

                        // Statistics summary
                        TrendSection(title: "Period Summary", icon: "chart.bar.fill") {
                            HStack(spacing: 16) {
                                StatBox(
                                    title: "Avg Readiness",
                                    value: String(format: "%.0f", averageReadiness),
                                    color: readinessColor(averageReadiness)
                                )

                                StatBox(
                                    title: "Best Day",
                                    value: String(format: "%.0f", bestReadiness),
                                    color: .green
                                )

                                StatBox(
                                    title: "Entries",
                                    value: "\(filteredIndicators.count)",
                                    color: AppColors.primary
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Recovery Trends")
            .toolbar {
                Button(action: { showingAddEntry = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                NavigationStack {
                    AddFatigueEntryView()
                }
                .presentationBackground(Color.black)
            }
            .onChange(of: timeRange) { _, _ in
                aiInsights = nil
            }
            .presentationBackground(Color.black)
        }
    }

    private func generateAIInsights() {
        guard let latest = latestIndicator else { return }

        isLoadingInsights = true

        Task {
            if #available(iOS 26.0, *) {
                let service = IntelligenceService.shared
                guard service.isAvailable else {
                    await MainActor.run { isLoadingInsights = false }
                    return
                }

                do {
                    let weeklyAvg = filteredIndicators.isEmpty ? 0 :
                        Double(filteredIndicators.reduce(0) { $0 + $1.readinessScore }) / Double(filteredIndicators.count)

                    let hrvTrend = calculateHRVTrend()
                    let rhrTrend = calculateRHRTrend()
                    let avgSleep = filteredIndicators.isEmpty ? 0 :
                        Double(filteredIndicators.reduce(0) { $0 + $1.sleepQuality }) / Double(filteredIndicators.count)

                    let data = RecoveryData(
                        currentReadiness: latest.readinessScore,
                        weeklyAverageReadiness: weeklyAvg,
                        hrvTrend: hrvTrend,
                        rhrTrend: rhrTrend,
                        avgSleepQuality: avgSleep,
                        fatigueLevel: latest.readinessLabel,
                        daysSinceRest: calculateDaysSinceRest(),
                        weeklyTrainingLoad: filteredIndicators.count
                    )

                    let insights = try await service.analyzeRecovery(data: data)
                    await MainActor.run {
                        aiInsights = insights
                        isLoadingInsights = false
                    }
                } catch {
                    await MainActor.run { isLoadingInsights = false }
                }
            } else {
                await MainActor.run { isLoadingInsights = false }
            }
        }
    }

    private func calculateHRVTrend() -> String {
        let hrvData = filteredIndicators.filter { $0.hrvValue > 0 }
        guard hrvData.count >= 2 else { return "insufficient data" }
        let recent = hrvData.prefix(3).map { $0.hrvValue }.reduce(0, +) / Double(min(3, hrvData.count))
        let older = hrvData.suffix(3).map { $0.hrvValue }.reduce(0, +) / Double(min(3, hrvData.count))
        if recent > older * 1.05 { return "improving" }
        if recent < older * 0.95 { return "declining" }
        return "stable"
    }

    private func calculateRHRTrend() -> String {
        let rhrData = filteredIndicators.filter { $0.restingHeartRate > 0 }
        guard rhrData.count >= 2 else { return "insufficient data" }
        let recent = Double(rhrData.prefix(3).map { $0.restingHeartRate }.reduce(0, +)) / Double(min(3, rhrData.count))
        let older = Double(rhrData.suffix(3).map { $0.restingHeartRate }.reduce(0, +)) / Double(min(3, rhrData.count))
        if recent < older * 0.95 { return "improving" }
        if recent > older * 1.05 { return "elevated" }
        return "stable"
    }

    private func calculateDaysSinceRest() -> Int {
        // Estimate based on consecutive entries
        return min(filteredIndicators.count, 7)
    }

    private var averageReadiness: Double {
        guard !filteredIndicators.isEmpty else { return 0 }
        let total = filteredIndicators.reduce(0) { $0 + $1.readinessScore }
        return Double(total) / Double(filteredIndicators.count)
    }

    private var bestReadiness: Double {
        Double(filteredIndicators.map(\.readinessScore).max() ?? 0)
    }

    private func readinessColor(_ value: Double) -> Color {
        switch value {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct ReadinessCard: View {
    let indicator: FatigueIndicator

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Readiness")
                    .font(.headline)
                Spacer()
                Text(indicator.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: CGFloat(indicator.readinessScore) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(indicator.readinessScore)")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(indicator.readinessLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(indicator.recommendation)
                        .font(.subheadline)

                    if indicator.hrvValue > 0 {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundStyle(.blue)
                            Text("HRV: \(Int(indicator.hrvValue)) ms")
                                .font(.caption)
                        }
                    }

                    if indicator.restingHeartRate > 0 {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text("RHR: \(indicator.restingHeartRate) bpm")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch indicator.readinessScore {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct TrendSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.primary)
                Text(title)
                    .font(.headline)
            }

            content
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AddFatigueEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var hrvValue: Double = 0
    @State private var restingHeartRate: Int = 0
    @State private var sleepQuality: Int = 3
    @State private var perceivedFatigue: Int = 3
    @State private var notes: String = ""

    var body: some View {
        Form {
            Section("Heart Rate Variability") {
                HStack {
                    Text("HRV (RMSSD)")
                    Spacer()
                    TextField("ms", value: $hrvValue, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                Text("Enter your morning HRV reading from your fitness tracker")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Resting Heart Rate") {
                HStack {
                    Text("Morning RHR")
                    Spacer()
                    TextField("bpm", value: $restingHeartRate, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            Section("Subjective Measures") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sleep Quality")
                    Picker("Sleep Quality", selection: $sleepQuality) {
                        Text("Poor").tag(1)
                        Text("Fair").tag(2)
                        Text("Good").tag(3)
                        Text("Very Good").tag(4)
                        Text("Excellent").tag(5)
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Perceived Fatigue")
                    Picker("Perceived Fatigue", selection: $perceivedFatigue) {
                        Text("Very Fresh").tag(1)
                        Text("Fresh").tag(2)
                        Text("Normal").tag(3)
                        Text("Tired").tag(4)
                        Text("Very Tired").tag(5)
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section("Notes") {
                TextField("How are you feeling today?", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .writingToolsBehavior(.complete)
            }
        }
        .navigationTitle("Add Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveEntry()
                }
            }
        }
    }

    private func saveEntry() {
        let indicator = FatigueIndicator()
        indicator.recordedAt = Date()
        indicator.hrvValue = hrvValue
        indicator.restingHeartRate = restingHeartRate
        indicator.sleepQuality = sleepQuality
        indicator.perceivedFatigue = perceivedFatigue
        indicator.notes = notes

        // Set baselines from recent data (simplified - would normally use rolling average)
        indicator.hrvBaseline = hrvValue
        indicator.restingHRBaseline = restingHeartRate

        indicator.calculateReadiness()

        modelContext.insert(indicator)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Recovery AI Insights View

struct RecoveryAIInsightsView: View {
    let indicator: FatigueIndicator
    let weeklyIndicators: [FatigueIndicator]
    let insights: RecoveryInsights?
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("AI Recovery Insights")
                    .font(.headline)

                Spacer()

                if !isLoading {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                    }
                }
            }

            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Analyzing your recovery data...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
            } else if let insights = insights {
                VStack(alignment: .leading, spacing: 12) {
                    // Status badge
                    HStack {
                        Text(insights.status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(statusColor(insights.status).opacity(0.15))
                            .foregroundStyle(statusColor(insights.status))
                            .clipShape(Capsule())

                        Spacer()

                        // Intensity recommendation
                        HStack(spacing: 4) {
                            Text("Suggested intensity:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(insights.suggestedIntensity)/10")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(intensityColor(insights.suggestedIntensity))
                        }
                    }

                    Text(insights.explanation)
                        .font(.subheadline)

                    Text(insights.todayRecommendation)
                        .font(.caption)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if !insights.recoveryTips.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recovery Tips")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            ForEach(insights.recoveryTips, id: \.self) { tip in
                                Label(tip, systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    if !insights.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(insights.warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("Get personalized recovery insights based on your HRV and readiness data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Analyze Recovery", action: onRefresh)
                        .font(.caption)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case let s where s.contains("excellent") || s.contains("optimal"): return .green
        case let s where s.contains("good") || s.contains("ready"): return .blue
        case let s where s.contains("moderate") || s.contains("fair"): return .orange
        case let s where s.contains("low") || s.contains("fatigued"): return .red
        default: return .gray
        }
    }

    private func intensityColor(_ intensity: Int) -> Color {
        switch intensity {
        case 1...3: return .green
        case 4...6: return .blue
        case 7...8: return .orange
        default: return .red
        }
    }
}

#Preview {
    RecoveryTrendsView()
        .modelContainer(for: [FatigueIndicator.self], inMemory: true)
}
