//
//  ScreenshotScreen.swift
//  TetraTrack
//
//  Defines all capturable screens for simctl-based App Store screenshots.
//  Launch arguments: --screenshot-mode --screenshot-screen <name>
//

import Foundation

enum ScreenshotScreen: String, CaseIterable {
    // Both iPhone & iPad
    case home
    case rideDetail = "ride-detail"
    case competitions
    case sessionInsights = "session-insights"
    case liveSharing = "live-sharing"

    // iPhone-only (capture views)
    case riding
    case horseProfile = "horse-profile"
    case running
    case swimming
    case shooting

    // iPad-only (review mode)
    case trainingHistory = "training-history"
    case competitionDetail = "competition-detail"
    case tasks
    case horseList = "horse-list"
    case horseDetail = "horse-detail"

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
