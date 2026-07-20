#!/usr/bin/env bash
# memory-maintain.sh — Librarian for the agent memory system
#
# The librarian consolidates, reflects on, and forgets memories so the
# memory store stays small and high-signal. LLM-driven judgement (merge /
# reflect) is delegated to the agent: this script only collects candidate
# memories, writes back the agent's decisions, and performs TTL-based
# forgetting that needs no LLM.
#
# Modes:
#   collect   Print candidate memories as JSON for the agent to analyze.
#   apply     Write back a JSON plan produced by the agent (merge/reflect).
#   forget    Delete stale memories by age / low confidence (no LLM needed).
#
# Usage:
#   memory-maintain.sh collect [--category Cat] [--tag Tag] [--limit N]
#   memory-maintain.sh apply   <plan.json> [--dry-run]
#   memory-maintain.sh forget  [--max-age DAYS] [--min-confidence LEVEL] [--dry-run]
set -euo pipefail

MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"
COLLECTION="${AGENT_MEMORY_COLLECTION:-agent-memory}"

MODE="${1:-}"
shift || true

# --- shared flags ---
CATEGORY=""
TAG=""
LIMIT=200
MAX_AGE_DAYS=180
MIN_CONFIDENCE="low"
DRY_RUN=false
PLAN_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --category)      CATEGORY="$2"; shift 2 ;;
    --tag)           TAG="$2";      shift 2 ;;
    --limit)         LIMIT="$2";    shift 2 ;;
    --max-age)       MAX_AGE_DAYS="$2"; shift 2 ;;
    --min-confidence) MIN_CONFIDENCE="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true;  shift ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$PLAN_FILE" ]]; then PLAN_FILE="$1"; fi
      shift
      ;;
  esac
done

# --- helpers ---
need_qmd() {
  if ! command -v qmd &>/dev/null; then
    echo "Error: qmd is not installed. Run: npm install -g @tobilu/qmd" >&2
    exit 1
  fi
}

# Convert a confidence level to a rank for comparison.
conf_rank() {
  case "$1" in
    high)   echo 3 ;;
    medium) echo 2 ;;
    low)    echo 1 ;;
    *)      echo 0 ;;
  esac
}

# ---------------------------------------------------------------------------
# collect — dump candidate memories as JSON for the agent to analyze
# ---------------------------------------------------------------------------
cmd_collect() {
  need_qmd
  if [[ ! -d "$MEMORY_DIR" ]]; then
    echo "[]"
    exit 0
  fi

  # Pull memories via qmd. With no query we list the whole collection by
  # querying a catch-all term. qmd is semantic, so an empty/near-empty result
  # is expected; in that case we scan the memory directory directly inside
  # python (which also applies the category/tag filters).
  local raw
  raw=$(qmd query "*" -c "$COLLECTION" -n "$LIMIT" --min-score 0 --json 2>/dev/null || echo "[]")

  # Normalize to a list, then filter by category/tag and emit a compact shape.
  CATEGORY="$CATEGORY" TAG="$TAG" MEMORY_DIR="$MEMORY_DIR" python3 -c "
import json, sys, os, re, glob

try:
    data = json.load(sys.stdin)
except Exception:
    data = []
if not isinstance(data, list):
    data = data.get('results', [])

# Fallback: if qmd returned nothing, scan the directory directly.
if not data:
    mdir = os.environ.get('MEMORY_DIR', '')
    data = [{'file': p, 'score': 1} for p in glob.glob(os.path.join(mdir, '*.md'))]

Cat = os.environ.get('CATEGORY', '')
Tag = os.environ.get('TAG', '')

def fm(path):
    try:
        with open(path, encoding='utf-8') as f:
            txt = f.read()
    except Exception:
        return None
    if not txt.startswith('---'):
        return None
    end = txt.find('\n---', 3)
    if end == -1:
        return None
    fm_text = txt[3:end]
    body = txt[end+4:].strip()
    meta = {}
    for line in fm_text.splitlines():
        m = re.match(r'^([a-zA-Z_]+):\s*(.*)$', line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            val = val.strip('\"')
            if val.startswith('[') and val.endswith(']'):
                val = [v.strip().strip('\"') for v in val[1:-1].split(',') if v.strip()]
            meta[key] = val
    return {'meta': meta, 'body': body, 'path': path}

out = []
mdir = os.environ.get('MEMORY_DIR', '')
for r in data:
    fpath = r.get('file', r.get('path', ''))
    if fpath.startswith('qmd://'):
        parts = fpath.split('/', 3)
        fpath = parts[3] if len(parts) >= 4 else ''
    full = fpath if os.path.isabs(fpath) else os.path.join(mdir, fpath)
    if not os.path.isfile(full):
        name = os.path.basename(fpath)
        cand = os.path.join(mdir, name)
        full = cand if os.path.isfile(cand) else None
    if not full or not os.path.isfile(full):
        continue
    info = fm(full)
    if info is None:
        continue
    if Cat and info['meta'].get('category') != Cat:
        continue
    if Tag:
        tags = info['meta'].get('tags', [])
        if Tag not in tags:
            continue
    out.append({
        'path': full,
        'filename': os.path.basename(full),
        'title': info['meta'].get('title', ''),
        'category': info['meta'].get('category', ''),
        'tags': info['meta'].get('tags', []),
        'created': info['meta'].get('created', ''),
        'updated': info['meta'].get('updated', ''),
        'confidence': info['meta'].get('confidence', 'low'),
        'content': info['body'],
    })

print(json.dumps(out, ensure_ascii=False, indent=2))
"
}

# ---------------------------------------------------------------------------
# apply — write back an agent-produced plan
# ---------------------------------------------------------------------------
cmd_apply() {
  if [[ -z "$PLAN_FILE" ]]; then
    echo "Error: apply requires a plan JSON file." >&2
    exit 1
  fi
  if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Error: plan file not found: $PLAN_FILE" >&2
    exit 1
  fi

  DRY_RUN="$DRY_RUN" MEMORY_DIR="$MEMORY_DIR" python3 - "$PLAN_FILE" <<'PY'
import json, sys, os, datetime

plan_path = sys.argv[1]
dry_run = os.environ.get('DRY_RUN') == 'true'
mdir = os.environ.get('MEMORY_DIR', '')
with open(plan_path, encoding='utf-8') as f:
    plan = json.load(f)
if not isinstance(plan, list):
    plan = plan.get('actions', [])

today = datetime.date.today().isoformat()
changed = 0
for act in plan:
    kind = act.get('action')
    if kind == 'merge':
        # Replace target file with consolidated content; record merged sources.
        target = act.get('target')
        if not os.path.isabs(target):
            target = os.path.join(mdir, target)
        if not os.path.isfile(target):
            print(f"[skip] merge target missing: {target}")
            continue
        new_body = act.get('content', '').strip()
        meta = act.get('meta', {})
        title = meta.get('title', '')
        category = meta.get('category', 'lesson')
        tags = meta.get('tags', [])
        conf = meta.get('confidence', 'medium')
        merged = act.get('merged_from', [])
        merged_line = ""
        if merged:
            merged_line = "\n# Merged from: " + ", ".join(merged)
        if dry_run:
            print(f"[dry-run] MERGE -> {target}\n  title={title} tags={tags}\n  {new_body[:120]}...")
            changed += 1
            continue
        with open(target, 'w', encoding='utf-8') as f:
            f.write(f"---\ntitle: \"{title}\"\ncategory: {category}\ntags: [{', '.join(tags)}]\n")
            f.write(f"created: {act.get('created', today)}\nupdated: {today}\nsource: librarian-merge\nconfidence: {conf}\n---\n\n{new_body}{merged_line}\n")
        print(f"[ok] MERGE -> {os.path.basename(target)}")
        changed += 1
    elif kind == 'reflect':
        # Create a new memory (uses memory-write conventions).
        title = act.get('title', '')
        category = act.get('category', 'lesson')
        tags = act.get('tags', [])
        body = act.get('content', '').strip()
        conf = act.get('confidence', 'medium')
        if not title or not body:
            print(f"[skip] reflect missing title/content")
            continue
        slug = ''.join(c if c.isalnum() or c in 'ぁ-んァ-ヶー一-龠' else '-' for c in title.lower())[:80].strip('-')
        fname = f"{slug}.md"
        full = os.path.join(mdir, fname)
        if dry_run:
            print(f"[dry-run] REFLECT -> {fname}\n  {body[:120]}...")
            changed += 1
            continue
        with open(full, 'w', encoding='utf-8') as f:
            f.write(f"---\ntitle: \"{title}\"\ncategory: {category}\ntags: [{', '.join(tags)}]\n")
            f.write(f"created: {today}\nupdated: {today}\nsource: librarian-reflect\nconfidence: {conf}\n---\n\n{body}\n")
        print(f"[ok] REFLECT -> {fname}")
        changed += 1
    elif kind == 'delete':
        target = act.get('target')
        if not os.path.isabs(target):
            target = os.path.join(mdir, target)
        if not os.path.isfile(target):
            print(f"[skip] delete target missing: {target}")
            continue
        if dry_run:
            print(f"[dry-run] DELETE -> {target}")
            changed += 1
            continue
        os.remove(target)
        print(f"[ok] DELETE -> {os.path.basename(target)}")
        changed += 1
    else:
        print(f"[skip] unknown action: {kind}")

print(f"--- {changed} action(s) {'planned' if dry_run else 'applied'} ---")
PY

  if [[ "$DRY_RUN" != "true" ]]; then
    need_qmd
    qmd embed 2>/dev/null && echo "Index updated." || echo "Warning: qmd embed failed." >&2
  fi
}

# ---------------------------------------------------------------------------
# forget — TTL-based forgetting, no LLM needed
# ---------------------------------------------------------------------------
cmd_forget() {
  need_qmd
  if [[ ! -d "$MEMORY_DIR" ]]; then
    echo "No memory directory."
    exit 0
  fi
  min_rank=$(conf_rank "$MIN_CONFIDENCE")
  cutoff=$(date -d "-$MAX_AGE_DAYS days" +%Y-%m-%d 2>/dev/null || date -v "-${MAX_AGE_DAYS}d" +%Y-%m-%d)

  local removed=0
  while IFS= read -r f; do
    read -r created updated conf < <(python3 -c "
import re
txt = open('$f', encoding='utf-8').read()
created = updated = conf = ''
m = re.search(r'^created:\s*(\S+)', txt, re.M)
if m: created = m.group(1)
m = re.search(r'^updated:\s*(\S+)', txt, re.M)
if m: updated = m.group(1)
m = re.search(r'^confidence:\s*(\S+)', txt, re.M)
if m: conf = m.group(1)
print(created, updated, conf)
")
    stale_date="${updated:-$created}"
    if [[ -z "$stale_date" || "$stale_date" < "$cutoff" ]]; then
      c_rank=$(conf_rank "$conf")
      if [[ "$c_rank" -le "$min_rank" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
          echo "[dry-run] FORGET -> $(basename "$f") (updated=$stale_date conf=$conf)"
        else
          rm -f "$f"
          echo "[ok] FORGET -> $(basename "$f")"
        fi
        removed=$((removed+1))
      fi
    fi
  done < <(find "$MEMORY_DIR" -maxdepth 1 -name '*.md' -type f)

  echo "--- $removed memory(ies) ${DRY_RUN:+planned for }forgotten (max_age=${MAX_AGE_DAYS}d, min_confidence=$MIN_CONFIDENCE) ---"

  if [[ "$DRY_RUN" != "true" && "$removed" -gt 0 ]]; then
    qmd embed 2>/dev/null && echo "Index updated." || echo "Warning: qmd embed failed." >&2
  fi
}

# --- dispatch ---
case "$MODE" in
  collect) cmd_collect ;;
  apply)   cmd_apply ;;
  forget)  cmd_forget ;;
  ""|-h|--help)
    cat <<'HELP'
memory-maintain.sh — Librarian for the agent memory system

Modes:
  collect [--category Cat] [--tag Tag] [--limit N]
      Print candidate memories as JSON for the agent to analyze (merge/reflect).
  apply <plan.json> [--dry-run]
      Write back an agent-produced plan of merge/reflect/delete actions.
  forget [--max-age DAYS] [--min-confidence LEVEL] [--dry-run]
      Delete memories older than max-age with confidence <= min-confidence.

The agent (Copilot CLI / OpenCode) performs the LLM judgement; this script
only collects, writes back, and forgets.
HELP
    ;;
  *)
    echo "Error: Unknown mode: $MODE" >&2
    echo "Try: memory-maintain.sh --help" >&2
    exit 1
    ;;
esac
