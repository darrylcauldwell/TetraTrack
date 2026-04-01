//
//  ShootingView.swift
//  TetraTrack
//
//  Shooting discipline — sessions are Watch-primary, iPhone handles marking/scoring
//

import SwiftUI
import SwiftData

struct ShootingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompetitionPractice = false
    @State private var showingHistory = false
    @State private var showingSettings = false

    private var menuItems: [DisciplineMenuItem] {
        [
            DisciplineMenuItem(
                title: "Free Practice",
                subtitle: "Start on Apple Watch — shoot and review",
                icon: "target",
                color: .blue,
                requiresCapture: false,
                action: { /* Watch-only — no iPhone action needed */ }
            ),
            DisciplineMenuItem(
                title: "Competition Practice",
                subtitle: "Scan and score targets after Watch session",
                icon: "figure.run",
                color: .orange,
                requiresCapture: true,
                action: {
                    showingCompetitionPractice = true
                }
            ),
            DisciplineMenuItem(
                title: "Shooting History",
                subtitle: "View patterns and pressure insights",
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                requiresCapture: false,
                action: { showingHistory = true }
            )
        ]
    }

    var body: some View {
        DisciplineMenuView(items: menuItems)
            .navigationTitle("Shooting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
            .fullScreenCover(isPresented: $showingHistory) {
                ShootingHistoryAggregateView(
                    onDismiss: {
                        showingHistory = false
                    },
                    initialDateFilter: nil
                )
            }
            .fullScreenCover(isPresented: $showingCompetitionPractice) {
                NavigationStack {
                    ShootingPracticeView()
                        .navigationTitle("Score Targets")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") {
                                    showingCompetitionPractice = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingSettings) {
                ShootingSettingsView()
            }
        .sheetBackground()
    }
}

#Preview {
    ShootingView()
        .modelContainer(for: ShootingSession.self, inMemory: true)
}
