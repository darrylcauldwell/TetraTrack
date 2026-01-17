//
//  ShotPatternVisualizationView.swift
//  TrackRide
//
//  Interactive visualization for shot patterns with point overlay and heat map modes.
//  Supports zoom/pan, MPI overlay, and tap-to-inspect functionality.
//

import SwiftUI

// MARK: - Display Mode

enum ShotDisplayMode: String, CaseIterable {
    case points = "Points"
    case heatMap = "Heat Map"

    var icon: String {
        switch self {
        case .points: return "circle.grid.2x2"
        case .heatMap: return "square.stack.3d.up.fill"
        }
    }
}

// MARK: - Main Visualization View

struct ShotPatternVisualizationView: View {
    let visualData: VisualPatternData?
    let showAggregate: Bool

    @State private var displayMode: ShotDisplayMode = .points
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var selectedShot: VisualPatternData.NormalizedShotPoint?
    @State private var showMPI: Bool = true
    @State private var showGroupRadius: Bool = false

    private let canvasSize: CGFloat = 300

    var body: some View {
        VStack(spacing: 12) {
            // Mode selector
            modeSelector

            // Visualization canvas
            visualizationCanvas
                .frame(width: canvasSize, height: canvasSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Controls
            controlsRow

            // Selected shot info
            if let shot = selectedShot {
                selectedShotInfo(shot)
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ShotDisplayMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.caption.weight(.medium))
                        Text(mode.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(displayMode == mode ? Color.blue : Color.clear)
                    .foregroundStyle(displayMode == mode ? .white : .primary)
                }
            }
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Visualization Canvas

    private var visualizationCanvas: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // Background with target rings (subtle)
                targetBackground(size: size)

                // Shot visualization layer
                Group {
                    switch displayMode {
                    case .points:
                        pointOverlayView(size: size)
                    case .heatMap:
                        heatMapView(size: size)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)

                // MPI and group radius overlays (not affected by zoom for clarity)
                if showMPI {
                    mpiOverlay(size: size)
                        .scaleEffect(scale)
                        .offset(offset)
                }

                if showGroupRadius {
                    groupRadiusOverlay(size: size)
                        .scaleEffect(scale)
                        .offset(offset)
                }

                // Zoom indicator
                if scale > 1.0 {
                    zoomIndicator
                }
            }
            .background(Color(.systemBackground))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let translation = value.translation
                        let distance = sqrt(translation.width * translation.width + translation.height * translation.height)

                        if scale > 1.0 && distance > 5 {
                            // Pan when zoomed
                            offset = CGSize(
                                width: lastOffset.width + translation.width,
                                height: lastOffset.height + translation.height
                            )
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation
                        let distance = sqrt(translation.width * translation.width + translation.height * translation.height)

                        if distance < 10 {
                            // Tap - check for shot selection
                            handleTap(at: value.location, in: size)
                        } else if scale > 1.0 {
                            lastOffset = offset
                        }
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1.0, min(value, 4.0))
                    }
                    .onEnded { value in
                        scale = max(1.0, min(value, 4.0))
                        if scale <= 1.0 {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Target Background

    private func targetBackground(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        // Tetrathlon scoring ring radii (normalized)
        let scoringRings = TetrathlonTargetGeometry.normalizedScoringRadii

        return ZStack {
            // Draw scoring rings from outer to inner
            ForEach(scoringRings.reversed(), id: \.score) { ring in
                let ringRadius = maxRadius * ring.normalizedRadius

                // Ring circle - use ellipse for Tetrathlon target
                Ellipse()
                    .stroke(ringColor(for: ring.score).opacity(0.4), lineWidth: ring.score == 10 ? 2 : 1)
                    .frame(
                        width: ringRadius * 2,
                        height: ringRadius * 2 / TetrathlonTargetGeometry.aspectRatio
                    )
                    .position(center)

                // Ring label (small, positioned to the right)
                if ring.score > 0 {
                    Text("\(ring.score)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(ringColor(for: ring.score).opacity(0.6))
                        .position(x: center.x + (maxRadius * ring.normalizedRadius) - 8, y: center.y)
                }
            }

            // Center crosshair
            Path { path in
                path.move(to: CGPoint(x: center.x - 10, y: center.y))
                path.addLine(to: CGPoint(x: center.x + 10, y: center.y))
                path.move(to: CGPoint(x: center.x, y: center.y - 10))
                path.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            }
            .stroke(Color(.tertiaryLabel).opacity(0.5), lineWidth: 1)
        }
    }

    /// Color for scoring ring
    private func ringColor(for score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 8: return .red
        case 6: return .blue
        case 4: return .primary
        case 2: return .secondary
        default: return .gray
        }
    }

    // MARK: - Point Overlay View

    private func pointOverlayView(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        return ZStack {
            // Historical shots (if showing aggregate)
            if showAggregate, let data = visualData {
                ForEach(data.historicalShots) { shot in
                    let screenPos = normalizedToScreen(shot.position, center: center, maxRadius: maxRadius)
                    ShotMarker(
                        isSelected: selectedShot?.id == shot.id,
                        isHistorical: true,
                        isOutlier: shot.isOutlier
                    )
                    .position(screenPos)
                    .onTapGesture {
                        selectedShot = shot
                    }
                }
            }

            // Current target shots
            if let data = visualData {
                ForEach(data.currentTargetShots) { shot in
                    let screenPos = normalizedToScreen(shot.position, center: center, maxRadius: maxRadius)
                    ShotMarker(
                        isSelected: selectedShot?.id == shot.id,
                        isHistorical: false,
                        isOutlier: shot.isOutlier
                    )
                    .position(screenPos)
                    .onTapGesture {
                        selectedShot = shot
                    }
                }
            }
        }
    }

    // MARK: - Heat Map View

    private func heatMapView(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        // Collect all shots for heat map
        var allShots: [CGPoint] = []

        if let data = visualData {
            allShots.append(contentsOf: data.currentTargetShots.map { $0.position })

            if showAggregate {
                allShots.append(contentsOf: data.historicalShots.map { $0.position })
            }
        }

        return Canvas { context, canvasSize in
            // Create density grid
            let gridSize = 20
            let cellWidth = canvasSize.width / CGFloat(gridSize)
            let cellHeight = canvasSize.height / CGFloat(gridSize)

            var densityGrid = Array(repeating: Array(repeating: 0.0, count: gridSize), count: gridSize)

            // Calculate density with gaussian kernel
            for shot in allShots {
                let screenPos = normalizedToScreen(shot, center: center, maxRadius: maxRadius)

                // Apply gaussian contribution to nearby cells
                for row in 0..<gridSize {
                    for col in 0..<gridSize {
                        let cellCenterX = (CGFloat(col) + 0.5) * cellWidth
                        let cellCenterY = (CGFloat(row) + 0.5) * cellHeight

                        let dx = screenPos.x - cellCenterX
                        let dy = screenPos.y - cellCenterY
                        let distSq = dx * dx + dy * dy

                        // Gaussian kernel with sigma = 15 pixels
                        let sigma: CGFloat = 15
                        let weight = exp(-distSq / (2 * sigma * sigma))
                        densityGrid[row][col] += weight
                    }
                }
            }

            // Find max density for normalization
            let maxDensity = densityGrid.flatMap { $0 }.max() ?? 1.0

            // Draw heat map cells
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let normalizedDensity = densityGrid[row][col] / maxDensity

                    if normalizedDensity > 0.01 {
                        let rect = CGRect(
                            x: CGFloat(col) * cellWidth,
                            y: CGFloat(row) * cellHeight,
                            width: cellWidth + 1,
                            height: cellHeight + 1
                        )

                        let color = heatMapColor(for: normalizedDensity)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func heatMapColor(for density: Double) -> Color {
        // Blue -> Cyan -> Green -> Yellow -> Orange -> Red
        let clamped = max(0, min(1, density))

        if clamped < 0.2 {
            // Blue to Cyan
            let t = clamped / 0.2
            return Color(red: 0, green: t, blue: 1)
        } else if clamped < 0.4 {
            // Cyan to Green
            let t = (clamped - 0.2) / 0.2
            return Color(red: 0, green: 1, blue: 1 - t)
        } else if clamped < 0.6 {
            // Green to Yellow
            let t = (clamped - 0.4) / 0.2
            return Color(red: t, green: 1, blue: 0)
        } else if clamped < 0.8 {
            // Yellow to Orange
            let t = (clamped - 0.6) / 0.2
            return Color(red: 1, green: 1 - t * 0.5, blue: 0)
        } else {
            // Orange to Red
            let t = (clamped - 0.8) / 0.2
            return Color(red: 1, green: 0.5 - t * 0.5, blue: 0)
        }
    }

    // MARK: - MPI Overlay

    private func mpiOverlay(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        return ZStack {
            // Current target MPI
            if let data = visualData, let mpiCurrent = data.mpiCurrent {
                let mpiScreen = normalizedToScreen(mpiCurrent, center: center, maxRadius: maxRadius)
                MPIMarker(color: .blue, label: "MPI")
                    .position(mpiScreen)
            }

            // Aggregate MPI (if different view)
            if showAggregate, let data = visualData, let mpiAggregate = data.mpiAggregate {
                let mpiScreen = normalizedToScreen(mpiAggregate, center: center, maxRadius: maxRadius)
                MPIMarker(color: .purple, label: "Avg")
                    .position(mpiScreen)
            }
        }
    }

    // MARK: - Group Radius Overlay

    private func groupRadiusOverlay(size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        return ZStack {
            // Current target group radius
            if let data = visualData, let mpiCurrent = data.mpiCurrent, let radiusCurrent = data.groupRadiusCurrent {
                let mpiScreen = normalizedToScreen(mpiCurrent, center: center, maxRadius: maxRadius)
                let radiusScreen = radiusCurrent * maxRadius

                Circle()
                    .stroke(Color.blue.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .frame(width: radiusScreen * 2, height: radiusScreen * 2)
                    .position(mpiScreen)
            }

            // Aggregate group radius
            if showAggregate, let data = visualData, let mpiAggregate = data.mpiAggregate, let radiusAggregate = data.groupRadiusAggregate {
                let mpiScreen = normalizedToScreen(mpiAggregate, center: center, maxRadius: maxRadius)
                let radiusScreen = radiusAggregate * maxRadius

                Circle()
                    .stroke(Color.purple.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .frame(width: radiusScreen * 2, height: radiusScreen * 2)
                    .position(mpiScreen)
            }
        }
    }

    // MARK: - Zoom Indicator

    private var zoomIndicator: some View {
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                }
                .padding(8)
            }
        }
    }

    // MARK: - Controls Row

    private var controlsRow: some View {
        HStack(spacing: 16) {
            Toggle(isOn: $showMPI) {
                HStack(spacing: 4) {
                    Image(systemName: "scope")
                    Text("MPI")
                }
                .font(.caption)
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)

            Toggle(isOn: $showGroupRadius) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.dashed")
                    Text("Spread")
                }
                .font(.caption)
            }
            .toggleStyle(.button)
            .buttonStyle(.bordered)

            Spacer()

            if let data = visualData {
                let totalShots = data.currentTargetShots.count + (showAggregate ? data.historicalShots.count : 0)
                Text("\(totalShots) shots")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Selected Shot Info

    private func selectedShotInfo(_ shot: VisualPatternData.NormalizedShotPoint) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(shot.isCurrentTarget ? "Current Target" : "Historical Shot")
                        .font(.caption.weight(.medium))

                    if shot.isOutlier {
                        Text("Outlier")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }

                let distance = sqrt(shot.position.x * shot.position.x + shot.position.y * shot.position.y)
                Text("Distance from center: \(String(format: "%.2f", distance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let timestamp = shot.timestamp {
                    Text(timestamp, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                selectedShot = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    private func normalizedToScreen(_ normalized: CGPoint, center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + normalized.x * maxRadius,
            y: center.y + normalized.y * maxRadius
        )
    }

    private func screenToNormalized(_ screen: CGPoint, center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        CGPoint(
            x: (screen.x - center.x) / maxRadius,
            y: (screen.y - center.y) / maxRadius
        )
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        // Account for zoom/pan
        let adjustedLocation = CGPoint(
            x: (location.x - size.width / 2 - offset.width) / scale + size.width / 2,
            y: (location.y - size.height / 2 - offset.height) / scale + size.height / 2
        )

        let hitRadius: CGFloat = 20 / scale

        guard let data = visualData else {
            selectedShot = nil
            return
        }

        // Check current target shots first
        for shot in data.currentTargetShots {
            let screenPos = normalizedToScreen(shot.position, center: center, maxRadius: maxRadius)
            let dx = adjustedLocation.x - screenPos.x
            let dy = adjustedLocation.y - screenPos.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance < hitRadius {
                selectedShot = shot
                return
            }
        }

        // Check historical shots
        if showAggregate {
            for shot in data.historicalShots {
                let screenPos = normalizedToScreen(shot.position, center: center, maxRadius: maxRadius)
                let dx = adjustedLocation.x - screenPos.x
                let dy = adjustedLocation.y - screenPos.y
                let distance = sqrt(dx * dx + dy * dy)

                if distance < hitRadius {
                    selectedShot = shot
                    return
                }
            }
        }

        // No shot hit - deselect
        selectedShot = nil
    }
}

// MARK: - Shot Marker

struct ShotMarker: View {
    let isSelected: Bool
    let isHistorical: Bool
    let isOutlier: Bool

    init(isSelected: Bool, isHistorical: Bool, isOutlier: Bool = false) {
        self.isSelected = isSelected
        self.isHistorical = isHistorical
        self.isOutlier = isOutlier
    }

    var body: some View {
        ZStack {
            // Base circle
            Circle()
                .fill(fillColor)
                .frame(width: markerSize, height: markerSize)

            Circle()
                .stroke(strokeColor, lineWidth: isSelected ? 3 : 1.5)
                .frame(width: markerSize, height: markerSize)

            // Outlier indicator (X mark)
            if isOutlier && !isSelected {
                Path { path in
                    let size: CGFloat = 4
                    path.move(to: CGPoint(x: -size, y: -size))
                    path.addLine(to: CGPoint(x: size, y: size))
                    path.move(to: CGPoint(x: size, y: -size))
                    path.addLine(to: CGPoint(x: -size, y: size))
                }
                .stroke(Color.white, lineWidth: 1.5)
            }

            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                    .frame(width: markerSize + 8, height: markerSize + 8)
            }
        }
    }

    private var fillColor: Color {
        if isOutlier {
            return Color.orange.opacity(0.6)
        } else if isHistorical {
            return Color.gray.opacity(0.4)
        } else {
            return Color.blue.opacity(0.7)
        }
    }

    private var strokeColor: Color {
        if isSelected {
            return Color.orange
        } else if isOutlier {
            return Color.orange
        } else if isHistorical {
            return Color.gray
        } else {
            return Color.blue
        }
    }

    private var markerSize: CGFloat {
        isSelected ? 14 : (isOutlier ? 12 : 10)
    }
}

// MARK: - MPI Marker

struct MPIMarker: View {
    let color: Color
    let label: String

    var body: some View {
        ZStack {
            // Crosshair
            Path { path in
                path.move(to: CGPoint(x: -8, y: 0))
                path.addLine(to: CGPoint(x: 8, y: 0))
                path.move(to: CGPoint(x: 0, y: -8))
                path.addLine(to: CGPoint(x: 0, y: 8))
            }
            .stroke(color, lineWidth: 2)

            // Center dot
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            // Outer ring
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: 16, height: 16)

            // Label
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(color)
                .clipShape(Capsule())
                .offset(y: -16)
        }
    }
}

// MARK: - Historical Aggregation View

struct HistoricalAggregationView: View {
    let historyManager: ShotPatternHistoryManager
    @State private var dateFilter: DateFilter = .allTime
    @State private var visualizationData: VisualPatternData?
    @State private var totalShotCount: Int = 0
    @State private var avgGroupRadius: Double = 0

    enum DateFilter: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case allTime = "All Time"

        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .today:
                return calendar.startOfDay(for: now)
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .allTime:
                return nil
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Date filter
            Picker("Period", selection: $dateFilter) {
                ForEach(DateFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: dateFilter) { _, _ in
                updateVisualizationData()
            }

            // Stats summary
            if visualizationData != nil {
                HStack(spacing: 24) {
                    PatternStatItem(value: "\(totalShotCount)", label: "Total Shots")
                    PatternStatItem(value: "\(filteredTargetCount)", label: "Targets")
                    PatternStatItem(
                        value: String(format: "%.2f", avgGroupRadius),
                        label: "Avg Spread"
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Visualization
                ShotPatternVisualizationView(
                    visualData: visualizationData,
                    showAggregate: true
                )
            } else {
                ContentUnavailableView(
                    "No Practice Data",
                    systemImage: "target",
                    description: Text("Complete some practice sessions to see your trends.")
                )
            }
        }
        .onAppear {
            updateVisualizationData()
        }
    }

    private var filteredTargetCount: Int {
        let filtered = filterHistory()
        return filtered.count
    }

    private func filterHistory() -> [StoredTargetPattern] {
        let history = historyManager.getRecentHistory(limit: 100)

        guard let startDate = dateFilter.startDate else {
            return history
        }

        return history.filter { $0.timestamp >= startDate }
    }

    private func updateVisualizationData() {
        let filtered = filterHistory()

        guard !filtered.isEmpty else {
            visualizationData = nil
            totalShotCount = 0
            avgGroupRadius = 0
            return
        }

        // Combine all normalized shots
        var allShots: [VisualPatternData.NormalizedShotPoint] = []
        var totalMpiX = 0.0
        var totalMpiY = 0.0
        var totalGroupRadius = 0.0
        var totalWeight = 0.0

        for pattern in filtered {
            for shotPoint in pattern.normalizedShots {
                allShots.append(VisualPatternData.NormalizedShotPoint(
                    position: shotPoint,
                    isCurrentTarget: false,
                    timestamp: pattern.timestamp
                ))
            }

            let weight = Double(pattern.shotCount)
            totalMpiX += pattern.clusterMpiX * weight
            totalMpiY += pattern.clusterMpiY * weight
            totalGroupRadius += pattern.clusterRadius * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else {
            visualizationData = nil
            totalShotCount = 0
            avgGroupRadius = 0
            return
        }

        let mpi = CGPoint(x: totalMpiX / totalWeight, y: totalMpiY / totalWeight)
        avgGroupRadius = totalGroupRadius / totalWeight
        totalShotCount = allShots.count

        visualizationData = VisualPatternData(
            currentTargetShots: [],
            historicalShots: allShots,
            mpiCurrent: nil,
            mpiAggregate: mpi,
            groupRadiusCurrent: nil,
            groupRadiusAggregate: avgGroupRadius
        )
    }
}

// MARK: - Pattern Stat Item

private struct PatternStatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Point Overlay") {
    let sampleShots: [VisualPatternData.NormalizedShotPoint] = [
        .init(position: CGPoint(x: 0.1, y: -0.05), isCurrentTarget: true, timestamp: nil),
        .init(position: CGPoint(x: 0.15, y: 0.02), isCurrentTarget: true, timestamp: nil),
        .init(position: CGPoint(x: 0.08, y: 0.1), isCurrentTarget: true, timestamp: nil),
        .init(position: CGPoint(x: 0.12, y: -0.08), isCurrentTarget: true, timestamp: nil),
        .init(position: CGPoint(x: 0.05, y: 0.05), isCurrentTarget: true, timestamp: nil),
    ]

    let sampleData = VisualPatternData(
        currentTargetShots: sampleShots,
        historicalShots: [],
        mpiCurrent: CGPoint(x: 0.1, y: 0.01),
        mpiAggregate: nil,
        groupRadiusCurrent: 0.08,
        groupRadiusAggregate: nil
    )

    ShotPatternVisualizationView(
        visualData: sampleData,
        showAggregate: false
    )
    .padding()
}
