//
//  AppColors.swift
//  TrackRide
//
//  Centralized color system with full dark/light mode support
//  Primary theme: Blue shades
//

import SwiftUI
import UIKit

// MARK: - Adaptive Color Provider

/// Provides colors that adapt to light/dark mode
/// Primary theme uses blue shades throughout
struct AppColors {

    // MARK: - Primary Blue Theme Colors

    /// Main brand blue - used for primary actions and key UI elements
    static var primary: Color {
        Color(light: .init(red: 0.15, green: 0.45, blue: 0.85),
              dark: .init(red: 0.35, green: 0.6, blue: 1.0))
    }

    /// Lighter blue for secondary elements
    static var secondary: Color {
        Color(light: .init(red: 0.4, green: 0.65, blue: 0.95),
              dark: .init(red: 0.5, green: 0.7, blue: 1.0))
    }

    /// Accent blue - brighter for highlights
    static var accent: Color {
        Color(light: .init(red: 0.0, green: 0.5, blue: 1.0),
              dark: .init(red: 0.3, green: 0.7, blue: 1.0))
    }

    /// Deep blue for contrast elements
    static var deep: Color {
        Color(light: .init(red: 0.1, green: 0.3, blue: 0.6),
              dark: .init(red: 0.25, green: 0.5, blue: 0.85))
    }

    /// Light blue for backgrounds and fills
    static var light: Color {
        Color(light: .init(red: 0.85, green: 0.92, blue: 1.0),
              dark: .init(red: 0.15, green: 0.25, blue: 0.4))
    }

    // MARK: - Gait Colors (blue-themed palette)

    static func gait(_ gaitType: GaitType) -> Color {
        switch gaitType {
        case .stationary: return stationary
        case .walk: return walk
        case .trot: return trot
        case .canter: return canter
        case .gallop: return gallop
        }
    }

    /// Stationary - muted blue-gray
    static var stationary: Color {
        Color(light: .init(red: 0.5, green: 0.55, blue: 0.65),
              dark: .init(red: 0.45, green: 0.5, blue: 0.6))
    }

    /// Walk - soft teal-blue
    static var walk: Color {
        Color(light: .init(red: 0.2, green: 0.65, blue: 0.7),
              dark: .init(red: 0.35, green: 0.8, blue: 0.85))
    }

    /// Trot - vibrant blue (matches primary theme)
    static var trot: Color {
        Color(light: .init(red: 0.2, green: 0.5, blue: 0.9),
              dark: .init(red: 0.4, green: 0.65, blue: 1.0))
    }

    /// Canter - blue-violet
    static var canter: Color {
        Color(light: .init(red: 0.45, green: 0.35, blue: 0.85),
              dark: .init(red: 0.6, green: 0.5, blue: 1.0))
    }

    /// Gallop - deep indigo-blue
    static var gallop: Color {
        Color(light: .init(red: 0.3, green: 0.2, blue: 0.7),
              dark: .init(red: 0.5, green: 0.4, blue: 0.9))
    }

    // MARK: - Turn Colors (blue theme)

    /// Left turn - sky blue
    static var turnLeft: Color {
        Color(light: .init(red: 0.2, green: 0.6, blue: 0.95),
              dark: .init(red: 0.4, green: 0.75, blue: 1.0))
    }

    /// Right turn - periwinkle
    static var turnRight: Color {
        Color(light: .init(red: 0.5, green: 0.5, blue: 0.9),
              dark: .init(red: 0.65, green: 0.65, blue: 1.0))
    }

    // MARK: - Status Colors

    /// Active/Success - keep green for universal recognition
    static var active: Color {
        Color(light: .init(red: 0.2, green: 0.7, blue: 0.4),
              dark: .init(red: 0.35, green: 0.85, blue: 0.5))
    }

    /// Inactive - blue-gray
    static var inactive: Color {
        Color(light: .init(red: 0.5, green: 0.55, blue: 0.65),
              dark: .init(red: 0.45, green: 0.5, blue: 0.6))
    }

    /// Warning - amber (keep for recognition)
    static var warning: Color {
        Color(light: .init(red: 0.95, green: 0.65, blue: 0.15),
              dark: .init(red: 1.0, green: 0.75, blue: 0.35))
    }

    /// Error - keep red for recognition
    static var error: Color {
        Color(light: .init(red: 0.9, green: 0.25, blue: 0.25),
              dark: .init(red: 1.0, green: 0.4, blue: 0.4))
    }

    static var success: Color { active }

    // MARK: - Surface Colors

    /// Card background - subtle blue tint
    static var cardBackground: Color {
        Color(light: .init(red: 0.94, green: 0.96, blue: 0.99),
              dark: .init(red: 0.12, green: 0.14, blue: 0.18))
    }

    /// Elevated surface - lighter blue tint
    static var elevatedSurface: Color {
        Color(light: .init(red: 0.97, green: 0.98, blue: 1.0),
              dark: .init(red: 0.16, green: 0.18, blue: 0.22))
    }

    // MARK: - Action Colors

    static var destructive: Color { error }

    // MARK: - Overview Card Colors (blue palette)

    static var cardBlue: Color { trot }
    static var cardGreen: Color { walk }
    static var cardOrange: Color { canter }
    static var cardRed: Color { gallop }
    static var cardPurple: Color {
        Color(light: .init(red: 0.5, green: 0.35, blue: 0.8),
              dark: .init(red: 0.65, green: 0.5, blue: 0.95))
    }
    static var cardTeal: Color {
        Color(light: .init(red: 0.15, green: 0.6, blue: 0.7),
              dark: .init(red: 0.3, green: 0.75, blue: 0.85))
    }

    // MARK: - Chart Colors

    static var chartLine: Color { primary }
    static var chartFill: Color { light }
    static var chartBar: Color { trot }

    // MARK: - Start/Stop Button Colors

    /// Start button - blue themed
    static var startButton: Color { primary }

    /// Stop button - keep red for safety recognition
    static var stopButton: Color { error }
}

// MARK: - Color Extension for Light/Dark

extension Color {
    /// Creates a color that adapts to light and dark mode
    init(light: Color.Resolved, dark: Color.Resolved) {
        self.init(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(
                    red: CGFloat(dark.red),
                    green: CGFloat(dark.green),
                    blue: CGFloat(dark.blue),
                    alpha: CGFloat(dark.opacity)
                )
            } else {
                return UIColor(
                    red: CGFloat(light.red),
                    green: CGFloat(light.green),
                    blue: CGFloat(light.blue),
                    alpha: CGFloat(light.opacity)
                )
            }
        })
    }
}

// MARK: - ShapeStyle Extension

extension ShapeStyle where Self == Color {
    static var gaitStationary: Color { AppColors.stationary }
    static var gaitWalk: Color { AppColors.walk }
    static var gaitTrot: Color { AppColors.trot }
    static var gaitCanter: Color { AppColors.canter }
    static var gaitGallop: Color { AppColors.gallop }

    static var appCardBackground: Color { AppColors.cardBackground }
}
