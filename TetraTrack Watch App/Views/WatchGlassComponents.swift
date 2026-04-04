//
//  WatchGlassComponents.swift
//  TetraTrack Watch App
//
//  watchOS-adapted glass design system modifiers.
//  Simpler than iOS since Watch is always dark mode.
//

import SwiftUI

// MARK: - Glass Panel Modifier

struct WatchGlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WatchAppColors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: WatchDesignTokens.CornerRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WatchDesignTokens.CornerRadius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Glass Card Modifier

struct WatchGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(WatchAppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: WatchDesignTokens.CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: WatchDesignTokens.CornerRadius.md, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
    }
}

// MARK: - View Extensions

extension View {
    func watchGlassPanel() -> some View {
        modifier(WatchGlassPanel())
    }

    func watchGlassCard() -> some View {
        modifier(WatchGlassCard())
    }
}

// MARK: - Metric Cell

struct WatchMetricCell: View {
    let value: String
    let unit: String
    var icon: String?
    var iconColor: Color = .secondary

    var body: some View {
        VStack(spacing: 2) {
            if let icon {
                HStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(iconColor)
                    Text(value)
                        .font(.headline)
                }
            } else {
                Text(value)
                    .font(.headline)
            }
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
