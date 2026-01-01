//
//  RidingView.swift
//  TetraTrack
//
//  Riding discipline - goes directly to ride type selection
//

import SwiftUI

struct RidingView: View {
    @Environment(\.viewContext) private var viewContext

    var body: some View {
        Group {
            if viewContext.isReadOnly {
                // iPad review-only mode - show informational message
                VStack(spacing: 16) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Review Mode")
                        .font(.headline)
                    Text("Session capture is not available on iPad. Use Session History to review past riding sessions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // iPhone capture mode - show tracking view
                TrackingView()
            }
        }
        .navigationTitle("Riding")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RidingView()
    }
}
