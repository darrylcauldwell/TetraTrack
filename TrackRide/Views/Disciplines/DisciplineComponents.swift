//
//  DisciplineComponents.swift
//  TrackRide
//
//  Shared components for discipline selection views
//

import SwiftUI

// MARK: - Discipline Row

/// A consistent row-style button for discipline type selection
/// Used across Running, Swimming, Shooting, and Riding discipline views
struct DisciplineRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        DisciplineRow(
            title: "Tetrathlon",
            subtitle: "1500m timed trial",
            icon: "stopwatch.fill",
            color: .purple
        ) {}

        DisciplineRow(
            title: "Training",
            subtitle: "Free swim practice",
            icon: "figure.pool.swim",
            color: .blue
        ) {}
    }
    .padding()
}
