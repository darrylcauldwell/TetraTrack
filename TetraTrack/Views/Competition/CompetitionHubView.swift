//
//  CompetitionHubView.swift
//  TetraTrack
//
//  Segmented hub for competition management: Calendar, Competition Day
//

import SwiftUI

struct CompetitionHubView: View {
    @State private var selectedTab: Int

    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                Text("Calendar").tag(0)
                Text("Comp Day").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Group {
                switch selectedTab {
                case 0: CompetitionCalendarView()
                case 1: CompetitionDayView()
                default: CompetitionCalendarView()
                }
            }
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
