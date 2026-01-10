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
                .fixedSize()
                .frame(minWidth: 20, alignment: .trailing)

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
    @State private var showingRunningPBEditor = false
    @State private var showingSwimmingPBEditor = false
    @State private var showingShootingPBEditor = false
    @AppStorage("selectedCompetitionLevel") private var competitionLevelRaw: String = CompetitionLevel.junior.rawValue

    /// Whether body measurements come from Apple Health
    private var isHealthKitAuthorized: Bool {
        healthKit.isAuthorized
    }

    private var competitionLevel: Binding<CompetitionLevel> {
        Binding(
            get: { CompetitionLevel(rawValue: competitionLevelRaw) ?? .junior },
            set: { competitionLevelRaw = $0.rawValue }
        )
    }

    // MARK: - Personal Best Computed Properties

    private var runningPBs: RunningPersonalBests { RunningPersonalBests.shared }
    private var swimmingPBs: SwimmingPersonalBests { SwimmingPersonalBests.shared }
    private var shootingPBs: ShootingPersonalBests { ShootingPersonalBests.shared }

    private var runningPBText: String {
        let level = competitionLevel.wrappedValue
        let pb = runningPBs.personalBest(for: level.runDistance)
        guard pb > 0 else { return "No PB set" }
        return runningPBs.formattedPB(for: level.runDistance)
    }

    private var swimmingPBText: String {
        guard swimmingPBs.pb3MinDistance > 0 else { return "No PB set" }
        return swimmingPBs.formattedPBDistance()
    }

    private var shootingPBText: String {
        guard shootingPBs.pbRawScore > 0 else { return "No PB set" }
        return shootingPBs.formattedPB
    }

    var body: some View {
        List {
            // Body Measurements
            Section {
                // Weight
                if isHealthKitAuthorized {
                    // Read-only when from Apple Health
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 24)
                        Text("Weight")
                        Spacer()
                        Text(profile.formattedWeight)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Editable when Apple Health not connected
                    Button(action: { showingWeightPicker = true }) {
                        HStack {
                            Image(systemName: "scalemass")
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 24)
                            Text("Weight")
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
                if isHealthKitAuthorized {
                    // Read-only when from Apple Health
                    HStack {
                        Image(systemName: "ruler")
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 24)
                        Text("Height")
                        Spacer()
                        Text(profile.formattedHeight)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // Editable when Apple Health not connected
                    Button(action: { showingHeightPicker = true }) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 24)
                            Text("Height")
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
                    Image(systemName: "percent")
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 24)
                    Text("BMI")
                    Spacer()
                    Text(profile.formattedBMI)
                        .foregroundStyle(.secondary)
                }
            } header: {
                if isHealthKitAuthorized {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Body Measurements")
                        Spacer()
                        Button("Refresh") {
                            Task {
                                await healthKit.updateProfileFromHealthKit(profile)
                            }
                        }
                        .font(.caption)
                    }
                } else {
                    Text("Body Measurements")
                }
            } footer: {
                if isHealthKitAuthorized {
                    Text("Synced from Apple Health")
                } else {
                    Text("Connect to Apple Health in Settings to sync your weight and height automatically.")
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

            // Personal Bests Section
            Section {
                // Running PB
                Button { showingRunningPBEditor = true } label: {
                    EditablePersonalBestRow(
                        icon: "figure.run",
                        color: AppColors.primary,
                        discipline: "Running (\(competitionLevel.wrappedValue.formattedRunDistance))",
                        pbText: runningPBText
                    )
                }
                .foregroundStyle(.primary)

                // Swimming PB
                Button { showingSwimmingPBEditor = true } label: {
                    EditablePersonalBestRow(
                        icon: "figure.pool.swim",
                        color: .blue,
                        discipline: "Swimming (\(competitionLevel.wrappedValue.formattedSwimDuration))",
                        pbText: swimmingPBText
                    )
                }
                .foregroundStyle(.primary)

                // Shooting PB
                Button { showingShootingPBEditor = true } label: {
                    EditablePersonalBestRow(
                        icon: "target",
                        color: .orange,
                        discipline: "Shooting",
                        pbText: shootingPBText
                    )
                }
                .foregroundStyle(.primary)
            } header: {
                Text("Personal Bests")
            } footer: {
                Text("Tap to edit. Update these after competitions to track your progress.")
            }

            // Calorie Estimator - All Disciplines
            Section {
                // Riding
                DisclosureGroup {
                    CalorieExampleRow(activity: "Walk", met: 2.5, weight: profile.weight, color: AppColors.walk)
                    CalorieExampleRow(activity: "Trot", met: 5.5, weight: profile.weight, color: AppColors.trot)
                    CalorieExampleRow(activity: "Canter", met: 7.0, weight: profile.weight, color: AppColors.canter)
                    CalorieExampleRow(activity: "Gallop", met: 8.5, weight: profile.weight, color: AppColors.gallop)
                } label: {
                    DisciplineCalorieHeader(
                        icon: "figure.equestrian.sports",
                        discipline: "Riding",
                        color: AppColors.primary,
                        avgCalories: Int(5.0 * profile.weight)  // Average MET ~5
                    )
                }

                // Running
                DisclosureGroup {
                    CalorieExampleRow(activity: "Jogging (8 km/h)", met: 8.0, weight: profile.weight, color: AppColors.primary)
                    CalorieExampleRow(activity: "Running (10 km/h)", met: 10.0, weight: profile.weight, color: AppColors.primary.opacity(0.8))
                    CalorieExampleRow(activity: "Fast (12 km/h)", met: 11.5, weight: profile.weight, color: AppColors.primary.opacity(0.6))
                    CalorieExampleRow(activity: "Sprint (15+ km/h)", met: 14.0, weight: profile.weight, color: AppColors.error)
                } label: {
                    DisciplineCalorieHeader(
                        icon: "figure.run",
                        discipline: "Running",
                        color: AppColors.primary,
                        avgCalories: Int(10.0 * profile.weight)  // Average MET ~10
                    )
                }

                // Swimming
                DisclosureGroup {
                    CalorieExampleRow(activity: "Leisurely", met: 6.0, weight: profile.weight, color: .blue.opacity(0.5))
                    CalorieExampleRow(activity: "Moderate", met: 7.0, weight: profile.weight, color: .blue.opacity(0.7))
                    CalorieExampleRow(activity: "Vigorous", met: 10.0, weight: profile.weight, color: .blue)
                    CalorieExampleRow(activity: "Racing", met: 13.0, weight: profile.weight, color: .blue.opacity(0.9))
                } label: {
                    DisciplineCalorieHeader(
                        icon: "figure.pool.swim",
                        discipline: "Swimming",
                        color: .blue,
                        avgCalories: Int(8.0 * profile.weight)  // Average MET ~8
                    )
                }

                // Shooting
                DisclosureGroup {
                    CalorieExampleRow(activity: "Standing/Aiming", met: 2.5, weight: profile.weight, color: .orange.opacity(0.6))
                    CalorieExampleRow(activity: "Competition", met: 3.0, weight: profile.weight, color: .orange)
                } label: {
                    DisciplineCalorieHeader(
                        icon: "target",
                        discipline: "Shooting",
                        color: .orange,
                        avgCalories: Int(2.5 * profile.weight)  // Average MET ~2.5
                    )
                }
            } header: {
                Text("Calorie Estimator")
            } footer: {
                Text("Estimates based on MET (Metabolic Equivalent) research. Actual calories vary with intensity and individual factors.")
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
        .sheet(isPresented: $showingRunningPBEditor) {
            RunningPBEditorView(distance: competitionLevel.wrappedValue.runDistance)
        }
        .sheet(isPresented: $showingSwimmingPBEditor) {
            SwimmingPBEditorView()
        }
        .sheet(isPresented: $showingShootingPBEditor) {
            ShootingPBEditorView()
        }
    }
}

// MARK: - Discipline Calorie Header

struct DisciplineCalorieHeader: View {
    let icon: String
    let discipline: String
    let color: Color
    let avgCalories: Int

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(discipline)
                .font(.subheadline)
            Spacer()
            Text("~\(avgCalories) kcal/hr")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Calorie Example Row

struct CalorieExampleRow: View {
    let activity: String
    let met: Double
    let weight: Double
    let color: Color

    private var caloriesPerHour: Int {
        Int(met * weight)
    }

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(activity)
                .font(.caption)
            Spacer()
            Text("\(caloriesPerHour) kcal/hr")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
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

// MARK: - Personal Best Row

struct PersonalBestRow: View {
    let icon: String
    let color: Color
    let discipline: String
    let pbText: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(discipline)

            Spacer()

            Text(pbText)
                .foregroundStyle(pbText == "No PB set" ? .tertiary : .secondary)
        }
    }
}

// MARK: - Editable Personal Best Row

struct EditablePersonalBestRow: View {
    let icon: String
    let color: Color
    let discipline: String
    let pbText: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(discipline)

            Spacer()

            Text(pbText)
                .foregroundStyle(pbText == "No PB set" ? .tertiary : .secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Running PB Editor

struct RunningPBEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let distance: Double

    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    private var personalBests: RunningPersonalBests { RunningPersonalBests.shared }

    private var distanceLabel: String {
        if distance >= 1000 {
            return String(format: "%.0fk", distance / 1000)
        }
        return String(format: "%.0fm", distance)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Running PB")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(distanceLabel)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primary)

                // Time picker
                HStack(spacing: 0) {
                    // Minutes
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { min in
                            Text("\(min)").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)

                    Text(":")
                        .font(.title)
                        .fontWeight(.bold)

                    // Seconds
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { sec in
                            Text(String(format: "%02d", sec)).tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                }

                Text("Time: \(minutes):\(String(format: "%02d", seconds))")
                    .font(.title2.bold())
                    .monospacedDigit()

                // Calculated pace
                if minutes > 0 || seconds > 0 {
                    let totalSeconds = Double(minutes * 60 + seconds)
                    let pacePerKm = (totalSeconds / distance) * 1000
                    let paceMin = Int(pacePerKm) / 60
                    let paceSec = Int(pacePerKm) % 60

                    Text("Pace: \(paceMin):\(String(format: "%02d", paceSec)) /km")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Running PB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let totalSeconds = TimeInterval(minutes * 60 + seconds)
                        var pbs = personalBests
                        pbs.updatePersonalBest(for: distance, time: totalSeconds)
                        dismiss()
                    }
                    .disabled(minutes == 0 && seconds == 0)
                }
            }
            .onAppear {
                let currentPB = personalBests.personalBest(for: distance)
                if currentPB > 0 {
                    minutes = Int(currentPB) / 60
                    seconds = Int(currentPB) % 60
                }
            }
        }
    }
}

// MARK: - Swimming PB Editor

struct SwimmingPBEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var distanceMeters: Int = 0

    private var personalBests: SwimmingPersonalBests { SwimmingPersonalBests.shared }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Swimming PB")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Timed Test")
                    .font(.title2.bold())
                    .foregroundStyle(.blue)

                // Distance picker
                Picker("Distance", selection: $distanceMeters) {
                    ForEach(Array(stride(from: 0, through: 300, by: 25)), id: \.self) { meters in
                        Text("\(meters)m").tag(meters)
                    }
                }
                .pickerStyle(.wheel)

                Text("\(distanceMeters) meters")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Swimming PB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var pbs = personalBests
                        pbs.updatePersonalBest(distance: Double(distanceMeters), time: 180) // 3 min test
                        dismiss()
                    }
                }
            }
            .onAppear {
                let currentPB = personalBests.pb3MinDistance
                if currentPB > 0 {
                    distanceMeters = Int(currentPB)
                }
            }
        }
    }
}

// MARK: - Shooting PB Editor

struct ShootingPBEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var rawScore: Int = 0

    private var personalBests: ShootingPersonalBests { ShootingPersonalBests.shared }

    private var tetrathlonPoints: Int {
        // Tetrathlon scoring: each point = 24 tetrathlon points, max 2400
        rawScore * 24
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Shooting PB")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Competition Score")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)

                // Score picker (0-100)
                Picker("Score", selection: $rawScore) {
                    ForEach(0...100, id: \.self) { score in
                        Text("\(score)").tag(score)
                    }
                }
                .pickerStyle(.wheel)

                VStack(spacing: 8) {
                    Text("\(rawScore)/100")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)

                    Text("\(tetrathlonPoints) tetrathlon points")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Edit Shooting PB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var pbs = personalBests
                        pbs.updatePersonalBest(rawScore: rawScore)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let currentPB = personalBests.pbRawScore
                if currentPB > 0 {
                    rawScore = currentPB
                }
            }
        }
    }
}

