//
//  ScreenshotDataGenerator.swift
//  TrackRide
//
//  Generates realistic sample data for App Store screenshots
//  Uses iconic UK stately homes and equestrian venues
//

import Foundation
import SwiftData

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

        // Create varied riding sessions
        generateBadmintonHack(in: context, horse: bella, daysAgo: 0)
        generateBurghleyXC(in: context, horse: bella, daysAgo: 2)
        generateChatsworthHack(in: context, horse: archie, daysAgo: 3)
        generateBlenheimFlatwork(in: context, horse: bella, daysAgo: 5)
        generateCastleHowardTrail(in: context, horse: willow, daysAgo: 7)
        generateAlthorpSchooling(in: context, horse: archie, daysAgo: 9)
        generateArundelBeachRide(in: context, horse: bella, daysAgo: 12)
        generateHicksteadJumping(in: context, horse: bella, daysAgo: 14)

        // Create running sessions
        generateRunningSessions(in: context)

        // Create swimming sessions
        generateSwimmingSessions(in: context)

        // Create shooting sessions
        generateShootingSessions(in: context)

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
        ride.leftTurns = 18
        ride.rightTurns = 21
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
        ride.leftTurns = 24
        ride.rightTurns = 26
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
        ride.leftTurns = 32
        ride.rightTurns = 29
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
        ride.leftTurns = 48
        ride.rightTurns = 45
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
        ride.leftTurns = 15
        ride.rightTurns = 17
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
        ride.leftTurns = 52
        ride.rightTurns = 50
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
        ride.leftTurns = 12
        ride.rightTurns = 14
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
        ride.leftTurns = 28
        ride.rightTurns = 32
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
    }

    private static func addShots(to end: ShootingEnd, scores: [Int], in context: ModelContext) {
        for (i, score) in scores.enumerated() {
            let shot = Shot(orderIndex: i, score: score, isX: score == 10)
            shot.end = end
            context.insert(shot)
        }
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
