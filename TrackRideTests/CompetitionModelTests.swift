//
//  CompetitionModelTests.swift
//  TrackRideTests
//
//  Tests for Competition model functionality
//

import Testing
import Foundation
@testable import TetraTrack

struct CompetitionModelTests {

    // MARK: - Basic Properties

    @Test func competitionInitializationWithDefaults() {
        let competition = Competition()

        #expect(competition.name == "")
        #expect(competition.location == "")
        #expect(competition.isEntered == false)
        #expect(competition.isCompleted == false)
    }

    @Test func competitionInitializationWithValues() {
        let competition = Competition(
            name: "Regional Championships",
            date: Date(),
            location: "County Showground",
            competitionType: .tetrathlon,
            level: .junior
        )

        #expect(competition.name == "Regional Championships")
        #expect(competition.location == "County Showground")
        #expect(competition.competitionType == .tetrathlon)
        #expect(competition.level == .junior)
    }

    // MARK: - Date Calculations

    @Test func competitionIsUpcoming() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let competition = Competition(name: "Future Event", date: futureDate)

        #expect(competition.isUpcoming == true)
        #expect(competition.isPast == false)
    }

    @Test func competitionIsPast() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let competition = Competition(name: "Past Event", date: pastDate)

        #expect(competition.isPast == true)
        #expect(competition.isUpcoming == false)
    }

    @Test func competitionDaysUntil() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let competition = Competition(name: "Upcoming", date: futureDate)

        #expect(competition.daysUntil == 5)
    }

    @Test func competitionCountdownTextTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let competition = Competition(name: "Tomorrow Event", date: tomorrow)

        #expect(competition.countdownText == "Tomorrow")
    }

    @Test func competitionCountdownTextDays() {
        let fiveDays = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let competition = Competition(name: "Five Days", date: fiveDays)

        #expect(competition.countdownText == "5 days")
    }

    // MARK: - Entry Deadline

    @Test func entryDeadlinePassed() {
        let competition = Competition(name: "Test")
        let pastDeadline = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        competition.entryDeadline = pastDeadline

        #expect(competition.entryDeadlinePassed == true)
    }

    @Test func entryDeadlineNotPassed() {
        let competition = Competition(name: "Test")
        let futureDeadline = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        competition.entryDeadline = futureDeadline

        #expect(competition.entryDeadlinePassed == false)
    }

    // MARK: - Competition Type

    @Test func competitionTypeTetrathlon() {
        let type = CompetitionType.tetrathlon

        #expect(type.disciplines.count == 4)
        #expect(type.disciplines.contains("Riding"))
        #expect(type.disciplines.contains("Shooting"))
        #expect(type.disciplines.contains("Swimming"))
        #expect(type.disciplines.contains("Running"))
    }

    @Test func competitionTypeTriathlon() {
        let type = CompetitionType.triathlon

        #expect(type.disciplines.count == 3)
        #expect(type.disciplines.contains("Riding"))
        #expect(type.disciplines.contains("Swimming"))
        #expect(type.disciplines.contains("Running"))
    }

    @Test func competitionTypeEventing() {
        let type = CompetitionType.eventing

        #expect(type.disciplines.count == 3)
        #expect(type.disciplines.contains("Dressage"))
        #expect(type.disciplines.contains("Cross Country"))
        #expect(type.disciplines.contains("Show Jumping"))
    }

    @Test func competitionTypeIcons() {
        #expect(CompetitionType.tetrathlon.icon == "star.fill")
        #expect(CompetitionType.eventing.icon == "figure.equestrian.sports")
        #expect(CompetitionType.showJumping.icon == "arrow.up.forward")
    }

    // MARK: - Competition Level

    @Test func competitionLevelRunDistances() {
        #expect(CompetitionLevel.minimus.runDistance == 1000)
        #expect(CompetitionLevel.junior.runDistance == 1500)
        #expect(CompetitionLevel.intermediateBoys.runDistance == 2000)
        #expect(CompetitionLevel.openBoys.runDistance == 3000)
    }

    @Test func competitionLevelSwimDurations() {
        #expect(CompetitionLevel.minimus.swimDuration == 120) // 2 minutes
        #expect(CompetitionLevel.junior.swimDuration == 180) // 3 minutes
        #expect(CompetitionLevel.openBoys.swimDuration == 240) // 4 minutes
    }

    @Test func competitionLevelAgeRanges() {
        #expect(CompetitionLevel.minimus.ageRange == "11 & under")
        #expect(CompetitionLevel.junior.ageRange == "14 & under")
        #expect(CompetitionLevel.openGirls.ageRange == "25 & under")
    }

    // MARK: - Todos

    @Test func competitionAddTodo() {
        let competition = Competition(name: "Test")
        let initialCount = competition.todos.count

        competition.addTodo("Pack riding boots")

        #expect(competition.todos.count == initialCount + 1)
        #expect(competition.todos.last?.title == "Pack riding boots")
        #expect(competition.todos.last?.isCompleted == false)
    }

    @Test func competitionToggleTodo() {
        let competition = Competition(name: "Test")
        competition.addTodo("Check entries")

        let todoId = competition.todos.first!.id
        competition.toggleTodo(todoId)

        #expect(competition.todos.first?.isCompleted == true)
    }

    @Test func competitionPendingTodosCount() {
        let competition = Competition(name: "Test")
        competition.addTodo("Task 1")
        competition.addTodo("Task 2")
        competition.addTodo("Task 3")

        let firstId = competition.todos.first!.id
        competition.toggleTodo(firstId)

        #expect(competition.pendingTodosCount == 2)
    }

    // MARK: - Scores

    @Test func competitionHasAnyScore() {
        let competition = Competition(name: "Test")

        #expect(competition.hasAnyScore == false)

        competition.ridingScore = 85.0
        #expect(competition.hasAnyScore == true)
    }

    @Test func competitionTotalPoints() {
        let competition = Competition(name: "Test")
        competition.ridingScore = 100
        competition.shootingScore = 80

        #expect(competition.totalPoints == 180)
    }
}
