//
//  TargetFixtures.swift
//  TetraTrack
//
//  Test fixture infrastructure for shooting target analysis.
//  Provides curated images with known metadata for simulator testing.
//

import Foundation
import UIKit

// MARK: - Target Fixture

/// A test fixture image with known metadata
struct TargetFixture: Identifiable {
    let id: String
    let name: String
    let category: FixtureCategory
    let metadata: TargetFixtureMetadata

    /// Resource name in bundle
    let resourceName: String

    /// Bundle containing the resource
    let bundle: Bundle

    /// Load the fixture image
    func loadImage() -> UIImage? {
        // Try loading from asset catalog first
        if let image = UIImage(named: resourceName, in: bundle, with: nil) {
            return image
        }
        // Try loading from file
        if let path = bundle.path(forResource: resourceName, ofType: nil),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        return nil
    }

    enum FixtureCategory: String, Codable, CaseIterable {
        case idealConditions = "Ideal"
        case challengingLighting = "Lighting"
        case perspectiveSkew = "Perspective"
        case rotated = "Rotated"
        case overlappingHoles = "Overlapping"
        case poorQuality = "Poor Quality"
        case edgeCases = "Edge Cases"

        var description: String {
            switch self {
            case .idealConditions:
                return "Clean image with perfect lighting"
            case .challengingLighting:
                return "Shadows or uneven illumination"
            case .perspectiveSkew:
                return "Camera not perpendicular to target"
            case .rotated:
                return "Target rotated in frame"
            case .overlappingHoles:
                return "Multiple holes very close together"
            case .poorQuality:
                return "Blurry, low contrast, or noisy"
            case .edgeCases:
                return "Unusual patterns or artifacts"
            }
        }
    }
}

// MARK: - Fixture Metadata

/// Rich metadata for a test fixture
struct TargetFixtureMetadata: Codable, Equatable {
    /// Target type in the fixture
    let targetType: String  // "tetrathlon" or "olympicPistol"

    /// Known crop bounds (normalized 0-1)
    let knownCropBounds: CropBounds?

    /// Known target center within crop
    let knownTargetCenter: NormalizedPoint?

    /// Known target semi-axes
    let knownSemiAxes: NormalizedSize?

    /// Rotation angle in degrees
    let rotationDegrees: Double

    /// Perspective skew severity (0-1)
    let perspectiveSkew: Double

    /// Lighting conditions
    let lightingCondition: LightingCondition

    /// Expected number of holes
    let expectedHoleCount: Int

    /// Golden master shot positions (normalized target coordinates)
    let goldenMasterShots: [GoldenMasterShot]

    /// Expected pattern analysis results
    let expectedAnalysis: ExpectedPatternAnalysis?

    /// Image quality metrics (expected)
    let expectedQuality: ExpectedQuality?

    /// Description of the fixture
    let description: String

    /// Difficulty rating (1-5)
    let difficulty: Int

    struct CropBounds: Codable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }

    struct NormalizedPoint: Codable, Equatable {
        let x: Double
        let y: Double

        var cgPoint: CGPoint {
            CGPoint(x: x, y: y)
        }
    }

    struct NormalizedSize: Codable, Equatable {
        let width: Double
        let height: Double

        var cgSize: CGSize {
            CGSize(width: width, height: height)
        }
    }

    enum LightingCondition: String, Codable {
        case ideal = "ideal"
        case shadows = "shadows"
        case uneven = "uneven"
        case overexposed = "overexposed"
        case underexposed = "underexposed"
    }
}

// MARK: - Golden Master Shot

/// A known shot position for golden master testing
struct GoldenMasterShot: Codable, Equatable, Identifiable {
    var id: String { "\(normalizedX)_\(normalizedY)" }

    /// Normalized target X coordinate (-1 to +1)
    let normalizedX: Double

    /// Normalized target Y coordinate (-1 to +1)
    let normalizedY: Double

    /// Expected score
    let expectedScore: Int

    /// Radius tolerance for matching (normalized units)
    let matchTolerance: Double

    /// Convert to NormalizedTargetPosition
    var normalizedPosition: NormalizedTargetPosition {
        NormalizedTargetPosition(x: normalizedX, y: normalizedY)
    }

    init(x: Double, y: Double, score: Int, tolerance: Double = 0.05) {
        self.normalizedX = x
        self.normalizedY = y
        self.expectedScore = score
        self.matchTolerance = tolerance
    }
}

// MARK: - Expected Pattern Analysis

/// Expected pattern analysis results for golden master testing
struct ExpectedPatternAnalysis: Codable, Equatable {
    /// Expected MPI (normalized coordinates)
    let mpiX: Double
    let mpiY: Double

    /// Expected standard deviation
    let standardDeviation: Double

    /// Expected extreme spread
    let extremeSpread: Double

    /// Tolerance for floating point comparisons
    let tolerance: Double

    /// Whether directional bias is expected
    let expectsBias: Bool

    /// Expected bias direction (if applicable)
    let expectedBiasDirection: String?

    init(
        mpiX: Double,
        mpiY: Double,
        standardDeviation: Double,
        extremeSpread: Double,
        tolerance: Double = 0.02,
        expectsBias: Bool = false,
        expectedBiasDirection: String? = nil
    ) {
        self.mpiX = mpiX
        self.mpiY = mpiY
        self.standardDeviation = standardDeviation
        self.extremeSpread = extremeSpread
        self.tolerance = tolerance
        self.expectsBias = expectsBias
        self.expectedBiasDirection = expectedBiasDirection
    }
}

// MARK: - Expected Quality

/// Expected image quality metrics
struct ExpectedQuality: Codable, Equatable {
    let minSharpness: Double
    let minContrast: Double
    let expectedExposure: String  // "good", "underexposed", "overexposed"

    init(minSharpness: Double = 0.3, minContrast: Double = 0.2, expectedExposure: String = "good") {
        self.minSharpness = minSharpness
        self.minContrast = minContrast
        self.expectedExposure = expectedExposure
    }
}

// MARK: - Fixture Registry

/// Registry of all available test fixtures
final class TargetFixtureRegistry {
    static let shared = TargetFixtureRegistry()

    private var fixtures: [String: TargetFixture] = [:]
    private var fixturesByCategory: [TargetFixture.FixtureCategory: [TargetFixture]] = [:]

    private init() {
        registerBuiltInFixtures()
    }

    /// All registered fixtures
    var allFixtures: [TargetFixture] {
        Array(fixtures.values).sorted { $0.name < $1.name }
    }

    /// Fixtures by category
    func fixtures(in category: TargetFixture.FixtureCategory) -> [TargetFixture] {
        fixturesByCategory[category] ?? []
    }

    /// Get fixture by name
    func fixture(named name: String) -> TargetFixture? {
        fixtures[name]
    }

    /// Register a fixture
    func register(_ fixture: TargetFixture) {
        fixtures[fixture.name] = fixture
        fixturesByCategory[fixture.category, default: []].append(fixture)
    }

    /// Register fixtures from JSON metadata file
    func registerFixtures(from jsonURL: URL) throws {
        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        let fixtureConfigs = try decoder.decode([FixtureConfig].self, from: data)

        for config in fixtureConfigs {
            let fixture = TargetFixture(
                id: config.id,
                name: config.name,
                category: TargetFixture.FixtureCategory(rawValue: config.category) ?? .idealConditions,
                metadata: config.metadata,
                resourceName: config.resourceName,
                bundle: Bundle.main
            )
            register(fixture)
        }
    }

    private struct FixtureConfig: Codable {
        let id: String
        let name: String
        let category: String
        let resourceName: String
        let metadata: TargetFixtureMetadata
    }

    // MARK: - Built-in Fixtures

    private func registerBuiltInFixtures() {
        // These fixtures would be loaded from bundled assets
        // For now, define programmatically

        #if DEBUG
        registerIdealFixtures()
        registerLightingFixtures()
        registerPerspectiveFixtures()
        registerOverlappingFixtures()
        registerEdgeCaseFixtures()
        #endif
    }

    private func registerIdealFixtures() {
        // Ideal conditions - 5 shots centered
        register(TargetFixture(
            id: "ideal_centered_5",
            name: "Ideal - 5 Centered Shots",
            category: .idealConditions,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 5,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.02, y: 0.03, score: 10),
                    GoldenMasterShot(x: -0.01, y: -0.02, score: 10),
                    GoldenMasterShot(x: 0.05, y: -0.01, score: 10),
                    GoldenMasterShot(x: -0.03, y: 0.04, score: 10),
                    GoldenMasterShot(x: 0.01, y: 0.01, score: 10)
                ],
                expectedAnalysis: ExpectedPatternAnalysis(
                    mpiX: 0.008,
                    mpiY: 0.01,
                    standardDeviation: 0.035,
                    extremeSpread: 0.08
                ),
                expectedQuality: ExpectedQuality(),
                description: "Clean tetrathlon target with 5 well-centered shots",
                difficulty: 1
            ),
            resourceName: "fixture_ideal_centered_5",
            bundle: .main
        ))

        // Ideal conditions - scattered shots
        register(TargetFixture(
            id: "ideal_scattered_8",
            name: "Ideal - 8 Scattered Shots",
            category: .idealConditions,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 8,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.15, y: 0.2, score: 8),
                    GoldenMasterShot(x: -0.1, y: -0.15, score: 8),
                    GoldenMasterShot(x: 0.25, y: -0.1, score: 6),
                    GoldenMasterShot(x: -0.2, y: 0.25, score: 6),
                    GoldenMasterShot(x: 0.05, y: 0.08, score: 10),
                    GoldenMasterShot(x: -0.08, y: -0.05, score: 10),
                    GoldenMasterShot(x: 0.3, y: 0.35, score: 4),
                    GoldenMasterShot(x: -0.25, y: -0.3, score: 4)
                ],
                expectedAnalysis: ExpectedPatternAnalysis(
                    mpiX: 0.015,
                    mpiY: 0.035,
                    standardDeviation: 0.22,
                    extremeSpread: 0.65
                ),
                expectedQuality: ExpectedQuality(),
                description: "Tetrathlon target with 8 shots spread across scoring zones",
                difficulty: 2
            ),
            resourceName: "fixture_ideal_scattered_8",
            bundle: .main
        ))
    }

    private func registerLightingFixtures() {
        // Shadow fixture
        register(TargetFixture(
            id: "shadow_partial",
            name: "Partial Shadow",
            category: .challengingLighting,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .shadows,
                expectedHoleCount: 5,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.1, y: 0.1, score: 8),
                    GoldenMasterShot(x: -0.05, y: 0.05, score: 10),
                    GoldenMasterShot(x: 0.08, y: -0.08, score: 10),
                    GoldenMasterShot(x: -0.15, y: -0.12, score: 8),
                    GoldenMasterShot(x: 0.0, y: 0.02, score: 10)
                ],
                expectedAnalysis: ExpectedPatternAnalysis(
                    mpiX: -0.004,
                    mpiY: -0.006,
                    standardDeviation: 0.1,
                    extremeSpread: 0.27
                ),
                expectedQuality: ExpectedQuality(minSharpness: 0.25, minContrast: 0.15),
                description: "Target with partial shadow across left side",
                difficulty: 3
            ),
            resourceName: "fixture_shadow_partial",
            bundle: .main
        ))

        // Uneven lighting
        register(TargetFixture(
            id: "lighting_uneven",
            name: "Uneven Lighting",
            category: .challengingLighting,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .uneven,
                expectedHoleCount: 6,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.05, y: 0.1, score: 10),
                    GoldenMasterShot(x: -0.1, y: 0.08, score: 8),
                    GoldenMasterShot(x: 0.12, y: -0.05, score: 8),
                    GoldenMasterShot(x: -0.08, y: -0.1, score: 8),
                    GoldenMasterShot(x: 0.03, y: 0.02, score: 10),
                    GoldenMasterShot(x: -0.02, y: -0.03, score: 10)
                ],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(minSharpness: 0.3, minContrast: 0.18),
                description: "Target with bright spot on right, darker on left",
                difficulty: 3
            ),
            resourceName: "fixture_lighting_uneven",
            bundle: .main
        ))
    }

    private func registerPerspectiveFixtures() {
        // Slight rotation
        register(TargetFixture(
            id: "rotated_15deg",
            name: "Rotated 15 Degrees",
            category: .rotated,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 15,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 5,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.05, y: 0.05, score: 10),
                    GoldenMasterShot(x: -0.08, y: 0.1, score: 8),
                    GoldenMasterShot(x: 0.1, y: -0.05, score: 8),
                    GoldenMasterShot(x: -0.02, y: -0.08, score: 10),
                    GoldenMasterShot(x: 0.03, y: 0.0, score: 10)
                ],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(),
                description: "Target rotated 15 degrees clockwise",
                difficulty: 2
            ),
            resourceName: "fixture_rotated_15deg",
            bundle: .main
        ))

        // Perspective skew
        register(TargetFixture(
            id: "perspective_moderate",
            name: "Moderate Perspective",
            category: .perspectiveSkew,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.48),
                knownSemiAxes: .init(width: 0.38, height: 0.42),
                rotationDegrees: 0,
                perspectiveSkew: 0.15,
                lightingCondition: .ideal,
                expectedHoleCount: 5,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.02, y: 0.05, score: 10),
                    GoldenMasterShot(x: -0.05, y: 0.08, score: 10),
                    GoldenMasterShot(x: 0.08, y: -0.02, score: 10),
                    GoldenMasterShot(x: -0.03, y: -0.05, score: 10),
                    GoldenMasterShot(x: 0.01, y: 0.01, score: 10)
                ],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(),
                description: "Camera at ~15 degree angle from perpendicular",
                difficulty: 3
            ),
            resourceName: "fixture_perspective_moderate",
            bundle: .main
        ))
    }

    private func registerOverlappingFixtures() {
        // Two overlapping holes
        register(TargetFixture(
            id: "overlapping_2",
            name: "Two Overlapping Holes",
            category: .overlappingHoles,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 5,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.02, y: 0.02, score: 10),
                    GoldenMasterShot(x: 0.04, y: 0.03, score: 10, tolerance: 0.03),  // Overlapping
                    GoldenMasterShot(x: -0.1, y: 0.15, score: 8),
                    GoldenMasterShot(x: 0.12, y: -0.08, score: 8),
                    GoldenMasterShot(x: -0.05, y: -0.1, score: 8)
                ],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(),
                description: "Target with two holes nearly touching in center",
                difficulty: 4
            ),
            resourceName: "fixture_overlapping_2",
            bundle: .main
        ))

        // Torn hole
        register(TargetFixture(
            id: "torn_hole",
            name: "Torn Hole",
            category: .overlappingHoles,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 4,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.08, y: 0.1, score: 8, tolerance: 0.06),  // Torn
                    GoldenMasterShot(x: -0.05, y: -0.05, score: 10),
                    GoldenMasterShot(x: 0.15, y: -0.12, score: 8),
                    GoldenMasterShot(x: -0.1, y: 0.08, score: 8)
                ],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(),
                description: "Target with one torn/elongated hole",
                difficulty: 4
            ),
            resourceName: "fixture_torn_hole",
            bundle: .main
        ))
    }

    private func registerEdgeCaseFixtures() {
        // No holes
        register(TargetFixture(
            id: "empty_target",
            name: "Empty Target",
            category: .edgeCases,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 0,
                goldenMasterShots: [],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(),
                description: "Clean target with no holes",
                difficulty: 1
            ),
            resourceName: "fixture_empty_target",
            bundle: .main
        ))

        // All misses
        register(TargetFixture(
            id: "all_misses",
            name: "All Misses (Outside Target)",
            category: .edgeCases,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 3,
                goldenMasterShots: [
                    GoldenMasterShot(x: 1.2, y: 0.5, score: 0),
                    GoldenMasterShot(x: -1.1, y: -0.3, score: 0),
                    GoldenMasterShot(x: 0.8, y: 1.3, score: 0)
                ],
                expectedAnalysis: nil,
                expectedQuality: ExpectedQuality(),
                description: "All shots missed the scoring area",
                difficulty: 2
            ),
            resourceName: "fixture_all_misses",
            bundle: .main
        ))

        // Single shot
        register(TargetFixture(
            id: "single_shot",
            name: "Single Shot",
            category: .edgeCases,
            metadata: TargetFixtureMetadata(
                targetType: "tetrathlon",
                knownCropBounds: .init(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                knownTargetCenter: .init(x: 0.5, y: 0.5),
                knownSemiAxes: .init(width: 0.38, height: 0.44),
                rotationDegrees: 0,
                perspectiveSkew: 0,
                lightingCondition: .ideal,
                expectedHoleCount: 1,
                goldenMasterShots: [
                    GoldenMasterShot(x: 0.05, y: -0.03, score: 10)
                ],
                expectedAnalysis: nil,  // Can't compute spread with 1 shot
                expectedQuality: ExpectedQuality(),
                description: "Single centered shot",
                difficulty: 1
            ),
            resourceName: "fixture_single_shot",
            bundle: .main
        ))
    }
}
