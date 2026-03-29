//
//  ShootingPracticeView.swift
//  TetraTrack
//
//  Two-phase Shoot + Mark flow for tetrathlon shooting practice.
//  Shoot tab: live session metrics (timer, HR, breathing, shot count).
//  Mark tab: scan & score UI reusing ShootingCompetitionView's scoring flow.
//

import SwiftUI
import PhotosUI
import TetraTrackShared

// MARK: - Shooting Practice View

struct ShootingPracticeView: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    @State private var selectedPhase: ShootingPhase = .shoot
    @State private var hasFinishedShooting = false

    // Scoring state (shared between tabs so Mark tab can save)
    @State private var card1Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var card2Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var card1ScanAnalysisID: UUID?
    @State private var card2ScanAnalysisID: UUID?
    @State private var showingResults = false
    @State private var scoringMode: ScoringMode = .scanScore
    @State private var showingScanSheet = false
    @State private var scanningCard: Int = 1

    enum ShootingPhase: String, CaseIterable {
        case shoot = "Shoot"
        case mark = "Mark"
    }

    enum ScoringMode: String, CaseIterable {
        case quickEntry = "Quick Entry"
        case scanScore = "Scan & Score"

        var icon: String {
            switch self {
            case .quickEntry: return "hand.tap"
            case .scanScore: return "camera.viewfinder"
            }
        }
    }

    // Tetrathlon scoring
    private let validScores = [2, 4, 6, 8, 10]
    private var card1Total: Int { card1Scores.reduce(0, +) }
    private var card2Total: Int { card2Scores.reduce(0, +) }
    private var totalRawScore: Int { card1Total + card2Total }
    private var tetrathlonPoints: Int { totalRawScore * 10 }
    private var allScoresEntered: Bool {
        card1Scores.allSatisfy({ $0 > 0 }) && card2Scores.allSatisfy({ $0 > 0 })
    }

    private var shootingPlugin: ShootingPlugin? {
        tracker?.plugin(as: ShootingPlugin.self)
    }

    private var sessionContext: ShootingSessionContext {
        shootingPlugin?.sessionContext ?? .competitionTraining
    }

    private var contextColor: Color {
        switch sessionContext.color {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), contextColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Phase picker
                Picker("Phase", selection: $selectedPhase) {
                    ForEach(ShootingPhase.allCases, id: \.self) { phase in
                        Text(phase.rawValue).tag(phase)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Tab content
                switch selectedPhase {
                case .shoot:
                    shootTabContent
                case .mark:
                    markTabContent
                }
            }
        }
    }

    // MARK: - Header (removed — nav title handles this)

    // MARK: - Shoot Tab

    private var shootTabContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Watch connectivity
                WatchStatusCard()

                if let tracker {
                    if tracker.sessionState == .idle {
                        // Start session button
                        VStack(spacing: 12) {
                            Text("Ready to shoot? Start the session to record stance, tremor, and shot timing from your Watch.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            let plugin = ShootingPlugin(sessionContext: .competitionTraining)
                            Task {
                                await tracker.startSession(plugin: plugin)
                            }
                        } label: {
                            Text("Start Session")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 60)
                                .background(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    } else if tracker.sessionState == .tracking {
                        liveSessionMetrics(tracker: tracker)
                    } else if tracker.sessionState == .paused {
                        pausedSessionView(tracker: tracker)
                    }
                }

                // Per-shot feedback from Watch (when available)
                let watchMetrics = WatchConnectivityManager.shared.receivedShotMetrics
                if let lastShot = watchMetrics.last {
                    lastShotFeedbackCard(lastShot, allMetrics: watchMetrics)
                }

                // Session shot summary (when 3+ shots detected)
                if watchMetrics.count >= 3 {
                    sessionShotSummaryCard(metrics: watchMetrics)
                }

                // Finish Shooting button
                if tracker?.sessionState == .tracking || tracker?.sessionState == .paused {
                    Button {
                        hasFinishedShooting = true
                        selectedPhase = .mark
                    } label: {
                        Label("Finish Shooting", systemImage: "arrow.right.circle.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 60)
                            .background(contextColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.top, 8)
                }

                Spacer(minLength: 100) // Space for floating control panel
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Live Session Metrics

    private func liveSessionMetrics(tracker: SessionTracker) -> some View {
        VStack(spacing: 16) {
            // Elapsed time
            Text(tracker.formattedElapsedTime)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            // Shot count and heart rate
            HStack(spacing: 32) {
                // Shot count from Watch
                let shotCount = WatchConnectivityManager.shared.receivedShotMetrics.count
                VStack(spacing: 4) {
                    Text("\(shotCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Shots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Heart rate
                if tracker.currentHeartRate > 0 {
                    let hr = tracker.currentHeartRate
                    VStack(spacing: 4) {
                        Text("\(hr)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                        Text("BPM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Breathing rate
                if let plugin = shootingPlugin, plugin.currentBreathingRate > 0 {
                    let rate = plugin.currentBreathingRate
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", rate))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.cyan)
                        Text("Breaths/min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Pause button
            Button {
                tracker.pauseSession()
            } label: {
                Label("Pause", systemImage: "pause.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(minWidth: 200, minHeight: 60)
                    .background(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard(material: .thin, cornerRadius: 16, padding: 0)
    }

    // MARK: - Paused Session View

    private func pausedSessionView(tracker: SessionTracker) -> some View {
        VStack(spacing: 16) {
            Text("Paused")
                .font(.title2.bold())
                .foregroundStyle(.orange)

            Text(tracker.formattedElapsedTime)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack(spacing: 20) {
                Button {
                    tracker.resumeSession()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(minWidth: 140, minHeight: 60)
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard(material: .thin, cornerRadius: 16, padding: 0)
    }

    // MARK: - Mark Tab

    private var markTabContent: some View {
        Group {
            if showingResults {
                resultsView
            } else {
                scoringView
            }
        }
    }

    // MARK: - Scoring View (Mark Tab)

    private var scoringView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card 1
                cardScoringView(cardNumber: 1, scores: $card1Scores, scanAnalysisID: card1ScanAnalysisID)

                // Card 2
                cardScoringView(cardNumber: 2, scores: $card2Scores, scanAnalysisID: card2ScanAnalysisID)

                // Running total with tetrathlon points
                VStack(spacing: 4) {
                    HStack {
                        Text("Total:")
                            .font(.headline)
                        Text("\(totalRawScore)/100")
                            .font(.title.bold())
                            .foregroundStyle(contextColor)
                    }
                    Text("\(tetrathlonPoints) tetrathlon points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard(material: .thin, cornerRadius: 12, padding: 0)

                // Submit button
                Button(action: { showingResults = true }) {
                    Text("Submit Scores")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .background(allScoresEntered ? contextColor : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!allScoresEntered)

                Spacer(minLength: 100)
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
        .fullScreenCover(isPresented: $showingScanSheet) {
            CardScanFlowView(
                cardNumber: scanningCard,
                sessionContext: sessionContext,
                onComplete: { scores, analysisID in
                    if scanningCard == 1 {
                        card1Scores = scores
                        card1ScanAnalysisID = analysisID
                    } else {
                        card2Scores = scores
                        card2ScanAnalysisID = analysisID
                    }
                    showingScanSheet = false
                },
                onCancel: {
                    showingScanSheet = false
                }
            )
        }
    }

    // MARK: - Card Scoring View

    private func cardScoringView(cardNumber: Int, scores: Binding<[Int]>, scanAnalysisID: UUID?) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Card \(cardNumber)")
                    .font(.headline)
                Spacer()
                if scanAnalysisID != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Scanned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if scoringMode == .scanScore {
                if scanAnalysisID != nil {
                    // Show scanned scores (read-only)
                    HStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { shotIndex in
                            Text(scores.wrappedValue[shotIndex] > 0 ?
                                 (scores.wrappedValue[shotIndex] == 10 ? "X" : "\(scores.wrappedValue[shotIndex])") : "-")
                                .font(.title3.bold())
                                .frame(width: 50, height: 50)
                                .background(scores.wrappedValue[shotIndex] > 0 ? contextColor.opacity(0.2) : AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                } else {
                    // Scan button
                    Button {
                        scanningCard = cardNumber
                        showingScanSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                            Text("Scan Card \(cardNumber)")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .background(contextColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                // Quick entry mode
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { shotIndex in
                        Menu {
                            ForEach(validScores.reversed(), id: \.self) { score in
                                Button("\(score) pts") {
                                    scores.wrappedValue[shotIndex] = score
                                }
                            }
                        } label: {
                            Text(scores.wrappedValue[shotIndex] > 0 ?
                                 (scores.wrappedValue[shotIndex] == 10 ? "X" : "\(scores.wrappedValue[shotIndex])") : "-")
                                .font(.title3.bold())
                                .frame(width: 50, height: 50)
                                .background(scores.wrappedValue[shotIndex] > 0 ? contextColor.opacity(0.2) : AppColors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            let cardTotal = scores.wrappedValue.reduce(0, +)
            Text("Card Total: \(cardTotal)/50")
                .font(.subheadline)
                .foregroundStyle(cardTotal == 50 ? .green : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Final Score")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(totalRawScore)")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(.orange)
                Text("out of 100")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(spacing: 2) {
                    Text("\(tetrathlonPoints)")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                    Text("tetrathlon points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            HStack(spacing: 40) {
                VStack {
                    Text("Card 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(card1Total)/50")
                        .font(.title2.bold())
                }
                VStack {
                    Text("Card 2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(card2Total)/50")
                        .font(.title2.bold())
                }
            }

            Spacer()

            Button(action: { saveAndFinish() }) {
                Label("Save & Finish", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 60)
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Save & Finish

    private func saveAndFinish() {
        shootingPlugin?.saveScores(
            card1Scores: card1Scores,
            card2Scores: card2Scores,
            card1ScanID: card1ScanAnalysisID,
            card2ScanID: card2ScanAnalysisID
        )
        tracker?.stopSession()
    }

    // MARK: - Per-Shot Feedback Card

    private func lastShotFeedbackCard(_ shot: DetectedShotMetrics, allMetrics: [DetectedShotMetrics]) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Shot \(shot.shotIndex)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let hr = shot.heartRateAtShot {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text("\(hr)")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            HStack(spacing: 16) {
                // Steadiness
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", shot.holdSteadiness))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(steadinessColor(shot.holdSteadiness))
                    Text("Steadiness")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Delta from previous shot
                if shot.shotIndex > 1, allMetrics.count >= 2 {
                    let prev = allMetrics[allMetrics.count - 2]
                    let delta = shot.holdSteadiness - prev.holdSteadiness
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption)
                            Text(String(format: "%.0f", abs(delta)))
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                        Text("vs prev")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Tremor
                VStack(spacing: 2) {
                    Text(shot.tremorIntensity < 30 ? "Low" : shot.tremorIntensity < 60 ? "Med" : "High")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(shot.tremorIntensity < 30 ? .green : shot.tremorIntensity < 60 ? .yellow : .red)
                    Text("Tremor")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Drift
                VStack(spacing: 2) {
                    Text(shot.driftMagnitude < 20 ? "Low" : shot.driftMagnitude < 50 ? "Med" : "High")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(shot.driftMagnitude < 20 ? .green : shot.driftMagnitude < 50 ? .yellow : .orange)
                    Text("Drift")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    // MARK: - Session Shot Summary Card

    private func sessionShotSummaryCard(metrics: [DetectedShotMetrics]) -> some View {
        let recentCount = min(metrics.count, 10)
        let recentMetrics = Array(metrics.suffix(recentCount))
        let avgSteadiness = recentMetrics.map(\.holdSteadiness).reduce(0, +) / Double(recentCount)

        let midpoint = metrics.count / 2
        let firstHalfAvg = metrics.prefix(max(1, midpoint)).map(\.holdSteadiness).reduce(0, +) / Double(max(1, midpoint))
        let secondHalfAvg = metrics.suffix(max(1, metrics.count - midpoint)).map(\.holdSteadiness).reduce(0, +) / Double(max(1, metrics.count - midpoint))
        let fatigueDelta = secondHalfAvg - firstHalfAvg

        return VStack(spacing: 8) {
            HStack {
                Text("Session Summary")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(metrics.count) shots detected")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", avgSteadiness))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(steadinessColor(avgSteadiness))
                    Text("Avg Steady")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: fatigueDelta > 2 ? "arrow.up" : fatigueDelta < -2 ? "arrow.down" : "arrow.right")
                            .font(.caption)
                        Text(fatigueDelta > 2 ? "Improving" : fatigueDelta < -2 ? "Degrading" : "Stable")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(fatigueDelta > 2 ? .green : fatigueDelta < -2 ? .orange : .primary)
                    Text("Form Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                let avgHold = recentMetrics.map(\.holdDuration).reduce(0, +) / Double(recentCount)
                VStack(spacing: 2) {
                    Text(String(format: "%.1fs", avgHold))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text("Avg Hold")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Mini steadiness bar chart
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(recentMetrics) { shot in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(steadinessColor(shot.holdSteadiness))
                        .frame(width: max(6, CGFloat(200 / recentCount)), height: max(4, CGFloat(shot.holdSteadiness) * 0.4))
                }
            }
            .frame(height: 40)
        }
        .padding()
        .glassCard(material: .thin, cornerRadius: 12, padding: 0)
    }

    // MARK: - Helpers

    private func steadinessColor(_ value: Double) -> Color {
        if value > 80 { return .green }
        if value > 60 { return .cyan }
        if value > 40 { return .orange }
        return .red
    }
}
