#!/usr/bin/env bash
# install.sh — Symlink hyprlock-recovery skill into ~/.claude/skills/

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$REPO_DIR/SKILL.md"
SKILL_DST_DIR="$HOME/.claude/skills/hyprlock-recovery"
SKILL_DST="$SKILL_DST_DIR/SKILL.md"

_link() {
    local src="$1" dst="$2"
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

echo "Installing hyprlock-recovery skill from: $REPO_DIR"
echo ""

[ -f "$SKILL_SRC" ] || { echo "Error: $SKILL_SRC not found." >&2; exit 1; }

mkdir -p "$SKILL_DST_DIR"

echo "Linking Claude skill definition:"
_link "$SKILL_SRC" "$SKILL_DST"

echo ""
echo "✓ hyprlock-recovery skill installed."
echo "  Claude will automatically use this runbook when you report a frozen screen."
