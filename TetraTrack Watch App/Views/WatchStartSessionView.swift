//
//  WatchStartSessionView.swift
//  TetraTrack Watch App
//
//  Discipline selector for starting autonomous Watch sessions
//

import SwiftUI

struct WatchStartSessionView: View {
    @State private var showRideTypePicker = false
    @State private var showShootingControl = false

    var body: some View {
        NavigationStack {
            disciplineSelectorView
            .navigationDestination(isPresented: $showRideTypePicker) {
                RideTypePickerView()
            }
            .navigationDestination(isPresented: $showShootingControl) {
                ShootingControlView()
            }
        }
    }

    // MARK: - Discipline Selector

    private var disciplineSelectorView: some View {
        VStack(spacing: 6) {
            // Riding button
            Button {
                showRideTypePicker = true
            } label: {
                HStack {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.riding)
                    Text("Riding")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

            // Shooting button
            Button {
                showShootingControl = true
            } label: {
                HStack {
                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.shooting)
                    Text("Shooting")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WatchAppColors.shooting.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    WatchStartSessionView()
}
