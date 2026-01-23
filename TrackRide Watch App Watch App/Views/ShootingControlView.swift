//
//  ShootingControlView.swift
//  TrackRide Watch App
//
//  DEPRECATED in Phase 2: Watch is companion-only
//  Session capture has been moved to iPhone
//  This view is kept for backwards compatibility only
//

import SwiftUI

/// DEPRECATED: Shooting control has been removed in Phase 2
/// Watch app now shows glanceable insights only
/// Session capture must be done from iPhone
@available(*, deprecated, message: "Use WatchHomeView for the glanceable dashboard instead")
struct ShootingControlView: View {
    var body: some View {
        // This view should not be displayed in Phase 2
        // Redirect to home dashboard if somehow reached
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.largeTitle)
                .foregroundStyle(WatchAppColors.shooting)

            Text("Session Control Moved")
                .font(.headline)

            Text("Start and control shooting from your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Watch shows insights only")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    ShootingControlView()
}
