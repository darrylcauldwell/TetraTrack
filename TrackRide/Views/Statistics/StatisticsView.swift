//
//  StatisticsView.swift
//  TrackRide
//
//  Liquid Glass Design - Statistics Dashboard
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query private var streaks: [TrainingStreak]
    @State private var selectedPeriod: StatisticsPeriod = .allTime
    @State private var aiNarrative: StatisticsNarrative?
    @State private var isLoadingNarrative = false

    // Cached statistics to avoid recalculation on every render
    @State private var statistics: RideStatistics = RideStatistics()
    @State private var weeklyData: [WeeklyDataPoint] = []
    @State private var weeklyTrends: [WeeklyTrendPoint] = []
    @State private var lastRideCount: Int = 0

    private var streak: TrainingStreak? {
        streaks.first
    }

    private func refreshStatistics() {
        statistics = StatisticsManager.calculateStatistics(from: rides, period: selectedPeriod)
        // Only recalculate weekly data if rides changed (not period-dependent)
        if rides.count != lastRideCount {
            weeklyData = StatisticsManager.weeklyBreakdown(from: rides)
            weeklyTrends = StatisticsManager.weeklyTrends(from: rides)
            lastRideCount = rides.count
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                LinearGradient(
                    colors: [
                        AppColors.light,
                        AppColors.primary.opacity(0.03),
                        AppColors.light.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Period Picker with glass styling
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if rides.isEmpty {
                            ContentUnavailableView(
                                "No Ride Data",
                                systemImage: "chart.bar",
                                description: Text("Complete some rides to see your statistics")
                            )
                            .glassCard(material: .ultraThin, cornerRadius: 20, padding: 40)
                            .padding()
                        } else {
                            // AI Narrative Section
                            StatisticsAINarrativeView(
                                statistics: statistics,
                                narrative: aiNarrative,
                                isLoading: isLoadingNarrative,
                                onRefresh: { generateNarrative() }
                            )

                            // Overview Cards
                            OverviewCardsView(statistics: statistics)

                            // Weekly Activity Chart
                            WeeklyActivityChart(data: weeklyData)

                            // Personal Records
                            PersonalRecordsView(statistics: statistics)

                            // Training Streaks
                            StreakStatsView(streak: streak, totalRides: statistics.totalRides)

                            // Gait Analysis
                            GaitAnalysisView(statistics: statistics)

                            // Turn Balance
                            TurnBalanceStatsView(statistics: statistics)

                            // Lead Balance Stats (if has data)
                            if statistics.totalLeadDuration > 0 {
                                LeadBalanceStatsView(statistics: statistics)
                            }

                            // Quality Trends (if has data)
                            if statistics.averageSymmetry > 0 || statistics.averageRhythm > 0 {
                                QualityTrendsView(weeklyTrends: weeklyTrends, statistics: statistics)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Statistics")
            .glassNavigation()
            .onAppear {
                refreshStatistics()
            }
            .onChange(of: selectedPeriod) { _, _ in
                aiNarrative = nil
                refreshStatistics()
            }
            .onChange(of: rides.count) { _, _ in
                refreshStatistics()
            }
        }
    }

    private func generateNarrative() {
        guard !rides.isEmpty else { return }

        isLoadingNarrative = true

        Task {
            if #available(iOS 26.0, *) {
                let service = IntelligenceService.shared
                guard service.isAvailable else {
                    await MainActor.run { isLoadingNarrative = false }
                    return
                }

                do {
                    let stats = await MainActor.run {
                        StatisticsData(
                            periodName: selectedPeriod.rawValue,
                            totalRides: statistics.totalRides,
                            totalDistance: statistics.totalDistance / 1000,
                            totalDurationHours: statistics.totalDuration / 3600,
                            averageDistance: statistics.averageDistance / 1000,
                            averageSpeed: statistics.averageSpeed * 3.6,
                            turnBalancePercent: statistics.turnBalancePercent,
                            leadBalancePercent: statistics.leadBalancePercent,
                            walkPercent: statistics.gaitBreakdown.first { $0.gait == .walk }?.percentage ?? 0,
                            trotPercent: statistics.gaitBreakdown.first { $0.gait == .trot }?.percentage ?? 0,
                            canterPercent: statistics.gaitBreakdown.first { $0.gait == .canter }?.percentage ?? 0,
                            gallopPercent: statistics.gaitBreakdown.first { $0.gait == .gallop }?.percentage ?? 0
                        )
                    }

                    let narrative = try await service.generateStatisticsNarrative(stats: stats)
                    await MainActor.run {
                        aiNarrative = narrative
                        isLoadingNarrative = false
                    }
                } catch {
                    await MainActor.run { isLoadingNarrative = false }
                }
            } else {
                await MainActor.run { isLoadingNarrative = false }
            }
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [Ride.self, LocationPoint.self, GaitSegment.self, TrainingStreak.self], inMemory: true)
}
