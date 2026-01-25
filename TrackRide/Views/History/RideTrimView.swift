//
//  RideTrimView.swift
//  TrackRide
//
//  Trim tool for removing unwanted portions from ride sessions
//

import SwiftUI
import SwiftData
import MapKit

struct RideTrimView: View {
    @Bindable var ride: Ride
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Trim state
    @State private var trimStartOffset: TimeInterval = 0  // Offset from ride start
    @State private var trimEndOffset: TimeInterval = 0    // Offset from ride end
    @State private var showingConfirmation = false

    private var originalDuration: TimeInterval {
        ride.totalDuration
    }

    private var trimmedDuration: TimeInterval {
        max(0, originalDuration - trimStartOffset - trimEndOffset)
    }

    private var trimmedStartDate: Date {
        ride.startDate.addingTimeInterval(trimStartOffset)
    }

    private var trimmedEndDate: Date {
        (ride.endDate ?? ride.startDate.addingTimeInterval(originalDuration))
            .addingTimeInterval(-trimEndOffset)
    }

    // Calculate trimmed distance by filtering points
    private var trimmedDistance: Double {
        let points = ride.sortedLocationPoints.filter {
            $0.timestamp >= trimmedStartDate && $0.timestamp <= trimmedEndDate
        }
        guard points.count > 1 else { return 0 }

        var distance: Double = 0
        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            distance += curr.distance(from: prev)
        }
        return distance
    }

    private var removedDistance: Double {
        ride.totalDistance - trimmedDistance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Route Map Preview
                    TrimRouteMapView(
                        ride: ride,
                        trimStart: trimmedStartDate,
                        trimEnd: trimmedEndDate
                    )
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Trim Sliders
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Trim Timeline")
                            .font(.headline)

                        // Start trim slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Remove from start")
                                    .font(.subheadline)
                                Spacer()
                                Text(formatDuration(trimStartOffset))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $trimStartOffset, in: 0...(originalDuration - trimEndOffset - 60)) {
                                Text("Start")
                            }
                            .tint(.red)
                        }

                        // End trim slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Remove from end")
                                    .font(.subheadline)
                                Spacer()
                                Text(formatDuration(trimEndOffset))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $trimEndOffset, in: 0...(originalDuration - trimStartOffset - 60)) {
                                Text("End")
                            }
                            .tint(.red)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Speed Anomalies Warning
                    if !ride.speedAnomalies.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("High speed detected")
                                    .font(.subheadline.weight(.medium))
                                Text("Found \(ride.speedAnomalies.count) points with vehicle-like speeds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Summary Card
                    VStack(spacing: 16) {
                        Text("Summary")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Original stats
                        HStack {
                            Text("Original")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ride.totalDistance.formattedDistance)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(formatDuration(originalDuration))
                        }
                        .font(.subheadline)

                        Divider()

                        // Trimmed stats
                        HStack {
                            Text("After trim")
                                .fontWeight(.medium)
                            Spacer()
                            Text(trimmedDistance.formattedDistance)
                                .foregroundStyle(AppColors.primary)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(formatDuration(trimmedDuration))
                                .foregroundStyle(AppColors.primary)
                        }
                        .font(.subheadline)

                        // Removed stats
                        if trimStartOffset > 0 || trimEndOffset > 0 {
                            HStack {
                                Text("Removing")
                                    .foregroundStyle(.red)
                                Spacer()
                                Text(removedDistance.formattedDistance)
                                    .foregroundStyle(.red)
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(formatDuration(trimStartOffset + trimEndOffset))
                                    .foregroundStyle(.red)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Apply Button
                    Button {
                        showingConfirmation = true
                    } label: {
                        Label("Apply Trim", systemImage: "scissors")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(trimStartOffset > 0 || trimEndOffset > 0 ? AppColors.primary : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(trimStartOffset == 0 && trimEndOffset == 0)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("Trim Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Apply Trim?", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Apply Trim", role: .destructive) {
                    applyTrim()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove \(formatDuration(trimStartOffset + trimEndOffset)) of data from this ride. This cannot be undone.")
            }
        }
    }

    private func applyTrim() {
        ride.applyTrim(
            startTime: trimmedStartDate,
            endTime: trimmedEndDate,
            context: modelContext
        )
        dismiss()
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Trim Route Map View

struct TrimRouteMapView: View {
    let ride: Ride
    let trimStart: Date
    let trimEnd: Date

    var body: some View {
        Map {
            // Kept route (green)
            let keptPoints = ride.sortedLocationPoints.filter {
                $0.timestamp >= trimStart && $0.timestamp <= trimEnd
            }
            if keptPoints.count > 1 {
                MapPolyline(coordinates: keptPoints.map { $0.coordinate })
                    .stroke(AppColors.primary, lineWidth: 4)
            }

            // Removed start section (red)
            let removedStartPoints = ride.sortedLocationPoints.filter {
                $0.timestamp < trimStart
            }
            if removedStartPoints.count > 1 {
                MapPolyline(coordinates: removedStartPoints.map { $0.coordinate })
                    .stroke(.red.opacity(0.6), lineWidth: 4)
            }

            // Removed end section (red)
            let removedEndPoints = ride.sortedLocationPoints.filter {
                $0.timestamp > trimEnd
            }
            if removedEndPoints.count > 1 {
                MapPolyline(coordinates: removedEndPoints.map { $0.coordinate })
                    .stroke(.red.opacity(0.6), lineWidth: 4)
            }

            // Start marker (after trim)
            if let start = keptPoints.first {
                Annotation("Start", coordinate: start.coordinate) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.green)
                        .padding(6)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
            }

            // End marker (after trim)
            if let end = keptPoints.last {
                Annotation("End", coordinate: end.coordinate) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(.white)
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
    }
}

#Preview {
    RideTrimView(ride: Ride())
        .modelContainer(for: Ride.self, inMemory: true)
}
