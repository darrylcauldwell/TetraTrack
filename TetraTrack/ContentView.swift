//
//  ContentView.swift
//  TetraTrack
//
//  All disciplines are Watch-primary — iPhone shows the disciplines hub.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        DisciplinesView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Ride.self], inMemory: true)
}
