//
//  ContentView.swift
//  TetraTrack
//
//  Created by Darryl Cauldwell on 01/01/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(SessionTracker.self) private var sessionTracker: SessionTracker?
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        Group {
            if viewContext.canCapture, let tracker = sessionTracker {
                if tracker.sessionState.isActive {
                    // Active session in progress
                    ActiveSessionView()
                } else if tracker.sessionState == .completed,
                          let info = tracker.completedSessionInfo {
                    // Session just ended — show post-session insights
                    PostSessionInsightsView(info: info)
                } else {
                    DisciplinesView()
                }
            } else {
                DisciplinesView()
            }
        }
    }
}

#Preview {
    let locManager = LocationManager()
    let gpsTracker = GPSSessionTracker(locationManager: locManager)
    ContentView()
        .environment(locManager)
        .environment(gpsTracker)
        .environment(SessionTracker(locationManager: locManager, gpsTracker: gpsTracker))
        .modelContainer(for: [Ride.self, LocationPoint.self, GaitSegment.self, FlatworkExercise.self], inMemory: true)
}
