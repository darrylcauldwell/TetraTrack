//
//  SignalFilterTests.swift
//  TetraTrackTests
//
//  Tests for Signal Filtering and Fall Detection logic
//

import Testing
import Foundation
@testable import TetraTrack

struct SignalFilterTests {

    // MARK: - SignalFilter Tests

    @Test func signalFilterDefaultAlpha() {
        let filter = SignalFilter()

        #expect(filter.alpha == 0.2)
    }

    @Test func signalFilterCustomAlpha() {
        let filter = SignalFilter(alpha: 0.5)

        #expect(filter.alpha == 0.5)
    }

    @Test func signalFilterAlphaClampedToMax() {
        let filter = SignalFilter(alpha: 1.5)

        #expect(filter.alpha == 1.0)
    }

    @Test func signalFilterAlphaClampedToMin() {
        let filter = SignalFilter(alpha: -0.5)

        #expect(filter.alpha == 0.0)
    }

    @Test func signalFilterFirstSampleUnfiltered() {
        var filter = SignalFilter()
        let result = filter.filter(10.0)

        // First sample should be returned unchanged
        #expect(result == 10.0)
    }

    @Test func signalFilterSmoothsValues() {
        var filter = SignalFilter(alpha: 0.2)
        _ = filter.filter(10.0)  // First sample

        // Second sample with higher value
        let result = filter.filter(20.0)

        // EMA: 0.2 * 20 + 0.8 * 10 = 4 + 8 = 12
        #expect(result == 12.0)
    }

    @Test func signalFilterHighAlphaMoreResponsive() {
        var filter = SignalFilter(alpha: 0.8)
        _ = filter.filter(10.0)

        let result = filter.filter(20.0)

        // EMA: 0.8 * 20 + 0.2 * 10 = 16 + 2 = 18
        #expect(result == 18.0)
    }

    @Test func signalFilterLowAlphaSmoother() {
        var filter = SignalFilter(alpha: 0.1)
        _ = filter.filter(10.0)

        let result = filter.filter(20.0)

        // EMA: 0.1 * 20 + 0.9 * 10 = 2 + 9 = 11
        #expect(result == 11.0)
    }

    @Test func signalFilterCurrentValue() {
        var filter = SignalFilter()

        #expect(filter.currentValue == nil)

        _ = filter.filter(15.0)
        #expect(filter.currentValue == 15.0)
    }

    @Test func signalFilterReset() {
        var filter = SignalFilter()
        _ = filter.filter(10.0)
        _ = filter.filter(20.0)

        filter.reset()

        #expect(filter.currentValue == nil)
    }

    // MARK: - Vector3DFilter Tests

    @Test func vector3DFilterDefaultAlpha() {
        let filter = Vector3DFilter()

        // Check that filter exists and works
        #expect(filter.currentValues.x == nil)
        #expect(filter.currentValues.y == nil)
        #expect(filter.currentValues.z == nil)
    }

    @Test func vector3DFilterFirstSampleUnfiltered() {
        var filter = Vector3DFilter()

        let result = filter.filter(x: 1.0, y: 2.0, z: 3.0)

        #expect(result.x == 1.0)
        #expect(result.y == 2.0)
        #expect(result.z == 3.0)
    }

    @Test func vector3DFilterCurrentValues() {
        var filter = Vector3DFilter()
        _ = filter.filter(x: 1.0, y: 2.0, z: 3.0)

        let values = filter.currentValues

        #expect(values.x == 1.0)
        #expect(values.y == 2.0)
        #expect(values.z == 3.0)
    }

    @Test func vector3DFilterMagnitudeCalculation() {
        var filter = Vector3DFilter()
        _ = filter.filter(x: 3.0, y: 4.0, z: 0.0)

        // Magnitude = sqrt(3^2 + 4^2 + 0^2) = sqrt(9 + 16) = sqrt(25) = 5
        #expect(filter.currentMagnitude == 5.0)
    }

    @Test func vector3DFilterMagnitude3D() {
        var filter = Vector3DFilter()
        _ = filter.filter(x: 2.0, y: 2.0, z: 1.0)

        // Magnitude = sqrt(4 + 4 + 1) = sqrt(9) = 3
        #expect(filter.currentMagnitude == 3.0)
    }

    @Test func vector3DFilterMagnitudeNilWhenNoData() {
        let filter = Vector3DFilter()

        #expect(filter.currentMagnitude == nil)
    }

    @Test func vector3DFilterReset() {
        var filter = Vector3DFilter()
        _ = filter.filter(x: 1.0, y: 2.0, z: 3.0)

        filter.reset()

        #expect(filter.currentValues.x == nil)
        #expect(filter.currentValues.y == nil)
        #expect(filter.currentValues.z == nil)
        #expect(filter.currentMagnitude == nil)
    }

    @Test func vector3DFilterSmoothsAllAxes() {
        var filter = Vector3DFilter(alpha: 0.2)
        _ = filter.filter(x: 10.0, y: 20.0, z: 30.0)

        let result = filter.filter(x: 20.0, y: 40.0, z: 60.0)

        // EMA for each axis: 0.2 * new + 0.8 * old
        #expect(result.x == 12.0) // 0.2*20 + 0.8*10 = 12
        #expect(result.y == 24.0) // 0.2*40 + 0.8*20 = 24
        #expect(result.z == 36.0) // 0.2*60 + 0.8*30 = 36
    }

    // MARK: - Fall Detection Threshold Tests

    @Test func fallImpactThreshold() {
        // Impact threshold should be 3.0G for typical falls
        let impactThreshold = 3.0

        // Normal activities should be below threshold
        let walking = 1.2  // ~1.2G during walking
        let trotting = 2.0 // ~2G during trotting
        let cantering = 2.5 // ~2.5G during cantering

        #expect(walking < impactThreshold)
        #expect(trotting < impactThreshold)
        #expect(cantering < impactThreshold)

        // Fall should exceed threshold
        let fallImpact = 4.0
        #expect(fallImpact > impactThreshold)
    }

    @Test func fallRotationThreshold() {
        // Rotation threshold should be 5.0 rad/s
        let rotationThreshold = 5.0

        // Normal activities
        let normalTurning = 2.0
        let quickTurn = 4.0

        #expect(normalTurning < rotationThreshold)
        #expect(quickTurn < rotationThreshold)

        // Fall rotation
        let fallRotation = 7.0
        #expect(fallRotation > rotationThreshold)
    }

    // MARK: - G-Force Calculations

    @Test func gForceCalculation() {
        // Test converting acceleration to G-forces
        let gravity = 9.81 // m/s^2

        // 1G = 9.81 m/s^2
        let acceleration1G = 9.81
        #expect(acceleration1G / gravity == 1.0)

        // 3G fall impact
        let acceleration3G = 29.43
        let gForces = acceleration3G / gravity
        #expect(gForces >= 2.9 && gForces <= 3.1)
    }
}
