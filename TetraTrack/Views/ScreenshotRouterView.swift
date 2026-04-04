//
//  ScreenshotRouterView.swift
//  TetraTrack
//
//  Renders a specific screen for simctl screenshot capture.
//  Used in screenshot mode to bypass navigation and show the target screen directly.
//

import SwiftUI
import SwiftData

struct ScreenshotRouterView: View {
    let screen: ScreenshotScreen

    @Query(sort: \Ride.startDate, order: .reverse) private var rides: [Ride]
    @Query(sort: \Horse.name) private var horses: [Horse]
    @Query(sort: \Competition.date, order: .reverse) private var competitions: [Competition]

    var body: some View {
        switch screen {
        case .home:
            DisciplinesView()

        case .training:
            NavigationStack {
                UnifiedTrainingView()
            }

        case .schooling:
            NavigationStack {
                ExerciseLibraryView()
            }

        case .competitions:
            NavigationStack {
                CompetitionHubView()
            }

        case .competitionDay:
            NavigationStack {
                CompetitionDayView()
            }

        case .sessionHistory:
            NavigationStack {
                SessionHistoryView()
            }

        case .sessionInsights:
            NavigationStack {
                SessionHistoryView(initialTab: .insights)
            }

        case .horseProfile:
            NavigationStack {
                if let horse = horses.first {
                    HorseDetailView(horse: horse)
                } else {
                    ContentUnavailableView("No Horses", systemImage: "pawprint")
                }
            }

        case .horseList:
            NavigationStack {
                HorseListView()
            }

        case .rideDetail:
            NavigationStack {
                if let ride = rides.first {
                    RideDetailView(ride: ride)
                } else {
                    ContentUnavailableView("No Rides", systemImage: "figure.equestrian.sports")
                }
            }

        case .liveSharing:
            FamilyView()
        }
    }
}
