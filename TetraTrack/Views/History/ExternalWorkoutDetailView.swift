//
//  ExternalWorkoutDetailView.swift
//  TetraTrack
//
//  Detail view for workouts recorded by external apps (Apple Fitness, Garmin, Strava, etc.)
//

import SwiftUI
import MapKit
import CoreLocation

struct ExternalWorkoutDetailView: View {
    let workout: ExternalWorkout
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoadingRoute = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Route map (if available)
                if !routeCoordinates.isEmpty {
                    routeMapSection
                }

                // Stats grid
                statsSection

                // Source info
                sourceSection
            }
            .padding()
        }
        .navigationTitle(workout.activityName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if workout.hasRoute {
                await loadRoute()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: workout.activityIcon)
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text(workout.activityName)
                .font(.title2.bold())

            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Route Map

    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route")
                .font(.headline)

            Map {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.blue, lineWidth: 3)
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard(title: "Duration", value: workout.formattedDuration, icon: "clock")

                if let distance = workout.formattedDistance {
                    statCard(title: "Distance", value: distance, icon: "ruler")
                }

                if let calories = workout.formattedCalories {
                    statCard(title: "Calories", value: calories, icon: "flame.fill")
                }

                if let hr = workout.averageHeartRate {
                    statCard(title: "Avg HR", value: "\(Int(hr)) bpm", icon: "heart.fill")
                }
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)

            Text(value)
                .font(.title3.bold().monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.headline)

            HStack {
                Image(systemName: "app.badge")
                    .foregroundStyle(.secondary)
                Text(workout.sourceName)
                    .font(.body)
                Spacer()
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: workout.startDate)
    }

    private func loadRoute() async {
        isLoadingRoute = true
        defer { isLoadingRoute = false }

        let coords = await ExternalWorkoutService.shared.fetchRouteCoordinates(
            for: workout.id,
            startDate: workout.startDate,
            endDate: workout.endDate
        )
        routeCoordinates = coords
    }
}
