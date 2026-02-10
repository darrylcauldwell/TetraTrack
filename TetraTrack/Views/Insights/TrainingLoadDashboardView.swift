//
//  TrainingLoadDashboardView.swift
//  TetraTrack
//
//  Performance Management Chart (PMC) showing CTL/ATL/TSB training load
//

import SwiftUI
import SwiftData
import Charts

struct TrainingLoadDashboardView: View {
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runs: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swims: [SwimmingSession]
    @Query(sort: \ShootingSession.startDate, order: .reverse) private var shoots: [ShootingSession]

    private var dailyTSS: [TrainingLoadService.DailyTSS] {
        TrainingLoadService.computeDailyTSS(
            rides: rides,
            runs: runs,
            swims: swims,
            shoots: shoots,
            days: 90
        )
    }

    private var pmcData: [TrainingLoadService.PMCData] {
        TrainingLoadService.computePMC(dailyTSS: dailyTSS)
    }

    private var currentForm: TrainingLoadService.FormStatus {
        guard let latest = pmcData.last else { return .optimal }
        return TrainingLoadService.formStatus(tsb: latest.tsb)
    }

    private var weeklyData: [(week: String, riding: Double, running: Double, swimming: Double, shooting: Double)] {
        TrainingLoadService.weeklyLoadSummary(dailyTSS: dailyTSS)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Form status card
                formStatusCard

                // PMC chart
                pmcChart

                // Weekly load breakdown
                weeklyLoadChart

                // Current stats
                currentStatsGrid
            }
            .padding()
        }
        .navigationTitle("Training Load")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Form Status Card

    private var formStatusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: currentForm.icon)
                .font(.largeTitle)
                .foregroundStyle(currentForm.color)

            VStack(alignment: .leading, spacing: 4) {
                Text("Current Form")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentForm.rawValue)
                    .font(.title2.weight(.bold))

                if let latest = pmcData.last {
                    Text("TSB: \(String(format: "%.0f", latest.tsb))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let latest = pmcData.last {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 6, height: 6)
                        Text("CTL: \(String(format: "%.0f", latest.ctl))")
                            .font(.caption)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.red).frame(width: 6, height: 6)
                        Text("ATL: \(String(format: "%.0f", latest.atl))")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(currentForm.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - PMC Chart

    private var pmcChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Management Chart")
                .font(.headline)

            if pmcData.count >= 2 {
                Chart {
                    ForEach(pmcData) { data in
                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("CTL", data.ctl),
                            series: .value("Metric", "Fitness (CTL)")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("ATL", data.atl),
                            series: .value("Metric", "Fatigue (ATL)")
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        LineMark(
                            x: .value("Date", data.date),
                            y: .value("TSB", data.tsb),
                            series: .value("Metric", "Form (TSB)")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    }

                    // Zero line for TSB
                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                .chartYAxisLabel("TSS")
                .frame(height: 200)
            } else {
                Text("Need more training data to show trends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                    Text("Fitness (CTL)").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("Fatigue (ATL)").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Rectangle().fill(.green).frame(width: 12, height: 2)
                    Text("Form (TSB)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Load Chart

    private var weeklyLoadChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Load by Discipline")
                .font(.headline)

            if !weeklyData.isEmpty {
                Chart {
                    ForEach(weeklyData, id: \.week) { week in
                        if week.riding > 0 {
                            BarMark(
                                x: .value("Week", week.week),
                                y: .value("TSS", week.riding)
                            )
                            .foregroundStyle(by: .value("Discipline", "Riding"))
                        }
                        if week.running > 0 {
                            BarMark(
                                x: .value("Week", week.week),
                                y: .value("TSS", week.running)
                            )
                            .foregroundStyle(by: .value("Discipline", "Running"))
                        }
                        if week.swimming > 0 {
                            BarMark(
                                x: .value("Week", week.week),
                                y: .value("TSS", week.swimming)
                            )
                            .foregroundStyle(by: .value("Discipline", "Swimming"))
                        }
                        if week.shooting > 0 {
                            BarMark(
                                x: .value("Week", week.week),
                                y: .value("TSS", week.shooting)
                            )
                            .foregroundStyle(by: .value("Discipline", "Shooting"))
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Riding": Color.brown,
                    "Running": Color.green,
                    "Swimming": Color.blue,
                    "Shooting": Color.purple
                ])
                .frame(height: 150)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Current Stats Grid

    private var currentStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let latest = pmcData.last {
                TrainingLoadStatCard(title: "Fitness (CTL)", value: String(format: "%.0f", latest.ctl), color: .blue)
                TrainingLoadStatCard(title: "Fatigue (ATL)", value: String(format: "%.0f", latest.atl), color: .red)
                TrainingLoadStatCard(title: "Form (TSB)", value: String(format: "%.0f", latest.tsb), color: .green)

                let todayTSS = dailyTSS.last?.totalTSS ?? 0
                TrainingLoadStatCard(title: "Today's TSS", value: String(format: "%.0f", todayTSS), color: .orange)
            }
        }
    }
}

// MARK: - Training Load Stat Card

private struct TrainingLoadStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        TrainingLoadDashboardView()
    }
}
