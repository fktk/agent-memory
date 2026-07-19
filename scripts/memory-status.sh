#!/usr/bin/env bash
# memory-status.sh — Show agent memory status
# Usage: memory-status.sh [--json]
set -euo pipefail

MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"
COLLECTION="${AGENT_MEMORY_COLLECTION:-agent-memory}"

JSON_OUTPUT=false
if [[ "${1:-}" == "--json" ]]; then
  JSON_OUTPUT=true
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: memory-status.sh [--json]"
  echo ""
  echo "Show agent memory index status and file statistics."
  exit 0
fi

# Check qmd is available
if ! command -v qmd &>/dev/null; then
  echo "Error: qmd is not installed. Run: npm install -g @tobilu/qmd" >&2
  exit 1
fi

# --- memory file stats ---
if [[ ! -d "$MEMORY_DIR" ]]; then
  TOTAL_FILES=0
  LESSON_COUNT=0
  KNOWLEDGE_COUNT=0
  PREFERENCE_COUNT=0
  OTHER_COUNT=0
else
  TOTAL_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l)

  # Count by category from frontmatter
  LESSON_COUNT=0
  KNOWLEDGE_COUNT=0
  PREFERENCE_COUNT=0
  OTHER_COUNT=0

  while IFS= read -r file; do
    category=$(sed -n '/^---$/,/^---$/{ /^category:/{ s/^category:[[:space:]]*//; s/[[:space:]]*$//; p; q; } }' "$file" 2>/dev/null || echo "")
    case "$category" in
      lesson)     LESSON_COUNT=$((LESSON_COUNT + 1)) ;;
      knowledge)  KNOWLEDGE_COUNT=$((KNOWLEDGE_COUNT + 1)) ;;
      preference) PREFERENCE_COUNT=$((PREFERENCE_COUNT + 1)) ;;
      *)          OTHER_COUNT=$((OTHER_COUNT + 1)) ;;
    esac
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null)
fi

if [[ "$JSON_OUTPUT" == "true" ]]; then
  # Get qmd status as JSON
  QMD_STATUS=$(qmd status --json 2>/dev/null || echo '{}')

  cat <<EOF
{
  "memory_dir": "$MEMORY_DIR",
  "collection": "$COLLECTION",
  "total_files": $TOTAL_FILES,
  "categories": {
    "lesson": $LESSON_COUNT,
    "knowledge": $KNOWLEDGE_COUNT,
    "preference": $PREFERENCE_COUNT,
    "other": $OTHER_COUNT
  },
  "qmd_status": $QMD_STATUS
}
EOF
else
  echo "=== Agent Memory Status ==="
  echo ""
  echo "Memory directory: $MEMORY_DIR"
  echo "Collection:       $COLLECTION"
  echo ""
  echo "--- Files ---"
  echo "Total:      $TOTAL_FILES"
  echo "  lesson:     $LESSON_COUNT"
  echo "  knowledge:  $KNOWLEDGE_COUNT"
  echo "  preference: $PREFERENCE_COUNT"
  echo "  other:      $OTHER_COUNT"
  echo ""
  echo "--- qmd Index ---"
  qmd status 2>/dev/null || echo "(qmd index not initialized)"

  # Show recent memories
  if [[ $TOTAL_FILES -gt 0 ]]; then
    echo ""
    echo "--- Recent Memories (last 5) ---"
    find "$MEMORY_DIR" -maxdepth 1 -name '*.md' -type f -printf '%T@ %f\n' 2>/dev/null \
      | sort -rn \
      | head -5 \
      | while read -r _ts fname; do
          title=$(sed -n '/^---$/,/^---$/{ /^title:/{ s/^title:[[:space:]]*["'"'"']*//; s/["'"'"']*[[:space:]]*$//; p; q; } }' "$MEMORY_DIR/$fname" 2>/dev/null || echo "$fname")
          echo "  • $title"
        done
  fi
fi
