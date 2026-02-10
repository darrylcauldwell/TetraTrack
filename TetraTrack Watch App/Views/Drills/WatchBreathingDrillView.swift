//
//  WatchBreathingDrillView.swift
//  TetraTrack Watch App
//
//  DEPRECATED in Phase 2: Watch is companion-only
//  Standalone drills have been moved to iPhone
//  This view is kept for backwards compatibility only
//

import SwiftUI

/// DEPRECATED: Breathing drill has been removed in Phase 2
/// Watch app now shows glanceable insights only
/// Training drills must be done from iPhone
@available(*, deprecated, message: "Use iPhone app for training drills instead")
struct WatchBreathingDrillView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wind")
                .font(.largeTitle)
                .foregroundStyle(WatchAppColors.drillBreathing)

            Text("Drills Moved")
                .font(.headline)

            Text("Start training drills from your iPhone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

#Preview {
    WatchBreathingDrillView()
}
