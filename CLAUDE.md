# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.
Shared Swift/iOS conventions (tech stack, code style, testing, error handling) are in `~/.claude/CLAUDE.md`.

## Project Overview

TetraTrack is a multi-discipline training app for iOS 26+ and watchOS 26+ targeting tetrathlon and eventing athletes. It tracks four disciplines: riding (equestrian with GPS, gait detection, balance analysis), running (1500m time trials, virtual pacer, treadmill mode), swimming (pool and open-water with stroke detection), and shooting (competition card scanning, stance tracking).

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
├── TetraTrack/                      # Main iOS app
│   ├── Models/                      # SwiftData models (Ride, Horse, LocationPoint, etc.)
│   │   └── SessionState.swift       # Discipline-neutral session state enum
│   ├── Services/                    # Business logic and managers
│   │   ├── SessionTracker.swift     # Unified session tracker (all disciplines)
│   │   ├── DisciplinePlugin.swift   # Protocol for discipline-specific logic
│   │   ├── Plugins/                 # DisciplinePlugin implementations
│   │   │   └── RidingPlugin.swift   # Riding-specific session logic
│   │   ├── Intelligence/            # Apple Intelligence integration
│   │   └── [service files]
│   ├── Views/                       # SwiftUI views by feature area
│   │   ├── Disciplines/             # Riding, Running, Swimming, Shooting
│   │   ├── Tracking/                # Active session UI
│   │   └── [subdirectories]
│   ├── Utilities/                   # Helpers (formatters, colors, calculators)
│   └── Intents/                     # Siri Shortcuts
├── TetraTrack Watch App/            # watchOS app
├── TetraTrackWidgetExtension/       # Home screen widgets
├── TetraTrackShared/                # SPM package shared between iOS/watchOS
└── TetraTrackTests/                 # Unit tests (Swift Testing framework)
```

### Naming Taxonomy

Use the correct suffix — it signals intent and lifecycle:

| Suffix | Role | Stateful? | Example |
|--------|------|-----------|---------|
| `*Manager` | Owns a subsystem, long-lived, `@Observable @MainActor` | Yes | `HealthKitManager`, `FallDetectionManager` |
| `*Service` | Coordinates operations, business logic | Usually no | `WeatherService`, `TrainingProgramService` |
| `*Analyzer` | Signal processing / DSP on streaming data | Internal buffers only | `GaitAnalyzer`, `TurnAnalyzer`, `RhythmAnalyzer` |
| `*Coordinator` | Orchestrates across multiple services | No | `UnifiedSharingCoordinator`, `InsightsCoordinator` |

### Session Tracking Architecture

All disciplines share a unified `SessionTracker` (`@Observable @MainActor`) that owns common session concerns: GPS, timer, heart rate, elevation, fall detection, vehicle detection, weather, family sharing, and Watch connectivity. Discipline-specific logic lives in `DisciplinePlugin` conformances.

```
SessionTracker (common)          DisciplinePlugin (protocol)
├── sessionState                 ├── createSessionModel()
├── elapsedTime, totalDistance   ├── createLocationPoint()
├── currentSpeed, elevation      ├── onSessionStarted/Stopped()
├── heartRate, HR zones          ├── onLocationProcessed()
├── fallDetection, weather       ├── onTimerTick()
├── familySharing                └── watchStatusFields()
└── startSession(plugin:)
         │
         ▼
    RidingPlugin (riding-specific)
    ├── gait detection, lead/rein analysis
    ├── phase management (warmup/round/rest/cooldown)
    ├── dressage test practice
    ├── XC timing
    └── CoreMotion processing
```

**Views** access common metrics from `SessionTracker` and discipline-specific data via plugin downcast:
```swift
@Environment(SessionTracker.self) private var tracker
let ridingPlugin = tracker?.plugin(as: RidingPlugin.self)
```

**`SessionState`** (`idle`, `tracking`, `paused`) replaces the old `RideState`. A `typealias RideState = SessionState` exists for backward compatibility until all disciplines are migrated.

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

**Transport selection is critical** — wrong transport causes lost commands.

| Message Type | Transport | Why |
|-------------|-----------|-----|
| Lifecycle (start/stop/pause/resume) | `sendReliableCommand()` — dual sendMessage + transferUserInfo | Must survive disconnect; applicationContext clobbered by 1Hz timer |
| Status updates (1Hz) | `sendMessage()` / `applicationContext` | Last-value-wins is acceptable |
| Haptic commands | `sendMessage()` | Non-critical; don't flood transferUserInfo queue |
| Handshake (ack, mirroringStarted) | `sendReliableMessage()` — dual sendMessage + transferUserInfo | Must not be clobbered |

**Never** send lifecycle commands via `applicationContext` — the 1Hz status timer overwrites them before the Watch reads them.

### Mirroring Pipeline
iPhone checks Watch availability (`isPaired && isReachable && isWatchAppInstalled`) before session start. If available, calls `HKHealthStore.startWatchApp(toHandle:)` → Watch receives config via `handle(_ workoutConfiguration:)` → creates HKWorkoutSession → `startMirroringToCompanionDevice()` → iPhone receives mirrored session via HealthKit. If Watch not available, starts iPhone-primary workout immediately.

### Key Files

| File | Side | Role |
|------|------|------|
| `WatchConnectivityManager.swift` | iPhone | Sends commands, receives Watch data |
| `WorkoutLifecycleService.swift` | iPhone | Manages workout lifecycle |
| `WorkoutManager.swift` | Watch | Manages workouts, wires mirroring/fallback |
| `WatchConnectivityService.swift` | Watch | Receives commands, sends data |

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

- **Every push to main**: full validation (SwiftLint, @Relationship lint, version consistency, metadata limits, build all targets) + TestFlight deploy
- Unit tests are **not** run in CI — simulator boot on macos-26 runners is unreliable. Run locally via `Scripts/preflight.sh` before pushing.

## TestFlight Upload Commands

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/TetraTrack-*
xcodebuild -project TetraTrack.xcodeproj -scheme TetraTrack -configuration Release -archivePath /tmp/TetraTrack.xcarchive clean archive
xcodebuild -exportArchive -archivePath /tmp/TetraTrack.xcarchive -exportPath /tmp/TetraTrackExport -exportOptionsPlist TetraTrack/ExportOptions.plist
```
