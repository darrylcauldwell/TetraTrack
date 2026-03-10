//
//  DrillSensorEnrichment.swift
//  TetraTrack
//
//  Reads Watch sensor data and populates drill session models before persistence.
//  Safe to call when Watch is disconnected — only writes non-zero values.

import Foundation

/// Enriches drill sessions with Watch sensor data before persistence
@MainActor
struct DrillSensorEnrichment {

    /// Enrich a UnifiedDrillSession with current Watch sensor readings
    static func enrich(_ session: UnifiedDrillSession) {
        let watchManager = WatchConnectivityManager.shared
        let sensorAnalyzer = WatchSensorAnalyzer.shared

        // Heart rate from Watch
        let hr = watchManager.lastReceivedHeartRate
        if hr > 0 {
            if session.startHeartRate == 0 {
                session.startHeartRate = Double(hr)
            }
            session.endHeartRate = Double(hr)
            session.averageHeartRateDrill = Double(hr)
        }

        // Breathing rate from WatchSensorAnalyzer
        let breathingRate = sensorAnalyzer.breathingRate
        if breathingRate > 0 {
            session.averageBreathingRate = breathingRate
        }

        // SpO2
        let spo2 = sensorAnalyzer.oxygenSaturation
        if spo2 > 0 {
            session.averageSpO2 = spo2
        }

        // Posture stability
        let posture = sensorAnalyzer.postureStability
        if posture > 0 && posture < 100 {
            session.postureStability = posture
        }

        // Tremor level (shooting drills)
        let tremor = sensorAnalyzer.tremorLevel
        if tremor > 0 {
            session.averageTremorLevel = tremor
        }

        // Stance stability (shooting drills)
        let stance = watchManager.stanceStability
        if stance > 0 {
            session.averageStanceStability = stance
        }
    }

    /// Enrich a ShootingDrillSession with current Watch sensor readings
    static func enrich(_ session: ShootingDrillSession) {
        let watchManager = WatchConnectivityManager.shared

        // Heart rate from Watch
        let hr = watchManager.lastReceivedHeartRate
        if hr > 0 {
            if session.startHeartRate == 0 {
                session.startHeartRate = Double(hr)
            }
        }
    }
}
