//
//  RidingView.swift
//  TetraTrack
//
//  Riding placeholder — sessions are Watch-primary.
//  Kept for ScreenshotRouterView compatibility.
//

import SwiftUI

struct RidingView: View {
    var body: some View {
        ContentUnavailableView(
            "Start on Apple Watch",
            systemImage: "applewatch",
            description: Text("Open TetraTrack on your Apple Watch to start a riding session.")
        )
        .navigationTitle("Riding")
        .navigationBarTitleDisplayMode(.inline)
    }
}
