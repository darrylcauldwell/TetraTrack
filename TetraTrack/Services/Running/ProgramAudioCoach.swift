//
//  ProgramAudioCoach.swift
//  TetraTrack
//
//  Wraps AudioCoachManager with training program context for interval announcements
//

import Foundation

@Observable
@MainActor
final class ProgramAudioCoach {

    private let audioCoach = AudioCoachManager.shared

    // MARK: - Session Announcements

    /// Announce program session intro
    func announceSessionStart(weekNumber: Int, sessionNumber: Int, sessionName: String) {
        let message = "Week \(weekNumber), Session \(sessionNumber). \(sessionName). Let's go!"
        audioCoach.announce(message)
    }

    /// Announce interval phase transition
    func announcePhaseTransition(phase: IntervalPhase, duration: Double, intervalIndex: Int, totalIntervals: Int) {
        let durStr = formatDuration(duration)

        switch phase {
        case .warmup:
            audioCoach.announce("Warm up for \(durStr). Easy pace to get started.")
        case .walk:
            audioCoach.announce("Walk \(durStr). Recover and breathe.")
        case .run:
            audioCoach.announce("Run \(durStr). Find your rhythm.")
        case .cooldown:
            audioCoach.announce("Cool down for \(durStr). Great work!")
        }
    }

    /// Announce interval progress (e.g., "Interval 4 of 8 complete")
    func announceIntervalProgress(completedIndex: Int, totalIntervals: Int) {
        guard audioCoach.isEnabled else { return }
        let remaining = totalIntervals - completedIndex - 1
        if remaining > 0 {
            audioCoach.announce("Interval \(completedIndex + 1) of \(totalIntervals) complete. \(remaining) to go.")
        }
    }

    /// Announce countdown within a phase (10 seconds remaining)
    func announcePhaseCountdown(secondsRemaining: Int, nextPhase: IntervalPhase?) {
        guard audioCoach.isEnabled else { return }
        if secondsRemaining == 10 {
            if let next = nextPhase {
                audioCoach.announce("10 seconds. Get ready to \(next.displayName.lowercased()).")
            } else {
                audioCoach.announce("10 seconds remaining.")
            }
        } else if secondsRemaining == 3 {
            audioCoach.announce("3, 2, 1")
        }
    }

    /// Announce session completion with next session preview
    func announceSessionComplete(sessionName: String, nextSessionName: String?) {
        var message = "\(sessionName) complete! Well done."
        if let next = nextSessionName {
            message += " Next session: \(next)."
        } else {
            message += " You've completed all sessions for this week!"
        }
        audioCoach.announce(message)
    }

    /// Announce program milestone
    func announceProgramMilestone(weekNumber: Int, totalWeeks: Int) {
        guard audioCoach.isEnabled else { return }
        let remaining = totalWeeks - weekNumber
        if remaining == 0 {
            audioCoach.announce("Congratulations! You've completed the program!")
        } else {
            audioCoach.announce("Week \(weekNumber) complete! \(remaining) weeks to go.")
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
        if minutes == 0 {
            return "\(secs) second\(secs == 1 ? "" : "s")"
        }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") \(secs) seconds"
    }
}
