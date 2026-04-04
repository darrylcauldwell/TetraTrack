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
            notes: "The horse equivalent of a labrador - enthusiastic about everything, especially mud." +
                " Known for his 'creative interpretation' of dressage tests. Once spooked at his own shadow, twice.",
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

        // Create walking sessions
        generateWalkingSessions(in: context)

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

        // Clear walking routes (cascades to attempts)
        let walkingRouteDescriptor = FetchDescriptor<WalkingRoute>()
        if let routes = try? context.fetch(walkingRouteDescriptor) {
            routes.forEach { context.delete($0) }
        }

        // Clear unified drill sessions
        let drillDescriptor = FetchDescriptor<UnifiedDrillSession>()
        if let drills = try? context.fetch(drillDescriptor) {
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
        ride.notes = "Glorious morning hack! Biscuit Thief only tried to eat three different bushes today - personal best." +
            " The deer near the lake did NOT appreciate our canter. Pretty sure I now have twigs in places twigs shouldn't be."

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
        addAISummary(to: ride, summary: "Fantastic hack covering 12.5km! Your turn balance was excellent at 46% left / 54% right." +
            " Biscuit Thief's enthusiasm for the gallop section was admirable, if slightly terrifying." +
            " Maybe pack fewer snacks next time - the bush-munching attempts are increasing.")
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
        ride.notes = "XC schooling at Burghley! Jumped 18 fences including the water complex - Biscuit only splashed me SLIGHTLY on purpose." +
            " The corner was dramatic but we survived. My screaming may have been heard in the next county."

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
        addAISummary(to: ride, summary: "Epic XC session! Your heart rate peaked at 182bpm - possibly during 'the corner incident'." +
            " Lead balance was excellent at 52% left / 48% right." +
            " The water complex approach was... creative. Perhaps less screaming next time for optimal performance.")
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
        ride.notes = "Peak District adventure with Chaos Theory! 285m of climbing - my thighs may never forgive me." +
            " Chaos found three different mud puddles to 'accidentally' wade through. I'm now 40% mud. Worth it for the views though!"

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
        addAISummary(to: ride, summary: "Outstanding endurance ride! You conquered 285m of climbing over 16.2km." +
            " Chaos Theory's mud-seeking behaviour added 'character' to the session." +
            " Your steady pace up the hills shows excellent fitness. Consider waterproof breeches next time.")
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
        ride.notes = "Working on transitions with Biscuit Thief. Her idea of 'collection' is 'collecting treats'." +
            " The right bend is improving - she only tried to exit at C three times today. We're practically Charlotte Dujardin. Practically."

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
        addAISummary(to: ride, summary: "Productive schooling session! Turn balance of 52% is excellent - you're working both reins equally." +
            " Symmetry score improved to 88% on the right rein." +
            " The 'exit at C' attempts are decreasing. Charlotte Dujardin status: 78% achieved.")
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
        ride.notes = "Confidence-building hack with Drama Queen. She only spooked at TWO things today: a suspicious leaf and what I think was air." +
            " Major progress! The parkland views almost distracted me from my impending doom."

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
        addAISummary(to: ride, summary: "Excellent confidence-building session! Spook count down to 2 - a personal best for Drama Queen." +
            " Your steady pace and calm approach helped. The suspicious leaf has been officially survived. Progress: immense.")
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
        ride.notes = "Running through prelim test with Chaos Theory. His 'free walk on a long rein' was more 'chaotic jig towards the gate'." +
            " The canter serpentine was... interpretive. At least our halt was square-ish."

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
        addAISummary(to: ride, summary: "Solid test practice! Your rhythm score of 84% is improving." +
            " The 'interpretive serpentine' showed creativity if not accuracy." +
            " Halt squareness: acceptable. Judges' sanity if they'd seen the free walk: questionable.")
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
        ride.notes = "BEACH DAY! Biscuit Thief transformed into a racehorse the moment her hooves hit the sand." +
            " Max speed 10.5m/s - I may have briefly lost my voice screaming 'WHEEEEE'. Sand in places sand shouldn't be. 10/10 would gallop again."

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
        addAISummary(to: ride, summary: "Exhilarating beach session! Your max speed of 10.5m/s suggests Biscuit Thief may have Red Rum ancestors." +
            " Heart rate peaked at 175bpm - possibly from the joy of life. Lead balance excellent. Sand extraction from riding boots: expected.")
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
        ride.notes = "SJ practice at Hickstead! Jumped up to 1m - Biscuit cleared it by approximately 47 metres." +
            " Her enthusiasm is not matched by my core strength. The getaways are getting tidier - only one victory lap today."

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
        addAISummary(to: ride, summary: "Strong jumping session! The 47-metre clearance over the 1m fence shows excellent scope" +
            " (and possibly excessive enthusiasm). Victory lap frequency is decreasing." +
            " Your core strength may need attention - consider more sit-ups.")
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
        ride.notes = "Raised poles and trot grids with Drama Queen. She's convinced the blue poles are more dangerous than the others." +
            " Counting strides has improved - we only launched into orbit twice today. Progress!"

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
        addAISummary(to: ride, summary: "Great polework session! Your rhythm through the grids improved from 78% to 82% by the end." +
            " Drama Queen's suspicion of blue poles is noted. The 'orbit launches' are becoming more controlled.")
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
        ride.notes = "Bounce grids to one-stride combinations. Biscuit Thief has decided bounces are her favourite thing" +
            " - she adds extra enthusiasm to every one. My back may disagree. The one-stride was... occasionally a no-stride."

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
        addAISummary(to: ride, summary: "Excellent gridwork! Symmetry at 88% shows you're staying balanced over the fences." +
            " The 'extra enthusiasm' is building Biscuit's confidence." +
            " Consider the occasional no-stride as 'advanced scope demonstration'.")
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
        ride.notes = "Lungeing Chaos Theory - which means I got more exercise than him trying to keep the circle actually circular." +
            " He's convinced lunge line = impromptu tug-of-war. Equal work both reins achieved through sheer determination."

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
        addAISummary(to: ride, summary: "Good lunge session! Turn balance is nearly perfect at 51%/49%." +
            " Chaos Theory's 'creative interpretation' of the circle improved as the session progressed." +
            " Your step count must have been impressive!")
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
        ride.notes = "Lateral work focus - leg yield improving! Shoulder-in left is still 'shoulder-somewhere-in-the-vicinity'." +
            " Biscuit's travers attempt was... a creative quarter pirouette. We'll call it intentional."

        addGaitSegments(to: ride, segments: [
            (.walk, 10, 650),
            (.trot, 15, 2200),
            (.walk, 5, 350),
            (.trot, 12, 1800),
            (.walk, 8, 500),
        ], in: context)

        generateArenaRoute(for: ride, location: .chatsworthHouse, in: context)
        addWeatherData(to: ride, temp: 12, condition: "Cloudy")
        addAISummary(to: ride, summary: "Solid lateral work! The 6% difference in symmetry between reins shows left is your weaker side" +
            " - focus there next session. The 'creative quarter pirouette' shows Biscuit's athleticism. Glass half full!")
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
        trial.minHeartRate = 142
        trial.averageVerticalOscillation = 9.2
        trial.averageGroundContactTime = 238
        trial.healthKitStrideLength = 1.25
        trial.healthKitPower = 320
        trial.healthKitSpeed = 3.97
        trial.startWeather = WeatherConditions(
            timestamp: trial.startDate, temperature: 11, feelsLike: 9,
            humidity: 0.72, windSpeed: 4.2, windDirection: 200, windGust: 6.5,
            condition: "Partly Cloudy", conditionSymbol: "cloud.sun.fill",
            uvIndex: 3, visibility: 12000, pressure: 1018, precipitationChance: 0.15, isDaylight: true
        )
        trial.endWeather = trial.startWeather
        trial.notes = "6:18 for 1500m - new PB! The last 200m was powered entirely by spite and the knowledge that ice cream awaited. Legs have filed a formal complaint."
        trial.averageBreathingRate = 28
        trial.averageSpO2 = 96
        trial.postureStability = 72
        trial.endFatigueScore = 35
        trial.trainingLoadScore = 65
        trial.recoveryQuality = 70
        context.insert(trial)
        generateRunningHeartRateSamples(for: trial, warmupHR: 142, peakHR: 185, sampleCount: 25)
        generateRunningRoute(for: trial, startLat: 51.5419, startLon: -2.2872, in: context)
        generateRunningSplits(for: trial, in: context)

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
        easy.minHeartRate = 118
        easy.averageVerticalOscillation = 8.5
        easy.averageGroundContactTime = 262
        easy.healthKitStrideLength = 1.12
        easy.healthKitPower = 245
        easy.healthKitSpeed = 2.89
        easy.startWeather = WeatherConditions(
            timestamp: easy.startDate, temperature: 14, feelsLike: 13,
            humidity: 0.58, windSpeed: 2.8, windDirection: 180, windGust: nil,
            condition: "Sunny", conditionSymbol: "sun.max.fill",
            uvIndex: 5, visibility: 15000, pressure: 1022, precipitationChance: 0.05, isDaylight: true
        )
        easy.endWeather = easy.startWeather
        easy.notes = "Easy 5k that was supposed to be 'gentle'. Still got overtaken by someone's grandmother. The dog that joined me for 2km was a highlight."
        easy.averageBreathingRate = 22
        easy.averageSpO2 = 97
        easy.postureStability = 82
        easy.endFatigueScore = 15
        easy.trainingLoadScore = 35
        easy.recoveryQuality = 85
        context.insert(easy)
        generateRunningHeartRateSamples(for: easy, warmupHR: 118, peakHR: 158, sampleCount: 25)
        generateRunningRoute(for: easy, startLat: 52.6214, startLon: -0.4133, in: context)
        generateRunningSplits(for: easy, in: context)

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
        intervals.minHeartRate = 128
        intervals.averageVerticalOscillation = 8.8
        intervals.averageGroundContactTime = 242
        intervals.healthKitStrideLength = 1.22
        intervals.healthKitPower = 310
        intervals.healthKitSpeed = 3.24
        intervals.startWeather = WeatherConditions(
            timestamp: intervals.startDate, temperature: 10, feelsLike: 8,
            humidity: 0.68, windSpeed: 5.1, windDirection: 270, windGust: 7.8,
            condition: "Cloudy", conditionSymbol: "cloud.fill",
            uvIndex: 2, visibility: 8000, pressure: 1010, precipitationChance: 0.30, isDaylight: true
        )
        intervals.endWeather = intervals.startWeather
        intervals.notes = "8x400m intervals. Each one felt progressively more like a life choice I needed to reconsider. The voice coach telling me to 'pick it up' was NOT appreciated on rep 7."
        intervals.averageBreathingRate = 26
        intervals.averageSpO2 = 96
        intervals.postureStability = 75
        intervals.endFatigueScore = 30
        intervals.trainingLoadScore = 60
        intervals.recoveryQuality = 72
        context.insert(intervals)
        generateRunningHeartRateSamples(for: intervals, warmupHR: 128, peakHR: 188, sampleCount: 30)
        generateRunningRoute(for: intervals, startLat: 53.2271, startLon: -1.6115, in: context)
        generateRunningSplits(for: intervals, in: context)

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
        treadmill.minHeartRate = 125
        treadmill.averageVerticalOscillation = 7.8
        treadmill.averageGroundContactTime = 255
        treadmill.healthKitStrideLength = 1.08
        treadmill.healthKitPower = 260
        treadmill.healthKitSpeed = 2.80
        treadmill.notes = "It was raining. I have no regrets. Watched an entire episode of something while running. This is peak efficiency. Or laziness. Possibly both."
        treadmill.averageBreathingRate = 24
        treadmill.averageSpO2 = 97
        treadmill.postureStability = 78
        treadmill.endFatigueScore = 18
        treadmill.trainingLoadScore = 40
        treadmill.recoveryQuality = 80
        context.insert(treadmill)
        generateRunningHeartRateSamples(for: treadmill, warmupHR: 125, peakHR: 162, sampleCount: 20)
        // No GPS route for treadmill

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
        longRun.minHeartRate = 120
        longRun.averageVerticalOscillation = 8.2
        longRun.averageGroundContactTime = 268
        longRun.healthKitStrideLength = 1.05
        longRun.healthKitPower = 230
        longRun.healthKitSpeed = 2.92
        longRun.startWeather = WeatherConditions(
            timestamp: longRun.startDate, temperature: 8, feelsLike: 6,
            humidity: 0.78, windSpeed: 3.2, windDirection: 315, windGust: 5.5,
            condition: "Cloudy", conditionSymbol: "cloud.fill",
            uvIndex: 2, visibility: 9000, pressure: 1008, precipitationChance: 0.40, isDaylight: true
        )
        longRun.endWeather = longRun.startWeather
        longRun.notes = "10.5km Sunday long run. The first 5km felt amazing. The last 5km felt like a negotiation with my legs." +
            " Discovered three new blisters and one new appreciation for sofas. The pub at the end was motivational."
        longRun.averageBreathingRate = 24
        longRun.averageSpO2 = 97
        longRun.postureStability = 76
        longRun.endFatigueScore = 28
        longRun.trainingLoadScore = 55
        longRun.recoveryQuality = 68
        context.insert(longRun)
        generateRunningHeartRateSamples(for: longRun, warmupHR: 120, peakHR: 165, sampleCount: 30)
        generateRunningRoute(for: longRun, startLat: 51.8413, startLon: -1.3618, in: context)
        generateRunningSplits(for: longRun, in: context)

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
        tempo.minHeartRate = 135
        tempo.averageVerticalOscillation = 8.6
        tempo.averageGroundContactTime = 245
        tempo.healthKitStrideLength = 1.18
        tempo.healthKitPower = 295
        tempo.healthKitSpeed = 3.22
        tempo.startWeather = WeatherConditions(
            timestamp: tempo.startDate, temperature: 13, feelsLike: 12,
            humidity: 0.62, windSpeed: 2.5, windDirection: 160, windGust: nil,
            condition: "Partly Cloudy", conditionSymbol: "cloud.sun.fill",
            uvIndex: 4, visibility: 14000, pressure: 1020, precipitationChance: 0.10, isDaylight: true
        )
        tempo.endWeather = tempo.startWeather
        tempo.notes = "Tempo pace practice - 'comfortably hard' they said. 'Uncomfortable and questioning life choices' is more accurate." +
            " Maintained pace for 4km though, which is a win. The voice coach was encouraging. Too encouraging."
        tempo.averageBreathingRate = 26
        tempo.averageSpO2 = 96
        tempo.postureStability = 74
        tempo.endFatigueScore = 25
        tempo.trainingLoadScore = 55
        tempo.recoveryQuality = 72
        context.insert(tempo)
        generateRunningHeartRateSamples(for: tempo, warmupHR: 135, peakHR: 175, sampleCount: 25)
        generateRunningRoute(for: tempo, startLat: 54.1193, startLon: -0.9095, in: context)
        generateRunningSplits(for: tempo, in: context)

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
        pacer.minHeartRate = 138
        pacer.averageVerticalOscillation = 9.0
        pacer.averageGroundContactTime = 240
        pacer.healthKitStrideLength = 1.20
        pacer.healthKitPower = 305
        pacer.healthKitSpeed = 3.57
        pacer.startWeather = WeatherConditions(
            timestamp: pacer.startDate, temperature: 12, feelsLike: 10,
            humidity: 0.65, windSpeed: 3.8, windDirection: 220, windGust: 5.2,
            condition: "Partly Cloudy", conditionSymbol: "cloud.sun.fill",
            uvIndex: 3, visibility: 11000, pressure: 1016, precipitationChance: 0.20, isDaylight: true
        )
        pacer.endWeather = pacer.startWeather
        pacer.notes = "Chasing my PB ghost on the 1500m. The ghost won by 42 seconds. The ghost is a show-off." +
            " Next time I'm setting a more achievable ghost. One that maybe takes a coffee break mid-run."
        pacer.averageBreathingRate = 27
        pacer.averageSpO2 = 96
        pacer.postureStability = 70
        pacer.endFatigueScore = 32
        pacer.trainingLoadScore = 58
        pacer.recoveryQuality = 68
        context.insert(pacer)
        generateRunningHeartRateSamples(for: pacer, warmupHR: 138, peakHR: 180, sampleCount: 20)
        generateRunningRoute(for: pacer, startLat: 52.2821, startLon: -1.0012, in: context)
        generateRunningSplits(for: pacer, in: context)

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
        hills.minHeartRate = 130
        hills.averageVerticalOscillation = 9.5
        hills.averageGroundContactTime = 248
        hills.healthKitStrideLength = 1.10
        hills.healthKitPower = 340
        hills.healthKitSpeed = 2.80
        hills.startWeather = WeatherConditions(
            timestamp: hills.startDate, temperature: 9, feelsLike: 7,
            humidity: 0.75, windSpeed: 4.5, windDirection: 290, windGust: 7.0,
            condition: "Cloudy", conditionSymbol: "cloud.fill",
            uvIndex: 2, visibility: 7000, pressure: 1005, precipitationChance: 0.35, isDaylight: true
        )
        hills.endWeather = hills.startWeather
        hills.notes = "6x hill repeats. By rep 4, the hill had become my nemesis. By rep 6, we had reached an uneasy truce." +
            " My quads are filing a formal complaint with HR. The views from the top were lovely, when I could see through the tears."
        hills.averageBreathingRate = 28
        hills.averageSpO2 = 95
        hills.postureStability = 68
        hills.endFatigueScore = 38
        hills.trainingLoadScore = 68
        hills.recoveryQuality = 62
        context.insert(hills)
        generateRunningHeartRateSamples(for: hills, warmupHR: 130, peakHR: 182, sampleCount: 25)
        generateRunningRoute(for: hills, startLat: 50.8559, startLon: -0.5528, in: context)
        generateRunningSplits(for: hills, in: context)

        // Recovery Run
        let recovery = RunningSession(name: "Recovery Shuffle (Barely Moving)", sessionType: .recovery, runMode: .outdoor)
        recovery.startDate = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        recovery.endDate = recovery.startDate.addingTimeInterval(1500)
        recovery.totalDistance = 3800
        recovery.totalDuration = 1500
        recovery.averageCadence = 155
        recovery.maxCadence = 162
        recovery.averageHeartRate = 118
        recovery.maxHeartRate = 132
        recovery.totalAscent = 15
        recovery.totalDescent = 12
        recovery.minHeartRate = 95
        recovery.averageVerticalOscillation = 7.2
        recovery.averageGroundContactTime = 275
        recovery.healthKitStrideLength = 1.02
        recovery.healthKitPower = 205
        recovery.healthKitSpeed = 2.53
        recovery.startWeather = WeatherConditions(
            timestamp: recovery.startDate, temperature: 15, feelsLike: 14,
            humidity: 0.55, windSpeed: 1.8, windDirection: 150, windGust: nil,
            condition: "Sunny", conditionSymbol: "sun.max.fill",
            uvIndex: 5, visibility: 16000, pressure: 1025, precipitationChance: 0.05, isDaylight: true
        )
        recovery.endWeather = recovery.startWeather
        recovery.notes = "Post-XC-schooling recovery jog. My legs had a team meeting and decided anything faster than a shuffle was unacceptable." +
            " Three pensioners overtook me. One offered encouragement. It was humbling."
        recovery.averageBreathingRate = 20
        recovery.averageSpO2 = 98
        recovery.postureStability = 85
        recovery.endFatigueScore = 10
        recovery.trainingLoadScore = 20
        recovery.recoveryQuality = 90
        context.insert(recovery)
        generateRunningHeartRateSamples(for: recovery, warmupHR: 95, peakHR: 132, sampleCount: 20)
        generateRunningRoute(for: recovery, startLat: 50.9683, startLon: -0.2247, in: context)
        generateRunningSplits(for: recovery, in: context)

        // Race - Parkrun
        let race = RunningSession(name: "Saturday Parkrun (Competitive Walking)", sessionType: .race, runMode: .outdoor)
        race.startDate = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
        race.endDate = race.startDate.addingTimeInterval(1620)
        race.totalDistance = 5000
        race.totalDuration = 1620 // 27:00
        race.averageCadence = 174
        race.maxCadence = 190
        race.averageHeartRate = 172
        race.maxHeartRate = 192
        race.totalAscent = 42
        race.totalDescent = 40
        race.minHeartRate = 145
        race.averageVerticalOscillation = 9.3
        race.averageGroundContactTime = 235
        race.healthKitStrideLength = 1.28
        race.healthKitPower = 335
        race.healthKitSpeed = 3.09
        race.startWeather = WeatherConditions(
            timestamp: race.startDate, temperature: 10, feelsLike: 8,
            humidity: 0.70, windSpeed: 3.5, windDirection: 240, windGust: 5.8,
            condition: "Partly Cloudy", conditionSymbol: "cloud.sun.fill",
            uvIndex: 3, visibility: 12000, pressure: 1014, precipitationChance: 0.15, isDaylight: true
        )
        race.endWeather = race.startWeather
        race.notes = "Parkrun PB attempt! Went out too fast, died at 3km, somehow resurrected for the sprint finish." +
            " Overtook someone in the funnel - peak athletic achievement. Free banana made it all worthwhile. Official time: 27:00."
        race.averageBreathingRate = 30
        race.averageSpO2 = 95
        race.postureStability = 68
        race.endFatigueScore = 40
        race.trainingLoadScore = 70
        race.recoveryQuality = 65
        context.insert(race)
        generateRunningHeartRateSamples(for: race, warmupHR: 145, peakHR: 192, sampleCount: 30)
        generateRunningRoute(for: race, startLat: 51.7580, startLon: -1.5803, in: context)
        generateRunningSplits(for: race, in: context)

        // Fartlek
        let fartlek = RunningSession(name: "Fartlek Fun (Organised Chaos)", sessionType: .fartlek, runMode: .outdoor)
        fartlek.startDate = Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date()
        fartlek.endDate = fartlek.startDate.addingTimeInterval(2400)
        fartlek.totalDistance = 7200
        fartlek.totalDuration = 2400
        fartlek.averageCadence = 170
        fartlek.maxCadence = 188
        fartlek.averageHeartRate = 155
        fartlek.maxHeartRate = 184
        fartlek.totalAscent = 55
        fartlek.totalDescent = 52
        fartlek.minHeartRate = 125
        fartlek.averageVerticalOscillation = 8.4
        fartlek.averageGroundContactTime = 250
        fartlek.healthKitStrideLength = 1.15
        fartlek.healthKitPower = 280
        fartlek.healthKitSpeed = 3.00
        fartlek.startWeather = WeatherConditions(
            timestamp: fartlek.startDate, temperature: 12, feelsLike: 11,
            humidity: 0.60, windSpeed: 2.2, windDirection: 170, windGust: nil,
            condition: "Sunny", conditionSymbol: "sun.max.fill",
            uvIndex: 4, visibility: 15000, pressure: 1021, precipitationChance: 0.08, isDaylight: true
        )
        fartlek.endWeather = fartlek.startWeather
        fartlek.notes = "Fartlek = Swedish for 'speed play'. My version = sprint to the next lamppost, wheeze dramatically, jog to recover, repeat." +
            " The dog walker who kept appearing thought I was having a medical emergency. Best unstructured session yet!"
        fartlek.averageBreathingRate = 25
        fartlek.averageSpO2 = 96
        fartlek.postureStability = 74
        fartlek.endFatigueScore = 22
        fartlek.trainingLoadScore = 50
        fartlek.recoveryQuality = 75
        context.insert(fartlek)
        generateRunningHeartRateSamples(for: fartlek, warmupHR: 125, peakHR: 184, sampleCount: 28)
        generateRunningRoute(for: fartlek, startLat: 52.2856, startLon: -1.5349, in: context)
        generateRunningSplits(for: fartlek, in: context)
    }

    // MARK: - Walking Sessions

    private static func generateWalkingSessions(in context: ModelContext) {
        let calendar = Calendar.current

        // MARK: Walking Route 1 — Cotswold Village Loop
        let villageRoute = WalkingRoute(
            name: "Cotswold Village Loop",
            startLatitude: 51.7580,
            startLongitude: -1.5803
        )
        villageRoute.routeDistanceMeters = 3200
        villageRoute.endLatitude = 51.7580
        villageRoute.endLongitude = -1.5803
        context.insert(villageRoute)

        // Attempt 1 — oldest, learning the route (16 days ago)
        let villageAttempt1 = WalkingRouteAttempt(
            date: calendar.date(byAdding: .day, value: -16, to: Date()) ?? Date(),
            durationSeconds: 2280, // 38 min
            pacePerKm: 712,       // ~11:52/km
            averageCadence: 112,
            symmetryScore: 72,
            rhythmScore: 76,
            stabilityScore: 68
        )
        villageAttempt1.route = villageRoute
        context.insert(villageAttempt1)

        // Attempt 2 — improving (9 days ago)
        let villageAttempt2 = WalkingRouteAttempt(
            date: calendar.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
            durationSeconds: 2100, // 35 min
            pacePerKm: 656,       // ~10:56/km
            averageCadence: 118,
            symmetryScore: 80,
            rhythmScore: 82,
            stabilityScore: 75
        )
        villageAttempt2.route = villageRoute
        context.insert(villageAttempt2)

        // Attempt 3 — most recent, linked to walking session (2 days ago)
        let villageAttempt3Date = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let villageAttempt3 = WalkingRouteAttempt(
            date: villageAttempt3Date,
            durationSeconds: 1980, // 33 min
            pacePerKm: 619,       // ~10:19/km
            averageCadence: 122,
            symmetryScore: 88,
            rhythmScore: 85,
            stabilityScore: 82
        )
        villageAttempt3.route = villageRoute
        context.insert(villageAttempt3)

        villageRoute.updateAggregates()

        // Walking Session 1 — Village Loop (linked to route)
        let walk1 = RunningSession(name: "Cotswold Village Loop", sessionType: .walking, runMode: .outdoor)
        walk1.startDate = villageAttempt3Date
        walk1.endDate = walk1.startDate.addingTimeInterval(1980)
        walk1.totalDistance = 3200
        walk1.totalDuration = 1980
        walk1.averageCadence = 122
        walk1.maxCadence = 132
        walk1.averageHeartRate = 108
        walk1.maxHeartRate = 125
        walk1.totalAscent = 45
        walk1.totalDescent = 42
        walk1.walkingSymmetryScore = 88
        walk1.walkingRhythmScore = 85
        walk1.walkingStabilityScore = 82
        walk1.walkingCadenceConsistency = 4.2
        walk1.healthKitDoubleSupportPercentage = 28.5
        walk1.healthKitWalkingSpeed = 1.62
        walk1.healthKitWalkingStepLength = 0.72
        walk1.healthKitWalkingSteadiness = 85.0
        walk1.healthKitAsymmetry = 4.2
        walk1.minHeartRate = 88
        walk1.startWeather = WeatherConditions(
            timestamp: walk1.startDate, temperature: 14, feelsLike: 13,
            humidity: 0.55, windSpeed: 2.0, windDirection: 190, windGust: nil,
            condition: "Sunny", conditionSymbol: "sun.max.fill",
            uvIndex: 4, visibility: 15000, pressure: 1022, precipitationChance: 0.05, isDaylight: true
        )
        walk1.endWeather = walk1.startWeather
        walk1.matchedRouteId = villageRoute.id
        walk1.routeComparison = WalkingRouteComparison(
            routeId: villageRoute.id,
            routeName: "Cotswold Village Loop",
            attemptNumber: 3,
            paceDelta: -37,
            cadenceDelta: 4,
            symmetryDelta: 8,
            rhythmDelta: 3,
            stabilityDelta: 7,
            durationDelta: -120,
            paceVsAverage: -43,
            durationVsAverage: -140
        )
        walk1.notes = "Beautiful evening loop through the village. Stone walls, thatched cottages, and one very judgmental sheep." +
            " Pace improving each time — the legs are getting used to the hill by the pub. Biomechanics looking good!"
        context.insert(walk1)
        generateRunningHeartRateSamples(for: walk1, warmupHR: 88, peakHR: 125, sampleCount: 20)
        generateWalkingRoute(for: walk1, startLat: 51.7580, startLon: -1.5803, in: context)
        villageAttempt3.runningSessionId = walk1.id

        // MARK: Walking Route 2 — Grand Union Canal Towpath
        let canalRoute = WalkingRoute(
            name: "Grand Union Canal Towpath",
            startLatitude: 52.2856,
            startLongitude: -1.5349
        )
        canalRoute.routeDistanceMeters = 4800
        canalRoute.endLatitude = 52.3012
        canalRoute.endLongitude = -1.5187
        context.insert(canalRoute)

        // Attempt 1 — first walk (12 days ago)
        let canalAttempt1 = WalkingRouteAttempt(
            date: calendar.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
            durationSeconds: 3240, // 54 min
            pacePerKm: 675,       // ~11:15/km
            averageCadence: 115,
            symmetryScore: 75,
            rhythmScore: 78,
            stabilityScore: 70
        )
        canalAttempt1.route = canalRoute
        context.insert(canalAttempt1)

        // Attempt 2 — improving, linked to walking session (5 days ago)
        let canalAttempt2Date = calendar.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        let canalAttempt2 = WalkingRouteAttempt(
            date: canalAttempt2Date,
            durationSeconds: 3000, // 50 min
            pacePerKm: 625,       // ~10:25/km
            averageCadence: 120,
            symmetryScore: 82,
            rhythmScore: 84,
            stabilityScore: 78
        )
        canalAttempt2.route = canalRoute
        context.insert(canalAttempt2)

        canalRoute.updateAggregates()

        // Walking Session 2 — Canal Towpath (linked to route)
        let walk2 = RunningSession(name: "Canal Towpath Wander", sessionType: .walking, runMode: .outdoor)
        walk2.startDate = canalAttempt2Date
        walk2.endDate = walk2.startDate.addingTimeInterval(3000)
        walk2.totalDistance = 4800
        walk2.totalDuration = 3000
        walk2.averageCadence = 120
        walk2.maxCadence = 128
        walk2.averageHeartRate = 112
        walk2.maxHeartRate = 130
        walk2.totalAscent = 12
        walk2.totalDescent = 10
        walk2.walkingSymmetryScore = 82
        walk2.walkingRhythmScore = 84
        walk2.walkingStabilityScore = 78
        walk2.walkingCadenceConsistency = 5.1
        walk2.healthKitDoubleSupportPercentage = 31.2
        walk2.healthKitWalkingSpeed = 1.6
        walk2.healthKitWalkingStepLength = 0.70
        walk2.healthKitWalkingSteadiness = 79.0
        walk2.healthKitAsymmetry = 5.8
        walk2.minHeartRate = 92
        walk2.startWeather = WeatherConditions(
            timestamp: walk2.startDate, temperature: 11, feelsLike: 9,
            humidity: 0.72, windSpeed: 3.5, windDirection: 250, windGust: 5.0,
            condition: "Cloudy", conditionSymbol: "cloud.fill",
            uvIndex: 2, visibility: 8000, pressure: 1012, precipitationChance: 0.25, isDaylight: true
        )
        walk2.endWeather = walk2.startWeather
        walk2.matchedRouteId = canalRoute.id
        walk2.routeComparison = WalkingRouteComparison(
            routeId: canalRoute.id,
            routeName: "Grand Union Canal Towpath",
            attemptNumber: 2,
            paceDelta: -50,
            cadenceDelta: 5,
            symmetryDelta: 7,
            rhythmDelta: 6,
            stabilityDelta: 8,
            durationDelta: -240,
            paceVsAverage: -25,
            durationVsAverage: -120
        )
        walk2.notes = "Flat towpath walk along the canal. Narrowboat traffic was excellent entertainment." +
            " Lost count of the locks but gained a new appreciation for canal engineering. The resident heron gave me the side-eye. Again."
        context.insert(walk2)
        generateRunningHeartRateSamples(for: walk2, warmupHR: 92, peakHR: 130, sampleCount: 20)
        generateWalkingRoute(for: walk2, startLat: 52.2856, startLon: -1.5349, in: context)
        canalAttempt2.runningSessionId = walk2.id

        // MARK: Walking Session 3 — Standalone (no saved route)
        let walk3 = RunningSession(name: "Morning Meander (No Plan)", sessionType: .walking, runMode: .outdoor)
        walk3.startDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        walk3.endDate = walk3.startDate.addingTimeInterval(2400)
        walk3.totalDistance = 3600
        walk3.totalDuration = 2400
        walk3.averageCadence = 118
        walk3.maxCadence = 126
        walk3.averageHeartRate = 105
        walk3.maxHeartRate = 118
        walk3.totalAscent = 28
        walk3.totalDescent = 25
        walk3.walkingSymmetryScore = 78
        walk3.walkingRhythmScore = 80
        walk3.walkingStabilityScore = 72
        walk3.walkingCadenceConsistency = 6.3
        walk3.healthKitDoubleSupportPercentage = 30.0
        walk3.healthKitWalkingSpeed = 1.5
        walk3.healthKitWalkingStepLength = 0.68
        walk3.healthKitWalkingSteadiness = 76.0
        walk3.healthKitAsymmetry = 6.5
        walk3.minHeartRate = 85
        walk3.startWeather = WeatherConditions(
            timestamp: walk3.startDate, temperature: 16, feelsLike: 15,
            humidity: 0.50, windSpeed: 1.5, windDirection: 140, windGust: nil,
            condition: "Sunny", conditionSymbol: "sun.max.fill",
            uvIndex: 6, visibility: 18000, pressure: 1028, precipitationChance: 0.02, isDaylight: true
        )
        walk3.endWeather = walk3.startWeather
        walk3.notes = "Just walked. No plan, no route, no pressure. Ended up at a farm shop and bought cheese." +
            " The walk home was slightly faster — possibly cheese-motivated. Sometimes the best training is no training."
        context.insert(walk3)
        generateRunningHeartRateSamples(for: walk3, warmupHR: 85, peakHR: 118, sampleCount: 18)
        generateWalkingRoute(for: walk3, startLat: 51.8413, startLon: -1.3618, in: context)
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
        test.averageHeartRate = 165
        test.maxHeartRate = 182
        test.minHeartRate = 140
        test.averageBreathingRate = 28
        test.averageSpO2 = 96
        test.notes = "9 lengths in 3 minutes - PB! The tumble turns are getting less 'tumble' and more 'controlled chaos'. Only swallowed a small amount of chlorine this time. Progress!"
        context.insert(test)
        generateSwimmingHeartRateSamples(for: test, warmupHR: 140, peakHR: 182, sampleCount: 15)

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
        training.averageHeartRate = 155
        training.maxHeartRate = 175
        training.minHeartRate = 125
        training.averageBreathingRate = 26
        training.averageSpO2 = 97
        training.endFatigueScore = 22
        training.trainingLoadScore = 48
        training.recoveryQuality = 75
        training.notes = "1km of speed sets! SWOLF improving - apparently I'm more efficient when there's cake promised at the end." +
            " The lane rope and I had a minor disagreement on length 32. We've reconciled."
        context.insert(training)
        generateSwimmingHeartRateSamples(for: training, warmupHR: 125, peakHR: 175, sampleCount: 25)

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
        openWater.averageHeartRate = 148
        openWater.maxHeartRate = 168
        openWater.minHeartRate = 118
        openWater.averageBreathingRate = 24
        openWater.averageSpO2 = 96
        openWater.endFatigueScore = 18
        openWater.trainingLoadScore = 35
        openWater.recoveryQuality = 78
        openWater.isIndoor = false
        openWater.startWeather = WeatherConditions(
            timestamp: openWater.startDate, temperature: 16, feelsLike: 15,
            humidity: 0.65, windSpeed: 2.5, windDirection: 180, windGust: nil,
            condition: "Partly Cloudy", conditionSymbol: "cloud.sun.fill",
            uvIndex: 5, visibility: 14000, pressure: 1020, precipitationChance: 0.10, isDaylight: true
        )
        openWater.endWeather = openWater.startWeather
        openWater.notes = "First open water swim of the season! Water temperature: 'refreshing' (read: cold enough to reconsider life)." +
            " Sighting practice went well - only swam into one buoy. The ducks were unimpressed by my technique."
        context.insert(openWater)
        generateSwimmingHeartRateSamples(for: openWater, warmupHR: 118, peakHR: 168, sampleCount: 20)

        // 50m Pool Session
        let fiftyPool = SwimmingSession(name: "Olympic Pool Practice", poolMode: .pool, poolLength: 50)
        fiftyPool.startDate = Calendar.current.date(byAdding: .day, value: -11, to: Date()) ?? Date()
        fiftyPool.endDate = fiftyPool.startDate.addingTimeInterval(2400)
        fiftyPool.totalDistance = 1500
        fiftyPool.totalDuration = 1800
        fiftyPool.totalStrokes = 1080
        fiftyPool.averageHeartRate = 152
        fiftyPool.maxHeartRate = 172
        fiftyPool.minHeartRate = 120
        fiftyPool.averageBreathingRate = 25
        fiftyPool.averageSpO2 = 97
        fiftyPool.endFatigueScore = 25
        fiftyPool.trainingLoadScore = 52
        fiftyPool.recoveryQuality = 72
        fiftyPool.notes = "50m pool - half the turns means twice the suffering per length. The extra distance between walls is psychological warfare." +
            " Flip turns are getting tidier though - only 60% of them involve mild panic now."
        context.insert(fiftyPool)
        generateSwimmingHeartRateSamples(for: fiftyPool, warmupHR: 120, peakHR: 172, sampleCount: 25)

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
        technique.averageHeartRate = 138
        technique.maxHeartRate = 155
        technique.minHeartRate = 112
        technique.averageBreathingRate = 22
        technique.averageSpO2 = 98
        technique.endFatigueScore = 12
        technique.trainingLoadScore = 30
        technique.recoveryQuality = 85
        technique.notes = "Technique drills - catch-up drill, fingertip drag, fist swimming." +
            " Discovered I've been 'swimming' with more splash than propulsion." +
            " Coach said my catch was 'improving' with a very diplomatic expression."
        context.insert(technique)
        generateSwimmingHeartRateSamples(for: technique, warmupHR: 112, peakHR: 155, sampleCount: 20)

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
        endurance.averageHeartRate = 148
        endurance.maxHeartRate = 168
        endurance.minHeartRate = 118
        endurance.averageBreathingRate = 24
        endurance.averageSpO2 = 96
        endurance.endFatigueScore = 30
        endurance.trainingLoadScore = 58
        endurance.recoveryQuality = 65
        endurance.notes = "2km continuous swim! The first 500m were pleasant. The second 500m were okay. The third 500m involved counting tiles." +
            " The final 500m was powered by stubbornness and the promise of hot chocolate. Channel swim status: not yet."
        context.insert(endurance)
        generateSwimmingHeartRateSamples(for: endurance, warmupHR: 118, peakHR: 168, sampleCount: 30)

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
        comp.sessionContext = .competitionTraining
        comp.averageHeartRate = 92
        comp.maxHeartRate = 108
        comp.minHeartRate = 78
        comp.averageStanceStability = 78
        comp.averageTremorLevel = 18
        comp.averageHoldSteadiness = 76
        comp.averageHoldDuration = 3.8
        comp.shotTimingConsistencyCV = 12.5
        comp.firstHalfSteadiness = 80
        comp.secondHalfSteadiness = 72
        comp.steadinessDegradation = 10.0
        comp.stabilityScore = 78
        comp.rhythmScore = 82
        comp.symmetryScore = 75
        comp.economyScore = 80
        comp.composureScore = 72
        comp.overallBiomechanicalScore = 79
        comp.averageBreathingRate = 16
        comp.averageSpO2 = 98
        comp.postureStability = 78
        comp.endFatigueScore = 12
        comp.trainingLoadScore = 28
        comp.notes = "86 points across 2 cards! My stance is getting steadier - the Watch only judged me 'slightly wobbly' this time. Shot 5 on card 1 was... ambitious. We don't talk about shot 5."
        context.insert(comp)
        generateShootingHeartRateSamples(for: comp, restingHR: 78, peakHR: 108, sampleCount: 18)

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
        training.sessionContext = .freePractice
        training.averageHeartRate = 88
        training.maxHeartRate = 102
        training.minHeartRate = 75
        training.averageStanceStability = 72
        training.averageTremorLevel = 22
        training.averageHoldSteadiness = 70
        training.averageHoldDuration = 3.5
        training.shotTimingConsistencyCV = 15.2
        training.firstHalfSteadiness = 75
        training.secondHalfSteadiness = 65
        training.steadinessDegradation = 13.3
        training.stabilityScore = 72
        training.rhythmScore = 76
        training.symmetryScore = 70
        training.economyScore = 74
        training.composureScore = 68
        training.overallBiomechanicalScore = 73
        training.averageBreathingRate = 15
        training.averageSpO2 = 98
        training.postureStability = 72
        training.endFatigueScore = 15
        training.trainingLoadScore = 32
        training.notes = "Focus on breathing today. Turns out holding your breath for 30 seconds is NOT the technique. Who knew?" +
            " Dry fire stability improved - I can now remain motionless for almost 4 seconds."
        context.insert(training)
        generateShootingHeartRateSamples(for: training, restingHR: 75, peakHR: 102, sampleCount: 20)

        let scores = [[8, 8, 6, 10, 8], [10, 8, 8, 6, 8], [8, 10, 10, 8, 8], [10, 8, 8, 10, 6]]
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
        dryFire.sessionContext = .freePractice
        dryFire.averageHeartRate = 82
        dryFire.maxHeartRate = 95
        dryFire.minHeartRate = 72
        dryFire.averageStanceStability = 82
        dryFire.averageTremorLevel = 14
        dryFire.averageHoldSteadiness = 84
        dryFire.averageHoldDuration = 4.2
        dryFire.shotTimingConsistencyCV = 8.5
        dryFire.firstHalfSteadiness = 85
        dryFire.secondHalfSteadiness = 80
        dryFire.steadinessDegradation = 5.9
        dryFire.stabilityScore = 84
        dryFire.rhythmScore = 88
        dryFire.symmetryScore = 82
        dryFire.economyScore = 86
        dryFire.composureScore = 90
        dryFire.overallBiomechanicalScore = 85
        dryFire.averageBreathingRate = 14
        dryFire.averageSpO2 = 99
        dryFire.postureStability = 84
        dryFire.endFatigueScore = 8
        dryFire.trainingLoadScore = 18
        dryFire.notes = "Dry fire stability practice. Hold time improving - managed 4.2 seconds without wobble!" +
            " The Watch says my stance is 'stable'. In my imagination, all shots were 10s. Reality may differ when we add actual ammunition."
        context.insert(dryFire)
        generateShootingHeartRateSamples(for: dryFire, restingHR: 72, peakHR: 95, sampleCount: 15)

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
        match.sessionContext = .competitionTraining
        match.averageHeartRate = 96
        match.maxHeartRate = 115
        match.minHeartRate = 80
        match.averageStanceStability = 74
        match.averageTremorLevel = 20
        match.averageHoldSteadiness = 72
        match.averageHoldDuration = 3.6
        match.shotTimingConsistencyCV = 14.0
        match.firstHalfSteadiness = 76
        match.secondHalfSteadiness = 68
        match.steadinessDegradation = 10.5
        match.stabilityScore = 74
        match.rhythmScore = 78
        match.symmetryScore = 72
        match.economyScore = 76
        match.composureScore = 65
        match.overallBiomechanicalScore = 75
        match.averageBreathingRate = 17
        match.averageSpO2 = 98
        match.postureStability = 74
        match.endFatigueScore = 18
        match.trainingLoadScore = 38
        match.notes = "Full competition simulation with time pressure! End 1 was shaky (nerves). End 2 was better (settled)." +
            " End 3 was peak performance. End 4 was... character building. Total: 168 points. Improvement noted!"
        context.insert(match)
        generateShootingHeartRateSamples(for: match, restingHR: 80, peakHR: 115, sampleCount: 20)

        let matchScores = [[6, 8, 8, 10, 8], [10, 10, 8, 8, 10], [10, 10, 10, 8, 10], [8, 6, 8, 10, 8]]
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
        precision.sessionContext = .freePractice
        precision.averageHeartRate = 85
        precision.maxHeartRate = 98
        precision.minHeartRate = 74
        precision.averageStanceStability = 80
        precision.averageTremorLevel = 15
        precision.averageHoldSteadiness = 82
        precision.averageHoldDuration = 4.0
        precision.shotTimingConsistencyCV = 10.2
        precision.firstHalfSteadiness = 84
        precision.secondHalfSteadiness = 78
        precision.steadinessDegradation = 7.1
        precision.stabilityScore = 82
        precision.rhythmScore = 85
        precision.symmetryScore = 80
        precision.economyScore = 84
        precision.composureScore = 82
        precision.overallBiomechanicalScore = 83
        precision.averageBreathingRate = 14
        precision.averageSpO2 = 99
        precision.postureStability = 82
        precision.endFatigueScore = 10
        precision.trainingLoadScore = 22
        precision.notes = "Focus on the inner rings only. Aiming for the 10 exclusively. Results: mixed." +
            " Turns out 'aim better' isn't quite enough instruction. Sight picture was good though. Release needs work. Always needs work."
        context.insert(precision)
        generateShootingHeartRateSamples(for: precision, restingHR: 74, peakHR: 98, sampleCount: 18)

        let precisionScores = [[8, 10, 10, 10, 8], [10, 8, 10, 10, 10], [10, 10, 8, 10, 10]]
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
        pressure.sessionContext = .competitionTraining
        pressure.averageHeartRate = 100
        pressure.maxHeartRate = 120
        pressure.minHeartRate = 82
        pressure.averageStanceStability = 68
        pressure.averageTremorLevel = 25
        pressure.averageHoldSteadiness = 65
        pressure.averageHoldDuration = 3.2
        pressure.shotTimingConsistencyCV = 18.5
        pressure.firstHalfSteadiness = 70
        pressure.secondHalfSteadiness = 60
        pressure.steadinessDegradation = 14.3
        pressure.stabilityScore = 68
        pressure.rhythmScore = 72
        pressure.symmetryScore = 66
        pressure.economyScore = 70
        pressure.composureScore = 58
        pressure.overallBiomechanicalScore = 69
        pressure.averageBreathingRate = 18
        pressure.averageSpO2 = 97
        pressure.postureStability = 68
        pressure.endFatigueScore = 20
        pressure.trainingLoadScore = 35
        pressure.notes = "Shot with dad watching. Discovered that being observed adds approximately 47% more wobble." +
            " Shot 3 of end 1 shall not be discussed. Managed to recover. Mental game: work in progress."
        context.insert(pressure)
        generateShootingHeartRateSamples(for: pressure, restingHR: 82, peakHR: 120, sampleCount: 15)

        let pressureScores = [[10, 8, 4, 8, 10], [8, 10, 10, 10, 8]]  // Note the 4 - "shall not be discussed"
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
            // Per-shot sensor data
            let baseStability = Double(score) * 8.0 + Double.random(in: -5...5)
            shot.holdSteadiness = min(100, max(20, baseStability))
            shot.holdDuration = 3.0 + Double.random(in: 0...2.0)
            shot.raiseSmoothness = 60 + Double.random(in: 0...30)
            shot.settleDuration = 1.5 + Double.random(in: 0...1.5)
            shot.tremorIntensity = max(5, 50 - baseStability * 0.4 + Double.random(in: -5...5))
            shot.driftMagnitude = max(5, 40 - Double(score) * 3.0 + Double.random(in: -3...3))
            shot.totalCycleTime = 6.0 + Double.random(in: 0...4.0)
            shot.heartRateAtShot = 80 + Int.random(in: 0...25)
            shot.holdPitchVariance = Double.random(in: 0.01...0.08)
            shot.holdYawVariance = Double.random(in: 0.01...0.08)
            // Position on target (normalized from center)
            let distFromCenter = max(0, 1.0 - Double(score) / 10.0)
            let angle = Double.random(in: 0...(2 * .pi))
            shot.positionX = distFromCenter * cos(angle) * 0.5
            shot.positionY = distFromCenter * sin(angle) * 0.5
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
                (maxRadius, UIColor(white: 0.85, alpha: 1), UIColor(white: 0.6, alpha: 1)),   // 2 - outer
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
        coreStability.notes = "Good session! Discovered my core is stronger than my willpower to continue." +
            " The phone kept telling me to 'stay stable' - easier said than done when you're shaking like a leaf."
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
        twoPoint.notes = "Two-point position practice. My thighs are filing a formal complaint." +
            " The endurance score declined sharply after 30 seconds - I prefer to think of it as 'strategic energy conservation'."
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
        breathingRhythm.notes = "Bilateral breathing practice - 3 strokes right, 3 strokes left." +
            " No longer drowning on the left side! Symmetry is improving. The pool was cold but the session was worth it."
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

        // Today's competition — full schedule for Competition Day + CarPlay screenshots
        let today = Competition(
            name: "Pony Club Area Tetrathlon",
            date: Date(),
            location: "Stonar School, Wiltshire",
            competitionType: .tetrathlon,
            level: .junior
        )
        today.horse = horse
        today.isEntered = true
        today.venue = "Stonar School"
        today.venueLatitude = 51.3475
        today.venueLongitude = -2.2456
        today.travelRouteNotes = "Avoid low bridge on B3105 at Bradford-on-Avon. Take A363 instead."
        today.estimatedTravelMinutes = 45
        today.arriveAtYard = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: Date())
        today.departureFromYard = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
        today.estimatedArrivalAtVenue = calendar.date(bySettingHour: 7, minute: 45, second: 0, of: Date())
        today.courseWalkTime = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: Date())
        today.shootingStartTime = calendar.date(bySettingHour: 9, minute: 15, second: 0, of: Date())
        today.shootingLane = 3
        today.swimWarmupTime = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: Date())
        today.swimStartTime = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: Date())
        today.swimmingLane = 4
        today.runningStartTime = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: Date())
        today.runningCompetitorNumber = 42
        today.prizeGivingTime = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: Date())
        context.insert(today)

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
        upcoming1.venueLatitude = 51.5419
        upcoming1.venueLongitude = -2.2872
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
        upcoming2.venueLatitude = 52.6214
        upcoming2.venueLongitude = -0.4133
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
        completed.resultNotes = "THIRD PLACE! 🥉 Shooting PB! Swimming went surprisingly well given my fear of tumble turns." +
            " Run was powered by pure determination and the sight of the finish line cake stall." +
            " Biscuit Thief was perfect - only tried to eat one jump."
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

            let point = GPSPoint(
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

    // MARK: - Running/Walking Route Generation

    private static func generateRunningRoute(
        for session: RunningSession,
        startLat: Double,
        startLon: Double,
        in context: ModelContext
    ) {
        let pointCount = 80
        let duration = session.totalDuration
        var lat = startLat
        var lon = startLon

        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let timestamp = session.startDate.addingTimeInterval(duration * progress)

            // Out-and-back pattern
            if progress < 0.5 {
                lat += Double.random(in: 0.0001...0.0003)
                lon += Double.random(in: -0.0001...0.0002)
            } else {
                lat -= Double.random(in: 0.0001...0.0003)
                lon -= Double.random(in: -0.0001...0.0002)
            }

            let speed = session.totalDistance / session.totalDuration
            let point = GPSPoint(
                latitude: lat, longitude: lon,
                altitude: 50 + Double.random(in: -5...5),
                timestamp: timestamp,
                horizontalAccuracy: Double.random(in: 3...8),
                speed: speed + Double.random(in: -0.5...0.5)
            )
            point.runningSession = session
            context.insert(point)
        }
    }

    private static func generateWalkingRoute(
        for session: RunningSession,
        startLat: Double,
        startLon: Double,
        in context: ModelContext
    ) {
        let pointCount = 50
        let duration = session.totalDuration
        var lat = startLat
        var lon = startLon

        for i in 0..<pointCount {
            let progress = Double(i) / Double(pointCount)
            let timestamp = session.startDate.addingTimeInterval(duration * progress)

            // Gentle loop pattern
            let angle = progress * 2 * .pi
            lat += 0.00015 * cos(angle) + Double.random(in: -0.00005...0.00005)
            lon += 0.00015 * sin(angle) + Double.random(in: -0.00005...0.00005)

            let speed = session.totalDistance / session.totalDuration
            let point = GPSPoint(
                latitude: lat, longitude: lon,
                altitude: 45 + Double.random(in: -3...3),
                timestamp: timestamp,
                horizontalAccuracy: Double.random(in: 3...8),
                speed: speed + Double.random(in: -0.3...0.3)
            )
            point.runningSession = session
            context.insert(point)
        }
    }

    // MARK: - Heart Rate Sample Helpers

    private static func generateRunningHeartRateSamples(
        for session: RunningSession,
        warmupHR: Double,
        peakHR: Double,
        sampleCount: Int = 25
    ) {
        let maxHR = Int(peakHR)
        let samples: [HeartRateSample] = (0..<sampleCount).map { i in
            let progress = Double(i) / Double(sampleCount)
            let timestamp = session.startDate.addingTimeInterval(session.totalDuration * progress)
            let hr = Int(warmupHR + (peakHR - warmupHR) * sin(progress * .pi))
            return HeartRateSample(timestamp: timestamp, bpm: hr, maxHeartRate: maxHR)
        }
        session.heartRateSamplesData = try? JSONEncoder().encode(samples)
    }

    private static func generateSwimmingHeartRateSamples(
        for session: SwimmingSession,
        warmupHR: Double,
        peakHR: Double,
        sampleCount: Int = 20
    ) {
        let maxHR = Int(peakHR)
        let samples: [HeartRateSample] = (0..<sampleCount).map { i in
            let progress = Double(i) / Double(sampleCount)
            let timestamp = session.startDate.addingTimeInterval(session.totalDuration * progress)
            let hr = Int(warmupHR + (peakHR - warmupHR) * sin(progress * .pi))
            return HeartRateSample(timestamp: timestamp, bpm: hr, maxHeartRate: maxHR)
        }
        session.heartRateSamplesData = try? JSONEncoder().encode(samples)
    }

    private static func generateShootingHeartRateSamples(
        for session: ShootingSession,
        restingHR: Double,
        peakHR: Double,
        sampleCount: Int = 20
    ) {
        let duration = session.endDate?.timeIntervalSince(session.startDate) ?? 900
        let maxHR = Int(peakHR)
        let samples: [HeartRateSample] = (0..<sampleCount).map { i in
            let progress = Double(i) / Double(sampleCount)
            let timestamp = session.startDate.addingTimeInterval(duration * progress)
            // Shooting HR is mostly steady with slight rises during ends
            let hr = Int(restingHR + (peakHR - restingHR) * 0.3 * (1.0 + sin(progress * .pi * 4)))
            return HeartRateSample(timestamp: timestamp, bpm: min(hr, maxHR), maxHeartRate: maxHR)
        }
        session.heartRateSamplesData = try? JSONEncoder().encode(samples)
    }

    // MARK: - Running Splits Helper

    private static func generateRunningSplits(
        for session: RunningSession,
        in context: ModelContext
    ) {
        let distanceKm = session.totalDistance / 1000.0
        let fullSplits = Int(distanceKm)
        let avgPace = session.totalDuration / distanceKm // seconds per km

        for i in 0..<fullSplits {
            let split = RunningSplit(orderIndex: i, distance: 1000)
            // Vary pace realistically: start slower, middle faster, end slower
            let progress = Double(i) / Double(max(fullSplits - 1, 1))
            let variation = sin(progress * .pi) * 0.05 // up to 5% faster in middle
            let splitPace = avgPace * (1.0 - variation) + Double.random(in: -5...5)
            split.duration = splitPace
            split.cadence = session.averageCadence + Int.random(in: -5...5)
            split.heartRate = session.averageHeartRate + Int.random(in: -8...8)
            split.elevation = Double.random(in: -5...10)
            split.session = session
            context.insert(split)
        }

        // Partial last split if there's remaining distance
        let remainingMeters = session.totalDistance - Double(fullSplits) * 1000.0
        if remainingMeters > 50 {
            let split = RunningSplit(orderIndex: fullSplits, distance: remainingMeters)
            split.duration = avgPace * (remainingMeters / 1000.0)
            split.cadence = session.averageCadence + Int.random(in: -3...3)
            split.heartRate = session.averageHeartRate + Int.random(in: -5...5)
            split.elevation = Double.random(in: -3...5)
            split.session = session
            context.insert(split)
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
