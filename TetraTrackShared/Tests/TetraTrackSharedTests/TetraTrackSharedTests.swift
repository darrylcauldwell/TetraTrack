import Testing
@testable import TetraTrackShared

@Test func heartRateZoneCalculation() async throws {
    // Test zone calculation for max HR of 180
    let zone1 = HeartRateZone.zone(for: 100, maxHR: 180)  // 55%
    #expect(zone1 == .zone1)

    let zone3 = HeartRateZone.zone(for: 135, maxHR: 180)  // 75%
    #expect(zone3 == .zone3)

    let zone5 = HeartRateZone.zone(for: 170, maxHR: 180)  // 94%
    #expect(zone5 == .zone5)
}

@Test func signalFilterSmoothing() async throws {
    var filter = SignalFilter(alpha: 0.5)

    // First value should pass through unchanged
    let first = filter.filter(10.0)
    #expect(first == 10.0)

    // Second value should be averaged
    let second = filter.filter(20.0)
    #expect(second == 15.0)  // 0.5 * 20 + 0.5 * 10 = 15
}

@Test func recoveryQualityCalculation() async throws {
    #expect(RecoveryQuality.quality(for: 45) == .excellent)
    #expect(RecoveryQuality.quality(for: 35) == .good)
    #expect(RecoveryQuality.quality(for: 25) == .average)
    #expect(RecoveryQuality.quality(for: 15) == .belowAverage)
    #expect(RecoveryQuality.quality(for: 8) == .poor)
}

@Test func watchMessageDictionaryRoundTrip() async throws {
    let original = WatchMessage.statusUpdate(
        rideState: .tracking,
        duration: 3600,
        distance: 5000,
        speed: 1.4,
        gait: "trot",
        heartRate: 145,
        heartRateZone: 3,
        averageHeartRate: 140,
        maxHeartRate: 165,
        horseName: "Star",
        rideType: "flatwork"
    )

    let dict = original.toDictionary()
    let restored = WatchMessage.from(dictionary: dict)

    #expect(restored != nil)
    #expect(restored?.rideState == .tracking)
    #expect(restored?.duration == 3600)
    #expect(restored?.horseName == "Star")
}
