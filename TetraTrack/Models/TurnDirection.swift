//
//  TurnDirection.swift
//  TetraTrack
//

import Foundation

enum TurnDirection: String, Codable {
    case left
    case right
    case straight
}

// Turn statistics for a ride
struct TurnStats {
    var totalLeftAngle: Double = 0  // degrees
    var totalRightAngle: Double = 0  // degrees

    var totalAngle: Double {
        totalLeftAngle + totalRightAngle
    }

    /// Angle-based balance (0.5 = balanced)
    var balance: Double {
        guard totalAngle > 0 else { return 0.5 }
        return totalLeftAngle / totalAngle
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
