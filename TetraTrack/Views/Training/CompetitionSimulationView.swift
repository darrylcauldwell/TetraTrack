//
//  CompetitionSimulationView.swift
//  TetraTrack
//
//  Competition Day Simulation - practice performing under competition conditions
//  Simulates the full tetrathlon/triathlon experience with timed disciplines and transitions.
//

import SwiftUI
import SwiftData

// MARK: - Simulation Phase

enum SimulationPhase: String, CaseIterable {
    case briefing = "Briefing"
    case warmup = "Warm Up"
    case shooting = "Shooting"
    case transitionToRun = "Transition to Run"
    case running = "Running"
    case transitionToSwim = "Transition to Swim"
    case swimming = "Swimming"
    case cooldown = "Cool Down"
    case results = "Results"

    var icon: String {
        switch self {
        case .briefing: return "clipboard"
        case .warmup: return "figure.walk"
        case .shooting: return "target"
        case .transitionToRun, .transitionToSwim: return "arrow.right"
        case .running: return "figure.run"
        case .swimming: return "figure.pool.swim"
        case .cooldown: return "heart"
        case .results: return "trophy"
        }
    }

    var color: Color {
        switch self {
        case .briefing: return .gray
        case .warmup: return .orange
        case .shooting: return .red
        case .transitionToRun, .transitionToSwim: return .purple
        case .running: return .green
        case .swimming: return .blue
        case .cooldown: return .teal
        case .results: return .yellow
        }
    }

    var duration: TimeInterval {
        switch self {
        case .briefing: return 60 // 1 minute
        case .warmup: return 180 // 3 minutes
        case .shooting: return 120 // 2 minutes (simulated)
        case .transitionToRun: return 60 // 1 minute transition
        case .running: return 300 // 5 minutes (virtual pacer)
        case .transitionToSwim: return 120 // 2 minute transition
        case .swimming: return 180 // 3 minutes
        case .cooldown: return 120 // 2 minutes
        case .results: return 0 // No time limit
        }
    }

    var tips: [String] {
        switch self {
        case .briefing:
            return [
                "Check your equipment is ready",
                "Review your targets for each discipline",
                "Mental preparation - visualize success"
            ]
        case .warmup:
            return [
                "Light jogging and stretching",
                "Practice breathing techniques",
                "Get your heart rate up gradually"
            ]
        case .shooting:
            return [
                "Control your breathing",
                "Focus on stance stability",
                "Smooth trigger pull",
                "Follow through each shot"
            ]
        case .transitionToRun:
            return [
                "Stay calm - you have time",
                "Focus on your running strategy",
                "Light movement to stay loose"
            ]
        case .running:
            return [
                "Start at a sustainable pace",
                "Control your breathing",
                "Stay mentally focused",
                "Push through the finish"
            ]
        case .transitionToSwim:
            return [
                "Hydrate if needed",
                "Prepare mentally for the swim",
                "Keep your muscles warm"
            ]
        case .swimming:
            return [
                "Strong streamline off the wall",
                "Consistent stroke rate",
                "Efficient turns",
                "Strong finish!"
            ]
        case .cooldown:
            return [
                "Walk to lower heart rate",
                "Light stretching",
                "Reflect on your performance"
            ]
        case .results:
            return []
        }
    }
}

// MARK: - Simulation Results

struct SimulationResults {
    var shootingScore: Int = 0
    var shootingAccuracy: Double = 0
    var runningTime: TimeInterval = 0
    var runningPace: TimeInterval = 0
    var swimmingTime: TimeInterval = 0
    var swimmingDistance: Double = 0
    var totalSimulationTime: TimeInterval = 0
    var mentalFocusScore: Double = 0 // 0-100 based on stability during drills

    var overallScore: Double {
        // Weighted average of discipline performance
        let shootingPart = shootingAccuracy * 0.33
        let runningPart = min(100, max(0, (600 - runningTime) / 6)) * 0.33 // 5min target
        let swimmingPart = min(100, max(0, (180 - swimmingTime) / 1.8)) * 0.34 // 3min target
        return shootingPart + runningPart + swimmingPart
    }

    var grade: String {
        if overallScore >= 90 { return "Competition Ready!" }
        if overallScore >= 75 { return "Strong Performance" }
        if overallScore >= 60 { return "Good Effort" }
        if overallScore >= 40 { return "Keep Practicing" }
        return "Building Foundation"
    }

    var gradeColor: Color {
        if overallScore >= 90 { return .green }
        if overallScore >= 75 { return .blue }
        if overallScore >= 60 { return .yellow }
        return .orange
    }
}

// MARK: - Competition Simulation View

struct CompetitionSimulationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var currentPhase: SimulationPhase = .briefing
    @State private var phaseTimeRemaining: TimeInterval = 60
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var results = SimulationResults()
    @State private var simulationStartTime: Date?
    @State private var showSkipAlert = false

    // Drill states
    @State private var showShootingDrill = false
    @State private var showRunningDrill = false
    @State private var showSwimmingDrill = false

    // Discipline scores passed back from drill views
    @State private var shootingComplete = false
    @State private var runningComplete = false
    @State private var swimmingComplete = false

    let competitionLevel: CompetitionLevel

    init(level: CompetitionLevel = .junior) {
        self.competitionLevel = level
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Phase-specific background color
                currentPhase.color.opacity(0.1)
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: currentPhase)

                VStack(spacing: 0) {
                    // Progress indicator
                    phaseProgressBar

                    // Main content
                    ScrollView {
                        VStack(spacing: 24) {
                            phaseHeader

                            if currentPhase == .results {
                                resultsView
                            } else {
                                activePhaseContent
                            }
                        }
                        .padding()
                    }

                    // Bottom action area
                    if currentPhase != .results {
                        bottomActionBar
                    }
                }
            }
            .navigationTitle("Competition Simulation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Exit") {
                        showSkipAlert = true
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    levelBadge
                }
            }
            .alert("Exit Simulation?", isPresented: $showSkipAlert) {
                Button("Continue", role: .cancel) { }
                Button("Exit", role: .destructive) {
                    cleanup()
                    dismiss()
                }
            } message: {
                Text("Your progress will not be saved.")
            }
            .fullScreenCover(isPresented: $showShootingDrill) {
                SimulatedShootingDrillView(
                    onComplete: { score, accuracy in
                        results.shootingScore = score
                        results.shootingAccuracy = accuracy
                        shootingComplete = true
                        advancePhase()
                    }
                )
            }
            .fullScreenCover(isPresented: $showRunningDrill) {
                SimulatedRunningDrillView(
                    targetDistance: competitionLevel.runDistance,
                    onComplete: { time, pace in
                        results.runningTime = time
                        results.runningPace = pace
                        runningComplete = true
                        advancePhase()
                    }
                )
            }
            .fullScreenCover(isPresented: $showSwimmingDrill) {
                SimulatedSwimmingDrillView(
                    targetDuration: competitionLevel.swimDuration,
                    onComplete: { time, distance in
                        results.swimmingTime = time
                        results.swimmingDistance = distance
                        swimmingComplete = true
                        advancePhase()
                    }
                )
            }
        }
        .onDisappear {
            cleanup()
        }
    }

    // MARK: - Progress Bar

    private var phaseProgressBar: some View {
        let phases = SimulationPhase.allCases
        let currentIndex = phases.firstIndex(of: currentPhase) ?? 0
        let progress = Double(currentIndex) / Double(phases.count - 1)

        return VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentPhase.color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 8)

            HStack {
                ForEach(Array(phases.enumerated()), id: \.element.rawValue) { index, phase in
                    if phase != .transitionToRun && phase != .transitionToSwim {
                        VStack(spacing: 4) {
                            Image(systemName: phase.icon)
                                .font(.caption2)
                                .foregroundStyle(index <= currentIndex ? phase.color : .gray)
                        }
                        if index < phases.count - 1 && phase != .cooldown {
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding()
    }

    // MARK: - Phase Header

    private var phaseHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(currentPhase.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: currentPhase.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(currentPhase.color)
            }

            Text(currentPhase.rawValue)
                .font(.title.bold())

            if currentPhase.duration > 0 && currentPhase != .results {
                Text(timeString(phaseTimeRemaining))
                    .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(phaseTimeRemaining < 30 ? .red : .primary)
            }
        }
    }

    // MARK: - Active Phase Content

    private var activePhaseContent: some View {
        VStack(spacing: 20) {
            // Tips for current phase
            if !currentPhase.tips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tips")
                        .font(.headline)

                    ForEach(currentPhase.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(currentPhase.color)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Phase-specific content
            switch currentPhase {
            case .briefing:
                briefingContent
            case .warmup:
                warmupContent
            case .shooting:
                disciplineInstructions(
                    title: "Shooting Phase",
                    description: "10 shots in 60 seconds\nFocus on stability and accuracy",
                    actionLabel: "Start Shooting Drill"
                ) {
                    showShootingDrill = true
                }
            case .transitionToRun:
                transitionContent(nextDiscipline: "Running")
            case .running:
                disciplineInstructions(
                    title: "Running Phase",
                    description: "\(competitionLevel.formattedRunDistance) virtual run\nPace yourself wisely",
                    actionLabel: "Start Running Drill"
                ) {
                    showRunningDrill = true
                }
            case .transitionToSwim:
                transitionContent(nextDiscipline: "Swimming")
            case .swimming:
                disciplineInstructions(
                    title: "Swimming Phase",
                    description: "\(competitionLevel.formattedSwimDuration) timed swim\nEfficient strokes, strong finish",
                    actionLabel: "Start Swimming Drill"
                ) {
                    showSwimmingDrill = true
                }
            case .cooldown:
                cooldownContent
            case .results:
                EmptyView() // Handled separately
            }
        }
    }

    // MARK: - Phase-Specific Content

    private var briefingContent: some View {
        VStack(spacing: 16) {
            Text("Competition Format")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(.red)
                    Text("Shooting - 10 shots")
                    Spacer()
                }
                HStack {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.green)
                    Text("Running - \(competitionLevel.formattedRunDistance)")
                    Spacer()
                }
                HStack {
                    Image(systemName: "figure.pool.swim")
                        .foregroundStyle(.blue)
                    Text("Swimming - \(competitionLevel.formattedSwimDuration)")
                    Spacer()
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Transitions are timed - stay focused!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var warmupContent: some View {
        VStack(spacing: 16) {
            Text("Prepare Your Body & Mind")
                .font(.headline)

            HStack(spacing: 20) {
                warmupStat(icon: "heart.fill", value: "Elevate", label: "Heart Rate")
                warmupStat(icon: "lungs.fill", value: "Control", label: "Breathing")
                warmupStat(icon: "brain.head.profile", value: "Focus", label: "Mental")
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func warmupStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func transitionContent(nextDiscipline: String) -> some View {
        VStack(spacing: 16) {
            Text("Transition to \(nextDiscipline)")
                .font(.headline)

            Text("Use this time wisely:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                VStack {
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("Hydrate")
                        .font(.caption)
                }
                VStack {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundStyle(.purple)
                    Text("Reset Focus")
                        .font(.caption)
                }
                VStack {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text("Stay Warm")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cooldownContent: some View {
        VStack(spacing: 16) {
            Text("Recovery Time")
                .font(.headline)

            Text("You've completed all disciplines!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Quick stats preview
            VStack(alignment: .leading, spacing: 8) {
                if shootingComplete {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.red)
                        Text("Shooting: \(results.shootingScore) pts")
                        Spacer()
                    }
                }
                if runningComplete {
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundStyle(.green)
                        Text("Running: \(timeString(results.runningTime))")
                        Spacer()
                    }
                }
                if swimmingComplete {
                    HStack {
                        Image(systemName: "figure.pool.swim")
                            .foregroundStyle(.blue)
                        Text("Swimming: \(timeString(results.swimmingTime))")
                        Spacer()
                    }
                }
            }
            .font(.subheadline)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func disciplineInstructions(
        title: String,
        description: String,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(currentPhase.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 24) {
            // Overall grade
            VStack(spacing: 8) {
                Text("\(Int(results.overallScore))%")
                    .scaledFont(size: 72, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .foregroundStyle(results.gradeColor)

                Text(results.grade)
                    .font(.title2.bold())
                    .foregroundStyle(results.gradeColor)
            }

            // Discipline breakdown
            VStack(spacing: 16) {
                Text("Discipline Breakdown")
                    .font(.headline)

                HStack(spacing: 16) {
                    resultCard(
                        icon: "target",
                        color: .red,
                        title: "Shooting",
                        value: "\(results.shootingScore)",
                        subtitle: "\(Int(results.shootingAccuracy))% accuracy"
                    )
                    resultCard(
                        icon: "figure.run",
                        color: .green,
                        title: "Running",
                        value: timeString(results.runningTime),
                        subtitle: "pace \(paceString(results.runningPace))"
                    )
                    resultCard(
                        icon: "figure.pool.swim",
                        color: .blue,
                        title: "Swimming",
                        value: timeString(results.swimmingTime),
                        subtitle: "\(Int(results.swimmingDistance))m"
                    )
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Total time
            HStack {
                Text("Total Simulation Time")
                Spacer()
                Text(timeString(results.totalSimulationTime))
                    .font(.headline.monospacedDigit())
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Actions
            VStack(spacing: 12) {
                Button {
                    resetSimulation()
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func resultCard(icon: String, color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            if !isRunning && currentPhase != .results {
                Button {
                    startPhase()
                } label: {
                    Text(currentPhase == .briefing ? "Begin Simulation" : "Start \(currentPhase.rawValue)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(currentPhase.color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else if isRunning {
                Button {
                    skipPhase()
                } label: {
                    Text("Skip Phase")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
    }

    // MARK: - Level Badge

    private var levelBadge: some View {
        Text(competitionLevel.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.purple.opacity(0.2))
            .foregroundStyle(.purple)
            .clipShape(Capsule())
    }

    // MARK: - Timer Logic

    private func startPhase() {
        if simulationStartTime == nil {
            simulationStartTime = Date()
        }

        isRunning = true
        phaseTimeRemaining = currentPhase.duration

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if phaseTimeRemaining > 0 {
                phaseTimeRemaining -= 1
            } else {
                advancePhase()
            }
        }
    }

    private func skipPhase() {
        advancePhase()
    }

    private func advancePhase() {
        timer?.invalidate()
        timer = nil
        isRunning = false

        let phases = SimulationPhase.allCases
        if let currentIndex = phases.firstIndex(of: currentPhase),
           currentIndex < phases.count - 1 {
            currentPhase = phases[currentIndex + 1]
            phaseTimeRemaining = currentPhase.duration

            // Auto-start transitions
            if currentPhase == .transitionToRun || currentPhase == .transitionToSwim || currentPhase == .cooldown {
                startPhase()
            }

            // Calculate total time when reaching results
            if currentPhase == .results, let start = simulationStartTime {
                results.totalSimulationTime = Date().timeIntervalSince(start)
            }
        }
    }

    private func resetSimulation() {
        cleanup()
        currentPhase = .briefing
        phaseTimeRemaining = 60
        results = SimulationResults()
        simulationStartTime = nil
        shootingComplete = false
        runningComplete = false
        swimmingComplete = false
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // MARK: - Helpers

    private func timeString(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func paceString(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }
}

// MARK: - Simulated Shooting Drill

struct SimulatedShootingDrillView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var shotsFired = 0
    @State private var score = 0
    @State private var timeRemaining: TimeInterval = 60
    @State private var isActive = false
    @State private var timer: Timer?
    @State private var showTarget = false
    @State private var lastShotScore = 0

    let totalShots = 10
    let onComplete: (Int, Double) -> Void

    var body: some View {
        ZStack {
            Color.red.opacity(0.1).ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Shooting Drill")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.0fs", timeRemaining))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(timeRemaining < 15 ? .red : .primary)
                }
                .padding()

                Spacer()

                if !isActive {
                    VStack(spacing: 16) {
                        Image(systemName: "target")
                            .scaledFont(size: 80, relativeTo: .largeTitle)
                            .foregroundStyle(.red)
                        Text("10 shots in 60 seconds")
                            .font(.title2)
                        Text("Tap anywhere to fire")
                            .foregroundStyle(.secondary)

                        Button("Start") {
                            startDrill()
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.red)
                        .clipShape(Capsule())
                    }
                } else if shotsFired >= totalShots {
                    // Results
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .scaledFont(size: 60, relativeTo: .largeTitle)
                            .foregroundStyle(.green)
                        Text("Complete!")
                            .font(.title.bold())
                        Text("Score: \(score) / \(totalShots * 10)")
                            .font(.title2)
                        Text("Accuracy: \(Int(Double(score) / Double(totalShots)))%")
                            .foregroundStyle(.secondary)

                        Button("Continue") {
                            onComplete(score, Double(score) / Double(totalShots))
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.green)
                        .clipShape(Capsule())
                    }
                } else {
                    // Active shooting
                    VStack(spacing: 20) {
                        Text("Shot \(shotsFired + 1) of \(totalShots)")
                            .font(.headline)

                        // Target
                        ZStack {
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                                .frame(width: 200, height: 200)
                            Circle()
                                .stroke(Color.red.opacity(0.5), lineWidth: 3)
                                .frame(width: 150, height: 150)
                            Circle()
                                .stroke(Color.red.opacity(0.7), lineWidth: 2)
                                .frame(width: 100, height: 100)
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: 50, height: 50)
                            Circle()
                                .fill(Color.red)
                                .frame(width: 20, height: 20)

                            if lastShotScore > 0 {
                                Text("+\(lastShotScore)")
                                    .font(.title.bold())
                                    .foregroundStyle(.green)
                                    .offset(y: -120)
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            fireShot()
                        }

                        Text("Score: \(score)")
                            .font(.title2.bold().monospacedDigit())
                    }
                }

                Spacer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startDrill() {
        isActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                finishDrill()
            }
        }
    }

    private func fireShot() {
        guard shotsFired < totalShots else { return }

        // Simulate shot score (6-10 typical range)
        let shotScore = Int.random(in: 6...10)
        lastShotScore = shotScore
        score += shotScore
        shotsFired += 1

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        if shotsFired >= totalShots {
            timer?.invalidate()
        }
    }

    private func finishDrill() {
        timer?.invalidate()
        // Fill remaining shots with 0
        while shotsFired < totalShots {
            shotsFired += 1
        }
    }
}

// MARK: - Simulated Running Drill

struct SimulatedRunningDrillView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var isRunning = false
    @State private var isComplete = false
    @State private var timer: Timer?
    @State private var virtualDistance: Double = 0

    let targetDistance: Double
    let onComplete: (TimeInterval, TimeInterval) -> Void

    var body: some View {
        ZStack {
            Color.green.opacity(0.1).ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("Running Drill")
                        .font(.headline)
                    Spacer()
                    Button("Skip") {
                        finishDrill()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()

                Spacer()

                if !isRunning && !isComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .scaledFont(size: 80, relativeTo: .largeTitle)
                            .foregroundStyle(.green)
                        Text("Virtual \(Int(targetDistance))m Run")
                            .font(.title2)
                        Text("Tap to simulate running pace")
                            .foregroundStyle(.secondary)

                        Button("Start") {
                            startDrill()
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.green)
                        .clipShape(Capsule())
                    }
                } else if isComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .scaledFont(size: 60, relativeTo: .largeTitle)
                            .foregroundStyle(.green)
                        Text("Complete!")
                            .font(.title.bold())
                        Text(timeString(elapsedTime))
                            .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)

                        let pace = elapsedTime / (targetDistance / 1000)
                        Text("Pace: \(paceString(pace))/km")
                            .foregroundStyle(.secondary)

                        Button("Continue") {
                            onComplete(elapsedTime, pace)
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.green)
                        .clipShape(Capsule())
                    }
                } else {
                    VStack(spacing: 20) {
                        Text(timeString(elapsedTime))
                            .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                            .monospacedDigit()

                        // Progress
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green)
                                        .frame(width: geo.size.width * (virtualDistance / targetDistance))
                                }
                            }
                            .frame(height: 16)

                            Text("\(Int(virtualDistance))m / \(Int(targetDistance))m")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 40)

                        Text("Tap rhythmically to maintain pace")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Tap area
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green.opacity(0.3))
                            .frame(height: 150)
                            .overlay {
                                VStack {
                                    Image(systemName: "hand.tap.fill")
                                        .font(.largeTitle)
                                    Text("TAP")
                                        .font(.headline)
                                }
                                .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 40)
                            .onTapGesture {
                                runStep()
                            }
                    }
                }

                Spacer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startDrill() {
        isRunning = true
        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)
        }
    }

    private func runStep() {
        // Each tap = ~10m of progress
        virtualDistance += 10

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if virtualDistance >= targetDistance {
            finishDrill()
        }
    }

    private func finishDrill() {
        timer?.invalidate()
        isRunning = false
        isComplete = true
        virtualDistance = targetDistance

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    private func paceString(_ pace: TimeInterval) -> String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Simulated Swimming Drill

struct SimulatedSwimmingDrillView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var elapsedTime: TimeInterval = 0
    @State private var timerStartDate: Date?
    @State private var isSwimming = false
    @State private var isComplete = false
    @State private var timer: Timer?
    @State private var strokeCount = 0
    @State private var virtualDistance: Double = 0

    let targetDuration: TimeInterval
    let onComplete: (TimeInterval, Double) -> Void

    var body: some View {
        ZStack {
            Color.blue.opacity(0.1).ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("Swimming Drill")
                        .font(.headline)
                    Spacer()
                    Button("Skip") {
                        finishDrill()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()

                Spacer()

                if !isSwimming && !isComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.pool.swim")
                            .scaledFont(size: 80, relativeTo: .largeTitle)
                            .foregroundStyle(.blue)
                        Text("\(Int(targetDuration / 60)) Minute Swim")
                            .font(.title2)
                        Text("Tap for each stroke")
                            .foregroundStyle(.secondary)

                        Button("Start") {
                            startDrill()
                        }
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .clipShape(Capsule())
                    }
                } else if isComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .scaledFont(size: 60, relativeTo: .largeTitle)
                            .foregroundStyle(.green)
                        Text("Complete!")
                            .font(.title.bold())
                        Text(timeString(elapsedTime))
                            .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        Text("\(Int(virtualDistance))m swum")
                            .font(.title3)
                        Text("\(strokeCount) strokes")
                            .foregroundStyle(.secondary)

                        Button("Continue") {
                            onComplete(elapsedTime, virtualDistance)
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .clipShape(Capsule())
                    }
                } else {
                    VStack(spacing: 20) {
                        // Time remaining
                        let remaining = max(0, targetDuration - elapsedTime)
                        Text(timeString(remaining))
                            .scaledFont(size: 56, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                            .monospacedDigit()
                            .foregroundStyle(remaining < 30 ? .red : .primary)

                        // Stats
                        HStack(spacing: 40) {
                            VStack {
                                Text("\(Int(virtualDistance))")
                                    .font(.title2.bold().monospacedDigit())
                                Text("meters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            VStack {
                                Text("\(strokeCount)")
                                    .font(.title2.bold().monospacedDigit())
                                Text("strokes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Stroke area
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue.opacity(0.3))
                            .frame(height: 150)
                            .overlay {
                                VStack {
                                    Image(systemName: "water.waves")
                                        .font(.largeTitle)
                                    Text("STROKE")
                                        .font(.headline)
                                }
                                .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 40)
                            .onTapGesture {
                                stroke()
                            }
                    }
                }

                Spacer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startDrill() {
        isSwimming = true
        timerStartDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let timerStartDate else { return }
            elapsedTime = Date().timeIntervalSince(timerStartDate)
            if elapsedTime >= targetDuration {
                finishDrill()
            }
        }
    }

    private func stroke() {
        strokeCount += 1
        virtualDistance += 2 // ~2m per stroke

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func finishDrill() {
        timer?.invalidate()
        isSwimming = false
        isComplete = true

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    CompetitionSimulationView(level: .junior)
}
