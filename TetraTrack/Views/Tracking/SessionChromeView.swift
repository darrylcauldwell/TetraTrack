//
//  SessionChromeView.swift
//  TetraTrack
//
//  Unified session control wrapper. Provides consistent header bar, bottom controls,
//  confirmation dialogs, and safety alerts for all discipline live views.
//  Discipline-specific content is provided via the content closure.
//

import SwiftUI
import SwiftData

struct SessionChromeView<Content: View>: View {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?
    @Environment(LocationManager.self) private var locationManager: LocationManager?

    /// Optional discipline-specific header items (e.g. page indicator, pocket mode, weather badge)
    let headerItems: AnyView?

    /// Override stop behavior (e.g. treadmill shows distance input before saving)
    var onStopOverride: (() -> Void)?

    /// Discipline-specific content (stats, metrics, scoring)
    @ViewBuilder let content: () -> Content

    @State private var showingExitConfirmation = false

    init(
        headerItems: AnyView? = nil,
        onStopOverride: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headerItems = headerItems
        self.onStopOverride = onStopOverride
        self.content = content
    }

    private var plugin: (any DisciplinePlugin)? {
        tracker?.activePlugin
    }

    var body: some View {
        ZStack {
            if let tracker {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header Bar
                    headerBar(tracker: tracker)

                    // MARK: - Discipline Content
                    content()

                    // MARK: - Bottom Controls
                    if plugin?.supportsPause ?? true {
                        PauseResumeButton(
                            isPaused: tracker.sessionState == .paused,
                            onTap: {
                                if tracker.sessionState == .paused {
                                    tracker.resumeSession()
                                } else {
                                    tracker.pauseSession()
                                }
                            },
                            onStop: {
                                if let onStopOverride {
                                    onStopOverride()
                                } else {
                                    tracker.stopSession()
                                }
                            },
                            onDiscard: { tracker.discardSession() }
                        )
                        .padding(.bottom, 20)
                    }
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        // Confirmation dialog
        .confirmationDialog("End Session", isPresented: $showingExitConfirmation, titleVisibility: .visible) {
            Button("Save") {
                if let onStopOverride {
                    onStopOverride()
                } else {
                    tracker?.stopSession()
                }
            }
            Button("Discard", role: .destructive) {
                tracker?.discardSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
        // Safety modifiers (no-op when plugin flags are false)
        .applyIf(plugin?.usesVehicleDetection ?? false) { view in
            view.vehicleDetectionAlert()
        }
        .applyIf(plugin?.usesFallDetection ?? false) { view in
            view.fallDetectionCover()
        }
        .applyIf(plugin?.supportsVoiceNotes ?? true) { view in
            view.voiceNoteOverlay()
        }
    }

    // MARK: - Header Bar

    @ViewBuilder
    private func headerBar(tracker: SessionTracker) -> some View {
        HStack(spacing: 12) {
            // Discipline-specific header items (left side)
            if let headerItems {
                headerItems
            }

            // GPS signal indicator
            if plugin?.usesGPS ?? false, let locManager = locationManager {
                GPSSignalIndicator(quality: locManager.gpsSignalQuality, showLabel: false)
                    .help(locManager.gpsSignalQuality.impactDescription)
            }

            Spacer()

            // Right side controls
            HStack(spacing: 8) {
                // Music control
                CompactMusicButton()

                // Audio coach mute (when discipline supports it)
                if plugin?.supportsAudioCoaching ?? true {
                    AudioCoachMuteButton()
                }

                // Voice note button (when paused and supported)
                if tracker.sessionState == .paused, plugin?.supportsVoiceNotes ?? true {
                    VoiceNoteToolbarButton { note in
                        plugin?.appendVoiceNote(note)
                    }
                    .frame(width: 44, height: 44)
                }

                // X button to close
                Button {
                    showingExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.cardBackground)
                        .clipShape(Circle())
                }
                .accessibleButton("End session", hint: "Opens options to save or discard this session")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Conditional Modifier Helper

extension View {
    @ViewBuilder
    func applyIf<Modified: View>(_ condition: Bool, transform: (Self) -> Modified) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
