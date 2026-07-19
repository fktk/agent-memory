#!/usr/bin/env bash
# memory-write.sh — Write or update an agent memory
# Usage: memory-write.sh <title> <category> <tags> <content>
#    or: echo "content" | memory-write.sh <title> <category> <tags>
#
# Flow:
#   1. Search for similar existing memories (dedup)
#   2. If similar memory found (score > 0.8), update it
#   3. Otherwise, create new memory file with frontmatter
#   4. Run qmd embed to update index
set -euo pipefail

MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"
COLLECTION="${AGENT_MEMORY_COLLECTION:-agent-memory}"
DEDUP_THRESHOLD="${AGENT_MEMORY_DEDUP_THRESHOLD:-0.8}"
TODAY=$(date +%Y-%m-%d)

# --- argument parsing ---
TITLE=""
CATEGORY=""
TAGS=""
CONTENT=""
FORCE=false
SOURCE="conversation"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)    FORCE=true;     shift ;;
    --source)   SOURCE="$2";    shift 2 ;;
    --help|-h)
      cat <<'HELP'
Usage: memory-write.sh <title> <category> <tags> <content>
   or: echo "content" | memory-write.sh <title> <category> <tags>

Write or update an agent memory file with YAML frontmatter.

Arguments:
  title       Memory title (will be slugified for filename)
  category    One of: lesson, knowledge, preference
  tags        Comma-separated tags (e.g., "coding-style,readability")
  content     Memory content (or pipe via stdin)

Options:
  --force     Skip duplicate check, always create new file
  --source    Source type: conversation, investigation, user-explicit (default: conversation)
  --help, -h  Show this help

Examples:
  memory-write.sh "Avoid nested ternary" lesson "coding-style,readability" \
    "Nested ternary operators harm readability. Use if/else instead."

  echo "Details..." | memory-write.sh "SQLite WAL mode" knowledge "sqlite,concurrency"
HELP
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$TITLE" ]]; then
        TITLE="$1"
      elif [[ -z "$CATEGORY" ]]; then
        CATEGORY="$1"
      elif [[ -z "$TAGS" ]]; then
        TAGS="$1"
      elif [[ -z "$CONTENT" ]]; then
        CONTENT="$1"
      else
        CONTENT="$CONTENT $1"
      fi
      shift
      ;;
  esac
done

# Read content from stdin if not provided as argument
if [[ -z "$CONTENT" ]] && [[ ! -t 0 ]]; then
  CONTENT=$(cat)
fi

# --- validation ---
if [[ -z "$TITLE" ]]; then
  echo "Error: Title is required." >&2
  exit 1
fi
if [[ -z "$CATEGORY" ]]; then
  echo "Error: Category is required (lesson, knowledge, preference)." >&2
  exit 1
fi
if [[ ! "$CATEGORY" =~ ^(lesson|knowledge|preference)$ ]]; then
  echo "Error: Category must be one of: lesson, knowledge, preference (got: $CATEGORY)" >&2
  exit 1
fi
if [[ -z "$CONTENT" ]]; then
  echo "Error: Content is required (as argument or via stdin)." >&2
  exit 1
fi

# Check qmd is available
if ! command -v qmd &>/dev/null; then
  echo "Error: qmd is not installed. Run: npm install -g @tobilu/qmd" >&2
  exit 1
fi

# --- ensure memory directory exists ---
mkdir -p "$MEMORY_DIR"

# --- slugify title for filename ---
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9ぁ-んァ-ヶー一-龠]/-/g' \
    | sed 's/--*/-/g; s/^-//; s/-$//' \
    | cut -c1-80
}

SLUG=$(slugify "$TITLE")
FILENAME="${SLUG}.md"
FILEPATH="$MEMORY_DIR/$FILENAME"

# --- dedup check ---
UPDATE_TARGET=""

if [[ "$FORCE" != "true" ]]; then
  # Search for similar memories
  SEARCH_RESULT=$(qmd query "$TITLE" \
    -c "$COLLECTION" \
    -n 3 \
    --min-score "$DEDUP_THRESHOLD" \
    --json 2>/dev/null || echo "[]")

  # Check if we got any high-score matches
  if [[ "$SEARCH_RESULT" != "[]" && -n "$SEARCH_RESULT" ]]; then
    # Extract the top match file path using python3
    MATCH_INFO=$(echo "$SEARCH_RESULT" | python3 -c "
import json, sys, os
try:
    results = json.load(sys.stdin)
    if not isinstance(results, list):
        results = results.get('results', [])
    if results:
        top = results[0]
        score = top.get('score', 0)
        fpath = top.get('file', top.get('path', ''))
        title = top.get('title', '')
        # Extract actual filesystem path from qmd URI
        # qmd returns paths like 'qmd://collection/filename'
        if fpath.startswith('qmd://'):
            parts = fpath.split('/', 3)
            if len(parts) >= 4:
                fpath = parts[3]
            else:
                fpath = ''
        print(f'{score}|{fpath}|{title}')
except Exception:
    pass
" 2>/dev/null || echo "")

    if [[ -n "$MATCH_INFO" ]]; then
      MATCH_SCORE=$(echo "$MATCH_INFO" | cut -d'|' -f1)
      MATCH_PATH=$(echo "$MATCH_INFO" | cut -d'|' -f2)
      MATCH_TITLE=$(echo "$MATCH_INFO" | cut -d'|' -f3-)

      # Check if score exceeds threshold
      IS_DUPLICATE=$(python3 -c "print('yes' if float('${MATCH_SCORE}') >= float('${DEDUP_THRESHOLD}') else 'no')" 2>/dev/null || echo "no")

      if [[ "$IS_DUPLICATE" == "yes" && -n "$MATCH_PATH" ]]; then
        # Resolve the actual file path
        if [[ -f "$MEMORY_DIR/$MATCH_PATH" ]]; then
          UPDATE_TARGET="$MEMORY_DIR/$MATCH_PATH"
        elif [[ -f "$MATCH_PATH" ]]; then
          UPDATE_TARGET="$MATCH_PATH"
        fi

        if [[ -n "$UPDATE_TARGET" ]]; then
          echo "Found similar memory (score: $MATCH_SCORE): $MATCH_TITLE"
          echo "Updating existing file: $(basename "$UPDATE_TARGET")"
          FILEPATH="$UPDATE_TARGET"
          FILENAME=$(basename "$FILEPATH")
        fi
      fi
    fi
  fi
fi

# --- format tags as YAML array ---
format_tags() {
  local tags_str="$1"
  if [[ -z "$tags_str" ]]; then
    echo "[]"
    return
  fi
  local formatted="["
  local first=true
  IFS=',' read -ra tag_array <<< "$tags_str"
  for tag in "${tag_array[@]}"; do
    tag=$(echo "$tag" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [[ "$first" == "true" ]]; then
      formatted="${formatted}${tag}"
      first=false
    else
      formatted="${formatted}, ${tag}"
    fi
  done
  formatted="${formatted}]"
  echo "$formatted"
}

TAGS_YAML=$(format_tags "$TAGS")

# --- determine confidence ---
CONFIDENCE="medium"
if [[ "$SOURCE" == "user-explicit" ]]; then
  CONFIDENCE="high"
fi

# --- write the file ---
if [[ -n "$UPDATE_TARGET" ]]; then
  # Update existing file: preserve created date, update content
  CREATED=$(sed -n '/^---$/,/^---$/{ /^created:/{ s/^created:[[:space:]]*//; p; q; } }' "$FILEPATH" 2>/dev/null || echo "$TODAY")
  OLD_CONFIDENCE=$(sed -n '/^---$/,/^---$/{ /^confidence:/{ s/^confidence:[[:space:]]*//; p; q; } }' "$FILEPATH" 2>/dev/null || echo "")
  # Don't downgrade confidence
  if [[ "$OLD_CONFIDENCE" == "high" ]]; then
    CONFIDENCE="high"
  fi
else
  CREATED="$TODAY"
fi

cat > "$FILEPATH" <<EOF
---
title: "$TITLE"
category: $CATEGORY
tags: $TAGS_YAML
created: $CREATED
updated: $TODAY
source: $SOURCE
confidence: $CONFIDENCE
---

$CONTENT
EOF

echo "Memory written: $FILENAME"

# --- ensure collection exists and update index ---
# Register collection (idempotent — qmd ignores if already exists)
qmd collection add "$MEMORY_DIR" --name "$COLLECTION" 2>/dev/null || true

# Update index
echo "Updating qmd index..."
qmd embed 2>/dev/null && echo "Index updated." || echo "Warning: qmd embed failed. Run 'qmd embed' manually." >&2

echo "Done."
