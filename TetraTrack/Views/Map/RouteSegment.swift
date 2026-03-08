//
//  RouteSegment.swift
//  TetraTrack
//
//  Unified route coloring model for all discipline map views.
//

import SwiftUI
import CoreLocation

// MARK: - Route Segment

struct RouteSegment: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

// MARK: - Route Color Scheme

enum RouteColorScheme {
    case solid(Color)
    case segments([RouteSegment])
    case trim(kept: [CLLocationCoordinate2D], removedStart: [CLLocationCoordinate2D], removedEnd: [CLLocationCoordinate2D], keptColor: Color)
}

// MARK: - Factory Methods

extension RouteColorScheme {

    /// Build gait-colored segments from a saved Ride by matching location timestamps to gait segments
    static func fromRide(_ ride: Ride) -> RouteColorScheme {
        guard let gaitSegments = ride.gaitSegments,
              !gaitSegments.isEmpty else {
            return .solid(AppColors.primary)
        }

        let sortedPoints = ride.sortedLocationPoints
        let sortedGaits = ride.sortedGaitSegments

        guard !sortedPoints.isEmpty else { return .solid(AppColors.primary) }

        var segments: [RouteSegment] = []
        var currentCoords: [CLLocationCoordinate2D] = []
        var currentGait: GaitType?

        for point in sortedPoints {
            let gait = gaitForTimestamp(point.timestamp, in: sortedGaits)

            if currentGait == nil {
                currentGait = gait
                currentCoords.append(point.coordinate)
            } else if gait == currentGait {
                currentCoords.append(point.coordinate)
            } else {
                if currentCoords.count >= 2 {
                    segments.append(RouteSegment(
                        coordinates: currentCoords,
                        color: AppColors.gait(currentGait ?? .walk)
                    ))
                }
                currentCoords = [currentCoords.last ?? point.coordinate, point.coordinate]
                currentGait = gait
            }
        }

        if currentCoords.count >= 2, let gait = currentGait {
            segments.append(RouteSegment(coordinates: currentCoords, color: AppColors.gait(gait)))
        }

        return segments.isEmpty ? .solid(AppColors.primary) : .segments(segments)
    }

    /// Build speed-phase colored segments from a RunningSession
    static func fromRunningSession(_ session: RunningSession) -> RouteColorScheme {
        let points = session.sortedLocationPoints
        guard points.count > 1 else { return .solid(AppColors.primary) }

        var segments: [RouteSegment] = []
        var currentCoords: [CLLocationCoordinate2D] = [points[0].coordinate]
        var currentPhase = RunningPhase.fromGPSSpeed(points[0].speed)

        for i in 1..<points.count {
            let phase = RunningPhase.fromGPSSpeed(points[i].speed)
            if phase == currentPhase {
                currentCoords.append(points[i].coordinate)
            } else {
                if currentCoords.count >= 2 {
                    segments.append(RouteSegment(
                        coordinates: currentCoords,
                        color: AppColors.gait(currentPhase.toGaitType)
                    ))
                }
                currentCoords = [currentCoords.last ?? points[i].coordinate, points[i].coordinate]
                currentPhase = phase
            }
        }

        if currentCoords.count >= 2 {
            segments.append(RouteSegment(
                coordinates: currentCoords,
                color: AppColors.gait(currentPhase.toGaitType)
            ))
        }

        return segments.isEmpty ? .solid(AppColors.primary) : .segments(segments)
    }

    /// Build trim visualization with kept/removed sections
    static func forTrim(
        sortedPoints: [CLLocationCoordinate2D],
        timestamps: [Date],
        trimStart: Date,
        trimEnd: Date,
        keptColor: Color
    ) -> RouteColorScheme {
        var kept: [CLLocationCoordinate2D] = []
        var removedStart: [CLLocationCoordinate2D] = []
        var removedEnd: [CLLocationCoordinate2D] = []

        for (coord, time) in zip(sortedPoints, timestamps) {
            if time < trimStart {
                removedStart.append(coord)
            } else if time > trimEnd {
                removedEnd.append(coord)
            } else {
                kept.append(coord)
            }
        }

        return .trim(kept: kept, removedStart: removedStart, removedEnd: removedEnd, keptColor: keptColor)
    }

    // MARK: - Private Helpers

    private static func gaitForTimestamp(_ timestamp: Date, in segments: [GaitSegment]) -> GaitType {
        for segment in segments {
            let endTime = segment.endTime ?? Date.distantFuture
            if timestamp >= segment.startTime && timestamp <= endTime {
                return segment.gait
            }
        }
        return .walk
    }
}
