//
//  WatchStartSessionView.swift
//  TetraTrack Watch App
//
//  Discipline selector for starting autonomous Watch sessions
//

import SwiftUI

struct WatchStartSessionView: View {
    @State private var showRideControl = false
    @State private var showRunControl = false
    @State private var showSwimControl = false
    @State private var showShootingControl = false

    var body: some View {
        NavigationStack {
            disciplineSelectorView
            .navigationDestination(isPresented: $showRideControl) {
                RideControlView()
            }
            .navigationDestination(isPresented: $showRunControl) {
                RunningControlView()
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
            // Riding button
            Button {
                showRideControl = true
            } label: {
                HStack {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.riding)
                    Text("GPS + Heart Rate")
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

            // Running button
            Button {
                showRunControl = true
            } label: {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.running)
                    Text("GPS + Heart Rate")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WatchAppColors.running.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // Swimming button
            Button {
                showSwimControl = true
            } label: {
                HStack {
                    Image(systemName: "figure.pool.swim")
                        .font(.title3)
                        .foregroundStyle(WatchAppColors.swimming)
                    Text("Strokes + HR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(WatchAppColors.swimming.opacity(0.15))
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
                    Text("IMU + Heart Rate")
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
