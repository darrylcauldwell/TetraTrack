//
//  ChildDashboardView.swift
//  TrackRide
//
//  Child's (athlete's) view with full metrics, friend sharing, and competition editing.
//

import SwiftUI
import SwiftData

struct ChildDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var syncService = ArtifactSyncService.shared
    @State private var friendService = FriendSharingService.shared

    @Query(sort: \SharingRelationship.addedDate, order: .reverse)
    private var friendRelationships: [SharingRelationship]

    @State private var artifacts: [TrainingArtifact] = []
    @State private var competitions: [SharedCompetition] = []
    @State private var isLoading = true
    @State private var showingFriendManagement = false
    @State private var selectedArtifactForSharing: TrainingArtifact?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Sync status
                    SyncStatusBanner(syncService: syncService)
                        .padding(.horizontal)

                    // Quick stats
                    QuickStatsGrid(artifacts: todayArtifacts, weekArtifacts: thisWeekArtifacts)
                        .padding(.horizontal)

                    // Recent sessions with full metrics
                    RecentSessionsList(
                        artifacts: artifacts,
                        onShare: { artifact in
                            selectedArtifactForSharing = artifact
                        }
                    )
                    .padding(.horizontal)

                    // Upcoming competitions
                    if !upcomingCompetitions.isEmpty {
                        UpcomingCompetitionsSection(competitions: upcomingCompetitions)
                            .padding(.horizontal)
                    }

                    // Friend sharing status
                    FriendSharingStatusCard(
                        relationships: friendRelationships,
                        activeShareCount: friendService.activeShares.count,
                        onManageFriends: { showingFriendManagement = true }
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("My Training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingFriendManagement = true }) {
                        Image(systemName: "person.2")
                    }
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingFriendManagement) {
                FriendManagementView()
            }
            .sheet(item: $selectedArtifactForSharing) { artifact in
                FriendShareSheet(
                    artifact: artifact,
                    friends: friendRelationships
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var todayArtifacts: [TrainingArtifact] {
        let calendar = Calendar.current
        return artifacts.filter { calendar.isDateInToday($0.startTime) }
    }

    private var thisWeekArtifacts: [TrainingArtifact] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return artifacts.filter { $0.startTime >= weekAgo }
    }

    private var upcomingCompetitions: [SharedCompetition] {
        competitions.filter { $0.isUpcoming }.sorted { $0.date < $1.date }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true

        // Fetch local artifacts and sync with CloudKit
        artifacts = await syncService.fetchArtifacts()
        competitions = await syncService.fetchCompetitions()

        // Process pending sync operations
        await syncService.processPendingOperations()

        isLoading = false
    }
}

// MARK: - Sync Status Banner

struct SyncStatusBanner: View {
    let syncService: ArtifactSyncService

    var body: some View {
        HStack {
            if syncService.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !syncService.isOnline {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.orange)
            } else if syncService.pendingOperationCount > 0 {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }

            Text(syncService.syncStatusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Quick Stats Grid

struct QuickStatsGrid: View {
    let artifacts: [TrainingArtifact]
    let weekArtifacts: [TrainingArtifact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickStatCard(
                    value: "\(artifacts.count)",
                    label: "Sessions",
                    icon: "flame.fill",
                    color: .orange
                )

                QuickStatCard(
                    value: totalDuration,
                    label: "Active",
                    icon: "clock.fill",
                    color: .blue
                )

                QuickStatCard(
                    value: "\(weekArtifacts.count)",
                    label: "This Week",
                    icon: "calendar",
                    color: .purple
                )
            }
        }
    }

    private var totalDuration: String {
        let total = artifacts.reduce(0) { $0 + $1.duration }
        if total < 60 {
            return "\(Int(total))s"
        } else if total < 3600 {
            return "\(Int(total / 60))m"
        } else {
            return String(format: "%.1fh", total / 3600)
        }
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recent Sessions List

struct RecentSessionsList: View {
    let artifacts: [TrainingArtifact]
    let onShare: (TrainingArtifact) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)

            if artifacts.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(artifacts.prefix(5)) { artifact in
                    FullMetricsArtifactRow(artifact: artifact, onShare: { onShare(artifact) })
                }
            }
        }
    }
}

// MARK: - Full Metrics Artifact Row

struct FullMetricsArtifactRow: View {
    let artifact: TrainingArtifact
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Discipline icon
                Image(systemName: artifact.discipline.icon)
                    .font(.title3)
                    .foregroundStyle(disciplineColor)
                    .frame(width: 36, height: 36)
                    .background(disciplineColor.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(artifact.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Share button
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            // Metrics row
            HStack(spacing: 16) {
                MetricPill(icon: "clock", value: artifact.formattedDuration)

                if let distance = artifact.distance {
                    MetricPill(icon: "arrow.left.and.right", value: distance.formattedDistance)
                }

                if let hr = artifact.averageHeartRate {
                    MetricPill(icon: "heart.fill", value: "\(hr) bpm")
                }

                if artifact.personalBest {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            // Sync status indicator
            if artifact.syncStatus != .synced {
                HStack(spacing: 4) {
                    Image(systemName: artifact.syncStatus == .pending ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle")
                        .font(.caption2)
                    Text(artifact.syncStatus == .pending ? "Pending sync" : "Sync conflict")
                        .font(.caption2)
                }
                .foregroundStyle(artifact.syncStatus == .pending ? .blue : .orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var disciplineColor: Color {
        switch artifact.discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }
}

// MARK: - Metric Pill

struct MetricPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }
}

// MARK: - Upcoming Competitions Section

struct UpcomingCompetitionsSection: View {
    let competitions: [SharedCompetition]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Competitions")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    // Competition calendar view
                    Text("Competition Calendar")
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            ForEach(competitions.prefix(3)) { competition in
                UpcomingCompetitionRow(competition: competition)
            }
        }
    }
}

// MARK: - Upcoming Competition Row

struct UpcomingCompetitionRow: View {
    let competition: SharedCompetition

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(competition.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(competition.venue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(competition.formattedDaysUntil)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                Text(competition.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Friend Sharing Status Card

struct FriendSharingStatusCard: View {
    let relationships: [SharingRelationship]
    let activeShareCount: Int
    let onManageFriends: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sharing")
                    .font(.headline)

                Spacer()

                Button("Manage", action: onManageFriends)
                    .font(.caption)
            }

            if relationships.isEmpty {
                Text("No friends or coaches added yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(spacing: 12) {
                    VStack {
                        Text("\(relationships.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Friends")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 40)

                    VStack {
                        Text("\(activeShareCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Active Shares")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Friend Management View

struct FriendManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SharingRelationship.addedDate, order: .reverse)
    private var relationships: [SharingRelationship]

    @State private var showingAddFriend = false

    var body: some View {
        NavigationStack {
            List {
                if relationships.isEmpty {
                    ContentUnavailableView(
                        "No Friends Added",
                        systemImage: "person.2",
                        description: Text("Add friends or coaches to share your training progress")
                    )
                } else {
                    ForEach(relationships) { relationship in
                        FriendRow(relationship: relationship)
                    }
                    .onDelete(perform: deleteRelationships)
                }
            }
            .navigationTitle("Friends & Coaches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddFriend = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
        }
    }

    private func deleteRelationships(at offsets: IndexSet) {
        for index in offsets {
            let relationship = relationships[index]
            Task {
                await FriendSharingService.shared.deleteRelationship(relationship, context: modelContext)
            }
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let relationship: SharingRelationship

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(relationship.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(relationship.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(relationship.relationshipType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Active shares count
            if relationship.activeShareCount > 0 {
                Text("\(relationship.activeShareCount) shared")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var email = ""
    @State private var relationshipType: RelationshipType = .friend

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Info") {
                    TextField("Name", text: $name)
                    TextField("Email (optional)", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Relationship") {
                    Picker("Type", selection: $relationshipType) {
                        ForEach(RelationshipType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        addFriend()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addFriend() {
        _ = FriendSharingService.shared.createRelationship(
            name: name,
            type: relationshipType,
            email: email.isEmpty ? nil : email,
            context: modelContext
        )
        dismiss()
    }
}

#Preview {
    ChildDashboardView()
        .modelContainer(for: SharingRelationship.self, inMemory: true)
}
