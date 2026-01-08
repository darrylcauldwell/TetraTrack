//
//  RideState.swift
//  TrackRide
//

import Foundation

enum RideState: String, Codable {
    case idle       // No active ride
    case tracking   // Currently recording
    case paused     // Ride paused (future feature)

    var isActive: Bool {
        self == .tracking || self == .paused
    }
}
