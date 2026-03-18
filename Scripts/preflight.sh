#!/bin/bash
#
# preflight.sh - Local pre-push validation for TetraTrack
#
# Runs lint checks, relationship validation, version consistency,
# and metadata validation before pushing.
#
# Usage:
#   ./Scripts/preflight.sh          # Full check (~60-90s): lint + tests
#   ./Scripts/preflight.sh --quick  # Lint only (~5-10s): skip unit tests
#
# Optional git hook:
#   ln -sf ../../Scripts/preflight.sh .git/hooks/pre-push

set -euo pipefail

# Resolve symlinks (needed when invoked as .git/hooks/pre-push → Scripts/preflight.sh)
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

QUICK=false
ERRORS=0

for arg in "$@"; do
    case $arg in
        --quick) QUICK=true ;;
    esac
done

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  WARN: $1"; }

echo "========================================"
echo "TetraTrack Preflight Checks"
if [ "$QUICK" = true ]; then
    echo "(quick mode — skipping unit tests)"
fi
echo "========================================"
echo ""

# -----------------------------------------------
# 1. SwiftLint
# -----------------------------------------------
echo "[1/5] SwiftLint..."

if command -v swiftlint &> /dev/null; then
    LINT_OUTPUT=$(cd "$PROJECT_DIR" && swiftlint lint --quiet 2>&1) || true
    LINT_ERRORS=$(echo "$LINT_OUTPUT" | grep -c "error:" || true)
    LINT_WARNINGS=$(echo "$LINT_OUTPUT" | grep -c "warning:" || true)
    LINT_ERRORS=$((LINT_ERRORS + 0))
    LINT_WARNINGS=$((LINT_WARNINGS + 0))

    if [ "$LINT_ERRORS" -gt 0 ]; then
        fail "SwiftLint found ${LINT_ERRORS} error(s) and ${LINT_WARNINGS} warning(s)"
        echo "$LINT_OUTPUT" | grep "error:" | head -10
    else
        pass "SwiftLint (${LINT_WARNINGS} warnings, 0 errors)"
    fi
else
    warn "SwiftLint not installed (brew install swiftlint)"
fi

# -----------------------------------------------
# 2. SwiftData @Relationship optionality
# -----------------------------------------------
echo ""
echo "[2/5] @Relationship optionality..."

RELATIONSHIP_ISSUES=$(
    grep -A1 "@Relationship" "$PROJECT_DIR"/TetraTrack/Models/*.swift "$PROJECT_DIR"/TetraTrack/Models/**/*.swift 2>/dev/null \
    | grep -E "var.*\[.*\].*=" \
    | grep -v "\?" \
    || true
)

if [ -n "$RELATIONSHIP_ISSUES" ]; then
    fail "Non-optional @Relationship arrays found (will break CloudKit sync):"
    echo "$RELATIONSHIP_ISSUES" | while IFS= read -r line; do echo "    $line"; done
else
    pass "@Relationship arrays are all optional"
fi

# -----------------------------------------------
# 3. MARKETING_VERSION consistency
# -----------------------------------------------
echo ""
echo "[3/5] MARKETING_VERSION consistency..."

PBXPROJ="${PROJECT_DIR}/TetraTrack.xcodeproj/project.pbxproj"

if [ -f "$PBXPROJ" ]; then
    VERSIONS=$(grep "MARKETING_VERSION" "$PBXPROJ" | sed 's/.*= //' | sed 's/;.*//' | sort -u)
    VERSION_COUNT=$(echo "$VERSIONS" | wc -l | tr -d ' ')

    if [ "$VERSION_COUNT" -gt 1 ]; then
        fail "Multiple MARKETING_VERSION values found:"
        echo "$VERSIONS" | while IFS= read -r v; do echo "    $v"; done
    else
        pass "All targets at MARKETING_VERSION = $(echo "$VERSIONS" | tr -d ' ')"
    fi
else
    warn "project.pbxproj not found"
fi

# -----------------------------------------------
# 4. App Store metadata character limits
# -----------------------------------------------
echo ""
echo "[4/5] App Store metadata limits..."

if [ -x "${SCRIPT_DIR}/validate_metadata.sh" ]; then
    METADATA_OUTPUT=$("${SCRIPT_DIR}/validate_metadata.sh" 2>&1) || true
    if echo "$METADATA_OUTPUT" | grep -q "FAILED"; then
        fail "Metadata character limits exceeded"
        echo "$METADATA_OUTPUT" | grep "FAIL:" | while IFS= read -r line; do echo "  $line"; done
    else
        pass "All metadata within character limits"
    fi
else
    warn "validate_metadata.sh not found or not executable"
fi

# -----------------------------------------------
# 5. Unit Tests (skipped in --quick mode)
# -----------------------------------------------
echo ""
if [ "$QUICK" = true ]; then
    echo "[5/5] Unit tests... SKIPPED (--quick mode)"
else
    echo "[5/5] Unit tests..."

    # Find an available iPhone simulator (tests need a concrete device, not generic)
    SIMULATOR=$(xcrun simctl list devices available -j \
        | python3 -c "import sys,json; devs=json.load(sys.stdin)['devices']; print(next(d['name'] for r in devs for d in devs[r] if 'iPhone' in d['name'] and d['isAvailable']),end='')" 2>/dev/null)
    if [ -z "$SIMULATOR" ]; then
        SIMULATOR="iPhone 17 Pro"
    fi
    echo "  Using simulator: $SIMULATOR"

    if xcodebuild test \
        -project "${PROJECT_DIR}/TetraTrack.xcodeproj" \
        -scheme TetraTrack \
        -destination "platform=iOS Simulator,name=$SIMULATOR" \
        -configuration Debug \
        CODE_SIGNING_ALLOWED=NO \
        -quiet 2>&1; then
        pass "All unit tests passed"
    else
        fail "Unit tests failed"
    fi
fi

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "========================================"
if [ "$ERRORS" -gt 0 ]; then
    echo "PREFLIGHT FAILED: ${ERRORS} check(s) failed"
    echo "========================================"
    exit 1
else
    echo "PREFLIGHT PASSED: All checks OK"
    echo "========================================"
    exit 0
fi
