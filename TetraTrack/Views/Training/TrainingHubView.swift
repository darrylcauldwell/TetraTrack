//
//  TrainingHubView.swift
//  TetraTrack
//
//  Combined view for Training Load and Training Drills
//

import SwiftUI

struct TrainingHubView: View {
    @State private var selectedTab: TrainingTab = .load

    enum TrainingTab: String, CaseIterable {
        case load = "Training Load"
        case drills = "Drills"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(TrainingTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .load:
                TrainingLoadDashboardView()
            case .drills:
                UnifiedTrainingView()
            }
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
    }
}
