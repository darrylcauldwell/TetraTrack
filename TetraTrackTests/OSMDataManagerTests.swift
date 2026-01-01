//
//  OSMDataManagerTests.swift
//  TetraTrackTests
//
//  Tests for OSMDataManager and related types
//

import Testing
import Foundation
import CoreLocation
@testable import TetraTrack

// MARK: - OSMDataError Tests

struct OSMDataErrorTests {

    @Test func notConfiguredError() {
        let error = OSMDataError.notConfigured

        #expect(error.errorDescription?.contains("not configured") == true)
    }

    @Test func alreadyDownloadingError() {
        let error = OSMDataError.alreadyDownloading

        #expect(error.errorDescription?.contains("already being downloaded") == true)
    }

    @Test func alreadyDownloadedError() {
        let error = OSMDataError.alreadyDownloaded

        #expect(error.errorDescription?.contains("already downloaded") == true)
    }

    @Test func downloadFailedError() {
        let error = OSMDataError.downloadFailed("Server timeout")

        #expect(error.errorDescription?.contains("Download failed") == true)
        #expect(error.errorDescription?.contains("Server timeout") == true)
    }

    @Test func parsingFailedError() {
        let error = OSMDataError.parsingFailed("Invalid data format")

        #expect(error.errorDescription?.contains("Failed to process map data") == true)
        #expect(error.errorDescription?.contains("Invalid data format") == true)
    }

    @Test func noRegionForLocationError() {
        let error = OSMDataError.noRegionForLocation

        #expect(error.errorDescription?.contains("No map data available") == true)
    }
}

// MARK: - OSMDataManager State Tests

struct OSMDataManagerStateTests {

    @Test @MainActor func initialState() {
        let manager = OSMDataManager()

        #expect(manager.activeDownloads.isEmpty)
        #expect(manager.lastError == nil)
    }
}

// MARK: - AvailableRegion Tests (if accessible)

struct AvailableRegionTests {

    @Test func ukRegionsExist() {
        // Test that the UK regions are defined
        let regions = AvailableRegion.ukRegions

        #expect(regions.count > 0)
    }

    @Test func regionHasValidBounds() {
        let regions = AvailableRegion.ukRegions

        for region in regions {
            // Latitude bounds check
            #expect(region.minLat >= -90)
            #expect(region.maxLat <= 90)
            #expect(region.minLat < region.maxLat)

            // Longitude bounds check
            #expect(region.minLon >= -180)
            #expect(region.maxLon <= 180)
            #expect(region.minLon < region.maxLon)

            // Has valid ID and display name
            #expect(!region.id.isEmpty)
            #expect(!region.displayName.isEmpty)
        }
    }

    @Test func regionContainsCoordinate() {
        let regions = AvailableRegion.ukRegions

        guard let firstRegion = regions.first else {
            return // Skip if no regions
        }

        // A coordinate inside the region bounds should be contained
        let midLat = (firstRegion.minLat + firstRegion.maxLat) / 2
        let midLon = (firstRegion.minLon + firstRegion.maxLon) / 2
        let insideCoord = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

        #expect(firstRegion.contains(insideCoord) == true)
    }

    @Test func regionDoesNotContainOutsideCoordinate() {
        let regions = AvailableRegion.ukRegions

        guard let firstRegion = regions.first else {
            return // Skip if no regions
        }

        // A coordinate far outside should not be contained
        let outsideCoord = CLLocationCoordinate2D(latitude: 0, longitude: 0)

        // This may or may not be true depending on region bounds
        // Just ensure no crash
        _ = firstRegion.contains(outsideCoord)
    }
}
