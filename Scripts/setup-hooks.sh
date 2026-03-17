#!/bin/bash
#
# setup-hooks.sh - Install git hooks for TetraTrack
#
# Run once after cloning:
#   ./Scripts/setup-hooks.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${PROJECT_DIR}/.git/hooks"

echo "Installing git hooks..."

# Pre-push hook: runs preflight checks (lint + tests) before every push
ln -sf ../../Scripts/preflight.sh "${HOOKS_DIR}/pre-push"
echo "  Installed pre-push → Scripts/preflight.sh"

echo "Done. Preflight checks will run automatically before each push."
echo "Use 'git push --no-verify' to skip (not recommended)."
