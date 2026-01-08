//
//  TurnDirection.swift
//  TrackRide
//

import Foundation

enum TurnDirection: String, Codable {
    case left
    case right
    case straight
}

// Turn statistics for a ride
struct TurnStats {
    var leftTurns: Int = 0
    var rightTurns: Int = 0
    var totalLeftAngle: Double = 0  // degrees
    var totalRightAngle: Double = 0  // degrees

    var balance: Double {
        let total = leftTurns + rightTurns
        guard total > 0 else { return 0.5 }
        return Double(leftTurns) / Double(total)
    }

    var balanceDescription: String {
        let leftPercent = Int(balance * 100)
        let rightPercent = 100 - leftPercent
        return "\(leftPercent)% Left / \(rightPercent)% Right"
    }

    var isBalanced: Bool {
        balance >= 0.4 && balance <= 0.6
    }
}
