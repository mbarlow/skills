---
name: vt
description: Switch Linux virtual terminals (TTYs) from a Wayland/Hyprland session via the `vt` alias (wraps `chvt` with a NOPASSWD sudoers rule)
user_invocable: true
---

# vt — Virtual Terminal Switcher

`vt` is a shell alias for `sudo chvt` that lets the user jump between Linux virtual terminals without being prompted for a password. Source lives at `~/git/github.com/mbarlow/skills/vt/`; `install.sh` wires it up on a new machine.

## How it works

- `Ctrl+Alt+F<n>` VT switching is handled by the **kernel VT subsystem**, not the Wayland compositor. Tools like `wtype`, `hyprctl dispatch`, and `xdotool` cannot trigger it — they only send events to userspace clients.
- `chvt` (from the `kbd` package) calls the `VT_ACTIVATE` ioctl directly and is the correct tool.
- `chvt` needs `CAP_SYS_TTY_CONFIG`, which unprivileged users don't have. A NOPASSWD sudoers rule scoped to `/usr/bin/chvt` is the simplest way to avoid typing a password every switch.
- The `tty` group does **not** grant VT switching. It only grants read/write on tty device files. Don't suggest adding users to `tty` for this purpose.

## Commands

```bash
vt <n>        # switch to TTY<n>, e.g. `vt 3`
vt 1          # typically returns to the graphical session (Hyprland, GDM, etc.)
fgconsole     # print the current VT number (needs access to /dev/tty0)
```

## When to use this skill

- User asks how to switch to a TTY / virtual console from Hyprland (or any Wayland session).
- User asks why `Ctrl+Alt+F3` behavior is inconsistent, or why `wtype` / `hyprctl` can't send VT switch chords.
- User wants to install or set up passwordless VT switching on a fresh machine.
- User asks to install the `vt` alias or mentions `chvt`.

## Installation

Run the setup script from the source repo:

```bash
~/git/github.com/mbarlow/skills/vt/install.sh
```

It:
1. Verifies `chvt` is installed (part of the `kbd` package).
2. Stages a sudoers snippet scoped to the current user and validates it with `visudo -c`.
3. Installs it to `/etc/sudoers.d/chvt-$USER` via `sudo install` (prompts for password once).
4. Symlinks `SKILL.md` into `~/.claude/skills/vt/` so Claude Code picks it up at runtime.
5. Verifies the NOPASSWD rule with `sudo -K && sudo -n chvt 99` (expects `No such device or address` from chvt itself, not a sudo password error).
6. Prints the `source ~/git/github.com/mbarlow/skills/vt/aliases.sh` line to add to `~/.bashrc`.

The script is idempotent — re-running it is safe. Existing non-symlink files at the destination are backed up as `*.bak`.

## Uninstallation

```bash
~/git/github.com/mbarlow/skills/vt/uninstall.sh
```

Removes `/etc/sudoers.d/chvt-$USER` and the `~/.claude/skills/vt/SKILL.md` symlink. Leaves the repo itself alone; the user strips the `source` line from their shell rc by hand.

## Gotchas

- `install.sh` prompts for a sudo password; don't run it through a non-interactive channel (it will fail silently on credential prompts).
- On `kbd` package upgrades, the file-capability alternative (`setcap cap_sys_tty_config+ep /usr/bin/chvt`) gets wiped. The sudoers approach survives upgrades, which is why this skill uses it.
- After switching to a TTY, the terminal that launched Claude is backgrounded. A second Claude session running on the TTY itself would be needed to drive anything from there.

## Examples

User: "how do I switch to a TTY from Hyprland?"
→ Explain `vt <n>` / `sudo chvt <n>`, point to this skill if setup is needed.

User: "set up passwordless VT switching on this machine"
→ Run `~/git/github.com/mbarlow/skills/vt/install.sh` (interactively, so sudo can prompt).

User: "go to TTY3"
→ Suggest running `vt 3` themselves — Claude can't usefully switch VTs on behalf of the user because once the switch happens, the terminal Claude is running in is no longer foregrounded.
