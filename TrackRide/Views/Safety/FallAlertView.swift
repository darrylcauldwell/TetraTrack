//
//  FallAlertView.swift
//  TrackRide
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
                    .font(.system(size: 42, weight: .bold))
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
                        .font(.system(size: 80, weight: .bold, design: .rounded))
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
    let emergencyContacts: [EmergencyContact]
    let onDismiss: () -> Void
    let onCallContact: (EmergencyContact) -> Void

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
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)

                Text("Your emergency contacts have been notified with your location")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Contact buttons
                if !emergencyContacts.isEmpty {
                    VStack(spacing: 12) {
                        Text("Call for help:")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))

                        ForEach(emergencyContacts.prefix(3), id: \.id) { contact in
                            Button(action: { onCallContact(contact) }) {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call \(contact.name)")
                                        .fontWeight(.semibold)
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
