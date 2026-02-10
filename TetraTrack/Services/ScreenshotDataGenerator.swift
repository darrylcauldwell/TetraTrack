//
//  ScreenshotDataGenerator.swift
//  TetraTrack
//
//  Generates realistic sample data for App Store screenshots
//  Uses iconic UK stately homes and equestrian venues
//

import Foundation
import SwiftData
import UIKit

struct ScreenshotDataGenerator {

    // MARK: - UK Stately Home Locations

    struct UKLocation {
        let name: String
        let latitude: Double
        let longitude: Double
        let altitude: Double

        static let badmintonEstate = UKLocation(
            name: "Badminton Estate",
            latitude: 51.5419,
            longitude: -2.2872,
            altitude: 85
        )

        static let burghleyHouse = UKLocation(
            name: "Burghley House",
            latitude: 52.6214,
            longitude: -0.4133,
            altitude: 35
        )

        static let chatsworthHouse = UKLocation(
            name: "Chatsworth House",
            latitude: 53.2271,
            longitude: -1.6115,
            altitude: 180
        )

        static let blenheimPalace = UKLocation(
            name: "Blenheim Palace",
            latitude: 51.8413,
            longitude: -1.3618,
            altitude: 95
        )

        static let castleHoward = UKLocation(
            name: "Castle Howard",
            latitude: 54.1193,
            longitude: -0.9095,
            altitude: 75
        )

        static let althorp = UKLocation(
            name: "Althorp Estate",
            latitude: 52.2821,
            longitude: -1.0012,
            altitude: 110
        )

        static let arundelCastle = UKLocation(
            name: "Arundel Castle",
            latitude: 50.8559,
            longitude: -0.5528,
            altitude: 25
        )

        static let hickstead = UKLocation(
            name: "Hickstead",
            latitude: 50.9683,
            longitude: -0.2247,
            altitude: 45
        )
    }

    // MARK: - Main Generator

    static func generateScreenshotData(in context: ModelContext) {
        // Clear existing data first for clean screenshots
        clearExistingData(in: context)

        // Create horses with personality
        let bella = createHorse(
            name: "Donaghmore Biscuit Thief",
            breed: "Irish Sport Horse",
            color: "Bay",
            heightHands: 16.1,
            ageYears: 9,
            notes: "Will do literally anything for a polo mint. Has perfected the art of looking innocent after eating your sandwich. Excellent jumper when treats are involved.",
            in: context
        )

        let archie = createHorse(
            name: "Donaghmore Chaos Theory",
            breed: "Irish Draught x Thoroughbred",
            color: "Grey",
            heightHands: 15.3,
            ageYears: 12,
            notes: "The horse equivalent of a labrador - enthusiastic about everything, especially mud. Known for his 'creative interpretation' of dressage tests. Once spooked at his own shadow, twice.",
            in: context
        )

        let willow = createHorse(
            name: "Donaghmore Drama Queen",
            breed: "Connemara x Thoroughbred",
            color: "Dun",
            heightHands: 14.2,
            ageYears: 7,
            notes: "Believes every plastic bag is a horse-eating monster. Despite being 14.2hh, is convinced she's a 17hh warmblood. The mare stare is strong with this one.",
            in: context
        )

        // Create varied riding sessions - hacking
        generateBadmintonHack(in: context, horse: bella, daysAgo: 0)
        generateChatsworthHack(in: context, horse: archie, daysAgo: 3)
        generateCastleHowardTrail(in: context, horse: willow, daysAgo: 7)
        generateArundelBeachRide(in: context, horse: bella, daysAgo: 12)

        // Cross country
        generateBurghleyXC(in: context, horse: bella, daysAgo: 2)

        // Schooling sessions - varied types
        generateBlenheimFlatwork(in: context, horse: bella, daysAgo: 1)
        generateAlthorpSchooling(in: context, horse: archie, daysAgo: 4)
        generateHicksteadJumping(in: context, horse: bella, daysAgo: 6)
        generatePoleworkSession(in: context, horse: willow, daysAgo: 8)
        generateGridworkSession(in: context, horse: bella, daysAgo: 10)
        generateLungeSession(in: context, horse: archie, daysAgo: 11)
        generateLateralWorkSession(in: context, horse: bella, daysAgo: 14)

        // Create running sessions
        generateRunningSessions(in: context)

        // Create swimming sessions
        generateSwimmingSessions(in: context)

        // Create shooting sessions
        generateShootingSessions(in: context)

        // Create shot pattern history (UserDefaults-based)
        generateShotPatternHistory()

        // Create training drill sessions
        generateDrillSessions(in: context)

        // Create competitions
        generateCompetitions(in: context, horse: bella)

        // Create rider profile
        generateRiderProfile(in: context)

        try? context.save()
    }

    // MARK: - Clear Data

    private static func clearExistingData(in context: ModelContext) {
        // Clear rides
        let rideDescriptor = FetchDescriptor<Ride>()
        if let rides = try? context.fetch(rideDescriptor) {
            rides.forEach { context.delete($0) }
        }

        // Clear horses
        let horseDescriptor = FetchDescriptor<Horse>()
        if let horses = try? context.fetch(horseDescriptor) {
            horses.forEach { context.delete($0) }
        }

        // Clear competitions
        let compDescriptor = FetchDescriptor<Competition>()
        if let comps = try? context.fetch(compDescriptor) {
            comps.forEach { context.delete($0) }
        }

        // Clear running sessions
        let runDescriptor = FetchDescriptor<RunningSession>()
        if let runs = try? context.fetch(runDescriptor) {
            runs.forEach { context.delete($0) }
        }

        // Clear swimming sessions
        let swimDescriptor = FetchDescriptor<SwimmingSession>()
        if let swims = try? context.fetch(swimDescriptor) {
            swims.forEach { context.delete($0) }
        }

        // Clear shooting sessions
        let shootDescriptor = FetchDescriptor<ShootingSession>()
        if let shoots = try? context.fetch(shootDescriptor) {
            shoots.forEach { context.delete($0) }
        }

        // Clear unified drill sessions
        let drillDescriptor = FetchDescriptor<UnifiedDrillSession>()
        if let drills = try? context.fetch(drillDescriptor) {
            drills.forEach { context.delete($0) }
        }

        // Clear legacy riding drill sessions
        let ridingDrillDescriptor = FetchDescriptor<RidingDrillSession>()
        if let drills = try? context.fetch(ridingDrillDescriptor) {
            drills.forEach { context.delete($0) }
        }

        // Clear legacy shooting drill sessions
        let shootingDrillDescriptor = FetchDescriptor<ShootingDrillSession>()
        if let drills = try? context.fetch(shootingDrillDescriptor) {
            drills.forEach { context.delete($0) }
        }

        // Clear shot pattern history (UserDefaults) and thumbnails
        UserDefaults.standard.removeObject(forKey: "shotPatternHistory")
        for thumbnailId in TargetThumbnailService.shared.listAllThumbnails() {
            TargetThumbnailService.shared.deleteThumbnail(forPatternId: thumbnailId)
        }

        try? context.save()
    }

    // MARK: - Horse Creation

    private static func createHorse(
        name: String,
        breed: String,
        color: String,
        heightHands: Double,
        ageYears: Int,
        notes: String = "Competing at Junior level tetrathlon. Great all-rounder with bold cross-country attitude.",
        in context: ModelContext
    ) -> Horse {
        let horse = Horse()
        horse.name = name
        horse.breed = breed
        horse.color = color
        horse.heightHands = heightHands
        horse.dateOfBirth = Calendar.current.date(byAdding: .year, value: -ageYears, to: Date())
        horse.notes = notes
        context.insert(horse)
        return horse
    }

    // MARK: - Riding Sessions

    private static func generateBadmintonHack(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Badminton Estate Adventure",
            type: .hack,
            durationMinutes: 75,
            distanceKm: 12.5,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 125
        ride.elevationLoss = 118
        ride.maxSpeed = 8.2
        ride.averageHeartRate = 128
        ride.maxHeartRate = 168
        ride.minHeartRate = 92
        ride.totalLeftAngle = 1620
        ride.totalRightAngle = 1890
        ride.leftLeadDuration = 320
        ride.rightLeadDuration = 285
        ride.notes = "Glorious morning hack! Biscuit Thief only tried to eat three different bushes today - personal best. The deer near the lake did NOT appreciate our canter. Pretty sure I now have twigs in places twigs shouldn't be."

        addGaitSegments(to: ride, segments: [
            (.walk, 10, 1200),    // Warm up
            (.trot, 15, 4200),    // Trot through parkland
            (.canter, 8, 3200),   // Canter on grass
            (.walk, 5, 600),      // Walk break
            (.trot, 12, 3300),    // More trotting
            (.canter, 5, 2000),   // Final canter
            (.gallop, 2, 1400),   // Short gallop on bridleway
            (.walk, 18, 1600),    // Cool down walk
        ], in: context)

        generateParklandRoute(for: ride, location: .badmintonEstate, in: context)
        addWeatherData(to: ride, temp: 14, condition: "Partly Cloudy")
        addAISummary(to: ride, summary: "Fantastic hack covering 12.5km! Your turn balance was excellent at 46% left / 54% right. Biscuit Thief's enthusiasm for the gallop section was admirable, if slightly terrifying. Maybe pack fewer snacks next time - the bush-munching attempts are increasing.")
    }

    private static func generateBurghleyXC(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Burghley XC Schooling",
            type: .crossCountry,
            durationMinutes: 55,
            distanceKm: 8.8,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 95
        ride.elevationLoss = 92
        ride.maxSpeed = 9.8
        ride.averageHeartRate = 148
        ride.maxHeartRate = 182
        ride.minHeartRate = 95
        ride.leftLeadDuration = 420
        ride.rightLeadDuration = 395
        ride.notes = "XC schooling at Burghley! Jumped 18 fences including the water complex - Biscuit only splashed me SLIGHTLY on purpose. The corner was dramatic but we survived. My screaming may have been heard in the next county."

        addGaitSegments(to: ride, segments: [
            (.walk, 8, 900),       // Warm up
            (.trot, 10, 2800),     // Trot warm up
            (.canter, 12, 4200),   // XC course work
            (.gallop, 3, 1800),    // Between fences
            (.walk, 5, 600),       // Brief walk
            (.canter, 8, 2800),    // More jumping
            (.trot, 6, 1200),      // Trot cool down
            (.walk, 8, 500),       // Final walk
        ], in: context)

        generateXCRoute(for: ride, location: .burghleyHouse, in: context)
        addWeatherData(to: ride, temp: 16, condition: "Sunny")
        addAISummary(to: ride, summary: "Epic XC session! Your heart rate peaked at 182bpm - possibly during 'the corner incident'. Lead balance was excellent at 52% left / 48% right. The water complex approach was... creative. Perhaps less screaming next time for optimal performance.")
    }

    private static func generateChatsworthHack(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Chatsworth Peak District Epic",
            type: .hack,
            durationMinutes: 105,
            distanceKm: 16.2,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 285
        ride.elevationLoss = 278
        ride.maxSpeed = 7.8
        ride.averageHeartRate = 122
        ride.maxHeartRate = 158
        ride.minHeartRate = 88
        ride.leftLeadDuration = 380
        ride.rightLeadDuration = 410
        ride.notes = "Peak District adventure with Chaos Theory! 285m of climbing - my thighs may never forgive me. Chaos found three different mud puddles to 'accidentally' wade through. I'm now 40% mud. Worth it for the views though!"

        addGaitSegments(to: ride, segments: [
            (.walk, 15, 1800),     // Warm up on incline
            (.trot, 20, 5600),     // Long trot sections
            (.walk, 10, 1200),     // Walk on steep bits
            (.canter, 10, 3800),   // Canter on moorland
            (.trot, 15, 4200),     // More trotting
            (.canter, 8, 2800),    // Final canter
            (.walk, 25, 3000),     // Long cool down
        ], in: context)

        generateHillyRoute(for: ride, location: .chatsworthHouse, in: context)
        addWeatherData(to: ride, temp: 11, condition: "Cloudy")
        addAISummary(to: ride, summary: "Outstanding endurance ride! You conquered 285m of climbing over 16.2km. Chaos Theory's mud-seeking behaviour added 'character' to the session. Your steady pace up the hills shows excellent fitness. Consider waterproof breeches next time.")
    }

    private static func generateBlenheimFlatwork(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Dressage Dreams (& Disasters)",
            type: .schooling,
            durationMinutes: 45,
            distanceKm: 5.2,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 5.8
        ride.averageHeartRate = 115
        ride.maxHeartRate = 142
        ride.minHeartRate = 88
        ride.totalLeftAngle = 4800
        ride.totalRightAngle = 4500
        ride.leftLeadDuration = 285
        ride.rightLeadDuration = 295
        ride.leftReinDuration = 720
        ride.rightReinDuration = 680
        ride.leftReinSymmetry = 84
        ride.rightReinSymmetry = 88
        ride.leftReinRhythm = 81
        ride.rightReinRhythm = 85
        ride.notes = "Working on transitions with Biscuit Thief. Her idea of 'collection' is 'collecting treats'. The right bend is improving - she only tried to exit at C three times today. We're practically Charlotte Dujardin. Practically."

        addGaitSegments(to: ride, segments: [
            (.walk, 8, 500),       // Warm up
            (.trot, 12, 2000),     // Trot work
            (.walk, 3, 200),       // Walk break
            (.canter, 8, 1500),    // Canter work
            (.trot, 10, 1800),     // More trot
            (.canter, 6, 1000),    // Canter again
            (.walk, 10, 700),      // Cool down
        ], in: context)

        generateArenaRoute(for: ride, location: .blenheimPalace, in: context)
        addWeatherData(to: ride, temp: 15, condition: "Sunny")
        addAISummary(to: ride, summary: "Productive schooling session! Turn balance of 52% is excellent - you're working both reins equally. Symmetry score improved to 88% on the right rein. The 'exit at C' attempts are decreasing. Charlotte Dujardin status: 78% achieved.")
    }

    private static func generateCastleHowardTrail(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Castle Howard Confidence Quest",
            type: .hack,
            durationMinutes: 60,
            distanceKm: 9.5,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 85
        ride.elevationLoss = 82
        ride.maxSpeed = 7.2
        ride.averageHeartRate = 118
        ride.maxHeartRate = 152
        ride.minHeartRate = 85
        ride.leftLeadDuration = 210
        ride.rightLeadDuration = 245
        ride.notes = "Confidence-building hack with Drama Queen. She only spooked at TWO things today: a suspicious leaf and what I think was air. Major progress! The parkland views almost distracted me from my impending doom."

        addGaitSegments(to: ride, segments: [
            (.walk, 10, 1200),
            (.trot, 15, 4200),
            (.canter, 5, 1800),
            (.walk, 8, 1000),
            (.trot, 12, 3300),
            (.walk, 10, 1200),
        ], in: context)

        generateParklandRoute(for: ride, location: .castleHoward, in: context)
        addWeatherData(to: ride, temp: 13, condition: "Partly Cloudy")
        addAISummary(to: ride, summary: "Excellent confidence-building session! Spook count down to 2 - a personal best for Drama Queen. Your steady pace and calm approach helped. The suspicious leaf has been officially survived. Progress: immense.")
    }

    private static func generateAlthorpSchooling(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Prelim Test Practice",
            type: .schooling,
            durationMinutes: 50,
            distanceKm: 5.8,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 5.5
        ride.averageHeartRate = 112
        ride.maxHeartRate = 138
        ride.minHeartRate = 85
        ride.totalLeftAngle = 5200
        ride.totalRightAngle = 5000
        ride.leftLeadDuration = 310
        ride.rightLeadDuration = 325
        ride.leftReinDuration = 780
        ride.rightReinDuration = 750
        ride.leftReinSymmetry = 86
        ride.rightReinSymmetry = 82
        ride.leftReinRhythm = 84
        ride.rightReinRhythm = 80
        ride.notes = "Running through prelim test with Chaos Theory. His 'free walk on a long rein' was more 'chaotic jig towards the gate'. The canter serpentine was... interpretive. At least our halt was square-ish."

        addGaitSegments(to: ride, segments: [
            (.walk, 10, 600),
            (.trot, 15, 2200),
            (.canter, 8, 1400),
            (.walk, 5, 400),
            (.trot, 10, 1600),
            (.canter, 6, 1000),
            (.walk, 8, 500),
        ], in: context)

        generateArenaRoute(for: ride, location: .althorp, in: context)
        addWeatherData(to: ride, temp: 12, condition: "Cloudy")
        addAISummary(to: ride, summary: "Solid test practice! Your rhythm score of 84% is improving. The 'interpretive serpentine' showed creativity if not accuracy. Halt squareness: acceptable. Judges' sanity if they'd seen the free walk: questionable.")
    }

    private static func generateArundelBeachRide(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Beach Gallop Extravaganza",
            type: .hack,
            durationMinutes: 90,
            distanceKm: 14.8,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 45
        ride.elevationLoss = 48
        ride.maxSpeed = 10.5
        ride.averageHeartRate = 135
        ride.maxHeartRate = 175
        ride.minHeartRate = 90
        ride.leftLeadDuration = 520
        ride.rightLeadDuration = 485
        ride.notes = "BEACH DAY! Biscuit Thief transformed into a racehorse the moment her hooves hit the sand. Max speed 10.5m/s - I may have briefly lost my voice screaming 'WHEEEEE'. Sand in places sand shouldn't be. 10/10 would gallop again."

        addGaitSegments(to: ride, segments: [
            (.walk, 15, 1800),
            (.trot, 15, 4200),
            (.canter, 12, 4500),
            (.gallop, 5, 3200),
            (.walk, 8, 1000),
            (.canter, 8, 2800),
            (.gallop, 3, 1800),
            (.walk, 20, 2400),
        ], in: context)

        generateBeachRoute(for: ride, location: .arundelCastle, in: context)
        addWeatherData(to: ride, temp: 17, condition: "Sunny")
        addAISummary(to: ride, summary: "Exhilarating beach session! Your max speed of 10.5m/s suggests Biscuit Thief may have Red Rum ancestors. Heart rate peaked at 175bpm - possibly from the joy of life. Lead balance excellent. Sand extraction from riding boots: expected.")
    }

    private static func generateHicksteadJumping(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Show Jumping Shenanigans",
            type: .schooling,  // Arena-based work
            durationMinutes: 40,
            distanceKm: 4.2,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 7.5
        ride.averageHeartRate = 138
        ride.maxHeartRate = 165
        ride.minHeartRate = 92
        ride.leftLeadDuration = 280
        ride.rightLeadDuration = 310
        ride.notes = "SJ practice at Hickstead! Jumped up to 1m - Biscuit cleared it by approximately 47 metres. Her enthusiasm is not matched by my core strength. The getaways are getting tidier - only one victory lap today."

        addGaitSegments(to: ride, segments: [
            (.walk, 8, 500),
            (.trot, 10, 1500),
            (.canter, 15, 3200),
            (.walk, 5, 400),
            (.canter, 8, 1800),
            (.walk, 6, 400),
        ], in: context)

        generateArenaRoute(for: ride, location: .hickstead, in: context)
        addWeatherData(to: ride, temp: 15, condition: "Partly Cloudy")
        addAISummary(to: ride, summary: "Strong jumping session! The 47-metre clearance over the 1m fence shows excellent scope (and possibly excessive enthusiasm). Victory lap frequency is decreasing. Your core strength may need attention - consider more sit-ups.")
    }

    // MARK: - Additional Schooling Sessions

    private static func generatePoleworkSession(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Polework Puzzle",
            type: .schooling,
            durationMinutes: 35,
            distanceKm: 3.8,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 5.2
        ride.averageHeartRate = 108
        ride.maxHeartRate = 132
        ride.minHeartRate = 82
        ride.leftLeadDuration = 195
        ride.rightLeadDuration = 210
        ride.leftReinDuration = 560
        ride.rightReinDuration = 580
        ride.leftReinSymmetry = 82
        ride.rightReinSymmetry = 85
        ride.leftReinRhythm = 78
        ride.rightReinRhythm = 82
        ride.notes = "Raised poles and trot grids with Drama Queen. She's convinced the blue poles are more dangerous than the others. Counting strides has improved - we only launched into orbit twice today. Progress!"

        addGaitSegments(to: ride, segments: [
            (.walk, 6, 400),
            (.trot, 10, 1600),
            (.walk, 4, 300),
            (.trot, 8, 1400),
            (.canter, 5, 800),
            (.walk, 8, 500),
        ], in: context)

        generateArenaRoute(for: ride, location: .hickstead, in: context)
        addWeatherData(to: ride, temp: 13, condition: "Cloudy")
        addAISummary(to: ride, summary: "Great polework session! Your rhythm through the grids improved from 78% to 82% by the end. Drama Queen's suspicion of blue poles is noted. The 'orbit launches' are becoming more controlled.")
    }

    private static func generateGridworkSession(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Bounce Grid Bootcamp",
            type: .schooling,
            durationMinutes: 40,
            distanceKm: 4.5,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 6.5
        ride.averageHeartRate = 125
        ride.maxHeartRate = 148
        ride.minHeartRate = 88
        ride.leftLeadDuration = 240
        ride.rightLeadDuration = 265
        ride.leftReinDuration = 620
        ride.rightReinDuration = 590
        ride.leftReinSymmetry = 88
        ride.rightReinSymmetry = 86
        ride.leftReinRhythm = 85
        ride.rightReinRhythm = 83
        ride.notes = "Bounce grids to one-stride combinations. Biscuit Thief has decided bounces are her favourite thing - she adds extra enthusiasm to every one. My back may disagree. The one-stride was... occasionally a no-stride."

        addGaitSegments(to: ride, segments: [
            (.walk, 8, 500),
            (.trot, 12, 1800),
            (.canter, 10, 1600),
            (.walk, 5, 350),
            (.canter, 8, 1200),
            (.walk, 7, 450),
        ], in: context)

        generateArenaRoute(for: ride, location: .blenheimPalace, in: context)
        addWeatherData(to: ride, temp: 14, condition: "Sunny")
        addAISummary(to: ride, summary: "Excellent gridwork! Symmetry at 88% shows you're staying balanced over the fences. The 'extra enthusiasm' is building Biscuit's confidence. Consider the occasional no-stride as 'advanced scope demonstration'.")
    }

    private static func generateLungeSession(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Lunge Day (Human Exercise)",
            type: .schooling,
            durationMinutes: 25,
            distanceKm: 2.2,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 4.8
        ride.averageHeartRate = 95
        ride.maxHeartRate = 118
        ride.minHeartRate = 75
        ride.leftLeadDuration = 180
        ride.rightLeadDuration = 175
        ride.leftReinDuration = 380
        ride.rightReinDuration = 370
        ride.leftReinSymmetry = 90
        ride.rightReinSymmetry = 88
        ride.leftReinRhythm = 86
        ride.rightReinRhythm = 84
        ride.notes = "Lungeing Chaos Theory - which means I got more exercise than him trying to keep the circle actually circular. He's convinced lunge line = impromptu tug-of-war. Equal work both reins achieved through sheer determination."

        addGaitSegments(to: ride, segments: [
            (.walk, 5, 300),
            (.trot, 8, 900),
            (.canter, 4, 500),
            (.trot, 6, 700),
            (.canter, 4, 450),
            (.walk, 5, 350),
        ], in: context)

        generateArenaRoute(for: ride, location: .althorp, in: context)
        addWeatherData(to: ride, temp: 11, condition: "Partly Cloudy")
        addAISummary(to: ride, summary: "Good lunge session! Turn balance is nearly perfect at 51%/49%. Chaos Theory's 'creative interpretation' of the circle improved as the session progressed. Your step count must have been impressive!")
    }

    private static func generateLateralWorkSession(in context: ModelContext, horse: Horse, daysAgo: Int) {
        let ride = createRide(
            name: "Leg Yield & Shoulder-In Safari",
            type: .schooling,
            durationMinutes: 45,
            distanceKm: 5.0,
            daysAgo: daysAgo,
            horse: horse,
            in: context
        )
        ride.elevationGain = 0
        ride.elevationLoss = 0
        ride.maxSpeed = 4.5
        ride.averageHeartRate = 112
        ride.maxHeartRate = 135
        ride.minHeartRate = 85
        ride.totalLeftAngle = 5500
        ride.totalRightAngle = 5200
        ride.leftLeadDuration = 220
        ride.rightLeadDuration = 235
        ride.leftReinDuration = 750
        ride.rightReinDuration = 720
        ride.leftReinSymmetry = 78
        ride.rightReinSymmetry = 84
        ride.leftReinRhythm = 76
        ride.rightReinRhythm = 82
        ride.notes = "Lateral work focus - leg yield improving! Shoulder-in left is still 'shoulder-somewhere-in-the-vicinity'. Biscuit's travers attempt was... a creative quarter pirouette. We'll call it intentional."

        addGaitSegments(to: ride, segments: [
            (.walk, 10, 650),
            (.trot, 15, 2200),
            (.walk, 5, 350),
            (.trot, 12, 1800),
            (.walk, 8, 500),
        ], in: context)

        generateArenaRoute(for: ride, location: .chatsworthHouse, in: context)
        addWeatherData(to: ride, temp: 12, condition: "Cloudy")
        addAISummary(to: ride, summary: "Solid lateral work! The 6% difference in symmetry between reins shows left is your weaker side - focus there next session. The 'creative quarter pirouette' shows Biscuit's athleticism. Glass half full!")
    }

    // MARK: - Running Sessions

    private static func generateRunningSessions(in context: ModelContext) {
        // 1500m Time Trial
        let trial = RunningSession(name: "1500m Time Trial (Suffering Edition)", sessionType: .timeTrial, runMode: .outdoor)
        trial.startDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        trial.endDate = trial.startDate.addingTimeInterval(378)
        trial.totalDistance = 1500
        trial.totalDuration = 378 // 6:18
        trial.averageCadence = 172
        trial.maxCadence = 185
        trial.averageHeartRate = 168
        trial.maxHeartRate = 185
        trial.totalAscent = 12
        trial.totalDescent = 10
        trial.notes = "6:18 for 1500m - new PB! The last 200m was powered entirely by spite and the knowledge that ice cream awaited. Legs have filed a formal complaint."
        context.insert(trial)

        // Easy Run
        let easy = RunningSession(name: "Recovery Jog (Walking Disguised)", sessionType: .easy, runMode: .outdoor)
        easy.startDate = Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()
        easy.endDate = easy.startDate.addingTimeInterval(1800)
        easy.totalDistance = 5200
        easy.totalDuration = 1800
        easy.averageCadence = 165
        easy.maxCadence = 172
        easy.averageHeartRate = 142
        easy.maxHeartRate = 158
        easy.totalAscent = 45
        easy.totalDescent = 42
        easy.notes = "Easy 5k that was supposed to be 'gentle'. Still got overtaken by someone's grandmother. The dog that joined me for 2km was a highlight."
        context.insert(easy)

        // Interval Session
        let intervals = RunningSession(name: "Speed Intervals (Voluntary Torture)", sessionType: .intervals, runMode: .outdoor)
        intervals.startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        intervals.endDate = intervals.startDate.addingTimeInterval(2100)
        intervals.totalDistance = 6800
        intervals.totalDuration = 2100
        intervals.averageCadence = 175
        intervals.maxCadence = 192
        intervals.averageHeartRate = 158
        intervals.maxHeartRate = 188
        intervals.totalAscent = 28
        intervals.totalDescent = 25
        intervals.notes = "8x400m intervals. Each one felt progressively more like a life choice I needed to reconsider. The voice coach telling me to 'pick it up' was NOT appreciated on rep 7."
        context.insert(intervals)

        // Treadmill
        let treadmill = RunningSession(name: "Treadmill (Hamster Wheel Experience)", sessionType: .easy, runMode: .treadmill)
        treadmill.startDate = Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date()
        treadmill.endDate = treadmill.startDate.addingTimeInterval(1500)
        treadmill.totalDistance = 4200
        treadmill.totalDuration = 1500
        treadmill.averageCadence = 168
        treadmill.averageHeartRate = 148
        treadmill.maxHeartRate = 162
        treadmill.manualDistance = true
        treadmill.treadmillIncline = 2.0
        treadmill.notes = "It was raining. I have no regrets. Watched an entire episode of something while running. This is peak efficiency. Or laziness. Possibly both."
        context.insert(treadmill)

        // Long Run
        let longRun = RunningSession(name: "Sunday Long Run (Pain & Suffering)", sessionType: .longRun, runMode: .outdoor)
        longRun.startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        longRun.endDate = longRun.startDate.addingTimeInterval(3600)
        longRun.totalDistance = 10500
        longRun.totalDuration = 3600
        longRun.averageCadence = 162
        longRun.maxCadence = 172
        longRun.averageHeartRate = 145
        longRun.maxHeartRate = 165
        longRun.totalAscent = 125
        longRun.totalDescent = 118
        longRun.notes = "10.5km Sunday long run. The first 5km felt amazing. The last 5km felt like a negotiation with my legs. Discovered three new blisters and one new appreciation for sofas. The pub at the end was motivational."
        context.insert(longRun)

        // Tempo Run
        let tempo = RunningSession(name: "Tempo Run (Comfortably Uncomfortable)", sessionType: .tempo, runMode: .outdoor)
        tempo.startDate = Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date()
        tempo.endDate = tempo.startDate.addingTimeInterval(1800)
        tempo.totalDistance = 5800
        tempo.totalDuration = 1800
        tempo.averageCadence = 176
        tempo.maxCadence = 182
        tempo.averageHeartRate = 162
        tempo.maxHeartRate = 175
        tempo.totalAscent = 35
        tempo.totalDescent = 32
        tempo.notes = "Tempo pace practice - 'comfortably hard' they said. 'Uncomfortable and questioning life choices' is more accurate. Maintained pace for 4km though, which is a win. The voice coach was encouraging. Too encouraging."
        context.insert(tempo)

        // Virtual Pacer Session
        let pacer = RunningSession(name: "Chase the Ghost (Virtual Pacer)", sessionType: .timeTrial, runMode: .outdoor)
        pacer.startDate = Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date()
        pacer.endDate = pacer.startDate.addingTimeInterval(420)
        pacer.totalDistance = 1500
        pacer.totalDuration = 420 // 7:00
        pacer.averageCadence = 170
        pacer.maxCadence = 182
        pacer.averageHeartRate = 165
        pacer.maxHeartRate = 180
        pacer.totalAscent = 8
        pacer.totalDescent = 6
        pacer.notes = "Chasing my PB ghost on the 1500m. The ghost won by 42 seconds. The ghost is a show-off. Next time I'm setting a more achievable ghost. One that maybe takes a coffee break mid-run."
        context.insert(pacer)

        // Hill Repeats
        let hills = RunningSession(name: "Hill Repeats (Stairway to Suffering)", sessionType: .intervals, runMode: .outdoor)
        hills.startDate = Calendar.current.date(byAdding: .day, value: -17, to: Date()) ?? Date()
        hills.endDate = hills.startDate.addingTimeInterval(1500)
        hills.totalDistance = 4200
        hills.totalDuration = 1500
        hills.averageCadence = 168
        hills.maxCadence = 178
        hills.averageHeartRate = 158
        hills.maxHeartRate = 182
        hills.totalAscent = 185
        hills.totalDescent = 180
        hills.notes = "6x hill repeats. By rep 4, the hill had become my nemesis. By rep 6, we had reached an uneasy truce. My quads are filing a formal complaint with HR. The views from the top were lovely, when I could see through the tears."
        context.insert(hills)
    }

    // MARK: - Swimming Sessions

    private static func generateSwimmingSessions(in context: ModelContext) {
        // 3 Minute Test
        let test = SwimmingSession(name: "3 Minute Test (Drowning Gracefully)", poolMode: .pool, poolLength: 25)
        test.startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        test.endDate = test.startDate.addingTimeInterval(180)
        test.totalDistance = 225 // 9 lengths
        test.totalDuration = 180
        test.totalStrokes = 162
        test.notes = "9 lengths in 3 minutes - PB! The tumble turns are getting less 'tumble' and more 'controlled chaos'. Only swallowed a small amount of chlorine this time. Progress!"
        context.insert(test)

        // Add laps
        for i in 0..<9 {
            let lap = SwimmingLap()
            lap.orderIndex = i
            lap.distance = 25
            lap.duration = 20.0 + Double.random(in: -2...2)
            lap.strokeCount = 18 + Int.random(in: -2...2)
            lap.session = test
            context.insert(lap)
        }

        // Training Session
        let training = SwimmingSession(name: "Speed Sets (Splashy Edition)", poolMode: .pool, poolLength: 25)
        training.startDate = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        training.endDate = training.startDate.addingTimeInterval(1800)
        training.totalDistance = 1000
        training.totalDuration = 1200
        training.totalStrokes = 720
        training.notes = "1km of speed sets! SWOLF improving - apparently I'm more efficient when there's cake promised at the end. The lane rope and I had a minor disagreement on length 32. We've reconciled."
        context.insert(training)

        // Add laps for training
        for i in 0..<40 {
            let lap = SwimmingLap()
            lap.orderIndex = i
            lap.distance = 25
            lap.duration = 22.0 + Double.random(in: -3...3)
            lap.strokeCount = 18 + Int.random(in: -2...3)
            lap.session = training
            context.insert(lap)
        }

        // Open Water Session
        let openWater = SwimmingSession(name: "Lake Adventure (Cold Water Shock)", poolMode: .openWater, poolLength: 0)
        openWater.startDate = Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date()
        openWater.endDate = openWater.startDate.addingTimeInterval(720)
        openWater.totalDistance = 400
        openWater.totalDuration = 720
        openWater.totalStrokes = 320
        openWater.notes = "First open water swim of the season! Water temperature: 'refreshing' (read: cold enough to reconsider life). Sighting practice went well - only swam into one buoy. The ducks were unimpressed by my technique."
        context.insert(openWater)

        // 50m Pool Session
        let fiftyPool = SwimmingSession(name: "Olympic Pool Practice", poolMode: .pool, poolLength: 50)
        fiftyPool.startDate = Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date()
        fiftyPool.endDate = fiftyPool.startDate.addingTimeInterval(2400)
        fiftyPool.totalDistance = 1500
        fiftyPool.totalDuration = 1800
        fiftyPool.totalStrokes = 1080
        fiftyPool.notes = "50m pool - half the turns means twice the suffering per length. The extra distance between walls is psychological warfare. Flip turns are getting tidier though - only 60% of them involve mild panic now."
        context.insert(fiftyPool)

        // Add laps for 50m pool (30 laps)
        for i in 0..<30 {
            let lap = SwimmingLap()
            lap.orderIndex = i
            lap.distance = 50
            lap.duration = 48.0 + Double.random(in: -5...5)
            lap.strokeCount = 36 + Int.random(in: -3...3)
            lap.session = fiftyPool
            context.insert(lap)
        }

        // Technique Focus Session
        let technique = SwimmingSession(name: "Catch & Pull Drills", poolMode: .pool, poolLength: 25)
        technique.startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        technique.endDate = technique.startDate.addingTimeInterval(1500)
        technique.totalDistance = 750
        technique.totalDuration = 1200
        technique.totalStrokes = 480
        technique.notes = "Technique drills - catch-up drill, fingertip drag, fist swimming. Discovered I've been 'swimming' with more splash than propulsion. Coach said my catch was 'improving' with a very diplomatic expression."
        context.insert(technique)

        // Add laps for technique (30 laps)
        for i in 0..<30 {
            let lap = SwimmingLap()
            lap.orderIndex = i
            lap.distance = 25
            lap.duration = 28.0 + Double.random(in: -4...6)  // Slower for drills
            lap.strokeCount = 16 + Int.random(in: -2...2)
            lap.session = technique
            context.insert(lap)
        }

        // Endurance Session
        let endurance = SwimmingSession(name: "Distance Day (Channel Prep?)", poolMode: .pool, poolLength: 25)
        endurance.startDate = Calendar.current.date(byAdding: .day, value: -18, to: Date()) ?? Date()
        endurance.endDate = endurance.startDate.addingTimeInterval(3000)
        endurance.totalDistance = 2000
        endurance.totalDuration = 2400
        endurance.totalStrokes = 1440
        endurance.notes = "2km continuous swim! The first 500m were pleasant. The second 500m were okay. The third 500m involved counting tiles. The final 500m was powered by stubbornness and the promise of hot chocolate. Channel swim status: not yet."
        context.insert(endurance)

        // Add laps for endurance (80 laps)
        for i in 0..<80 {
            let lap = SwimmingLap()
            lap.orderIndex = i
            lap.distance = 25
            lap.duration = 24.0 + Double.random(in: -3...4) + (Double(i) * 0.05)  // Slight fatigue
            lap.strokeCount = 18 + Int.random(in: -2...2)
            lap.session = endurance
            context.insert(lap)
        }
    }

    // MARK: - Shooting Sessions

    private static func generateShootingSessions(in context: ModelContext) {
        // Competition Practice
        let comp = ShootingSession(
            name: "Competition Practice (Mostly Hitting Target)",
            targetType: .olympic,
            distance: 10,
            numberOfEnds: 2,
            arrowsPerEnd: 5
        )
        comp.startDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        comp.endDate = comp.startDate.addingTimeInterval(900)
        comp.notes = "86 points across 2 cards! My stance is getting steadier - the Watch only judged me 'slightly wobbly' this time. Shot 5 on card 1 was... ambitious. We don't talk about shot 5."
        context.insert(comp)

        // Add ends with shots for realistic scores
        let end1 = ShootingEnd(orderIndex: 0)
        end1.session = comp
        context.insert(end1)
        addShots(to: end1, scores: [10, 8, 10, 8, 6], in: context)

        let end2 = ShootingEnd(orderIndex: 1)
        end2.session = comp
        context.insert(end2)
        addShots(to: end2, scores: [8, 10, 8, 10, 8], in: context)

        // Training Session
        let training = ShootingSession(
            name: "Training (Breathing & Not Panicking)",
            targetType: .olympic,
            distance: 10,
            numberOfEnds: 4,
            arrowsPerEnd: 5
        )
        training.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        training.endDate = training.startDate.addingTimeInterval(1800)
        training.notes = "Focus on breathing today. Turns out holding your breath for 30 seconds is NOT the technique. Who knew? Dry fire stability improved - I can now remain motionless for almost 4 seconds."
        context.insert(training)

        let scores = [[8,8,6,10,8], [10,8,8,6,8], [8,10,10,8,8], [10,8,8,10,6]]
        for (i, scoreSet) in scores.enumerated() {
            let end = ShootingEnd(orderIndex: i)
            end.session = training
            context.insert(end)
            addShots(to: end, scores: scoreSet, in: context)
        }

        // Dry Fire Practice
        let dryFire = ShootingSession(
            name: "Dry Fire Drills (Imaginary Excellence)",
            targetType: .olympic,
            distance: 10,
            numberOfEnds: 3,
            arrowsPerEnd: 5
        )
        dryFire.startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        dryFire.endDate = dryFire.startDate.addingTimeInterval(1200)
        dryFire.notes = "Dry fire stability practice. Hold time improving - managed 4.2 seconds without wobble! The Watch says my stance is 'stable'. In my imagination, all shots were 10s. Reality may differ when we add actual ammunition."
        context.insert(dryFire)

        // Add ends with phantom scores for dry fire (all 10s in imagination!)
        for i in 0..<3 {
            let end = ShootingEnd(orderIndex: i)
            end.session = dryFire
            context.insert(end)
            addShots(to: end, scores: [10, 10, 10, 10, 10], in: context)
        }

        // Match Simulation
        let match = ShootingSession(
            name: "Full Competition Simulation",
            targetType: .olympic,
            distance: 10,
            numberOfEnds: 4,
            arrowsPerEnd: 5
        )
        match.startDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        match.endDate = match.startDate.addingTimeInterval(1500)
        match.notes = "Full competition simulation with time pressure! End 1 was shaky (nerves). End 2 was better (settled). End 3 was peak performance. End 4 was... character building. Total: 168 points. Improvement noted!"
        context.insert(match)

        let matchScores = [[6,8,8,10,8], [10,10,8,8,10], [10,10,10,8,10], [8,6,8,10,8]]
        for (i, scoreSet) in matchScores.enumerated() {
            let end = ShootingEnd(orderIndex: i)
            end.session = match
            context.insert(end)
            addShots(to: end, scores: scoreSet, in: context)
        }

        // Precision Focus Session
        let precision = ShootingSession(
            name: "Precision Practice (Small Targets)",
            targetType: .olympic,
            distance: 10,
            numberOfEnds: 3,
            arrowsPerEnd: 5
        )
        precision.startDate = Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date()
        precision.endDate = precision.startDate.addingTimeInterval(1100)
        precision.notes = "Focus on the inner rings only. Aiming for the 10 exclusively. Results: mixed. Turns out 'aim better' isn't quite enough instruction. Sight picture was good though. Release needs work. Always needs work."
        context.insert(precision)

        let precisionScores = [[8,10,10,10,8], [10,8,10,10,10], [10,10,8,10,10]]
        for (i, scoreSet) in precisionScores.enumerated() {
            let end = ShootingEnd(orderIndex: i)
            end.session = precision
            context.insert(end)
            addShots(to: end, scores: scoreSet, in: context)
        }

        // Pressure Practice
        let pressure = ShootingSession(
            name: "Under Pressure (Dad Watching)",
            targetType: .olympic,
            distance: 10,
            numberOfEnds: 2,
            arrowsPerEnd: 5
        )
        pressure.startDate = Calendar.current.date(byAdding: .day, value: -25, to: Date()) ?? Date()
        pressure.endDate = pressure.startDate.addingTimeInterval(600)
        pressure.notes = "Shot with dad watching. Discovered that being observed adds approximately 47% more wobble. Shot 3 of end 1 shall not be discussed. Managed to recover. Mental game: work in progress."
        context.insert(pressure)

        let pressureScores = [[10,8,4,8,10], [8,10,10,10,8]]  // Note the 4 - "shall not be discussed"
        for (i, scoreSet) in pressureScores.enumerated() {
            let end = ShootingEnd(orderIndex: i)
            end.session = pressure
            context.insert(end)
            addShots(to: end, scores: scoreSet, in: context)
        }
    }

    private static func addShots(to end: ShootingEnd, scores: [Int], in context: ModelContext) {
        for (i, score) in scores.enumerated() {
            let shot = Shot(orderIndex: i, score: score, isX: score == 10)
            shot.end = end
            context.insert(shot)
        }
    }

    // MARK: - Shot Pattern History (UserDefaults)

    private static func generateShotPatternHistory() {
        let manager = ShotPatternHistoryManager()
        manager.clearHistory()

        let calendar = Calendar.current

        // Helper to generate shots clustered around a center point with some spread
        func generateShots(center: CGPoint, spread: Double, count: Int, outlierChance: Double = 0.1) -> [CGPoint] {
            var shots: [CGPoint] = []
            for _ in 0..<count {
                if Double.random(in: 0...1) < outlierChance {
                    let angle = Double.random(in: 0...(2 * .pi))
                    let dist = spread * Double.random(in: 2.0...3.5)
                    shots.append(CGPoint(
                        x: center.x + dist * cos(angle),
                        y: center.y + dist * sin(angle)
                    ))
                } else {
                    let angle = Double.random(in: 0...(2 * .pi))
                    let dist = spread * Double.random(in: 0...1)
                    shots.append(CGPoint(
                        x: center.x + dist * cos(angle),
                        y: center.y + dist * sin(angle)
                    ))
                }
            }
            return shots
        }

        func addPatternWithThumbnail(_ pattern: StoredTargetPattern) {
            manager.addPattern(pattern)
            let thumbnail = renderTargetThumbnail(shots: pattern.normalizedShots)
            TargetThumbnailService.shared.saveThumbnail(thumbnail, forPatternId: pattern.id)
        }

        // Session 1: Recent free practice - tight group, slight right bias (3 days ago)
        let shots1 = generateShots(center: CGPoint(x: 0.08, y: -0.03), spread: 0.06, count: 10)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            normalizedShots: shots1,
            clusterMpiX: 0.08, clusterMpiY: -0.03,
            clusterRadius: 0.06, clusterShotCount: 9, outlierCount: 1,
            sessionType: .freePractice
        ))

        // Session 2: Competition training - moderate group (5 days ago)
        let shots2 = generateShots(center: CGPoint(x: 0.04, y: 0.06), spread: 0.09, count: 10)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            normalizedShots: shots2,
            clusterMpiX: 0.04, clusterMpiY: 0.06,
            clusterRadius: 0.09, clusterShotCount: 9, outlierCount: 1,
            sessionType: .competitionTraining
        ))

        // Session 3: Free practice - improving (7 days ago)
        let shots3 = generateShots(center: CGPoint(x: 0.05, y: 0.02), spread: 0.08, count: 10)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            normalizedShots: shots3,
            clusterMpiX: 0.05, clusterMpiY: 0.02,
            clusterRadius: 0.08, clusterShotCount: 9, outlierCount: 1,
            sessionType: .freePractice
        ))

        // Session 4: Tetrathlon practice - pressure showing (10 days ago)
        let shots4 = generateShots(center: CGPoint(x: -0.06, y: 0.10), spread: 0.12, count: 10, outlierChance: 0.2)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
            normalizedShots: shots4,
            clusterMpiX: -0.06, clusterMpiY: 0.10,
            clusterRadius: 0.12, clusterShotCount: 8, outlierCount: 2,
            sessionType: .tetrathlonPractice
        ))

        // Session 5: Competition - nerves (14 days ago)
        let shots5 = generateShots(center: CGPoint(x: 0.10, y: 0.08), spread: 0.14, count: 10, outlierChance: 0.2)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
            normalizedShots: shots5,
            clusterMpiX: 0.10, clusterMpiY: 0.08,
            clusterRadius: 0.14, clusterShotCount: 8, outlierCount: 2,
            sessionType: .competition
        ))

        // Session 6: Free practice - wider group (18 days ago)
        let shots6 = generateShots(center: CGPoint(x: -0.03, y: -0.05), spread: 0.11, count: 10)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -18, to: Date()) ?? Date(),
            normalizedShots: shots6,
            clusterMpiX: -0.03, clusterMpiY: -0.05,
            clusterRadius: 0.11, clusterShotCount: 9, outlierCount: 1,
            sessionType: .freePractice
        ))

        // Session 7: Competition training - early session (22 days ago)
        let shots7 = generateShots(center: CGPoint(x: 0.12, y: -0.08), spread: 0.15, count: 10, outlierChance: 0.2)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: calendar.date(byAdding: .day, value: -22, to: Date()) ?? Date(),
            normalizedShots: shots7,
            clusterMpiX: 0.12, clusterMpiY: -0.08,
            clusterRadius: 0.15, clusterShotCount: 8, outlierCount: 2,
            sessionType: .competitionTraining
        ))

        // Session 8: Free practice - second target same day as session 1 (3 days ago)
        let shots8 = generateShots(center: CGPoint(x: 0.06, y: -0.01), spread: 0.05, count: 10)
        addPatternWithThumbnail(StoredTargetPattern(
            timestamp: (calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()).addingTimeInterval(1800),
            normalizedShots: shots8,
            clusterMpiX: 0.06, clusterMpiY: -0.01,
            clusterRadius: 0.05, clusterShotCount: 10, outlierCount: 0,
            sessionType: .freePractice
        ))
    }

    /// Renders a synthetic target card image with shot holes
    private static func renderTargetThumbnail(shots: [CGPoint]) -> UIImage {
        let size = CGSize(width: 600, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let context = ctx.cgContext
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 20

            // Off-white card background
            UIColor(white: 0.95, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Scoring ring colors and radii (outer to inner)
            let rings: [(radius: CGFloat, fill: UIColor, stroke: UIColor)] = [
                (maxRadius,       UIColor(white: 0.85, alpha: 1), UIColor(white: 0.6, alpha: 1)),   // 2 - outer
                (maxRadius * 0.8, UIColor(white: 0.80, alpha: 1), UIColor(white: 0.6, alpha: 1)),   // 4
                (maxRadius * 0.6, UIColor(red: 0.6, green: 0.75, blue: 0.9, alpha: 1), UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1)), // 6 - blue
                (maxRadius * 0.4, UIColor(red: 0.9, green: 0.5, blue: 0.5, alpha: 1), UIColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1)), // 8 - red
                (maxRadius * 0.2, UIColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1), UIColor(red: 0.8, green: 0.7, blue: 0.2, alpha: 1)), // 10 - gold
            ]

            for ring in rings {
                let rect = CGRect(
                    x: center.x - ring.radius,
                    y: center.y - ring.radius,
                    width: ring.radius * 2,
                    height: ring.radius * 2
                )
                ring.fill.setFill()
                ring.stroke.setStroke()
                context.setLineWidth(1.5)
                context.fillEllipse(in: rect)
                context.strokeEllipse(in: rect)
            }

            // Center crosshair
            UIColor(white: 0.3, alpha: 0.6).setStroke()
            context.setLineWidth(1)
            context.move(to: CGPoint(x: center.x - 12, y: center.y))
            context.addLine(to: CGPoint(x: center.x + 12, y: center.y))
            context.strokePath()
            context.move(to: CGPoint(x: center.x, y: center.y - 12))
            context.addLine(to: CGPoint(x: center.x, y: center.y + 12))
            context.strokePath()

            // Shot holes
            for shot in shots {
                let x = center.x + shot.x * maxRadius
                let y = center.y + shot.y * maxRadius
                let holeRadius: CGFloat = 5

                // Dark hole
                UIColor(white: 0.15, alpha: 0.9).setFill()
                context.fillEllipse(in: CGRect(x: x - holeRadius, y: y - holeRadius, width: holeRadius * 2, height: holeRadius * 2))

                // Torn paper ring around hole
                UIColor(white: 0.98, alpha: 0.8).setStroke()
                context.setLineWidth(1.5)
                context.strokeEllipse(in: CGRect(x: x - holeRadius - 1, y: y - holeRadius - 1, width: (holeRadius + 1) * 2, height: (holeRadius + 1) * 2))
            }
        }
    }

    // MARK: - Drill Sessions

    private static func generateDrillSessions(in context: ModelContext) {
        let calendar = Calendar.current

        // MARK: Riding Drills

        // Core Stability - Yesterday
        let coreStability = UnifiedDrillSession(
            drillType: .coreStability,
            duration: 65,
            score: 78,
            stabilityScore: 82,
            symmetryScore: 75,
            enduranceScore: 72,
            averageRMS: 0.12,
            averageWobble: 0.08
        )
        coreStability.startDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        coreStability.notes = "Good session! Discovered my core is stronger than my willpower to continue. The phone kept telling me to 'stay stable' - easier said than done when you're shaking like a leaf."
        context.insert(coreStability)

        // Two-Point - 3 days ago
        let twoPoint = UnifiedDrillSession(
            drillType: .twoPoint,
            duration: 45,
            score: 71,
            stabilityScore: 68,
            symmetryScore: 74,
            enduranceScore: 65,
            averageRMS: 0.18,
            peakDeviation: 0.25
        )
        twoPoint.startDate = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        twoPoint.notes = "Two-point position practice. My thighs are filing a formal complaint. The endurance score declined sharply after 30 seconds - I prefer to think of it as 'strategic energy conservation'."
        context.insert(twoPoint)

        // Heel Position - 5 days ago
        let heelPosition = UnifiedDrillSession(
            drillType: .heelPosition,
            duration: 60,
            score: 85,
            stabilityScore: 88,
            symmetryScore: 82,
            coordinationScore: 80,
            averageRMS: 0.09
        )
        heelPosition.startDate = calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        heelPosition.notes = "Heels down drill went well! Who knew standing with your heels down could be this challenging without a horse? The cat was unimpressed by my efforts."
        context.insert(heelPosition)

        // Posting Rhythm - 8 days ago
        let postingRhythm = UnifiedDrillSession(
            drillType: .postingRhythm,
            duration: 90,
            score: 82,
            enduranceScore: 76,
            coordinationScore: 78,
            rhythmScore: 85,
            rhythmAccuracy: 87
        )
        postingRhythm.startDate = calendar.date(byAdding: .day, value: -8, to: Date()) ?? Date()
        postingRhythm.notes = "Practiced posting to metronome at 145 BPM. Started strong, ended looking like a confused kangaroo. Rhythm score proves I CAN keep time when nobody's watching."
        context.insert(postingRhythm)

        // MARK: Shooting Drills

        // Box Breathing - 2 days ago
        let boxBreathing = UnifiedDrillSession(
            drillType: .boxBreathing,
            duration: 180,
            score: 92,
            stabilityScore: 88,
            enduranceScore: 90,
            breathingScore: 95,
            averageRMS: 0.05
        )
        boxBreathing.startDate = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        boxBreathing.notes = "3 minutes of box breathing - 4 in, 4 hold, 4 out, 4 hold. Achieved an almost zen-like state. Then the dog barked and ruined everything. Still a PB!"
        context.insert(boxBreathing)

        // Dry Fire - 4 days ago
        let dryFire = UnifiedDrillSession(
            drillType: .dryFire,
            duration: 120,
            score: 76,
            stabilityScore: 78,
            symmetryScore: 72,
            coordinationScore: 74,
            averageWobble: 0.12,
            peakDeviation: 0.18
        )
        dryFire.startDate = calendar.date(byAdding: .day, value: -4, to: Date()) ?? Date()
        dryFire.notes = "Dry fire practice - trigger pull without the bang. My imaginary targets were hit with great precision. Real targets may vary. Stability improved toward the end!"
        context.insert(dryFire)

        // Steady Hold - 6 days ago
        let steadyHold = UnifiedDrillSession(
            drillType: .steadyHold,
            duration: 90,
            score: 68,
            stabilityScore: 65,
            symmetryScore: 71,
            enduranceScore: 62,
            averageWobble: 0.15,
            peakDeviation: 0.22
        )
        steadyHold.startDate = calendar.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        steadyHold.notes = "Extended hold drill. Discovered that holding still is HARD. My arms have opinions about this. Stability degraded significantly after 60 seconds - arms staged a mutiny."
        context.insert(steadyHold)

        // Reaction Time - 9 days ago
        let reactionTime = UnifiedDrillSession(
            drillType: .reactionTime,
            duration: 60,
            score: 81,
            coordinationScore: 78,
            reactionScore: 84,
            bestReactionTime: 0.28,
            averageReactionTime: 0.42
        )
        reactionTime.startDate = calendar.date(byAdding: .day, value: -9, to: Date()) ?? Date()
        reactionTime.notes = "Reaction drill with voice commands. Best time 0.28s - channeling my inner ninja! Average is still 'human speed' at 0.42s. The 'FIRE!' command made me jump once."
        context.insert(reactionTime)

        // MARK: Running Drills

        // Cadence Training - Today
        let cadence = UnifiedDrillSession(
            drillType: .cadenceTraining,
            duration: 180,
            score: 88,
            enduranceScore: 84,
            coordinationScore: 82,
            rhythmScore: 91,
            rhythmAccuracy: 92,
            cadence: 178
        )
        cadence.startDate = calendar.date(byAdding: .hour, value: -3, to: Date()) ?? Date()
        cadence.notes = "Target: 180 SPM. Achieved: 178 SPM. Close enough! The metronome was relentless but my feet eventually cooperated. Felt like a running robot by the end."
        context.insert(cadence)

        // Breathing Patterns - 7 days ago
        let breathingPatterns = UnifiedDrillSession(
            drillType: .breathingPatterns,
            duration: 150,
            score: 79,
            enduranceScore: 74,
            breathingScore: 82,
            rhythmScore: 76
        )
        breathingPatterns.startDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        breathingPatterns.notes = "3:2 breathing pattern practice. In-in-in, out-out. Surprisingly hard to coordinate with feet. Brain wanted to do its own thing. Eventually found the rhythm."
        context.insert(breathingPatterns)

        // Plyometrics - 11 days ago
        let plyometrics = UnifiedDrillSession(
            drillType: .plyometrics,
            duration: 120,
            score: 74,
            enduranceScore: 68,
            coordinationScore: 76,
            rhythmScore: 72,
            averageRMS: 0.22
        )
        plyometrics.startDate = calendar.date(byAdding: .day, value: -11, to: Date()) ?? Date()
        plyometrics.notes = "Jump power drill! My vertical is... aspirational. The neighbours may have thought I was trying to escape something. Legs complained for two days afterward."
        context.insert(plyometrics)

        // MARK: Swimming Drills

        // Breathing Rhythm - Yesterday
        let breathingRhythm = UnifiedDrillSession(
            drillType: .breathingRhythm,
            duration: 120,
            score: 83,
            symmetryScore: 78,
            breathingScore: 86,
            rhythmScore: 80
        )
        breathingRhythm.startDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        breathingRhythm.notes = "Bilateral breathing practice - 3 strokes right, 3 strokes left. No longer drowning on the left side! Symmetry is improving. The pool was cold but the session was worth it."
        context.insert(breathingRhythm)

        // Kick Efficiency - 10 days ago
        let kickEfficiency = UnifiedDrillSession(
            drillType: .kickEfficiency,
            duration: 90,
            score: 72,
            enduranceScore: 68,
            coordinationScore: 70,
            rhythmScore: 74
        )
        kickEfficiency.startDate = calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        kickEfficiency.notes = "Flutter kick rhythm drill. My kick is more 'enthusiastic splashing' than 'efficient propulsion' but the rhythm is getting steadier. Less white water is a win."
        context.insert(kickEfficiency)

        // Streamline Position - 12 days ago
        let streamline = UnifiedDrillSession(
            drillType: .streamlinePosition,
            duration: 60,
            score: 86,
            stabilityScore: 89,
            symmetryScore: 84,
            enduranceScore: 80,
            averageRMS: 0.08
        )
        streamline.startDate = calendar.date(byAdding: .day, value: -12, to: Date()) ?? Date()
        streamline.notes = "Streamline posture drill - arms squeezed behind ears, core tight. I am now 4.7% more hydrodynamic (imaginary statistic). Actually held it well this time!"
        context.insert(streamline)

        // Shoulder Mobility - 14 days ago
        let shoulderMobility = UnifiedDrillSession(
            drillType: .shoulderMobility,
            duration: 75,
            score: 77,
            symmetryScore: 75,
            enduranceScore: 72,
            coordinationScore: 79
        )
        shoulderMobility.startDate = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        shoulderMobility.notes = "Shoulder circles and mobility work. Left shoulder is the problem child - always has been. Range of motion improving though. Can now wave hello without wincing."
        context.insert(shoulderMobility)
    }

    // MARK: - Competitions

    private static func generateCompetitions(in context: ModelContext, horse: Horse) {
        let calendar = Calendar.current

        // Upcoming competition - 12 days away
        let upcoming1 = Competition(
            name: "Area Tetrathlon Championships",
            date: calendar.date(byAdding: .day, value: 12, to: Date()) ?? Date(),
            location: "Badminton Estate, Gloucestershire",
            competitionType: .tetrathlon,
            level: .junior
        )
        upcoming1.horse = horse
        upcoming1.isEntered = true
        upcoming1.entryDeadline = calendar.date(byAdding: .day, value: 5, to: Date())
        upcoming1.venue = "Badminton Horse Trials Venue"
        context.insert(upcoming1)

        // Add todos
        upcoming1.addTodo("Pack kit bag (including the lucky socks)")
        upcoming1.addTodo("Check Biscuit Thief's passport hasn't been eaten by Biscuit Thief")
        upcoming1.addTodo("Confirm transport - and snack supply")
        upcoming1.addTodo("Practice not falling off during XC")

        // Upcoming competition - 28 days away
        let upcoming2 = Competition(
            name: "Regional Qualifiers",
            date: calendar.date(byAdding: .day, value: 28, to: Date()) ?? Date(),
            location: "Burghley House, Stamford",
            competitionType: .tetrathlon,
            level: .junior
        )
        upcoming2.horse = horse
        upcoming2.isEntered = false
        upcoming2.entryDeadline = calendar.date(byAdding: .day, value: 14, to: Date())
        context.insert(upcoming2)

        // Completed competition - 21 days ago
        let completed = Competition(
            name: "Spring Tetrathlon",
            date: calendar.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
            location: "Hickstead, West Sussex",
            competitionType: .tetrathlon,
            level: .junior
        )
        completed.horse = horse
        completed.isEntered = true
        completed.isCompleted = true
        completed.ridingScore = 285
        completed.shootingScore = 840
        completed.swimmingDistance = 225
        completed.runningTime = 378
        completed.overallPlacing = 3
        completed.placement = "3rd"
        completed.resultNotes = "THIRD PLACE! 🥉 Shooting PB! Swimming went surprisingly well given my fear of tumble turns. Run was powered by pure determination and the sight of the finish line cake stall. Biscuit Thief was perfect - only tried to eat one jump."
        context.insert(completed)

        // Add completed todos
        completed.addTodo("Collect rosette (and photograph it from 47 angles)")
        completed.addTodo("Thank instructor for not giving up on us")
        var todos = completed.todos
        if !todos.isEmpty {
            todos[0].isCompleted = true
            todos[1].isCompleted = true
            completed.todos = todos
        }

        // MARK: - Competition Tasks (for Tasks view)

        let task1 = CompetitionTask(
            title: "Pack kit bag (boots, hat, body protector)",
            notes: "Don't forget the lucky socks this time!",
            dueDate: calendar.date(byAdding: .day, value: 10, to: Date()),
            priority: .high,
            category: .equipment,
            competition: upcoming1
        )
        context.insert(task1)

        let task2 = CompetitionTask(
            title: "Confirm lorry booking with Sarah",
            notes: "Pick up at 6am, need to collect hay nets from yard first",
            dueDate: calendar.date(byAdding: .day, value: 8, to: Date()),
            priority: .high,
            category: .travel,
            competition: upcoming1
        )
        context.insert(task2)

        let task3 = CompetitionTask(
            title: "Check Biscuit Thief's passport",
            dueDate: calendar.date(byAdding: .day, value: 7, to: Date()),
            priority: .medium,
            category: .entries,
            competition: upcoming1
        )
        context.insert(task3)

        let task4 = CompetitionTask(
            title: "Submit entry form",
            dueDate: calendar.date(byAdding: .day, value: 5, to: Date()),
            priority: .high,
            category: .entries,
            competition: upcoming1
        )
        context.insert(task4)

        let task5 = CompetitionTask(
            title: "Clean and oil tack",
            dueDate: calendar.date(byAdding: .day, value: 11, to: Date()),
            priority: .medium,
            category: .equipment,
            competition: upcoming1
        )
        context.insert(task5)

        let task6 = CompetitionTask(
            title: "Book stable for overnight",
            notes: "Check if straw or shavings bedding available",
            dueDate: calendar.date(byAdding: .day, value: 6, to: Date()),
            priority: .medium,
            category: .venue,
            competition: upcoming1
        )
        context.insert(task6)

        // A couple of completed tasks
        let task7 = CompetitionTask(
            title: "Register for online entries portal",
            priority: .low,
            category: .entries,
            competition: upcoming1
        )
        task7.isCompleted = true
        task7.completedAt = calendar.date(byAdding: .day, value: -2, to: Date())
        context.insert(task7)

        let task8 = CompetitionTask(
            title: "Check swimming costume still fits",
            notes: "It does. Just.",
            priority: .low,
            category: .equipment,
            competition: upcoming1
        )
        task8.isCompleted = true
        task8.completedAt = calendar.date(byAdding: .day, value: -1, to: Date())
        context.insert(task8)
    }

    // MARK: - Rider Profile

    private static func generateRiderProfile(in context: ModelContext) {
        let descriptor = FetchDescriptor<RiderProfile>()
        if let existing = try? context.fetch(descriptor).first {
            // Update existing
            existing.weight = 52.0
            existing.height = 165.0
            existing.dateOfBirth = Calendar.current.date(byAdding: .year, value: -14, to: Date())
        } else {
            // Create new
            let profile = RiderProfile()
            profile.weight = 52.0
            profile.height = 165.0
            profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -14, to: Date())
            context.insert(profile)
        }
    }

    // MARK: - Helper Functions

    private static func createRide(
        name: String,
        type: RideType,
        durationMinutes: Int,
        distanceKm: Double,
        daysAgo: Int,
        horse: Horse,
        in context: ModelContext
    ) -> Ride {
        let ride = Ride()
        ride.name = name
        ride.rideTypeValue = type.rawValue
        ride.startDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        ride.endDate = ride.startDate.addingTimeInterval(Double(durationMinutes * 60))
        ride.totalDuration = Double(durationMinutes * 60)
        ride.totalDistance = distanceKm * 1000
        ride.horse = horse
        context.insert(ride)
        return ride
    }

    private static func addGaitSegments(
        to ride: Ride,
        segments: [(gait: GaitType, minutes: Int, distanceMeters: Double)],
        in context: ModelContext
    ) {
        var currentTime = ride.startDate

        for (gait, minutes, distance) in segments {
            let duration = Double(minutes * 60)
            let segment = GaitSegment(gaitType: gait, startTime: currentTime)
            segment.endTime = currentTime.addingTimeInterval(duration)
            segment.distance = distance
            segment.averageSpeed = distance / duration
            segment.rhythmScore = Double.random(in: 75...95)

            if gait == .canter || gait == .gallop {
                segment.leadValue = Bool.random() ? Lead.left.rawValue : Lead.right.rawValue
                segment.leadConfidence = Double.random(in: 0.82...0.96)
            }

            segment.ride = ride
            context.insert(segment)
            currentTime = currentTime.addingTimeInterval(duration)
        }
    }

    private static func generateParklandRoute(for ride: Ride, location: UKLocation, in context: ModelContext) {
        generateRoute(
            for: ride,
            startLat: location.latitude,
            startLon: location.longitude,
            startAlt: location.altitude,
            pattern: .parkland,
            in: context
        )
    }

    private static func generateXCRoute(for ride: Ride, location: UKLocation, in context: ModelContext) {
        generateRoute(
            for: ride,
            startLat: location.latitude,
            startLon: location.longitude,
            startAlt: location.altitude,
            pattern: .crossCountry,
            in: context
        )
    }

    private static func generateHillyRoute(for ride: Ride, location: UKLocation, in context: ModelContext) {
        generateRoute(
            for: ride,
            startLat: location.latitude,
            startLon: location.longitude,
            startAlt: location.altitude,
            pattern: .hilly,
            in: context
        )
    }

    private static func generateArenaRoute(for ride: Ride, location: UKLocation, in context: ModelContext) {
        generateRoute(
            for: ride,
            startLat: location.latitude,
            startLon: location.longitude,
            startAlt: location.altitude,
            pattern: .arena,
            in: context
        )
    }

    private static func generateBeachRoute(for ride: Ride, location: UKLocation, in context: ModelContext) {
        generateRoute(
            for: ride,
            startLat: location.latitude,
            startLon: location.longitude,
            startAlt: location.altitude,
            pattern: .beach,
            in: context
        )
    }

    enum RoutePattern {
        case parkland, crossCountry, hilly, arena, beach
    }

    private static func generateRoute(
        for ride: Ride,
        startLat: Double,
        startLon: Double,
        startAlt: Double,
        pattern: RoutePattern,
        in context: ModelContext
    ) {
        let pointCount = 120
        var currentLat = startLat
        var currentLon = startLon
        var currentAlt = startAlt

        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let timestamp = ride.startDate.addingTimeInterval(ride.totalDuration * progress)

            switch pattern {
            case .parkland:
                // Gentle meandering through parkland
                currentLat += Double.random(in: -0.0004...0.0008)
                currentLon += Double.random(in: -0.0003...0.0006)
                currentAlt += Double.random(in: -2...3)

            case .crossCountry:
                // More varied with some directional changes
                let direction = sin(progress * .pi * 3)
                currentLat += Double.random(in: -0.0003...0.0007) + direction * 0.0002
                currentLon += Double.random(in: -0.0002...0.0005)
                currentAlt += Double.random(in: -4...5)

            case .hilly:
                // Significant elevation changes
                currentLat += Double.random(in: -0.0005...0.0008)
                currentLon += Double.random(in: -0.0003...0.0006)
                let hillFactor = sin(progress * .pi * 4)
                currentAlt += hillFactor * 8 + Double.random(in: -2...2)

            case .arena:
                // Tight circles
                let angle = progress * 2 * .pi * 6 // Multiple laps
                let radius = 0.0003
                currentLat = startLat + radius * cos(angle)
                currentLon = startLon + radius * 1.5 * sin(angle)
                currentAlt = startAlt

            case .beach:
                // Long stretches with gentle curves
                currentLat += Double.random(in: -0.0002...0.001)
                currentLon += Double.random(in: -0.0001...0.0008)
                currentAlt = startAlt + Double.random(in: -1...1)
            }

            let point = LocationPoint(
                latitude: currentLat,
                longitude: currentLon,
                altitude: max(0, currentAlt),
                timestamp: timestamp,
                horizontalAccuracy: Double.random(in: 3...8),
                speed: Double.random(in: 1...9)
            )
            point.ride = ride
            context.insert(point)
        }
    }

    private static func addWeatherData(to ride: Ride, temp: Int, condition: String) {
        let weather = WeatherConditions(
            timestamp: ride.startDate,
            temperature: Double(temp),
            feelsLike: Double(temp - 1),
            humidity: 0.65,
            windSpeed: 3.5,  // m/s
            windDirection: 225,
            windGust: 5.0,
            condition: condition,
            conditionSymbol: conditionSymbol(for: condition),
            uvIndex: 4,
            visibility: 10000,
            pressure: 1015,
            precipitationChance: 0.1,
            isDaylight: true
        )
        ride.startWeather = weather
        ride.endWeather = weather
    }

    private static func conditionSymbol(for condition: String) -> String {
        switch condition {
        case "Sunny": return "sun.max.fill"
        case "Partly Cloudy": return "cloud.sun.fill"
        case "Cloudy": return "cloud.fill"
        default: return "cloud.fill"
        }
    }

    private static func addAISummary(to ride: Ride, summary: String) {
        let sessionSummary = SessionSummary(
            generatedAt: Date(),
            headline: ride.name,
            praise: ["Good balance", "Consistent rhythm", "Forward energy"],
            improvements: ["Consider more transitions", "Work on right bend"],
            keyMetrics: ["Distance: \(String(format: "%.1f", ride.totalDistance/1000)) km", "Duration: \(Int(ride.totalDuration/60)) mins"],
            encouragement: summary,
            overallRating: 4,
            voiceNotesIncluded: []
        )
        ride.aiSummary = sessionSummary
    }
}
