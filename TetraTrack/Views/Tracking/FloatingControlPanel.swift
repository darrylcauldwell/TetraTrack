//
//  FloatingControlPanel.swift
//  TetraTrack
//
//  Apple Fitness-style floating glass control panel for live sessions.
//  Compact during tracking; shows End/Resume buttons when paused.
//

import SwiftUI

struct FloatingControlPanel: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    let disciplineIcon: String
    let disciplineColor: Color
    var onStop: () -> Void
    var onVoiceNote: ((String) -> Void)?

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
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
        VStack(spacing: 16) {
            // Apple Fitness-style End / Resume buttons
            HStack(spacing: 40) {
                // End button
                VStack(spacing: 6) {
                    Button(action: onStop) {
                        ZStack {
                            Circle()
                                .fill(AppColors.error)
                                .frame(width: 80, height: 80)

                            Image(systemName: "xmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibleButton("End session", hint: "End and save the session")

                    Text("End")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                // Resume button
                VStack(spacing: 6) {
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

                    Text("Resume")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Secondary controls
            HStack(spacing: 20) {
                if supportsVoiceNotes, let voiceHandler = onVoiceNote {
                    VoiceNoteToolbarButton(onNoteSaved: voiceHandler)
                        .frame(width: 44, height: 44)
                }

                CompactMusicButton()
                    .frame(width: 44, height: 44)

                if supportsAudioCoaching {
                    AudioCoachMuteButton()
                        .frame(width: 44, height: 44)
                }
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

#Preview("Floating Control Panel - Tracking") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            FloatingControlPanel(
                disciplineIcon: "figure.equestrian.sports",
                disciplineColor: AppColors.riding,
                onStop: {},
                onVoiceNote: { _ in }
            )
        }
    }
}
