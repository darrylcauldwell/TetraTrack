#!/bin/bash
#
# TetraTrack - Fully Automated App Store Screenshot Pipeline
# ==========================================================
#
# This script runs UI tests that auto-generate demo data (via -screenshotMode),
# navigate through the app, capture screenshots as XCTest attachments, then
# extracts them from the .xcresult bundle into AppStoreScreenshots/.
#
# No manual steps required. Just run:
#   cd TetraTrack && ./Scripts/automated_screenshots.sh
#
# Options:
#   --iphone-only    Only capture iPhone screenshots
#   --ipad-only      Only capture iPad screenshots
#   --skip-tests     Skip running tests, just extract from existing .xcresult
#
# Output goes to fastlane/screenshots/en-GB/ (and copied to en-US/).
# The fastlane upload_metadata lane reads from there.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${PROJECT_DIR}/fastlane/screenshots"

IPHONE_RESULT="/tmp/TetraTrackScreenshots.xcresult"
IPAD_RESULT="/tmp/TetraTrackiPadScreenshots.xcresult"

IPHONE_DEVICE="${SCREENSHOT_IPHONE_DEVICE:-iPhone 17 Pro Max}"
IPAD_DEVICE="${SCREENSHOT_IPAD_DEVICE:-iPad Pro 13-inch (M4)}"

# Parse arguments
RUN_IPHONE=true
RUN_IPAD=true
SKIP_TESTS=false

for arg in "$@"; do
    case $arg in
        --iphone-only) RUN_IPAD=false ;;
        --ipad-only) RUN_IPHONE=false ;;
        --skip-tests) SKIP_TESTS=true ;;
    esac
done

echo "==============================================="
echo "TetraTrack Automated Screenshot Pipeline"
echo "==============================================="
echo ""

# Create output directories (en-GB is primary, en-US is copied after)
mkdir -p "${OUTPUT_DIR}/en-GB"
mkdir -p "${OUTPUT_DIR}/en-US"

# -----------------------------------------------
# Step 1: Run UI Tests
# -----------------------------------------------

run_tests() {
    local device="$1"
    local result_path="$2"
    local test_class="$3"
    local label="$4"

    echo "[$label] Running UI tests on ${device}..."

    # Remove previous result bundle
    rm -rf "${result_path}"

    xcodebuild \
        -project "${PROJECT_DIR}/TetraTrack.xcodeproj" \
        -scheme TetraTrack \
        -sdk iphonesimulator \
        -destination "platform=iOS Simulator,name=${device}" \
        -resultBundlePath "${result_path}" \
        -only-testing:"TetraTrackUITests/${test_class}" \
        test 2>&1 | tail -5

    echo "[$label] Tests complete. Result bundle: ${result_path}"
}

if [ "$SKIP_TESTS" = false ]; then
    if [ "$RUN_IPHONE" = true ]; then
        run_tests "$IPHONE_DEVICE" "$IPHONE_RESULT" "ScreenshotTests" "iPhone"
    fi

    if [ "$RUN_IPAD" = true ]; then
        run_tests "$IPAD_DEVICE" "$IPAD_RESULT" "iPadScreenshotTests" "iPad"
    fi
else
    echo "Skipping tests, extracting from existing .xcresult bundles..."
fi

# -----------------------------------------------
# Step 2: Extract Screenshots from .xcresult
# -----------------------------------------------

extract_screenshots() {
    local result_path="$1"
    local output_subdir="$2"
    local label="$3"
    local dest="${OUTPUT_DIR}/${output_subdir}"

    if [ ! -d "${result_path}" ]; then
        echo "[$label] No result bundle found at ${result_path} - skipping"
        return
    fi

    echo ""
    echo "[$label] Extracting screenshots from ${result_path}..."

    # Get the list of test attachments using xcresulttool
    # Export all attachments to a temp directory
    local tmp_export="/tmp/TetraTrackScreenshotExport_${label}"
    rm -rf "${tmp_export}"
    mkdir -p "${tmp_export}"

    # Use xcresulttool to export attachments
    xcrun xcresulttool export attachments \
        --path "${result_path}" \
        --output-path "${tmp_export}" 2>/dev/null || true

    # The export creates files with UUID names and a manifest.json
    local manifest="${tmp_export}/manifest.json"

    if [ ! -f "${manifest}" ]; then
        echo "[$label] No manifest.json found - trying legacy export..."
        # Fallback: try the older xcresulttool format
        xcrun xcresulttool export \
            --type file \
            --path "${result_path}" \
            --output-path "${tmp_export}" 2>/dev/null || true
    fi

    if [ -f "${manifest}" ]; then
        echo "[$label] Found manifest.json, extracting named screenshots..."

        # Parse manifest.json to map attachment names to exported files
        # manifest format: array of { testIdentifier, attachments: [{ exportedFileName, suggestedHumanReadableName }] }
        python3 -c "
import json, shutil, os, sys

manifest_path = '${manifest}'
export_dir = '${tmp_export}'
dest_dir = '${dest}'

with open(manifest_path) as f:
    tests = json.load(f)

count = 0
for test in tests:
    for att in test.get('attachments', []):
        exported = att.get('exportedFileName', '')
        suggested = att.get('suggestedHumanReadableName', '')
        if not exported or not suggested:
            continue

        # Extract clean name: '01_Home_Disciplines_0_UUID.png' -> '01_Home_Disciplines.png'
        # Remove trailing '_0_UUID' pattern
        parts = suggested.rsplit('.', 1)
        name_part = parts[0]
        ext = parts[1] if len(parts) > 1 else 'png'

        # Split on '_' and remove the last two segments (index and UUID)
        segments = name_part.split('_')
        if len(segments) >= 3:
            # Find where the numeric index + UUID starts (last 2 segments)
            # UUID is 36 chars with hyphens
            if len(segments[-1]) >= 30 and len(segments[-2]) <= 2:
                clean_name = '_'.join(segments[:-2])
            else:
                clean_name = name_part
        else:
            clean_name = name_part

        src = os.path.join(export_dir, exported)
        dst = os.path.join(dest_dir, f'{clean_name}.{ext}')

        if os.path.exists(src):
            shutil.copy2(src, dst)
            count += 1
            print(f'  {clean_name}.{ext}')

print(f'Extracted {count} screenshots to {dest_dir}')
"

        # Also copy the manifest for reference
        cp "${manifest}" "${dest}/manifest.json"
    else
        echo "[$label] No manifest found. Copying all PNG files..."
        # Fallback: just copy any PNG files found
        local count=0
        for png in "${tmp_export}"/*.png; do
            if [ -f "$png" ]; then
                cp "$png" "${dest}/"
                count=$((count + 1))
            fi
        done
        echo "[$label] Copied ${count} PNG files"
    fi

    # Cleanup temp directory
    rm -rf "${tmp_export}"
}

if [ "$RUN_IPHONE" = true ]; then
    extract_screenshots "$IPHONE_RESULT" "en-GB" "iPhone"
fi

if [ "$RUN_IPAD" = true ]; then
    extract_screenshots "$IPAD_RESULT" "en-GB" "iPad"
fi

# -----------------------------------------------
# Step 3: Copy en-GB to en-US
# -----------------------------------------------

echo ""
echo "Copying en-GB screenshots to en-US..."
cp -f "${OUTPUT_DIR}/en-GB/"*.png "${OUTPUT_DIR}/en-US/" 2>/dev/null || true

# -----------------------------------------------
# Step 4: Summary
# -----------------------------------------------

echo ""
echo "==============================================="
echo "Screenshot Pipeline Complete"
echo "==============================================="
echo ""

if [ -d "${OUTPUT_DIR}/en-GB" ]; then
    total_count=$(ls -1 "${OUTPUT_DIR}/en-GB/"*.png 2>/dev/null | wc -l | tr -d ' ')
    echo "Total: ${total_count} screenshots in en-GB/ (copied to en-US/)"
    echo ""
    ls -1 "${OUTPUT_DIR}/en-GB/"*.png 2>/dev/null | while read f; do echo "  $(basename "$f")"; done
    echo ""
fi

echo "Output: ${OUTPUT_DIR}/en-GB/ and ${OUTPUT_DIR}/en-US/"
echo ""
echo "Note: Watch screenshots must be captured manually (no UI test automation for watchOS)."
echo ""
echo "Upload to App Store Connect with: fastlane upload_metadata"
