#!/usr/bin/env bash
# install.sh — Symlink support into ~/.local/bin and ~/.claude/skills/support
#
# Idempotent: safe to re-run. Existing non-symlink files are backed up as *.bak
# before being replaced.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_SRC="$REPO_DIR/bin/support"
SKILL_SRC="$REPO_DIR/SKILL.md"

BIN_DST="$HOME/.local/bin/support"
SKILL_DST_DIR="$HOME/.claude/skills/support"
SKILL_DST="$SKILL_DST_DIR/SKILL.md"

# ── Helpers ──────────────────────────────────────────────────────────────────

_link() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ]; then
        ln -sfn "$src" "$dst"
        echo "  updated symlink: $dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "${dst}.bak"
        echo "  backed up existing file: ${dst}.bak"
        ln -s "$src" "$dst"
        echo "  created symlink: $dst"
    else
        ln -s "$src" "$dst"
        echo "  created symlink: $dst"
    fi
}

# ── Pre-flight ───────────────────────────────────────────────────────────────

echo "Installing support from: $REPO_DIR"
echo ""

if [ ! -x "$BIN_SRC" ]; then
    echo "Making $BIN_SRC executable..."
    chmod +x "$BIN_SRC"
fi

if [ ! -f "$SKILL_SRC" ]; then
    echo "Error: $SKILL_SRC not found." >&2
    exit 1
fi

# ── Dependency check ─────────────────────────────────────────────────────────

missing_deps=()
command -v jq  >/dev/null 2>&1 || missing_deps+=("jq")
command -v gh  >/dev/null 2>&1 || missing_deps+=("gh")
command -v git >/dev/null 2>&1 || missing_deps+=("git")

if [ "${#missing_deps[@]}" -gt 0 ]; then
    echo "Warning: missing dependencies: ${missing_deps[*]}"
    echo "         support will not work correctly until these are installed."
    echo ""
fi

if ! command -v check-jsonschema >/dev/null 2>&1; then
    echo "Note: check-jsonschema not found — 'support validate' will use a structural"
    echo "      required-fields check instead of full JSON Schema validation."
    echo "      Install with:  pipx install check-jsonschema   (optional)"
    echo ""
fi

# ── Support repo check ───────────────────────────────────────────────────────

SUPPORT_REPO="${SUPPORT_REPO:-$HOME/git/github.com/mbarlow/support}"
if [ ! -d "$SUPPORT_REPO" ]; then
    echo "Warning: SUPPORT_REPO not found at $SUPPORT_REPO"
    echo "         Clone or create it before running 'support new'."
    echo "         Override with: export SUPPORT_REPO=/path/to/repo"
    echo ""
fi

# ── Install ──────────────────────────────────────────────────────────────────

mkdir -p "$HOME/.local/bin"
mkdir -p "$SKILL_DST_DIR"

echo "Linking support script:"
_link "$BIN_SRC" "$BIN_DST"

echo ""
echo "Linking Claude skill definition:"
_link "$SKILL_SRC" "$SKILL_DST"

# ── Post-install instructions ────────────────────────────────────────────────

echo ""
echo "✓ support installed."
echo ""
echo "To enable the sup-* aliases, add this line to your ~/.bashrc (or ~/.zshrc):"
echo ""
echo "    source $REPO_DIR/aliases.sh"
echo ""
echo "Then reload your shell: source ~/.bashrc"
echo ""
echo "Verify with: support help"
