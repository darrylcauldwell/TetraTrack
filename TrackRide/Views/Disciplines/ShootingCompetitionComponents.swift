//
//  ShootingCompetitionComponents.swift
//  TrackRide
//
//  Competition and practice views for shooting discipline
//

import SwiftUI

// MARK: - Competition View

struct ShootingCompetitionView: View {
    let onEnd: (Int) -> Void

    @State private var card1Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var card2Scores: [Int] = Array(repeating: 0, count: 5)
    @State private var showingResults = false

    // Tetrathlon scoring: 2, 4, 6, 8, 10 points per shot
    // Total raw score max = 100, tetrathlon points = raw x 10 = max 1000
    private var card1Total: Int { card1Scores.reduce(0, +) }
    private var card2Total: Int { card2Scores.reduce(0, +) }
    private var totalRawScore: Int { card1Total + card2Total }
    private var tetrathlonPoints: Int { totalRawScore * 10 }

    // Valid tetrathlon scores (even numbers only)
    private let validScores = [2, 4, 6, 8, 10]

    // Check if all scores are entered
    private var allScoresEntered: Bool {
        card1Scores.allSatisfy({ $0 > 0 }) && card2Scores.allSatisfy({ $0 > 0 })
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(.systemBackground), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header with title and close button
                HStack {
                    Text("Competition Practice")
                        .font(.title2.bold())

                    Spacer()

                    Button(action: { onEnd(0) }) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)

                if showingResults {
                    resultsView
                } else {
                    scoringView
                }
            }
            .padding(.top, 8)
        }
    }

    private var scoringView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card 1
                cardScoringView(cardNumber: 1, scores: $card1Scores)

                // Card 2
                cardScoringView(cardNumber: 2, scores: $card2Scores)

                // Running total with tetrathlon points
                VStack(spacing: 4) {
                    HStack {
                        Text("Total:")
                            .font(.headline)
                        Text("\(totalRawScore)/100")
                            .font(.title.bold())
                            .foregroundStyle(.orange)
                    }
                    Text("\(tetrathlonPoints) tetrathlon points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Submit button - enabled when all scores entered
                Button(action: { showingResults = true }) {
                    Text("Submit Scores")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(allScoresEntered ? Color.orange : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!allScoresEntered)

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }

    private func cardScoringView(cardNumber: Int, scores: Binding<[Int]>) -> some View {
        VStack(spacing: 12) {
            Text("Card \(cardNumber)")
                .font(.headline)

            // Score entry row
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
                            .background(scores.wrappedValue[shotIndex] > 0 ? Color.orange.opacity(0.2) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            let cardTotal = scores.wrappedValue.reduce(0, +)
            Text("Card Total: \(cardTotal)/50")
                .font(.subheadline)
                .foregroundStyle(cardTotal == 50 ? .green : .secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Final score with tetrathlon points
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

                // Tetrathlon points
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

            // Card breakdown
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

            // Save button
            Button(action: { onEnd(totalRawScore) }) {
                Label("Save & Finish", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Free Practice View

struct FreePracticeView: View {
    let onEnd: () -> Void

    @State private var scannedTargets: [ScannedTarget] = []
    @State private var showingScanner = false
    @State private var selectedTarget: ScannedTarget?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("Free Practice")
                            .font(.title2.bold())
                        Spacer()
                        Button(action: onEnd) {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)

                    // Scan button
                    Button(action: { showingScanner = true }) {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 48))
                            Text("Scan Target")
                                .font(.headline)
                            Text("Take photo to analyze shot placement")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal)

                    // Session summary
                    if !scannedTargets.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Session Summary")
                                .font(.headline)

                            HStack(spacing: 20) {
                                VStack {
                                    Text("\(scannedTargets.count)")
                                        .font(.title.bold())
                                    Text("Targets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack {
                                    Text("\(totalShots)")
                                        .font(.title.bold())
                                    Text("Shots")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                VStack {
                                    Text(String(format: "%.1f", averageScore))
                                        .font(.title.bold())
                                    Text("Avg Score")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Scanned targets list
                    if scannedTargets.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No targets scanned yet")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(scannedTargets) { target in
                                    ScannedTargetRow(target: target)
                                        .onTapGesture {
                                            selectedTarget = target
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 8)
                .padding(.horizontal)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            TargetScannerView(
                expectedShots: 0, // Unlimited for free practice
                onScanned: { scores in
                    let target = ScannedTarget(
                        scores: scores,
                        timestamp: Date()
                    )
                    scannedTargets.append(target)
                    showingScanner = false
                },
                onCancel: {
                    showingScanner = false
                }
            )
        }
        .sheet(item: $selectedTarget) { target in
            TargetAnalysisView(target: target)
        }
    }

    private var totalShots: Int {
        scannedTargets.reduce(0) { $0 + $1.scores.count }
    }

    private var averageScore: Double {
        let allScores = scannedTargets.flatMap { $0.scores }
        guard !allScores.isEmpty else { return 0 }
        return Double(allScores.reduce(0, +)) / Double(allScores.count)
    }
}

// MARK: - Scanned Target Model

struct ScannedTarget: Identifiable {
    let id = UUID()
    let scores: [Int]
    let timestamp: Date
    var holePositions: [CGPoint] = [] // Relative positions for pattern analysis

    var totalScore: Int { scores.reduce(0, +) }
    var shotCount: Int { scores.count }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // Pattern analysis
    var groupingSize: Double {
        guard holePositions.count >= 2 else { return 0 }
        var maxDistance: Double = 0
        for i in 0..<holePositions.count {
            for j in (i+1)..<holePositions.count {
                let dx = holePositions[i].x - holePositions[j].x
                let dy = holePositions[i].y - holePositions[j].y
                let distance = sqrt(dx*dx + dy*dy)
                maxDistance = max(maxDistance, distance)
            }
        }
        return maxDistance
    }

    var groupingDescription: String {
        let size = groupingSize
        if size < 0.1 { return "Excellent grouping" }
        if size < 0.2 { return "Good grouping" }
        if size < 0.3 { return "Fair grouping" }
        return "Spread pattern"
    }

    var patternBias: String {
        guard !holePositions.isEmpty else { return "No data" }
        let avgX = holePositions.map { $0.x }.reduce(0, +) / Double(holePositions.count)
        let avgY = holePositions.map { $0.y }.reduce(0, +) / Double(holePositions.count)

        var bias: [String] = []
        if avgX < 0.4 { bias.append("Left") }
        else if avgX > 0.6 { bias.append("Right") }
        if avgY < 0.4 { bias.append("High") }
        else if avgY > 0.6 { bias.append("Low") }

        return bias.isEmpty ? "Centered" : bias.joined(separator: "-")
    }
}

// MARK: - Scanned Target Row

struct ScannedTargetRow: View {
    let target: ScannedTarget

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(target.shotCount) shots")
                    .font(.headline)
                Text(target.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score badges
            HStack(spacing: 4) {
                ForEach(target.scores.prefix(5), id: \.self) { score in
                    Text(score == 10 ? "X" : "\(score)")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(scoreColor(score))
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                if target.scores.count > 5 {
                    Text("+\(target.scores.count - 5)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(target.totalScore)")
                .font(.title3.bold())
                .foregroundStyle(.blue)
                .frame(width: 40, alignment: .trailing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 9: return .orange
        case 8: return .red
        case 7: return .blue
        default: return .gray
        }
    }
}

// MARK: - Target Analysis View

struct TargetAnalysisView: View {
    let target: ScannedTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score summary
                    VStack(spacing: 8) {
                        Text("\(target.totalScore)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("\(target.shotCount) shots")
                            .foregroundStyle(.secondary)
                    }

                    // Score breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Score Breakdown")
                            .font(.headline)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                            ForEach(Array(target.scores.enumerated()), id: \.offset) { index, score in
                                VStack {
                                    Text(score == 10 ? "X" : "\(score)")
                                        .font(.title3.bold())
                                        .frame(width: 44, height: 44)
                                        .background(scoreColor(score))
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                    Text("#\(index + 1)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Pattern analysis
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pattern Analysis")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Grouping")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(target.groupingDescription)
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Bias")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(target.patternBias)
                                    .font(.subheadline.bold())
                            }
                        }

                        // Score distribution
                        HStack(spacing: 4) {
                            ForEach(1...10, id: \.self) { score in
                                let count = target.scores.filter { $0 == score }.count
                                VStack {
                                    Spacer()
                                    if count > 0 {
                                        Rectangle()
                                            .fill(scoreColor(score))
                                            .frame(height: CGFloat(count) * 20)
                                    }
                                    Text(score == 10 ? "X" : "\(score)")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 80)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Tips based on pattern
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tips", systemImage: "lightbulb.fill")
                            .font(.headline)
                            .foregroundStyle(.yellow)

                        Text(generateTip())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Target Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 9: return .orange
        case 8: return .red
        case 7: return .blue
        default: return .gray
        }
    }

    private func generateTip() -> String {
        let avgScore = Double(target.totalScore) / Double(target.shotCount)

        if avgScore >= 9.5 {
            return "Excellent shooting! Focus on consistency and mental preparation."
        } else if avgScore >= 8.5 {
            return "Great scores! Work on breathing control to tighten your grouping."
        } else if avgScore >= 7.5 {
            return "Good progress! Check your stance and grip for more stability."
        } else {
            return "Focus on the fundamentals: stance, grip, sight alignment, and trigger control."
        }
    }
}
