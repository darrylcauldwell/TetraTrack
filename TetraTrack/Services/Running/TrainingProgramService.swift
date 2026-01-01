//
//  TrainingProgramService.swift
//  TetraTrack
//
//  Manages training program lifecycle and provides hardcoded program definitions
//

import Foundation
import SwiftData

@Observable
@MainActor
final class TrainingProgramService {

    // MARK: - Program Creation

    /// Create a new training program from a program type
    func createProgram(
        type: TrainingProgramType,
        startDate: Date = Date(),
        context: ModelContext
    ) -> TrainingProgram {
        let program = TrainingProgram(
            name: type.displayName,
            programType: type,
            startDate: startDate
        )
        program.totalWeeks = type.totalWeeks
        program.targetDistanceMeters = type.targetDistance

        // Generate program definition
        let weeks = generateWeeks(for: type)
        program.programDefinition = weeks
        program.sessionsPerWeek = weeks.first?.sessions.count ?? 3

        // Calculate total sessions
        program.totalSessions = weeks.reduce(0) { $0 + $1.sessions.count }

        // Calculate target end date
        program.targetEndDate = Calendar.current.date(
            byAdding: .weekOfYear,
            value: type.totalWeeks,
            to: startDate
        )

        context.insert(program)

        // Create ProgramSession records for each session
        var orderIndex = 0
        for week in weeks {
            for sessionDef in week.sessions {
                let session = ProgramSession(
                    weekNumber: week.weekNumber,
                    sessionNumber: sessionDef.sessionNumber,
                    orderIndex: orderIndex,
                    name: sessionDef.name,
                    targetDurationSeconds: sessionDef.totalDurationSeconds
                )
                session.sessionDefinition = sessionDef.intervals

                // Schedule date
                let weekOffset = week.weekNumber - 1
                let dayOffset = (sessionDef.sessionNumber - 1) * 2 // every other day
                session.scheduledDate = Calendar.current.date(
                    byAdding: .day,
                    value: weekOffset * 7 + dayOffset,
                    to: startDate
                )

                context.insert(session)
                if program.programSessions == nil { program.programSessions = [] }
                program.programSessions?.append(session)

                orderIndex += 1
            }
        }

        try? context.save()
        return program
    }

    // MARK: - Session Completion

    /// Complete a program session, linking it to the actual running session
    func completeSession(
        programSession: ProgramSession,
        runningSession: RunningSession,
        context: ModelContext
    ) {
        programSession.status = .completed
        programSession.completedDate = Date()
        programSession.runningSessionId = runningSession.id
        programSession.actualDurationSeconds = runningSession.totalDuration
        programSession.actualDistanceMeters = runningSession.totalDistance
        programSession.averageHeartRate = runningSession.averageHeartRate
        programSession.trainingStressScore = runningSession.trainingStress

        // Link back
        runningSession.programSessionId = programSession.id

        // Update program progress
        if let program = programSession.program {
            program.completedSessions = (program.programSessions ?? [])
                .filter { $0.status == .completed }
                .count

            // Advance week if all sessions in current week are done
            let currentWeekSessions = (program.programSessions ?? [])
                .filter { $0.weekNumber == program.currentWeek }
            let allCurrentDone = currentWeekSessions.allSatisfy { $0.status == .completed || $0.status == .skipped }
            if allCurrentDone && program.currentWeek < program.totalWeeks {
                program.currentWeek += 1
            }

            // Check program completion
            if program.completedSessions >= program.totalSessions {
                program.isCompleted = true
                program.status = .completed
            }
        }

        try? context.save()
    }

    /// Skip a program session
    func skipSession(_ programSession: ProgramSession, context: ModelContext) {
        programSession.status = .skipped
        if let program = programSession.program {
            let currentWeekSessions = (program.programSessions ?? [])
                .filter { $0.weekNumber == program.currentWeek }
            let allCurrentDone = currentWeekSessions.allSatisfy { $0.status == .completed || $0.status == .skipped }
            if allCurrentDone && program.currentWeek < program.totalWeeks {
                program.currentWeek += 1
            }
        }
        try? context.save()
    }

    /// Abandon a program
    func abandonProgram(_ program: TrainingProgram, context: ModelContext) {
        program.status = .abandoned
        try? context.save()
    }

    /// Pause/resume a program
    func togglePause(_ program: TrainingProgram, context: ModelContext) {
        program.status = program.status == .paused ? .active : .paused
        try? context.save()
    }

    // MARK: - NHS Couch to 5K Definition

    private func generateC25K() -> [ProgramWeek] {
        [
            // Week 1: Run 1min, Walk 1.5min x 8
            week(1, "First Steps", tss: 20, sessions: [
                session(1, "Run/Walk Intervals", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 60, repeatCount: 8),
                    .init(phase: .walk, durationSeconds: 90, repeatCount: 8),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "Run/Walk Intervals", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 60, repeatCount: 8),
                    .init(phase: .walk, durationSeconds: 90, repeatCount: 8),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "Run/Walk Intervals", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 60, repeatCount: 8),
                    .init(phase: .walk, durationSeconds: 90, repeatCount: 8),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 2: Run 1.5min, Walk 2min x 6
            week(2, "Building Confidence", tss: 25, sessions: [
                session(1, "Longer Runs", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 90, repeatCount: 6),
                    .init(phase: .walk, durationSeconds: 120, repeatCount: 6),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "Longer Runs", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 90, repeatCount: 6),
                    .init(phase: .walk, durationSeconds: 120, repeatCount: 6),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "Longer Runs", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 90, repeatCount: 6),
                    .init(phase: .walk, durationSeconds: 120, repeatCount: 6),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 3: Run 1.5min, Walk 1.5min, Run 3min, Walk 3min x 2
            week(3, "Stepping Up", tss: 30, sessions: [
                session(1, "Mixed Intervals", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 90),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .run, durationSeconds: 90),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "Mixed Intervals", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 90),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .run, durationSeconds: 90),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "Mixed Intervals", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 90),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .run, durationSeconds: 90),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 4: Run 3min, Walk 1.5min, Run 5min, Walk 2.5min x 2
            week(4, "Finding Your Stride", tss: 35, sessions: [
                session(1, "Building Endurance", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 150),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 150),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "Building Endurance", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 150),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 150),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "Building Endurance", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 150),
                    .init(phase: .run, durationSeconds: 180),
                    .init(phase: .walk, durationSeconds: 90),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 150),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 5: Run 5min, Walk 3min, Run 5min / Run 8min, Walk 5min, Run 8min / Run 20min
            week(5, "The Breakthrough Week", tss: 40, sessions: [
                session(1, "5-3-5", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "8-5-8", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 480),
                    .init(phase: .walk, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 480),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "20 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1200),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 6: Run 5min, Walk 3min, Run 8min / Run 10min, Walk 3min, Run 10min / Run 25min
            week(6, "Longer and Stronger", tss: 45, sessions: [
                session(1, "5-3-8", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 300),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .run, durationSeconds: 480),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "10-3-10", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 600),
                    .init(phase: .walk, durationSeconds: 180),
                    .init(phase: .run, durationSeconds: 600),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "25 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1500),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 7: Run 25min continuous
            week(7, "Continuous Running", tss: 50, sessions: [
                session(1, "25 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1500),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "25 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1500),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "25 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1500),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 8: Run 28min continuous
            week(8, "Almost There", tss: 55, sessions: [
                session(1, "28 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1680),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "28 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1680),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "28 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1680),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ]),
            // Week 9: Run 30min continuous
            week(9, "You're a Runner!", tss: 60, sessions: [
                session(1, "30 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1800),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(2, "30 Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1800),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]),
                session(3, "Graduation Run: 5K!", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: 1800),
                    .init(phase: .cooldown, durationSeconds: 300)
                ])
            ])
        ]
    }

    // MARK: - Program Generation

    private func generateWeeks(for type: TrainingProgramType) -> [ProgramWeek] {
        switch type {
        case .c25k:
            return generateC25K()
        case .c210k:
            return generateC210K()
        case .c2half:
            return generateC2Half()
        case .marathon:
            return generateDistanceProgram(weeks: 20, targetMinutes: 210, sessionsPerWeek: 4)
        }
    }

    // MARK: - C210K (builds from 5K capability)

    private func generateC210K() -> [ProgramWeek] {
        var weeks: [ProgramWeek] = []
        // Weeks 1-9: Same as C25K
        weeks.append(contentsOf: generateC25K())
        // Weeks 10-14: Progressive increase from 30 to 60 min
        let extraMinutes = [35, 40, 45, 50, 60]
        for i in 0..<5 {
            let weekNum = 10 + i
            let runMinutes = extraMinutes[i]
            weeks.append(
                week(weekNum, "Week \(weekNum): \(runMinutes) min", tss: Double(50 + i * 10), sessions: [
                    session(1, "\(runMinutes) Minute Run", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: Double(runMinutes * 60)),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ]),
                    session(2, "Easy \(max(25, runMinutes - 10)) min", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: Double(max(25, runMinutes - 10) * 60)),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ]),
                    session(3, "\(runMinutes) Minute Run", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: Double(runMinutes * 60)),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ])
                ])
            )
        }
        return weeks
    }

    // MARK: - C2Half (builds to half marathon)

    private func generateC2Half() -> [ProgramWeek] {
        var weeks: [ProgramWeek] = []
        // Weeks 1-14: C210K
        weeks.append(contentsOf: generateC210K())
        // Weeks 15-20: Progressive increase from 60 to 120 min
        let longRunMinutes = [70, 80, 90, 100, 110, 120]
        for i in 0..<6 {
            let weekNum = 15 + i
            let longRun = longRunMinutes[i]
            weeks.append(
                week(weekNum, "Week \(weekNum): Long Run \(longRun) min", tss: Double(80 + i * 10), sessions: [
                    session(1, "Easy 40 min", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: 2400),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ]),
                    session(2, "Tempo 30 min", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: 1800),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ]),
                    session(3, "Easy 35 min", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: 2100),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ]),
                    session(4, "Long Run \(longRun) min", intervals: [
                        .init(phase: .warmup, durationSeconds: 300),
                        .init(phase: .run, durationSeconds: Double(longRun * 60)),
                        .init(phase: .cooldown, durationSeconds: 300)
                    ])
                ])
            )
        }
        return weeks
    }

    // MARK: - Distance Program Template

    private func generateDistanceProgram(weeks: Int, targetMinutes: Int, sessionsPerWeek: Int) -> [ProgramWeek] {
        var result: [ProgramWeek] = []
        let startMinutes = max(20, targetMinutes / 3)

        for weekNum in 1...weeks {
            let progress = Double(weekNum) / Double(weeks)
            let weekMinutes = startMinutes + Int(Double(targetMinutes - startMinutes) * progress)
            let tss = 30 + progress * 70

            var sessions: [ProgramSessionDefinition] = []
            for s in 1...sessionsPerWeek {
                let sessionMinutes: Int
                if s == sessionsPerWeek {
                    // Long run day
                    sessionMinutes = weekMinutes
                } else if s == 1 {
                    // Easy day
                    sessionMinutes = max(20, weekMinutes - 15)
                } else {
                    // Medium day
                    sessionMinutes = max(20, weekMinutes - 5)
                }

                sessions.append(session(s, "\(sessionMinutes) Minute Run", intervals: [
                    .init(phase: .warmup, durationSeconds: 300),
                    .init(phase: .run, durationSeconds: Double(sessionMinutes * 60)),
                    .init(phase: .cooldown, durationSeconds: 300)
                ]))
            }

            result.append(week(weekNum, "Week \(weekNum)", tss: tss, sessions: sessions))
        }
        return result
    }

    // MARK: - Helpers

    private func week(_ number: Int, _ theme: String, tss: Double, sessions: [ProgramSessionDefinition]) -> ProgramWeek {
        ProgramWeek(weekNumber: number, theme: theme, sessions: sessions, weeklyTargetTSS: tss)
    }

    private func session(_ number: Int, _ name: String, intervals: [ProgramInterval]) -> ProgramSessionDefinition {
        ProgramSessionDefinition(sessionNumber: number, name: name, intervals: intervals)
    }
}
