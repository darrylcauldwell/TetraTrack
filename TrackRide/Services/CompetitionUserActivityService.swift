//
//  CompetitionUserActivityService.swift
//  TrackRide
//
//  NSUserActivity support for competitions to surface in Maps and Siri Suggestions
//

import Foundation
import CoreLocation
import CoreSpotlight
import UniformTypeIdentifiers
import Intents

/// Activity type identifiers for competitions
enum CompetitionActivityType {
    static let viewCompetition = "com.tetratrack.viewCompetition"
    static let upcomingCompetition = "com.tetratrack.upcomingCompetition"
}

/// Service for managing NSUserActivity for competitions
final class CompetitionUserActivityService {

    static let shared = CompetitionUserActivityService()

    private init() {}

    // MARK: - Create Activity for Viewing Competition

    /// Creates an NSUserActivity for viewing a competition
    /// This allows the competition to appear in Siri Suggestions and Maps
    func createActivity(for competition: Competition) -> NSUserActivity {
        let activity = NSUserActivity(activityType: CompetitionActivityType.viewCompetition)

        // Basic info
        activity.title = competition.name.isEmpty ? "Competition" : competition.name
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.isEligibleForPublicIndexing = false

        // User info for restoring state
        activity.userInfo = [
            "competitionID": competition.id.uuidString,
            "competitionName": competition.name,
            "competitionDate": competition.date.timeIntervalSince1970
        ]

        // Keywords for search
        var keywords: Set<String> = ["competition", "tetrathlon", "triathlon", "pony club"]
        if !competition.name.isEmpty {
            keywords.insert(competition.name)
        }
        if !competition.venue.isEmpty {
            keywords.insert(competition.venue)
        }
        keywords.insert(competition.competitionType.rawValue)
        activity.keywords = keywords

        // Content attributes for Spotlight
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.displayName = competition.name.isEmpty ? "Competition" : competition.name

        // Build description
        var descriptionParts: [String] = []
        descriptionParts.append(competition.competitionType.rawValue)
        if !competition.venue.isEmpty {
            descriptionParts.append(competition.venue)
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        descriptionParts.append(dateFormatter.string(from: competition.date))
        attributes.contentDescription = descriptionParts.joined(separator: " • ")

        // Location for Maps integration
        if let lat = competition.venueLatitude, let lon = competition.venueLongitude {
            attributes.latitude = lat as NSNumber
            attributes.longitude = lon as NSNumber

            // Also set supportsNavigation for Maps
            attributes.supportsNavigation = 1

            // Set the location name
            if !competition.venue.isEmpty {
                attributes.namedLocation = competition.venue
            }
        }

        // Calendar-like attributes
        attributes.startDate = competition.date
        if let endDate = competition.endDate {
            attributes.endDate = endDate
        } else {
            // Default to end of day
            attributes.endDate = Calendar.current.date(byAdding: .hour, value: 8, to: competition.date)
        }

        activity.contentAttributeSet = attributes

        // Suggested invocation phrase for Siri
        activity.suggestedInvocationPhrase = "Open \(competition.name.isEmpty ? "competition" : competition.name)"

        return activity
    }

    // MARK: - Donate Activity

    /// Donates an activity to the system for a viewed competition
    func donateActivity(for competition: Competition) {
        let activity = createActivity(for: competition)
        activity.becomeCurrent()
    }

    /// Resigns the current activity
    func resignActivity(_ activity: NSUserActivity?) {
        activity?.resignCurrent()
    }

    // MARK: - Index Upcoming Competitions

    /// Index all upcoming competitions for Spotlight and Maps
    func indexUpcomingCompetitions(_ competitions: [Competition]) {
        let upcomingCompetitions = competitions.filter { $0.isUpcoming && $0.isEntered }

        var searchableItems: [CSSearchableItem] = []

        for competition in upcomingCompetitions {
            let attributes = CSSearchableItemAttributeSet(contentType: .content)
            attributes.displayName = competition.name.isEmpty ? "Competition" : competition.name

            // Build description
            var descriptionParts: [String] = []
            descriptionParts.append(competition.competitionType.rawValue)
            if !competition.venue.isEmpty {
                descriptionParts.append(competition.venue)
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            descriptionParts.append(dateFormatter.string(from: competition.date))
            attributes.contentDescription = descriptionParts.joined(separator: " • ")

            // Location
            if let lat = competition.venueLatitude, let lon = competition.venueLongitude {
                attributes.latitude = lat as NSNumber
                attributes.longitude = lon as NSNumber
                attributes.supportsNavigation = 1
                if !competition.venue.isEmpty {
                    attributes.namedLocation = competition.venue
                }
            }

            // Calendar attributes
            attributes.startDate = competition.date
            if let endDate = competition.endDate {
                attributes.endDate = endDate
            }

            // Keywords
            var keywords: [String] = ["competition", "tetrathlon", "triathlon", "pony club"]
            if !competition.name.isEmpty {
                keywords.append(competition.name)
            }
            if !competition.venue.isEmpty {
                keywords.append(competition.venue)
            }
            attributes.keywords = keywords

            let item = CSSearchableItem(
                uniqueIdentifier: "competition-\(competition.id.uuidString)",
                domainIdentifier: "com.tetratrack.competitions",
                attributeSet: attributes
            )

            // Set expiration to day after competition
            if let expirationDate = Calendar.current.date(byAdding: .day, value: 1, to: competition.date) {
                item.expirationDate = expirationDate
            }

            searchableItems.append(item)
        }

        // Index items
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { _ in
            // Silently handle indexing result
        }
    }

    /// Remove a competition from the index
    func removeFromIndex(competitionID: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["competition-\(competitionID.uuidString)"]) { _ in
            // Silently handle removal
        }
    }

    /// Remove all competitions from the index
    func removeAllFromIndex() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: ["com.tetratrack.competitions"]) { _ in
            // Silently handle removal
        }
    }
}
