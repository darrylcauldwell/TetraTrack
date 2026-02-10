//
//  TurnBalanceView.swift
//  TetraTrack
//

import SwiftUI

struct TurnBalanceView: View {
    let ride: Ride

    private var leftPercent: Int {
        ride.turnBalancePercent
    }

    private var rightPercent: Int {
        100 - leftPercent
    }

    private var hasTurnData: Bool {
        ride.totalLeftAngle + ride.totalRightAngle > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turn Balance")
                .font(.headline)

            if !hasTurnData {
                Text("No turn data recorded")
                    .foregroundStyle(.secondary)
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
                            Image(systemName: "arrow.turn.up.left")
                                .foregroundStyle(AppColors.turnLeft)
                            Text("Left")
                                .font(.subheadline)
                        }
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
                            Text("Right")
                                .font(.subheadline)
                            Image(systemName: "arrow.turn.up.right")
                                .foregroundStyle(AppColors.turnRight)
                        }
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
}

#Preview {
    TurnBalanceView(ride: {
        let ride = Ride()
        ride.totalLeftAngle = 720.0
        ride.totalRightAngle = 480.0
        return ride
    }())
    .padding()
}
