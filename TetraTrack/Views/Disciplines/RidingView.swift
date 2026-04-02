//
//  RidingView.swift
//  TetraTrack
//
//  Riding discipline — sessions are Watch-primary, this view guides to Watch
//

import SwiftUI

struct RidingView: View {
    var body: some View {
        WatchSessionGuideView(
            discipline: "Riding",
            icon: "figure.equestrian.sports",
            color: .green,
            description: "Riding session with type-specific metrics",
            metrics: [
                (icon: "figure.equestrian.sports", name: "Ride", detail: "General riding — hacking, schooling, trail"),
                (icon: "figure.equestrian.sports", name: "Dressage", detail: "Posting rhythm and turn balance"),
                (icon: "arrow.up.forward", name: "Showjumping", detail: "Jump counting with manual override")
            ]
        )
    }
}

#Preview {
    NavigationStack {
        RidingView()
    }
}
