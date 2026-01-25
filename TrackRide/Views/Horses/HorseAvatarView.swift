//
//  HorseAvatarView.swift
//  TrackRide
//
//  Reusable circular avatar component for horses

import SwiftUI

struct HorseAvatarView: View {
    let horse: Horse?
    var size: CGFloat = 50

    var body: some View {
        Group {
            if let horse = horse, let photo = horse.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))

                    Image(systemName: "figure.equestrian.sports")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColors.primary.opacity(0.2), lineWidth: 2)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        HorseAvatarView(horse: nil, size: 80)
        HorseAvatarView(horse: nil, size: 50)
        HorseAvatarView(horse: nil, size: 32)
    }
    .padding()
}
