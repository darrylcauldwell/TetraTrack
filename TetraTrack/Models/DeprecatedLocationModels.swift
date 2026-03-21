//
//  DeprecatedLocationModels.swift
//  TetraTrack
//
//  SCHEMA-ONLY stubs for removed location point models.
//  These must remain in the schema to prevent CloudKit metadata
//  corruption during migration (ANSCKRECORDMETADATA UNIQUE constraint
//  violation). Do not use these models in new code.
//

import Foundation
import SwiftData

@available(*, deprecated, message: "Use GPSPoint instead")
@Model
final class LocationPoint {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    var timestamp: Date = Date()
    var horizontalAccuracy: Double = 0.0
    var speed: Double = 0.0

    init() {}
}

@available(*, deprecated, message: "Use GPSPoint instead")
@Model
final class RunningLocationPoint {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    var timestamp: Date = Date()
    var speed: Double = 0.0
    var horizontalAccuracy: Double = 0.0

    init() {}
}

@available(*, deprecated, message: "Use GPSPoint instead")
@Model
final class SwimmingLocationPoint {
    var id: UUID = UUID()
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var altitude: Double = 0.0
    var timestamp: Date = Date()
    var speed: Double = 0.0
    var horizontalAccuracy: Double = 0.0

    init() {}
}
