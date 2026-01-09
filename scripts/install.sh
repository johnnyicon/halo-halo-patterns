#!/usr/bin/env bash
set -euo pipefail

# Halo-Halo Patterns: Install script for consuming repositories
# Usage: bash .halo-halo/upstream/scripts/install.sh [TARGET_DIR]

TARGET="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CATALOG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$CATALOG_ROOT/templates/consuming"
HALO_VERSION="0.1"

echo "Installing Halo-Halo patterns into: $TARGET"

# Create local directories for cases and scratch
mkdir -p "$TARGET/.halo-halo/local/cases"
mkdir -p "$TARGET/.halo-halo/local/scratch"

# Copy GitHub templates (halo-prefixed prompts, agents, workflows)
mkdir -p "$TARGET/.github/prompts/halo" "$TARGET/.github/agents/halo" "$TARGET/.github/workflows"
if [ -d "$TEMPLATES/.github" ]; then
  # Copy prompts
  if [ -d "$TEMPLATES/.github/prompts/halo" ]; then
    cp -R "$TEMPLATES/.github/prompts/halo/"*.prompt.md "$TARGET/.github/prompts/halo/" 2>/dev/null || true
  fi
  # Copy agents
  if [ -d "$TEMPLATES/.github/agents" ]; then
    cp -R "$TEMPLATES/.github/agents/"*.agent.md "$TARGET/.github/agents/halo/" 2>/dev/null || true
  fi
  # Copy workflows
  if [ -d "$TEMPLATES/.github/workflows" ]; then
    cp "$TEMPLATES/.github/workflows/"*.yml "$TARGET/.github/workflows/" 2>/dev/null || true
  fi
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
    awk -v start="$MARKER_START" -v end="$MARKER_END" -v snippet="$SNIPPET" '
      BEGIN { in_block=0 }
      $0 ~ start { 
        print
        while ((getline line < snippet) > 0) print line
        close(snippet)
        in_block=1
        next
      }
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
.halo-halo/local/**
!.halo-halo/local/README.md
$BLOCK_END
EOF
  echo "✓ Added .halo-halo/local to .gitignore"
else
  echo "✓ .gitignore already configured"
fi

# Create local README if it doesn't exist
LOCAL_README="$TARGET/.halo-halo/local/README.md"
if [ ! -f "$LOCAL_README" ]; then
  cat > "$LOCAL_README" <<'EOF'
# Local Patterns

This directory is for project-specific patterns and cases.

- `cases/` - Project-specific debugging/troubleshooting cases
- `scratch/` - Temporary notes (gitignored)

**Do not commit sensitive information** (API keys, credentials, PII, etc.)
EOF
  echo "✓ Created .halo-halo/local/README.md"
fi

# Update VS Code settings.json to include Halo prompts path (if file exists)
VSCODE_SETTINGS="$TARGET/.vscode/settings.json"
if [ -f "$VSCODE_SETTINGS" ]; then
  # Check if chat.promptFilesLocations exists and doesn't already have halo path
  if grep -q '"chat.promptFilesLocations"' "$VSCODE_SETTINGS" 2>/dev/null; then
    if ! grep -q '".github/prompts/halo"' "$VSCODE_SETTINGS" 2>/dev/null; then
      # Add halo path to existing promptFilesLocations using jq if available, or warn user
      if command -v jq &> /dev/null; then
        TMP_FILE=$(mktemp)
        jq '.["chat.promptFilesLocations"][".github/prompts/halo"] = true' "$VSCODE_SETTINGS" > "$TMP_FILE" && mv "$TMP_FILE" "$VSCODE_SETTINGS"
        echo "✓ Added .github/prompts/halo to VS Code settings.json"
      else
        echo "⚠ Please manually add \".github/prompts/halo\": true to chat.promptFilesLocations in .vscode/settings.json"
      fi
    else
      echo "✓ VS Code settings.json already configured for Halo prompts"
    fi
  else
    echo "⚠ Please add chat.promptFilesLocations to .vscode/settings.json (see VS Code Copilot docs)"
  fi
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Review .github/copilot-instructions.md (Halo block added)"
echo "  2. Try /halo-search in GitHub Copilot Chat"
echo "  3. Run /halo-install-wizard for advanced setup"
echo ""
echo "Patterns location: .halo-halo/upstream/patterns/"
echo "Local cases: .halo-halo/local/cases/"

# Run verification script
if [ -f "$SCRIPT_DIR/verify.sh" ]; then
  bash "$SCRIPT_DIR/verify.sh" "$TARGET"
else
  echo ""
  echo "⚠️  Verification script not found. Installation may be incomplete."
fi
