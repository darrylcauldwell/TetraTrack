//
//  FamilyView.swift
//  TrackRide
//
//  Live Sharing - Share your rides with family and friends in real-time
//

import SwiftUI
import os

struct FamilyView: View {
    @Environment(RideTracker.self) private var rideTracker: RideTracker?
    @State private var sharingCoordinator = UnifiedSharingCoordinator.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var syncMonitor = SyncStatusMonitor.shared
    @State private var showingAddMember = false
    @State private var trustedContacts: [SharingRelationship] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Pending Requests Section (always visible)
                    PendingRequestsSection(
                        pendingRequests: sharingCoordinator.pendingRequests,
                        sharingCoordinator: sharingCoordinator
                    )

                    // Shared With Me Section (always visible)
                    SharedWithMeSection(linkedRiders: sharingCoordinator.linkedRiders)

                    // My Sharing Card
                    MySharingCard(
                        rideTracker: rideTracker,
                        notificationManager: notificationManager,
                        sharingCoordinator: sharingCoordinator
                    )

                    // Show either the contacts list OR the get started card (not both)
                    if trustedContacts.isEmpty {
                        // No contacts yet - show onboarding card with safety info
                        GetStartedCard(onAddMember: { showingAddMember = true })
                    } else {
                        // Has contacts - show the list
                        TrustedContactsCard(
                            contacts: trustedContacts,
                            sharingCoordinator: sharingCoordinator,
                            onAddMember: { showingAddMember = true }
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Live Sharing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        SyncStatusIndicator()

                        NavigationLink(destination: SharingDiagnosticsView()) {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .refreshable {
                await sharingCoordinator.fetchFamilyLocations()
                loadContacts()
            }
            .onAppear {
                sharingCoordinator.startWatchingLocations()
                syncMonitor.startMonitoring()
            }
            .onDisappear {
                sharingCoordinator.stopWatchingLocations()
                syncMonitor.stopMonitoring()
            }
            .sheet(isPresented: $showingAddMember) {
                AddFamilyMemberView()
                    .presentationBackground(Color.black)
            }
            .task {
                sharingCoordinator.loadLinkedRiders()
                await sharingCoordinator.setup()
                await sharingCoordinator.fetchFamilyLocations()
                loadContacts()
            }
            .presentationBackground(Color.black)
        }
    }

    private func loadContacts() {
        do {
            trustedContacts = try sharingCoordinator.fetchFamilyMembers()
        } catch {
            Log.family.error("Failed to load contacts: \(error)")
        }
    }
}

// MARK: - Shared With Me Section (Always Visible)

struct SharedWithMeSection: View {
    let linkedRiders: [LinkedRider]

    var activeCount: Int {
        linkedRiders.filter { $0.isCurrentlyRiding }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColors.primary)
                Text("Shared With Me")
                    .font(.headline)
                Spacer()
                if activeCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.active)
                            .frame(width: 8, height: 8)
                        Text("\(activeCount) riding")
                            .font(.caption)
                            .foregroundStyle(AppColors.active)
                    }
                }
            }

            if linkedRiders.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No riders sharing with you yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("When someone shares their rides with you, they'll appear here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                // Show all linked riders
                // Navigation depends solely on currentSession to avoid race between
                // isCurrentlyRiding and currentSession properties
                ForEach(linkedRiders) { rider in
                    if let session = rider.currentSession, session.isActive {
                        // Rider has active session - show with navigation to live map
                        NavigationLink(destination: LiveTrackingMapView(session: session)) {
                            LinkedRiderCard(rider: rider)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Rider is not active or no session data - show status only
                        LinkedRiderCard(rider: rider)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Pending Requests Section

struct PendingRequestsSection: View {
    let pendingRequests: [PendingShareRequest]
    let sharingCoordinator: UnifiedSharingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "person.badge.clock.fill")
                    .font(.title3)
                    .foregroundStyle(pendingRequests.isEmpty ? Color.secondary : Color.orange)
                Text("Pending Requests")
                    .font(.headline)
                Spacer()
                if !pendingRequests.isEmpty {
                    Text("\(pendingRequests.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange)
                        .clipShape(Capsule())
                }
            }

            if pendingRequests.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)

                    Text("No pending requests")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("When someone invites you to follow their rides, their request will appear here for you to accept or decline.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Text("Someone wants to share their rides with you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(pendingRequests) { request in
                    PendingRequestCard(request: request, sharingCoordinator: sharingCoordinator)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(pendingRequests.isEmpty ? AppColors.cardBackground.opacity(0.5) : .orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(pendingRequests.isEmpty ? Color(.systemGray4).opacity(0.3) : .orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Pending Request Card

struct PendingRequestCard: View {
    let request: PendingShareRequest
    let sharingCoordinator: UnifiedSharingCoordinator
    @State private var isAccepting = false
    @State private var showingDeclineConfirmation = false

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Text(request.initials)
                    .font(.headline)
                    .foregroundStyle(AppColors.primary)
            }

            // Name and time
            VStack(alignment: .leading, spacing: 4) {
                Text(request.ownerName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Received \(request.timeSinceReceived)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Decline button
                Button {
                    showingDeclineConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Accept button
                Button {
                    acceptRequest()
                } label: {
                    if isAccepting {
                        ProgressView()
                            .frame(width: 36, height: 36)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(AppColors.success)
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAccepting)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .confirmationDialog("Decline request from \(request.ownerName)?", isPresented: $showingDeclineConfirmation, titleVisibility: .visible) {
            Button("Decline", role: .destructive) {
                // Decline the pending request (does NOT accept the CKShare)
                Task {
                    await sharingCoordinator.declinePendingRequest(request)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't be able to see their live location or receive safety alerts from them.")
        }
    }

    private func acceptRequest() {
        isAccepting = true
        Task {
            // Use the proper accept method that accepts the CKShare and removes from pending
            _ = await sharingCoordinator.acceptPendingRequest(request)
            await MainActor.run {
                isAccepting = false
            }
        }
    }
}

// MARK: - Linked Rider Card

struct LinkedRiderCard: View {
    let rider: LinkedRider

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with status indicator
            ZStack {
                Circle()
                    .fill(rider.isCurrentlyRiding ? AppColors.active.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 48, height: 48)

                Text(rider.initials)
                    .font(.headline)
                    .foregroundStyle(rider.isCurrentlyRiding ? AppColors.active : .secondary)

                // Live indicator when riding
                if rider.isCurrentlyRiding {
                    Circle()
                        .fill(AppColors.active)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(AppColors.active, lineWidth: 2)
                                .scaleEffect(1.5)
                                .opacity(0.5)
                        )
                        .offset(x: 16, y: -16)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rider.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(rider.isCurrentlyRiding ? .primary : .secondary)

                if rider.isCurrentlyRiding, let session = rider.currentSession {
                    // Show live stats
                    HStack(spacing: 12) {
                        Label(session.formattedDistance, systemImage: "arrow.left.and.right")
                        Label(session.formattedDuration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Current gait
                    HStack(spacing: 4) {
                        Image(systemName: session.gait.icon)
                        Text(session.gait.rawValue)
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.gait(session.gait))
                } else {
                    Text("Not currently riding")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Navigation hint when riding
            if rider.isCurrentlyRiding {
                VStack {
                    Image(systemName: "map")
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                    Text("View")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            rider.isCurrentlyRiding ?
            Color(.systemBackground).opacity(0.8) :
            Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Active Ride Card

struct ActiveRideCard: View {
    let session: LiveTrackingSession

    var body: some View {
        HStack(spacing: 16) {
            // Live indicator with rider avatar
            ZStack {
                Circle()
                    .fill(gaitColor.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: "figure.equestrian.sports")
                    .font(.title2)
                    .foregroundStyle(gaitColor)

                // Pulsing live indicator
                Circle()
                    .fill(AppColors.active)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(AppColors.active, lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0.5)
                    )
                    .offset(x: 20, y: -20)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.riderName.isEmpty ? "Rider" : session.riderName)
                        .font(.headline)

                    // Stationary warning
                    if session.isStationary && session.stationaryDuration > 120 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppColors.warning)
                            .font(.caption)
                    }
                }

                HStack(spacing: 12) {
                    Label(session.formattedDistance, systemImage: "arrow.left.and.right")
                    Label(session.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Current gait
                HStack(spacing: 4) {
                    Image(systemName: session.gait.icon)
                    Text(session.gait.rawValue)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(gaitColor)
            }

            Spacer()

            // Tap to view indicator
            VStack {
                Image(systemName: "map")
                    .font(.title3)
                    .foregroundStyle(AppColors.primary)
                Text("View")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var gaitColor: Color {
        AppColors.gait(session.gait)
    }
}

// MARK: - Sharing Status Card

struct MySharingCard: View {
    let rideTracker: RideTracker?
    let notificationManager: NotificationManager
    let sharingCoordinator: UnifiedSharingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(AppColors.primary)
                Text("Sharing Status")
                    .font(.headline)
            }

            // Current ride status
            if let tracker = rideTracker {
                HStack(spacing: 8) {
                    Image(systemName: tracker.rideState == .tracking ? "antenna.radiowaves.left.and.right" : "circle")
                        .foregroundStyle(tracker.rideState == .tracking ? AppColors.active : .secondary)

                    Text(tracker.rideState == .tracking ? "Currently sharing your ride" : "Not riding - live sharing inactive")
                        .font(.subheadline)
                        .foregroundStyle(tracker.rideState == .tracking ? AppColors.active : .secondary)
                }

                // Show error indicator when location updates are failing
                if tracker.rideState == .tracking && sharingCoordinator.hasLocationUpdateError {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(sharingCoordinator.locationErrorDescription ?? "Location updates failing")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.orange)
                        }
                        if let errorTime = sharingCoordinator.locationErrorStartTime {
                            Text("Family may not see updates since \(errorTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            // Notification permission status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")
                        .font(.subheadline)
                    Text(notificationManager.isAuthorized ? "You'll receive safety alerts from your contacts" : "Enable to receive safety alerts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if notificationManager.isAuthorized {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(AppColors.success)
                } else {
                    Button("Enable") {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Trusted Contacts Card

struct TrustedContactsCard: View {
    let contacts: [SharingRelationship]
    let sharingCoordinator: UnifiedSharingCoordinator
    let onAddMember: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColors.primary)
                Text("Trusted Contacts")
                    .font(.headline)

                Spacer()

                Button(action: onAddMember) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                }
            }
            .padding(.bottom, 16)

            // Contact list with dividers
            ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                ContactRow(contact: contact, sharingCoordinator: sharingCoordinator)
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: SharingRelationship
    let sharingCoordinator: UnifiedSharingCoordinator
    @State private var liveTracking: Bool
    @State private var fallAlerts: Bool
    @State private var stationaryAlerts: Bool
    @State private var emergencySOS: Bool
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false
    @State private var isExpanded = false
    @State private var isGeneratingShare = false
    @State private var currentShareURL: URL?
    @State private var showingShareError = false

    init(contact: SharingRelationship, sharingCoordinator: UnifiedSharingCoordinator) {
        self.contact = contact
        self.sharingCoordinator = sharingCoordinator
        self._liveTracking = State(initialValue: contact.canViewLiveRiding)
        self._fallAlerts = State(initialValue: contact.receiveFallAlerts)
        self._stationaryAlerts = State(initialValue: contact.receiveStationaryAlerts)
        self._emergencySOS = State(initialValue: contact.isEmergencyContact)
    }

    private var inviteStatusColor: Color {
        switch contact.inviteStatus {
        case .notSent: return .secondary
        case .pending: return .orange
        case .accepted: return AppColors.success
        }
    }

    private var enabledCount: Int {
        [liveTracking, fallAlerts, stationaryAlerts, emergencySOS].filter { $0 }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main contact row - tap to expand
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Name and Primary badge
                        HStack(spacing: 8) {
                            Text(contact.name)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            if contact.isPrimaryEmergency {
                                Text("Primary")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppColors.error)
                                    .clipShape(Capsule())
                            }
                        }

                        // Invite status
                        HStack(spacing: 4) {
                            Image(systemName: contact.inviteStatus.icon)
                                .font(.system(size: 11))
                            Text(contact.inviteStatus == .pending ?
                                 "Pending" + (contact.timeSinceInvite.map { " · \($0)" } ?? "") :
                                 contact.inviteStatus.displayText)
                                .font(.caption)
                        }
                        .foregroundStyle(inviteStatusColor)
                    }

                    Spacer()

                    // Expand chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Expanded settings
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                    VStack(spacing: 24) {
                        // Invite status section (if not connected)
                        if contact.inviteStatus != .accepted {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    Image(systemName: contact.inviteStatus.icon)
                                        .font(.title3)
                                        .foregroundStyle(inviteStatusColor)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(contact.inviteStatus == .pending ? "Invite pending" : "Not yet invited")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)

                                        if contact.inviteStatus == .pending {
                                            if let timeSince = contact.timeSinceInvite {
                                                Text("Sent \(timeSince)")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                }

                                if contact.inviteStatus == .pending && contact.reminderCount > 0 {
                                    Text("\(contact.reminderCount) reminder\(contact.reminderCount == 1 ? "" : "s") sent")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Button {
                                    // Generate share URL if needed before showing sheet
                                    if contact.shareURLValue == nil && currentShareURL == nil {
                                        isGeneratingShare = true
                                        Task {
                                            let url = await sharingCoordinator.generateShareLink(for: contact)
                                            await MainActor.run {
                                                isGeneratingShare = false
                                                guard let url = url else {
                                                    // Show error - share link is required
                                                    showingShareError = true
                                                    return
                                                }
                                                currentShareURL = url
                                                showingShareSheet = true
                                            }
                                        }
                                    } else {
                                        currentShareURL = contact.shareURLValue
                                        showingShareSheet = true
                                    }
                                } label: {
                                    if isGeneratingShare {
                                        ProgressView()
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                    } else {
                                        Label(
                                            contact.inviteStatus == .pending ? "Send reminder" : "Send invite",
                                            systemImage: contact.inviteStatus == .pending ? "arrow.clockwise" : "paperplane"
                                        )
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(contact.inviteStatus == .pending ? .orange : AppColors.primary)
                                .disabled(isGeneratingShare)
                            }
                            .padding(16)
                            .background(AppColors.cardBackground.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            Divider()
                                .padding(.vertical, 8)
                        }

                        // Feature permissions section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Permissions")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.bottom, 4)

                            // Live Tracking toggle
                            FeatureToggleRow(
                                icon: "location.fill",
                                title: "Live Tracking",
                                description: "Can see your live location while you're riding",
                                color: AppColors.primary,
                                isOn: $liveTracking
                            ) { newValue in
                                contact.canViewLiveRiding = newValue
                                sharingCoordinator.repository?.update(contact)
                            }

                            // Fall Detection toggle
                            FeatureToggleRow(
                                icon: "figure.fall",
                                title: "Fall Detection",
                                description: "Gets notified immediately if a fall is detected",
                                color: AppColors.error,
                                isOn: $fallAlerts
                            ) { newValue in
                                contact.receiveFallAlerts = newValue
                                sharingCoordinator.repository?.update(contact)
                            }

                            // Stationary Alerts toggle
                            FeatureToggleRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Stationary Alerts",
                                description: "Gets warned if you stop moving unexpectedly",
                                color: AppColors.warning,
                                isOn: $stationaryAlerts
                            ) { newValue in
                                contact.receiveStationaryAlerts = newValue
                                sharingCoordinator.repository?.update(contact)
                            }

                            // Emergency SOS toggle
                            FeatureToggleRow(
                                icon: "sos",
                                title: "Emergency SOS",
                                description: "Receives SMS with your GPS location in emergencies",
                                color: .red,
                                isOn: $emergencySOS
                            ) { newValue in
                                contact.isEmergencyContact = newValue
                                sharingCoordinator.repository?.update(contact)
                            }
                        }

                        // Remove button
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                Text("Remove contact")
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .confirmationDialog("Remove \(contact.name)?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Contact", role: .destructive) {
                Task {
                    await sharingCoordinator.deleteRelationship(contact)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will no longer receive your live location or safety alerts.")
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            if contact.inviteStatus == .notSent {
                contact.inviteStatus = .pending
                contact.inviteSentDate = Date()
                sharingCoordinator.repository?.update(contact)
            } else if contact.inviteStatus == .pending {
                contact.lastReminderDate = Date()
                contact.reminderCount += 1
                sharingCoordinator.repository?.update(contact)
            }
        }) {
            ShareSheet(items: [contact.generateInviteMessage(isReminder: contact.inviteStatus == .pending)])
        }
        .alert("Unable to Generate Invite Link", isPresented: $showingShareError) {
            Button("OK") { }
        } message: {
            Text("Please make sure you're signed into iCloud in Settings. The invite link requires iCloud to work.")
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Feature Toggle Row

struct FeatureToggleRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Binding var isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top row: Icon, Title, and Toggle
            HStack(spacing: 14) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .onChange(of: isOn) { _, newValue in
                        onChange(newValue)
                    }
            }

            // Description on its own line
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.leading, 58) // Align with title (44 icon + 14 spacing)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(AppColors.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Get Started Card (with integrated safety features)

struct GetStartedCard: View {
    let onAddMember: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.primary.opacity(0.6))

                Text("Ride Safer Together")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Share your live location with family and friends so they can follow your rides and be alerted if something goes wrong.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Safety features in a compact grid
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    SafetyFeatureItem(
                        icon: "location.fill",
                        title: "Live Tracking",
                        color: AppColors.primary
                    )
                    SafetyFeatureItem(
                        icon: "figure.fall",
                        title: "Fall Detection",
                        color: AppColors.error
                    )
                }

                HStack(spacing: 16) {
                    SafetyFeatureItem(
                        icon: "exclamationmark.triangle.fill",
                        title: "Stationary Alerts",
                        color: AppColors.warning
                    )
                    SafetyFeatureItem(
                        icon: "sos",
                        title: "Emergency SOS",
                        color: .red
                    )
                }
            }

            // Add contact button
            Button(action: onAddMember) {
                Label("Add Trusted Contact", systemImage: "person.badge.plus")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
            .controlSize(.large)
        }
        .padding(24)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Safety Feature Item

struct SafetyFeatureItem: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Add Contact View

struct AddFamilyMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isLoading = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(height: 40)

                    // Simple header
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 56))
                            .foregroundStyle(AppColors.primary)

                        Text("Add Trusted Contact")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("They can follow your rides and receive safety alerts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    Spacer()
                        .frame(height: 40)

                    // Name field
                    TextField("Name (e.g. Mum, Sarah)", text: $name)
                        .textContentType(.name)
                        .font(.title3)
                        .padding()
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                        .padding(.horizontal)

                    Spacer()
                        .frame(height: 40)

                    // Single action button
                    VStack(spacing: 8) {
                        Button {
                            isNameFieldFocused = false
                            addAndInvite()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 24)
                            } else {
                                Label("Add & Send Invite", systemImage: "paperplane.fill")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.primary)
                        .controlSize(.large)
                        .disabled(name.isEmpty || isLoading)

                        Text("They'll receive a link to download the app")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
            .alert("Unable to Generate Invite Link", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .presentationBackground(Color.black)
        }
    }

    private func addAndInvite() {
        isLoading = true
        let sharingCoordinator = UnifiedSharingCoordinator.shared

        Task {
            // Create the relationship first
            guard let relationship = sharingCoordinator.createRelationship(
                name: name,
                type: .familyMember,
                preset: .fullAccess
            ) else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create contact."
                    showingError = true
                }
                return
            }

            // Generate CloudKit share URL
            let shareURL = await sharingCoordinator.generateShareLink(for: relationship)

            await MainActor.run {
                // Check if we got a share URL
                guard let url = shareURL else {
                    // Show error to user - the share link is critical for the invite
                    isLoading = false
                    errorMessage = "Please make sure you're signed into iCloud in Settings. The invite link requires iCloud to work."
                    showingError = true
                    return
                }

                // Generate share content with the CloudKit URL
                shareItems = [relationship.generateInviteMessage()]
                isLoading = false
                showingShareSheet = true
            }
        }
    }
}

// ShareSheet is defined in RideDetailView.swift

#Preview {
    FamilyView()
        .environment(RideTracker(locationManager: LocationManager()))
}
