//
//  DisciplineMenuView.swift
//  TrackRide
//
//  Unified menu component for all discipline views
//

import SwiftUI

// MARK: - Menu Item Configuration

struct DisciplineMenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
}

// MARK: - Discipline Menu View

struct DisciplineMenuView: View {
    let items: [DisciplineMenuItem]
    var header: AnyView? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Optional header content (e.g., mode picker for Running)
                if let header = header {
                    header
                        .padding(.horizontal, 16)
                }

                // Menu items
                ForEach(items) { item in
                    Button(action: item.action) {
                        DisciplineCard(
                            title: item.title,
                            subtitle: item.subtitle,
                            icon: item.icon,
                            color: item.color
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
}

// MARK: - Convenience initializer without header

extension DisciplineMenuView {
    init(items: [DisciplineMenuItem]) {
        self.items = items
        self.header = nil
    }
}

#Preview {
    NavigationStack {
        DisciplineMenuView(items: [
            DisciplineMenuItem(
                title: "Track Ride",
                subtitle: "GPS & gait tracking",
                icon: "location.fill",
                color: .green,
                action: {}
            ),
            DisciplineMenuItem(
                title: "Training",
                subtitle: "Off-horse drills",
                icon: "figure.stand",
                color: .blue,
                action: {}
            ),
            DisciplineMenuItem(
                title: "Plan Route",
                subtitle: "Bridleways & trails",
                icon: "map.fill",
                color: .orange,
                action: {}
            )
        ])
        .navigationTitle("Riding")
        .navigationBarTitleDisplayMode(.inline)
    }
}
