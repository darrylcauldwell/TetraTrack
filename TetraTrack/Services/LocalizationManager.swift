//
//  LocalizationManager.swift
//  TetraTrack
//
//  Manages app-wide localization with system language detection
//  and manual override support for English, German, French,
//  Dutch, and Swedish.
//
//  Uses Bundle.main class override so SwiftUI's Text("key") picks up
//  the selected language automatically — no per-view changes needed.
//

import Foundation
import SwiftUI

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case german = "de"
    case french = "fr"
    case dutch = "nl"
    case swedish = "sv"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System Default"
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .dutch: return "Nederlands"
        case .swedish: return "Svenska"
        }
    }

    var flag: String {
        switch self {
        case .system: return "🌐"
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .dutch: return "🇳🇱"
        case .swedish: return "🇸🇪"
        }
    }

    /// The actual language code to use (resolves system to actual language)
    var resolvedLanguageCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            let supported = ["de", "fr", "nl", "sv"]
            for code in supported {
                if preferred.hasPrefix(code) { return code }
            }
            return "en"
        case .english: return "en"
        case .german: return "de"
        case .french: return "fr"
        case .dutch: return "nl"
        case .swedish: return "sv"
        }
    }
}

// MARK: - Bundle Override

/// Subclass that routes localizedString lookups through the
/// language bundle selected by LocalizationManager.
/// Installed once via `object_setClass(Bundle.main, ...)`.
nonisolated private class OverriddenBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        MainActor.assumeIsolated {
            let selected = LocalizationManager.shared.bundle
            // Avoid infinite recursion when selected IS Bundle.main
            guard selected !== Bundle.main else {
                return super.localizedString(forKey: key, value: value, table: tableName)
            }
            return selected.localizedString(forKey: key, value: value, table: tableName)
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

    /// The locale matching the selected language (for SwiftUI .environment)
    private(set) var locale: Locale = .current

    /// The lproj bundle for the selected language
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

        // Swizzle Bundle.main so all localizedString calls route through us.
        // This makes SwiftUI Text("key") work without per-view changes.
        object_setClass(Bundle.main, OverriddenBundle.self)
    }

    /// Update the bundle and locale based on selected language
    private func updateBundle() {
        let languageCode = selectedLanguage.resolvedLanguageCode

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let lprojBundle = Bundle(path: path) {
            self.bundle = lprojBundle
        } else {
            // Fallback to main bundle (English)
            self.bundle = .main
        }

        locale = Locale(identifier: languageCode)
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
