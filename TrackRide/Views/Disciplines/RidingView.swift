//
//  RidingView.swift
//  TrackRide
//
//  Riding discipline - track rides and off-horse training drills
//

import SwiftUI

struct RidingView: View {
    @State private var showingTraining = false
    @State private var showingTracking = false
    @State private var showingRoutePlanner = false

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Track Ride",
                subtitle: "GPS & gait tracking",
                icon: "location.fill",
                color: .green,
                action: { showingTracking = true }
            ),
            DisciplineMenuItem(
                title: "Training",
                subtitle: "Off-horse drills",
                icon: "figure.stand",
                color: AppColors.primary,
                action: { showingTraining = true }
            ),
            DisciplineMenuItem(
                title: "Plan Route",
                subtitle: "Bridleways & trails",
                icon: "map.fill",
                color: .orange,
                action: { showingRoutePlanner = true }
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Riding")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingTracking) {
                TrackingView()
            }
            .navigationDestination(isPresented: $showingRoutePlanner) {
                RoutePlannerView()
            }
            .sheet(isPresented: $showingTraining) {
                RidingTrainingView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .interactiveDismissDisabled()
            }
    }
}

#Preview {
    NavigationStack {
        RidingView()
    }
}
