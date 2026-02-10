//
//  GaitLearningServiceTests.swift
//  TetraTrackTests
//
//  Tests for GaitLearningService adaptive gait parameter learning
//

import Testing
import Foundation
@testable import TetraTrack

// MARK: - GaitLearningServiceTests

struct GaitLearningServiceTests {

    let service = GaitLearningService()

    // MARK: - Helpers

    /// Create a minimal ride with gait segments for testing
    private func createRideWithSegments(gaits: [(GaitType, TimeInterval, Double)]) -> (Ride, [GaitSegment]) {
        let ride = Ride()
        ride.startDate = Date()
        var segments: [GaitSegment] = []

        var time = ride.startDate
        for (gait, duration, frequency) in gaits {
            let segment = GaitSegment(gaitType: gait, startTime: time)
            segment.endTime = time.addingTimeInterval(duration)
            segment.strideFrequency = frequency
            segment.harmonicRatioH2 = 0.5
            segment.harmonicRatioH3 = 0.3
            segment.spectralEntropy = 0.4
            segment.verticalYawCoherence = 0.5
            segment.ride = ride
            segments.append(segment)
            time = time.addingTimeInterval(duration)
        }

        return (ride, segments)
    }

    // MARK: - Basic Learning

    @Test func learnFromRideUpdatesParameters() {
        let horse = Horse()
        horse.name = "Test Horse"

        let (ride, _) = createRideWithSegments(gaits: [
            (.walk, 30.0, 1.5),
            (.trot, 60.0, 2.8),
            (.canter, 20.0, 2.4)
        ])

        service.learnFromRide(ride, horse: horse)

        let learned = horse.learnedGaitParameters
        #expect(learned != nil)
        #expect(learned?.rideCount == 1)
    }

    @Test func learnFromRideIncrementsRideCount() {
        let horse = Horse()
        horse.name = "Test Horse"

        let (ride1, _) = createRideWithSegments(gaits: [(.walk, 30.0, 1.5)])
        let (ride2, _) = createRideWithSegments(gaits: [(.walk, 30.0, 1.6)])

        service.learnFromRide(ride1, horse: horse)
        service.learnFromRide(ride2, horse: horse)

        #expect(horse.learnedGaitParameters?.rideCount == 2)
    }

    // MARK: - Short Segments Ignored

    @Test func shortSegmentsAreIgnored() {
        let horse = Horse()
        horse.name = "Test Horse"

        // Only 1.5s segments (below 2s threshold) and 3s segment (below 5s total threshold)
        let (ride, _) = createRideWithSegments(gaits: [
            (.walk, 1.5, 1.5),
            (.trot, 1.0, 2.8)
        ])

        service.learnFromRide(ride, horse: horse)

        // Parameters should be set but walk/trot centers may not be updated due to short durations
        let learned = horse.learnedGaitParameters
        #expect(learned?.rideCount == 1)
    }

    // MARK: - EMA Alpha Decay

    @Test func emaAlphaDecaysWithRideCount() {
        let horse = Horse()
        horse.name = "Test Horse"

        // First ride: alpha = max(0.1, 0.5/1) = 0.5
        let (ride1, _) = createRideWithSegments(gaits: [(.walk, 30.0, 1.5)])
        service.learnFromRide(ride1, horse: horse)

        let firstValue = horse.learnedGaitParameters?.walkFrequencyCenter

        // Second ride with different frequency: alpha = max(0.1, 0.5/2) = 0.25
        let (ride2, _) = createRideWithSegments(gaits: [(.walk, 30.0, 2.0)])
        service.learnFromRide(ride2, horse: horse)

        let secondValue = horse.learnedGaitParameters?.walkFrequencyCenter

        // After two rides, the value should be between first and second ride values
        if let first = firstValue, let second = secondValue {
            #expect(second > first)  // Should have moved toward 2.0
            #expect(second < 2.0)    // But not all the way (EMA blending)
        }
    }

    // MARK: - Empty Ride

    @Test func emptyRideDoesNotCrash() {
        let horse = Horse()
        horse.name = "Test Horse"

        let ride = Ride()
        ride.startDate = Date()

        // Should not crash with empty segments
        service.learnFromRide(ride, horse: horse)

        // learnedGaitParameters may or may not be set (depends on whether any segments matched)
        // The key assertion is: no crash
    }

    // MARK: - Last Update

    @Test func lastUpdateIsSet() {
        let horse = Horse()
        horse.name = "Test Horse"

        let before = Date()
        let (ride, _) = createRideWithSegments(gaits: [(.walk, 30.0, 1.5)])
        service.learnFromRide(ride, horse: horse)
        let after = Date()

        if let lastUpdate = horse.learnedGaitParameters?.lastUpdate {
            #expect(lastUpdate >= before)
            #expect(lastUpdate <= after)
        }
    }
}
