//
//  SkillDomainService.swift
//  TetraTrack
//
//  Computes skill domain scores from discipline-specific metrics
//

import Foundation
import SwiftData
import Observation

@Observable
final class SkillDomainService {

    // MARK: - Riding Score Computation

    /// Compute all domain scores from a completed ride
    func computeScores(from ride: Ride) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []
        let confidence = computeConfidence(from: ride)

        // BALANCE: reinBalance + leadBalance + turnBalance
        let balanceValue = computeRidingBalance(ride)
        if balanceValue > 0 {
            scores.append(SkillDomainScore(
                domain: .balance,
                score: balanceValue,
                confidence: confidence,
                discipline: .riding,
                sourceSessionId: ride.id,
                contributingMetrics: [
                    "reinBalance": ride.reinBalance * 100,
                    "leadBalance": ride.leadBalance * 100,
                    "turnBalance": Double(ride.turnBalancePercent)
                ]
            ))
        }

        // SYMMETRY: leftReinSymmetry + rightReinSymmetry
        let symmetryValue = computeRidingSymmetry(ride)
        if symmetryValue > 0 {
            scores.append(SkillDomainScore(
                domain: .symmetry,
                score: symmetryValue,
                confidence: confidence,
                discipline: .riding,
                sourceSessionId: ride.id,
                contributingMetrics: [
                    "leftReinSymmetry": ride.leftReinSymmetry,
                    "rightReinSymmetry": ride.rightReinSymmetry,
                    "overallSymmetry": ride.overallSymmetry
                ]
            ))
        }

        // RHYTHM: leftReinRhythm + rightReinRhythm
        let rhythmValue = computeRidingRhythm(ride)
        if rhythmValue > 0 {
            scores.append(SkillDomainScore(
                domain: .rhythm,
                score: rhythmValue,
                confidence: confidence,
                discipline: .riding,
                sourceSessionId: ride.id,
                contributingMetrics: [
                    "leftReinRhythm": ride.leftReinRhythm,
                    "rightReinRhythm": ride.rightReinRhythm,
                    "overallRhythm": ride.overallRhythm
                ]
            ))
        }

        // ENDURANCE: duration-based
        let enduranceValue = computeRidingEndurance(ride)
        if enduranceValue > 0 {
            scores.append(SkillDomainScore(
                domain: .endurance,
                score: enduranceValue,
                confidence: confidence,
                discipline: .riding,
                sourceSessionId: ride.id,
                contributingMetrics: [
                    "duration": ride.totalDuration
                ]
            ))
        }

        // CALMNESS: HR variability (if available)
        let calmnessValue = computeRidingCalmness(ride)
        if calmnessValue > 0 {
            scores.append(SkillDomainScore(
                domain: .calmness,
                score: calmnessValue,
                confidence: ride.hasHeartRateData ? confidence : confidence * 0.5,
                discipline: .riding,
                sourceSessionId: ride.id,
                contributingMetrics: [
                    "averageHeartRate": Double(ride.averageHeartRate),
                    "maxHeartRate": Double(ride.maxHeartRate)
                ]
            ))
        }

        return scores
    }

    // MARK: - Running Score Computation

    /// Compute domain scores from a running session
    func computeScores(from session: RunningSession, score: RunningScore?) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []

        // SYMMETRY: cadence consistency implies symmetric gait
        let cadenceCV = computeCadenceCV(session)
        let symmetryValue = max(0, 100 - cadenceCV * 500)
        if symmetryValue > 0 && session.averageCadence > 0 {
            scores.append(SkillDomainScore(
                domain: .symmetry,
                score: symmetryValue,
                confidence: 0.6,
                discipline: .running,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "cadenceCV": cadenceCV,
                    "averageCadence": Double(session.averageCadence)
                ]
            ))
        }

        // RHYTHM: cadence consistency + pace stability
        let rhythmValue = computeRunningRhythm(session, score: score)
        if rhythmValue > 0 {
            scores.append(SkillDomainScore(
                domain: .rhythm,
                score: rhythmValue,
                confidence: 0.7,
                discipline: .running,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "averageCadence": Double(session.averageCadence),
                    "cadenceConsistency": Double(score?.cadenceConsistency ?? 0)
                ]
            ))
        }

        // ENDURANCE: duration, finish strength, energy level
        let enduranceValue = computeRunningEndurance(session, score: score)
        if enduranceValue > 0 {
            scores.append(SkillDomainScore(
                domain: .endurance,
                score: enduranceValue,
                confidence: 0.8,
                discipline: .running,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "duration": session.totalDuration,
                    "distance": session.totalDistance,
                    "finishStrength": Double(score?.finishStrength ?? 0),
                    "energyLevel": Double(score?.energyLevel ?? 0)
                ]
            ))
        }

        // STABILITY: subjective form score
        if let runScore = score, runScore.hasScores {
            let stabilityValue = runScore.formAverage * 20  // Convert 1-5 to 0-100
            if stabilityValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: stabilityValue,
                    confidence: 0.5,
                    discipline: .running,
                    sourceSessionId: session.id,
                    contributingMetrics: [
                        "formAverage": runScore.formAverage,
                        "runningForm": Double(runScore.runningForm)
                    ]
                ))
            }
        }

        return scores
    }

    // MARK: - Swimming Score Computation

    /// Compute domain scores from a swimming session
    func computeScores(from session: SwimmingSession, score: SwimmingScore?) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []

        // RHYTHM: SWOLF consistency across laps
        let rhythmValue = computeSwimmingRhythm(session)
        if rhythmValue > 0 {
            scores.append(SkillDomainScore(
                domain: .rhythm,
                score: rhythmValue,
                confidence: 0.7,
                discipline: .swimming,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "averageSwolf": session.averageSwolf,
                    "lapCount": Double(session.lapCount)
                ]
            ))
        }

        // SYMMETRY: stroke count consistency
        let symmetryValue = computeSwimmingSymmetry(session)
        if symmetryValue > 0 {
            scores.append(SkillDomainScore(
                domain: .symmetry,
                score: symmetryValue,
                confidence: 0.6,
                discipline: .swimming,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "averageStrokesPerLap": session.averageStrokesPerLap,
                    "totalStrokes": Double(session.totalStrokes)
                ]
            ))
        }

        // ENDURANCE: endurance feel + distance bonus
        let enduranceValue = computeSwimmingEndurance(session, score: score)
        if enduranceValue > 0 {
            scores.append(SkillDomainScore(
                domain: .endurance,
                score: enduranceValue,
                confidence: 0.8,
                discipline: .swimming,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "distance": session.totalDistance,
                    "duration": session.totalDuration,
                    "enduranceFeel": Double(score?.enduranceFeel ?? 0)
                ]
            ))
        }

        // BALANCE: body position subjective score
        if let swimScore = score, swimScore.hasScores {
            let balanceValue = Double(swimScore.bodyPosition) * 20  // Convert 1-5 to 0-100
            if balanceValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .balance,
                    score: balanceValue,
                    confidence: 0.5,
                    discipline: .swimming,
                    sourceSessionId: session.id,
                    contributingMetrics: [
                        "bodyPosition": Double(swimScore.bodyPosition),
                        "techniqueAverage": swimScore.techniqueAverage
                    ]
                ))
            }
        }

        return scores
    }

    // MARK: - Shooting Score Computation

    /// Compute domain scores from a shooting session
    func computeScores(from session: ShootingSession) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []

        // STABILITY: grouping quality + score consistency
        let stabilityValue = computeShootingStability(session)
        if stabilityValue > 0 {
            scores.append(SkillDomainScore(
                domain: .stability,
                score: stabilityValue,
                confidence: 0.8,
                discipline: .shooting,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "scorePercentage": session.scorePercentage,
                    "averagePerArrow": session.averageScorePerArrow
                ]
            ))
        }

        // CALMNESS: X-count and 10s ratio indicates steadiness
        let calmnessValue = computeShootingCalmness(session)
        if calmnessValue > 0 {
            scores.append(SkillDomainScore(
                domain: .calmness,
                score: calmnessValue,
                confidence: 0.7,
                discipline: .shooting,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "xCount": Double(session.xCount),
                    "tensCount": Double(session.tensCount)
                ]
            ))
        }

        // BALANCE: end-to-end consistency (no fatigue dropoff)
        let balanceValue = computeShootingBalance(session)
        if balanceValue > 0 {
            scores.append(SkillDomainScore(
                domain: .balance,
                score: balanceValue,
                confidence: 0.6,
                discipline: .shooting,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "endCount": Double((session.ends ?? []).count),
                    "averagePerEnd": session.averageScorePerEnd
                ]
            ))
        }

        return scores
    }

    // MARK: - Profile Update

    /// Update athlete profile with new scores from the database
    func updateProfile(
        _ profile: AthleteProfile,
        context: ModelContext
    ) {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        for domain in SkillDomain.allCases {
            let domainRaw = domain.rawValue
            let descriptor = FetchDescriptor<SkillDomainScore>(
                predicate: #Predicate { $0.domainRaw == domainRaw && $0.timestamp >= thirtyDaysAgo },
                sortBy: [SortDescriptor(\.timestamp)]
            )

            guard let recentScores = try? context.fetch(descriptor),
                  !recentScores.isEmpty else {
                continue
            }

            // Compute weighted average (more recent = higher weight)
            var weightedSum: Double = 0
            var totalWeight: Double = 0

            for (index, score) in recentScores.enumerated() {
                let recencyWeight = Double(index + 1)
                let weight = recencyWeight * score.confidence
                weightedSum += score.score * weight
                totalWeight += weight
            }

            let average = totalWeight > 0 ? weightedSum / totalWeight : 0

            // Compute trend (compare first half to second half)
            let midpoint = recentScores.count / 2
            guard midpoint > 0 else {
                profile.updateDomain(domain, average: average, trend: 0)
                continue
            }

            let firstHalf = Array(recentScores.prefix(midpoint))
            let secondHalf = Array(recentScores.suffix(recentScores.count - midpoint))

            let firstAvg = firstHalf.map(\.score).reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.map(\.score).reduce(0, +) / Double(secondHalf.count)

            let trend: Int
            if secondAvg - firstAvg > 5 {
                trend = 1  // Improving
            } else if firstAvg - secondAvg > 5 {
                trend = -1  // Declining
            } else {
                trend = 0  // Stable
            }

            profile.updateDomain(domain, average: average, trend: trend)
        }
    }

    // MARK: - Private Computation Methods (Riding)

    private func computeRidingBalance(_ ride: Ride) -> Double {
        // Perfect balance = 50% on each side (0.5 ratio)
        let reinBalanceScore = 100 - abs(ride.reinBalance - 0.5) * 200
        let leadBalanceScore = 100 - abs(ride.leadBalance - 0.5) * 200
        let turnBalanceScore = 100 - abs(Double(ride.turnBalancePercent) - 50) * 2

        var validScores: [Double] = []
        if ride.leftReinDuration + ride.rightReinDuration > 0 {
            validScores.append(max(0, reinBalanceScore))
        }
        if ride.leftLeadDuration + ride.rightLeadDuration > 0 {
            validScores.append(max(0, leadBalanceScore))
        }
        if ride.totalLeftAngle + ride.totalRightAngle > 0 {
            validScores.append(max(0, turnBalanceScore))
        }

        guard !validScores.isEmpty else { return 0 }
        return validScores.reduce(0, +) / Double(validScores.count)
    }

    private func computeRidingSymmetry(_ ride: Ride) -> Double {
        ride.overallSymmetry
    }

    private func computeRidingRhythm(_ ride: Ride) -> Double {
        ride.overallRhythm
    }

    private func computeRidingEndurance(_ ride: Ride) -> Double {
        // Longer rides = higher endurance score (1 hour = 100)
        let durationScore = min(100, ride.totalDuration / 3600 * 100)
        guard durationScore > 0 else { return 0 }
        return durationScore
    }

    private func computeRidingCalmness(_ ride: Ride) -> Double {
        // Based on HR variability
        guard ride.hasHeartRateData else { return 50 }

        let hrStats = ride.heartRateStatistics
        let samples = hrStats.samples
        guard samples.count >= 5 else { return 70 }

        // Compute standard deviation manually
        let bpms = samples.map { Double($0.bpm) }
        let mean = bpms.reduce(0, +) / Double(bpms.count)
        let variance = bpms.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(bpms.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0 else { return 70 }

        // Lower HR variance = calmer (stdDev of 50 = very variable = 0 score)
        let hrVarianceScore = max(0, 100 - stdDev * 2)
        return hrVarianceScore
    }

    private func computeConfidence(from ride: Ride) -> Double {
        // More data = higher confidence
        let durationFactor = min(1.0, ride.totalDuration / 1800)  // 30 min = full confidence
        let pointsFactor = min(1.0, Double(ride.locationPoints?.count ?? 0) / 500)
        return (durationFactor + pointsFactor) / 2
    }

    // MARK: - Private Computation Methods (Running)

    private func computeCadenceCV(_ session: RunningSession) -> Double {
        // Use split-level cadence data if available
        let splits = session.splits ?? []
        guard splits.count >= 3 else { return 0.1 }  // Default moderate variance

        let cadences = splits.compactMap { split -> Double? in
            guard split.cadence > 0 else { return nil }
            return Double(split.cadence)
        }

        guard cadences.count >= 3 else { return 0.1 }

        let mean = cadences.reduce(0, +) / Double(cadences.count)
        let variance = cadences.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(cadences.count)
        return mean > 0 ? sqrt(variance) / mean : 0.1
    }

    private func computeRunningRhythm(_ session: RunningSession, score: RunningScore?) -> Double {
        var baseScore: Double = 50

        if let runScore = score, runScore.cadenceConsistency > 0 {
            baseScore = Double(runScore.cadenceConsistency) * 20
        }

        // Bonus for target cadence range (170-180)
        if session.averageCadence >= 170 && session.averageCadence <= 180 {
            baseScore += 10
        } else if session.averageCadence >= 160 && session.averageCadence <= 190 {
            baseScore += 5
        }

        return min(100, baseScore)
    }

    private func computeRunningEndurance(_ session: RunningSession, score: RunningScore?) -> Double {
        var baseScore: Double = 50

        if let runScore = score {
            let finishStrength = Double(runScore.finishStrength)
            let energyLevel = Double(runScore.energyLevel)
            if finishStrength > 0 || energyLevel > 0 {
                baseScore = (finishStrength + energyLevel) * 10
            }
        }

        // Duration bonus: up to 30 points for 1 hour
        let durationBonus = min(30, session.totalDuration / 120)

        return min(100, baseScore + durationBonus)
    }

    // MARK: - Private Computation Methods (Swimming)

    private func computeSwimmingRhythm(_ session: SwimmingSession) -> Double {
        // SWOLF consistency across laps
        let laps = session.sortedLaps
        guard laps.count >= 3 else { return 50 }

        let swolfs = laps.map { Double($0.swolf) }.filter { $0 > 0 }
        guard swolfs.count >= 3 else { return 50 }

        let mean = swolfs.reduce(0, +) / Double(swolfs.count)
        let variance = swolfs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(swolfs.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 0

        // CV of 0 = 100, CV of 0.2 = 0
        return max(0, 100 - cv * 500)
    }

    private func computeSwimmingSymmetry(_ session: SwimmingSession) -> Double {
        // Stroke count consistency
        let laps = session.sortedLaps
        guard laps.count >= 3 else { return 50 }

        let strokes = laps.map { Double($0.strokeCount) }.filter { $0 > 0 }
        guard strokes.count >= 3 else { return 50 }

        let mean = strokes.reduce(0, +) / Double(strokes.count)
        let variance = strokes.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(strokes.count)
        let cv = mean > 0 ? sqrt(variance) / mean : 0

        return max(0, 100 - cv * 300)
    }

    private func computeSwimmingEndurance(_ session: SwimmingSession, score: SwimmingScore?) -> Double {
        var baseScore: Double = 50

        if let swimScore = score, swimScore.enduranceFeel > 0 {
            baseScore = Double(swimScore.enduranceFeel) * 20
        }

        // Distance bonus: up to 30 points for 3km
        let distanceBonus = min(30, session.totalDistance / 100)

        return min(100, baseScore + distanceBonus)
    }

    // MARK: - Unified Drill Session Score Computation

    /// Compute domain scores from a unified drill session
    /// This ensures drill performance flows into the AthleteProfile
    func computeScores(from session: UnifiedDrillSession) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []
        let drillType = session.drillType

        // Convert Discipline to TrainingDiscipline
        let discipline = trainingDiscipline(from: session.primaryDiscipline)

        // Primary domain score based on drill type
        let primaryDomain = domainForDrillType(drillType)
        if session.score > 0 {
            scores.append(SkillDomainScore(
                domain: primaryDomain,
                score: session.score,
                confidence: 0.85,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: [
                    "drillScore": session.score,
                    "duration": session.duration
                ]
            ))
        }

        // Map subscores to domains
        if session.stabilityScore > 0 {
            scores.append(SkillDomainScore(
                domain: .stability,
                score: session.stabilityScore,
                confidence: 0.8,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: ["stabilityScore": session.stabilityScore]
            ))
        }

        if session.symmetryScore > 0 {
            scores.append(SkillDomainScore(
                domain: .symmetry,
                score: session.symmetryScore,
                confidence: 0.8,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: ["symmetryScore": session.symmetryScore]
            ))
        }

        if session.rhythmScore > 0 {
            scores.append(SkillDomainScore(
                domain: .rhythm,
                score: session.rhythmScore,
                confidence: 0.8,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: ["rhythmScore": session.rhythmScore]
            ))
        }

        if session.enduranceScore > 0 {
            scores.append(SkillDomainScore(
                domain: .endurance,
                score: session.enduranceScore,
                confidence: 0.8,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: ["enduranceScore": session.enduranceScore]
            ))
        }

        if session.breathingScore > 0 {
            scores.append(SkillDomainScore(
                domain: .calmness,
                score: session.breathingScore,
                confidence: 0.7,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: ["breathingScore": session.breathingScore]
            ))
        }

        if session.coordinationScore > 0 {
            scores.append(SkillDomainScore(
                domain: .balance,
                score: session.coordinationScore,
                confidence: 0.7,
                discipline: discipline,
                sourceSessionId: session.id,
                contributingMetrics: ["coordinationScore": session.coordinationScore]
            ))
        }

        return scores
    }

    /// Convert Discipline enum to TrainingDiscipline enum
    private func trainingDiscipline(from discipline: Discipline) -> TrainingDiscipline {
        switch discipline {
        case .riding: return .riding
        case .running: return .running
        case .swimming: return .swimming
        case .shooting: return .shooting
        case .all: return .riding // Default for generic drills
        }
    }

    /// Map a drill type to its primary skill domain
    private func domainForDrillType(_ drillType: UnifiedDrillType) -> SkillDomain {
        switch drillType {
        // Stability drills
        case .coreStability, .riderStillness, .steadyHold, .standingBalance,
             .runningCoreStability, .swimmingCoreStability, .streamlinePosition, .posturalDrift:
            return .stability

        // Balance drills
        case .balanceBoard, .heelPosition, .twoPoint, .stirrupPressure, .singleLegBalance:
            return .balance

        // Symmetry/Mobility drills
        case .hipMobility, .runningHipMobility, .shoulderMobility:
            return .symmetry

        // Rhythm drills
        case .postingRhythm, .cadenceTraining, .breathingRhythm, .kickEfficiency:
            return .rhythm

        // Endurance drills
        case .stressInoculation, .plyometrics, .extendedSeatHold:
            return .endurance

        // Calmness drills
        case .boxBreathing, .breathingPatterns, .dryFire, .mountedBreathing:
            return .calmness

        // Reaction drills map to rhythm (timing)
        case .reactionTime, .splitTime:
            return .rhythm

        // Recovery drills map to balance
        case .recoilControl:
            return .balance
        }
    }

    // MARK: - Shooting Drill Score Computation

    /// Compute domain scores from a shooting drill session
    func computeScores(from drill: ShootingDrillSession) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []

        // Map drill type to relevant domains
        switch drill.drillType {
        case .balance, .posturalDrift:
            // BALANCE: direct balance training
            let balanceValue = max(drill.score, drill.stabilityScore)
            if balanceValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .balance,
                    score: balanceValue,
                    confidence: 0.9,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "stabilityScore": drill.stabilityScore,
                        "duration": drill.duration
                    ]
                ))
            }

            // STABILITY: core stability training
            if drill.stabilityScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: drill.stabilityScore,
                    confidence: 0.9,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "stabilityScore": drill.stabilityScore,
                        "averageWobble": drill.averageWobble
                    ]
                ))
            }

        case .breathing, .stressInoculation:
            // CALMNESS: stress management training
            let calmnessValue = drill.score
            if calmnessValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .calmness,
                    score: calmnessValue,
                    confidence: 0.85,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "startHeartRate": drill.startHeartRate,
                        "duration": drill.duration
                    ]
                ))
            }

        case .steadyHold:
            // STABILITY: hold steadiness
            let stabilityValue = max(drill.score, drill.stabilityScore)
            if stabilityValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: stabilityValue,
                    confidence: 0.9,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "stabilityScore": drill.stabilityScore,
                        "averageWobble": drill.averageWobble
                    ]
                ))
            }

            // CALMNESS: steadiness implies calmness
            if drill.score > 0 {
                scores.append(SkillDomainScore(
                    domain: .calmness,
                    score: drill.score * 0.8,
                    confidence: 0.6,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score
                    ]
                ))
            }

        case .dryFire:
            // STABILITY: trigger control requires stability
            if drill.score > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: drill.score,
                    confidence: 0.7,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "duration": drill.duration
                    ]
                ))
            }

        case .reaction, .splitTime:
            // RHYTHM: timing and transitions
            let rhythmValue = drill.transitionScore > 0 ? drill.transitionScore : drill.score
            if rhythmValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .rhythm,
                    score: rhythmValue,
                    confidence: 0.8,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "transitionScore": drill.transitionScore,
                        "bestReactionTime": drill.bestReactionTime,
                        "averageSplitTime": drill.averageSplitTime
                    ]
                ))
            }

        case .recoilControl:
            // BALANCE: recovery from recoil
            let balanceValue = drill.recoveryScore > 0 ? drill.recoveryScore : drill.score
            if balanceValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .balance,
                    score: balanceValue,
                    confidence: 0.8,
                    discipline: .shooting,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "recoveryScore": drill.recoveryScore
                    ]
                ))
            }
        }

        // ENDURANCE: all drills contribute to shooting endurance based on duration
        let enduranceValue = computeDrillEndurance(drill)
        if enduranceValue > 0 && drill.drillType == .posturalDrift {
            scores.append(SkillDomainScore(
                domain: .endurance,
                score: enduranceValue,
                confidence: 0.7,
                discipline: .shooting,
                sourceSessionId: drill.id,
                contributingMetrics: [
                    "duration": drill.duration,
                    "enduranceScore": drill.enduranceScore
                ]
            ))
        }

        return scores
    }

    private func computeDrillEndurance(_ drill: ShootingDrillSession) -> Double {
        if drill.enduranceScore > 0 {
            return drill.enduranceScore
        }
        // Base on duration (60 seconds = 80 points)
        return min(100, drill.duration / 60 * 80)
    }

    // MARK: - Private Computation Methods (Shooting)

    private func computeShootingStability(_ session: ShootingSession) -> Double {
        // Grouping quality based on score consistency across ends
        let ends = session.sortedEnds
        guard ends.count >= 2 else { return session.scorePercentage }

        let scores = ends.map { Double($0.totalScore) }
        let mean = scores.reduce(0, +) / Double(scores.count)

        guard mean > 0 else { return session.scorePercentage }

        let variance = scores.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(scores.count)
        let cv = sqrt(variance) / mean

        // Combine score percentage with consistency
        let consistencyScore = max(0, 100 - cv * 200)
        return session.scorePercentage * 0.6 + consistencyScore * 0.4
    }

    private func computeShootingCalmness(_ session: ShootingSession) -> Double {
        // X-count and 10s ratio indicates steadiness
        let totalShots = (session.ends ?? []).flatMap { $0.shots ?? [] }.count
        guard totalShots > 0 else { return 50 }

        let xRatio = Double(session.xCount) / Double(totalShots)
        let tensRatio = Double(session.tensCount) / Double(totalShots)

        // High X and 10 ratio = calm under pressure
        return xRatio * 100 * 0.6 + tensRatio * 100 * 0.4
    }

    private func computeShootingBalance(_ session: ShootingSession) -> Double {
        // End-to-end consistency (no fatigue dropoff)
        let ends = session.sortedEnds
        guard ends.count >= 3 else { return 70 }

        let firstHalfEnds = Array(ends.prefix(ends.count / 2))
        let secondHalfEnds = Array(ends.suffix(ends.count - ends.count / 2))

        guard !firstHalfEnds.isEmpty, !secondHalfEnds.isEmpty else { return 70 }

        let firstAvg = Double(firstHalfEnds.reduce(0) { $0 + $1.totalScore }) / Double(firstHalfEnds.count)
        let secondAvg = Double(secondHalfEnds.reduce(0) { $0 + $1.totalScore }) / Double(secondHalfEnds.count)

        // If second half >= first half, good endurance
        if secondAvg >= firstAvg {
            return 90
        }

        // Calculate dropoff penalty
        guard firstAvg > 0 else { return 70 }
        let dropoffPercent = (firstAvg - secondAvg) / firstAvg * 100
        return max(0, 100 - dropoffPercent * 2)
    }

    // MARK: - Riding Drill Score Computation

    /// Compute domain scores from a riding drill session
    func computeScores(from drill: RidingDrillSession) -> [SkillDomainScore] {
        var scores: [SkillDomainScore] = []

        // Map drill type to relevant domains
        switch drill.drillType {
        case .coreStability, .riderStillness:
            // STABILITY: core strength and stillness
            let stabilityValue = max(drill.score, drill.stabilityScore)
            if stabilityValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: stabilityValue,
                    confidence: 0.9,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "stabilityScore": drill.stabilityScore,
                        "duration": drill.duration
                    ]
                ))
            }

            // SYMMETRY from core drills
            if drill.symmetryScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .symmetry,
                    score: drill.symmetryScore,
                    confidence: 0.7,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "symmetryScore": drill.symmetryScore
                    ]
                ))
            }

        case .heelPosition, .stirrupPressure:
            // BALANCE: heel and stirrup position
            let balanceValue = max(drill.score, drill.stabilityScore)
            if balanceValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .balance,
                    score: balanceValue,
                    confidence: 0.9,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "stabilityScore": drill.stabilityScore,
                        "duration": drill.duration
                    ]
                ))
            }

            // SYMMETRY: left/right balance
            if drill.symmetryScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .symmetry,
                    score: drill.symmetryScore,
                    confidence: 0.8,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "symmetryScore": drill.symmetryScore
                    ]
                ))
            }

        case .twoPoint:
            // ENDURANCE: holding position
            let enduranceValue = max(drill.score, drill.enduranceScore)
            if enduranceValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .endurance,
                    score: enduranceValue,
                    confidence: 0.9,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "enduranceScore": drill.enduranceScore,
                        "duration": drill.duration
                    ]
                ))
            }

            // STABILITY: requires core stability too
            if drill.stabilityScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: drill.stabilityScore,
                    confidence: 0.7,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "stabilityScore": drill.stabilityScore
                    ]
                ))
            }

        case .balanceBoard:
            // BALANCE: proprioception training
            let balanceValue = max(drill.score, drill.coordinationScore)
            if balanceValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .balance,
                    score: balanceValue,
                    confidence: 0.9,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "coordinationScore": drill.coordinationScore,
                        "duration": drill.duration
                    ]
                ))
            }

            // STABILITY: reflexes require stability
            if drill.stabilityScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .stability,
                    score: drill.stabilityScore,
                    confidence: 0.7,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "stabilityScore": drill.stabilityScore
                    ]
                ))
            }

        case .hipMobility:
            // SYMMETRY: hip circles require balance
            let symmetryValue = max(drill.score, drill.symmetryScore)
            if symmetryValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .symmetry,
                    score: symmetryValue,
                    confidence: 0.9,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "symmetryScore": drill.symmetryScore,
                        "duration": drill.duration
                    ]
                ))
            }

            // BALANCE: hip mobility improves balance
            if drill.coordinationScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .balance,
                    score: drill.coordinationScore,
                    confidence: 0.6,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "coordinationScore": drill.coordinationScore
                    ]
                ))
            }

        case .postingRhythm:
            // RHYTHM: timing and metronome accuracy
            let rhythmValue = max(drill.score, drill.rhythmAccuracy)
            if rhythmValue > 0 {
                scores.append(SkillDomainScore(
                    domain: .rhythm,
                    score: rhythmValue,
                    confidence: 0.9,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "drillScore": drill.score,
                        "rhythmAccuracy": drill.rhythmAccuracy,
                        "duration": drill.duration
                    ]
                ))
            }

            // ENDURANCE: posting requires leg endurance
            if drill.enduranceScore > 0 {
                scores.append(SkillDomainScore(
                    domain: .endurance,
                    score: drill.enduranceScore,
                    confidence: 0.7,
                    discipline: .riding,
                    sourceSessionId: drill.id,
                    contributingMetrics: [
                        "enduranceScore": drill.enduranceScore
                    ]
                ))
            }
        }

        return scores
    }
}
