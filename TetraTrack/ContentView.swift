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
            // iPad review-only mode: always show DisciplinesView (no tracking)
            // iPhone: show TrackingView if there's an active session
            if viewContext.canCapture,
               let tracker = sessionTracker,
               tracker.sessionState.isActive {
                TrackingView()
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
