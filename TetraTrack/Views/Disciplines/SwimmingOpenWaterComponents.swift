//
//  SwimmingOpenWaterComponents.swift
//  TetraTrack
//
//  Map views for open water swimming GPS tracking
//

import SwiftUI
import MapKit

// MARK: - Live Open Water Map

struct SwimmingOpenWaterMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    let distance: Double

    var body: some View {
        ZStack {
            Map {
                UserAnnotation()

                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.cyan, lineWidth: 4)
                }

                // Start marker
                if let start = coordinates.first {
                    Annotation("Start", coordinate: start) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().stroke(.white, lineWidth: 2)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            // Distance overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text(String(format: "%.0fm", distance))
                            .font(.headline.bold())
                            .monospacedDigit()
                        Text("GPS Distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding()
                }
            }
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Post-Session Route View

struct SwimmingOpenWaterRouteView: View {
    let session: SwimmingSession

    private var coordinates: [CLLocationCoordinate2D] {
        session.coordinates
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "water.waves")
                    .foregroundStyle(.cyan)
                Text("Open Water Route")
                    .font(.headline)
            }

            Map {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.cyan, lineWidth: 4)
                }

                // Start marker
                if let start = coordinates.first {
                    Annotation("Start", coordinate: start) {
                        Circle()
                            .fill(.green)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(.white, lineWidth: 2)
                            )
                    }
                }

                // End marker
                if let end = coordinates.last, coordinates.count > 1 {
                    Annotation("End", coordinate: end) {
                        Circle()
                            .fill(.red)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle().stroke(.white, lineWidth: 2)
                            )
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Previews

#Preview("Live Map") {
    SwimmingOpenWaterMapView(
        coordinates: [
            CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            CLLocationCoordinate2D(latitude: 51.5075, longitude: -0.1280),
            CLLocationCoordinate2D(latitude: 51.5077, longitude: -0.1282)
        ],
        distance: 150
    )
    .padding()
}
