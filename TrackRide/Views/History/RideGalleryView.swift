//
//  RideGalleryView.swift
//  TrackRide
//
//  Display photos taken during a ride
//

import SwiftUI
import Photos

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
                            await photoService.requestAuthorization()
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
        photos = await photoService.findPhotosForRide(ride)
        isLoading = false
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset

    @State private var image: UIImage?
    private let photoService = RidePhotoService.shared

    var body: some View {
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

        let targetSize = CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)

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

// Make PHAsset Identifiable for sheet presentation
extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}

#Preview {
    NavigationStack {
        RideGalleryView(ride: Ride())
    }
}
