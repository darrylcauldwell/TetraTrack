//
//  ScreenshotScreen.swift
//  TetraTrack
//
//  Defines all capturable screens for simctl-based App Store screenshots.
//  Launch arguments: --screenshot-mode --screenshot-screen <name>
//

import Foundation

enum ScreenshotScreen: String, CaseIterable {
    // Landing page
    case home

    // Training & Drills
    case training
    case schooling

    // Competition
    case competitions
    case competitionDay = "competition-day"

    // Session History
    case sessionHistory = "session-history"
    case sessionInsights = "session-insights"

    // Horses
    case horseProfile = "horse-profile"
    case horseList = "horse-list"

    // Live Sharing
    case liveSharing = "live-sharing"

    // Ride Detail (enriched from HealthKit)
    case rideDetail = "ride-detail"

    static var isScreenshotMode: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--screenshot-mode") || args.contains("-screenshotMode")
    }

    static func fromLaunchArguments() -> ScreenshotScreen? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot-screen"),
              index + 1 < args.count else {
            return nil
        }
        return ScreenshotScreen(rawValue: args[index + 1])
    }
}
