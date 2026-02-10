//
//  WatchTrainingView.swift
//  TetraTrack Watch App
//
//  DEPRECATED in Phase 2: Watch is companion-only
//  Standalone training drills have been removed
//  This view is kept for backwards compatibility only
//

import SwiftUI

/// DEPRECATED: Standalone training drills removed in Phase 2
/// Watch app now shows glanceable insights only
/// Training must be done from iPhone
@available(*, deprecated, message: "Use WatchHomeView for the glanceable dashboard instead")
struct WatchTrainingView: View {
    var body: some View {
        // This view should not be displayed in Phase 2
        // Redirect to home dashboard if somehow reached
        VStack(spacing: 12) {
            Image(systemName: "figure.mixed.cardio")
                .font(.largeTitle)
                .foregroundStyle(WatchAppColors.primary)

            Text("Training Moved")
                .font(.headline)

            Text("Start training drills from your iPhone")
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
    WatchTrainingView()
}
