//
//  TrackingView.swift
//  TetraTrack
//
//  Liquid Glass Design - Main Tracking Interface with swipe-to-map
//

import SwiftUI
import SwiftData

struct TrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionTracker.self) private var sessionTracker: SessionTracker?
    @Environment(LocationManager.self) private var locationManager: LocationManager?
    @State private var selectedTab: TrackingTab = .stats
    @State private var showingExerciseLibrary = false
    @State private var showingExitConfirmation = false
    @State private var emergencyAlertSent = false
    @Query(filter: #Predicate<SharingRelationship> { $0.receiveFallAlerts == true && $0.phoneNumber != nil }) private var emergencyContacts: [SharingRelationship]

    enum TrackingTab {
        case stats
        case map
        case exercises
    }

    /// Access the riding plugin if the active session is riding
    private var ridingPlugin: RidingPlugin? {
        sessionTracker?.plugin(as: RidingPlugin.self)
    }

    var body: some View {
        ZStack {
            if let tracker = sessionTracker {
                if tracker.sessionState == .tracking || tracker.sessionState == .paused {
                    let plugin = ridingPlugin

                    // Pure black background
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Top bar with controls
                        HStack(spacing: 12) {
                            // Page indicator on left
                            HStack(spacing: 8) {
                                let isOutdoor = plugin?.selectedRideType.isOutdoor ?? true
                                let tabs: [TrackingTab] = isOutdoor ? [.stats, .map] : [.stats, .exercises]
                                ForEach(tabs, id: \.self) { tab in
                                    Capsule()
                                        .fill(selectedTab == tab ? AppColors.primary : Color.gray.opacity(0.3))
                                        .frame(width: selectedTab == tab ? 24 : 8, height: 8)
                                        .animation(.spring(response: 0.3), value: selectedTab)
                                }
                            }

                            // GPS signal indicator
                            if let locManager = locationManager {
                                GPSSignalIndicator(quality: locManager.gpsSignalQuality, showLabel: false)
                                    .help(locManager.gpsSignalQuality.impactDescription)
                            }

                            Spacer()

                            // Right side controls: Pocket mode, Music, Mic (when paused), X
                            HStack(spacing: 8) {
                                // Pocket mode indicator
                                PocketModeIndicator()

                                // Music control
                                CompactMusicButton()

                                // Voice note button when paused
                                if tracker.sessionState == .paused {
                                    VoiceNoteToolbarButton { note in
                                        if let ride = plugin?.currentRide {
                                            let service = VoiceNotesService.shared
                                            ride.notes = service.appendNote(note, to: ride.notes)
                                        }
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

                        // Content - swipeable with map for outdoor, stats+exercises for flatwork
                        let isOutdoor = plugin?.selectedRideType.isOutdoor ?? true
                        if isOutdoor {
                            TabView(selection: $selectedTab) {
                                // Stats View with integrated pause/resume/stop
                                StatsContentView(
                                    tracker: tracker,
                                    ridingPlugin: plugin,
                                    onPauseResume: {
                                        if tracker.sessionState == .paused {
                                            tracker.resumeSession()
                                        } else {
                                            tracker.pauseSession()
                                        }
                                    },
                                    onStop: { tracker.stopSession() },
                                    onDiscard: { tracker.discardSession() }
                                )
                                .sensoryFeedback(.impact(weight: .heavy), trigger: tracker.sessionState)
                                .tag(TrackingTab.stats)

                                // Map View
                                LiveSessionMapView(
                                    routeSegments: (locationManager?.gaitRouteSegments ?? []).map {
                                        RouteSegment(coordinates: $0.coordinates, color: AppColors.gait($0.gaitType))
                                    },
                                    currentLocation: locationManager?.currentLocation,
                                    onBack: {
                                        withAnimation {
                                            selectedTab = .stats
                                        }
                                    }
                                )
                                .overlay(alignment: .bottom) {
                                    MapLegendView.allGaitsLegend()
                                        .padding(.bottom, 20)
                                }
                                .tag(TrackingTab.map)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                        } else {
                            // Flatwork - stats + exercises swipeable
                            TabView(selection: $selectedTab) {
                                // Stats View with integrated pause/resume/stop
                                StatsContentView(
                                    tracker: tracker,
                                    ridingPlugin: plugin,
                                    onPauseResume: {
                                        if tracker.sessionState == .paused {
                                            tracker.resumeSession()
                                        } else {
                                            tracker.pauseSession()
                                        }
                                    },
                                    onStop: { tracker.stopSession() },
                                    onDiscard: { tracker.discardSession() }
                                )
                                .sensoryFeedback(.impact(weight: .heavy), trigger: tracker.sessionState)
                                .tag(TrackingTab.stats)

                                // Exercises View
                                ActiveExerciseView()
                                    .tag(TrackingTab.exercises)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                        }
                    }
                } else {
                    // Idle state - setup view
                    IdleSetupView(tracker: tracker)
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .overlay(alignment: .top) {
            VoiceNoteRecordingOverlay()
        }
        .confirmationDialog("End Session", isPresented: $showingExitConfirmation, titleVisibility: .visible) {
            Button("Save") {
                sessionTracker?.stopSession()
            }
            Button("Discard", role: .destructive) {
                sessionTracker?.discardSession()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save or discard this session?")
        }
        .alert("Vehicle Detected", isPresented: vehicleAlertBinding) {
            Button("Stop & Save") {
                sessionTracker?.stopSession()
            }
            Button("Keep Tracking", role: .cancel) {
                sessionTracker?.dismissVehicleAlert()
            }
        } message: {
            Text("It looks like you're traveling at vehicle speed. Would you like to stop tracking?")
        }
        .fullScreenCover(isPresented: fallAlertBinding) {
            if emergencyAlertSent {
                EmergencyAlertSentView(
                    emergencyContacts: emergencyContacts,
                    onDismiss: {
                        sessionTracker?.confirmFallOK()
                        emergencyAlertSent = false
                    },
                    onCallContact: { contact in
                        if let url = contact.callURL {
                            UIApplication.shared.open(url)
                        }
                    }
                )
            } else {
                FallAlertView(
                    countdownSeconds: sessionTracker?.fallAlertCountdown ?? 30,
                    onConfirmOK: {
                        sessionTracker?.confirmFallOK()
                    },
                    onRequestEmergency: {
                        sessionTracker?.requestEmergencyHelp()
                        emergencyAlertSent = true
                    }
                )
            }
        }
        .onChange(of: sessionTracker?.fallAlertCountdown ?? 30) { _, newValue in
            if newValue <= 0 && (sessionTracker?.showingFallAlert ?? false) {
                emergencyAlertSent = true
            }
        }
    }

    /// Binding to vehicle alert state in SessionTracker
    private var vehicleAlertBinding: Binding<Bool> {
        Binding(
            get: { sessionTracker?.showingVehicleAlert ?? false },
            set: { _ in sessionTracker?.dismissVehicleAlert() }
        )
    }

    /// Binding to fall alert state in SessionTracker
    private var fallAlertBinding: Binding<Bool> {
        Binding(
            get: { sessionTracker?.showingFallAlert ?? false },
            set: { newValue in
                if !newValue {
                    sessionTracker?.confirmFallOK()
                    emergencyAlertSent = false
                }
            }
        )
    }
}

#Preview {
    let locManager = LocationManager()
    let gpsTracker = GPSSessionTracker(locationManager: locManager)
    TrackingView()
        .environment(locManager)
        .environment(gpsTracker)
        .environment(SessionTracker(locationManager: locManager, gpsTracker: gpsTracker))
        .modelContainer(for: [FlatworkExercise.self, PoleworkExercise.self], inMemory: true)
}
