//
//  RideIntents.swift
//  TetraTrack
//
//  Siri Shortcuts for starting and stopping rides
//

import AppIntents
import SwiftUI

// MARK: - Start Ride Intent

struct StartRideIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Ride"
    static var description = IntentDescription("Start tracking a new ride in TetraTrack")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Ride Type")
    var rideType: RideTypeEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to start ride
        await MainActor.run {
            NotificationCenter.default.post(
                name: .startRideFromSiri,
                object: nil,
                userInfo: ["rideType": rideType?.rideType.rawValue ?? RideType.hack.rawValue]
            )
        }

        let typeName = rideType?.rideType.rawValue ?? "hacking"
        return .result(dialog: "Starting your \(typeName) ride. Have a great time!")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$rideType) ride")
    }
}

// MARK: - Stop Ride Intent

struct StopRideIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Ride"
    static var description = IntentDescription("Stop the current ride in TetraTrack")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to stop ride
        await MainActor.run {
            NotificationCenter.default.post(name: .stopRideFromSiri, object: nil)
        }

        return .result(dialog: "Stopping your ride. Great job!")
    }
}

// MARK: - Pause Ride Intent

struct PauseRideIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Ride"
    static var description = IntentDescription("Pause the current ride in TetraTrack")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to pause ride
        await MainActor.run {
            NotificationCenter.default.post(name: .pauseRideFromSiri, object: nil)
        }

        return .result(dialog: "Ride paused. Say resume my ride when you're ready to continue.")
    }
}

// MARK: - Resume Ride Intent

struct ResumeRideIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Ride"
    static var description = IntentDescription("Resume the paused ride in TetraTrack")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to resume ride
        await MainActor.run {
            NotificationCenter.default.post(name: .resumeRideFromSiri, object: nil)
        }

        return .result(dialog: "Ride resumed. Tracking is active.")
    }
}

// MARK: - Get Tracking Status Intent

struct GetTrackingStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Tracking Status"
    static var description = IntentDescription("Get the current tracking and safety status in TetraTrack")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Post notification to announce status
        await MainActor.run {
            NotificationCenter.default.post(name: .getStatusFromSiri, object: nil)
        }

        return .result(dialog: "Checking your status.")
    }
}

// MARK: - Enable Audio Coaching Intent

struct EnableAudioCoachingIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Audio Coaching"
    static var description = IntentDescription("Turn on audio coaching announcements in TetraTrack")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            NotificationCenter.default.post(name: .enableAudioFromSiri, object: nil)
        }

        return .result(dialog: "Audio coaching enabled. You'll hear announcements for distance, gait changes, and more.")
    }
}

// MARK: - Disable Audio Coaching Intent

struct DisableAudioCoachingIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Audio Coaching"
    static var description = IntentDescription("Turn off audio coaching announcements in TetraTrack")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            NotificationCenter.default.post(name: .disableAudioFromSiri, object: nil)
        }

        return .result(dialog: "Audio coaching disabled. Announcements are now muted.")
    }
}

// MARK: - Toggle Audio Coaching Intent

struct ToggleAudioCoachingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Audio Coaching"
    static var description = IntentDescription("Toggle audio coaching on or off in TetraTrack")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            NotificationCenter.default.post(name: .toggleAudioFromSiri, object: nil)
        }

        return .result(dialog: "Toggling audio coaching.")
    }
}

// MARK: - Ride Type Entity

struct RideTypeEntity: AppEntity {
    var id: String
    var rideType: RideType

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Ride Type")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: rideType.rawValue.capitalized))
    }

    static var defaultQuery = RideTypeEntityQuery()
}

struct RideTypeEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RideTypeEntity] {
        identifiers.compactMap { id in
            guard let type = RideType(rawValue: id) else { return nil }
            return RideTypeEntity(id: id, rideType: type)
        }
    }

    func suggestedEntities() async throws -> [RideTypeEntity] {
        RideType.allCases.map { RideTypeEntity(id: $0.rawValue, rideType: $0) }
    }

    func defaultResult() async -> RideTypeEntity? {
        RideTypeEntity(id: RideType.hack.rawValue, rideType: .hack)
    }
}

// MARK: - App Shortcuts Provider (Single Provider for entire app)

struct TetraTrackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Basic ride controls
        AppShortcut(
            intent: StartRideIntent(),
            phrases: [
                "Start a ride in \(.applicationName)",
                "Start my ride in \(.applicationName)",
                "Begin riding in \(.applicationName)",
                "Track my ride with \(.applicationName)"
            ],
            shortTitle: "Start Ride",
            systemImageName: "play.circle.fill"
        )

        AppShortcut(
            intent: StopRideIntent(),
            phrases: [
                "Stop my ride in \(.applicationName)",
                "End my ride in \(.applicationName)",
                "Finish riding in \(.applicationName)",
                "Stop tracking in \(.applicationName)"
            ],
            shortTitle: "Stop Ride",
            systemImageName: "stop.circle.fill"
        )

        AppShortcut(
            intent: PauseRideIntent(),
            phrases: [
                "Pause my ride in \(.applicationName)",
                "Pause tracking in \(.applicationName)",
                "Take a break in \(.applicationName)"
            ],
            shortTitle: "Pause Ride",
            systemImageName: "pause.circle.fill"
        )

        AppShortcut(
            intent: ResumeRideIntent(),
            phrases: [
                "Resume my ride in \(.applicationName)",
                "Continue my ride in \(.applicationName)",
                "Resume tracking in \(.applicationName)"
            ],
            shortTitle: "Resume Ride",
            systemImageName: "play.circle.fill"
        )

        AppShortcut(
            intent: GetTrackingStatusIntent(),
            phrases: [
                "What's my status in \(.applicationName)",
                "Check my status in \(.applicationName)",
                "Am I being tracked in \(.applicationName)",
                "Is tracking active in \(.applicationName)"
            ],
            shortTitle: "Check Status",
            systemImageName: "checkmark.shield.fill"
        )

        // Audio coaching control (toggle includes enable/disable phrases)
        AppShortcut(
            intent: ToggleAudioCoachingIntent(),
            phrases: [
                "Toggle audio in \(.applicationName)",
                "Mute announcements in \(.applicationName)",
                "Stop talking in \(.applicationName)",
                "Enable audio in \(.applicationName)"
            ],
            shortTitle: "Toggle Audio",
            systemImageName: "speaker.wave.2.fill"
        )

        // Intelligent queries
        AppShortcut(
            intent: GetLastRideSummaryIntent(),
            phrases: [
                "How was my last ride in \(.applicationName)",
                "Summarize my last ride in \(.applicationName)"
            ],
            shortTitle: "Last Ride Summary",
            systemImageName: "text.bubble"
        )

        AppShortcut(
            intent: GetTrainingStatsIntent(),
            phrases: [
                "How much have I ridden in \(.applicationName)",
                "Show my training stats in \(.applicationName)"
            ],
            shortTitle: "Training Stats",
            systemImageName: "chart.bar"
        )

        AppShortcut(
            intent: GetTrainingRecommendationIntent(),
            phrases: [
                "What should I work on in \(.applicationName)",
                "Give me training advice from \(.applicationName)"
            ],
            shortTitle: "Get Recommendation",
            systemImageName: "lightbulb"
        )

        // Combined training stats covers all disciplines
        AppShortcut(
            intent: GetCombinedTrainingStatsIntent(),
            phrases: [
                "How has my training been in \(.applicationName)",
                "Give me a training summary from \(.applicationName)"
            ],
            shortTitle: "All Training",
            systemImageName: "chart.bar"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    // Ride control
    static let startRideFromSiri = Notification.Name("startRideFromSiri")
    static let stopRideFromSiri = Notification.Name("stopRideFromSiri")
    static let pauseRideFromSiri = Notification.Name("pauseRideFromSiri")
    static let resumeRideFromSiri = Notification.Name("resumeRideFromSiri")
    static let getStatusFromSiri = Notification.Name("getStatusFromSiri")

    // Audio coaching control
    static let enableAudioFromSiri = Notification.Name("enableAudioFromSiri")
    static let disableAudioFromSiri = Notification.Name("disableAudioFromSiri")
    static let toggleAudioFromSiri = Notification.Name("toggleAudioFromSiri")
}
