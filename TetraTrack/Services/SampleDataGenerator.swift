//
//  SampleDataGenerator.swift
//  TetraTrack
//
//  Generates sample ride data for testing/demo purposes
//

import Foundation
import SwiftData

struct SampleDataGenerator {

    static func generateSampleData(in context: ModelContext) {
        // Check if we already have sample data
        let descriptor = FetchDescriptor<Ride>()
        let existingRides = (try? context.fetch(descriptor)) ?? []
        guard existingRides.isEmpty else { return }

        // Create a sample horse first
        let horse = Horse()
        horse.name = "Bella"
        horse.breed = "Irish Sport Horse"
        horse.color = "Bay"
        horse.heightHands = 16.1
        horse.dateOfBirth = Calendar.current.date(byAdding: .year, value: -8, to: Date())
        context.insert(horse)

        // Generate sample rides
        generateHackingRide(in: context, horse: horse, daysAgo: 1)
        generateFlatworkRide(in: context, horse: horse, daysAgo: 3)
        generateLongHackRide(in: context, horse: horse, daysAgo: 5)
        generateCrossCountryRide(in: context, horse: horse, daysAgo: 7)

        try? context.save()
    }

    // MARK: - Sample Rides

    private static func generateHackingRide(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = Ride()
        ride.name = "Morning Hack"
        ride.rideTypeValue = RideType.hack.rawValue
        ride.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        ride.endDate = ride.startDate.addingTimeInterval(3600) // 1 hour
        ride.totalDuration = 3600
        ride.totalDistance = 8500 // 8.5 km
        ride.elevationGain = 85
        ride.elevationLoss = 80
        ride.maxSpeed = 7.5
        ride.totalLeftAngle = 1080
        ride.totalRightAngle = 1260
        ride.leftLeadDuration = 180
        ride.rightLeadDuration = 210
        ride.averageHeartRate = 125
        ride.maxHeartRate = 165
        ride.minHeartRate = 95
        ride.horse = horse
        ride.notes = "Lovely morning ride through the woods. Bella was forward but relaxed."

        context.insert(ride)

        // Add gait segments
        let segments = [
            (GaitType.walk, 600.0, 1200.0),   // 10 min walk warm-up
            (GaitType.trot, 900.0, 2800.0),   // 15 min trot
            (GaitType.walk, 300.0, 500.0),    // 5 min walk break
            (GaitType.canter, 420.0, 2100.0), // 7 min canter
            (GaitType.trot, 480.0, 1200.0),   // 8 min trot
            (GaitType.walk, 600.0, 700.0),    // 10 min walk cool-down
        ]

        var currentTime = ride.startDate
        for (gait, duration, distance) in segments {
            let segment = GaitSegment(gaitType: gait, startTime: currentTime)
            segment.endTime = currentTime.addingTimeInterval(duration)
            segment.distance = distance
            segment.averageSpeed = distance / duration
            segment.rhythmScore = Double.random(in: 75...95)
            if gait == .canter {
                segment.leadValue = Bool.random() ? Lead.left.rawValue : Lead.right.rawValue
                segment.leadConfidence = Double.random(in: 0.8...0.95)
            }
            segment.ride = ride
            context.insert(segment)
            currentTime = currentTime.addingTimeInterval(duration)
        }

        // Add location points (simplified route near UK coordinates)
        generateRoutePoints(for: ride, in: context, startLat: 51.5, startLon: -1.2)
    }

    private static func generateFlatworkRide(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = Ride()
        ride.name = "Arena Schooling"
        ride.rideTypeValue = RideType.schooling.rawValue
        ride.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        ride.endDate = ride.startDate.addingTimeInterval(2700) // 45 min
        ride.totalDuration = 2700
        ride.totalDistance = 4200 // 4.2 km
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 5.5
        ride.totalLeftAngle = 4500
        ride.totalRightAngle = 4200
        ride.leftLeadDuration = 240
        ride.rightLeadDuration = 255
        ride.leftReinDuration = 780
        ride.rightReinDuration = 820
        ride.leftReinSymmetry = 82
        ride.rightReinSymmetry = 85
        ride.leftReinRhythm = 78
        ride.rightReinRhythm = 81
        ride.averageHeartRate = 118
        ride.maxHeartRate = 145
        ride.minHeartRate = 90
        ride.horse = horse
        ride.notes = "Focused on transitions and bend. Good improvement on right rein."

        context.insert(ride)

        // Add gait segments for arena work
        let segments = [
            (GaitType.walk, 300.0, 400.0),    // 5 min walk warm-up
            (GaitType.trot, 600.0, 1500.0),   // 10 min trot
            (GaitType.walk, 120.0, 150.0),    // 2 min walk
            (GaitType.canter, 300.0, 900.0),  // 5 min canter
            (GaitType.trot, 480.0, 800.0),    // 8 min trot
            (GaitType.canter, 360.0, 750.0),  // 6 min canter
            (GaitType.walk, 540.0, 700.0),    // 9 min walk cool-down
        ]

        var currentTime = ride.startDate
        for (gait, duration, distance) in segments {
            let segment = GaitSegment(gaitType: gait, startTime: currentTime)
            segment.endTime = currentTime.addingTimeInterval(duration)
            segment.distance = distance
            segment.averageSpeed = distance / duration
            segment.rhythmScore = Double.random(in: 80...95)
            if gait == .canter {
                segment.leadValue = Bool.random() ? Lead.left.rawValue : Lead.right.rawValue
                segment.leadConfidence = Double.random(in: 0.85...0.98)
            }
            segment.ride = ride
            context.insert(segment)
            currentTime = currentTime.addingTimeInterval(duration)
        }

        // Arena is small, generate tight route
        generateArenaPoints(for: ride, in: context, centerLat: 51.5, centerLon: -1.2)
    }

    private static func generateLongHackRide(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = Ride()
        ride.name = "Weekend Trail Ride"
        ride.rideTypeValue = RideType.hack.rawValue
        ride.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        ride.endDate = ride.startDate.addingTimeInterval(7200) // 2 hours
        ride.totalDuration = 7200
        ride.totalDistance = 15800 // 15.8 km
        ride.elevationGain = 210
        ride.elevationLoss = 195
        ride.maxSpeed = 8.2
        ride.totalLeftAngle = 2520
        ride.totalRightAngle = 2790
        ride.leftLeadDuration = 420
        ride.rightLeadDuration = 480
        ride.averageHeartRate = 130
        ride.maxHeartRate = 172
        ride.minHeartRate = 88
        ride.horse = horse
        ride.notes = "Great long ride with some good canters on the bridleway. Bella loved it!"

        context.insert(ride)

        // Add gait segments
        let segments = [
            (GaitType.walk, 900.0, 1500.0),   // 15 min walk
            (GaitType.trot, 1200.0, 3800.0),  // 20 min trot
            (GaitType.canter, 600.0, 3000.0), // 10 min canter
            (GaitType.walk, 600.0, 1000.0),   // 10 min walk
            (GaitType.trot, 900.0, 2700.0),   // 15 min trot
            (GaitType.canter, 300.0, 1500.0), // 5 min canter
            (GaitType.trot, 600.0, 1500.0),   // 10 min trot
            (GaitType.walk, 1100.0, 1800.0),  // ~18 min walk cool-down
        ]

        var currentTime = ride.startDate
        for (gait, duration, distance) in segments {
            let segment = GaitSegment(gaitType: gait, startTime: currentTime)
            segment.endTime = currentTime.addingTimeInterval(duration)
            segment.distance = distance
            segment.averageSpeed = distance / duration
            segment.rhythmScore = Double.random(in: 70...90)
            if gait == .canter {
                segment.leadValue = Bool.random() ? Lead.left.rawValue : Lead.right.rawValue
                segment.leadConfidence = Double.random(in: 0.75...0.92)
            }
            segment.ride = ride
            context.insert(segment)
            currentTime = currentTime.addingTimeInterval(duration)
        }

        generateRoutePoints(for: ride, in: context, startLat: 51.52, startLon: -1.18)
    }

    private static func generateCrossCountryRide(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = Ride()
        ride.name = "XC Schooling"
        ride.rideTypeValue = RideType.crossCountry.rawValue
        ride.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        ride.endDate = ride.startDate.addingTimeInterval(4500) // 1hr 15min
        ride.totalDuration = 4500
        ride.totalDistance = 9200 // 9.2 km
        ride.elevationGain = 145
        ride.elevationLoss = 140
        ride.maxSpeed = 9.5
        ride.totalLeftAngle = 1620
        ride.totalRightAngle = 1800
        ride.leftLeadDuration = 380
        ride.rightLeadDuration = 350
        ride.averageHeartRate = 142
        ride.maxHeartRate = 185
        ride.minHeartRate = 92
        ride.horse = horse
        ride.notes = "Jumped 15 fences. Bella was bold and confident over the water."

        context.insert(ride)

        // Add gait segments for XC
        let segments = [
            (GaitType.walk, 600.0, 800.0),    // 10 min walk warm-up
            (GaitType.trot, 480.0, 1200.0),   // 8 min trot
            (GaitType.canter, 600.0, 2400.0), // 10 min canter
            (GaitType.gallop, 180.0, 1200.0), // 3 min gallop
            (GaitType.walk, 300.0, 400.0),    // 5 min walk
            (GaitType.canter, 420.0, 1800.0), // 7 min canter
            (GaitType.trot, 360.0, 800.0),    // 6 min trot
            (GaitType.walk, 660.0, 600.0),    // 11 min walk cool-down
        ]

        var currentTime = ride.startDate
        for (gait, duration, distance) in segments {
            let segment = GaitSegment(gaitType: gait, startTime: currentTime)
            segment.endTime = currentTime.addingTimeInterval(duration)
            segment.distance = distance
            segment.averageSpeed = distance / duration
            segment.rhythmScore = Double.random(in: 65...88)
            if gait == .canter || gait == .gallop {
                segment.leadValue = Bool.random() ? Lead.left.rawValue : Lead.right.rawValue
                segment.leadConfidence = Double.random(in: 0.7...0.9)
            }
            segment.ride = ride
            context.insert(segment)
            currentTime = currentTime.addingTimeInterval(duration)
        }

        generateRoutePoints(for: ride, in: context, startLat: 51.48, startLon: -1.22)
    }

    // MARK: - Location Point Generation

    private static func generateRoutePoints(for ride: Ride, in context: ModelContext, startLat: Double, startLon: Double) {
        // Generate a simple route with some variation
        let pointCount = 100
        var currentLat = startLat
        var currentLon = startLon
        var currentAlt = 120.0

        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let timestamp = ride.startDate.addingTimeInterval(ride.totalDuration * progress)

            // Add some wandering to the route
            currentLat += Double.random(in: -0.0005...0.001)
            currentLon += Double.random(in: -0.0003...0.0008)
            currentAlt += Double.random(in: -3...4)

            let point = LocationPoint(
                latitude: currentLat,
                longitude: currentLon,
                altitude: max(50, currentAlt),
                timestamp: timestamp,
                horizontalAccuracy: Double.random(in: 3...10),
                speed: Double.random(in: 1...7)
            )
            point.ride = ride
            context.insert(point)
        }
    }

    private static func generateArenaPoints(for ride: Ride, in context: ModelContext, centerLat: Double, centerLon: Double) {
        // Generate circular arena pattern
        let pointCount = 80
        let arenaRadius = 0.0003 // ~30 meters

        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let angle = progress * 2 * .pi * 4 // 4 laps of the arena
            let timestamp = ride.startDate.addingTimeInterval(ride.totalDuration * progress)

            let lat = centerLat + arenaRadius * cos(angle)
            let lon = centerLon + arenaRadius * sin(angle) * 1.5 // Ellipse shape

            let point = LocationPoint(
                latitude: lat,
                longitude: lon,
                altitude: 100,
                timestamp: timestamp,
                horizontalAccuracy: Double.random(in: 2...5),
                speed: Double.random(in: 2...5)
            )
            point.ride = ride
            context.insert(point)
        }
    }
}
