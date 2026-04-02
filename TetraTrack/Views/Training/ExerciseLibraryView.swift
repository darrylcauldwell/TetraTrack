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
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(ExerciseTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .flatwork:
                FlatworkLibraryView()
            case .polework:
                PoleworkLibraryView()
            }
        }
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}
