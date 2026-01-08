#!/bin/bash
#
# TrackRide App Store Screenshot Generator
# ========================================
#
# This script captures screenshots from iOS and watchOS simulators
# for App Store Connect submission.
#
# Prerequisites:
# 1. Run the app in simulator and go to Settings > Generate Screenshot Data
# 2. Navigate to the screen you want to capture
# 3. Run this script with the desired screen name
#
# Usage:
#   ./generate_screenshots.sh                    # Capture current screen
#   ./generate_screenshots.sh "screen_name"      # Capture with custom name
#

set -e

# Configuration
OUTPUT_DIR="${PWD}/AppStoreScreenshots"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# iPhone simulator (6.9" display - required for App Store)
IPHONE_DEVICE="iPhone 17 Pro Max"
IPHONE_UDID=$(xcrun simctl list devices available | grep "${IPHONE_DEVICE}" | head -1 | grep -oE '[A-F0-9-]{36}')

# Apple Watch simulator (required for watchOS apps)
WATCH_DEVICE="Apple Watch Series 11 (46mm)"
WATCH_UDID=$(xcrun simctl list devices available | grep "${WATCH_DEVICE}" | head -1 | grep -oE '[A-F0-9-]{36}')

# Screen name from argument or default
SCREEN_NAME="${1:-screenshot}"

# Create output directories
mkdir -p "${OUTPUT_DIR}/iPhone_6.9"
mkdir -p "${OUTPUT_DIR}/Apple_Watch_46mm"

echo "==============================================="
echo "TrackRide Screenshot Generator"
echo "==============================================="
echo ""
echo "Output directory: ${OUTPUT_DIR}"
echo "Screen name: ${SCREEN_NAME}"
echo ""

# App bundle identifiers
IPHONE_BUNDLE_ID="MyHorse.TrackRide"
WATCH_BUNDLE_ID="MyHorse.TrackRide.watchkitapp"

# Launch apps if --launch flag provided or if this is the first run
if [ "$2" = "--launch" ] || [ "$SCREEN_NAME" = "01_Home" ]; then
    echo "Launching apps..."
    if [ -n "${IPHONE_UDID}" ]; then
        xcrun simctl launch "${IPHONE_UDID}" "${IPHONE_BUNDLE_ID}" 2>/dev/null || true
    fi
    if [ -n "${WATCH_UDID}" ]; then
        xcrun simctl launch "${WATCH_UDID}" "${WATCH_BUNDLE_ID}" 2>/dev/null || true
    fi
    echo "Waiting for apps to load..."
    sleep 3
fi

# Capture iPhone screenshot
if [ -n "${IPHONE_UDID}" ]; then
    echo "Capturing iPhone 17 Pro Max screenshot..."
    IPHONE_FILE="${OUTPUT_DIR}/iPhone_6.9/${SCREEN_NAME}_${TIMESTAMP}.png"
    xcrun simctl io "${IPHONE_UDID}" screenshot "${IPHONE_FILE}"
    echo "  Saved: ${IPHONE_FILE}"
else
    echo "WARNING: ${IPHONE_DEVICE} simulator not found"
fi

# Capture Apple Watch screenshot
if [ -n "${WATCH_UDID}" ]; then
    echo "Capturing Apple Watch Series 11 screenshot..."
    WATCH_FILE="${OUTPUT_DIR}/Apple_Watch_46mm/${SCREEN_NAME}_${TIMESTAMP}.png"
    xcrun simctl io "${WATCH_UDID}" screenshot "${WATCH_FILE}"
    echo "  Saved: ${WATCH_FILE}"
else
    echo "WARNING: ${WATCH_DEVICE} simulator not found"
fi

echo ""
echo "==============================================="
echo "Screenshot capture complete!"
echo "==============================================="
echo ""
echo "For App Store Connect, you need these screenshots:"
echo ""
echo "IPHONE (Required: 6.9\" display):"
echo "  1. Home/Disciplines screen"
echo "  2. Tracking view with big start button"
echo "  3. Live ride map with gait colors"
echo "  4. Ride detail with stats"
echo "  5. Competition calendar"
echo "  6. Statistics/Analytics view"
echo "  7. Horse profile"
echo "  8. Running view"
echo "  9. Swimming view"
echo "  10. AI Insights"
echo ""
echo "APPLE WATCH (Required: 46mm display):"
echo "  1. Riding control view"
echo "  2. Live heart rate display"
echo "  3. Discipline selection"
echo ""
echo "Recommended screenshot workflow:"
echo "  1. Launch app in simulator"
echo "  2. Go to Settings > Generate Screenshot Data"
echo "  3. Navigate to each screen"
echo "  4. Run: ./generate_screenshots.sh 'screen_name'"
echo ""
