//
//  RouteWaypoint.swift
//  TetraTrack
//

import Foundation
import SwiftData
import CoreLocation

/// Type of waypoint in a planned route
enum WaypointType: String, Codable, CaseIterable {
    case start
    case via
    case end
    case avoid  // Route around this point

    var displayName: String {
        switch self {
        case .start: return "Start"
        case .via: return "Via"
        case .end: return "End"
        case .avoid: return "Avoid"
        }
    }

    var iconName: String {
        switch self {
        case .start: return "flag.fill"
        case .via: return "mappin"
        case .end: return "flag.checkered"
        case .avoid: return "xmark.circle.fill"
        }
    }
}

@Model
final class RouteWaypoint {
    // All properties have defaults for CloudKit compatibility
    var id: UUID = UUID()
    var latitude: Double = 0
    var longitude: Double = 0
    var orderIndex: Int = 0
    var waypointTypeValue: String = WaypointType.via.rawValue
    var name: String?
    var notes: String?

    // Parent route relationship
    var route: PlannedRoute?

    init() {}

    convenience init(
        coordinate: CLLocationCoordinate2D,
        type: WaypointType,
        orderIndex: Int,
        name: String? = nil
    ) {
        self.init()
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.waypointType = type
        self.orderIndex = orderIndex
        self.name = name
    }

    // MARK: - Computed Properties

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var waypointType: WaypointType {
        get { WaypointType(rawValue: waypointTypeValue) ?? .via }
        set { waypointTypeValue = newValue.rawValue }
    }

    var displayName: String {
        name ?? waypointType.displayName
    }
}
