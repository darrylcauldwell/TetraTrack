//
//  RideMapView.swift
//  TrackRide
//
//  Live ride map with gait-colored route display
//

import SwiftUI
import MapKit

struct RideMapView: View {
    @Environment(RideTracker.self) private var rideTracker: RideTracker?
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var onBack: (() -> Void)? = nil
    var plannedRoute: PlannedRoute? = nil

    var body: some View {
        ZStack {
            if let _ = rideTracker, let locManager = locationManager {
                // Map with gait-colored route
                Map(position: $position) {
                    // User location
                    UserAnnotation()

                    // Planned route overlay (dashed orange line behind gait track)
                    if let route = plannedRoute, !route.coordinates.isEmpty {
                        MapPolyline(coordinates: route.coordinates)
                            .stroke(.orange.opacity(0.6), style: StrokeStyle(
                                lineWidth: 6,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [10, 5]
                            ))
                    }

                    // Gait-colored route polylines
                    ForEach(locManager.gaitRouteSegments) { segment in
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(AppColors.gait(segment.gaitType), lineWidth: 5)
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }

                // Overlay controls - minimal: back button and gait legend only
                VStack {
                    // Back button at top left
                    HStack {
                        Button(action: { onBack?() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                Text("Stats")
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppColors.cardBackground)
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }
                    .padding()

                    Spacer()

                    // Gait legend at bottom
                    GaitLegend()
                        .padding(.bottom, 20)
                }
            } else {
                ContentUnavailableView(
                    "No Active Ride",
                    systemImage: "map",
                    description: Text("Start a ride to see your route")
                )
            }
        }
    }
}

// MARK: - Mini Stats Card (kept for potential future use)

struct MiniStatsCard: View {
    let tracker: RideTracker

    var body: some View {
        HStack(spacing: 20) {
            // Duration
            VStack(spacing: 2) {
                Text(tracker.formattedElapsedTime)
                    .font(.headline)
                    .monospacedDigit()
                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            // Distance
            VStack(spacing: 2) {
                Text(tracker.formattedDistance)
                    .font(.headline)
                    .monospacedDigit()
                Text("Distance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            // Current gait with color
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.gait(tracker.currentGait))
                        .frame(width: 8, height: 8)
                    Text(tracker.currentGait.rawValue)
                        .font(.headline)
                }
                Text("Gait")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            // Speed
            VStack(spacing: 2) {
                Text(tracker.formattedSpeed)
                    .font(.headline)
                    .monospacedDigit()
                Text("Speed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

// MARK: - Location Manager Extension for Gait Route Segments

extension LocationManager {
    /// Group tracked points by gait for route display
    var gaitRouteSegments: [GaitRouteSegment] {
        guard trackedPoints.count > 1 else { return [] }

        var segments: [GaitRouteSegment] = []
        var currentGait = trackedPoints[0].gait
        var currentCoordinates: [CLLocationCoordinate2D] = [trackedPoints[0].coordinate]

        for i in 1..<trackedPoints.count {
            let point = trackedPoints[i]
            if point.gait == currentGait {
                currentCoordinates.append(point.coordinate)
            } else {
                // Finalize current segment
                if currentCoordinates.count > 1 {
                    segments.append(GaitRouteSegment(gait: currentGait, coordinates: currentCoordinates))
                }
                // Start new segment (include last point for continuity)
                currentGait = point.gait
                currentCoordinates = [trackedPoints[i-1].coordinate, point.coordinate]
            }
        }

        // Add final segment
        if currentCoordinates.count > 1 {
            segments.append(GaitRouteSegment(gait: currentGait, coordinates: currentCoordinates))
        }

        return segments
    }
}

#Preview {
    RideMapView()
        .environment(LocationManager())
        .environment(RideTracker(locationManager: LocationManager()))
}
