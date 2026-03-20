#!/bin/bash
#
# TetraTrack - simctl-based App Store Screenshot Pipeline
# ========================================================
#
# Captures screenshots by launching the app with --screenshot-mode --screenshot-screen <name>,
# rendering each target screen directly via ScreenshotRouterView, and capturing with simctl io.
#
# No XCTest involved. Each screen launch: in-memory ModelContainer → demo data → target screen → capture → terminate.
#
# Usage:
#   ./Scripts/screenshots.sh                # All devices
#   ./Scripts/screenshots.sh --iphone-only  # iPhone only
#   ./Scripts/screenshots.sh --ipad-only    # iPad only
#   ./Scripts/screenshots.sh --keep-simulators  # Don't delete simulators after
#
# Output: fastlane/screenshots/en-GB/ (copied to en-US/)
#

set -euo pipefail

# -----------------------------------------------
# Configuration
# -----------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SHARED_LIB="${HOME}/.claude/shared/screenshot-lib.sh"

if [ ! -f "$SHARED_LIB" ]; then
    echo "Error: Shared screenshot library not found at ${SHARED_LIB}"
    exit 1
fi
source "$SHARED_LIB"

BUNDLE_ID="dev.dreamfold.TetraTrack"
PROJECT="${PROJECT_DIR}/TetraTrack.xcodeproj"
SCHEME="TetraTrack"
DERIVED_DATA="/tmp/TetraTrackScreenshotBuild"
OUTPUT_DIR="${PROJECT_DIR}/fastlane/screenshots"
SETTLE_TIME=4

# Device configurations: name, device type ID
IPHONE_67_NAME="Screenshot_iPhone_6.7"
IPHONE_67_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"

IPHONE_61_NAME="Screenshot_iPhone_6.1"
IPHONE_61_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"

IPAD_13_NAME="Screenshot_iPad_13"
IPAD_13_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5"

# iPhone screens (capture views available)
IPHONE_SCREENS=(
    "home"
    "riding"
    "ride-detail"
    "competitions"
    "horse-profile"
    "running"
    "swimming"
    "shooting"
    "session-insights"
    "live-sharing"
)

# iPad screens (review-only mode, no capture views)
IPAD_SCREENS=(
    "home"
    "training-history"
    "ride-detail"
    "session-insights"
    "competitions"
    "competition-detail"
    "tasks"
    "live-sharing"
    "horse-list"
    "horse-detail"
)

# Screenshot filenames (matched by index to screen arrays)
IPHONE_FILENAMES=(
    "01_Home_Disciplines"
    "02_Riding_BigButton"
    "03_Ride_Detail"
    "04_Competition_Calendar"
    "05_Horse_Profile"
    "06_Running"
    "07_Swimming"
    "08_Shooting"
    "09_Session_Insights"
    "10_Live_Sharing"
)

IPAD_FILENAMES=(
    "iPad_01_Home"
    "iPad_02_Training_History"
    "iPad_03_Ride_Detail"
    "iPad_04_Session_Insights"
    "iPad_05_Competitions"
    "iPad_06_Competition_Detail"
    "iPad_07_Tasks"
    "iPad_08_Live_Sharing"
    "iPad_09_Horse_List"
    "iPad_10_Horse_Detail"
)

# -----------------------------------------------
# Parse Arguments
# -----------------------------------------------

RUN_IPHONE=true
RUN_IPAD=true
KEEP_SIMULATORS=false

for arg in "$@"; do
    case $arg in
        --iphone-only) RUN_IPAD=false ;;
        --ipad-only) RUN_IPHONE=false ;;
        --keep-simulators) KEEP_SIMULATORS=true ;;
    esac
done

echo "==============================================="
echo "TetraTrack Screenshot Pipeline (simctl)"
echo "==============================================="
echo ""

# -----------------------------------------------
# Build Once
# -----------------------------------------------

echo "Step 1: Building app..."
screenshot_build_app "$PROJECT" "$SCHEME" "$DERIVED_DATA"

APP_BUNDLE=$(screenshot_find_app_bundle "$DERIVED_DATA" "TetraTrack")
if [ -z "$APP_BUNDLE" ]; then
    echo "Error: Could not find TetraTrack.app in derived data"
    exit 1
fi
echo "App bundle: ${APP_BUNDLE}"
echo ""

# -----------------------------------------------
# Capture Function
# -----------------------------------------------

capture_device() {
    local sim_name="$1"
    local sim_type="$2"
    local label="$3"
    local -n screens_ref=$4
    local -n filenames_ref=$5
    local output_subdir="$6"

    local dest="${OUTPUT_DIR}/${output_subdir}"
    mkdir -p "$dest"

    echo "[$label] Creating simulator: ${sim_name}..."
    local udid
    udid=$(screenshot_create_simulator "$sim_name" "$sim_type")
    echo "[$label] Simulator UDID: ${udid}"

    echo "[$label] Booting simulator..."
    screenshot_boot_simulator "$udid"
    screenshot_override_status_bar "$udid"

    echo "[$label] Installing app..."
    screenshot_install_app "$udid" "$APP_BUNDLE"

    echo "[$label] Capturing ${#screens_ref[@]} screens..."
    for i in "${!screens_ref[@]}"; do
        local screen="${screens_ref[$i]}"
        local filename="${filenames_ref[$i]}"
        local output_path="${dest}/${filename}.png"
        screenshot_capture_screen "$udid" "$BUNDLE_ID" "$screen" "$output_path" "$SETTLE_TIME"
    done

    if [ "$KEEP_SIMULATORS" = false ]; then
        echo "[$label] Cleaning up simulator..."
        screenshot_delete_simulator "$udid"
    else
        echo "[$label] Keeping simulator (UDID: ${udid})"
    fi

    echo "[$label] Done — ${#screens_ref[@]} screenshots captured"
    echo ""
}

# -----------------------------------------------
# Capture Screenshots
# -----------------------------------------------

echo "Step 2: Capturing screenshots..."
echo ""

if [ "$RUN_IPHONE" = true ]; then
    # Capture on 6.7" (primary iPhone size for App Store)
    capture_device "$IPHONE_67_NAME" "$IPHONE_67_TYPE" "iPhone 6.7\"" \
        IPHONE_SCREENS IPHONE_FILENAMES "en-GB"

    # Capture on 6.1" (secondary iPhone size)
    capture_device "$IPHONE_61_NAME" "$IPHONE_61_TYPE" "iPhone 6.1\"" \
        IPHONE_SCREENS IPHONE_FILENAMES "en-GB/6.1"
fi

if [ "$RUN_IPAD" = true ]; then
    capture_device "$IPAD_13_NAME" "$IPAD_13_TYPE" "iPad 13\"" \
        IPAD_SCREENS IPAD_FILENAMES "en-GB"
fi

# -----------------------------------------------
# Copy Locale
# -----------------------------------------------

echo "Step 3: Copying en-GB to en-US..."
screenshot_copy_locale "${OUTPUT_DIR}/en-GB" "${OUTPUT_DIR}/en-US"
if [ -d "${OUTPUT_DIR}/en-GB/6.1" ]; then
    screenshot_copy_locale "${OUTPUT_DIR}/en-GB/6.1" "${OUTPUT_DIR}/en-US/6.1"
fi
echo ""

# -----------------------------------------------
# Summary
# -----------------------------------------------

echo "==============================================="
echo "Screenshot Pipeline Complete"
echo "==============================================="
echo ""

if [ -d "${OUTPUT_DIR}/en-GB" ]; then
    total_count=$(find "${OUTPUT_DIR}/en-GB" -maxdepth 1 -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    echo "Total: ${total_count} screenshots in en-GB/ (copied to en-US/)"
    echo ""
    find "${OUTPUT_DIR}/en-GB" -maxdepth 1 -name "*.png" -exec basename {} \; | sort | while read f; do echo "  $f"; done
    echo ""
fi

echo "Output: ${OUTPUT_DIR}/en-GB/ and ${OUTPUT_DIR}/en-US/"
echo ""
echo "Note: Watch screenshots must be captured manually."
echo "Upload to App Store Connect with: fastlane upload_metadata"
