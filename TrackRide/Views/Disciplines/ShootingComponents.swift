//
//  ShootingComponents.swift
//  TrackRide
//
//  Shooting discipline subviews extracted from ShootingView
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - Shoot Type Button

struct ShootTypeButton: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(color)
                    .frame(width: 70)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shoot Type Card (Grid Style)

struct ShootTypeCard: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shooting Personal Bests

struct ShootingPersonalBests {
    static var shared = ShootingPersonalBests()

    private let defaults = UserDefaults.standard

    // Competition PB - tetrathlon points (max 1000)
    // Raw score (2,4,6,8,10 per shot) x 10 = tetrathlon points
    var pbRawScore: Int {
        get { defaults.integer(forKey: "shooting_pb_raw") }
        set { defaults.set(newValue, forKey: "shooting_pb_raw") }
    }

    var pbTetrathlonPoints: Int {
        pbRawScore * 10
    }

    var formattedPB: String {
        guard pbRawScore > 0 else { return "No PB yet" }
        return "\(pbRawScore)/100 (\(pbTetrathlonPoints) pts)"
    }

    mutating func updatePersonalBest(rawScore: Int) {
        if rawScore > pbRawScore {
            pbRawScore = rawScore
        }
    }
}

// MARK: - Settings View

struct ShootingSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Competition") {
                    Text("Default: 2x 5-shot cards (10 shots total)")
                        .foregroundStyle(.secondary)
                }

                Section("Personal Best") {
                    HStack {
                        Text("Current PB")
                        Spacer()
                        Text(ShootingPersonalBests.shared.formattedPB)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Shooting Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Session Setup View

struct ShootingSessionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessionName = ""
    @State private var targetType: ShootingTargetType = .olympic
    @State private var distance: Double = 10.0
    @State private var numberOfEnds = 6
    @State private var arrowsPerEnd = 6
    @State private var sessionMode: SessionMode = .practice

    enum SessionMode: String, CaseIterable {
        case practice = "Practice"
        case competition = "Competition"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Type") {
                    Picker("Mode", selection: $sessionMode) {
                        ForEach(SessionMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Session Name (optional)", text: $sessionName)
                }

                Section("Target") {
                    Picker("Target Type", selection: $targetType) {
                        ForEach(ShootingTargetType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    HStack {
                        Text("Distance")
                        Spacer()
                        Text(String(format: "%.0fm", distance))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $distance, in: 5...25, step: 1)
                }

                Section("Rounds") {
                    Stepper("Ends: \(numberOfEnds)", value: $numberOfEnds, in: 1...12)
                    Stepper("Shots per End: \(arrowsPerEnd)", value: $arrowsPerEnd, in: 3...10)
                }

                Section {
                    Text("Total shots: \(numberOfEnds * arrowsPerEnd)")
                        .foregroundStyle(.secondary)
                    Text("Max possible score: \(numberOfEnds * arrowsPerEnd * targetType.maxScore)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { startSession() }
                }
            }
        }
    }

    private func startSession() {
        let session = ShootingSession(
            name: sessionName.isEmpty ? "\(sessionMode.rawValue) Session" : sessionName,
            targetType: targetType,
            distance: distance,
            numberOfEnds: numberOfEnds,
            arrowsPerEnd: arrowsPerEnd
        )
        modelContext.insert(session)
        // Sync sessions to widgets
        WidgetDataSyncService.shared.syncRecentSessions(context: modelContext)
        dismiss()
    }
}

// MARK: - Session Detail View

struct ShootingSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: ShootingSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score summary
                    VStack(spacing: 8) {
                        Text("\(session.totalScore)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(AppColors.primary)

                        Text("out of \(session.maxPossibleScore)")
                            .foregroundStyle(.secondary)

                        Text(String(format: "%.1f%%", session.scorePercentage))
                            .font(.title3)
                    }
                    .padding()

                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        MiniStatCard(title: "X's", value: "\(session.xCount)")
                        MiniStatCard(title: "10's", value: "\(session.tensCount)")
                        MiniStatCard(title: "Avg/Arrow", value: String(format: "%.1f", session.averageScorePerArrow))
                    }
                    .padding(.horizontal)

                    // Ends breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ends")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(session.sortedEnds) { end in
                            EndRow(end: end)
                        }
                    }

                    // Session info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Info")
                            .font(.headline)

                        HStack {
                            Text("Target")
                            Spacer()
                            Text(session.targetType.rawValue)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Distance")
                            Spacer()
                            Text(session.formattedDistance)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(session.formattedDuration)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Notes section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.headline)

                            Spacer()

                            VoiceNoteToolbarButton { note in
                                let service = VoiceNotesService.shared
                                session.notes = service.appendNote(note, to: session.notes)
                            }
                        }

                        if !session.notes.isEmpty {
                            Text(session.notes)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                session.notes = ""
                            } label: {
                                Label("Clear Notes", systemImage: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        } else {
                            Text("Tap the mic to add voice notes")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(session.name.isEmpty ? "Session" : session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - End Row

struct EndRow: View {
    let end: ShootingEnd

    var body: some View {
        HStack {
            Text("End \(end.orderIndex + 1)")
                .font(.subheadline)

            Spacer()

            Text(end.formattedScores)
                .font(.system(.subheadline, design: .monospaced))

            Text("= \(end.totalScore)")
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.primary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
