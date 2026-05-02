# bsm — Byobu Session Manager

`bsm` saves and restores [byobu](https://www.byobu.org/) terminal session layouts as JSON configs. Capture your current windows, directories, and running commands under a name, then bring the whole layout back later with a single command.

It also ships a Claude Code skill definition (`SKILL.md`) so Claude can help you manage sessions conversationally.

## Install

```bash
git clone git@github.com:mbarlow/skills.git ~/git/github.com/mbarlow/skills
cd ~/git/github.com/mbarlow/skills/bsm
./install.sh
```

The installer symlinks:

- `bin/bsm` → `~/.local/bin/bsm`
- `SKILL.md` → `~/.claude/skills/bsm/SKILL.md`

Existing files at those paths are backed up as `*.bak` before being replaced. Because these are symlinks, edits you make in the repo take effect immediately — no re-install needed.

Make sure `~/.local/bin` is on your `PATH`.

## Aliases

The repo ships a set of shortcut aliases. Enable them by adding this line to your `~/.bashrc` (or `~/.zshrc`):

```bash
source ~/git/github.com/mbarlow/skills/bsm/aliases.sh
```

Then reload your shell (`source ~/.bashrc`). You'll get:

| Alias          | Runs            |
|----------------|-----------------|
| `bsm-save`     | `bsm save`      |
| `bsm-load`     | `bsm load`      |
| `bsm-list`     | `bsm list`      |
| `bsm-show`     | `bsm show`      |
| `bsm-shutdown` | `bsm shutdown`  |

## Commands

```bash
bsm save [--no-csm] [name]          # Save current byobu session as <name>
                                    # (no arg: defaults to the current session name when inside tmux)
bsm load [--no-csm] <name>          # Load a saved config as a tmux session named <name>.
                                    # Runs alongside other live sessions; prompts on collision.
bsm list                            # List saved configs with live/drift status
bsm show <name>                     # Show the window layout of a saved config
bsm delete <name>                   # Delete a saved config (use -f to skip confirmation)
bsm shutdown [--no-csm] [name|all]  # Shut down a session (default: current when inside tmux,
                                    # else picker). Use "all" to kill the entire byobu server.
bsm help                            # Show usage
```

`bsm load` and `bsm shutdown` are interactive (they prompt before destructive actions). `save`, `list`, `show`, and `delete -f` are safe to script.

## Multi-session model

`bsm load <name>` creates a tmux session **named `<name>`** and runs alongside any other live sessions. Switch between them with `tmux switch-client -t <name>` (or byobu's `Shift+F8`).

The config name and live session name are coupled by convention — that's how `bsm list` decides which configs are currently loaded:

- `● live` — a tmux session with this name is running and its window names match the saved config exactly
- `~ drift` — a session with this name is running but windows have changed since save
- blank — not loaded

`bsm shutdown` kills a single session by default; pass `all` to kill the whole server.

## csm coupling

When [`csm`](../csm/) is installed on PATH, bsm pairs with it by name:

- `bsm load <name>` also runs `csm load <name>` if a csm config `<name>` exists and no csm instance is running.
- `bsm save <name>` also runs `csm save <name>` if a csm instance for `<name>` is running.
- `bsm shutdown <name>` also runs `csm stop <name>` if a csm instance is running. `bsm shutdown all` runs `csm stop all`.

Pass `--no-csm` to any bsm command to skip the coupling for that call.

## Where configs live

Saved sessions are stored as JSON at:

```
~/.config/byobu-sessions/<name>.json
```

**These files are personal state and are NOT tracked in this repo.** If you want to back them up, do it separately.

## Config spec

Each config is a single JSON object:

```json
{
  "name": "dev",
  "saved_at": "2026-04-10T18:42:49-04:00",
  "session_name": "1",
  "windows": [
    {
      "index": 0,
      "name": "CLAUDE",
      "directory": "/home/mbarlow/git/github.com/mbarlow",
      "command": "claude"
    },
    {
      "index": 1,
      "name": "SONGNOOK",
      "directory": "/home/mbarlow/git/github.com/mbarlow/songnook",
      "command": "make dev"
    }
  ]
}
```

Fields:

| Field               | Type     | Description                                                                                                         |
|---------------------|----------|---------------------------------------------------------------------------------------------------------------------|
| `name`              | string   | The config name (matches the filename without `.json`).                                                             |
| `saved_at`          | string   | ISO-8601 timestamp of when the config was written.                                                                  |
| `session_name`      | string   | The byobu session name at save time. On load, this name is recreated.                                               |
| `windows`           | array    | One entry per byobu window (not pane — bsm doesn't capture pane splits).                                            |
| `windows[].index`   | integer  | Window index (0-based).                                                                                             |
| `windows[].name`    | string   | Window title.                                                                                                       |
| `windows[].directory` | string | Absolute path of the pane's current working directory at save time.                                                 |
| `windows[].command` | string   | Command to re-run on load. Captured from `/proc/<pid>/cmdline` of the first child of the pane's pid. May be empty for idle shells. |

On load, `bsm` recreates the session with `byobu new-session`, adds each window with `byobu new-window`, and replays each `command` via `send-keys`.

## Dependencies

- [`byobu`](https://www.byobu.org/) — the session manager
- [`jq`](https://jqlang.github.io/jq/) — for JSON parsing in the script
- `bash` 4+

The installer warns if `byobu` or `jq` are missing.

## Claude Code integration

`SKILL.md` is a Claude Code skill definition. Once the installer symlinks it into `~/.claude/skills/bsm/`, Claude Code can invoke `bsm` on your behalf when you ask things like:

- "save my current session as dev"
- "what sessions do I have saved?"
- "load my dev session" (Claude will suggest you run it yourself, since it's interactive)

See `SKILL.md` for the full list of prompts and behavior notes.

## Layout

```
bsm/
├── README.md       # This file
├── SKILL.md        # Claude Code skill definition
├── bin/
│   └── bsm         # The bash script (~263 lines)
├── aliases.sh      # Sourceable bsm-* shell aliases
└── install.sh      # Idempotent symlink installer
```
