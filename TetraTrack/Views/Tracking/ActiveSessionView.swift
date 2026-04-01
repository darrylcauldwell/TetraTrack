//
//  ActiveSessionView.swift
//  TetraTrack
//
//  Routes to the correct discipline-specific live view based on the active plugin type.
//  Riding is Watch-primary — only shooting uses iPhone-based session tracking.
//

import SwiftUI

struct ActiveSessionView: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    var body: some View {
        if let tracker {
            if let _ = tracker.plugin(as: ShootingPlugin.self) {
                ShootingPracticeView()
            } else {
                ProgressView("Starting session...")
            }
        } else {
            ProgressView("Starting session...")
        }
    }
}
