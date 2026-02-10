//
//  LeadBalanceView.swift
//  TetraTrack
//
//  Displays left/right lead balance during canter/gallop

import SwiftUI

struct LeadBalanceView: View {
    let ride: Ride

    private var leftPercent: Int {
        ride.leadBalancePercent
    }

    private var rightPercent: Int {
        100 - leftPercent
    }

    private var totalLeadDuration: TimeInterval {
        ride.totalLeadDuration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lead Balance")
                    .font(.headline)

                Spacer()

                Text("Canter/Gallop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if totalLeadDuration == 0 {
                Text("No lead data recorded")
                    .foregroundStyle(.secondary)
                placementGuidance
            } else {
                // Balance bar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Left side
                        Rectangle()
                            .fill(AppColors.turnLeft)
                            .frame(width: geometry.size.width * CGFloat(leftPercent) / 100)

                        // Right side
                        Rectangle()
                            .fill(AppColors.turnRight)
                            .frame(width: geometry.size.width * CGFloat(rightPercent) / 100)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 24)

                // Labels
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "arrow.left.circle.fill")
                                .foregroundStyle(AppColors.turnLeft)
                            Text("Left Lead")
                                .font(.subheadline)
                        }
                        Text(ride.formattedLeftLeadDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(leftPercent)%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.turnLeft)
                    }

                    Spacer()

                    // Balance indicator
                    VStack {
                        Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundStyle(isBalanced ? AppColors.success : AppColors.warning)
                        Text(isBalanced ? "Balanced" : "Uneven")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        HStack {
                            Text("Right Lead")
                                .font(.subheadline)
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(AppColors.turnRight)
                        }
                        Text(ride.formattedRightLeadDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(rightPercent)%")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.turnRight)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var isBalanced: Bool {
        leftPercent >= 40 && leftPercent <= 60
    }

    @ViewBuilder
    private var placementGuidance: some View {
        if ride.phoneMountPosition == .jacketChest {
            Label("For best lead detection, place phone in jodhpur thigh pocket", systemImage: "iphone.gen3")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LeadBalanceView(ride: {
        let ride = Ride()
        ride.leftLeadDuration = 120
        ride.rightLeadDuration = 90
        return ride
    }())
    .padding()
}
