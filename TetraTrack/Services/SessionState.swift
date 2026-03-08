//
//  SessionState.swift
//  TetraTrack
//

import Foundation

enum SessionState: String, Codable {
    case idle
    case tracking
    case paused

    var isActive: Bool {
        self == .tracking || self == .paused
    }
}
