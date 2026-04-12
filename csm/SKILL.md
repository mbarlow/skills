---
name: csm
description: Manage and restore Chrome remote-debugging tab sessions — save, load, list, and show sessions
user_invocable: true
---

# Chrome Session Manager (csm)

`csm` is a CLI tool at `~/.local/bin/csm` that saves and restores Chrome (or Chromium/Brave) debug-mode tab sessions as JSON configs stored in `~/.config/chrome-sessions/`.

It talks to Chrome via the DevTools JSON endpoint exposed by `--remote-debugging-port=9222`. Think of it as `bsm` but for browser tabs instead of byobu windows.

## Commands

```bash
csm start             # Launch an empty debug-mode Chrome on the debug port
csm stop              # Stop the debug-mode Chrome (prompts to save first, then confirms kill)
csm status            # Show whether debug Chrome is alive + tab count (exit 1 if not)
csm save <name>       # Save currently open tabs (in debug-mode Chrome) as a named config
csm load <name>       # Kill any existing debug Chrome (with confirmation) and relaunch with saved tabs
csm list              # List all saved tab configs with tab count + first-tab title
csm show <name>       # Show every tab in a saved config (index, title, URL)
csm help              # Show usage
```

## What gets saved

Each config is a JSON file (`~/.config/chrome-sessions/<name>.json`) containing:
- Session name
- ISO-8601 timestamp
- Browser version string
- Debug port used at save time
- Array of tabs, each with: `index`, `title`, `url`

Only targets where `type == "page"` are saved — service workers, background pages, iframes, and DevTools panels are excluded.

## Prerequisites

- Chrome/Chromium/Brave must be running with `--remote-debugging-port=9222` (or whatever `CSM_DEBUG_PORT` is set to) **for `csm save` to work**.
- `curl` and `jq` must be installed.

The easiest way to bring up a debug-mode Chrome is:

```bash
csm start
```

Or launch it manually:

```bash
google-chrome --remote-debugging-port=9222
```

Use `csm status` to check whether a debug Chrome is already running before attempting a save.

## Behavior notes

- `csm load` and `csm stop` are **interactive** — they prompt before killing Chrome. Suggest the user run them with `! csm load <name>` or `! csm stop`.
- `csm start`, `csm status`, `csm save`, `csm list`, and `csm show` are non-interactive and safe to run directly.
- On load, `csm` launches Chrome detached (`nohup ... & disown`) so the terminal isn't blocked. All saved URLs are passed on the command line, which opens them as tabs in a single new window.
- `pkill -f "remote-debugging-port=$PORT"` is used to stop the existing debug Chrome before relaunching.
- `csm` uses a dedicated `--user-data-dir` (default `~/.config/chrome-sessions/profile`) so the debug Chrome runs separately from the user's regular browser. Required by Chrome 147+.
- Tab order is preserved. Window groupings are **not** — all tabs land in one window.
- Page state (form inputs, scroll position, auth-gated SPA routes) is not preserved — only URLs.

## Environment variables

| Var                  | Purpose                                                 | Default                                |
|----------------------|---------------------------------------------------------|----------------------------------------|
| `CSM_DEBUG_PORT`     | Chrome remote-debugging port                            | `9222`                                 |
| `CSM_CHROME_BIN`     | Chrome binary name/path                                 | auto-detect                            |
| `CSM_USER_DATA_DIR`  | Chrome user-data-dir for the debug profile              | `~/.config/chrome-sessions/profile`    |
| `CSM_CHROME_ARGS`    | Extra args appended to the `chrome` launch command      | (none)                                 |

Auto-detect order: `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, `chrome`, `brave-browser`.

## Examples

User: "start debug chrome"
→ `csm start`

User: "is chrome running?"
→ `csm status`

User: "save my current browser tabs as research"
→ `csm save research`

User: "what chrome sessions do I have saved?"
→ `csm list`

User: "show me what's in my dev-tabs session"
→ `csm show dev-tabs`

User: "load my research tabs"
→ Suggest: `! csm load research` (interactive — needs user to run it)

User: "shut down chrome"
→ Suggest: `! csm stop` (interactive — needs user to run it)

User: "save my browser as dev but on port 9333"
→ `CSM_DEBUG_PORT=9333 csm save dev`

## When to use this skill

- User asks to save, restore, list, or manage their browser tab sessions
- User mentions Chrome debugging, remote debugging port, or DevTools Protocol
- User wants to switch between browsing contexts (e.g., "load my research tabs", "switch to my ops dashboard tabs")
- User is setting up a development environment and wants a specific set of tabs back

## Not a fit for

- Restoring page state (forms, scroll, in-memory SPA routes)
- Saving tab groups, pinned tabs, or tab-to-window mappings
- Browsers without DevTools Protocol support
