//
//  HorseDetailView.swift
//  TetraTrack
//
//  Detailed view showing horse profile, statistics, and ride history

import SwiftUI
import SwiftData

struct HorseDetailView: View {
    @Bindable var horse: Horse
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingEditSheet = false
    @State private var showingGaitTuning = false
    @State private var selectedPeriod: StatisticsPeriod = .allTime
    @State private var selectedVideoIndex: Int?
    @State private var showingVideoPlayer = false

    private var statistics: HorseStatistics {
        HorseStatisticsManager.calculateStatistics(for: horse, period: selectedPeriod)
    }

    private var workload: WorkloadData {
        HorseStatisticsManager.calculateWorkload(for: horse)
    }

    private var recentRides: [Ride] {
        HorseStatisticsManager.recentRides(for: horse, limit: 5)
    }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .navigationTitle(horse.name.isEmpty ? "Horse" : horse.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") {
                showingEditSheet = true
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            HorseEditView(horse: horse)
                .presentationBackground(Color.black)
        }
    }

    // MARK: - iPad Layout (Side-by-Side)

    private var iPadLayout: some View {
        HStack(alignment: .top, spacing: Spacing.xl) {
            // Left column: Profile and Videos
            VStack(spacing: 20) {
                profileHeader

                gaitTuningSection

                if horse.hasVideos {
                    videoGallerySection
                }

                WorkloadCardView(workload: workload)
            }
            .frame(width: 350)

            // Right column: Statistics and Rides
            VStack(spacing: 20) {
                statisticsSection

                recentRidesSection
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Spacing.xl)
    }

    // MARK: - iPhone Layout (Vertical)

    private var iPhoneLayout: some View {
        VStack(spacing: 20) {
            profileHeader

            gaitTuningSection

            if horse.hasVideos {
                videoGallerySection
            }

            WorkloadCardView(workload: workload)

            statisticsSection

            recentRidesSection
        }
        .padding()
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Photo
            HorseAvatarView(horse: horse, size: 100)

            // Breed
            if !horse.breed.isEmpty {
                Text(horse.breed)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Details - one per row
            VStack(spacing: 0) {
                if !horse.color.isEmpty {
                    HorseDetailRow(label: "Colour", value: horse.color, icon: "paintpalette")
                }
                if horse.dateOfBirth != nil {
                    HorseDetailRow(label: "Age", value: horse.formattedAge, icon: "calendar")
                }
                if horse.weight != nil {
                    HorseDetailRow(label: "Weight", value: horse.formattedWeight, icon: "scalemass")
                }
                if horse.heightHands != nil {
                    HorseDetailRow(label: "Height", value: horse.formattedHeight, icon: "ruler")
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Notes
            if !horse.notes.isEmpty {
                Text(horse.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Gait Tuning Section

    private var gaitTuningSection: some View {
        Button {
            showingGaitTuning = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Gait Detection", systemImage: "waveform.path.ecg")
                        .font(.headline)

                    if horse.hasCustomGaitSettings {
                        Text("Custom settings applied")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Using \(horse.typedBreed.displayName) defaults")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingGaitTuning) {
            HorseGaitTuningView(horse: horse)
        }
    }

    // MARK: - Video Gallery Section

    private var videoGallerySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Videos", systemImage: "video")
                    .font(.headline)
                Spacer()
                Text("\(horse.videoAssetIdentifiers.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(horse.videoThumbnails.enumerated()), id: \.offset) { index, thumbnailData in
                        if let image = UIImage(data: thumbnailData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 3)
                                )
                                .onTapGesture {
                                    selectedVideoIndex = index
                                    showingVideoPlayer = true
                                }
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showingVideoPlayer) {
            if let index = selectedVideoIndex, index < horse.videoAssetIdentifiers.count {
                HorseVideoPlayer(assetIdentifier: horse.videoAssetIdentifiers[index])
                    .presentationBackground(Color.black)
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                Spacer()
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.menu)
            }

            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(title: "Rides", value: "\(statistics.totalRides)", icon: "figure.equestrian.sports")
                StatCard(title: "Distance", value: statistics.formattedTotalDistance, icon: "arrow.left.and.right")
                StatCard(title: "Time", value: statistics.formattedTotalDuration, icon: "clock")
                StatCard(title: "Avg Speed", value: statistics.formattedAverageSpeed, icon: "speedometer")
            }

            // Gait Breakdown
            if !statistics.gaitBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gait Distribution")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(statistics.gaitBreakdown, id: \.gait) { item in
                        HorseGaitRow(
                            gait: item.gait,
                            duration: item.duration,
                            percentage: item.percentage
                        )
                    }
                }
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Recent Rides Section

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Rides")
                .font(.headline)

            if recentRides.isEmpty {
                Text("No rides recorded yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(recentRides) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        HorseRideRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Horse Gait Row

struct HorseGaitRow: View {
    let gait: GaitType
    let duration: TimeInterval
    let percentage: Double

    var body: some View {
        HStack {
            Image(systemName: gait.icon)
                .foregroundStyle(AppColors.gait(gait))
                .frame(width: 24)

            Text(gait.rawValue)
                .font(.subheadline)

            Spacer()

            Text(formatDuration(duration))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(String(format: "%.0f%%", percentage))
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Horse Detail Row

struct HorseDetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Horse Ride Row

struct HorseRideRow: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.name.isEmpty ? "Untitled Ride" : ride.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    Label(ride.formattedDistance, systemImage: "arrow.left.and.right")
                    Label(ride.formattedDuration, systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ride.startDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        HorseDetailView(horse: Horse())
    }
    .modelContainer(for: [Horse.self, Ride.self], inMemory: true)
}
