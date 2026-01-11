//
//  CompetitionCalendarView.swift
//  TrackRide
//
//  Pony Club competition calendar with countdown timers
//

import SwiftUI
import SwiftData
import Combine
import WidgetKit

// MARK: - Calendar Event

enum CalendarEvent: Identifiable {
    case competition(Competition)
    case entryDeadline(Competition)
    case stableDeadline(Competition)

    var id: String {
        switch self {
        case .competition(let c): return "comp-\(c.id)"
        case .entryDeadline(let c): return "deadline-\(c.id)"
        case .stableDeadline(let c): return "stable-\(c.id)"
        }
    }

    var date: Date {
        switch self {
        case .competition(let c): return c.date
        case .entryDeadline(let c): return c.entryDeadline ?? c.date
        case .stableDeadline(let c): return c.stableDeadline ?? c.date
        }
    }

    var competition: Competition {
        switch self {
        case .competition(let c), .entryDeadline(let c), .stableDeadline(let c): return c
        }
    }

    var isUpcoming: Bool {
        date > Date() || Calendar.current.isDateInToday(date)
    }

    var isPast: Bool {
        date < Date() && !Calendar.current.isDateInToday(date)
    }
}

struct CompetitionCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Competition.date) private var competitions: [Competition]
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name) private var horses: [Horse]

    @State private var showingAddCompetition = false
    @State private var selectedCompetition: Competition?
    @State private var viewMode: ViewMode = .upcoming
    @State private var showingFilters = false

    // Filter state
    @State private var selectedHorse: Horse?
    @State private var selectedVenue: String?
    @State private var selectedType: CompetitionType?
    @State private var selectedLevel: CompetitionLevel?

    enum ViewMode: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
        case all = "All"
    }

    /// Unique venues from all competitions
    private var uniqueVenues: [String] {
        Array(Set(competitions.compactMap { $0.venue.isEmpty ? nil : $0.venue })).sorted()
    }

    /// Count of active filters
    private var activeFilterCount: Int {
        var count = 0
        if selectedHorse != nil { count += 1 }
        if selectedVenue != nil { count += 1 }
        if selectedType != nil { count += 1 }
        if selectedLevel != nil { count += 1 }
        return count
    }

    private var filteredEvents: [CalendarEvent] {
        var result: [CalendarEvent] = []

        // Build list of competitions matching filters
        var filteredComps = competitions

        // Apply horse filter
        if let horse = selectedHorse {
            filteredComps = filteredComps.filter { $0.horse?.id == horse.id }
        }

        // Apply venue filter
        if let venue = selectedVenue {
            filteredComps = filteredComps.filter { $0.venue == venue }
        }

        // Apply type filter
        if let type = selectedType {
            filteredComps = filteredComps.filter { $0.competitionType == type }
        }

        // Apply level filter
        if let level = selectedLevel {
            filteredComps = filteredComps.filter { $0.level == level }
        }

        // Add competition events and entry deadline events
        for competition in filteredComps {
            let compEvent = CalendarEvent.competition(competition)

            // Add competition event based on view mode
            switch viewMode {
            case .upcoming:
                if compEvent.isUpcoming { result.append(compEvent) }
            case .past:
                if compEvent.isPast { result.append(compEvent) }
            case .all:
                result.append(compEvent)
            }

            // Add entry deadline event if deadline exists
            if competition.entryDeadline != nil {
                let deadlineEvent = CalendarEvent.entryDeadline(competition)
                switch viewMode {
                case .upcoming:
                    if deadlineEvent.isUpcoming { result.append(deadlineEvent) }
                case .past:
                    if deadlineEvent.isPast { result.append(deadlineEvent) }
                case .all:
                    result.append(deadlineEvent)
                }
            }

            // Add stable deadline event if deadline exists
            if competition.stableDeadline != nil {
                let stableEvent = CalendarEvent.stableDeadline(competition)
                switch viewMode {
                case .upcoming:
                    if stableEvent.isUpcoming { result.append(stableEvent) }
                case .past:
                    if stableEvent.isPast { result.append(stableEvent) }
                case .all:
                    result.append(stableEvent)
                }
            }
        }

        // Sort based on view mode
        switch viewMode {
        case .upcoming, .all:
            return result.sorted { $0.date < $1.date }
        case .past:
            return result.sorted { $0.date > $1.date }
        }
    }

    private func clearFilters() {
        selectedHorse = nil
        selectedVenue = nil
        selectedType = nil
        selectedLevel = nil
    }

    private var nextCompetition: Competition? {
        competitions.filter { $0.isUpcoming || $0.isToday }.min { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Next competition countdown
                    if let next = nextCompetition {
                        NextCompetitionCard(competition: next)
                            .onTapGesture {
                                selectedCompetition = next
                            }
                    }

                    // Active filters display
                    if activeFilterCount > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if let horse = selectedHorse {
                                    CompetitionFilterChip(
                                        label: horse.name,
                                        icon: "figure.equestrian.sports",
                                        onRemove: { selectedHorse = nil }
                                    )
                                }
                                if let venue = selectedVenue {
                                    CompetitionFilterChip(
                                        label: venue,
                                        icon: "building.2",
                                        onRemove: { selectedVenue = nil }
                                    )
                                }
                                if let type = selectedType {
                                    CompetitionFilterChip(
                                        label: type.rawValue,
                                        icon: type.icon,
                                        onRemove: { selectedType = nil }
                                    )
                                }
                                if let level = selectedLevel {
                                    CompetitionFilterChip(
                                        label: level.rawValue,
                                        icon: "flag",
                                        onRemove: { selectedLevel = nil }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // View mode picker
                    Picker("View", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Competition and deadline list
                    if filteredEvents.isEmpty {
                        emptyStateView
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredEvents) { event in
                                switch event {
                                case .competition(let competition):
                                    CompetitionRowView(competition: competition)
                                        .onTapGesture {
                                            selectedCompetition = competition
                                        }
                                case .entryDeadline(let competition):
                                    EntryDeadlineRowView(competition: competition)
                                        .onTapGesture {
                                            selectedCompetition = competition
                                        }
                                case .stableDeadline(let competition):
                                    StableDeadlineRowView(competition: competition)
                                        .onTapGesture {
                                            selectedCompetition = competition
                                        }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Competitions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: CompetitionStatsView()) {
                        Image(systemName: "chart.bar.xaxis")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddCompetition = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCompetition) {
                CompetitionEditView(competition: nil)
            }
            .sheet(item: $selectedCompetition) { competition in
                CompetitionDetailView(competition: competition)
            }
            .sheet(isPresented: $showingFilters) {
                CompetitionFilterSheet(
                    horses: horses,
                    venues: uniqueVenues,
                    selectedHorse: $selectedHorse,
                    selectedVenue: $selectedVenue,
                    selectedType: $selectedType,
                    selectedLevel: $selectedLevel
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Competitions", systemImage: "calendar")
        } description: {
            Text(viewMode == .upcoming ? "Add your upcoming events to track your season" : "No past competitions to show")
        } actions: {
            if viewMode == .upcoming {
                Button("Add Competition") {
                    showingAddCompetition = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 40)
    }
}

// Components moved to CompetitionComponents.swift:
// - NextCompetitionCard
// - CountdownView, CountdownUnit, CountdownSeparator
// - CompetitionRowView
// - CompetitionDetailView
// - DetailRow, CompletedBadge
// - CompetitionEditView
// - CompetitionScorecardView
// - CompetitionTodoListView, TodoItemRow
// - CompetitionFilterChip, CompetitionFilterSheet

#Preview {
    CompetitionCalendarView()
        .modelContainer(for: [Competition.self, Horse.self], inMemory: true)
}
