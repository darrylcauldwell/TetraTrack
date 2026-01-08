//
//  HorseModelTests.swift
//  TrackRideTests
//
//  Tests for Horse model functionality
//

import Testing
import Foundation
@testable import TetraTrack

struct HorseModelTests {

    // MARK: - Basic Properties

    @Test func horseInitializationWithDefaults() {
        let horse = Horse()

        #expect(horse.name == "")
        #expect(horse.breed == "")
        #expect(horse.color == "")
        #expect(horse.isArchived == false)
        #expect(horse.heightHands == nil)
        #expect(horse.weight == nil)
        #expect(horse.dateOfBirth == nil)
    }

    @Test func horsePropertyAssignment() {
        let horse = Horse()
        horse.name = "Thunder"
        horse.breed = "Thoroughbred"
        horse.color = "Bay"

        #expect(horse.name == "Thunder")
        #expect(horse.breed == "Thoroughbred")
        #expect(horse.color == "Bay")
    }

    // MARK: - Height Formatting

    @Test func formattedHeightWithValidHeight() {
        let horse = Horse()
        horse.heightHands = 15.2

        #expect(horse.formattedHeight == "15.2hh")
    }

    @Test func formattedHeightWithZeroInches() {
        let horse = Horse()
        horse.heightHands = 16.0

        #expect(horse.formattedHeight == "16.0hh")
    }

    @Test func formattedHeightWithNoHeight() {
        let horse = Horse()

        #expect(horse.formattedHeight == "Not set")
    }

    @Test func formattedHeightWithThreeInches() {
        let horse = Horse()
        horse.heightHands = 14.3

        #expect(horse.formattedHeight == "14.3hh")
    }

    // MARK: - Weight Formatting

    @Test func formattedWeightWithValidWeight() {
        let horse = Horse()
        horse.weight = 500.0

        #expect(horse.formattedWeight == "500 kg")
    }

    @Test func formattedWeightWithNoWeight() {
        let horse = Horse()

        #expect(horse.formattedWeight == "Not set")
    }

    // MARK: - Age Calculation

    @Test func ageCalculationForYoungHorse() {
        let horse = Horse()
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())
        horse.dateOfBirth = twoYearsAgo

        #expect(horse.age == 2)
    }

    @Test func ageCalculationForOlderHorse() {
        let horse = Horse()
        let tenYearsAgo = Calendar.current.date(byAdding: .year, value: -10, to: Date())
        horse.dateOfBirth = tenYearsAgo

        #expect(horse.age == 10)
    }

    @Test func ageCalculationWithNoDOB() {
        let horse = Horse()

        #expect(horse.age == nil)
    }

    @Test func formattedAgeWithSingleYear() {
        let horse = Horse()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())
        horse.dateOfBirth = oneYearAgo

        #expect(horse.formattedAge == "1 year")
    }

    @Test func formattedAgeWithMultipleYears() {
        let horse = Horse()
        let fiveYearsAgo = Calendar.current.date(byAdding: .year, value: -5, to: Date())
        horse.dateOfBirth = fiveYearsAgo

        #expect(horse.formattedAge == "5 years")
    }

    @Test func formattedAgeWithNoDOB() {
        let horse = Horse()

        #expect(horse.formattedAge == "Unknown")
    }

    // MARK: - Archive Status

    @Test func archiveHorse() {
        let horse = Horse()
        horse.isArchived = false

        horse.isArchived = true

        #expect(horse.isArchived == true)
    }

    // MARK: - Statistics

    @Test func rideCountEmpty() {
        let horse = Horse()

        #expect(horse.rideCount == 0)
    }

    @Test func totalDistanceEmpty() {
        let horse = Horse()

        #expect(horse.totalDistance == 0)
    }

    @Test func totalDurationEmpty() {
        let horse = Horse()

        #expect(horse.totalDuration == 0)
    }

    @Test func formattedTotalDistanceMeters() {
        let horse = Horse()
        // No rides, so total distance is 0m
        #expect(horse.formattedTotalDistance == "0 m")
    }

    @Test func formattedTotalDurationEmpty() {
        let horse = Horse()
        // No rides, so total duration is 0
        #expect(horse.formattedTotalDuration == "0 min")
    }

    // MARK: - Last Ride

    @Test func lastRideWithNoRides() {
        let horse = Horse()

        #expect(horse.lastRide == nil)
    }

    @Test func daysSinceLastRideWithNoRides() {
        let horse = Horse()

        #expect(horse.daysSinceLastRide == nil)
    }

    @Test func formattedLastRideWithNoRides() {
        let horse = Horse()

        #expect(horse.formattedLastRide == "No rides yet")
    }

    // MARK: - Media Properties

    @Test func hasPhotoWithNoPhoto() {
        let horse = Horse()

        #expect(horse.hasPhoto == false)
    }

    @Test func hasVideosWithNoVideos() {
        let horse = Horse()

        #expect(horse.hasVideos == false)
    }

    @Test func hasMediaWithNoMedia() {
        let horse = Horse()

        #expect(horse.hasMedia == false)
    }
}
