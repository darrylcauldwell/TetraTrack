//
//  FloatingControlPanel.swift
//  TetraTrack
//
//  Apple Fitness-style floating glass control panel for live sessions.
//  Compact during tracking; expands when paused to reveal end/discard actions.
//

import SwiftUI

struct FloatingControlPanel: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    let disciplineIcon: String
    let disciplineColor: Color
    var onStop: () -> Void
    var onDiscard: () -> Void
    var onVoiceNote: ((String) -> Void)?

    @State private var isPanelExpanded = false

    private var isPaused: Bool {
        tracker?.sessionState == .paused
    }

    private var supportsAudioCoaching: Bool {
        tracker?.activePlugin?.supportsAudioCoaching ?? true
    }

    private var supportsVoiceNotes: Bool {
        tracker?.activePlugin?.supportsVoiceNotes ?? true
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main control card
            mainPanel
                .glassCard(material: .regular, cornerRadius: 28, shadowRadius: 16, padding: 0)

            // Expanded action cards (paused only)
            if isPanelExpanded {
                VStack(spacing: 8) {
                    ControlPanelActionCard(
                        icon: "xmark.circle.fill",
                        label: "End Session",
                        isDestructive: true,
                        action: onStop
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    ControlPanelActionCard(
                        icon: "trash",
                        label: "Discard",
                        isDestructive: false,
                        action: onDiscard
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onChange(of: isPaused) { _, paused in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isPanelExpanded = paused
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isPaused)
    }

    // MARK: - Main Panel

    @ViewBuilder
    private var mainPanel: some View {
        VStack(spacing: 16) {
            // Top row: icon, timer, HR zone
            HStack {
                Image(systemName: disciplineIcon)
                    .font(.title3)
                    .foregroundStyle(disciplineColor)
                    .frame(width: 32)

                Spacer()

                // Timer
                Text(tracker?.formattedElapsedTime ?? "00:00")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isPaused ? .secondary : AppColors.warning)

                Spacer()

                // HR zone mini ring
                if let hr = tracker?.currentHeartRate, hr > 0,
                   let zone = tracker?.currentHeartRateZone {
                    HeartRateZoneMiniRing(bpm: hr, zone: zone)
                } else {
                    Color.clear.frame(width: 32, height: 32)
                }
            }

            // Bottom row: controls
            if isPaused {
                pausedControls
            } else {
                trackingControls
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Tracking Controls

    private var trackingControls: some View {
        HStack(spacing: 20) {
            // Music
            CompactMusicButton()
                .frame(width: 44, height: 44)

            Spacer()

            // Pause button
            Button {
                tracker?.pauseSession()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.warning)
                        .frame(width: 70, height: 70)

                    Image(systemName: "pause.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibleButton("Pause session", hint: "Pause the current session")

            Spacer()

            // Coach mute
            if supportsAudioCoaching {
                AudioCoachMuteButton()
                    .frame(width: 44, height: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Paused Controls

    private var pausedControls: some View {
        HStack(spacing: 20) {
            // Voice note (when supported)
            if supportsVoiceNotes, let voiceHandler = onVoiceNote {
                VoiceNoteToolbarButton(onNoteSaved: voiceHandler)
                    .frame(width: 44, height: 44)
            } else {
                CompactMusicButton()
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Resume button
            Button {
                tracker?.resumeSession()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppColors.startButton)
                        .frame(width: 80, height: 80)

                    Image(systemName: "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibleButton("Resume session", hint: "Resume the current session")

            Spacer()

            // Music
            if supportsVoiceNotes, onVoiceNote != nil {
                CompactMusicButton()
                    .frame(width: 44, height: 44)
            } else if supportsAudioCoaching {
                AudioCoachMuteButton()
                    .frame(width: 44, height: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }
}

// MARK: - Heart Rate Zone Mini Ring

struct HeartRateZoneMiniRing: View {
    let bpm: Int
    let zone: HeartRateZone

    private var zoneColor: Color {
        heartRateZoneColor(zone)
    }

    private var zoneProgress: Double {
        Double(zone.rawValue) / 5.0
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(zoneColor.opacity(0.2), lineWidth: 3)
                .frame(width: 32, height: 32)

            // Progress ring
            Circle()
                .trim(from: 0, to: zoneProgress)
                .stroke(zoneColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(-90))

            // BPM text
            Text("\(bpm)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(zoneColor)
        }
    }
}

// MARK: - Control Panel Action Card

struct ControlPanelActionCard: View {
    let icon: String
    let label: String
    let isDestructive: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDestructive ? AppColors.error : .secondary)

                Text(label)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isDestructive ? AppColors.error : .primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isDestructive ? AppColors.error.opacity(0.08) : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isDestructive ? AppColors.error.opacity(0.2) : Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .accessibleButton(label, hint: isDestructive ? "Ends and saves the session" : "Discards session data")
    }
}

#Preview("Floating Control Panel - Tracking") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            FloatingControlPanel(
                disciplineIcon: "figure.equestrian.sports",
                disciplineColor: AppColors.riding,
                onStop: {},
                onDiscard: {},
                onVoiceNote: { _ in }
            )
        }
    }
}
