#!/usr/bin/env bash
set -euo pipefail

# Halo-Halo Patterns: Install script for consuming repositories
# Usage: bash .patterns/catalog/scripts/install.sh [TARGET_DIR]

TARGET="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$CATALOG_ROOT/templates/consuming"

echo "Installing Halo-Halo patterns into: $TARGET"

# Create local directories for cases and scratch
mkdir -p "$TARGET/.patterns/local/cases"
mkdir -p "$TARGET/.patterns/local/scratch"

# Copy GitHub templates (halo-prefixed prompts, agents, instructions)
mkdir -p "$TARGET/.github/prompts/halo" "$TARGET/.github/agents/halo"
if [ -d "$TEMPLATES/.github" ]; then
  cp -R "$TEMPLATES/.github/"* "$TARGET/.github/" 2>/dev/null || true
fi
echo "✓ Installed Halo Copilot prompts and agents to .github/"

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
echo "  1. Review .github/halo-copilot-instructions.md"
echo "  2. Try the /halo-search prompt in GitHub Copilot Chat"
echo "  3. Add your first case to .patterns/local/cases/"
