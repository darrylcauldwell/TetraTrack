//
//  AdaptiveDifficultyService.swift
//  TetraTrack
//
//  Automatically adjusts drill difficulty based on user performance history.
//  Provides progressive challenge to ensure continuous improvement.
//

import Foundation
import SwiftData
import Observation

/// Difficulty level for drills
enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"

    var multiplier: Double {
        switch self {
        case .beginner: return 0.7
        case .intermediate: return 1.0
        case .advanced: return 1.3
        case .expert: return 1.6
        }
    }

    var nextLevel: DifficultyLevel? {
        switch self {
        case .beginner: return .intermediate
        case .intermediate: return .advanced
        case .advanced: return .expert
        case .expert: return nil
        }
    }

    var previousLevel: DifficultyLevel? {
        switch self {
        case .beginner: return nil
        case .intermediate: return .beginner
        case .advanced: return .intermediate
        case .expert: return .advanced
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced: return "3.circle.fill"
        case .expert: return "star.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .expert: return "purple"
        }
    }
}

/// Adaptive difficulty settings for a specific drill type
struct AdaptiveDrillSettings {
    let drillType: UnifiedDrillType
    let currentLevel: DifficultyLevel
    let suggestedDuration: TimeInterval
    let suggestedReps: Int
    let targetStability: Double
    let targetScore: Double
    let progressToNextLevel: Double  // 0-1
    let canLevelUp: Bool
    let canLevelDown: Bool
}

/// Service for managing adaptive difficulty across all drills
@Observable
final class AdaptiveDifficultyService {

    // MARK: - Configuration

    /// Number of recent sessions to consider for difficulty adjustment
    private let recentSessionCount = 5

    /// Score threshold for level up consideration (out of 100)
    private let levelUpThreshold: Double = 80

    /// Score threshold for level down consideration (out of 100)
    private let levelDownThreshold: Double = 40

    /// Minimum sessions at current level before allowing level up
    private let minSessionsForLevelUp = 3

    /// Consistency requirement for level up (ratio of successful sessions)
    private let levelUpConsistencyRatio: Double = 0.8

    // MARK: - Public Interface

    /// Get adaptive settings for a drill type based on user history
    func getSettings(for drillType: UnifiedDrillType, sessions: [UnifiedDrillSession]) -> AdaptiveDrillSettings {
        let relevantSessions = sessions
            .filter { $0.drillType == drillType }
            .sorted { $0.startDate > $1.startDate }
            .prefix(recentSessionCount)

        let currentLevel = determineLevel(from: Array(relevantSessions))
        let progressToNext = calculateProgress(Array(relevantSessions), at: currentLevel)

        return AdaptiveDrillSettings(
            drillType: drillType,
            currentLevel: currentLevel,
            suggestedDuration: suggestedDuration(for: drillType, at: currentLevel),
            suggestedReps: suggestedReps(for: drillType, at: currentLevel),
            targetStability: targetStability(for: drillType, at: currentLevel),
            targetScore: targetScore(for: drillType, at: currentLevel),
            progressToNextLevel: progressToNext,
            canLevelUp: currentLevel.nextLevel != nil && progressToNext >= 1.0,
            canLevelDown: currentLevel.previousLevel != nil && shouldLevelDown(Array(relevantSessions))
        )
    }

    /// Get recommended difficulty level for a new user or drill they haven't tried
    func getDefaultLevel(for drillType: UnifiedDrillType) -> DifficultyLevel {
        // Start most users at intermediate
        // Some drills that are inherently harder start at beginner
        switch drillType {
        case .extendedSeatHold, .posturalDrift, .stressInoculation:
            return .beginner
        default:
            return .intermediate
        }
    }

    /// Update user's level after completing a session
    func shouldLevelUp(after session: UnifiedDrillSession, recentSessions: [UnifiedDrillSession]) -> Bool {
        let settings = getSettings(for: session.drillType, sessions: recentSessions + [session])
        return settings.canLevelUp
    }

    /// Check if user should level down after poor performance
    func shouldLevelDown(after session: UnifiedDrillSession, recentSessions: [UnifiedDrillSession]) -> Bool {
        let settings = getSettings(for: session.drillType, sessions: recentSessions + [session])
        return settings.canLevelDown
    }

    // MARK: - Level Determination

    private func determineLevel(from sessions: [UnifiedDrillSession]) -> DifficultyLevel {
        guard !sessions.isEmpty else { return .intermediate }

        // Calculate average score
        let avgScore = sessions.map(\.score).reduce(0, +) / Double(sessions.count)

        // Determine level based on consistent performance
        if avgScore >= 90 && sessions.count >= minSessionsForLevelUp {
            let highScoreRatio = Double(sessions.filter { $0.score >= levelUpThreshold }.count) / Double(sessions.count)
            if highScoreRatio >= levelUpConsistencyRatio {
                return .expert
            }
            return .advanced
        } else if avgScore >= 75 {
            return .advanced
        } else if avgScore >= 55 {
            return .intermediate
        } else {
            return .beginner
        }
    }

    private func calculateProgress(_ sessions: [UnifiedDrillSession], at level: DifficultyLevel) -> Double {
        guard !sessions.isEmpty else { return 0 }
        guard level.nextLevel != nil else { return 1.0 }

        // Progress is based on:
        // 1. Number of sessions at or above threshold (40% weight)
        // 2. Average score relative to threshold (40% weight)
        // 3. Consistency/trend (20% weight)

        let successfulSessions = Double(sessions.filter { $0.score >= levelUpThreshold }.count)
        let sessionProgress = min(1.0, successfulSessions / Double(minSessionsForLevelUp))

        let avgScore = sessions.map(\.score).reduce(0, +) / Double(sessions.count)
        let scoreProgress = min(1.0, avgScore / levelUpThreshold)

        // Trend: compare first half to second half
        let trendProgress: Double
        if sessions.count >= 4 {
            let midpoint = sessions.count / 2
            let recentAvg = sessions.prefix(midpoint).map(\.score).reduce(0, +) / Double(midpoint)
            let olderAvg = sessions.suffix(sessions.count - midpoint).map(\.score).reduce(0, +) / Double(sessions.count - midpoint)
            trendProgress = recentAvg >= olderAvg ? 1.0 : 0.5
        } else {
            trendProgress = 0.5
        }

        return sessionProgress * 0.4 + scoreProgress * 0.4 + trendProgress * 0.2
    }

    private func shouldLevelDown(_ sessions: [UnifiedDrillSession]) -> Bool {
        guard sessions.count >= 3 else { return false }

        let recentThree = sessions.prefix(3)
        let avgScore = recentThree.map(\.score).reduce(0, +) / Double(recentThree.count)
        let allBelow = recentThree.allSatisfy { $0.score < levelDownThreshold }

        return allBelow || avgScore < levelDownThreshold
    }

    // MARK: - Parameter Calculations

    private func suggestedDuration(for drillType: UnifiedDrillType, at level: DifficultyLevel) -> TimeInterval {
        let baseDuration = drillType.suggestedDuration

        switch level {
        case .beginner:
            return baseDuration * 0.7
        case .intermediate:
            return baseDuration
        case .advanced:
            return baseDuration * 1.25
        case .expert:
            return baseDuration * 1.5
        }
    }

    private func suggestedReps(for drillType: UnifiedDrillType, at level: DifficultyLevel) -> Int {
        // Base reps for drill types that use reps
        let baseReps: Int
        switch drillType {
        case .plyometrics:
            baseReps = 10
        case .dryFire:
            baseReps = 10
        case .reactionTime, .splitTime:
            baseReps = 5
        default:
            baseReps = 5
        }

        switch level {
        case .beginner:
            return max(3, Int(Double(baseReps) * 0.6))
        case .intermediate:
            return baseReps
        case .advanced:
            return Int(Double(baseReps) * 1.4)
        case .expert:
            return Int(Double(baseReps) * 1.8)
        }
    }

    private func targetStability(for drillType: UnifiedDrillType, at level: DifficultyLevel) -> Double {
        // Base target stability for passing score
        let baseTarget: Double
        switch drillType.primaryCategory {
        case .stability, .balance:
            baseTarget = 70
        case .endurance:
            baseTarget = 65
        default:
            baseTarget = 60
        }

        switch level {
        case .beginner:
            return baseTarget - 10
        case .intermediate:
            return baseTarget
        case .advanced:
            return baseTarget + 10
        case .expert:
            return baseTarget + 15
        }
    }

    private func targetScore(for drillType: UnifiedDrillType, at level: DifficultyLevel) -> Double {
        switch level {
        case .beginner:
            return 60
        case .intermediate:
            return 70
        case .advanced:
            return 80
        case .expert:
            return 90
        }
    }
}

// MARK: - SwiftUI View Extension for Displaying Difficulty

import SwiftUI

struct DifficultyBadgeView: View {
    let level: DifficultyLevel
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
            if !compact {
                Text(level.rawValue)
            }
        }
        .font(compact ? .caption : .subheadline)
        .foregroundStyle(levelColor)
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(levelColor.opacity(0.2))
        .clipShape(Capsule())
    }

    private var levelColor: Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .expert: return .purple
        }
    }
}

struct DifficultyProgressView: View {
    let settings: AdaptiveDrillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DifficultyBadgeView(level: settings.currentLevel)
                Spacer()
                if settings.canLevelUp {
                    Label("Ready to level up!", systemImage: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if let nextLevel = settings.currentLevel.nextLevel {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress to \(nextLevel.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(settings.progressToNextLevel * 100))%")
                            .font(.caption.bold())
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(settings.progressToNextLevel >= 1.0 ? Color.green : Color.blue)
                                .frame(width: geo.size.width * settings.progressToNextLevel)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(DifficultyLevel.allCases, id: \.rawValue) { level in
            DifficultyBadgeView(level: level)
        }

        DifficultyProgressView(settings: AdaptiveDrillSettings(
            drillType: .coreStability,
            currentLevel: .intermediate,
            suggestedDuration: 60,
            suggestedReps: 10,
            targetStability: 70,
            targetScore: 70,
            progressToNextLevel: 0.65,
            canLevelUp: false,
            canLevelDown: false
        ))
        .padding()
    }
}
