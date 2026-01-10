//
//  FamilyView.swift
//  TrackRide
//
//  Live Sharing - Share your rides with family and friends in real-time
//

import SwiftUI

struct FamilyView: View {
    @Environment(RideTracker.self) private var rideTracker: RideTracker?
    @State private var familySharing = FamilySharingManager.shared
    @State private var notificationManager = NotificationManager.shared
    @State private var showingAddMember = false
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Pending Requests Section (always visible)
                    PendingRequestsSection(
                        pendingRequests: familySharing.pendingRequests,
                        familySharing: familySharing
                    )

                    // Shared With Me Section (always visible)
                    SharedWithMeSection(linkedRiders: familySharing.linkedRiders)

                    // My Sharing Card
                    MySharingCard(
                        rideTracker: rideTracker,
                        notificationManager: notificationManager
                    )

                    // Show either the contacts list OR the get started card (not both)
                    if familySharing.trustedContacts.isEmpty {
                        // No contacts yet - show onboarding card with safety info
                        GetStartedCard(onAddMember: { showingAddMember = true })
                    } else {
                        // Has contacts - show the list
                        TrustedContactsCard(
                            familySharing: familySharing,
                            onAddMember: { showingAddMember = true }
                        )
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        AppColors.light,
                        AppColors.primary.opacity(0.05),
                        AppColors.light.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Live Sharing")
            .refreshable {
                await familySharing.fetchFamilyLocations()
            }
            .onAppear {
                startRefreshing()
            }
            .onDisappear {
                stopRefreshing()
            }
            .sheet(isPresented: $showingAddMember) {
                AddFamilyMemberView()
            }
            .task {
                familySharing.loadContacts()
                await familySharing.setup()
                await familySharing.fetchFamilyLocations()
            }
        }
    }

    private func startRefreshing() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task {
                await familySharing.fetchFamilyLocations()
            }
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
                ForEach(linkedRiders) { rider in
                    if rider.isCurrentlyRiding, let session = rider.currentSession {
                        // Rider is active - show with navigation to live map
                        NavigationLink(destination: LiveTrackingMapView(session: session)) {
                            LinkedRiderCard(rider: rider)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Rider is not active - show status only
                        LinkedRiderCard(rider: rider)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Pending Requests Section

struct PendingRequestsSection: View {
    let pendingRequests: [PendingShareRequest]
    let familySharing: FamilySharingManager

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
                    PendingRequestCard(request: request, familySharing: familySharing)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(pendingRequests.isEmpty ? Color(.systemGray6).opacity(0.5) : .orange.opacity(0.1))
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
    let familySharing: FamilySharingManager
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
                familySharing.declinePendingRequest(request)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't be able to see their live location or receive safety alerts from them.")
        }
    }

    private func acceptRequest() {
        isAccepting = true
        Task {
            _ = await familySharing.acceptPendingRequest(request)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Trusted Contacts Card

struct TrustedContactsCard: View {
    let familySharing: FamilySharingManager
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
            ForEach(Array(familySharing.trustedContacts.enumerated()), id: \.element.id) { index, contact in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                ContactRow(contact: contact, familySharing: familySharing)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: TrustedContact
    let familySharing: FamilySharingManager
    @State private var liveTracking: Bool
    @State private var fallAlerts: Bool
    @State private var stationaryAlerts: Bool
    @State private var emergencySOS: Bool
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false
    @State private var isExpanded = false

    init(contact: TrustedContact, familySharing: FamilySharingManager) {
        self.contact = contact
        self.familySharing = familySharing
        self._liveTracking = State(initialValue: contact.canViewLiveTracking)
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
                                    showingShareSheet = true
                                } label: {
                                    Label(
                                        contact.inviteStatus == .pending ? "Send reminder" : "Send invite",
                                        systemImage: contact.inviteStatus == .pending ? "arrow.clockwise" : "paperplane"
                                    )
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(contact.inviteStatus == .pending ? .orange : AppColors.primary)
                            }
                            .padding(16)
                            .background(Color(.systemGray6).opacity(0.5))
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
                                var updated = contact
                                updated.canViewLiveTracking = newValue
                                familySharing.updateContact(updated)
                            }

                            // Fall Detection toggle
                            FeatureToggleRow(
                                icon: "figure.fall",
                                title: "Fall Detection",
                                description: "Gets notified immediately if a fall is detected",
                                color: AppColors.error,
                                isOn: $fallAlerts
                            ) { newValue in
                                var updated = contact
                                updated.receiveFallAlerts = newValue
                                familySharing.updateContact(updated)
                            }

                            // Stationary Alerts toggle
                            FeatureToggleRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Stationary Alerts",
                                description: "Gets warned if you stop moving unexpectedly",
                                color: AppColors.warning,
                                isOn: $stationaryAlerts
                            ) { newValue in
                                var updated = contact
                                updated.receiveStationaryAlerts = newValue
                                familySharing.updateContact(updated)
                            }

                            // Emergency SOS toggle
                            FeatureToggleRow(
                                icon: "sos",
                                title: "Emergency SOS",
                                description: "Receives SMS with your GPS location in emergencies",
                                color: .red,
                                isOn: $emergencySOS
                            ) { newValue in
                                var updated = contact
                                updated.isEmergencyContact = newValue
                                familySharing.updateContact(updated)
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
                familySharing.removeContact(id: contact.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will no longer receive your live location or safety alerts.")
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            if contact.inviteStatus == .notSent {
                familySharing.markInviteSent(contactID: contact.id)
            } else if contact.inviteStatus == .pending {
                familySharing.markReminderSent(contactID: contact.id)
            }
        }) {
            ShareSheet(items: [contact.inviteMessage(isReminder: contact.inviteStatus == .pending)])
        }
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
        .background(Color(.systemGray6).opacity(0.6))
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
        .background(.ultraThinMaterial)
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
                        .background(Color(.systemGray6))
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
        }
    }

    private func addAndInvite() {
        isLoading = true

        Task {
            // Generate CloudKit share URL
            let shareURL = await FamilySharingManager.shared.generateShareLink()

            await MainActor.run {
                // Add the contact with pending invite status
                FamilySharingManager.shared.addContact(
                    name: name,
                    phoneNumber: "",
                    email: nil,
                    isEmergencyContact: true,
                    inviteStatus: .pending,
                    inviteSentDate: Date()
                )

                // Generate share content with the CloudKit URL
                let firstName = name.split(separator: " ").first.map(String.init) ?? "there"
                var message = """
                Hi \(firstName)! I've added you as a trusted contact on TetraTrack.

                You can follow my horse rides live and receive safety alerts if I need help.

                Download TetraTrack: https://apps.apple.com/app/tetratrack
                """

                if let url = shareURL {
                    message += "\n\nTap to connect: \(url.absoluteString)"
                }

                shareItems = [message]
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
