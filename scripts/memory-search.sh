#!/usr/bin/env bash
# memory-search.sh — Search agent memories using qmd hybrid search
# Usage: memory-search.sh <query> [--limit N] [--min-score SCORE] [--json] [--collection NAME]
set -euo pipefail

MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"
COLLECTION="${AGENT_MEMORY_COLLECTION:-agent-memory}"

# --- argument parsing ---
QUERY=""
LIMIT=10
MIN_SCORE="0.3"
JSON_OUTPUT=false
EXTRA_COLLECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit)      LIMIT="$2";         shift 2 ;;
    --min-score)  MIN_SCORE="$2";     shift 2 ;;
    --json)       JSON_OUTPUT=true;   shift   ;;
    --collection) EXTRA_COLLECTION="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: memory-search.sh <query> [--limit N] [--min-score SCORE] [--json] [--collection NAME]"
      echo ""
      echo "Search agent memories using qmd hybrid search (BM25 + vector + reranking)."
      echo ""
      echo "Options:"
      echo "  --limit N          Max results (default: 10)"
      echo "  --min-score SCORE  Minimum relevance 0-1 (default: 0.3)"
      echo "  --json             Output raw JSON from qmd"
      echo "  --collection NAME  Search specific collection (default: agent-memory)"
      echo "  --help, -h         Show this help"
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"
      else
        # Append additional words to query
        QUERY="$QUERY $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$QUERY" ]]; then
  echo "Error: No search query provided." >&2
  echo "Usage: memory-search.sh <query> [--limit N] [--min-score SCORE] [--json]" >&2
  exit 1
fi

# Check qmd is available
if ! command -v qmd &>/dev/null; then
  echo "Error: qmd is not installed. Run: npm install -g @tobilu/qmd" >&2
  exit 1
fi

# Check if memory directory exists
if [[ ! -d "$MEMORY_DIR" ]]; then
  echo "No memories found. Memory directory does not exist: $MEMORY_DIR" >&2
  exit 0
fi

# --- build qmd command ---
COLLECTION_FILTER="${EXTRA_COLLECTION:-$COLLECTION}"

if [[ "$JSON_OUTPUT" == "true" ]]; then
  qmd query "$QUERY" \
    -c "$COLLECTION_FILTER" \
    -n "$LIMIT" \
    --min-score "$MIN_SCORE" \
    --json
else
  # Human-readable output with context
  RESULTS=$(qmd query "$QUERY" \
    -c "$COLLECTION_FILTER" \
    -n "$LIMIT" \
    --min-score "$MIN_SCORE" \
    --json 2>/dev/null || echo "[]")

  # Check if results are empty
  if [[ "$RESULTS" == "[]" || -z "$RESULTS" ]]; then
    echo "No relevant memories found for: \"$QUERY\""
    exit 0
  fi

  echo "=== Agent Memory Search Results ==="
  echo "Query: \"$QUERY\""
  echo "---"

  # Parse JSON results and display formatted output
  echo "$RESULTS" | python3 -c "
import json, sys
try:
    results = json.load(sys.stdin)
    if not isinstance(results, list):
        results = results.get('results', [])
    for i, r in enumerate(results, 1):
        score = r.get('score', 0)
        title = r.get('title', 'Untitled')
        path = r.get('file', r.get('path', ''))
        snippet = r.get('snippet', r.get('content', ''))
        context = r.get('context', '')
        print(f'[{i}] {title} (score: {score:.2f})')
        if path:
            print(f'    File: {path}')
        if context:
            print(f'    Context: {context}')
        if snippet:
            # Truncate snippet to 200 chars
            snippet_clean = snippet.strip().replace('\n', ' ')
            if len(snippet_clean) > 200:
                snippet_clean = snippet_clean[:200] + '...'
            print(f'    {snippet_clean}')
        print()
    print(f'--- {len(results)} result(s) found ---')
except Exception as e:
    print(f'Error parsing results: {e}', file=sys.stderr)
    sys.exit(1)
"
fi
