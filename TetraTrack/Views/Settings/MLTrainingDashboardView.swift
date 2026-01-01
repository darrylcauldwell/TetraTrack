//
//  MLTrainingDashboardView.swift
//  TetraTrack
//
//  Dashboard showing ML training data collection progress and per-session metrics.
//

import SwiftUI
import os

struct MLTrainingDashboardView: View {
    @State private var manifest: TrainingDatasetManifest?
    @State private var recentCaptures: [TrainingTargetCapture] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingClearConfirmation = false

    // Goals for ML readiness
    private let targetCaptures = 100
    private let targetBlackRegionHoles = 200
    private let targetOverlappingHoles = 50

    var body: some View {
        List {
            if isLoading {
                loadingSection
            } else if let error = errorMessage {
                errorSection(error)
            } else {
                progressSection
                statsSection
                breakdownSection
                recentCapturesSection
                exportSection
            }
        }
        .navigationTitle("ML Training Data")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        Section {
            HStack {
                ProgressView()
                Text("Loading training data...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorSection(_ error: String) -> some View {
        Section {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }

    // MARK: - Progress Toward Goals

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Collection Progress")
                    .font(.headline)

                progressRow(
                    title: "Total Targets",
                    current: manifest?.datasetStats.totalCaptures ?? 0,
                    goal: targetCaptures,
                    icon: "target",
                    color: .blue
                )

                progressRow(
                    title: "Black Region Holes",
                    current: manifest?.datasetStats.blackRegionHoles ?? 0,
                    goal: targetBlackRegionHoles,
                    icon: "circle.lefthalf.filled",
                    color: .purple
                )

                progressRow(
                    title: "Overlapping Holes",
                    current: manifest?.datasetStats.overlappingHoles ?? 0,
                    goal: targetOverlappingHoles,
                    icon: "circle.circle",
                    color: .orange
                )
            }
            .padding(.vertical, 8)
        } header: {
            Text("ML Readiness")
        } footer: {
            if let stats = manifest?.datasetStats, stats.totalCaptures >= targetCaptures {
                Label("Dataset ready for ML training!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Text("Collect more targets to build a robust ML model")
            }
        }
    }

    private func progressRow(title: String, current: Int, goal: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                Spacer()
                Text("\(current) / \(goal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: min(Double(current), Double(goal)), total: Double(goal))
                .tint(current >= goal ? .green : color)
        }
    }

    // MARK: - Overall Statistics

    private var statsSection: some View {
        Section("Dataset Statistics") {
            if let stats = manifest?.datasetStats {
                statRow(label: "Total Captures", value: "\(stats.totalCaptures)")
                statRow(label: "Total Holes Marked", value: "\(stats.totalHoles)")
                statRow(label: "Avg Holes/Target", value: String(format: "%.1f", stats.totalCaptures > 0 ? Double(stats.totalHoles) / Double(stats.totalCaptures) : 0))
                statRow(label: "Total Corrections", value: "\(stats.totalCorrections)")
                statRow(label: "Correction Rate", value: String(format: "%.1f%%", stats.totalHoles > 0 ? Double(stats.totalCorrections) / Double(stats.totalHoles) * 100 : 0))
            } else {
                Text("No data collected yet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Breakdown by Category

    private var breakdownSection: some View {
        Section("Hole Distribution") {
            if let stats = manifest?.datasetStats, stats.totalHoles > 0 {
                HStack(spacing: 20) {
                    categoryPill(
                        label: "White",
                        count: stats.whiteRegionHoles,
                        total: stats.totalHoles,
                        color: .gray
                    )
                    categoryPill(
                        label: "Black",
                        count: stats.blackRegionHoles,
                        total: stats.totalHoles,
                        color: .primary
                    )
                    categoryPill(
                        label: "Torn",
                        count: stats.tornHoles,
                        total: stats.totalHoles,
                        color: .orange
                    )
                    categoryPill(
                        label: "Overlap",
                        count: stats.overlappingHoles,
                        total: stats.totalHoles,
                        color: .red
                    )
                }
                .padding(.vertical, 8)
            } else {
                Text("No holes marked yet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func categoryPill(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(String(format: "%.0f%%", total > 0 ? Double(count) / Double(total) * 100 : 0))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Captures

    private var recentCapturesSection: some View {
        Section("Recent Captures") {
            if recentCaptures.isEmpty {
                Text("No captures yet. Scan a target to start collecting data.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentCaptures.prefix(10)) { capture in
                    captureRow(capture)
                }
            }
        }
    }

    private func captureRow(_ capture: TrainingTargetCapture) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text(capture.captureTimestamp, style: .date)
                        .font(.subheadline.bold())
                    Text(capture.captureTimestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(capture.annotations.count) holes")
                        .font(.subheadline)
                    if capture.stats.totalCorrections > 0 {
                        Text("\(capture.stats.totalCorrections) corrections")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Session metrics
            HStack(spacing: 12) {
                metricBadge(
                    icon: "circle.righthalf.filled",
                    value: "\(capture.stats.whiteRegionHoles)",
                    label: "White"
                )
                metricBadge(
                    icon: "circle.lefthalf.filled",
                    value: "\(capture.stats.blackRegionHoles)",
                    label: "Black"
                )
                if capture.stats.overlappingHoles > 0 {
                    metricBadge(
                        icon: "circle.circle",
                        value: "\(capture.stats.overlappingHoles)",
                        label: "Overlap",
                        highlight: true
                    )
                }
                if capture.stats.tornHoles > 0 {
                    metricBadge(
                        icon: "waveform.path",
                        value: "\(capture.stats.tornHoles)",
                        label: "Torn",
                        highlight: true
                    )
                }

                Spacer()

                // Session duration
                if let duration = capture.metadata.sessionDurationSeconds {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func metricBadge(icon: String, value: String, label: String, highlight: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption.bold())
        }
        .foregroundStyle(highlight ? .orange : .secondary)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            Button {
                Task {
                    await exportDataset()
                }
            } label: {
                Label("Export Dataset", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
            .confirmationDialog(
                "Clear Training Data",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    Task {
                        await clearAllData()
                    }
                }
            } message: {
                Text("This will delete all captured training data. This action cannot be undone.")
            }
        } header: {
            Text("Actions")
        } footer: {
            if let path = getDatasetPath() {
                Text("Data stored at: \(path)")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            manifest = try await MLTrainingDataService.shared.loadManifest()

            // Load recent captures
            var captures: [TrainingTargetCapture] = []
            if let refs = manifest?.captures.suffix(10) {
                for ref in refs.reversed() {
                    if let capture = try? await MLTrainingDataService.shared.loadCapture(id: ref.captureId) {
                        captures.append(capture)
                    }
                }
            }
            recentCaptures = captures
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func exportDataset() async {
        do {
            let url = try await MLTrainingDataService.shared.exportDataset()
            Log.shooting.info("Dataset exported to: \(url.path)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearAllData() async {
        do {
            try await MLTrainingDataService.shared.clearAllData()
            manifest = nil
            recentCaptures = []
            await loadData()
            Log.shooting.info("ML training data cleared")
        } catch {
            errorMessage = error.localizedDescription
            Log.shooting.error("Failed to clear training data: \(error.localizedDescription)")
        }
    }

    private func getDatasetPath() -> String? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("MLTrainingData").path
    }
}

#Preview {
    NavigationStack {
        MLTrainingDashboardView()
    }
}
