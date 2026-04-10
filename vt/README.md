# vt — Virtual Terminal Switcher Skill

Passwordless VT (virtual terminal / TTY) switching for Wayland desktops.
Installs a narrowly-scoped sudoers rule and a `vt` shell alias so you can
jump between the graphical session and a bare TTY with a single short
command.

## Why this exists

`Ctrl+Alt+F1` .. `Ctrl+Alt+F6` are **kernel-level** VT switch chords.
From inside a Wayland compositor like Hyprland, userspace keypress
injectors like `wtype`, `hyprctl dispatch`, and `xdotool` cannot trigger
them — those events never reach the kernel VT layer. The direct tool is
`chvt` (from the `kbd` package), which calls the `VT_ACTIVATE` ioctl.

`chvt` requires `CAP_SYS_TTY_CONFIG`, which normal users don't have. The
common workarounds are:

| Approach | Scope | Verdict |
|---|---|---|
| Add user to `tty` group | — | **Doesn't work.** `tty` only grants device-file access, not VT switching |
| `setcap cap_sys_tty_config+ep /usr/bin/chvt` | All users | Works, but wiped on every `kbd` package upgrade |
| NOPASSWD sudoers rule for `/usr/bin/chvt` | Single user | Works, survives upgrades, minimal blast radius |
| Setuid wrapper script | Custom | More moving parts than needed |

This skill picks the sudoers rule.

## What gets installed

1. `/etc/sudoers.d/chvt-$USER` — a single line:
   ```
   <user> ALL=(root) NOPASSWD: /usr/bin/chvt
   ```
   Grants `NOPASSWD` for *only* `/usr/bin/chvt`. No other commands gain
   passwordless access.

2. A symlink at `~/.claude/skills/vt/SKILL.md` pointing to this repo's
   `SKILL.md`, so Claude Code picks up the skill at runtime.

3. **You** add one line to your shell rc to enable the `vt` alias:
   ```
   source ~/git/github.com/mbarlow/skills/vt/aliases.sh
   ```
   The installer prints this line at the end — it does not touch your
   shell rc automatically.

## Install

```bash
~/git/github.com/mbarlow/skills/vt/install.sh
```

The script will:

1. Check that `chvt` is on the `PATH` (fails loudly if the `kbd`
   package is missing).
2. Stage a sudoers snippet in a temp file and validate it with
   `visudo -c`.
3. Run `sudo install -m 440 -o root -g root` to put it in
   `/etc/sudoers.d/chvt-$USER` (prompts for password once).
4. Symlink `SKILL.md` into `~/.claude/skills/vt/` (backing up any
   existing real file as `.bak`).
5. Clear the sudo credential cache and run `sudo -n chvt 99` as a
   real end-to-end test. A successful test returns chvt's own error
   (`Couldn't activate vt 99: No such device or address`), proving
   sudo let the call through without a password.
6. Print the `source` line to add to your shell rc.

The script is idempotent — safe to re-run. If the sudoers file already
exists, it is replaced only after re-validation.

**Must be run interactively.** `sudo install` needs a real TTY to
prompt for your password. Don't pipe it through a non-interactive
wrapper or the credential prompt will vanish and the install will fail
silently.

## Usage after install

Open a new shell (or `source ~/.bashrc`), then:

```bash
vt 3    # jump to TTY3
vt 1    # back to the graphical session (Hyprland, GDM, etc.)
```

You can also use `sudo chvt <n>` directly without the alias.

## Uninstall

```bash
~/git/github.com/mbarlow/skills/vt/uninstall.sh
```

Removes `/etc/sudoers.d/chvt-$USER` (prompts for password once) and
the `SKILL.md` symlink in `~/.claude/skills/vt/`. The `kbd` package,
the `chvt` binary, and the repo itself are left alone. Strip the
`source` line from your shell rc by hand.

## Files

```
vt/
├── README.md      # this file
├── SKILL.md       # Claude Code skill definition (symlinked into ~/.claude/skills/vt/)
├── aliases.sh     # shell alias(es) — source from ~/.bashrc
├── install.sh     # idempotent installer
└── uninstall.sh   # removes the sudoers rule and skill symlink
```

## Compatibility

- **OS:** Linux with SysV-style virtual terminals (most distros).
- **Shells:** `aliases.sh` is bash/zsh-compatible. Fish users will need
  to translate the alias into their own syntax.
- **Packages required:** `kbd` (provides `chvt`) and `sudo`.
- **Not applicable to:** macOS, Windows, systems without Linux VTs, or
  environments where `/etc/sudoers.d` isn't honored (some container
  images strip it).
