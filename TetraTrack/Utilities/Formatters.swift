//
//  Formatters.swift
//  TetraTrack
//
//  Unified formatting utilities for duration, distance, pace, and speed
//

import Foundation

// MARK: - Duration Formatting

extension TimeInterval {
    /// Format as "HH:MM:SS" or "MM:SS" for display
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Format as "M:SS.t" with tenths for lap times
    var formattedLapTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let tenths = Int((self.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    /// Format as pace "M:SS/km" for running/swimming
    var formattedPace: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d/km", minutes, seconds)
    }

    /// Format as pace "M:SS/100m" for swimming
    var formattedSwimPace: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d/100m", minutes, seconds)
    }

    /// Format for speech output (audio coach)
    var spokenDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "") \(minutes) minute\(minutes != 1 ? "s" : "")"
        } else if minutes > 0 {
            return "\(minutes) minute\(minutes != 1 ? "s" : "") \(seconds) second\(seconds != 1 ? "s" : "")"
        } else {
            return "\(seconds) second\(seconds != 1 ? "s" : "")"
        }
    }

    /// Format pace for speech output
    var spokenPace: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60

        if seconds == 0 {
            return "\(minutes) minutes per kilometer"
        } else if seconds < 10 {
            return "\(minutes) oh \(seconds) per kilometer"
        } else {
            return "\(minutes) \(seconds) per kilometer"
        }
    }

    /// Format lap time for speech output
    var spokenLapTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let tenths = Int((self.truncatingRemainder(dividingBy: 1)) * 10)

        if minutes > 0 {
            if seconds == 0 {
                return "\(minutes) minute\(minutes != 1 ? "s" : "")"
            }
            return "\(minutes) minute\(minutes != 1 ? "s" : "") \(seconds) second\(seconds != 1 ? "s" : "")"
        } else {
            return "\(seconds) point \(tenths) seconds"
        }
    }
}

// MARK: - Distance Formatting

extension Double {
    /// Format meters as "X.XX km" or "X m" for display
    var formattedDistance: String {
        if self >= 1000 {
            return String(format: "%.2f km", self / 1000)
        }
        return String(format: "%.0f m", self)
    }

    /// Format meters as short distance "X.X km" or "X m"
    var formattedDistanceShort: String {
        if self >= 1000 {
            return String(format: "%.1f km", self / 1000)
        }
        return String(format: "%.0f m", self)
    }

    /// Format for speech output
    var spokenDistance: String {
        if self >= 1000 {
            let km = self / 1000
            if km == floor(km) {
                return "\(Int(km)) kilometer\(km != 1 ? "s" : "")"
            }
            return String(format: "%.1f kilometers", km)
        }
        return "\(Int(self)) meters"
    }

    /// Format m/s as "X.X km/h" for speed display
    var formattedSpeed: String {
        let kmh = self * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    /// Format elevation in meters
    var formattedElevation: String {
        if abs(self) >= 1000 {
            return String(format: "%.2f km", self / 1000)
        }
        return String(format: "%.0f m", self)
    }
}

// MARK: - Integer Distance Formatting

extension Int {
    /// Format meters as distance
    var formattedDistance: String {
        Double(self).formattedDistance
    }
}

// MARK: - Formatting Utilities

enum Formatters {
    // MARK: - Duration

    /// Format seconds as duration string
    static func duration(_ seconds: TimeInterval) -> String {
        seconds.formattedDuration
    }

    /// Format seconds as lap time with tenths
    static func lapTime(_ seconds: TimeInterval) -> String {
        seconds.formattedLapTime
    }

    // MARK: - Distance

    /// Format meters as distance string
    static func distance(_ meters: Double) -> String {
        meters.formattedDistance
    }

    /// Format meters as short distance string
    static func distanceShort(_ meters: Double) -> String {
        meters.formattedDistanceShort
    }

    // MARK: - Pace

    /// Format seconds per km as pace string
    static func pace(_ secondsPerKm: TimeInterval) -> String {
        secondsPerKm.formattedPace
    }

    /// Format seconds per 100m as swim pace string
    static func swimPace(_ secondsPer100m: TimeInterval) -> String {
        secondsPer100m.formattedSwimPace
    }

    /// Calculate and format pace from distance and duration
    static func pace(distance meters: Double, duration seconds: TimeInterval) -> String {
        guard meters > 0 else { return "--:--/km" }
        let pacePerKm = seconds / (meters / 1000)
        return pacePerKm.formattedPace
    }

    // MARK: - Speed

    /// Format m/s as speed string
    static func speed(_ metersPerSecond: Double) -> String {
        metersPerSecond.formattedSpeed
    }

    /// Calculate and format speed from distance and duration
    static func speed(distance meters: Double, duration seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0.0 km/h" }
        let mps = meters / seconds
        return mps.formattedSpeed
    }

    // MARK: - Speech (Audio Coach)

    /// Format duration for speech
    static func spokenDuration(_ seconds: TimeInterval) -> String {
        seconds.spokenDuration
    }

    /// Format distance for speech
    static func spokenDistance(_ meters: Double) -> String {
        meters.spokenDistance
    }

    /// Format pace for speech
    static func spokenPace(_ secondsPerKm: TimeInterval) -> String {
        secondsPerKm.spokenPace
    }

    /// Format lap time for speech
    static func spokenLapTime(_ seconds: TimeInterval) -> String {
        seconds.spokenLapTime
    }

    // MARK: - Date/Time Cached Formatters

    /// Cached date formatter for medium date style
    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Cached date/time formatter for medium date + short time
    private static let mediumDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Cached relative date formatter
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// Cached formatter for "MMM d" (e.g., "Jan 15") - used for week labels
    private static let shortMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Cached formatter for "MMM yyyy" (e.g., "Jan 2026") - used for month labels
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    /// Cached formatter for "EEEE d MMMM" (e.g., "Monday 15 January") - used for ride names
    private static let fullDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    /// Cached ISO8601 formatter for GPX/data export (nonisolated for actor compatibility)
    nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Cached formatter for "yyyy-MM-dd" (file names)
    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Cached formatter for "yyyy-MM-dd_HHmm" (file names with time)
    private static let fileNameDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter
    }()

    /// Format date as medium style
    static func date(_ date: Date) -> String {
        mediumDateFormatter.string(from: date)
    }

    /// Format date with time
    static func dateTime(_ date: Date) -> String {
        mediumDateTimeFormatter.string(from: date)
    }

    /// Format as relative date (Today, Yesterday, etc.)
    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format as "MMM d" (e.g., "Jan 15") for week labels
    static func shortMonthDay(_ date: Date) -> String {
        shortMonthDayFormatter.string(from: date)
    }

    /// Format as "MMM yyyy" (e.g., "Jan 2026") for month labels
    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    /// Format as "EEEE d MMMM" (e.g., "Monday 15 January") for full day display
    static func fullDayMonth(_ date: Date) -> String {
        fullDayMonthFormatter.string(from: date)
    }

    /// Format date for file names (yyyy-MM-dd)
    nonisolated static func fileNameDate(_ date: Date) -> String {
        fileNameDateFormatter.string(from: date)
    }

    /// Format date+time for file names (yyyy-MM-dd_HHmm)
    nonisolated static func fileNameDateTime(_ date: Date) -> String {
        fileNameDateTimeFormatter.string(from: date)
    }

    /// Format as ISO8601 for data export
    nonisolated static func iso8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }
}
