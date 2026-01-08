//
//  TrackRideComplication.swift
//  TrackRide Watch App
//
//  Watch face complications for quick ride stats and launch
//

import WidgetKit
import SwiftUI

// MARK: - Complication Entry

struct TrackRideEntry: TimelineEntry {
    let date: Date
    let isRiding: Bool
    let duration: TimeInterval
    let distance: Double
    let gait: String
    let heartRate: Int
}

// MARK: - Timeline Provider

struct TrackRideProvider: TimelineProvider {
    func placeholder(in context: Context) -> TrackRideEntry {
        TrackRideEntry(
            date: Date(),
            isRiding: false,
            duration: 0,
            distance: 0,
            gait: "Ready",
            heartRate: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TrackRideEntry) -> Void) {
        let service = WatchConnectivityService.shared
        let entry = TrackRideEntry(
            date: Date(),
            isRiding: service.isRiding,
            duration: service.duration,
            distance: service.distance,
            gait: service.gait,
            heartRate: service.heartRate
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TrackRideEntry>) -> Void) {
        let service = WatchConnectivityService.shared
        let currentDate = Date()

        var entries: [TrackRideEntry] = []

        // Create entry for current state
        let entry = TrackRideEntry(
            date: currentDate,
            isRiding: service.isRiding,
            duration: service.duration,
            distance: service.distance,
            gait: service.gait,
            heartRate: service.heartRate
        )
        entries.append(entry)

        // If riding, update more frequently
        let refreshDate: Date
        if service.isRiding {
            refreshDate = Calendar.current.date(byAdding: .second, value: 15, to: currentDate)!
        } else {
            refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
        }

        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
}

// MARK: - Complication Views

struct TrackRideComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: TrackRideEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        default:
            CircularComplicationView(entry: entry)
        }
    }
}

// MARK: - Circular Complication

struct CircularComplicationView: View {
    let entry: TrackRideEntry

    var body: some View {
        ZStack {
            if entry.isRiding {
                // Show heart rate ring when riding
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    if entry.heartRate > 0 {
                        Text("\(entry.heartRate)")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                        Text("BPM")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.title2)
                        Text(formatDuration(entry.duration))
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            } else {
                // Show app icon when idle
                AccessoryWidgetBackground()
                Image(systemName: "figure.equestrian.sports")
                    .font(.title2)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Rectangular Complication

struct RectangularComplicationView: View {
    let entry: TrackRideEntry

    var body: some View {
        if entry.isRiding {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.caption2)
                        Text("TrackRide")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }

                    Text(formatDuration(entry.duration))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)

                    HStack(spacing: 8) {
                        Text(formatDistance(entry.distance))
                            .font(.caption2)
                        if entry.heartRate > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.red)
                                Text("\(entry.heartRate)")
                                    .font(.caption2)
                            }
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        } else {
            HStack {
                Image(systemName: "figure.equestrian.sports")
                    .font(.title3)
                VStack(alignment: .leading) {
                    Text("TrackRide")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Tap to start")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDistance(_ distance: Double) -> String {
        let km = distance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.2f km", km)
    }
}

// MARK: - Inline Complication

struct InlineComplicationView: View {
    let entry: TrackRideEntry

    var body: some View {
        if entry.isRiding {
            HStack {
                Image(systemName: "figure.equestrian.sports")
                Text("\(formatDuration(entry.duration)) • \(formatDistance(entry.distance))")
            }
        } else {
            HStack {
                Image(systemName: "figure.equestrian.sports")
                Text("TrackRide Ready")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDistance(_ distance: Double) -> String {
        let km = distance / 1000.0
        if km < 1 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.1f km", km)
    }
}

// MARK: - Corner Complication

struct CornerComplicationView: View {
    let entry: TrackRideEntry

    var body: some View {
        if entry.isRiding {
            ZStack {
                AccessoryWidgetBackground()
                VStack {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.caption)
                    if entry.heartRate > 0 {
                        Text("\(entry.heartRate)")
                            .font(.system(.caption2, design: .rounded))
                    }
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "figure.equestrian.sports")
                    .font(.caption)
            }
        }
    }
}

// MARK: - Widget Configuration

struct TrackRideComplicationWidget: Widget {
    let kind: String = "TrackRideComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TrackRideProvider()) { entry in
            TrackRideComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("TrackRide")
        .description("Quick access to your ride stats")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Previews

#Preview("Circular - Idle", as: .accessoryCircular) {
    TrackRideComplicationWidget()
} timeline: {
    TrackRideEntry(date: Date(), isRiding: false, duration: 0, distance: 0, gait: "Ready", heartRate: 0)
}

#Preview("Circular - Riding", as: .accessoryCircular) {
    TrackRideComplicationWidget()
} timeline: {
    TrackRideEntry(date: Date(), isRiding: true, duration: 1845, distance: 5200, gait: "Trot", heartRate: 145)
}

#Preview("Rectangular - Riding", as: .accessoryRectangular) {
    TrackRideComplicationWidget()
} timeline: {
    TrackRideEntry(date: Date(), isRiding: true, duration: 1845, distance: 5200, gait: "Trot", heartRate: 145)
}
