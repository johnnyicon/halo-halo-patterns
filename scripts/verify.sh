#!/usr/bin/env bash
set -euo pipefail

# Halo-Halo Patterns: Verification script for installation
# Usage: bash .halo-halo/upstream/scripts/verify.sh [TARGET_DIR]

TARGET="${1:-.}"
ERRORS=0

echo ""
echo "=== Verifying Halo-Halo Installation ==="
echo ""

# Check prompts
echo "Checking prompts..."
for PROMPT in halo-search.prompt.md halo-apply.prompt.md halo-gatekeeper.prompt.md halo-write-pattern.prompt.md halo-commit.prompt.md halo-health.prompt.md halo-install-wizard.prompt.md; do
  if [ -f "$TARGET/.github/prompts/halo/$PROMPT" ]; then
    echo "  ✅ $PROMPT"
  else
    echo "  ❌ $PROMPT (missing)"
    ERRORS=$((ERRORS + 1))
  fi
done

# Check agents
echo ""
echo "Checking agents..."
if [ -f "$TARGET/.github/agents/halo/halo-gatekeeper.agent.md" ]; then
  echo "  ✅ halo-gatekeeper.agent.md"
  
  # Verify agent name
  if grep -q "name: Halo-Halo Patterns Gatekeeper" "$TARGET/.github/agents/halo/halo-gatekeeper.agent.md" 2>/dev/null; then
    echo "  ✅ Agent name is correct"
  else
    echo "  ⚠️  Agent name may need updating"
  fi
else
  echo "  ❌ halo-gatekeeper.agent.md (missing)"
  ERRORS=$((ERRORS + 1))
fi

# Check local directories
echo ""
echo "Checking local directories..."
for DIR in cases scratch; do
  if [ -d "$TARGET/.halo-halo/local/$DIR" ]; then
    echo "  ✅ .halo-halo/local/$DIR/"
  else
    echo "  ❌ .halo-halo/local/$DIR/ (missing)"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ -f "$TARGET/.halo-halo/local/README.md" ]; then
  echo "  ✅ .halo-halo/local/README.md"
else
  echo "  ❌ .halo-halo/local/README.md (missing)"
  ERRORS=$((ERRORS + 1))
fi

# Check instructions snippet
echo ""
echo "Checking instructions..."
# Note: snippet file is only in upstream, not copied to consuming repo
# Check copilot-instructions.md has Halo block
if [ -f "$TARGET/.github/copilot-instructions.md" ]; then
  if grep -q "<!-- halo-halo:start" "$TARGET/.github/copilot-instructions.md" 2>/dev/null; then
    echo "  ✅ Halo block in .github/copilot-instructions.md"
  else
    echo "  ⚠️  Halo block not found in .github/copilot-instructions.md"
  fi
else
  echo "  ⚠️  .github/copilot-instructions.md not found"
fi

# Check .gitignore
echo ""
echo "Checking .gitignore..."
if [ -f "$TARGET/.gitignore" ]; then
  if grep -q "halo-halo-patterns:local-start" "$TARGET/.gitignore" 2>/dev/null; then
    echo "  ✅ .gitignore configured for .halo-halo/local/"
  else
    echo "  ⚠️  .gitignore not configured for .halo-halo/local/"
  fi
else
  echo "  ⚠️  .gitignore not found"
fi

# Check VS Code settings.json
echo ""
echo "Checking VS Code settings..."
if [ -f "$TARGET/.vscode/settings.json" ]; then
  if grep -q '".github/prompts/halo"' "$TARGET/.vscode/settings.json" 2>/dev/null; then
    echo "  ✅ .vscode/settings.json includes .github/prompts/halo"
  else
    echo "  ⚠️  .vscode/settings.json does not include .github/prompts/halo"
    echo "     Add to chat.promptFilesLocations: \".github/prompts/halo\": true"
  fi
else
  echo "  ⚠️  .vscode/settings.json not found"
fi

# Check health check components
echo ""
echo "Checking health check components..."
if [ -f "$TARGET/.github/prompts/halo/halo-health.prompt.md" ]; then
  echo "  ✅ halo-health.prompt.md"
else
  echo "  ⚠️  halo-health.prompt.md (missing)"
fi

# Find the upstream submodule path
UPSTREAM_PATH="$TARGET/.halo-halo/upstream"
[ ! -d "$UPSTREAM_PATH" ] && UPSTREAM_PATH="$TARGET/.halo-halo/halo-halo-upstream"

if [ -f "$UPSTREAM_PATH/scripts/staleness.sh" ]; then
  if [ -x "$UPSTREAM_PATH/scripts/staleness.sh" ]; then
    echo "  ✅ staleness.sh (executable)"
  else
    echo "  ⚠️  staleness.sh (not executable)"
    echo "     Run: chmod +x $UPSTREAM_PATH/scripts/staleness.sh"
  fi
else
  echo "  ⚠️  staleness.sh (missing)"
fi

# Check for Python 3 (needed for staleness.sh date calculations)
if command -v python3 &>/dev/null; then
  echo "  ✅ Python 3 available (for staleness.sh)"
else
  echo "  ⚠️  Python 3 not found (staleness.sh requires it for date math)"
  echo "     Install Python 3 or staleness.sh will fail"
fi

# Check upstream patterns catalog is accessible
echo ""
echo "Checking patterns catalog..."
if [ -d "$TARGET/.halo-halo/upstream/patterns" ] || [ -d "$TARGET/.halo-halo/halo-halo-upstream/patterns" ]; then
  PATTERNS_DIR="$TARGET/.halo-halo/upstream/patterns"
  [ ! -d "$PATTERNS_DIR" ] && PATTERNS_DIR="$TARGET/.halo-halo/halo-halo-upstream/patterns"
  
  PATTERN_COUNT=$(find "$PATTERNS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$PATTERN_COUNT" -gt 0 ]; then
    echo "  ✅ Patterns catalog accessible ($PATTERN_COUNT patterns found)"
    echo ""
    echo "  Sample patterns:"
    find "$PATTERNS_DIR" -name "*.md" 2>/dev/null | head -3 | sed 's|^|    - |'
  else
    echo "  ⚠️  Patterns catalog is empty"
  fi
else
  echo "  ❌ Patterns catalog not found (submodule not initialized?)"
  ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
  echo "✅ All critical checks passed!"
  echo ""
  echo "Ready to use:"
  echo "  - /halo-search <keywords>    # Search for patterns"
  echo "  - /halo-apply <pattern-id>   # Apply a pattern"
  echo "  - /halo-gatekeeper           # Capture new pattern"
  echo "  - /halo-write-pattern        # Write from Gatekeeper decision"
  echo "  - /halo-commit               # Commit with validation"
  echo "  - /halo-health               # Check catalog health"
  exit 0
else
  echo "❌ $ERRORS error(s) found"
  echo ""
  echo "Please review the output above and fix any missing files."
  exit 1
fi
