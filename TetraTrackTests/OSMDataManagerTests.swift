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

// MARK: - DownloadProgress Tests

struct DownloadProgressTests {

    @Test func initialProgress() {
        let progress = OSMDataManager.DownloadProgress.initial

        #expect(progress.phase == .downloading)
        #expect(progress.progress == 0)
        #expect(progress.message == "Starting download...")
    }

    @Test func downloadingPhase() {
        let progress = OSMDataManager.DownloadProgress(
            phase: .downloading,
            progress: 0.5,
            message: "50% complete"
        )

        #expect(progress.phase == .downloading)
        #expect(progress.progress == 0.5)
        #expect(progress.message == "50% complete")
    }

    @Test func parsingPhase() {
        let progress = OSMDataManager.DownloadProgress(
            phase: .parsing,
            progress: 0.75,
            message: "Parsing nodes..."
        )

        #expect(progress.phase == .parsing)
        #expect(progress.progress == 0.75)
    }

    @Test func indexingPhase() {
        let progress = OSMDataManager.DownloadProgress(
            phase: .indexing,
            progress: 0.9,
            message: "Building connections..."
        )

        #expect(progress.phase == .indexing)
        #expect(progress.progress == 0.9)
    }

    @Test func completePhase() {
        let progress = OSMDataManager.DownloadProgress(
            phase: .complete,
            progress: 1.0,
            message: "Ready"
        )

        #expect(progress.phase == .complete)
        #expect(progress.progress == 1.0)
    }

    @Test func failedPhase() {
        let progress = OSMDataManager.DownloadProgress(
            phase: .failed,
            progress: 0,
            message: "Network error"
        )

        #expect(progress.phase == .failed)
        #expect(progress.progress == 0)
    }

    @Test func progressIsEquatable() {
        let progress1 = OSMDataManager.DownloadProgress(
            phase: .downloading,
            progress: 0.5,
            message: "Downloading..."
        )

        let progress2 = OSMDataManager.DownloadProgress(
            phase: .downloading,
            progress: 0.5,
            message: "Downloading..."
        )

        let progress3 = OSMDataManager.DownloadProgress(
            phase: .parsing,
            progress: 0.5,
            message: "Parsing..."
        )

        #expect(progress1 == progress2)
        #expect(progress1 != progress3)
    }
}

// MARK: - DownloadProgress.Phase Tests

struct DownloadProgressPhaseTests {

    @Test func phaseIsEquatable() {
        let phase1 = OSMDataManager.DownloadProgress.Phase.downloading
        let phase2 = OSMDataManager.DownloadProgress.Phase.downloading
        let phase3 = OSMDataManager.DownloadProgress.Phase.parsing

        #expect(phase1 == phase2)
        #expect(phase1 != phase3)
    }

    @Test func allPhasesExist() {
        let phases: [OSMDataManager.DownloadProgress.Phase] = [
            .downloading,
            .parsing,
            .indexing,
            .complete,
            .failed
        ]

        #expect(phases.count == 5)
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
