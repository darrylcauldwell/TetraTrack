//
//  DisciplinesView.swift
//  TrackRide
//
//  Hub view for all Tetrathlon disciplines
//

import SwiftUI

struct DisciplinesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.viewContext) private var viewContext

    /// Grid columns based on device size
    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            // iPad: 3 columns for better use of space
            return [
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md),
                GridItem(.flexible(), spacing: Spacing.md)
            ]
        } else {
            // iPhone: 1 column
            return [GridItem(.flexible())]
        }
    }

    /// Welcome banner shown on iPad for better use of horizontal space
    private var iPadWelcomeBanner: some View {
        HStack(spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("TetraTrack")
                    .font(.largeTitle.bold())
                Text(viewContext.isReadOnly ? "Review your training sessions" : "Track your tetrathlon training")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Quick action buttons on iPad
            if !viewContext.isReadOnly {
                HStack(spacing: Spacing.md) {
                    NavigationLink(destination: RidingView()) {
                        quickActionButton(icon: "figure.equestrian.sports", label: "Ride", color: AppColors.riding)
                    }
                    NavigationLink(destination: RunningView()) {
                        quickActionButton(icon: "figure.run", label: "Run", color: AppColors.running)
                    }
                    NavigationLink(destination: SwimmingView()) {
                        quickActionButton(icon: "figure.pool.swim", label: "Swim", color: AppColors.swimming)
                    }
                    NavigationLink(destination: ShootingView()) {
                        quickActionButton(icon: "target", label: "Shoot", color: AppColors.shooting)
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
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70, height: 70)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // iPad welcome banner
                    if horizontalSizeClass == .regular {
                        iPadWelcomeBanner
                    }

                    LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
                    // MARK: - Capture Disciplines (Hidden on iPad)
                    // These navigation links are hidden in read-only mode (iPad)
                    // as they provide session capture capabilities

                    NavigationLink(destination: RidingView()) {
                        DisciplineCard(
                            title: "Riding",
                            subtitle: "Record a riding session",
                            icon: "figure.equestrian.sports",
                            color: AppColors.riding
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Riding")
                    .accessibilityHint("Record an equestrian riding session with gait detection")
                    .hideInReadOnlyMode()

                    NavigationLink(destination: RunningView()) {
                        DisciplineCard(
                            title: "Running",
                            subtitle: "Record a running session",
                            icon: "figure.run",
                            color: AppColors.running
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Running")
                    .accessibilityHint("Record a running session with pace tracking")
                    .hideInReadOnlyMode()

                    NavigationLink(destination: SwimmingView()) {
                        DisciplineCard(
                            title: "Swimming",
                            subtitle: "Record a swimming session",
                            icon: "figure.pool.swim",
                            color: AppColors.swimming
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Swimming")
                    .accessibilityHint("Record a swimming session with stroke detection")
                    .hideInReadOnlyMode()

                    NavigationLink(destination: ShootingView()) {
                        DisciplineCard(
                            title: "Shooting",
                            subtitle: "Record a shooting session",
                            icon: "target",
                            color: AppColors.shooting
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Shooting")
                    .accessibilityHint("Record a shooting session and scan score cards")
                    .hideInReadOnlyMode()

                    // MARK: - Review Accessible Items
                    // These navigation links are available on all devices including iPad
                    // as they provide review/browse capabilities without session capture

                    NavigationLink(destination: SessionHistoryView()) {
                        DisciplineCard(
                            title: "Training History",
                            subtitle: "Review all sessions and insights",
                            icon: "clock.arrow.circlepath",
                            color: AppColors.neutralGray
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Training History")
                    .accessibilityHint("Review past sessions and training insights across all disciplines")

                    // Skills training involves capture, hidden on iPad
                    NavigationLink(destination: UnifiedTrainingView()) {
                        DisciplineCard(
                            title: "Skills",
                            subtitle: "Perform off-discipline training drills",
                            icon: "figure.run.circle",
                            color: AppColors.mint
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skills Training")
                    .accessibilityHint("Access training drills for all disciplines")
                    .hideInReadOnlyMode()

                    NavigationLink(destination: CompetitionCalendarView()) {
                        DisciplineCard(
                            title: "Competitions",
                            subtitle: "View competition calendar and results",
                            icon: "calendar",
                            color: AppColors.purple
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Competitions")
                    .accessibilityHint("View upcoming competitions and past results")

                    NavigationLink(destination: TaskListView()) {
                        DisciplineCard(
                            title: "Tasks",
                            subtitle: "Manage training and competition tasks",
                            icon: "checklist",
                            color: AppColors.cardTeal
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tasks")
                    .accessibilityHint("Manage training and competition preparation tasks")

                    NavigationLink(destination: FamilyView()) {
                        DisciplineCard(
                            title: "Live Sharing",
                            subtitle: "Family & emergency contacts",
                            icon: "location.fill.viewfinder",
                            color: AppColors.cyan
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Live Sharing")
                    .accessibilityHint("Share location with family and emergency contacts")
                    }
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
                }
            }
        }
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
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
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
