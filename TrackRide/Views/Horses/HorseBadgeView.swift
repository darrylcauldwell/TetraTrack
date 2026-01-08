//
//  HorseBadgeView.swift
//  TrackRide
//
//  Compact badge showing horse avatar and name for ride views

import SwiftUI

struct HorseBadgeView: View {
    let horse: Horse

    var body: some View {
        HStack(spacing: 8) {
            HorseAvatarView(horse: horse, size: 24)

            Text(horse.name.isEmpty ? "Horse" : horse.name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.cardBackground)
        .clipShape(Capsule())
    }
}

#Preview {
    HorseBadgeView(horse: Horse())
        .padding()
}
