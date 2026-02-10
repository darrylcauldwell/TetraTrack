//
//  PhoneNumberValidator.swift
//  TetraTrack
//
//  Lightweight phone number validation for international mobile numbers.
//  Supports UK, France, Germany, Ireland, US/Canada, and generic international formats.
//

import SwiftUI

// MARK: - Validation Result

enum PhoneValidationResult {
    case empty
    case tooShort
    case tooLong
    case validMobile(country: String)
    case likelyValid
    case possiblyLandline(country: String)

    var isAcceptable: Bool {
        switch self {
        case .validMobile, .likelyValid: return true
        default: return false
        }
    }

    var icon: String {
        switch self {
        case .empty: return "phone"
        case .tooShort, .tooLong: return "exclamationmark.circle"
        case .validMobile: return "checkmark.circle.fill"
        case .likelyValid: return "checkmark.circle"
        case .possiblyLandline: return "phone.arrow.down.left"
        }
    }

    var color: Color {
        switch self {
        case .empty: return .secondary
        case .tooShort, .tooLong: return .red
        case .validMobile: return .green
        case .likelyValid: return .yellow
        case .possiblyLandline: return .orange
        }
    }

    var message: String {
        switch self {
        case .empty:
            return "Enter a phone number"
        case .tooShort:
            return "Number is too short"
        case .tooLong:
            return "Number is too long"
        case .validMobile(let country):
            return "Valid \(country) mobile number"
        case .likelyValid:
            return "Looks like a valid number"
        case .possiblyLandline(let country):
            return "This may be a \(country) landline — SMS requires a mobile number"
        }
    }
}

// MARK: - Validator

struct PhoneNumberValidator {

    /// Strip formatting and normalise international prefix to `+` form.
    /// Returns `nil` when the input is empty or whitespace-only.
    static func normalise(_ input: String) -> String? {
        var stripped = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ".", with: "")
        guard !stripped.isEmpty else { return nil }
        if stripped.hasPrefix("00") {
            stripped = "+" + stripped.dropFirst(2)
        }
        return stripped
    }

    static func validate(_ input: String) -> PhoneValidationResult {
        // Strip formatting characters
        let stripped = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: ".", with: "")

        guard !stripped.isEmpty else { return .empty }

        // Detect international prefix and normalise to +
        var normalised = stripped
        if normalised.hasPrefix("00") {
            normalised = "+" + normalised.dropFirst(2)
        }

        let hasPlus = normalised.hasPrefix("+")

        // Extract pure digits (after optional +)
        let digits = String(normalised.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) })

        guard !digits.isEmpty else { return .empty }
        if digits.count < 7 { return .tooShort }
        if digits.count > 15 { return .tooLong }

        // Country-specific matching (international format)
        if hasPlus {
            // UK (+44)
            if digits.hasPrefix("44") {
                let afterCC = String(digits.dropFirst(2))
                if afterCC.hasPrefix("7") && digits.count == 12 {
                    return .validMobile(country: "UK")
                }
                if afterCC.hasPrefix("1") || afterCC.hasPrefix("2") || afterCC.hasPrefix("3") {
                    return .possiblyLandline(country: "UK")
                }
            }

            // France (+33)
            if digits.hasPrefix("33") {
                let afterCC = String(digits.dropFirst(2))
                if (afterCC.hasPrefix("6") || afterCC.hasPrefix("7")) && digits.count == 11 {
                    return .validMobile(country: "French")
                }
                if afterCC.hasPrefix("1") || afterCC.hasPrefix("2") || afterCC.hasPrefix("3")
                    || afterCC.hasPrefix("4") || afterCC.hasPrefix("5")
                    || afterCC.hasPrefix("8") || afterCC.hasPrefix("9") {
                    return .possiblyLandline(country: "French")
                }
            }

            // Germany (+49)
            if digits.hasPrefix("49") {
                let afterCC = String(digits.dropFirst(2))
                if (afterCC.hasPrefix("15") || afterCC.hasPrefix("16") || afterCC.hasPrefix("17"))
                    && (digits.count >= 12 && digits.count <= 13) {
                    return .validMobile(country: "German")
                }
                if afterCC.hasPrefix("30") || afterCC.hasPrefix("40") || afterCC.hasPrefix("69")
                    || afterCC.hasPrefix("89") || afterCC.hasPrefix("21") || afterCC.hasPrefix("22") {
                    return .possiblyLandline(country: "German")
                }
            }

            // Ireland (+353)
            if digits.hasPrefix("353") {
                let afterCC = String(digits.dropFirst(3))
                if afterCC.hasPrefix("8") && digits.count == 12 {
                    return .validMobile(country: "Irish")
                }
                if afterCC.hasPrefix("1") || afterCC.hasPrefix("21") {
                    return .possiblyLandline(country: "Irish")
                }
            }

            // US/Canada (+1)
            if digits.hasPrefix("1") && !digits.hasPrefix("11") {
                if digits.count == 11 {
                    return .validMobile(country: "US/Canada")
                }
            }

            // Generic international: has + prefix, reasonable length
            return .likelyValid
        }

        // Local format matching (no + prefix)

        // UK local: 07xx (11 digits)
        if digits.hasPrefix("07") && digits.count == 11 {
            return .validMobile(country: "UK")
        }
        // UK landline local: 01x, 02x, 03x
        if (digits.hasPrefix("01") || digits.hasPrefix("02") || digits.hasPrefix("03"))
            && digits.count == 11 {
            return .possiblyLandline(country: "UK")
        }

        // France local: 06, 07 (10 digits)
        if (digits.hasPrefix("06") || digits.hasPrefix("07")) && digits.count == 10 {
            return .validMobile(country: "French")
        }

        // Germany local: 015, 016, 017 (11-12 digits)
        if (digits.hasPrefix("015") || digits.hasPrefix("016") || digits.hasPrefix("017"))
            && (digits.count >= 11 && digits.count <= 12) {
            return .validMobile(country: "German")
        }

        // Ireland local: 08x (10 digits)
        if digits.hasPrefix("08") && digits.count == 10 {
            return .validMobile(country: "Irish")
        }

        // Fallback: enough digits to be plausible
        if digits.count >= 10 {
            return .likelyValid
        }

        return .tooShort
    }
}
