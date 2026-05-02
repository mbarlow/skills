---
name: bsm
description: Manage and restore byobu screen session configurations — save, load, list, show, delete, and shutdown sessions
user_invocable: true
---

# Byobu Session Manager (bsm)

`bsm` is a CLI tool at `~/.local/bin/bsm` that saves and restores byobu terminal sessions as JSON configs stored in `~/.config/byobu-sessions/`.

## Commands

```bash
bsm save [name]          # Save current byobu session as <name>
                         # (no arg: defaults to current session name when inside tmux)
bsm load <name>          # Load a saved config as a tmux session named <name>.
                         # Runs alongside other live sessions; prompts if <name> already exists.
bsm list                 # List all saved configs with live/drift status
bsm show <name>          # Show detailed window layout of a saved config
bsm delete <name>        # Delete a saved config (prompts; -f to skip confirmation)
bsm shutdown [name|all]  # Shut down a session (default: current when inside tmux,
                         # else picker). Use "all" to kill the entire byobu server.
```

## Multi-session model

`bsm load <name>` creates a tmux session **named `<name>`**. Running `bsm load dev` then `bsm load samdin` from a fresh shell gives you two parallel sessions; switch between them with `tmux switch-client -t <name>` or byobu's `Shift+F8`. The config name and the live tmux session name are coupled by convention — that's how `bsm list` knows which configs are currently loaded.

## What gets saved

Each config is a JSON file (`~/.config/byobu-sessions/<name>.json`) containing:
- Config name
- Timestamp
- The live tmux session name at save time (informational; `load` uses the config name)
- Array of windows, each with: index, name, working directory, and running command

## `bsm list` STATUS column

- `● live` — a tmux session with this name is running and its window names match the saved config exactly
- `~ drift` — a session with this name is running but windows have changed since save (rename/add/remove)
- blank — not loaded

## Behavior notes

- `bsm load` is interactive when the named session already exists (prompts: attach / reload / cancel) and when it attaches/switches at the end. Suggest the user run it themselves with `! bsm load <name>`.
- `bsm shutdown` is interactive — prompts to save and confirm. Suggest `! bsm shutdown [name]`.
- `bsm save` is safe to run directly; outside tmux with multiple live sessions, it prompts which to save.
- `bsm delete` prompts for confirmation by default; pass `-f` to skip the prompt.
- `bsm list` and `bsm show` are non-interactive and safe to run directly.
- Saved commands are captured from child processes of each pane via `/proc/<pid>/cmdline`.
- On load, windows are created with `byobu new-window` and commands are sent via `send-keys`.
- Inside tmux, `bsm load` uses `tmux switch-client` (no nested session). Outside tmux, it `byobu attach`s.

## Examples

User: "save my current session as dev"
→ `bsm save dev`

User: "save what I have right now" (inside tmux)
→ `bsm save` (uses current session name)

User: "what sessions do I have saved?"
→ `bsm list`

User: "show me what's in my dev session"
→ `bsm show dev`

User: "load my dev session"
→ Suggest: `! bsm load dev` (interactive — needs user to run it)

User: "load dev alongside what I'm already running"
→ Suggest: `! bsm load dev` — it no longer kills other sessions; both run in parallel.

User: "shut down just this session"
→ Suggest: `! bsm shutdown` (defaults to current session when inside tmux)

User: "kill everything"
→ Suggest: `! bsm shutdown all`

User: "delete my old dev session"
→ Suggest: `! bsm delete dev` (prompts), or run `bsm delete dev -f` if user has confirmed

User: "forget all my saved sessions"
→ Confirm with user first, then `bsm delete <name> -f` per entry from `bsm list`

## When to use this skill

- User asks to save, restore, list, or manage their terminal/byobu sessions
- User mentions session layouts, window configurations, or workspace setup
- User wants to switch between development contexts (e.g., "load my dev session")
