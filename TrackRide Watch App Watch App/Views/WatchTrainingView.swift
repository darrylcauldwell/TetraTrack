//
//  WatchTrainingView.swift
//  TrackRide Watch App
//
//  Training drill selection for standalone Watch drills
//

import SwiftUI

struct WatchTrainingView: View {
    @State private var selectedDrill: DrillType?

    enum DrillType: String, CaseIterable, Identifiable {
        case balance = "Balance"
        case breathing = "Breathing"
        case reaction = "Reaction"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .balance: return "figure.stand"
            case .breathing: return "wind"
            case .reaction: return "bolt.fill"
            }
        }

        var color: Color {
            switch self {
            case .balance: return .purple
            case .breathing: return .blue
            case .reaction: return .orange
            }
        }

        var description: String {
            switch self {
            case .balance: return "One-leg stability"
            case .breathing: return "Box breathing"
            case .reaction: return "Tap targets"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Training Drills")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                ForEach(DrillType.allCases) { drill in
                    DrillButton(drill: drill) {
                        selectedDrill = drill
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedDrill) { drill in
            switch drill {
            case .balance:
                WatchBalanceDrillView()
            case .breathing:
                WatchBreathingDrillView()
            case .reaction:
                WatchReactionDrillView()
            }
        }
    }
}

// MARK: - Drill Button

private struct DrillButton: View {
    let drill: WatchTrainingView.DrillType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(drill.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: drill.icon)
                        .font(.body)
                        .foregroundStyle(drill.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text(drill.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.darkGray).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        WatchTrainingView()
    }
}
