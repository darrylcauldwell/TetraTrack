//
//  ImageSourceSelectorView.swift
//  TrackRide
//
//  Presents available image sources for target scanning.
//  Shows Photo Library prominently on Simulator where camera is unavailable.
//

import SwiftUI
import PhotosUI

// MARK: - Image Source Selector View

/// View for selecting image source before scanning
struct ImageSourceSelectorView: View {
    let onImageSelected: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    #if DEBUG
    @State private var showingFixtureSelector = false
    #endif

    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)

                    Text("Select Target Image")
                        .font(.title2.bold())

                    Text("Choose how to provide your target image")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                Spacer()

                // Source options
                VStack(spacing: 16) {
                    // Camera option (primary on device)
                    if isCameraAvailable {
                        SourceOptionButton(
                            icon: "camera.fill",
                            title: "Take Photo",
                            subtitle: "Use camera to capture target",
                            color: .blue,
                            isPrimary: true
                        ) {
                            showingCamera = true
                        }
                    }

                    // Photo Library option (primary on Simulator)
                    SourceOptionButton(
                        icon: "photo.on.rectangle",
                        title: "Photo Library",
                        subtitle: "Select from your photos",
                        color: .green,
                        isPrimary: !isCameraAvailable
                    ) {
                        showingPhotoPicker = true
                    }

                    #if DEBUG
                    // Test fixtures option (debug only)
                    SourceOptionButton(
                        icon: "testtube.2",
                        title: "Test Fixtures",
                        subtitle: "Use bundled test images",
                        color: .orange,
                        isPrimary: false
                    ) {
                        showingFixtureSelector = true
                    }
                    #endif
                }
                .padding(.horizontal)

                Spacer()

                // Simulator hint
                #if targetEnvironment(simulator)
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Running in Simulator - camera unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                #endif
            }
            .navigationTitle("Scan Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            onImageSelected(image)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraOnlyView(onCapture: { image in
                    showingCamera = false
                    onImageSelected(image)
                }, onCancel: {
                    showingCamera = false
                })
            }
            #if DEBUG
            .sheet(isPresented: $showingFixtureSelector) {
                DebugFolderSelectorSheet(onImageSelected: { image in
                    showingFixtureSelector = false
                    onImageSelected(image)
                })
            }
            #endif
        }
    }
}

// MARK: - Source Option Button

private struct SourceOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isPrimary ? .white : color)
                    .frame(width: 44, height: 44)
                    .background(isPrimary ? color : color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(isPrimary ? color.opacity(0.1) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? color.opacity(0.3) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Debug Folder Selector Sheet

#if DEBUG
private struct DebugFolderSelectorSheet: View {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var folderSource = FolderFixtureSource()
    @State private var selectedFolder: FixtureFolder?

    var body: some View {
        NavigationStack {
            List {
                ForEach(folderSource.availableFolders) { folder in
                    Button {
                        selectedFolder = folder
                    } label: {
                        HStack {
                            Image(systemName: folder.source == .bundled ? "folder.fill" : "folder.badge.person.crop")
                                .foregroundStyle(folder.source == .bundled ? .orange : .blue)

                            VStack(alignment: .leading) {
                                Text(folder.displayName)
                                    .font(.headline)
                                Text("\(folder.imageCount) images")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Test Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedFolder) { folder in
                FolderImageListSheet(folder: folder, onImageSelected: onImageSelected)
            }
        }
    }
}

private struct FolderImageListSheet: View {
    let folder: FixtureFolder
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(folder.images) { image in
                        Button {
                            if let uiImage = image.loadImage() {
                                dismiss()
                                onImageSelected(uiImage)
                            }
                        } label: {
                            if let uiImage = image.loadImage() {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(folder.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    ImageSourceSelectorView(
        onImageSelected: { _ in },
        onCancel: { }
    )
}
