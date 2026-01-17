//
//  TargetMarkingView.swift
//  TrackRide
//
//  Precision target marking with unified hole mode and accurate tap placement.
//

import SwiftUI
import UIKit
import CoreImage
import PhotosUI

// MARK: - Interaction Mode (Simplified)

enum MarkingMode: String, CaseIterable {
    case holes = "Holes"
    case center = "Center"

    var icon: String {
        switch self {
        case .holes: return "circle"
        case .center: return "plus.circle"
        }
    }

    var hint: String {
        switch self {
        case .holes: return "Tap to add, tap hole to select, long-press to drag"
        case .center: return "Tap to set target center"
        }
    }
}

// MARK: - Coordinate Models (Image Pixel Space)

/// A point in image pixel coordinates
struct ImagePoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }

    /// Convert to normalized coordinates relative to target center
    func normalized(center: ImagePoint, radius: CGFloat) -> CGPoint {
        let dx = (x - center.x) / radius
        let dy = (y - center.y) / radius
        return CGPoint(x: dx, y: dy)
    }

    /// Convert to polar coordinates relative to target center
    func polar(center: ImagePoint) -> (distance: CGFloat, angle: CGFloat) {
        let dx = x - center.x
        let dy = y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let angle = atan2(dy, dx)
        return (distance, angle)
    }
}

/// A marked hole in image pixel coordinates
struct MarkedHole: Identifiable, Equatable {
    let id: UUID
    var position: ImagePoint

    init(id: UUID = UUID(), position: ImagePoint) {
        self.id = id
        self.position = position
    }
}

// MARK: - Undo Action

enum UndoAction {
    case addHole(UUID)
    case deleteHole(MarkedHole)
    case moveHole(UUID, from: ImagePoint)
    case setCenter(ImagePoint?)
}

// MARK: - Target Marking View

struct TargetMarkingView: View {
    let image: UIImage
    let onComplete: () -> Void
    let onCancel: () -> Void

    // Marking state
    @State private var holes: [MarkedHole] = []
    @State private var targetCenter: ImagePoint?
    @State private var selectedHoleID: UUID?

    // Interaction mode
    @State private var mode: MarkingMode = .holes

    // Undo stack (single action)
    @State private var lastAction: UndoAction?

    // Zoom and pan
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Dragging state
    @State private var isDraggingHole: Bool = false
    @State private var dragStartPosition: ImagePoint?
    @State private var longPressActive: Bool = false

    // Image dimensions
    @State private var imageSize: CGSize = .zero

    // Submission state
    @State private var showingAnalysis: Bool = false

    // Haptic feedback
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    // Validation
    private var canSubmit: Bool {
        !holes.isEmpty && targetCenter != nil
    }

    private var validationMessages: [String] {
        var messages: [String] = []
        if holes.isEmpty {
            messages.append("Mark at least one hole")
        }
        if targetCenter == nil {
            messages.append("Mark target center")
        }
        return messages
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with safe area
                headerView
                    .padding(.top, geometry.safeAreaInsets.top)
                    .background(Color(.systemBackground))
                    .zIndex(10)

                // Mode selector (simplified to 2 modes)
                modeSelector
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .zIndex(10)

                // Main canvas
                markingCanvas(geometry: geometry)
                    .frame(maxHeight: .infinity)
                    .zIndex(1)

                // Bottom controls
                bottomControls
                    .zIndex(10)
            }
            .background(Color(.systemBackground))
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            imageSize = image.size
        }
        .fullScreenCover(isPresented: $showingAnalysis) {
            if let center = targetCenter {
                TargetAnalysisResultView(
                    image: image,
                    holes: holes,
                    center: center,
                    onDone: {
                        showingAnalysis = false
                        onComplete()
                    },
                    onEdit: {
                        showingAnalysis = false
                    }
                )
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .font(.subheadline)

            Spacer()

            Text("Mark Target")
                .font(.headline)

            Spacer()

            // Undo button
            Button {
                performUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.subheadline.weight(.medium))
            }
            .disabled(lastAction == nil)
            .opacity(lastAction == nil ? 0.3 : 1.0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Mode Selector (Simplified)

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(MarkingMode.allCases, id: \.self) { modeOption in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = modeOption
                        if modeOption == .center {
                            selectedHoleID = nil
                        }
                    }
                    impactLight.impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: modeOption.icon)
                            .font(.body.weight(.medium))
                        Text(modeOption.rawValue)
                            .font(.body.weight(.medium))
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(mode == modeOption ? Color.blue : Color.clear)
                    .foregroundStyle(mode == modeOption ? .white : .primary)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Marking Canvas

    private func markingCanvas(geometry: GeometryProxy) -> some View {
        GeometryReader { canvasGeo in
            let canvasSize = canvasGeo.size
            let imageFrame = calculateImageFrame(canvasSize: canvasSize)

            ZStack {
                // Background
                Color.black.opacity(0.05)

                // Image container with zoom/pan
                ZStack {
                    // The target image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // Hole markers (positioned in image-relative coordinates)
                    // Size markers relative to image display size for consistent appearance
                    let markerScale = imageFrame.width / max(imageSize.width, 1)
                    ForEach(holes) { hole in
                        let viewPos = imageToViewLocal(hole.position.cgPoint, imageFrame: imageFrame)
                        TargetHoleMarker(
                            isSelected: selectedHoleID == hole.id,
                            isDragging: isDraggingHole && selectedHoleID == hole.id,
                            displayScale: markerScale
                        )
                        .position(viewPos)
                    }

                    // Center marker
                    if let center = targetCenter {
                        let viewPos = imageToViewLocal(center.cgPoint, imageFrame: imageFrame)
                        CenterMarkerShape()
                            .position(viewPos)
                    }
                }
                .frame(width: imageFrame.width, height: imageFrame.height)
                .scaleEffect(scale)
                .offset(offset)
                .position(x: canvasSize.width / 2, y: canvasSize.height / 2)

                // Gesture overlay (captures all touch interactions within canvas only)
                Color.clear
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .contentShape(Rectangle())
                    .gesture(
                        // Single unified drag gesture that handles taps, drags, and pans
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let translation = value.translation
                                let distance = sqrt(translation.width * translation.width + translation.height * translation.height)

                                // Check if we should start dragging a selected hole
                                if !isDraggingHole && mode == .holes && selectedHoleID != nil && distance > 5 {
                                    // Check if drag started near the selected hole
                                    if let hole = holes.first(where: { $0.id == selectedHoleID }) {
                                        let holeScreen = imageToScreen(hole.position.cgPoint, canvasSize: canvasSize, imageFrame: imageFrame)
                                        let startDist = sqrt(pow(value.startLocation.x - holeScreen.x, 2) + pow(value.startLocation.y - holeScreen.y, 2))
                                        if startDist < 50 {
                                            // Start dragging this hole
                                            isDraggingHole = true
                                            dragStartPosition = hole.position
                                            impactMedium.impactOccurred()
                                        }
                                    }
                                }

                                // If dragging a selected hole
                                if isDraggingHole, mode == .holes, selectedHoleID != nil {
                                    handleHoleDrag(drag: value, canvasSize: canvasSize, imageFrame: imageFrame)
                                }
                                // If zoomed and dragging to pan (not dragging a hole)
                                else if scale > 1.0 && distance > 10 && !isDraggingHole {
                                    offset = CGSize(
                                        width: lastOffset.width + translation.width,
                                        height: lastOffset.height + translation.height
                                    )
                                }
                            }
                            .onEnded { value in
                                let translation = value.translation
                                let distance = sqrt(translation.width * translation.width + translation.height * translation.height)

                                if isDraggingHole {
                                    // Finalize hole drag
                                    finalizeDrag()
                                } else if distance < 10 {
                                    // This was a tap (minimal movement)
                                    handleTap(at: value.location, canvasSize: canvasSize, imageFrame: imageFrame)
                                } else if scale > 1.0 {
                                    // Finalize pan
                                    lastOffset = offset
                                }
                            }
                    )
                    .simultaneousGesture(
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

                // Zoom indicator
                if scale > 1.0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
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

                // Mode hint overlay
                VStack {
                    HStack {
                        modeHintLabel
                            .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .clipped()
        }
    }

    private var modeHintLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: mode.icon)
            Text(mode.hint)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Status indicators
            HStack(spacing: 16) {
                // Holes count
                HStack(spacing: 6) {
                    Image(systemName: "circle")
                        .foregroundStyle(holes.isEmpty ? Color.secondary : Color.blue)
                    Text("\(holes.count) hole\(holes.count == 1 ? "" : "s")")
                        .font(.subheadline)
                }

                Spacer()

                // Center status
                HStack(spacing: 6) {
                    Image(systemName: targetCenter != nil ? "checkmark.circle.fill" : "plus.circle")
                        .foregroundStyle(targetCenter != nil ? Color.green : Color.secondary)
                    Text(targetCenter != nil ? "Center marked" : "No center")
                        .font(.subheadline)
                }

                Spacer()

                // Delete selected hole button
                if selectedHoleID != nil {
                    Button {
                        if let id = selectedHoleID {
                            deleteHole(id: id)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                // Clear all
                if !holes.isEmpty || targetCenter != nil {
                    Button {
                        clearAll()
                    } label: {
                        Image(systemName: "trash.slash")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal)

            // Validation messages
            if !canSubmit {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.orange)
                    Text(validationMessages.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            // Submit button
            Button {
                if canSubmit {
                    showingAnalysis = true
                }
            } label: {
                HStack {
                    Image(systemName: canSubmit ? "checkmark.circle.fill" : "exclamationmark.circle")
                    Text("Submit for Analysis")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSubmit ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!canSubmit)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Coordinate Conversion

    /// Calculate the image frame within the canvas
    private func calculateImageFrame(canvasSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: canvasSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let canvasAspect = canvasSize.width / canvasSize.height

        let scaledWidth: CGFloat
        let scaledHeight: CGFloat

        if imageAspect > canvasAspect {
            // Image is wider - fit to width
            scaledWidth = canvasSize.width
            scaledHeight = canvasSize.width / imageAspect
        } else {
            // Image is taller - fit to height
            scaledHeight = canvasSize.height
            scaledWidth = canvasSize.height * imageAspect
        }

        return CGRect(
            x: 0,
            y: 0,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    /// Convert image pixel coordinates to local view coordinates (within image frame, before zoom/pan)
    private func imageToViewLocal(_ point: CGPoint, imageFrame: CGRect) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return point
        }

        let scaleX = imageFrame.width / imageSize.width
        let scaleY = imageFrame.height / imageSize.height

        return CGPoint(
            x: point.x * scaleX,
            y: point.y * scaleY
        )
    }

    /// Convert screen tap coordinates to image pixel coordinates
    private func screenToImage(_ screenPoint: CGPoint, canvasSize: CGSize, imageFrame: CGRect) -> CGPoint? {
        // The image is centered in the canvas, scaled by `scale`, and offset by `offset`
        let canvasCenterX = canvasSize.width / 2
        let canvasCenterY = canvasSize.height / 2

        // Image center in screen coordinates (after zoom/pan)
        let imageCenterScreenX = canvasCenterX + offset.width
        let imageCenterScreenY = canvasCenterY + offset.height

        // Convert screen tap to position relative to image center
        let relativeX = (screenPoint.x - imageCenterScreenX) / scale
        let relativeY = (screenPoint.y - imageCenterScreenY) / scale

        // Convert to image frame coordinates (image frame is centered at origin in its own space)
        let imageFrameX = relativeX + imageFrame.width / 2
        let imageFrameY = relativeY + imageFrame.height / 2

        // Convert image frame coordinates to image pixel coordinates
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let scaleX = imageSize.width / imageFrame.width
        let scaleY = imageSize.height / imageFrame.height

        let imageX = imageFrameX * scaleX
        let imageY = imageFrameY * scaleY

        // Validate within bounds
        guard imageX >= 0, imageX <= imageSize.width,
              imageY >= 0, imageY <= imageSize.height else {
            return nil
        }

        return CGPoint(x: imageX, y: imageY)
    }

    /// Convert image coordinates to screen coordinates (for hit testing)
    private func imageToScreen(_ imagePoint: CGPoint, canvasSize: CGSize, imageFrame: CGRect) -> CGPoint {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return imagePoint
        }

        // Convert to image frame coordinates
        let scaleX = imageFrame.width / imageSize.width
        let scaleY = imageFrame.height / imageSize.height

        let frameX = imagePoint.x * scaleX
        let frameY = imagePoint.y * scaleY

        // Convert to relative position from image center
        let relativeX = frameX - imageFrame.width / 2
        let relativeY = frameY - imageFrame.height / 2

        // Apply zoom and pan to get screen coordinates
        let canvasCenterX = canvasSize.width / 2
        let canvasCenterY = canvasSize.height / 2

        let screenX = canvasCenterX + offset.width + relativeX * scale
        let screenY = canvasCenterY + offset.height + relativeY * scale

        return CGPoint(x: screenX, y: screenY)
    }

    // MARK: - Gesture Handling

    private func handleTap(at location: CGPoint, canvasSize: CGSize, imageFrame: CGRect) {
        switch mode {
        case .holes:
            // First check if tapping on existing hole (for selection)
            if let tappedHole = findHoleNear(screenPoint: location, canvasSize: canvasSize, imageFrame: imageFrame) {
                // Toggle selection
                if selectedHoleID == tappedHole.id {
                    selectedHoleID = nil
                } else {
                    selectedHoleID = tappedHole.id
                }
                impactLight.impactOccurred()
            } else {
                // Add new hole at tap location
                if let imagePoint = screenToImage(location, canvasSize: canvasSize, imageFrame: imageFrame) {
                    addHole(at: ImagePoint(imagePoint))
                    selectedHoleID = nil
                }
            }

        case .center:
            if let imagePoint = screenToImage(location, canvasSize: canvasSize, imageFrame: imageFrame) {
                setCenter(at: ImagePoint(imagePoint))
            }
        }
    }

    private func handleHoleDrag(drag: DragGesture.Value, canvasSize: CGSize, imageFrame: CGRect) {
        guard let holeID = selectedHoleID else { return }

        if !isDraggingHole {
            // Start drag
            if let hole = holes.first(where: { $0.id == holeID }) {
                isDraggingHole = true
                dragStartPosition = hole.position
                impactMedium.impactOccurred()
            }
        }

        // Update hole position
        if let imagePoint = screenToImage(drag.location, canvasSize: canvasSize, imageFrame: imageFrame) {
            if let index = holes.firstIndex(where: { $0.id == holeID }) {
                holes[index].position = ImagePoint(imagePoint)
            }
        }
    }

    private func finalizeDrag() {
        if let holeID = selectedHoleID, let startPos = dragStartPosition {
            lastAction = .moveHole(holeID, from: startPos)
        }
        isDraggingHole = false
        dragStartPosition = nil
        impactLight.impactOccurred()
    }

    private func findHoleNear(screenPoint: CGPoint, canvasSize: CGSize, imageFrame: CGRect) -> MarkedHole? {
        // Hit test radius in screen points (minimum 44pt for accessibility, scales with zoom)
        let hitRadius: CGFloat = max(44, 30 * scale)

        for hole in holes {
            let holeScreenPos = imageToScreen(hole.position.cgPoint, canvasSize: canvasSize, imageFrame: imageFrame)
            let dx = screenPoint.x - holeScreenPos.x
            let dy = screenPoint.y - holeScreenPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < hitRadius {
                return hole
            }
        }
        return nil
    }

    // MARK: - Actions

    private func addHole(at position: ImagePoint) {
        let hole = MarkedHole(position: position)
        holes.append(hole)
        lastAction = .addHole(hole.id)
        impactMedium.impactOccurred()
    }

    private func setCenter(at position: ImagePoint) {
        let oldCenter = targetCenter
        targetCenter = position
        lastAction = .setCenter(oldCenter)
        impactMedium.impactOccurred()
        notificationFeedback.notificationOccurred(.success)
    }

    private func deleteHole(id: UUID) {
        guard let hole = holes.first(where: { $0.id == id }) else { return }

        holes.removeAll { $0.id == id }
        lastAction = .deleteHole(hole)
        if selectedHoleID == id {
            selectedHoleID = nil
        }
        impactMedium.impactOccurred()
    }

    private func clearAll() {
        holes.removeAll()
        targetCenter = nil
        selectedHoleID = nil
        lastAction = nil
        notificationFeedback.notificationOccurred(.warning)
    }

    private func performUndo() {
        guard let action = lastAction else { return }

        switch action {
        case .addHole(let id):
            holes.removeAll { $0.id == id }

        case .deleteHole(let hole):
            holes.append(hole)

        case .moveHole(let id, let from):
            if let index = holes.firstIndex(where: { $0.id == id }) {
                holes[index].position = from
            }

        case .setCenter(let oldCenter):
            targetCenter = oldCenter
        }

        lastAction = nil
        impactLight.impactOccurred()
    }

}

// MARK: - Target Hole Marker View (Redesigned)

struct TargetHoleMarker: View {
    let isSelected: Bool
    let isDragging: Bool
    /// Scale factor: imageFrame.width / imageSize.width
    /// Used to size markers proportionally to the displayed image
    var displayScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Small centered dot marker
            Circle()
                .fill(isSelected ? Color.orange : Color.red)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 0)

            // Selection ring (only when selected) - proportionally small
            if isSelected {
                Circle()
                    .stroke(Color.orange, lineWidth: 1.5)
                    .frame(width: selectionRingSize, height: selectionRingSize)
            }
        }
        .scaleEffect(isDragging ? 1.3 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    /// Small dot size - about 10-12 pixels in image space, much smaller than the hole
    private var dotSize: CGFloat {
        let baseSize: CGFloat = 12
        let scaledSize = baseSize * displayScale
        return max(scaledSize, 6) // Minimum 6pt for visibility
    }

    /// Selection ring - slightly larger than the dot
    private var selectionRingSize: CGFloat {
        dotSize + 8
    }
}

// MARK: - Center Marker Shape

struct CenterMarkerShape: View {
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.5), radius: 1)

            // Inner ring
            Circle()
                .stroke(Color.green, lineWidth: 2)
                .frame(width: 30, height: 30)

            // Crosshair - horizontal
            Rectangle()
                .fill(Color.green)
                .frame(width: 24, height: 2)
                .shadow(color: .black.opacity(0.3), radius: 1)

            // Crosshair - vertical
            Rectangle()
                .fill(Color.green)
                .frame(width: 2, height: 24)
                .shadow(color: .black.opacity(0.3), radius: 1)

            // Center dot
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: .black.opacity(0.3), radius: 1)
        }
    }
}

// MARK: - Analysis Result View

struct TargetAnalysisResultView: View {
    let image: UIImage
    let holes: [MarkedHole]
    let center: ImagePoint
    let onDone: () -> Void
    let onEdit: () -> Void

    @State private var analysis: ShotPatternAnalysis?
    @State private var historyManager = ShotPatternHistoryManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Target thumbnail
                    targetThumbnail
                        .padding(.horizontal)

                    // Shot count summary
                    shotCountSummary
                        .padding(.horizontal)

                    // Analysis content
                    if let analysis = analysis {
                        if let suppression = analysis.suppressionReason {
                            // Suppression message (insufficient data)
                            suppressionCard(message: suppression)
                                .padding(.horizontal)
                        } else if let current = analysis.currentTarget {
                            // Visualization section
                            if let visualData = analysis.visualData {
                                visualizationSection(visualData: visualData)
                                    .padding(.horizontal)
                            }

                            // Current target insights
                            insightsSection(result: current, title: "This Target")
                                .padding(.horizontal)

                            // Aggregate history (if available)
                            if let aggregate = analysis.aggregateHistory {
                                insightsSection(result: aggregate, title: "Practice Trend")
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        // Loading state
                        ProgressView("Analyzing pattern...")
                            .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Practice Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { onEdit() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveToHistory()
                        onDone()
                    }
                }
            }
            .onAppear {
                performAnalysis()
            }
        }
    }

    // MARK: - Target Thumbnail

    private var targetThumbnail: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Shot Count Summary

    private var shotCountSummary: some View {
        HStack(spacing: 24) {
            VStack {
                Text("\(holes.count)")
                    .font(.title2.bold())
                Text("Shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let analysis = analysis?.currentTarget {
                Divider()
                    .frame(height: 30)

                VStack {
                    Text(analysis.patternLabel.tightness.description.capitalized)
                        .font(.title2.bold())
                        .foregroundStyle(tightnessColor(analysis.patternLabel.tightness))
                    Text("Grouping")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 30)

                VStack {
                    Text(analysis.patternLabel.bias.description.capitalized)
                        .font(.title2.bold())
                        .foregroundStyle(analysis.patternLabel.bias == .centered ? .green : .orange)
                    Text("Position")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Visualization Section

    private func visualizationSection(visualData: VisualPatternData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shot Pattern")
                .font(.headline)

            ShotPatternVisualizationView(
                visualData: visualData,
                showAggregate: !historyManager.history.isEmpty
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Suppression Card

    private func suppressionCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title2)
                .foregroundStyle(.blue)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Insights Section

    private func insightsSection(result: PatternAnalysisResult, title: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                confidenceBadge(result.confidence)
            }

            // 1. Observation
            VStack(alignment: .leading, spacing: 6) {
                Label("Observation", systemImage: "eye")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(result.observationText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 2. Practice Focus
            VStack(alignment: .leading, spacing: 6) {
                Label("Practice Focus", systemImage: "target")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Text(result.practiceFocusText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 3. Suggested Drills
            VStack(alignment: .leading, spacing: 8) {
                Label("Try These Drills", systemImage: "list.bullet.clipboard")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                ForEach(result.suggestedDrills, id: \.self) { drill in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.blue)
                            .padding(.top, 6)
                        Text(drill)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Confidence Badge

    private func confidenceBadge(_ confidence: AnalysisConfidence) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(confidenceFillColor(confidence, index: index))
                    .frame(width: 6, height: 6)
            }
            Text(confidence.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func confidenceFillColor(_ confidence: AnalysisConfidence, index: Int) -> Color {
        switch confidence {
        case .low:
            return index == 0 ? .orange : Color(.tertiaryLabel)
        case .medium:
            return index < 2 ? .yellow : Color(.tertiaryLabel)
        case .high:
            return .green
        }
    }

    private func tightnessColor(_ tightness: GroupTightness) -> Color {
        switch tightness {
        case .tight: return .green
        case .moderate: return .blue
        case .wide: return .orange
        }
    }

    // MARK: - Analysis

    private func performAnalysis() {
        let shots = holes.map { $0.position.cgPoint }
        let centerPoint = center.cgPoint

        analysis = ShotPatternAnalyzer.analyze(
            shots: shots,
            centerPoint: centerPoint,
            imageWidth: image.size.width,
            imageHeight: image.size.height,
            history: historyManager.getRecentHistory()
        )
    }

    private func saveToHistory() {
        let shots = holes.map { $0.position.cgPoint }
        let centerPoint = center.cgPoint

        if let pattern = ShotPatternAnalyzer.createStoredPattern(
            shots: shots,
            centerPoint: centerPoint,
            imageWidth: image.size.width,
            imageHeight: image.size.height
        ) {
            historyManager.addPattern(pattern)
        }
    }
}

// MARK: - Preview

#Preview {
    TargetMarkingView(
        image: UIImage(systemName: "circle.fill")!,
        onComplete: { },
        onCancel: { }
    )
}
