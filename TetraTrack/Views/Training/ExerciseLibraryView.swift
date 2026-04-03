//
//  ExerciseLibraryView.swift
//  TetraTrack
//
//  Combined exercise library with Flatwork and Polework tabs
//

import SwiftUI

struct ExerciseLibraryView: View {
    @State private var selectedTab: ExerciseTab = .flatwork

    enum ExerciseTab: String, CaseIterable {
        case flatwork = "Flatwork"
        case polework = "Polework"
        case groundwork = "Groundwork"
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .flatwork:
                FlatworkLibraryView()
            case .polework:
                PoleworkLibraryView()
            case .groundwork:
                GroundworkLibraryView()
            }
        }
        .navigationTitle("Schooling")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ExerciseTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            if tab == selectedTab {
                                Label(tab.rawValue, systemImage: "checkmark")
                            } else {
                                Text(tab.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedTab.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(Capsule())
                }
            }
        }
    }
}
