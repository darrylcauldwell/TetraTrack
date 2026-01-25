//
//  UnifiedTrainingComponents.swift
//  TrackRide
//
//  Reusable components for the unified training view
//

import SwiftUI
import SwiftData

// MARK: - Unified Streak Banner

struct UnifiedStreakBanner: View {
    let sessions: [UnifiedDrillSession]

    private var currentStreak: Int {
        calculateStreak(from: sessions.map(\.startDate))
    }

    private var totalSessions: Int {
        sessions.count
    }

    private var thisWeekCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.startDate >= weekAgo }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            // Streak
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(currentStreak)")
                        .font(.title2.bold())
                }
                Text("Day Streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            // This Week
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                    Text("\(thisWeekCount)")
                        .font(.title2.bold())
                }
                Text("This Week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            // Total
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(totalSessions)")
                        .font(.title2.bold())
                }
                Text("Total Drills")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func calculateStreak(from dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let sortedDates = dates.sorted(by: >)  // Most recent first

        // Get unique days
        var uniqueDays = Set<DateComponents>()
        for date in sortedDates {
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            uniqueDays.insert(components)
        }

        let today = calendar.dateComponents([.year, .month, .day], from: Date())
        let yesterday = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: -1, to: Date())!)

        // Must have drilled today or yesterday to have active streak
        guard uniqueDays.contains(today) || uniqueDays.contains(yesterday) else { return 0 }

        var streak = 0
        var checkDate = today

        while uniqueDays.contains(checkDate) {
            streak += 1
            if let date = calendar.date(from: checkDate),
               let previousDate = calendar.date(byAdding: .day, value: -1, to: date) {
                checkDate = calendar.dateComponents([.year, .month, .day], from: previousDate)
            } else {
                break
            }
        }

        return streak
    }
}

// MARK: - Movement Pattern Transfer Card

struct MovementPatternTransferCard: View {
    let category: MovementCategory
    let sessions: [UnifiedDrillSession]

    private var categorySessions: [UnifiedDrillSession] {
        sessions.filter { $0.primaryCategory == category }
    }

    private var disciplinesUsed: Set<Discipline> {
        Set(categorySessions.map(\.primaryDiscipline))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
                Text(category.displayName)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(categorySessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Show which disciplines have used this category
            HStack(spacing: 4) {
                Text("Used in:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(Array(disciplinesUsed).filter { $0 != .all }, id: \.self) { discipline in
                    Image(systemName: discipline.icon)
                        .font(.caption2)
                        .foregroundStyle(discipline.color)
                }
            }

            // Transfer benefit message
            if disciplinesUsed.count > 1 {
                Text("Training transfers across \(disciplinesUsed.count) disciplines")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Empty Training State

struct EmptyTrainingState: View {
    let discipline: Discipline

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Start Your Training Journey")
                .font(.headline)

            if discipline == .all {
                Text("Complete drills across any discipline to build movement patterns that transfer to all sports.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Complete \(discipline.displayName.lowercased()) drills to improve your performance and unlock coaching insights.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let sessions: [UnifiedDrillSession]
    let timeframe: Timeframe

    enum Timeframe {
        case today, week, month, all

        var title: String {
            switch self {
            case .today: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            case .all: return "All Time"
            }
        }

        var dateFilter: Date {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.startOfDay(for: Date())
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            case .all:
                return .distantPast
            }
        }
    }

    private var filteredSessions: [UnifiedDrillSession] {
        sessions.filter { $0.startDate >= timeframe.dateFilter }
    }

    private var totalDuration: TimeInterval {
        filteredSessions.map(\.duration).reduce(0, +)
    }

    private var averageScore: Double {
        guard !filteredSessions.isEmpty else { return 0 }
        return filteredSessions.map(\.score).reduce(0, +) / Double(filteredSessions.count)
    }

    var body: some View {
        HStack {
            TrainingStatItem(
                icon: "number",
                value: "\(filteredSessions.count)",
                label: "Drills"
            )
            Spacer()
            TrainingStatItem(
                icon: "clock",
                value: formatDuration(totalDuration),
                label: "Time"
            )
            Spacer()
            TrainingStatItem(
                icon: "percent",
                value: String(format: "%.0f", averageScore),
                label: "Avg Score"
            )
        }
        .padding()
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

private struct TrainingStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Phone Placement Guidance

/// Enum defining phone placement recommendations for different drill types
enum PhonePlacement {
    case chestHeld          // Hold at chest with both hands
    case chestPocket        // Secure in chest pocket or bra band
    case armband            // Secure on upper arm
    case waistband          // Secure at waist
    case twoHandedGrip      // Two-handed grip simulating firearm
    case floorBeside        // Place on floor beside you
    case pronePlacement     // Place on lower back for prone exercises
    case poolside           // Place on poolside, waterproof case if needed

    var icon: String {
        switch self {
        case .chestHeld: return "hand.raised.fingers.spread"
        case .chestPocket: return "tshirt"
        case .armband: return "figure.strengthtraining.traditional"
        case .waistband: return "figure.walk"
        case .twoHandedGrip: return "hand.point.up.fill"
        case .floorBeside: return "iphone.gen3.radiowaves.left.and.right"
        case .pronePlacement: return "person.fill.turn.down"
        case .poolside: return "figure.pool.swim"
        }
    }

    var title: String {
        switch self {
        case .chestHeld: return "Hold at Chest"
        case .chestPocket: return "Chest Pocket"
        case .armband: return "Armband"
        case .waistband: return "Waistband"
        case .twoHandedGrip: return "Two-Handed Grip"
        case .floorBeside: return "Floor Beside You"
        case .pronePlacement: return "On Lower Back"
        case .poolside: return "Poolside"
        }
    }

    var description: String {
        switch self {
        case .chestHeld:
            return "Hold your phone at chest level with both hands, elbows relaxed at your sides. Keep a firm but not tight grip."
        case .chestPocket:
            return "Secure phone in a chest pocket, sports bra band, or running vest pocket. Ensure it won't move during the drill."
        case .armband:
            return "Use a sports armband on your upper arm. The screen should face outward, secure but not too tight."
        case .waistband:
            return "Place phone in a running belt or secure waistband pocket at your hip. Avoid loose pockets that allow bouncing."
        case .twoHandedGrip:
            return "Hold phone with both hands at eye level, as if aiming a firearm. Extend arms slightly with elbows unlocked."
        case .floorBeside:
            return "Place phone flat on the floor beside you, screen facing up. Keep it within arm's reach but out of your movement path."
        case .pronePlacement:
            return "Lie face down and place phone on your lower back. It should rest flat without sliding. You can also use a low stool."
        case .poolside:
            return "Place phone on the pool deck within view. Use a waterproof case if there's any splash risk."
        }
    }
}

/// Reusable view component for displaying phone placement guidance
struct PhonePlacementGuidanceView: View {
    let placement: PhonePlacement
    var compact: Bool = false

    var body: some View {
        if compact {
            HStack(spacing: 8) {
                Image(systemName: placement.icon)
                    .font(.body)
                    .foregroundStyle(.blue)
                Text(placement.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: placement.icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 32)
                    Text("Phone Placement")
                        .font(.subheadline.bold())
                }

                Text(placement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// Extension to map drill types to their recommended phone placement
extension UnifiedDrillType {
    var recommendedPhonePlacement: PhonePlacement {
        switch self {
        // Riding - mostly chest-held for torso stability measurement
        case .heelPosition, .stirrupPressure:
            return .chestPocket
        case .coreStability, .riderStillness, .extendedSeatHold, .mountedBreathing:
            return .chestHeld
        case .twoPoint:
            return .chestPocket
        case .balanceBoard:
            return .chestHeld
        case .hipMobility:
            return .waistband
        case .postingRhythm:
            return .chestPocket

        // Shooting - two-handed grip for aim simulation
        case .steadyHold, .dryFire, .recoilControl, .splitTime, .reactionTime:
            return .twoHandedGrip
        case .standingBalance, .posturalDrift:
            return .chestHeld
        case .boxBreathing:
            return .floorBeside
        case .stressInoculation:
            return .armband

        // Running - armband or waistband
        case .cadenceTraining, .plyometrics:
            return .armband
        case .runningHipMobility:
            return .waistband
        case .runningCoreStability:
            return .pronePlacement
        case .breathingPatterns:
            return .chestPocket
        case .singleLegBalance:
            return .chestHeld

        // Swimming - poolside or waterproof
        case .breathingRhythm, .kickEfficiency:
            return .poolside
        case .swimmingCoreStability:
            return .pronePlacement
        case .shoulderMobility:
            return .chestHeld
        case .streamlinePosition:
            return .floorBeside
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            UnifiedStreakBanner(sessions: [])

            EmptyTrainingState(discipline: .all)

            PhonePlacementGuidanceView(placement: .chestHeld)
            PhonePlacementGuidanceView(placement: .twoHandedGrip)
            PhonePlacementGuidanceView(placement: .armband, compact: true)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
