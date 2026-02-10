//
//  CompetitionHubView.swift
//  TetraTrack
//
//  3-tab hub for competition management: Calendar, Competition Day, Tasks
//

import SwiftUI

struct CompetitionHubView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CompetitionCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(0)

            CompetitionDayView()
                .tabItem {
                    Label("Competition Day", systemImage: "flag.fill")
                }
                .tag(1)

            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(2)
        }
        .navigationTitle("Competitions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CompetitionHubView()
    }
}
