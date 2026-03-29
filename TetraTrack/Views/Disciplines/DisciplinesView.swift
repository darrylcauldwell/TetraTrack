//
//  DisciplinesView.swift
//  TetraTrack
//
//  Hub view — Riding + Shooting capture, Competitions, recent workouts feed
//

import SwiftUI
import HealthKit

struct DisciplinesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.viewContext) private var viewContext
    private let externalWorkoutService = ExternalWorkoutService.shared

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

                    // MARK: - Recent Workouts Feed
                    recentWorkoutsSection

                    // MARK: - More
                    moreSection
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
            .task {
                await loadRecentWorkouts()
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

            NavigationLink(destination: ShootingView()) {
                DisciplineCard(
                    title: "Shooting",
                    subtitle: "Record a shooting session",
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

    // MARK: - Recent Workouts Feed

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: SessionHistoryView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.primary)
                }
            }

            if externalWorkoutService.workouts.isEmpty && externalWorkoutService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, Spacing.lg)
            } else if externalWorkoutService.workouts.isEmpty {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "figure.mixed.cardio")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No recent workouts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Complete a workout on Apple Watch or start a session above")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
            } else {
                ForEach(externalWorkoutService.workouts.prefix(5)) { workout in
                    NavigationLink(destination: EnrichedWorkoutDetailView(workout: workout)) {
                        recentWorkoutRow(workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
    }

    private func recentWorkoutRow(_ workout: ExternalWorkout) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: workout.activityIcon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(workout.formattedDuration)
                    if let distance = workout.formattedDistance {
                        Text("·")
                        Text(distance)
                    }
                    if let hr = workout.averageHeartRate {
                        Text("·")
                        Text("\(Int(hr)) bpm")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(workout.startDate, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - More Section

    private var moreSection: some View {
        let columns = horizontalSizeClass == .regular
            ? [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]
            : [GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: Spacing.md) {
            NavigationLink(destination: SessionHistoryView()) {
                DisciplineCard(
                    title: "Training History",
                    subtitle: "Sessions and session insights",
                    icon: "clock.arrow.circlepath",
                    color: AppColors.neutralGray
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: TrainingLoadDashboardView()) {
                DisciplineCard(
                    title: "Training Load",
                    subtitle: "Monitor fitness, fatigue, and form",
                    icon: "chart.line.uptrend.xyaxis",
                    color: AppColors.cardOrange
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: UnifiedTrainingView()) {
                DisciplineCard(
                    title: "Drills",
                    subtitle: "Off-discipline training drills",
                    icon: "figure.run.circle",
                    color: AppColors.mint
                )
            }
            .buttonStyle(.plain)
            .hideInReadOnlyMode()

            NavigationLink(destination: FamilyView()) {
                DisciplineCard(
                    title: "Live Sharing",
                    subtitle: "Family & emergency contacts",
                    icon: "location.fill.viewfinder",
                    color: AppColors.cyan
                )
            }
            .buttonStyle(.plain)
        }
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

    // MARK: - Data Loading

    private func loadRecentWorkouts() async {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        await externalWorkoutService.fetchWorkouts(from: twoWeeksAgo, to: Date())
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
