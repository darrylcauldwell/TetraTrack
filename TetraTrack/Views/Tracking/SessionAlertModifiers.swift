//
//  SessionAlertModifiers.swift
//  TetraTrack
//
//  Reusable view modifiers for session safety alerts and overlays.
//  Extracted from TrackingView for use in SessionChromeView.
//

import SwiftUI
import SwiftData

// MARK: - Vehicle Detection Alert

struct VehicleDetectionAlertModifier: ViewModifier {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?

    private var vehicleAlertBinding: Binding<Bool> {
        Binding(
            get: { tracker?.showingVehicleAlert ?? false },
            set: { _ in tracker?.dismissVehicleAlert() }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert("Vehicle Detected", isPresented: vehicleAlertBinding) {
                Button("Stop & Save") {
                    tracker?.stopSession()
                }
                Button("Keep Tracking", role: .cancel) {
                    tracker?.dismissVehicleAlert()
                }
            } message: {
                Text("It looks like you're traveling at vehicle speed. Would you like to stop tracking?")
            }
    }
}

// MARK: - Fall Detection Cover

struct FallDetectionCoverModifier: ViewModifier {
    @Environment(SessionTracker.self) private var tracker: SessionTracker?
    @Query(filter: #Predicate<SharingRelationship> { $0.receiveFallAlerts == true && $0.phoneNumber != nil }) private var emergencyContacts: [SharingRelationship]
    @State private var emergencyAlertSent = false

    private var fallAlertBinding: Binding<Bool> {
        Binding(
            get: { tracker?.showingFallAlert ?? false },
            set: { newValue in
                if !newValue {
                    tracker?.confirmFallOK()
                    emergencyAlertSent = false
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: fallAlertBinding) {
                if emergencyAlertSent {
                    EmergencyAlertSentView(
                        emergencyContacts: emergencyContacts,
                        onDismiss: {
                            tracker?.confirmFallOK()
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
                        countdownSeconds: tracker?.fallAlertCountdown ?? 30,
                        onConfirmOK: {
                            tracker?.confirmFallOK()
                        },
                        onRequestEmergency: {
                            tracker?.requestEmergencyHelp()
                            emergencyAlertSent = true
                        }
                    )
                }
            }
            .onChange(of: tracker?.fallAlertCountdown ?? 30) { _, newValue in
                if newValue <= 0 && (tracker?.showingFallAlert ?? false) {
                    emergencyAlertSent = true
                }
            }
    }
}

// MARK: - Voice Note Recording Overlay

struct VoiceNoteOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VoiceNoteRecordingOverlay()
            }
    }
}

// MARK: - View Extensions

extension View {
    func vehicleDetectionAlert() -> some View {
        modifier(VehicleDetectionAlertModifier())
    }

    func fallDetectionCover() -> some View {
        modifier(FallDetectionCoverModifier())
    }

    func voiceNoteOverlay() -> some View {
        modifier(VoiceNoteOverlayModifier())
    }
}
