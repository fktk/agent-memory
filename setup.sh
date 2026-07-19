#!/usr/bin/env bash
# setup.sh — Install Agent Memory System
# Usage: ./setup.sh [--uninstall]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DIR="${AGENT_MEMORY_DIR:-$HOME/.local/share/qmd/docs}"
COLLECTION="${AGENT_MEMORY_COLLECTION:-agent-memory}"
BIN_DIR="$HOME/.local/bin"
RULES_FILE="$SCRIPT_DIR/rules/copilot-memory-rules.md"
SKILLS_DIR="$SCRIPT_DIR/skills"
COPILOT_INSTRUCTIONS="$HOME/.github/copilot-instructions.md"
COPILOT_SKILLS_DIR="$HOME/.github/copilot/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# --- uninstall ---
if [[ "${1:-}" == "--uninstall" ]]; then
  info "Uninstalling Agent Memory System..."

  rm -f "$BIN_DIR/memory-write.sh" \
        "$BIN_DIR/memory-search.sh" \
        "$BIN_DIR/memory-status.sh" \
        "$BIN_DIR/memory-delete.sh"
  success "Scripts removed from $BIN_DIR"

  rm -rf "$COPILOT_SKILLS_DIR/memory-write" \
         "$COPILOT_SKILLS_DIR/memory-search" \
         "$COPILOT_SKILLS_DIR/memory-status" \
         "$COPILOT_SKILLS_DIR/memory-delete"
  success "Skills removed from $COPILOT_SKILLS_DIR"

  warn "Memory files in $MEMORY_DIR are preserved."
  warn "copilot-instructions.md was NOT modified. Remove the 'Agent Memory System' section manually if desired."

  echo ""
  success "Uninstall complete."
  exit 0
fi

echo "======================================"
echo "  Agent Memory System — Setup"
echo "======================================"
echo ""

# --- step 1: check prerequisites ---
info "Checking prerequisites..."

if ! command -v qmd &>/dev/null; then
  error "qmd is not installed."
  echo "  Install with: npm install -g @tobilu/qmd"
  echo "  Or:           bun install -g @tobilu/qmd"
  exit 1
fi
success "qmd is installed: $(qmd --version 2>/dev/null || echo 'unknown version')"

if ! command -v python3 &>/dev/null; then
  error "python3 is required for JSON parsing in scripts."
  exit 1
fi
success "python3 is available"

# --- step 2: create directories ---
info "Creating directories..."

mkdir -p "$MEMORY_DIR"
success "Memory directory: $MEMORY_DIR"

mkdir -p "$BIN_DIR"
success "Script directory: $BIN_DIR"

mkdir -p "$(dirname "$COPILOT_INSTRUCTIONS")"
success "Copilot config directory: $(dirname "$COPILOT_INSTRUCTIONS")"

# --- step 3: install scripts ---
info "Installing scripts..."

for skill in memory-write memory-search memory-status memory-delete; do
  src="$SKILLS_DIR/$skill/scripts/${skill}.sh"
  dst="$BIN_DIR/${skill}.sh"

  if [[ ! -f "$src" ]]; then
    warn "Script not found: $src (skipping)"
    continue
  fi

  cp "$src" "$dst"
  chmod +x "$dst"
  success "Installed: $dst"
done

# Ensure ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  warn "$BIN_DIR is not in your PATH."
  echo "  Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
fi

# --- step 4: register qmd collection ---
info "Registering qmd collection..."

qmd collection add "$MEMORY_DIR" --name "$COLLECTION" 2>/dev/null && \
  success "Collection '$COLLECTION' registered" || \
  success "Collection '$COLLECTION' already exists"

# Add context for better search results
qmd context add "qmd://$COLLECTION" "LLMエージェントが記録した教訓(lesson)、調査知識(knowledge)、ユーザーの好み(preference)。プロジェクト横断で再利用する汎用的なナレッジベース。" 2>/dev/null && \
  success "Context added for collection" || \
  success "Context already exists"

# --- step 5: install copilot instructions ---
info "Setting up copilot-instructions.md..."

if [[ ! -f "$RULES_FILE" ]]; then
  warn "Rules file not found: $RULES_FILE"
  warn "Skipping copilot-instructions.md setup."
else
  if [[ -f "$COPILOT_INSTRUCTIONS" ]]; then
    # Check if already installed
    if grep -q "Agent Memory System" "$COPILOT_INSTRUCTIONS" 2>/dev/null; then
      warn "Agent Memory System section already exists in copilot-instructions.md"
      echo "  To update, remove the existing section and re-run setup."
    else
      echo "" >> "$COPILOT_INSTRUCTIONS"
      cat "$RULES_FILE" >> "$COPILOT_INSTRUCTIONS"
      success "Rules appended to: $COPILOT_INSTRUCTIONS"
    fi
  else
    cp "$RULES_FILE" "$COPILOT_INSTRUCTIONS"
    success "Created: $COPILOT_INSTRUCTIONS"
  fi
fi

# --- step 6: install copilot skills ---
info "Installing Copilot skills..."

mkdir -p "$COPILOT_SKILLS_DIR"

for skill in memory-write memory-search memory-status memory-delete; do
  src="$SKILLS_DIR/$skill"
  dst="$COPILOT_SKILLS_DIR/$skill"

  if [[ ! -d "$src" ]]; then
    warn "Skill not found: $src (skipping)"
    continue
  fi

  cp -r "$src" "$dst"
  chmod +x "$dst/scripts/"*.sh 2>/dev/null || true
  success "Skill installed: $dst"
done

# --- step 7: initial embed ---
info "Running initial embedding..."
qmd embed 2>/dev/null && \
  success "Index ready" || \
  warn "Embedding skipped (no documents yet or model loading issue)"

# --- done ---
echo ""
echo "======================================"
echo "  Setup Complete!"
echo "======================================"
echo ""
echo "Available commands:"
echo "  memory-write.sh  <title> <category> <tags> <content>"
echo "  memory-search.sh <query> [--limit N] [--min-score SCORE]"
echo "  memory-status.sh [--json]"
echo "  memory-delete.sh <filename-or-title>"
echo ""
echo "Installed to:"
echo "  Scripts: $BIN_DIR/memory-*.sh"
echo "  Skills:  $COPILOT_SKILLS_DIR/memory-*/SKILL.md"
echo "  Rules:   $COPILOT_INSTRUCTIONS"
echo "  Memory:  $MEMORY_DIR"
echo ""
echo "Try it out:"
echo "  memory-write.sh \"Test memory\" knowledge \"test\" \"This is a test memory.\""
echo "  memory-search.sh \"test\""
echo "  memory-status.sh"

