//
//  WatchAppColors.swift
//  TrackRide Watch App
//
//  Centralized color system for watchOS
//  Mirrors AppColors from iOS app for consistency
//

import SwiftUI

/// Provides colors that match the iOS app's design system
/// watchOS always uses dark mode, so we use the dark variants
struct WatchAppColors {

    // MARK: - Primary Blue Theme Colors

    /// Main brand blue - used for primary actions and key UI elements
    static let primary = Color(red: 0.35, green: 0.6, blue: 1.0)

    /// Lighter blue for secondary elements
    static let secondary = Color(red: 0.5, green: 0.7, blue: 1.0)

    /// Accent blue - brighter for highlights
    static let accent = Color(red: 0.3, green: 0.7, blue: 1.0)

    /// Deep blue for contrast elements
    static let deep = Color(red: 0.25, green: 0.5, blue: 0.85)

    /// Light blue for backgrounds and fills
    static let light = Color(red: 0.15, green: 0.25, blue: 0.4)

    // MARK: - Surface Colors

    /// Card background - subtle blue tint
    static let cardBackground = Color(red: 0.12, green: 0.14, blue: 0.18)

    /// Elevated surface - lighter blue tint
    static let elevatedSurface = Color(red: 0.16, green: 0.18, blue: 0.22)

    // MARK: - Status Colors

    /// Active/Success - green
    static let active = Color(red: 0.35, green: 0.85, blue: 0.5)

    /// Inactive - blue-gray
    static let inactive = Color(red: 0.45, green: 0.5, blue: 0.6)

    /// Warning - amber
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.35)

    /// Error - red
    static let error = Color(red: 1.0, green: 0.4, blue: 0.4)

    static let success = active

    // MARK: - Discipline Colors

    /// Riding discipline - green
    static let riding = Color(red: 0.35, green: 0.85, blue: 0.5)

    /// Running discipline - orange
    static let running = Color(red: 1.0, green: 0.65, blue: 0.35)

    /// Swimming discipline - cyan
    static let swimming = Color(red: 0.3, green: 0.85, blue: 0.95)

    /// Shooting discipline - red/maroon
    static let shooting = Color(red: 0.9, green: 0.35, blue: 0.4)

    // MARK: - Drill Colors

    /// Balance drill - purple
    static let drillBalance = Color(red: 0.65, green: 0.5, blue: 0.95)

    /// Breathing drill - blue
    static let drillBreathing = Color(red: 0.3, green: 0.85, blue: 0.95)

    /// Reaction drill - orange
    static let drillReaction = Color(red: 1.0, green: 0.65, blue: 0.35)

    // MARK: - Action Colors

    /// Start button - blue themed
    static let startButton = primary

    /// Stop button - red
    static let stopButton = error
}

// MARK: - Design Tokens for Watch

enum WatchDesignTokens {
    enum TapTarget {
        /// Minimum tap target for watchOS (38pt per HIG)
        static let minimum: CGFloat = 38
        /// Comfortable tap target for watchOS (44pt)
        static let comfortable: CGFloat = 44
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}
