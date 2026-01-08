//
//  GPXExporter.swift
//  TrackRide
//

import Foundation
import CoreLocation
import os

/// Actor-based GPX exporter to avoid main thread blocking
actor GPXExporter {

    /// Shared instance for convenience
    static let shared = GPXExporter()

    /// Export a single ride to GPX string (non-blocking)
    func export(ride: Ride) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TrackRide"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(ride.name))</name>
            <time>\(Formatters.iso8601(ride.startDate))</time>
          </metadata>
          <trk>
            <name>\(escapeXML(ride.name))</name>
            <type>horse_riding</type>
            <trkseg>

        """

        for point in ride.sortedLocationPoints {
            gpx += """
                  <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                    <ele>\(point.altitude)</ele>
                    <time>\(Formatters.iso8601(point.timestamp))</time>
                    <speed>\(point.speed)</speed>
                  </trkpt>

            """
        }

        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    /// Export ride to file (non-blocking)
    func exportToFile(ride: Ride) -> URL? {
        let gpxContent = export(ride: ride)

        let fileName = sanitizeFileName(ride.name.isEmpty ? "ride" : ride.name)
        let dateString = formatDateForFileName(ride.startDate)
        let fullFileName = "\(fileName)_\(dateString).gpx"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fullFileName)

        do {
            try gpxContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            Log.export.error("Failed to write GPX file: \(error)")
            return nil
        }
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    private func formatDateForFileName(_ date: Date) -> String {
        Formatters.fileNameDateTime(date)
    }

    // MARK: - Batch Export

    /// Export multiple rides to a single GPX file (non-blocking)
    func exportMultiple(rides: [Ride]) -> String {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TrackRide"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>TrackRide Export - \(rides.count) rides</name>
            <time>\(Formatters.iso8601(Date()))</time>
          </metadata>

        """

        for ride in rides.sorted(by: { $0.startDate < $1.startDate }) {
            gpx += """
              <trk>
                <name>\(escapeXML(ride.name))</name>
                <type>horse_riding</type>
                <trkseg>

            """

            for point in ride.sortedLocationPoints {
                gpx += """
                      <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
                        <ele>\(point.altitude)</ele>
                        <time>\(Formatters.iso8601(point.timestamp))</time>
                        <speed>\(point.speed)</speed>
                      </trkpt>

                """
            }

            gpx += """
                </trkseg>
              </trk>

            """
        }

        gpx += "</gpx>"
        return gpx
    }

    /// Export rides within a date range (non-blocking)
    func exportDateRange(
        rides: [Ride],
        from startDate: Date,
        to endDate: Date
    ) -> URL? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!

        let filteredRides = rides.filter { ride in
            ride.startDate >= start && ride.startDate < end
        }

        guard !filteredRides.isEmpty else { return nil }

        let gpxContent = exportMultiple(rides: filteredRides)

        let startString = Formatters.fileNameDate(startDate)
        let endString = Formatters.fileNameDate(endDate)
        let fileName = "TrackRide_\(startString)_to_\(endString).gpx"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try gpxContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            Log.export.error("Failed to write batch GPX file: \(error)")
            return nil
        }
    }

    /// Export all rides for a specific horse (non-blocking)
    func exportForHorse(_ horse: Horse, rides: [Ride]) -> URL? {
        let horseRides = rides.filter { $0.horse?.id == horse.id }
        guard !horseRides.isEmpty else { return nil }

        let gpxContent = exportMultiple(rides: horseRides)

        let sanitizedName = sanitizeFileName(horse.name)
        let fileName = "TrackRide_\(sanitizedName)_all_rides.gpx"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try gpxContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            Log.export.error("Failed to write horse GPX file: \(error)")
            return nil
        }
    }
}
