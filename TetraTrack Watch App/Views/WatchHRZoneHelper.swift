//
//  WatchHRZoneHelper.swift
//  TetraTrack Watch App
//
//  Shared HR zone color mapping for Watch views
//

import SwiftUI
import TetraTrackShared

/// Maps HeartRateZone to a SwiftUI Color for Watch views
func watchZoneColor(_ zone: HeartRateZone) -> Color {
    switch zone {
    case .zone1: return .gray
    case .zone2: return .blue
    case .zone3: return .green
    case .zone4: return .orange
    case .zone5: return .red
    }
}
