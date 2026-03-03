# TetraTrack

The complete training companion for tetrathlon and eventing athletes. Track riding, running, swimming, and shooting — with automatic gait detection, AI coaching, family safety, and Apple Watch integration.

## Features

### Riding
- GPS route tracking with automatic gait detection (walk/trot/canter/gallop)
- Gait-coloured route maps with elevation profiles
- Balance analysis: rein balance, turn tracking, canter lead detection, rider symmetry
- Signal processing pipeline: FFT, Hidden Markov Model, coherence analysis at 100Hz
- Route planning with offline map support via OpenStreetMap
- Weather recording via WeatherKit

### Running
- 1500m time trial with automatic lap detection
- Virtual pacer with target pace/time modes
- Treadmill mode with manual distance entry
- Interval training and structured workout support
- Training programmes (C25K, 10K, Half Marathon)
- Walking mode with cadence and symmetry tracking

### Swimming
- 3-minute tetrathlon test simulation
- Apple Watch stroke detection (freestyle, breaststroke, backstroke, butterfly)
- SWOLF scoring and stroke rate analysis
- Per-length breakdown with split charts
- Structured training sets

### Shooting
- Competition scorecard (two 5-shot cards, tetrathlon scoring)
- Target scanning with automatic hole detection
- Pattern analysis: grouping quality, spread, directional bias
- Training drills: dry fire, balance stance, trigger control, reaction
- Apple Watch stance tracking with stability grading (A-F)

### Apple Intelligence (iOS 26+)
- Post-session natural language summaries
- Natural language search across all sessions
- Recovery monitoring with readiness assessment
- Training pattern analysis and coaching recommendations
- Competition performance insights and trend analysis

### Family Safety
- Live location sharing with gait-coloured routes
- Fall detection (2-phase: impact detection + movement check + heart rate)
- Automatic emergency alerts to trusted contacts
- Stationary warnings after period of no movement

### Apple Watch
- Independent session tracking for all four disciplines
- Glove-friendly oversized controls
- Live heart rate with zone indicator
- Haptic feedback for gait transitions, pace alerts, lap completions
- Fall detection and emergency alerts
- Voice notes recording

### Competition Calendar
- Competition management with countdown timers
- Task checklists for competition preparation
- Scorecard recording with points tracking
- Competition statistics and personal bests
- NSUserActivity integration (Spotlight, Maps, Siri)

### Training Load
- Performance Management Chart (CTL/ATL/TSB)
- Weekly load breakdown by discipline
- Form status monitoring (fresh/optimal/fatigued/overreaching)

### Horse Profiles
- Complete profiles: photo, breed, height, weight, colour, notes
- Per-horse training history and statistics
- Gait parameter tuning per horse
- Smart workload recommendations

## Build

```bash
# iOS app
xcodebuild -project TetraTrack/TetraTrack.xcodeproj -scheme TetraTrack \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Watch app
xcodebuild -project TetraTrack/TetraTrack.xcodeproj -scheme "TetraTrack Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Unit tests
xcodebuild -project TetraTrack/TetraTrack.xcodeproj -scheme TetraTrack test

# Shared package
cd TetraTrackShared && swift build && swift test
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for comprehensive technical documentation including data models, service architecture, signal processing pipeline, and future roadmap.

**Key patterns:**
- SwiftUI + SwiftData with CloudKit sync
- MVVM using `@Observable` (iOS 17+)
- Protocol-based dependency injection via `ServiceContainer`
- Signal processing: FFT, HMM, coherence analysis, Hilbert transform
- All relationships optional for CloudKit compatibility

## Project Structure

```
TetraTrack/
├── TetraTrack/                    # Main iOS app (383 Swift files)
│   ├── Models/                    # SwiftData models (58 files)
│   ├── Services/                  # Business logic (62 files)
│   │   ├── Intelligence/          # Apple Intelligence (FoundationModels)
│   │   ├── DSP/                   # Signal processing (FFT, HMM, coherence)
│   │   ├── Sharing/               # CloudKit family sharing
│   │   └── Detection/             # Shooting detection
│   ├── Views/                     # SwiftUI views (145+ files)
│   │   ├── Disciplines/           # Riding, Running, Swimming, Shooting + Drills
│   │   ├── Competition/           # Calendar, stats, scorecards
│   │   ├── Tracking/              # Active session UI
│   │   ├── Insights/              # Analytics and AI insights
│   │   ├── Family/                # Live sharing and safety
│   │   └── Settings/              # App configuration
│   └── Utilities/                 # Formatters, colours, design system
├── TetraTrack Watch App/          # watchOS companion (28 files)
├── TetraTrackWidgetExtension/     # Home screen widgets
├── TetraTrackShared/              # SPM package (iOS + watchOS)
├── TetraTrackTests/               # Unit tests (29 files)
└── fastlane/                      # TestFlight deployment
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI (iOS 17+) |
| Persistence | SwiftData + CloudKit |
| Location | CoreLocation (`CLLocationUpdate.liveUpdates`) |
| Maps | MapKit (iOS 17+ native `Map`) |
| Health | HealthKit (HR, workouts, calories) |
| Motion | CoreMotion (accelerometer, gyroscope) |
| AI | FoundationModels (iOS 26+) |
| Weather | WeatherKit |
| Audio | AVSpeechSynthesizer (voice coaching) |
| Watch | WatchConnectivity |
| Routing | OpenStreetMap / Overpass API |
| CI/CD | GitHub Actions + Fastlane |

## Deployment

Push to `main` triggers automatic TestFlight deployment via GitHub Actions and Fastlane.

```bash
# Local deployment
bundle exec fastlane beta
```

## Localization

Supported languages: English (UK/US), German, French, Dutch, Swedish.

~690 localization keys per language, managed via `LocalizationManager` with runtime language switching.

## Device Requirements

- **iPhone**: iOS 17.0+ (iOS 26+ for Apple Intelligence)
- **Apple Watch**: watchOS 10.0+
- **iPad**: Review-only mode
- **Widgets**: WidgetKit with App Groups data sharing

## Privacy

All data stored on-device. Optional iCloud sync via CloudKit private database. AI processing via Apple Intelligence (on-device). No third-party analytics or advertising. See [PRIVACY.md](PRIVACY.md).

## Licence

Copyright 2026 Darryl Cauldwell. All rights reserved.
