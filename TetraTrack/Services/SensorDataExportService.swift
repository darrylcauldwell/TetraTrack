//
//  SensorDataExportService.swift
//  TetraTrack
//
//  Exports ride sensor data as CSV or JSON for gait analysis review

import Foundation
import SwiftData
import os

@MainActor
final class SensorDataExportService {

    static let shared = SensorDataExportService()

    // MARK: - CSV Export

    /// Export ride sensor data as a CSV file for gait analysis review.
    /// The CSV includes metadata as comment rows, a header row, location points
    /// with per-point gait classification, and gait segment details.
    func exportCSV(ride: Ride) -> URL? {
        var csv = buildCSVMetadata(ride: ride)
        csv += buildCSVLocationSection(ride: ride)
        csv += buildCSVGaitSegmentSection(ride: ride)
        csv += buildCSVGaitTransitionSection(ride: ride)
        csv += buildCSVReinSegmentSection(ride: ride)

        return writeToFile(content: csv, ride: ride, extension: "csv")
    }

    // MARK: - JSON Export

    /// Export ride sensor data as a JSON file for structured analysis.
    func exportJSON(ride: Ride) -> URL? {
        let data = buildJSONPayload(ride: ride)

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) else {
            Log.export.error("Failed to serialize sensor data JSON")
            return nil
        }

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            Log.export.error("Failed to convert JSON data to string")
            return nil
        }

        return writeToFile(content: jsonString, ride: ride, extension: "json")
    }

    // MARK: - CSV Metadata

    private func buildCSVMetadata(ride: Ride) -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        var meta = """
        # TetraTrack Sensor Data Export
        # Format: CSV with metadata comments (lines starting with #)
        # App Version: \(appVersion) (\(buildNumber))
        # Export Date: \(Formatters.iso8601(Date()))
        #
        # Ride Name: \(ride.name.isEmpty ? "Untitled Ride" : ride.name)
        # Ride Type: \(ride.rideType.rawValue)
        # Start Date: \(Formatters.iso8601(ride.startDate))
        # End Date: \(ride.endDate.map { Formatters.iso8601($0) } ?? "N/A")
        # Duration (s): \(String(format: "%.1f", ride.totalDuration))
        # Total Distance (m): \(String(format: "%.1f", ride.totalDistance))
        # Max Speed (m/s): \(String(format: "%.2f", ride.maxSpeed))
        # Elevation Gain (m): \(String(format: "%.1f", ride.elevationGain))
        # Elevation Loss (m): \(String(format: "%.1f", ride.elevationLoss))

        """

        if let horse = ride.horse {
            meta += """
            # Horse Name: \(horse.name)
            # Horse Breed: \(horse.typedBreed.rawValue)
            # Horse Height (hh): \(String(format: "%.1f", horse.heightHands ?? 0.0))
            # Horse Weight (kg): \(String(format: "%.0f", horse.weight ?? 0.0))

            """
        } else {
            meta += """
            # Horse: None assigned

            """
        }

        // Gait summary
        meta += """
        # --- Gait Summary ---
        # Walk Time (s): \(String(format: "%.1f", ride.totalWalkTime)) (\(String(format: "%.1f", ride.gaitPercentage(for: .walk)))%)
        # Trot Time (s): \(String(format: "%.1f", ride.totalTrotTime)) (\(String(format: "%.1f", ride.gaitPercentage(for: .trot)))%)
        # Canter Time (s): \(String(format: "%.1f", ride.totalCanterTime)) (\(String(format: "%.1f", ride.gaitPercentage(for: .canter)))%)
        # Gallop Time (s): \(String(format: "%.1f", ride.totalGallopTime)) (\(String(format: "%.1f", ride.gaitPercentage(for: .gallop)))%)
        # Gait Segments: \((ride.gaitSegments ?? []).count)
        # Gait Transitions: \((ride.gaitTransitions ?? []).count)
        # Avg Transition Quality: \(String(format: "%.2f", ride.averageTransitionQuality))
        #
        # --- Biomechanical Summary ---
        # Avg Stride Frequency (Hz): \(String(format: "%.2f", ride.averageStrideFrequency))
        # Jump Count: \(ride.detectedJumpCount)
        # Active Time (%): \(String(format: "%.1f", ride.activeTimePercent))
        #

        """

        return meta
    }

    // MARK: - CSV Location Points

    private func buildCSVLocationSection(ride: Ride) -> String {
        let points = ride.sortedLocationPoints
        let segments = ride.sortedGaitSegments

        var csv = """
        # ===== SECTION: LOCATION POINTS =====
        # Each row is a GPS sample (~1 Hz). gait_detected is interpolated from overlapping gait segments.
        #
        timestamp_iso,elapsed_seconds,latitude,longitude,altitude_m,speed_m_s,horizontal_accuracy_m,gait_detected

        """

        guard let rideStart = points.first?.timestamp else { return csv }

        for point in points {
            let elapsed = point.timestamp.timeIntervalSince(rideStart)
            let gait = gaitAtTime(point.timestamp, segments: segments)

            csv += "\(Formatters.iso8601(point.timestamp)),"
            csv += "\(String(format: "%.3f", elapsed)),"
            csv += "\(String(format: "%.7f", point.latitude)),"
            csv += "\(String(format: "%.7f", point.longitude)),"
            csv += "\(String(format: "%.1f", point.altitude)),"
            csv += "\(String(format: "%.3f", point.speed)),"
            csv += "\(String(format: "%.1f", point.horizontalAccuracy)),"
            csv += "\(gait.rawValue)\n"
        }

        csv += "\n"
        return csv
    }

    // MARK: - CSV Gait Segments

    private func buildCSVGaitSegmentSection(ride: Ride) -> String {
        let segments = ride.sortedGaitSegments

        var csv = """
        # ===== SECTION: GAIT SEGMENTS =====
        # Each row is a continuous period at one gait. Includes spectral features from FFT analysis.
        # stride_frequency_hz: Dominant frequency from FFT of vertical accelerometer
        # h2_ratio / h3_ratio: 2nd and 3rd harmonic ratios (gait discrimination)
        # spectral_entropy: Signal complexity (0=pure tone, 1=noise)
        # vertical_yaw_coherence: Phase coupling between bounce and rotation (0-1)
        # lead: Detected canter/gallop lead (Left/Right/Unknown)
        # lead_confidence: Confidence of lead detection (0-1)
        # rhythm_score: Rhythm consistency during segment (0-100)
        #
        segment_index,gait,start_time_iso,end_time_iso,duration_s,distance_m,avg_speed_m_s,stride_frequency_hz,h2_ratio,h3_ratio,spectral_entropy,vertical_yaw_coherence,lead,lead_confidence,rhythm_score

        """

        for (index, segment) in segments.enumerated() {
            let endTimeStr = segment.endTime.map { Formatters.iso8601($0) } ?? ""
            csv += "\(index),"
            csv += "\(segment.gait.rawValue),"
            csv += "\(Formatters.iso8601(segment.startTime)),"
            csv += "\(endTimeStr),"
            csv += "\(String(format: "%.2f", segment.duration)),"
            csv += "\(String(format: "%.1f", segment.distance)),"
            csv += "\(String(format: "%.3f", segment.averageSpeed)),"
            csv += "\(String(format: "%.3f", segment.strideFrequency)),"
            csv += "\(String(format: "%.4f", segment.harmonicRatioH2)),"
            csv += "\(String(format: "%.4f", segment.harmonicRatioH3)),"
            csv += "\(String(format: "%.4f", segment.spectralEntropy)),"
            csv += "\(String(format: "%.4f", segment.verticalYawCoherence)),"
            csv += "\(segment.lead.rawValue),"
            csv += "\(String(format: "%.3f", segment.leadConfidence)),"
            csv += "\(String(format: "%.1f", segment.rhythmScore))\n"
        }

        csv += "\n"
        return csv
    }

    // MARK: - CSV Gait Transitions

    private func buildCSVGaitTransitionSection(ride: Ride) -> String {
        let transitions = ride.sortedGaitTransitions

        var csv = """
        # ===== SECTION: GAIT TRANSITIONS =====
        # Each row is a gait-to-gait transition event.
        # transition_quality: Smoothness score (0=abrupt, 1=smooth)
        # direction: Upward (faster gait) or Downward (slower gait) or Lateral
        #
        transition_index,timestamp_iso,from_gait,to_gait,transition_quality,direction

        """

        for (index, transition) in transitions.enumerated() {
            let direction: String
            if transition.isUpwardTransition {
                direction = "Upward"
            } else if transition.isDownwardTransition {
                direction = "Downward"
            } else {
                direction = "Lateral"
            }

            csv += "\(index),"
            csv += "\(Formatters.iso8601(transition.timestamp)),"
            csv += "\(transition.fromGait.rawValue),"
            csv += "\(transition.toGait.rawValue),"
            csv += "\(String(format: "%.3f", transition.transitionQuality)),"
            csv += "\(direction)\n"
        }

        csv += "\n"
        return csv
    }

    // MARK: - CSV Rein Segments

    private func buildCSVReinSegmentSection(ride: Ride) -> String {
        let reinSegments = ride.sortedReinSegments
        guard !reinSegments.isEmpty else { return "" }

        var csv = """
        # ===== SECTION: REIN SEGMENTS =====
        # Rein direction tracking for flatwork analysis.
        #
        rein_index,direction,start_time_iso,end_time_iso,duration_s,distance_m,symmetry_score,rhythm_score

        """

        for (index, segment) in reinSegments.enumerated() {
            let endTimeStr = segment.endTime.map { Formatters.iso8601($0) } ?? ""
            csv += "\(index),"
            csv += "\(segment.reinDirection.rawValue),"
            csv += "\(Formatters.iso8601(segment.startTime)),"
            csv += "\(endTimeStr),"
            csv += "\(String(format: "%.2f", segment.duration)),"
            csv += "\(String(format: "%.1f", segment.distance)),"
            csv += "\(String(format: "%.1f", segment.symmetryScore)),"
            csv += "\(String(format: "%.1f", segment.rhythmScore))\n"
        }

        csv += "\n"
        return csv
    }

    // MARK: - JSON Payload

    private func buildJSONPayload(ride: Ride) -> [String: Any] {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        var payload: [String: Any] = [
            "export_format": "TetraTrack Sensor Data",
            "export_version": 2,
            "app_version": "\(appVersion) (\(buildNumber))",
            "export_date": Formatters.iso8601(Date()),
        ]

        // Ride metadata
        var rideMeta: [String: Any] = [
            "name": ride.name.isEmpty ? "Untitled Ride" : ride.name,
            "ride_type": ride.rideType.rawValue,
            "start_date": Formatters.iso8601(ride.startDate),
            "duration_seconds": ride.totalDuration,
            "total_distance_meters": ride.totalDistance,
            "max_speed_m_s": ride.maxSpeed,
            "elevation_gain_meters": ride.elevationGain,
            "elevation_loss_meters": ride.elevationLoss,
            "notes": ride.notes,
            "phone_mount_position": ride.phoneMountPosition.rawValue,
            "total_left_angle_degrees": ride.totalLeftAngle,
            "total_right_angle_degrees": ride.totalRightAngle,
            "left_lead_duration_seconds": ride.leftLeadDuration,
            "right_lead_duration_seconds": ride.rightLeadDuration,
            "left_rein_duration_seconds": ride.leftReinDuration,
            "right_rein_duration_seconds": ride.rightReinDuration,
            "left_rein_symmetry": ride.leftReinSymmetry,
            "right_rein_symmetry": ride.rightReinSymmetry,
            "left_rein_rhythm": ride.leftReinRhythm,
            "right_rein_rhythm": ride.rightReinRhythm,
        ]

        if let endDate = ride.endDate {
            rideMeta["end_date"] = Formatters.iso8601(endDate)
        }

        payload["ride"] = rideMeta

        // Horse profile
        if let horse = ride.horse {
            var horseDict: [String: Any] = [
                "name": horse.name,
                "breed": horse.typedBreed.rawValue,
                "color": horse.color,
                "notes": horse.notes,
                "has_custom_gait_settings": horse.hasCustomGaitSettings,
                "gait_frequency_offset": horse.gaitFrequencyOffset,
                "gait_speed_sensitivity": horse.gaitSpeedSensitivity,
                "gait_transition_speed": horse.gaitTransitionSpeed,
                "canter_sensitivity": horse.canterSensitivity,
                "walk_trot_threshold": horse.walkTrotThreshold,
                "trot_canter_threshold": horse.trotCanterThreshold,
            ]
            if let height = horse.heightHands {
                horseDict["height_hands"] = height
            }
            if let weight = horse.weight {
                horseDict["weight_kg"] = weight
            }
            if let dob = horse.dateOfBirth {
                horseDict["date_of_birth"] = Formatters.iso8601(dob)
            }
            if let learned = horse.learnedGaitParameters {
                var learnedDict: [String: Any] = [
                    "ride_count": learned.rideCount,
                ]
                if let v = learned.walkFrequencyCenter { learnedDict["walk_frequency_center"] = v }
                if let v = learned.trotFrequencyCenter { learnedDict["trot_frequency_center"] = v }
                if let v = learned.canterFrequencyCenter { learnedDict["canter_frequency_center"] = v }
                if let v = learned.gallopFrequencyCenter { learnedDict["gallop_frequency_center"] = v }
                if let v = learned.walkH2Mean { learnedDict["walk_h2_mean"] = v }
                if let v = learned.trotH2Mean { learnedDict["trot_h2_mean"] = v }
                if let v = learned.canterH3Mean { learnedDict["canter_h3_mean"] = v }
                if let v = learned.gallopEntropyMean { learnedDict["gallop_entropy_mean"] = v }
                if let v = learned.lastUpdate { learnedDict["last_update"] = Formatters.iso8601(v) }
                horseDict["learned_gait_parameters"] = learnedDict
            }
            payload["horse"] = horseDict
        }

        // Gait summary
        payload["gait_summary"] = [
            "walk_seconds": ride.totalWalkTime,
            "walk_percent": ride.gaitPercentage(for: .walk),
            "trot_seconds": ride.totalTrotTime,
            "trot_percent": ride.gaitPercentage(for: .trot),
            "canter_seconds": ride.totalCanterTime,
            "canter_percent": ride.gaitPercentage(for: .canter),
            "gallop_seconds": ride.totalGallopTime,
            "gallop_percent": ride.gaitPercentage(for: .gallop),
            "total_segments": (ride.gaitSegments ?? []).count,
            "total_transitions": (ride.gaitTransitions ?? []).count,
            "avg_transition_quality": ride.averageTransitionQuality,
        ] as [String: Any]

        // Biomechanical summary
        payload["biomechanics_summary"] = [
            "avg_stride_frequency_hz": ride.averageStrideFrequency,
        ] as [String: Any]

        // Rider physiology (Watch sensor data)
        payload["rider_physiology"] = [
            "jump_count": ride.detectedJumpCount,
            "active_time_percent": ride.activeTimePercent,
        ] as [String: Any]

        // Heart rate
        var heartRate: [String: Any] = [
            "average_bpm": ride.averageHeartRate,
            "max_bpm": ride.maxHeartRate,
            "min_bpm": ride.minHeartRate,
        ]
        let hrSamples = ride.heartRateSamples
        if !hrSamples.isEmpty {
            heartRate["samples"] = hrSamples.map { sample -> [String: Any] in
                [
                    "timestamp": Formatters.iso8601(sample.timestamp),
                    "bpm": sample.bpm,
                    "zone": sample.zone.rawValue,
                ] as [String: Any]
            }
        }
        payload["heart_rate"] = heartRate

        // Recovery metrics
        if let recovery = ride.recoveryMetrics {
            var recoveryDict: [String: Any] = [
                "ride_end_time": Formatters.iso8601(recovery.rideEndTime),
                "peak_heart_rate": recovery.peakHeartRate,
                "heart_rate_at_end": recovery.heartRateAtEnd,
                "recovery_quality": recovery.recoveryQuality.rawValue,
            ]
            if let v = recovery.oneMinuteRecovery { recoveryDict["one_minute_recovery"] = v }
            if let v = recovery.twoMinuteRecovery { recoveryDict["two_minute_recovery"] = v }
            if let v = recovery.timeToRestingHR { recoveryDict["time_to_resting_hr_seconds"] = v }
            payload["recovery_metrics"] = recoveryDict
        }

        // Weather
        if let startWeather = ride.startWeather {
            payload["weather_start"] = weatherDict(startWeather)
        }
        if let endWeather = ride.endWeather {
            payload["weather_end"] = weatherDict(endWeather)
        }

        // AI summary
        if let summary = ride.aiSummary {
            payload["ai_summary"] = [
                "generated_at": Formatters.iso8601(summary.generatedAt),
                "headline": summary.headline,
                "praise": summary.praise,
                "improvements": summary.improvements,
                "key_metrics": summary.keyMetrics,
                "encouragement": summary.encouragement,
                "overall_rating": summary.overallRating,
                "voice_notes_included": summary.voiceNotesIncluded,
            ] as [String: Any]
        }

        // Voice notes
        let voiceNotes = ride.voiceNotes
        if !voiceNotes.isEmpty {
            payload["voice_notes"] = voiceNotes
        }

        // Location points
        let points = ride.sortedLocationPoints
        let segments = ride.sortedGaitSegments
        let rideStart = points.first?.timestamp ?? ride.startDate

        payload["location_points"] = points.map { point -> [String: Any] in
            let elapsed = point.timestamp.timeIntervalSince(rideStart)
            let gait = gaitAtTime(point.timestamp, segments: segments)
            return [
                "timestamp": Formatters.iso8601(point.timestamp),
                "elapsed_seconds": round(elapsed * 1000) / 1000,
                "latitude": point.latitude,
                "longitude": point.longitude,
                "altitude_m": round(point.altitude * 10) / 10,
                "speed_m_s": round(point.speed * 1000) / 1000,
                "horizontal_accuracy_m": round(point.horizontalAccuracy * 10) / 10,
                "gait_detected": gait.rawValue,
            ] as [String: Any]
        }

        // Gait segments
        payload["gait_segments"] = ride.sortedGaitSegments.enumerated().map { (index, segment) -> [String: Any] in
            var dict: [String: Any] = [
                "index": index,
                "gait": segment.gait.rawValue,
                "start_time": Formatters.iso8601(segment.startTime),
                "duration_seconds": round(segment.duration * 100) / 100,
                "distance_meters": round(segment.distance * 10) / 10,
                "avg_speed_m_s": round(segment.averageSpeed * 1000) / 1000,
                "stride_frequency_hz": round(segment.strideFrequency * 1000) / 1000,
                "h2_ratio": round(segment.harmonicRatioH2 * 10000) / 10000,
                "h3_ratio": round(segment.harmonicRatioH3 * 10000) / 10000,
                "spectral_entropy": round(segment.spectralEntropy * 10000) / 10000,
                "vertical_yaw_coherence": round(segment.verticalYawCoherence * 10000) / 10000,
                "lead": segment.lead.rawValue,
                "lead_confidence": round(segment.leadConfidence * 1000) / 1000,
                "rhythm_score": round(segment.rhythmScore * 10) / 10,
            ]
            if let endTime = segment.endTime {
                dict["end_time"] = Formatters.iso8601(endTime)
            }
            return dict
        }

        // Gait transitions
        payload["gait_transitions"] = ride.sortedGaitTransitions.enumerated().map { (index, transition) -> [String: Any] in
            let direction: String
            if transition.isUpwardTransition {
                direction = "upward"
            } else if transition.isDownwardTransition {
                direction = "downward"
            } else {
                direction = "lateral"
            }
            return [
                "index": index,
                "timestamp": Formatters.iso8601(transition.timestamp),
                "from_gait": transition.fromGait.rawValue,
                "to_gait": transition.toGait.rawValue,
                "quality": round(transition.transitionQuality * 1000) / 1000,
                "direction": direction,
            ] as [String: Any]
        }

        // Rein segments
        let reinSegs = ride.sortedReinSegments
        if !reinSegs.isEmpty {
            payload["rein_segments"] = reinSegs.enumerated().map { (index, segment) -> [String: Any] in
                var dict: [String: Any] = [
                    "index": index,
                    "direction": segment.reinDirection.rawValue,
                    "start_time": Formatters.iso8601(segment.startTime),
                    "duration_seconds": round(segment.duration * 100) / 100,
                    "distance_meters": round(segment.distance * 10) / 10,
                    "symmetry_score": round(segment.symmetryScore * 10) / 10,
                    "rhythm_score": round(segment.rhythmScore * 10) / 10,
                ]
                if let endTime = segment.endTime {
                    dict["end_time"] = Formatters.iso8601(endTime)
                }
                return dict
            }
        }

        // Ride scores
        let scores = (ride.scores ?? []).filter { $0.hasScores }
        if !scores.isEmpty {
            payload["ride_scores"] = scores.map { score -> [String: Any] in
                [
                    "scored_at": Formatters.iso8601(score.scoredAt),
                    "relaxation": score.relaxation,
                    "impulsion": score.impulsion,
                    "straightness": score.straightness,
                    "rhythm": score.rhythm,
                    "rider_position": score.riderPosition,
                    "connection": score.connection,
                    "suppleness": score.suppleness,
                    "collection": score.collection,
                    "overall_feeling": score.overallFeeling,
                    "horse_energy": score.horseEnergy,
                    "horse_mood": score.horseMood,
                    "notes": score.notes,
                    "highlights": score.highlights,
                    "improvements": score.improvements,
                ] as [String: Any]
            }
        }

        // Gait diagnostics (HMM time series for gait testing rides)
        let diagnostics = ride.gaitDiagnostics
        if !diagnostics.isEmpty {
            payload["gait_diagnostics"] = [
                "sample_count": diagnostics.count,
                "description": "Per-HMM-update feature vectors and state probabilities (~6 Hz)",
                "entries": diagnostics.map { entry -> [String: Any] in
                    [
                        "timestamp": Formatters.iso8601(entry.timestamp),
                        "detected_gait": entry.detectedGait,
                        "confidence": entry.confidence,
                        "state_probabilities": entry.stateProbabilities,
                        "features": [
                            "stride_frequency_hz": entry.strideFrequency,
                            "h2_ratio": entry.h2Ratio,
                            "h3_ratio": entry.h3Ratio,
                            "spectral_entropy": entry.spectralEntropy,
                            "xy_coherence": entry.xyCoherence,
                            "z_yaw_coherence": entry.zYawCoherence,
                            "normalized_vertical_rms": entry.normalizedVerticalRMS,
                            "yaw_rate_rms": entry.yawRateRMS,
                            "gps_speed": entry.gpsSpeed,
                            "gps_accuracy": entry.gpsAccuracy,
                        ] as [String: Any]
                    ] as [String: Any]
                }
            ] as [String: Any]
        }

        // Photo metadata (no binary data)
        let photos = (ride.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
        if !photos.isEmpty {
            payload["photo_metadata"] = photos.map { photo -> [String: Any] in
                var dict: [String: Any] = [
                    "captured_at": Formatters.iso8601(photo.capturedAt),
                    "has_location": photo.hasLocation,
                    "caption": photo.caption,
                    "is_favorite": photo.isFavorite,
                ]
                if photo.hasLocation {
                    dict["latitude"] = photo.latitude
                    dict["longitude"] = photo.longitude
                }
                return dict
            }
        }

        return payload
    }

    /// Convert WeatherConditions to a JSON-compatible dictionary.
    private func weatherDict(_ w: WeatherConditions) -> [String: Any] {
        var dict: [String: Any] = [
            "timestamp": Formatters.iso8601(w.timestamp),
            "temperature_celsius": w.temperature,
            "feels_like_celsius": w.feelsLike,
            "humidity": w.humidity,
            "wind_speed_m_s": w.windSpeed,
            "wind_direction_degrees": w.windDirection,
            "condition": w.condition,
            "condition_symbol": w.conditionSymbol,
            "uv_index": w.uvIndex,
            "visibility_meters": w.visibility,
            "pressure_hpa": w.pressure,
            "precipitation_chance": w.precipitationChance,
            "is_daylight": w.isDaylight,
        ]
        if let gust = w.windGust {
            dict["wind_gust_m_s"] = gust
        }
        return dict
    }

    // MARK: - Helpers

    /// Determine the gait at a given timestamp by finding the overlapping gait segment.
    private func gaitAtTime(_ time: Date, segments: [GaitSegment]) -> GaitType {
        for segment in segments {
            let segmentEnd = segment.endTime ?? Date.distantFuture
            if time >= segment.startTime && time <= segmentEnd {
                return segment.gait
            }
        }
        return .stationary
    }

    /// Write content to a temporary file and return the URL.
    private func writeToFile(content: String, ride: Ride, extension ext: String) -> URL? {
        let rideName = ride.name.isEmpty ? "ride" : ride.name
        let sanitized = sanitizeFileName(rideName)
        let dateString = Formatters.fileNameDateTime(ride.startDate)
        let fileName = "\(sanitized)_sensor_data_\(dateString).\(ext)"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            Log.export.info("Sensor data exported to \(tempURL.lastPathComponent)")
            return tempURL
        } catch {
            Log.export.error("Failed to write sensor data file: \(error)")
            return nil
        }
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }
}
