//
//  WeatherDisplayView.swift
//  TrackRide
//
//  Displays current weather conditions during outdoor sessions
//

import SwiftUI

// MARK: - Compact Weather Badge

struct WeatherBadgeView: View {
    let weather: WeatherConditions

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: weather.conditionSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.caption)

            Text(weather.formattedTemperature)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Weather Row for Lists

struct WeatherRowView: View {
    let weather: WeatherConditions

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: weather.conditionSymbol)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.condition)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(weather.formattedTemperature) (feels like \(weather.formattedFeelsLike))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.caption)
                    Text(weather.formattedWindSpeed)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "humidity")
                        .font(.caption)
                    Text(weather.formattedHumidity)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Live Weather Card (for Tracking View)

struct LiveWeatherCardView: View {
    let weather: WeatherConditions?
    let isLoading: Bool
    let error: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "cloud.sun")
                    .foregroundStyle(.secondary)
                Text("Weather")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let weather = weather {
                HStack(spacing: 12) {
                    Image(systemName: weather.conditionSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.title)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.formattedTemperature)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(weather.condition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "wind")
                                .font(.caption2)
                            Text(weather.formattedWindSpeed)
                                .font(.caption2)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "humidity")
                                .font(.caption2)
                            Text(weather.formattedHumidity)
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Weather unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Riding Conditions Indicator

struct RidingConditionsView: View {
    let conditions: RidingConditions

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: conditions.icon)
                .foregroundStyle(conditionColor)

            Text(conditions.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(conditionColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(conditionColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var conditionColor: Color {
        switch conditions {
        case .excellent: return .green
        case .good: return .teal
        case .fair: return .yellow
        case .poor: return .orange
        case .dangerous: return .red
        }
    }
}

// MARK: - Weather Detail View (for History)

struct WeatherDetailView: View {
    let weather: WeatherConditions
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                RidingConditionsView(conditions: weather.ridingConditions)
            }

            HStack(spacing: 16) {
                // Main temperature
                VStack(alignment: .center, spacing: 4) {
                    Image(systemName: weather.conditionSymbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.largeTitle)

                    Text(weather.formattedTemperature)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(weather.condition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()

                // Details grid
                VStack(alignment: .leading, spacing: 8) {
                    WeatherDetailRow(icon: "thermometer", label: "Feels like", value: weather.formattedFeelsLike)
                    WeatherDetailRow(icon: "wind", label: "Wind", value: "\(weather.formattedWindSpeed) \(weather.windDirectionCompass)")
                    WeatherDetailRow(icon: "humidity", label: "Humidity", value: weather.formattedHumidity)
                    WeatherDetailRow(icon: "cloud.rain", label: "Precip", value: weather.formattedPrecipitationChance)
                    WeatherDetailRow(icon: "sun.max", label: "UV Index", value: "\(weather.uvIndex)")
                    WeatherDetailRow(icon: "eye", label: "Visibility", value: weather.formattedVisibility)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WeatherDetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Weather Change Summary

struct WeatherChangeSummaryView: View {
    let stats: WeatherStats

    var body: some View {
        if let start = stats.startConditions, let end = stats.endConditions {
            VStack(alignment: .leading, spacing: 8) {
                Text("Weather Change")
                    .font(.headline)

                HStack(spacing: 24) {
                    // Start
                    VStack(spacing: 4) {
                        Text("Start")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: start.conditionSymbol)
                            .symbolRenderingMode(.multicolor)
                        Text(start.formattedTemperature)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    // Arrow
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    // End
                    VStack(spacing: 4) {
                        Text("End")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: end.conditionSymbol)
                            .symbolRenderingMode(.multicolor)
                        Text(end.formattedTemperature)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    // Temperature change
                    if let change = stats.temperatureChange {
                        VStack(spacing: 4) {
                            Text("Change")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%+.0f°C", change))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(change > 0 ? .orange : (change < 0 ? .blue : .primary))
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Previews

#Preview("Weather Badge") {
    WeatherBadgeView(weather: PreviewWeather.sample)
        .padding()
}

#Preview("Live Weather Card") {
    VStack(spacing: 16) {
        LiveWeatherCardView(weather: PreviewWeather.sample, isLoading: false, error: nil)
        LiveWeatherCardView(weather: nil, isLoading: true, error: nil)
        LiveWeatherCardView(weather: nil, isLoading: false, error: "Location unavailable")
    }
    .padding()
}

#Preview("Weather Detail") {
    WeatherDetailView(weather: PreviewWeather.sample, title: "Start Weather")
        .padding()
}

// Preview helper
private enum PreviewWeather {
    static let sample = WeatherConditions(
        timestamp: Date(),
        temperature: 18,
        feelsLike: 16,
        humidity: 0.65,
        windSpeed: 4.5,
        windDirection: 225,
        windGust: 8.0,
        condition: "Partly Cloudy",
        conditionSymbol: "cloud.sun.fill",
        uvIndex: 4,
        visibility: 10000,
        pressure: 1015,
        precipitationChance: 0.2,
        isDaylight: true
    )
}
