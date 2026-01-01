//
//  RideHistoryView.swift
//  TetraTrack
//

import SwiftUI
import SwiftData
import WidgetKit

struct RideHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name) private var horses: [Horse]

    @State private var searchText = ""
    @State private var isAISearching = false
    @State private var aiSearchResults: [Int] = []
    @State private var aiSearchExplanation: String?
    @State private var showAISearch = false

    // Filter state
    @State private var showingFilters = false
    @State private var selectedHorse: Horse?
    @State private var selectedRideType: RideType?
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var hasDateFilter = false

    // Pagination state
    private static let pageSize = 20
    @State private var displayedCount = 20

    // Cached filtered results - avoids recomputing on every view update
    @State private var cachedFilteredRides: [Ride] = []
    @State private var filterCacheKey: String = ""

    /// Count of active filters
    private var activeFilterCount: Int {
        var count = 0
        if selectedHorse != nil { count += 1 }
        if selectedRideType != nil { count += 1 }
        if hasDateFilter { count += 1 }
        return count
    }

    /// Paginated rides for display (avoids rendering all rides at once)
    private var displayedRides: [Ride] {
        Array(filteredRides.prefix(displayedCount))
    }

    private var hasMoreRides: Bool {
        displayedCount < filteredRides.count
    }

    /// Cache key for filter state - changes when any filter changes
    private var currentFilterCacheKey: String {
        let horseKey = selectedHorse?.persistentModelID.hashValue ?? 0
        let typeKey = selectedRideType?.rawValue ?? "all"
        let dateKey = hasDateFilter ? "\(startDate?.timeIntervalSince1970 ?? 0)-\(endDate?.timeIntervalSince1970 ?? 0)" : "nodate"
        let searchKey = searchText
        let aiKey = aiSearchResults.hashValue
        let ridesKey = rides.count  // Invalidate when ride count changes
        return "\(horseKey)-\(typeKey)-\(dateKey)-\(searchKey)-\(aiKey)-\(ridesKey)"
    }

    private var filteredRides: [Ride] {
        // Return cached results if cache is still valid
        if filterCacheKey == currentFilterCacheKey && !cachedFilteredRides.isEmpty {
            return cachedFilteredRides
        }
        return computeFilteredRides()
    }

    private func computeFilteredRides() -> [Ride] {
        var result = rides

        // Apply horse filter - cache horse ID to avoid repeated relationship access
        if let horse = selectedHorse {
            let horseID = horse.persistentModelID
            result = result.filter { $0.horse?.persistentModelID == horseID }
        }

        // Apply ride type filter
        if let rideType = selectedRideType {
            result = result.filter { $0.rideType == rideType }
        }

        // Apply date range filter
        if hasDateFilter {
            if let start = startDate {
                result = result.filter { $0.startDate >= start }
            }
            if let end = endDate {
                // Include the entire end day
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
                result = result.filter { $0.startDate < endOfDay }
            }
        }

        // Apply search text
        if !searchText.isEmpty {
            // If we have AI search results, use those
            if !aiSearchResults.isEmpty {
                let aiFilteredSet = Set(aiSearchResults.compactMap { idx in
                    idx < rides.count ? rides[idx].persistentModelID : nil
                })
                result = result.filter { aiFilteredSet.contains($0.persistentModelID) }
            } else {
                // Basic text search
                result = result.filter { ride in
                    ride.name.localizedCaseInsensitiveContains(searchText) ||
                    ride.rideType.rawValue.localizedCaseInsensitiveContains(searchText) ||
                    ride.notes.localizedCaseInsensitiveContains(searchText) ||
                    (ride.horse?.name.localizedCaseInsensitiveContains(searchText) ?? false)
                }
            }
        }

        return result
    }

    private func updateFilterCache() {
        cachedFilteredRides = computeFilteredRides()
        filterCacheKey = currentFilterCacheKey
    }

    private func loadMoreRides() {
        displayedCount += Self.pageSize
    }

    private func clearFilters() {
        selectedHorse = nil
        selectedRideType = nil
        startDate = nil
        endDate = nil
        hasDateFilter = false
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar and AI Search toggle
                if !rides.isEmpty {
                    VStack(spacing: 0) {
                        // Active filters summary
                        if activeFilterCount > 0 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if let horse = selectedHorse {
                                        RideFilterChip(
                                            label: horse.name,
                                            icon: "figure.equestrian.sports",
                                            onRemove: { selectedHorse = nil }
                                        )
                                    }
                                    if let rideType = selectedRideType {
                                        RideFilterChip(
                                            label: rideType.rawValue.capitalized,
                                            icon: "tag",
                                            onRemove: { selectedRideType = nil }
                                        )
                                    }
                                    if hasDateFilter {
                                        RideFilterChip(
                                            label: formatDateRange(),
                                            icon: "calendar",
                                            onRemove: {
                                                hasDateFilter = false
                                                startDate = nil
                                                endDate = nil
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical, 8)
                            .background(AppColors.cardBackground)
                        }

                        HStack {
                            Image(systemName: showAISearch ? "sparkles" : "magnifyingglass")
                                .foregroundStyle(showAISearch ? .purple : .secondary)

                            Text(showAISearch ? "AI Search" : "Search")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Toggle("", isOn: $showAISearch)
                                .labelsHidden()
                                .tint(.purple)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(AppColors.cardBackground)
                    }
                }

                List {
                    // AI Search explanation
                    if let explanation = aiSearchExplanation, !searchText.isEmpty {
                        Section {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                                Text(explanation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(displayedRides) { ride in
                        NavigationLink(destination: RideDetailView(ride: ride)) {
                            RideRowView(ride: ride)
                        }
                    }
                    .onDelete(perform: deleteRides)

                    // Load More button for pagination
                    if hasMoreRides {
                        Section {
                            Button(action: loadMoreRides) {
                                HStack {
                                    Spacer()
                                    Text("Load More (\(filteredRides.count - displayedCount) remaining)")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                            .onAppear {
                                // Auto-load more when scrolling near bottom
                                loadMoreRides()
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: showAISearch ? "Ask anything about your rides..." : "Search rides")
            .onChange(of: searchText) { _, newValue in
                // Reset pagination when search changes
                displayedCount = Self.pageSize

                if showAISearch && !newValue.isEmpty {
                    performAISearch(query: newValue)
                } else {
                    aiSearchResults = []
                    aiSearchExplanation = nil
                }
            }
            .navigationTitle("Ride History")
            .overlay {
                if rides.isEmpty {
                    ContentUnavailableView(
                        "No Rides Yet",
                        systemImage: "figure.equestrian.sports",
                        description: Text("Your completed rides will appear here")
                    )
                } else if isAISearching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Searching with AI...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.cardBackground)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !rides.isEmpty {
                        Button {
                            showingFilters = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                if activeFilterCount > 0 {
                                    Text("\(activeFilterCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(AppColors.primary)
                                        .clipShape(Circle())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    if !rides.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                RideFilterSheet(
                    horses: horses,
                    selectedHorse: $selectedHorse,
                    selectedRideType: $selectedRideType,
                    startDate: $startDate,
                    endDate: $endDate,
                    hasDateFilter: $hasDateFilter
                )
                .presentationDetents([.medium, .large])
            }
            // Update filter cache when any filter changes
            .onChange(of: selectedHorse) { _, _ in updateFilterCache() }
            .onChange(of: selectedRideType) { _, _ in updateFilterCache() }
            .onChange(of: hasDateFilter) { _, _ in updateFilterCache() }
            .onChange(of: startDate) { _, _ in updateFilterCache() }
            .onChange(of: endDate) { _, _ in updateFilterCache() }
            .onChange(of: aiSearchResults) { _, _ in updateFilterCache() }
            .onChange(of: rides.count) { _, _ in updateFilterCache() }
            .onAppear { updateFilterCache() }
            .presentationBackground(Color.black)
        }
    }

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = startDate, let end = endDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = startDate {
            return "From \(formatter.string(from: start))"
        } else if let end = endDate {
            return "Until \(formatter.string(from: end))"
        }
        return "Date Range"
    }

    private func performAISearch(query: String) {
        // Debounce the search
        let searchQuery = query
        isAISearching = true

        Task {
            // Small delay for debouncing
            try? await Task.sleep(nanoseconds: 500_000_000)

            guard searchText == searchQuery else {
                await MainActor.run { isAISearching = false }
                return
            }

            if #available(iOS 26.0, *) {
                let service = IntelligenceService.shared
                guard service.isAvailable else {
                    await MainActor.run { isAISearching = false }
                    return
                }

                do {
                    let results = try await service.searchRides(query: searchQuery, rides: Array(rides))
                    await MainActor.run {
                        aiSearchResults = results.matchingIndices
                        aiSearchExplanation = results.explanation
                        isAISearching = false
                    }
                } catch {
                    await MainActor.run {
                        isAISearching = false
                        aiSearchExplanation = nil
                    }
                }
            } else {
                await MainActor.run { isAISearching = false }
            }
        }
    }

    private func deleteRides(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rides[index])
        }
        // Sync sessions to widgets
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
    }
}

// MARK: - Ride Row View

struct RideRowView: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ride.name.isEmpty ? "Untitled Ride" : ride.name)
                    .font(.headline)

                Spacer()

                // Horse badge
                if let horse = ride.horse {
                    HStack(spacing: 4) {
                        HorseAvatarView(horse: horse, size: 20)
                        Text(horse.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 16) {
                Label(ride.formattedDistance, systemImage: "arrow.left.and.right")
                Label(ride.formattedDuration, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(ride.formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Ride Filter Chip

struct RideFilterChip: View {
    let label: String
    let icon: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.primary.opacity(0.15))
        .foregroundStyle(AppColors.primary)
        .clipShape(Capsule())
    }
}

// MARK: - Ride Filter Sheet

struct RideFilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    let horses: [Horse]
    @Binding var selectedHorse: Horse?
    @Binding var selectedRideType: RideType?
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var hasDateFilter: Bool

    @State private var tempStartDate = Date()
    @State private var tempEndDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                // Horse filter
                Section("Horse") {
                    Picker("Horse", selection: $selectedHorse) {
                        Text("All Horses").tag(nil as Horse?)
                        ForEach(horses) { horse in
                            HStack {
                                HorseAvatarView(horse: horse, size: 24)
                                Text(horse.name)
                            }
                            .tag(horse as Horse?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Ride type filter
                Section("Ride Type") {
                    Picker("Type", selection: $selectedRideType) {
                        Text("All Types").tag(nil as RideType?)
                        ForEach(RideType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue.capitalized)
                            }
                            .tag(type as RideType?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Date range filter
                Section("Date Range") {
                    Toggle("Filter by Date", isOn: $hasDateFilter)

                    if hasDateFilter {
                        DatePicker(
                            "From",
                            selection: $tempStartDate,
                            displayedComponents: .date
                        )
                        .onChange(of: tempStartDate) { _, newValue in
                            startDate = newValue
                        }

                        DatePicker(
                            "To",
                            selection: $tempEndDate,
                            displayedComponents: .date
                        )
                        .onChange(of: tempEndDate) { _, newValue in
                            endDate = newValue
                        }
                    }
                }

                // Quick date presets
                if hasDateFilter {
                    Section("Quick Presets") {
                        Button("Last 7 Days") {
                            tempStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                            tempEndDate = Date()
                            startDate = tempStartDate
                            endDate = tempEndDate
                        }
                        Button("Last 30 Days") {
                            tempStartDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                            tempEndDate = Date()
                            startDate = tempStartDate
                            endDate = tempEndDate
                        }
                        Button("This Month") {
                            let now = Date()
                            tempStartDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) ?? now
                            tempEndDate = now
                            startDate = tempStartDate
                            endDate = tempEndDate
                        }
                        Button("This Year") {
                            let now = Date()
                            tempStartDate = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: now)) ?? now
                            tempEndDate = now
                            startDate = tempStartDate
                            endDate = tempEndDate
                        }
                    }
                }

                // Clear all filters
                Section {
                    Button("Clear All Filters", role: .destructive) {
                        selectedHorse = nil
                        selectedRideType = nil
                        hasDateFilter = false
                        startDate = nil
                        endDate = nil
                    }
                }
            }
            .navigationTitle("Filter Rides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let start = startDate {
                    tempStartDate = start
                }
                if let end = endDate {
                    tempEndDate = end
                }
            }
        }
    }
}

#Preview {
    RideHistoryView()
        .modelContainer(for: [Ride.self, LocationPoint.self, Horse.self], inMemory: true)
}
