//
//  ShootingDrillDetailView.swift
//  TrackRide
//
//  Detail view for a completed shooting drill session
//

import SwiftUI
import SwiftData

struct ShootingDrillDetailView: View {
    let session: ShootingDrillSession
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
                    ShootingDrillStatBox(title: "Duration", value: session.formattedDuration, icon: "clock")
                    ShootingDrillStatBox(title: "Score", value: session.formattedScore, icon: "star.fill")
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
        case .balance: return .purple
        case .breathing: return .blue
        case .dryFire: return .green
        case .reaction: return .orange
        case .steadyHold: return .cyan
        case .recoilControl: return .red
        case .splitTime: return .yellow
        case .posturalDrift: return .indigo
        case .stressInoculation: return .pink
        }
    }

    private var scoreColor: Color {
        if session.score >= 80 { return .green }
        if session.score >= 60 { return .yellow }
        return .orange
    }

    private var drillDescription: String {
        switch session.drillType {
        case .balance:
            return "Balance training develops the stable platform needed for accurate shooting. Standing on one leg challenges your proprioception and builds the core strength required to maintain a steady shooting position."
        case .breathing:
            return "Box breathing (4-4-4-4) calms the nervous system and steadies your aim. This technique is used by elite shooters and military personnel to manage stress and improve focus before taking a shot."
        case .dryFire:
            return "Dry fire practice develops proper trigger control without the distraction of recoil. Focus on smooth trigger pulls while maintaining sight alignment and a stable stance."
        case .reaction:
            return "Reaction training with range commands builds the reflexes needed for rapid target acquisition. Quick, accurate responses to verbal commands translate to better competition performance."
        case .steadyHold:
            return "Steady hold training measures and improves your ability to maintain a stable aim point. Minimizing wobble leads to tighter shot groups and more consistent scoring."
        case .recoilControl:
            return "Recoil control training measures your ability to quickly return to target after simulated recoil. Fast recovery times between shots are essential for rapid-fire competition shooting."
        case .splitTime:
            return "Split time training develops quick, accurate transitions between multiple targets. Minimizing transition time while maintaining stability at each target is key to competition success."
        case .posturalDrift:
            return "Postural drift training builds endurance for extended shooting sessions. Maintaining stability over 60-120 seconds simulates the demands of multi-shot competition strings."
        case .stressInoculation:
            return "Stress inoculation training tests your shooting under elevated heart rate conditions. Performing after physical exertion simulates the physiological stress of competition."
        }
    }
}

// MARK: - Shooting Drill Stat Box

private struct ShootingDrillStatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.red)

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
        ShootingDrillDetailView(session: ShootingDrillSession(
            drillType: .balance,
            duration: 30,
            score: 85
        ))
    }
}
