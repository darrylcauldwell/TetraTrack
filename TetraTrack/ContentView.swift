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
        .alert("Watch Notice",
               isPresented: Binding(
                   get: { sessionTracker?.sessionStartError != nil },
                   set: { if !$0 { sessionTracker?.sessionStartError = nil } }
               )) {
            Button("OK") { sessionTracker?.sessionStartError = nil }
        } message: {
            if let diag = sessionTracker?.watchDiagnostics {
                Text((sessionTracker?.sessionStartError ?? "") + "\n\nWatch log:\n" + diag)
            } else {
                Text(sessionTracker?.sessionStartError ?? "")
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
        .modelContainer(for: [Ride.self, GPSPoint.self, GaitSegment.self, FlatworkExercise.self], inMemory: true)
}
