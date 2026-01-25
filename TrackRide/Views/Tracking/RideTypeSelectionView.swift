//
//  RideTypeSelectionView.swift
//  TrackRide
//
//  Allows user to select ride type before starting a ride

import SwiftUI

struct RideTypeSelectionView: View {
    @Binding var selectedType: RideType

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Ride Type")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RideType.allCases, id: \.self) { rideType in
                    RideTypeCard(
                        rideType: rideType,
                        isSelected: selectedType == rideType,
                        action: { selectedType = rideType }
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}

struct RideTypeCard: View {
    let rideType: RideType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: rideType.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : rideType.color)

                Text(rideType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(rideType.color)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.cardBackground)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? rideType.color : Color.clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

#Preview {
    RideTypeSelectionView(selectedType: .constant(.hack))
        .padding()
        .background(Color(.systemBackground))
}
