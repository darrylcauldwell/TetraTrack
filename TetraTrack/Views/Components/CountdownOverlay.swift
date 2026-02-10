//
//  CountdownOverlay.swift
//  TetraTrack
//
//  Countdown overlay before starting a session (like Apple Fitness)
//

import SwiftUI

/// A 3-2-1 countdown overlay shown before starting a session
/// Allows user to cancel if they started by mistake
struct CountdownOverlay: View {
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var countdown: Int = 3
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var countdownTimer: Timer?

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Countdown number with animation
                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(AppColors.primary.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .scaleEffect(scale)

                    // Main number
                    Text("\(countdown)")
                        .scaledFont(size: 120, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(AppColors.primary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.3), value: countdown)
                }

                Text("Get Ready")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                // Cancel button
                Button {
                    countdownTimer?.invalidate()
                    countdownTimer = nil
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 50)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            scale = 1.1
        }

        // Countdown timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                countdownTimer = nil
                // Brief delay then complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}

/// View modifier to add countdown before an action
struct CountdownModifier: ViewModifier {
    @Binding var showCountdown: Bool
    let onComplete: () -> Void

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showCountdown) {
                CountdownOverlay(
                    onComplete: {
                        showCountdown = false
                        onComplete()
                    },
                    onCancel: {
                        showCountdown = false
                    }
                )
                .presentationBackground(.clear)
            }
    }
}

extension View {
    /// Shows a 3-2-1 countdown overlay before executing an action
    func countdown(isPresented: Binding<Bool>, onComplete: @escaping () -> Void) -> some View {
        modifier(CountdownModifier(showCountdown: isPresented, onComplete: onComplete))
    }
}

#Preview {
    CountdownOverlay(
        onComplete: { print("Complete!") },
        onCancel: { print("Cancelled") }
    )
}
