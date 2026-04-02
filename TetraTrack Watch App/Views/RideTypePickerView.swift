//
//  RideTypePickerView.swift
//  TetraTrack Watch App
//
//  Ride type selection for autonomous Watch rides.
//  Starts the workout then navigates to RideControlView.
//

import SwiftUI

struct RideTypePickerView: View {
    @Environment(WorkoutManager.self) private var workoutManager
    @State private var showRideControl = false

    var body: some View {
        VStack(spacing: 6) {
            ForEach(WatchRideType.allCases) { type in
                Button {
                    Task {
                        await workoutManager.startAutonomousRide(type: type)
                        showRideControl = true
                    }
                } label: {
                    HStack {
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundStyle(WatchAppColors.riding)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(type.rawValue)
                                .font(.caption.weight(.semibold))
                            Text(type.description)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(WatchAppColors.riding.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .navigationTitle("Ride Type")
        .navigationDestination(isPresented: $showRideControl) {
            RideControlView()
                .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    NavigationStack {
        RideTypePickerView()
    }
}
