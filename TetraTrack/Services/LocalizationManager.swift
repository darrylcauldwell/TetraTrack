//
//  LocalizationManager.swift
//  TetraTrack
//
//  Manages app-wide localization with system language detection
//  and manual override support for English, German, and French.
//

import Foundation
import SwiftUI

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case german = "de"
    case french = "fr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "System Default", table: "Settings")
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        }
    }

    /// The actual language code to use (resolves system to actual language)
    var resolvedLanguageCode: String {
        switch self {
        case .system:
            // Get system preferred language, default to English
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("de") { return "de" }
            if preferred.hasPrefix("fr") { return "fr" }
            return "en"
        case .english: return "en"
        case .german: return "de"
        case .french: return "fr"
        }
    }
}

// MARK: - Localization Manager

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    private let languageKey = "appLanguage"

    /// Currently selected language setting
    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
            updateBundle()
        }
    }

    /// The bundle to use for localized strings
    private(set) var bundle: Bundle = .main

    private init() {
        // Load saved language preference or default to system
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: saved) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
        updateBundle()
    }

    /// Update the bundle based on selected language
    private func updateBundle() {
        let languageCode = selectedLanguage.resolvedLanguageCode

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            // Fallback to main bundle (English)
            self.bundle = .main
        }
    }

    /// Get localized string for a key
    func localized(_ key: String, table: String? = nil) -> String {
        bundle.localizedString(forKey: key, value: nil, table: table)
    }

    /// Get localized string with format arguments
    func localizedWithArgs(_ key: String, table: String? = nil, _ arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: table)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - String Extension for Easy Localization

extension String {
    /// Localize this string using the app's selected language
    var localized: String {
        LocalizationManager.shared.localized(self)
    }

    /// Localize this string from a specific table
    func localized(table: String) -> String {
        LocalizationManager.shared.localized(self, table: table)
    }
}
