#!/bin/bash
#
# TetraTrack - Capture All App Store Screenshots
# =============================================
#
# This script guides you through capturing all required screenshots.
# Run this script and follow the prompts.
#

set -e

OUTPUT_DIR="${PWD}/AppStoreScreenshots"
IPHONE_UDID="3790E23D-277F-4255-AF0A-226B20D11A81"
WATCH_UDID="03C2C62D-FC46-48AD-A5D0-26807E4B27D8"

mkdir -p "${OUTPUT_DIR}/iPhone_6.9"
mkdir -p "${OUTPUT_DIR}/Apple_Watch_46mm"

capture_iphone() {
    local name=$1
    local file="${OUTPUT_DIR}/iPhone_6.9/${name}.png"
    xcrun simctl io "${IPHONE_UDID}" screenshot "${file}"
    echo "✓ Saved: ${file}"
}

capture_watch() {
    local name=$1
    local file="${OUTPUT_DIR}/Apple_Watch_46mm/${name}.png"
    xcrun simctl io "${WATCH_UDID}" screenshot "${file}"
    echo "✓ Saved: ${file}"
}

wait_for_enter() {
    echo ""
    read -p "Press ENTER when ready to capture..."
}

echo "==============================================="
echo "TetraTrack App Store Screenshot Capture"
echo "==============================================="
echo ""
echo "IMPORTANT: Before starting, go to Settings in the app"
echo "and tap 'Generate Screenshot Data' to create sample data."
echo ""
echo "This script will guide you through capturing:"
echo "  - 10 iPhone screenshots"
echo "  - 3 Apple Watch screenshots"
echo ""
read -p "Press ENTER to begin..."

# iPhone Screenshots
echo ""
echo "=== iPhone Screenshots ==="
echo ""

echo "1/10: HOME SCREEN - Show the main Disciplines grid"
echo "      Navigate to: Main app home screen"
wait_for_enter
capture_iphone "01_Home_Disciplines"

echo ""
echo "2/10: RIDING START - Show the big start button"
echo "      Navigate to: Tap 'Riding' card"
wait_for_enter
capture_iphone "02_Riding_Start_Button"

echo ""
echo "3/10: TRAINING HISTORY - Show ride history list"
echo "      Navigate to: Go back, tap 'Training History'"
wait_for_enter
capture_iphone "03_Training_History"

echo ""
echo "4/10: RIDE DETAIL - Show a completed ride with map and stats"
echo "      Navigate to: Tap on any ride in the history"
wait_for_enter
capture_iphone "04_Ride_Detail"

echo ""
echo "5/10: COMPETITION CALENDAR - Show upcoming events"
echo "      Navigate to: Go back to home, tap 'Competition Calendar'"
wait_for_enter
capture_iphone "05_Competition_Calendar"

echo ""
echo "6/10: HORSE PROFILE - Show a horse's profile"
echo "      Navigate to: Settings > My Horses > tap a horse"
wait_for_enter
capture_iphone "06_Horse_Profile"

echo ""
echo "7/10: RUNNING - Show the running discipline view"
echo "      Navigate to: Home > Running"
wait_for_enter
capture_iphone "07_Running"

echo ""
echo "8/10: SWIMMING - Show the swimming discipline view"
echo "      Navigate to: Home > Swimming"
wait_for_enter
capture_iphone "08_Swimming"

echo ""
echo "9/10: SHOOTING - Show the shooting discipline view"
echo "      Navigate to: Home > Shooting"
wait_for_enter
capture_iphone "09_Shooting"

echo ""
echo "10/10: AI INSIGHTS or FAMILY SAFETY"
echo "       Navigate to: Home > Insights OR Home > Family Tracking"
wait_for_enter
capture_iphone "10_Insights_Or_Family"

# Apple Watch Screenshots
echo ""
echo "=== Apple Watch Screenshots ==="
echo ""
echo "Switch to the Watch Simulator window"
echo ""

echo "1/3: RIDE CONTROL - Main riding controls with start button"
echo "     Navigate to: Main Watch app screen"
wait_for_enter
capture_watch "01_Watch_Ride_Control"

echo ""
echo "2/3: HEART RATE - Live heart rate display (if available)"
echo "     Navigate to: Start a ride or show heart rate screen"
wait_for_enter
capture_watch "02_Watch_Heart_Rate"

echo ""
echo "3/3: STATS DISPLAY - Show live ride statistics"
echo "     Navigate to: Any stats display on watch"
wait_for_enter
capture_watch "03_Watch_Stats"

echo ""
echo "==============================================="
echo "Screenshot capture complete!"
echo "==============================================="
echo ""
echo "Screenshots saved to: ${OUTPUT_DIR}"
echo ""
echo "iPhone screenshots (6.9\" - 1320x2868):"
ls -la "${OUTPUT_DIR}/iPhone_6.9/"
echo ""
echo "Apple Watch screenshots (46mm - 396x484):"
ls -la "${OUTPUT_DIR}/Apple_Watch_46mm/"
echo ""
echo "Next steps:"
echo "1. Review screenshots in ${OUTPUT_DIR}"
echo "2. Upload to App Store Connect"
echo "3. Add captions from AppStoreMetadata.md"
