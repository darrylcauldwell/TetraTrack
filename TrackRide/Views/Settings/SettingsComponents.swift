//
//  SettingsComponents.swift
//  TrackRide
//
//  Settings subviews extracted from SettingsView
//

import SwiftUI
import SwiftData

// MARK: - Offline Map Step

struct OfflineMapStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.primary)
                .frame(width: 16, alignment: .leading)

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Watch Feature Row

struct WatchFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.primary)
                .frame(width: 16)
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - MET Info Row

struct METInfoRow: View {
    let gait: String
    let met: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(gait)
                .font(.caption)
            Spacer()
            Text("MET \(met)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Rider Profile View

struct RiderProfileView: View {
    @Bindable var profile: RiderProfile
    private var healthKit: HealthKitManager { HealthKitManager.shared }
    @State private var showingWeightPicker = false
    @State private var showingHeightPicker = false
    @State private var showingDatePicker = false
    @AppStorage("selectedCompetitionLevel") private var competitionLevelRaw: String = CompetitionLevel.junior.rawValue

    /// Whether body measurements are read-only (synced from Apple Health)
    private var isHealthKitSynced: Bool {
        profile.useHealthKitData && healthKit.isAuthorized
    }

    private var competitionLevel: Binding<CompetitionLevel> {
        Binding(
            get: { CompetitionLevel(rawValue: competitionLevelRaw) ?? .junior },
            set: { competitionLevelRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            // HealthKit Data Status
            if isHealthKitSynced {
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(AppColors.error)
                        Text("Synced from Apple Health")
                            .font(.subheadline)
                        Spacer()
                        Button("Refresh") {
                            Task {
                                await healthKit.updateProfileFromHealthKit(profile)
                            }
                        }
                        .font(.caption)
                    }
                }
            }

            // Body Measurements
            Section {
                // Weight
                if isHealthKitSynced {
                    // Read-only when synced from HealthKit
                    HStack {
                        Label("Weight", systemImage: "scalemass")
                        Spacer()
                        Text(profile.formattedWeight)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Editable when not synced
                    Button(action: { showingWeightPicker = true }) {
                        HStack {
                            Label("Weight", systemImage: "scalemass")
                            Spacer()
                            Text(profile.formattedWeight)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // Height
                if isHealthKitSynced {
                    // Read-only when synced from HealthKit
                    HStack {
                        Label("Height", systemImage: "ruler")
                        Spacer()
                        Text(profile.formattedHeight)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Editable when not synced
                    Button(action: { showingHeightPicker = true }) {
                        HStack {
                            Label("Height", systemImage: "ruler")
                            Spacer()
                            Text(profile.formattedHeight)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // BMI (always calculated/read-only)
                HStack {
                    Label("BMI", systemImage: "percent")
                    Spacer()
                    Text(profile.formattedBMI)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Body Measurements")
            } footer: {
                if isHealthKitSynced {
                    Text("Data synced from Apple Health. To edit manually, disable sync in Settings.")
                }
            }

            // Personal Info
            Section("Personal Information") {
                // Sex
                Picker("Sex", selection: $profile.sex) {
                    ForEach(BiologicalSex.allCases, id: \.self) { sex in
                        Text(sex.rawValue).tag(sex)
                    }
                }

                // Date of Birth
                Button(action: { showingDatePicker = true }) {
                    HStack {
                        Label("Date of Birth", systemImage: "calendar")
                        Spacer()
                        if let dob = profile.dateOfBirth {
                            Text(dob.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not Set")
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                // Age (calculated)
                if let age = profile.age {
                    HStack {
                        Label("Age", systemImage: "person")
                        Spacer()
                        Text("\(age) years")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Tetrathlon Settings
            Section("Tetrathlon") {
                Picker("Competition Class", selection: competitionLevel) {
                    ForEach(CompetitionLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }

                HStack {
                    Label("Run Distance", systemImage: "figure.run")
                    Spacer()
                    Text(competitionLevel.wrappedValue.formattedRunDistance)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Swim Duration", systemImage: "figure.pool.swim")
                    Spacer()
                    Text(competitionLevel.wrappedValue.formattedSwimDuration)
                        .foregroundStyle(.secondary)
                }
            }

            // Calorie Example
            Section("Calorie Estimate Example") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("For a 1-hour ride at your weight:")
                        .font(.subheadline)

                    CalorieExampleRow(gait: "Walking", calories: walkCalories, color: AppColors.walk)
                    CalorieExampleRow(gait: "Trotting", calories: trotCalories, color: AppColors.trot)
                    CalorieExampleRow(gait: "Cantering", calories: canterCalories, color: AppColors.canter)
                    CalorieExampleRow(gait: "Galloping", calories: gallopCalories, color: AppColors.gallop)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Rider Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingWeightPicker) {
            WeightPickerView(weight: $profile.weight)
        }
        .sheet(isPresented: $showingHeightPicker) {
            HeightPickerView(height: $profile.height)
        }
        .sheet(isPresented: $showingDatePicker) {
            DateOfBirthPickerView(dateOfBirth: $profile.dateOfBirth)
        }
    }

    // Calculate example calories for 1 hour at each gait
    private var walkCalories: Int {
        Int(RidingMETValues.calories(met: RidingMETValues.walk, weightKg: profile.weight, durationSeconds: 3600))
    }

    private var trotCalories: Int {
        Int(RidingMETValues.calories(met: RidingMETValues.trot, weightKg: profile.weight, durationSeconds: 3600))
    }

    private var canterCalories: Int {
        Int(RidingMETValues.calories(met: RidingMETValues.canter, weightKg: profile.weight, durationSeconds: 3600))
    }

    private var gallopCalories: Int {
        Int(RidingMETValues.calories(met: RidingMETValues.gallop, weightKg: profile.weight, durationSeconds: 3600))
    }
}

// MARK: - Calorie Example Row

struct CalorieExampleRow: View {
    let gait: String
    let calories: Int
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(gait)
                .font(.subheadline)
            Spacer()
            Text("\(calories) kcal")
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Weight Picker

struct WeightPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var weight: Double
    @State private var selectedWeight: Double = 70.0

    var body: some View {
        NavigationStack {
            VStack {
                Text("\(String(format: "%.1f", selectedWeight)) kg")
                    .font(.system(size: 48, weight: .bold))
                    .padding()

                Picker("Weight", selection: $selectedWeight) {
                    ForEach(Array(stride(from: 30.0, through: 150.0, by: 0.5)), id: \.self) { value in
                        Text("\(String(format: "%.1f", value)) kg").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        weight = selectedWeight
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedWeight = weight
            }
        }
    }
}

// MARK: - Height Picker

struct HeightPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var height: Double
    @State private var selectedHeight: Double = 170.0

    var body: some View {
        NavigationStack {
            VStack {
                Text("\(Int(selectedHeight)) cm")
                    .font(.system(size: 48, weight: .bold))
                    .padding()

                Picker("Height", selection: $selectedHeight) {
                    ForEach(Array(stride(from: 100.0, through: 220.0, by: 1.0)), id: \.self) { value in
                        Text("\(Int(value)) cm").tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("Height")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        height = selectedHeight
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedHeight = height
            }
        }
    }
}

// MARK: - Date of Birth Picker

struct DateOfBirthPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dateOfBirth: Date?
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Date of Birth",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("Date of Birth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dateOfBirth = selectedDate
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let dob = dateOfBirth {
                    selectedDate = dob
                }
            }
        }
    }
}

