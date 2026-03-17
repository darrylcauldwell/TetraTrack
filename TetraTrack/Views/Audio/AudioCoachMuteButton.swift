//
//  AudioCoachMuteButton.swift
//  TetraTrack
//
//  Reusable mute toggle for audio coaching during active sessions.
//

import SwiftUI
import UIKit

struct AudioCoachMuteButton: View {
    private let audioCoach = AudioCoachManager.shared

    var body: some View {
        Button {
            audioCoach.isMuted.toggle()
            if audioCoach.isMuted {
                audioCoach.stopSpeaking()
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            Image(systemName: audioCoach.isMuted ? "speaker.slash" : "speaker.wave.2")
                .font(.body.weight(.medium))
                .foregroundStyle(audioCoach.isMuted ? .red : .primary)
                .frame(width: 44, height: 44)
                .background(AppColors.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(audioCoach.isMuted ? Color.clear : AppColors.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .accessibleButton(
            audioCoach.isMuted ? "Unmute coaching" : "Mute coaching",
            hint: audioCoach.isMuted ? "Resume voice coaching" : "Silence voice coaching"
        )
    }
}
