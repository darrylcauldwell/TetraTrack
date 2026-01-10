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

// MARK: - Showjumping Class

/// Represents a class/round at a showjumping competition
struct ShowjumpingClass: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String  // e.g., "90cm", "1m Open", "1.10m Championship"
    var entryStatus: EntryStatus = .planning

    // Results (when competition is completed)
    var time: TimeInterval?  // Round time in seconds (optional)
    var faults: Int?  // Knockdowns, refusals, time faults etc.
    var jumpOffTime: TimeInterval?  // Jump-off time (if applicable)
    var jumpOffFaults: Int?  // Jump-off faults
    var placing: Int?  // 1st, 2nd, 3rd, etc.
    var points: Double?  // Points earned (if applicable)
    var notes: String = ""

    enum EntryStatus: String, Codable, CaseIterable {
        case planning = "Planning"
        case entered = "Entered"
        case scratched = "Scratched"
        case completed = "Completed"

        var icon: String {
            switch self {
            case .planning: return "clock"
            case .entered: return "checkmark.circle"
            case .scratched: return "xmark.circle"
            case .completed: return "flag.checkered"
            }
        }
    }

    init(name: String, entryStatus: EntryStatus = .planning) {
        self.name = name
        self.entryStatus = entryStatus
    }

    /// Whether this class has any results recorded
    var hasResults: Bool {
        faults != nil || time != nil || placing != nil
    }

    /// Formatted time string
    var formattedTime: String? {
        guard let time = time else { return nil }
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        if minutes > 0 {
            return String(format: "%d:%05.2f", minutes, seconds)
        }
        return String(format: "%.2f", seconds)
    }

    /// Formatted jump-off time string
    var formattedJumpOffTime: String? {
        guard let time = jumpOffTime else { return nil }
        let minutes = Int(time) / 60
        let seconds = time.truncatingRemainder(dividingBy: 60)
        if minutes > 0 {
            return String(format: "%d:%05.2f", minutes, seconds)
        }
        return String(format: "%.2f", seconds)
    }

    /// Result summary for display
    var resultSummary: String {
        var parts: [String] = []

        if let faults = faults {
            if faults == 0 {
                parts.append("Clear")
            } else {
                parts.append("\(faults) faults")
            }
        }

        if let time = formattedTime {
            parts.append(time)
        }

        if let placing = placing {
            parts.append(ordinalString(placing))
        }

        return parts.isEmpty ? "No result" : parts.joined(separator: " | ")
    }

    private func ordinalString(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

/// Common showjumping class heights for quick selection
enum ShowjumpingHeight: String, CaseIterable {
    case cm60 = "60cm"
    case cm70 = "70cm"
    case cm80 = "80cm"
    case cm90 = "90cm"
    case m100 = "1.00m"
    case m105 = "1.05m"
    case m110 = "1.10m"
    case m115 = "1.15m"
    case m120 = "1.20m"
    case m130 = "1.30m"
    case m140 = "1.40m"

    var displayName: String { rawValue }
}

// MARK: - Dressage Class

/// Represents a class at a dressage competition
struct DressageClass: Codable, Identifiable {
    var id: UUID = UUID()
    var testName: String  // e.g., "Prelim 12", "Novice 27", "Elementary 49"
    var className: String = ""  // Optional class name/description
    var entryStatus: EntryStatus = .planning

    // Results (when competition is completed)
    var score: Double?  // Total marks achieved
    var maxScore: Double?  // Maximum possible marks
    var percentage: Double?  // Percentage achieved
    var collectiveMarks: Double?  // Collective marks (if applicable)
    var placing: Int?
    var notes: String = ""

    enum EntryStatus: String, Codable, CaseIterable {
        case planning = "Planning"
        case entered = "Entered"
        case scratched = "Scratched"
        case completed = "Completed"

        var icon: String {
            switch self {
            case .planning: return "clock"
            case .entered: return "checkmark.circle"
            case .scratched: return "xmark.circle"
            case .completed: return "flag.checkered"
            }
        }
    }

    init(testName: String, className: String = "", entryStatus: EntryStatus = .planning) {
        self.testName = testName
        self.className = className
        self.entryStatus = entryStatus
    }

    /// Whether this class has any results recorded
    var hasResults: Bool {
        score != nil || percentage != nil || placing != nil
    }

    /// Calculated percentage from score/maxScore
    var calculatedPercentage: Double? {
        if let pct = percentage { return pct }
        if let score = score, let max = maxScore, max > 0 {
            return (score / max) * 100
        }
        return nil
    }

    /// Formatted percentage string
    var formattedPercentage: String? {
        guard let pct = calculatedPercentage else { return nil }
        return String(format: "%.2f%%", pct)
    }

    /// Result summary for display
    var resultSummary: String {
        var parts: [String] = []

        if let pct = formattedPercentage {
            parts.append(pct)
        }

        if let placing = placing {
            parts.append(ordinalString(placing))
        }

        return parts.isEmpty ? "No result" : parts.joined(separator: " | ")
    }

    private func ordinalString(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

/// Common dressage tests for quick selection (British Dressage)
enum DressageTest: String, CaseIterable {
    case introA = "Intro A"
    case introB = "Intro B"
    case introC = "Intro C"
    case prelim1 = "Prelim 1"
    case prelim2 = "Prelim 2"
    case prelim7 = "Prelim 7"
    case prelim12 = "Prelim 12"
    case prelim13 = "Prelim 13"
    case prelim14 = "Prelim 14"
    case prelim17 = "Prelim 17"
    case prelim18 = "Prelim 18"
    case novice22 = "Novice 22"
    case novice24 = "Novice 24"
    case novice27 = "Novice 27"
    case novice28 = "Novice 28"
    case novice30 = "Novice 30"
    case novice34 = "Novice 34"
    case elem42 = "Elementary 42"
    case elem43 = "Elementary 43"
    case elem44 = "Elementary 44"
    case elem49 = "Elementary 49"

    var displayName: String { rawValue }
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

    // Tetrathlon-specific start times
    var shootingStartTime: Date?
    var runningStartTime: Date?
    var swimWarmupTime: Date?
    var swimStartTime: Date?

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

    // Showjumping classes - JSON encoded array of ShowjumpingClass
    var showjumpingClassesData: Data?

    @Transient var showjumpingClasses: [ShowjumpingClass] {
        get {
            guard let data = showjumpingClassesData else { return [] }
            return (try? JSONDecoder().decode([ShowjumpingClass].self, from: data)) ?? []
        }
        set {
            showjumpingClassesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this competition has showjumping classes defined
    var hasShowjumpingClasses: Bool {
        !showjumpingClasses.isEmpty
    }

    /// Count of entered showjumping classes
    var enteredClassesCount: Int {
        showjumpingClasses.filter { $0.entryStatus == .entered || $0.entryStatus == .completed }.count
    }

    /// Count of classes with results
    var classesWithResultsCount: Int {
        showjumpingClasses.filter { $0.hasResults }.count
    }

    // Dressage classes - JSON encoded array of DressageClass
    var dressageClassesData: Data?

    @Transient var dressageClasses: [DressageClass] {
        get {
            guard let data = dressageClassesData else { return [] }
            return (try? JSONDecoder().decode([DressageClass].self, from: data)) ?? []
        }
        set {
            dressageClassesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whether this competition has dressage classes defined
    var hasDressageClasses: Bool {
        !dressageClasses.isEmpty
    }

    /// Count of entered dressage classes
    var enteredDressageClassesCount: Int {
        dressageClasses.filter { $0.entryStatus == .entered || $0.entryStatus == .completed }.count
    }

    /// Count of dressage classes with results
    var dressageClassesWithResultsCount: Int {
        dressageClasses.filter { $0.hasResults }.count
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

    // MARK: - Showjumping Class Methods

    func addShowjumpingClass(_ name: String, status: ShowjumpingClass.EntryStatus = .planning) {
        var current = showjumpingClasses
        current.append(ShowjumpingClass(name: name, entryStatus: status))
        showjumpingClasses = current
    }

    func updateShowjumpingClass(_ classEntry: ShowjumpingClass) {
        var current = showjumpingClasses
        if let index = current.firstIndex(where: { $0.id == classEntry.id }) {
            current[index] = classEntry
            showjumpingClasses = current
        }
    }

    func removeShowjumpingClass(_ id: UUID) {
        var current = showjumpingClasses
        current.removeAll { $0.id == id }
        showjumpingClasses = current
    }

    // MARK: - Dressage Class Methods

    func addDressageClass(_ testName: String, className: String = "", status: DressageClass.EntryStatus = .planning) {
        var current = dressageClasses
        current.append(DressageClass(testName: testName, className: className, entryStatus: status))
        dressageClasses = current
    }

    func updateDressageClass(_ classEntry: DressageClass) {
        var current = dressageClasses
        if let index = current.firstIndex(where: { $0.id == classEntry.id }) {
            current[index] = classEntry
            dressageClasses = current
        }
    }

    func removeDressageClass(_ id: UUID) {
        var current = dressageClasses
        current.removeAll { $0.id == id }
        dressageClasses = current
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
