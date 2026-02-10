//
//  TurnAnalyzerTests.swift
//  TetraTrackTests
//
//  Tests for TurnAnalyzer turn detection and over-segmentation hypothesis validation
//

import Testing
import Foundation
import CoreLocation
@testable import TetraTrack

// MARK: - Basic Turn Analyzer Tests

struct TurnAnalyzerTests {

    @Test func initialization() {
        let analyzer = TurnAnalyzer()

        #expect(analyzer.totalLeftAngle == 0)
        #expect(analyzer.totalRightAngle == 0)
    }

    @Test func resetClearsState() {
        let analyzer = TurnAnalyzer()

        // Simulate some turns
        let start = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let end1 = CLLocationCoordinate2D(latitude: 51.5075, longitude: -0.1270)
        let end2 = CLLocationCoordinate2D(latitude: 51.5080, longitude: -0.1270)

        analyzer.processLocations(from: start, to: end1)
        analyzer.processLocations(from: end1, to: end2)

        analyzer.reset()

        #expect(analyzer.totalLeftAngle == 0)
        #expect(analyzer.totalRightAngle == 0)
    }

    @Test func turnStatsReturnsCorrectValues() {
        let analyzer = TurnAnalyzer()

        let stats = analyzer.turnStats

        #expect(stats.totalLeftAngle == 0)
        #expect(stats.totalRightAngle == 0)
        #expect(stats.balance == 0.5)  // Default when no turns
    }
}

// MARK: - Turn Over-Segmentation Hypothesis Tests

/// Tests to validate the hypothesis that individual turns are being over-counted
/// due to threshold crossings, noise, or lack of temporal hysteresis.
struct TurnOverSegmentationTests {

    // MARK: - Synthetic Turn Stress Test

    /// This test simulates a 1-hour arena ride with 30 left turns and 30 right turns.
    /// Each turn has realistic characteristics: 60-120 degrees, 3-8 seconds duration,
    /// with micro-oscillation noise.
    ///
    /// Expected behavior:
    /// - Raw detector may detect many events (due to over-segmentation)
    /// - Reference model should detect ~60 turns total
    /// - Over-count factor should reveal the magnitude of the problem
    @Test func syntheticArenaRideOverSegmentation() {
        let analyzer = TurnAnalyzer()
        analyzer.startSession()
        analyzer.diagnosticLoggingEnabled = false  // Reduce noise during test

        // Simulation parameters
        let totalDuration: TimeInterval = 3600  // 1 hour
        let gpsUpdateRate: TimeInterval = 1.0    // 1 Hz GPS updates
        let targetLeftTurns = 30
        let targetRightTurns = 30

        // Generate synthetic ride with realistic turns
        let turnEvents = generateSyntheticTurnEvents(
            duration: totalDuration,
            leftTurns: targetLeftTurns,
            rightTurns: targetRightTurns
        )

        // Process all GPS samples through the analyzer
        var previousCoord: CLLocationCoordinate2D?
        let baseCoord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

        for event in turnEvents {
            let coord = coordinateFromBearing(
                base: baseCoord,
                bearing: event.bearing,
                distance: event.speed * gpsUpdateRate
            )

            if let prev = previousCoord {
                analyzer.updateContext(speed: event.speed, gait: event.gait)
                analyzer.processLocations(from: prev, to: coord)
            }

            previousCoord = coord
        }

        // Generate and print the over-segmentation report
        let report = analyzer.generateOverSegmentationReport()
        print(report)

        // Calculate expected vs actual
        let expectedPhysicalTurns = targetLeftTurns + targetRightTurns
        print("""
        ╔══════════════════════════════════════════════════════════════════════╗
        ║              HYPOTHESIS VALIDATION SUMMARY                           ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ Expected Physical Turns:             \(String(format: "%10d", expectedPhysicalTurns))                     ║
        ║ Physical Turns (reference model):    \(String(format: "%10d", report.physicalTurns))                     ║
        ║ Over-Count Factor:                   \(String(format: "%10.2f", report.overCountFactor))x                    ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ DIAGNOSIS:                                                           ║
        """)

        if report.overCountFactor > 2.0 {
            print("║   HYPOTHESIS CONFIRMED: Significant over-counting detected         ║")
            print("║   Single physical turns are being split into multiple events       ║")
        } else if report.overCountFactor > 1.5 {
            print("║   HYPOTHESIS PARTIALLY CONFIRMED: Moderate over-counting           ║")
        } else {
            print("║   HYPOTHESIS NOT CONFIRMED: Turn counting appears accurate         ║")
        }

        print("╚══════════════════════════════════════════════════════════════════════╝")

        // Assertions - these are diagnostic, not hard failures
        // The test is designed to REVEAL the over-counting, not enforce a fix

        // Reference model should detect approximately the expected turns
        let referenceAccuracy = Double(report.physicalTurns) / Double(expectedPhysicalTurns)
        #expect(referenceAccuracy > 0.7, "Reference model should detect at least 70% of expected turns")
        #expect(referenceAccuracy < 1.5, "Reference model should not over-detect by more than 50%")

        // Document the over-count factor for analysis
        print("\nOver-count factor: \(String(format: "%.2f", report.overCountFactor))x")
        print("This means each physical turn is being counted as ~\(String(format: "%.1f", report.overCountFactor)) events")

        // Time-based metrics should be stable regardless of event over-counting
        let turnTimeBalance = report.leftTurnPercent / (report.leftTurnPercent + report.rightTurnPercent) * 100
        #expect(turnTimeBalance > 40 && turnTimeBalance < 60, "Time-based turn balance should be ~50%")
    }

    /// Test a single continuous turn to see how many events it generates
    @Test func singleContinuousTurnSegmentation() {
        let analyzer = TurnAnalyzer()
        analyzer.startSession()
        analyzer.diagnosticLoggingEnabled = true

        // Simulate a single 90-degree left turn over 5 seconds
        // GPS at 1 Hz = 5 samples
        // Each sample should show ~18 degrees of bearing change

        let turnDuration = 5.0
        let totalAngle = 90.0
        let samplesPerSecond = 1.0
        let sampleCount = Int(turnDuration * samplesPerSecond)
        let anglePerSample = totalAngle / Double(sampleCount)

        print("""
        ╔══════════════════════════════════════════════════════════════════════╗
        ║              SINGLE TURN SEGMENTATION TEST                           ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ Turn Parameters:                                                     ║
        ║   Total angle:        \(String(format: "%6.1f", totalAngle))°                                      ║
        ║   Duration:           \(String(format: "%6.1f", turnDuration)) seconds                                ║
        ║   GPS samples:        \(String(format: "%6d", sampleCount))                                        ║
        ║   Angle per sample:   \(String(format: "%6.1f", anglePerSample))°                                      ║
        ╚══════════════════════════════════════════════════════════════════════╝
        """)

        var currentBearing = 0.0
        let baseCoord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        var previousCoord: CLLocationCoordinate2D?

        for i in 0..<sampleCount {
            // Add small oscillation noise (±3 degrees)
            let noise = Double.random(in: -3...3)
            let noisyAngleChange = anglePerSample + noise

            currentBearing -= noisyAngleChange  // Negative for left turn

            let coord = coordinateFromBearing(
                base: baseCoord,
                bearing: currentBearing,
                distance: 5.0  // 5 meters per second
            )

            if let prev = previousCoord {
                analyzer.updateContext(speed: 5.0, gait: "canter")
                analyzer.processLocations(from: prev, to: coord)
            }

            previousCoord = coord
        }

        let report = analyzer.generateOverSegmentationReport()

        print("""
        RESULTS:
        ═══════════════════════════════════════════════════════════════════════
        Total left angle:           \(String(format: "%.1f", analyzer.totalLeftAngle))°
        Total right angle:          \(String(format: "%.1f", analyzer.totalRightAngle))°
        Physical turns detected:    \(report.physicalTurns)
        ═══════════════════════════════════════════════════════════════════════
        """)

        print("Expected: 1 physical turn")
        print("Total angle accumulated: \(String(format: "%.1f", analyzer.totalLeftAngle + analyzer.totalRightAngle))°")
    }

    /// Test turn counting with varying GPS sample rates
    @Test func turnCountingAtDifferentSampleRates() {
        print("""
        ╔══════════════════════════════════════════════════════════════════════╗
        ║              GPS SAMPLE RATE IMPACT ON TURN COUNTING                 ║
        ╚══════════════════════════════════════════════════════════════════════╝
        """)

        let sampleRates = [0.5, 1.0, 2.0, 5.0]  // Hz
        let turnAngle = 90.0
        let turnDuration = 4.0

        for rate in sampleRates {
            let analyzer = TurnAnalyzer()
            analyzer.startSession()
            analyzer.diagnosticLoggingEnabled = false

            let sampleCount = Int(turnDuration * rate)
            let anglePerSample = turnAngle / Double(sampleCount)

            var currentBearing = 0.0
            let baseCoord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
            var previousCoord: CLLocationCoordinate2D?

            for _ in 0..<sampleCount {
                currentBearing -= anglePerSample

                let coord = coordinateFromBearing(
                    base: baseCoord,
                    bearing: currentBearing,
                    distance: 5.0 / rate
                )

                if let prev = previousCoord {
                    analyzer.processLocations(from: prev, to: coord)
                }

                previousCoord = coord
            }

            let report = analyzer.generateOverSegmentationReport()

            print("""
            Sample Rate: \(String(format: "%4.1f", rate)) Hz
              Samples: \(String(format: "%3d", sampleCount))
              Angle/sample: \(String(format: "%5.1f", anglePerSample))°
              Total angle: \(String(format: "%6.1f", analyzer.totalLeftAngle + analyzer.totalRightAngle))°
              Physical turns: \(String(format: "%3d", report.physicalTurns))
              Will trigger threshold (\(anglePerSample >= 30 ? "YES" : "NO"))
            """)
        }
    }

    // MARK: - Helper Functions

    /// Generate synthetic turn events for a simulated ride
    private func generateSyntheticTurnEvents(
        duration: TimeInterval,
        leftTurns: Int,
        rightTurns: Int
    ) -> [SyntheticGPSEvent] {
        var events: [SyntheticGPSEvent] = []
        var currentBearing = 0.0
        var currentTime: TimeInterval = 0
        let gpsInterval: TimeInterval = 1.0

        // Calculate turn spacing
        let totalTurns = leftTurns + rightTurns
        let avgTimeBetweenTurns = duration / Double(totalTurns + 1)

        // Create turn schedule
        var turnSchedule: [(time: TimeInterval, direction: TurnDirection, angle: Double, duration: Double)] = []

        for i in 0..<totalTurns {
            let direction: TurnDirection = i % 2 == 0 ? .left : .right
            let turnTime = avgTimeBetweenTurns * Double(i + 1)
            let turnAngle = Double.random(in: 60...120)
            let turnDuration = Double.random(in: 3...8)

            turnSchedule.append((turnTime, direction, turnAngle, turnDuration))
        }

        var turnIndex = 0

        while currentTime < duration {
            var inTurn = false
            var turnProgress: Double = 0

            // Check if we're in a turn
            if turnIndex < turnSchedule.count {
                let turn = turnSchedule[turnIndex]
                let turnStart = turn.time
                let turnEnd = turn.time + turn.duration

                if currentTime >= turnStart && currentTime < turnEnd {
                    inTurn = true
                    turnProgress = (currentTime - turnStart) / turn.duration

                    // Calculate bearing change for this segment
                    let angleRate = turn.angle / turn.duration

                    // Add micro-oscillation noise (±3 deg/sec)
                    let noise = Double.random(in: -3...3)
                    let angleChange = (angleRate + noise) * gpsInterval

                    if turn.direction == .left {
                        currentBearing -= angleChange
                    } else {
                        currentBearing += angleChange
                    }
                } else if currentTime >= turnEnd {
                    turnIndex += 1
                }
            }

            // Normalize bearing
            while currentBearing > 180 { currentBearing -= 360 }
            while currentBearing < -180 { currentBearing += 360 }

            let speed = inTurn ? Double.random(in: 4...6) : Double.random(in: 3...7)
            let gait = speed > 5 ? "canter" : (speed > 3 ? "trot" : "walk")

            events.append(SyntheticGPSEvent(
                time: currentTime,
                bearing: currentBearing,
                speed: speed,
                gait: gait,
                inTurn: inTurn
            ))

            currentTime += gpsInterval
        }

        return events
    }

    /// Calculate a coordinate from a base point given bearing and distance
    private func coordinateFromBearing(
        base: CLLocationCoordinate2D,
        bearing: Double,
        distance: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0  // meters
        let bearingRad = bearing * .pi / 180
        let lat1 = base.latitude * .pi / 180
        let lon1 = base.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                       cos(lat1) * sin(distance / earthRadius) * cos(bearingRad))

        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / earthRadius) * cos(lat1),
                                cos(distance / earthRadius) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}

/// Synthetic GPS event for testing
struct SyntheticGPSEvent {
    let time: TimeInterval
    let bearing: Double
    let speed: Double
    let gait: String
    let inTurn: Bool
}

// MARK: - Turn Count vs Percentage Validation Tests

struct TurnMetricsValidationTests {

    /// Validates that time-based percentages remain stable while event counts may inflate
    @Test func timeBasedVsEventBasedMetrics() {
        let analyzer = TurnAnalyzer()
        analyzer.startSession()
        analyzer.diagnosticLoggingEnabled = false

        // Simulate equal time turning left and right
        // 100 seconds total: 50s left turns, 50s right turns
        let baseCoord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        var previousCoord: CLLocationCoordinate2D?
        var currentBearing = 0.0

        // Left turns for 50 samples (50 seconds at 1 Hz)
        for i in 0..<50 {
            let angle = Double.random(in: 25...45)  // Some above threshold, some below
            currentBearing -= angle

            let coord = coordinateFromBearing(
                base: baseCoord,
                bearing: currentBearing,
                distance: 5.0
            )

            if let prev = previousCoord {
                analyzer.processLocations(from: prev, to: coord)
            }

            previousCoord = coord
        }

        let leftAngleAfterLeftPhase = analyzer.totalLeftAngle

        // Right turns for 50 samples
        for i in 0..<50 {
            let angle = Double.random(in: 25...45)
            currentBearing += angle

            let coord = coordinateFromBearing(
                base: baseCoord,
                bearing: currentBearing,
                distance: 5.0
            )

            if let prev = previousCoord {
                analyzer.processLocations(from: prev, to: coord)
            }

            previousCoord = coord
        }

        let report = analyzer.generateOverSegmentationReport()

        print("""
        ╔══════════════════════════════════════════════════════════════════════╗
        ║              ANGLE-BASED vs TIME-BASED METRICS                       ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ ANGLE-BASED:                                                         ║
        ║   Left turn angle:        \(String(format: "%10.1f", analyzer.totalLeftAngle))°                    ║
        ║   Right turn angle:       \(String(format: "%10.1f", analyzer.totalRightAngle))°                    ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ TIME-BASED (should be accurate):                                     ║
        ║   Left turn time:         \(String(format: "%10.1f", report.totalLeftTurnTime)) s                  ║
        ║   Right turn time:        \(String(format: "%10.1f", report.totalRightTurnTime)) s                  ║
        ║   Time-based balance:     \(String(format: "%10.1f", report.leftTurnPercent))%%                    ║
        ╚══════════════════════════════════════════════════════════════════════╝
        """)

        // Time-based metrics should show ~50/50 balance
        #expect(report.leftTurnPercent > 40 && report.leftTurnPercent < 60,
                "Time-based left turn percentage should be ~50%")

        // Angle and time-based metrics should both reflect balanced turns
        print("\nTime-based balance (\(String(format: "%.1f", report.leftTurnPercent))%) is the reliable metric")
    }

    private func coordinateFromBearing(
        base: CLLocationCoordinate2D,
        bearing: Double,
        distance: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6371000.0
        let bearingRad = bearing * .pi / 180
        let lat1 = base.latitude * .pi / 180
        let lon1 = base.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                       cos(lat1) * sin(distance / earthRadius) * cos(bearingRad))

        let lon2 = lon1 + atan2(sin(bearingRad) * sin(distance / earthRadius) * cos(lat1),
                                cos(distance / earthRadius) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
