//
//  ShootingPracticeView.swift
//  TetraTrack
//
//  Mark-only scoring view for tetrathlon shooting.
//  Shooting session capture is Watch-primary — this view handles
//  post-session target scanning and score entry.
//

import SwiftUI
import SwiftData
import PhotosUI
import TetraTrackShared

struct ShootingPracticeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Scoring state
    @State private var card1Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var card2Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var card1ScanAnalysisID: UUID?
    @State private var card2ScanAnalysisID: UUID?
    @State private var showingResults = false
    @State private var scoringMode: ScoringMode = .scanScore
    @State private var showingScanSheet = false
    @State private var scanningCard: Int = 1

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

    private let contextColor: Color = .orange

    var body: some View {
        Group {
            if showingResults {
                resultsView
            } else {
                scoringView
            }
        }
    }

    // MARK: - Scoring View

    private var scoringView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Scoring mode picker
                Picker("Mode", selection: $scoringMode) {
                    ForEach(ScoringMode.allCases, id: \.self) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                // Card 1
                cardScoringView(cardNumber: 1, scores: $card1Scores, scanAnalysisID: card1ScanAnalysisID)

                // Card 2
                cardScoringView(cardNumber: 2, scores: $card2Scores, scanAnalysisID: card2ScanAnalysisID)

                // Running total
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
                sessionContext: .competitionTraining,
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

            Button(action: { saveAndDismiss() }) {
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

    // MARK: - Save

    private func saveAndDismiss() {
        let session = ShootingSession()
        session.startDate = Date()
        session.endDate = Date()
        session.sessionContextRaw = ShootingSessionContext.competitionTraining.rawValue

        // Create ends and shots
        let end1 = ShootingEnd(orderIndex: 0)
        var shots1: [Shot] = []
        for (i, score) in card1Scores.enumerated() {
            let shot = Shot()
            shot.score = score
            shot.orderIndex = i
            shot.isX = score == 10
            shots1.append(shot)
        }
        end1.shots = shots1
        if let id = card1ScanAnalysisID { end1.targetScanAnalysisID = id }

        let end2 = ShootingEnd(orderIndex: 1)
        var shots2: [Shot] = []
        for (i, score) in card2Scores.enumerated() {
            let shot = Shot()
            shot.score = score
            shot.orderIndex = i + 5  // Offset by card 1 shots
            shot.isX = score == 10
            shots2.append(shot)
        }
        end2.shots = shots2
        if let id = card2ScanAnalysisID { end2.targetScanAnalysisID = id }

        session.ends = [end1, end2]

        // Wire Watch sensor data from pending shooting summary if available
        let watchManager = WatchConnectivityManager.shared
        if let summary = watchManager.pendingShootingSummaries.last {
            session.healthKitWorkoutUUID = summary.hkWorkoutUUID
            session.totalDuration = summary.duration
            session.averageHeartRate = summary.averageHeartRate

            // Convert dictionaries to DetectedShotMetrics and wire to shots
            let detectedMetrics = summary.shots.compactMap { DetectedShotMetrics.from(dictionary: $0) }
            let allShots = shots1 + shots2
            ShootingSensorAnalyzer.applyShotSensorData(detectedMetrics, to: allShots)

            // Compute and apply pillar scores
            let analysis = ShootingSensorAnalyzer.analyzeSession(
                shotMetrics: detectedMetrics,
                averageHeartRate: summary.averageHeartRate
            )
            ShootingSensorAnalyzer.applyAnalysis(analysis, to: session)

            watchManager.removePendingShootingSummary(workoutUUID: summary.hkWorkoutUUID)
        }

        modelContext.insert(session)
        try? modelContext.save()
        dismiss()
    }
}
