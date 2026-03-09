//
//  SessionState.swift
//  TetraTrack
//
//  Discipline-neutral session state, replacing RideState

import Foundation

enum SessionState: String, Codable {
    case idle       // No active session
    case tracking   // Currently recording
    case paused     // Session paused

    var isActive: Bool {
        self == .tracking || self == .paused
    }
}

// Backward compatibility — remove when Phases 2-4 complete
typealias RideState = SessionState
