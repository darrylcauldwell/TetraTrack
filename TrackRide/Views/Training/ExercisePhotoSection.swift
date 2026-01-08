//
//  ExercisePhotoSection.swift
//  TrackRide
//
//  Reusable photo picker and gallery for exercise library
//  Videos are stored as references to Apple Photos (iCloud synced)
//

import SwiftUI
import PhotosUI
import Photos
import AVFoundation
import AVKit

// MARK: - Exercise Photo Section (for editors - photos only, legacy support)

struct ExercisePhotoSection: View {
    @Binding var photos: [Data]
    let maxPhotos: Int
    let canEdit: Bool

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading = false

    init(photos: Binding<[Data]>, maxPhotos: Int = 5, canEdit: Bool = true) {
        self._photos = photos
        self.maxPhotos = maxPhotos
        self.canEdit = canEdit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photoGrid
            addPhotoButton
            photoCountLabel
        }
        .onChange(of: selectedItems) { oldItems, newItems in
            handlePhotoSelection(newItems)
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                        photoThumbnail(data: photoData, index: index)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(data: Data, index: Int) -> some View {
        if let uiImage = UIImage(data: data) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if canEdit {
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

    @ViewBuilder
    private var addPhotoButton: some View {
        if canEdit && photos.count < maxPhotos {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: maxPhotos - photos.count,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                    Text(photos.isEmpty ? "Add Photos" : "Add More Photos")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private var photoCountLabel: some View {
        if canEdit {
            Text("\(photos.count)/\(maxPhotos) photos")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoading = true

        let itemsCopy = items
        let currentMax = maxPhotos
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
                        if photos.count < currentMax {
                            photos.append(compressed)
                        }
                    }
                }
            }
        }

        group.notify(queue: .main) {
            selectedItems = []
            isLoading = false
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
}

// MARK: - Exercise Media Section (photos + videos for editors)

struct ExerciseMediaSection: View {
    @Binding var photos: [Data]
    @Binding var videoAssetIdentifiers: [String]
    @Binding var videoThumbnails: [Data]
    let canEdit: Bool

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
        canEdit: Bool = true,
        maxPhotos: Int = 5,
        maxVideos: Int = 3
    ) {
        self._photos = photos
        self._videoAssetIdentifiers = videoAssetIdentifiers
        self._videoThumbnails = videoThumbnails
        self.canEdit = canEdit
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
                    .font(.subheadline.bold())
                Spacer()
                Text("\(photos.count)/\(maxPhotos)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !photos.isEmpty {
                photoGrid
            }

            if canEdit && photos.count < maxPhotos {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: maxPhotos - photos.count,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text(photos.isEmpty ? "Add Photos" : "Add More")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
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
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            if canEdit {
                                Button {
                                    withAnimation {
                                        _ = photos.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.callout)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
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
                    .font(.subheadline.bold())
                Spacer()
                Text("\(videoAssetIdentifiers.count)/\(maxVideos)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !videoAssetIdentifiers.isEmpty {
                videoGrid
            }

            if canEdit && videoAssetIdentifiers.count < maxVideos {
                PhotosPicker(
                    selection: $selectedVideoItems,
                    maxSelectionCount: maxVideos - videoAssetIdentifiers.count,
                    matching: .videos
                ) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                        Text(videoAssetIdentifiers.isEmpty ? "Add Videos" : "Add More")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLoadingVideos)
                .overlay {
                    if isLoadingVideos {
                        ProgressView()
                    }
                }

                Text("Videos stay in Photos (synced via iCloud)")
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
                                .frame(width: 100, height: 75)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 75)
                                .overlay {
                                    Image(systemName: "video.fill")
                                        .foregroundStyle(.secondary)
                                }
                        }

                        if canEdit {
                            Button {
                                withAnimation {
                                    _ = videoAssetIdentifiers.remove(at: index)
                                    if index < videoThumbnails.count {
                                        _ = videoThumbnails.remove(at: index)
                                    }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.callout)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .offset(x: 4, y: -4)
                        }
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

                if let assetIdentifier = item.itemIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)

                    if let asset = fetchResult.firstObject {
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

// MARK: - Exercise Media Gallery (for detail views)

struct ExerciseMediaGallery: View {
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
                get: { selectedPhotoIndex.map { ExercisePhotoViewerItem(index: $0) } },
                set: { selectedPhotoIndex = $0?.index }
            )) { item in
                ExercisePhotoFullScreenViewer(photos: photos, initialIndex: item.index) {
                    selectedPhotoIndex = nil
                }
            }
            .fullScreenCover(item: Binding(
                get: { selectedVideoIdentifier.map { ExerciseVideoViewerItem(identifier: $0) } },
                set: { selectedVideoIdentifier = $0?.identifier }
            )) { item in
                ExerciseVideoPlayer(assetIdentifier: item.identifier) {
                    selectedVideoIdentifier = nil
                }
            }
        }
    }
}

// MARK: - Exercise Photo Gallery (legacy - photos only)

struct ExercisePhotoGallery: View {
    let photos: [Data]
    @State private var selectedPhotoIndex: Int?

    var body: some View {
        if !photos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(.blue)
                    Text("Photos")
                        .font(.headline)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photoData in
                            galleryThumbnail(data: photoData, index: index)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .fullScreenCover(item: Binding(
                get: { selectedPhotoIndex.map { PhotoViewerItem(index: $0) } },
                set: { selectedPhotoIndex = $0?.index }
            )) { item in
                PhotoViewer(photos: photos, initialIndex: item.index) {
                    selectedPhotoIndex = nil
                }
            }
        }
    }

    @ViewBuilder
    private func galleryThumbnail(data: Data, index: Int) -> some View {
        if let uiImage = UIImage(data: data) {
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

// Helper structs for fullScreenCover
private struct PhotoViewerItem: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct ExercisePhotoViewerItem: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct ExerciseVideoViewerItem: Identifiable {
    let identifier: String
    var id: String { identifier }
}

// MARK: - Full Screen Photo Viewer

struct ExercisePhotoFullScreenViewer: View {
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

// MARK: - Exercise Video Player

struct ExerciseVideoPlayer: View {
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
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)

        guard let asset = fetchResult.firstObject else {
            errorMessage = "Video not found in Photos library.\nIt may have been deleted."
            isLoading = false
            return
        }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            DispatchQueue.main.async {
                if let urlAsset = avAsset as? AVURLAsset {
                    let avPlayer = AVPlayer(url: urlAsset.url)
                    self.player = avPlayer
                    self.isLoading = false
                    avPlayer.play()
                } else if let avAsset = avAsset {
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

// MARK: - Legacy PhotoViewer (kept for backwards compatibility)

struct PhotoViewer: View {
    let photos: [Data]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

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
                    photoPage(data: photoData, index: index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))

            closeButton
            photoCounter
        }
    }

    @ViewBuilder
    private func photoPage(data: Data, index: Int) -> some View {
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
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

    private var closeButton: some View {
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
    }

    private var photoCounter: some View {
        VStack {
            Spacer()
            Text("\(currentIndex + 1) / \(photos.count)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.bottom, 60)
        }
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
                    ExerciseMediaSection(
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
