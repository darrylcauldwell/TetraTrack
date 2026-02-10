//
//  SwimmingTrendsView.swift
//  TetraTrack
//
//  Session-over-session trend analysis for swimming
//

import SwiftUI
import SwiftData
import Charts

struct SwimmingTrendsView: View {
    @Query(sort: \SwimmingSession.startDate, order: .reverse)
    private var allSessions: [SwimmingSession]

    @State private var selectedPeriod: TrendPeriod = .month

    private var filteredSessions: [SwimmingSession] {
        let cutoff: Date
        switch selectedPeriod {
        case .week:
            cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .month:
            cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .threeMonths:
            cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .year:
            cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        case .all:
            return allSessions.filter { $0.totalDistance > 0 }
        }
        return allSessions.filter { $0.startDate >= cutoff && $0.totalDistance > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period filter
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "figure.pool.swim",
                        description: Text("Complete some swimming sessions to see trends.")
                    )
                } else {
                    // Pace trend
                    paceTrendChart
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                    // SWOLF trend
                    swolfTrendChart
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                    // Distance per session
                    distanceChart
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                    // Heart rate trend (if data exists)
                    if filteredSessions.contains(where: { $0.hasHeartRateData }) {
                        heartRateTrendChart
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    }

                    // Summary stats
                    summaryStats
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Swimming Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pace Trend

    private var paceTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pace Trend")
                .font(.headline)

            Chart {
                ForEach(filteredSessions.reversed()) { session in
                    LineMark(
                        x: .value("Date", session.startDate),
                        y: .value("Pace", session.averagePace)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", session.startDate),
                        y: .value("Pace", session.averagePace)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(30)
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let pace = value.as(Double.self) {
                            Text(formatPace(pace))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatDate(date))
                                .font(.caption2)
                        }
                    }
                }
            }

            Text("Lower is faster")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - SWOLF Trend

    private var swolfTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SWOLF Trend")
                .font(.headline)

            let sessionsWithSwolf = filteredSessions.filter { $0.averageSwolf > 0 }

            if sessionsWithSwolf.count >= 2 {
                Chart {
                    ForEach(sessionsWithSwolf.reversed()) { session in
                        LineMark(
                            x: .value("Date", session.startDate),
                            y: .value("SWOLF", session.averageSwolf)
                        )
                        .foregroundStyle(.cyan)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", session.startDate),
                            y: .value("SWOLF", session.averageSwolf)
                        )
                        .foregroundStyle(.cyan)
                        .symbolSize(30)
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatDate(date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                        AxisGridLine()
                    }
                }

                Text("Lower is more efficient")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Need 2+ sessions with lap data for SWOLF trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Distance Chart

    private var distanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Distance per Session")
                .font(.headline)

            Chart {
                ForEach(filteredSessions.reversed()) { session in
                    BarMark(
                        x: .value("Date", session.startDate, unit: .day),
                        y: .value("Distance", session.totalDistance)
                    )
                    .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatDate(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let dist = value.as(Double.self) {
                            Text("\(Int(dist))m")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
        }
    }

    // MARK: - Heart Rate Trend

    private var heartRateTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Heart Rate Trend")
                    .font(.headline)
            }

            let hrSessions = filteredSessions.filter { $0.hasHeartRateData }

            Chart {
                ForEach(hrSessions.reversed()) { session in
                    LineMark(
                        x: .value("Date", session.startDate),
                        y: .value("Avg HR", session.averageHeartRate)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", session.startDate),
                        y: .value("Avg HR", session.averageHeartRate)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(30)
                }
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(formatDate(date))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                    AxisGridLine()
                }
            }
        }
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Period Summary")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SwimMiniStat(
                    title: "Sessions",
                    value: "\(filteredSessions.count)"
                )

                SwimMiniStat(
                    title: "Total Distance",
                    value: String(format: "%.0fm", filteredSessions.reduce(0) { $0 + $1.totalDistance })
                )

                SwimMiniStat(
                    title: "Best Pace",
                    value: bestPace
                )

                SwimMiniStat(
                    title: "Best SWOLF",
                    value: bestSwolf
                )
            }
        }
    }

    private var bestPace: String {
        let paces = filteredSessions.compactMap { session -> TimeInterval? in
            guard session.averagePace > 0 else { return nil }
            return session.averagePace
        }
        guard let best = paces.min() else { return "--:--" }
        return formatPace(best)
    }

    private var bestSwolf: String {
        let swolfs = filteredSessions.compactMap { session -> Double? in
            guard session.averageSwolf > 0 else { return nil }
            return session.averageSwolf
        }
        guard let best = swolfs.min() else { return "--" }
        return String(format: "%.0f", best)
    }

    // MARK: - Formatters

    private func formatPace(_ secondsPer100m: Double) -> String {
        let mins = Int(secondsPer100m) / 60
        let secs = Int(secondsPer100m) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M"
        return formatter.string(from: date)
    }
}

// MARK: - Trend Period

enum TrendPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Mo"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }

    var label: String { rawValue }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SwimmingTrendsView()
            .modelContainer(for: SwimmingSession.self, inMemory: true)
    }
}
