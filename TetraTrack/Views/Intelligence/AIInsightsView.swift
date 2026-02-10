//
//  AIInsightsView.swift
//  TetraTrack
//
//  SwiftUI view for displaying AI-powered training insights
//

import SwiftUI

// MARK: - AI Insights View

struct AIInsightsView: View {
    @State private var isLoading = false
    @State private var insights: TrainingInsights?
    @State private var recommendations: [TrainingRecommendation] = []
    @State private var errorMessage: String?
    @State private var showUnavailableAlert = false

    let rides: [Ride]

    /// Check if Apple Intelligence is available on this device
    private var isAppleIntelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return IntelligenceService.shared.isAvailable
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if !isAppleIntelligenceAvailable {
                unavailableView
            } else if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let insights = insights {
                insightsContent(insights)
            } else {
                placeholderView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .alert("Apple Intelligence Required", isPresented: $showUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("AI insights require an iPhone 15 Pro or later with iOS 26 or newer.")
        }
        .onAppear {
            // Auto-generate insights when view appears with rides (only if AI available)
            if isAppleIntelligenceAvailable && insights == nil && !rides.isEmpty && !isLoading {
                generateInsights()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "apple.intelligence")
                .font(.title2)
                .foregroundStyle(.purple)

            Text("Apple Intelligence Insights")
                .font(.headline)

            Spacer()

            // Only show refresh button if Apple Intelligence is available
            if isAppleIntelligenceAvailable && !isLoading {
                Button {
                    generateInsights()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                }
                .disabled(rides.isEmpty)
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Analyzing your training...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title)
                .foregroundStyle(.purple.opacity(0.6))

            Text("Tap refresh to generate AI-powered insights about your training")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "apple.intelligence")
                .font(.largeTitle)
                .foregroundStyle(.gray.opacity(0.5))

            Text("Apple Intelligence Not Available")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text("Apple Intelligence insights require iPhone 15 Pro or later with iOS 26 and Apple Intelligence enabled in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Insights Content

    private func insightsContent(_ insights: TrainingInsights) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trend Badge
            trendBadge(insights.trend)

            // Observations
            if !insights.observations.isEmpty {
                insightSection(title: "Observations", items: insights.observations, icon: "eye", color: .blue)
            }

            // Strengths
            if !insights.strengths.isEmpty {
                insightSection(title: "Strengths", items: insights.strengths, icon: "star.fill", color: .yellow)
            }

            // Areas for Improvement
            if !insights.areasForImprovement.isEmpty {
                insightSection(title: "Focus Areas", items: insights.areasForImprovement, icon: "target", color: .orange)
            }

            // Balance Assessment
            if !insights.balanceAssessment.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Balance", systemImage: "scale.3d")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    Text(insights.balanceAssessment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Recommendations Section
            if !recommendations.isEmpty {
                recommendationsSection
            }
        }
    }

    private func trendBadge(_ trend: String) -> some View {
        HStack {
            Image(systemName: trendIcon(for: trend))
            Text(trend.capitalized)
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(trendColor(for: trend).opacity(0.15))
        .foregroundStyle(trendColor(for: trend))
        .clipShape(Capsule())
    }

    private func trendIcon(for trend: String) -> String {
        switch trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "maintaining": return "arrow.right"
        case "declining": return "arrow.down.right"
        default: return "minus"
        }
    }

    private func trendColor(for trend: String) -> Color {
        switch trend.lowercased() {
        case "improving": return .green
        case "maintaining": return .blue
        case "declining": return .orange
        default: return .gray
        }
    }

    private func insightSection(title: String, items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(color)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recommendations", systemImage: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(.purple)

            ForEach(recommendations) { rec in
                RecommendationCard(recommendation: rec)
            }
        }
    }

    // MARK: - Actions

    private func generateInsights() {
        guard !rides.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                if #available(iOS 26.0, *) {
                    let service = IntelligenceService.shared

                    guard service.isAvailable else {
                        // Fallback to sample insights when AI unavailable
                        self.insights = generateSampleInsights()
                        self.recommendations = generateSampleRecommendations()
                        self.isLoading = false
                        return
                    }

                    async let insightsTask = service.analyzeTrainingPatterns(rides: rides)
                    async let recsTask = service.generateRecommendations(recentRides: rides, goals: nil)

                    let (fetchedInsights, fetchedRecs) = try await (insightsTask, recsTask)

                    self.insights = fetchedInsights
                    self.recommendations = fetchedRecs
                    self.isLoading = false
                } else {
                    // Fallback for iOS versions before 26
                    self.insights = generateSampleInsights()
                    self.recommendations = generateSampleRecommendations()
                    self.isLoading = false
                }
            } catch {
                // Fallback on error - show sample data rather than error
                self.insights = generateSampleInsights()
                self.recommendations = generateSampleRecommendations()
                self.isLoading = false
            }
        }
    }

    // MARK: - Sample Data (when AI unavailable)

    private func generateSampleInsights() -> TrainingInsights {
        // Generate insights based on actual ride data
        let totalRides = rides.count
        let avgDistance = rides.isEmpty ? 0 : rides.reduce(0) { $0 + $1.totalDistance } / Double(totalRides)
        let avgBalance = rides.isEmpty ? 50 : rides.reduce(0) { $0 + $1.turnBalancePercent } / totalRides

        let trend: String
        if totalRides >= 3 {
            let recentAvg = rides.prefix(3).reduce(0) { $0 + $1.totalDistance } / 3
            let olderAvg = rides.dropFirst(3).prefix(3).reduce(0) { $0 + $1.totalDistance } / max(1, Double(min(3, rides.count - 3)))
            trend = recentAvg > olderAvg ? "improving" : recentAvg < olderAvg ? "maintaining" : "maintaining"
        } else {
            trend = "maintaining"
        }

        var observations: [String] = []
        if totalRides > 0 {
            observations.append("You've completed \(totalRides) rides recently - great consistency!")
        }
        if avgDistance > 5000 {
            observations.append("Your average ride distance of \(String(format: "%.1f", avgDistance / 1000)) km shows excellent endurance")
        }

        var strengths: [String] = []
        if abs(avgBalance - 50) < 10 {
            strengths.append("Well-balanced turn distribution between left and right")
        }
        if rides.contains(where: { $0.rideType == .crossCountry }) {
            strengths.append("Cross-country experience building confidence")
        }
        if rides.contains(where: { $0.rideType == .schooling }) {
            strengths.append("Regular flatwork sessions improving technique")
        }

        var improvements: [String] = []
        if avgBalance > 60 {
            improvements.append("Consider more right turns to balance your training")
        } else if avgBalance < 40 {
            improvements.append("Consider more left turns to balance your training")
        }
        if !rides.contains(where: { $0.rideType == .crossCountry }) {
            improvements.append("Add some cross-country sessions for variety")
        }

        let balanceAssessment = abs(avgBalance - 50) < 10
            ? "Excellent balance between left and right work"
            : "Consider working on \(avgBalance > 50 ? "right-hand" : "left-hand") turns"

        return TrainingInsights(
            trend: trend,
            observations: observations.isEmpty ? ["Keep up the great work with your training!"] : observations,
            strengths: strengths.isEmpty ? ["Consistent training schedule"] : strengths,
            areasForImprovement: improvements.isEmpty ? ["Maintain current training balance"] : improvements,
            balanceAssessment: balanceAssessment
        )
    }

    private func generateSampleRecommendations() -> [TrainingRecommendation] {
        var recs: [TrainingRecommendation] = []

        // Recommend based on what's missing from recent rides
        let rideTypes = Set(rides.map { $0.rideType })

        if !rideTypes.contains(.schooling) {
            recs.append(TrainingRecommendation(
                title: "Flatwork Session",
                description: "Focus on transitions and bend work to improve suppleness",
                durationMinutes: 45,
                priority: "medium",
                focusArea: "technique"
            ))
        }

        if !rideTypes.contains(.hack) {
            recs.append(TrainingRecommendation(
                title: "Trail Ride",
                description: "A relaxed hack to build confidence and fitness",
                durationMinutes: 60,
                priority: "low",
                focusArea: "fitness"
            ))
        }

        recs.append(TrainingRecommendation(
            title: "Balance Exercise",
            description: "Work on serpentines and figure-8s to improve symmetry",
            durationMinutes: 30,
            priority: "high",
            focusArea: "balance"
        ))

        return recs
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: TrainingRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(recommendation.title)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("\(recommendation.durationMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(recommendation.description)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                priorityBadge
                Spacer()
                focusBadge
            }
        }
        .padding(10)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var priorityBadge: some View {
        Text(recommendation.priority.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.15))
            .foregroundStyle(priorityColor)
            .clipShape(Capsule())
    }

    private var priorityColor: Color {
        switch recommendation.priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .gray
        }
    }

    private var focusBadge: some View {
        Text(recommendation.focusArea)
            .font(.caption2)
            .foregroundStyle(.purple)
    }
}

// MARK: - Ride Summary AI View

struct RideSummaryAIView: View {
    let ride: Ride
    @State private var summary: RideSummary?
    @State private var isLoading = false
    @State private var showUnavailable = false

    /// Check if Apple Intelligence is available on this device
    private var isAppleIntelligenceAvailable: Bool {
        if #available(iOS 26.0, *) {
            return IntelligenceService.shared.isAvailable
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(.purple)
                Text("Apple Intelligence Summary")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating summary...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let summary = summary {
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.headline)
                        .font(.subheadline)

                    if !summary.achievements.isEmpty {
                        ForEach(summary.achievements, id: \.self) { achievement in
                            Label(achievement, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    if !summary.improvements.isEmpty {
                        ForEach(summary.improvements, id: \.self) { improvement in
                            Label(improvement, systemImage: "arrow.up.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(summary.encouragement)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()

                    ratingStars(summary.rating)
                }
            } else if isAppleIntelligenceAvailable {
                Button("Generate Summary") {
                    generateSummary()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            } else {
                Text("Requires iPhone 15 Pro or later with Apple Intelligence enabled")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Apple Intelligence Required", isPresented: $showUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This feature requires iOS 26 on iPhone 15 Pro or later.")
        }
    }

    private func ratingStars(_ rating: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
            }
        }
    }

    private func generateSummary() {
        isLoading = true

        Task {
            if #available(iOS 26.0, *) {
                let service = IntelligenceService.shared
                guard service.isAvailable else {
                    await MainActor.run {
                        showUnavailable = true
                        isLoading = false
                    }
                    return
                }

                do {
                    let result = try await service.summarizeRide(ride)
                    await MainActor.run {
                        summary = result
                        isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    showUnavailable = true
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AIInsightsView(rides: [])
        .padding()
}
