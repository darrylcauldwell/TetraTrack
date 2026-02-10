//
//  CenterConfirmationView.swift
//  TetraTrack
//
//  User interface for confirming and adjusting target center alignment.
//
//  **DEPRECATED**: This view is no longer used in the scanning workflow.
//  With perspective-corrected crops, the target center is automatically
//  calculated as the geometric center (0.5, 0.5). The EnhancedTargetScanner
//  now skips the center confirmation phase entirely.
//
//  This file is kept for backward compatibility but may be removed in a
//  future release.
//

import SwiftUI

// MARK: - Center Confirmation View (Deprecated)

/// View for confirming target center alignment before hole detection.
///
/// **Deprecated**: With auto-center calculation, manual center confirmation is no longer
/// needed. The center is automatically calculated as (0.5, 0.5) in the perspective-corrected
/// crop. The scanning workflow now skips this phase entirely.
///
/// This view is retained for backward compatibility but is no longer used.
@available(*, deprecated, message: "Center is now auto-calculated. This view is no longer used in the scanning workflow.")
struct CenterConfirmationView: View {
    let image: UIImage
    let initialGeometry: TargetCropGeometry
    let targetType: ShootingTargetGeometryType
    let onConfirm: (TargetAlignment) -> Void
    let onCancel: () -> Void

    @State private var centerPosition: CGPoint
    @State private var semiAxes: CGSize
    @State private var rotation: Double
    @State private var showGuides: Bool = true
    @State private var isAdjusting: Bool = false

    // Gesture state
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragOffset: CGSize = .zero
    @State private var pinchScale: CGFloat = 1.0
    @State private var lastPinchScale: CGFloat = 1.0
    @State private var rotationAngle: Angle = .zero
    @State private var lastRotationAngle: Angle = .zero

    init(
        image: UIImage,
        initialGeometry: TargetCropGeometry,
        targetType: ShootingTargetGeometryType,
        onConfirm: @escaping (TargetAlignment) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.image = image
        self.initialGeometry = initialGeometry
        self.targetType = targetType
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        _centerPosition = State(initialValue: initialGeometry.targetCenterInCrop)
        _semiAxes = State(initialValue: initialGeometry.targetSemiAxes)
        _rotation = State(initialValue: initialGeometry.rotationDegrees)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Main content
                    ZStack {
                        // Target image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Overlay with alignment guides
                        GeometryReader { imageGeometry in
                            alignmentOverlay(in: imageGeometry.size)
                        }
                    }
                    .gesture(combinedGesture)

                    // Controls
                    controlsView
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button("Cancel") {
                onCancel()
            }
            .foregroundColor(.red)

            Spacer()

            Text("Confirm Center")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button("Done") {
                confirmAlignment()
            }
            .fontWeight(.semibold)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Alignment Overlay

    private func alignmentOverlay(in size: CGSize) -> some View {
        let centerX = centerPosition.x * size.width
        let centerY = centerPosition.y * size.height
        let radiusX = semiAxes.width * size.width
        let radiusY = semiAxes.height * size.height

        return ZStack {
            // Semi-transparent overlay outside target
            if showGuides {
                targetMask(in: size, centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY)
            }

            // Target ellipse outline
            Ellipse()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: radiusX * 2, height: radiusY * 2)
                .rotationEffect(.degrees(rotation))
                .position(x: centerX, y: centerY)

            // Scoring rings preview
            if showGuides {
                scoringRingsPreview(centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY)
            }

            // Center crosshair
            centerCrosshair(centerX: centerX, centerY: centerY)

            // Draggable center handle
            centerHandle(centerX: centerX, centerY: centerY)

            // Resize handles at corners
            resizeHandles(centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY)

            // Rotation handle
            rotationHandle(centerX: centerX, centerY: centerY, radiusY: radiusY)
        }
    }

    private func targetMask(in size: CGSize, centerX: CGFloat, centerY: CGFloat, radiusX: CGFloat, radiusY: CGFloat) -> some View {
        Canvas { context, canvasSize in
            // Draw semi-transparent overlay
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.black.opacity(0.4))
            )

            // Cut out ellipse for target area
            var ellipsePath = Path()
            let transform = CGAffineTransform(translationX: centerX, y: centerY)
                .rotated(by: rotation * .pi / 180)
                .translatedBy(x: -centerX, y: -centerY)

            ellipsePath.addEllipse(in: CGRect(
                x: centerX - radiusX,
                y: centerY - radiusY,
                width: radiusX * 2,
                height: radiusY * 2
            ), transform: transform)

            context.blendMode = .destinationOut
            context.fill(ellipsePath, with: .color(.white))
        }
    }

    private func scoringRingsPreview(centerX: CGFloat, centerY: CGFloat, radiusX: CGFloat, radiusY: CGFloat) -> some View {
        ForEach(targetType.normalizedScoringRadii.dropLast(), id: \.score) { score, radius in
            Ellipse()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: radiusX * 2 * radius, height: radiusY * 2 * radius)
                .rotationEffect(.degrees(rotation))
                .position(x: centerX, y: centerY)
        }
    }

    private func centerCrosshair(centerX: CGFloat, centerY: CGFloat) -> some View {
        Group {
            // Horizontal line
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 40, height: 1)
                .position(x: centerX, y: centerY)

            // Vertical line
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 1, height: 40)
                .position(x: centerX, y: centerY)

            // Center dot
            Circle()
                .fill(Color.yellow)
                .frame(width: 8, height: 8)
                .position(x: centerX, y: centerY)
        }
    }

    private func centerHandle(centerX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(Color.yellow.opacity(0.3))
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
            )
            .position(x: centerX, y: centerY)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isAdjusting = true
                    }
                    .onEnded { _ in
                        isAdjusting = false
                    }
            )
    }

    private func resizeHandles(centerX: CGFloat, centerY: CGFloat, radiusX: CGFloat, radiusY: CGFloat) -> some View {
        Group {
            // Right handle
            resizeHandle()
                .position(x: centerX + radiusX, y: centerY)

            // Left handle
            resizeHandle()
                .position(x: centerX - radiusX, y: centerY)

            // Top handle
            resizeHandle()
                .position(x: centerX, y: centerY - radiusY)

            // Bottom handle
            resizeHandle()
                .position(x: centerX, y: centerY + radiusY)
        }
    }

    private func resizeHandle() -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
            )
    }

    private func rotationHandle(centerX: CGFloat, centerY: CGFloat, radiusY: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.yellow)
        }
        .frame(width: 30, height: 30)
        .background(Color.black.opacity(0.5))
        .clipShape(Circle())
        .position(x: centerX, y: centerY - radiusY - 30)
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 16) {
            // Fine adjustment controls
            HStack(spacing: 24) {
                // Position nudge
                VStack(spacing: 4) {
                    Text("Position")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        nudgeButton(systemName: "arrow.left") {
                            centerPosition.x -= 0.005
                        }
                        VStack(spacing: 4) {
                            nudgeButton(systemName: "arrow.up") {
                                centerPosition.y -= 0.005
                            }
                            nudgeButton(systemName: "arrow.down") {
                                centerPosition.y += 0.005
                            }
                        }
                        nudgeButton(systemName: "arrow.right") {
                            centerPosition.x += 0.005
                        }
                    }
                }

                Divider()
                    .frame(height: 60)

                // Size adjustment
                VStack(spacing: 4) {
                    Text("Size")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        nudgeButton(systemName: "minus.circle") {
                            let scale: CGFloat = 0.98
                            semiAxes.width *= scale
                            semiAxes.height *= scale
                        }
                        nudgeButton(systemName: "plus.circle") {
                            let scale: CGFloat = 1.02
                            semiAxes.width *= scale
                            semiAxes.height *= scale
                        }
                    }
                }

                Divider()
                    .frame(height: 60)

                // Rotation
                VStack(spacing: 4) {
                    Text("Rotate")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        nudgeButton(systemName: "rotate.left") {
                            rotation -= 1
                        }
                        nudgeButton(systemName: "rotate.right") {
                            rotation += 1
                        }
                    }
                }
            }

            // Toggle and reset
            HStack {
                Toggle("Show Guides", isOn: $showGuides)
                    .toggleStyle(.button)
                    .tint(.yellow)

                Spacer()

                Button("Reset") {
                    resetToInitial()
                }
                .foregroundColor(.orange)
            }

            // Instructions
            Text("Drag center to adjust position. Use controls for fine adjustments.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    private func nudgeButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.gray.opacity(0.3))
                .clipShape(Circle())
        }
    }

    // MARK: - Gestures

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            dragGesture,
            SimultaneousGesture(magnificationGesture, rotationGesture)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isAdjusting = true
                let translation = value.translation
                centerPosition.x = min(1, max(0, centerPosition.x + (translation.width - lastDragOffset.width) / 500))
                centerPosition.y = min(1, max(0, centerPosition.y + (translation.height - lastDragOffset.height) / 500))
                lastDragOffset = CGSize(width: translation.width, height: translation.height)
            }
            .onEnded { _ in
                lastDragOffset = .zero
                isAdjusting = false
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isAdjusting = true
                let scale = value / lastPinchScale
                semiAxes.width *= scale
                semiAxes.height *= scale
                lastPinchScale = value
            }
            .onEnded { _ in
                lastPinchScale = 1.0
                isAdjusting = false
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                isAdjusting = true
                rotation += (value - lastRotationAngle).degrees
                lastRotationAngle = value
            }
            .onEnded { _ in
                lastRotationAngle = .zero
                isAdjusting = false
            }
    }

    // MARK: - Actions

    private func resetToInitial() {
        withAnimation(.easeInOut(duration: 0.3)) {
            centerPosition = initialGeometry.targetCenterInCrop
            semiAxes = initialGeometry.targetSemiAxes
            rotation = initialGeometry.rotationDegrees
        }
    }

    private func confirmAlignment() {
        let centerOffset = CGPoint(
            x: centerPosition.x - initialGeometry.targetCenterInCrop.x,
            y: centerPosition.y - initialGeometry.targetCenterInCrop.y
        )

        let alignment = TargetAlignment(
            confirmedCenter: centerPosition,
            confirmedSemiAxes: semiAxes,
            centerOffset: centerOffset,
            rotationAdjustment: rotation - initialGeometry.rotationDegrees,
            alignmentConfidence: 1.0,
            wasManuallyAdjusted: centerOffset != .zero || rotation != initialGeometry.rotationDegrees
        )

        onConfirm(alignment)
    }
}

// MARK: - Preview

#Preview {
    CenterConfirmationView(
        image: UIImage(systemName: "target")!,
        initialGeometry: TargetCropGeometry(),
        targetType: .tetrathlon,
        onConfirm: { _ in },
        onCancel: {}
    )
}
