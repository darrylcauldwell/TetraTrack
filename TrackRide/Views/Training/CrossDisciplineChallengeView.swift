//
//  CrossDisciplineChallengeView.swift
//  TrackRide
//
//  Cross-Discipline Challenge Mode - combines skills from multiple disciplines
//  Helps athletes understand how skills transfer between disciplines.
//

import SwiftUI
import SwiftData

// MARK: - Challenge Types

enum ChallengeType: String, CaseIterable, Identifiable {
    case steadyUnderPressure = "Steady Under Pressure"
    case enduranceBlitz = "Endurance Blitz"
    case balanceMastery = "Balance Mastery"
    case rhythmAndTiming = "Rhythm & Timing"
    case mentalFortitude = "Mental Fortitude"
    case fullTetrathlon = "Full Tetrathlon"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .steadyUnderPressure: return "hand.raised.fill"
        case .enduranceBlitz: return "bolt.fill"
        case .balanceMastery: return "figure.stand"
        case .rhythmAndTiming: return "metronome.fill"
        case .mentalFortitude: return "brain.head.profile"
        case .fullTetrathlon: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .steadyUnderPressure: return .red
        case .enduranceBlitz: return .orange
        case .balanceMastery: return .purple
        case .rhythmAndTiming: return .blue
        case .mentalFortitude: return .teal
        case .fullTetrathlon: return .yellow
        }
    }

    var description: String {
        switch self {
        case .steadyUnderPressure:
            return "Shooting stability meets riding position"
        case .enduranceBlitz:
            return "Running stamina plus swimming endurance"
        case .balanceMastery:
            return "Riding balance with shooting stance"
        case .rhythmAndTiming:
            return "Running cadence meets swimming stroke"
        case .mentalFortitude:
            return "Breathing control across all disciplines"
        case .fullTetrathlon:
            return "Complete all four discipline drills"
        }
    }

    var disciplines: [Discipline] {
        switch self {
        case .steadyUnderPressure: return [.shooting, .riding]
        case .enduranceBlitz: return [.running, .swimming]
        case .balanceMastery: return [.riding, .shooting]
        case .rhythmAndTiming: return [.running, .swimming]
        case .mentalFortitude: return [.shooting, .riding, .running, .swimming]
        case .fullTetrathlon: return [.shooting, .riding, .running, .swimming]
        }
    }

    var drills: [UnifiedDrillType] {
        switch self {
        case .steadyUnderPressure:
            return [.steadyHold, .riderStillness, .dryFire]
        case .enduranceBlitz:
            return [.cadenceTraining, .swimmingCoreStability]
        case .balanceMastery:
            return [.singleLegBalance, .balanceBoard, .steadyHold]
        case .rhythmAndTiming:
            return [.cadenceTraining, .streamlinePosition]
        case .mentalFortitude:
            return [.boxBreathing, .mountedBreathing, .stressInoculation]
        case .fullTetrathlon:
            return [.dryFire, .coreStability, .cadenceTraining, .swimmingCoreStability]
        }
    }

    var estimatedDuration: TimeInterval {
        switch self {
        case .steadyUnderPressure: return 300 // 5 min
        case .enduranceBlitz: return 420 // 7 min
        case .balanceMastery: return 360 // 6 min
        case .rhythmAndTiming: return 360 // 6 min
        case .mentalFortitude: return 480 // 8 min
        case .fullTetrathlon: return 600 // 10 min
        }
    }

    var targetScore: Double {
        switch self {
        case .steadyUnderPressure: return 75
        case .enduranceBlitz: return 70
        case .balanceMastery: return 80
        case .rhythmAndTiming: return 70
        case .mentalFortitude: return 75
        case .fullTetrathlon: return 70
        }
    }
}

// MARK: - Challenge Progress

struct ChallengeProgress {
    var completedDrills: Int = 0
    var totalDrills: Int = 0
    var drillScores: [UnifiedDrillType: Double] = [:]
    var startTime: Date?
    var endTime: Date?

    var averageScore: Double {
        guard !drillScores.isEmpty else { return 0 }
        return drillScores.values.reduce(0, +) / Double(drillScores.count)
    }

    var totalDuration: TimeInterval {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }

    var isComplete: Bool {
        completedDrills >= totalDrills && totalDrills > 0
    }
}

// MARK: - Cross-Discipline Challenge View

struct CrossDisciplineChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UnifiedDrillSession.startDate, order: .reverse) private var sessions: [UnifiedDrillSession]

    @State private var selectedChallenge: ChallengeType?
    @State private var isInChallenge = false
    @State private var currentDrillIndex = 0
    @State private var progress = ChallengeProgress()
    @State private var showDrill = false
    @State private var currentDrill: UnifiedDrillType?
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            Group {
                if showResults {
                    challengeResultsView
                } else if isInChallenge, let challenge = selectedChallenge {
                    activeChallengeView(challenge)
                } else {
                    challengeSelectionView
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isInChallenge {
                        Button("Exit") {
                            exitChallenge()
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .fullScreenCover(item: $currentDrill) { drill in
                DrillViewFactory.view(for: drill, modelContext: modelContext)
                    .onDisappear {
                        handleDrillCompletion(drill)
                    }
            }
        }
    }

    // MARK: - Challenge Selection

    private var challengeSelectionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.yellow)

                    Text("Cross-Discipline Challenges")
                        .font(.title2.bold())

                    Text("Build skills that transfer across all four disciplines")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Challenge cards
                ForEach(ChallengeType.allCases) { challenge in
                    ChallengeCard(
                        challenge: challenge,
                        completedCount: completedChallengeCount(challenge),
                        bestScore: bestChallengeScore(challenge),
                        onStart: {
                            startChallenge(challenge)
                        }
                    )
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Active Challenge View

    private func activeChallengeView(_ challenge: ChallengeType) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Challenge header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(challenge.color.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: challenge.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(challenge.color)
                    }

                    Text(challenge.rawValue)
                        .font(.title2.bold())

                    // Discipline badges
                    HStack(spacing: 8) {
                        ForEach(challenge.disciplines, id: \.self) { discipline in
                            HStack(spacing: 4) {
                                Image(systemName: discipline.icon)
                                Text(discipline.displayName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(discipline.color.opacity(0.2))
                            .foregroundStyle(discipline.color)
                            .clipShape(Capsule())
                        }
                    }
                }

                // Progress
                VStack(spacing: 12) {
                    HStack {
                        Text("Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(progress.completedDrills) / \(progress.totalDrills)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                            RoundedRectangle(cornerRadius: 8)
                                .fill(challenge.color)
                                .frame(width: geo.size.width * progressPercent)
                                .animation(.easeInOut, value: progressPercent)
                        }
                    }
                    .frame(height: 12)

                    if progress.averageScore > 0 {
                        HStack {
                            Text("Average Score")
                            Spacer()
                            Text("\(Int(progress.averageScore))%")
                                .font(.headline)
                                .foregroundStyle(scoreColor(progress.averageScore))
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Drill list
                VStack(alignment: .leading, spacing: 16) {
                    Text("Drills")
                        .font(.headline)

                    ForEach(Array(challenge.drills.enumerated()), id: \.offset) { index, drill in
                        DrillProgressRow(
                            drill: drill,
                            index: index,
                            isComplete: progress.drillScores[drill] != nil,
                            score: progress.drillScores[drill],
                            isCurrent: index == currentDrillIndex && !progress.isComplete
                        )
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Next drill button
                if !progress.isComplete && currentDrillIndex < challenge.drills.count {
                    let drill = challenge.drills[currentDrillIndex]
                    Button {
                        currentDrill = drill
                    } label: {
                        HStack {
                            Image(systemName: drill.icon)
                            Text("Start \(drill.displayName)")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(challenge.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button {
                        showResults = true
                    } label: {
                        HStack {
                            Image(systemName: "trophy.fill")
                            Text("View Results")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Results View

    @ViewBuilder
    private var challengeResultsView: some View {
        if let challenge = selectedChallenge {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: progress.averageScore >= challenge.targetScore ? "trophy.fill" : "medal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(progress.averageScore >= challenge.targetScore ? .yellow : .gray)

                        Text(progress.averageScore >= challenge.targetScore ? "Challenge Complete!" : "Good Effort!")
                            .font(.title.bold())

                        Text("\(Int(progress.averageScore))%")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(progress.averageScore))

                        if progress.averageScore >= challenge.targetScore {
                            Text("You beat the target of \(Int(challenge.targetScore))%!")
                                .foregroundStyle(.green)
                        } else {
                            Text("Target: \(Int(challenge.targetScore))%")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Stats
                    VStack(spacing: 16) {
                        Text("Performance Breakdown")
                            .font(.headline)

                        ForEach(Array(progress.drillScores.keys.sorted(by: { $0.displayName < $1.displayName })), id: \.self) { drill in
                            if let score = progress.drillScores[drill] {
                                HStack {
                                    Image(systemName: drill.icon)
                                        .foregroundStyle(drill.color)
                                        .frame(width: 30)
                                    Text(drill.displayName)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(score))%")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(scoreColor(score))
                                }
                            }
                        }

                        Divider()

                        HStack {
                            Text("Total Time")
                            Spacer()
                            Text(formatDuration(progress.totalDuration))
                                .font(.subheadline.bold().monospacedDigit())
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Cross-training insight
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Cross-Training Insight")
                                .font(.headline)
                        }

                        Text(generateInsight(for: challenge))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            resetChallenge()
                        } label: {
                            Text("Try Again")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            exitChallenge()
                        } label: {
                            Text("Back to Challenges")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(challenge.color)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
        } else {
            EmptyView()
        }
    }

    // MARK: - Helper Views

    private var progressPercent: Double {
        guard progress.totalDrills > 0 else { return 0 }
        return Double(progress.completedDrills) / Double(progress.totalDrills)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .yellow }
        return .orange
    }

    // MARK: - Challenge Logic

    private func startChallenge(_ challenge: ChallengeType) {
        selectedChallenge = challenge
        isInChallenge = true
        currentDrillIndex = 0
        progress = ChallengeProgress()
        progress.totalDrills = challenge.drills.count
        progress.startTime = Date()
        showResults = false
    }

    private func handleDrillCompletion(_ drill: UnifiedDrillType) {
        // Get the most recent session for this drill type
        if let recentSession = sessions.first(where: { $0.drillType == drill }) {
            progress.drillScores[drill] = recentSession.score
        } else {
            // Default score if no session found
            progress.drillScores[drill] = 70
        }

        progress.completedDrills += 1
        currentDrillIndex += 1

        if progress.completedDrills >= progress.totalDrills {
            progress.endTime = Date()
        }
    }

    private func resetChallenge() {
        guard let challenge = selectedChallenge else { return }
        currentDrillIndex = 0
        progress = ChallengeProgress()
        progress.totalDrills = challenge.drills.count
        progress.startTime = Date()
        showResults = false
    }

    private func exitChallenge() {
        isInChallenge = false
        selectedChallenge = nil
        showResults = false
        progress = ChallengeProgress()
    }

    // MARK: - Data Helpers

    private func completedChallengeCount(_ challenge: ChallengeType) -> Int {
        // Count sessions that match challenge drills
        let challengeDrills = Set(challenge.drills)
        return sessions.filter { challengeDrills.contains($0.drillType) }.count
    }

    private func bestChallengeScore(_ challenge: ChallengeType) -> Double? {
        let challengeDrills = Set(challenge.drills)
        let relevantSessions = sessions.filter { challengeDrills.contains($0.drillType) }
        guard !relevantSessions.isEmpty else { return nil }
        return relevantSessions.map(\.score).max()
    }

    private func generateInsight(for challenge: ChallengeType) -> String {
        let avgScore = progress.averageScore

        switch challenge {
        case .steadyUnderPressure:
            if avgScore >= 80 {
                return "Excellent stability! Your shooting stance work is directly improving your riding position control."
            } else {
                return "Focus on breathing control - it's the common thread between shooting accuracy and riding stillness."
            }

        case .enduranceBlitz:
            if avgScore >= 80 {
                return "Great endurance! Your running cadence control translates directly to swimming rhythm."
            } else {
                return "Work on maintaining a steady pace in both disciplines - consistency builds endurance."
            }

        case .balanceMastery:
            if avgScore >= 80 {
                return "Strong balance skills! These core stability gains benefit both your seat and your shooting platform."
            } else {
                return "Single-leg balance work improves both riding aids and shooting stance stability."
            }

        case .rhythmAndTiming:
            if avgScore >= 80 {
                return "Excellent rhythm! Your cadence control creates efficient movement in both running and swimming."
            } else {
                return "Focus on finding your natural rhythm - it reduces energy expenditure in both disciplines."
            }

        case .mentalFortitude:
            if avgScore >= 80 {
                return "Outstanding mental control! Breathing techniques are your secret weapon across all disciplines."
            } else {
                return "Box breathing is your foundation - practice it daily to improve performance under pressure."
            }

        case .fullTetrathlon:
            if avgScore >= 80 {
                return "Competition ready! Your cross-discipline training shows excellent skill transfer."
            } else {
                return "Keep working all four disciplines - your weakest area often limits overall performance."
            }
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Challenge Card

private struct ChallengeCard: View {
    let challenge: ChallengeType
    let completedCount: Int
    let bestScore: Double?
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    Circle()
                        .fill(challenge.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: challenge.icon)
                        .font(.title2)
                        .foregroundStyle(challenge.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.rawValue)
                        .font(.headline)
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Discipline badges
                    HStack(spacing: 4) {
                        ForEach(challenge.disciplines, id: \.self) { discipline in
                            Image(systemName: discipline.icon)
                                .font(.caption)
                                .foregroundStyle(discipline.color)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let best = bestScore {
                        Text("\(Int(best))%")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("Best")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack {
                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("~\(Int(challenge.estimatedDuration / 60)) min")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                Spacer()

                // Drills count
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Text("\(challenge.drills.count) drills")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: onStart) {
                    Text("Start")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(challenge.color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Drill Progress Row

private struct DrillProgressRow: View {
    let drill: UnifiedDrillType
    let index: Int
    let isComplete: Bool
    let score: Double?
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(isCurrent ? drill.color : .secondary)
                }
            }

            // Drill info
            VStack(alignment: .leading, spacing: 2) {
                Text(drill.displayName)
                    .font(.subheadline)
                    .fontWeight(isCurrent ? .semibold : .regular)

                Text(drill.primaryDiscipline.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score or current indicator
            if let score = score {
                Text("\(Int(score))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(score >= 70 ? .green : .orange)
            } else if isCurrent {
                Text("Next")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(drill.color.opacity(0.2))
                    .foregroundStyle(drill.color)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if isComplete { return .green }
        if isCurrent { return drill.color }
        return .gray
    }
}

// MARK: - Preview

#Preview {
    CrossDisciplineChallengeView()
        .modelContainer(for: UnifiedDrillSession.self, inMemory: true)
}
