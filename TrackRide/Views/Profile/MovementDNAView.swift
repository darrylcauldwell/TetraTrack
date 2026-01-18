//
//  MovementDNAView.swift
//  TrackRide
//
//  Movement DNA radar chart showing six universal skill domains
//

import SwiftUI
import SwiftData

struct MovementDNAView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AthleteProfile]
    @Query(sort: \SkillDomainScore.timestamp, order: .reverse)
    private var recentScores: [SkillDomainScore]

    private var profile: AthleteProfile? {
        profiles.first
    }

    @State private var selectedTrendDomain: SkillDomain = .stability
    @State private var showDrillImpact = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Radar Chart
                radarChartSection

                // Domain Trend Charts (NEW)
                domainTrendSection

                // Domain Details
                domainDetailsSection

                // Recent Activity
                recentActivitySection
            }
            .padding()
        }
        .navigationTitle("Movement DNA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDrillImpact = true
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
            }
        }
        .sheet(isPresented: $showDrillImpact) {
            NavigationStack {
                DrillImpactChartView()
            }
        }
        .onAppear {
            ensureProfileExists()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "dna")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Your Movement DNA")
                .font(.title2)
                .fontWeight(.bold)

            Text("Six universal skill domains across all disciplines")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let profile = profile {
                HStack(spacing: 16) {
                    VStack {
                        Text("\(Int(profile.overallScore))")
                            .font(.title.bold())
                            .foregroundStyle(.primary)
                        Text("Overall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let strongest = profile.strongestDomain {
                        VStack {
                            Image(systemName: strongest.icon)
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("Strongest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let weakest = profile.weakestDomain {
                        VStack {
                            Image(systemName: weakest.icon)
                                .font(.title2)
                                .foregroundStyle(.orange)
                            Text("Focus Area")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
    }

    // MARK: - Radar Chart Section

    private var radarChartSection: some View {
        VStack(spacing: 16) {
            Text("Skill Profile")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            SkillRadarChart(profile: profile)
                .frame(height: 280)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Domain Trend Section

    private var domainTrendSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Progress Over Time")
                    .font(.headline)
                Spacer()

                // Domain selector
                Menu {
                    ForEach(SkillDomain.allCases) { domain in
                        Button {
                            selectedTrendDomain = domain
                        } label: {
                            Label(domain.displayName, systemImage: domain.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedTrendDomain.icon)
                        Text(selectedTrendDomain.displayName)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            // Trend line chart
            DomainTrendChart(
                domain: selectedTrendDomain,
                scores: trendScores(for: selectedTrendDomain)
            )
            .frame(height: 160)

            // Trend summary with concrete delta
            if let trendData = trendSummary(for: selectedTrendDomain) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trendData.direction)
                            .font(.caption)
                            .foregroundStyle(trendData.isImproving ? .green : (trendData.isDeclining ? .red : .secondary))
                        Text(trendData.deltaText)
                            .font(.headline)
                            .foregroundStyle(trendData.isImproving ? .green : (trendData.isDeclining ? .red : .primary))
                    }

                    Divider()
                        .frame(height: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(trendData.current))")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("30d Avg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(trendData.average))")
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(trendData.best))")
                            .font(.headline)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trendScores(for domain: SkillDomain) -> [(date: Date, score: Double)] {
        recentScores
            .filter { $0.domain == domain }
            .sorted { $0.timestamp < $1.timestamp }
            .map { (date: $0.timestamp, score: $0.score) }
    }

    private struct TrendSummary {
        let direction: String
        let deltaText: String
        let isImproving: Bool
        let isDeclining: Bool
        let current: Double
        let average: Double
        let best: Double
    }

    private func trendSummary(for domain: SkillDomain) -> TrendSummary? {
        let scores = recentScores.filter { $0.domain == domain }
        guard !scores.isEmpty else { return nil }

        let sortedByDate = scores.sorted { $0.timestamp < $1.timestamp }
        let current = sortedByDate.last?.score ?? 0
        let average = scores.map { $0.score }.reduce(0, +) / Double(scores.count)
        let best = scores.map { $0.score }.max() ?? 0

        // Calculate week-over-week change
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let recentScores = sortedByDate.filter { $0.timestamp > oneWeekAgo }
        let olderScores = sortedByDate.filter { $0.timestamp <= oneWeekAgo }

        let recentAvg = recentScores.isEmpty ? current : recentScores.map { $0.score }.reduce(0, +) / Double(recentScores.count)
        let olderAvg = olderScores.isEmpty ? recentAvg : olderScores.map { $0.score }.reduce(0, +) / Double(olderScores.count)

        let delta = recentAvg - olderAvg
        let percentChange = olderAvg > 0 ? (delta / olderAvg) * 100 : 0

        let isImproving = delta > 2
        let isDeclining = delta < -2

        let direction: String
        let deltaText: String

        if isImproving {
            direction = "Improving"
            deltaText = "+\(Int(delta)) pts (\(String(format: "+%.0f%%", percentChange)))"
        } else if isDeclining {
            direction = "Declining"
            deltaText = "\(Int(delta)) pts (\(String(format: "%.0f%%", percentChange)))"
        } else {
            direction = "Stable"
            deltaText = "No significant change"
        }

        return TrendSummary(
            direction: direction,
            deltaText: deltaText,
            isImproving: isImproving,
            isDeclining: isDeclining,
            current: current,
            average: average,
            best: best
        )
    }

    // MARK: - Domain Details Section

    private var domainDetailsSection: some View {
        VStack(spacing: 12) {
            Text("Domain Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(SkillDomain.allCases) { domain in
                DomainDetailRow(
                    domain: domain,
                    average: profile?.score(for: domain) ?? 0,
                    trend: profile?.trend(for: domain) ?? 0,
                    best: profile?.bestScore(for: domain) ?? 0
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(spacing: 12) {
            Text("Recent Scores")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if recentScores.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Complete sessions to build your profile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
            } else {
                ForEach(recentScores.prefix(10)) { score in
                    RecentScoreRow(score: score)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func ensureProfileExists() {
        if profiles.isEmpty {
            let newProfile = AthleteProfile()
            modelContext.insert(newProfile)
            try? modelContext.save()
        } else if let existingProfile = profiles.first {
            // Update profile with latest scores
            let skillService = SkillDomainService()
            skillService.updateProfile(existingProfile, context: modelContext)
            try? modelContext.save()
        }
    }
}

// MARK: - Skill Radar Chart

struct SkillRadarChart: View {
    let profile: AthleteProfile?

    private let domains = SkillDomain.allCases
    private let maxValue: Double = 100

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 40

            ZStack {
                // Background rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                    RadarPolygon(sides: domains.count, scale: scale)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                }

                // Axis lines
                ForEach(0..<domains.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: domains.count)
                    let endPoint = pointOnCircle(center: center, radius: radius, angle: angle)

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                // Data polygon
                if let profile = profile {
                    RadarDataPolygon(
                        values: domains.map { profile.score(for: $0) },
                        maxValue: maxValue
                    )
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.4), .blue.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                    RadarDataPolygon(
                        values: domains.map { profile.score(for: $0) },
                        maxValue: maxValue
                    )
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                }

                // Domain labels
                ForEach(0..<domains.count, id: \.self) { index in
                    let domain = domains[index]
                    let angle = angleForIndex(index, total: domains.count)
                    let labelPoint = pointOnCircle(center: center, radius: radius + 30, angle: angle)

                    VStack(spacing: 2) {
                        Image(systemName: domain.icon)
                            .font(.caption)
                            .foregroundStyle(domain.colorValue)
                        Text(domain.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .position(labelPoint)
                }

                // Data points
                if let profile = profile {
                    ForEach(0..<domains.count, id: \.self) { index in
                        let domain = domains[index]
                        let value = profile.score(for: domain)
                        let normalizedValue = value / maxValue
                        let angle = angleForIndex(index, total: domains.count)
                        let point = pointOnCircle(center: center, radius: radius * normalizedValue, angle: angle)

                        Circle()
                            .fill(domain.colorValue)
                            .frame(width: 8, height: 8)
                            .position(point)
                    }
                }
            }
        }
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        let angleStep = 2 * .pi / Double(total)
        return angleStep * Double(index) - .pi / 2  // Start from top
    }

    private func pointOnCircle(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

// MARK: - Radar Polygon Shape

struct RadarPolygon: Shape {
    let sides: Int
    let scale: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2 * scale

        var path = Path()

        for i in 0..<sides {
            let angle = angleForIndex(i)
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func angleForIndex(_ index: Int) -> Double {
        let angleStep = 2 * .pi / Double(sides)
        return angleStep * Double(index) - .pi / 2
    }
}

// MARK: - Radar Data Polygon Shape

struct RadarDataPolygon: Shape {
    let values: [Double]
    let maxValue: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let maxRadius = min(rect.width, rect.height) / 2

        var path = Path()

        for i in 0..<values.count {
            let angle = angleForIndex(i)
            let normalizedValue = min(values[i] / maxValue, 1.0)
            let radius = maxRadius * normalizedValue
            let point = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func angleForIndex(_ index: Int) -> Double {
        let angleStep = 2 * .pi / Double(values.count)
        return angleStep * Double(index) - .pi / 2
    }
}

// MARK: - Domain Detail Row

struct DomainDetailRow: View {
    let domain: SkillDomain
    let average: Double
    let trend: Int
    let best: Double

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: domain.icon)
                .font(.title3)
                .foregroundStyle(domain.colorValue)
                .frame(width: 36, height: 36)
                .background(domain.colorValue.opacity(0.15))
                .clipShape(Circle())

            // Name and description
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(domain.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    // Trend indicator
                    if trend != 0 {
                        Image(systemName: trend > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(trend > 0 ? .green : .red)
                    }

                    Text("\(Int(average))")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(domain.colorValue)
                            .frame(width: geometry.size.width * (average / 100), height: 6)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(domain.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    if best > 0 {
                        Text("Best: \(Int(best))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Recent Score Row

struct RecentScoreRow: View {
    let score: SkillDomainScore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: score.domain.icon)
                .font(.caption)
                .foregroundStyle(score.domain.colorValue)
                .frame(width: 24, height: 24)
                .background(score.domain.colorValue.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(score.domain.displayName)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text("via \(score.discipline.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(score.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(Int(score.score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(scoreColor)
        }
        .padding(.vertical, 4)
    }

    private var scoreColor: Color {
        switch score.score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
}

// MARK: - Domain Trend Chart

struct DomainTrendChart: View {
    let domain: SkillDomain
    let scores: [(date: Date, score: Double)]

    var body: some View {
        GeometryReader { geometry in
            if scores.count < 2 {
                // Not enough data
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Complete more sessions to see trends")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let chartWidth = geometry.size.width - 40
                let chartHeight = geometry.size.height - 30

                let minScore = max(0, (scores.map { $0.score }.min() ?? 0) - 10)
                let maxScore = min(100, (scores.map { $0.score }.max() ?? 100) + 10)
                let scoreRange = max(maxScore - minScore, 20)

                let minDate = scores.map { $0.date }.min() ?? Date()
                let maxDate = scores.map { $0.date }.max() ?? Date()
                let dateRange = maxDate.timeIntervalSince(minDate)

                ZStack(alignment: .topLeading) {
                    // Y-axis labels
                    VStack(alignment: .trailing) {
                        Text("\(Int(maxScore))")
                        Spacer()
                        Text("\(Int((maxScore + minScore) / 2))")
                        Spacer()
                        Text("\(Int(minScore))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, height: chartHeight)

                    // Chart area
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack(alignment: .bottomLeading) {
                            // Grid lines
                            Path { path in
                                for i in 0...4 {
                                    let y = chartHeight * CGFloat(i) / 4
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: chartWidth, y: y))
                                }
                            }
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                            // Trend line
                            Path { path in
                                for (index, point) in scores.enumerated() {
                                    let x = dateRange > 0
                                        ? chartWidth * CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
                                        : chartWidth * CGFloat(index) / CGFloat(scores.count - 1)
                                    let y = chartHeight - chartHeight * CGFloat((point.score - minScore) / scoreRange)

                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(
                                domain.colorValue,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )

                            // Area fill
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: chartHeight))

                                for (index, point) in scores.enumerated() {
                                    let x = dateRange > 0
                                        ? chartWidth * CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
                                        : chartWidth * CGFloat(index) / CGFloat(scores.count - 1)
                                    let y = chartHeight - chartHeight * CGFloat((point.score - minScore) / scoreRange)
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }

                                let lastX = dateRange > 0
                                    ? chartWidth * CGFloat((scores.last?.date.timeIntervalSince(minDate) ?? 0) / dateRange)
                                    : chartWidth
                                path.addLine(to: CGPoint(x: lastX, y: chartHeight))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [domain.colorValue.opacity(0.3), domain.colorValue.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            // Data points
                            ForEach(Array(scores.enumerated()), id: \.offset) { index, point in
                                let x = dateRange > 0
                                    ? chartWidth * CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
                                    : chartWidth * CGFloat(index) / CGFloat(scores.count - 1)
                                let y = chartHeight - chartHeight * CGFloat((point.score - minScore) / scoreRange)

                                Circle()
                                    .fill(domain.colorValue)
                                    .frame(width: 6, height: 6)
                                    .position(x: x, y: y)
                            }
                        }
                        .frame(width: chartWidth, height: chartHeight)

                        // X-axis labels
                        HStack {
                            Text(minDate, format: .dateTime.month(.abbreviated).day())
                            Spacer()
                            Text(maxDate, format: .dateTime.month(.abbreviated).day())
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: chartWidth)
                    }
                    .padding(.leading, 35)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MovementDNAView()
            .modelContainer(for: [AthleteProfile.self, SkillDomainScore.self], inMemory: true)
    }
}
