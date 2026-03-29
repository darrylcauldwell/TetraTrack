//
//  ShootingCompetitionComponents.swift
//  TetraTrack
//
//  Competition and practice views for shooting discipline
//

import SwiftUI
import PhotosUI
import TetraTrackShared
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Transferable Image Helper

struct TransferableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            return TransferableImage(image: image)
        }
    }

    enum TransferError: Error {
        case importFailed
    }
}

// MARK: - Competition View

struct ShootingCompetitionView: View {
    /// When provided, runs in standalone mode (competition day): starts its own session
    var standaloneContext: ShootingSessionContext? = nil
    var onEnd: ((Int) -> Void)? = nil
    var onComplete: ((Int) -> Void)? = nil

    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    @State private var card1Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var card2Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var showingResults = false
    @State private var scoringMode: ScoringMode = .scanScore
    @State private var card1ScanAnalysisID: UUID?
    @State private var card2ScanAnalysisID: UUID?
    @State private var showingScanSheet = false
    @State private var scanningCard: Int = 1

    enum ScoringMode: String, CaseIterable {
        case quickEntry = "Quick Entry"
        case scanScore = "Scan & Score"

        var icon: String {
            switch self {
            case .quickEntry: return "hand.tap"
            case .scanScore: return "camera.viewfinder"
            }
        }
    }

    // Tetrathlon scoring: 2, 4, 6, 8, 10 points per shot
    // Total raw score max = 100, tetrathlon points = raw x 10 = max 1000
    private var card1Total: Int { card1Scores.reduce(0, +) }
    private var card2Total: Int { card2Scores.reduce(0, +) }
    private var totalRawScore: Int { card1Total + card2Total }
    private var tetrathlonPoints: Int { totalRawScore * 10 }

    // Valid tetrathlon scores (even numbers only)
    private let validScores = [2, 4, 6, 8, 10]

    // Check if all scores are entered
    private var allScoresEntered: Bool {
        card1Scores.allSatisfy({ $0 > 0 }) && card2Scores.allSatisfy({ $0 > 0 })
    }

    private var isStandalone: Bool { standaloneContext != nil }

    private var sessionContext: ShootingSessionContext {
        standaloneContext ?? shootingPlugin?.sessionContext ?? .competitionTraining
    }

    private var contextColor: Color {
        switch sessionContext.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), contextColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header with context badge and close button
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: sessionContext.icon)
                            .font(.title3)
                        Text(sessionContext.displayName)
                            .font(.title2.bold())
                    }
                    .foregroundStyle(contextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(contextColor.opacity(0.15))
                    .clipShape(Capsule())

                    Spacer()

                    Button(action: {
                        if isStandalone {
                            tracker?.discardSession()
                            onEnd?(0)
                        } else {
                            tracker?.discardSession()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.cardBackground)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)

                if WatchConnectivityManager.shared.isPaired {
                    ShootingWatchStatusCard()
                        .padding(.horizontal)
                }

                if showingResults {
                    resultsView
                } else {
                    scoringView
                }
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if tracker?.sessionState == .tracking || tracker?.sessionState == .paused {
                FloatingControlPanel(
                    disciplineIcon: tracker?.activePlugin?.disciplineIcon ?? "target",
                    disciplineColor: tracker?.activePlugin?.disciplineColor ?? .orange,
                    onStop: {
                        if isStandalone {
                            tracker?.discardSession()
                            onEnd?(0)
                        } else {
                            tracker?.stopSession()
                        }
                    }
                )
            }
        }
        .task {
            // Standalone mode (competition day): start session here
            if let context = standaloneContext, tracker?.sessionState == .idle {
                let plugin = ShootingPlugin(sessionContext: context)
                await tracker?.startSession(plugin: plugin)
            }
        }
        .onDisappear {
            // Standalone mode: discard if still active
            if isStandalone && tracker?.sessionState.isActive == true {
                tracker?.discardSession()
            }
        }
    }

    private var scoringView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card 1
                cardScoringView(cardNumber: 1, scores: $card1Scores, scanAnalysisID: card1ScanAnalysisID)

                // Card 2
                cardScoringView(cardNumber: 2, scores: $card2Scores, scanAnalysisID: card2ScanAnalysisID)

                // Running total with tetrathlon points
                VStack(spacing: 4) {
                    HStack {
                        Text("Total:")
                            .font(.headline)
                        Text("\(totalRawScore)/100")
                            .font(.title.bold())
                            .foregroundStyle(contextColor)
                    }
                    Text("\(tetrathlonPoints) tetrathlon points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard(material: .thin, cornerRadius: 12, padding: 0)

                // Per-shot feedback from Watch (when available)
                if let lastShot = watchShotMetrics.last {
                    lastShotFeedbackCard(lastShot)
                }

                // Session fatigue trend (when 3+ shots detected)
                if watchShotMetrics.count >= 3 {
                    sessionShotSummaryCard
                }

                // Submit button - enabled when all scores entered
                Button(action: { showingResults = true }) {
                    Text("Submit Scores")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(allScoresEntered ? contextColor : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!allScoresEntered)

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
        .fullScreenCover(isPresented: $showingScanSheet) {
            CardScanFlowView(
                cardNumber: scanningCard,
                sessionContext: sessionContext,
                onComplete: { scores, analysisID in
                    if scanningCard == 1 {
                        card1Scores = scores
                        card1ScanAnalysisID = analysisID
                    } else {
                        card2Scores = scores
                        card2ScanAnalysisID = analysisID
                    }
                    showingScanSheet = false
                },
                onCancel: {
                    showingScanSheet = false
                }
            )
        }
    }

    private func cardScoringView(cardNumber: Int, scores: Binding<[Int]>, scanAnalysisID: UUID?) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Card \(cardNumber)")
                    .font(.headline)
                Spacer()
                if let _ = scanAnalysisID {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Scanned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if scoringMode == .scanScore {
                // Scan mode
                if scanAnalysisID != nil {
                    // Show scanned scores (read-only display)
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { shotIndex in
                            Text(scores.wrappedValue[shotIndex] > 0 ?
                                 (scores.wrappedValue[shotIndex] == 10 ? "X" : "\(scores.wrappedValue[shotIndex])") : "-")
                                .font(.title3.bold())
                                .frame(width: 50, height: 50)
                                .background(scores.wrappedValue[shotIndex] > 0 ? contextColor.opacity(0.2) : AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    // Scan button
                    Button {
                        scanningCard = cardNumber
                        showingScanSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Card \(cardNumber)")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(contextColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                // Quick entry mode (existing manual entry)
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { shotIndex in
                        Menu {
                            ForEach(validScores.reversed(), id: \.self) { score in
                                Button("\(score) pts") {
                                    scores.wrappedValue[shotIndex] = score
                                }
                            }
                        } label: {
                            Text(scores.wrappedValue[shotIndex] > 0 ?
                                 (scores.wrappedValue[shotIndex] == 10 ? "X" : "\(scores.wrappedValue[shotIndex])") : "-")
                                .font(.title3.bold())
                                .frame(width: 50, height: 50)
                                .background(scores.wrappedValue[shotIndex] > 0 ? contextColor.opacity(0.2) : AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let cardTotal = scores.wrappedValue.reduce(0, +)
            Text("Card Total: \(cardTotal)/50")
                .font(.subheadline)
                .foregroundStyle(cardTotal == 50 ? .green : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Final score with tetrathlon points
            VStack(spacing: 8) {
                Text("Final Score")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(totalRawScore)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.orange)
                Text("out of 100")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                // Tetrathlon points
                VStack(spacing: 2) {
                    Text("\(tetrathlonPoints)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("tetrathlon points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            // Card breakdown
            HStack(spacing: 40) {
                VStack {
                    Text("Card 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(card1Total)/50")
                        .font(.title2.bold())
                }
                VStack {
                    Text("Card 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(card2Total)/50")
                        .font(.title2.bold())
                }
            }

            Spacer()

            // Save button
            Button(action: { saveCompetitionSession() }) {
                Label("Save & Finish", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Plugin Access

    private var shootingPlugin: ShootingPlugin? {
        tracker?.plugin(as: ShootingPlugin.self)
    }

    private var watchShotMetrics: [DetectedShotMetrics] {
        WatchConnectivityManager.shared.receivedShotMetrics
    }

    // MARK: - Per-Shot Feedback Card

    private func lastShotFeedbackCard(_ shot: DetectedShotMetrics) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Shot \(shot.shotIndex)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let hr = shot.heartRateAtShot {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text("\(hr)")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            // Steadiness (hero metric)
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", shot.holdSteadiness))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(steadinessColor(shot.holdSteadiness))
                    Text("Steadiness")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Delta from previous shot
                if shot.shotIndex > 1, watchShotMetrics.count >= 2 {
                    let prev = watchShotMetrics[watchShotMetrics.count - 2]
                    let delta = shot.holdSteadiness - prev.holdSteadiness
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text(String(format: "%.0f", abs(delta)))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                        Text("vs prev")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Tremor
                VStack(spacing: 2) {
                    Text(shot.tremorIntensity < 30 ? "Low" : shot.tremorIntensity < 60 ? "Med" : "High")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(shot.tremorIntensity < 30 ? .green : shot.tremorIntensity < 60 ? .yellow : .red)
                    Text("Tremor")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Drift
                VStack(spacing: 2) {
                    Text(shot.driftMagnitude < 20 ? "Low" : shot.driftMagnitude < 50 ? "Med" : "High")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(shot.driftMagnitude < 20 ? .green : shot.driftMagnitude < 50 ? .yellow : .orange)
                    Text("Drift")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Phase timing bar
            phaseTimingBar(shot)
        }
        .padding()
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    private func phaseTimingBar(_ shot: DetectedShotMetrics) -> some View {
        let total = shot.raiseDuration + shot.settleDuration + shot.holdDuration
        guard total > 0 else { return AnyView(EmptyView()) }

        let raiseFraction = shot.raiseDuration / total
        let settleFraction = shot.settleDuration / total
        let holdFraction = shot.holdDuration / total

        return AnyView(
            VStack(spacing: 4) {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        phaseSegment(label: "Raise", fraction: raiseFraction, color: phaseQualityColor(shot.raiseDuration, ideal: 0.8...1.5), width: geo.size.width)
                        phaseSegment(label: "Settle", fraction: settleFraction, color: phaseQualityColor(shot.settleDuration, ideal: 0.3...1.0), width: geo.size.width)
                        phaseSegment(label: "Hold", fraction: holdFraction, color: phaseQualityColor(shot.holdDuration, ideal: 1.0...3.0), width: geo.size.width)
                    }
                }
                .frame(height: 20)

                HStack {
                    Text(String(format: "%.1fs raise", shot.raiseDuration))
                    Spacer()
                    Text(String(format: "%.1fs settle", shot.settleDuration))
                    Spacer()
                    Text(String(format: "%.1fs hold", shot.holdDuration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        )
    }

    private func phaseSegment(label: String, fraction: Double, color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: max(4, width * fraction))
    }

    private func phaseQualityColor(_ duration: Double, ideal: ClosedRange<Double>) -> Color {
        if ideal.contains(duration) { return .green }
        if duration < ideal.lowerBound * 0.5 || duration > ideal.upperBound * 1.5 { return .red }
        return .orange
    }

    private func steadinessColor(_ value: Double) -> Color {
        if value > 80 { return .green }
        if value > 60 { return .cyan }
        if value > 40 { return .orange }
        return .red
    }

    // MARK: - Session Shot Summary

    private var sessionShotSummaryCard: some View {
        let metrics = watchShotMetrics
        let recentCount = min(metrics.count, 10)
        let recentMetrics = Array(metrics.suffix(recentCount))
        let avgSteadiness = recentMetrics.map(\.holdSteadiness).reduce(0, +) / Double(recentCount)

        // Fatigue trend: compare first half vs second half steadiness
        let midpoint = metrics.count / 2
        let firstHalfAvg = metrics.prefix(max(1, midpoint)).map(\.holdSteadiness).reduce(0, +) / Double(max(1, midpoint))
        let secondHalfAvg = metrics.suffix(max(1, metrics.count - midpoint)).map(\.holdSteadiness).reduce(0, +) / Double(max(1, metrics.count - midpoint))
        let fatigueDelta = secondHalfAvg - firstHalfAvg

        return VStack(spacing: 8) {
            HStack {
                Text("Session Summary")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(metrics.count) shots detected")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 20) {
                // Average steadiness
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", avgSteadiness))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(steadinessColor(avgSteadiness))
                    Text("Avg Steady")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Fatigue trend
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: fatigueDelta > 2 ? "arrow.up" : fatigueDelta < -2 ? "arrow.down" : "arrow.right")
                            .font(.caption)
                        Text(fatigueDelta > 2 ? "Improving" : fatigueDelta < -2 ? "Degrading" : "Stable")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(fatigueDelta > 2 ? .green : fatigueDelta < -2 ? .orange : .primary)
                    Text("Form Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Avg hold time
                let avgHold = recentMetrics.map(\.holdDuration).reduce(0, +) / Double(recentCount)
                VStack(spacing: 2) {
                    Text(String(format: "%.1fs", avgHold))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("Avg Hold")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Mini steadiness bar chart (last 5-10 shots)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(recentMetrics) { shot in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(steadinessColor(shot.holdSteadiness))
                        .frame(width: max(6, CGFloat(200 / recentCount)), height: max(4, CGFloat(shot.holdSteadiness) * 0.4))
                }
            }
            .frame(height: 40)
        }
        .padding()
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    private func saveCompetitionSession() {
        // Save scores via plugin (creates ends/shots, wires Watch data, runs GRACE analysis)
        shootingPlugin?.saveScores(
            card1Scores: card1Scores,
            card2Scores: card2Scores,
            card1ScanID: card1ScanAnalysisID,
            card2ScanID: card2ScanAnalysisID
        )

        // Stop session (triggers HealthKit enrichment, workout save, widget sync, artifact conversion)
        tracker?.stopSession()

        // Standalone mode (competition day): bridge score back via callbacks
        if isStandalone {
            onComplete?(totalRawScore)
            onEnd?(totalRawScore)
        }
    }
}

// MARK: - Free Practice View

// Helper class to hold image state that survives view rebuilds
@Observable
private class FreePracticeImageHolder {
    var rawImage: UIImage?
    var croppedImage: UIImage?
}

// MARK: - Card Scan Flow View

struct CardScanFlowView: View {
    let cardNumber: Int
    let sessionContext: ShootingSessionContext
    let onComplete: ([Int], UUID) -> Void
    let onCancel: () -> Void

    enum ScanStep {
        case pickImage
        case cropping
        case marking
    }

    @State private var step: ScanStep = .pickImage
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var croppedImage: UIImage?
    @State private var isLoadingImage = false

    var body: some View {
        ZStack {
            switch step {
            case .pickImage:
                pickImageView

            case .cropping:
                if let image = capturedImage {
                    ManualCropView(
                        image: image,
                        onCropped: { cropped in
                            croppedImage = cropped
                            step = .marking
                        },
                        onCancel: {
                            capturedImage = nil
                            selectedPhotoItem = nil
                            step = .pickImage
                        }
                    )
                }

            case .marking:
                if let image = croppedImage {
                    TargetMarkingView(
                        image: image,
                        onComplete: {
                            // Fallback if pattern creation fails
                            croppedImage = nil
                            step = .pickImage
                        },
                        onCancel: {
                            croppedImage = nil
                            step = .pickImage
                        },
                        sessionType: sessionContext.patternSessionType,
                        onCompleteWithScores: { scores, id in
                            onComplete(scores, id)
                        }
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPreviewView(onCapture: { image in
                capturedImage = image
                showingCamera = false
                step = .cropping
            })
        }
    }

    private var pickImageView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(contextColor)

                    Text("Scan Card \(cardNumber)")
                        .font(.title2.bold())

                    Text("Take a photo of your target to auto-calculate scores from hole positions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                Spacer()

                // Camera / Photo options
                VStack(spacing: 16) {
                    Button {
                        showingCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                            Text("Take Photo")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(contextColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Choose from Library")
                        }
                        .font(.headline)
                        .foregroundStyle(contextColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(contextColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                isLoadingImage = true
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            capturedImage = image
                            isLoadingImage = false
                            step = .cropping
                        }
                    } else {
                        await MainActor.run {
                            isLoadingImage = false
                        }
                    }
                }
            }
            .overlay {
                if isLoadingImage {
                    ProgressView("Loading...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var contextColor: Color {
        switch sessionContext.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }
}

struct FreePracticeView: View {
    var sessionContext: ShootingSessionContext = .freePractice
    let onEnd: () -> Void
    var onAnalysisComplete: (() -> Void)? = nil  // Called when analysis is saved
    var onNavigateToHistory: ((DateFilterOption) -> Void)? = nil  // Navigate to history with pre-selected filter

    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageHolder = FreePracticeImageHolder()
    @State private var showingCropView = false
    @State private var showingAnalysis = false
    @State private var isLoadingImage = false

    private var contextColor: Color {
        switch sessionContext.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return AVCaptureDevice.default(for: .video) != nil
        #endif
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header with context badge
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: sessionContext.icon)
                            .font(.title3)
                        Text(sessionContext.displayName)
                            .font(.title2.bold())
                    }
                    .foregroundStyle(contextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(contextColor.opacity(0.15))
                    .clipShape(Capsule())
                    Spacer()
                    Button(action: onEnd) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(AppColors.cardBackground)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                if WatchConnectivityManager.shared.isPaired {
                    ShootingWatchStatusCard()
                        .padding(.horizontal)
                }

                Spacer()

                // Icon
                Image(systemName: "target")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue.opacity(0.6))

                // Instructions
                VStack(spacing: 8) {
                    Text("Analyse Your Target")
                        .font(.title3.bold())
                    Text("Mark holes and center to see grouping analysis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Primary actions
                VStack(spacing: 16) {
                    // Take Photo button (primary when camera available)
                    if isCameraAvailable {
                        Button {
                            showingCamera = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Take Photo of Target")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Select from Photos button - use PhotosPicker directly
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text("Select Target Photo")
                                .font(.headline)
                        }
                        .foregroundStyle(isCameraAvailable ? .blue : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isCameraAvailable ? Color.blue.opacity(0.1) : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isCameraAvailable ? Color.blue.opacity(0.3) : .clear, lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 24)

                #if targetEnvironment(simulator)
                // Simulator hint
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Camera unavailable in Simulator")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                #endif

                Spacer()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            isLoadingImage = true

            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            isLoadingImage = false
                            imageHolder.rawImage = image
                            showingCropView = true
                        }
                    } else {
                        await MainActor.run { isLoadingImage = false }
                    }
                } catch {
                    await MainActor.run { isLoadingImage = false }
                }
            }
        }
        .overlay {
            if isLoadingImage {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Loading image...")
                            .foregroundStyle(.white)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraOnlyView(onCapture: { image in
                showingCamera = false
                imageHolder.rawImage = image
                showingCropView = true
            }, onCancel: {
                showingCamera = false
            })
        }
        .fullScreenCover(isPresented: $showingCropView) {
            if let image = imageHolder.rawImage {
                ManualCropView(
                    image: image,
                    onCropped: { croppedResult in
                        imageHolder.croppedImage = croppedResult
                        showingCropView = false
                        // Delay presentation to allow dismiss animation to complete
                        Task {
                            try? await Task.sleep(for: .seconds(0.5))
                            showingAnalysis = true
                        }
                    },
                    onCancel: {
                        showingCropView = false
                        imageHolder.rawImage = nil
                        selectedPhotoItem = nil
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingAnalysis) {
            #if DEBUG
            let _ = print("[FreePractice] fullScreenCover body - croppedImage is \(imageHolder.croppedImage == nil ? "nil" : "valid")")
            #endif
            if let image = imageHolder.croppedImage {
                #if DEBUG
                let _ = print("[FreePractice] Rendering TargetMarkingView")
                #endif
                TargetMarkingView(
                    image: image,
                    onComplete: {
                        showingAnalysis = false
                        imageHolder.croppedImage = nil
                        imageHolder.rawImage = nil
                        selectedPhotoItem = nil
                        // Navigate to history with "Last Target" filter, or fallback to legacy callback
                        if let navigateToHistory = onNavigateToHistory {
                            navigateToHistory(.lastTarget)
                        } else {
                            onAnalysisComplete?()
                        }
                    },
                    onCancel: {
                        showingAnalysis = false
                        imageHolder.croppedImage = nil
                        imageHolder.rawImage = nil
                        selectedPhotoItem = nil
                    }
                )
            }
        }
    }
}

// MARK: - Camera Only View (moved from ImageSourceSelectorView)

struct CameraOnlyView: View {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            CameraPreviewView(onCapture: onCapture, onAlignmentUpdate: nil)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppColors.cardBackground)
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()
            }
        }
    }
}

// MARK: - Scanned Target Model

struct ScannedTarget: Identifiable {
    let id = UUID()
    let scores: [Int]
    let timestamp: Date
    var holePositions: [CGPoint] = [] // Relative positions for pattern analysis

    var totalScore: Int { scores.reduce(0, +) }
    var shotCount: Int { scores.count }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // Pattern analysis
    var groupingSize: Double {
        guard holePositions.count >= 2 else { return 0 }
        var maxDistance: Double = 0
        for i in 0..<holePositions.count {
            for j in (i+1)..<holePositions.count {
                let dx = holePositions[i].x - holePositions[j].x
                let dy = holePositions[i].y - holePositions[j].y
                let distance = sqrt(dx*dx + dy*dy)
                maxDistance = max(maxDistance, distance)
            }
        }
        return maxDistance
    }

    var groupingDescription: String {
        let size = groupingSize
        if size < 0.1 { return "Excellent grouping" }
        if size < 0.2 { return "Good grouping" }
        if size < 0.3 { return "Fair grouping" }
        return "Spread pattern"
    }

    var patternBias: String {
        guard !holePositions.isEmpty else { return "No data" }
        let avgX = holePositions.map { $0.x }.reduce(0, +) / Double(holePositions.count)
        let avgY = holePositions.map { $0.y }.reduce(0, +) / Double(holePositions.count)

        var bias: [String] = []
        if avgX < 0.4 { bias.append("Left") }
        else if avgX > 0.6 { bias.append("Right") }
        if avgY < 0.4 { bias.append("High") }
        else if avgY > 0.6 { bias.append("Low") }

        return bias.isEmpty ? "Centered" : bias.joined(separator: "-")
    }
}

// MARK: - Scanned Target Row

struct ScannedTargetRow: View {
    let target: ScannedTarget

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(target.shotCount) shots")
                    .font(.headline)
                Text(target.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score badges
            HStack(spacing: 4) {
                ForEach(target.scores.prefix(5), id: \.self) { score in
                    Text(score == 10 ? "X" : "\(score)")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(scoreColor(score))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                if target.scores.count > 5 {
                    Text("+\(target.scores.count - 5)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(target.totalScore)")
                .font(.title3.bold())
                .foregroundStyle(.blue)
                .frame(width: 40, alignment: .trailing)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 9: return .orange
        case 8: return .red
        case 7: return .blue
        default: return .gray
        }
    }
}

// MARK: - Target Analysis View

struct TargetAnalysisView: View {
    let target: ScannedTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score summary
                    VStack(spacing: 8) {
                        Text("\(target.totalScore)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("\(target.shotCount) shots")
                            .foregroundStyle(.secondary)
                    }

                    // Score breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Score Breakdown")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(Array(target.scores.enumerated()), id: \.offset) { index, score in
                                VStack {
                                    Text(score == 10 ? "X" : "\(score)")
                                        .font(.title3.bold())
                                        .frame(width: 44, height: 44)
                                        .background(scoreColor(score))
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                    Text("#\(index + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Pattern analysis
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pattern Analysis")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Grouping")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(target.groupingDescription)
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Bias")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(target.patternBias)
                                    .font(.subheadline.bold())
                            }
                        }

                        // Score distribution
                        HStack(spacing: 4) {
                            ForEach(1...10, id: \.self) { score in
                                let count = target.scores.filter { $0 == score }.count
                                VStack {
                                    Spacer()
                                    if count > 0 {
                                        Rectangle()
                                            .fill(scoreColor(score))
                                            .frame(height: CGFloat(count) * 20)
                                    }
                                    Text(score == 10 ? "X" : "\(score)")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 80)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Tips based on pattern
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tips", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)

                        Text(generateTip())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Target Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 9: return .orange
        case 8: return .red
        case 7: return .blue
        default: return .gray
        }
    }

    private func generateTip() -> String {
        let avgScore = Double(target.totalScore) / Double(target.shotCount)

        if avgScore >= 9.5 {
            return "Excellent shooting! Focus on consistency and mental preparation."
        } else if avgScore >= 8.5 {
            return "Great scores! Work on breathing control to tighten your grouping."
        } else if avgScore >= 7.5 {
            return "Good progress! Check your stance and grip for more stability."
        } else {
            return "Focus on the fundamentals: stance, grip, sight alignment, and trigger control."
        }
    }
}
