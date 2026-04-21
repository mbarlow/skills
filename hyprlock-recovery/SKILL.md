---
name: hyprlock-recovery
description: Recover from a wedged hyprlock / frozen Hyprland session on NVIDIA+Wayland without rebooting. Use when the user reports their screen is locked/frozen/unresponsive after hyprlock or their Hyprland session is stuck.
allowed-tools: Bash Read Grep
user_invocable: false
---

# Hyprlock / Hyprland Recovery

Step-by-step recovery for a wedged hyprlock or frozen Hyprland session. This machine runs Hyprland on NVIDIA (RTX 3060, proprietary driver) with hyprlock as the screen locker, triggered by hypridle via `omarchy-lock-screen`.

## When this applies

- User says their screen is frozen, locked, or hyprlock crashed
- User is on a secondary TTY (e.g. tty3) because their graphical session is stuck
- hyprlock process is alive but the lock screen won't accept input
- Hyprland is running but the display is unresponsive after killing hyprlock

## Recovery sequence

Run these steps in order. Stop as soon as the desktop is usable.

### Step 1: Kill hyprlock

```bash
pkill -TERM hyprlock
```

Verify it's gone:

```bash
pgrep hyprlock || echo "hyprlock gone"
```

### Step 2: Clear the session lock state

hyprlock uses the Wayland session-lock protocol. Killing it without a clean unlock leaves Hyprland in a stale lock state. Fix it:

```bash
hyprctl keyword misc:allow_session_lock_restore true
```

Also clear the loginctl lock hint if set:

```bash
loginctl unlock-session 1
```

### Step 3: Switch to tty1

```bash
sudo chvt 1
```

(NOPASSWD sudoers rule exists for `/usr/bin/chvt` on this machine.)

### Step 4: If the display is frozen / blank

hyprctl IPC may still work even when the display is stuck. Try in order:

**a) Force focus + workspace switch:**
```bash
hyprctl dispatch workspace 1
hyprctl dispatch focuswindow "class:com.mitchellh.ghostty"
```

**b) DPMS toggle (forces display mode reset on NVIDIA):**
```bash
hyprctl dispatch dpms off
sleep 2
hyprctl dispatch dpms on
```

**c) Config reload:**
```bash
hyprctl reload
```

### Step 5: If STILL frozen — clean exit Hyprland

This is the nuclear option short of a reboot. It cleanly exits Hyprland and SDDM re-prompts a fresh login. tmux sessions survive.

```bash
hyprctl dispatch exit
```

The user then logs back in via SDDM. All Wayland clients (Chrome, Ghostty, etc.) are lost, but tmux/byobu sessions and any background processes survive.

### Step 6: Only if exit fails — reboot

```bash
sudo reboot
```

This should be a last resort.

## Important notes

- **tmux survives everything except reboot.** The user's Claude Code session, background builds, etc. all persist through Hyprland restart.
- **Never `pkill -9 Hyprland`** — TERM (or `hyprctl dispatch exit`) lets it tear down Wayland sockets cleanly.
- **NVIDIA + Wayland** is the root cause of most of these render-pipeline freezes. The DRM state gets corrupted when the session-lock protocol tears down uncleanly.
- After recovery, check if hyprlock needs upgrading: `pacman -Q hyprlock` — versions before 0.9.4 have known input-grab issues on NVIDIA.
- The `omarchy-lock-screen` wrapper (`~/.local/share/omarchy/bin/omarchy-lock-screen`) spawns hyprlock + locks 1Password. The hypridle config at `~/.config/hypr/hypridle.conf` controls the idle timeouts.
