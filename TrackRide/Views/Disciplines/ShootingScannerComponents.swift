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

struct TargetScannerView: View {
    let expectedShots: Int // 0 = unlimited
    let onScanned: ([Int]) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext

    // Flow states: camera -> crop -> analysis
    @State private var rawCapturedImage: UIImage?  // Original image before cropping
    @State private var capturedImage: UIImage?      // Cropped image for analysis
    @State private var showingCropView = false
    @State private var detectedHoles: [DetectedHole] = []
    @State private var detectedTargetCenter: CGPoint?
    @State private var detectedTargetSize: CGSize?
    @State private var showingImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var aiCoachingInsights: ShootingCoachingInsights?
    @State private var isLoadingAICoaching = false
    @State private var saveAnalysis = true  // Option to save for historical tracking

    var body: some View {
        ZStack {
            if showingCropView, let rawImage = rawCapturedImage {
                // Manual cropping step
                ManualCropView(
                    image: rawImage,
                    onCropped: { croppedImage in
                        capturedImage = croppedImage
                        showingCropView = false
                        // No auto-detection - user will manually mark holes
                        detectedHoles = []
                        // Set default target center and size for scoring calculation
                        detectedTargetCenter = CGPoint(x: 0.5, y: 0.5)
                        detectedTargetSize = CGSize(width: 0.7, height: 0.9)
                    },
                    onCancel: {
                        rawCapturedImage = nil
                        showingCropView = false
                    }
                )
            } else if let image = capturedImage {
                analysisView(image: image)
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
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    Spacer()
                    Text("Scan Target")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    Spacer()
                    Button {
                        showingImagePicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
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
                        Capsule().fill(.ultraThinMaterial)
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

    private func analysisView(image: UIImage) -> some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Button("Retake") {
                        // Reset all states and go back to camera
                        capturedImage = nil
                        rawCapturedImage = nil
                        showingCropView = false
                        detectedHoles = []
                        detectedTargetCenter = nil
                        detectedTargetSize = nil
                        aiCoachingInsights = nil
                    }
                    Spacer()
                    Text("Mark Holes")
                        .font(.headline)
                    Spacer()
                    Button("Cancel") { onCancel() }
                }
                .padding()

                ScrollView {
                    VStack(spacing: 16) {
                        // Interactive annotated image with zoom
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
                        .frame(height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Correction instructions
                        VStack(alignment: .leading, spacing: 6) {
                            Label("How to Mark Holes", systemImage: "hand.tap")
                                .font(.caption.bold())
                                .foregroundStyle(.blue)
                            HStack(spacing: 16) {
                                Label("Tap to add hole", systemImage: "plus.circle")
                                Label("Hold & drag to move", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            HStack(spacing: 16) {
                                Label("Tap marker then X", systemImage: "xmark.circle")
                                Label("Pinch to zoom", systemImage: "magnifyingglass")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Pattern Analysis
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Pattern Analysis")
                                    .font(.headline)
                                Spacer()
                                Text("\(detectedHoles.count) shots")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if detectedHoles.isEmpty {
                                Text("Tap on the target image to mark each hole")
                                    .foregroundStyle(.secondary)
                            } else {
                                // Pattern feedback
                                patternFeedbackView
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Visual pattern indicator
                        if !detectedHoles.isEmpty {
                            patternVisualization
                        }

                        // Apple Intelligence Coaching
                        if !detectedHoles.isEmpty {
                            aiCoachingSection
                        }

                        // Save for history toggle
                        if !detectedHoles.isEmpty {
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
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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

    // MARK: - Hole Correction Functions

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

        // Sort by score
        detectedHoles.sort { $0.score > $1.score }
    }

    private func moveHole(id: UUID, to newPosition: CGPoint) {
        guard let index = detectedHoles.firstIndex(where: { $0.id == id }) else { return }

        let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)
        let targetSize = detectedTargetSize ?? CGSize(width: 0.4, height: 0.6)

        // Recalculate score based on new position
        let newScore = calculateScore(for: newPosition, center: targetCenter, size: targetSize)

        detectedHoles[index].position = newPosition
        detectedHoles[index].score = newScore

        // Re-sort by score
        detectedHoles.sort { $0.score > $1.score }
    }

    private func deleteHole(id: UUID) {
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
            .background(Color(.secondarySystemBackground))
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
        .background(Color(.secondarySystemBackground))
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

// MARK: - Manual Crop View

struct ManualCropView: View {
    let image: UIImage
    let onCropped: (UIImage) -> Void
    let onCancel: () -> Void

    // Crop rectangle state (normalized 0-1 coordinates)
    @State private var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

    // Which handle is being dragged
    @State private var activeHandle: CropHandle?

    // For panning the entire crop area
    @State private var isPanningCrop = false
    @State private var panStartRect = CGRect.zero

    enum CropHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Spacer()

                    Text("Crop Target")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Button("Done") { applyCrop() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .padding(8)
                        .background(.green)
                        .clipShape(Capsule())
                }
                .padding()

                // Image with crop overlay
                GeometryReader { geo in
                    let imageSize = calculateImageSize(in: geo.size)
                    let imageOffset = calculateImageOffset(in: geo.size, imageSize: imageSize)

                    ZStack {
                        // The image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize.width, height: imageSize.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)

                        // Darkened overlay outside crop area
                        CropOverlay(
                            cropRect: cropRect,
                            imageFrame: CGRect(
                                x: imageOffset.x,
                                y: imageOffset.y,
                                width: imageSize.width,
                                height: imageSize.height
                            ),
                            geoSize: geo.size
                        )

                        // Crop handles
                        CropHandles(
                            cropRect: cropRect,
                            imageFrame: CGRect(
                                x: imageOffset.x,
                                y: imageOffset.y,
                                width: imageSize.width,
                                height: imageSize.height
                            ),
                            onHandleDrag: { handle, translation in
                                updateCropRect(handle: handle, translation: translation, imageSize: imageSize)
                            },
                            onPanCrop: { translation in
                                panCropRect(translation: translation, imageSize: imageSize)
                            },
                            onPanStart: {
                                panStartRect = cropRect
                            }
                        )
                    }
                }

                // Instructions
                Text("Drag corners or edges to adjust crop area")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
        }
    }

    private func calculateImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider than container
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller than container
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    private func calculateImageOffset(in containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        return CGPoint(
            x: (containerSize.width - imageSize.width) / 2,
            y: (containerSize.height - imageSize.height) / 2
        )
    }

    private func updateCropRect(handle: CropHandle, translation: CGSize, imageSize: CGSize) {
        let dx = translation.width / imageSize.width
        let dy = translation.height / imageSize.height

        var newRect = cropRect

        switch handle {
        case .topLeft:
            newRect.origin.x += dx
            newRect.origin.y += dy
            newRect.size.width -= dx
            newRect.size.height -= dy
        case .topRight:
            newRect.origin.y += dy
            newRect.size.width += dx
            newRect.size.height -= dy
        case .bottomLeft:
            newRect.origin.x += dx
            newRect.size.width -= dx
            newRect.size.height += dy
        case .bottomRight:
            newRect.size.width += dx
            newRect.size.height += dy
        case .top:
            newRect.origin.y += dy
            newRect.size.height -= dy
        case .bottom:
            newRect.size.height += dy
        case .left:
            newRect.origin.x += dx
            newRect.size.width -= dx
        case .right:
            newRect.size.width += dx
        }

        // Clamp to valid bounds
        newRect.origin.x = max(0, min(1 - 0.1, newRect.origin.x))
        newRect.origin.y = max(0, min(1 - 0.1, newRect.origin.y))
        newRect.size.width = max(0.1, min(1 - newRect.origin.x, newRect.size.width))
        newRect.size.height = max(0.1, min(1 - newRect.origin.y, newRect.size.height))

        cropRect = newRect
    }

    private func panCropRect(translation: CGSize, imageSize: CGSize) {
        let dx = translation.width / imageSize.width
        let dy = translation.height / imageSize.height

        var newRect = panStartRect
        newRect.origin.x += dx
        newRect.origin.y += dy

        // Clamp to valid bounds
        newRect.origin.x = max(0, min(1 - newRect.size.width, newRect.origin.x))
        newRect.origin.y = max(0, min(1 - newRect.size.height, newRect.origin.y))

        cropRect = newRect
    }

    private func applyCrop() {
        guard let cgImage = image.cgImage else {
            onCropped(image)
            return
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        let cropX = cropRect.origin.x * imageWidth
        let cropY = cropRect.origin.y * imageHeight
        let cropWidth = cropRect.size.width * imageWidth
        let cropHeight = cropRect.size.height * imageHeight

        let cropCGRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)

        guard let croppedCGImage = cgImage.cropping(to: cropCGRect) else {
            onCropped(image)
            return
        }

        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        onCropped(croppedImage)
    }
}

// MARK: - Crop Overlay (darkens area outside crop)

struct CropOverlay: View {
    let cropRect: CGRect
    let imageFrame: CGRect
    let geoSize: CGSize

    var body: some View {
        Canvas { context, size in
            // Fill entire view with dark overlay
            let fullRect = CGRect(origin: .zero, size: size)
            context.fill(Path(fullRect), with: .color(.black.opacity(0.6)))

            // Cut out the crop area (make it transparent)
            let cropPath = Path(CGRect(
                x: imageFrame.origin.x + cropRect.origin.x * imageFrame.width,
                y: imageFrame.origin.y + cropRect.origin.y * imageFrame.height,
                width: cropRect.width * imageFrame.width,
                height: cropRect.height * imageFrame.height
            ))
            context.blendMode = .destinationOut
            context.fill(cropPath, with: .color(.white))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Crop Handles

struct CropHandles: View {
    let cropRect: CGRect
    let imageFrame: CGRect
    let onHandleDrag: (ManualCropView.CropHandle, CGSize) -> Void
    let onPanCrop: (CGSize) -> Void
    let onPanStart: () -> Void

    private let handleSize: CGFloat = 30
    private let edgeHandleLength: CGFloat = 44

    var body: some View {
        let cropFrame = CGRect(
            x: imageFrame.origin.x + cropRect.origin.x * imageFrame.width,
            y: imageFrame.origin.y + cropRect.origin.y * imageFrame.height,
            width: cropRect.width * imageFrame.width,
            height: cropRect.height * imageFrame.height
        )

        ZStack {
            // Border
            Rectangle()
                .stroke(.white, lineWidth: 2)
                .frame(width: cropFrame.width, height: cropFrame.height)
                .position(x: cropFrame.midX, y: cropFrame.midY)

            // Grid lines (rule of thirds)
            Path { path in
                // Vertical lines
                path.move(to: CGPoint(x: cropFrame.minX + cropFrame.width / 3, y: cropFrame.minY))
                path.addLine(to: CGPoint(x: cropFrame.minX + cropFrame.width / 3, y: cropFrame.maxY))
                path.move(to: CGPoint(x: cropFrame.minX + cropFrame.width * 2 / 3, y: cropFrame.minY))
                path.addLine(to: CGPoint(x: cropFrame.minX + cropFrame.width * 2 / 3, y: cropFrame.maxY))
                // Horizontal lines
                path.move(to: CGPoint(x: cropFrame.minX, y: cropFrame.minY + cropFrame.height / 3))
                path.addLine(to: CGPoint(x: cropFrame.maxX, y: cropFrame.minY + cropFrame.height / 3))
                path.move(to: CGPoint(x: cropFrame.minX, y: cropFrame.minY + cropFrame.height * 2 / 3))
                path.addLine(to: CGPoint(x: cropFrame.maxX, y: cropFrame.minY + cropFrame.height * 2 / 3))
            }
            .stroke(.white.opacity(0.5), lineWidth: 1)

            // Corner handles
            cornerHandle(at: CGPoint(x: cropFrame.minX, y: cropFrame.minY), handle: .topLeft)
            cornerHandle(at: CGPoint(x: cropFrame.maxX, y: cropFrame.minY), handle: .topRight)
            cornerHandle(at: CGPoint(x: cropFrame.minX, y: cropFrame.maxY), handle: .bottomLeft)
            cornerHandle(at: CGPoint(x: cropFrame.maxX, y: cropFrame.maxY), handle: .bottomRight)

            // Edge handles
            edgeHandle(at: CGPoint(x: cropFrame.midX, y: cropFrame.minY), handle: .top, isHorizontal: true)
            edgeHandle(at: CGPoint(x: cropFrame.midX, y: cropFrame.maxY), handle: .bottom, isHorizontal: true)
            edgeHandle(at: CGPoint(x: cropFrame.minX, y: cropFrame.midY), handle: .left, isHorizontal: false)
            edgeHandle(at: CGPoint(x: cropFrame.maxX, y: cropFrame.midY), handle: .right, isHorizontal: false)

            // Center drag area (to move entire crop)
            Rectangle()
                .fill(.clear)
                .frame(width: cropFrame.width - handleSize * 2, height: cropFrame.height - handleSize * 2)
                .position(x: cropFrame.midX, y: cropFrame.midY)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation == .zero {
                                onPanStart()
                            }
                            onPanCrop(value.translation)
                        }
                )
                .contentShape(Rectangle())
        }
    }

    private func cornerHandle(at position: CGPoint, handle: ManualCropView.CropHandle) -> some View {
        Circle()
            .fill(.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(color: .black.opacity(0.3), radius: 2)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onHandleDrag(handle, value.translation)
                    }
            )
    }

    private func edgeHandle(at position: CGPoint, handle: ManualCropView.CropHandle, isHorizontal: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white)
            .frame(
                width: isHorizontal ? edgeHandleLength : 8,
                height: isHorizontal ? 8 : edgeHandleLength
            )
            .shadow(color: .black.opacity(0.3), radius: 2)
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        onHandleDrag(handle, value.translation)
                    }
            )
    }
}

// MARK: - Detected Hole Model

struct DetectedHole: Identifiable {
    let id = UUID()
    var position: CGPoint // Normalized 0-1
    var score: Int
    var confidence: Double
    var radius: CGFloat = 0.02 // Normalized radius
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
    @State private var showingDeleteConfirmation = false
    @State private var holeToDelete: UUID?

    // Zoom and pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0

    // Track the geo size for tap handling
    @State private var currentGeoSize: CGSize = .zero

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
                // Zoomable/pannable content
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // Draw editable holes
                    ForEach(holes) { hole in
                        DraggableHoleMarker(
                            hole: hole,
                            isSelected: selectedHoleID == hole.id,
                            geoSize: geo.size,
                            scale: scale,
                            onSelect: {
                                if selectedHoleID == hole.id {
                                    // Already selected - show delete confirmation
                                    holeToDelete = hole.id
                                    showingDeleteConfirmation = true
                                } else {
                                    selectedHoleID = hole.id
                                }
                            },
                            onMove: { newPosition in
                                onHoleMoved?(hole.id, newPosition)
                            },
                            onDelete: {
                                holeToDelete = hole.id
                                showingDeleteConfirmation = true
                            }
                        )
                    }
                }
                .scaleEffect(scale * magnifyBy)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(
                    // Single tap to add holes (uses SpatialTapGesture for location)
                    SpatialTapGesture()
                        .onEnded { value in
                            handleTap(at: value.location, geoSize: geo.size)
                        }
                )
                .simultaneousGesture(
                    // Double tap to reset zoom
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                selectedHoleID = nil
                            }
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($magnifyBy) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            let newScale = lastScale * value
                            scale = min(max(newScale, 1.0), 5.0) // Limit zoom 1x-5x
                            lastScale = scale

                            // Reset offset if zoomed out
                            if scale == 1.0 {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 && selectedHoleID == nil {
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

                // Zoom controls overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            // Zoom indicator
                            if scale > 1.0 {
                                Text(String(format: "%.1fx", scale))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Capsule())
                            }

                            // Reset zoom button
                            if scale > 1.0 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } label: {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            .clipped()
            .onAppear { currentGeoSize = geo.size }
            .onChange(of: geo.size) { _, newSize in currentGeoSize = newSize }
        }
        .confirmationDialog("Delete this hole?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = holeToDelete {
                    onHoleDeleted?(id)
                    selectedHoleID = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func handleTap(at location: CGPoint, geoSize: CGSize) {
        // First check if tapping on or near an existing hole
        let tapThreshold: CGFloat = 30 / scale  // Adjust for zoom

        for hole in holes {
            let holeX = hole.position.x * geoSize.width
            let holeY = hole.position.y * geoSize.height
            let distance = sqrt(pow(location.x - holeX, 2) + pow(location.y - holeY, 2))

            if distance < tapThreshold {
                // Tapped on an existing hole - select or delete it
                if selectedHoleID == hole.id {
                    holeToDelete = hole.id
                    showingDeleteConfirmation = true
                } else {
                    selectedHoleID = hole.id
                }
                return
            }
        }

        // Deselect if a hole was selected
        if selectedHoleID != nil {
            selectedHoleID = nil
            return
        }

        // Convert tap location accounting for zoom and pan
        let adjustedX = (location.x - geoSize.width / 2) / scale + geoSize.width / 2 - offset.width / scale
        let adjustedY = (location.y - geoSize.height / 2) / scale + geoSize.height / 2 - offset.height / scale

        let normalizedPosition = CGPoint(
            x: adjustedX / geoSize.width,
            y: adjustedY / geoSize.height
        )

        // Clamp to valid range
        let clampedPosition = CGPoint(
            x: max(0, min(1, normalizedPosition.x)),
            y: max(0, min(1, normalizedPosition.y))
        )

        // Add hole directly with calculated score (no picker for free practice)
        onHoleAdded?(clampedPosition)
    }
}

// MARK: - Draggable Hole Marker

struct DraggableHoleMarker: View {
    let hole: DetectedHole
    let isSelected: Bool
    let geoSize: CGSize
    var scale: CGFloat = 1.0
    let onSelect: () -> Void
    let onMove: (CGPoint) -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @GestureState private var isDragging = false

    // Adjust marker size based on zoom level (smaller when zoomed in)
    private var markerSize: CGFloat { 24 / scale }
    private var selectionSize: CGFloat { 32 / scale }
    private var deleteButtonSize: CGFloat { 18 / scale }
    private var deleteOffset: CGFloat { 14 / scale }

    var body: some View {
        ZStack {
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(.yellow, lineWidth: 3 / scale)
                    .frame(width: selectionSize, height: selectionSize)
            }

            // Hole marker
            Circle()
                .fill(holeColor.opacity(0.6))
                .frame(width: markerSize, height: markerSize)
            Circle()
                .stroke(holeColor, lineWidth: 2 / scale)
                .frame(width: markerSize, height: markerSize)
            Text("\(hole.score)")
                .font(.system(size: 12 / scale, weight: .bold))
                .foregroundStyle(.white)

            // Delete button when selected
            if isSelected {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: deleteButtonSize))
                        .foregroundStyle(.white, .red)
                }
                .offset(x: deleteOffset, y: -deleteOffset)
            }
        }
        .position(
            x: hole.position.x * geoSize.width + dragOffset.width,
            y: hole.position.y * geoSize.height + dragOffset.height
        )
        .gesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture())
                .updating($isDragging) { value, state, _ in
                    switch value {
                    case .second(true, _):
                        state = true
                    default:
                        break
                    }
                }
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if let drag = drag {
                            // Adjust drag for zoom level
                            dragOffset = CGSize(
                                width: drag.translation.width / scale,
                                height: drag.translation.height / scale
                            )
                        }
                    default:
                        break
                    }
                }
                .onEnded { value in
                    switch value {
                    case .second(true, let drag):
                        if let drag = drag {
                            let newPosition = CGPoint(
                                x: hole.position.x + drag.translation.width / (geoSize.width * scale),
                                y: hole.position.y + drag.translation.height / (geoSize.height * scale)
                            )
                            onMove(newPosition)
                        }
                    default:
                        break
                    }
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            onSelect()
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private var holeColor: Color {
        switch hole.score {
        case 10: return .yellow
        case 8: return .orange
        case 6: return .red
        case 4: return .blue
        case 2: return .purple
        default: return .gray
        }
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

// MARK: - Target Analyzer (Vision-based)

actor TargetAnalyzer {
    struct AnalysisResult {
        var holes: [DetectedHole]
        var targetCenter: CGPoint?
        var targetSize: CGSize?  // For oval targets (width, height)
        var scoringRings: [ScoringRing]  // Detected ring lines
    }

    struct ScoringRing {
        var normalizedHeight: CGFloat  // Height in normalized coords (0-1)
        var score: Int  // Tetrathlon score for this ring (2, 4, 6, 8, 10)
    }

    static func analyze(image: UIImage) async throws -> AnalysisResult {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }

        var result = AnalysisResult(holes: [], targetCenter: nil, targetSize: nil, scoringRings: [])

        // Detect contours for hole and target detection
        let contourRequest = VNDetectContoursRequest()
        contourRequest.maximumImageDimension = 1024
        contourRequest.contrastAdjustment = 2.0

        // Also detect lines for scoring rings
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([contourRequest])

        // Process contour results
        if let contours = contourRequest.results?.first {
            // Find the target (largest oval/elliptical contour - vertical oval for tetrathlon)
            let targetInfo = detectOvalTarget(from: contours)
            result.targetCenter = targetInfo.center
            result.targetSize = targetInfo.size

            // Detect scoring ring lines (horizontal lines in the target)
            result.scoringRings = detectScoringRings(
                from: contours,
                targetCenter: result.targetCenter ?? CGPoint(x: 0.5, y: 0.5),
                targetSize: result.targetSize ?? CGSize(width: 0.3, height: 0.5)
            )

            // Find holes (small circular contours)
            let holes = detectHolesFromContours(
                contours: contours,
                targetCenter: result.targetCenter ?? CGPoint(x: 0.5, y: 0.5),
                targetSize: result.targetSize ?? CGSize(width: 0.3, height: 0.5),
                scoringRings: result.scoringRings
            )
            result.holes = holes
        }

        // Sort holes by score (highest first)
        result.holes.sort { $0.score > $1.score }

        return result
    }

    private static func detectOvalTarget(from contours: VNContoursObservation) -> (center: CGPoint?, size: CGSize?) {
        var largestOval: (center: CGPoint, size: CGSize)? = nil
        var largestArea: Float = 0

        for i in 0..<contours.contourCount {
            guard let contour = try? contours.contour(at: i) else { continue }

            let points = contour.normalizedPoints
            guard points.count >= 20 else { continue }

            // Calculate bounding box
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { continue }

            let width = maxX - minX
            let height = maxY - minY
            let area = width * height

            // Must be reasonably large
            guard width > 0.1 && height > 0.1 else { continue }

            // Tetrathlon targets are vertical ovals (height > width)
            // Accept aspect ratios from 0.5 to 1.2 (allowing for viewing angle variations)
            let aspectRatio = width / height
            guard aspectRatio > 0.4 && aspectRatio < 1.3 else { continue }

            // Check ellipse-like shape
            let perimeter = calculatePerimeter(points: points)
            let expectedPerimeter = Float.pi * (1.5 * (width + height) - sqrt(width * height))
            let shapeRatio = perimeter / expectedPerimeter
            guard shapeRatio > 0.7 && shapeRatio < 1.5 else { continue }

            if area > largestArea {
                largestArea = area
                let centerX = (minX + maxX) / 2
                let centerY = 1 - ((minY + maxY) / 2)
                largestOval = (
                    CGPoint(x: CGFloat(centerX), y: CGFloat(centerY)),
                    CGSize(width: CGFloat(width), height: CGFloat(height))
                )
            }
        }

        return (largestOval?.center, largestOval?.size)
    }

    private static func detectScoringRings(from contours: VNContoursObservation, targetCenter: CGPoint, targetSize: CGSize) -> [ScoringRing] {
        // Tetrathlon targets have 5 scoring zones: 2, 4, 6, 8, 10
        // These are divided by horizontal lines or elliptical rings
        // We'll estimate 5 equal zones within the target
        var rings: [ScoringRing] = []

        let zoneHeight = targetSize.height / 5

        // Create 5 zones from center outward (innermost = 10, outermost = 2)
        for i in 0..<5 {
            let score = 10 - (i * 2)  // 10, 8, 6, 4, 2
            let normalizedHeight = CGFloat(i) * zoneHeight / targetSize.height
            rings.append(ScoringRing(normalizedHeight: normalizedHeight, score: score))
        }

        return rings
    }

    private static func calculateTetrathlonScore(holePosition: CGPoint, targetCenter: CGPoint, targetSize: CGSize) -> Int {
        // For tetrathlon oval targets, score based on position within the oval
        // The center vertical zone is 10, moving outward: 8, 6, 4, 2

        // Calculate normalized position within the target
        let dx = abs(holePosition.x - targetCenter.x) / (targetSize.width / 2)
        let dy = abs(holePosition.y - targetCenter.y) / (targetSize.height / 2)

        // Use elliptical distance (normalized to target shape)
        let ellipticalDistance = sqrt(dx * dx + dy * dy)

        // Tetrathlon uses only even scores: 2, 4, 6, 8, 10
        // Divide target into 5 zones
        if ellipticalDistance < 0.2 { return 10 }
        if ellipticalDistance < 0.4 { return 8 }
        if ellipticalDistance < 0.6 { return 6 }
        if ellipticalDistance < 0.8 { return 4 }
        if ellipticalDistance < 1.0 { return 2 }
        return 0 // Miss - outside target
    }

    private static func detectHolesFromContours(contours: VNContoursObservation, targetCenter: CGPoint, targetSize: CGSize, scoringRings: [ScoringRing]) -> [DetectedHole] {
        var holes: [DetectedHole] = []

        for i in 0..<contours.contourCount {
            guard let contour = try? contours.contour(at: i) else { continue }

            let points = contour.normalizedPoints
            guard points.count >= 8 else { continue }

            // Calculate bounding box
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { continue }

            let width = maxX - minX
            let height = maxY - minY

            // Check if roughly circular (bullet holes are round)
            guard width > 0.005 && height > 0.005 else { continue }
            let aspectRatio = width / height
            guard aspectRatio > 0.6 && aspectRatio < 1.6 else { continue }

            // Check if small enough to be a hole
            guard width < 0.08 && height < 0.08 else { continue }

            let centerX = (minX + maxX) / 2
            let centerY = 1 - ((minY + maxY) / 2)

            let position = CGPoint(x: CGFloat(centerX), y: CGFloat(centerY))

            // Calculate tetrathlon score
            let score = calculateTetrathlonScore(
                holePosition: position,
                targetCenter: targetCenter,
                targetSize: targetSize
            )

            // Calculate circularity as confidence
            let perimeter = calculatePerimeter(points: points)
            let area = width * height
            let circularity = (4 * .pi * area) / (perimeter * perimeter)
            let confidence = min(1.0, Double(circularity))

            if confidence > 0.4 && score > 0 {
                holes.append(DetectedHole(
                    position: position,
                    score: score,
                    confidence: confidence,
                    radius: CGFloat((width + height) / 4)
                ))
            }
        }

        return holes
    }

    private static func calculatePerimeter(points: [SIMD2<Float>]) -> Float {
        var perimeter: Float = 0
        for i in 0..<points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            perimeter += sqrt(dx * dx + dy * dy)
        }
        return perimeter
    }

    enum AnalysisError: Error {
        case invalidImage
        case analysisFailed
    }
}
