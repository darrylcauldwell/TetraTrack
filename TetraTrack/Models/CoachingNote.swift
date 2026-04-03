//
//  CoachingNote.swift
//  TetraTrack
//
//  A timestamped note from a trusted contact coaching a ride
//

import Foundation

nonisolated struct CoachingNote: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date
    var text: String
    var authorName: String

    init(timestamp: Date = Date(), text: String, authorName: String) {
        self.timestamp = timestamp
        self.text = text
        self.authorName = authorName
    }
}
