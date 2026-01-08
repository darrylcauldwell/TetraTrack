//
//  RunningSessionTrimView.swift
//  TrackRide
//
//  Trim tool for removing unwanted portions from running sessions
//

import SwiftUI
import SwiftData
import MapKit

struct RunningSessionTrimView: View {
    @Bindable var session: RunningSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Trim state
    @State private var trimStartOffset: TimeInterval = 0  // Offset from session start
    @State private var trimEndOffset: TimeInterval = 0    // Offset from session end
    @State private var showingConfirmation = false

    private var originalDuration: TimeInterval {
        session.totalDuration
    }

    private var trimmedDuration: TimeInterval {
        max(0, originalDuration - trimStartOffset - trimEndOffset)
    }

    private var trimmedStartDate: Date {
        session.startDate.addingTimeInterval(trimStartOffset)
    }

    private var trimmedEndDate: Date {
        (session.endDate ?? session.startDate.addingTimeInterval(originalDuration))
            .addingTimeInterval(-trimEndOffset)
    }

    // Calculate trimmed distance by filtering points
    private var trimmedDistance: Double {
        let points = session.sortedLocationPoints.filter {
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
        session.totalDistance - trimmedDistance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Route Map Preview
                    RunningTrimRouteMapView(
                        session: session,
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Speed Anomalies Warning
                    if !session.speedAnomalies.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("High speed detected")
                                    .font(.subheadline.weight(.medium))
                                Text("Found \(session.speedAnomalies.count) points with vehicle-like speeds")
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
                            Text(session.totalDistance.formattedDistance)
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
                                .foregroundStyle(.blue)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(formatDuration(trimmedDuration))
                                .foregroundStyle(.blue)
                        }
                        .font(.subheadline)

                        // Pace comparison
                        if trimmedDistance > 0 && trimmedDuration > 0 {
                            HStack {
                                Text("New pace")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatPace(trimmedDuration / (trimmedDistance / 1000)))
                                    .foregroundStyle(.blue)
                            }
                            .font(.subheadline)
                        }

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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Apply Button
                    Button {
                        showingConfirmation = true
                    } label: {
                        Label("Apply Trim", systemImage: "scissors")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(trimStartOffset > 0 || trimEndOffset > 0 ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(trimStartOffset == 0 && trimEndOffset == 0)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("Trim Run")
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
                Text("This will permanently remove \(formatDuration(trimStartOffset + trimEndOffset)) of data from this run. This cannot be undone.")
            }
        }
    }

    private func applyTrim() {
        session.applyTrim(
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

    private func formatPace(_ secondsPerKm: TimeInterval) -> String {
        let mins = Int(secondsPerKm) / 60
        let secs = Int(secondsPerKm) % 60
        return String(format: "%d:%02d /km", mins, secs)
    }
}

// MARK: - Running Trim Route Map View

struct RunningTrimRouteMapView: View {
    let session: RunningSession
    let trimStart: Date
    let trimEnd: Date

    var body: some View {
        Map {
            // Kept route (blue)
            let keptPoints = session.sortedLocationPoints.filter {
                $0.timestamp >= trimStart && $0.timestamp <= trimEnd
            }
            if keptPoints.count > 1 {
                MapPolyline(coordinates: keptPoints.map { $0.coordinate })
                    .stroke(.blue, lineWidth: 4)
            }

            // Removed start section (red)
            let removedStartPoints = session.sortedLocationPoints.filter {
                $0.timestamp < trimStart
            }
            if removedStartPoints.count > 1 {
                MapPolyline(coordinates: removedStartPoints.map { $0.coordinate })
                    .stroke(.red.opacity(0.6), lineWidth: 4)
            }

            // Removed end section (red)
            let removedEndPoints = session.sortedLocationPoints.filter {
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
    RunningSessionTrimView(session: RunningSession())
        .modelContainer(for: RunningSession.self, inMemory: true)
}
