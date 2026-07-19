#!/usr/bin/env bash
# memory-delete.sh — Delete an agent memory
# Usage: memory-delete.sh <filename-or-title>
set -euo pipefail

MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || -z "${1:-}" ]]; then
  echo "Usage: memory-delete.sh <filename-or-title>"
  echo ""
  echo "Delete a memory file and update the qmd index."
  echo ""
  echo "The argument can be:"
  echo "  - A filename (e.g., avoid-nested-ternary.md)"
  echo "  - A title to search for (fuzzy match)"
  exit 0
fi

TARGET="$1"

# Check qmd is available
if ! command -v qmd &>/dev/null; then
  echo "Error: qmd is not installed. Run: npm install -g @tobilu/qmd" >&2
  exit 1
fi

# Check memory directory
if [[ ! -d "$MEMORY_DIR" ]]; then
  echo "Error: Memory directory does not exist: $MEMORY_DIR" >&2
  exit 1
fi

# --- resolve file ---
# Try direct filename first
if [[ -f "$MEMORY_DIR/$TARGET" ]]; then
  FILEPATH="$MEMORY_DIR/$TARGET"
elif [[ -f "$MEMORY_DIR/${TARGET}.md" ]]; then
  FILEPATH="$MEMORY_DIR/${TARGET}.md"
else
  # Fuzzy search by slugified title
  SLUG=$(echo "$TARGET" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
  MATCH=$(find "$MEMORY_DIR" -maxdepth 1 -name "*${SLUG}*" -type f 2>/dev/null | head -1)

  if [[ -n "$MATCH" ]]; then
    FILEPATH="$MATCH"
  else
    echo "Error: Memory not found: $TARGET" >&2
    echo "Available memories:" >&2
    find "$MEMORY_DIR" -maxdepth 1 -name '*.md' -type f -exec basename {} \; 2>/dev/null | sort >&2
    exit 1
  fi
fi

FILENAME=$(basename "$FILEPATH")

# --- delete ---
rm "$FILEPATH"
echo "Deleted: $FILENAME"

# --- update index ---
echo "Updating qmd index..."
qmd embed 2>/dev/null && echo "Index updated." || echo "Warning: Failed to update index." >&2
