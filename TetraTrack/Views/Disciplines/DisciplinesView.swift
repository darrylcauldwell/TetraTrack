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

                    competitionsSection
                    trainingDrillsSection
                    exerciseLibrarySection
                    liveSharingSection
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

    // MARK: - Cards

    private var competitionsSection: some View {
        NavigationLink(destination: CompetitionHubView()) {
            DisciplineCard(title: "Competitions", subtitle: "Calendar, competition day & tasks", icon: "calendar", color: AppColors.purple)
        }
        .buttonStyle(.plain)
    }

    private var trainingLoadSection: some View {
        NavigationLink(destination: TrainingLoadDashboardView()) {
            DisciplineCard(title: "Training Load", subtitle: "Weekly volume and recovery trends", icon: "chart.bar.fill", color: AppColors.cardOrange)
        }
        .buttonStyle(.plain)
    }

    private var trainingDrillsSection: some View {
        NavigationLink(destination: UnifiedTrainingView()) {
            DisciplineCard(title: "Training", subtitle: "Riding, shooting, and fitness drills", icon: "figure.run.circle", color: .blue)
        }
        .buttonStyle(.plain)
    }

    private var exerciseLibrarySection: some View {
        NavigationLink(destination: ExerciseLibraryView()) {
            DisciplineCard(title: "Schooling", subtitle: "Flatwork, polework, and groundwork", icon: "book.fill", color: .indigo)
        }
        .buttonStyle(.plain)
    }

    private var liveSharingSection: some View {
        NavigationLink(destination: FamilyView()) {
            DisciplineCard(title: "Live Sharing", subtitle: "Share location with family", icon: "location.fill.viewfinder", color: .cyan)
        }
        .buttonStyle(.plain)
    }

    private var sessionHistorySection: some View {
        NavigationLink(destination: SessionHistoryView()) {
            DisciplineCard(title: "Session History", subtitle: "Sessions and session insights", icon: "clock.arrow.circlepath", color: AppColors.neutralGray)
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

            NavigationLink(destination: CompetitionHubView()) {
                quickActionButton(icon: "calendar", label: "Compete", color: AppColors.purple)
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
