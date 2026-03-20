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
        // Screens that own their own NavigationStack
        case .home:
            DisciplinesView()

        case .liveSharing:
            FamilyView()

        // iPhone capture screens — wrapped in NavigationStack
        case .riding:
            NavigationStack {
                RidingView()
            }

        case .running:
            NavigationStack {
                RunningView()
            }

        case .swimming:
            NavigationStack {
                SwimmingView()
            }

        case .shooting:
            NavigationStack {
                ShootingView()
            }

        // Detail screens — need NavigationStack + model data
        case .rideDetail:
            NavigationStack {
                if let ride = rides.first {
                    RideDetailView(ride: ride)
                } else {
                    ContentUnavailableView("No Rides", systemImage: "figure.equestrian.sports")
                }
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

        case .horseDetail:
            NavigationStack {
                if let horse = horses.first {
                    HorseDetailView(horse: horse)
                } else {
                    ContentUnavailableView("No Horses", systemImage: "pawprint")
                }
            }

        case .competitions:
            NavigationStack {
                CompetitionHubView()
            }

        case .competitionDetail:
            NavigationStack {
                if let competition = competitions.first {
                    CompetitionDetailView(competition: competition)
                } else {
                    ContentUnavailableView("No Competitions", systemImage: "calendar")
                }
            }

        case .tasks:
            NavigationStack {
                CompetitionHubView(initialTab: 2)
            }

        case .trainingHistory:
            NavigationStack {
                SessionHistoryView()
            }

        case .sessionInsights:
            NavigationStack {
                SessionHistoryView(initialTab: .insights)
            }
        }
    }
}
