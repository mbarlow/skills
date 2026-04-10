#!/usr/bin/env bash
# install.sh — set up passwordless virtual terminal switching.
#
# 1. Installs a NOPASSWD sudoers rule scoped to /usr/bin/chvt for the
#    current user.
# 2. Symlinks SKILL.md into ~/.claude/skills/vt/ so Claude Code picks
#    it up at runtime.
# 3. Prints the line the user should add to their shell rc to enable
#    the `vt` alias.
#
# Idempotent: safe to re-run. Existing non-symlink files at the skill
# destination are backed up as *.bak before being replaced.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

USER_NAME="${USER:-$(id -un)}"
SUDOERS_FILE="/etc/sudoers.d/chvt-${USER_NAME}"
STAGED="$(mktemp -t "chvt-${USER_NAME}.XXXXXX")"

SKILL_SRC="$REPO_DIR/SKILL.md"
SKILL_DST_DIR="$HOME/.claude/skills/vt"
SKILL_DST="$SKILL_DST_DIR/SKILL.md"

ALIASES_SRC="$REPO_DIR/aliases.sh"

trap 'rm -f "$STAGED"' EXIT

info() { printf 'vt-install: %s\n' "$*"; }
err()  { printf 'vt-install: %s\n' "$*" >&2; }

# ── Helpers ──────────────────────────────────────────────────────────────────

_link() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ]; then
        ln -sfn "$src" "$dst"
        info "  updated symlink: $dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "${dst}.bak"
        info "  backed up existing file: ${dst}.bak"
        ln -s "$src" "$dst"
        info "  created symlink: $dst"
    else
        ln -s "$src" "$dst"
        info "  created symlink: $dst"
    fi
}

# ── Pre-flight ───────────────────────────────────────────────────────────────

info "installing vt from: $REPO_DIR"

if ! command -v chvt >/dev/null 2>&1; then
    err "chvt not found on PATH — install the 'kbd' package first:"
    err "  Arch:   sudo pacman -S kbd"
    err "  Debian: sudo apt install kbd"
    err "  Fedora: sudo dnf install kbd"
    exit 1
fi
CHVT_PATH="$(command -v chvt)"
info "found chvt at ${CHVT_PATH}"

if ! command -v visudo >/dev/null 2>&1; then
    err "visudo not found — the sudo package is required"
    exit 1
fi

if [ ! -f "$SKILL_SRC" ]; then
    err "$SKILL_SRC not found"
    exit 1
fi

if [ ! -f "$ALIASES_SRC" ]; then
    err "$ALIASES_SRC not found"
    exit 1
fi

# ── Stage and validate sudoers snippet ───────────────────────────────────────

printf '%s ALL=(root) NOPASSWD: %s\n' "$USER_NAME" "$CHVT_PATH" > "$STAGED"
chmod 440 "$STAGED"

if ! visudo -c -f "$STAGED" >/dev/null; then
    err "staged sudoers file failed syntax validation — aborting"
    exit 1
fi
info "sudoers snippet validated"

# ── Install sudoers rule ─────────────────────────────────────────────────────

info "installing ${SUDOERS_FILE} (sudo may prompt for your password)"
if ! sudo install -m 440 -o root -g root "$STAGED" "$SUDOERS_FILE"; then
    err "failed to install sudoers file"
    exit 1
fi
info "installed ${SUDOERS_FILE}"

# ── Symlink SKILL.md into ~/.claude/skills/vt/ ──────────────────────────────

mkdir -p "$SKILL_DST_DIR"
info "linking Claude skill definition:"
_link "$SKILL_SRC" "$SKILL_DST"

# ── End-to-end NOPASSWD verification ────────────────────────────────────────

info "verifying NOPASSWD rule (clearing sudo credential cache)..."
sudo -K

set +e
output="$(sudo -n chvt 99 2>&1)"
rc=$?
set -e

if printf '%s' "$output" | grep -qi 'password is required'; then
    err "NOPASSWD verification FAILED — sudo still requires a password"
    err "  output: $output"
    err "  check ${SUDOERS_FILE} and any overriding rules in /etc/sudoers"
    exit 1
fi

if [[ $rc -eq 0 ]] || printf '%s' "$output" | grep -qi 'no such device'; then
    info "NOPASSWD verified"
else
    err "unexpected output from 'sudo -n chvt 99':"
    err "  rc=$rc output=$output"
    exit 1
fi

# ── Post-install instructions ────────────────────────────────────────────────

cat <<EOF

vt installed.

To enable the \`vt\` alias, add this line to your ~/.bashrc (or ~/.zshrc):

    source $ALIASES_SRC

Then reload your shell: source ~/.bashrc

Usage:
  vt 3    # jump to TTY3
  vt 1    # back to the graphical session

Docs: $REPO_DIR/README.md
EOF
