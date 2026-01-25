//
//  FriendShareSheet.swift
//  TrackRide
//
//  Sheet for sharing a training artifact with friends/coaches.
//

import SwiftUI
import SwiftData

struct FriendShareSheet: View {
    @Environment(\.dismiss) private var dismiss

    let artifact: TrainingArtifact
    let friends: [SharingRelationship]

    @State private var selectedFriends: Set<UUID> = []
    @State private var expiryOption: ExpiryOption = .oneDay
    @State private var isSharing = false
    @State private var shareError: String?
    @State private var shareSuccess = false

    enum ExpiryOption: String, CaseIterable {
        case oneHour = "1 Hour"
        case oneDay = "24 Hours"
        case oneWeek = "1 Week"
        case noExpiry = "No Expiry"

        var duration: TimeInterval? {
            switch self {
            case .oneHour: return 3600
            case .oneDay: return 86400
            case .oneWeek: return 604800
            case .noExpiry: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Artifact summary
                artifactSummaryHeader
                    .padding()
                    .background(AppColors.cardBackground)

                Divider()

                if friends.isEmpty {
                    noFriendsView
                } else {
                    // Friend selection list
                    List {
                        Section("Share with") {
                            ForEach(friends) { friend in
                                FriendSelectionRow(
                                    friend: friend,
                                    isSelected: selectedFriends.contains(friend.id),
                                    onToggle: { toggleFriend(friend.id) }
                                )
                            }
                        }

                        Section("Share Duration") {
                            Picker("Expires after", selection: $expiryOption) {
                                ForEach(ExpiryOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }

                        if let error = shareError {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Share Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Share") {
                        shareWithSelectedFriends()
                    }
                    .disabled(selectedFriends.isEmpty || isSharing)
                }
            }
            .overlay {
                if isSharing {
                    ProgressView("Sharing...")
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Shared Successfully", isPresented: $shareSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your session has been shared with \(selectedFriends.count) friend\(selectedFriends.count == 1 ? "" : "s").")
            }
        }
    }

    // MARK: - Views

    private var artifactSummaryHeader: some View {
        HStack(spacing: 12) {
            // Discipline icon
            Image(systemName: artifact.discipline.icon)
                .font(.title2)
                .foregroundStyle(disciplineColor)
                .frame(width: 50, height: 50)
                .background(disciplineColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.name.isEmpty ? artifact.discipline.rawValue : artifact.name)
                    .font(.headline)

                Text(artifact.formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(artifact.formattedDuration, systemImage: "clock")
                    if let distance = artifact.distance {
                        Label(distance.formattedDistance, systemImage: "arrow.left.and.right")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var noFriendsView: some View {
        ContentUnavailableView {
            Label("No Friends", systemImage: "person.2.slash")
        } description: {
            Text("Add friends or coaches first to share your training sessions.")
        } actions: {
            Button("Add Friends") {
                dismiss()
                // Would navigate to friend management
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private var disciplineColor: Color {
        switch artifact.discipline {
        case .riding: return .brown
        case .running: return .green
        case .swimming: return .blue
        case .shooting: return .orange
        }
    }

    private func toggleFriend(_ id: UUID) {
        if selectedFriends.contains(id) {
            selectedFriends.remove(id)
        } else {
            selectedFriends.insert(id)
        }
    }

    private func shareWithSelectedFriends() {
        isSharing = true
        shareError = nil

        Task {
            var successCount = 0
            let sharingCoordinator = UnifiedSharingCoordinator.shared

            for friendID in selectedFriends {
                guard let friend = friends.first(where: { $0.id == friendID }) else { continue }

                do {
                    _ = try await sharingCoordinator.shareArtifact(
                        artifact,
                        with: friend,
                        expiresIn: expiryOption.duration
                    )
                    successCount += 1
                } catch {
                    await MainActor.run {
                        shareError = error.localizedDescription
                    }
                }
            }

            await MainActor.run {
                isSharing = false
                if successCount > 0 {
                    shareSuccess = true
                }
            }
        }
    }
}

// MARK: - Friend Selection Row

struct FriendSelectionRow: View {
    let friend: SharingRelationship
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(isSelected ? .blue : .gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundStyle(.white)
                        } else {
                            Text(friend.name.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundStyle(.gray)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image(systemName: friend.relationshipType.icon)
                            .font(.caption2)
                        Text(friend.relationshipType.displayName)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Permission indicators
                HStack(spacing: 4) {
                    if friend.canViewLiveRiding {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if friend.receiveCompletionAlerts {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Confirmation View

struct ShareConfirmationView: View {
    let artifactName: String
    let friendNames: [String]
    let expiresIn: String?
    let shareURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Shared Successfully!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(artifactName) has been shared with \(friendNames.joined(separator: ", ")).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let expires = expiresIn {
                Text("This share will expire in \(expires).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let url = shareURL {
                ShareLink(item: url) {
                    Label("Copy Share Link", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Existing Shares View

struct ExistingSharesView: View {
    let artifact: TrainingArtifact
    @State private var shares: [ArtifactShare] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currently Shared With")
                .font(.headline)

            if shares.isEmpty {
                Text("Not currently shared")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shares) { share in
                    ExistingShareRow(share: share, onRevoke: {
                        revokeShare(share)
                    })
                }
            }
        }
        .task {
            shares = await UnifiedSharingCoordinator.shared.shares(for: artifact.id)
        }
    }

    private func revokeShare(_ share: ArtifactShare) {
        Task {
            try? await UnifiedSharingCoordinator.shared.revokeArtifactShare(share)
            shares = await UnifiedSharingCoordinator.shared.shares(for: artifact.id)
        }
    }
}

// MARK: - Existing Share Row

struct ExistingShareRow: View {
    let share: ArtifactShare
    let onRevoke: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shared \(share.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)

                if let expires = share.expiresAt {
                    if share.isExpired {
                        Text("Expired")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Expires \(expires.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button("Revoke", role: .destructive, action: onRevoke)
                .font(.caption)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    FriendShareSheet(
        artifact: TrainingArtifact(
            discipline: .running,
            sessionType: "training",
            name: "Morning Run",
            startTime: Date()
        ),
        friends: []
    )
}
