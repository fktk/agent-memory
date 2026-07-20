#!/usr/bin/env bash
# init-memory.sh — Initialize the qmd backend for Agent Memory System
# Run after `apm install`: registers the qmd collection and builds the index.
# Usage: ./scripts/init-memory.sh
set -euo pipefail

MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"
COLLECTION="${AGENT_MEMORY_COLLECTION:-agent-memory}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW:-}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- prerequisites ---
if ! command -v qmd &>/dev/null; then
  error "qmd is not installed."
  echo "  Install with: npm install -g @tobilu/qmd"
  echo "  Or:           bun install -g @tobilu/qmd"
  exit 1
fi
success "qmd is installed: $(qmd --version 2>/dev/null || echo 'unknown version')"

if ! command -v python3 &>/dev/null; then
  error "python3 is required for JSON parsing in memory scripts."
  exit 1
fi
success "python3 is available"

# --- memory directory ---
mkdir -p "$MEMORY_DIR"
success "Memory directory: $MEMORY_DIR"

# --- register qmd collection ---
info "Registering qmd collection..."
qmd collection add "$MEMORY_DIR" --name "$COLLECTION" 2>/dev/null && \
  success "Collection '$COLLECTION' registered" || \
  success "Collection '$COLLECTION' already exists"

qmd context add "qmd://$COLLECTION" "LLMエージェントが記録した教訓(lesson)、調査知識(knowledge)、ユーザーの好み(preference)。プロジェクト横断で再利用する汎用的なナレッジベース。" 2>/dev/null && \
  success "Context added for collection" || \
  success "Context already exists"

# --- initial embedding ---
info "Running initial embedding..."
qmd embed 2>/dev/null && \
  success "Index ready" || \
  warn "Embedding skipped (no documents yet or model loading issue)"

success "Agent Memory System backend initialized."
echo "Try it out:"
echo "  memory-write.sh \"Test memory\" knowledge \"test\" \"This is a test memory.\""
echo "  memory-search.sh \"test\""
