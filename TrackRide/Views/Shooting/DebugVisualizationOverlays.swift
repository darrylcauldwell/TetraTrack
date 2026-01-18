//
//  DebugVisualizationOverlays.swift
//  TrackRide
//
//  Debug overlays for visualizing detection pipeline stages.
//  Shows crop regions, candidates, filtering, and analysis results.
//

import SwiftUI

#if DEBUG

// MARK: - Debug Overlay Configuration

/// Configuration for debug visualization overlays
struct DebugOverlayConfig {
    var showCropBounds: Bool = true
    var showNormalizedGrid: Bool = true
    var showCandidateHoles: Bool = true
    var showFilteredHoles: Bool = true
    var showAcceptedHoles: Bool = true
    var showLocalBackground: Bool = false
    var showScoringRings: Bool = true
    var showMPI: Bool = true
    var showConfidenceScores: Bool = true
    var showCoordinateLabels: Bool = false

    var candidateColor: Color = .orange
    var filteredColor: Color = .red.opacity(0.5)
    var acceptedColor: Color = .green
    var backgroundRegionColor: Color = .purple.opacity(0.3)

    static let minimal = DebugOverlayConfig(
        showCropBounds: true,
        showNormalizedGrid: false,
        showCandidateHoles: false,
        showFilteredHoles: false,
        showAcceptedHoles: true,
        showLocalBackground: false,
        showScoringRings: true,
        showMPI: true,
        showConfidenceScores: false,
        showCoordinateLabels: false
    )

    static let full = DebugOverlayConfig(
        showCropBounds: true,
        showNormalizedGrid: true,
        showCandidateHoles: true,
        showFilteredHoles: true,
        showAcceptedHoles: true,
        showLocalBackground: true,
        showScoringRings: true,
        showMPI: true,
        showConfidenceScores: true,
        showCoordinateLabels: true
    )
}

// MARK: - Debug Overlay View

/// Main debug overlay view
struct DebugDetectionOverlay: View {
    let imageSize: CGSize
    let pipelineState: DebugPipelineState
    let config: DebugOverlayConfig

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )

            ZStack {
                // Crop bounds
                if config.showCropBounds, let crop = pipelineState.cropGeometry {
                    CropBoundsOverlay(
                        cropGeometry: crop,
                        scale: scale,
                        imageSize: imageSize
                    )
                }

                // Normalized grid
                if config.showNormalizedGrid, let crop = pipelineState.cropGeometry {
                    NormalizedGridOverlay(
                        cropGeometry: crop,
                        scale: scale,
                        imageSize: imageSize
                    )
                }

                // Scoring rings
                if config.showScoringRings, let crop = pipelineState.cropGeometry {
                    ScoringRingsOverlay(
                        cropGeometry: crop,
                        scale: scale,
                        imageSize: imageSize
                    )
                }

                // Background regions
                if config.showLocalBackground {
                    ForEach(pipelineState.backgroundRegions) { region in
                        BackgroundRegionOverlay(
                            region: region,
                            scale: scale,
                            color: config.backgroundRegionColor
                        )
                    }
                }

                // Candidate holes
                if config.showCandidateHoles {
                    ForEach(pipelineState.candidateHoles) { hole in
                        HoleCandidateOverlay(
                            hole: hole,
                            scale: scale,
                            color: config.candidateColor,
                            showConfidence: config.showConfidenceScores,
                            showCoords: config.showCoordinateLabels
                        )
                    }
                }

                // Filtered holes
                if config.showFilteredHoles {
                    ForEach(pipelineState.filteredHoles) { hole in
                        FilteredHoleOverlay(
                            hole: hole,
                            scale: scale,
                            color: config.filteredColor
                        )
                    }
                }

                // Accepted holes
                if config.showAcceptedHoles {
                    ForEach(pipelineState.acceptedHoles) { hole in
                        AcceptedHoleOverlay(
                            hole: hole,
                            scale: scale,
                            color: config.acceptedColor,
                            showConfidence: config.showConfidenceScores,
                            showCoords: config.showCoordinateLabels
                        )
                    }
                }

                // MPI marker
                if config.showMPI, let analysis = pipelineState.patternAnalysis,
                   let crop = pipelineState.cropGeometry {
                    MPIMarkerOverlay(
                        mpi: analysis.mpi,
                        cropGeometry: crop,
                        scale: scale,
                        imageSize: imageSize
                    )
                }
            }
        }
    }
}

// MARK: - Component Overlays

private struct CropBoundsOverlay: View {
    let cropGeometry: TargetCropGeometry
    let scale: CGFloat
    let imageSize: CGSize

    var body: some View {
        let rect = cropGeometry.cropRect
        let scaledRect = CGRect(
            x: rect.origin.x * imageSize.width * scale,
            y: rect.origin.y * imageSize.height * scale,
            width: rect.width * imageSize.width * scale,
            height: rect.height * imageSize.height * scale
        )

        Rectangle()
            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            .frame(width: scaledRect.width, height: scaledRect.height)
            .position(
                x: scaledRect.midX,
                y: scaledRect.midY
            )
    }
}

private struct NormalizedGridOverlay: View {
    let cropGeometry: TargetCropGeometry
    let scale: CGFloat
    let imageSize: CGSize

    var body: some View {
        let center = cropGeometry.targetCenterInCrop
        let semiAxes = cropGeometry.targetSemiAxes

        let centerX = center.x * imageSize.width * scale
        let centerY = center.y * imageSize.height * scale
        let radiusX = semiAxes.width * imageSize.width * scale
        let radiusY = semiAxes.height * imageSize.height * scale

        ZStack {
            // Horizontal axis
            Rectangle()
                .fill(Color.cyan.opacity(0.5))
                .frame(width: radiusX * 2, height: 1)
                .position(x: centerX, y: centerY)

            // Vertical axis
            Rectangle()
                .fill(Color.cyan.opacity(0.5))
                .frame(width: 1, height: radiusY * 2)
                .position(x: centerX, y: centerY)

            // Grid lines at 0.5 intervals
            ForEach([-0.5, 0.5], id: \.self) { offset in
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: radiusX * 2, height: 1)
                    .position(x: centerX, y: centerY + radiusY * offset)

                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 1, height: radiusY * 2)
                    .position(x: centerX + radiusX * offset, y: centerY)
            }
        }
    }
}

private struct ScoringRingsOverlay: View {
    let cropGeometry: TargetCropGeometry
    let scale: CGFloat
    let imageSize: CGSize

    var body: some View {
        let center = cropGeometry.targetCenterInCrop
        let semiAxes = cropGeometry.targetSemiAxes

        let centerX = center.x * imageSize.width * scale
        let centerY = center.y * imageSize.height * scale
        let radiusX = semiAxes.width * imageSize.width * scale
        let radiusY = semiAxes.height * imageSize.height * scale

        // Tetrathlon scoring zones (normalized radii)
        let rings: [(Double, Color)] = [
            (0.092, .yellow),   // 10
            (0.319, .red),      // 8
            (0.546, .blue),     // 6
            (0.773, .gray),     // 4
            (1.0, .white)       // 2
        ]

        ForEach(Array(rings.enumerated()), id: \.offset) { _, ring in
            Ellipse()
                .stroke(ring.1.opacity(0.4), lineWidth: 1)
                .frame(
                    width: radiusX * 2 * ring.0,
                    height: radiusY * 2 * ring.0
                )
                .position(x: centerX, y: centerY)
        }
    }
}

private struct BackgroundRegionOverlay: View {
    let region: DebugBackgroundRegion
    let scale: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(color, lineWidth: 1)
                .frame(
                    width: region.outerRadius * 2 * scale,
                    height: region.outerRadius * 2 * scale
                )

            // Inner ring
            Circle()
                .stroke(color, lineWidth: 1)
                .frame(
                    width: region.innerRadius * 2 * scale,
                    height: region.innerRadius * 2 * scale
                )

            // Stats label
            Text("\(Int(region.meanIntensity))±\(Int(region.stdDev))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(color)
                .offset(y: region.outerRadius * scale + 8)
        }
        .position(
            x: region.center.x * scale,
            y: region.center.y * scale
        )
    }
}

private struct HoleCandidateOverlay: View {
    let hole: DebugHoleCandidate
    let scale: CGFloat
    let color: Color
    let showConfidence: Bool
    let showCoords: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1)
                .frame(
                    width: hole.radiusPixels * 2 * scale,
                    height: hole.radiusPixels * 2 * scale
                )

            if showConfidence {
                Text(String(format: "%.0f%%", hole.confidence * 100))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(color)
                    .offset(y: -hole.radiusPixels * scale - 10)
            }

            if showCoords {
                Text("(\(String(format: "%.2f", hole.normalizedPosition.x)), \(String(format: "%.2f", hole.normalizedPosition.y)))")
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundStyle(color)
                    .offset(y: hole.radiusPixels * scale + 10)
            }
        }
        .position(
            x: hole.pixelPosition.x * scale,
            y: hole.pixelPosition.y * scale
        )
    }
}

private struct FilteredHoleOverlay: View {
    let hole: DebugHoleCandidate
    let scale: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            // X through the hole
            Circle()
                .stroke(color, lineWidth: 1)
                .frame(
                    width: hole.radiusPixels * 2 * scale,
                    height: hole.radiusPixels * 2 * scale
                )

            Path { path in
                let size = hole.radiusPixels * scale
                path.move(to: CGPoint(x: -size, y: -size))
                path.addLine(to: CGPoint(x: size, y: size))
                path.move(to: CGPoint(x: size, y: -size))
                path.addLine(to: CGPoint(x: -size, y: size))
            }
            .stroke(color, lineWidth: 1)

            // Filter reason
            if let reason = hole.filterReason {
                Text(reason)
                    .font(.system(size: 6, design: .monospaced))
                    .foregroundStyle(color)
                    .offset(y: hole.radiusPixels * scale + 8)
            }
        }
        .position(
            x: hole.pixelPosition.x * scale,
            y: hole.pixelPosition.y * scale
        )
    }
}

private struct AcceptedHoleOverlay: View {
    let hole: DebugHoleCandidate
    let scale: CGFloat
    let color: Color
    let showConfidence: Bool
    let showCoords: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(
                    width: hole.radiusPixels * 2 * scale,
                    height: hole.radiusPixels * 2 * scale
                )

            Circle()
                .stroke(color, lineWidth: 2)
                .frame(
                    width: hole.radiusPixels * 2 * scale,
                    height: hole.radiusPixels * 2 * scale
                )

            if showConfidence {
                Text(String(format: "%.0f%%", hole.confidence * 100))
                    .font(.system(size: 9, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .offset(y: -hole.radiusPixels * scale - 12)
            }

            if showCoords {
                Text("(\(String(format: "%.2f", hole.normalizedPosition.x)), \(String(format: "%.2f", hole.normalizedPosition.y)))")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(color)
                    .offset(y: hole.radiusPixels * scale + 12)
            }
        }
        .position(
            x: hole.pixelPosition.x * scale,
            y: hole.pixelPosition.y * scale
        )
    }
}

private struct MPIMarkerOverlay: View {
    let mpi: NormalizedTargetPosition
    let cropGeometry: TargetCropGeometry
    let scale: CGFloat
    let imageSize: CGSize

    var body: some View {
        let center = cropGeometry.targetCenterInCrop
        let semiAxes = cropGeometry.targetSemiAxes

        let centerX = center.x * imageSize.width * scale
        let centerY = center.y * imageSize.height * scale
        let radiusX = semiAxes.width * imageSize.width * scale
        let radiusY = semiAxes.height * imageSize.height * scale

        let mpiX = centerX + mpi.x * radiusX
        let mpiY = centerY - mpi.y * radiusY  // Flip Y

        ZStack {
            // Crosshair
            Rectangle()
                .fill(Color.orange)
                .frame(width: 20, height: 2)

            Rectangle()
                .fill(Color.orange)
                .frame(width: 2, height: 20)

            // MPI label
            Text("MPI")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .offset(y: -16)
        }
        .position(x: mpiX, y: mpiY)
    }
}

// MARK: - Debug Overlay Control Panel

/// Control panel for toggling debug overlay options
struct DebugOverlayControlPanel: View {
    @Binding var config: DebugOverlayConfig
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Debug Overlays")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(.orange)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ToggleRow(label: "Crop Bounds", isOn: $config.showCropBounds)
                    ToggleRow(label: "Normalized Grid", isOn: $config.showNormalizedGrid)
                    ToggleRow(label: "Scoring Rings", isOn: $config.showScoringRings)
                    ToggleRow(label: "Candidate Holes", isOn: $config.showCandidateHoles)
                    ToggleRow(label: "Filtered Holes", isOn: $config.showFilteredHoles)
                    ToggleRow(label: "Accepted Holes", isOn: $config.showAcceptedHoles)
                    ToggleRow(label: "Local Background", isOn: $config.showLocalBackground)
                    ToggleRow(label: "MPI Marker", isOn: $config.showMPI)
                    ToggleRow(label: "Confidence Scores", isOn: $config.showConfidenceScores)
                    ToggleRow(label: "Coordinate Labels", isOn: $config.showCoordinateLabels)

                    Divider()

                    HStack {
                        Button("Minimal") {
                            config = .minimal
                        }
                        .font(.caption)

                        Button("Full") {
                            config = .full
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private struct ToggleRow: View {
        let label: String
        @Binding var isOn: Bool

        var body: some View {
            Toggle(label, isOn: $isOn)
                .font(.caption)
                .toggleStyle(.switch)
                .tint(.orange)
        }
    }
}

// MARK: - Pipeline Stage Timing View

/// Shows timing for each pipeline stage
struct PipelineStagingTimingView: View {
    let state: DebugPipelineState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pipeline Timing")
                .font(.caption.bold())
                .foregroundStyle(.orange)

            ForEach(DebugPipelineState.PipelineStage.allCases, id: \.self) { stage in
                HStack {
                    Circle()
                        .fill(state.completedStages.contains(stage) ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(stage.rawValue)
                        .font(.system(size: 10, design: .monospaced))

                    Spacer()

                    if let timing = state.stageTiming[stage] {
                        Text(String(format: "%.1fms", timing * 1000))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !state.stageTiming.isEmpty {
                Divider()
                HStack {
                    Text("Total")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Spacer()
                    Text(String(format: "%.1fms", state.stageTiming.values.reduce(0, +) * 1000))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#endif
