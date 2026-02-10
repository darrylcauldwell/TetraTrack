//
//  FallAlertView.swift
//  TetraTrack
//
//  "Are you OK?" prompt with countdown timer
//

import SwiftUI

struct FallAlertView: View {
    let countdownSeconds: Int
    let onConfirmOK: () -> Void
    let onRequestEmergency: () -> Void

    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // Urgent red background
            Color.red.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Warning icon with pulse
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )

                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 140, height: 140)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(.white)
                }

                // Main question
                Text("Are You OK?")
                    .scaledFont(size: 42, weight: .bold, relativeTo: .title)
                    .foregroundStyle(.white)

                Text("A possible fall was detected")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))

                // Countdown
                VStack(spacing: 8) {
                    Text("Emergency alert in")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("\(countdownSeconds)")
                        .scaledFont(size: 80, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("seconds")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.vertical)

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    // I'm OK button - large and prominent
                    Button(action: onConfirmOK) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                            Text("I'm OK")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Emergency button
                    Button(action: onRequestEmergency) {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.fill")
                                .font(.title2)
                            Text("Get Help Now")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

// MARK: - Emergency Sent View

struct EmergencyAlertSentView: View {
    let emergencyContacts: [SharingRelationship]
    let onDismiss: () -> Void
    let onCallContact: (SharingRelationship) -> Void

    /// Contacts that have a valid phone number and can be called
    private var callableContacts: [SharingRelationship] {
        emergencyContacts
            .filter { $0.callURL != nil }
            .sorted { $0.isPrimaryEmergency && !$1.isPrimaryEmergency }
    }

    var body: some View {
        ZStack {
            Color.orange.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Alert icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 120, height: 120)

                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }

                Text("Alert Sent")
                    .scaledFont(size: 36, weight: .bold, relativeTo: .title)
                    .foregroundStyle(.white)

                if callableContacts.isEmpty {
                    Text("Attempting to notify your emergency contacts via iCloud")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Your emergency contacts have been notified with your location")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Contact call buttons (only for contacts with phone numbers)
                if !callableContacts.isEmpty {
                    VStack(spacing: 12) {
                        Text("Call for help:")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))

                        ForEach(callableContacts.prefix(3), id: \.id) { contact in
                            Button(action: { onCallContact(contact) }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call \(contact.name)")
                                        .fontWeight(.semibold)
                                    if contact.isPrimaryEmergency {
                                        Text("Primary")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.3))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Emergency services fallback
                Button {
                    if let url = URL(string: "tel://999") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "phone.arrow.up.right")
                        Text("Call 999")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)

                // Dismiss button
                Button(action: onDismiss) {
                    Text("I'm OK - Cancel Alert")
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview

#Preview("Fall Alert") {
    FallAlertView(
        countdownSeconds: 25,
        onConfirmOK: {},
        onRequestEmergency: {}
    )
}

#Preview("Emergency Sent") {
    EmergencyAlertSentView(
        emergencyContacts: [],
        onDismiss: {},
        onCallContact: { _ in }
    )
}
