//
//  HorseRowView.swift
//  TrackRide
//
//  List row component for displaying a horse

import SwiftUI

struct HorseRowView: View {
    let horse: Horse

    var body: some View {
        HStack(spacing: 14) {
            HorseAvatarView(horse: horse, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(horse.name.isEmpty ? "Unnamed Horse" : horse.name)
                    .font(.headline)

                if !horse.breed.isEmpty {
                    Text(horse.breed)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    List {
        HorseRowView(horse: Horse())
    }
}
