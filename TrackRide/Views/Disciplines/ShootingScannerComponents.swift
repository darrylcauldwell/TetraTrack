//
//  ShootingScannerComponents.swift
//  TrackRide
//
//  Camera and target scanner views for shooting discipline
//

import SwiftUI
import SwiftData
import AVFoundation
import Vision
import PhotosUI

// MARK: - Target Scanner View

/// Target scanning view with manual center calibration.
///
/// **Flow**:
/// 1. Capture: Camera/photo capture
/// 2. Crop: Perspective crop (drag corners to match target card edges)
/// 3. Center: Set target center point manually for accurate scoring
/// 4. Mark: Mark holes and review scores
///
/// Manual center placement ensures accurate scoring for any target orientation.
struct TargetScannerView: View {
    let expectedShots: Int // 0 = unlimited
    let onScanned: ([Int]) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext

    // Flow states: sourceSelect -> camera -> crop -> center -> mark -> review
    @State private var showingSourceSelector = false
    @State private var rawCapturedImage: UIImage?  // Original image before cropping
    @State private var capturedImage: UIImage?      // Cropped image for analysis
    @State private var showingCropView = false
    @State private var showingCenterConfirmation = false  // Center calibration step
    @State private var detectedHoles: [DetectedHole] = []
    @State private var detectedTargetCenter: CGPoint?
    @State private var detectedTargetSize: CGSize?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var aiCoachingInsights: ShootingCoachingInsights?
    @State private var isLoadingAICoaching = false
    @State private var saveAnalysis = true  // Option to save for historical tracking

    // Optional auto-detection (can be disabled)
    @State private var isAutoDetecting = false
    @State private var autoDetectionComplete = false
    @State private var useAutoDetection = false  // User preference

    // ML Training Data Collection
    @State private var markingEvents: [HoleMarkingEvent] = []
    @State private var sessionStartTime: Date = Date()
    @State private var lastActionTime: Date = Date()
    @State private var retakeCount: Int = 0
    @State private var currentZoomLevel: Double = 1.0

    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    var body: some View {
        ZStack {
            if showingCropView, let rawImage = rawCapturedImage {
                // Perspective crop step
                ManualCropView(
                    image: rawImage,
                    onCropped: { croppedImage in
                        capturedImage = croppedImage
                        showingCropView = false
                        // Initialize with geometric center (user can adjust using Set Center mode)
                        detectedTargetCenter = CGPoint(x: 0.5, y: 0.5)
                        detectedTargetSize = CGSize(width: 0.8, height: 0.9)
                        detectedHoles = []
                        // Go directly to analysis - user can adjust center in marking view
                    },
                    onCancel: {
                        rawCapturedImage = nil
                        showingCropView = false
                    }
                )
            } else if let image = capturedImage {
                analysisView(image: image)
            } else if showingSourceSelector || !isCameraAvailable {
                // Show source selector on Simulator or when requested
                ImageSourceSelectorView(
                    onImageSelected: { image in
                        rawCapturedImage = image
                        showingCropView = true
                        showingSourceSelector = false
                    },
                    onCancel: onCancel
                )
            } else {
                cameraView
            }
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        // Go to manual crop view instead of auto-analyzing
                        rawCapturedImage = image
                        showingCropView = true
                    }
                }
            }
        }
    }

    @State private var alignmentQuality: AlignmentQuality = .none

    private var cameraView: some View {
        ZStack {
            // Camera preview with real-time alignment detection
            CameraPreviewView(
                onCapture: { image in
                    // Go to manual crop view instead of auto-analyzing
                    rawCapturedImage = image
                    showingCropView = true
                },
                onAlignmentUpdate: { quality in
                    alignmentQuality = quality
                }
            )

            VStack {
                // Header
                HStack {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    Spacer()
                    Text("Scan Target")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(AppColors.cardBackground)
                        .clipShape(Capsule())
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(AppColors.cardBackground)
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                // Alignment status indicator
                HStack(spacing: 8) {
                    Image(systemName: alignmentQuality.icon)
                        .foregroundStyle(alignmentQuality.color)
                    Text(alignmentQuality.message)
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background {
                    if alignmentQuality == .good {
                        Capsule().fill(.green.opacity(0.4))
                    } else {
                        Capsule().fill(AppColors.cardBackground)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: alignmentQuality)

                // Target overlay guide - tetrathlon rectangular target with oval zones
                GeometryReader { geo in
                    let frameWidth = geo.size.width - 32  // 16pt padding each side
                    let frameHeight = frameWidth * 1.36   // Tetrathlon target aspect ratio
                    let ovalWidth = frameWidth * 0.82     // Oval slightly smaller than frame
                    let ovalHeight = frameHeight * 0.8
                    let cornerSize: CGFloat = 30

                    ZStack {
                        // Corner alignment guides (change color based on alignment)
                        let cornerColor = alignmentQuality.color

                        // Top-left corner
                        CornerGuide(corner: .topLeft, size: cornerSize, color: cornerColor)
                            .position(x: 16 + cornerSize/2, y: (geo.size.height - frameHeight)/2 + cornerSize/2)

                        // Top-right corner
                        CornerGuide(corner: .topRight, size: cornerSize, color: cornerColor)
                            .position(x: geo.size.width - 16 - cornerSize/2, y: (geo.size.height - frameHeight)/2 + cornerSize/2)

                        // Bottom-left corner
                        CornerGuide(corner: .bottomLeft, size: cornerSize, color: cornerColor)
                            .position(x: 16 + cornerSize/2, y: (geo.size.height + frameHeight)/2 - cornerSize/2)

                        // Bottom-right corner
                        CornerGuide(corner: .bottomRight, size: cornerSize, color: cornerColor)
                            .position(x: geo.size.width - 16 - cornerSize/2, y: (geo.size.height + frameHeight)/2 - cornerSize/2)

                        // Outer rectangle (target card outline) - dashed when not aligned
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                alignmentQuality == .good ? .green : .white.opacity(0.6),
                                style: StrokeStyle(
                                    lineWidth: alignmentQuality == .good ? 3 : 2,
                                    dash: alignmentQuality == .good ? [] : [10, 5]
                                )
                            )
                            .frame(width: frameWidth, height: frameHeight)

                        // Oval scoring zones (tetrathlon style)
                        ForEach([1.0, 0.8, 0.6, 0.4, 0.2], id: \.self) { scale in
                            Ellipse()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                .frame(width: ovalWidth * scale, height: ovalHeight * scale)
                        }

                        // Center crosshair
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 1, height: ovalHeight)
                        Rectangle()
                            .fill(.white.opacity(0.3))
                            .frame(width: ovalWidth, height: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()
            }
        }
    }

    // State to track whether we're in marking mode or review mode
    @State private var showingReview = false

    private func analysisView(image: UIImage) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if isAutoDetecting {
                // Auto-detection in progress
                autoDetectionLoadingView
            } else if showingReview {
                reviewView(image: image)
            } else {
                markingView(image: image)
            }
        }
    }

    // MARK: - Auto-Detection

    /// Run auto-detection on the cropped image
    private func runAutoDetection(on image: UIImage) async {
        await MainActor.run {
            isAutoDetecting = true
        }

        do {
            let pipeline = HoleDetectionPipeline()
            let result = try await pipeline.detect(image: image)

            // Calculate scores for detected holes based on distance from center
            let targetCenter = CGPoint(x: 0.5, y: 0.5)
            let targetSize = CGSize(width: 0.8, height: 0.9)

            let scoredHoles = result.allHoles.map { hole -> DetectedHole in
                let score = calculateScore(for: hole.position, center: targetCenter, size: targetSize)
                return DetectedHole(
                    id: hole.id,
                    position: hole.position,
                    score: score,
                    confidence: hole.confidence,
                    radius: hole.radius,
                    needsReview: hole.needsReview,
                    reviewReason: hole.reviewReason
                )
            }

            await MainActor.run {
                detectedHoles = scoredHoles
                isAutoDetecting = false
                autoDetectionComplete = true
                // Go straight to review if holes were detected
                if !scoredHoles.isEmpty {
                    showingReview = true
                }
            }
        } catch {
            // Detection failed - go to manual marking
            await MainActor.run {
                isAutoDetecting = false
                autoDetectionComplete = true
            }
        }
    }

    /// Loading view shown during auto-detection
    private var autoDetectionLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Detecting holes...")
                .font(.headline)

            Text("Auto-scoring based on target position")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Step 1: Marking View (Full screen for marking)

    private func markingView(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Compact header
            HStack {
                Button("Retake") {
                    retakeCount += 1
                    capturedImage = nil
                    rawCapturedImage = nil
                    showingCropView = false
                    detectedHoles = []
                    detectedTargetCenter = nil
                    detectedTargetSize = nil
                    aiCoachingInsights = nil
                    markingEvents = []
                    lastActionTime = Date()
                    showingReview = false
                }
                .font(.subheadline)

                Spacer()

                Text("Mark Holes")
                    .font(.headline)

                Spacer()

                Button("Cancel") { onCancel() }
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Large target image area - takes most of the screen
            InteractiveAnnotatedTargetImage(
                image: image,
                holes: $detectedHoles,
                targetCenter: detectedTargetCenter,
                targetSize: detectedTargetSize,
                onHoleAdded: { position in
                    addHole(at: position)
                },
                onHoleMoved: { id, newPosition in
                    moveHole(id: id, to: newPosition)
                },
                onHoleDeleted: { id in
                    deleteHole(id: id)
                }
            )
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 8)

            // Bottom controls - compact
            VStack(spacing: 12) {
                // Instructions and hole count
                HStack {
                    // Instructions
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap")
                                .font(.caption2)
                            Text("Tap to add hole")
                                .font(.caption2)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap")
                                .font(.caption2)
                            Text("Tap hole, then X to delete")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    // Hole count badge
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .foregroundStyle(.orange)
                        Text("\(detectedHoles.count) holes")
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(detectedHoles.isEmpty ? AppColors.elevatedSurface : Color.orange.opacity(0.15))
                    .clipShape(Capsule())

                    // Clear All button
                    if !detectedHoles.isEmpty {
                        Button {
                            detectedHoles.removeAll()
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)

                // Review button - only enabled when holes are marked
                Button {
                    if detectedHoles.isEmpty {
                        // Allow finishing with no holes (user might want to skip)
                        onScanned([])
                    } else {
                        showingReview = true
                    }
                } label: {
                    HStack {
                        Text(detectedHoles.isEmpty ? "Skip" : "Review Analysis")
                            .font(.headline)
                        if !detectedHoles.isEmpty {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(detectedHoles.isEmpty ? .gray : .blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .background(Color(.systemBackground))
        }
    }

    // State for adding missed holes in review mode
    @State private var isAddingMissedHole = false

    // MARK: - Step 2: Review View (Shows analysis after auto-detection)

    private func reviewView(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button {
                    if isAddingMissedHole {
                        isAddingMissedHole = false
                    } else {
                        showingReview = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(isAddingMissedHole ? "Back" : "Edit")
                    }
                    .font(.subheadline)
                }

                Spacer()

                Text(isAddingMissedHole ? "Add Missed Hole" : "Analysis")
                    .font(.headline)

                Spacer()

                Button("Cancel") { onCancel() }
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            if isAddingMissedHole {
                // Add missed hole view - simple tap to add
                addMissedHoleView(image: image)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Target preview with detected holes overlay
                        targetPreviewWithHoles(image: image)

                        // Summary stats
                        scoreSummaryCard

                        // Add missed hole button
                        addMissedHoleButton

                        // Pattern Analysis
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pattern Analysis")
                                .font(.headline)

                            patternFeedbackView
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Visual pattern indicator
                        patternVisualization

                        // Apple Intelligence Coaching
                        aiCoachingSection

                        // Save for history toggle
                        Toggle(isOn: $saveAnalysis) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text("Save to History")
                                        .font(.subheadline)
                                    Text("Track patterns over time")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }

                // Done button
                Button {
                    if saveAnalysis && !detectedHoles.isEmpty {
                        saveTargetAnalysis()
                    }
                    onScanned(detectedHoles.map { $0.score })
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
    }

    /// Target preview with detected holes overlaid
    private func targetPreviewWithHoles(image: UIImage) -> some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                // Overlay detected holes with scores
                ForEach(detectedHoles) { hole in
                    ZStack {
                        Circle()
                            .fill(scoreColor(for: hole.score).opacity(0.6))
                            .frame(width: 24, height: 24)
                        Circle()
                            .stroke(scoreColor(for: hole.score), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        Text("\(hole.score)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    .position(
                        x: hole.position.x * geo.size.width,
                        y: hole.position.y * geo.size.height
                    )
                }
            }
        }
        .aspectRatio(contentMode: .fit)
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    /// Score summary card
    private var scoreSummaryCard: some View {
        VStack(spacing: 12) {
            let totalScore = detectedHoles.reduce(0) { $0 + $1.score }

            HStack(spacing: 24) {
                VStack {
                    Text("\(detectedHoles.count)")
                        .font(.title.bold())
                    Text("Shots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text("\(totalScore)")
                        .font(.title.bold())
                        .foregroundStyle(.orange)
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !detectedHoles.isEmpty {
                    VStack {
                        let avgScore = Double(totalScore) / Double(detectedHoles.count)
                        Text(String(format: "%.1f", avgScore))
                            .font(.title.bold())
                            .foregroundStyle(.blue)
                        Text("Average")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Score breakdown by ring
            if !detectedHoles.isEmpty {
                HStack(spacing: 8) {
                    ForEach([10, 8, 6, 4, 2, 0], id: \.self) { score in
                        let count = detectedHoles.filter { $0.score == score }.count
                        if count > 0 {
                            HStack(spacing: 2) {
                                Text(score == 10 ? "X" : "\(score)")
                                    .font(.caption.bold())
                                    .foregroundStyle(scoreColor(for: score))
                                Text("x\(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Add missed hole button
    private var addMissedHoleButton: some View {
        Button {
            isAddingMissedHole = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                Text("Add Missed Hole")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// View for adding a missed hole - simple tap to add
    private func addMissedHoleView(image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Instructions
            Text("Tap on the target to add a missed hole")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()

            // Target image with tap to add
            GeometryReader { geo in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // Show existing holes
                    ForEach(detectedHoles) { hole in
                        Circle()
                            .fill(scoreColor(for: hole.score).opacity(0.6))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(scoreColor(for: hole.score), lineWidth: 2)
                            )
                            .position(
                                x: hole.position.x * geo.size.width,
                                y: hole.position.y * geo.size.height
                            )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Convert tap to normalized coordinates
                    let normalizedX = location.x / geo.size.width
                    let normalizedY = location.y / geo.size.height
                    let position = CGPoint(x: normalizedX, y: normalizedY)

                    // Add the hole
                    addHole(at: position)

                    // Return to review
                    isAddingMissedHole = false
                }
            }
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()

            Spacer()
        }
    }

    /// Get color for score value
    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 8: return .orange
        case 6: return .red
        case 4: return .blue
        case 2: return .cyan
        default: return .gray
        }
    }

    // MARK: - Hole Correction Functions (with ML Training Data Capture)

    private func addHole(at position: CGPoint) {
        let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)
        let targetSize = detectedTargetSize ?? CGSize(width: 0.4, height: 0.6)

        // Calculate score based on position
        let score = calculateScore(for: position, center: targetCenter, size: targetSize)

        let newHole = DetectedHole(
            position: position,
            score: score,
            confidence: 1.0, // Manual entries are 100% confident
            radius: 0.02
        )
        detectedHoles.append(newHole)

        // Record ML training event
        let now = Date()
        let event = HoleMarkingEvent(
            action: .add,
            holeId: newHole.id,
            position: CodablePoint(position),
            timeSinceLastAction: now.timeIntervalSince(lastActionTime),
            zoomLevel: currentZoomLevel,
            sequenceNumber: markingEvents.count + 1,
            totalHolesAtTime: detectedHoles.count
        )
        markingEvents.append(event)
        lastActionTime = now

        // Sort by score
        detectedHoles.sort { $0.score > $1.score }
    }

    private func moveHole(id: UUID, to newPosition: CGPoint) {
        guard let index = detectedHoles.firstIndex(where: { $0.id == id }) else { return }

        let oldPosition = detectedHoles[index].position
        let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)
        let targetSize = detectedTargetSize ?? CGSize(width: 0.4, height: 0.6)

        // Recalculate score based on new position
        let newScore = calculateScore(for: newPosition, center: targetCenter, size: targetSize)

        // Calculate drag distance for ML training
        let dragDistance = hypot(newPosition.x - oldPosition.x, newPosition.y - oldPosition.y)

        // Record ML training event
        let now = Date()
        let event = HoleMarkingEvent(
            action: .move,
            holeId: id,
            position: CodablePoint(newPosition),
            previousPosition: CodablePoint(oldPosition),
            timeSinceLastAction: now.timeIntervalSince(lastActionTime),
            dragDistance: dragDistance,
            zoomLevel: currentZoomLevel,
            sequenceNumber: markingEvents.count + 1,
            totalHolesAtTime: detectedHoles.count
        )
        markingEvents.append(event)
        lastActionTime = now

        detectedHoles[index].position = newPosition
        detectedHoles[index].score = newScore

        // Re-sort by score
        detectedHoles.sort { $0.score > $1.score }
    }

    private func deleteHole(id: UUID) {
        guard let hole = detectedHoles.first(where: { $0.id == id }) else { return }

        // Record ML training event
        let now = Date()
        let event = HoleMarkingEvent(
            action: .delete,
            holeId: id,
            position: CodablePoint(hole.position),
            timeSinceLastAction: now.timeIntervalSince(lastActionTime),
            zoomLevel: currentZoomLevel,
            sequenceNumber: markingEvents.count + 1,
            totalHolesAtTime: detectedHoles.count - 1
        )
        markingEvents.append(event)
        lastActionTime = now

        detectedHoles.removeAll { $0.id == id }
    }

    private func saveTargetAnalysis() {
        let analysis = TargetScanAnalysis()

        // Convert detected holes to ScanShots
        let scanShots = detectedHoles.map { hole in
            ScanShot(
                positionX: hole.position.x,
                positionY: hole.position.y,
                score: hole.score,
                confidence: hole.confidence
            )
        }
        analysis.shotPositions = scanShots

        // Calculate metrics
        let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)
        analysis.calculateMetrics(from: scanShots, targetCenter: targetCenter)

        // Save to SwiftData
        modelContext.insert(analysis)
        try? modelContext.save()

        // Save ML training data
        saveMLTrainingData()
    }

    /// Save comprehensive ML training data for future model development
    private func saveMLTrainingData() {
        guard let image = capturedImage else { return }

        Task {
            // Determine target region for each hole
            let isLeftBlack = true // Default assumption, could be computed from image

            // Convert to HoleAnnotations with full metadata
            let annotations = detectedHoles.map { hole -> HoleAnnotation in
                let region = MLTrainingDataService.shared.determineTargetRegion(
                    position: hole.position,
                    isLeftBlack: isLeftBlack
                )

                return HoleAnnotation(
                    id: hole.id,
                    position: hole.position,
                    estimatedDiameter: hole.radius * 2,
                    targetRegion: region,
                    score: hole.score,
                    confidence: hole.confidence,
                    source: .manualAdd,
                    wasAutoDetected: false,
                    wasUserCorrected: false
                )
            }

            // Create capture metadata
            let originalSize = rawCapturedImage?.size ?? image.size
            let metadata = CaptureMetadata.capture(
                originalSize: originalSize,
                croppedSize: image.size,
                sessionDuration: Date().timeIntervalSince(sessionStartTime),
                retakeCount: retakeCount
            )

            // Save training capture
            do {
                _ = try await MLTrainingDataService.shared.saveTrainingCapture(
                    image: image,
                    annotations: annotations,
                    markingEvents: markingEvents,
                    metadata: metadata,
                    targetType: .tetrathlon
                )
            } catch {
                // ML training data save failed silently
            }
        }
    }

    private func calculateScore(for position: CGPoint, center: CGPoint, size: CGSize) -> Int {
        // Calculate normalized distance from center (elliptical)
        let dx = abs(position.x - center.x) / (size.width / 2)
        let dy = abs(position.y - center.y) / (size.height / 2)
        let ellipticalDistance = sqrt(dx * dx + dy * dy)

        // Tetrathlon scoring: 10, 8, 6, 4, 2 (only even numbers)
        if ellipticalDistance < 0.2 { return 10 }
        if ellipticalDistance < 0.4 { return 8 }
        if ellipticalDistance < 0.6 { return 6 }
        if ellipticalDistance < 0.8 { return 4 }
        if ellipticalDistance < 1.0 { return 2 }
        return 0 // Miss
    }

    // MARK: - Pattern Analysis

    private var patternFeedbackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(patternFeedback) { feedback in
                HStack(spacing: 8) {
                    Image(systemName: feedback.icon)
                        .foregroundStyle(feedback.color)
                        .frame(width: 24)
                    Text(feedback.message)
                        .font(.subheadline)
                }
            }
        }
    }

    private var patternVisualization: some View {
        VStack(spacing: 8) {
            Text("Shot Distribution")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Simple visual showing where shots landed
            ZStack {
                // Target outline
                Ellipse()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: 120, height: 160)

                // Center point
                Circle()
                    .fill(.green.opacity(0.3))
                    .frame(width: 24, height: 24)

                // Plot shots
                ForEach(detectedHoles) { hole in
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(
                            x: (hole.position.x - 0.5) * 120,
                            y: (hole.position.y - 0.5) * 160
                        )
                }

                // Average position marker
                let avgX = detectedHoles.map { $0.position.x }.reduce(0, +) / Double(detectedHoles.count)
                let avgY = detectedHoles.map { $0.position.y }.reduce(0, +) / Double(detectedHoles.count)
                Circle()
                    .stroke(.orange, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .offset(
                        x: (avgX - 0.5) * 120,
                        y: (avgY - 0.5) * 160
                    )
            }
            .frame(height: 180)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Red dots = shots, Orange circle = average position")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private struct PatternFeedback: Identifiable {
        let id = UUID()
        let message: String
        let icon: String
        let color: Color
    }

    private var patternFeedback: [PatternFeedback] {
        guard !detectedHoles.isEmpty else { return [] }

        var feedback: [PatternFeedback] = []
        let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)

        // Calculate average position
        let avgX = detectedHoles.map { $0.position.x }.reduce(0, +) / Double(detectedHoles.count)
        let avgY = detectedHoles.map { $0.position.y }.reduce(0, +) / Double(detectedHoles.count)

        // Calculate spread (standard deviation)
        let spreadX = sqrt(detectedHoles.map { pow($0.position.x - avgX, 2) }.reduce(0, +) / Double(detectedHoles.count))
        let spreadY = sqrt(detectedHoles.map { pow($0.position.y - avgY, 2) }.reduce(0, +) / Double(detectedHoles.count))
        let totalSpread = sqrt(spreadX * spreadX + spreadY * spreadY)

        // Grouping quality
        if totalSpread < 0.05 {
            feedback.append(PatternFeedback(message: "Excellent grouping - very tight cluster", icon: "star.fill", color: .yellow))
        } else if totalSpread < 0.10 {
            feedback.append(PatternFeedback(message: "Good grouping - consistent shots", icon: "checkmark.circle.fill", color: .green))
        } else if totalSpread < 0.15 {
            feedback.append(PatternFeedback(message: "Fair grouping - some spread", icon: "circle.fill", color: .orange))
        } else {
            feedback.append(PatternFeedback(message: "Wide spread - work on consistency", icon: "exclamationmark.triangle.fill", color: .red))
        }

        // Horizontal bias
        let horizontalBias = avgX - targetCenter.x
        if horizontalBias > 0.08 {
            feedback.append(PatternFeedback(message: "Shots pulling to the right", icon: "arrow.right", color: .blue))
        } else if horizontalBias < -0.08 {
            feedback.append(PatternFeedback(message: "Shots pulling to the left", icon: "arrow.left", color: .blue))
        }

        // Vertical bias
        let verticalBias = avgY - targetCenter.y
        if verticalBias > 0.08 {
            feedback.append(PatternFeedback(message: "Shots trending low", icon: "arrow.down", color: .blue))
        } else if verticalBias < -0.08 {
            feedback.append(PatternFeedback(message: "Shots trending high", icon: "arrow.up", color: .blue))
        }

        // Check for outliers
        let outliers = detectedHoles.filter { hole in
            let dx = hole.position.x - avgX
            let dy = hole.position.y - avgY
            let distance = sqrt(dx * dx + dy * dy)
            return distance > totalSpread * 2.5
        }
        if !outliers.isEmpty && outliers.count < detectedHoles.count / 2 {
            feedback.append(PatternFeedback(message: "\(outliers.count) outlier shot(s) - check technique", icon: "exclamationmark.circle", color: .orange))
        }

        // Overall assessment
        let distanceFromCenter = sqrt(pow(avgX - targetCenter.x, 2) + pow(avgY - targetCenter.y, 2))
        if distanceFromCenter < 0.05 && totalSpread < 0.08 {
            feedback.append(PatternFeedback(message: "Great shooting - centered and consistent!", icon: "hand.thumbsup.fill", color: .green))
        } else if distanceFromCenter < 0.1 {
            feedback.append(PatternFeedback(message: "Good center alignment", icon: "scope", color: .green))
        }

        return feedback
    }

    // MARK: - Apple Intelligence Coaching

    private var aiCoachingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "apple.intelligence")
                    .foregroundStyle(.purple)
                Text("AI Coach")
                    .font(.headline)
                Text("(Apple Intelligence)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if isLoadingAICoaching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing your shooting pattern...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let insights = aiCoachingInsights {
                // AI Coaching Results
                VStack(alignment: .leading, spacing: 10) {
                    // Overall assessment
                    Text(insights.overallAssessment)
                        .font(.subheadline)

                    // Grouping quality
                    if !insights.groupingQuality.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "target")
                                .foregroundStyle(.blue)
                                .frame(width: 20)
                            Text(insights.groupingQuality)
                                .font(.subheadline)
                        }
                    }

                    // Directional bias
                    if !insights.directionalBias.isEmpty && insights.directionalBias != "None" {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.left.and.right")
                                .foregroundStyle(.orange)
                                .frame(width: 20)
                            Text(insights.directionalBias)
                                .font(.subheadline)
                        }
                    }

                    // Technique suggestions
                    if !insights.techniqueSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Technique Tips:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(insights.techniqueSuggestions, id: \.self) { suggestion in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                        .frame(width: 16)
                                    Text(suggestion)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    // Recommended drills
                    if !insights.recommendedDrills.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Try These Drills:")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            ForEach(insights.recommendedDrills, id: \.self) { drill in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                        .frame(width: 16)
                                    Text(drill)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    // Encouragement
                    if !insights.encouragement.isEmpty {
                        Text(insights.encouragement)
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.green)
                            .padding(.top, 4)
                    }
                }
            } else {
                // Request AI coaching button
                Button(action: requestAICoaching) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Get AI Coaching Feedback")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func requestAICoaching() {
        guard !detectedHoles.isEmpty else { return }

        isLoadingAICoaching = true

        let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)

        // Calculate pattern metrics
        let avgX = detectedHoles.map { $0.position.x }.reduce(0, +) / Double(detectedHoles.count)
        let avgY = detectedHoles.map { $0.position.y }.reduce(0, +) / Double(detectedHoles.count)
        let spreadX = sqrt(detectedHoles.map { pow($0.position.x - avgX, 2) }.reduce(0, +) / Double(detectedHoles.count))
        let spreadY = sqrt(detectedHoles.map { pow($0.position.y - avgY, 2) }.reduce(0, +) / Double(detectedHoles.count))
        let totalSpread = sqrt(spreadX * spreadX + spreadY * spreadY)
        let horizontalBias = avgX - targetCenter.x
        let verticalBias = avgY - targetCenter.y

        let patternData = ShootingPatternData(
            shotCount: detectedHoles.count,
            shotPositions: detectedHoles.map { $0.position },
            targetCenterX: targetCenter.x,
            targetCenterY: targetCenter.y,
            averageX: avgX,
            averageY: avgY,
            spreadX: spreadX,
            spreadY: spreadY,
            totalSpread: totalSpread,
            horizontalBias: horizontalBias,
            verticalBias: verticalBias
        )

        Task {
            if #available(iOS 26.0, *) {
                do {
                    let insights = try await IntelligenceService.shared.analyzeShootingPattern(data: patternData)
                    await MainActor.run {
                        aiCoachingInsights = insights
                        isLoadingAICoaching = false
                    }
                } catch {
                    await MainActor.run {
                        // Fall back to basic feedback on error
                        isLoadingAICoaching = false
                    }
                }
            } else {
                await MainActor.run {
                    isLoadingAICoaching = false
                }
            }
        }
    }
}

// MARK: - Alignment Quality

enum AlignmentQuality: Equatable {
    case none
    case partial
    case good

    var color: Color {
        switch self {
        case .none: return .white.opacity(0.6)
        case .partial: return .yellow
        case .good: return .green
        }
    }

    var icon: String {
        switch self {
        case .none: return "viewfinder"
        case .partial: return "viewfinder.rectangular"
        case .good: return "checkmark.circle.fill"
        }
    }

    var message: String {
        switch self {
        case .none: return "Align target card within the frame"
        case .partial: return "Adjusting... hold steady"
        case .good: return "Aligned! Tap to capture"
        }
    }
}

// MARK: - Corner Guide View

struct CornerGuide: View {
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    let corner: Corner
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            // L-shaped corner guide
            Path { path in
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: 0, y: size))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: size, y: 0))
                case .topRight:
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: size, y: 0))
                    path.addLine(to: CGPoint(x: size, y: size))
                case .bottomLeft:
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: size))
                    path.addLine(to: CGPoint(x: size, y: size))
                case .bottomRight:
                    path.move(to: CGPoint(x: 0, y: size))
                    path.addLine(to: CGPoint(x: size, y: size))
                    path.addLine(to: CGPoint(x: size, y: 0))
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Manual Crop View (with Perspective Correction)

struct ManualCropView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    let onCancel: () -> Void

    // Four corner points for perspective crop (normalized 0-1 coordinates)
    @State private var topLeft = CGPoint(x: 0.1, y: 0.1)
    @State private var topRight = CGPoint(x: 0.9, y: 0.1)
    @State private var bottomLeft = CGPoint(x: 0.1, y: 0.9)
    @State private var bottomRight = CGPoint(x: 0.9, y: 0.9)

    // Track which corner is being dragged
    @State private var activeCorner: Corner?

    // Mode: rectangle or perspective
    @State private var usePerspective = true

    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                // Image with perspective crop overlay
                GeometryReader { geo in
                    let imageSize = calculateImageSize(in: geo.size)
                    let imageOffset = calculateImageOffset(in: geo.size, imageSize: imageSize)
                    let imageFrame = CGRect(
                        x: imageOffset.x,
                        y: imageOffset.y,
                        width: imageSize.width,
                        height: imageSize.height
                    )

                    ZStack {
                        // The image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize.width, height: imageSize.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                        // Darkened overlay with quadrilateral cutout
                        PerspectiveCropOverlay(
                            corners: cornerPositions(in: imageFrame),
                            geoSize: geo.size
                        )

                        // Draggable corner handles
                        perspectiveHandles(imageFrame: imageFrame)
                    }
                }

                // Controls
                VStack(spacing: 12) {
                    // Reset button
                    HStack {
                        Button {
                            resetCorners()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        // Toggle perspective mode
                        Toggle(isOn: $usePerspective) {
                            Text("Perspective")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .toggleStyle(.button)
                        .tint(.orange)
                    }
                    .padding(.horizontal)

                    // Instructions
                    Text("Drag corners to match the target edges.\nPerspective mode corrects for angled photos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 16)
            }
            } // Close ZStack
            .navigationTitle("Crop Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { applyCrop() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Corner Positions

    private func cornerPositions(in imageFrame: CGRect) -> [CGPoint] {
        [
            CGPoint(
                x: imageFrame.origin.x + topLeft.x * imageFrame.width,
                y: imageFrame.origin.y + topLeft.y * imageFrame.height
            ),
            CGPoint(
                x: imageFrame.origin.x + topRight.x * imageFrame.width,
                y: imageFrame.origin.y + topRight.y * imageFrame.height
            ),
            CGPoint(
                x: imageFrame.origin.x + bottomRight.x * imageFrame.width,
                y: imageFrame.origin.y + bottomRight.y * imageFrame.height
            ),
            CGPoint(
                x: imageFrame.origin.x + bottomLeft.x * imageFrame.width,
                y: imageFrame.origin.y + bottomLeft.y * imageFrame.height
            )
        ]
    }

    // MARK: - Perspective Handles

    private func perspectiveHandles(imageFrame: CGRect) -> some View {
        ZStack {
            // Border connecting corners
            Path { path in
                let corners = cornerPositions(in: imageFrame)
                guard corners.count == 4 else { return }
                path.move(to: corners[0])
                path.addLine(to: corners[1])
                path.addLine(to: corners[2])
                path.addLine(to: corners[3])
                path.closeSubpath()
            }
            .stroke(.white, lineWidth: 2)

            // Grid lines
            Path { path in
                let corners = cornerPositions(in: imageFrame)
                guard corners.count == 4 else { return }

                // Horizontal thirds
                for i in 1...2 {
                    let t = CGFloat(i) / 3.0
                    let left = interpolate(corners[0], corners[3], t: t)
                    let right = interpolate(corners[1], corners[2], t: t)
                    path.move(to: left)
                    path.addLine(to: right)
                }

                // Vertical thirds
                for i in 1...2 {
                    let t = CGFloat(i) / 3.0
                    let top = interpolate(corners[0], corners[1], t: t)
                    let bottom = interpolate(corners[3], corners[2], t: t)
                    path.move(to: top)
                    path.addLine(to: bottom)
                }
            }
            .stroke(.white.opacity(0.4), lineWidth: 1)

            // Corner handles
            cornerHandle(for: .topLeft, in: imageFrame, position: topLeft)
            cornerHandle(for: .topRight, in: imageFrame, position: topRight)
            cornerHandle(for: .bottomLeft, in: imageFrame, position: bottomLeft)
            cornerHandle(for: .bottomRight, in: imageFrame, position: bottomRight)
        }
    }

    private func interpolate(_ p1: CGPoint, _ p2: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: p1.x + (p2.x - p1.x) * t,
            y: p1.y + (p2.y - p1.y) * t
        )
    }

    private func cornerHandle(for corner: Corner, in imageFrame: CGRect, position: CGPoint) -> some View {
        let screenPos = CGPoint(
            x: imageFrame.origin.x + position.x * imageFrame.width,
            y: imageFrame.origin.y + position.y * imageFrame.height
        )

        return Circle()
            .fill(.orange)
            .frame(width: 30, height: 30)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .position(screenPos)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newX = (value.location.x - imageFrame.origin.x) / imageFrame.width
                        let newY = (value.location.y - imageFrame.origin.y) / imageFrame.height

                        // Clamp to valid range
                        let clampedX = max(0, min(1, newX))
                        let clampedY = max(0, min(1, newY))

                        switch corner {
                        case .topLeft:
                            if usePerspective {
                                topLeft = CGPoint(x: clampedX, y: clampedY)
                            } else {
                                // Rectangle mode: move opposite corners proportionally
                                topLeft = CGPoint(x: clampedX, y: clampedY)
                                topRight.y = clampedY
                                bottomLeft.x = clampedX
                            }
                        case .topRight:
                            if usePerspective {
                                topRight = CGPoint(x: clampedX, y: clampedY)
                            } else {
                                topRight = CGPoint(x: clampedX, y: clampedY)
                                topLeft.y = clampedY
                                bottomRight.x = clampedX
                            }
                        case .bottomLeft:
                            if usePerspective {
                                bottomLeft = CGPoint(x: clampedX, y: clampedY)
                            } else {
                                bottomLeft = CGPoint(x: clampedX, y: clampedY)
                                bottomRight.y = clampedY
                                topLeft.x = clampedX
                            }
                        case .bottomRight:
                            if usePerspective {
                                bottomRight = CGPoint(x: clampedX, y: clampedY)
                            } else {
                                bottomRight = CGPoint(x: clampedX, y: clampedY)
                                bottomLeft.y = clampedY
                                topRight.x = clampedX
                            }
                        }
                    }
            )
    }

    private func resetCorners() {
        withAnimation(.easeInOut(duration: 0.2)) {
            topLeft = CGPoint(x: 0.1, y: 0.1)
            topRight = CGPoint(x: 0.9, y: 0.1)
            bottomLeft = CGPoint(x: 0.1, y: 0.9)
            bottomRight = CGPoint(x: 0.9, y: 0.9)
        }
    }

    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    private func calculateImageOffset(in containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2
        )
    }

    @State private var isProcessing = false

    private func applyCrop() {
        guard !isProcessing else { return }
        isProcessing = true

        // Capture values for background processing
        let capturedImage = image
        let capturedTopLeft = topLeft
        let capturedTopRight = topRight
        let capturedBottomLeft = bottomLeft
        let capturedBottomRight = bottomRight
        let capturedUsePerspective = usePerspective
        let isRect = isRectangle()
        let capturedOnCropped = onCropped

        // Use DispatchQueue to ensure Core Image runs off the main thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Normalize image orientation before cropping to avoid rotation issues
            let normalizedImage = Self.normalizeImageOrientation(capturedImage)

            guard let cgImage = normalizedImage.cgImage else {
                DispatchQueue.main.async {
                    capturedOnCropped(capturedImage)
                }
                return
            }

            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)

            // Convert normalized corners to pixel coordinates
            // Note: Core Image uses bottom-left origin, so we flip Y
            let pixelTopLeft = CGPoint(
                x: capturedTopLeft.x * imageWidth,
                y: (1 - capturedTopLeft.y) * imageHeight
            )
            let pixelTopRight = CGPoint(
                x: capturedTopRight.x * imageWidth,
                y: (1 - capturedTopRight.y) * imageHeight
            )
            let pixelBottomLeft = CGPoint(
                x: capturedBottomLeft.x * imageWidth,
                y: (1 - capturedBottomLeft.y) * imageHeight
            )
            let pixelBottomRight = CGPoint(
                x: capturedBottomRight.x * imageWidth,
                y: (1 - capturedBottomRight.y) * imageHeight
            )

            // Check if we need perspective correction (corners form non-rectangle)
            let needsPerspective = capturedUsePerspective && !isRect

            var resultImage: UIImage = normalizedImage

            if needsPerspective {
                // Use Core Image perspective correction
                if let corrected = Self.applyPerspectiveCorrectionStatic(
                    cgImage: cgImage,
                    topLeft: pixelTopLeft,
                    topRight: pixelTopRight,
                    bottomLeft: pixelBottomLeft,
                    bottomRight: pixelBottomRight,
                    originalImage: normalizedImage
                ) {
                    resultImage = corrected
                } else {
                    // Fallback to simple crop
                    resultImage = Self.applySimpleCropStatic(
                        cgImage: cgImage,
                        imageWidth: imageWidth,
                        imageHeight: imageHeight,
                        topLeft: capturedTopLeft,
                        topRight: capturedTopRight,
                        bottomLeft: capturedBottomLeft,
                        bottomRight: capturedBottomRight,
                        originalImage: normalizedImage
                    )
                }
            } else {
                // Simple rectangular crop
                resultImage = Self.applySimpleCropStatic(
                    cgImage: cgImage,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    topLeft: capturedTopLeft,
                    topRight: capturedTopRight,
                    bottomLeft: capturedBottomLeft,
                    bottomRight: capturedBottomRight,
                    originalImage: normalizedImage
                )
            }

            DispatchQueue.main.async {
                capturedOnCropped(resultImage)
            }
        }
    }

    private func isRectangle() -> Bool {
        // Check if corners form a rectangle (within tolerance)
        let tolerance: CGFloat = 0.02
        let topSame = abs(topLeft.y - topRight.y) < tolerance
        let bottomSame = abs(bottomLeft.y - bottomRight.y) < tolerance
        let leftSame = abs(topLeft.x - bottomLeft.x) < tolerance
        let rightSame = abs(topRight.x - bottomRight.x) < tolerance
        return topSame && bottomSame && leftSame && rightSame
    }

    private static func applySimpleCropStatic(
        cgImage: CGImage,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint,
        originalImage: UIImage
    ) -> UIImage {
        // Calculate bounding rectangle from corners
        let minX = min(topLeft.x, bottomLeft.x)
        let maxX = max(topRight.x, bottomRight.x)
        let minY = min(topLeft.y, topRight.y)
        let maxY = max(bottomLeft.y, bottomRight.y)

        let cropRect = CGRect(
            x: minX * imageWidth,
            y: minY * imageHeight,
            width: (maxX - minX) * imageWidth,
            height: (maxY - minY) * imageHeight
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return originalImage
        }

        return UIImage(cgImage: croppedCGImage, scale: originalImage.scale, orientation: originalImage.imageOrientation)
    }

    private static func applyPerspectiveCorrectionStatic(
        cgImage: CGImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint,
        originalImage: UIImage
    ) -> UIImage? {
        let ciImage = CIImage(cgImage: cgImage)

        // Use CIPerspectiveCorrection filter
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let outputImage = filter.outputImage else {
            return nil
        }

        // Render to UIImage
        let context = CIContext()

        // The output extent might be different, so we use the corrected image's extent
        let extent = outputImage.extent
        guard let outputCGImage = context.createCGImage(outputImage, from: extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: originalImage.scale, orientation: .up)
    }

    /// Normalize image orientation by rendering to a new context with correct orientation applied.
    /// This ensures the cgImage pixel data matches the displayed orientation.
    private static func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        // If orientation is already up, no need to normalize
        guard image.imageOrientation != .up else { return image }

        // Create a graphics context with the correct size
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        // Draw the image at origin - this applies the orientation transform
        image.draw(at: .zero)

        // Get the normalized image
        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return image
        }

        return normalizedImage
    }
}

// MARK: - Perspective Crop Overlay

struct PerspectiveCropOverlay: View {
    let corners: [CGPoint]  // [topLeft, topRight, bottomRight, bottomLeft]
    let geoSize: CGSize

    var body: some View {
        Canvas { context, size in
            // Fill entire view with dark overlay
            let fullRect = CGRect(origin: .zero, size: size)
            context.fill(Path(fullRect), with: .color(.black.opacity(0.6)))

            // Cut out the quadrilateral area
            guard corners.count == 4 else { return }

            var quadPath = Path()
            quadPath.move(to: corners[0])
            quadPath.addLine(to: corners[1])
            quadPath.addLine(to: corners[2])
            quadPath.addLine(to: corners[3])
            quadPath.closeSubpath()

            context.blendMode = .destinationOut
            context.fill(quadPath, with: .color(.white))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Detected Hole Model

struct DetectedHole: Identifiable {
    var id = UUID()
    var position: CGPoint // Normalized 0-1
    var score: Int
    var confidence: Double
    var radius: CGFloat = 0.02 // Normalized radius
    var needsReview: Bool = false
    var reviewReason: String? = nil
}

// MARK: - Score Edit Button

struct ScoreEditButton: View {
    let score: Int
    let onEdit: (Int) -> Void

    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            Text(score == 10 ? "X" : "\(score)")
                .font(.title3.bold())
                .frame(width: 44, height: 44)
                .background(scoreColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
        .confirmationDialog("Edit Score", isPresented: $showingPicker) {
            ForEach((0...10).reversed(), id: \.self) { s in
                Button(s == 10 ? "X (10)" : "\(s)") {
                    onEdit(s)
                }
            }
            Button("Delete", role: .destructive) {
                onEdit(-1) // Signal deletion
            }
        }
    }

    private var scoreColor: Color {
        switch score {
        case 10: return .yellow
        case 9: return .orange
        case 8: return .red
        case 7: return .blue
        case 6: return .cyan
        default: return .gray
        }
    }
}

// MARK: - Annotated Target Image (Read-only version)

struct AnnotatedTargetImage: View {
    let image: UIImage
    let holes: [DetectedHole]
    let targetCenter: CGPoint?
    let targetSize: CGSize?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                // Draw detected target outline (oval for tetrathlon)
                if let center = targetCenter, let size = targetSize {
                    Ellipse()
                        .stroke(.green, lineWidth: 2)
                        .frame(
                            width: size.width * geo.size.width,
                            height: size.height * geo.size.height
                        )
                        .position(
                            x: center.x * geo.size.width,
                            y: center.y * geo.size.height
                        )
                }

                // Draw detected holes
                ForEach(holes) { hole in
                    ZStack {
                        Circle()
                            .fill(.red.opacity(0.5))
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(.red, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Text("\(hole.score)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    .position(
                        x: hole.position.x * geo.size.width,
                        y: hole.position.y * geo.size.height
                    )
                }
            }
        }
    }
}

// MARK: - Interactive Annotated Target Image (Editable version with zoom)

struct InteractiveAnnotatedTargetImage: View {
    let image: UIImage
    @Binding var holes: [DetectedHole]
    let targetCenter: CGPoint?
    let targetSize: CGSize?
    let onHoleAdded: ((CGPoint) -> Void)?
    let onHoleMoved: ((UUID, CGPoint) -> Void)?
    let onHoleDeleted: ((UUID) -> Void)?

    @State private var selectedHoleID: UUID?

    // Zoom and pan state
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(
        image: UIImage,
        holes: Binding<[DetectedHole]>,
        targetCenter: CGPoint?,
        targetSize: CGSize?,
        onHoleAdded: ((CGPoint) -> Void)? = nil,
        onHoleMoved: ((UUID, CGPoint) -> Void)? = nil,
        onHoleDeleted: ((UUID) -> Void)? = nil
    ) {
        self.image = image
        self._holes = holes
        self.targetCenter = targetCenter
        self.targetSize = targetSize
        self.onHoleAdded = onHoleAdded
        self.onHoleMoved = onHoleMoved
        self.onHoleDeleted = onHoleDeleted
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background tap catcher - this handles adding new holes
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, geoSize: geo.size)
                    }

                // Zoomable/pannable content
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // Draw editable holes - positioned in normalized coordinates
                    ForEach(holes) { hole in
                        SimpleHoleMarker(
                            hole: hole,
                            isSelected: selectedHoleID == hole.id,
                            geoSize: geo.size,
                            scale: scale,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selectedHoleID == hole.id {
                                        selectedHoleID = nil
                                    } else {
                                        selectedHoleID = hole.id
                                    }
                                }
                            },
                            onDelete: {
                                onHoleDeleted?(hole.id)
                                selectedHoleID = nil
                            }
                        )
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    // Pinch to zoom
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(1.0, min(value, 5.0))
                        }
                        .onEnded { value in
                            scale = max(1.0, min(value, 5.0))
                            if scale <= 1.0 {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    // Drag for panning - only when zoomed
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    // Double tap to reset zoom or zoom in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if scale > 1.0 {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                        }
                        selectedHoleID = nil
                    }
                }

                // Minimal zoom controls - bottom right only
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        if scale > 1.0 {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    Text(String(format: "%.1fx", scale))
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.7))
                                .clipShape(Capsule())
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .clipped()
        }
    }

    private func handleTap(at location: CGPoint, geoSize: CGSize) {
        // The tap location is in the GeometryReader's coordinate space
        // We need to convert it to normalized image coordinates (0-1)

        // Account for zoom and pan: reverse the transformations
        let centerX = geoSize.width / 2
        let centerY = geoSize.height / 2

        // The content is scaled around center and then offset
        // To get the original position: (tapped - center - offset) / scale + center
        let imageX = (location.x - centerX - offset.width) / scale + centerX
        let imageY = (location.y - centerY - offset.height) / scale + centerY

        // Convert to normalized coordinates (0-1)
        let normalizedX = imageX / geoSize.width
        let normalizedY = imageY / geoSize.height

        // First check if tapping on or near an existing hole
        let tapThreshold: CGFloat = 0.05  // 5% of image size

        for hole in holes {
            let dx = normalizedX - hole.position.x
            let dy = normalizedY - hole.position.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < tapThreshold {
                // Tapped on an existing hole - toggle selection
                withAnimation(.easeInOut(duration: 0.15)) {
                    if selectedHoleID == hole.id {
                        selectedHoleID = nil
                    } else {
                        selectedHoleID = hole.id
                    }
                }
                return
            }
        }

        // If a hole was selected, deselect it (tap elsewhere to deselect)
        if selectedHoleID != nil {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedHoleID = nil
            }
            return
        }

        // Clamp to valid range (0-1)
        let clampedPosition = CGPoint(
            x: max(0, min(1, normalizedX)),
            y: max(0, min(1, normalizedY))
        )

        // Add new hole at tapped position
        onHoleAdded?(clampedPosition)
    }
}

// MARK: - Simple Hole Marker (Lightweight for performance)

private struct SimpleHoleMarker: View {
    let hole: DetectedHole
    let isSelected: Bool
    let geoSize: CGSize
    let scale: CGFloat
    let onTap: () -> Void
    let onDelete: () -> Void

    // Marker size scales inversely with zoom for consistent visual size
    private var markerSize: CGFloat { 14 / scale }
    private var deleteButtonSize: CGFloat { 28 / scale }

    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.yellow, lineWidth: 3 / scale)
                    .frame(width: markerSize + 12 / scale, height: markerSize + 12 / scale)
            }

            // Hole marker - red dot
            Circle()
                .fill(Color.red.opacity(0.8))
                .frame(width: markerSize, height: markerSize)
            Circle()
                .stroke(Color.white, lineWidth: 2 / scale)
                .frame(width: markerSize, height: markerSize)

            // Delete button when selected - large and obvious
            if isSelected {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: deleteButtonSize))
                        .foregroundStyle(.white, .red)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .offset(x: 18 / scale, y: -18 / scale)
            }
        }
        .position(
            x: hole.position.x * geoSize.width,
            y: hole.position.y * geoSize.height
        )
        .contentShape(Circle().scale(3)) // Larger tap target
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Simple Hole Marker View

struct HoleMarkerView: View {
    let hole: DetectedHole
    let isSelected: Bool
    let geoSize: CGSize
    let onTap: () -> Void
    let onDelete: () -> Void
    let onMove: ((CGPoint) -> Void)?

    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    private let markerSize: CGFloat = 10
    private let deleteButtonSize: CGFloat = 22

    init(
        hole: DetectedHole,
        isSelected: Bool,
        geoSize: CGSize,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onMove: ((CGPoint) -> Void)? = nil
    ) {
        self.hole = hole
        self.isSelected = isSelected
        self.geoSize = geoSize
        self.onTap = onTap
        self.onDelete = onDelete
        self.onMove = onMove
    }

    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(.yellow, lineWidth: 3)
                    .frame(width: markerSize + 8, height: markerSize + 8)
            }

            // Dragging indicator
            if isDragging {
                Circle()
                    .stroke(.green, lineWidth: 2)
                    .frame(width: markerSize + 12, height: markerSize + 12)
            }

            // Hole marker - simple red dot for pattern analysis
            Circle()
                .fill(.red.opacity(0.7))
                .frame(width: markerSize, height: markerSize)
            Circle()
                .stroke(.red, lineWidth: 2)
                .frame(width: markerSize, height: markerSize)

            // Delete button when selected - larger and easier to tap
            if isSelected && !isDragging {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: deleteButtonSize))
                        .foregroundStyle(.white, .red)
                }
                .frame(width: 44, height: 44) // Large tap target
                .offset(x: 14, y: -14)
            }
        }
        .position(
            x: hole.position.x * geoSize.width + dragOffset.width,
            y: hole.position.y * geoSize.height + dragOffset.height
        )
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture())
                .onChanged { value in
                    switch value {
                    case .first(true):
                        // Long press recognized, ready to drag
                        isDragging = true
                    case .second(true, let drag):
                        // Dragging
                        if let drag = drag {
                            dragOffset = drag.translation
                        }
                    default:
                        break
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag) = value, let drag = drag {
                        // Calculate new normalized position
                        let newX = hole.position.x + drag.translation.width / geoSize.width
                        let newY = hole.position.y + drag.translation.height / geoSize.height
                        let clampedPosition = CGPoint(
                            x: max(0, min(1, newX)),
                            y: max(0, min(1, newY))
                        )
                        onMove?(clampedPosition)
                    }
                    isDragging = false
                    dragOffset = .zero
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if !isDragging {
                        onTap()
                    }
                }
        )
    }

}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    var onAlignmentUpdate: ((AlignmentQuality) -> Void)?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        controller.onAlignmentUpdate = onAlignmentUpdate
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.onAlignmentUpdate = onAlignmentUpdate
    }
}

class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    var onAlignmentUpdate: ((AlignmentQuality) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "video.queue", qos: .userInitiated)

    // Store detected rectangle for auto-crop
    private var detectedRectangle: VNRectangleObservation?

    // Rectangle detection
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleRectangleDetection(request: request, error: error)
        }
        request.minimumAspectRatio = 0.5  // Allow rectangles with varying aspect ratios
        request.maximumAspectRatio = 1.0  // Tetrathlon targets are taller than wide
        request.minimumSize = 0.2  // At least 20% of the image (lowered for distant targets)
        request.maximumObservations = 1  // Just the main target
        request.minimumConfidence = 0.4  // Slightly lower for better detection
        return request
    }()

    private var lastAlignmentUpdate = Date()
    private let alignmentUpdateInterval: TimeInterval = 0.1 // 10 fps for alignment detection

    // Expected guide rectangle (normalized coordinates)
    // Based on: frameWidth = screenWidth - 32, frameHeight = frameWidth * 1.36
    // Centered in the view
    private var expectedGuideRect: CGRect {
        // The guide is centered and takes up most of the width
        let guideWidth: CGFloat = 0.9  // ~90% of screen width (accounting for 16pt padding each side)
        let guideHeight = guideWidth * 1.36  // Tetrathlon aspect ratio
        let guideX = (1.0 - guideWidth) / 2
        let guideY = (1.0 - guideHeight) / 2
        return CGRect(x: guideX, y: guideY, width: guideWidth, height: guideHeight)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermission()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
            setupCaptureButton()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                        self?.setupCaptureButton()
                    } else {
                        self?.showCameraUnavailable(message: "Camera access denied.\nPlease enable in Settings.")
                    }
                }
            }
        case .denied, .restricted:
            showCameraUnavailable(message: "Camera access denied.\nPlease enable in Settings.")
        @unknown default:
            showCameraUnavailable(message: "Camera unavailable")
        }
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            showCameraUnavailable(message: "Camera unavailable\nUse photo library instead")
            return
        }

        guard let session = captureSession else { return }

        session.addInput(input)

        // Photo output for capturing
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput {
            session.addOutput(photoOutput)
        }

        // Video output for real-time rectangle detection
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        videoOutput?.setSampleBufferDelegate(self, queue: videoQueue)
        if let videoOutput = videoOutput {
            session.addOutput(videoOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds

        if let layer = previewLayer {
            view.layer.addSublayer(layer)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func showCameraUnavailable(message: String = "Camera unavailable\nUse photo library instead") {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupCaptureButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 70, weight: .regular)
        button.setImage(UIImage(systemName: "circle.inset.filled", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    // MARK: - Rectangle Detection

    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        guard error == nil else {
            detectedRectangle = nil
            updateAlignment(.none)
            return
        }

        guard let results = request.results as? [VNRectangleObservation],
              let rectangle = results.first else {
            detectedRectangle = nil
            updateAlignment(.none)
            return
        }

        // Store the detected rectangle for auto-crop
        detectedRectangle = rectangle

        // Calculate how well the detected rectangle matches the expected guide
        let detectedRect = CGRect(
            x: rectangle.boundingBox.origin.x,
            y: rectangle.boundingBox.origin.y,
            width: rectangle.boundingBox.width,
            height: rectangle.boundingBox.height
        )

        let quality = calculateAlignmentQuality(detected: detectedRect, expected: expectedGuideRect)
        updateAlignment(quality)
    }

    private func calculateAlignmentQuality(detected: CGRect, expected: CGRect) -> AlignmentQuality {
        // Calculate overlap (Intersection over Union)
        let intersection = detected.intersection(expected)
        let union = detected.union(expected)

        guard !intersection.isNull && union.width > 0 && union.height > 0 else {
            return .none
        }

        let iou = (intersection.width * intersection.height) / (union.width * union.height)

        // Check aspect ratio similarity
        let detectedAspect = detected.height / detected.width
        let expectedAspect = expected.height / expected.width
        let aspectDiff = abs(detectedAspect - expectedAspect) / expectedAspect

        // Check center alignment
        let detectedCenter = CGPoint(x: detected.midX, y: detected.midY)
        let expectedCenter = CGPoint(x: expected.midX, y: expected.midY)
        let centerDistance = sqrt(pow(detectedCenter.x - expectedCenter.x, 2) + pow(detectedCenter.y - expectedCenter.y, 2))

        // Evaluate quality
        if iou > 0.7 && aspectDiff < 0.15 && centerDistance < 0.1 {
            return .good
        } else if iou > 0.4 || (aspectDiff < 0.3 && centerDistance < 0.2) {
            return .partial
        } else {
            return .none
        }
    }

    private func updateAlignment(_ quality: AlignmentQuality) {
        DispatchQueue.main.async { [weak self] in
            self?.onAlignmentUpdate?(quality)
        }
    }
}

// MARK: - Video Sample Buffer Delegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle to avoid excessive processing
        let now = Date()
        guard now.timeIntervalSince(lastAlignmentUpdate) >= alignmentUpdateInterval else { return }
        lastAlignmentUpdate = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([rectangleRequest])
        } catch {
            // Silently fail - alignment detection is optional
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }

        // Pass raw image - manual crop view handles cropping now
        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(image)
        }
    }
}

// MARK: - Target Analyzer (Multi-Signal Pipeline)

actor TargetAnalyzer {
    struct AnalysisResult {
        var holes: [DetectedHole]
        var targetCenter: CGPoint?
        var targetSize: CGSize?
        var scoringRings: [ScoringRing]
        var qualityWarnings: [String]
        var processingTimeMs: Int
    }

    struct ScoringRing {
        var normalizedHeight: CGFloat
        var score: Int
    }

    /// Analyze target image using multi-signal detection pipeline
    static func analyze(image: UIImage) async throws -> AnalysisResult {
        // Use the new multi-signal detection pipeline
        let pipeline = HoleDetectionPipeline()
        let detectionResult = try await pipeline.detect(image: image)

        // Combine accepted and flagged holes
        var allHoles = detectionResult.acceptedHoles
        allHoles.append(contentsOf: detectionResult.flaggedCandidates)

        return AnalysisResult(
            holes: allHoles,
            targetCenter: CGPoint(x: 0.5, y: 0.5),
            targetSize: CGSize(width: 0.8, height: 0.9),
            scoringRings: [],
            qualityWarnings: detectionResult.qualityWarnings,
            processingTimeMs: detectionResult.processingTimeMs
        )
    }

    enum AnalysisError: Error {
        case invalidImage
        case analysisFailed
    }
}
