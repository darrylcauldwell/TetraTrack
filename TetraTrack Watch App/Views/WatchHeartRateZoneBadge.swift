//
//  WatchHeartRateZoneBadge.swift
//  TetraTrack Watch App
//
//  Reusable heart rate + zone badge, extracted from discipline views.
//

import SwiftUI
import TetraTrackShared

struct WatchHeartRateZoneBadge: View {
    let heartRate: Int
    let maxHR: Int = 180

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text(heartRate > 0 ? "\(heartRate)" : "\u{2013}")
                    .font(.headline)
            }
            if heartRate > 0 {
                let zone = HeartRateZone.zone(for: heartRate, maxHR: maxHR)
                Text(zone.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(watchZoneColor(zone))
                    .clipShape(Capsule())
            } else {
                Text("bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
