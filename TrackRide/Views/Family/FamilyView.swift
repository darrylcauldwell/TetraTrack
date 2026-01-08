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
                    // Active Rides Section (most important - at top)
                    if !familySharing.sharedWithMe.isEmpty {
                        ActiveRidesSection(sessions: familySharing.sharedWithMe)
                    }

                    // My Sharing Card
                    MySharingCard(
                        rideTracker: rideTracker,
                        notificationManager: notificationManager
                    )

                    // Show either the contacts list OR the get started card (not both)
                    if familySharing.trustedContacts.isEmpty {
                        // No contacts yet - show onboarding card
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

// MARK: - Active Rides Section

struct ActiveRidesSection: View {
    let sessions: [LiveTrackingSession]

    var activeSessions: [LiveTrackingSession] {
        sessions.filter { $0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(AppColors.active)
                Text("Live Rides")
                    .font(.headline)
                Spacer()
                Text("\(activeSessions.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(activeSessions, id: \.id) { session in
                NavigationLink(destination: LiveTrackingMapView(session: session)) {
                    ActiveRideCard(session: session)
                }
                .buttonStyle(.plain)
            }

            if activeSessions.isEmpty {
                Text("No one currently riding")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

                    Text(tracker.rideState == .tracking ? "Currently sharing your ride" : "Not riding - sharing inactive")
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(AppColors.primary)
                Text("Trusted Contacts")
                    .font(.headline)

                Spacer()

                Button(action: onAddMember) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.primary)
                }
            }

            ForEach(familySharing.trustedContacts) { contact in
                ContactRow(contact: contact, familySharing: familySharing)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: TrustedContact
    let familySharing: FamilySharingManager
    @State private var shareWithContact: Bool
    @State private var alertsFromContact: Bool
    @State private var showingDeleteConfirmation = false

    init(contact: TrustedContact, familySharing: FamilySharingManager) {
        self.contact = contact
        self.familySharing = familySharing
        self._shareWithContact = State(initialValue: contact.shareMyLocation)
        self._alertsFromContact = State(initialValue: contact.receiveAlerts)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Contact info header
            HStack(spacing: 12) {
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(contact.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundStyle(AppColors.primary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let email = contact.email, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Delete button
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }

            // Per-contact toggles
            VStack(spacing: 8) {
                HStack {
                    Label("Share my location", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $shareWithContact)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: shareWithContact) { _, newValue in
                            var updated = contact
                            updated.shareMyLocation = newValue
                            familySharing.updateContact(updated)
                        }
                }

                HStack {
                    Label("Safety alerts", systemImage: "bell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $alertsFromContact)
                        .labelsHidden()
                        .scaleEffect(0.8)
                        .onChange(of: alertsFromContact) { _, newValue in
                            var updated = contact
                            updated.receiveAlerts = newValue
                            familySharing.updateContact(updated)
                        }
                }
            }
            .padding(.leading, 52)
        }
        .padding(.vertical, 8)
        .confirmationDialog("Remove \(contact.name)?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Remove Contact", role: .destructive) {
                familySharing.removeContact(id: contact.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will no longer be able to see your live location.")
        }
    }

    private var statusText: String {
        if shareWithContact && alertsFromContact {
            return "Sharing location • Alerts on"
        } else if shareWithContact {
            return "Sharing location"
        } else if alertsFromContact {
            return "Alerts only"
        } else {
            return "Paused"
        }
    }
}

// MARK: - Get Started Card

struct GetStartedCard: View {
    let onAddMember: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primary.opacity(0.6))

            Text("Ride Safer Together")
                .font(.headline)

            Text("Share your live location with family, friends, or instructors so they can follow along and receive safety alerts if you stop moving.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "location.fill", text: "Share your live location while riding")
                FeatureRow(icon: "bell.fill", text: "Automatic alerts if you stop unexpectedly")
                FeatureRow(icon: "figure.equestrian.sports", text: "Track gait and distance in real-time")
            }
            .padding(.vertical, 8)

            Button(action: onAddMember) {
                Label("Add Trusted Contact", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Add Contact View

struct AddFamilyMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var relationship = "Family"
    @State private var isLoading = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?

    private let relationships = ["Family", "Friend", "Instructor", "Carer", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Illustration
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.primary)
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("Add Trusted Contact")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add family, friends, or instructors who can see your live location while riding and receive safety alerts.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Contact details
                    VStack(alignment: .leading, spacing: 16) {
                        // Name (required)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("e.g. Mum, Dad, Sarah", text: $name)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Email (optional)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Email")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("(optional)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            TextField("contact@icloud.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Relationship picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Relationship")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("Relationship", selection: $relationship) {
                                ForEach(relationships, id: \.self) { rel in
                                    Text(rel).tag(rel)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 20)

                    // Add button
                    VStack(spacing: 12) {
                        Button {
                            addContact()
                        } label: {
                            Text("Add Contact")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.primary)
                        .disabled(name.isEmpty)

                        // Share link option
                        Button {
                            generateAndShareLink()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Send Invite Link", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(name.isEmpty || isLoading)

                        Text("Send a link they can tap to connect with you")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [
                        "Join me on TetraTrack to follow my rides! Tap this link to connect:",
                        url
                    ])
                }
            }
        }
    }

    private func addContact() {
        FamilySharingManager.shared.addContact(
            name: name,
            email: email.isEmpty ? nil : email,
            relationship: relationship
        )
        dismiss()
    }

    private func generateAndShareLink() {
        // First add the contact locally
        FamilySharingManager.shared.addContact(
            name: name,
            email: email.isEmpty ? nil : email,
            relationship: relationship
        )

        isLoading = true

        Task {
            if let url = await FamilySharingManager.shared.generateShareLink() {
                await MainActor.run {
                    shareURL = url
                    showingShareSheet = true
                    isLoading = false
                }
            } else {
                // Fallback - just dismiss after adding contact
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    FamilyView()
        .environment(RideTracker(locationManager: LocationManager()))
}
