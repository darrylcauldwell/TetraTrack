//
//  HorseListView.swift
//  TrackRide
//
//  Main list view for managing horses

import SwiftUI
import SwiftData

struct HorseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name)
    private var horses: [Horse]

    @State private var showingAddHorse = false
    @State private var horseToDelete: Horse?
    @State private var showingDeleteConfirmation = false
    @State private var selectedHorse: Horse?

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
    }

    // MARK: - iPad Layout (Split View)

    private var iPadLayout: some View {
        NavigationSplitView {
            horseListContent
                .navigationTitle("Horses")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingAddHorse = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
        } detail: {
            if let horse = selectedHorse {
                HorseDetailView(horse: horse)
            } else {
                ContentUnavailableView(
                    "Select a Horse",
                    systemImage: "figure.equestrian.sports",
                    description: Text("Choose a horse to view details")
                )
            }
        }
        .sheet(isPresented: $showingAddHorse) {
            HorseEditView(horse: nil)
        }
        .confirmationDialog(
            "Delete \(horseToDelete?.name ?? "Horse")?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                if let horse = horseToDelete {
                    deleteHorse(horse)
                }
            }
            Button("Archive Instead") {
                if let horse = horseToDelete {
                    archiveHorse(horse)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the horse and remove it from all ride history. Archive instead to hide the horse but keep historical data.")
        }
    }

    // MARK: - iPhone Layout (Stack)

    private var iPhoneLayout: some View {
        NavigationStack {
            horseListContent
                .navigationTitle("Horses")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingAddHorse = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddHorse) {
                    HorseEditView(horse: nil)
                }
                .confirmationDialog(
                    "Delete \(horseToDelete?.name ?? "Horse")?",
                    isPresented: $showingDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Permanently", role: .destructive) {
                        if let horse = horseToDelete {
                            deleteHorse(horse)
                        }
                    }
                    Button("Archive Instead") {
                        if let horse = horseToDelete {
                            archiveHorse(horse)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete the horse and remove it from all ride history. Archive instead to hide the horse but keep historical data.")
                }
                .presentationBackground(Color.black)
        }
    }

    // MARK: - Shared List Content

    private var horseListContent: some View {
        List(selection: horizontalSizeClass == .regular ? $selectedHorse : .constant(nil)) {
            ForEach(horses) { horse in
                Group {
                    if horizontalSizeClass == .regular {
                        HorseRowView(horse: horse)
                            .tag(horse)
                    } else {
                        NavigationLink(destination: HorseDetailView(horse: horse)) {
                            HorseRowView(horse: horse)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        horseToDelete = horse
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        archiveHorse(horse)
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if horses.isEmpty {
                ContentUnavailableView(
                    "No Horses Yet",
                    systemImage: "figure.equestrian.sports",
                    description: Text("Add your first horse to track their rides and fitness")
                )
            }
        }
    }

    private func archiveHorse(_ horse: Horse) {
        horse.isArchived = true
        horse.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteHorse(_ horse: Horse) {
        modelContext.delete(horse)
        try? modelContext.save()
    }
}

#Preview {
    HorseListView()
        .modelContainer(for: [Horse.self, Ride.self], inMemory: true)
}
