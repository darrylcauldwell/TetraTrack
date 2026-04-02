//
//  WatchSessionGuideView.swift
//  TetraTrack
//
//  Reusable guidance view for Watch-primary disciplines.
//  Shown on iPhone to direct user to start sessions on Apple Watch.
//

import SwiftUI

struct WatchSessionGuideView: View {
    let discipline: String
    let icon: String
    let color: Color
    let description: String
    let metrics: [(icon: String, name: String, detail: String)]

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "applewatch")
                .font(.system(size: 56))
                .foregroundStyle(color)

            Text("Start on Apple Watch")
                .font(.title2.bold())

            Text("Open TetraTrack on your Apple Watch and tap \(discipline) to begin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(metrics, id: \.name) { metric in
                    HStack(spacing: 12) {
                        Image(systemName: metric.icon)
                            .font(.title3)
                            .foregroundStyle(color)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.name)
                                .font(.subheadline.weight(.medium))
                            Text(metric.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Text("After your session, review it here with enriched metrics and insights.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
        .navigationTitle(discipline)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Discipline-Specific Instances

struct RunningGuideView: View {
    var body: some View {
        WatchSessionGuideView(
            discipline: "Running",
            icon: "figure.run",
            color: .orange,
            description: "Running session with pace tracking",
            metrics: [
                (icon: "speedometer", name: "min/400m Pace", detail: "Real-time pace per 400 metres"),
                (icon: "heart.fill", name: "Heart Rate", detail: "Live HR with zone tracking"),
                (icon: "point.topleft.down.to.point.bottomright.curvepath", name: "Distance", detail: "GPS distance tracking"),
                (icon: "metronome", name: "Cadence", detail: "Steps per minute")
            ]
        )
    }
}

struct SwimmingGuideView: View {
    var body: some View {
        WatchSessionGuideView(
            discipline: "Swimming",
            icon: "figure.pool.swim",
            color: .cyan,
            description: "Swimming session with lap counting",
            metrics: [
                (icon: "arrow.triangle.2.circlepath", name: "Lap Count", detail: "Automatic lap detection"),
                (icon: "heart.fill", name: "Heart Rate", detail: "Live HR with zone tracking"),
                (icon: "hands.clap", name: "Stroke Count", detail: "Total strokes tracked"),
                (icon: "ruler", name: "Distance", detail: "Based on pool length and laps")
            ]
        )
    }
}

struct WalkingGuideView: View {
    var body: some View {
        WatchSessionGuideView(
            discipline: "Walking",
            icon: "figure.walk",
            color: .yellow,
            description: "Walking session with cadence tracking",
            metrics: [
                (icon: "metronome", name: "Steps/min", detail: "Real-time cadence from Watch sensors"),
                (icon: "heart.fill", name: "Heart Rate", detail: "Live HR with zone tracking"),
                (icon: "point.topleft.down.to.point.bottomright.curvepath", name: "Distance", detail: "GPS distance tracking"),
                (icon: "mountain.2", name: "Elevation", detail: "Elevation gain from barometer")
            ]
        )
    }
}
