//
//  HapticManager.swift
//  TrackRide Watch App
//
//  Haptic feedback for Watch
//

import Foundation
import WatchKit

final class HapticManager {
    // MARK: - Singleton

    static let shared = HapticManager()

    private init() {}

    // MARK: - Ride Control Haptics

    func playStartHaptic() {
        WKInterfaceDevice.current().play(.start)
    }

    func playStopHaptic() {
        WKInterfaceDevice.current().play(.stop)
    }

    func playPauseHaptic() {
        WKInterfaceDevice.current().play(.click)
    }

    func playResumeHaptic() {
        WKInterfaceDevice.current().play(.start)
    }

    // MARK: - Notification Haptics

    func playNotificationHaptic() {
        WKInterfaceDevice.current().play(.notification)
    }

    func playSuccessHaptic() {
        WKInterfaceDevice.current().play(.success)
    }

    func playFailureHaptic() {
        WKInterfaceDevice.current().play(.failure)
    }

    func playWarningHaptic() {
        WKInterfaceDevice.current().play(.retry)
    }

    // MARK: - Gait Change Haptics

    func playGaitChangeHaptic() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    // MARK: - Milestone Haptics

    func playMilestoneHaptic() {
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Heart Rate Zone Haptics

    func playZoneChangeHaptic(zone: Int) {
        switch zone {
        case 4, 5:
            // High intensity zone - strong feedback
            WKInterfaceDevice.current().play(.notification)
        case 3:
            // Moderate zone
            WKInterfaceDevice.current().play(.directionUp)
        default:
            // Low zone - subtle feedback
            WKInterfaceDevice.current().play(.click)
        }
    }

    // MARK: - Safety Haptics

    func playCheckInHaptic() {
        // Three quick taps to get attention
        WKInterfaceDevice.current().play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WKInterfaceDevice.current().play(.notification)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func playEmergencyHaptic() {
        // Strong repeated haptic for emergency
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4) {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
