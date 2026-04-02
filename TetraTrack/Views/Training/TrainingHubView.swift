//
//  TrainingHubView.swift
//  TetraTrack
//
//  Combined view for Training Load and Training Drills
//

import SwiftUI

struct TrainingHubView: View {
    @State private var selectedTab: TrainingTab = .load

    @State private var showingScoreTargets = false

    enum TrainingTab: String, CaseIterable {
        case load = "Load"
        case drills = "Drills"
        case scoring = "Scoring"
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
            case .scoring:
                scoringTab
            }
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingScoreTargets) {
            NavigationStack {
                ShootingPracticeView()
                    .navigationTitle("Score Targets")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingScoreTargets = false }
                        }
                    }
            }
        }
    }

    private var scoringTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button {
                    showingScoreTargets = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 32))
                            .foregroundStyle(AppColors.shooting)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Score Targets")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Scan and score shooting practice targets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }
}
