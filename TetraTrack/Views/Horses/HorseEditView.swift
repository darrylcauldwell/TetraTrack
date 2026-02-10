//
//  HorseEditView.swift
//  TetraTrack
//
//  Form for adding or editing a horse

import SwiftUI
import SwiftData
import PhotosUI

struct HorseEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let horse: Horse?

    @State private var name: String = ""
    @State private var breedType: HorseBreed = .unknown
    @State private var breed: String = ""  // Optional specific breed name within category
    @State private var color: String = ""
    @State private var dateOfBirth: Date?
    @State private var weight: Double?
    @State private var heightHands: Double?
    @State private var notes: String = ""

    // Photo - Apple Photos link
    @State private var photoAssetIdentifier: String?
    @State private var photoThumbnail: Data?

    // Videos - Apple Photos links
    @State private var videoAssetIdentifiers: [String] = []
    @State private var videoThumbnails: [Data] = []

    // Legacy photo data (for backwards compatibility)
    @State private var legacyPhotoData: Data?

    @State private var showingWeightPicker = false
    @State private var showingDatePicker = false
    @State private var showingHeightPicker = false

    private var isEditing: Bool { horse != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo Section
                Section {
                    HorseProfilePhotoSection(
                        photoAssetIdentifier: $photoAssetIdentifier,
                        photoThumbnail: $photoThumbnail,
                        legacyPhotoData: $legacyPhotoData
                    )
                    .listRowBackground(Color.clear)
                }

                // Basic Info
                Section("Basic Information") {
                    TextField("Name", text: $name)

                    // Breed Type - editable only when adding new horse or breed not yet set
                    if isEditing && horse?.typedBreed != .unknown {
                        // Read-only display for existing horses with breed set
                        HStack {
                            Text("Breed Type")
                            Spacer()
                            Text(breedType.displayName)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Editable picker for new horses or when breed not yet set
                        Picker("Breed Type", selection: $breedType) {
                            ForEach(HorseBreed.allCases) { breed in
                                Text(breed.displayName).tag(breed)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    // Optional specific breed name (for display) - also read-only if breed is set
                    if isEditing && horse?.typedBreed != .unknown {
                        HStack {
                            Text("Specific Breed")
                            Spacer()
                            Text(breed.isEmpty ? "Not specified" : breed)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        TextField("Specific Breed (optional)", text: $breed)
                            .textInputAutocapitalization(.words)
                    }

                    TextField("Color", text: $color)
                }

                // Breed Info
                if breedType != .unknown {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("Gait detection will use \(breedType.displayName) biomechanical characteristics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Details
                Section("Details") {
                    // Date of Birth
                    Button(action: { showingDatePicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .frame(width: 24)
                                .foregroundStyle(.primary)
                            Text("Born")
                                .lineLimit(1)
                            Spacer()
                            if let dob = dateOfBirth {
                                Text(dob.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not Set")
                                    .foregroundStyle(.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    // Weight
                    Button(action: { showingWeightPicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass")
                                .frame(width: 24)
                                .foregroundStyle(.primary)
                            Text("Weight")
                                .lineLimit(1)
                            Spacer()
                            if let w = weight {
                                Text(String(format: "%.0f kg", w))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not Set")
                                    .foregroundStyle(.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    // Height
                    Button(action: { showingHeightPicker = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "ruler")
                                .frame(width: 24)
                                .foregroundStyle(.primary)
                            Text("Height")
                                .lineLimit(1)
                            Spacer()
                            if let h = heightHands {
                                Text(formatHeight(h))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not Set")
                                    .foregroundStyle(.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .writingToolsBehavior(.complete)
                }

                // Videos Section
                Section {
                    HorseVideoSection(
                        videoAssetIdentifiers: $videoAssetIdentifiers,
                        videoThumbnails: $videoThumbnails
                    )
                } header: {
                    Text("Videos")
                } footer: {
                    Text("Add videos from your Photos library. Videos stay in Photos and are linked here.")
                }
            }
            .navigationTitle(isEditing ? "Edit Horse" : "Add Horse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveHorse()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingWeightPicker) {
                HorseWeightPickerView(weight: $weight)
            }
            .sheet(isPresented: $showingDatePicker) {
                HorseDateOfBirthPickerView(dateOfBirth: $dateOfBirth)
            }
            .sheet(isPresented: $showingHeightPicker) {
                HorseHeightPickerView(heightHands: $heightHands)
            }
            .onAppear {
                if let horse = horse {
                    name = horse.name
                    breedType = horse.typedBreed
                    breed = horse.breed
                    color = horse.color
                    dateOfBirth = horse.dateOfBirth
                    weight = horse.weight
                    heightHands = horse.heightHands
                    notes = horse.notes
                    // Load photo data
                    photoAssetIdentifier = horse.photoAssetIdentifier
                    photoThumbnail = horse.photoThumbnail
                    legacyPhotoData = horse.photoData
                    // Load video data
                    videoAssetIdentifiers = horse.videoAssetIdentifiers
                    videoThumbnails = horse.videoThumbnails
                }
            }
            .presentationBackground(Color.black)
        }
    }

    private func saveHorse() {
        if let horse = horse {
            // Update existing
            horse.name = name
            horse.typedBreed = breedType
            horse.breed = breed
            horse.color = color
            horse.dateOfBirth = dateOfBirth
            horse.weight = weight
            horse.heightHands = heightHands
            horse.notes = notes
            // Save photo data
            horse.photoAssetIdentifier = photoAssetIdentifier
            horse.photoThumbnail = photoThumbnail
            // Clear legacy data if using Apple Photos link
            if photoAssetIdentifier != nil {
                horse.photoData = nil
            } else {
                horse.photoData = legacyPhotoData
            }
            // Save video data
            horse.videoAssetIdentifiers = videoAssetIdentifiers
            horse.videoThumbnails = videoThumbnails
            horse.updatedAt = Date()
        } else {
            // Create new
            let newHorse = Horse()
            newHorse.name = name
            newHorse.typedBreed = breedType
            newHorse.breed = breed
            newHorse.color = color
            newHorse.dateOfBirth = dateOfBirth
            newHorse.weight = weight
            newHorse.heightHands = heightHands
            newHorse.notes = notes
            // Save photo data
            newHorse.photoAssetIdentifier = photoAssetIdentifier
            newHorse.photoThumbnail = photoThumbnail
            if photoAssetIdentifier == nil {
                newHorse.photoData = legacyPhotoData
            }
            // Save video data
            newHorse.videoAssetIdentifiers = videoAssetIdentifiers
            newHorse.videoThumbnails = videoThumbnails
            modelContext.insert(newHorse)
        }
    }

    private func formatHeight(_ height: Double) -> String {
        let hands = Int(height)
        let inches = Int(round((height - Double(hands)) * 10))
        return "\(hands).\(inches)hh"
    }
}

// MARK: - Weight Picker

struct HorseWeightPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weight: Double?
    @State private var selectedWeight: Double = 500.0

    var body: some View {
        NavigationStack {
            VStack {
                Text("\(Int(selectedWeight)) kg")
                    .scaledFont(size: 48, weight: .bold, relativeTo: .largeTitle)
                    .padding()

                Picker("Weight", selection: $selectedWeight) {
                    ForEach(Array(stride(from: 200.0, through: 800.0, by: 5.0)), id: \.self) { value in
                        Text("\(Int(value)) kg").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        weight = selectedWeight
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let w = weight {
                    selectedWeight = w
                }
            }
        }
    }
}

// MARK: - Date of Birth Picker

struct HorseDateOfBirthPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dateOfBirth: Date?
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Date of Birth",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dateOfBirth = selectedDate
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let dob = dateOfBirth {
                    selectedDate = dob
                }
            }
        }
    }
}

// MARK: - Height Picker

struct HorseHeightPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var heightHands: Double?
    @State private var selectedHands: Int = 15
    @State private var selectedInches: Int = 2

    var body: some View {
        NavigationStack {
            VStack {
                Text("\(selectedHands).\(selectedInches)hh")
                    .scaledFont(size: 48, weight: .bold, relativeTo: .largeTitle)
                    .padding()

                HStack {
                    // Hands picker
                    VStack {
                        Text("Hands")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Hands", selection: $selectedHands) {
                            ForEach(10...18, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }

                    Text(".")
                        .scaledFont(size: 48, weight: .bold, relativeTo: .largeTitle)

                    // Inches picker (0-3, as 4 inches = 1 hand)
                    VStack {
                        Text("Inches")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Inches", selection: $selectedInches) {
                            ForEach(0...3, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }
                }
            }
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        heightHands = Double(selectedHands) + Double(selectedInches) / 10.0
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let h = heightHands {
                    selectedHands = Int(h)
                    // Use round() to avoid floating-point precision issues (e.g., 14.2 becoming 14.1)
                    selectedInches = Int(round((h - Double(Int(h))) * 10))
                }
            }
        }
    }
}

// MARK: - Profile Photo Section

import Photos

struct HorseProfilePhotoSection: View {
    @Binding var photoAssetIdentifier: String?
    @Binding var photoThumbnail: Data?
    @Binding var legacyPhotoData: Data?

    @State private var showingPhotoPicker = false
    @State private var showingActionSheet = false

    private var displayImage: UIImage? {
        if let data = photoThumbnail, let image = UIImage(data: data) {
            return image
        }
        if let data = legacyPhotoData, let image = UIImage(data: data) {
            return image
        }
        return nil
    }

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.primary.opacity(0.2), lineWidth: 2)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "figure.equestrian.sports")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.primary)
                    }
                }

                Button {
                    if photoAssetIdentifier != nil || legacyPhotoData != nil {
                        showingActionSheet = true
                    } else {
                        showingPhotoPicker = true
                    }
                } label: {
                    Text(displayImage == nil ? "Add Photo" : "Change Photo")
                        .font(.subheadline)
                }
            }
            Spacer()
        }
        .sheet(isPresented: $showingPhotoPicker) {
            HorsePhotoPicker(
                photoAssetIdentifier: $photoAssetIdentifier,
                photoThumbnail: $photoThumbnail,
                legacyPhotoData: $legacyPhotoData
            )
            .presentationBackground(Color.black)
        }
        .confirmationDialog("Photo", isPresented: $showingActionSheet) {
            Button("Choose New Photo") {
                showingPhotoPicker = true
            }
            Button("Remove Photo", role: .destructive) {
                photoAssetIdentifier = nil
                photoThumbnail = nil
                legacyPhotoData = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Horse Photo Picker

struct HorsePhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photoAssetIdentifier: String?
    @Binding var photoThumbnail: Data?
    @Binding var legacyPhotoData: Data?

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 60))
                            .foregroundStyle(AppColors.primary)

                        Text("Select Photo from Library")
                            .font(.headline)

                        Text("Choose a photo from your Apple Photos library")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if isLoading {
                    ProgressView("Loading photo...")
                        .padding()
                }
            }
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let item = newValue else { return }
                isLoading = true

                // Get the PHAsset local identifier
                if let assetId = item.itemIdentifier {
                    photoAssetIdentifier = assetId

                    // Fetch thumbnail from Photos library
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                    if let asset = fetchResult.firstObject {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        options.resizeMode = .exact
                        options.isNetworkAccessAllowed = true

                        let targetSize = CGSize(width: 400, height: 400)

                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: targetSize,
                            contentMode: .aspectFill,
                            options: options
                        ) { image, _ in
                            DispatchQueue.main.async {
                                if let image = image {
                                    photoThumbnail = image.jpegData(compressionQuality: 0.8)
                                    legacyPhotoData = nil  // Clear legacy data
                                }
                                isLoading = false
                                dismiss()
                            }
                        }
                    } else {
                        isLoading = false
                        dismiss()
                    }
                } else {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Video Section

struct HorseVideoSection: View {
    @Binding var videoAssetIdentifiers: [String]
    @Binding var videoThumbnails: [Data]

    @State private var showingVideoPicker = false
    @State private var selectedVideoIndex: Int?
    @State private var showingVideoPlayer = false

    private let maxVideos = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Video thumbnails
            if !videoThumbnails.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(videoThumbnails.enumerated()), id: \.offset) { index, thumbnailData in
                            ZStack(alignment: .topTrailing) {
                                if let image = UIImage(data: thumbnailData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 75)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            Image(systemName: "play.circle.fill")
                                                .font(.title)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        )
                                        .onTapGesture {
                                            selectedVideoIndex = index
                                            showingVideoPlayer = true
                                        }
                                }

                                // Delete button
                                Button {
                                    removeVideo(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white, .red)
                                        .shadow(radius: 1)
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Add video button
            if videoAssetIdentifiers.count < maxVideos {
                Button {
                    showingVideoPicker = true
                } label: {
                    Label("Add Video", systemImage: "video.badge.plus")
                }
            } else {
                Text("Maximum \(maxVideos) videos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingVideoPicker) {
            HorseVideoPicker(
                videoAssetIdentifiers: $videoAssetIdentifiers,
                videoThumbnails: $videoThumbnails
            )
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let index = selectedVideoIndex, index < videoAssetIdentifiers.count {
                HorseVideoPlayer(assetIdentifier: videoAssetIdentifiers[index])
            }
        }
        .presentationBackground(Color.black)
    }

    private func removeVideo(at index: Int) {
        guard index < videoAssetIdentifiers.count && index < videoThumbnails.count else { return }
        videoAssetIdentifiers.remove(at: index)
        videoThumbnails.remove(at: index)
    }
}

// MARK: - Horse Video Picker

struct HorseVideoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var videoAssetIdentifiers: [String]
    @Binding var videoThumbnails: [Data]

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(AppColors.primary)

                        Text("Select Video from Library")
                            .font(.headline)

                        Text("Videos stay in your Photos library and are linked here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if isLoading {
                    ProgressView("Loading video...")
                        .padding()
                }
            }
            .navigationTitle("Select Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let item = newValue else { return }
                isLoading = true

                if let assetId = item.itemIdentifier {
                    // Check if already added
                    guard !videoAssetIdentifiers.contains(assetId) else {
                        isLoading = false
                        dismiss()
                        return
                    }

                    // Fetch thumbnail
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                    if let asset = fetchResult.firstObject {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        options.isNetworkAccessAllowed = true

                        let targetSize = CGSize(width: 200, height: 150)

                        PHImageManager.default().requestImage(
                            for: asset,
                            targetSize: targetSize,
                            contentMode: .aspectFill,
                            options: options
                        ) { image, _ in
                            DispatchQueue.main.async {
                                if let image = image, let thumbnailData = image.jpegData(compressionQuality: 0.7) {
                                    videoAssetIdentifiers.append(assetId)
                                    videoThumbnails.append(thumbnailData)
                                }
                                isLoading = false
                                dismiss()
                            }
                        }
                    } else {
                        isLoading = false
                        dismiss()
                    }
                } else {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Horse Video Player

import AVKit

struct HorseVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    let assetIdentifier: String

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading video...")
                        .foregroundStyle(.white)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text(error)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                loadVideo()
            }
            .onDisappear {
                player?.pause()
            }
        }
    }

    private func loadVideo() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            errorMessage = "Video not found in Photos library"
            isLoading = false
            return
        }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
            DispatchQueue.main.async {
                if let urlAsset = avAsset as? AVURLAsset {
                    self.player = AVPlayer(url: urlAsset.url)
                    self.player?.play()
                    self.isLoading = false
                } else if let error = info?[PHImageErrorKey] as? Error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                } else {
                    self.errorMessage = "Unable to load video"
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    HorseEditView(horse: nil)
        .modelContainer(for: [Horse.self], inMemory: true)
}
