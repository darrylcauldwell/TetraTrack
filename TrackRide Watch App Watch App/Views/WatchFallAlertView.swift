//
//  WatchFallAlertView.swift
//  TrackRide Watch App
//
//  Fall detection alert view with glove-friendly controls
//

import SwiftUI

struct WatchFallAlertView: View {
    @Bindable var fallManager: WatchFallDetectionManager
    @State private var isPulsing: Bool = false

    var body: some View {
        ZStack {
            // Red background with gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.red.opacity(0.9), Color.red.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Warning icon with pulse animation
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                // Title
                Text("Fall Detected")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                // Countdown display
                Text("\(fallManager.countdownSeconds)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("seconds until alert")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()
                    .frame(height: 8)

                // I'm OK button - large and prominent
                Button(action: {
                    HapticManager.shared.playSuccessHaptic()
                    fallManager.confirmOK()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                        Text("I'm OK")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Get Help button
                Button(action: {
                    HapticManager.shared.playStopHaptic()
                    fallManager.requestEmergency()
                }) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                        Text("Get Help")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .onAppear {
            isPulsing = true
        }
    }
}

#Preview {
    WatchFallAlertView(fallManager: WatchFallDetectionManager.shared)
}
