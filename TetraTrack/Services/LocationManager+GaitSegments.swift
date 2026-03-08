//
//  LocationManager+GaitSegments.swift
//  TetraTrack
//
//  Extension to group tracked GPS points by gait for live route display.
//

import CoreLocation

extension LocationManager {
    /// Group tracked points by gait for route display
    var gaitRouteSegments: [GaitRouteSegment] {
        guard trackedPoints.count > 1 else { return [] }

        var segments: [GaitRouteSegment] = []
        var currentGait = trackedPoints[0].gait
        var currentCoordinates: [CLLocationCoordinate2D] = [trackedPoints[0].coordinate]

        for i in 1..<trackedPoints.count {
            let point = trackedPoints[i]
            if point.gait == currentGait {
                currentCoordinates.append(point.coordinate)
            } else {
                // Finalize current segment
                if currentCoordinates.count > 1 {
                    segments.append(GaitRouteSegment(gait: currentGait, coordinates: currentCoordinates))
                }
                // Start new segment (include last point for continuity)
                currentGait = point.gait
                currentCoordinates = [trackedPoints[i-1].coordinate, point.coordinate]
            }
        }

        // Add final segment
        if currentCoordinates.count > 1 {
            segments.append(GaitRouteSegment(gait: currentGait, coordinates: currentCoordinates))
        }

        return segments
    }
}
