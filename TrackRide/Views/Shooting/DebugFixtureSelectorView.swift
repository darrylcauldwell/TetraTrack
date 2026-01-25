//
//  DebugFixtureSelectorView.swift
//  TrackRide
//
//  Debug-only UI for selecting test fixtures in Simulator.
//  Does not appear in production builds.
//

import SwiftUI

#if DEBUG

// MARK: - Fixture Selector View

/// Debug view for selecting test fixture images
struct DebugFixtureSelectorView: View {
    @Environment(\.dismiss) private var dismiss

    let onFixtureSelected: (TargetFixture) -> Void

    @State private var selectedCategory: TargetFixture.FixtureCategory?
    @State private var searchText = ""
    @State private var showMetadata = false
    @State private var selectedFixture: TargetFixture?

    private let registry = TargetFixtureRegistry.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                categoryPicker

                // Fixture list
                fixtureList
            }
            .navigationTitle("Test Fixtures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search fixtures")
            .sheet(item: $selectedFixture) { fixture in
                FixtureDetailSheet(
                    fixture: fixture,
                    onSelect: {
                        onFixtureSelected(fixture)
                        dismiss()
                    }
                )
            }
            .presentationBackground(Color.black)
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(TargetFixture.FixtureCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(AppColors.cardBackground)
    }

    // MARK: - Fixture List

    private var fixtureList: some View {
        List {
            ForEach(filteredFixtures) { fixture in
                FixtureRow(fixture: fixture)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFixture = fixture
                    }
            }
        }
        .listStyle(.plain)
    }

    private var filteredFixtures: [TargetFixture] {
        var fixtures = selectedCategory == nil
            ? registry.allFixtures
            : registry.fixtures(in: selectedCategory!)

        if !searchText.isEmpty {
            fixtures = fixtures.filter { fixture in
                fixture.name.localizedCaseInsensitiveContains(searchText) ||
                fixture.metadata.description.localizedCaseInsensitiveContains(searchText)
            }
        }

        return fixtures
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : AppColors.elevatedSurface)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Fixture Row

private struct FixtureRow: View {
    let fixture: TargetFixture

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.elevatedSurface)

                if let image = fixture.loadImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(fixture.name)
                    .font(.subheadline.bold())

                Text(fixture.metadata.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label("\(fixture.metadata.expectedHoleCount)", systemImage: "circle.fill")
                    Label("D\(fixture.metadata.difficulty)", systemImage: "star.fill")
                    Text(fixture.category.rawValue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fixture Detail Sheet

private struct FixtureDetailSheet: View {
    let fixture: TargetFixture
    let onSelect: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    imagePreview

                    // Metadata
                    metadataSection

                    // Golden master shots
                    if !fixture.metadata.goldenMasterShots.isEmpty {
                        goldenMasterSection
                    }

                    // Expected analysis
                    if let analysis = fixture.metadata.expectedAnalysis {
                        expectedAnalysisSection(analysis)
                    }
                }
                .padding()
            }
            .navigationTitle(fixture.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Fixture") {
                        onSelect()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let image = fixture.loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.elevatedSurface)
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                            Text("Image not found")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetadataItem(label: "Target Type", value: fixture.metadata.targetType)
                MetadataItem(label: "Expected Holes", value: "\(fixture.metadata.expectedHoleCount)")
                MetadataItem(label: "Rotation", value: "\(Int(fixture.metadata.rotationDegrees))°")
                MetadataItem(label: "Perspective Skew", value: String(format: "%.2f", fixture.metadata.perspectiveSkew))
                MetadataItem(label: "Lighting", value: fixture.metadata.lightingCondition.rawValue)
                MetadataItem(label: "Difficulty", value: "\(fixture.metadata.difficulty)/5")
            }

            Text(fixture.metadata.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var goldenMasterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Golden Master Shots")
                .font(.headline)

            ForEach(fixture.metadata.goldenMasterShots) { shot in
                HStack {
                    Text("(\(String(format: "%.2f", shot.normalizedX)), \(String(format: "%.2f", shot.normalizedY)))")
                        .font(.system(.caption, design: .monospaced))

                    Spacer()

                    Text("Score: \(shot.expectedScore)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(scoreColor(shot.expectedScore).opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func expectedAnalysisSection(_ analysis: ExpectedPatternAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expected Analysis")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetadataItem(
                    label: "MPI",
                    value: "(\(String(format: "%.3f", analysis.mpiX)), \(String(format: "%.3f", analysis.mpiY)))"
                )
                MetadataItem(
                    label: "Std Dev",
                    value: String(format: "%.3f", analysis.standardDeviation)
                )
                MetadataItem(
                    label: "Extreme Spread",
                    value: String(format: "%.3f", analysis.extremeSpread)
                )
                MetadataItem(
                    label: "Tolerance",
                    value: String(format: "%.3f", analysis.tolerance)
                )
            }

            if analysis.expectsBias, let direction = analysis.expectedBiasDirection {
                Text("Expected bias: \(direction)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 10: return .yellow
        case 8, 6: return .green
        case 4, 2: return .blue
        default: return .gray
        }
    }
}

// MARK: - Metadata Item

private struct MetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Inline Fixture Picker (for embedding in other views)

/// Compact fixture picker for embedding in scanner view
struct InlineFixturePicker: View {
    @Binding var selectedFixture: TargetFixture?
    @State private var showingFullSelector = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "testtube.2")
                    .foregroundStyle(.orange)
                Text("Simulator Mode")
                    .font(.subheadline.bold())
                Spacer()
                Button("Select Fixture") {
                    showingFullSelector = true
                }
                .font(.subheadline)
            }

            if let fixture = selectedFixture {
                HStack {
                    if let image = fixture.loadImage() {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading) {
                        Text(fixture.name)
                            .font(.caption.bold())
                        Text("\(fixture.metadata.expectedHoleCount) holes, D\(fixture.metadata.difficulty)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        selectedFixture = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(AppColors.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingFullSelector) {
            DebugFixtureSelectorView { fixture in
                selectedFixture = fixture
            }
        }
        .presentationBackground(Color.black)
    }
}

// MARK: - Preview

#Preview {
    DebugFixtureSelectorView { fixture in
        print("Selected: \(fixture.name)")
    }
}

#endif
