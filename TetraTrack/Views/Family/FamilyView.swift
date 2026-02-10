//
//  FamilyView.swift
//  TetraTrack
//
//  Live Sharing - Share your rides with family and friends in real-time
//

import SwiftUI
import os

struct FamilyView: View {
    @Environment(RideTracker.self) private var rideTracker: RideTracker?
    private let sharingCoordinator = UnifiedSharingCoordinator.shared
    private let notificationManager = NotificationManager.shared
    private let syncMonitor = SyncStatusMonitor.shared
    @State private var showingAddMember = false
    @State private var trustedContacts: [SharingRelationship] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // iCloud availability banner (shown when not signed in)
                    if !sharingCoordinator.isSignedIn && sharingCoordinator.isSetupComplete {
                        ICloudRequiredBanner()
                    }

                    // Shared With Me Section (always visible)
                    SharedWithMeSection(linkedRiders: sharingCoordinator.linkedRiders)

                    // Sharing With Section (merged status + contacts)
                    if trustedContacts.isEmpty {
                        // No contacts yet - show onboarding card with safety info
                        GetStartedCard(onAddMember: { showingAddMember = true })
                    } else {
                        // Has contacts - show merged sharing status and contacts
                        SharingWithCard(
                            contacts: trustedContacts,
                            rideTracker: rideTracker,
                            notificationManager: notificationManager,
                            sharingCoordinator: sharingCoordinator,
                            onAddMember: { showingAddMember = true },
                            onContactRemoved: { loadContacts() }
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
                // Restart refresh loop if it stopped due to errors
                sharingCoordinator.restartRefreshLoopIfNeeded()

                await sharingCoordinator.fetchFamilyLocations()
                await sharingCoordinator.updateInviteStatuses()
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
                await sharingCoordinator.updateInviteStatuses()
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
                    // Show connected status when not riding
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.success)
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(AppColors.success)
                        }
                        Text("Not currently riding")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Show what you can access
            if rider.isCurrentlyRiding {
                VStack {
                    Image(systemName: "map")
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                    Text("View")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                // Show access icons when not riding
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.primary.opacity(0.5))
                    Image(systemName: "figure.fall")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.error.opacity(0.5))
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

// MARK: - Sharing With Card (Merged Status + Contacts)

struct SharingWithCard: View {
    let contacts: [SharingRelationship]
    let rideTracker: RideTracker?
    let notificationManager: NotificationManager
    let sharingCoordinator: UnifiedSharingCoordinator
    let onAddMember: () -> Void
    let onContactRemoved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(AppColors.primary)
                Text("Sharing With")
                    .font(.headline)

                Spacer()

                Button(action: onAddMember) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.primary)
                }
            }

            // Current sharing status
            if let tracker = rideTracker {
                HStack(spacing: 8) {
                    Image(systemName: tracker.rideState == .tracking ? "antenna.radiowaves.left.and.right" : "circle")
                        .font(.caption)
                        .foregroundStyle(tracker.rideState == .tracking ? AppColors.active : .secondary)

                    Text(tracker.rideState == .tracking ? "Currently sharing your ride" : "Not currently riding")
                        .font(.caption)
                        .foregroundStyle(tracker.rideState == .tracking ? AppColors.active : .secondary)
                }
                .padding(.top, 8)

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
                    .padding(.top, 8)
                }
            }

            Divider()
                .padding(.vertical, 12)

            // Contact list
            ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 4)
                }
                ContactRow(
                    contact: contact,
                    sharingCoordinator: sharingCoordinator,
                    onRemoved: onContactRemoved
                )
            }

            // Notification status at bottom
            if !notificationManager.isAuthorized {
                Divider()
                    .padding(.vertical, 12)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.subheadline)
                        Text("Enable to receive safety alerts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

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
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: SharingRelationship
    let sharingCoordinator: UnifiedSharingCoordinator
    let onRemoved: () -> Void
    @State private var liveTracking: Bool
    @State private var fallAlerts: Bool
    @State private var stationaryAlerts: Bool
    @State private var emergencySOS: Bool
    @State private var phoneNumber: String
    @State private var isPrimary: Bool
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false
    @State private var isExpanded = false
    @State private var isGeneratingShare = false
    @State private var currentShareURL: URL?
    @State private var showingShareError = false
    @State private var showingFeaturesDisabledAlert = false

    init(contact: SharingRelationship, sharingCoordinator: UnifiedSharingCoordinator, onRemoved: @escaping () -> Void) {
        self.contact = contact
        self.sharingCoordinator = sharingCoordinator
        self.onRemoved = onRemoved
        self._liveTracking = State(initialValue: contact.canViewLiveTracking)
        self._fallAlerts = State(initialValue: contact.receiveFallAlerts)
        self._stationaryAlerts = State(initialValue: contact.receiveStationaryAlerts)
        self._emergencySOS = State(initialValue: contact.isEmergencyContact)
        self._phoneNumber = State(initialValue: contact.phoneNumber ?? "")
        self._isPrimary = State(initialValue: contact.isPrimaryEmergency)
    }

    /// Sync state with contact data when it changes externally (e.g., CloudKit sync)
    private func syncStateWithContact() {
        if liveTracking != contact.canViewLiveTracking {
            liveTracking = contact.canViewLiveTracking
        }
        if fallAlerts != contact.receiveFallAlerts {
            fallAlerts = contact.receiveFallAlerts
        }
        if stationaryAlerts != contact.receiveStationaryAlerts {
            stationaryAlerts = contact.receiveStationaryAlerts
        }
        if emergencySOS != contact.isEmergencyContact {
            emergencySOS = contact.isEmergencyContact
        }
        if phoneNumber != (contact.phoneNumber ?? "") {
            phoneNumber = contact.phoneNumber ?? ""
        }
        if isPrimary != contact.isPrimaryEmergency {
            isPrimary = contact.isPrimaryEmergency
        }
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

                        // Invite status and permission icons
                        HStack(spacing: 8) {
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

                            // Permission icons (only show when connected)
                            if contact.inviteStatus == .accepted {
                                HStack(spacing: 4) {
                                    if liveTracking {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppColors.primary)
                                    }
                                    if fallAlerts {
                                        Image(systemName: "figure.fall")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppColors.error)
                                    }
                                    if stationaryAlerts {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AppColors.warning)
                                    }
                                    if emergencySOS {
                                        Image(systemName: "sos")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
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
                                    // Always regenerate if no current URL or cached URL
                                    let needsGeneration = contact.shareURLValue == nil && currentShareURL == nil

                                    if needsGeneration {
                                        isGeneratingShare = true
                                        Task {
                                            let url = await sharingCoordinator.generateShareLink(for: contact)
                                            await MainActor.run {
                                                isGeneratingShare = false
                                                guard let url = url else {
                                                    // Show error - share link is required
                                                    // Clear any stale cached URL
                                                    currentShareURL = nil
                                                    showingShareError = true
                                                    return
                                                }
                                                currentShareURL = url
                                                showingShareSheet = true
                                            }
                                        }
                                    } else if let cachedURL = currentShareURL ?? contact.shareURLValue {
                                        // Use existing valid URL
                                        currentShareURL = cachedURL
                                        showingShareSheet = true
                                    } else {
                                        // Fallback: no URL available, show error
                                        showingShareError = true
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

                        // Contact Details section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact Details")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.bottom, 4)

                            // Phone number field
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.success.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppColors.success)
                                }

                                TextField("Phone number", text: $phoneNumber)
                                    .textContentType(.telephoneNumber)
                                    .keyboardType(.phonePad)
                                    .font(.subheadline)
                                    .onChange(of: phoneNumber) { _, newValue in
                                        contact.phoneNumber = newValue.isEmpty ? nil : PhoneNumberValidator.normalise(newValue)
                                        // Disable phone-dependent features when number becomes invalid
                                        if !PhoneNumberValidator.validate(newValue).isAcceptable {
                                            var featuresDisabled = false
                                            if fallAlerts {
                                                fallAlerts = false
                                                contact.receiveFallAlerts = false
                                                featuresDisabled = true
                                            }
                                            if emergencySOS {
                                                emergencySOS = false
                                                contact.isEmergencyContact = false
                                                featuresDisabled = true
                                            }
                                            if isPrimary {
                                                isPrimary = false
                                                contact.isPrimaryEmergency = false
                                                featuresDisabled = true
                                            }
                                            if featuresDisabled {
                                                showingFeaturesDisabledAlert = true
                                            }
                                        }
                                        sharingCoordinator.repository?.update(contact)
                                    }
                            }
                            .padding(12)
                            .background(AppColors.cardBackground.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Phone validation hint
                            if !phoneNumber.isEmpty {
                                let result = PhoneNumberValidator.validate(phoneNumber)
                                Label(result.message, systemImage: result.icon)
                                    .font(.caption)
                                    .foregroundStyle(result.color)
                                    .padding(.horizontal, 4)
                            }

                            // Primary Emergency Contact toggle
                            FeatureToggleRow(
                                icon: "staroflife.fill",
                                title: "Primary Contact",
                                description: !PhoneNumberValidator.validate(phoneNumber).isAcceptable
                                    ? "Add a valid mobile number to set as primary"
                                    : "Called first in an emergency",
                                color: AppColors.error,
                                isOn: $isPrimary
                            ) { newValue in
                                if newValue {
                                    try? sharingCoordinator.repository?.setPrimaryEmergencyContact(contact)
                                } else {
                                    contact.isPrimaryEmergency = false
                                    sharingCoordinator.repository?.update(contact)
                                }
                            }
                            .disabled(!PhoneNumberValidator.validate(phoneNumber).isAcceptable)
                        }

                        Divider()
                            .padding(.vertical, 8)

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
                                description: "Can see your live location during sessions",
                                color: AppColors.primary,
                                isOn: $liveTracking
                            ) { newValue in
                                contact.canViewLiveTracking = newValue
                                sharingCoordinator.repository?.update(contact)
                            }

                            // Fall Detection toggle
                            FeatureToggleRow(
                                icon: "figure.fall",
                                title: "Fall Detection",
                                description: !PhoneNumberValidator.validate(phoneNumber).isAcceptable
                                    ? "Requires a valid mobile number to send SMS alerts"
                                    : "Gets notified immediately if a fall is detected",
                                color: AppColors.error,
                                isOn: $fallAlerts
                            ) { newValue in
                                contact.receiveFallAlerts = newValue
                                sharingCoordinator.repository?.update(contact)
                            }
                            .disabled(!PhoneNumberValidator.validate(phoneNumber).isAcceptable)

                            // Stationary Alerts toggle
                            FeatureToggleRow(
                                icon: "exclamationmark.triangle.fill",
                                title: "Stationary Alerts",
                                description: !PhoneNumberValidator.validate(phoneNumber).isAcceptable
                                    ? "Warned via push if you stop moving. SMS fallback needs a valid mobile number"
                                    : "Gets warned if you stop moving unexpectedly",
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
                                description: !PhoneNumberValidator.validate(phoneNumber).isAcceptable
                                    ? "Requires a valid mobile number to send SMS alerts"
                                    : "Receives SMS with your GPS location in emergencies",
                                color: .red,
                                isOn: $emergencySOS
                            ) { newValue in
                                contact.isEmergencyContact = newValue
                                sharingCoordinator.repository?.update(contact)
                            }
                            .disabled(!PhoneNumberValidator.validate(phoneNumber).isAcceptable)

                            // Medical Notes link (shown when Emergency SOS or Fall Detection is enabled)
                            if emergencySOS || fallAlerts {
                                NavigationLink {
                                    MedicalNotesEditView(relationship: contact)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppColors.error.opacity(0.15))
                                                .frame(width: 36, height: 36)

                                            Image(systemName: "heart.text.square")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(AppColors.error)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Medical Notes")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.primary)
                                            Text(contact.medicalNotes?.isEmpty == false ? "Tap to edit" : "Not set")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(12)
                                    .background(AppColors.cardBackground.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
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
                    await MainActor.run {
                        onRemoved()
                    }
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
        .alert("Safety Features Disabled", isPresented: $showingFeaturesDisabledAlert) {
            Button("OK") { }
        } message: {
            Text("Fall Detection and Emergency SOS have been turned off because the phone number is no longer valid. Re-enter a valid mobile number to re-enable them.")
        }
        .onAppear {
            // Sync state with contact data on appear (handles external changes)
            syncStateWithContact()
        }
        .onChange(of: contact.canViewLiveTracking) { _, newValue in
            if liveTracking != newValue { liveTracking = newValue }
        }
        .onChange(of: contact.receiveFallAlerts) { _, newValue in
            if fallAlerts != newValue { fallAlerts = newValue }
        }
        .onChange(of: contact.receiveStationaryAlerts) { _, newValue in
            if stationaryAlerts != newValue { stationaryAlerts = newValue }
        }
        .onChange(of: contact.isEmergencyContact) { _, newValue in
            if emergencySOS != newValue { emergencySOS = newValue }
        }
        .onChange(of: contact.phoneNumber) { _, newValue in
            let resolved = newValue ?? ""
            if phoneNumber != resolved { phoneNumber = resolved }
        }
        .onChange(of: contact.isPrimaryEmergency) { _, newValue in
            if isPrimary != newValue { isPrimary = newValue }
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
        VStack(alignment: .leading, spacing: 12) {
            // Top row: Icon, Title, and Toggle
            HStack(spacing: 12) {
                // Icon with colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .onChange(of: isOn) { _, newValue in
                        onChange(newValue)
                    }
            }

            // Description on its own line with proper wrapping
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppColors.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

                Text("Safer Together")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Share your live location with family and friends so they can follow your sessions and be alerted if something goes wrong.")
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

// MARK: - iCloud Required Banner

struct ICloudRequiredBanner: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "icloud.slash")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sign-In Required")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Live Sharing requires iCloud to sync your location with family members.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {
                // Open Settings app to iCloud section
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Add Contact View

struct AddFamilyMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phoneNumber = ""
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
                        .submitLabel(.next)
                        .onSubmit {
                            isNameFieldFocused = false
                        }
                        .padding(.horizontal)

                    // Phone number field
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Phone number (for SMS alerts)", text: $phoneNumber)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .font(.title3)
                            .padding()
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if phoneNumber.isEmpty {
                            Label("Required for fall detection and emergency SMS alerts", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        } else {
                            let result = PhoneNumberValidator.validate(phoneNumber)
                            Label(result.message, systemImage: result.icon)
                                .font(.caption)
                                .foregroundStyle(result.color)
                                .padding(.horizontal, 4)
                        }
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

                        Text(phoneNumber.isEmpty
                            ? "You can add their phone number later to enable safety alerts"
                            : "They'll receive a link to download the app")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
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
                phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
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
                    // Show the actual error from the coordinator if available
                    isLoading = false
                    let coordinatorError = sharingCoordinator.errorMessage
                    let isSignedIn = sharingCoordinator.isSignedIn
                    let userID = sharingCoordinator.currentUserID

                    if let error = coordinatorError {
                        errorMessage = error
                    } else {
                        // Debug info to help diagnose
                        errorMessage = "Share link failed. Debug: isSignedIn=\(isSignedIn), userID=\(userID.isEmpty ? "empty" : "set"), coordinatorError=nil"
                    }
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

// MARK: - Medical Notes Edit View

struct MedicalNotesEditView: View {
    @Bindable var relationship: SharingRelationship

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This information may be shared with emergency contacts and first responders if you don't respond to a fall alert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Medical Notes") {
                TextEditor(text: Binding(
                    get: { relationship.medicalNotes ?? "" },
                    set: { relationship.medicalNotes = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 150)
                .writingToolsBehavior(.complete)
            }

            Section("Suggestions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consider including:")
                        .font(.caption)
                        .fontWeight(.medium)

                    VStack(alignment: .leading, spacing: 4) {
                        BulletPoint(text: "Known allergies")
                        BulletPoint(text: "Current medications")
                        BulletPoint(text: "Medical conditions")
                        BulletPoint(text: "Blood type")
                        BulletPoint(text: "Doctor's contact")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Medical Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bullet Point

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

// ShareSheet is defined in RideDetailView.swift

#Preview {
    FamilyView()
        .environment(RideTracker(locationManager: LocationManager()))
}
