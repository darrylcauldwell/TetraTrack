#!/bin/bash
#
# validate_metadata.sh - Validate App Store metadata character limits
#
# Checks all locale directories under fastlane/metadata/ for:
#   name.txt: 30 chars
#   subtitle.txt: 30 chars
#   keywords.txt: 100 chars
#   description.txt: 4000 chars
#   promotional_text.txt: 170 chars
#   release_notes.txt: 4000 chars
#
# Outputs GitHub Actions ::error annotations on failures.
#
# Usage:
#   ./Scripts/validate_metadata.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
METADATA_DIR="${PROJECT_DIR}/fastlane/metadata"

ERRORS=0

check_length() {
    local file="$1"
    local max_chars="$2"
    local field_name="$3"

    if [ ! -f "$file" ]; then
        return
    fi

    # Use wc -m for correct Unicode character counting, trim trailing newline
    local char_count
    char_count=$(tr -d '\n' < "$file" | wc -m | tr -d ' ')

    if [ "$char_count" -gt "$max_chars" ]; then
        local relative_path="${file#"${PROJECT_DIR}"/}"
        echo "::error file=${relative_path}::${field_name} is ${char_count} characters (max ${max_chars})"
        echo "  FAIL: ${relative_path} — ${char_count}/${max_chars} chars"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "Validating App Store metadata character limits..."
echo ""

# Find all locale directories
for locale_dir in "${METADATA_DIR}"/*/; do
    if [ ! -d "$locale_dir" ]; then
        continue
    fi

    locale=$(basename "$locale_dir")
    echo "Checking ${locale}..."

    check_length "${locale_dir}name.txt"             30   "${locale}/name"
    check_length "${locale_dir}subtitle.txt"          30   "${locale}/subtitle"
    check_length "${locale_dir}keywords.txt"          100  "${locale}/keywords"
    check_length "${locale_dir}description.txt"       4000 "${locale}/description"
    check_length "${locale_dir}promotional_text.txt"  170  "${locale}/promotional_text"
    check_length "${locale_dir}release_notes.txt"     4000 "${locale}/release_notes"
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "FAILED: ${ERRORS} metadata field(s) exceed character limits"
    exit 1
else
    echo "All metadata fields within character limits."
fi
