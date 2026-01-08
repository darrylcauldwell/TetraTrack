//
//  ContentView.swift
//  TrackRide
//
//  Created by Darryl Cauldwell on 01/01/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(RideTracker.self) private var rideTracker: RideTracker?

    var body: some View {
        Group {
            // If there's an active ride session, show TrackingView directly
            if let tracker = rideTracker, tracker.rideState.isActive {
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
