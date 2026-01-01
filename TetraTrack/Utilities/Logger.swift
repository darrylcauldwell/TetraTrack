//
//  Logger.swift
//  TetraTrack
//
//  Centralized logging using os.Logger for better performance and filtering
//

import Foundation
import os

/// Centralized logging for TetraTrack app
/// Usage: Log.services.debug("Message") or Log.health.error("Error message")
enum Log {
    /// General app logging
    static nonisolated let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "App")

    /// Services layer logging (RideTracker, etc.)
    static nonisolated let services = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Services")

    /// Ride tracking logging (start, stop, state changes)
    static nonisolated let tracking = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Tracking")

    /// HealthKit related logging
    static nonisolated let health = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Health")

    /// Location and motion logging
    static nonisolated let location = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Location")

    /// Watch connectivity logging
    static nonisolated let watch = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Watch")

    /// Notifications logging
    static nonisolated let notifications = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Notifications")

    /// Family sharing logging
    static nonisolated let family = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Family")

    /// External integrations
    static nonisolated let integrations = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Integrations")

    /// Audio coaching logging
    static nonisolated let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Audio")

    /// Widget data sync logging
    static nonisolated let widgets = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Widgets")

    /// Fall detection logging
    static nonisolated let safety = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Safety")

    /// Data export logging
    static nonisolated let export = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Export")

    /// AI/Intelligence logging
    static nonisolated let intelligence = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Intelligence")

    /// UI/View lifecycle logging
    static nonisolated let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "UI")

    /// Gait analysis diagnostic logging (DEBUG only)
    static nonisolated let gait = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "GaitDiagnostic")

    /// Shooting discipline logging
    static nonisolated let shooting = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Shooting")

    /// Storage/persistence logging
    static nonisolated let storage = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TetraTrack", category: "Storage")
}
