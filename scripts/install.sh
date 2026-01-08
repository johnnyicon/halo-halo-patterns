#!/usr/bin/env bash
set -euo pipefail

# Halo-Halo Patterns: Install script for consuming repositories
# Usage: bash .patterns/catalog/scripts/install.sh [TARGET_DIR]

TARGET="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$CATALOG_ROOT/templates/consuming"
HALO_VERSION="0.1"

echo "Installing Halo-Halo patterns into: $TARGET"

# Create local directories for cases and scratch
mkdir -p "$TARGET/.patterns/local/cases"
mkdir -p "$TARGET/.patterns/local/scratch"

# Copy GitHub templates (halo-prefixed prompts, agents)
mkdir -p "$TARGET/.github/prompts/halo" "$TARGET/.github/agents/halo"
if [ -d "$TEMPLATES/.github" ]; then
  cp -R "$TEMPLATES/.github/"* "$TARGET/.github/" 2>/dev/null || true
fi
echo "✓ Installed Halo Copilot prompts and agents to .github/"

# Merge Halo instructions into copilot-instructions.md (safe, idempotent)
COPILOT_INSTRUCTIONS="$TARGET/.github/copilot-instructions.md"
SNIPPET="$TEMPLATES/.github/halo-halo.instructions.snippet.md"
MARKER_START="<!-- halo-halo:start version=$HALO_VERSION -->"
MARKER_END="<!-- halo-halo:end -->"

if [ ! -f "$SNIPPET" ]; then
  echo "⚠ Warning: Snippet file not found, skipping instructions merge"
else
  SNIPPET_CONTENT=$(cat "$SNIPPET")
  
  if [ ! -f "$COPILOT_INSTRUCTIONS" ]; then
    # Create new copilot-instructions.md with Halo block
    cat > "$COPILOT_INSTRUCTIONS" <<EOF
# Copilot Instructions

$MARKER_START
$SNIPPET_CONTENT
$MARKER_END
EOF
    echo "✓ Created .github/copilot-instructions.md with Halo instructions"
  elif grep -q "$MARKER_START" "$COPILOT_INSTRUCTIONS" 2>/dev/null; then
    # Update existing marker block
    awk -v start="$MARKER_START" -v end="$MARKER_END" -v content="$SNIPPET_CONTENT" '
      BEGIN { in_block=0 }
      $0 ~ start { print; print content; in_block=1; next }
      $0 ~ end { print; in_block=0; next }
      !in_block { print }
    ' "$COPILOT_INSTRUCTIONS" > "$COPILOT_INSTRUCTIONS.tmp"
    mv "$COPILOT_INSTRUCTIONS.tmp" "$COPILOT_INSTRUCTIONS"
    echo "✓ Updated Halo instructions block in .github/copilot-instructions.md"
  else
    # Append Halo block to existing file
    cat >> "$COPILOT_INSTRUCTIONS" <<EOF

$MARKER_START
$SNIPPET_CONTENT
$MARKER_END
EOF
    echo "✓ Appended Halo instructions to .github/copilot-instructions.md"
  fi
fi

# Add gitignore block (idempotent - won't duplicate)
GITIGNORE="$TARGET/.gitignore"
touch "$GITIGNORE"

BLOCK_START="# --- halo-halo-patterns:local-start ---"
BLOCK_END="# --- halo-halo-patterns:local-end ---"

if ! grep -q "$BLOCK_START" "$GITIGNORE" 2>/dev/null; then
  cat >> "$GITIGNORE" <<EOF

$BLOCK_START
.patterns/local/**
!.patterns/local/README.md
$BLOCK_END
EOF
  echo "✓ Added .patterns/local to .gitignore"
else
  echo "✓ .gitignore already configured"
fi

# Create local README if it doesn't exist
LOCAL_README="$TARGET/.patterns/local/README.md"
if [ ! -f "$LOCAL_README" ]; then
  cat > "$LOCAL_README" <<'EOF'
# Local Patterns

This directory is for project-specific patterns and cases.

- `cases/` - Project-specific debugging/troubleshooting cases
- `scratch/` - Temporary notes (gitignored)

**Do not commit sensitive information** (API keys, credentials, PII, etc.)
EOF
  echo "✓ Created .patterns/local/README.md"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Review .github/copilot-instructions.md (Halo block added)"
echo "  2. Try /halo-search in GitHub Copilot Chat"
echo "  3. Run /halo-install-wizard for advanced setup"
echo ""
echo "For manual merge: cat .github/halo-halo.instructions.snippet.md"
