# Air Pistol Target Analysis - Gap Analysis and Improvement Plan

## Executive Summary

This document analyzes the current air pistol shooting target analysis implementation in TrackRide and provides a comprehensive improvement plan. The analysis covers 12 key areas from image capture to history aggregation.

**Current State**: Auto-detection is disabled (`// No auto-detection - user will manually mark holes`). Manual marking works but lacks robust coordinate normalization and has tap interaction issues.

**Key Issues Identified**:
1. Crop geometry is not persisted or used for coordinate transformation
2. Target center is hardcoded to `(0.5, 0.5)` regardless of actual target position
3. No proper pixel-to-millimeter scaling
4. Tap-to-delete requires double-tap with confirmation dialog (poor UX)
5. `ScannedTarget` stores scores but not normalized positions
6. History aggregation impossible without normalized coordinate storage

---

## 1. Image Capture and Cropping

### Current Implementation
**File**: `ShootingScannerComponents.swift:811-1026`

```swift
// ManualCropView
@State private var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
```

- User can drag corners/edges to define crop rectangle
- Crop is applied via `CGImage.cropping(to:)`
- After cropping, the crop geometry is **discarded** - only the cropped UIImage is passed forward

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Crop rect not persisted | Cannot compute pixel-to-target scaling | Critical |
| No circular/elliptical crop option | Tetrathlon targets are oval but crop is rectangular | Medium |
| No crop preview validation | User cannot verify target alignment | Low |

### Recommendation

**A. Persist Crop Geometry**
```swift
struct TargetCropGeometry: Codable {
    let cropRect: CGRect              // Normalized (0-1) crop rectangle
    let targetBoundaryType: BoundaryType  // .rectangular, .circular, .elliptical
    let targetCenterInCrop: CGPoint   // Center relative to cropped image (0-1)
    let targetRadiusInCrop: CGSize    // Radius or semi-axes relative to crop

    enum BoundaryType: String, Codable {
        case rectangular
        case circular
        case elliptical
    }
}
```

**B. Add Target Boundary Overlay**
After cropping, show an adjustable ellipse overlay to define the actual target boundary:
```swift
struct TargetBoundaryEditor: View {
    let croppedImage: UIImage
    @Binding var targetCenter: CGPoint    // 0-1 normalized
    @Binding var targetRadius: CGSize     // Semi-axes for ellipse

    // User can drag center point and resize handles
}
```

**C. Update Crop Flow**
```
Camera → ManualCropView → TargetBoundaryEditor → InteractiveAnnotatedTargetImage
         (persist crop)   (persist boundary)     (use for scoring)
```

---

## 2. Target Coordinate System

### Current Implementation
**File**: `ShootingScannerComponents.swift:350-367`

```swift
private func addHole(at position: CGPoint) {
    let targetCenter = detectedTargetCenter ?? CGPoint(x: 0.5, y: 0.5)  // HARDCODED
    let targetSize = detectedTargetSize ?? CGSize(width: 0.4, height: 0.6)  // HARDCODED
    // ...
}
```

Positions are stored as normalized `(0-1)` coordinates relative to the cropped image, NOT relative to the target center.

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Coordinates relative to image, not target | Analysis math is incorrect | Critical |
| No true target-centric origin | Cannot aggregate across sessions | Critical |
| No unit specification (pixels vs mm) | Ambiguous measurements | High |

### Recommendation

**A. Define Canonical Target Coordinate System**
```swift
/// Shot position in target-centric normalized coordinates
/// Origin: Target center (0, 0)
/// X-axis: Positive = right, Negative = left
/// Y-axis: Positive = up, Negative = down
/// Units: Normalized target radius (-1 to +1 for shots at target edge)
struct NormalizedTargetPosition: Codable, Equatable {
    let x: Double  // -1.0 (left edge) to +1.0 (right edge)
    let y: Double  // -1.0 (bottom) to +1.0 (top)

    /// Distance from center (0 to 1+ for shots outside target)
    var radialDistance: Double {
        sqrt(x * x + y * y)
    }

    /// Elliptical distance accounting for oval targets
    func ellipticalDistance(aspectRatio: Double) -> Double {
        // aspectRatio = width/height
        let normalizedX = x / aspectRatio
        return sqrt(normalizedX * normalizedX + y * y)
    }

    /// Angle from center (0 = right, 90 = up, etc.)
    var angle: Double {
        atan2(y, x) * 180 / .pi
    }
}
```

**B. Coordinate Transformation Functions**
```swift
struct TargetCoordinateTransformer {
    let cropGeometry: TargetCropGeometry
    let imageSize: CGSize  // Cropped image size in pixels

    /// Convert pixel position in cropped image to normalized target coordinates
    func toTargetCoordinates(pixelPosition: CGPoint) -> NormalizedTargetPosition {
        // Step 1: Normalize to 0-1 range
        let normalizedX = pixelPosition.x / imageSize.width
        let normalizedY = pixelPosition.y / imageSize.height

        // Step 2: Translate to target center origin
        let centerX = normalizedX - cropGeometry.targetCenterInCrop.x
        let centerY = cropGeometry.targetCenterInCrop.y - normalizedY  // Flip Y (image Y is down)

        // Step 3: Scale by target radius to get -1 to +1 range
        let targetX = centerX / cropGeometry.targetRadiusInCrop.width
        let targetY = centerY / cropGeometry.targetRadiusInCrop.height

        return NormalizedTargetPosition(x: targetX, y: targetY)
    }

    /// Convert normalized target coordinates back to pixel position
    func toPixelPosition(targetPosition: NormalizedTargetPosition) -> CGPoint {
        let centerX = targetPosition.x * cropGeometry.targetRadiusInCrop.width
        let centerY = targetPosition.y * cropGeometry.targetRadiusInCrop.height

        let normalizedX = centerX + cropGeometry.targetCenterInCrop.x
        let normalizedY = cropGeometry.targetCenterInCrop.y - centerY

        return CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )
    }
}
```

---

## 3. Target Geometry and Scaling

### Current Implementation
**File**: `ShootingScannerComponents.swift:412-425`

```swift
private func calculateScore(for position: CGPoint, center: CGPoint, size: CGSize) -> Int {
    let dx = abs(position.x - center.x) / (size.width / 2)
    let dy = abs(position.y - center.y) / (size.height / 2)
    let ellipticalDistance = sqrt(dx * dx + dy * dy)

    // Tetrathlon scoring: 10, 8, 6, 4, 2
    if ellipticalDistance < 0.2 { return 10 }
    // ...
}
```

The scoring rings are hardcoded as fractions (0.2, 0.4, 0.6, 0.8, 1.0) without reference to actual physical dimensions.

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| No physical target model | Cannot validate against official specs | Medium |
| Hardcoded ring ratios | May not match actual tetrathlon targets | Medium |
| No pellet diameter consideration | Scoring uses point, not hole edge | Low |

### Recommendation

**A. Define Physical Target Model**
```swift
/// Physical dimensions of tetrathlon air pistol target
/// Based on UIPM specifications
struct TetrathlonTargetGeometry {
    /// Total target card dimensions (mm)
    static let cardWidth: Double = 170
    static let cardHeight: Double = 170

    /// Scoring zone outer diameters (mm) - elliptical
    /// Zone boundaries from center outward
    static let scoringZones: [(score: Int, radiusX: Double, radiusY: Double)] = [
        (10, 5.75, 7.5),     // Inner 10 (X-ring equivalent)
        (8, 20.0, 26.0),     // 8 zone
        (6, 34.25, 44.5),    // 6 zone
        (4, 48.5, 63.0),     // 4 zone
        (2, 62.75, 81.5),    // 2 zone (outer edge)
    ]

    /// Standard pellet diameter (mm)
    static let pelletDiameter: Double = 4.5

    /// Calculate score from position (mm from center)
    static func score(atX x: Double, atY y: Double) -> Int {
        for zone in scoringZones {
            let normalizedDistance = sqrt(
                pow(x / zone.radiusX, 2) + pow(y / zone.radiusY, 2)
            )
            if normalizedDistance <= 1.0 {
                return zone.score
            }
        }
        return 0  // Miss
    }
}
```

**B. Pixel-to-Millimeter Scaling**
```swift
struct TargetScaling {
    let pixelsPerMillimeter: Double

    init(targetRadiusPixels: CGSize, targetRadiusMM: CGSize) {
        // Use average of X and Y for consistent scaling
        let scaleX = targetRadiusPixels.width / targetRadiusMM.width
        let scaleY = targetRadiusPixels.height / targetRadiusMM.height
        pixelsPerMillimeter = (scaleX + scaleY) / 2
    }

    func toMillimeters(pixels: Double) -> Double {
        pixels / pixelsPerMillimeter
    }

    func toPixels(millimeters: Double) -> Double {
        millimeters * pixelsPerMillimeter
    }
}
```

---

## 4. Manual Center Confirmation

### Current Implementation
**File**: `ShootingScannerComponents.swift:46-49`

```swift
// Set default target center and size for scoring calculation
detectedTargetCenter = CGPoint(x: 0.5, y: 0.5)
detectedTargetSize = CGSize(width: 0.7, height: 0.9)
```

The center is hardcoded after cropping. There is no mechanism to adjust it.

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| No center adjustment UI | Imperfect crops cause scoring errors | High |
| No visual feedback of detected center | User cannot verify alignment | High |
| Center offset not persisted | Cannot recalculate after session | Medium |

### Recommendation

**A. Add Center Confirmation Step**
```swift
struct CenterConfirmationView: View {
    let croppedImage: UIImage
    @Binding var targetCenter: CGPoint  // Normalized 0-1
    @Binding var targetRadius: CGSize   // Normalized semi-axes

    @State private var showCrosshair = true
    @State private var showScoringRings = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: croppedImage)
                    .resizable()
                    .scaledToFit()

                // Draggable center point
                DraggableCenterMarker(
                    position: $targetCenter,
                    geoSize: geo.size
                )

                // Scoring ring overlay for visual confirmation
                if showScoringRings {
                    ScoringRingOverlay(
                        center: targetCenter,
                        radius: targetRadius,
                        geoSize: geo.size
                    )
                }
            }
        }
    }
}

struct DraggableCenterMarker: View {
    @Binding var position: CGPoint
    let geoSize: CGSize

    var body: some View {
        ZStack {
            // Crosshair
            Rectangle().fill(.red).frame(width: 2, height: 40)
            Rectangle().fill(.red).frame(width: 40, height: 2)
            Circle().stroke(.red, lineWidth: 2).frame(width: 20, height: 20)
        }
        .position(
            x: position.x * geoSize.width,
            y: position.y * geoSize.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    position = CGPoint(
                        x: value.location.x / geoSize.width,
                        y: value.location.y / geoSize.height
                    )
                }
        )
    }
}
```

**B. Persist Center Offset**
```swift
struct TargetAlignment: Codable {
    var confirmedCenter: CGPoint      // User-confirmed center
    var confirmedRadius: CGSize       // User-confirmed radius
    var centerOffset: CGPoint = .zero // Adjustment from detected center
    var rotationAngle: Double = 0     // For perspective correction
}
```

---

## 5. Assisted Hole Auto-Detection

### Current Implementation
**File**: `ShootingScannerComponents.swift:1893-2112`

```swift
actor TargetAnalyzer {
    // Uses VNDetectContoursRequest
    // Looks for small circular contours
    // Currently DISABLED in TargetScannerView
}
```

The `TargetAnalyzer` exists but:
- Is not called after cropping
- Uses fixed thresholds that fail under varying lighting
- Has no confidence scoring for assisted workflow

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Auto-detection completely disabled | User must manually mark all holes | High |
| No adaptive thresholding | Fails with uneven lighting | High |
| No expected hole size constraint | Detects debris as holes | Medium |
| No confidence scoring | Cannot distinguish high/low confidence | Medium |

### Recommendation

**A. Robust Detection Pipeline**
```swift
actor AssistedHoleDetector {

    struct DetectionConfig {
        /// Expected pellet hole diameter in pixels (calculated from target scaling)
        var expectedHoleDiameterPixels: ClosedRange<CGFloat> = 10...30

        /// Minimum circularity (0-1) to accept as potential hole
        var minCircularity: Double = 0.5

        /// Confidence threshold for auto-accept
        var autoAcceptConfidence: Double = 0.85

        /// Confidence threshold for suggestions
        var suggestionConfidence: Double = 0.5
    }

    struct DetectedHoleCandidate: Identifiable {
        let id = UUID()
        let pixelPosition: CGPoint
        let radiusPixels: CGFloat
        let confidence: Double      // 0-1
        let features: HoleFeatures

        enum AcceptanceLevel {
            case autoAccept    // confidence >= 0.85
            case suggestion    // 0.5 <= confidence < 0.85
            case rejected      // confidence < 0.5
        }

        var acceptanceLevel: AcceptanceLevel {
            if confidence >= 0.85 { return .autoAccept }
            if confidence >= 0.5 { return .suggestion }
            return .rejected
        }
    }

    struct HoleFeatures {
        let circularity: Double       // 0-1
        let contrast: Double          // Local contrast
        let darkness: Double          // Average intensity
        let edgeStrength: Double      // Edge definition
    }

    func detectHoles(
        in image: CGImage,
        cropGeometry: TargetCropGeometry,
        config: DetectionConfig
    ) async throws -> [DetectedHoleCandidate] {

        var candidates: [DetectedHoleCandidate] = []

        // Step 1: Adaptive thresholding for varying lighting
        let preprocessed = await preprocessWithAdaptiveThreshold(image)

        // Step 2: Contour detection
        let contours = try await detectContours(preprocessed)

        // Step 3: Filter by size and shape
        for contour in contours {
            let bounds = contour.boundingBox
            let diameter = (bounds.width + bounds.height) / 2

            // Size filter
            guard config.expectedHoleDiameterPixels.contains(diameter) else {
                continue
            }

            // Shape analysis
            let circularity = calculateCircularity(contour)
            guard circularity >= config.minCircularity else {
                continue
            }

            // Calculate confidence from multiple features
            let features = analyzeFeatures(contour, in: image)
            let confidence = calculateConfidence(features, circularity: circularity)

            if confidence >= config.suggestionConfidence {
                candidates.append(DetectedHoleCandidate(
                    pixelPosition: bounds.center,
                    radiusPixels: diameter / 2,
                    confidence: confidence,
                    features: features
                ))
            }
        }

        // Step 4: Non-maximum suppression for overlapping detections
        return nonMaximumSuppression(candidates, overlapThreshold: 0.5)
    }

    private func preprocessWithAdaptiveThreshold(_ image: CGImage) async -> CGImage {
        // Use Core Image for adaptive local thresholding
        let ciImage = CIImage(cgImage: image)

        // Apply Gaussian blur to get local mean
        let blurred = ciImage.applyingFilter("CIGaussianBlur", parameters: [
            kCIInputRadiusKey: 15.0
        ])

        // Subtract blurred from original for local contrast
        let difference = ciImage.applyingFilter("CISubtractBlendMode", parameters: [
            kCIInputBackgroundImageKey: blurred
        ])

        // Threshold the difference
        // ... implementation details

        return result
    }

    private func calculateConfidence(_ features: HoleFeatures, circularity: Double) -> Double {
        // Weighted combination of features
        let circularityWeight = 0.3
        let contrastWeight = 0.25
        let darknessWeight = 0.25
        let edgeWeight = 0.2

        return circularity * circularityWeight +
               features.contrast * contrastWeight +
               features.darkness * darknessWeight +
               features.edgeStrength * edgeWeight
    }
}
```

**B. Adaptive Parameters Based on Image Analysis**
```swift
extension AssistedHoleDetector {

    /// Analyze image to determine optimal detection parameters
    func calibrateParameters(for image: CGImage, targetScaling: TargetScaling) -> DetectionConfig {
        var config = DetectionConfig()

        // Calculate expected hole size in pixels
        let holeMMDiameter = TetrathlonTargetGeometry.pelletDiameter
        let holePixelDiameter = targetScaling.toPixels(millimeters: holeMMDiameter)

        // Allow ±50% tolerance for torn/irregular holes
        config.expectedHoleDiameterPixels =
            (holePixelDiameter * 0.5)...(holePixelDiameter * 1.5)

        // Analyze image statistics for adaptive thresholding
        let stats = calculateImageStatistics(image)

        // Lower circularity requirement for low-contrast images
        if stats.contrast < 0.3 {
            config.minCircularity = 0.4
        }

        return config
    }
}
```

---

## 6. Human-in-the-Loop Correction Model

### Current Implementation
The current flow is fully manual:
1. User taps to add holes
2. Long-press + drag to move
3. Tap → tap again → confirmation dialog to delete

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| No assisted detection shown | User must find all holes manually | High |
| No visual distinction between auto/manual | Cannot see detection confidence | Medium |
| Deletion requires 3 interactions | Slow correction workflow | Medium |

### Recommendation

**A. Three-Tier Hole Display**
```swift
enum HoleStatus {
    case autoAccepted     // Green ring - high confidence, auto-added
    case suggested        // Yellow ring - medium confidence, needs confirmation
    case manuallyAdded    // Blue ring - user added
    case manuallyRejected // For tracking rejected suggestions
}

struct AnnotatedHole: Identifiable {
    let id = UUID()
    var targetPosition: NormalizedTargetPosition
    var status: HoleStatus
    var detectionConfidence: Double?  // nil for manually added
    var score: Int
}
```

**B. Assisted Workflow UI**
```swift
struct AssistedAnnotationView: View {
    @Binding var holes: [AnnotatedHole]
    let suggestions: [DetectedHoleCandidate]

    var body: some View {
        ZStack {
            // Image layer

            // Auto-accepted holes (green, no interaction needed)
            ForEach(autoAcceptedHoles) { hole in
                HoleMarker(hole: hole, style: .autoAccepted)
            }

            // Suggested holes (yellow, tap to accept/reject)
            ForEach(suggestedHoles) { suggestion in
                SuggestionMarker(
                    suggestion: suggestion,
                    onAccept: { acceptSuggestion(suggestion) },
                    onReject: { rejectSuggestion(suggestion) }
                )
            }

            // Manually added holes (blue)
            ForEach(manuallyAddedHoles) { hole in
                HoleMarker(hole: hole, style: .manual)
            }
        }
    }
}

struct SuggestionMarker: View {
    let suggestion: DetectedHoleCandidate
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        ZStack {
            // Pulsing yellow ring
            Circle()
                .stroke(.yellow, lineWidth: 3)
                .frame(width: 30, height: 30)

            // Accept/reject buttons on tap
            HStack(spacing: 4) {
                Button(action: onAccept) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Button(action: onReject) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.system(size: 20))
        }
    }
}
```

**C. Bulk Actions**
```swift
// Accept all suggestions above threshold
func acceptAllSuggestions(minConfidence: Double = 0.7) {
    for suggestion in suggestions where suggestion.confidence >= minConfidence {
        acceptSuggestion(suggestion)
    }
}

// Clear all suggestions (keep only confirmed)
func rejectAllSuggestions() {
    suggestions.removeAll()
}
```

---

## 7. Manual Shot Interaction Reliability

### Current Implementation
**File**: `ShootingScannerComponents.swift:1452-1496`

```swift
private func handleTap(at location: CGPoint, geoSize: CGSize) {
    let tapThreshold: CGFloat = 30 / scale

    for hole in holes {
        let holeX = hole.position.x * geoSize.width
        let holeY = hole.position.y * geoSize.height
        let distance = sqrt(pow(location.x - holeX, 2) + pow(location.y - holeY, 2))

        if distance < tapThreshold {
            if selectedHoleID == hole.id {
                holeToDelete = hole.id
                showingDeleteConfirmation = true  // REQUIRES CONFIRMATION
            } else {
                selectedHoleID = hole.id  // FIRST TAP ONLY SELECTS
            }
            return
        }
    }
    // ... add new hole if no hit
}
```

**Problem**: Tapping a marker requires:
1. First tap → selects hole
2. Second tap → shows confirmation dialog
3. Dialog "Delete" button → actually deletes

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Tap doesn't calculate position accounting for zoom/pan | Hit testing fails when zoomed | High |
| Selection state creates confusion | User expects tap to toggle | Medium |
| Confirmation dialog for every delete | Slows workflow significantly | Medium |
| No undo functionality | User must re-add deleted holes | Low |

### Recommendation

**A. Fix Hit Testing with Zoom/Pan**
```swift
private func handleTap(at location: CGPoint, geoSize: CGSize) {
    // Transform tap location to account for current zoom and pan
    let transformedLocation = transformTapLocation(
        location,
        scale: scale,
        offset: offset,
        geoSize: geoSize
    )

    let tapThresholdPoints: CGFloat = 44  // Apple HIG minimum
    let tapThresholdNormalized = tapThresholdPoints / (geoSize.width * scale)

    // Find nearest hole within threshold
    let nearestHole = holes
        .map { hole -> (hole: DetectedHole, distance: CGFloat) in
            let dx = hole.position.x - transformedLocation.x
            let dy = hole.position.y - transformedLocation.y
            return (hole, sqrt(dx*dx + dy*dy))
        }
        .filter { $0.distance < tapThresholdNormalized }
        .min { $0.distance < $1.distance }

    if let (hole, _) = nearestHole {
        handleHoleTap(hole)
    } else {
        addHole(at: transformedLocation)
    }
}

private func transformTapLocation(
    _ location: CGPoint,
    scale: CGFloat,
    offset: CGSize,
    geoSize: CGSize
) -> CGPoint {
    // Reverse the zoom/pan transformations
    let centeredX = location.x - geoSize.width / 2
    let centeredY = location.y - geoSize.height / 2

    let unscaledX = centeredX / scale
    let unscaledY = centeredY / scale

    let unpannedX = unscaledX - offset.width / scale
    let unpannedY = unscaledY - offset.height / scale

    let normalizedX = (unpannedX + geoSize.width / 2) / geoSize.width
    let normalizedY = (unpannedY + geoSize.height / 2) / geoSize.height

    return CGPoint(
        x: max(0, min(1, normalizedX)),
        y: max(0, min(1, normalizedY))
    )
}
```

**B. Simplified Interaction Model**
```swift
// Option 1: Single tap toggles delete with visual feedback
private func handleHoleTap(_ hole: DetectedHole) {
    // Mark for deletion with visual indicator
    if markedForDeletion.contains(hole.id) {
        // Second tap confirms deletion
        deleteHole(id: hole.id)
        markedForDeletion.remove(hole.id)
    } else {
        markedForDeletion.insert(hole.id)
        // Auto-clear mark after 2 seconds if no second tap
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            markedForDeletion.remove(hole.id)
        }
    }
}

// Option 2: Swipe to delete
struct SwipeableHoleMarker: View {
    let hole: DetectedHole
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        HoleMarkerContent(hole: hole)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = value.translation.width
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 50 {
                            withAnimation { onDelete() }
                        } else {
                            withAnimation { offset = 0 }
                        }
                    }
            )
    }
}
```

**C. Add Undo Stack**
```swift
class HoleEditHistory: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    private var undoStack: [HoleEditAction] = []
    private var redoStack: [HoleEditAction] = []

    enum HoleEditAction {
        case add(DetectedHole)
        case delete(DetectedHole)
        case move(id: UUID, from: CGPoint, to: CGPoint)
    }

    func recordAdd(_ hole: DetectedHole) {
        undoStack.append(.add(hole))
        redoStack.removeAll()
        updateState()
    }

    func undo() -> HoleEditAction? {
        guard let action = undoStack.popLast() else { return nil }
        redoStack.append(action)
        updateState()
        return action
    }
}
```

---

## 8. Shot Data Model

### Current Implementation

**DetectedHole** (in-memory during annotation):
```swift
struct DetectedHole: Identifiable {
    let id = UUID()
    var position: CGPoint  // Normalized 0-1 relative to IMAGE
    var score: Int
    var confidence: Double
    var radius: CGFloat = 0.02
}
```

**ScanShot** (persisted):
```swift
struct ScanShot: Codable, Identifiable {
    var id: UUID = UUID()
    var positionX: Double
    var positionY: Double
    var score: Int
    var confidence: Double
}
```

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Position is image-relative, not target-relative | Cannot aggregate across sessions | Critical |
| No distinction between detected vs manual | Cannot analyze detection accuracy | Medium |
| No uncertainty/error radius stored | Cannot visualize precision | Low |

### Recommendation

**A. Enhanced Shot Model**
```swift
/// Individual shot with full provenance tracking
struct TargetShot: Codable, Identifiable {
    let id: UUID

    // Position in target-centric normalized coordinates
    let position: NormalizedTargetPosition

    // Optional: Position in millimeters (if target geometry known)
    var positionMM: CGPoint?

    // Scoring
    let score: Int
    let isXRing: Bool  // For archery-style targets

    // Provenance
    let source: ShotSource
    let createdAt: Date

    // Detection metadata (if auto-detected)
    var detectionConfidence: Double?
    var detectionFeatures: DetectionFeatures?

    // Manual correction metadata
    var wasManuallyAdjusted: Bool = false
    var originalPosition: NormalizedTargetPosition?  // If moved

    // Uncertainty
    var uncertaintyRadius: Double?  // In normalized units

    enum ShotSource: String, Codable {
        case autoDetected
        case manuallyAdded
        case importedFromHistory
    }

    struct DetectionFeatures: Codable {
        let circularity: Double
        let contrast: Double
        let edgeStrength: Double
    }
}
```

**B. Batch Shot Collection**
```swift
struct TargetShotGroup: Codable, Identifiable {
    let id: UUID
    let capturedAt: Date

    // All shots on this target
    var shots: [TargetShot]

    // Target configuration
    let targetGeometry: TargetCropGeometry
    let targetType: TetrathlonTargetType

    // Image reference (for re-analysis)
    var imageFileName: String?

    // Computed metrics
    var totalScore: Int { shots.reduce(0) { $0 + $1.score } }
    var shotCount: Int { shots.count }

    // Separation of raw vs corrected
    var rawDetectedShots: [TargetShot] {
        shots.filter { $0.source == .autoDetected && !$0.wasManuallyAdjusted }
    }
    var userCorrectedShots: [TargetShot] {
        shots.filter { $0.wasManuallyAdjusted || $0.source == .manuallyAdded }
    }
}
```

---

## 9. Shot Pattern Analysis

### Current Implementation
**File**: `ShootingScannerComponents.swift:501-563`

```swift
private var patternFeedback: [PatternFeedback] {
    // Calculate average position
    let avgX = detectedHoles.map { $0.position.x }.reduce(0, +) / Double(detectedHoles.count)
    let avgY = detectedHoles.map { $0.position.y }.reduce(0, +) / Double(detectedHoles.count)

    // Calculate spread (standard deviation)
    let spreadX = sqrt(detectedHoles.map { pow($0.position.x - avgX, 2) }.reduce(0, +) / Double(detectedHoles.count))
    // ...
}
```

**Problem**: All calculations use image-relative coordinates (0.5 = center of image, not target center).

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Analysis uses image coords, not target coords | Bias calculations wrong if target not centered | Critical |
| No group center (MPI) calculation | Missing standard shooting metric | High |
| No extreme spread (max group size) | Missing standard metric | Medium |
| Spread thresholds are arbitrary | Not validated against real data | Low |

### Recommendation

**A. Proper Pattern Analysis Engine**
```swift
struct PatternAnalyzer {

    /// Analyze shot pattern in target-normalized coordinates
    static func analyze(shots: [TargetShot]) -> PatternAnalysis {
        guard !shots.isEmpty else {
            return PatternAnalysis.empty
        }

        let positions = shots.map { $0.position }

        // Mean Point of Impact (MPI)
        let mpiX = positions.map { $0.x }.reduce(0, +) / Double(positions.count)
        let mpiY = positions.map { $0.y }.reduce(0, +) / Double(positions.count)
        let mpi = NormalizedTargetPosition(x: mpiX, y: mpiY)

        // Distance from center (0,0 is target center)
        let distanceFromCenter = mpi.radialDistance

        // Standard deviation (group dispersion)
        let varianceX = positions.map { pow($0.x - mpiX, 2) }.reduce(0, +) / Double(positions.count)
        let varianceY = positions.map { pow($0.y - mpiY, 2) }.reduce(0, +) / Double(positions.count)
        let stdDevX = sqrt(varianceX)
        let stdDevY = sqrt(varianceY)

        // Extreme spread (max distance between any two shots)
        var extremeSpread: Double = 0
        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let dist = sqrt(dx*dx + dy*dy)
                extremeSpread = max(extremeSpread, dist)
            }
        }

        // Circular Error Probable (CEP) - radius containing 50% of shots
        let distancesFromMPI = positions.map { pos in
            sqrt(pow(pos.x - mpiX, 2) + pow(pos.y - mpiY, 2))
        }.sorted()
        let cep = distancesFromMPI[positions.count / 2]

        // Directional bias
        let horizontalBias = classifyBias(mpiX, thresholds: (0.05, 0.15))
        let verticalBias = classifyBias(mpiY, thresholds: (0.05, 0.15))

        return PatternAnalysis(
            meanPointOfImpact: mpi,
            distanceFromCenter: distanceFromCenter,
            standardDeviationX: stdDevX,
            standardDeviationY: stdDevY,
            extremeSpread: extremeSpread,
            circularErrorProbable: cep,
            horizontalBias: horizontalBias,
            verticalBias: verticalBias,
            shotCount: shots.count
        )
    }

    private static func classifyBias(_ value: Double, thresholds: (slight: Double, significant: Double)) -> DirectionalBias {
        if value > thresholds.significant { return .significantPositive }
        if value > thresholds.slight { return .slightPositive }
        if value < -thresholds.significant { return .significantNegative }
        if value < -thresholds.slight { return .slightNegative }
        return .centered
    }
}

struct PatternAnalysis: Codable {
    let meanPointOfImpact: NormalizedTargetPosition
    let distanceFromCenter: Double  // 0 = perfect center
    let standardDeviationX: Double
    let standardDeviationY: Double
    let extremeSpread: Double       // Max distance between any two shots
    let circularErrorProbable: Double // Radius containing 50% of shots
    let horizontalBias: DirectionalBias
    let verticalBias: DirectionalBias
    let shotCount: Int

    var groupingQuality: GroupingQuality {
        if extremeSpread < 0.1 && circularErrorProbable < 0.05 { return .excellent }
        if extremeSpread < 0.2 && circularErrorProbable < 0.1 { return .good }
        if extremeSpread < 0.3 { return .fair }
        return .poor
    }

    static let empty = PatternAnalysis(
        meanPointOfImpact: NormalizedTargetPosition(x: 0, y: 0),
        distanceFromCenter: 0,
        standardDeviationX: 0,
        standardDeviationY: 0,
        extremeSpread: 0,
        circularErrorProbable: 0,
        horizontalBias: .centered,
        verticalBias: .centered,
        shotCount: 0
    )
}

enum DirectionalBias: String, Codable {
    case significantNegative  // Far left or high
    case slightNegative       // Slightly left or high
    case centered
    case slightPositive       // Slightly right or low
    case significantPositive  // Far right or low

    var horizontalDescription: String {
        switch self {
        case .significantNegative: return "Far Left"
        case .slightNegative: return "Slightly Left"
        case .centered: return "Centered"
        case .slightPositive: return "Slightly Right"
        case .significantPositive: return "Far Right"
        }
    }

    var verticalDescription: String {
        switch self {
        case .significantNegative: return "High"
        case .slightNegative: return "Slightly High"
        case .centered: return "Centered"
        case .slightPositive: return "Slightly Low"
        case .significantPositive: return "Low"
        }
    }
}
```

---

## 10. Data Integrity and Re-analysis

### Current Implementation
**File**: `ShootingSession.swift:391-492`

```swift
@Model
final class TargetScanAnalysis {
    var shotPositionsJSON: Data?  // Raw positions

    // Derived metrics stored directly
    var averageX: Double = 0.5
    var spreadX: Double = 0
    // ...

    func calculateMetrics(from shots: [ScanShot], targetCenter: CGPoint) {
        // Calculates and stores metrics
        // Called once at save time
    }
}
```

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| Metrics stored redundantly | Can become stale if shots edited | Medium |
| No separation of raw vs corrected data | Cannot audit corrections | Medium |
| Re-analysis requires passing targetCenter | Center not stored | High |
| No versioning of analysis algorithm | Old data uses old algorithm | Low |

### Recommendation

**A. Immutable Raw Data + Computed Analysis**
```swift
@Model
final class TargetScanRecord {
    var id: UUID = UUID()
    var capturedAt: Date = Date()

    // Immutable raw data
    private(set) var rawShotsJSON: Data?      // Original detections
    private(set) var userCorrectionsJSON: Data? // User edits
    private(set) var targetGeometryJSON: Data?  // Crop & center info

    // Image reference
    var imageFileName: String?

    // Computed analysis (can be regenerated)
    var cachedAnalysisJSON: Data?
    var analysisVersion: Int = 1  // Increment when algorithm changes

    // Accessors
    var rawShots: [TargetShot] {
        guard let data = rawShotsJSON else { return [] }
        return (try? JSONDecoder().decode([TargetShot].self, from: data)) ?? []
    }

    var userCorrections: [ShotCorrection] {
        guard let data = userCorrectionsJSON else { return [] }
        return (try? JSONDecoder().decode([ShotCorrection].self, from: data)) ?? []
    }

    /// Apply corrections to raw data
    var finalShots: [TargetShot] {
        var shots = rawShots
        for correction in userCorrections {
            switch correction.action {
            case .delete(let id):
                shots.removeAll { $0.id == id }
            case .add(let shot):
                shots.append(shot)
            case .move(let id, let newPosition):
                if let index = shots.firstIndex(where: { $0.id == id }) {
                    var shot = shots[index]
                    shot.position = newPosition
                    shot.wasManuallyAdjusted = true
                    shots[index] = shot
                }
            }
        }
        return shots
    }

    /// Re-run analysis with current algorithm
    func reanalyze() -> PatternAnalysis {
        PatternAnalyzer.analyze(shots: finalShots)
    }
}

struct ShotCorrection: Codable {
    let id: UUID
    let timestamp: Date
    let action: CorrectionAction

    enum CorrectionAction: Codable {
        case delete(shotId: UUID)
        case add(shot: TargetShot)
        case move(shotId: UUID, newPosition: NormalizedTargetPosition)
    }
}
```

---

## 11. History and Aggregation

### Current Implementation
**File**: `ShootingCompetitionComponents.swift:220-373`

```swift
struct FreePracticeView: View {
    @State private var scannedTargets: [ScannedTarget] = []  // In-memory only
    // ...
}
```

The `ScannedTarget` is an in-memory struct, NOT persisted to SwiftData:
```swift
struct ScannedTarget: Identifiable {
    let scores: [Int]
    let timestamp: Date
    var holePositions: [CGPoint] = []  // Often empty!
}
```

`TargetScanAnalysis` IS persisted but:
- Not connected to `ScannedTarget`
- No UI to view historical analyses
- No aggregation capability

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| ScannedTarget not persisted | Session history lost on app close | Critical |
| No historical view | Cannot review past targets | High |
| No multi-target overlay | Cannot see patterns across sessions | High |
| holePositions often empty | Pattern analysis fails | High |

### Recommendation

**A. Persist All Target Scans**
```swift
// Modify FreePracticeView to use SwiftData
struct FreePracticeView: View {
    @Environment(\.modelContext) private var modelContext

    // Query persisted targets for current session
    @Query(
        filter: #Predicate<TargetScanRecord> { record in
            record.sessionId == currentSessionId
        },
        sort: \TargetScanRecord.capturedAt
    ) private var scannedTargets: [TargetScanRecord]

    @State private var currentSessionId = UUID()
    // ...
}
```

**B. Practice Session Model**
```swift
@Model
final class FreePracticeSession {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var notes: String = ""

    @Relationship(deleteRule: .cascade)
    var targetScans: [TargetScanRecord] = []

    // Aggregate metrics
    var totalShots: Int {
        targetScans.reduce(0) { $0 + $1.finalShots.count }
    }

    var averageScore: Double {
        let allScores = targetScans.flatMap { $0.finalShots.map { $0.score } }
        guard !allScores.isEmpty else { return 0 }
        return Double(allScores.reduce(0, +)) / Double(allScores.count)
    }

    /// Aggregate analysis across all targets in session
    func aggregateAnalysis() -> PatternAnalysis {
        let allShots = targetScans.flatMap { $0.finalShots }
        return PatternAnalyzer.analyze(shots: allShots)
    }
}
```

**C. History View**
```swift
struct ShootingHistoryView: View {
    @Query(sort: \FreePracticeSession.startDate, order: .reverse)
    private var sessions: [FreePracticeSession]

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRow(session: session)
                    }
                }
            }
            .navigationTitle("Practice History")
        }
    }
}

struct SessionDetailView: View {
    let session: FreePracticeSession
    @State private var selectedTargets: Set<UUID> = []
    @State private var showOverlay = false

    var body: some View {
        ScrollView {
            VStack {
                // Session summary
                SessionSummaryCard(session: session)

                // Target thumbnails (tap to select for overlay)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                    ForEach(session.targetScans) { target in
                        TargetThumbnail(
                            target: target,
                            isSelected: selectedTargets.contains(target.id)
                        )
                        .onTapGesture {
                            toggleSelection(target.id)
                        }
                    }
                }

                // Overlay button
                if selectedTargets.count > 1 {
                    Button("Overlay Selected Targets") {
                        showOverlay = true
                    }
                }
            }
        }
        .sheet(isPresented: $showOverlay) {
            MultiTargetOverlayView(
                targets: session.targetScans.filter { selectedTargets.contains($0.id) }
            )
        }
    }
}
```

**D. Multi-Target Overlay View**
```swift
struct MultiTargetOverlayView: View {
    let targets: [TargetScanRecord]

    var body: some View {
        ZStack {
            // Target background
            TargetBackgroundView()

            // Plot all shots from all targets
            ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                ForEach(target.finalShots) { shot in
                    Circle()
                        .fill(colorForTarget(index))
                        .frame(width: 8, height: 8)
                        .position(
                            x: (shot.position.x * 0.5 + 0.5) * size,
                            y: (0.5 - shot.position.y * 0.5) * size
                        )
                }
            }

            // Combined MPI
            let allShots = targets.flatMap { $0.finalShots }
            let analysis = PatternAnalyzer.analyze(shots: allShots)
            MPIMarker(position: analysis.meanPointOfImpact)
        }
    }

    private func colorForTarget(_ index: Int) -> Color {
        let colors: [Color] = [.red, .blue, .green, .orange, .purple]
        return colors[index % colors.count]
    }
}
```

---

## 12. Validation and Defensive Checks

### Current Implementation
Minimal validation exists:
```swift
// Only bounds clamping
let clampedPosition = CGPoint(
    x: max(0, min(1, normalizedPosition.x)),
    y: max(0, min(1, normalizedPosition.y))
)
```

### Gap Analysis
| Issue | Impact | Severity |
|-------|--------|----------|
| No validation for shots outside target | Invalid data accepted silently | Medium |
| No detection of implausible patterns | Garbage data not flagged | Medium |
| No warning for too many/few shots | User might miss shots | Low |

### Recommendation

**A. Shot Validation**
```swift
struct ShotValidator {

    struct ValidationResult {
        let isValid: Bool
        let warnings: [Warning]
        let errors: [Error]

        enum Warning {
            case shotNearEdge(shotId: UUID)
            case possibleOverlap(shot1: UUID, shot2: UUID)
            case unusualGroupSize(expected: Int, actual: Int)
        }

        enum Error {
            case shotOutsideTarget(shotId: UUID, distance: Double)
            case implausibleMPI(distance: Double)
            case insufficientShots(count: Int, minimum: Int)
        }
    }

    static func validate(
        shots: [TargetShot],
        expectedShotCount: Int? = nil
    ) -> ValidationResult {
        var warnings: [ValidationResult.Warning] = []
        var errors: [ValidationResult.Error] = []

        // Check each shot
        for shot in shots {
            let distance = shot.position.radialDistance

            // Error: Shot clearly outside target
            if distance > 1.2 {  // 20% outside target edge
                errors.append(.shotOutsideTarget(shotId: shot.id, distance: distance))
            }
            // Warning: Shot near edge (might be a miss marked as hit)
            else if distance > 0.95 {
                warnings.append(.shotNearEdge(shotId: shot.id))
            }
        }

        // Check for overlapping shots (possible duplicate detection)
        for i in 0..<shots.count {
            for j in (i+1)..<shots.count {
                let dx = shots[i].position.x - shots[j].position.x
                let dy = shots[i].position.y - shots[j].position.y
                let dist = sqrt(dx*dx + dy*dy)

                if dist < 0.02 {  // Very close together
                    warnings.append(.possibleOverlap(shot1: shots[i].id, shot2: shots[j].id))
                }
            }
        }

        // Check shot count
        if let expected = expectedShotCount {
            if shots.count != expected {
                warnings.append(.unusualGroupSize(expected: expected, actual: shots.count))
            }
        }

        // Check MPI plausibility
        let analysis = PatternAnalyzer.analyze(shots: shots)
        if analysis.distanceFromCenter > 0.8 {
            errors.append(.implausibleMPI(distance: analysis.distanceFromCenter))
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }
}
```

**B. Validation UI**
```swift
struct ValidationBanner: View {
    let result: ShotValidator.ValidationResult

    var body: some View {
        if !result.isValid {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Validation Issues")
                        .font(.headline)
                }

                ForEach(result.errors, id: \.self) { error in
                    Text(error.description)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                ForEach(result.warnings, id: \.self) { warning in
                    Text(warning.description)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
```

---

## Prioritized Improvement Plan

### Phase 1: Foundation (Critical - Blocks All Analysis)
**Goal**: Establish correct coordinate system and persistence

1. **Define NormalizedTargetPosition** type
2. **Create TargetCropGeometry** to persist crop and center
3. **Add TargetCoordinateTransformer** for conversions
4. **Update DetectedHole to use target coordinates**
5. **Persist target geometry with TargetScanAnalysis**

**Effort**: ~3-4 hours
**Files**: New `TargetCoordinates.swift`, modify `ShootingScannerComponents.swift`

### Phase 2: Center Confirmation
**Goal**: Allow user to verify/adjust detected center

6. **Add CenterConfirmationView** after cropping
7. **Add draggable center marker**
8. **Add scoring ring overlay for visual confirmation**
9. **Persist confirmed center in TargetAlignment**

**Effort**: ~2-3 hours
**Files**: Modify `ShootingScannerComponents.swift`

### Phase 3: Fix Tap Interaction
**Goal**: Make manual correction reliable

10. **Fix hit testing to account for zoom/pan**
11. **Simplify delete interaction** (remove confirmation dialog)
12. **Add visual feedback for selected state**
13. **Add undo functionality**

**Effort**: ~2 hours
**Files**: Modify `InteractiveAnnotatedTargetImage`, `DraggableHoleMarker`

### Phase 4: Restore Assisted Detection
**Goal**: Enable auto-detection in assistive mode

14. **Implement adaptive preprocessing**
15. **Add confidence scoring**
16. **Create three-tier display** (auto-accept, suggest, manual)
17. **Add bulk accept/reject actions**
18. **Re-enable detection after crop confirmation**

**Effort**: ~4-5 hours
**Files**: Modify `TargetAnalyzer`, new `AssistedHoleDetector.swift`

### Phase 5: History and Aggregation
**Goal**: Enable pattern tracking over time

19. **Create FreePracticeSession model**
20. **Persist TargetScanRecord with SwiftData**
21. **Add history view with target list**
22. **Add multi-target overlay view**
23. **Add session-level aggregate analysis**

**Effort**: ~3-4 hours
**Files**: Modify `ShootingSession.swift`, new `ShootingHistoryView.swift`

### Phase 6: Polish and Validation
**Goal**: Ensure data quality and robustness

24. **Add ShotValidator**
25. **Add validation banner UI**
26. **Add physical target model for mm scaling**
27. **Update AI coaching to use target coordinates**

**Effort**: ~2 hours
**Files**: New `ShotValidator.swift`, modify analysis views

---

## Total Estimated Effort

| Phase | Hours |
|-------|-------|
| Phase 1: Foundation | 3-4 |
| Phase 2: Center Confirmation | 2-3 |
| Phase 3: Fix Tap Interaction | 2 |
| Phase 4: Assisted Detection | 4-5 |
| Phase 5: History/Aggregation | 3-4 |
| Phase 6: Validation | 2 |
| **Total** | **16-20 hours** |

---

## Files to Create/Modify Summary

### New Files
- `Models/TargetCoordinates.swift` - Coordinate types and transformers
- `Services/AssistedHoleDetector.swift` - Robust detection pipeline
- `Services/PatternAnalyzer.swift` - Analysis algorithms
- `Services/ShotValidator.swift` - Validation logic
- `Views/Shooting/ShootingHistoryView.swift` - Historical data views
- `Views/Shooting/CenterConfirmationView.swift` - Center adjustment UI

### Modified Files
- `Models/ShootingSession.swift` - Add FreePracticeSession, enhance TargetScanAnalysis
- `Views/Disciplines/ShootingScannerComponents.swift` - Major changes to:
  - `ManualCropView` - Persist geometry
  - `InteractiveAnnotatedTargetImage` - Fix hit testing
  - `DraggableHoleMarker` - Simplify interactions
  - `TargetScannerView` - Add center confirmation step
  - `TargetAnalyzer` - Re-enable with confidence scoring
- `Views/Disciplines/ShootingCompetitionComponents.swift` - Connect to persisted data

---

## Success Criteria

1. **Cropping**: Crop geometry persisted and used for all coordinate transformations
2. **Coordinates**: All shot positions stored in target-centric normalized coordinates
3. **Scoring**: Scores calculated from target-relative positions, not image positions
4. **Detection**: Auto-detection identifies 80%+ of holes with >0.7 confidence
5. **Interaction**: Delete a hole with 2 taps maximum (no dialog)
6. **History**: View any past target, overlay multiple targets
7. **Validation**: Warning shown for shots outside target boundary
8. **Analysis**: Pattern metrics (MPI, spread, bias) correct for off-center crops

---

## Appendix: Stadium Geometry Implementation (Build 67+)

### Overview

As of Build 67, Tetrathlon target geometry uses **stadium shapes** (running track / discorectangle) instead of ellipses. This matches the actual paper target design where scoring rings consist of:
- Two semicircles (top and bottom)
- Two straight vertical lines connecting them

### Key Files

| File | Purpose |
|------|---------|
| `Models/TargetGeometry.swift` | `StadiumGeometry` struct, `TetrathlonTargetGeometry` |
| `Services/Shooting/RingAwareAnalyzer.swift` | Ring classification using stadium distance |
| `Views/Shooting/ShotPatternVisualizationView.swift` | `StadiumRingShape` for visualization |

### Ring Boundaries (Calibrated)

| Score | Normalized Radius | Description |
|-------|------------------|-------------|
| 10 | 0.12 | Bull / innermost |
| 8 | 0.35 | |
| 6 | 0.55 | |
| 4 | 0.75 | |
| 2 | 1.0 | Outer boundary |

### Distance Calculation

Ring membership uses **distance to nearest boundary point**:

1. **Straight section** (|y| <= halfStraight): Horizontal distance to side boundary
2. **Semicircle region** (|y| > halfStraight): Radial distance from semicircle center

```swift
func signedDistance(to point: CGPoint) -> Double {
    if localY < -halfStraight {
        // Top semicircle region
        return distanceToCenter - semicircleRadius
    } else if localY > halfStraight {
        // Bottom semicircle region
        return distanceToCenter - semicircleRadius
    } else {
        // Straight section
        return abs(localX) - semicircleRadius
    }
}
```

### Validation

- `validateBullClassification(shots:)` - Returns true if 75%+ of visually central shots classify as 10
- `debugClassification(for:)` - Returns detailed classification info for debugging

### Developer Overlay

Enable `showValidationOverlay = true` on `ShotPatternVisualizationView` to see:
- Ring classification label next to each shot
- Validation status panel

### Backward Compatibility

- Stored shot coordinates unchanged (normalized -1 to 1)
- Historical patterns re-classified with corrected geometry on load
- No migration required
