#!/usr/bin/env bash
set -euo pipefail

# Update Halo-Halo submodule pointer to latest in consuming repo
# Run this from the CONSUMING repo root (not inside the submodule)
#
# Usage:
#   bash .halo-halo/halo-halo-upstream/scripts/update-submodule-pointer.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBMODULE_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SUBMODULE_PATH/../.." && pwd)"

echo "🔄 Updating Halo-Halo submodule to latest..."
echo ""

# Verify we're in consuming repo root (not inside submodule)
if [ "$(pwd)" != "$REPO_ROOT" ]; then
  echo "❌ Error: Must run from consuming repo root"
  echo "   Current dir: $(pwd)"
  echo "   Expected: $REPO_ROOT"
  exit 1
fi

# Navigate to submodule
cd "$SUBMODULE_PATH"

# Store current commit for comparison
OLD_COMMIT=$(git rev-parse HEAD)
OLD_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")

# Fetch and checkout latest
echo "📥 Fetching latest from origin..."
git fetch origin
git checkout origin/main

# Get new commit info
NEW_COMMIT=$(git rev-parse HEAD)
NEW_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "unknown")

# Return to repo root
cd "$REPO_ROOT"

# Check if anything changed
if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
  echo "✅ Already up to date at $NEW_VERSION ($OLD_COMMIT)"
  exit 0
fi

echo ""
echo "📝 Changes detected:"
echo "   Old: $OLD_VERSION ($OLD_COMMIT)"
echo "   New: $NEW_VERSION ($NEW_COMMIT)"
echo ""

# Show what changed
echo "📋 Changelog:"
cd "$SUBMODULE_PATH"
git log --oneline "$OLD_COMMIT..$NEW_COMMIT"
cd "$REPO_ROOT"

echo ""

# Stage the submodule pointer update
git add .halo-halo/halo-halo-upstream

echo "✅ Submodule updated and staged"
echo ""
echo "📌 Next steps:"
echo "   1. Review changes: git diff --staged"
echo "   2. Commit update: git commit -m \"chore: update halo-halo to $NEW_VERSION\""
echo "   3. Push: git push"
echo ""
echo "💡 Or run: git reset HEAD .halo-halo/halo-halo-upstream to undo"
