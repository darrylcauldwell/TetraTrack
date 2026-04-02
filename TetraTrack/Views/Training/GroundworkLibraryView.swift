//
//  GroundworkLibraryView.swift
//  TetraTrack
//
//  Browse groundwork exercises for horse handling and partnership
//

import SwiftUI

// MARK: - Data Types

enum GroundworkCategory: String, CaseIterable, Identifiable {
    case leading = "Leading"
    case lunging = "Lunging"
    case desensitisation = "Desensitisation"
    case inHand = "In-Hand"
    case liberty = "Liberty"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .leading: return "figure.walk"
        case .lunging: return "arrow.triangle.2.circlepath"
        case .desensitisation: return "shield.checkered"
        case .inHand: return "hand.raised"
        case .liberty: return "wind"
        }
    }
}

enum GroundworkDifficulty: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }
}

struct GroundworkExercise: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: GroundworkCategory
    let difficulty: GroundworkDifficulty
    let benefits: String
}

// MARK: - Exercise Data

extension GroundworkExercise {
    static let allExercises: [GroundworkExercise] = [
        // Leading
        GroundworkExercise(
            name: "Walk-Halt Transitions",
            description: "Walk the horse forward and halt squarely using voice and body position. The handler walks at the horse's shoulder with soft contact on the lead rope.",
            category: .leading, difficulty: .beginner,
            benefits: "Basic communication, teaches horse to respect handler's space"
        ),
        GroundworkExercise(
            name: "Leading Through Obstacles",
            description: "Lead the horse through ground poles, narrow corridors, and weaving patterns around cones. Progress from wide gaps to narrower ones.",
            category: .leading, difficulty: .beginner,
            benefits: "Builds trust, improves horse's spatial awareness"
        ),
        GroundworkExercise(
            name: "In-Hand Trotting",
            description: "Trot alongside the horse in a straight line or triangle. The handler runs at the shoulder while the horse trots freely on a loose lead.",
            category: .leading, difficulty: .beginner,
            benefits: "Fitness for horse and handler, correct presentation for vet trot-ups"
        ),
        GroundworkExercise(
            name: "Backing Up",
            description: "Standing facing the horse, ask it to step backward in a straight line using voice commands and light chest pressure. Aim for even diagonal steps.",
            category: .leading, difficulty: .intermediate,
            benefits: "Builds respect for space, strengthens hindquarters"
        ),
        GroundworkExercise(
            name: "Loading and Unloading",
            description: "Practice leading the horse calmly into and out of a trailer or horsebox. Start with a partitioned space and progress to self-loading.",
            category: .leading, difficulty: .intermediate,
            benefits: "Critical for competition travel, builds confidence in confined spaces"
        ),

        // Lunging
        GroundworkExercise(
            name: "Basic Circle Lunging",
            description: "Lunge the horse on a 20m circle using a lunge line. Work through walk, trot, and halt transitions using voice commands and body position.",
            category: .lunging, difficulty: .intermediate,
            benefits: "Develops handler coordination, improves horse balance and rhythm"
        ),
        GroundworkExercise(
            name: "Lunging Over Ground Poles",
            description: "Place 3-5 ground poles on the lunge circle at appropriate distances. The horse works over them at trot, developing rhythm and proprioception.",
            category: .lunging, difficulty: .intermediate,
            benefits: "Improves stride regularity, strengthens topline"
        ),
        GroundworkExercise(
            name: "Lunging with Side Reins",
            description: "Attach side reins to encourage the horse to work in a rounder frame on the lunge. Use under supervision only.",
            category: .lunging, difficulty: .advanced,
            benefits: "Develops self-carriage, strengthens back and hindquarters"
        ),
        GroundworkExercise(
            name: "Ground Pole Grid Work",
            description: "Set up a grid of ground poles at varied distances and angles. Lead or free-school the horse through different routes for adjustability.",
            category: .lunging, difficulty: .intermediate,
            benefits: "Develops proprioception, strengthens coordination, transfers to jumping"
        ),

        // Desensitisation
        GroundworkExercise(
            name: "Tarpaulin Walk",
            description: "Lay a tarpaulin flat on the ground and lead the horse over it. Progress from walking past, to stepping on the edge, to walking fully across.",
            category: .desensitisation, difficulty: .beginner,
            benefits: "Builds confidence, reduces spookiness for cross-country"
        ),
        GroundworkExercise(
            name: "Flag and Bag Work",
            description: "Wave plastic bags, flags, or streamers around the horse at increasing proximity. Start at a distance and work closer as the horse relaxes.",
            category: .desensitisation, difficulty: .beginner,
            benefits: "Reduces flight response, prepares for competition environments"
        ),
        GroundworkExercise(
            name: "Sound Desensitisation",
            description: "Expose the horse to various sounds: clapping, rustling, music, spray bottles, clippers. Pair with positive reinforcement.",
            category: .desensitisation, difficulty: .beginner,
            benefits: "Prepares for competition environments and veterinary procedures"
        ),

        // In-Hand
        GroundworkExercise(
            name: "Yielding the Hindquarters",
            description: "Stand at the horse's barrel and apply light pressure to ask hind legs to cross over and step away. The front end stays relatively still.",
            category: .inHand, difficulty: .intermediate,
            benefits: "Develops lateral control, teaches leg yield concept from the ground"
        ),
        GroundworkExercise(
            name: "Yielding the Forehand",
            description: "Stand near the horse's head and ask the front end to move around the hindquarters. The horse pivots on the inside hind leg.",
            category: .inHand, difficulty: .advanced,
            benefits: "Develops front-end control, prepares for mounted pirouettes"
        ),
        GroundworkExercise(
            name: "Shoulder-In on the Ground",
            description: "Walk alongside the horse and use a schooling whip to ask for slight inside bend with shoulders tracking inside the line of travel along a wall.",
            category: .inHand, difficulty: .advanced,
            benefits: "Develops lateral suppleness, strengthens inside hind leg"
        ),
        GroundworkExercise(
            name: "Halt and Stand (Immobility)",
            description: "Ask the horse to halt and stand still for increasing durations without fidgeting. The handler steps away gradually.",
            category: .inHand, difficulty: .beginner,
            benefits: "Essential for safety, develops patience and obedience"
        ),
        GroundworkExercise(
            name: "Picking Up All Four Feet",
            description: "Pick up each foot in sequence, hold for 10-30 seconds, tap the sole gently, and set down calmly. Progress to simulating farrier work.",
            category: .inHand, difficulty: .beginner,
            benefits: "Foundation for hoof care, teaches balance on three legs"
        ),

        // Liberty
        GroundworkExercise(
            name: "Free Lunging",
            description: "Work the horse at liberty in a round pen or small arena. Use body position and energy to direct walk, trot, canter, halt, and direction changes.",
            category: .liberty, difficulty: .advanced,
            benefits: "Deep communication and partnership, teaches equine body language"
        ),
        GroundworkExercise(
            name: "Join-Up / Follow Me",
            description: "After free lunging, invite the horse to follow the handler around the arena without a lead rope, based on reading body language.",
            category: .liberty, difficulty: .advanced,
            benefits: "Builds trust and partnership, rewards calm and consistent approach"
        ),
    ]
}

// MARK: - View

struct GroundworkLibraryView: View {
    @State private var searchText = ""
    @State private var selectedCategory: GroundworkCategory?
    @State private var selectedDifficulty: GroundworkDifficulty?

    private var filteredExercises: [GroundworkExercise] {
        var result = GroundworkExercise.allExercises

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficulty == difficulty }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        List {
            // Filters
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GroundworkCategory.allCases) { category in
                            Button {
                                selectedCategory = selectedCategory == category ? nil : category
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: category.icon)
                                    Text(category.rawValue)
                                }
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == category ? Color.green : Color(.systemGray5))
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Difficulty filter removed
            }

            // Exercises
            ForEach(filteredExercises) { exercise in
                GroundworkExerciseRow(exercise: exercise)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
    }
}

// MARK: - Exercise Row

private struct GroundworkExerciseRow: View {
    let exercise: GroundworkExercise
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: exercise.category.icon)
                        .foregroundStyle(.green)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(exercise.category.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(exercise.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(exercise.benefits)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
