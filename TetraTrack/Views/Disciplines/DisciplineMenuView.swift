//
//  DisciplineMenuView.swift
//  TetraTrack
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
    /// Whether this menu item requires capture capability.
    /// Items marked as requiresCapture will be hidden in review-only mode (iPad).
    let requiresCapture: Bool

    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        requiresCapture: Bool = true,  // Default: most menu items require capture
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.requiresCapture = requiresCapture
        self.action = action
    }
}

// MARK: - Discipline Menu View

struct DisciplineMenuView: View {
    let items: [DisciplineMenuItem]
    var header: AnyView? = nil
    @Environment(\.viewContext) private var viewContext

    /// Items filtered by current ViewContext.
    /// In review-only mode (iPad), items requiring capture are hidden.
    private var filteredItems: [DisciplineMenuItem] {
        if viewContext.isReadOnly {
            return items.filter { !$0.requiresCapture }
        }
        return items
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Optional header content (e.g., mode picker for Running)
                // Header is hidden in review-only mode as it typically controls capture settings
                if let header = header, !viewContext.isReadOnly {
                    header
                        .padding(.horizontal, 16)
                }

                // Show message if no items available in review mode
                if filteredItems.isEmpty && viewContext.isReadOnly {
                    VStack(spacing: 16) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Review Mode")
                            .font(.headline)
                        Text("Session capture is not available on iPad. Use Session History to review past sessions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 48)
                    .padding(.horizontal, 32)
                } else {
                    // Menu items
                    ForEach(filteredItems) { item in
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
