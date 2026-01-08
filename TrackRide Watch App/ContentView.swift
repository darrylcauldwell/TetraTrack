//
//  ContentView.swift
//  TrackRide Watch App
//
//  Main watch app view
//

import SwiftUI

struct ContentView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @Environment(WatchConnectivityService.self) private var connectivityService

    var body: some View {
        TabView {
            RideControlView()

            HeartRateRingView()
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    ContentView()
        .environment(WorkoutManager())
        .environment(WatchConnectivityService.shared)
}
