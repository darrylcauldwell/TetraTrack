//
//  RouteMapView.swift
//  TrackRide
//
//  Liquid Glass Design - Route Map with Colour-Coded Gait Segments
//

import SwiftUI
import MapKit
import Photos

// MARK: - Map Style Options

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

// MARK: - Photo Annotation

struct PhotoAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let asset: PHAsset
    let timestamp: Date
}

// MARK: - Route Map View
// Note: Uses GaitRouteSegment from LiveTrackingSession.swift

struct RouteMapView: View {
    let ride: Ride?
    let coordinates: [CLLocationCoordinate2D]
    @State private var showLegend = true
    @State private var mapStyle: RouteMapStyle = .standard
    @State private var photoAnnotations: [PhotoAnnotation] = []
    @State private var selectedPhotoAsset: PHAsset?
    @State private var showPhotos = true

    /// Initialize with a Ride for colour-coded gait segments
    init(ride: Ride) {
        self.ride = ride
        self.coordinates = ride.coordinates
    }

    /// Initialize with coordinates only (fallback, single colour)
    init(coordinates: [CLLocationCoordinate2D]) {
        self.ride = nil
        self.coordinates = coordinates
    }

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            // Default to UK if no coordinates
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }

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

        // Add padding around the route
        let latDelta = max((maxLat - minLat) * 1.3, 0.005)
        let lonDelta = max((maxLon - minLon) * 1.3, 0.005)

        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    /// Build gait-coloured route segments by matching location timestamps to gait segments
    private var gaitRouteSegments: [GaitRouteSegment] {
        guard let ride = ride,
              let gaitSegments = ride.gaitSegments,
              !gaitSegments.isEmpty else {
            // No gait data - return single segment with primary colour
            if coordinates.count >= 2 {
                return [GaitRouteSegment(coordinates: coordinates, gaitType: .walk)]
            }
            return []
        }

        let sortedPoints = ride.sortedLocationPoints
        let sortedGaits = ride.sortedGaitSegments

        guard !sortedPoints.isEmpty else { return [] }

        var segments: [GaitRouteSegment] = []
        var currentCoords: [CLLocationCoordinate2D] = []
        var currentGait: GaitType?

        for point in sortedPoints {
            // Find which gait segment this point belongs to
            let gait = gaitForTimestamp(point.timestamp, in: sortedGaits)

            if currentGait == nil {
                // First point
                currentGait = gait
                currentCoords.append(point.coordinate)
            } else if gait == currentGait {
                // Same gait, add to current segment
                currentCoords.append(point.coordinate)
            } else {
                // Gait changed - save current segment and start new one
                if currentCoords.count >= 2 {
                    segments.append(GaitRouteSegment(
                        coordinates: currentCoords,
                        gaitType: currentGait ?? .walk
                    ))
                }
                // Start new segment with overlap point for continuity
                currentCoords = [currentCoords.last ?? point.coordinate, point.coordinate]
                currentGait = gait
            }
        }

        // Add final segment
        if currentCoords.count >= 2, let gait = currentGait {
            segments.append(GaitRouteSegment(coordinates: currentCoords, gaitType: gait))
        }

        return segments
    }

    /// Find the gait type for a given timestamp
    private func gaitForTimestamp(_ timestamp: Date, in segments: [GaitSegment]) -> GaitType {
        for segment in segments {
            let endTime = segment.endTime ?? Date.distantFuture
            if timestamp >= segment.startTime && timestamp <= endTime {
                return segment.gait
            }
        }
        // Default to walk if no matching segment found
        return .walk
    }

    /// Get unique gaits used in route for legend
    private var usedGaits: [GaitType] {
        let gaits = gaitRouteSegments.map { $0.gaitType }
        return Array(Set(gaits)).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(initialPosition: .region(region)) {
                // Colour-coded gait route segments
                if ride != nil && !gaitRouteSegments.isEmpty {
                    ForEach(gaitRouteSegments) { segment in
                        MapPolyline(coordinates: segment.coordinates)
                            .stroke(AppColors.gait(segment.gaitType), lineWidth: 5)
                    }
                } else if coordinates.count >= 2 {
                    // Fallback: single colour route
                    MapPolyline(coordinates: coordinates)
                        .stroke(AppColors.primary, lineWidth: 4)
                }

                // Start marker
                if let first = coordinates.first {
                    Annotation("Start", coordinate: first) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
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

                // End marker
                if let last = coordinates.last, coordinates.count > 1 {
                    Annotation("End", coordinate: last) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
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

                // Photo annotations
                if showPhotos {
                    ForEach(photoAnnotations) { photo in
                        Annotation("Photo", coordinate: photo.coordinate) {
                            Button {
                                selectedPhotoAsset = photo.asset
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 32, height: 32)
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "camera.fill")
                                        .foregroundStyle(AppColors.primary)
                                        .font(.system(size: 14))
                                }
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                        }
                    }
                }
            }
            .mapStyle(mapStyle.mapStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
            }

            // Controls overlay
            VStack(alignment: .trailing, spacing: 8) {
                // Map style picker
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
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }

                // Photo toggle (if photos available)
                if !photoAnnotations.isEmpty {
                    Button {
                        showPhotos.toggle()
                    } label: {
                        Image(systemName: showPhotos ? "camera.fill" : "camera")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }

                // Gait Legend (glass styled)
                if showLegend && !usedGaits.isEmpty && ride != nil {
                    GaitMapLegend(gaits: usedGaits)
                }
            }
            .padding(12)
        }
        .sheet(item: $selectedPhotoAsset) { asset in
            PhotoDetailView(asset: asset)
        }
        .task {
            await loadPhotoAnnotations()
        }
    }

    private func loadPhotoAnnotations() async {
        guard let ride = ride else { return }

        let photoService = RidePhotoService.shared
        guard photoService.isAuthorized else { return }

        // Use full-day search to capture all photos with GPS from the ride day
        let (photos, _) = await photoService.findMediaForFullDay(ride)

        var annotations: [PhotoAnnotation] = []
        for asset in photos {
            if let location = asset.location?.coordinate,
               let date = asset.creationDate {
                annotations.append(PhotoAnnotation(
                    coordinate: location,
                    asset: asset,
                    timestamp: date
                ))
            }
        }

        await MainActor.run {
            photoAnnotations = annotations
        }
    }
}

// MARK: - Gait Map Legend

struct GaitMapLegend: View {
    let gaits: [GaitType]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(gaits, id: \.self) { gait in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.gait(gait))
                        .frame(width: 20, height: 4)

                    Text(gait.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

#Preview("With Gait Data") {
    RouteMapView(coordinates: [
        CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        CLLocationCoordinate2D(latitude: 51.5080, longitude: -0.1290),
        CLLocationCoordinate2D(latitude: 51.5090, longitude: -0.1285),
        CLLocationCoordinate2D(latitude: 51.5095, longitude: -0.1270),
    ])
    .frame(height: 300)
}

#Preview("Coordinates Only") {
    RouteMapView(coordinates: [
        CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        CLLocationCoordinate2D(latitude: 51.5080, longitude: -0.1290),
        CLLocationCoordinate2D(latitude: 51.5090, longitude: -0.1285),
        CLLocationCoordinate2D(latitude: 51.5095, longitude: -0.1270),
    ])
    .frame(height: 300)
}
