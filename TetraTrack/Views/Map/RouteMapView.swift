//
//  RouteMapView.swift
//  TetraTrack
//
//  Ride-specific route map with photo annotations and gait coloring.
//  Delegates route rendering to shared RouteColorScheme; adds photo overlay.
//

import SwiftUI
import MapKit
import Photos

// MARK: - Photo Annotation

struct PhotoAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let asset: PHAsset
    let timestamp: Date
}

// MARK: - Route Map View

struct RouteMapView: View {
    let ride: Ride
    @State private var showLegend = true
    @State private var mapStyle: RouteMapStyle = .standard
    @State private var photoAnnotations: [PhotoAnnotation] = []
    @State private var selectedPhotoAsset: PHAsset?
    @State private var showPhotos = true

    private var routeColors: RouteColorScheme {
        .fromRide(ride)
    }

    private var coordinates: [CLLocationCoordinate2D] {
        ride.coordinates
    }

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
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

        let latDelta = max((maxLat - minLat) * 1.3, 0.005)
        let lonDelta = max((maxLon - minLon) * 1.3, 0.005)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    private var usedGaits: [GaitType] {
        switch routeColors {
        case .segments(let segments):
            let gaits: [GaitType] = segments.compactMap { segment in
                GaitType.allCases.first { AppColors.gait($0) == segment.color }
            }
            return Array(Set(gaits)).sorted { $0.rawValue < $1.rawValue }
        default:
            return []
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(initialPosition: .region(region)) {
                // Route rendering via shared RouteColorScheme
                routeContent

                // Start marker
                if let first = coordinates.first {
                    Annotation("Start", coordinate: first) {
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

                // End marker
                if let last = coordinates.last, coordinates.count > 1 {
                    Annotation("End", coordinate: last) {
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

                // Photo annotations
                if showPhotos {
                    ForEach(photoAnnotations) { photo in
                        Annotation("Photo", coordinate: photo.coordinate) {
                            Button {
                                selectedPhotoAsset = photo.asset
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.cardBackground)
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
                        .background(AppColors.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                }

                // Photo toggle
                if !photoAnnotations.isEmpty {
                    Button {
                        showPhotos.toggle()
                    } label: {
                        Image(systemName: showPhotos ? "camera.fill" : "camera")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 36, height: 36)
                            .background(AppColors.cardBackground)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }

                // Gait Legend
                if showLegend && !usedGaits.isEmpty {
                    MapLegendView.gaitLegend(usedGaits: usedGaits)
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
        .sheetBackground()
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
        case .trim:
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(AppColors.primary, lineWidth: 4)
            }
        }
    }

    private func loadPhotoAnnotations() async {
        let photoService = RidePhotoService.shared
        guard photoService.isAuthorized else { return }

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
