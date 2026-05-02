# csm — Chrome Session Manager

`csm` saves and restores Chrome tab layouts as JSON configs by talking to Chrome's remote-debugging endpoint. Capture your currently open tabs under a name, then bring the whole set back later with a single command.

It's a companion to [`bsm`](../bsm/) — same ergonomics, same file layout, but for browser tabs instead of byobu windows.

It also ships a Claude Code skill definition (`SKILL.md`) so Claude can help you manage sessions conversationally.

## How it works

1. `csm load <name>` (or `csm start <name>`) launches Chrome under `<name>` with its own `--user-data-dir` and an auto-allocated `--remote-debugging-port` (starting at 9222 and walking up). The pid + port are written to `~/.config/chrome-sessions/state/<name>.json`.
2. `csm save <name>` curls that session's debug port, filters to `type == "page"`, and writes the tab list to `~/.config/chrome-sessions/<name>.json`.
3. Multiple named sessions can run in parallel — each gets its own profile dir and port.

Only URLs are restored — not form inputs, scroll position, or auth-gated SPA routes.

## Install

```bash
git clone git@github.com:mbarlow/skills.git ~/git/github.com/mbarlow/skills
cd ~/git/github.com/mbarlow/skills/csm
./install.sh
```

The installer symlinks:

- `bin/csm` → `~/.local/bin/csm`
- `SKILL.md` → `~/.claude/skills/csm/SKILL.md`

Existing files at those paths are backed up as `*.bak` before being replaced. Because these are symlinks, edits you make in the repo take effect immediately — no re-install needed.

Make sure `~/.local/bin` is on your `PATH`.

## Aliases

The repo ships a set of shortcut aliases. Enable them by adding this line to your `~/.bashrc` (or `~/.zshrc`):

```bash
source ~/git/github.com/mbarlow/skills/csm/aliases.sh
```

Then reload your shell (`source ~/.bashrc`). You'll get:

| Alias         | Runs           |
|---------------|----------------|
| `csm-start`   | `csm start`    |
| `csm-stop`    | `csm stop`     |
| `csm-status`  | `csm status`   |
| `csm-save`    | `csm save`     |
| `csm-load`    | `csm load`     |
| `csm-list`    | `csm list`     |
| `csm-show`    | `csm show`     |

## Commands

```bash
csm start <name>            # Launch an empty debug Chrome under <name>
csm stop [name|all] [-q]    # Stop a debug Chrome (default: only-running, current
                            # if exactly one). "all" stops every running. -q skips prompts.
csm status [name]           # List all running sessions; or show details for <name>.
csm save [name]             # Save tabs from a running session.
                            # No name → only-running; multiple running → picker.
csm load <name>             # Launch Chrome under <name> with saved tabs.
                            # Prompts attach / reload / cancel if already running.
csm list                    # List saved configs with live status + tab titles.
csm show <name>             # Show every tab in a saved config.
csm help                    # Show usage.
```

`csm load` and `csm stop` (without `-q`) are interactive. `start`, `status`, `save`, `list`, and `show` are non-interactive and safe to script. `csm status [name]` exits non-zero when nothing matches, so it's usable in shell conditionals.

## Multi-session model

Each named session gets:

- A user-data-dir at `~/.config/chrome-sessions/profiles/<name>/`
- An auto-allocated debug port (first free port from `CSM_BASE_PORT`, default 9222)
- A state file at `~/.config/chrome-sessions/state/<name>.json` recording pid + port
- A tab config at `~/.config/chrome-sessions/<name>.json` (written by `csm save`)

`csm load dev` and `csm load samdin` run side by side — independent windows, independent extensions, independent profile state.

## `csm list` STATUS column

- `● live` — a session by this name is running (state file exists and the port responds)
- blank — saved config, nothing running

## Typical workflow

```bash
csm start dev             # brings up an empty debug Chrome under "dev"
# ... open whatever tabs you want ...
csm save dev              # snapshot them
csm stop dev              # kill that browser
# ... later ...
csm load dev              # bring the dev tab set back
csm load samdin           # also bring up samdin's tab set, in parallel
csm list                  # both show ● live
```

Auto-detection order for the Chrome binary: `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, `chrome`, `brave-browser`. Override with `CSM_CHROME_BIN=/path/to/my-chrome`.

## bsm coupling

When [`bsm`](../bsm/) runs `load` / `save` / `shutdown` for a name, csm's matching session follows automatically — no extra command. Pass `--no-csm` to bsm to opt out per-call.

## Environment variables

| Var                | Purpose                                              | Default       |
|--------------------|------------------------------------------------------|---------------|
| `CSM_BASE_PORT`    | Base port for debug-port allocation                  | `9222`        |
| `CSM_DEBUG_PORT`   | Legacy alias for `CSM_BASE_PORT`                     | `9222`        |
| `CSM_CHROME_BIN`   | Chrome binary name/path                              | auto-detect   |
| `CSM_CHROME_ARGS`  | Extra args appended to every chrome launch command   | (none)        |

`csm` uses dedicated `--user-data-dir`s so debug-mode Chromes run as separate instances from your regular browser. This is required by Chrome 147+ (which won't enable the debug port on the default profile). Each csm session has its own bookmarks, extensions, and history.

## Where configs live

Saved sessions are stored as JSON at:

```
~/.config/chrome-sessions/<name>.json
```

**These files are personal state and are NOT tracked in this repo.** If you want to back them up, do it separately.

## Config spec

Each config is a single JSON object:

```json
{
  "name": "dev",
  "saved_at": "2026-04-11T14:08:22-04:00",
  "browser": "Chrome/124.0.6367.60",
  "debug_port": 9222,
  "tabs": [
    {
      "index": 0,
      "title": "GitHub — mbarlow/skills",
      "url": "https://github.com/mbarlow/skills"
    },
    {
      "index": 1,
      "title": "Chrome DevTools Protocol",
      "url": "https://chromedevtools.github.io/devtools-protocol/"
    }
  ]
}
```

Fields:

| Field              | Type     | Description                                                                |
|--------------------|----------|----------------------------------------------------------------------------|
| `name`             | string   | The config name (matches the filename without `.json`).                    |
| `saved_at`         | string   | ISO-8601 timestamp of when the config was written.                         |
| `browser`          | string   | The `Browser` field reported by `/json/version`.                           |
| `debug_port`       | integer  | The debug port used at save time.                                          |
| `tabs`             | array    | One entry per open page target (excludes workers, iframes, DevTools).      |
| `tabs[].index`     | integer  | Tab order (0-based) as returned by `/json`.                                |
| `tabs[].title`     | string   | Tab title at save time.                                                    |
| `tabs[].url`       | string   | Tab URL at save time — this is what gets re-opened on load.                |

On load, `csm` launches Chrome with `--remote-debugging-port=<port>` and every saved URL as a positional argument. Chrome opens them as tabs in a single new window.

## Limitations

- Only URLs are restored. Form state, scroll position, and in-memory SPA routes are lost.
- Multiple windows collapse into one on load.
- Tab groups and pinned state are not captured.
- Each named session has its own `--user-data-dir`, separate from your regular Chrome and from other csm sessions.

## Dependencies

- A Chromium-based browser (Chrome, Chromium, Brave)
- [`jq`](https://jqlang.github.io/jq/) — for JSON parsing in the script
- `curl` — to hit the DevTools JSON endpoint
- `bash` 4+

The installer warns if `curl` or `jq` are missing.

## Claude Code integration

`SKILL.md` is a Claude Code skill definition. Once the installer symlinks it into `~/.claude/skills/csm/`, Claude Code can invoke `csm` on your behalf when you ask things like:

- "save my current browser tabs as research"
- "what chrome sessions do I have saved?"
- "load my research tabs" (Claude will suggest you run it yourself, since it's interactive)

See `SKILL.md` for the full list of prompts and behavior notes.

## Layout

```
csm/
├── README.md       # This file
├── SKILL.md        # Claude Code skill definition
├── bin/
│   └── csm         # The bash script
├── aliases.sh      # Sourceable csm-* shell aliases
└── install.sh      # Idempotent symlink installer
```

