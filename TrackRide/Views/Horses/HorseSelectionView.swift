//
//  HorseSelectionView.swift
//  TrackRide
//
//  Horizontal scroll view for selecting a horse before starting a ride

import SwiftUI
import SwiftData
import os

struct HorseSelectionView: View {
    @Query(filter: #Predicate<Horse> { !$0.isArchived }, sort: \Horse.name)
    private var horses: [Horse]

    @Binding var selectedHorse: Horse?
    @State private var showingSettings = false

    var body: some View {
        let _ = Log.ui.debug("HorseSelectionView body rendering, horses count: \(horses.count)")
        VStack(alignment: .leading, spacing: 12) {
            Text("Horse")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if horses.isEmpty {
                // No horses configured - show + button to add
                Button(action: { showingSettings = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primary.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(AppColors.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Horse")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("Go to Settings to add your horse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            } else {
                // Show all configured horses
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(horses) { horse in
                            HorseSelectionItem(
                                horse: horse,
                                isSelected: selectedHorse?.id == horse.id,
                                onTap: { selectedHorse = horse }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                HorseListView()
            }
            .presentationBackground(Color.black)
        }
        .onAppear {
            // Auto-select first horse if none selected and horses exist
            if selectedHorse == nil, let firstHorse = horses.first {
                selectedHorse = firstHorse
            }
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Horse Selection Item

struct HorseSelectionItem: View {
    let horse: Horse
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    HorseAvatarView(horse: horse, size: 50)

                    // Selection indicator
                    if isSelected {
                        Circle()
                            .stroke(AppColors.primary, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }

                Text(horse.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? AppColors.primary : .secondary)
            }
            .frame(width: 60)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        HorseSelectionView(selectedHorse: .constant(nil))
            .padding()
    }
    .modelContainer(for: [Horse.self], inMemory: true)
}
