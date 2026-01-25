//
//  TurnAnalyzer.swift
//  TrackRide
//

import CoreLocation
import Foundation
import os

// MARK: - Diagnostic Structures (DEBUG)

#if DEBUG
/// Event type for turn detection diagnostics
enum TurnEventType: String {
    case start = "START"
    case continuation = "CONTINUE"
    case end = "END"
    case threshold = "THRESHOLD_CROSS"
}

/// Diagnostic entry for a single turn detection event
struct TurnDiagnosticEntry: CustomStringConvertible {
    let timestamp: Date
    let direction: TurnDirection
    let eventType: TurnEventType
    let bearingChange: Double           // degrees (this sample)
    let cumulativeAngle: Double         // degrees (current turn event)
    let eventDuration: TimeInterval     // seconds
    let speed: Double                   // m/s
    let gait: String
    let reason: String                  // why this was classified as a turn

    var description: String {
        """
        [TURN_DIAG] {"timestamp": "\(ISO8601DateFormatter().string(from: timestamp))", "direction": "\(direction.rawValue)", "event": "\(eventType.rawValue)", "bearing_change_deg": \(String(format: "%.1f", bearingChange)), "cumulative_deg": \(String(format: "%.1f", cumulativeAngle)), "duration_s": \(String(format: "%.2f", eventDuration)), "speed_mps": \(String(format: "%.1f", speed)), "gait": "\(gait)", "reason": "\(reason)"}
        """
    }
}

/// Reference model for what constitutes a single physical turn
struct PhysicalTurnModel {
    /// Minimum heading change to count as a turn (degrees)
    static let minHeadingChange: Double = 20.0

    /// Minimum duration for a turn (seconds)
    static let minDuration: TimeInterval = 1.0

    /// Cooldown period after turn ends before a new turn can start (seconds)
    static let hysteresisWindow: TimeInterval = 0.5

    /// Threshold for yaw rate to be considered "in a turn" (deg/sec)
    static let yawRateThreshold: Double = 5.0

    /// Small oscillations below this are noise, not direction changes
    static let noiseThreshold: Double = 3.0
}

/// Tracks a physical turn in progress for the reference model
struct PhysicalTurnInProgress {
    let startTime: Date
    let direction: TurnDirection
    var cumulativeAngle: Double = 0
    var lastUpdateTime: Date
    var sampleCount: Int = 0

    var duration: TimeInterval {
        lastUpdateTime.timeIntervalSince(startTime)
    }
}

/// A completed physical turn
struct PhysicalTurn {
    let startTime: Date
    let endTime: Date
    let direction: TurnDirection
    let totalAngle: Double
    let detectedEventCount: Int  // How many raw events fell within this physical turn

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

/// Over-segmentation analysis report
struct TurnOverSegmentationReport: CustomStringConvertible {
    let sessionDuration: TimeInterval
    let rawDetectedTurns: Int
    let physicalTurns: Int
    let physicalTurnDetails: [PhysicalTurn]
    let averageEventsPerPhysicalTurn: Double
    let maxEventsPerPhysicalTurn: Int
    let turnsWithMoreThan3Events: Int
    let overCountFactor: Double

    // Time-based metrics
    let totalLeftTurnTime: TimeInterval
    let totalRightTurnTime: TimeInterval
    let leftTurnPercent: Double
    let rightTurnPercent: Double

    var percentTurnsSplitIntoMultiple: Double {
        guard physicalTurns > 0 else { return 0 }
        return Double(turnsWithMoreThan3Events) / Double(physicalTurns) * 100
    }

    var description: String {
        """
        ╔══════════════════════════════════════════════════════════════════════╗
        ║              TURN OVER-SEGMENTATION ANALYSIS REPORT                  ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ Session Duration:                    \(String(format: "%10.1f", sessionDuration)) s                  ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ EVENT-BASED METRICS (potential over-counting)                        ║
        ║   Raw Detected Turn Events:          \(String(format: "%10d", rawDetectedTurns))                     ║
        ║   Physical Turns (reference model):  \(String(format: "%10d", physicalTurns))                     ║
        ║   Over-Count Factor:                 \(String(format: "%10.2f", overCountFactor))x                    ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ SEGMENTATION ANALYSIS                                                ║
        ║   Avg Events per Physical Turn:      \(String(format: "%10.2f", averageEventsPerPhysicalTurn))                     ║
        ║   Max Events per Physical Turn:      \(String(format: "%10d", maxEventsPerPhysicalTurn))                     ║
        ║   Turns Split into >3 Events:        \(String(format: "%10d", turnsWithMoreThan3Events)) (\(String(format: "%.1f", percentTurnsSplitIntoMultiple))%)           ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ TIME-BASED METRICS (should be accurate)                              ║
        ║   Total Left Turn Time:              \(String(format: "%10.1f", totalLeftTurnTime)) s                  ║
        ║   Total Right Turn Time:             \(String(format: "%10.1f", totalRightTurnTime)) s                  ║
        ║   Left Turn Percentage:              \(String(format: "%10.1f", leftTurnPercent))%%                    ║
        ║   Right Turn Percentage:             \(String(format: "%10.1f", rightTurnPercent))%%                    ║
        ╚══════════════════════════════════════════════════════════════════════╝
        """
    }
}
#endif

final class TurnAnalyzer: Resettable {
    private var previousBearing: Double?
    private var bearingHistory: [Double] = []
    private let minTurnAngle: Double = 30  // Minimum angle to count as a turn

    private(set) var leftTurns: Int = 0
    private(set) var rightTurns: Int = 0
    private(set) var totalLeftAngle: Double = 0
    private(set) var totalRightAngle: Double = 0

    // MARK: - Production Turn Tracking (with hysteresis to prevent over-segmentation)

    /// Minimum sustained angle change to register a physical turn
    private let physicalTurnThreshold: Double = 20.0

    /// Noise threshold - small oscillations below this are ignored
    private let noiseThreshold: Double = 5.0

    /// Hysteresis window after turn ends before new turn can start (seconds)
    private let hysteresisWindow: TimeInterval = 0.3

    /// Current turn accumulator
    private var currentTurnDirection: TurnDirection = .straight
    private var currentTurnAngle: Double = 0
    private var turnStartTime: Date?
    private var lastTurnEndTime: Date?
    private var lastProcessTime: Date?

    // MARK: - Diagnostic State (DEBUG)

    #if DEBUG
    /// Enable/disable diagnostic logging
    var diagnosticLoggingEnabled: Bool = true

    /// All diagnostic entries for analysis
    private(set) var diagnosticEntries: [TurnDiagnosticEntry] = []

    /// Physical turn reference model tracking
    private var physicalTurnInProgress: PhysicalTurnInProgress?
    private var completedPhysicalTurns: [PhysicalTurn] = []
    private var currentPhysicalTurnEventCount: Int = 0

    /// Time tracking for turn direction
    private var leftTurnStartTime: Date?
    private var rightTurnStartTime: Date?
    private var totalLeftTurnTime: TimeInterval = 0
    private var totalRightTurnTime: TimeInterval = 0

    /// Current state for diagnostics
    private var currentSpeed: Double = 0
    private var currentGait: String = "unknown"
    private var sessionStartTime: Date?
    #endif

    func reset() {
        previousBearing = nil
        bearingHistory = []
        leftTurns = 0
        rightTurns = 0
        totalLeftAngle = 0
        totalRightAngle = 0

        // Reset production turn tracking
        currentTurnDirection = .straight
        currentTurnAngle = 0
        turnStartTime = nil
        lastTurnEndTime = nil
        lastProcessTime = nil

        #if DEBUG
        diagnosticEntries = []
        physicalTurnInProgress = nil
        completedPhysicalTurns = []
        leftTurnStartTime = nil
        rightTurnStartTime = nil
        totalLeftTurnTime = 0
        totalRightTurnTime = 0
        sessionStartTime = nil
        #endif
    }

    #if DEBUG
    /// Update current context for diagnostics
    func updateContext(speed: Double, gait: String) {
        currentSpeed = speed
        currentGait = gait
    }

    /// Start session tracking
    func startSession() {
        sessionStartTime = Date()
        lastProcessTime = Date()
    }
    #endif

    // Process two consecutive locations to detect turns
    func processLocations(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) {
        let bearing = LocationMath.bearing(from: from, to: to)
        let now = Date()

        #if DEBUG
        if sessionStartTime == nil {
            sessionStartTime = now
        }
        #endif

        guard let prevBearing = previousBearing else {
            previousBearing = bearing
            lastProcessTime = now
            return
        }

        // Calculate angle difference using LocationMath
        let angleDiff = LocationMath.bearingChange(from: prevBearing, to: bearing)
        let absAngle = abs(angleDiff)
        let direction: TurnDirection = angleDiff > 0 ? .right : (angleDiff < 0 ? .left : .straight)

        #if DEBUG
        // Track time in turn direction
        updateTurnTimeTracking(direction: direction, timestamp: now)

        // Update physical turn reference model
        updatePhysicalTurnModel(angleDiff: angleDiff, timestamp: now)
        #endif

        // PRODUCTION: Hysteresis-based turn counting to prevent over-segmentation
        // A "turn" is only counted when cumulative angle exceeds threshold
        // and direction is consistent (not just small oscillations)

        // Check hysteresis window
        let inHysteresis = lastTurnEndTime.map { now.timeIntervalSince($0) < hysteresisWindow } ?? false

        if absAngle < noiseThreshold {
            // Small angle change - might be end of turn or noise
            if currentTurnAngle >= physicalTurnThreshold && !inHysteresis {
                // End of a significant turn - register it
                if currentTurnDirection == .left {
                    leftTurns += 1
                    totalLeftAngle += currentTurnAngle
                    #if DEBUG
                    logTurnEvent(
                        direction: .left,
                        eventType: .end,
                        bearingChange: angleDiff,
                        timestamp: now,
                        reason: "Turn completed: \(String(format: "%.1f", currentTurnAngle))° cumulative"
                    )
                    #endif
                } else if currentTurnDirection == .right {
                    rightTurns += 1
                    totalRightAngle += currentTurnAngle
                    #if DEBUG
                    logTurnEvent(
                        direction: .right,
                        eventType: .end,
                        bearingChange: angleDiff,
                        timestamp: now,
                        reason: "Turn completed: \(String(format: "%.1f", currentTurnAngle))° cumulative"
                    )
                    #endif
                }
                lastTurnEndTime = now
            }
            // Reset turn accumulator
            currentTurnDirection = .straight
            currentTurnAngle = 0
            turnStartTime = nil
        } else {
            // Significant angle change
            if currentTurnDirection == .straight || currentTurnDirection == direction {
                // Continue or start same direction turn
                if currentTurnDirection == .straight {
                    turnStartTime = now
                    currentTurnDirection = direction
                }
                currentTurnAngle += absAngle
            } else {
                // Direction changed - end current turn if significant, start new one
                if currentTurnAngle >= physicalTurnThreshold && !inHysteresis {
                    if currentTurnDirection == .left {
                        leftTurns += 1
                        totalLeftAngle += currentTurnAngle
                    } else if currentTurnDirection == .right {
                        rightTurns += 1
                        totalRightAngle += currentTurnAngle
                    }
                    lastTurnEndTime = now
                }
                // Start new turn in opposite direction
                currentTurnDirection = direction
                currentTurnAngle = absAngle
                turnStartTime = now
            }
        }

        previousBearing = bearing
        lastProcessTime = now
    }

    var turnStats: TurnStats {
        TurnStats(
            leftTurns: leftTurns,
            rightTurns: rightTurns,
            totalLeftAngle: totalLeftAngle,
            totalRightAngle: totalRightAngle
        )
    }

    // MARK: - Diagnostic Methods (DEBUG)

    #if DEBUG
    /// Log a turn event
    private func logTurnEvent(
        direction: TurnDirection,
        eventType: TurnEventType,
        bearingChange: Double,
        timestamp: Date,
        reason: String
    ) {
        currentPhysicalTurnEventCount += 1

        let entry = TurnDiagnosticEntry(
            timestamp: timestamp,
            direction: direction,
            eventType: eventType,
            bearingChange: bearingChange,
            cumulativeAngle: physicalTurnInProgress?.cumulativeAngle ?? abs(bearingChange),
            eventDuration: physicalTurnInProgress?.duration ?? 0,
            speed: currentSpeed,
            gait: currentGait,
            reason: reason
        )

        diagnosticEntries.append(entry)

        if diagnosticLoggingEnabled {
            Log.gait.debug("\(entry.description)")
        }
    }

    /// Update turn time tracking for time-based metrics
    private func updateTurnTimeTracking(direction: TurnDirection, timestamp: Date) {
        let dt = lastProcessTime.map { timestamp.timeIntervalSince($0) } ?? 0

        switch direction {
        case .left:
            // End any right turn
            if rightTurnStartTime != nil {
                rightTurnStartTime = nil
            }
            // Start left turn if needed
            if leftTurnStartTime == nil {
                leftTurnStartTime = timestamp
            }
            totalLeftTurnTime += dt

        case .right:
            // End any left turn
            if leftTurnStartTime != nil {
                leftTurnStartTime = nil
            }
            // Start right turn if needed
            if rightTurnStartTime == nil {
                rightTurnStartTime = timestamp
            }
            totalRightTurnTime += dt

        case .straight:
            leftTurnStartTime = nil
            rightTurnStartTime = nil
        }
    }

    /// Update the physical turn reference model
    private func updatePhysicalTurnModel(angleDiff: Double, timestamp: Date) {
        let absAngle = abs(angleDiff)
        let direction: TurnDirection = angleDiff > 0 ? .right : (angleDiff < 0 ? .left : .straight)

        // Check if we're still in hysteresis window
        if let lastEnd = lastTurnEndTime,
           timestamp.timeIntervalSince(lastEnd) < PhysicalTurnModel.hysteresisWindow {
            // Still in cooldown, accumulate to existing turn if same direction
            if var turn = physicalTurnInProgress, turn.direction == direction {
                turn.cumulativeAngle += absAngle
                turn.lastUpdateTime = timestamp
                turn.sampleCount += 1
                physicalTurnInProgress = turn
            }
            return
        }

        // Small angle - might be noise or end of turn
        if absAngle < PhysicalTurnModel.noiseThreshold {
            // End current turn if we have one with sufficient characteristics
            if var turn = physicalTurnInProgress {
                if turn.cumulativeAngle >= PhysicalTurnModel.minHeadingChange &&
                   turn.duration >= PhysicalTurnModel.minDuration {
                    // Valid physical turn
                    completedPhysicalTurns.append(PhysicalTurn(
                        startTime: turn.startTime,
                        endTime: timestamp,
                        direction: turn.direction,
                        totalAngle: turn.cumulativeAngle,
                        detectedEventCount: currentPhysicalTurnEventCount
                    ))
                }
                physicalTurnInProgress = nil
                lastTurnEndTime = timestamp
                currentPhysicalTurnEventCount = 0
            }
            return
        }

        // Significant angle
        if var turn = physicalTurnInProgress {
            if turn.direction == direction {
                // Continue same turn
                turn.cumulativeAngle += absAngle
                turn.lastUpdateTime = timestamp
                turn.sampleCount += 1
                physicalTurnInProgress = turn
            } else {
                // Direction changed - end current turn, start new one
                if turn.cumulativeAngle >= PhysicalTurnModel.minHeadingChange &&
                   turn.duration >= PhysicalTurnModel.minDuration {
                    completedPhysicalTurns.append(PhysicalTurn(
                        startTime: turn.startTime,
                        endTime: timestamp,
                        direction: turn.direction,
                        totalAngle: turn.cumulativeAngle,
                        detectedEventCount: currentPhysicalTurnEventCount
                    ))
                }

                // Start new turn in opposite direction
                physicalTurnInProgress = PhysicalTurnInProgress(
                    startTime: timestamp,
                    direction: direction,
                    cumulativeAngle: absAngle,
                    lastUpdateTime: timestamp,
                    sampleCount: 1
                )
                lastTurnEndTime = timestamp
                currentPhysicalTurnEventCount = 0
            }
        } else {
            // Start new turn
            physicalTurnInProgress = PhysicalTurnInProgress(
                startTime: timestamp,
                direction: direction,
                cumulativeAngle: absAngle,
                lastUpdateTime: timestamp,
                sampleCount: 1
            )
        }
    }

    /// Finalize any in-progress turn (call at end of session)
    func finalizeSession() {
        let now = Date()

        // Complete any in-progress turn
        if var turn = physicalTurnInProgress {
            if turn.cumulativeAngle >= PhysicalTurnModel.minHeadingChange &&
               turn.duration >= PhysicalTurnModel.minDuration {
                completedPhysicalTurns.append(PhysicalTurn(
                    startTime: turn.startTime,
                    endTime: now,
                    direction: turn.direction,
                    totalAngle: turn.cumulativeAngle,
                    detectedEventCount: currentPhysicalTurnEventCount
                ))
            }
            physicalTurnInProgress = nil
        }
    }

    /// Generate over-segmentation analysis report
    func generateOverSegmentationReport() -> TurnOverSegmentationReport {
        finalizeSession()

        let sessionDuration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let rawTurns = leftTurns + rightTurns
        let physicalTurnCount = completedPhysicalTurns.count

        // Calculate events per physical turn
        let eventsPerTurn = completedPhysicalTurns.map { $0.detectedEventCount }
        let avgEventsPerTurn = eventsPerTurn.isEmpty ? 0 : Double(eventsPerTurn.reduce(0, +)) / Double(eventsPerTurn.count)
        let maxEventsPerTurn = eventsPerTurn.max() ?? 0
        let turnsWithMoreThan3 = eventsPerTurn.filter { $0 > 3 }.count

        // Over-count factor
        let overCountFactor = physicalTurnCount > 0 ? Double(rawTurns) / Double(physicalTurnCount) : 0

        // Time-based percentages
        let totalTurnTime = totalLeftTurnTime + totalRightTurnTime
        let leftPercent = totalTurnTime > 0 ? (totalLeftTurnTime / totalTurnTime) * 100 : 0
        let rightPercent = totalTurnTime > 0 ? (totalRightTurnTime / totalTurnTime) * 100 : 0

        return TurnOverSegmentationReport(
            sessionDuration: sessionDuration,
            rawDetectedTurns: rawTurns,
            physicalTurns: physicalTurnCount,
            physicalTurnDetails: completedPhysicalTurns,
            averageEventsPerPhysicalTurn: avgEventsPerTurn,
            maxEventsPerPhysicalTurn: maxEventsPerTurn,
            turnsWithMoreThan3Events: turnsWithMoreThan3,
            overCountFactor: overCountFactor,
            totalLeftTurnTime: totalLeftTurnTime,
            totalRightTurnTime: totalRightTurnTime,
            leftTurnPercent: leftPercent,
            rightTurnPercent: rightPercent
        )
    }

    /// Get all physical turns for analysis
    func getPhysicalTurns() -> [PhysicalTurn] {
        finalizeSession()
        return completedPhysicalTurns
    }

    /// Get left physical turn count
    func getPhysicalLeftTurns() -> Int {
        finalizeSession()
        return completedPhysicalTurns.filter { $0.direction == .left }.count
    }

    /// Get right physical turn count
    func getPhysicalRightTurns() -> Int {
        finalizeSession()
        return completedPhysicalTurns.filter { $0.direction == .right }.count
    }
    #endif
}
