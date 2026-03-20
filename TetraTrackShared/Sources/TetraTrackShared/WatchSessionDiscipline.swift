//
//  WatchSessionDiscipline.swift
//  TetraTrackShared
//
//  Discipline for active Watch connectivity session.
//  Single source of truth shared between iPhone and Watch.
//

import Foundation

public enum WatchSessionDiscipline: String, Codable, Sendable {
    case riding
    case walking
    case running
    case treadmill
    case swimming
    case shooting
}
