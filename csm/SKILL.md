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

## Multi-session model

Each named session has its own user-data-dir (`~/.config/chrome-sessions/profiles/<name>/`) and its own auto-allocated debug port. Multiple sessions run in parallel. State (pid + port) lives at `~/.config/chrome-sessions/state/<name>.json`.

## `csm list` STATUS column

- `● live` — a session by this name is running (state file exists and the port responds)
- blank — saved config, nothing running

The `TABS` column in `csm list` shows comma-separated tab titles, truncated to fit the terminal width.

## What gets saved

Each config is a JSON file (`~/.config/chrome-sessions/<name>.json`) containing:
- Session name
- ISO-8601 timestamp
- Browser version string
- Debug port used at save time
- Array of tabs, each with: `index`, `title`, `url`

Only targets where `type == "page"` are saved — service workers, background pages, iframes, and DevTools panels are excluded.

## bsm coupling

When `bsm load <name>` runs and a csm config `<name>` exists, bsm calls `csm load <name>` automatically. `bsm save <name>` triggers `csm save <name>` if a csm session for that name is running. `bsm shutdown <name>` triggers `csm stop <name>`. Pass `--no-csm` to any bsm command to skip the coupling.

## Prerequisites

- Chrome/Chromium/Brave on PATH (or set `CSM_CHROME_BIN`).
- `curl` and `jq` must be installed.

## Behavior notes

- `csm load` is **interactive** when a session by that name is already running (prompts attach / reload / cancel). Suggest `! csm load <name>` so the user can answer the prompt.
- `csm stop` (without `-q`) is interactive — prompts to save and confirm. Suggest `! csm stop [name]` or use `csm stop <name> --quiet` for non-interactive automation.
- `csm start`, `csm status`, `csm save`, `csm list`, and `csm show` are non-interactive and safe to run directly.
- On launch, csm runs Chrome detached (`nohup ... & disown`) so the terminal isn't blocked. URLs are passed on the command line; Chrome opens them as tabs in a single window.
- Each session uses its own `--user-data-dir` (required by Chrome 147+ to enable the debug port). Sessions are isolated from each other and from your regular Chrome.
- Tab order is preserved. Window groupings, tab groups, and pinned state are **not**.
- Page state (form inputs, scroll position, in-memory SPA routes) is not preserved — only URLs.

## Environment variables

| Var                | Purpose                                              | Default       |
|--------------------|------------------------------------------------------|---------------|
| `CSM_BASE_PORT`    | Base port for debug-port allocation                  | `9222`        |
| `CSM_DEBUG_PORT`   | Legacy alias for `CSM_BASE_PORT`                     | `9222`        |
| `CSM_CHROME_BIN`   | Chrome binary name/path                              | auto-detect   |
| `CSM_CHROME_ARGS`  | Extra args appended to every chrome launch command   | (none)        |

Auto-detect order: `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`, `chrome`, `brave-browser`.

## Examples

User: "start an empty debug chrome under dev"
→ `csm start dev`

User: "is chrome running?"
→ `csm status` (lists all running sessions)

User: "is the dev session running?"
→ `csm status dev`

User: "save my current browser tabs as research"
→ `csm save research`

User: "what chrome sessions do I have saved?"
→ `csm list`

User: "show me what's in my dev-tabs session"
→ `csm show dev-tabs`

User: "load my research tabs"
→ Suggest: `! csm load research` (interactive only on collision)

User: "shut down dev"
→ Suggest: `! csm stop dev` (interactive — prompts to save first)

User: "kill all running debug chromes"
→ Suggest: `! csm stop all`

## When to use this skill

- User asks to save, restore, list, or manage their browser tab sessions
- User mentions Chrome debugging, remote debugging port, or DevTools Protocol
- User wants to switch between browsing contexts (e.g., "load my research tabs", "switch to my ops dashboard tabs")
- User is setting up a development environment and wants a specific set of tabs back

## Not a fit for

- Restoring page state (forms, scroll, in-memory SPA routes)
- Saving tab groups, pinned tabs, or tab-to-window mappings
- Browsers without DevTools Protocol support
