#!/usr/bin/env bash
# uninstall.sh — remove the passwordless vt setup.
#
# 1. Removes /etc/sudoers.d/chvt-$USER.
# 2. Removes the SKILL.md symlink in ~/.claude/skills/vt/.
# 3. Prints the source line the user should strip from their shell rc.
#
# Leaves the chvt binary, kbd package, and the repo itself alone.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

USER_NAME="${USER:-$(id -un)}"
SUDOERS_FILE="/etc/sudoers.d/chvt-${USER_NAME}"

SKILL_DST_DIR="$HOME/.claude/skills/vt"
SKILL_DST="$SKILL_DST_DIR/SKILL.md"

ALIASES_SRC="$REPO_DIR/aliases.sh"

info() { printf 'vt-uninstall: %s\n' "$*"; }
err()  { printf 'vt-uninstall: %s\n' "$*" >&2; }

# ── Remove sudoers rule ──────────────────────────────────────────────────────

info "checking for ${SUDOERS_FILE} (sudo may prompt for your password)"
if sudo test -f "$SUDOERS_FILE"; then
    if sudo rm -f "$SUDOERS_FILE"; then
        info "removed ${SUDOERS_FILE}"
    else
        err "failed to remove ${SUDOERS_FILE}"
        exit 1
    fi
else
    info "no sudoers file at ${SUDOERS_FILE} (already removed?)"
fi

# ── Remove skill symlink ─────────────────────────────────────────────────────

if [ -L "$SKILL_DST" ]; then
    rm "$SKILL_DST"
    info "removed symlink: $SKILL_DST"
    # Remove the skill dir if it's now empty
    if [ -d "$SKILL_DST_DIR" ] && [ -z "$(ls -A "$SKILL_DST_DIR")" ]; then
        rmdir "$SKILL_DST_DIR"
        info "removed empty skill dir: $SKILL_DST_DIR"
    fi
elif [ -e "$SKILL_DST" ]; then
    info "$SKILL_DST exists but is not a symlink — leaving it alone"
else
    info "no skill symlink at $SKILL_DST"
fi

# ── Post-uninstall instructions ──────────────────────────────────────────────

cat <<EOF

vt uninstalled.

If you added this line to ~/.bashrc (or ~/.zshrc), remove it:

    source $ALIASES_SRC

The alias will still be active in any shell that already loaded it.
Run 'unalias vt' in those shells, or open a new one, to fully clear it.
EOF
