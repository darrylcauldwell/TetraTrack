# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Shared Swift/iOS conventions (tech stack, code style, testing, error handling) are in `~/.claude/CLAUDE.md`.

## Project Overview

TetraTrack is a tetrathlon training app for iOS 26+ and watchOS 26+. **The Watch app is the primary session capture device** — all disciplines (riding, running, swimming, walking, shooting) start and record on Apple Watch using native `HKWorkoutSession`. The iPhone app enriches completed workouts from HealthKit with detailed metrics, actionable insights, post-session annotation (horse, scores, notes), target scanning for shooting, cross-discipline analytics, and AI-powered training analysis mapped to 5 biomechanical pillars (Stability, Rhythm, Symmetry, Economy, Physiology).

## Build Commands

```bash
# Build main iOS app
xcodebuild -project TetraTrack.xcodeproj -scheme TetraTrack -destination 'generic/platform=iOS Simulator' build

# Build and run all unit tests
xcodebuild -project TetraTrack.xcodeproj -scheme TetraTrack test

# Run specific test class
xcodebuild -project TetraTrack.xcodeproj -scheme TetraTrack test -only-testing:TetraTrackTests/RideModelTests

# Build watch app
xcodebuild -project TetraTrack.xcodeproj -scheme "TetraTrack Watch App" -destination 'generic/platform=watchOS Simulator' build

# Build widgets
xcodebuild -project TetraTrack.xcodeproj -scheme TetraTrackWidgetExtension -configuration Debug build

# Build shared package
xcodebuild -project TetraTrack.xcodeproj -scheme TetraTrackShared -configuration Debug build
```

## Architecture

### Project-Specific Frameworks
- **Persistence**: SwiftData with CloudKit sync
- **Location**: CoreLocation with `CLLocationUpdate.liveUpdates(.fitness)` API
- **Maps**: MapKit (`Map`/`MapPolyline`)
- **Watch**: WatchConnectivity framework

### Project Structure
```
TetraTrack/
├── TetraTrack/                      # Main iOS app (enrichment, annotation, history)
│   ├── Models/                      # SwiftData models (Ride, Horse, ShootingSession, etc.)
│   ├── Services/                    # Business logic and managers
│   │   ├── WorkoutEnrichmentService.swift  # Fetches HealthKit metrics for any workout
│   │   ├── Shooting/               # ShootingSensorAnalyzer for pillar scores
│   │   ├── Intelligence/           # Apple Intelligence integration
│   │   └── [service files]
│   ├── Views/                       # SwiftUI views by feature area
│   │   ├── Disciplines/            # Drill views, shooting scoring, ride annotation
│   │   ├── History/                # Session detail views with enrichment + insights
│   │   ├── Competition/            # Competition calendar, day view, stats
│   │   └── [subdirectories]
│   ├── Utilities/                   # Helpers (formatters, colors, calculators)
│   └── Intents/                     # Siri Shortcuts
├── TetraTrack Watch App/            # watchOS app (primary session capture)
│   ├── Services/
│   │   ├── WorkoutManager.swift     # Autonomous HKWorkoutSession for all disciplines
│   │   ├── ShootingShotDetector.swift # 50Hz IMU shot detection state machine
│   │   ├── WatchRideMetricsCollector.swift # Jump, turn, steadiness, rhythm, halt
│   │   └── WatchMotionManager.swift # Cadence, stance, posture from IMU
│   └── Views/
│       ├── RideControlView.swift    # 3 ride types (Ride, Dressage, Showjumping)
│       ├── RunControlView.swift     # min/400m pace hero
│       ├── SwimControlView.swift    # Lap count hero
│       ├── WalkControlView.swift    # SPM hero
│       └── ShootingControlView.swift # Steadiness + HR hero
├── TetraTrackWidgetExtension/       # Home screen widgets
├── TetraTrackShared/                # SPM package shared between iOS/watchOS
└── TetraTrackTests/                 # Unit tests (Swift Testing framework)
```

### Naming Taxonomy

Use the correct suffix — it signals intent and lifecycle:

| Suffix | Role | Stateful? | Example |
|--------|------|-----------|---------|
| `*Manager` | Owns a subsystem, long-lived, `@Observable @MainActor` | Yes | `HealthKitManager`, `WorkoutManager` |
| `*Service` | Coordinates operations, business logic | Usually no | `WeatherService`, `WorkoutEnrichmentService` |
| `*Analyzer` | Signal processing / DSP on streaming data | Internal buffers only | `WatchSensorAnalyzer`, `ShootingSensorAnalyzer` |
| `*Coordinator` | Orchestrates across multiple services | No | `UnifiedSharingCoordinator`, `InsightsCoordinator` |
| `*Collector` | Gathers metrics from sensors during a session | Internal buffers only | `WatchRideMetricsCollector` |

### Watch-Primary Session Architecture

**All disciplines capture on Apple Watch.** iPhone is the enrichment, annotation, and review layer.

```
Watch (capture)                          iPhone (review)
├── WorkoutManager                       ├── WorkoutEnrichmentService
│   ├── startAutonomousRide(type:)       │   (HR, route, elevation, weather, photos)
│   ├── startAutonomousRun()             ├── EnrichedWorkoutDetailView
│   ├── startAutonomousSwim()            │   (Session + Insights tabs)
│   ├── startAutonomousWalk()            ├── RideAnnotationView
│   └── startAutonomousShooting()        │   (horse, scores, notes)
│                                        └── ShootingPracticeView
├── HKWorkoutSession (.equestrianSports, │   (scan targets, enter scores)
│   .running, .swimming, .walking,       │
│   .archery) — Watch owns + saves       │
│                                        │
├── Post-session: transferUserInfo       │
│   sends summary to iPhone              │
│   (ride metrics, shot data, etc.)      │
└── Workout appears in HealthKit ────────┘
    → iPhone enriches via HealthKit queries
```

**No iPhone app needed during sessions.** Watch is fully autonomous.
Post-session data flows via `transferUserInfo` (guaranteed delivery) for ride annotations and shooting scores.

### HealthKit Workout Enrichment

All workouts (riding, running, swimming, walking, shooting, and Apple Watch native types) are captured on Watch and saved to HealthKit. TetraTrack enriches these on iPhone:

- `WorkoutEnrichmentService` — fetches HR timeseries, per-km splits, walking/running/swimming/cycling metrics, elevation, route
- `WorkoutInsightsGenerator` — generates actionable insights by comparing against recent history (pace trends, PBs, form feedback, consistency)
- `EnrichedWorkoutDetailView` — rich detail view with HR chart + zones, splits, activity-specific metrics, photos, insights
- `ExternalWorkoutService` — queries HealthKit for workouts, shown by default in Training History

Legacy `RunningSession` and `SwimmingSession` models remain in the CloudKit schema but no new instances are created. Historical sessions route through `EnrichedWorkoutDetailView` via `asExternalWorkout` conversion.

### Dependency Injection

- **`ServiceContainer`** manages production dependencies. Has a public `init(...)` with protocol parameters for test injection.
- **`@Environment`** in views: services passed via `EnvironmentKey` extensions on `EnvironmentValues`.
- **`.shared` singletons only where frameworks require it**: `HealthKitManager.shared`, `WatchConnectivityManager.shared`, `NotificationManager.shared`, `WidgetDataSyncService.shared`. Mark as `@MainActor static let shared`.
- Prefer constructor injection for new services. Use protocols (`WeatherFetching`, `AudioCoaching`) for testability.

### Async Patterns (Project-Specific)

- `@MainActor` on all `@Observable` managers and any service that touches UI state
- `@Sendable` on closure types for thread safety
- Use wall-clock time for timers: store `startDate = Date()`, compute elapsed as `Date().timeIntervalSince(startDate)`. Never rely on `Timer` tick counting — it drifts.

### Logging

Log via the `Log` enum (wraps `os.Logger`) with category:
```swift
Log.services.debug("Fetching weather for \(location)")
Log.gait.error("Failed to classify: \(error)")
```
Categories: `.app`, `.services`, `.tracking`, `.health`, `.location`, `.watch`, `.notifications`, `.family`, `.integrations`, `.audio`, `.widgets`, `.safety`, `.export`, `.intelligence`, `.ui`, `.gait`, `.shooting`, `.storage`

## SwiftData & CloudKit

CloudKit sync is enabled via SwiftData's `cloudKitDatabase: .automatic` configuration.
**Container**: `iCloud.dev.dreamfold.TetraTrack`

### Model Rules

```swift
// All properties MUST have default values or be optional
var name: String = ""
var endDate: Date?

// NEVER use @Attribute(.unique) with CloudKit — breaks sync

// String-backed enums for CloudKit compatibility
var rideTypeValue: String = RideType.hack.rawValue
var rideType: RideType {
    get { RideType(rawValue: rideTypeValue) ?? .hack }
    set { rideTypeValue = newValue.rawValue }
}

// @Transient for cached computed values (not persisted)
@Transient private var _cachedHeartRateSamples: [HeartRateSample]?

// #Index for query-hot fields
#Index<Ride>([\.startDate], [\.rideTypeValue])

// Encoded Data fields for complex types
var heartRateSamplesData: Data?  // JSON-encoded via Codable
```

### Relationship Rules

Relationships **MUST** be optional arrays. Non-optional relationships break CloudKit sync (error 134060).

```swift
// CORRECT — optional array with ?
@Relationship(deleteRule: .cascade, inverse: \LocationPoint.ride)
var locationPoints: [LocationPoint]? = []

// WRONG — will break CloudKit sync
// var locationPoints: [LocationPoint] = []  // Missing ?
```

**Lint check** — run before committing model changes:
```bash
grep -A1 "@Relationship" TetraTrack/Models/*.swift TetraTrack/Models/**/*.swift 2>/dev/null | grep -E "var.*\[.*\].*=" | grep -v "\?"
```

**When using relationships in code:**
1. Access with nil coalescing: `(relationship ?? [])`
2. Before appending: `if array == nil { array = [] }; array?.append(item)`

### CloudKit Architecture

```
Private Database (per user)
├── FamilySharing Zone (custom zone for sharing)
│   ├── LiveTrackingSession records
│   ├── FamilyRelationship records
│   ├── TrainingArtifact records
│   └── SharedCompetition records
└── Default Zone (SwiftData automatic sync)
    └── All SwiftData models

Shared Database (accepted shares)
└── Access to other users' FamilySharing zones
```

**Entitlements required:**
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.dev.dreamfold.TetraTrack</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

## CoreLocation

```swift
// Use async CLLocationUpdate API
let updates = CLLocationUpdate.liveUpdates(.fitness)
for try await update in updates {
    if let location = update.location { ... }
}

// Background tracking requirements
locationManager.allowsBackgroundLocationUpdates = true
locationManager.pausesLocationUpdatesAutomatically = false
locationManager.activityType = .fitness
```

## WatchConnectivity

**Transport selection** — Watch-primary architecture simplifies transport. No lifecycle commands sent from iPhone.

| Message Type | Transport | Direction | Why |
|-------------|-----------|-----------|-----|
| Post-session summary (ride metrics, shot data) | `transferUserInfo` | Watch → iPhone | Guaranteed delivery, survives disconnect |
| Real-time shot metrics | `sendMessage()` | Watch → iPhone | Bonus live feedback if iPhone open |
| HR updates (1Hz) | `sendMessage()` | Watch → iPhone | Last-value-wins acceptable |
| Motion data (1Hz) | `sendMessage()` / `applicationContext` | Watch → iPhone | Sensor relay |

### Watch-Primary Workout Architecture

Watch owns all `HKWorkoutSession` instances. Each discipline has an autonomous start/stop method on `WorkoutManager`. Watch saves workouts directly to HealthKit. Post-session summaries sent to iPhone via `WCSession.transferUserInfo` for annotation data (ride metrics, shot sensor data).

### Key Files

| File | Side | Role |
|------|------|------|
| `WorkoutManager.swift` | Watch | Autonomous HKWorkoutSession for all 5 disciplines |
| `WatchRideMetricsCollector.swift` | Watch | Jump, turn, steadiness, rhythm, halt detection |
| `ShootingShotDetector.swift` | Watch | 50Hz IMU shot detection state machine |
| `WatchMotionManager.swift` | Watch | Cadence, stance, posture from IMU sensors |
| `WatchConnectivityManager.swift` | iPhone | Receives Watch summaries, stores pending annotations |
| `WorkoutEnrichmentService.swift` | iPhone | Fetches HealthKit metrics for completed workouts |

## UI Guidelines

- Primary buttons: minimum 200pt diameter (glove-friendly)
- Touch targets: minimum 60pt for all interactive elements
- Use monospaced digits for time/distance: `.font(.system(.largeTitle, design: .rounded)).monospacedDigit()`
- High contrast colors (green = start, red = stop)
- Add haptic feedback on button taps

## Versioning

- **Format**: `0.<milestone>.<build>` (e.g., `0.2.130` for build 130 in the 0.2 milestone)
- The `<milestone>` portion tracks the current release milestone (0.2, 0.3, etc.)
- `CURRENT_PROJECT_VERSION` (build number) is auto-incremented by the fastlane `beta` lane
- `MARKETING_VERSION` must be identical across all targets in project.pbxproj
- Widget extension uses `$(CURRENT_PROJECT_VERSION)` in Info.plist to stay in sync
- When starting work on a new milestone, update `MARKETING_VERSION` to match (e.g., `0.3.x` when starting 0.3 — Polish)

## Release Milestones

Issues are grouped into milestones that represent themed releases:

| Milestone | Theme |
|-----------|-------|
| `0.2 — Stability` | Fix existing bugs |
| `0.3 — Polish` | Cleanup + wire existing data to UI |
| `0.4 — Riding` | Dressage, showjumping, coaching |
| `0.5 — Shooting` | Full shooting analysis overhaul |
| `0.6 — Refactoring` | Model consolidation |
| `0.7 — Analytics` | Tier 2 new analysis logic |
| `0.8 — Integrations` | CarPlay, localisation, ML |

- Work on the current milestone's issues first (lowest milestone number)
- When all issues in a milestone are closed, close the milestone
- Version bumps happen automatically via fastlane on push to main

**Milestone assignment guide:**
- Bug fixes → `Stability`
- UI cleanup, wiring existing data → `Polish`
- Discipline-specific features → `Riding`, `Shooting`, etc.
- Model/code restructuring → `Refactoring`
- New analysis/metrics → `Analytics`
- External integrations → `Integrations`

## CI Pipeline

CI/CD follows the standard iOS playbook in `~/.claude/ios-cicd-playbook.md`. TestFlight deploys via GitHub Actions on every push to main.
