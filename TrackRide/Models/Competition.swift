//
//  Competition.swift
//  TrackRide
//
//  Pony Club competition calendar - tetrathlon and eventing events
//

import Foundation
import SwiftData

// MARK: - Competition Todo

struct CompetitionTodo: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var completedAt: Date?

    mutating func toggle() {
        isCompleted.toggle()
        completedAt = isCompleted ? Date() : nil
    }
}

// MARK: - Competition

@Model
final class Competition {
    var id: UUID = UUID()
    var name: String = ""
    var date: Date = Date()
    var endDate: Date?
    var location: String = ""
    var venue: String = ""
    var competitionTypeRaw: String = "tetrathlon"
    var levelRaw: String = "open"
    var notes: String = ""
    var entryDeadline: Date?
    var entryFee: Double?
    var isEntered: Bool = false
    var websiteURL: String = ""
    var organizerContact: String = ""

    // Stable booking
    var stableDeadline: Date?
    var isStableBooked: Bool = false

    // Travel plan
    var startTime: Date?
    var courseWalkTime: Date?
    var estimatedArrivalAtVenue: Date?
    var estimatedTravelMinutes: Int?
    var travelRouteNotes: String = ""
    var departureFromYard: Date?
    var departureFromVenue: Date?
    var arrivalBackAtYard: Date?
    var isTravelPlanned: Bool = false

    // Results (if completed)
    var isCompleted: Bool = false
    var overallPlacing: Int?
    var ridingScore: Double?
    var shootingScore: Int?
    var swimmingDistance: Double?
    var runningTime: TimeInterval?
    var storedTotalPoints: Double?
    var placement: String?
    var resultNotes: String?

    // Media attachments - photos and videos from the competition
    @Attribute(.externalStorage) var photos: [Data] = []

    // Video references - stored as PHAsset local identifiers (videos stay in Apple Photos)
    var videoAssetIdentifiers: [String] = []
    @Attribute(.externalStorage) var videoThumbnails: [Data] = []

    // Legacy video data storage (for backwards compatibility)
    @Attribute(.externalStorage) var videos: [Data] = []

    // Horse relationship (optional - for tracking which horse competed)
    var horse: Horse?

    // Competition tasks relationship
    @Relationship(deleteRule: .cascade, inverse: \CompetitionTask.competition)
    var tasks: [CompetitionTask]? = []

    // Todo list for follow-up tasks
    var todosData: Data?  // JSON encoded CompetitionTodo array

    @Transient var todos: [CompetitionTodo] {
        get {
            guard let data = todosData else { return [] }
            return (try? JSONDecoder().decode([CompetitionTodo].self, from: data)) ?? []
        }
        set {
            todosData = try? JSONEncoder().encode(newValue)
        }
    }

    var pendingTodosCount: Int {
        todos.filter { !$0.isCompleted }.count
    }

    init() {}

    func addTodo(_ title: String) {
        var current = todos
        current.append(CompetitionTodo(title: title))
        todos = current
    }

    func toggleTodo(_ id: UUID) {
        var current = todos
        if let index = current.firstIndex(where: { $0.id == id }) {
            current[index].isCompleted.toggle()
            todos = current
        }
    }

    func removeTodo(_ id: UUID) {
        var current = todos
        current.removeAll { $0.id == id }
        todos = current
    }

    var hasAnyScore: Bool {
        ridingScore != nil || shootingScore != nil || swimmingDistance != nil || runningTime != nil
    }

    var totalPoints: Int {
        var points = 0
        if let riding = ridingScore { points += Int(riding) }
        if let shooting = shootingScore { points += shooting }
        // Swimming and running scores would need proper conversion based on competition tables
        return points
    }

    var competitionType: CompetitionType {
        get { CompetitionType(rawValue: competitionTypeRaw) ?? .tetrathlon }
        set { competitionTypeRaw = newValue.rawValue }
    }

    var level: CompetitionLevel {
        get { CompetitionLevel(rawValue: levelRaw) ?? .junior }
        set { levelRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        date: Date = Date(),
        location: String = "",
        competitionType: CompetitionType = .tetrathlon,
        level: CompetitionLevel = .junior
    ) {
        self.name = name
        self.date = date
        self.location = location
        self.competitionTypeRaw = competitionType.rawValue
        self.levelRaw = level.rawValue
    }

    // MARK: - Computed Properties

    var isUpcoming: Bool {
        date > Date()
    }

    var isPast: Bool {
        date < Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var daysUntil: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfEvent = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfEvent)
        return components.day ?? 0
    }

    var countdownText: String {
        let days = daysUntil
        if days < 0 {
            return "\(abs(days)) days ago"
        } else if days == 0 {
            return "Today!"
        } else if days == 1 {
            return "Tomorrow"
        } else if days < 7 {
            return "\(days) days"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks) \(weeks == 1 ? "week" : "weeks")"
        } else {
            let months = days / 30
            return "\(months) \(months == 1 ? "month" : "months")"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        if let end = endDate, !Calendar.current.isDate(date, inSameDayAs: end) {
            return "\(formatter.string(from: date)) - \(formatter.string(from: end))"
        }
        return formatter.string(from: date)
    }

    var entryDeadlinePassed: Bool {
        guard let deadline = entryDeadline else { return false }
        return deadline < Date()
    }

    var daysUntilEntryDeadline: Int? {
        guard let deadline = entryDeadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }

    var stableDeadlinePassed: Bool {
        guard let deadline = stableDeadline else { return false }
        return deadline < Date()
    }

    var daysUntilStableDeadline: Int? {
        guard let deadline = stableDeadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }

    var hasTravelPlan: Bool {
        startTime != nil || departureFromYard != nil || estimatedArrivalAtVenue != nil
    }
}

// MARK: - Competition Type

enum CompetitionType: String, Codable, CaseIterable {
    case tetrathlon = "Tetrathlon"
    case triathlon = "Triathlon"
    case eventing = "Eventing"
    case showJumping = "Show Jumping"
    case dressage = "Dressage"
    case crossCountry = "Cross Country"
    case huntingTrial = "Hunting Trial"
    case other = "Other"

    var icon: String {
        switch self {
        case .tetrathlon: return "star.fill"
        case .triathlon: return "triangle.fill"
        case .eventing: return "figure.equestrian.sports"
        case .showJumping: return "arrow.up.forward"
        case .dressage: return "circle.hexagonpath"
        case .crossCountry: return "figure.outdoor.cycle"
        case .huntingTrial: return "leaf.fill"
        case .other: return "flag.fill"
        }
    }

    var disciplines: [String] {
        switch self {
        case .tetrathlon:
            return ["Riding", "Shooting", "Swimming", "Running"]
        case .triathlon:
            return ["Riding", "Swimming", "Running"]
        case .eventing:
            return ["Dressage", "Cross Country", "Show Jumping"]
        case .showJumping:
            return ["Show Jumping"]
        case .dressage:
            return ["Dressage"]
        case .crossCountry:
            return ["Cross Country"]
        case .huntingTrial:
            return ["Hunting"]
        case .other:
            return []
        }
    }
}

// MARK: - Competition Level (Pony Club Tetrathlon Age Classes)

enum CompetitionLevel: String, Codable, CaseIterable {
    case minimus = "Minimus"
    case junior = "Junior"
    case intermediateGirls = "Intermediate Girls"
    case intermediateBoys = "Intermediate Boys"
    case openGirls = "Open Girls"
    case openBoys = "Open Boys"

    var displayName: String {
        rawValue
    }

    var ageRange: String {
        switch self {
        case .minimus: return "11 & under"
        case .junior: return "14 & under"
        case .intermediateGirls, .intermediateBoys: return "25 & under"
        case .openGirls, .openBoys: return "25 & under"
        }
    }

    var runDistance: Double {
        switch self {
        case .minimus: return 1000
        case .junior: return 1500
        case .intermediateGirls: return 1500
        case .intermediateBoys: return 2000
        case .openGirls: return 1500
        case .openBoys: return 3000
        }
    }

    var formattedRunDistance: String {
        if runDistance >= 1000 {
            return String(format: "%.0fm", runDistance)
        }
        return String(format: "%.0fm", runDistance)
    }

    var swimDuration: TimeInterval {
        switch self {
        case .minimus: return 120 // 2 minutes
        case .junior: return 180 // 3 minutes
        case .intermediateGirls, .intermediateBoys: return 180 // 3 minutes
        case .openGirls: return 180 // 3 minutes
        case .openBoys: return 240 // 4 minutes
        }
    }

    var formattedSwimDuration: String {
        let minutes = Int(swimDuration / 60)
        let seconds = Int(swimDuration.truncatingRemainder(dividingBy: 60))
        if seconds == 0 {
            return "\(minutes) min"
        }
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    // Group levels for display
    static var groupedLevels: [(String, [CompetitionLevel])] {
        [
            ("Minimus (11 & under)", [.minimus]),
            ("Junior (14 & under)", [.junior]),
            ("Intermediate (25 & under)", [.intermediateGirls, .intermediateBoys]),
            ("Open (25 & under)", [.openGirls, .openBoys])
        ]
    }
}

// MARK: - Season

struct CompetitionSeason {
    let year: Int
    let competitions: [Competition]

    var upcoming: [Competition] {
        competitions.filter { $0.isUpcoming }.sorted { $0.date < $1.date }
    }

    var past: [Competition] {
        competitions.filter { $0.isPast }.sorted { $0.date > $1.date }
    }

    var nextCompetition: Competition? {
        upcoming.first
    }

    var entered: [Competition] {
        competitions.filter { $0.isEntered }
    }

    var completed: [Competition] {
        competitions.filter { $0.isCompleted }
    }

    var totalCompetitions: Int {
        competitions.count
    }

    var competitionsEntered: Int {
        entered.count
    }

    var competitionsCompleted: Int {
        completed.count
    }
}

// MARK: - Built-in Competition Templates

extension Competition {
    static func createSampleCompetitions() -> [Competition] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        var competitions: [Competition] = []

        // Sample Pony Club events
        let events: [(String, String, Int, Int, CompetitionType, CompetitionLevel)] = [
            ("Area Tetrathlon - Junior", "Regional Pony Club Centre", 3, 15, .tetrathlon, .junior),
            ("Spring Triathlon - Open", "County Showground", 4, 20, .triathlon, .openGirls),
            ("Zone Championships", "National Equestrian Centre", 5, 10, .tetrathlon, .openBoys),
            ("Summer Tetrathlon - Intermediate", "Pony Club HQ", 6, 5, .tetrathlon, .intermediateBoys),
            ("Autumn Tetrathlon - Minimus", "Local Riding School", 9, 12, .tetrathlon, .minimus),
            ("Regional Finals - Junior", "Area Sports Complex", 7, 22, .tetrathlon, .junior),
        ]

        for (name, location, month, day, type, level) in events {
            if let date = calendar.date(from: DateComponents(year: currentYear, month: month, day: day)) {
                let comp = Competition(
                    name: name,
                    date: date,
                    location: location,
                    competitionType: type,
                    level: level
                )
                comp.entryDeadline = calendar.date(byAdding: .day, value: -14, to: date)
                competitions.append(comp)
            }
        }

        return competitions
    }
}
