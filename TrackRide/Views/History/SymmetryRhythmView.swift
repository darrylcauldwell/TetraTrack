//
//  SymmetryRhythmView.swift
//  TrackRide
//
//  Displays Training Scale metrics based on the German dressage pyramid
//  (Rhythm, Relaxation, Connection, Impulsion, Straightness, Collection)

import SwiftUI

// MARK: - Training Scale Element

/// The six elements of the German Training Scale (Skala der Ausbildung)
enum TrainingScaleElement: String, CaseIterable, Identifiable {
    case rhythm = "Rhythm"
    case relaxation = "Relaxation"
    case connection = "Connection"
    case impulsion = "Impulsion"
    case straightness = "Straightness"
    case collection = "Collection"

    var id: String { rawValue }

    var germanName: String {
        switch self {
        case .rhythm: return "Takt"
        case .relaxation: return "Losgelassenheit"
        case .connection: return "Anlehnung"
        case .impulsion: return "Schwung"
        case .straightness: return "Geraderichtung"
        case .collection: return "Versammlung"
        }
    }

    var icon: String {
        switch self {
        case .rhythm: return "metronome"
        case .relaxation: return "leaf"
        case .connection: return "hand.draw"
        case .impulsion: return "bolt"
        case .straightness: return "arrow.up"
        case .collection: return "figure.equestrian.sports"
        }
    }

    var description: String {
        switch self {
        case .rhythm:
            return "Is the horse keeping a steady beat? Like a metronome, each stride should be the same length and timing. A 4-beat walk, 2-beat trot, 3-beat canter."
        case .relaxation:
            return "Is the horse loose and calm? Look for a swinging back, soft muscles, and relaxed breathing. No tension or stiffness."
        case .connection:
            return "Is there a soft, elastic feel in the reins? The horse should accept the bit willingly, not pulling or going behind the contact."
        case .impulsion:
            return "Is there energy and power from behind? The horse should feel like it wants to go forward, with active hindquarters pushing."
        case .straightness:
            return "Are you working both sides equally? The horse's spine should be straight on straight lines, and bent correctly on curves."
        case .collection:
            return "Is the horse carrying itself? More weight on the hindquarters, lighter in front, with active hind legs stepping under."
        }
    }

    /// Whether this element can be measured by device sensors
    var isMeasurable: Bool {
        switch self {
        case .rhythm: return true
        case .straightness: return true  // Derived from turn balance
        case .relaxation, .connection, .impulsion, .collection: return false
        }
    }

    var measurementNote: String? {
        switch self {
        case .rhythm:
            return "Steady beat? Measures if strides are evenly spaced"
        case .straightness:
            return "Equal turns left and right during the session"
        case .relaxation:
            return "Watch for: swinging back, soft eye, relaxed breathing"
        case .connection:
            return "Feel for: light, elastic contact, horse seeking the bit"
        case .impulsion:
            return "Feel for: forward desire, active hindquarters"
        case .collection:
            return "Feel for: lightness in front, lowered haunches"
        }
    }
}

// MARK: - Training Scale View

struct SymmetryRhythmView: View {
    let ride: Ride
    @State private var selectedElement: TrainingScaleElement?
    @State private var showingInfo = false

    private var hasRhythmData: Bool {
        ride.overallRhythm > 0
    }

    private var hasTurnData: Bool {
        ride.leftTurns + ride.rightTurns > 0
    }

    /// Calculate straightness score from turn balance (50/50 = 100% straight)
    private var straightnessScore: Double {
        let balance = ride.turnBalancePercent
        // 50% balance = 100% straight, 0% or 100% balance = 0% straight
        let deviation = abs(balance - 50)
        return max(0, 100 - (Double(deviation) * 2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with info button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Schooling Scores")
                        .font(.headline)
                    Text("What the app can measure from your phone's sensors")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }

            // Measured metrics
            if hasRhythmData || hasTurnData {
                VStack(spacing: 12) {
                    // Rhythm (measured)
                    if hasRhythmData {
                        TrainingScaleRow(
                            element: .rhythm,
                            score: ride.overallRhythm,
                            isSelected: selectedElement == .rhythm
                        ) {
                            selectedElement = selectedElement == .rhythm ? nil : .rhythm
                        }
                    }

                    // Straightness (derived from turn balance)
                    if hasTurnData {
                        TrainingScaleRow(
                            element: .straightness,
                            score: straightnessScore,
                            isSelected: selectedElement == .straightness
                        ) {
                            selectedElement = selectedElement == .straightness ? nil : .straightness
                        }
                    }
                }

                // Show selected element details
                if let element = selectedElement {
                    TrainingScaleDetailCard(element: element)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                // No data message
                VStack(spacing: 8) {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    Text("No training data recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Rhythm and straightness will be measured during your ride")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            // Manual assessment reminder
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Self-Assessment")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("Relaxation, Connection, Impulsion, and Collection require feel and observation. Tap info for guidance.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: selectedElement)
        .sheet(isPresented: $showingInfo) {
            TrainingScaleInfoSheet()
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Training Scale Row

struct TrainingScaleRow: View {
    let element: TrainingScaleElement
    let score: Double
    let isSelected: Bool
    let onTap: () -> Void

    private var scoreColor: Color {
        switch score {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: element.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(scoreColor)
                    .frame(width: 24)

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(element.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let note = element.measurementNote {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Score
                HStack(spacing: 4) {
                    Text(String(format: "%.0f", score))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor)

                    Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Chevron
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? scoreColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Training Scale Detail Card

struct TrainingScaleDetailCard: View {
    let element: TrainingScaleElement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(element.germanName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                if element.isMeasurable {
                    Label("Sensor measured", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(element.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(AppColors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Training Scale Info Sheet

struct TrainingScaleInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Introduction
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The Training Scale")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("The German Training Scale (Skala der Ausbildung) is the foundation of classical dressage training. Each element builds upon the previous ones, creating a pyramid of development.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Pyramid diagram
                    TrainingScalePyramid()
                        .frame(height: 200)

                    Divider()

                    // Each element
                    ForEach(TrainingScaleElement.allCases) { element in
                        TrainingScaleInfoRow(element: element)
                    }

                    // What the app measures
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("What TetraTrack Measures", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.headline)

                        Text("Using your phone's motion sensors, the app can measure:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TrainingScaleBulletPoint(text: "Rhythm: Stride consistency and regularity")
                        TrainingScaleBulletPoint(text: "Straightness: Turn balance (equal work on both reins)")

                        Text("The other elements—Relaxation, Connection, Impulsion, and Collection—require the rider's feel and observation. Use the descriptions above as a guide for self-assessment.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Training Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct TrainingScaleInfoRow: View {
    let element: TrainingScaleElement

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: element.icon)
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 24)

                Text(element.rawValue)
                    .font(.headline)

                Text("(\(element.germanName))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if element.isMeasurable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            Text(element.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let note = element.measurementNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
    }
}

struct TrainingScalePyramid: View {
    private let elements = TrainingScaleElement.allCases.reversed()

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let rowHeight = height / 6

            VStack(spacing: 2) {
                ForEach(Array(elements.enumerated()), id: \.element.id) { index, element in
                    let blockWidth = width * (0.4 + Double(index) * 0.1)

                    HStack {
                        Text(element.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    .frame(width: blockWidth, height: rowHeight - 2)
                    .background(element.isMeasurable ? AppColors.primary : AppColors.primary.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TrainingScaleBulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(AppColors.primary)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Circular Gauge (kept for compatibility)

struct CircularGaugeView: View {
    let value: Double
    let maxValue: Double
    let title: String
    var subtitle: String? = nil
    let color: Color

    private var progress: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress)

                // Value text
                VStack(spacing: 0) {
                    Text(String(format: "%.0f", value))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(color)

                    Text("%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SymmetryRhythmView(ride: {
        let ride = Ride()
        ride.leftReinSymmetry = 85
        ride.rightReinSymmetry = 82
        ride.leftReinRhythm = 78
        ride.rightReinRhythm = 81
        ride.leftReinDuration = 300
        ride.rightReinDuration = 280
        ride.leftTurns = 12
        ride.rightTurns = 14
        return ride
    }())
    .padding()
}
