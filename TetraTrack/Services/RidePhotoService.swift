//
//  RidePhotoService.swift
//  TetraTrack
//
//  Photo library service for finding and caching ride, session, and competition media
//

import Foundation
import Photos
import UIKit
import Observation

@Observable
final class RidePhotoService {
    private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
    private(set) var isAuthorized: Bool = false

    /// Thumbnail cache keyed by asset local identifier
    private let thumbnailCache = NSCache<NSString, UIImage>()

    /// Full image cache (smaller capacity due to size)
    private let fullImageCache = NSCache<NSString, UIImage>()

    static let shared = RidePhotoService()

    private init() {
        checkAuthorization()
        configureCaches()
    }

    private func configureCaches() {
        // Configure thumbnail cache - ~100 thumbnails at 200x200 ~= 15MB
        thumbnailCache.countLimit = 100
        thumbnailCache.totalCostLimit = 15 * 1024 * 1024

        // Configure full image cache - ~10 full images
        fullImageCache.countLimit = 10
        fullImageCache.totalCostLimit = 50 * 1024 * 1024
    }

    /// Get cached thumbnail or nil
    func getCachedThumbnail(for identifier: String) -> UIImage? {
        thumbnailCache.object(forKey: identifier as NSString)
    }

    /// Cache a thumbnail
    func cacheThumbnail(_ image: UIImage, for identifier: String) {
        thumbnailCache.setObject(image, forKey: identifier as NSString)
    }

    /// Get cached full image or nil
    func getCachedFullImage(for identifier: String) -> UIImage? {
        fullImageCache.object(forKey: identifier as NSString)
    }

    /// Cache a full image
    func cacheFullImage(_ image: UIImage, for identifier: String) {
        fullImageCache.setObject(image, forKey: identifier as NSString)
    }

    /// Clear all caches
    func clearCaches() {
        thumbnailCache.removeAllObjects()
        fullImageCache.removeAllObjects()
    }

    func checkAuthorization() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        isAuthorized = authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            authorizationStatus = status
            isAuthorized = status == .authorized || status == .limited
        }
        return isAuthorized
    }

    /// Find photos taken during a ride's time window
    func findPhotosForRide(_ ride: Ride) async -> [PHAsset] {
        guard isAuthorized else { return [] }

        let start = ride.startDate
        let end = ride.endDate ?? Date()

        // Add some buffer time (5 minutes before and after)
        let bufferedStart = start.addingTimeInterval(-300)
        let bufferedEnd = end.addingTimeInterval(300)

        return await fetchAssets(from: bufferedStart, to: bufferedEnd, mediaType: .image)
    }

    /// Find photos taken within 1 hour before and after a riding session
    /// This captures pre-ride preparation and post-ride cool-down photos
    func findPhotosForSession(_ ride: Ride) async -> [PHAsset] {
        guard isAuthorized else { return [] }

        let start = ride.startDate
        let end = ride.endDate ?? Date()

        // 1 hour buffer before and after the session
        let bufferedStart = start.addingTimeInterval(-3600)  // 1 hour before
        let bufferedEnd = end.addingTimeInterval(3600)       // 1 hour after

        return await fetchAssets(from: bufferedStart, to: bufferedEnd, mediaType: .image)
    }

    /// Find photos and videos taken within 1 hour before and after a riding session
    /// This captures pre-ride preparation and post-ride cool-down media
    func findMediaForSession(_ ride: Ride) async -> (photos: [PHAsset], videos: [PHAsset]) {
        guard isAuthorized else { return ([], []) }

        let start = ride.startDate
        let end = ride.endDate ?? Date()

        // 1 hour buffer before and after the session
        let bufferedStart = start.addingTimeInterval(-3600)  // 1 hour before
        let bufferedEnd = end.addingTimeInterval(3600)       // 1 hour after

        let photos = await fetchAssets(from: bufferedStart, to: bufferedEnd, mediaType: .image)
        let videos = await fetchAssets(from: bufferedStart, to: bufferedEnd, mediaType: .video)

        return (photos, videos)
    }

    /// Find photos and videos taken within 1 hour before and after a running session
    func findMediaForRunningSession(_ session: RunningSession) async -> (photos: [PHAsset], videos: [PHAsset]) {
        guard isAuthorized else { return ([], []) }

        let start = session.startDate
        let end = session.endDate ?? Date()

        // 1 hour buffer before and after the session
        let bufferedStart = start.addingTimeInterval(-3600)
        let bufferedEnd = end.addingTimeInterval(3600)

        let photos = await fetchAssets(from: bufferedStart, to: bufferedEnd, mediaType: .image)
        let videos = await fetchAssets(from: bufferedStart, to: bufferedEnd, mediaType: .video)

        return (photos, videos)
    }

    /// Find all photos and videos for the full day(s) of a ride
    /// This captures all moments from the day, not just during the ride
    func findMediaForFullDay(_ ride: Ride) async -> (photos: [PHAsset], videos: [PHAsset]) {
        guard isAuthorized else { return ([], []) }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: ride.startDate)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: ride.endDate ?? ride.startDate)) ?? Date()

        let photos = await fetchAssets(from: start, to: end, mediaType: .image)
        let videos = await fetchAssets(from: start, to: end, mediaType: .video)

        return (photos, videos)
    }

    /// Find all photos and videos for a competition (supports multi-day events)
    /// Captures all moments from the start day through the end day
    func findMediaForCompetition(_ competition: Competition) async -> (photos: [PHAsset], videos: [PHAsset]) {
        guard isAuthorized else { return ([], []) }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: competition.date)
        let endDay: Date

        if let competitionEndDate = competition.endDate {
            // Multi-day event: include all days from start to end
            endDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: competitionEndDate)) ?? Date()
        } else {
            // Single-day event: just that day
            endDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? Date()
        }

        let photos = await fetchAssets(from: startDay, to: endDay, mediaType: .image)
        let videos = await fetchAssets(from: startDay, to: endDay, mediaType: .video)

        return (photos, videos)
    }

    /// Find all media for a date range (useful for custom queries)
    func findMediaForDateRange(from start: Date, to end: Date) async -> (photos: [PHAsset], videos: [PHAsset]) {
        guard isAuthorized else { return ([], []) }

        let photos = await fetchAssets(from: start, to: end, mediaType: .image)
        let videos = await fetchAssets(from: start, to: end, mediaType: .video)

        return (photos, videos)
    }

    /// Core fetch method for assets within a time range
    private func fetchAssets(from start: Date, to end: Date, mediaType: PHAssetMediaType) async -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            start as NSDate,
            end as NSDate
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let results = PHAsset.fetchAssets(with: mediaType, options: options)

        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        return assets
    }

    /// Get thumbnail image for a photo
    func getThumbnail(for asset: PHAsset, size: CGSize) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                let data = image?.jpegData(compressionQuality: 0.7)
                continuation.resume(returning: data)
            }
        }
    }

    /// Get full-size image for a photo
    func getFullImage(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    /// Get asset by local identifier
    func getAsset(identifier: String) -> PHAsset? {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return results.firstObject
    }
}
