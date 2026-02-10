//
//  WeatherService.swift
//  TetraTrack
//
//  Weather tracking service using WeatherKit for outdoor sessions
//

import Foundation
import WeatherKit
import CoreLocation
import Observation
import os

/// Weather conditions captured during an outdoor session
struct WeatherConditions: Codable, Equatable, Sendable {
    let timestamp: Date
    let temperature: Double  // Celsius
    let feelsLike: Double  // Celsius
    let humidity: Double  // 0-1
    let windSpeed: Double  // m/s
    let windDirection: Double  // degrees
    let windGust: Double?  // m/s
    let condition: String  // WeatherKit condition name
    let conditionSymbol: String  // SF Symbol name
    let uvIndex: Int
    let visibility: Double  // meters
    let pressure: Double  // hPa
    let precipitationChance: Double  // 0-1
    let isDaylight: Bool

    // Formatted values for display
    var formattedTemperature: String {
        String(format: "%.0f°C", temperature)
    }

    var formattedFeelsLike: String {
        String(format: "%.0f°C", feelsLike)
    }

    var formattedHumidity: String {
        String(format: "%.0f%%", humidity * 100)
    }

    var formattedWindSpeed: String {
        let kmh = windSpeed * 3.6
        return String(format: "%.0f km/h", kmh)
    }

    var formattedWindGust: String? {
        guard let gust = windGust else { return nil }
        let kmh = gust * 3.6
        return String(format: "%.0f km/h", kmh)
    }

    var formattedVisibility: String {
        let km = visibility / 1000
        if km >= 10 {
            return "10+ km"
        }
        return String(format: "%.1f km", km)
    }

    var formattedPressure: String {
        String(format: "%.0f hPa", pressure)
    }

    var formattedPrecipitationChance: String {
        String(format: "%.0f%%", precipitationChance * 100)
    }

    var windDirectionCompass: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((windDirection + 11.25) / 22.5) % 16
        return directions[index]
    }

    /// Brief weather summary for compact display
    var briefSummary: String {
        "\(formattedTemperature) • \(condition)"
    }

    /// Riding conditions assessment
    var ridingConditions: RidingConditions {
        // Assess conditions for horseback riding
        var score = 100.0

        // Temperature penalties
        if temperature < 0 {
            score -= 20
        } else if temperature < 5 {
            score -= 10
        } else if temperature > 30 {
            score -= 15
        } else if temperature > 35 {
            score -= 30
        }

        // Wind penalties (horses can be spooked by high winds)
        let windKmh = windSpeed * 3.6
        if windKmh > 40 {
            score -= 25
        } else if windKmh > 25 {
            score -= 15
        } else if windKmh > 15 {
            score -= 5
        }

        // Precipitation penalties
        if precipitationChance > 0.7 {
            score -= 20
        } else if precipitationChance > 0.4 {
            score -= 10
        }

        // Visibility penalties
        let visKm = visibility / 1000
        if visKm < 1 {
            score -= 25
        } else if visKm < 3 {
            score -= 10
        }

        // Condition-specific penalties
        let conditionLower = condition.lowercased()
        if conditionLower.contains("thunderstorm") || conditionLower.contains("lightning") {
            score -= 50  // Dangerous for outdoor riding
        } else if conditionLower.contains("heavy rain") || conditionLower.contains("heavy snow") {
            score -= 30
        } else if conditionLower.contains("rain") || conditionLower.contains("snow") || conditionLower.contains("sleet") {
            score -= 15
        } else if conditionLower.contains("fog") || conditionLower.contains("mist") {
            score -= 10
        }

        score = max(0, min(100, score))

        if score >= 80 {
            return .excellent
        } else if score >= 60 {
            return .good
        } else if score >= 40 {
            return .fair
        } else if score >= 20 {
            return .poor
        } else {
            return .dangerous
        }
    }
}

/// Assessment of riding conditions
enum RidingConditions: String, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case dangerous = "Dangerous"

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "teal"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .dangerous: return "red"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.circle"
        case .poor: return "exclamationmark.triangle"
        case .dangerous: return "xmark.octagon.fill"
        }
    }
}

/// Weather statistics for a session (start and end conditions)
struct WeatherStats: Codable {
    let startConditions: WeatherConditions?
    let endConditions: WeatherConditions?

    var temperatureChange: Double? {
        guard let start = startConditions?.temperature,
              let end = endConditions?.temperature else { return nil }
        return end - start
    }

    var conditionChanged: Bool {
        guard let start = startConditions?.condition,
              let end = endConditions?.condition else { return false }
        return start != end
    }
}

@Observable
final class WeatherService: WeatherFetching {
    // MARK: - State

    private(set) var currentConditions: WeatherConditions?
    private(set) var isLoading: Bool = false
    private(set) var lastError: Error?
    private(set) var lastFetchTime: Date?

    // MARK: - Private

    private let weatherService = WeatherKit.WeatherService.shared
    private var cachedWeather: (location: CLLocation, weather: WeatherConditions, time: Date)?
    private let cacheTimeout: TimeInterval = 300  // 5 minutes
    private let fetchTimeout: TimeInterval = 15  // 15 seconds for weather fetch

    // MARK: - Singleton

    static let shared = WeatherService()

    private init() {}

    // MARK: - Public Methods

    /// Fetch current weather for a location
    @MainActor
    func fetchWeather(for location: CLLocation) async throws -> WeatherConditions {
        // Check cache
        if let cached = cachedWeather,
           cached.location.distance(from: location) < 1000,  // Within 1km
           Date().timeIntervalSince(cached.time) < cacheTimeout {
            currentConditions = cached.weather
            return cached.weather
        }

        isLoading = true
        lastError = nil

        do {
            let weather = try await withTimeout(seconds: fetchTimeout) {
                try await self.weatherService.weather(for: location, including: .current)
            }

            let conditions = WeatherConditions(
                timestamp: Date(),
                temperature: weather.temperature.value,
                feelsLike: weather.apparentTemperature.value,
                humidity: weather.humidity,
                windSpeed: weather.wind.speed.value,
                windDirection: weather.wind.direction.value,
                windGust: weather.wind.gust?.value,
                condition: weather.condition.description,
                conditionSymbol: weather.symbolName,
                uvIndex: weather.uvIndex.value,
                visibility: weather.visibility.value,
                pressure: weather.pressure.value,
                precipitationChance: weather.precipitationIntensity.value > 0 ? 0.5 : 0.0,
                isDaylight: weather.isDaylight
            )

            // Update cache
            cachedWeather = (location, conditions, Date())
            currentConditions = conditions
            lastFetchTime = Date()
            isLoading = false

            return conditions
        } catch {
            lastError = error
            isLoading = false
            throw error
        }
    }

    /// Fetch weather with hourly forecast
    @MainActor
    func fetchWeatherWithForecast(for location: CLLocation) async throws -> (current: WeatherConditions, precipChance: Double) {
        isLoading = true
        lastError = nil

        do {
            let weather = try await withTimeout(seconds: fetchTimeout) {
                try await self.weatherService.weather(for: location, including: .current, .hourly)
            }

            // Get precipitation chance from next hour
            let nextHourPrecip = weather.1.first?.precipitationChance ?? 0.0

            let conditions = WeatherConditions(
                timestamp: Date(),
                temperature: weather.0.temperature.value,
                feelsLike: weather.0.apparentTemperature.value,
                humidity: weather.0.humidity,
                windSpeed: weather.0.wind.speed.value,
                windDirection: weather.0.wind.direction.value,
                windGust: weather.0.wind.gust?.value,
                condition: weather.0.condition.description,
                conditionSymbol: weather.0.symbolName,
                uvIndex: weather.0.uvIndex.value,
                visibility: weather.0.visibility.value,
                pressure: weather.0.pressure.value,
                precipitationChance: nextHourPrecip,
                isDaylight: weather.0.isDaylight
            )

            cachedWeather = (location, conditions, Date())
            currentConditions = conditions
            lastFetchTime = Date()
            isLoading = false

            return (conditions, nextHourPrecip)
        } catch {
            lastError = error
            isLoading = false
            throw error
        }
    }

    /// Clear cached weather data
    func clearCache() {
        cachedWeather = nil
        currentConditions = nil
    }

    // MARK: - Private Helpers

    /// Execute an async operation with a timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw WeatherServiceError.timeout
            }

            guard let result = try await group.next() else {
                throw WeatherServiceError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Errors

enum WeatherServiceError: Error, LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Weather request timed out"
        }
    }
}
