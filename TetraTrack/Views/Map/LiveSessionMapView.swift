//
//  LiveSessionMapView.swift
//  TetraTrack
//
//  Shared live-tracking map view for all disciplines.
//

import SwiftUI
import MapKit
import CoreLocation

struct LiveSessionMapView: View {
    let routeSegments: [RouteSegment]
    var followsUser: Bool = true
    var followDistance: Double = 400
    var currentLocation: CLLocation?
    var onBack: (() -> Void)?
    var backLabel: String = "Stats"

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                UserAnnotation()

                ForEach(routeSegments) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(segment.color, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .task {
                guard followsUser else { return }
                updateCameraPosition()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    updateCameraPosition()
                }
            }

            if let onBack {
                VStack {
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                Text(backLabel)
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
                }
            }
        }
    }

    private func updateCameraPosition() {
        guard let location = currentLocation else { return }
        position = .camera(MapCamera(
            centerCoordinate: location.coordinate,
            distance: followDistance
        ))
    }
}
