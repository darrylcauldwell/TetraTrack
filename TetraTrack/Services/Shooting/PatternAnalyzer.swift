//
//  PatternAnalyzer.swift
//  TetraTrack
//
//  Shot pattern analysis algorithms for shooting performance evaluation.
//  Provides statistical metrics, group analysis, and improvement suggestions.
//

import Foundation
import CoreGraphics

// MARK: - Pattern Analysis Result

/// Comprehensive shot pattern analysis result
struct PatternAnalysis: Codable, Equatable {
    /// Mean Point of Impact (normalized coordinates)
    let mpi: NormalizedTargetPosition

    /// Standard deviation of shot positions
    let standardDeviation: Double

    /// Extreme spread (max distance between any two shots)
    let extremeSpread: Double

    /// Circular Error Probable (radius containing 50% of shots)
    let cep50: Double

    /// Radius containing 90% of shots
    let cep90: Double

    /// Directional bias analysis
    let directionalBias: DirectionalBias

    /// Shot count used in analysis
    let shotCount: Int

    /// Timestamp of analysis
    let analyzedAt: Date

    /// Algorithm version for compatibility tracking
    let algorithmVersion: Int

    static let currentAlgorithmVersion = 1

    /// Consistency rating based on standard deviation
    var consistencyRating: ConsistencyRating {
        // Based on normalized target coordinates (0-1 range represents target radius)
        if standardDeviation < 0.05 { return .excellent }
        if standardDeviation < 0.10 { return .good }
        if standardDeviation < 0.15 { return .fair }
        return .needsWork
    }

    /// Accuracy rating based on MPI distance from center
    var accuracyRating: AccuracyRating {
        let mpiDistance = mpi.radialDistance
        if mpiDistance < 0.05 { return .excellent }
        if mpiDistance < 0.10 { return .good }
        if mpiDistance < 0.20 { return .fair }
        return .needsWork
    }

    /// Group size in normalized units (diameter containing most shots)
    var groupSize: Double {
        cep90 * 2
    }

    enum ConsistencyRating: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case needsWork = "Needs Work"
    }

    enum AccuracyRating: String, Codable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case needsWork = "Needs Work"
    }
}

// MARK: - Directional Bias

/// Analysis of systematic directional errors
struct DirectionalBias: Codable, Equatable {
    /// Horizontal bias (-1 = left, +1 = right)
    let horizontalBias: Double

    /// Vertical bias (-1 = down, +1 = up)
    let verticalBias: Double

    /// Primary bias direction (clock position)
    let primaryDirection: ClockDirection?

    /// Magnitude of bias (0 = none, 1 = severe)
    let magnitude: Double

    /// Whether bias is statistically significant
    let isSignificant: Bool

    enum ClockDirection: Int, Codable, CaseIterable {
        case twelve = 12
        case one = 1
        case two = 2
        case three = 3
        case four = 4
        case five = 5
        case six = 6
        case seven = 7
        case eight = 8
        case nine = 9
        case ten = 10
        case eleven = 11

        var description: String {
            "\(rawValue) o'clock"
        }

        static func from(angleDegrees: Double) -> ClockDirection {
            // Convert angle to clock position
            // 0° = 3 o'clock, 90° = 12 o'clock, etc.
            let adjustedAngle = (90 - angleDegrees + 360).truncatingRemainder(dividingBy: 360)
            let hour = Int(round(adjustedAngle / 30.0).truncatingRemainder(dividingBy: 12))
            return ClockDirection(rawValue: hour == 0 ? 12 : hour) ?? .twelve
        }
    }

    /// User-friendly description of the bias
    var description: String? {
        guard isSignificant, let direction = primaryDirection else {
            return nil
        }

        let intensity: String
        if magnitude > 0.3 {
            intensity = "Strong"
        } else if magnitude > 0.15 {
            intensity = "Moderate"
        } else {
            intensity = "Slight"
        }

        return "\(intensity) bias toward \(direction.description)"
    }

    /// Coaching suggestion based on bias
    var coachingSuggestion: String? {
        guard isSignificant else { return nil }

        // Provide specific corrections based on bias direction
        switch primaryDirection {
        case .twelve:
            return "Shots grouping high - check front sight alignment and trigger squeeze"
        case .six:
            return "Shots grouping low - ensure proper sight picture and follow-through"
        case .three:
            return "Shots pulling right - check grip pressure and trigger finger placement"
        case .nine:
            return "Shots pulling left - work on consistent grip and smooth trigger press"
        case .one, .two:
            return "High-right pattern - focus on grip steadiness and sight alignment"
        case .ten, .eleven:
            return "High-left pattern - check for anticipation and grip tension"
        case .four, .five:
            return "Low-right pattern - maintain follow-through and sight picture"
        case .seven, .eight:
            return "Low-left pattern - classic anticipation or flinch, practice dry firing"
        default:
            return nil
        }
    }

    static let none = DirectionalBias(
        horizontalBias: 0,
        verticalBias: 0,
        primaryDirection: nil,
        magnitude: 0,
        isSignificant: false
    )
}

// MARK: - Pattern Analyzer

/// Analyzes shot patterns for statistical metrics and coaching insights
struct PatternAnalyzer {

    /// Minimum shots required for meaningful analysis
    static let minimumShotsForAnalysis = 3

    /// Analyze a collection of shots
    static func analyze(shots: [ShotForAnalysis]) -> PatternAnalysis? {
        guard shots.count >= minimumShotsForAnalysis else {
            return nil
        }

        let positions = shots.map { $0.normalizedPosition }

        // Calculate Mean Point of Impact
        let mpi = calculateMPI(positions)

        // Calculate standard deviation from MPI
        let stdDev = calculateStandardDeviation(positions, from: mpi)

        // Calculate extreme spread
        let extremeSpread = calculateExtremeSpread(positions)

        // Calculate CEP values
        let cep50 = calculateCEP(positions, from: mpi, percentile: 0.50)
        let cep90 = calculateCEP(positions, from: mpi, percentile: 0.90)

        // Analyze directional bias
        let bias = analyzeDirectionalBias(positions, mpi: mpi)

        return PatternAnalysis(
            mpi: mpi,
            standardDeviation: stdDev,
            extremeSpread: extremeSpread,
            cep50: cep50,
            cep90: cep90,
            directionalBias: bias,
            shotCount: shots.count,
            analyzedAt: Date(),
            algorithmVersion: PatternAnalysis.currentAlgorithmVersion
        )
    }

    /// Calculate Mean Point of Impact (centroid of all shots)
    private static func calculateMPI(_ positions: [NormalizedTargetPosition]) -> NormalizedTargetPosition {
        guard !positions.isEmpty else {
            return .zero
        }

        let sumX = positions.reduce(0.0) { $0 + $1.x }
        let sumY = positions.reduce(0.0) { $0 + $1.y }

        return NormalizedTargetPosition(
            x: sumX / Double(positions.count),
            y: sumY / Double(positions.count)
        )
    }

    /// Calculate standard deviation of positions from a reference point
    private static func calculateStandardDeviation(
        _ positions: [NormalizedTargetPosition],
        from reference: NormalizedTargetPosition
    ) -> Double {
        guard positions.count > 1 else { return 0 }

        let squaredDistances = positions.map { position in
            let dx = position.x - reference.x
            let dy = position.y - reference.y
            return dx * dx + dy * dy
        }

        let meanSquaredDistance = squaredDistances.reduce(0, +) / Double(positions.count)
        return sqrt(meanSquaredDistance)
    }

    /// Calculate extreme spread (maximum distance between any two shots)
    private static func calculateExtremeSpread(_ positions: [NormalizedTargetPosition]) -> Double {
        guard positions.count >= 2 else { return 0 }

        var maxDistance: Double = 0

        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let distance = positions[i].distance(to: positions[j])
                maxDistance = max(maxDistance, distance)
            }
        }

        return maxDistance
    }

    /// Calculate Circular Error Probable at given percentile
    private static func calculateCEP(
        _ positions: [NormalizedTargetPosition],
        from reference: NormalizedTargetPosition,
        percentile: Double
    ) -> Double {
        guard !positions.isEmpty else { return 0 }

        let distances = positions.map { position in
            position.distance(to: reference)
        }.sorted()

        let index = min(Int(Double(distances.count) * percentile), distances.count - 1)
        return distances[index]
    }

    /// Analyze directional bias in shot pattern
    private static func analyzeDirectionalBias(
        _ positions: [NormalizedTargetPosition],
        mpi: NormalizedTargetPosition
    ) -> DirectionalBias {
        let horizontalBias = mpi.x
        let verticalBias = mpi.y
        let magnitude = mpi.radialDistance

        // Determine if bias is statistically significant
        // Use threshold based on typical expected variation
        let significanceThreshold = 0.08  // ~8% of target radius
        let isSignificant = magnitude > significanceThreshold

        let primaryDirection: DirectionalBias.ClockDirection?
        if isSignificant {
            primaryDirection = DirectionalBias.ClockDirection.from(angleDegrees: mpi.angleDegrees)
        } else {
            primaryDirection = nil
        }

        return DirectionalBias(
            horizontalBias: horizontalBias,
            verticalBias: verticalBias,
            primaryDirection: primaryDirection,
            magnitude: magnitude,
            isSignificant: isSignificant
        )
    }
}

// MARK: - Shot Protocol for Analysis

/// Protocol for shots that can be analyzed
protocol ShotForAnalysis {
    var normalizedPosition: NormalizedTargetPosition { get }
}

// MARK: - Session Analysis

/// Analysis aggregated across multiple sessions
struct AggregatedPatternAnalysis: Codable, Equatable {
    /// Individual session analyses
    let sessionAnalyses: [PatternAnalysis]

    /// Combined MPI across all sessions
    let overallMPI: NormalizedTargetPosition

    /// Overall standard deviation
    let overallStdDev: Double

    /// Trend in consistency (negative = improving, positive = worsening)
    let consistencyTrend: Double

    /// Trend in accuracy (negative = improving, positive = worsening)
    let accuracyTrend: Double

    /// Total shot count across all sessions
    let totalShots: Int

    /// Session count
    let sessionCount: Int

    /// Date range of analysis
    let dateRange: ClosedRange<Date>

    /// Overall consistency rating
    var overallConsistencyRating: PatternAnalysis.ConsistencyRating {
        if overallStdDev < 0.05 { return .excellent }
        if overallStdDev < 0.10 { return .good }
        if overallStdDev < 0.15 { return .fair }
        return .needsWork
    }

    /// Trend description
    var trendDescription: String {
        if consistencyTrend < -0.01 && accuracyTrend < -0.01 {
            return "Improving in both consistency and accuracy"
        } else if consistencyTrend < -0.01 {
            return "Consistency improving"
        } else if accuracyTrend < -0.01 {
            return "Accuracy improving"
        } else if consistencyTrend > 0.01 || accuracyTrend > 0.01 {
            return "Performance variance - review recent sessions"
        }
        return "Stable performance"
    }
}

/// Analyzer for aggregating multiple sessions
struct SessionAggregator {

    /// Aggregate analysis across multiple sessions
    static func aggregate(analyses: [PatternAnalysis]) -> AggregatedPatternAnalysis? {
        guard !analyses.isEmpty else { return nil }

        let sortedByDate = analyses.sorted { $0.analyzedAt < $1.analyzedAt }

        // Calculate overall MPI (weighted by shot count)
        let totalShots = analyses.reduce(0) { $0 + $1.shotCount }
        guard totalShots > 0 else { return nil }

        var weightedX: Double = 0
        var weightedY: Double = 0

        for analysis in analyses {
            let weight = Double(analysis.shotCount) / Double(totalShots)
            weightedX += analysis.mpi.x * weight
            weightedY += analysis.mpi.y * weight
        }

        let overallMPI = NormalizedTargetPosition(x: weightedX, y: weightedY)

        // Calculate overall standard deviation (pooled)
        var pooledVariance: Double = 0
        for analysis in analyses {
            let weight = Double(analysis.shotCount) / Double(totalShots)
            pooledVariance += analysis.standardDeviation * analysis.standardDeviation * weight
        }
        let overallStdDev = sqrt(pooledVariance)

        // Calculate trends using linear regression
        let consistencyTrend = calculateTrend(analyses.map { $0.standardDeviation })
        let accuracyTrend = calculateTrend(analyses.map { $0.mpi.radialDistance })

        let startDate = sortedByDate.first?.analyzedAt ?? Date()
        let endDate = sortedByDate.last?.analyzedAt ?? Date()

        return AggregatedPatternAnalysis(
            sessionAnalyses: sortedByDate,
            overallMPI: overallMPI,
            overallStdDev: overallStdDev,
            consistencyTrend: consistencyTrend,
            accuracyTrend: accuracyTrend,
            totalShots: totalShots,
            sessionCount: analyses.count,
            dateRange: startDate...endDate
        )
    }

    /// Calculate trend using simple linear regression
    private static func calculateTrend(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }

        let n = Double(values.count)
        let indices = (0..<values.count).map { Double($0) }

        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumXX = indices.reduce(0.0) { $0 + $1 * $1 }

        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return 0 }

        let slope = (n * sumXY - sumX * sumY) / denominator
        return slope
    }
}

// MARK: - Improvement Suggestions

/// Generates coaching suggestions based on pattern analysis
struct ImprovementSuggestionGenerator {

    /// Generate prioritized improvement suggestions
    static func generateSuggestions(from analysis: PatternAnalysis) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []

        // Check accuracy (MPI distance from center)
        if analysis.accuracyRating == .needsWork || analysis.accuracyRating == .fair {
            suggestions.append(ImprovementSuggestion(
                priority: .high,
                category: .sightAlignment,
                title: "Sight Alignment",
                description: "Your shots are consistently off-center. Focus on proper sight alignment and confirm your zero.",
                drills: ["Dry fire practice with focus on sight picture", "Confirm zero at known distance"]
            ))
        }

        // Check consistency (standard deviation)
        if analysis.consistencyRating == .needsWork {
            suggestions.append(ImprovementSuggestion(
                priority: .high,
                category: .holdControl,
                title: "Hold Control",
                description: "Shot spread is large. Work on steady hold and breathing.",
                drills: ["Balance exercises", "Extended hold drills", "Breathing rhythm practice"]
            ))
        } else if analysis.consistencyRating == .fair {
            suggestions.append(ImprovementSuggestion(
                priority: .medium,
                category: .holdControl,
                title: "Improve Consistency",
                description: "Good baseline consistency, but room for improvement.",
                drills: ["Slow fire practice", "Focus on trigger control"]
            ))
        }

        // Check directional bias
        if let biasSuggestion = analysis.directionalBias.coachingSuggestion {
            suggestions.append(ImprovementSuggestion(
                priority: analysis.directionalBias.magnitude > 0.2 ? .high : .medium,
                category: .triggerControl,
                title: "Correct Directional Bias",
                description: biasSuggestion,
                drills: ["Dry fire with wall drill", "Ball and dummy drill"]
            ))
        }

        // Check extreme spread
        if analysis.extremeSpread > 0.4 {
            suggestions.append(ImprovementSuggestion(
                priority: .medium,
                category: .mentalFocus,
                title: "Shot Discipline",
                description: "Large variation between best and worst shots. Focus on consistent pre-shot routine.",
                drills: ["Develop consistent routine", "Mental rehearsal"]
            ))
        }

        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
}

/// A specific improvement suggestion
struct ImprovementSuggestion: Identifiable, Codable, Equatable {
    let id: UUID
    let priority: Priority
    let category: Category
    let title: String
    let description: String
    let drills: [String]

    init(priority: Priority, category: Category, title: String, description: String, drills: [String]) {
        self.id = UUID()
        self.priority = priority
        self.category = category
        self.title = title
        self.description = description
        self.drills = drills
    }

    enum Priority: Int, Codable {
        case low = 1
        case medium = 2
        case high = 3
    }

    enum Category: String, Codable {
        case sightAlignment = "Sight Alignment"
        case triggerControl = "Trigger Control"
        case holdControl = "Hold Control"
        case mentalFocus = "Mental Focus"
        case stance = "Stance"
        case grip = "Grip"
    }
}

// MARK: - Score Projection

/// Projects scores based on pattern analysis
struct ScoreProjector {

    /// Project expected score based on current pattern
    static func projectScore(
        from analysis: PatternAnalysis,
        targetType: ShootingTargetGeometryType,
        shotCount: Int = 10
    ) -> ScoreProjection {
        // Monte Carlo simulation to project scores
        var simulatedScores: [Int] = []
        let iterations = 1000

        for _ in 0..<iterations {
            var roundScore = 0
            for _ in 0..<shotCount {
                // Generate random shot based on MPI and standard deviation
                let position = generateRandomShot(
                    mpi: analysis.mpi,
                    stdDev: analysis.standardDeviation
                )
                roundScore += targetType.score(from: position)
            }
            simulatedScores.append(roundScore)
        }

        simulatedScores.sort()

        let mean = Double(simulatedScores.reduce(0, +)) / Double(iterations)
        let p10Index = Int(Double(iterations) * 0.10)
        let p50Index = Int(Double(iterations) * 0.50)
        let p90Index = Int(Double(iterations) * 0.90)

        return ScoreProjection(
            expectedScore: mean,
            lowEstimate: Double(simulatedScores[p10Index]),
            medianEstimate: Double(simulatedScores[p50Index]),
            highEstimate: Double(simulatedScores[p90Index]),
            maxPossible: Double(shotCount * targetType.maxScore),
            shotCount: shotCount
        )
    }

    private static func generateRandomShot(
        mpi: NormalizedTargetPosition,
        stdDev: Double
    ) -> NormalizedTargetPosition {
        // Box-Muller transform for normal distribution
        let u1 = Double.random(in: 0.001...0.999)
        let u2 = Double.random(in: 0.001...0.999)

        let r = sqrt(-2.0 * log(u1)) * stdDev
        let theta = 2.0 * .pi * u2

        let x = mpi.x + r * cos(theta)
        let y = mpi.y + r * sin(theta)

        return NormalizedTargetPosition(x: x, y: y)
    }
}

/// Score projection result
struct ScoreProjection: Codable, Equatable {
    /// Expected average score
    let expectedScore: Double

    /// 10th percentile (pessimistic)
    let lowEstimate: Double

    /// 50th percentile (median)
    let medianEstimate: Double

    /// 90th percentile (optimistic)
    let highEstimate: Double

    /// Maximum possible score
    let maxPossible: Double

    /// Number of shots in projection
    let shotCount: Int

    /// Expected score as percentage of maximum
    var expectedPercentage: Double {
        guard maxPossible > 0 else { return 0 }
        return expectedScore / maxPossible * 100
    }

    /// Confidence range description
    var confidenceRangeDescription: String {
        String(format: "%.0f - %.0f (80%% confidence)", lowEstimate, highEstimate)
    }
}
