//
//  DressageTestExecution.swift
//  TetraTrack
//
//  Records a practice run through a dressage test with per-movement scores
//

import Foundation

nonisolated struct DressageMovement: Codable, Identifiable {
    var id: Int { number }
    var number: Int
    var marker: String
    var instruction: String
    var maxMark: Int = 10
    var coefficient: Int = 1
}

nonisolated struct DressageMovementScore: Codable, Identifiable {
    var id: Int { movementNumber }
    var movementNumber: Int
    var score: Int?  // 0-10, nil if not scored
    var notes: String = ""
}

nonisolated struct DressageTestExecution: Codable {
    var testName: String
    var movementScores: [DressageMovementScore]
    var totalScore: Double {
        let scored = movementScores.compactMap { $0.score }
        return scored.reduce(0) { Double($0) + Double($1) }
    }
    var maxPossibleScore: Double
    var percentage: Double {
        guard maxPossibleScore > 0 else { return 0 }
        return (totalScore / maxPossibleScore) * 100
    }
    var timestamp: Date = Date()
}
