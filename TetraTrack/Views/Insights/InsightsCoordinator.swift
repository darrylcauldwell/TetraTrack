//
//  InsightsCoordinator.swift
//  TetraTrack
//
//  Shared state manager for cross-chart interaction in Ride Insights view
//  Coordinates timestamp highlighting, zoom level, and comparison mode
//

import SwiftUI

/// Manages shared state across all insight charts for synchronized interaction
@Observable
final class InsightsCoordinator {
    // MARK: - Timestamp Highlighting

    /// Currently selected timestamp for cross-chart highlighting
    var selectedTimestamp: Date?

    /// Whether a timestamp is currently selected
    var hasSelection: Bool { selectedTimestamp != nil }

    // MARK: - Zoom Controls

    /// Current zoom level (1x to 4x)
    var zoomLevel: Double = 1.0

    /// Minimum zoom level
    static let minZoom: Double = 1.0

    /// Maximum zoom level
    static let maxZoom: Double = 4.0

    /// Zoom step for controls
    static let zoomStep: Double = 0.5

    // MARK: - Comparison Mode

    /// Whether comparison mode is active
    var comparisonMode: Bool = false

    /// Start timestamp for first comparison range
    var comparisonStartA: Date?

    /// End timestamp for first comparison range
    var comparisonEndA: Date?

    /// Start timestamp for second comparison range
    var comparisonStartB: Date?

    /// End timestamp for second comparison range
    var comparisonEndB: Date?

    /// Whether comparison ranges are fully defined
    var hasValidComparison: Bool {
        comparisonStartA != nil && comparisonEndA != nil &&
        comparisonStartB != nil && comparisonEndB != nil
    }

    // MARK: - Methods

    /// Select a timestamp for cross-chart highlighting
    func selectTimestamp(_ timestamp: Date) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTimestamp = timestamp
        }
    }

    /// Clear the current timestamp selection
    func clearSelection() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTimestamp = nil
        }
    }

    /// Zoom in by one step
    func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomLevel = min(zoomLevel + Self.zoomStep, Self.maxZoom)
        }
    }

    /// Zoom out by one step
    func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomLevel = max(zoomLevel - Self.zoomStep, Self.minZoom)
        }
    }

    /// Reset zoom to default
    func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomLevel = Self.minZoom
        }
    }

    /// Toggle comparison mode
    func toggleComparisonMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            comparisonMode.toggle()
            if !comparisonMode {
                clearComparisonRanges()
            }
        }
    }

    /// Set comparison ranges for first half vs second half of ride
    func setDefaultComparisonRanges(rideStart: Date, rideEnd: Date) {
        let midpoint = rideStart.addingTimeInterval(rideEnd.timeIntervalSince(rideStart) / 2)
        comparisonStartA = rideStart
        comparisonEndA = midpoint
        comparisonStartB = midpoint
        comparisonEndB = rideEnd
    }

    /// Clear comparison ranges
    func clearComparisonRanges() {
        comparisonStartA = nil
        comparisonEndA = nil
        comparisonStartB = nil
        comparisonEndB = nil
    }

    /// Calculate the visible time range based on zoom level
    func visibleRange(rideDuration: TimeInterval, rideStart: Date) -> ClosedRange<Date> {
        let visibleDuration = rideDuration / zoomLevel
        let end = rideStart.addingTimeInterval(visibleDuration)
        return rideStart...end
    }

    /// Calculate position ratio for a timestamp within the ride
    func positionRatio(for timestamp: Date, rideStart: Date, rideDuration: TimeInterval) -> Double {
        guard rideDuration > 0 else { return 0 }
        let elapsed = timestamp.timeIntervalSince(rideStart)
        return min(max(elapsed / rideDuration, 0), 1)
    }
}

// MARK: - Comparison Stats

extension InsightsCoordinator {
    /// Calculate stats for a specific time range
    struct RangeStats {
        let averageRhythm: Double
        let segmentCount: Int
    }

    /// Calculate stats for comparison range A
    func statsForRangeA(segments: [GaitSegment]) -> RangeStats? {
        guard let start = comparisonStartA, let end = comparisonEndA else { return nil }
        return calculateStats(for: segments, in: start...end)
    }

    /// Calculate stats for comparison range B
    func statsForRangeB(segments: [GaitSegment]) -> RangeStats? {
        guard let start = comparisonStartB, let end = comparisonEndB else { return nil }
        return calculateStats(for: segments, in: start...end)
    }

    private func calculateStats(for segments: [GaitSegment], in range: ClosedRange<Date>) -> RangeStats {
        let filtered = segments.filter { segment in
            segment.startTime >= range.lowerBound &&
            segment.startTime <= range.upperBound
        }

        guard !filtered.isEmpty else {
            return RangeStats(averageRhythm: 0, segmentCount: 0)
        }

        let rhythmSum = filtered.reduce(0) { $0 + $1.rhythmScore }

        return RangeStats(
            averageRhythm: rhythmSum / Double(filtered.count),
            segmentCount: filtered.count
        )
    }
}
