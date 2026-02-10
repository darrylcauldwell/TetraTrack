//
//  ContentView.swift
//  TetraTrack
//
//  Created by Darryl Cauldwell on 01/01/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(RideTracker.self) private var rideTracker: RideTracker?
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        Group {
            // iPad review-only mode: always show DisciplinesView (no tracking)
            // iPhone: show TrackingView if there's an active ride session
            if viewContext.canCapture,
               let tracker = rideTracker,
               tracker.rideState.isActive {
                TrackingView()
            } else {
                DisciplinesView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(LocationManager())
        .environment(RideTracker(locationManager: LocationManager()))
        .modelContainer(for: [Ride.self, LocationPoint.self, GaitSegment.self, FlatworkExercise.self], inMemory: true)
}
