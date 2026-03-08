//
//  SessionRouteMapView.swift
//  TetraTrack
//
//  Shared post-session and trim map view for all disciplines.
//

import SwiftUI
import MapKit

// MARK: - Route Map Style

enum RouteMapStyle: String, CaseIterable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .satellite:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        }
    }

    var icon: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.europe.africa"
        case .hybrid: return "square.on.square"
        }
    }
}

// MARK: - Session Route Map View

struct SessionRouteMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    let routeColors: RouteColorScheme
    var showMarkers: Bool = true
    var showMapStylePicker: Bool = false
    var showMapControls: Bool = true

    @State private var mapStyle: RouteMapStyle = .standard

    private var region: MKCoordinateRegion {
        let displayCoords = displayCoordinates
        guard !displayCoords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let latitudes = displayCoords.map { $0.latitude }
        let longitudes = displayCoords.map { $0.longitude }

        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else {
            return MKCoordinateRegion()
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = max((maxLat - minLat) * 1.3, 0.005)
        let lonDelta = max((maxLon - minLon) * 1.3, 0.005)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    private var displayCoordinates: [CLLocationCoordinate2D] {
        switch routeColors {
        case .trim(let kept, _, _, _):
            return kept
        default:
            return coordinates
        }
    }

    private var markerStartCoordinate: CLLocationCoordinate2D? {
        displayCoordinates.first
    }

    private var markerEndCoordinate: CLLocationCoordinate2D? {
        guard displayCoordinates.count > 1 else { return nil }
        return displayCoordinates.last
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(initialPosition: .region(region)) {
                routeContent

                if showMarkers {
                    markerContent
                }
            }
            .mapStyle(mapStyle.mapStyle)
            .mapControls {
                if showMapControls {
                    MapCompass()
                    MapScaleView()
                }
            }

            if showMapStylePicker {
                mapStylePickerOverlay
            }
        }
    }

    // MARK: - Route Content

    @MapContentBuilder
    private var routeContent: some MapContent {
        switch routeColors {
        case .solid(let color):
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(color, lineWidth: 4)
            }

        case .segments(let segments):
            ForEach(segments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.color, lineWidth: 5)
            }

        case .trim(let kept, let removedStart, let removedEnd, let keptColor):
            if kept.count > 1 {
                MapPolyline(coordinates: kept)
                    .stroke(keptColor, lineWidth: 4)
            }
            if removedStart.count > 1 {
                MapPolyline(coordinates: removedStart)
                    .stroke(.red.opacity(0.6), lineWidth: 4)
            }
            if removedEnd.count > 1 {
                MapPolyline(coordinates: removedEnd)
                    .stroke(.red.opacity(0.6), lineWidth: 4)
            }
        }
    }

    // MARK: - Markers

    @MapContentBuilder
    private var markerContent: some MapContent {
        if let start = markerStartCoordinate {
            Annotation("Start", coordinate: start) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 36, height: 36)
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                    Image(systemName: "flag.fill")
                        .foregroundStyle(AppColors.success)
                        .font(.system(size: 16))
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }

        if let end = markerEndCoordinate {
            Annotation("End", coordinate: end) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 36, height: 36)
                    Circle()
                        .fill(.white)
                        .frame(width: 32, height: 32)
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(AppColors.deep)
                        .font(.system(size: 16))
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
        }
    }

    // MARK: - Map Style Picker

    private var mapStylePickerOverlay: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Menu {
                ForEach(RouteMapStyle.allCases, id: \.self) { style in
                    Button {
                        mapStyle = style
                    } label: {
                        Label(style.rawValue, systemImage: style.icon)
                    }
                }
            } label: {
                Image(systemName: mapStyle.icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
        }
        .padding(12)
    }
}
