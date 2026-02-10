//
//  InsightsView.swift
//  TetraTrack
//
//  Main Insights hub for AI-powered training analysis
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \RunningSession.startDate, order: .reverse) private var runningSessions: [RunningSession]
    @Query(sort: \SwimmingSession.startDate, order: .reverse) private var swimmingSessions: [SwimmingSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // AI Training Insights
                    AIInsightsView(rides: Array(rides.prefix(30)))
                        .padding(.horizontal)

                    // Quick Stats Summary
                    QuickStatsCard(
                        totalRides: rides.count,
                        totalRuns: runningSessions.count,
                        totalSwims: swimmingSessions.count,
                        thisWeekRides: ridesThisWeek,
                        thisWeekRuns: runsThisWeek,
                        thisWeekSwims: swimsThisWeek
                    )
                    .padding(.horizontal)

                    // Recent Activity Trends
                    if !rides.isEmpty || !runningSessions.isEmpty || !swimmingSessions.isEmpty {
                        RecentActivityCard(
                            recentRides: Array(rides.prefix(5)),
                            recentRuns: Array(runningSessions.prefix(5)),
                            recentSwims: Array(swimmingSessions.prefix(5))
                        )
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .navigationTitle("Insights")
        }
    }

    private var ridesThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return rides.filter { $0.startDate >= weekAgo }.count
    }

    private var runsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return runningSessions.filter { $0.startDate >= weekAgo }.count
    }

    private var swimsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return swimmingSessions.filter { $0.startDate >= weekAgo }.count
    }
}

// MARK: - Quick Stats Card

struct QuickStatsCard: View {
    let totalRides: Int
    let totalRuns: Int
    let totalSwims: Int
    let thisWeekRides: Int
    let thisWeekRuns: Int
    let thisWeekSwims: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("Activity Summary")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                InsightStatBox(
                    icon: "figure.equestrian.sports",
                    color: .green,
                    total: totalRides,
                    thisWeek: thisWeekRides,
                    label: "Rides"
                )

                InsightStatBox(
                    icon: "figure.run",
                    color: .orange,
                    total: totalRuns,
                    thisWeek: thisWeekRuns,
                    label: "Runs"
                )

                InsightStatBox(
                    icon: "figure.pool.swim",
                    color: .blue,
                    total: totalSwims,
                    thisWeek: thisWeekSwims,
                    label: "Swims"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct InsightStatBox: View {
    let icon: String
    let color: Color
    let total: Int
    let thisWeek: Int
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text("\(total)")
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            if thisWeek > 0 {
                Text("+\(thisWeek) this week")
                    .font(.caption2)
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recent Activity Card

struct RecentActivityCard: View {
    let recentRides: [Ride]
    let recentRuns: [RunningSession]
    let recentSwims: [SwimmingSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.orange)
                Text("Recent Activity")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                ForEach(allActivities.prefix(5), id: \.id) { activity in
                    HStack {
                        Image(systemName: activity.icon)
                            .font(.caption)
                            .foregroundStyle(activity.color)
                            .frame(width: 20)

                        Text(activity.name)
                            .font(.subheadline)

                        Spacer()

                        Text(activity.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    private var allActivities: [RecentActivity] {
        var activities: [RecentActivity] = []

        for ride in recentRides {
            activities.append(RecentActivity(
                id: ride.id.uuidString,
                name: ride.name.isEmpty ? "Ride" : ride.name,
                date: ride.startDate,
                icon: "figure.equestrian.sports",
                color: .green
            ))
        }

        for run in recentRuns {
            activities.append(RecentActivity(
                id: run.id.uuidString,
                name: run.name.isEmpty ? "Run" : run.name,
                date: run.startDate,
                icon: "figure.run",
                color: .orange
            ))
        }

        for swim in recentSwims {
            activities.append(RecentActivity(
                id: swim.id.uuidString,
                name: swim.name.isEmpty ? "Swim" : swim.name,
                date: swim.startDate,
                icon: "figure.pool.swim",
                color: .blue
            ))
        }

        return activities.sorted { $0.date > $1.date }
    }
}

struct RecentActivity {
    let id: String
    let name: String
    let date: Date
    let icon: String
    let color: Color
}

#Preview {
    InsightsView()
        .modelContainer(for: [Ride.self, RunningSession.self, SwimmingSession.self], inMemory: true)
}
