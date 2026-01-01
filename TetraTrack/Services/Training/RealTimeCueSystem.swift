//
//  RealTimeCueSystem.swift
//  TetraTrack
//
//  Coordinates haptic, audio, and visual feedback during drills
//  with physics-based directional cues derived from real sensor data.
//

import SwiftUI
import UIKit

/// Type of feedback cue
enum CueType: Equatable {
    case encouragement  // Green - doing well
    case warning        // Yellow - attention needed
    case correction     // Red - action required
    case neutral        // Default state

    var color: Color {
        switch self {
        case .encouragement: return .green
        case .warning: return .yellow
        case .correction: return .red
        case .neutral: return .primary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .encouragement: return .green.opacity(0.2)
        case .warning: return .yellow.opacity(0.2)
        case .correction: return .red.opacity(0.2)
        case .neutral: return .clear
        }
    }
}

/// Specific coaching cue categories for physics-based feedback
enum CoachingCueCategory {
    case asymmetry      // Left-right lean issues
    case anteriorPosterior  // Forward-back lean
    case tremor         // High-frequency instability
    case drift          // Slow postural loss
    case fatigue        // Performance degradation
    case rhythm         // Timing consistency
    case general        // General stability
}

/// Real-time feedback cue system for drills
@Observable
final class RealTimeCueSystem {

    // MARK: - Published State

    /// Current cue message to display
    var currentCue: String = ""

    /// Current cue type for styling
    var cueType: CueType = .neutral

    /// Whether a cue is currently visible
    var isCueVisible: Bool = false

    // MARK: - Configuration

    /// Whether haptic feedback is enabled
    var hapticsEnabled: Bool = true

    /// Whether voice cues are enabled
    var voiceEnabled: Bool = true

    /// Minimum interval between cues (to avoid spam)
    var minCueInterval: TimeInterval = 3.0

    // MARK: - Private State

    private var lastCueTime: Date = .distantPast
    private let audioManager = DrillAudioManager.shared
    private var cueTimer: Timer?

    // MARK: - Feedback Generators

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Initialization

    init() {
        prepareHaptics()
    }

    private func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Main Processing

    /// Process current drill state and provide appropriate feedback
    func processDrillState(
        score: Double,
        stability: Double,
        elapsed: TimeInterval,
        duration: TimeInterval
    ) {
        // Check stability thresholds
        if stability < 30 {
            showCue("Reset your position!", type: .correction)
            playHaptic(.warning)
        } else if stability < 50 {
            showCue("Focus! Stabilize.", type: .warning)
            playHaptic(.light)
        } else if stability >= 90 && score >= 80 {
            showCue("Excellent!", type: .encouragement)
            playHaptic(.success)
        }

        // Time-based cues
        let remaining = duration - elapsed
        if remaining == 30 {
            showCue("30 seconds left", type: .neutral)
        } else if remaining == 10 {
            showCue("Final 10 seconds!", type: .warning)
            playHaptic(.medium)
        } else if remaining == 5 {
            showCue("5...", type: .warning)
        }
    }

    // MARK: - Physics-Based Motion Analysis Processing

    /// Process motion analyzer data to generate specific, directional coaching cues
    /// - Parameters:
    ///   - analyzer: The DrillMotionAnalyzer providing real-time sensor metrics
    ///   - elapsed: Time elapsed since drill start
    ///   - duration: Total drill duration
    func processMotionAnalysis(
        _ analyzer: DrillMotionAnalyzer,
        elapsed: TimeInterval,
        duration: TimeInterval
    ) {
        // Skip processing during first 2 seconds (baseline establishment)
        guard elapsed > 2.0 else { return }

        // Priority 1: Critical stability issues
        if analyzer.stabilityScore * 100 < DrillPhysicsConstants.CueThresholds.criticalStability {
            generateStabilityCue(analyzer)
            return
        }

        // Priority 2: Directional asymmetry (left-right lean)
        if abs(analyzer.leftRightAsymmetry) > DrillPhysicsConstants.CueThresholds.asymmetryCriticalThreshold {
            generateAsymmetryCue(analyzer, critical: true)
            return
        } else if abs(analyzer.leftRightAsymmetry) > DrillPhysicsConstants.CueThresholds.asymmetryCueThreshold {
            generateAsymmetryCue(analyzer, critical: false)
            return
        }

        // Priority 3: Forward-back lean
        if abs(analyzer.anteriorPosterior) > DrillPhysicsConstants.CueThresholds.leanCriticalThreshold {
            generateLeanCue(analyzer, critical: true)
            return
        } else if abs(analyzer.anteriorPosterior) > DrillPhysicsConstants.CueThresholds.leanCueThreshold {
            generateLeanCue(analyzer, critical: false)
            return
        }

        // Priority 4: Tremor detection (nervous system stress)
        if analyzer.tremorPower > DrillPhysicsConstants.CueThresholds.tremorCueThreshold {
            generateTremorCue(analyzer)
            return
        }

        // Priority 5: Drift detection (postural loss)
        if analyzer.driftPower > DrillPhysicsConstants.CueThresholds.driftCueThreshold {
            generateDriftCue(analyzer)
            return
        }

        // Priority 6: Fatigue detection
        if analyzer.stabilityRetention < 100 - (DrillPhysicsConstants.CueThresholds.fatigueCueThreshold * 100) {
            generateFatigueCue(analyzer)
            return
        }

        // Priority 7: Encouragement for good performance
        if analyzer.stabilityScore * 100 >= DrillPhysicsConstants.CueThresholds.excellentStability &&
           abs(analyzer.leftRightAsymmetry) < DrillPhysicsConstants.Asymmetry.excellentThreshold {
            showCue("Excellent stability!", type: .encouragement, speakMessage: voiceEnabled)
            playHaptic(.success)
        }
    }

    // MARK: - Specific Cue Generators

    private func generateStabilityCue(_ analyzer: DrillMotionAnalyzer) {
        let score = analyzer.stabilityScore * 100
        if score < DrillPhysicsConstants.CueThresholds.criticalStability {
            showCue("Reset position! Stability lost.", type: .correction, speakMessage: voiceEnabled)
            playHaptic(.error)
        } else if score < DrillPhysicsConstants.CueThresholds.warningStability {
            showCue("Stabilize. Find your center.", type: .warning, speakMessage: voiceEnabled)
            playHaptic(.warning)
        }
    }

    private func generateAsymmetryCue(_ analyzer: DrillMotionAnalyzer, critical: Bool) {
        let asymmetry = analyzer.leftRightAsymmetry
        let direction = asymmetry > 0 ? "right" : "left"
        let correction = asymmetry > 0 ? "Shift weight left." : "Shift weight right."

        if critical {
            showCue("Leaning \(direction)! \(correction)", type: .correction, speakMessage: voiceEnabled)
            playHaptic(.warning)
        } else {
            showCue("Slight \(direction) lean. Center your weight.", type: .warning, speakMessage: false)
            playHaptic(.light)
        }
    }

    private func generateLeanCue(_ analyzer: DrillMotionAnalyzer, critical: Bool) {
        let lean = analyzer.anteriorPosterior
        let direction = lean > 0 ? "forward" : "backward"
        let correction = lean > 0 ? "Sit back slightly." : "Engage core, lift chest."

        if critical {
            showCue("Leaning \(direction)! \(correction)", type: .correction, speakMessage: voiceEnabled)
            playHaptic(.warning)
        } else {
            showCue("Slight \(direction) lean. \(correction)", type: .warning, speakMessage: false)
            playHaptic(.light)
        }
    }

    private func generateTremorCue(_ analyzer: DrillMotionAnalyzer) {
        // Tremor indicates nervous system stress, tension, or fatigue
        let tremorLevel = analyzer.tremorPower

        if tremorLevel > DrillPhysicsConstants.FrequencyBands.tremorPowerWarning {
            showCue("Tremor detected. Relax and breathe.", type: .warning, speakMessage: voiceEnabled)
            playHaptic(.light)
        } else {
            showCue("Slight tension. Soften your grip.", type: .warning, speakMessage: false)
            playHaptic(.selection)
        }
    }

    private func generateDriftCue(_ analyzer: DrillMotionAnalyzer) {
        // Drift indicates slow postural loss, losing balance gradually
        let driftLevel = analyzer.driftPower

        if driftLevel > DrillPhysicsConstants.FrequencyBands.driftPowerWarning {
            showCue("Drifting off balance. Re-center.", type: .warning, speakMessage: voiceEnabled)
            playHaptic(.medium)
        } else {
            showCue("Position drifting. Check your base.", type: .warning, speakMessage: false)
            playHaptic(.light)
        }
    }

    private func generateFatigueCue(_ analyzer: DrillMotionAnalyzer) {
        let retention = analyzer.stabilityRetention
        let decline = 100 - retention

        if decline > DrillPhysicsConstants.FatigueDetection.significantDeclinePercent {
            showCue("Fatigue detected. Maintain focus!", type: .warning, speakMessage: voiceEnabled)
            playHaptic(.medium)
        } else if decline > DrillPhysicsConstants.FatigueDetection.mildDeclinePercent {
            showCue("Stability declining. Stay engaged.", type: .warning, speakMessage: false)
            playHaptic(.light)
        }
    }

    /// Process rhythm-specific metrics for posting and cadence drills
    func processRhythmAnalysis(
        _ analyzer: DrillMotionAnalyzer,
        targetFrequency: Double,
        elapsed: TimeInterval
    ) {
        guard elapsed > 3.0 else { return }

        let frequency = analyzer.dominantFrequency
        let consistency = analyzer.rhythmConsistency

        // Frequency feedback
        let frequencyError = abs(frequency - targetFrequency)
        if frequencyError > 0.3 {
            if frequency < targetFrequency {
                showCue("Speed up rhythm. Too slow.", type: .warning, speakMessage: voiceEnabled)
            } else {
                showCue("Slow down rhythm. Too fast.", type: .warning, speakMessage: voiceEnabled)
            }
            playHaptic(.medium)
            return
        }

        // Consistency feedback
        if consistency < 60 {
            showCue("Inconsistent timing. Find the beat.", type: .warning, speakMessage: voiceEnabled)
            playHaptic(.warning)
        } else if consistency > 90 && frequencyError < 0.1 {
            showCue("Perfect rhythm!", type: .encouragement, speakMessage: false)
            playHaptic(.success)
        }
    }

    /// Process rhythm training state
    func processRhythmState(
        accuracy: Double,
        beatCount: Int,
        isOnBeat: Bool
    ) {
        if isOnBeat {
            playHaptic(.selection)
            if accuracy >= 90 {
                showCue("Perfect!", type: .encouragement)
            }
        } else {
            if accuracy < 50 && beatCount > 4 {
                showCue("Adjust timing", type: .correction)
                playHaptic(.warning)
            }
        }
    }

    /// Process target acquisition state
    func processTargetState(
        isOnTarget: Bool,
        transitionTime: TimeInterval
    ) {
        if isOnTarget {
            playHaptic(.light)
            showCue("Hold...", type: .encouragement)
        } else {
            if transitionTime > 1.0 {
                showCue("Acquire target", type: .warning)
            }
        }
    }

    // MARK: - Cue Display

    /// Show a cue message with type
    func showCue(_ message: String, type: CueType, speakMessage: Bool = false) {
        // Throttle cues
        guard Date().timeIntervalSince(lastCueTime) >= minCueInterval else { return }

        lastCueTime = Date()
        currentCue = message
        cueType = type
        isCueVisible = true

        // Speak if enabled
        if speakMessage && voiceEnabled {
            audioManager.speak(message)
        }

        // Auto-hide after delay
        cueTimer?.invalidate()
        cueTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideCue()
        }
    }

    /// Hide the current cue
    func hideCue() {
        isCueVisible = false
        currentCue = ""
        cueType = .neutral
    }

    /// Reset the cue system
    func reset() {
        hideCue()
        lastCueTime = .distantPast
        cueTimer?.invalidate()
    }

    // MARK: - Haptic Feedback

    /// Play haptic feedback
    func playHaptic(_ type: HapticType) {
        guard hapticsEnabled else { return }

        switch type {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        case .selection:
            selectionGenerator.selectionChanged()
        }

        // Re-prepare for next use
        prepareHaptics()
    }

    /// Play metronome beat haptic
    func playMetronomeBeat() {
        guard hapticsEnabled else { return }
        impactMedium.impactOccurred()
        prepareHaptics()
    }

    /// Play rhythm success feedback
    func playRhythmSuccess() {
        playHaptic(.success)
    }

    /// Play rhythm miss feedback
    func playRhythmMiss() {
        playHaptic(.light)
    }

    /// Play stability warning (gentle pulse)
    func playStabilityWarning() {
        playHaptic(.light)
    }

    /// Play stability lost (sharp feedback)
    func playStabilityLost() {
        playHaptic(.warning)
    }

    /// Play target acquired
    func playTargetAcquired() {
        playHaptic(.success)
    }

    /// Play target lost
    func playTargetLost() {
        playHaptic(.light)
    }

    // MARK: - Types

    enum HapticType {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
    }
}

// MARK: - Cue View Modifier

/// View modifier to display real-time cues
struct RealTimeCueOverlay: ViewModifier {
    @Bindable var cueSystem: RealTimeCueSystem

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if cueSystem.isCueVisible {
                    Text(cueSystem.currentCue)
                        .font(.headline)
                        .foregroundStyle(cueSystem.cueType.color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(cueSystem.cueType.backgroundColor)
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: cueSystem.isCueVisible)
                        .padding(.top, 8)
                }
            }
    }
}

extension View {
    /// Add real-time cue overlay to a view
    func withRealTimeCues(_ cueSystem: RealTimeCueSystem) -> some View {
        modifier(RealTimeCueOverlay(cueSystem: cueSystem))
    }
}
