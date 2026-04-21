---
name: bsm
description: Manage and restore byobu screen session configurations — save, load, list, show, delete, and shutdown sessions
user_invocable: true
---

# Byobu Session Manager (bsm)

`bsm` is a CLI tool at `~/.local/bin/bsm` that saves and restores byobu terminal sessions as JSON configs stored in `~/.config/byobu-sessions/`.

## Commands

```bash
bsm save <name>       # Save current byobu session layout as named config
bsm load <name>       # Kill existing session (with confirmation) and restore a saved one
bsm list              # List all saved session configs with window summaries
bsm show <name>       # Show detailed window layout of a saved config
bsm delete <name>     # Delete a saved config (prompts; -f to skip confirmation)
bsm shutdown          # Gracefully shutdown byobu (offers to save first)
```

## What gets saved

Each config is a JSON file (`~/.config/byobu-sessions/<name>.json`) containing:
- Session name
- Timestamp
- Array of windows, each with: index, name, working directory, and running command

## Behavior notes

- `bsm load` is interactive — it prompts before killing an existing session, so suggest the user run it themselves with `! bsm load <name>`
- `bsm shutdown` is also interactive — prompts to save and confirm
- `bsm delete` prompts for confirmation by default; pass `-f` to skip the prompt (safe to run non-interactively with `-f`)
- `bsm save`, `bsm list`, and `bsm show` are non-interactive and safe to run directly
- Saved commands are captured from child processes of each pane via `/proc/<pid>/cmdline`
- On load, windows are created with `byobu new-window` and commands are sent via `send-keys`

## Examples

User: "save my current session as dev"
→ `bsm save dev`

User: "what sessions do I have saved?"
→ `bsm list`

User: "show me what's in my dev session"
→ `bsm show dev`

User: "load my dev session"
→ Suggest: `! bsm load dev` (interactive — needs user to run it)

User: "delete my old dev session"
→ Suggest: `! bsm delete dev` (prompts), or run `bsm delete dev -f` if user has confirmed

User: "forget all my saved sessions"
→ Confirm with user first, then `bsm delete <name> -f` per entry from `bsm list`

User: "shut down byobu"
→ Suggest: `! bsm shutdown` (interactive — needs user to run it)

## When to use this skill

- User asks to save, restore, list, or manage their terminal/byobu sessions
- User mentions session layouts, window configurations, or workspace setup
- User wants to switch between development contexts (e.g., "load my dev session")
