#!/usr/bin/env bash
# install.sh — Symlink csm into ~/.local/bin and ~/.claude/skills/csm
#
# Idempotent: safe to re-run. Existing non-symlink files are backed up as *.bak
# before being replaced.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_SRC="$REPO_DIR/bin/csm"
SKILL_SRC="$REPO_DIR/SKILL.md"

BIN_DST="$HOME/.local/bin/csm"
SKILL_DST_DIR="$HOME/.claude/skills/csm"
SKILL_DST="$SKILL_DST_DIR/SKILL.md"

# ── Helpers ──────────────────────────────────────────────────────────────────

_link() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ]; then
        # Already a symlink — replace (ln -sfn handles this atomically).
        ln -sfn "$src" "$dst"
        echo "  updated symlink: $dst"
    elif [ -e "$dst" ]; then
        # Real file in the way — back it up before replacing.
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

echo "Installing csm from: $REPO_DIR"
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
command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
command -v jq   >/dev/null 2>&1 || missing_deps+=("jq")

if [ "${#missing_deps[@]}" -gt 0 ]; then
    echo "Warning: missing dependencies: ${missing_deps[*]}"
    echo "         csm will not work correctly until these are installed."
    echo ""
fi

# Chrome binary detection is informational only — csm auto-detects at runtime.
chrome_found=""
for bin in google-chrome google-chrome-stable chromium chromium-browser chrome brave-browser; do
    if command -v "$bin" >/dev/null 2>&1; then
        chrome_found="$bin"
        break
    fi
done

if [ -z "$chrome_found" ]; then
    echo "Warning: no Chromium-based browser found on PATH."
    echo "         csm load will need CSM_CHROME_BIN set, or a browser installed."
    echo ""
else
    echo "Detected browser: $chrome_found"
    echo ""
fi

# ── Install ──────────────────────────────────────────────────────────────────

mkdir -p "$HOME/.local/bin"
mkdir -p "$SKILL_DST_DIR"

echo "Linking csm script:"
_link "$BIN_SRC" "$BIN_DST"

echo ""
echo "Linking Claude skill definition:"
_link "$SKILL_SRC" "$SKILL_DST"

# ── Post-install instructions ────────────────────────────────────────────────

echo ""
echo "✓ csm installed."
echo ""
echo "To enable the csm-* aliases, add this line to your ~/.bashrc (or ~/.zshrc):"
echo ""
echo "    source $REPO_DIR/aliases.sh"
echo ""
echo "Then reload your shell: source ~/.bashrc"
echo ""
echo "Verify with: csm help"
echo ""
echo "To save your first session, launch Chrome with:"
echo "    google-chrome --remote-debugging-port=9222"
echo "then run:"
echo "    csm save <name>"
