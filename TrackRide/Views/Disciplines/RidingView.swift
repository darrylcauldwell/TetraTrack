//
//  RidingView.swift
//  TrackRide
//
//  Riding discipline - goes directly to ride type selection
//

import SwiftUI

struct RidingView: View {
    var body: some View {
        TrackingView()
            .navigationTitle("Riding")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RidingView()
    }
}
