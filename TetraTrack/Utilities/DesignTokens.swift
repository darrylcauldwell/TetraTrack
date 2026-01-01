//
//  DesignTokens.swift
//  TetraTrack
//
//  Centralized design tokens for consistent spacing, sizing, and styling
//  across iPhone, iPad, and Apple Watch platforms.
//

import SwiftUI

// MARK: - Spacing Scale

/// Consistent spacing values used throughout the app
enum Spacing {
    /// Extra small spacing: 4pt
    static let xs: CGFloat = 4
    /// Small spacing: 8pt
    static let sm: CGFloat = 8
    /// Medium spacing: 12pt
    static let md: CGFloat = 12
    /// Large spacing: 16pt
    static let lg: CGFloat = 16
    /// Extra large spacing: 20pt
    static let xl: CGFloat = 20
    /// Extra extra large spacing: 24pt
    static let xxl: CGFloat = 24
    /// Jumbo spacing: 32pt
    static let jumbo: CGFloat = 32
}

// MARK: - Corner Radius Scale

/// Consistent corner radius values
enum CornerRadius {
    /// Small radius for badges, chips: 8pt
    static let sm: CGFloat = 8
    /// Medium radius for buttons, small cards: 12pt
    static let md: CGFloat = 12
    /// Large radius for cards: 16pt
    static let lg: CGFloat = 16
    /// Extra large radius for panels, glass cards: 20pt
    static let xl: CGFloat = 20
    /// Full radius for pills and capsules
    static let pill: CGFloat = 9999
}

// MARK: - Tap Target Sizes

/// Minimum tap target sizes per platform and context
enum TapTarget {
    /// Standard minimum tap target for iOS (44pt per Apple HIG)
    static let standard: CGFloat = 44
    /// Comfortable tap target for primary actions: 60pt
    static let comfortable: CGFloat = 60
    /// Large tap target for glove-friendly buttons: 80pt
    static let large: CGFloat = 80
    /// Extra large tap target for primary action buttons: 200pt
    static let extraLarge: CGFloat = 200

    /// Watch minimum tap target (38pt per watchOS HIG)
    static let watchMinimum: CGFloat = 38
    /// Watch comfortable tap target: 44pt
    static let watchComfortable: CGFloat = 44
}

// MARK: - Shadow Scale

/// Consistent shadow configurations
enum Shadow {
    /// Subtle shadow for light elevation
    static let subtle = ShadowConfig(color: .black.opacity(0.06), radius: 4, y: 2)
    /// Medium shadow for cards
    static let medium = ShadowConfig(color: .black.opacity(0.08), radius: 8, y: 4)
    /// Prominent shadow for floating elements
    static let prominent = ShadowConfig(color: .black.opacity(0.12), radius: 12, y: 6)
    /// Glass shadow for glass design system
    static let glass = ShadowConfig(color: .black.opacity(0.08), radius: 10, y: 4)
}

/// Shadow configuration helper
struct ShadowConfig {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
    var x: CGFloat = 0
}

// MARK: - Typography Scale

/// Consistent typography configurations
enum Typography {
    /// Large title for hero displays
    static let largeTitle: Font = .largeTitle
    /// Title for section headers
    static let title: Font = .title
    /// Title 2 for card headers
    static let title2: Font = .title2
    /// Title 3 for sub-sections
    static let title3: Font = .title3
    /// Headline for emphasized content
    static let headline: Font = .headline
    /// Body for main content
    static let body: Font = .body
    /// Subheadline for secondary content
    static let subheadline: Font = .subheadline
    /// Caption for labels and hints
    static let caption: Font = .caption
    /// Caption 2 for smallest text
    static let caption2: Font = .caption2

    /// Monospaced digits for numerical displays
    static func monospacedDigits(_ font: Font) -> Font {
        font.monospacedDigit()
    }
}

// MARK: - Border Width

/// Consistent border widths
enum BorderWidth {
    /// Subtle border: 0.5pt
    static let subtle: CGFloat = 0.5
    /// Standard border: 1pt
    static let standard: CGFloat = 1
    /// Emphasis border: 2pt
    static let emphasis: CGFloat = 2
}

// MARK: - Opacity Scale

/// Consistent opacity values for overlays and backgrounds
enum Opacity {
    /// Ultra light: 0.05
    static let ultraLight: Double = 0.05
    /// Light: 0.1
    static let light: Double = 0.1
    /// Medium light: 0.15
    static let mediumLight: Double = 0.15
    /// Medium: 0.2
    static let medium: Double = 0.2
    /// Medium heavy: 0.3
    static let mediumHeavy: Double = 0.3
    /// Heavy: 0.4
    static let heavy: Double = 0.4
}

// MARK: - Animation Durations

/// Consistent animation timing
enum AnimationDuration {
    /// Fast animation: 0.15s
    static let fast: Double = 0.15
    /// Standard animation: 0.25s
    static let standard: Double = 0.25
    /// Slow animation: 0.35s
    static let slow: Double = 0.35
}

// MARK: - View Modifiers

extension View {
    /// Apply standard shadow
    func standardShadow(_ config: ShadowConfig = Shadow.medium) -> some View {
        self.shadow(color: config.color, radius: config.radius, x: config.x, y: config.y)
    }

    /// Ensure minimum tap target size
    func minimumTapTarget(_ size: CGFloat = TapTarget.standard) -> some View {
        self.frame(minWidth: size, minHeight: size)
    }

    /// Apply standard card styling
    func standardCard() -> some View {
        self
            .padding(Spacing.lg)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
    }
}

// MARK: - Drill Start Button Style

/// Consistent button style for drill start buttons across all disciplines
struct DrillStartButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = AppColors.primary) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.fast), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

/// Button style for secondary/try again actions in drills
struct DrillSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(configuration.isPressed ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.fast), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

/// Consistent done button style for drill completion
struct DrillDoneButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = AppColors.primary) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(Spacing.lg)
            .background(configuration.isPressed ? color.opacity(0.8) : color)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.fast), value: configuration.isPressed)
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Adaptive Layout

/// Layout configuration for different device sizes
enum AdaptiveLayout {
    /// Number of columns for grid layouts based on horizontal size class
    static func columns(for sizeClass: UserInterfaceSizeClass?) -> Int {
        switch sizeClass {
        case .regular:
            return 2  // iPad landscape, iPad portrait
        default:
            return 1  // iPhone
        }
    }

    /// Maximum content width for readability on large screens
    static let maxContentWidth: CGFloat = 700

    /// Ideal card width for grid layouts
    static let idealCardWidth: CGFloat = 320

    /// Minimum card width to prevent cards from getting too small
    static let minCardWidth: CGFloat = 280
}

/// Adaptive grid layout that responds to horizontal size class
struct AdaptiveGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = Spacing.lg, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        let columns = AdaptiveLayout.columns(for: horizontalSizeClass)

        if columns > 1 {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                content()
            }
        } else {
            VStack(spacing: spacing) {
                content()
            }
        }
    }
}

/// View modifier for iPad-optimized content width
extension View {
    /// Constrains content width on iPad for better readability
    func adaptiveContentWidth() -> some View {
        self.frame(maxWidth: AdaptiveLayout.maxContentWidth)
    }

    /// Applies padding that scales with screen size
    @ViewBuilder
    func adaptivePadding(_ sizeClass: UserInterfaceSizeClass?) -> some View {
        switch sizeClass {
        case .regular:
            self.padding(.horizontal, Spacing.jumbo)
        default:
            self.padding(.horizontal, Spacing.lg)
        }
    }
}

// MARK: - iPad Adaptive Layout Components

/// Adaptive split view that uses NavigationSplitView on iPad and NavigationStack on iPhone.
/// Use this for list views that should show detail inline on iPad.
struct AdaptiveSplitView<ListContent: View, DetailContent: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let listContent: ListContent
    let detailContent: DetailContent
    let listTitle: String
    let emptyDetailTitle: String
    let emptyDetailIcon: String
    let emptyDetailDescription: String

    init(
        listTitle: String,
        emptyDetailTitle: String = "Select an Item",
        emptyDetailIcon: String = "doc.text",
        emptyDetailDescription: String = "Choose an item to view details",
        @ViewBuilder list: () -> ListContent,
        @ViewBuilder detail: () -> DetailContent
    ) {
        self.listTitle = listTitle
        self.emptyDetailTitle = emptyDetailTitle
        self.emptyDetailIcon = emptyDetailIcon
        self.emptyDetailDescription = emptyDetailDescription
        self.listContent = list()
        self.detailContent = detail()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                listContent
                    .navigationTitle(listTitle)
            } detail: {
                detailContent
            }
        } else {
            NavigationStack {
                listContent
                    .navigationTitle(listTitle)
            }
        }
    }
}

/// Adaptive detail layout that arranges content side-by-side on iPad and vertically on iPhone.
/// Use this for detail views with a primary element (map) and secondary content (stats).
struct AdaptiveDetailLayout<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let primary: Primary
    let secondary: Secondary
    let primaryMinWidth: CGFloat
    let secondaryWidth: CGFloat

    init(
        primaryMinWidth: CGFloat = 400,
        secondaryWidth: CGFloat = 350,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.primaryMinWidth = primaryMinWidth
        self.secondaryWidth = secondaryWidth
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: Spacing.xl) {
                primary
                    .frame(minWidth: primaryMinWidth, maxWidth: .infinity)
                secondary
                    .frame(width: secondaryWidth)
            }
        } else {
            VStack(spacing: Spacing.lg) {
                primary
                secondary
            }
        }
    }
}

/// Adaptive chart grid that uses multi-column layout on iPad and single column on iPhone.
/// Use this for views with multiple charts or analytics cards.
struct AdaptiveChartGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let minItemWidth: CGFloat
    let spacing: CGFloat
    let content: () -> Content

    init(
        minItemWidth: CGFloat = 350,
        spacing: CGFloat = Spacing.lg,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minItemWidth), spacing: spacing)],
                spacing: spacing
            ) {
                content()
            }
        } else {
            VStack(spacing: spacing) {
                content()
            }
        }
    }
}

/// View modifier to check if running on iPad (regular horizontal size class)
extension View {
    /// Returns true if the current horizontal size class is regular (iPad)
    @ViewBuilder
    func iPadOnly<Content: View>(@ViewBuilder content: (Self) -> Content) -> some View {
        content(self)
    }
}

/// Environment key for checking if we're in iPad layout mode
struct IsIPadLayoutKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isIPadLayout: Bool {
        get { self[IsIPadLayoutKey.self] }
        set { self[IsIPadLayoutKey.self] = newValue }
    }
}

// MARK: - Stability Color Helper

/// Returns appropriate color for stability score (used across all drills)
enum StabilityColors {
    static func color(for score: Double) -> Color {
        if score > 0.8 { return AppColors.active }
        if score > 0.5 { return AppColors.warning }
        return AppColors.error
    }

    static func gradeColor(for score: Double) -> Color {
        if score > 0.8 { return AppColors.active }
        if score > 0.6 { return AppColors.warning }
        return AppColors.running
    }
}

// MARK: - Dynamic Type Support

/// ViewModifier for Dynamic Type-aware font sizing.
/// Use this to replace fixed `.font(.system(size:))` calls with scaling fonts.
struct ScaledFont: ViewModifier {
    @ScaledMetric var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default, relativeTo textStyle: Font.TextStyle = .body) {
        self._size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    /// Apply a Dynamic Type-aware custom font size.
    ///
    /// Use this instead of `.font(.system(size:))` for accessibility.
    /// The font will scale based on the user's Dynamic Type settings.
    ///
    /// - Parameters:
    ///   - size: Base font size at default Dynamic Type setting
    ///   - weight: Font weight (default: .regular)
    ///   - design: Font design (default: .default)
    ///   - relativeTo: The text style to scale relative to (default: .body)
    ///
    /// Size mapping guide:
    /// - 64-120pt hero displays → relativeTo: .largeTitle
    /// - 48-60pt large stats → relativeTo: .largeTitle
    /// - 36-44pt section heroes → relativeTo: .title
    /// - 28-32pt card headers → relativeTo: .title2
    /// - 20-24pt subheadings → relativeTo: .title3
    /// - 16-18pt body text → relativeTo: .body
    /// - 14pt secondary text → relativeTo: .subheadline
    /// - 10-12pt labels/hints → relativeTo: .caption
    /// - 6-9pt debug only → relativeTo: .caption2
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, relativeTo: textStyle))
    }
}

// MARK: - Accessibility Helpers

extension View {
    /// Add accessibility for interactive buttons
    /// - Parameters:
    ///   - label: A concise description of what the button does
    ///   - hint: Optional hint describing what happens when activated
    func accessibleButton(_ label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    /// Add accessibility for navigation links
    /// - Parameters:
    ///   - label: Description of where the link navigates to
    ///   - hint: Description of what the user will find there
    func accessibleNavigation(_ label: String, hint: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
    }

    /// Add accessibility for status indicators (combines children into single element)
    /// - Parameters:
    ///   - status: The status name (e.g., "Connected", "Syncing")
    ///   - description: Additional context about the status
    func accessibleStatus(_ status: String, description: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(status): \(description)")
    }

    /// Add accessibility for numeric values with units
    /// - Parameters:
    ///   - value: The numeric value as a string
    ///   - unit: The unit of measurement
    ///   - context: Optional additional context (e.g., "Distance")
    func accessibleValue(_ value: String, unit: String, context: String? = nil) -> some View {
        let label = context != nil ? "\(context!): \(value) \(unit)" : "\(value) \(unit)"
        return self.accessibilityLabel(label)
    }

    /// Add accessibility for charts with a summary description
    /// - Parameter summary: A text description of the chart content and trends
    func accessibleChart(_ summary: String) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)
    }

    /// Add accessibility for toggle controls
    /// - Parameters:
    ///   - label: Description of what the toggle controls
    ///   - isOn: Current state of the toggle
    func accessibleToggle(_ label: String, isOn: Bool) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Accessible Status Indicator

/// A WCAG-compliant status indicator that uses icon, color, AND text
/// to convey status information without relying on color alone.
struct AccessibleStatusIndicator: View {
    let status: StatusType
    let size: Size

    enum StatusType {
        case connected
        case disconnected
        case syncing
        case error
        case warning
        case success
        case inactive

        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle.fill"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .inactive: return "circle"
            }
        }

        var color: Color {
            switch self {
            case .connected, .success: return AppColors.active
            case .disconnected, .inactive: return AppColors.inactive
            case .syncing: return AppColors.primary
            case .error: return AppColors.error
            case .warning: return AppColors.warning
            }
        }

        var label: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .syncing: return "Syncing"
            case .error: return "Error"
            case .warning: return "Warning"
            case .success: return "Success"
            case .inactive: return "Inactive"
            }
        }
    }

    enum Size {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }

        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
    }

    init(_ status: StatusType, size: Size = .medium) {
        self.status = status
        self.size = size
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: size.iconSize))
                .foregroundStyle(status.color)
                .symbolEffect(.pulse, options: .repeating, isActive: status == .syncing)

            Text(status.label)
                .font(size.font)
                .foregroundStyle(status.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.label)")
    }
}

/// A compact status dot with accessible label for inline status display
struct AccessibleStatusDot: View {
    let isActive: Bool
    let activeLabel: String
    let inactiveLabel: String

    init(isActive: Bool, activeLabel: String = "Active", inactiveLabel: String = "Inactive") {
        self.isActive = isActive
        self.activeLabel = activeLabel
        self.inactiveLabel = inactiveLabel
    }

    var body: some View {
        Circle()
            .fill(isActive ? AppColors.active : AppColors.inactive)
            .frame(width: 8, height: 8)
            .accessibilityLabel(isActive ? activeLabel : inactiveLabel)
    }
}
