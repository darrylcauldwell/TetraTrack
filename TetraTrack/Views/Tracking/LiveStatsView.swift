//
//  LiveStatsView.swift
//  TetraTrack
//

import SwiftUI

struct LiveStatsView: View {
    let duration: String
    let distance: String
    let speed: String
    let gait: GaitType

    // Pause state hint
    var isPaused: Bool = false

    // Optional live metrics
    var lead: Lead = .unknown
    var rein: ReinDirection = .straight
    var symmetry: Double = 0.0
    var rhythm: Double = 0.0
    var rideType: RideType = .hack

    // Speed and elevation metrics (kept for compatibility but not displayed)
    var averageSpeed: String = ""
    var elevation: String = ""
    var elevationGain: String = ""

    // Gait breakdown percentages
    var walkPercent: Double = 0
    var trotPercent: Double = 0
    var canterPercent: Double = 0
    var gallopPercent: Double = 0

    // Heart rate metrics
    var heartRate: Int = 0
    var heartRateZone: HeartRateZone = .zone1
    var averageHeartRate: Int = 0
    var maxHeartRate: Int = 0

    // Flatwork-specific metrics
    var leftReinPercent: Double = 0
    var rightReinPercent: Double = 0
    var leftTurnPercent: Double = 0
    var rightTurnPercent: Double = 0
    var leftLeadPercent: Double = 0
    var rightLeadPercent: Double = 0

    // Cross Country specific metrics
    var xcTimeDifference: String = "0s"
    var xcIsAheadOfTime: Bool = true
    var xcOptimumTime: TimeInterval = 0
    var currentSpeedFormatted: String = ""
    var currentGradient: String = "0%"

    private var showXCMetrics: Bool {
        rideType == .crossCountry
    }

    private var hasXCData: Bool {
        xcOptimumTime > 0
    }

    private var hasGaitData: Bool {
        walkPercent > 0 || trotPercent > 0 || canterPercent > 0 || gallopPercent > 0
    }

    private var showLead: Bool {
        gait == .canter || gait == .gallop
    }

    private var showReinMetrics: Bool {
        rideType == .schooling
    }

    private var showHeartRate: Bool {
        heartRate > 0
    }

    var body: some View {
        VStack(spacing: 24) {
            // Duration - most prominent
            VStack(spacing: 4) {
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(duration)
                    .scaledFont(size: 64, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                    .monospacedDigit()
            }

            // Cross Country specific - Optimum Time display
            if showXCMetrics {
                XCOptimumTimeDisplay(
                    timeDifference: xcTimeDifference,
                    isAhead: xcIsAheadOfTime,
                    currentSpeed: currentSpeedFormatted,
                    gradient: currentGradient,
                    hasOptimumTime: hasXCData
                )
            }

            // Distance and Avg Speed - large and side by side (hide for flatwork and XC)
            if !showReinMetrics && !showXCMetrics {
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("Distance")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(distance)
                            .scaledFont(size: 32, weight: .semibold, design: .rounded, relativeTo: .title)
                            .monospacedDigit()
                    }

                    VStack(spacing: 4) {
                        Text("Avg Speed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(averageSpeed.isEmpty ? speed : averageSpeed)
                            .scaledFont(size: 32, weight: .semibold, design: .rounded, relativeTo: .title)
                            .monospacedDigit()
                    }
                }
            }

            // Current Gait indicator (hide when stationary)
            if gait != .stationary {
                GaitIndicator(gait: gait)
            }

            // Gait breakdown bar (always show during ride)
            GaitBreakdownBar(
                walkPercent: walkPercent,
                trotPercent: trotPercent,
                canterPercent: canterPercent,
                gallopPercent: gallopPercent
            )

            // Flatwork-specific breakdown bars
            if showReinMetrics {
                VStack(spacing: 16) {
                    ReinBreakdownBar(
                        leftPercent: leftReinPercent,
                        rightPercent: rightReinPercent
                    )

                    TurnBreakdownBar(
                        leftPercent: leftTurnPercent,
                        rightPercent: rightTurnPercent
                    )

                    LeadBreakdownBar(
                        leftPercent: leftLeadPercent,
                        rightPercent: rightLeadPercent
                    )
                }
            }

            // Heart rate display
            if showHeartRate {
                HeartRateDisplayView(
                    heartRate: heartRate,
                    zone: heartRateZone,
                    averageHeartRate: averageHeartRate > 0 ? averageHeartRate : nil,
                    maxHeartRate: maxHeartRate > 0 ? maxHeartRate : nil
                )
            }

            // Live metrics row
            if showLead || showReinMetrics {
                HStack(spacing: 16) {
                    // Lead indicator (during canter/gallop)
                    if showLead {
                        LiveMetricBadge(
                            icon: lead == .left ? "arrow.left.circle.fill" : (lead == .right ? "arrow.right.circle.fill" : "questionmark.circle"),
                            label: "Lead",
                            value: lead.rawValue,
                            color: lead == .unknown ? .secondary : (lead == .left ? AppColors.turnLeft : AppColors.turnRight)
                        )
                    }

                    // Rein indicator (for flatwork)
                    if showReinMetrics {
                        LiveMetricBadge(
                            icon: rein == .left ? "arrow.counterclockwise.circle.fill" : (rein == .right ? "arrow.clockwise.circle.fill" : "arrow.up.circle"),
                            label: "Rein",
                            value: rein.rawValue,
                            color: rein == .straight ? .secondary : (rein == .left ? AppColors.turnLeft : AppColors.turnRight)
                        )
                    }
                }
            }

            // Quality metrics for flatwork
            if showReinMetrics && (symmetry > 0 || rhythm > 0) {
                HStack(spacing: 24) {
                    if symmetry > 0 {
                        LiveQualityGauge(label: "Symmetry", value: symmetry)
                    }
                    if rhythm > 0 {
                        LiveQualityGauge(label: "Rhythm", value: rhythm)
                    }
                }
            }
        }
    }
}

// MARK: - Gait Breakdown Bar

struct GaitBreakdownBar: View {
    let walkPercent: Double
    let trotPercent: Double
    let canterPercent: Double
    let gallopPercent: Double

    private var hasData: Bool {
        walkPercent > 0 || trotPercent > 0 || canterPercent > 0 || gallopPercent > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Gait Balance")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if hasData {
                // Stacked bar
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        if walkPercent > 0 {
                            Rectangle()
                                .fill(AppColors.gait(.walk))
                                .frame(width: geometry.size.width * (walkPercent / 100))
                        }
                        if trotPercent > 0 {
                            Rectangle()
                                .fill(AppColors.gait(.trot))
                                .frame(width: geometry.size.width * (trotPercent / 100))
                        }
                        if canterPercent > 0 {
                            Rectangle()
                                .fill(AppColors.gait(.canter))
                                .frame(width: geometry.size.width * (canterPercent / 100))
                        }
                        if gallopPercent > 0 {
                            Rectangle()
                                .fill(AppColors.gait(.gallop))
                                .frame(width: geometry.size.width * (gallopPercent / 100))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 10)

                // Labels
                HStack(spacing: 16) {
                    if walkPercent > 0 {
                        GaitLabel(gait: .walk, percent: walkPercent)
                    }
                    if trotPercent > 0 {
                        GaitLabel(gait: .trot, percent: trotPercent)
                    }
                    if canterPercent > 0 {
                        GaitLabel(gait: .canter, percent: canterPercent)
                    }
                    if gallopPercent > 0 {
                        GaitLabel(gait: .gallop, percent: gallopPercent)
                    }
                }
            } else {
                // Empty state with legend
                HStack(spacing: 12) {
                    GaitLegendItem(gait: .walk)
                    GaitLegendItem(gait: .trot)
                    GaitLegendItem(gait: .canter)
                    GaitLegendItem(gait: .gallop)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }
}

// Note: GaitLegendItem is defined in LiveTrackingMapView.swift

struct GaitLabel: View {
    let gait: GaitType
    let percent: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppColors.gait(gait))
                .frame(width: 8, height: 8)
            Text("\(Int(percent))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Live Metric Badge

struct LiveMetricBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Live Quality Gauge

struct LiveQualityGauge: View {
    let label: String
    let value: Double

    private var color: Color {
        switch value {
        case 0..<50: return AppColors.error
        case 50..<70: return AppColors.warning
        case 70..<85: return AppColors.success
        default: return AppColors.primary
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f%%", value))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Gait Indicator

struct GaitIndicator: View {
    let gait: GaitType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: gait.icon)
                .font(.title)
                .foregroundStyle(gaitColor)

            Text(gait.rawValue)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(gaitColor.opacity(0.2))
        .clipShape(Capsule())
    }

    private var gaitColor: Color {
        AppColors.gait(gait)
    }
}

// MARK: - XC Optimum Time Display

struct XCOptimumTimeDisplay: View {
    let timeDifference: String
    let isAhead: Bool
    let currentSpeed: String
    let gradient: String
    var hasOptimumTime: Bool = true

    private var timeColor: Color {
        if timeDifference == "0s" {
            return AppColors.success
        }
        // Ahead of time (negative) - risk of speeding penalty
        if isAhead {
            return timeDifference.contains("15") || timeDifference.count > 3 ? AppColors.warning : AppColors.success
        }
        // Behind time - risk of time fault
        return timeDifference.count > 3 ? AppColors.error : AppColors.warning
    }

    private var gradientColor: Color {
        if gradient.contains("+") {
            return AppColors.error  // Uphill - harder
        } else if gradient.contains("-") && !gradient.contains("0") {
            return AppColors.success  // Downhill - easier
        }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 16) {
            if hasOptimumTime {
                // Main time difference display - very prominent
                VStack(spacing: 4) {
                    Text("vs Optimum")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(timeDifference)
                        .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(timeColor)
                        .monospacedDigit()
                    Text(isAhead ? "AHEAD" : "BEHIND")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(timeColor)
                }
            } else {
                // No optimum time set - show placeholder
                VStack(spacing: 4) {
                    Text("vs Optimum")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("--:--")
                        .scaledFont(size: 48, weight: .bold, design: .rounded, relativeTo: .largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Set optimum time before ride")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Speed and Gradient row - always show
            HStack(spacing: 32) {
                // Current Speed
                VStack(spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentSpeed.isEmpty ? "0.0 km/h" : currentSpeed)
                        .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                        .monospacedDigit()
                }

                // Gradient indicator
                VStack(spacing: 4) {
                    Text("Gradient")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: gradient.contains("+") ? "arrow.up.right" : (gradient.contains("-") && !gradient.contains("0") ? "arrow.down.right" : "arrow.right"))
                            .font(.caption)
                            .foregroundStyle(gradientColor)
                        Text(gradient)
                            .scaledFont(size: 24, weight: .semibold, design: .rounded, relativeTo: .title3)
                            .foregroundStyle(gradientColor)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Rein Breakdown Bar

struct ReinBreakdownBar: View {
    let leftPercent: Double
    let rightPercent: Double

    private var hasData: Bool {
        leftPercent > 0 || rightPercent > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Rein Balance")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if hasData {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(AppColors.turnLeft)
                            .frame(width: geometry.size.width * (leftPercent / 100))
                        Rectangle()
                            .fill(AppColors.turnRight)
                            .frame(width: geometry.size.width * (rightPercent / 100))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 10)

                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.turnLeft)
                            .frame(width: 8, height: 8)
                        Text("L \(Int(leftPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("R \(Int(rightPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(AppColors.turnRight)
                            .frame(width: 8, height: 8)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.turnLeft)
                            .frame(width: 8, height: 8)
                        Text("Left")
                            .font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.turnRight)
                            .frame(width: 8, height: 8)
                        Text("Right")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Turn Breakdown Bar

struct TurnBreakdownBar: View {
    let leftPercent: Double
    let rightPercent: Double

    private var hasData: Bool {
        leftPercent > 0 || rightPercent > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Turn Balance")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if hasData {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(AppColors.turnLeft)
                            .frame(width: geometry.size.width * (leftPercent / 100))
                        Rectangle()
                            .fill(AppColors.turnRight)
                            .frame(width: geometry.size.width * (rightPercent / 100))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 10)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2)
                            .foregroundStyle(AppColors.turnLeft)
                        Text("\(Int(leftPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(Int(rightPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(AppColors.turnRight)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption2)
                        Text("Left")
                            .font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                        Text("Right")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Lead Breakdown Bar

struct LeadBreakdownBar: View {
    let leftPercent: Double
    let rightPercent: Double

    private var hasData: Bool {
        leftPercent > 0 || rightPercent > 0
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Canter Lead Balance")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if hasData {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(AppColors.turnLeft)
                            .frame(width: geometry.size.width * (leftPercent / 100))
                        Rectangle()
                            .fill(AppColors.turnRight)
                            .frame(width: geometry.size.width * (rightPercent / 100))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 10)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.turnLeft)
                        Text("\(Int(leftPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(Int(rightPercent))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.turnRight)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.circle")
                            .font(.caption2)
                        Text("Left Lead")
                            .font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                            .font(.caption2)
                        Text("Right Lead")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    LiveStatsView(
        duration: "01:23:45",
        distance: "5.67 km",
        speed: "12.3 km/h",
        gait: .trot
    )
}
