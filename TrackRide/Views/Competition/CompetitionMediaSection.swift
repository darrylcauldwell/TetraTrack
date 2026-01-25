//
//  CompetitionMediaSection.swift
//  TrackRide
//
//  Photo and video picker for competition entries
//  Videos are stored as references to Apple Photos (iCloud synced)
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import AVKit

// MARK: - Competition Media Section (for editing)

struct CompetitionMediaSection: View {
    @Binding var photos: [Data]
    @Binding var videoAssetIdentifiers: [String]
    @Binding var videoThumbnails: [Data]

    let maxPhotos: Int
    let maxVideos: Int

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var isLoadingVideos = false
    @State private var showingPhotoAccessAlert = false

    init(
        photos: Binding<[Data]>,
        videoAssetIdentifiers: Binding<[String]>,
        videoThumbnails: Binding<[Data]>,
        maxPhotos: Int = 10,
        maxVideos: Int = 5
    ) {
        self._photos = photos
        self._videoAssetIdentifiers = videoAssetIdentifiers
        self._videoThumbnails = videoThumbnails
        self.maxPhotos = maxPhotos
        self.maxVideos = maxVideos
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            photosSection
            Divider()
            videosSection
        }
        .alert("Photo Library Access", isPresented: $showingPhotoAccessAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow access to your Photo Library in Settings to attach videos.")
        }
    }

    // MARK: - Photos Section

    @ViewBuilder
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle")
                    .foregroundStyle(.blue)
                Text("Photos")
                    .font(.headline)
                Spacer()
                Text("\(photos.count)/\(maxPhotos)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !photos.isEmpty {
                photoGrid
            }

            if photos.count < maxPhotos {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: maxPhotos - photos.count,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text(photos.isEmpty ? "Add Photos" : "Add More Photos")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.elevatedSurface)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLoadingPhotos)
                .overlay {
                    if isLoadingPhotos {
                        ProgressView()
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            loadPhotos(from: newItems)
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                    if let uiImage = UIImage(data: photoData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button {
                                withAnimation {
                                    _ = photos.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .offset(x: 6, y: -6)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Videos Section

    @ViewBuilder
    private var videosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundStyle(.purple)
                Text("Videos")
                    .font(.headline)
                Spacer()
                Text("\(videoAssetIdentifiers.count)/\(maxVideos)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !videoAssetIdentifiers.isEmpty {
                videoGrid
            }

            if videoAssetIdentifiers.count < maxVideos {
                PhotosPicker(
                    selection: $selectedVideoItems,
                    maxSelectionCount: maxVideos - videoAssetIdentifiers.count,
                    matching: .videos
                ) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                        Text(videoAssetIdentifiers.isEmpty ? "Add Videos" : "Add More Videos")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.elevatedSurface)
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLoadingVideos)
                .overlay {
                    if isLoadingVideos {
                        ProgressView()
                    }
                }

                Text("Videos stay in your Photos library (synced via iCloud Photos). Only a link is stored here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedVideoItems) { _, newItems in
            loadVideoReferences(from: newItems)
        }
    }

    @ViewBuilder
    private var videoGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(videoAssetIdentifiers.enumerated()), id: \.offset) { index, _ in
                    ZStack(alignment: .topTrailing) {
                        if index < videoThumbnails.count,
                           let uiImage = UIImage(data: videoThumbnails[index]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    Image(systemName: "play.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 90)
                                .overlay {
                                    Image(systemName: "video.fill")
                                        .font(.title)
                                        .foregroundStyle(.secondary)
                                }
                        }

                        Button {
                            withAnimation {
                                _ = videoAssetIdentifiers.remove(at: index)
                                if index < videoThumbnails.count {
                                    _ = videoThumbnails.remove(at: index)
                                }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.5)))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
        }
    }

    // MARK: - Photo Loading

    private func loadPhotos(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoadingPhotos = true

        let itemsCopy = items
        let group = DispatchGroup()

        for item in itemsCopy {
            group.enter()
            item.loadTransferable(type: Data.self) { result in
                defer { group.leave() }
                if case .success(let data) = result,
                   let data = data,
                   let uiImage = UIImage(data: data),
                   let compressed = compressImage(uiImage) {
                    DispatchQueue.main.async {
                        if photos.count < maxPhotos {
                            photos.append(compressed)
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            selectedPhotoItems = []
            isLoadingPhotos = false
        }
    }

    private func compressImage(_ image: UIImage) -> Data? {
        let maxSize: CGFloat = 1024
        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage?.jpegData(compressionQuality: 0.7)
    }

    // MARK: - Video Reference Loading

    private func loadVideoReferences(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoadingVideos = true

        // Request photo library access for reading asset identifiers
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    isLoadingVideos = false
                    selectedVideoItems = []
                    showingPhotoAccessAlert = true
                }
                return
            }

            let itemsCopy = items
            let group = DispatchGroup()

            for item in itemsCopy {
                group.enter()

                // Get the asset identifier from the PhotosPickerItem
                if let assetIdentifier = item.itemIdentifier {
                    // Fetch the PHAsset to generate thumbnail
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)

                    if let asset = fetchResult.firstObject {
                        // Generate thumbnail
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        options.resizeMode = .exact
                        options.isSynchronous = false

                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: CGSize(width: 400, height: 300),
                            contentMode: .aspectFill,
                            options: options
                        ) { image, _ in
                            defer { group.leave() }

                            if let image = image,
                               let thumbnailData = image.jpegData(compressionQuality: 0.7) {
                                DispatchQueue.main.async {
                                    if videoAssetIdentifiers.count < maxVideos {
                                        videoAssetIdentifiers.append(assetIdentifier)
                                        videoThumbnails.append(thumbnailData)
                                    }
                                }
                            }
                        }
                    } else {
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                selectedVideoItems = []
                isLoadingVideos = false
            }
        }
    }
}

// MARK: - Competition Media Gallery (for detail views)

struct CompetitionMediaGallery: View {
    let photos: [Data]
    let videoAssetIdentifiers: [String]
    let videoThumbnails: [Data]

    @State private var selectedPhotoIndex: Int?
    @State private var selectedVideoIdentifier: String?

    var body: some View {
        if !photos.isEmpty || !videoAssetIdentifiers.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Photos
                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundStyle(.blue)
                            Text("Photos")
                                .font(.headline)
                            Spacer()
                            Text("\(photos.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                                    if let uiImage = UIImage(data: photoData) {
                                        Button {
                                            selectedPhotoIndex = index
                                        } label: {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Videos
                if !videoAssetIdentifiers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "video.fill")
                                .foregroundStyle(.purple)
                            Text("Videos")
                                .font(.headline)
                            Spacer()
                            Text("\(videoAssetIdentifiers.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(videoAssetIdentifiers.enumerated()), id: \.offset) { index, identifier in
                                    Button {
                                        selectedVideoIdentifier = identifier
                                    } label: {
                                        ZStack {
                                            if index < videoThumbnails.count,
                                               let uiImage = UIImage(data: videoThumbnails[index]) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 160, height: 120)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            } else {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 160, height: 120)
                                            }

                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 44))
                                                .foregroundStyle(.white)
                                                .shadow(radius: 3)
                                        }
                                    }
                                }
                            }
                        }

                        Text("Videos play from your Photos library")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .fullScreenCover(item: Binding(
                get: { selectedPhotoIndex.map { PhotoGalleryItem(index: $0) } },
                set: { selectedPhotoIndex = $0?.index }
            )) { item in
                CompetitionPhotoViewer(photos: photos, initialIndex: item.index) {
                    selectedPhotoIndex = nil
                }
            }
            .fullScreenCover(item: Binding(
                get: { selectedVideoIdentifier.map { VideoIdentifierItem(identifier: $0) } },
                set: { selectedVideoIdentifier = $0?.identifier }
            )) { item in
                PhotosVideoPlayer(assetIdentifier: item.identifier) {
                    selectedVideoIdentifier = nil
                }
            }
        }
    }
}

// Helper structs for fullScreenCover
private struct PhotoGalleryItem: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct VideoIdentifierItem: Identifiable {
    let identifier: String
    var id: String { identifier }
}

// MARK: - Competition Photo Viewer

struct CompetitionPhotoViewer: View {
    let photos: [Data]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0

    init(photos: [Data], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                    if let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = value
                                    }
                                    .onEnded { _ in
                                        withAnimation {
                                            scale = 1.0
                                        }
                                    }
                            )
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
            }

            VStack {
                Spacer()
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Photos Library Video Player

struct PhotosVideoPlayer: View {
    let assetIdentifier: String
    let onDismiss: () -> Void

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading video...")
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        player?.pause()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            loadVideoFromPhotos()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func loadVideoFromPhotos() {
        // Fetch the PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)

        guard let asset = fetchResult.firstObject else {
            errorMessage = "Video not found in Photos library.\nIt may have been deleted."
            isLoading = false
            return
        }

        // Request the video
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true // Allow downloading from iCloud

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            DispatchQueue.main.async {
                if let urlAsset = avAsset as? AVURLAsset {
                    let avPlayer = AVPlayer(url: urlAsset.url)
                    self.player = avPlayer
                    self.isLoading = false
                    avPlayer.play()
                } else if let avAsset = avAsset {
                    // For non-URL assets, create a player item directly
                    let playerItem = AVPlayerItem(asset: avAsset)
                    let avPlayer = AVPlayer(playerItem: playerItem)
                    self.player = avPlayer
                    self.isLoading = false
                    avPlayer.play()
                } else {
                    self.errorMessage = "Could not load video.\nIt may still be downloading from iCloud."
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Competition Media Editor View

struct CompetitionMediaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var competition: Competition

    @State private var photos: [Data] = []
    @State private var videoAssetIdentifiers: [String] = []
    @State private var videoThumbnails: [Data] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: competition.competitionType.icon)
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.primary)
                        Text(competition.name)
                            .font(.headline)
                        Text(competition.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    CompetitionMediaSection(
                        photos: $photos,
                        videoAssetIdentifiers: $videoAssetIdentifiers,
                        videoThumbnails: $videoThumbnails
                    )
                } header: {
                    Text("Photos & Videos")
                } footer: {
                    Text("Photos are stored in the app. Videos are linked to your Photos library and stay synced via iCloud Photos.")
                }
            }
            .navigationTitle("Competition Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMedia()
                    }
                }
            }
            .onAppear {
                loadMedia()
            }
        }
    }

    private func loadMedia() {
        photos = competition.photos
        videoAssetIdentifiers = competition.videoAssetIdentifiers
        videoThumbnails = competition.videoThumbnails
    }

    private func saveMedia() {
        competition.photos = photos
        competition.videoAssetIdentifiers = videoAssetIdentifiers
        competition.videoThumbnails = videoThumbnails
        dismiss()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var photos: [Data] = []
        @State var videoIds: [String] = []
        @State var videoThumbnails: [Data] = []

        var body: some View {
            Form {
                Section("Media") {
                    CompetitionMediaSection(
                        photos: $photos,
                        videoAssetIdentifiers: $videoIds,
                        videoThumbnails: $videoThumbnails
                    )
                }
            }
        }
    }

    return PreviewWrapper()
}
