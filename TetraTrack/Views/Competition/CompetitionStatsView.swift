//
//  CompetitionStatsView.swift
//  TetraTrack
//
//  Statistics and personal bests for triathlon/tetrathlon competitions
//

import SwiftUI
import SwiftData
import Charts

struct CompetitionStatsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Competition.date, order: .reverse) private var competitions: [Competition]
    @State private var selectedPeriod: StatisticsPeriod = .allTime
    @State private var selectedType: CompetitionTypeFilter = .all
    @State private var statistics: CompetitionStatistics = CompetitionStatistics()

    // Apple Intelligence insights
    @State private var performanceSummary: CompetitionPerformanceSummary?
    @State private var trendAnalysis: CompetitionTrendAnalysis?
    @State private var weatherAnalysis: WeatherImpactAnalysis?
    @State private var isLoadingInsights = false
    @State private var insightsError: String?
    @State private var isAppleIntelligenceAvailable = false

    private func refreshStatistics() {
        statistics = CompetitionStatisticsManager.calculateStatistics(
            from: competitions,
            period: selectedPeriod,
            typeFilter: selectedType
        )
    }

    var body: some View {
        ZStack {
            // Pure black background
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Period Picker
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Competition Type Filter
                    CompetitionTypeFilterView(selectedType: $selectedType)

                    if statistics.completedCompetitions == 0 {
                        emptyStateView
                    } else if horizontalSizeClass == .regular {
                        iPadContent
                    } else {
                        iPhoneContent
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Competition Stats")
        .glassNavigation()
        .onAppear {
            refreshStatistics()
        }
        .task {
            if #available(iOS 26.0, *) {
                // Check if Apple Intelligence is available on this device
                isAppleIntelligenceAvailable = IntelligenceService.shared.isAvailable
                if isAppleIntelligenceAvailable {
                    await loadInsights()
                }
            }
        }
        .onChange(of: selectedPeriod) { _, _ in
            refreshStatistics()
        }
        .onChange(of: selectedType) { _, _ in
            refreshStatistics()
        }
        .onChange(of: competitions.count) { _, _ in
            refreshStatistics()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Completed Competitions",
            systemImage: "chart.bar",
            description: Text("Complete some triathlon or tetrathlon competitions to see your statistics")
        )
        .glassCard(material: .ultraThin, cornerRadius: 20, padding: 40)
        .padding()
    }

    // MARK: - iPad Layout (Side-by-Side)

    private var iPadContent: some View {
        VStack(spacing: Spacing.xl) {
            // Apple Intelligence Insights Section (full width)
            if #available(iOS 26.0, *), isAppleIntelligenceAvailable {
                CompetitionInsightsSection(
                    performanceSummary: performanceSummary,
                    trendAnalysis: trendAnalysis,
                    weatherAnalysis: weatherAnalysis,
                    isLoading: isLoadingInsights,
                    error: insightsError,
                    onRefresh: { await loadInsights() }
                )
            }

            // Side-by-side layout: Overview + Personal Bests | Charts
            HStack(alignment: .top, spacing: Spacing.xl) {
                // Left column: Overview and Personal Bests
                VStack(spacing: Spacing.lg) {
                    CompetitionOverviewCards(statistics: statistics)
                    CompetitionPersonalBestsView(statistics: statistics)
                }
                .frame(width: 380)

                // Right column: Charts
                VStack(spacing: Spacing.lg) {
                    if statistics.trendPoints.count >= 2 {
                        CompetitionTrendChart(trendPoints: statistics.trendPoints)
                    }
                    DisciplineBreakdownChart(statistics: statistics)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - iPhone Layout (Vertical)

    private var iPhoneContent: some View {
        VStack(spacing: 24) {
            // Apple Intelligence Insights Section - only show if available
            if #available(iOS 26.0, *), isAppleIntelligenceAvailable {
                CompetitionInsightsSection(
                    performanceSummary: performanceSummary,
                    trendAnalysis: trendAnalysis,
                    weatherAnalysis: weatherAnalysis,
                    isLoading: isLoadingInsights,
                    error: insightsError,
                    onRefresh: { await loadInsights() }
                )
            }

            // Overview Cards
            CompetitionOverviewCards(statistics: statistics)

            // Personal Bests Section
            CompetitionPersonalBestsView(statistics: statistics)

            // Points Trend Chart
            if statistics.trendPoints.count >= 2 {
                CompetitionTrendChart(trendPoints: statistics.trendPoints)
            }

            // Discipline Breakdown
            DisciplineBreakdownChart(statistics: statistics)
        }
    }

    // MARK: - Apple Intelligence

    @available(iOS 26.0, *)
    private func loadInsights() async {
        guard statistics.completedCompetitions >= 1 else { return }
        guard !isLoadingInsights else { return }

        isLoadingInsights = true
        insightsError = nil

        let service = IntelligenceService.shared
        guard service.isAvailable else {
            insightsError = "Apple Intelligence not available"
            isLoadingInsights = false
            return
        }

        // Load insights concurrently
        await withTaskGroup(of: Void.self) { group in
            // Performance Summary
            group.addTask {
                do {
                    let summary = try await service.generateCompetitionPerformanceSummary(stats: statistics)
                    await MainActor.run { performanceSummary = summary }
                } catch {
                    await MainActor.run { insightsError = error.localizedDescription }
                }
            }

            // Trend Analysis (needs 2+ competitions)
            if statistics.completedCompetitions >= 2 {
                group.addTask {
                    do {
                        let trends = try await service.analyzeCompetitionTrends(competitions: competitions)
                        await MainActor.run { trendAnalysis = trends }
                    } catch {
                        // Silent fail for optional insight
                    }
                }
            }

            // Weather Impact (needs competitions with weather data)
            let compsWithWeather = competitions.filter { $0.isCompleted && $0.hasWeatherData }
            if compsWithWeather.count >= 2 {
                group.addTask {
                    do {
                        let weather = try await service.analyzeWeatherImpact(competitions: competitions)
                        await MainActor.run { weatherAnalysis = weather }
                    } catch {
                        // Silent fail for optional insight
                    }
                }
            }
        }

        isLoadingInsights = false
    }
}

#Preview {
    NavigationStack {
        CompetitionStatsView()
            .modelContainer(for: [Competition.self], inMemory: true)
    }
}
