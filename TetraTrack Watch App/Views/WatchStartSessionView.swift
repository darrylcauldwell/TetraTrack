//
//  WatchStartSessionView.swift
//  TetraTrack Watch App
//
//  Discipline selector for starting autonomous Watch sessions
//

import SwiftUI

struct WatchStartSessionView: View {
    @State private var showRideTypePicker = false
    @State private var showRunControl = false
    @State private var showWalkControl = false
    @State private var showSwimControl = false
    @State private var showShootingControl = false

    var body: some View {
        NavigationStack {
            disciplineSelectorView
            .navigationDestination(isPresented: $showRideTypePicker) {
                RideTypePickerView()
            }
            .navigationDestination(isPresented: $showRunControl) {
                RunControlView()
            }
            .navigationDestination(isPresented: $showWalkControl) {
                WalkControlView()
            }
            .navigationDestination(isPresented: $showSwimControl) {
                SwimControlView()
            }
            .navigationDestination(isPresented: $showShootingControl) {
                ShootingControlView()
            }
        }
    }

    // MARK: - Discipline Selector

    private var disciplineSelectorView: some View {
        VStack(spacing: 6) {
            Button { showRideTypePicker = true } label: {
                disciplineButton(icon: "figure.equestrian.sports", label: "Riding", color: WatchAppColors.riding)
            }
            .buttonStyle(.plain)

            Button { showRunControl = true } label: {
                disciplineButton(icon: "figure.run", label: "Running", color: WatchAppColors.running)
            }
            .buttonStyle(.plain)

            Button { showSwimControl = true } label: {
                disciplineButton(icon: "figure.pool.swim", label: "Swimming", color: WatchAppColors.swimming)
            }
            .buttonStyle(.plain)

            Button { showWalkControl = true } label: {
                disciplineButton(icon: "figure.walk", label: "Walking", color: WatchAppColors.walking)
            }
            .buttonStyle(.plain)

            Button { showShootingControl = true } label: {
                disciplineButton(icon: "target", label: "Shooting", color: WatchAppColors.shooting)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }

    private func disciplineButton(icon: String, label: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    WatchStartSessionView()
}
