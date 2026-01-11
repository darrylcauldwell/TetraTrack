//
//  RideGalleryView.swift
//  TrackRide
//
//  Display photos and videos taken during a ride
//

import SwiftUI
import Photos
import PhotosUI
import AVKit

// MARK: - Legacy Photo-Only Gallery (kept for backwards compatibility)

struct RideGalleryView: View {
    let ride: Ride

    @State private var photos: [PHAsset] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PHAsset?
    @State private var photoService = RidePhotoService.shared

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack {
            if !photoService.isAuthorized {
                // Request permission
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    Text("Photo Access Required")
                        .font(.headline)

                    Text("Allow TetraTrack to access your photos to find pictures taken during your rides.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Allow Access") {
                        Task {
                            _ = await photoService.requestAuthorization()
                            await loadPhotos()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if isLoading {
                ProgressView("Finding photos...")
            } else if photos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    Text("No Photos Found")
                        .font(.headline)

                    Text("No photos were taken during this ride. Photos taken while riding will appear here automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos, id: \.localIdentifier) { asset in
                            PhotoThumbnail(asset: asset)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .onTapGesture {
                                    selectedPhoto = asset
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ride Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhoto) { asset in
            PhotoDetailView(asset: asset)
        }
        .task {
            await loadPhotos()
        }
    }

    private func loadPhotos() async {
        isLoading = true
        // Use full-day search to capture all photos from the ride day
        let (dayPhotos, _) = await photoService.findMediaForFullDay(ride)
        photos = dayPhotos
        isLoading = false
    }
}

// MARK: - Full Media Gallery (Photos & Videos)

struct RideMediaGalleryView: View {
    let ride: Ride

    @State private var photos: [PHAsset] = []
    @State private var videos: [PHAsset] = []
    @State private var isLoading = true
    @State private var selectedPhoto: PHAsset?
    @State private var selectedVideo: PHAsset?
    @State private var photoService = RidePhotoService.shared

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        VStack {
            if !photoService.isAuthorized {
                MediaPermissionView {
                    Task {
                        _ = await photoService.requestAuthorization()
                        await loadMedia()
                    }
                }
            } else if isLoading {
                ProgressView("Finding photos & videos...")
            } else if photos.isEmpty && videos.isEmpty {
                EmptyMediaView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Photos section
                        if !photos.isEmpty {
                            Text("Photos (\(photos.count))")
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos, id: \.localIdentifier) { asset in
                                    PhotoThumbnail(asset: asset)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .onTapGesture {
                                            selectedPhoto = asset
                                        }
                                }
                            }
                        }

                        // Videos section
                        if !videos.isEmpty {
                            Text("Videos (\(videos.count))")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, photos.isEmpty ? 0 : 8)

                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(videos, id: \.localIdentifier) { asset in
                                    VideoThumbnail(asset: asset)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                        .onTapGesture {
                                            selectedVideo = asset
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Photos & Videos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPhoto) { asset in
            PhotoDetailView(asset: asset)
        }
        .sheet(item: $selectedVideo) { asset in
            VideoPlayerView(asset: asset)
        }
        .task {
            await loadMedia()
        }
    }

    private func loadMedia() async {
        isLoading = true
        let (dayPhotos, dayVideos) = await photoService.findMediaForSession(ride)
        photos = dayPhotos
        videos = dayVideos
        isLoading = false
    }
}

// MARK: - Media Editor (Manual Add)

struct RideMediaEditorView: View {
    let ride: Ride
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Info text
                VStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Photos and videos taken within 1 hour of your ride are automatically linked.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Use the options below to add media from other times.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                Spacer()

                // Photo picker
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 20,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add Photos", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Video picker
                PhotosPicker(
                    selection: $selectedVideos,
                    maxSelectionCount: 10,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Label("Add Videos", systemImage: "video.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Selected count
                if !selectedPhotos.isEmpty || !selectedVideos.isEmpty {
                    Text("Selected: \(selectedPhotos.count) photos, \(selectedVideos.count) videos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    var preserveAspectRatio: Bool = false
    var maxHeight: CGFloat = 80

    @State private var image: UIImage?
    private let photoService = RidePhotoService.shared

    /// Calculate the aspect ratio from the asset's pixel dimensions
    private var assetAspectRatio: CGFloat {
        guard asset.pixelHeight > 0 else { return 1 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    var body: some View {
        Group {
            if preserveAspectRatio {
                // Preserve original aspect ratio
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: maxHeight * assetAspectRatio, height: maxHeight)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: maxHeight * assetAspectRatio, height: maxHeight)
                        .overlay {
                            ProgressView()
                        }
                }
            } else {
                // Square thumbnail (original behavior)
                GeometryReader { geometry in
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Check cache first
        if let cached = photoService.getCachedThumbnail(for: asset.localIdentifier) {
            self.image = cached
            return
        }

        let size = CGSize(width: 200, height: 200)

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                // Cache the thumbnail
                photoService.cacheThumbnail(result, for: asset.localIdentifier)
                Task { @MainActor in
                    self.image = result
                }
            }
        }
    }
}

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset

    @State private var image: UIImage?
    @State private var isLoading = true
    private let photoService = RidePhotoService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    if let date = asset.creationDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            await loadFullImage()
        }
    }

    private func loadFullImage() async {
        // Check cache first
        if let cached = photoService.getCachedFullImage(for: asset.localIdentifier) {
            self.image = cached
            self.isLoading = false
            return
        }

        isLoading = true

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        // Use a generous size for high-quality display on any device
        let targetSize = CGSize(width: 2000, height: 2000)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { result, _ in
            Task { @MainActor in
                if let result = result {
                    // Cache the full image
                    photoService.cacheFullImage(result, for: asset.localIdentifier)
                    self.image = result
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Video Thumbnail

struct VideoThumbnail: View {
    let asset: PHAsset
    var preserveAspectRatio: Bool = false
    var maxHeight: CGFloat = 80

    @State private var image: UIImage?
    private let photoService = RidePhotoService.shared

    /// Calculate the aspect ratio from the asset's pixel dimensions
    private var assetAspectRatio: CGFloat {
        guard asset.pixelHeight > 0 else { return 16.0 / 9.0 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    var body: some View {
        Group {
            if preserveAspectRatio {
                // Preserve original aspect ratio
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: maxHeight * assetAspectRatio, height: maxHeight)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: maxHeight * assetAspectRatio, height: maxHeight)
                            .overlay {
                                ProgressView()
                            }
                    }

                    // Play icon overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)

                    // Duration badge
                    if asset.duration > 0 {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(formatDuration(asset.duration))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(4)
                            }
                        }
                        .frame(width: maxHeight * assetAspectRatio, height: maxHeight)
                    }
                }
            } else {
                // Square thumbnail (original behavior)
                GeometryReader { geometry in
                    ZStack {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.width)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color(.secondarySystemBackground))
                                .overlay {
                                    ProgressView()
                                }
                        }

                        // Play icon overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)

                        // Duration badge
                        if asset.duration > 0 {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(formatDuration(asset.duration))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(.black.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .padding(4)
                                }
                            }
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        // Check cache first
        if let cached = photoService.getCachedThumbnail(for: asset.localIdentifier) {
            self.image = cached
            return
        }

        let size = CGSize(width: 200, height: 200)

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                photoService.cacheThumbnail(result, for: asset.localIdentifier)
                Task { @MainActor in
                    self.image = result
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Player

struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Loading video...")
                            .foregroundStyle(.white)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func loadVideo() {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true // Allow iCloud download

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            DispatchQueue.main.async {
                if let urlAsset = avAsset as? AVURLAsset {
                    let avPlayer = AVPlayer(url: urlAsset.url)
                    self.player = avPlayer
                    self.isLoading = false
                    avPlayer.play()
                } else if let error = info?[PHImageErrorKey] as? Error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                } else {
                    self.errorMessage = "Video not found in Photos library.\nIt may have been deleted."
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Helper Views

struct MediaPermissionView: View {
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("Photo Access Required")
                .font(.headline)

            Text("Allow TetraTrack to access your photos and videos to find media taken during your sessions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Allow Access", action: onRequestAccess)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct EmptyMediaView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Media Found")
                .font(.headline)

            Text("No photos or videos were taken during this session. Media taken within 1 hour of your session will appear here automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// Make PHAsset Identifiable for sheet presentation
extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

#Preview {
    NavigationStack {
        RideGalleryView(ride: Ride())
    }
}
