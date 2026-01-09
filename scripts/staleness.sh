#!/usr/bin/env bash
set -euo pipefail

# Check for --help flag
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'HELP'
Usage: staleness.sh [CATALOG_ROOT]

Audit Halo-Halo patterns for maintenance issues.

Arguments:
  CATALOG_ROOT    Path to patterns directory (default: patterns)

Environment Variables:
  MAX_LAST_VERIFIED_DAYS    Days before last_verified is stale (default: 90)

Exit Codes:
  0    No blocking issues
  1    Script error (missing python3, invalid path, etc.)
  2    Blocking issues found (overdue review_by dates)

Example:
  bash scripts/staleness.sh patterns
  MAX_LAST_VERIFIED_DAYS=60 bash scripts/staleness.sh patterns
HELP
  exit 0
fi

# Check for Python 3
if ! command -v python3 &> /dev/null; then
  echo "ERROR: Python 3 is required but not found."
  echo "Install: apt install python3 (Debian/Ubuntu) or brew install python3 (macOS)"
  exit 1
fi

CATALOG_ROOT="${1:-patterns}"
MAX_LAST_VERIFIED_DAYS="${MAX_LAST_VERIFIED_DAYS:-90}"

today="$(date +%Y-%m-%d)"

# --- helpers ---------------------------------------------------------------

front_matter() {
  # Prints YAML front matter (between the first two --- lines), or empty.
  awk '
    NR==1 && $0!="---" { exit }
    NR==1 && $0=="---" { in=1; next }
    in && $0=="---" { exit }
    in { print }
  ' "$1" 2>/dev/null || true
}

trim() {
  local s="$1"
  s="${s#\"}"; s="${s%\"}"
  s="${s#\'}"; s="${s%\'}"
  echo "$s" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g'
}

fm_scalar() {
  # naive scalar YAML: key: value
  local key="$1"
  awk -v k="$key" '
    BEGIN { IGNORECASE=1 }
    $1 ~ ("^" k ":$") || $0 ~ ("^" k ":[[:space:]]") {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print $0
      exit
    }
  '
}

fm_list_block() {
  # naive list YAML:
  # related:
  #   - id1
  #   - id2
  local key="$1"
  awk -v k="$key" '
    BEGIN { IGNORECASE=1; in=0 }
    $0 ~ ("^" k ":[[:space:]]*$") { in=1; next }
    in {
      if ($0 ~ "^[A-Za-z0-9_-]+:[[:space:]]") exit
      if ($0 ~ "^[[:space:]]*-[[:space:]]+") {
        sub("^[[:space:]]*-[[:space:]]+", "", $0)
        print $0
      } else if ($0 ~ "^[[:space:]]*$") {
        # keep going
      } else {
        # non-list content ends block
        exit
      }
    }
  '
}

date_lt() {
  # returns 0 if $1 < $2 (YYYY-MM-DD), else 1
  python3 - "$1" "$2" <<'PY'
import sys
from datetime import date
def parse(s): return date.fromisoformat(s)
a=parse(sys.argv[1]); b=parse(sys.argv[2])
sys.exit(0 if a < b else 1)
PY
}

days_since() {
  # prints days between today and $1 (YYYY-MM-DD). If invalid, prints empty.
  python3 - "$1" <<'PY'
import sys
from datetime import date
try:
  d = date.fromisoformat(sys.argv[1])
  print((date.today() - d).days)
except Exception:
  pass
PY
}

# --- scan ------------------------------------------------------------------

declare -A status_by_id file_by_id deprecated_by_id
declare -a validated_overdue validated_warn referenced_deprecated

while IFS= read -r -d '' f; do
  fm="$(front_matter "$f")"
  [ -z "$fm" ] && continue

  id="$(trim "$(echo "$fm" | fm_scalar id || true)")"
  status="$(trim "$(echo "$fm" | fm_scalar status || true)")"
  review_by="$(trim "$(echo "$fm" | fm_scalar review_by || true)")"
  last_verified="$(trim "$(echo "$fm" | fm_scalar last_verified || true)")"
  deprecated_date="$(trim "$(echo "$fm" | fm_scalar deprecated_date || true)")"

  [ -z "$id" ] && continue

  file_by_id["$id"]="$f"
  status_by_id["$id"]="$status"
  deprecated_by_id["$id"]="$deprecated_date"

  if [ "$status" = "deprecated" ] && [ -z "$deprecated_date" ]; then
    # Not fatal, but worth surfacing.
    :
  fi

  if [ "$status" = "validated" ]; then
    if [ -n "$review_by" ] && date_lt "$review_by" "$today"; then
      validated_overdue+=("$id|$f|review_by=$review_by")
    fi
    if [ -n "$last_verified" ]; then
      ds="$(days_since "$last_verified")"
      if [ -n "$ds" ] && [ "$ds" -gt "$MAX_LAST_VERIFIED_DAYS" ]; then
        validated_warn+=("$id|$f|last_verified=$last_verified (${ds}d)")
      fi
    fi
  fi
done < <(find "$CATALOG_ROOT" -type f -name "*.md" -print0 2>/dev/null)

# second pass: referenced deprecated (related -> deprecated)
while IFS= read -r -d '' f; do
  fm="$(front_matter "$f")"
  [ -z "$fm" ] && continue
  id="$(trim "$(echo "$fm" | fm_scalar id || true)")"
  [ -z "$id" ] && continue
  related_ids="$(echo "$fm" | fm_list_block related || true)"
  while IFS= read -r rid; do
    rid="$(trim "$rid")"
    [ -z "$rid" ] && continue
    if [ "${status_by_id["$rid"]:-}" = "deprecated" ]; then
      referenced_deprecated+=("$id|$f|references deprecated=$rid")
    fi
  done <<< "$related_ids"
done < <(find "$CATALOG_ROOT" -type f -name "*.md" -print0 2>/dev/null)

# --- output ----------------------------------------------------------------

echo "# Pattern Staleness Report"
echo
echo "- Date: $today"
echo "- Catalog: $CATALOG_ROOT"
echo "- last_verified warning threshold: ${MAX_LAST_VERIFIED_DAYS}d"
echo

if [ "${#validated_overdue[@]}" -gt 0 ]; then
  echo "## Overdue reviews (BLOCKING)"
  for x in "${validated_overdue[@]}"; do
    IFS='|' read -r id f meta <<<"$x"
    echo "- **$id** — $meta — \`$f\`"
  done
  echo
else
  echo "## Overdue reviews (BLOCKING)"
  echo "- None ✅"
  echo
fi

if [ "${#validated_warn[@]}" -gt 0 ]; then
  echo "## last_verified warnings"
  for x in "${validated_warn[@]}"; do
    IFS='|' read -r id f meta <<<"$x"
    echo "- **$id** — $meta — \`$f\`"
  done
  echo
else
  echo "## last_verified warnings"
  echo "- None ✅"
  echo
fi

if [ "${#referenced_deprecated[@]}" -gt 0 ]; then
  echo "## References to deprecated patterns"
  for x in "${referenced_deprecated[@]}"; do
    IFS='|' read -r id f meta <<<"$x"
    echo "- **$id** — $meta — \`$f\`"
  done
  echo
else
  echo "## References to deprecated patterns"
  echo "- None ✅"
  echo
fi

# Exit non-zero if blocking overdue items exist
if [ "${#validated_overdue[@]}" -gt 0 ]; then
  exit 2
fi
