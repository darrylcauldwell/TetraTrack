//
//  RidingView.swift
//  TrackRide
//
//  Riding discipline - track rides and off-horse training drills
//

import SwiftUI

struct RidingView: View {
    @State private var showingTraining = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                // Track Ride
                NavigationLink(destination: TrackingView()) {
                    DisciplineCard(
                        title: "Track Ride",
                        subtitle: "GPS & gait tracking",
                        icon: "location.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)

                // Training Drills
                Button { showingTraining = true } label: {
                    DisciplineCard(
                        title: "Training",
                        subtitle: "Off-horse drills",
                        icon: "figure.stand",
                        color: AppColors.primary
                    )
                }
                .buttonStyle(.plain)

                // Plan Route
                NavigationLink(destination: RoutePlannerView()) {
                    DisciplineCard(
                        title: "Plan Route",
                        subtitle: "Bridleways & trails",
                        icon: "map.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("Riding")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingTraining) {
            RidingTrainingView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    NavigationStack {
        RidingView()
    }
}
