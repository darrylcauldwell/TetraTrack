//
//  WatchSessionDiscipline.swift
//  TetraTrackShared
//
//  Discipline for active Watch connectivity session.
//  Shared between iPhone and Watch targets.
//

import Foundation

/// Discipline for active Watch connectivity session
public enum WatchSessionDiscipline: String, Sendable, Codable {
    case riding
    case walking
    case running
    case swimming
    case shooting
}
