//
//  DisciplinesView.swift
//  TetraTrack
//
//  Hub view — Riding + Shooting capture, Competitions, recent workouts feed
//

import SwiftUI

struct DisciplinesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // iPad welcome banner
                    if horizontalSizeClass == .regular {
                        iPadWelcomeBanner
                    }

                    // MARK: - Capture Disciplines
                    if !viewContext.isReadOnly {
                        captureSection
                    }

                    // MARK: - Competitions
                    competitionsSection

                    // MARK: - Training
                    trainingSection

                    // MARK: - Session History
                    sessionHistorySection
                }
                .adaptivePadding(horizontalSizeClass)
                .padding(.top, Spacing.md)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    // MARK: - Capture Section

    private var captureSection: some View {
        let columns = horizontalSizeClass == .regular
            ? [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]
            : [GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: Spacing.md) {
            NavigationLink(destination: RidingView()) {
                DisciplineCard(
                    title: "Riding",
                    subtitle: "Record a riding session",
                    icon: "figure.equestrian.sports",
                    color: AppColors.riding
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: RunningGuideView()) {
                DisciplineCard(
                    title: "Running",
                    subtitle: "min/400m pace tracking",
                    icon: "figure.run",
                    color: AppColors.running
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: SwimmingGuideView()) {
                DisciplineCard(
                    title: "Swimming",
                    subtitle: "Lap and stroke counting",
                    icon: "figure.pool.swim",
                    color: AppColors.swimming
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: WalkingGuideView()) {
                DisciplineCard(
                    title: "Walking",
                    subtitle: "Steps per minute tracking",
                    icon: "figure.walk",
                    color: AppColors.walking
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ShootingView()) {
                DisciplineCard(
                    title: "Shooting",
                    subtitle: "Steadiness and target scoring",
                    icon: "target",
                    color: AppColors.shooting
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Competitions Section

    private var competitionsSection: some View {
        NavigationLink(destination: CompetitionHubView()) {
            DisciplineCard(
                title: "Competitions",
                subtitle: "Calendar, competition day & tasks",
                icon: "calendar",
                color: AppColors.purple
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Training

    private var trainingSection: some View {
        NavigationLink(destination: TrainingHubView()) {
            DisciplineCard(
                title: "Training",
                subtitle: "Training load and drills",
                icon: "figure.run.circle",
                color: AppColors.cardOrange
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session History

    private var sessionHistorySection: some View {
        NavigationLink(destination: SessionHistoryView()) {
            DisciplineCard(
                title: "Session History",
                subtitle: "Sessions and session insights",
                icon: "clock.arrow.circlepath",
                color: AppColors.neutralGray
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - iPad Banner

    private var iPadWelcomeBanner: some View {
        HStack(spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("TetraTrack")
                    .font(.largeTitle.bold())
                Text(viewContext.isReadOnly ? "Review your training" : "Track your tetrathlon training")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !viewContext.isReadOnly {
                HStack(spacing: Spacing.md) {
                    NavigationLink(destination: RidingView()) {
                        quickActionButton(icon: "figure.equestrian.sports", label: "Ride", color: AppColors.riding)
                    }
                    NavigationLink(destination: ShootingView()) {
                        quickActionButton(icon: "target", label: "Shoot", color: AppColors.shooting)
                    }
                    NavigationLink(destination: CompetitionHubView()) {
                        quickActionButton(icon: "calendar", label: "Compete", color: AppColors.purple)
                    }
                }
            }
        }
        .padding(Spacing.xl)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
    }

    private func quickActionButton(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
            Text(label.localized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70, height: 70)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

}

struct DisciplineCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let title: String
    var subtitle: String = ""
    let icon: String
    let color: Color

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Larger vertical card layout
                iPadCard
            } else {
                // iPhone: Compact horizontal layout
                iPhoneCard
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
    }

    private var iPadCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(color)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title.localized)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .padding(Spacing.lg)
    }

    private var iPhoneCard: some View {
        HStack(spacing: Spacing.lg) {
            // Icon on the left
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)
                .frame(width: TapTarget.standard)

            // Text on the right
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title.localized)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
    }
}

#Preview {
    DisciplinesView()
}
