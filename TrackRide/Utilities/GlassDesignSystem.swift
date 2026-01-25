//
//  GlassDesignSystem.swift
//  TrackRide
//
//  Liquid Glass Design System - iOS 26 Native
//  All UI components built with glass-first principles:
//  - Translucent materials with depth
//  - Subtle blur and vibrancy
//  - Floating, layered elements
//  - Soft shadows and borders
//  - Fluid animations
//

import SwiftUI

// MARK: - Glass Material Levels

/// Defines the intensity of glass effect
/// Uses AppColors for consistent theming across the app
enum GlassMaterial {
    case ultraThin    // Subtle, barely visible
    case thin         // Light translucency
    case regular      // Standard glass effect
    case thick        // More opaque
    case chromatic    // Color-tinted glass

    var color: Color {
        switch self {
        case .ultraThin: return AppColors.cardBackground
        case .thin: return AppColors.cardBackground
        case .regular: return AppColors.elevatedSurface
        case .thick: return AppColors.elevatedSurface
        case .chromatic: return AppColors.cardBackground
        }
    }
}

// MARK: - Glass Card View Modifier

struct GlassCard: ViewModifier {
    let material: GlassMaterial
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let borderWidth: CGFloat
    let padding: CGFloat

    init(
        material: GlassMaterial = .regular,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        borderWidth: CGFloat = 0.5,
        padding: CGFloat = 16
    ) {
        self.material = material
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.borderWidth = borderWidth
        self.padding = padding
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(material.color)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: borderWidth
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: shadowRadius, x: 0, y: 4)
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    let material: GlassMaterial
    let tint: Color

    init(material: GlassMaterial = .thin, tint: Color = AppColors.primary) {
        self.material = material
        self.tint = tint
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(material.color)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(configuration.isPressed ? 0.2 : 0.1))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: tint.opacity(0.2), radius: configuration.isPressed ? 4 : 8, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glass Floating Button (Large)

struct GlassFloatingButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    init(
        icon: String,
        color: Color = AppColors.primary,
        size: CGFloat = 200,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: size + 20, height: size + 20)
                    .blur(radius: 20)

                // Glass background
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: size, height: size)

                // Color fill
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size - 8, height: size - 8)

                // Inner highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: size - 8, height: size - 8)

                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundStyle(.white)

                // Glass rim
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: size - 4, height: size - 4)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: color.opacity(0.4), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Glass Stat Card

struct GlassStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            // Icon with glass bubble
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .modifier(GlassCard(material: .thin, cornerRadius: 16, shadowRadius: 6, padding: 16))
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.primary)
            }
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    let progress: Double
    let leftColor: Color
    let rightColor: Color
    let height: CGFloat

    init(
        progress: Double,
        leftColor: Color = AppColors.turnLeft,
        rightColor: Color = AppColors.turnRight,
        height: CGFloat = 28
    ) {
        self.progress = progress
        self.leftColor = leftColor
        self.rightColor = rightColor
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(AppColors.cardBackground)

                // Progress bars
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [leftColor, leftColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 0) {
                    Spacer(minLength: 0)

                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [rightColor.opacity(0.8), rightColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (1 - progress))
                }

                // Glass overlay
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        }
        .frame(height: height)
    }
}

// MARK: - Glass Chip

struct GlassChip: View {
    let text: String
    let icon: String?
    let color: Color

    init(_ text: String, icon: String? = nil, color: Color = AppColors.primary) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .background(AppColors.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Glass Tab Bar Item

struct GlassTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? icon : icon.replacingOccurrences(of: ".fill", with: ""))
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? AppColors.primary : .secondary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(isSelected ? AppColors.primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            isSelected ?
            AnyShapeStyle(AppColors.primary.opacity(0.1)) :
            AnyShapeStyle(.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glass card styling
    func glassCard(
        material: GlassMaterial = .regular,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10
    ) -> some View {
        modifier(GlassCard(
            material: material,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius
        ))
    }

    /// Apply glass card with custom padding
    func glassCard(
        material: GlassMaterial = .regular,
        cornerRadius: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        padding: CGFloat
    ) -> some View {
        modifier(GlassCard(
            material: material,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            padding: padding
        ))
    }

    /// Apply subtle glass effect for list sections
    func glassList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppColors.cardBackground)
    }

    /// Apply floating glass panel style
    func glassPanel() -> some View {
        self
            .background(AppColors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Glass Navigation Style

struct GlassNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(AppColors.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func glassNavigation() -> some View {
        modifier(GlassNavigationStyle())
    }
}

// MARK: - Preview

#Preview("Glass Components") {
    ScrollView {
        VStack(spacing: 24) {
            GlassSectionHeader("Overview", icon: "chart.bar.fill")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                GlassStatCard(title: "Distance", value: "12.5 km", icon: "arrow.left.and.right", tint: AppColors.cardBlue)
                GlassStatCard(title: "Duration", value: "1:23", icon: "clock.fill", tint: AppColors.cardOrange)
            }
            .padding(.horizontal)

            GlassChip("Trotting", icon: "figure.equestrian.sports", color: AppColors.trot)

            GlassProgressBar(progress: 0.6)
                .padding(.horizontal)

            GlassFloatingButton(icon: "play.fill", color: AppColors.primary) {}
        }
        .padding(.vertical)
    }
    .background(Color.black)
}
