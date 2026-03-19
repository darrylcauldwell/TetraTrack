//
//  ProgramSetupSheet.swift
//  TetraTrack
//
//  Setup sheet for starting a new training program
//

import SwiftUI

struct ProgramSetupSheet: View {
    let programType: TrainingProgramType
    let onStart: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date = Date()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 32) {
                        // Program icon + title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                Image(systemName: programType.icon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(.green)
                            }
                            Text(programType.displayName)
                                .font(.title2.bold())
                            Text(programType.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Program overview
                        overviewCard

                        // Start date picker
                        startDateCard

                        // First week preview
                        firstWeekPreview

                        // Start button
                        Button {
                            onStart(startDate)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.green.opacity(0.4), radius: 12, y: 4)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                        }

                        Text("Start Program")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheetBackground()
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.green)
                Text("Overview")
                    .font(.headline)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                overviewItem(icon: "calendar", label: "Duration", value: "\(programType.totalWeeks) weeks")
                overviewItem(icon: "repeat", label: "Sessions/Week", value: "3")
                overviewItem(icon: "flag", label: "Target", value: formatDistance(programType.targetDistance))
                overviewItem(icon: "chart.line.uptrend.xyaxis", label: "Progression", value: "Guided")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }

    private func overviewItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.green)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Start Date Card

    private var startDateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.green)
                Text("Start Date")
                    .font(.headline)
            }

            DatePicker("", selection: $startDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()

            if let endDate = Calendar.current.date(byAdding: .weekOfYear, value: programType.totalWeeks, to: startDate) {
                Text("Finishes: \(endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - First Week Preview

    private var firstWeekPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "1.circle.fill")
                    .foregroundStyle(.green)
                Text("Week 1 Preview")
                    .font(.headline)
            }

            let service = TrainingProgramService()
            let _ = service // Suppress unused warning

            // Show a summary based on program type
            switch programType {
            case .c25k:
                weekPreviewRow(session: 1, description: "Run 1 min / Walk 1.5 min x 8")
                weekPreviewRow(session: 2, description: "Run 1 min / Walk 1.5 min x 8")
                weekPreviewRow(session: 3, description: "Run 1 min / Walk 1.5 min x 8")
            default:
                weekPreviewRow(session: 1, description: "Easy run + warm up/cool down")
                weekPreviewRow(session: 2, description: "Medium effort run")
                weekPreviewRow(session: 3, description: "Longer progression run")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 20)
    }

    private func weekPreviewRow(session: Int, description: String) -> some View {
        HStack(spacing: 8) {
            Text("S\(session)")
                .font(.caption.bold())
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }
}
