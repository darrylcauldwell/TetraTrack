#!/bin/bash
#
# DEPRECATED: Use automated_screenshots.sh instead
#
# This script has been replaced by the fully automated pipeline.
# Run: ./Scripts/automated_screenshots.sh
#
# The new script:
#   - Auto-generates demo data via -screenshotMode launch argument
#   - Runs UI tests that navigate and capture all screens
#   - Extracts screenshots from .xcresult into AppStoreScreenshots/
#   - No manual navigation or prompts required
#

echo "This script is deprecated. Use the automated pipeline instead:"
echo ""
echo "  ./Scripts/automated_screenshots.sh"
echo ""
echo "Options:"
echo "  --iphone-only    Only capture iPhone screenshots"
echo "  --ipad-only      Only capture iPad screenshots"
echo "  --skip-tests     Extract from existing .xcresult without re-running tests"
echo ""
exit 1
