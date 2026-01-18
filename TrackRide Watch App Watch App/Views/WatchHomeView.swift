//
//  WatchHomeView.swift
//  TrackRide Watch App
//
//  Discipline selection view when Watch app is idle
//

import SwiftUI

struct WatchHomeView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService
    @State private var showingTraining = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    // App title
                    Text("TetraTrack")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 4)

                    // Discipline indicators
                    DisciplineRow(
                        title: "Riding",
                        icon: "figure.equestrian.sports",
                        color: .green
                    )

                    DisciplineRow(
                        title: "Running",
                        icon: "figure.run",
                        color: .orange
                    )

                    DisciplineRow(
                        title: "Swimming",
                        icon: "figure.pool.swim",
                        color: .blue
                    )

                    DisciplineRow(
                        title: "Shooting",
                        icon: "target",
                        color: .red
                    )

                    // Training button - can start standalone
                    DisciplineButton(
                        title: "Training",
                        icon: "figure.run.circle",
                        color: .mint
                    ) {
                        showingTraining = true
                    }

                    // Hint
                    Text("Start sessions from iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .navigationDestination(isPresented: $showingTraining) {
                WatchTrainingView()
            }
        }
    }
}

// MARK: - Discipline Row (non-interactive)

struct DisciplineRow: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "iphone")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.darkGray).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Discipline Button

struct DisciplineButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 28)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.darkGray).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WatchHomeView()
        .environment(WatchConnectivityService.shared)
}
