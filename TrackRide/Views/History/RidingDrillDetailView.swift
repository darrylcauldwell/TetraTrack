//
//  RidingDrillDetailView.swift
//  TrackRide
//
//  Detail view for a completed riding drill session
//

import SwiftUI
import SwiftData

struct RidingDrillDetailView: View {
    let session: RidingDrillSession
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(drillColor.opacity(0.2))
                            .frame(width: 80, height: 80)

                        Image(systemName: session.drillType.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(drillColor)
                    }

                    Text(session.name)
                        .font(.title2.bold())

                    Text(session.startDate.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Score card
                VStack(spacing: 8) {
                    Text("\(Int(session.score))%")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(scoreColor)

                    Text(session.gradeString)
                        .font(.title3.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(scoreColor.opacity(0.2))
                        .foregroundStyle(scoreColor)
                        .clipShape(Capsule())
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    DrillStatBox(title: "Duration", value: session.formattedDuration, icon: "clock")
                    DrillStatBox(title: "Score", value: session.formattedScore, icon: "star.fill")
                }
                .padding(.horizontal)

                // Drill type description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About this drill")
                        .font(.headline)

                    Text(drillDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Drill Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var drillColor: Color {
        switch session.drillType {
        case .heelPosition: return .green
        case .coreStability: return .blue
        case .twoPoint: return .orange
        case .balanceBoard: return .purple
        case .hipMobility: return .pink
        case .postingRhythm: return .indigo
        case .riderStillness: return .teal
        case .stirrupPressure: return .mint
        }
    }

    private var scoreColor: Color {
        if session.score >= 80 { return .green }
        if session.score >= 60 { return .yellow }
        return .orange
    }

    private var drillDescription: String {
        switch session.drillType {
        case .heelPosition:
            return "The heel position drill develops lower leg stability and proper weight distribution through the heel. Stand on a step with heels hanging off to strengthen the calf muscles and maintain proper riding position."
        case .coreStability:
            return "Core stability training develops an independent seat by strengthening the core muscles. Using an unstable surface like an exercise ball challenges your balance and builds the muscles needed for quiet, effective riding."
        case .twoPoint:
            return "The two-point (half-seat) position builds leg strength and balance for jumping and galloping. Maintaining this position off the horse develops the muscular endurance needed for cross-country and show jumping."
        case .balanceBoard:
            return "Balance board training develops the ability to absorb movement through soft joints, mimicking the biomechanics of sitting a moving horse. This improves overall balance and movement absorption."
        case .hipMobility:
            return "Hip mobility training develops the ability to follow the horse's movement through supple, independent hips. Circular hip motions while maintaining upper body stillness build the biomechanical skills for an effective seat."
        case .postingRhythm:
            return "Posting rhythm training develops consistent timing for the rising trot. Using a metronome to guide your posting cadence builds muscle memory for maintaining rhythm regardless of the horse's pace."
        case .riderStillness:
            return "Rider stillness training develops quiet, stable aids by minimizing unnecessary movement. Holding a steady position while simulating movement builds the core control needed for effective communication with the horse."
        case .stirrupPressure:
            return "Stirrup pressure training develops proper weight distribution through the heels and stirrups. Maintaining consistent pressure builds the lower leg stability essential for secure, balanced riding."
        }
    }
}

// MARK: - Drill Stat Box

private struct DrillStatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)

            Text(value)
                .font(.title3.bold())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        RidingDrillDetailView(session: RidingDrillSession(
            drillType: .coreStability,
            duration: 30,
            score: 85
        ))
    }
}
