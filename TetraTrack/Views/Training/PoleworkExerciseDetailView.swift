//
//  PoleworkExerciseDetailView.swift
//  TetraTrack
//
//  Detail view for polework exercises with dynamic stride calculations
//

import SwiftUI

struct PoleworkExerciseDetailView: View {
    let exercise: PoleworkExercise
    var horse: Horse?
    var onEdit: ((PoleworkExercise) -> Void)?

    @State private var showDistanceAdjustment: Bool = false
    @State private var distanceAdjustment: Double = 0
    @Environment(\.dismiss) private var dismiss

    /// Horse size derived from horse profile, or .average if no horse provided
    private var selectedHorseSize: HorseSize {
        horse?.horseSize ?? .average
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // User-created badge
                if !exercise.isBuiltIn {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Custom Exercise")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
                }

                // Header
                headerSection

                // Horse Size Selector
                horseSizeSelector

                // Pole Distances Card
                poleDistancesCard

                // Instructions
                if !exercise.instructions.isEmpty {
                    instructionsSection
                }

                // Benefits
                if !exercise.benefits.isEmpty {
                    benefitsSection
                }

                // Tips
                if !exercise.tips.isEmpty {
                    tipsSection
                }

                // Safety Notes
                if !exercise.safetyNotes.isEmpty {
                    safetySection
                }

                // Media (Photos & Videos)
                if !exercise.photos.isEmpty || !exercise.videoAssetIdentifiers.isEmpty {
                    ExerciseMediaGallery(
                        photos: exercise.photos,
                        videoAssetIdentifiers: exercise.videoAssetIdentifiers,
                        videoThumbnails: exercise.videoThumbnails
                    )
                }

                // Quick Reference Card
                quickReferenceSection
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Edit/Duplicate button
                if let onEdit = onEdit {
                    Button {
                        dismiss()
                        onEdit(exercise)
                    } label: {
                        Image(systemName: exercise.isBuiltIn ? "doc.on.doc" : "pencil")
                    }
                }

                // Favorite button
                Button {
                    exercise.isFavorite.toggle()
                } label: {
                    Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(exercise.isFavorite ? .red : .gray)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Category badge
                Label(exercise.category.displayName, systemImage: exercise.category.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())

                // Difficulty badge
                Text(exercise.difficulty.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.1))
                    .foregroundStyle(difficultyColor)
                    .clipShape(Capsule())

                Spacer()
            }

            Text(exercise.exerciseDescription)
                .font(.body)
                .foregroundStyle(.secondary)

            // Required gaits
            if !exercise.requiredGaits.isEmpty {
                HStack(spacing: 8) {
                    Text("Gaits:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(exercise.requiredGaits, id: \.self) { gait in
                        Label(gait.displayName, systemImage: gait.icon)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Horse Info Card

    private var horseSizeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.equestrian.sports")
                    .foregroundStyle(.orange)
                Text("Horse Profile")
                    .font(.headline)
            }

            if let horse = horse {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(horse.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if horse.hasHeightSet {
                            Text("\(horse.formattedHeight) • \(selectedHorseSize.shortName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Height not set • Using average distances")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    Text("×\(String(format: "%.0f%%", selectedHorseSize.strideMultiplier * 100))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No horse selected")
                            .font(.subheadline)

                        Text("Using average distances (15.2-16.2hh)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("×100%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Pole Distances Card

    private var poleDistancesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler")
                    .foregroundStyle(.orange)
                Text("Pole Distances")
                    .font(.headline)
                Spacer()

                Button {
                    showDistanceAdjustment.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.blue)
                }
            }

            // Main distance
            let spacing = exercise.formattedSpacing(for: selectedHorseSize)
            VStack(spacing: 4) {
                Text("Spacing Between Poles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    VStack {
                        Text(spacing.metres)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("metres")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("or")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack {
                        Text(spacing.feet)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("feet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Adjustment slider
            if showDistanceAdjustment {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Fine-tune")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%+.0f%%", distanceAdjustment))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $distanceAdjustment, in: -15...15, step: 1)

                    let adjusted = PoleStrideCalculator.formattedDistance(
                        for: exercise.exerciseType,
                        horseSize: selectedHorseSize,
                        adjustmentPercent: distanceAdjustment
                    )
                    Text("Adjusted: \(adjusted.metres) / \(adjusted.feet)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Additional info for specific exercise types
            if exercise.arrangement == .fan {
                fanDistancesView
            }

            if exercise.isGrid {
                gridSpacingsView
            }

            // Layout info
            HStack {
                Label("\(exercise.numberOfPoles) poles", systemImage: "minus")
                Spacer()
                if exercise.isRaised {
                    Label("Height: \(Int(exercise.raiseHeightCm))cm", systemImage: "arrow.up.to.line")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Total length
            let totalLength = exercise.totalLength(for: selectedHorseSize)
            if totalLength > 0 {
                Text("Total length: \(String(format: "%.1fm", totalLength)) (\(String(format: "%.0fft", totalLength * 3.28084)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Fan Distances View

    @ViewBuilder
    private var fanDistancesView: some View {
        if let fanDist = exercise.fanDistances(for: selectedHorseSize) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fan Pole Distances")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 16) {
                    fanDistanceItem(label: "Inner", distance: fanDist.inner)
                    fanDistanceItem(label: "Middle", distance: fanDist.middle)
                    fanDistanceItem(label: "Outer", distance: fanDist.outer)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func fanDistanceItem(label: String, distance: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2fm", distance))
                .font(.subheadline)
                .fontWeight(.medium)
            Text(String(format: "%.1fft", distance * 3.28084))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grid Spacings View

    @ViewBuilder
    private var gridSpacingsView: some View {
        if !exercise.gridElements.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Grid Layout")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    ForEach(Array(exercise.gridElements.enumerated()), id: \.offset) { index, element in
                        gridElementView(element: element, index: index)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func gridElementView(element: GridElement, index: Int) -> some View {
        VStack(spacing: 2) {
            switch element {
            case .pole:
                Rectangle()
                    .fill(Color.brown)
                    .frame(width: 30, height: 4)
                Text("Pole")
                    .font(.caption2)

            case .fence:
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("Fence")
                    .font(.caption2)

            case .bounce:
                Text(PoleStrideCalculator.formattedDistance(for: .bounce, horseSize: selectedHorseSize).metres)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text("Bounce")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            case .oneStride:
                Text(PoleStrideCalculator.formattedDistance(for: .oneStride, horseSize: selectedHorseSize).metres)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text("1 Stride")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

            case .twoStride:
                Text(PoleStrideCalculator.formattedDistance(for: .twoStride, horseSize: selectedHorseSize).metres)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text("2 Stride")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Instructions", systemImage: "list.number")
                .font(.headline)

            ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 20, height: 20)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())

                    Text(instruction)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Benefits", systemImage: "star")
                .font(.headline)

            ForEach(exercise.benefits, id: \.self) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)

                    Text(benefit)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips", systemImage: "lightbulb")
                .font(.headline)

            ForEach(exercise.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text(tip)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Safety Notes", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(exercise.safetyNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Text(note)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Reference Section

    private var quickReferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Reference - \(selectedHorseSize.shortName) Horse")
                .font(.headline)

            let card = PoleStrideCalculator.quickReferenceCard(for: selectedHorseSize)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickRefItem(title: "Walk Poles", distance: card.walkPoles)
                quickRefItem(title: "Trot Poles", distance: card.trotPoles)
                quickRefItem(title: "Canter Poles", distance: card.canterPoles)
                quickRefItem(title: "Bounce", distance: card.bounce)
                quickRefItem(title: "One Stride", distance: card.oneStride)
                quickRefItem(title: "Two Stride", distance: card.twoStride)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    private func quickRefItem(title: String, distance: (metres: String, feet: String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(distance.metres)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(distance.feet)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}
