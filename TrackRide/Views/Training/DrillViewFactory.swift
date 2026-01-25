//
//  DrillViewFactory.swift
//  TrackRide
//
//  Factory for creating the appropriate view for each drill type
//

import SwiftUI
import SwiftData

/// Factory that creates the appropriate drill view based on drill type
struct DrillViewFactory {

    /// Returns the appropriate view for a given unified drill type
    @ViewBuilder
    static func view(for drillType: UnifiedDrillType, modelContext: ModelContext) -> some View {
        switch drillType {
        // MARK: - Riding Drills
        case .heelPosition:
            HeelPositionDrillView()
        case .coreStability:
            CoreStabilityDrillView()
        case .twoPoint:
            TwoPointHoldDrillView()
        case .balanceBoard:
            BalanceBoardDrillView()
        case .hipMobility:
            HipMobilityDrillView()
        case .postingRhythm:
            PostingRhythmDrillView()
        case .riderStillness:
            RiderStillnessDrillView()
        case .stirrupPressure:
            StirrupPressureDrillView()
        case .extendedSeatHold:
            ExtendedSeatHoldDrillView()
        case .mountedBreathing:
            MountedBreathingDrillView()

        // MARK: - Shooting Drills
        case .standingBalance:
            BalanceDrillView()
        case .boxBreathing:
            BreathingDrillView()
        case .dryFire:
            DryFireDrillView()
        case .reactionTime:
            ReactionDrillView()
        case .steadyHold:
            SteadyHoldDrillView()
        case .recoilControl:
            RecoilControlDrillView()
        case .splitTime:
            SplitTimeDrillView()
        case .posturalDrift:
            PosturalDriftDrillView()
        case .stressInoculation:
            StressInoculationDrillView()

        // MARK: - Running Drills
        case .cadenceTraining:
            CadenceTrainingDrillView()
        case .runningHipMobility:
            RunningHipMobilityDrillView()
        case .runningCoreStability:
            RunningCoreStabilityDrillView()
        case .breathingPatterns:
            BreathingPatternsDrillView()
        case .plyometrics:
            PlyometricsDrillView()
        case .singleLegBalance:
            SingleLegBalanceDrillView()

        // MARK: - Swimming Drills
        case .breathingRhythm:
            BreathingRhythmDrillView()
        case .swimmingCoreStability:
            SwimmingCoreStabilityDrillView()
        case .shoulderMobility:
            ShoulderMobilityDrillView()
        case .streamlinePosition:
            StreamlinePositionDrillView()
        case .kickEfficiency:
            KickEfficiencyDrillView()
        }
    }

    /// Returns a placeholder view for drill types not yet implemented
    @ViewBuilder
    static func placeholderView(for drillType: UnifiedDrillType) -> some View {
        DrillPlaceholderView(drillType: drillType)
    }
}

// MARK: - Placeholder View for Unimplemented Drills

struct DrillPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    let drillType: UnifiedDrillType

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(drillType.color.opacity(0.2))
                        .frame(width: 120, height: 120)
                    Image(systemName: drillType.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(drillType.color)
                }

                // Title
                Text(drillType.displayName)
                    .font(.largeTitle.bold())

                // Category
                HStack {
                    Image(systemName: drillType.primaryCategory.icon)
                    Text(drillType.primaryCategory.displayName)
                }
                .font(.headline)
                .foregroundStyle(.secondary)

                // Description
                Text(drillType.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Benefits badges
                if drillType.benefitsDisciplines.count > 1 {
                    VStack(spacing: 8) {
                        Text("Benefits")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(Array(drillType.benefitsDisciplines).filter { $0 != .all }, id: \.self) { discipline in
                                VStack(spacing: 4) {
                                    Image(systemName: discipline.icon)
                                        .font(.title2)
                                        .foregroundStyle(discipline.color)
                                    Text(discipline.displayName)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(AppColors.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Coming soon notice
                VStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Coming Soon")
                        .font(.headline)
                    Text("This drill is being developed and will be available in a future update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DrillPlaceholderView(drillType: .cadenceTraining)
}
