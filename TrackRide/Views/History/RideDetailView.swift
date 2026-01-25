//
//  RideDetailView.swift
//  TrackRide
//

import SwiftUI
import Photos
import AVKit

struct RideDetailView: View {
    @Bindable var ride: Ride
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingShareSheet = false
    @State private var gpxFileURL: URL?
    @State private var showingGallery = false
    @State private var ridePhotos: [PHAsset] = []
    @State private var rideVideos: [PHAsset] = []
    @State private var hasLoadedMedia = false
    @State private var showingTrimView = false
    @State private var showingMediaEditor = false
    @State private var selectedVideo: PHAsset?

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle(ride.name.isEmpty ? "Ride Details" : ride.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = gpxFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingTrimView) {
            RideTrimView(ride: ride)
        }
        .sheet(isPresented: $showingMediaEditor) {
            RideMediaEditorView(ride: ride) {
                // Refresh media after editing
                hasLoadedMedia = false
                Task {
                    await loadMedia()
                }
            }
        }
        .sheet(item: $selectedVideo) { video in
            VideoPlayerView(asset: video)
        }
        .task {
            await loadMedia()
        }
        .presentationBackground(Color.black)
    }

    // MARK: - iPad Layout (Side-by-Side)

    private var iPadLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Top row: Map + Stats side by side
            HStack(alignment: .top, spacing: Spacing.xl) {
                // Left column: Map and Elevation
                VStack(spacing: Spacing.lg) {
                    mapSection
                        .frame(height: 400)

                    ElevationProfileView(profile: ride.elevationProfile)

                    // Media Gallery
                    mediaSection
                }
                .frame(maxWidth: .infinity)

                // Right column: Stats and Info
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Stats Grid - 2 columns on iPad sidebar
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Distance", value: ride.formattedDistance, icon: "arrow.left.and.right")
                        StatCard(title: "Duration", value: ride.formattedDuration, icon: "clock")
                        StatCard(title: "Avg Speed", value: ride.formattedAverageSpeed, icon: "speedometer")
                        StatCard(title: "Max Speed", value: ride.formattedMaxSpeed, icon: "gauge.with.dots.needle.100percent")
                        StatCard(title: "Elev. Gain", value: ride.formattedElevationGain, icon: "arrow.up.right")
                        StatCard(title: "Elev. Loss", value: ride.formattedElevationLoss, icon: "arrow.down.right")
                    }

                    badgesSection
                    insightsLinkSection

                    if ride.hasHeartRateData {
                        HeartRateSummaryView(ride: ride)
                    }

                    if let recoveryMetrics = ride.recoveryMetrics {
                        RecoverySummaryView(recoveryMetrics: recoveryMetrics)
                    }

                    if ride.hasWeatherData {
                        weatherSection
                    }

                    notesSection
                    actionButtons

                    dateSection
                }
                .frame(width: 380)
            }
        }
        .padding(Spacing.xl)
    }

    // MARK: - iPhone Layout (Vertical)

    private var iPhoneLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            mapSection
                .frame(height: 300)

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "Distance", value: ride.formattedDistance, icon: "arrow.left.and.right")
                StatCard(title: "Duration", value: ride.formattedDuration, icon: "clock")
                StatCard(title: "Avg Speed", value: ride.formattedAverageSpeed, icon: "speedometer")
                StatCard(title: "Max Speed", value: ride.formattedMaxSpeed, icon: "gauge.with.dots.needle.100percent")
                StatCard(title: "Elev. Gain", value: ride.formattedElevationGain, icon: "arrow.up.right")
                StatCard(title: "Elev. Loss", value: ride.formattedElevationLoss, icon: "arrow.down.right")
            }

            badgesSection
            insightsLinkSection

            if ride.hasHeartRateData {
                HeartRateSummaryView(ride: ride)
            }

            if let recoveryMetrics = ride.recoveryMetrics {
                RecoverySummaryView(recoveryMetrics: recoveryMetrics)
            }

            ElevationProfileView(profile: ride.elevationProfile)

            if ride.hasWeatherData {
                weatherSection
            }

            mediaSection
            dateSection
            notesSection
            actionButtons
        }
        .padding()
    }

    // MARK: - Extracted Sections

    private var mapSection: some View {
        Group {
            if !ride.coordinates.isEmpty {
                RouteMapView(ride: ride)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackground)
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No route data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }

    private var badgesSection: some View {
        HStack(spacing: 12) {
            if let horse = ride.horse {
                NavigationLink(destination: HorseDetailView(horse: horse)) {
                    HorseBadgeView(horse: horse)
                }
                .buttonStyle(.plain)
            }

            if ride.rideType != .hack {
                HStack {
                    Image(systemName: ride.rideType.icon)
                        .foregroundStyle(ride.rideType.color)
                    Text(ride.rideType.rawValue)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ride.rideType.color.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }

    private var insightsLinkSection: some View {
        NavigationLink(destination: RideInsightsView(ride: ride)) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundStyle(AppColors.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Biomechanical Insights")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Rhythm, balance, engagement & coach feedback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(AppColors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud.sun")
                Text("Weather")
                    .font(.headline)
            }

            if let startWeather = ride.startWeather {
                WeatherDetailView(weather: startWeather, title: "Start Conditions")
            }

            if let endWeather = ride.endWeather, ride.startWeather?.condition != endWeather.condition {
                WeatherChangeSummaryView(stats: ride.weatherStats)
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos & Videos")
                    .font(.headline)
                Spacer()
                if !ridePhotos.isEmpty || !rideVideos.isEmpty {
                    NavigationLink(destination: RideMediaGalleryView(ride: ride)) {
                        Text("View All (\(ridePhotos.count + rideVideos.count))")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }

            if ridePhotos.isEmpty && rideVideos.isEmpty {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No photos or videos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Media taken within 1 hour of this ride will appear here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ridePhotos.prefix(4), id: \.localIdentifier) { asset in
                            PhotoThumbnail(asset: asset)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        ForEach(rideVideos.prefix(2), id: \.localIdentifier) { asset in
                            VideoThumbnail(asset: asset)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedVideo = asset
                                }
                        }
                        if ridePhotos.count + rideVideos.count > 6 {
                            NavigationLink(destination: RideMediaGalleryView(ride: ride)) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.cardBackground)
                                        .frame(width: 80, height: 80)
                                    VStack {
                                        Text("+\(ridePhotos.count + rideVideos.count - 6)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text("more")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Button {
                showingMediaEditor = true
            } label: {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text(ridePhotos.isEmpty && rideVideos.isEmpty ? "Add Photos & Videos" : "Add More")
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.headline)
            Text(ride.formattedDate)
                .foregroundStyle(.secondary)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)

                Spacer()

                VoiceNoteToolbarButton { note in
                    let service = VoiceNotesService.shared
                    ride.notes = service.appendNote(note, to: ride.notes)
                }
            }

            if !ride.notes.isEmpty {
                Text(ride.notes)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button {
                        ride.notes = ""
                    } label: {
                        Label("Clear Notes", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Text("Tap the mic to add voice notes")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if !ride.coordinates.isEmpty {
                Button {
                    showingTrimView = true
                } label: {
                    Label("Trim", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button(action: exportGPX) {
                Label("Export GPX", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top)
    }

    private func loadMedia() async {
        guard !hasLoadedMedia else { return }
        hasLoadedMedia = true

        let photoService = RidePhotoService.shared
        if !photoService.isAuthorized {
            _ = await photoService.requestAuthorization()
        }

        // Search within 1 hour before and after the session for all ride types
        let (photos, videos) = await photoService.findMediaForSession(ride)

        await MainActor.run {
            ridePhotos = photos
            rideVideos = videos
        }
    }

    private func exportGPX() {
        Task {
            if let url = await GPXExporter.shared.exportToFile(ride: ride) {
                await MainActor.run {
                    gpxFileURL = url
                    showingShareSheet = true
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppColors.primary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        RideDetailView(ride: Ride())
    }
}
