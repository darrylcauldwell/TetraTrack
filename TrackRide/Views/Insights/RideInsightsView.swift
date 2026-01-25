//
//  RideInsightsView.swift
//  TrackRide
//
//  Comprehensive physics-based biomechanical insights view
//  Displays time-annotated metrics from IMU sensors and horse profile
//  Designed to feel like feedback from a professional riding coach
//

import SwiftUI
import Charts

struct RideInsightsView: View {
    let ride: Ride

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Shared coordinator for cross-chart interaction
    @State private var coordinator = InsightsCoordinator()

    @State private var expandedSection: InsightSection?
    @State private var showingInsightPopup = false
    @State private var currentInsight: String = ""

    // Convenience accessor for coordinator's selected timestamp
    private var selectedTimestamp: Date? {
        get { coordinator.selectedTimestamp }
    }

    // MARK: - Overall Scores

    private var rhythmScore: Double { ride.overallRhythm }
    private var stabilityScore: Double { ride.averageRiderStability }
    private var straightnessScore: Double { ride.averageStraightness }
    private var leadQualityScore: Double { computeLeadQuality() }
    private var engagementScore: Double { ride.averageEngagement }

    var body: some View {
        ScrollView {
            if horizontalSizeClass == .regular {
                iPadContent
            } else {
                iPhoneContent
            }
        }
        .navigationTitle("Ride Insights")
        .navigationBarTitleDisplayMode(.inline)
        .glassNavigation()
        .sheet(isPresented: $showingInsightPopup) {
            InsightPopupView(insight: currentInsight)
                .presentationDetents([.medium])
        }
        .presentationBackground(Color.black)
    }

    // MARK: - iPad Layout (Multi-Column Grid)

    private var iPadContent: some View {
        VStack(spacing: Spacing.xl) {
            // 1. Header Summary Row (full width)
            headerSummaryRow

            // Expanded detail view (shown when a score card is tapped)
            if let section = expandedSection {
                ExpandedMetricDetailView(
                    metricType: section,
                    segments: ride.sortedGaitSegments,
                    rideDuration: ride.totalDuration,
                    rideStart: ride.startDate,
                    selectedTimestamp: $coordinator.selectedTimestamp
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // 2. Gait Timeline Strip (full width - anchor)
            gaitTimelineSection

            // Zoom controls and comparison toggle
            interactiveControlsRow

            // Comparison stats (when comparison mode active)
            if coordinator.comparisonMode {
                comparisonStatsSection
            }

            // Two-column grid for analysis sections
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Spacing.lg),
                GridItem(.flexible(), spacing: Spacing.lg)
            ], spacing: Spacing.lg) {
                // 3. Rein and Turn Balance Graphs
                balanceGraphsSection

                // 4. Straightness and Rider Symmetry
                symmetrySection

                // 5. Rhythm and Stability View
                rhythmStabilitySection

                // 7. Lead Consistency & Canter Quality
                leadConsistencySection

                // 8. Impulsion / Engagement
                impulsionEngagementSection

                // 10. Mental State / Tension Proxy
                mentalStateSection
            }

            // Full-width timeline sections
            // 6. Transition Quality Strip
            transitionQualitySection

            // 9. Training Load Timeline
            trainingLoadSection

            // Coach Insights Summary (full width)
            coachInsightsSection
        }
        .padding(Spacing.xl)
    }

    // MARK: - iPhone Layout (Vertical)

    private var iPhoneContent: some View {
        VStack(spacing: 20) {
            // 1. Header Summary Row
            headerSummaryRow

            // Expanded detail view (shown when a score card is tapped)
            if let section = expandedSection {
                ExpandedMetricDetailView(
                    metricType: section,
                    segments: ride.sortedGaitSegments,
                    rideDuration: ride.totalDuration,
                    rideStart: ride.startDate,
                    selectedTimestamp: $coordinator.selectedTimestamp
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // 2. Gait Timeline Strip
            gaitTimelineSection

            // Zoom controls and comparison toggle
            interactiveControlsRow

            // Comparison stats (when comparison mode active)
            if coordinator.comparisonMode {
                comparisonStatsSection
            }

            // 3. Rein and Turn Balance Graphs
            balanceGraphsSection

            // 4. Straightness and Rider Symmetry
            symmetrySection

            // 5. Rhythm and Stability View
            rhythmStabilitySection

            // 6. Transition Quality Strip
            transitionQualitySection

            // 7. Lead Consistency & Canter Quality
            leadConsistencySection

            // 8. Impulsion / Engagement
            impulsionEngagementSection

            // 9. Training Load Timeline
            trainingLoadSection

            // 10. Mental State / Tension Proxy
            mentalStateSection

            // Coach Insights Summary
            coachInsightsSection
        }
        .padding()
    }

    // MARK: - 1. Header Summary Row

    private var headerSummaryRow: some View {
        VStack(spacing: 16) {
            GlassSectionHeader("Overall Performance", icon: "chart.bar.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    InsightScoreCard(
                        title: "Rhythm",
                        score: rhythmScore,
                        icon: "metronome",
                        isExpanded: expandedSection == .rhythm
                    ) {
                        toggleSection(.rhythm)
                    }

                    InsightScoreCard(
                        title: "Stability",
                        score: stabilityScore,
                        icon: "figure.equestrian.sports",
                        isExpanded: expandedSection == .stability
                    ) {
                        toggleSection(.stability)
                    }

                    InsightScoreCard(
                        title: "Straightness",
                        score: straightnessScore,
                        icon: "arrow.up",
                        isExpanded: expandedSection == .straightness
                    ) {
                        toggleSection(.straightness)
                    }

                    InsightScoreCard(
                        title: "Lead Quality",
                        score: leadQualityScore,
                        icon: "arrow.left.arrow.right",
                        isExpanded: expandedSection == .leadQuality
                    ) {
                        toggleSection(.leadQuality)
                    }

                    InsightScoreCard(
                        title: "Engagement",
                        score: engagementScore,
                        icon: "bolt.fill",
                        isExpanded: expandedSection == .engagement
                    ) {
                        toggleSection(.engagement)
                    }
                }
                .padding(.horizontal)
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 2. Gait Timeline Strip

    private var gaitTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader("Gait Timeline", icon: "timeline.selection")

            ZStack {
                GaitTimelineStrip(
                    segments: ride.sortedGaitSegments,
                    rideDuration: ride.totalDuration,
                    selectedTimestamp: $coordinator.selectedTimestamp,
                    onSegmentTap: { segment in
                        coordinator.selectTimestamp(segment.startTime)
                        showSegmentDetails(segment)
                    }
                )
                .frame(height: 60)

                // Cross-chart timestamp highlight
                if let timestamp = coordinator.selectedTimestamp {
                    TimestampHighlightLine(
                        timestamp: timestamp,
                        rideStart: ride.startDate,
                        rideDuration: ride.totalDuration,
                        height: 60
                    )
                }

                // Comparison range overlay
                if coordinator.comparisonMode {
                    ComparisonRangeSelector(
                        coordinator: coordinator,
                        rideStart: ride.startDate,
                        rideDuration: ride.totalDuration
                    )
                }
            }

            // Time axis labels
            TimeAxisLabels(duration: ride.totalDuration)

            // Legend
            InsightsGaitLegend()
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 3. Rein and Turn Balance Graphs

    private var balanceGraphsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Balance Analysis", icon: "scale.3d")

            VStack(spacing: 20) {
                // Rein Balance Graph
                BalanceLineChart(
                    title: "Rein Balance",
                    segments: ride.sortedReinSegments.map { segment in
                        BalanceDataPoint(
                            timestamp: segment.startTime,
                            value: segment.reinDirection == .left ? 0.3 : (segment.reinDirection == .right ? -0.3 : 0),
                            duration: segment.duration
                        )
                    },
                    positiveLabel: "Left Heavy",
                    negativeLabel: "Right Heavy",
                    rideDuration: ride.totalDuration
                )
                .frame(height: 120)

                // Turn Balance Graph
                BalanceLineChart(
                    title: "Turn Balance",
                    segments: computeTurnBalanceData(),
                    positiveLabel: "Falling In",
                    negativeLabel: "Drifting Out",
                    rideDuration: ride.totalDuration
                )
                .frame(height: 120)
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 4. Straightness and Rider Symmetry

    private var symmetrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Symmetry Analysis", icon: "arrow.left.and.right")

            // Summary stats
            HStack(spacing: 20) {
                SummaryStatBadge(
                    label: "Straight",
                    value: "\(Int(ride.averageStraightness))%",
                    color: scoreColor(ride.averageStraightness)
                )
                SummaryStatBadge(
                    label: "Balanced",
                    value: "\(Int(ride.overallSymmetry))%",
                    color: scoreColor(ride.overallSymmetry)
                )
                SummaryStatBadge(
                    label: "Crooked",
                    value: "\(Int(max(0, 100 - ride.averageStraightness)))%",
                    color: .secondary
                )
            }

            // Symmetry line chart
            SymmetryLineChart(
                symmetryScore: ride.overallSymmetry,
                straightnessScore: ride.averageStraightness,
                segments: ride.sortedGaitSegments
            )
            .frame(height: 100)
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 5. Rhythm and Stability View

    private var rhythmStabilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassSectionHeader("Rhythm & Stability", icon: "waveform.path.ecg")

            HStack(spacing: 20) {
                // Rhythm score gauge
                CircularGaugeView(
                    value: rhythmScore,
                    maxValue: 100,
                    title: "Rhythm",
                    subtitle: "Stride regularity",
                    color: scoreColor(rhythmScore)
                )

                // Stability score gauge
                CircularGaugeView(
                    value: stabilityScore,
                    maxValue: 100,
                    title: "Stability",
                    subtitle: "Rider position",
                    color: scoreColor(stabilityScore)
                )
            }
            .frame(maxWidth: .infinity)

            // Rhythm heatmap
            RhythmHeatmap(
                segments: ride.sortedGaitSegments,
                rideDuration: ride.totalDuration
            )
            .frame(height: 40)

            Text("Color intensity shows deviation from ideal rhythm (green = regular, red = irregular)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 6. Transition Quality Strip

    private var transitionQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GlassSectionHeader("Transitions", icon: "arrow.triangle.swap")
                Spacer()
                Text("\(ride.transitionCount) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if ride.transitionCount > 0 {
                TransitionQualityStrip(
                    transitions: ride.sortedGaitTransitions,
                    rideDuration: ride.totalDuration,
                    onTransitionTap: { transition in
                        showTransitionDetails(transition)
                    }
                )
                .frame(height: 50)

                // Transition summary
                HStack(spacing: 16) {
                    TransitionStatBadge(
                        label: "Upward",
                        count: ride.upwardTransitionCount,
                        icon: "arrow.up.circle.fill",
                        color: AppColors.success
                    )
                    TransitionStatBadge(
                        label: "Downward",
                        count: ride.downwardTransitionCount,
                        icon: "arrow.down.circle.fill",
                        color: AppColors.warning
                    )
                    TransitionStatBadge(
                        label: "Quality",
                        count: Int(ride.averageTransitionQuality * 100),
                        icon: "star.fill",
                        color: scoreColor(ride.averageTransitionQuality * 100),
                        isPercentage: true
                    )
                }
            } else {
                Text("No transitions recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 7. Lead Consistency & Canter Quality

    private var leadConsistencySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GlassSectionHeader("Lead Analysis", icon: "arrow.left.arrow.right.circle")
                Spacer()
                // Show correct lead percentage if there's cross-canter
                if ride.crossCanterDuration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("\(Int(ride.correctLeadPercentage))% correct")
                            .font(.caption)
                    }
                    .foregroundStyle(ride.correctLeadPercentage > 80 ? AppColors.success : AppColors.warning)
                }
            }

            if ride.totalLeadDuration > 0 {
                // Use enhanced chart with cross-canter detection
                EnhancedLeadDistributionChart(ride: ride)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.equestrian.sports")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No canter/gallop recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 8. Impulsion / Engagement

    private var impulsionEngagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GlassSectionHeader("Impulsion & Engagement", icon: "bolt.fill")
                Spacer()
                ScoreBadge(score: engagementScore, label: "Overall")
            }

            // Engagement area chart
            EngagementAreaChart(
                impulsion: ride.averageImpulsion,
                engagement: ride.averageEngagement,
                segments: ride.sortedGaitSegments
            )
            .frame(height: 120)

            // Engagement bands legend
            HStack(spacing: 16) {
                EngagementBandLabel(label: "Low", color: AppColors.error.opacity(0.3))
                EngagementBandLabel(label: "Medium", color: AppColors.warning.opacity(0.3))
                EngagementBandLabel(label: "High", color: AppColors.success.opacity(0.3))
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 9. Training Load Timeline

    private var trainingLoadSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GlassSectionHeader("Training Load", icon: "flame.fill")
                Spacer()
                Text(String(format: "%.1f", ride.totalTrainingLoad))
                    .font(.headline)
                    .foregroundStyle(AppColors.cardOrange)

                // Heart rate indicator if available
                if ride.hasHeartRateData {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                }
            }

            // Cumulative load chart with heart rate overlay
            TrainingLoadChart(
                totalLoad: ride.totalTrainingLoad,
                segments: ride.sortedGaitSegments,
                rideDuration: ride.totalDuration,
                heartRateSamples: ride.heartRateSamples,
                rideStartDate: ride.startDate,
                showHeartRate: ride.hasHeartRateData
            )
            .frame(height: 100)

            HStack {
                Text("Training load = RMS(vertical) × stride frequency × time")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                if ride.hasHeartRateData {
                    Text("HR: \(ride.formattedAverageHeartRate)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.error)
                }
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - 10. Mental State / Tension Proxy

    private var mentalStateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                GlassSectionHeader("Mental State", icon: "brain.head.profile")
                Spacer()
                CalmnessBadge(score: computeCalmnessScore())
            }

            // Tension heatmap
            TensionHeatmap(
                segments: ride.sortedGaitSegments,
                rideDuration: ride.totalDuration
            )
            .frame(height: 40)

            HStack(spacing: 16) {
                TensionLegendItem(label: "Calm", color: AppColors.success)
                TensionLegendItem(label: "Alert", color: AppColors.warning)
                TensionLegendItem(label: "Tense", color: AppColors.error)
            }

            Text("Based on spectral entropy and yaw noise patterns")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - Coach Insights Summary

    private var coachInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader("Coach Insights", icon: "person.fill.questionmark")

            ForEach(generateCoachInsights(), id: \.self) { insight in
                InsightRow(insight: insight)
            }
        }
        .glassCard(material: .thin, cornerRadius: 16, padding: 16)
    }

    // MARK: - Interactive Controls Row

    private var interactiveControlsRow: some View {
        HStack {
            ZoomControlBar(coordinator: coordinator)
            Spacer()
            ComparisonModeToggle(
                coordinator: coordinator,
                rideStart: ride.startDate,
                rideEnd: ride.endDate ?? ride.startDate.addingTimeInterval(ride.totalDuration)
            )
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Comparison Stats Section

    @ViewBuilder
    private var comparisonStatsSection: some View {
        if let statsA = coordinator.statsForRangeA(segments: ride.sortedGaitSegments),
           let statsB = coordinator.statsForRangeB(segments: ride.sortedGaitSegments) {
            ComparisonStatsView(statsA: statsA, statsB: statsB)
        }
    }

    // MARK: - Helper Methods

    private func toggleSection(_ section: InsightSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSection == section {
                expandedSection = nil
            } else {
                expandedSection = section
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    private func computeLeadQuality() -> Double {
        guard ride.totalLeadDuration > 0 else { return 0 }
        // Lead quality based on balance (50/50 = optimal) and consistency
        let balance = abs(ride.leadBalance - 0.5) * 2 // 0 = perfect, 1 = all one lead
        let balanceScore = (1 - balance) * 100
        return min(100, max(0, balanceScore))
    }

    private func computeCalmnessScore() -> Double {
        // Inverse of spectral entropy average across segments
        let segments = ride.sortedGaitSegments
        guard !segments.isEmpty else { return 50 }
        let avgEntropy = segments.reduce(0) { $0 + $1.spectralEntropy } / Double(segments.count)
        // Lower entropy = calmer
        return max(0, min(100, (1 - avgEntropy) * 100))
    }

    private func computeTurnBalanceData() -> [BalanceDataPoint] {
        // Generate turn balance data from turn stats
        var data: [BalanceDataPoint] = []
        let balance = Double(ride.turnBalancePercent - 50) / 50.0 // -1 to 1
        data.append(BalanceDataPoint(
            timestamp: ride.startDate,
            value: balance * 0.5,
            duration: ride.totalDuration
        ))
        return data
    }

    private func showSegmentDetails(_ segment: GaitSegment) {
        currentInsight = """
        Gait: \(segment.gait.rawValue)
        Duration: \(segment.duration.formattedDuration)
        Stride Frequency: \(String(format: "%.1f Hz", segment.strideFrequency))
        Stride Length: \(String(format: "%.2f m", segment.strideLength))
        Speed: \(segment.averageSpeed.formattedSpeed)
        """
        showingInsightPopup = true
    }

    private func showTransitionDetails(_ transition: GaitTransition) {
        currentInsight = """
        Transition: \(transition.fromGait.rawValue) → \(transition.toGait.rawValue)
        Quality: \(String(format: "%.0f%%", transition.transitionQuality * 100))
        Time: \(Formatters.dateTime(transition.timestamp))
        """
        showingInsightPopup = true
    }

    private func generateCoachInsights() -> [String] {
        var insights: [String] = []

        // Rein balance insight
        let reinBalance = ride.reinBalancePercent
        if reinBalance < 40 {
            insights.append("Horse leaned more on right rein (\(100 - reinBalance)% right)")
        } else if reinBalance > 60 {
            insights.append("Horse leaned more on left rein (\(reinBalance)% left)")
        }

        // Lead consistency
        if ride.totalLeadDuration > 0 {
            let leadPercent = Int(ride.leadBalance * 100)
            if leadPercent > 65 {
                insights.append("Canter predominantly on left lead (\(leadPercent)%)")
            } else if leadPercent < 35 {
                insights.append("Canter predominantly on right lead (\(100 - leadPercent)%)")
            } else {
                insights.append("Good lead balance maintained (\(leadPercent)% left / \(100 - leadPercent)% right)")
            }
        }

        // Rhythm insight
        if rhythmScore < 60 {
            insights.append("Rhythm dropped during transitions - practice half-halts")
        } else if rhythmScore >= 80 {
            insights.append("Excellent rhythm consistency throughout the session")
        }

        // Engagement insight
        if engagementScore < 50 {
            insights.append("Consider more forward energy from hindquarters")
        } else if engagementScore >= 75 {
            insights.append("Good engagement with active hindquarters")
        }

        // Turn balance insight
        let turnBalance = ride.turnBalancePercent
        if abs(turnBalance - 50) > 20 {
            let direction = turnBalance > 50 ? "left" : "right"
            insights.append("More turns to the \(direction) - ensure equal work both directions")
        }

        // Add default if no insights
        if insights.isEmpty {
            insights.append("Session completed with balanced work distribution")
        }

        return insights
    }
}

// MARK: - Insight Section Enum

enum InsightSection: String, CaseIterable {
    case rhythm
    case stability
    case straightness
    case leadQuality
    case engagement
}

// MARK: - Balance Data Point

struct BalanceDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double // -1 to 1
    let duration: TimeInterval
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RideInsightsView(ride: {
            let ride = Ride()
            ride.totalDuration = 3600
            ride.totalDistance = 5000
            ride.leftReinDuration = 900
            ride.rightReinDuration = 850
            ride.leftReinSymmetry = 85
            ride.rightReinSymmetry = 82
            ride.leftReinRhythm = 78
            ride.rightReinRhythm = 81
            ride.leftLeadDuration = 300
            ride.rightLeadDuration = 280
            ride.leftTurns = 12
            ride.rightTurns = 14
            ride.averageStrideLength = 2.5
            ride.averageStrideFrequency = 2.2
            ride.averageImpulsion = 65
            ride.averageEngagement = 70
            ride.averageStraightness = 75
            ride.averageRiderStability = 80
            ride.totalTrainingLoad = 125.5
            return ride
        }())
    }
}
