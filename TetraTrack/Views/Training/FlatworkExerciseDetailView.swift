//
//  FlatworkExerciseDetailView.swift
//  TetraTrack
//
//  Detailed view of a flatwork exercise with instructions, tips, and benefits
//

import SwiftUI
import SwiftData

struct FlatworkExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: FlatworkExercise

    // Optional callbacks
    var onStartRide: ((FlatworkExercise) -> Void)?
    var onEdit: ((FlatworkExercise) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    // Header section
                    headerSection

                    Divider()

                    // Required gaits
                    if !exercise.requiredGaits.isEmpty {
                        gaitsSection
                    }

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

                    // Media (Photos & Videos)
                    if !exercise.photos.isEmpty || !exercise.videoAssetIdentifiers.isEmpty {
                        ExerciseMediaGallery(
                            photos: exercise.photos,
                            videoAssetIdentifiers: exercise.videoAssetIdentifiers,
                            videoThumbnails: exercise.videoThumbnails
                        )
                    }

                    // Start ride button
                    if onStartRide != nil {
                        startRideSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Exercise Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

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
                        toggleFavorite()
                    } label: {
                        Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(exercise.isFavorite ? .red : .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category and difficulty badges
            HStack(spacing: 8) {
                // Category badge
                HStack(spacing: 4) {
                    Image(systemName: exercise.category.icon)
                        .font(.caption)
                    Text(exercise.category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.primary.opacity(0.12))
                .foregroundStyle(AppColors.primary)
                .clipShape(Capsule())

                // Difficulty badge
                Text(exercise.difficulty.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(difficultyColor.opacity(0.12))
                    .foregroundStyle(difficultyColor)
                    .clipShape(Capsule())
            }

            // Exercise name
            Text(exercise.name)
                .font(.title)
                .fontWeight(.bold)

            // Description
            Text(exercise.exerciseDescription)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Gaits Section

    private var gaitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Required Gaits", icon: "figure.equestrian.sports")

            HStack(spacing: 12) {
                ForEach(exercise.requiredGaits) { gait in
                    GaitBadge(gait: gait)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "How to Ride", icon: "list.number")

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        // Step number
                        ZStack {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 28, height: 28)

                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }

                        // Instruction text
                        Text(instruction)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Benefits", icon: "checkmark.circle.fill")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(exercise.benefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.green)

                        Text(benefit)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tips", icon: "lightbulb.fill")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(exercise.tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.body)
                            .foregroundStyle(.yellow)

                        Text(tip)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Start Ride Section

    private var startRideSection: some View {
        Button {
            onStartRide?(exercise)
        } label: {
            HStack {
                Image(systemName: "play.fill")
                    .font(.title3)

                Text("Start Ride with This Exercise")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 8)
    }

    // MARK: - Helper Views

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }

    private func toggleFavorite() {
        exercise.isFavorite.toggle()
        try? modelContext.save()
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.primary)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Gait Badge

private struct GaitBadge: View {
    let gait: FlatworkGait

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(gaitColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: gait.icon)
                    .font(.title2)
                    .foregroundStyle(gaitColor)
            }

            Text(gait.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var gaitColor: Color {
        switch gait {
        case .walk: return AppColors.walk
        case .trot: return AppColors.trot
        case .canter: return AppColors.canter
        }
    }
}

// MARK: - Preview

#Preview {
    let exercise = FlatworkExercise(
        name: "20m Circle",
        description: "A large circle using half the arena width, fundamental for developing bend and balance.",
        difficulty: .beginner,
        category: .circles,
        instructions: [
            "At A or C, turn onto the circle",
            "Pass through X at the centre of the arena",
            "Maintain consistent bend throughout the horse's body",
            "Keep your inside leg at the girth, outside leg slightly behind"
        ],
        benefits: [
            "Develops correct bend through the horse's body",
            "Improves balance and rhythm",
            "Foundation for all lateral work"
        ],
        tips: [
            "Imagine you're sitting on the outside of the saddle",
            "Keep your shoulders aligned with your horse's shoulders"
        ],
        requiredGaits: [.walk, .trot, .canter]
    )

    return FlatworkExerciseDetailView(
        exercise: exercise,
        onStartRide: { _ in }
    )
    .modelContainer(for: [FlatworkExercise.self], inMemory: true)
}
