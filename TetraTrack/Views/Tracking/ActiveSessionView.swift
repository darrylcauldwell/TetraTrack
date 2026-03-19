//
//  ActiveSessionView.swift
//  TetraTrack
//
//  Routes to the correct discipline-specific live view based on the active plugin type.
//  All disciplines are routed equally through this single entry point.
//

import SwiftUI

struct ActiveSessionView: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    var body: some View {
        if let tracker {
            if let _ = tracker.plugin(as: RidingPlugin.self) {
                TrackingView()
            } else if let _ = tracker.plugin(as: WalkingPlugin.self) {
                WalkingLiveView()
            } else if let plugin = tracker.plugin(as: RunningPlugin.self) {
                if plugin.session.sessionType == .treadmill {
                    TreadmillLiveView()
                } else {
                    RunningLiveView()
                }
            } else if let _ = tracker.plugin(as: SwimmingPlugin.self) {
                SwimmingLiveView()
            } else if let _ = tracker.plugin(as: ShootingPlugin.self) {
                ShootingCompetitionView()
            } else {
                ProgressView("Starting session...")
            }
        } else {
            ProgressView("Starting session...")
        }
    }
}
