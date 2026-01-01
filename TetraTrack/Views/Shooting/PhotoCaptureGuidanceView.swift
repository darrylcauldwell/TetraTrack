//
//  PhotoCaptureGuidanceView.swift
//  TetraTrack
//
//  Guidance for capturing target photos with optimal detection quality.
//  Includes tips for handling targets with dark half areas.
//

import SwiftUI

// MARK: - Photo Capture Guidance View

/// View providing guidance for capturing target photos
struct PhotoCaptureGuidanceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    // Quick tips
                    quickTipsSection

                    // Detailed guidance sections
                    lightingSection
                    positioningSection
                    darkAreaSection
                    backgroundSection
                    commonIssuesSection
                }
                .padding()
            }
            .navigationTitle("Capture Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Optimal Photo Capture", systemImage: "camera.viewfinder")
                .font(.title2.bold())

            Text("Follow these guidelines to ensure accurate hole detection, especially on targets with dark areas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quick Tips

    private var quickTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tips")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickTipCard(
                    icon: "lightbulb.max.fill",
                    title: "Use Flash",
                    color: .yellow
                )

                QuickTipCard(
                    icon: "arrow.up.and.down.and.arrow.left.and.right",
                    title: "Fill Frame",
                    color: .blue
                )

                QuickTipCard(
                    icon: "viewfinder",
                    title: "Center Target",
                    color: .green
                )

                QuickTipCard(
                    icon: "arrow.up.to.line",
                    title: "Shoot Flat",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Lighting Section

    private var lightingSection: some View {
        GuidanceSection(
            title: "Lighting",
            icon: "sun.max.fill",
            iconColor: .yellow
        ) {
            GuidanceItem(
                recommendation: "Use flash for consistent illumination",
                detail: "Flash provides even lighting and improves contrast on dark target areas. Built-in flash is sufficient for most conditions.",
                importance: .high
            )

            GuidanceItem(
                recommendation: "Avoid direct sunlight",
                detail: "Direct sunlight creates harsh shadows and can wash out parts of the target. Shoot in shade or use diffused light.",
                importance: .medium
            )

            GuidanceItem(
                recommendation: "Minimize shadows on the target",
                detail: "Position yourself so your shadow doesn't fall on the target. Side lighting can help reveal hole depth.",
                importance: .medium
            )

            GuidanceItem(
                recommendation: "Indoor: use overhead or angled lighting",
                detail: "Angle a light source at 30-45 degrees to create subtle shadows that help define holes.",
                importance: .low
            )
        }
    }

    // MARK: - Positioning Section

    private var positioningSection: some View {
        GuidanceSection(
            title: "Camera Position",
            icon: "camera.fill",
            iconColor: .blue
        ) {
            GuidanceItem(
                recommendation: "Position camera directly above the target",
                detail: "Perpendicular alignment minimizes perspective distortion and ensures accurate coordinate mapping.",
                importance: .high
            )

            GuidanceItem(
                recommendation: "Fill 70-80% of the frame with the target",
                detail: "Leaves room for the outer edge while maximizing resolution on the scoring zones.",
                importance: .high
            )

            GuidanceItem(
                recommendation: "Keep the target centered",
                detail: "Centering reduces lens distortion effects, especially at the edges of the frame.",
                importance: .medium
            )

            GuidanceItem(
                recommendation: "Hold camera steady or use a tripod",
                detail: "Blur from camera shake significantly reduces detection accuracy. Use a steady rest if available.",
                importance: .medium
            )
        }
    }

    // MARK: - Dark Area Section

    private var darkAreaSection: some View {
        GuidanceSection(
            title: "Targets with Dark Areas",
            icon: "circle.lefthalf.filled",
            iconColor: .purple
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tetrathlon and some competition targets have half-black scoring zones where holes are harder to see.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GuidanceItem(
                recommendation: "Always use flash on dark targets",
                detail: "Flash creates a bright spot on the paper that reveals holes by their shadow and edge contrast.",
                importance: .high
            )

            GuidanceItem(
                recommendation: "Angle the target slightly toward light",
                detail: "A 5-10 degree tilt can help light reach inside the holes, making them more visible against the dark background.",
                importance: .high
            )

            GuidanceItem(
                recommendation: "Use a flashlight for additional fill",
                detail: "A second light source from a different angle can illuminate hole interiors on the dark half.",
                importance: .medium
            )

            GuidanceItem(
                recommendation: "Check the preview before committing",
                detail: "Zoom in on the dark area to verify holes are visible before saving the photo.",
                importance: .medium
            )

            GuidanceItem(
                recommendation: "Consider taking multiple exposures",
                detail: "If holes aren't visible, try different flash angles or add ambient light.",
                importance: .low
            )
        }
    }

    // MARK: - Background Section

    private var backgroundSection: some View {
        GuidanceSection(
            title: "Background & Surface",
            icon: "rectangle.fill",
            iconColor: .gray
        ) {
            GuidanceItem(
                recommendation: "Place target on a solid, neutral surface",
                detail: "Gray or tan backgrounds work best. Avoid patterned surfaces that could interfere with edge detection.",
                importance: .high
            )

            GuidanceItem(
                recommendation: "Ensure the target lies flat",
                detail: "Wrinkled or curled paper creates shadows and distortion. Use clips or weights if needed.",
                importance: .medium
            )

            GuidanceItem(
                recommendation: "Remove distracting elements from frame",
                detail: "Other objects near the target can confuse automatic cropping and center detection.",
                importance: .low
            )
        }
    }

    // MARK: - Common Issues Section

    private var commonIssuesSection: some View {
        GuidanceSection(
            title: "Troubleshooting",
            icon: "exclamationmark.triangle.fill",
            iconColor: .orange
        ) {
            TroubleshootingItem(
                problem: "Holes not detected on dark half",
                solutions: [
                    "Enable flash and retake",
                    "Angle a secondary light into the holes",
                    "Increase brightness in detection settings"
                ]
            )

            TroubleshootingItem(
                problem: "Too many false detections",
                solutions: [
                    "Use a cleaner background",
                    "Ensure even lighting without hot spots",
                    "Increase confidence threshold in settings"
                ]
            )

            TroubleshootingItem(
                problem: "Blurry image warning",
                solutions: [
                    "Use a tripod or steady rest",
                    "Improve lighting to enable faster shutter",
                    "Clean the camera lens"
                ]
            )

            TroubleshootingItem(
                problem: "Target not centered correctly",
                solutions: [
                    "Manually adjust center point after capture",
                    "Ensure target edges are visible in frame",
                    "Remove nearby objects that may confuse detection"
                ]
            )
        }
    }
}

// MARK: - Guidance Section

private struct GuidanceSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Guidance Item

private struct GuidanceItem: View {
    let recommendation: String
    let detail: String
    let importance: Importance

    enum Importance {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }

        var icon: String {
            switch self {
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "info.circle.fill"
            case .low: return "lightbulb.fill"
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: importance.icon)
                .foregroundStyle(importance.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation)
                    .font(.subheadline.bold())

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Quick Tip Card

private struct QuickTipCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Troubleshooting Item

private struct TroubleshootingItem: View {
    let problem: String
    let solutions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(problem)
                .font(.subheadline.bold())
                .foregroundStyle(.orange)

            ForEach(solutions, id: \.self) { solution in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)

                    Text(solution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Compact Guidance Banner

/// Compact banner for showing in capture views
struct CaptureGuidanceBanner: View {
    let showExpandedTips: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)

            Text("Use flash for best results on dark targets")
                .font(.caption)

            Spacer()

            Button("More Tips") {
                showExpandedTips()
            }
            .font(.caption.bold())
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    PhotoCaptureGuidanceView()
}

#Preview("Banner") {
    CaptureGuidanceBanner {
        print("Show tips")
    }
    .padding()
}
