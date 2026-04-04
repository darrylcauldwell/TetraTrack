//
//  CarPlaySceneDelegate.swift
//  TetraTrack
//
//  CarPlay interface for competition day navigation and at-a-glance info
//

import CarPlay
import SwiftData
import MapKit
import os

@MainActor
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let root = buildRootTemplate()
        interfaceController.setRootTemplate(root, animated: false)
        Log.app.info("CarPlay connected")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        Log.app.info("CarPlay disconnected")
    }

    // MARK: - Root Template

    private func buildRootTemplate() -> CPListTemplate {
        let context = ModelContext(TetraTrackApp.sharedModelContainer)
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Fetch today's competition
        var todayDescriptor = FetchDescriptor<Competition>(
            predicate: #Predicate<Competition> { comp in
                comp.date >= today && comp.date < tomorrow
            },
            sortBy: [SortDescriptor(\.date)]
        )
        todayDescriptor.fetchLimit = 1
        let todayComp = (try? context.fetch(todayDescriptor))?.first

        // Fetch upcoming competitions (next 5)
        var upcomingDescriptor = FetchDescriptor<Competition>(
            predicate: #Predicate<Competition> { comp in
                comp.date >= today
            },
            sortBy: [SortDescriptor(\.date)]
        )
        upcomingDescriptor.fetchLimit = 6
        let upcoming = (try? context.fetch(upcomingDescriptor)) ?? []

        var sections: [CPListSection] = []

        // Today section
        if let comp = todayComp {
            let item = competitionItem(comp, isToday: true)
            sections.append(CPListSection(items: [item], header: "Today", sectionIndexTitle: nil))
        }

        // Upcoming section (exclude today's comp if already shown)
        let upcomingFiltered = upcoming.filter { comp in
            if let todayComp { return comp.id != todayComp.id } else { return true }
        }.prefix(5)

        if !upcomingFiltered.isEmpty {
            let items = upcomingFiltered.map { competitionItem($0, isToday: false) }
            sections.append(CPListSection(items: items, header: "Upcoming", sectionIndexTitle: nil))
        }

        // Empty state
        if sections.isEmpty {
            let empty = CPListItem(text: "No upcoming competitions", detailText: "Add competitions in the TetraTrack app")
            sections.append(CPListSection(items: [empty]))
        }

        return CPListTemplate(title: "TetraTrack", sections: sections)
    }

    // MARK: - Competition List Item

    private func competitionItem(_ comp: Competition, isToday: Bool) -> CPListItem {
        let title = comp.name.isEmpty ? "Competition" : comp.name
        var subtitle = ""

        if isToday {
            let venue = comp.venue.isEmpty ? comp.location : comp.venue
            if !venue.isEmpty {
                subtitle = venue
            }
            if let arrival = comp.estimatedArrivalAtVenue {
                let time = formatTime(arrival)
                subtitle += subtitle.isEmpty ? "Arrive \(time)" : " · Arrive \(time)"
            }
        } else {
            subtitle = comp.formattedDate
            let venue = comp.venue.isEmpty ? comp.location : comp.venue
            if !venue.isEmpty {
                subtitle += " · \(venue)"
            }
        }

        let item = CPListItem(
            text: title,
            detailText: subtitle.isEmpty ? nil : subtitle,
            image: UIImage(systemName: "calendar"),
            showsDisclosureIndicator: true
        )

        // Capture data for detail view (avoid storing Competition reference)
        let compID = comp.id
        item.handler = { [weak self] _, completion in
            self?.showDetail(competitionID: compID)
            completion()
        }

        return item
    }

    // MARK: - Detail Template

    private func showDetail(competitionID: UUID) {
        let context = ModelContext(TetraTrackApp.sharedModelContainer)
        var descriptor = FetchDescriptor<Competition>(
            predicate: #Predicate<Competition> { $0.id == competitionID }
        )
        descriptor.fetchLimit = 1
        guard let comp = (try? context.fetch(descriptor))?.first else { return }

        let detail = buildDetailTemplate(for: comp)
        interfaceController?.pushTemplate(detail, animated: true)
    }

    private func buildDetailTemplate(for comp: Competition) -> CPListTemplate {
        let title = comp.name.isEmpty ? "Competition" : comp.name
        var sections: [CPListSection] = []

        // Navigate section
        sections.append(buildNavigateSection(for: comp))

        // Schedule section
        let scheduleItems = buildScheduleItems(for: comp)
        if !scheduleItems.isEmpty {
            sections.append(CPListSection(items: scheduleItems, header: "Schedule", sectionIndexTitle: nil))
        }

        // Assignments section
        let assignmentItems = buildAssignmentItems(for: comp)
        if !assignmentItems.isEmpty {
            sections.append(CPListSection(items: assignmentItems, header: "Assignments", sectionIndexTitle: nil))
        }

        // Travel notes section
        if !comp.travelRouteNotes.isEmpty {
            let notesItem = CPListItem(
                text: "Route Notes",
                detailText: String(comp.travelRouteNotes.prefix(100))
            )
            sections.append(CPListSection(items: [notesItem], header: "Travel", sectionIndexTitle: nil))
        }

        return CPListTemplate(title: title, sections: sections)
    }

    // MARK: - Navigate Section

    private func buildNavigateSection(for comp: Competition) -> CPListSection {
        let venue = comp.venue.isEmpty ? comp.location : comp.venue
        let hasCoordinates = comp.venueLatitude != nil && comp.venueLongitude != nil

        let navItem = CPListItem(
            text: hasCoordinates ? "Navigate to Venue" : "No Location Set",
            detailText: venue.isEmpty ? nil : venue,
            image: UIImage(systemName: hasCoordinates ? "location.fill" : "location.slash")
        )

        if hasCoordinates, let lat = comp.venueLatitude, let lon = comp.venueLongitude {
            let venueName = venue.isEmpty ? comp.name : venue
            navItem.handler = { _, completion in
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let placemark = MKPlacemark(coordinate: coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = venueName
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
                completion()
            }
        }

        return CPListSection(items: [navItem], header: "Navigation", sectionIndexTitle: nil)
    }

    // MARK: - Schedule Items

    private func buildScheduleItems(for comp: Competition) -> [CPListItem] {
        var items: [CPListItem] = []

        if let time = comp.arriveAtYard {
            items.append(CPListItem(text: "Arrive at Yard", detailText: formatTime(time)))
        }
        if let time = comp.departureFromYard {
            items.append(CPListItem(text: "Depart Yard", detailText: formatTime(time)))
        }
        if let time = comp.estimatedArrivalAtVenue {
            items.append(CPListItem(text: "Arrive at Venue", detailText: formatTime(time)))
        }
        if let time = comp.courseWalkTime {
            items.append(CPListItem(text: "Course Walk", detailText: formatTime(time)))
        }
        if let time = comp.shootingStartTime {
            var detail = formatTime(time)
            if let lane = comp.shootingLane, lane > 0 { detail += " · Lane \(lane)" }
            items.append(CPListItem(text: "Shooting", detailText: detail))
        }
        if let time = comp.swimStartTime {
            var detail = formatTime(time)
            if let lane = comp.swimmingLane, lane > 0 { detail += " · Lane \(lane)" }
            items.append(CPListItem(text: "Swimming", detailText: detail))
        }
        if let time = comp.runningStartTime {
            var detail = formatTime(time)
            if let bib = comp.runningCompetitorNumber, bib > 0 { detail += " · #\(bib)" }
            items.append(CPListItem(text: "Running", detailText: detail))
        }
        if let time = comp.prizeGivingTime {
            items.append(CPListItem(text: "Prize Giving", detailText: formatTime(time)))
        }

        return items
    }

    // MARK: - Assignment Items

    private func buildAssignmentItems(for comp: Competition) -> [CPListItem] {
        var items: [CPListItem] = []

        if let lane = comp.shootingLane, lane > 0 {
            items.append(CPListItem(text: "Shooting Lane", detailText: "\(lane)"))
        }
        if let lane = comp.swimmingLane, lane > 0 {
            items.append(CPListItem(text: "Swimming Lane", detailText: "\(lane)"))
        }
        if let bib = comp.runningCompetitorNumber, bib > 0 {
            items.append(CPListItem(text: "Bib Number", detailText: "#\(bib)"))
        }

        return items
    }

    // MARK: - Formatting

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
