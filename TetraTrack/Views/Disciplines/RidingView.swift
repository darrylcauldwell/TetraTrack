//
//  RidingView.swift
//  TetraTrack
//
//  Riding discipline — sessions are Watch-primary, this view guides to Watch
//

import SwiftUI

struct RidingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "applewatch")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Start on Apple Watch")
                .font(.title2.bold())

            Text("Open TetraTrack on your Apple Watch and select a ride type to begin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 12) {
                rideTypeRow(icon: "figure.equestrian.sports", name: "Ride", description: "General riding — hacking, schooling, trail")
                rideTypeRow(icon: "figure.equestrian.sports", name: "Dressage", description: "Dressage with posting rhythm and turn balance")
                rideTypeRow(icon: "arrow.up.forward", name: "Showjumping", description: "Showjumping with jump counting")
            }
            .padding(.horizontal, 24)

            Text("After your ride, annotate it here with horse, scores, and notes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
        .navigationTitle("Riding")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rideTypeRow(icon: String, name: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RidingView()
    }
}
