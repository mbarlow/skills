# csm — Chrome Session Manager

`csm` saves and restores Chrome tab layouts as JSON configs by talking to Chrome's remote-debugging endpoint. Capture your currently open tabs under a name, then bring the whole set back later with a single command.

It's a companion to [`bsm`](../bsm/) — same ergonomics, same file layout, but for browser tabs instead of byobu windows.

It also ships a Claude Code skill definition (`SKILL.md`) so Claude can help you manage sessions conversationally.

## How it works

1. You launch Chrome with `--remote-debugging-port=9222`.
2. `csm save <name>` curls `http://localhost:9222/json`, filters to `type == "page"`, and writes the tab list to `~/.config/chrome-sessions/<name>.json`.
3. `csm load <name>` optionally kills the running debug Chrome, then relaunches it with every saved URL on the command line (one tab per URL, all in a single window).

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
csm start             # Launch an empty debug-mode Chrome on the debug port
csm stop              # Stop the debug-mode Chrome (offers to save first)
csm status            # Show whether a debug Chrome is alive + tab count
csm save <name>       # Save the current debug-mode Chrome tabs as <name>
csm load <name>       # Kill existing debug Chrome (with confirmation) and relaunch with <name>
csm list              # List all saved tab configs
csm show <name>       # Show the tab layout of a saved config
csm help              # Show usage
```

`csm load` and `csm stop` are interactive (they prompt before destructive actions). `start`, `status`, `save`, `list`, and `show` are non-interactive and safe to script. `csm status` exits non-zero when no debug Chrome is alive, so it's usable in shell conditionals.

## Typical workflow

```bash
csm start                 # brings up an empty debug-mode Chrome
# ... open whatever tabs you want ...
csm save research         # snapshot them
csm stop                  # kill the browser when you're done
# ... later ...
csm load research         # bring the whole tab set back
```

Auto-detection order for the Chrome binary: `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, `chrome`, `brave-browser`. Override with `CSM_CHROME_BIN=/path/to/my-chrome`.

## Environment variables

| Var                  | Purpose                                                 | Default                                |
|----------------------|---------------------------------------------------------|----------------------------------------|
| `CSM_DEBUG_PORT`     | Chrome remote-debugging port                            | `9222`                                 |
| `CSM_CHROME_BIN`     | Chrome binary name/path                                 | auto-detect                            |
| `CSM_USER_DATA_DIR`  | Chrome user-data-dir for the debug profile              | `~/.config/chrome-sessions/profile`    |
| `CSM_CHROME_ARGS`    | Extra args appended to the `chrome` launch command      | (none)                                 |

`csm` uses a dedicated `--user-data-dir` by default so that the debug-mode Chrome runs as a separate instance from your regular browser. This is required by Chrome 147+ (which won't enable the debug port on the default profile). Your csm bookmarks, extensions, and history are independent of your main Chrome.

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
- `csm` uses a separate `--user-data-dir` so it doesn't conflict with your regular Chrome. This means the csm Chrome has its own bookmarks, extensions, and session history. Override with `CSM_USER_DATA_DIR`.

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

## Roadmap

- Optional `bsm` integration: hook `bsm save`/`bsm load` so a byobu session can carry an associated `csm` session name, restoring both terminals and browser tabs in one command.
