//
//  EmergencyContactsView.swift
//  TrackRide
//
//  Manage emergency contacts for safety alerts
//

import SwiftUI
import SwiftData

struct EmergencyContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EmergencyContact.name) private var contacts: [EmergencyContact]

    /// Returns contacts sorted with primary contact first
    private var sortedContacts: [EmergencyContact] {
        contacts.sorted { $0.isPrimary && !$1.isPrimary }
    }

    @State private var showingAddContact = false
    @State private var editingContact: EmergencyContact?

    var body: some View {
        List {
            // Info section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.primary)

                        Text("Emergency Contacts")
                            .font(.headline)
                    }

                    Text("These contacts will be notified if a fall is detected and you don't respond within 30 seconds. They'll receive your location so they can find you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Contacts list
            Section("Your Contacts") {
                if contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)

                        Text("No emergency contacts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Add at least one contact to enable fall detection alerts")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(sortedContacts) { contact in
                        EmergencyContactRow(contact: contact)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingContact = contact
                            }
                    }
                    .onDelete(perform: deleteContacts)
                }
            }

            // Add button
            Section {
                Button(action: { showingAddContact = true }) {
                    Label("Add Emergency Contact", systemImage: "plus.circle.fill")
                }
            }

            // Medical notes
            Section("Medical Information") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optional notes for first responders")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("You can add medical conditions, allergies, or other important information that emergency contacts should know.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)

                if let primaryContact = sortedContacts.first(where: { $0.isPrimary }) {
                    NavigationLink(destination: MedicalNotesView(contact: primaryContact)) {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .foregroundStyle(AppColors.error)
                            Text("Edit Medical Notes")
                        }
                    }
                }
            }
        }
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !contacts.isEmpty {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddContact) {
            NavigationStack {
                EmergencyContactEditView(contact: nil) { newContact in
                    modelContext.insert(newContact)
                    // Make first contact primary
                    if contacts.isEmpty {
                        newContact.isPrimary = true
                    }
                }
            }
        }
        .sheet(item: $editingContact) { contact in
            NavigationStack {
                EmergencyContactEditView(contact: contact) { _ in }
            }
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        let contactsToDelete = offsets.map { sortedContacts[$0] }
        for contact in contactsToDelete {
            modelContext.delete(contact)
        }
    }
}

// MARK: - Emergency Contact Row

struct EmergencyContactRow: View {
    let contact: EmergencyContact

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(contact.isPrimary ? AppColors.primary.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)

                Text(contact.name.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(contact.isPrimary ? AppColors.primary : .secondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(contact.name)
                        .font(.headline)

                    if contact.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                }

                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(contact.phoneNumber)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Call button
            if let url = contact.callURL {
                Link(destination: url) {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.success)
                        .padding(8)
                        .background(AppColors.success.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Emergency Contact Edit View

struct EmergencyContactEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let contact: EmergencyContact?
    let onSave: (EmergencyContact) -> Void

    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    @State private var relationship: String = ""
    @State private var isPrimary: Bool = false
    @State private var notifyOnFall: Bool = true

    var body: some View {
        Form {
            Section("Contact Details") {
                TextField("Name", text: $name)
                    .textContentType(.name)

                TextField("Phone Number", text: $phoneNumber)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)

                Picker("Relationship", selection: $relationship) {
                    Text("Select...").tag("")
                    ForEach(EmergencyContact.commonRelationships, id: \.self) { rel in
                        Text(rel).tag(rel)
                    }
                }
            }

            Section("Notifications") {
                Toggle("Primary Contact", isOn: $isPrimary)

                Toggle("Notify on Fall Detection", isOn: $notifyOnFall)
            }

            if !isPrimary {
                Section {
                    Text("The primary contact will be called first in an emergency and will receive all safety alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(contact == nil ? "Add Contact" : "Edit Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveContact()
                }
                .disabled(name.isEmpty || phoneNumber.isEmpty)
            }
        }
        .onAppear {
            if let contact = contact {
                name = contact.name
                phoneNumber = contact.phoneNumber
                relationship = contact.relationship
                isPrimary = contact.isPrimary
                notifyOnFall = contact.notifyOnFall
            }
        }
    }

    private func saveContact() {
        if let existing = contact {
            existing.name = name
            existing.phoneNumber = phoneNumber
            existing.relationship = relationship
            existing.isPrimary = isPrimary
            existing.notifyOnFall = notifyOnFall
        } else {
            let newContact = EmergencyContact(
                name: name,
                phoneNumber: phoneNumber,
                relationship: relationship,
                isPrimary: isPrimary
            )
            newContact.notifyOnFall = notifyOnFall
            onSave(newContact)
        }
        dismiss()
    }
}

// MARK: - Medical Notes View

struct MedicalNotesView: View {
    @Bindable var contact: EmergencyContact

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
                TextEditor(text: $contact.medicalNotes)
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

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmergencyContactsView()
            .modelContainer(for: [EmergencyContact.self], inMemory: true)
    }
}
