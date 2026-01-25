//
//  DebugFolderSelectorView.swift
//  TrackRide
//
//  Debug-only UI for selecting test fixture folders in Simulator.
//  Allows batch processing and single image selection.
//

import SwiftUI

#if DEBUG

// MARK: - Folder Selector View

/// Debug view for selecting test fixture folders
struct DebugFolderSelectorView: View {
    @Environment(\.dismiss) private var dismiss

    let onFolderSelected: (FixtureFolder) -> Void
    let onImageSelected: ((FolderFixtureImage, FixtureFolder) -> Void)?
    let onBatchProcess: ((FixtureFolder) -> Void)?

    @State private var folderSource = FolderFixtureSource()
    @State private var selectedFolder: FixtureFolder?
    @State private var showingImagePicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(
        onFolderSelected: @escaping (FixtureFolder) -> Void,
        onImageSelected: ((FolderFixtureImage, FixtureFolder) -> Void)? = nil,
        onBatchProcess: ((FixtureFolder) -> Void)? = nil
    ) {
        self.onFolderSelected = onFolderSelected
        self.onImageSelected = onImageSelected
        self.onBatchProcess = onBatchProcess
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading folders...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if folderSource.availableFolders.isEmpty {
                    emptyStateView
                } else {
                    folderList
                }
            }
            .navigationTitle("Test Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showFolderInstructions()
                        } label: {
                            Label("Setup Instructions", systemImage: "questionmark.circle")
                        }

                        Button {
                            openDocumentsFolder()
                        } label: {
                            Label("Open Documents Folder", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingImagePicker) {
                if let folder = selectedFolder {
                    FolderImagePickerView(
                        folder: folder,
                        onImageSelected: { image in
                            onImageSelected?(image, folder)
                            dismiss()
                        },
                        onBatchProcess: onBatchProcess != nil ? {
                            onBatchProcess?(folder)
                            dismiss()
                        } : nil
                    )
                }
            }
            .presentationBackground(Color.black)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Test Folders Found")
                .font(.headline)

            Text("Add target images to test the detection pipeline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Setup Instructions:")
                    .font(.subheadline.bold())

                instructionRow(number: 1, text: "Create a folder in the app's Documents directory named 'SimulatorTargets'")
                instructionRow(number: 2, text: "Add subfolders for different test sets (e.g., 'HighHoleDensity')")
                instructionRow(number: 3, text: "Add .jpg images following the naming convention: target_YYYYMMDD_##.jpg")
                instructionRow(number: 4, text: "Optionally add metadata.json with expected hole positions")
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Button {
                openDocumentsFolder()
            } label: {
                Label("Open Documents Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Folder List

    private var folderList: some View {
        List {
            Section {
                ForEach(folderSource.availableFolders) { folder in
                    FolderRow(folder: folder)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFolder = folder
                            showingImagePicker = true
                        }
                }
            } header: {
                Text("Available Folders")
            } footer: {
                Text("Tap a folder to select individual images or batch process all images.")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func showFolderInstructions() {
        // Show instructions alert
        errorMessage = """
        To add test images:

        1. Open Finder and navigate to:
           ~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/SimulatorTargets/

        2. Create subfolders for different test conditions

        3. Add .jpg images with naming: target_YYYYMMDD_##.jpg

        4. Add optional metadata.json with hole positions
        """
    }

    private func openDocumentsFolder() {
        #if targetEnvironment(simulator)
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Create the SimulatorTargets folder if needed
            let targetsURL = documentsURL.appendingPathComponent("SimulatorTargets")
            try? FileManager.default.createDirectory(at: targetsURL, withIntermediateDirectories: true)

            // Print path for developer convenience
            print("📁 Simulator targets folder: \(targetsURL.path)")
        }
        #endif
    }
}

// MARK: - Folder Row

private struct FolderRow: View {
    let folder: FixtureFolder

    var body: some View {
        HStack(spacing: 12) {
            // Folder icon with source indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(folder.source == .bundled ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))

                Image(systemName: folder.source == .bundled ? "folder.fill" : "folder.badge.person.crop")
                    .foregroundStyle(folder.source == .bundled ? .blue : .orange)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.displayName)
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    Label("\(folder.imageCount)", systemImage: "photo")

                    if let desc = folder.description {
                        Text(desc)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Folder Image Picker

struct FolderImagePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let folder: FixtureFolder
    let onImageSelected: (FolderFixtureImage) -> Void
    let onBatchProcess: (() -> Void)?

    @State private var selectedImage: FolderFixtureImage?
    @State private var showingDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if folder.images.isEmpty {
                    emptyFolderView
                } else {
                    imageGrid
                }
            }
            .navigationTitle(folder.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }

                if onBatchProcess != nil && !folder.images.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Batch Process") {
                            onBatchProcess?()
                        }
                    }
                }
            }
            .sheet(item: $selectedImage) { image in
                FolderImageDetailView(
                    image: image,
                    folder: folder,
                    onSelect: {
                        onImageSelected(image)
                    }
                )
            }
            .presentationBackground(Color.black)
        }
    }

    private var emptyFolderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Images Found")
                .font(.headline)

            Text("Add .jpg images to this folder to test detection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var imageGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(folder.images) { image in
                    ImageThumbnail(image: image)
                        .onTapGesture {
                            selectedImage = image
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Image Thumbnail

private struct ImageThumbnail: View {
    let image: FolderFixtureImage

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.elevatedSurface)

            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            if let holeCount = image.metadata?.expectedHoleCount {
                Text("\(holeCount)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.cardBackground)
                    .clipShape(Capsule())
                    .padding(4)
            }
        }
        .task {
            thumbnail = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> UIImage? {
        guard let fullImage = image.loadImage() else { return nil }

        // Create thumbnail
        let size = CGSize(width: 150, height: 150)
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
                fullImage.draw(in: CGRect(origin: .zero, size: size))
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                continuation.resume(returning: thumbnail)
            }
        }
    }
}

// MARK: - Image Detail View

struct FolderImageDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let image: FolderFixtureImage
    let folder: FixtureFolder
    let onSelect: () -> Void

    @State private var loadedImage: UIImage?
    @State private var qualityAssessment: ImageQualityAssessment?
    @State private var isAssessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    imagePreview

                    // Quality assessment
                    if isAssessing {
                        ProgressView("Assessing image quality...")
                    } else if let assessment = qualityAssessment {
                        qualitySection(assessment)
                    }

                    // Metadata
                    if let metadata = image.metadata {
                        metadataSection(metadata)
                    }

                    // Capture guidance link
                    NavigationLink {
                        PhotoCaptureGuidanceView()
                    } label: {
                        Label("Photo Capture Tips", systemImage: "camera.viewfinder")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle(image.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Image") {
                        onSelect()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await loadImageAndAssess()
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.elevatedSurface)
                    .frame(height: 200)
                    .overlay {
                        ProgressView()
                    }
            }
        }
    }

    private func qualitySection(_ assessment: ImageQualityAssessment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Image Quality")
                    .font(.headline)

                Spacer()

                Text(assessment.qualityLevel.description)
                    .font(.subheadline.bold())
                    .foregroundStyle(qualityColor(assessment.qualityLevel))
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QualityMetricRow(label: "Sharpness", value: assessment.sharpness)
                QualityMetricRow(label: "Contrast", value: assessment.contrast)
                QualityMetricRow(label: "Brightness", value: assessment.brightness)
                QualityMetricRow(label: "Overall", value: assessment.overallScore)
            }

            if let guidance = assessment.userGuidance {
                Text(guidance)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metadataSection(_ metadata: ImageMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)

            if let holeCount = metadata.expectedHoleCount {
                HStack {
                    Text("Expected Holes")
                    Spacer()
                    Text("\(holeCount)")
                        .foregroundStyle(.secondary)
                }
            }

            if let difficulty = metadata.difficulty {
                HStack {
                    Text("Difficulty")
                    Spacer()
                    Text("\(difficulty)/5")
                        .foregroundStyle(.secondary)
                }
            }

            if let lighting = metadata.lightingCondition {
                HStack {
                    Text("Lighting")
                    Spacer()
                    Text(lighting.capitalized)
                        .foregroundStyle(.secondary)
                }
            }

            if let notes = metadata.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func qualityColor(_ level: ImageQualityAssessment.QualityLevel) -> Color {
        switch level {
        case .good: return .green
        case .acceptable: return .yellow
        case .poor: return .red
        }
    }

    private func loadImageAndAssess() async {
        loadedImage = image.loadImage()

        guard let uiImage = loadedImage else { return }

        isAssessing = true
        let assessor = ImageQualityAssessor()
        qualityAssessment = await assessor.assess(image: uiImage)
        isAssessing = false
    }
}

// MARK: - Quality Metric Row

private struct QualityMetricRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                ProgressView(value: value)
                    .tint(colorForValue(value))

                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption.monospacedDigit())
            }
        }
    }

    private func colorForValue(_ value: Double) -> Color {
        if value >= 0.7 { return .green }
        if value >= 0.4 { return .yellow }
        return .red
    }
}

// MARK: - Preview

#Preview {
    DebugFolderSelectorView { folder in
        print("Selected folder: \(folder.name)")
    } onImageSelected: { image, folder in
        print("Selected image: \(image.filename) from \(folder.name)")
    } onBatchProcess: { folder in
        print("Batch process: \(folder.name)")
    }
}

#endif
