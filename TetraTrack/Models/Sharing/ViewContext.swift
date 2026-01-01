//
//  ViewContext.swift
//  TetraTrack
//
//  Context for role-aware and platform-aware view rendering.
//  Enables read-only mode on iPad while sharing views with iPhone.
//

import SwiftUI

// MARK: - View Mode

/// The interaction mode for the current view context.
enum ViewMode: String, Sendable {
    case capture    // Full capture and editing (iPhone primary)
    case review     // Read-only review (iPad, TV, CarPlay)
}

// MARK: - User Role

/// The role of the current user viewing the data.
enum UserRole: String, Sendable {
    case athlete    // Viewing own data
    case parent     // Viewing linked child's data
    case coach      // Future: viewing coached athlete's data
}

// MARK: - View Context

/// Context object providing role and mode information to views.
/// Injected via environment to enable conditional UI rendering.
@Observable
final class ViewContext: Sendable {

    // MARK: - Properties

    /// Current interaction mode
    let mode: ViewMode

    /// Current user role relative to displayed data
    let role: UserRole

    /// The athlete whose data is being displayed
    let athleteName: String?

    /// Last time data was synced from CloudKit
    var lastSyncedAt: Date?

    /// Whether currently syncing
    var isSyncing: Bool = false

    /// Sync error if last sync failed
    var syncError: String?

    // MARK: - Computed Properties

    /// Whether capture actions should be available
    var canCapture: Bool {
        mode == .capture && role == .athlete
    }

    /// Whether editing actions should be available
    var canEdit: Bool {
        mode == .capture && role == .athlete
    }

    /// Whether this is a read-only context
    var isReadOnly: Bool {
        mode == .review || role != .athlete
    }

    /// Human-readable sync status
    var syncStatusText: String {
        if isSyncing {
            return "Syncing..."
        }
        if let error = syncError {
            return "Sync failed: \(error)"
        }
        guard let lastSync = lastSyncedAt else {
            return "Not synced"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    }

    /// Whether sync status indicates a problem
    var hasSyncIssue: Bool {
        syncError != nil || lastSyncedAt == nil
    }

    // MARK: - Initialization

    init(
        mode: ViewMode,
        role: UserRole,
        athleteName: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.mode = mode
        self.role = role
        self.athleteName = athleteName
        self.lastSyncedAt = lastSyncedAt
    }

    // MARK: - Factory Methods

    /// Context for athlete using their own device (iPhone capture mode)
    static func athleteCapture() -> ViewContext {
        ViewContext(mode: .capture, role: .athlete)
    }

    /// Context for parent viewing child's data (iPad review mode)
    static func parentReview(childName: String, lastSyncedAt: Date? = nil) -> ViewContext {
        ViewContext(
            mode: .review,
            role: .parent,
            athleteName: childName,
            lastSyncedAt: lastSyncedAt
        )
    }

    /// Context for reviewing own data on secondary device
    static func athleteReview(lastSyncedAt: Date? = nil) -> ViewContext {
        ViewContext(
            mode: .review,
            role: .athlete,
            lastSyncedAt: lastSyncedAt
        )
    }

    // MARK: - Sync Status Updates

    func beginSync() {
        isSyncing = true
        syncError = nil
    }

    func completeSync() {
        isSyncing = false
        lastSyncedAt = Date()
        syncError = nil
    }

    func failSync(error: String) {
        isSyncing = false
        syncError = error
    }
}

// MARK: - Environment Key

private struct ViewContextKey: EnvironmentKey {
    static let defaultValue: ViewContext = .athleteCapture()
}

extension EnvironmentValues {
    var viewContext: ViewContext {
        get { self[ViewContextKey.self] }
        set { self[ViewContextKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Sets the view context for this view hierarchy.
    func viewContext(_ context: ViewContext) -> some View {
        environment(\.viewContext, context)
    }
}

// MARK: - Conditional View Modifiers

extension View {
    /// Hides this view when in read-only context.
    @ViewBuilder
    func hideInReadOnlyMode() -> some View {
        modifier(HideInReadOnlyModifier())
    }

    /// Disables this view when in read-only context.
    @ViewBuilder
    func disableInReadOnlyMode() -> some View {
        modifier(DisableInReadOnlyModifier())
    }
}

private struct HideInReadOnlyModifier: ViewModifier {
    @Environment(\.viewContext) private var viewContext

    func body(content: Content) -> some View {
        if !viewContext.isReadOnly {
            content
        }
    }
}

private struct DisableInReadOnlyModifier: ViewModifier {
    @Environment(\.viewContext) private var viewContext

    func body(content: Content) -> some View {
        content.disabled(viewContext.isReadOnly)
    }
}

// MARK: - Sync Status View

/// Reusable sync status indicator for headers.
struct SyncStatusView: View {
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        HStack(spacing: 6) {
            if viewContext.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            } else if viewContext.hasSyncIssue {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
            }

            Text(viewContext.syncStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Athlete Header View

/// Header showing which athlete's data is being displayed.
struct AthleteHeaderView: View {
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        if let name = viewContext.athleteName, viewContext.role == .parent {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.blue)
                Text("\(name)'s Training")
                    .font(.headline)
                Spacer()
                SyncStatusView()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }
}
