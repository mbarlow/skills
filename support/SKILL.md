---
name: support
description: Create, investigate, and track incidents in the mbarlow/support repo. The `support` CLI creates skeleton incident reports; Claude picks up the skeleton, investigates (read-only), fills in the markdown + JSON, and files a tracking issue in mbarlow/tasks via the /issues skill. Use when the user has a system failure, crash, hang, misconfiguration, or other incident they want logged for review and follow-up.
argument-hint: [new|list|show|status|link|path|validate] [options]
allowed-tools: Bash Read Write Edit Grep Glob Skill
user_invocable: true
---

# Support — Incident Reports

`support` is a CLI at `~/.local/bin/support` that manages incident reports in `~/git/github.com/mbarlow/support`. This skill pairs the CLI with Claude so that every incident gets a proper investigation and a review issue in `mbarlow/tasks`.

Each incident is a folder under `incidents/YYYY-MM-DD-<slug>/` containing:

- `incident.md` — human-readable narrative
- `incident.json` — structured metadata conforming to `schema/incident.schema.json`

Schema reference: see `$SUPPORT_REPO/schema/incident.schema.json`.

## Interpreting Arguments

Parse `$ARGUMENTS` to determine the action. Default action when called with a freeform description is **`new`**.

### `/support new <description>` — create + investigate

This is the primary flow. The user will typically describe an incident in freeform ("hyprlock crashed, I'm stuck on tty3"). Do this:

1. **Parse the description** to extract:
   - `--title` — one-line summary (derive from the description; ≤200 chars)
   - `--severity` — `low` | `medium` | `high` | `critical` (default `medium`; bump to `high` for crashes blocking the user's work, `critical` for data loss / security)
   - `--category` — `wm` (window manager / desktop), `boot`, `gpu`, `network`, `app`, `security`, `hardware`, `other`. Infer from keywords.
   - `--slug` — optional; only pass if the user asks for a specific slug. Otherwise the CLI derives one from the title.

2. **Create the skeleton** by running:
   ```bash
   support new --title "<title>" --severity <sev> --category <cat>
   ```
   Capture the folder path it prints.

3. **Investigate (read-only).** Based on the category and description, gather evidence. Use only read tools — do NOT kill processes, restart services, or edit configs without the user's explicit approval. Good sources:

   - `wm` / Wayland / Hyprland: `~/.cache/hyprland/`, `journalctl --user -b -p err`, `~/.config/hypr/*.conf`, `pgrep -fa Hyprland|hyprlock|hypridle`, `pacman -Q hyprland hyprlock hypridle`
   - `boot`: `journalctl -b -p err`, `systemctl --failed`, `dmesg | grep -iE 'error|fail'`
   - `gpu`: `lspci -k | grep -A2 VGA`, `nvidia-smi` (if present), `glxinfo | head -20`, kernel module info
   - `network`: `journalctl -u NetworkManager`, `ip a`, `nmcli device status`, `resolvectl status`
   - `app`: the app's log dir (`~/.cache/<name>/`, `~/.local/state/<name>/`, `journalctl --user -u <name>`), `pacman -Q <name>`
   - `security`: `journalctl | grep -iE 'pam|sudo|polkit|auth'` and the relevant config files — **handle any tokens/keys seen with extreme care; never paste them into the report**
   - `hardware`: `dmesg`, `smartctl`, `lsusb`, `lspci`
   - General: `coredumpctl list --since "2 hours ago"`, `loginctl list-sessions`, `who`, `w`

4. **Fill in the report** by editing `incident.md` and `incident.json` in the folder created in step 2:
   - `incident.md`: flesh out Summary, Affected components, Symptoms, Timeline, Evidence, Hypotheses, Recovery, Prevention, Upstream. Leave Root cause blank/"Unknown" if not confirmed.
   - `incident.json`: populate `affected_components[]`, `symptoms[]`, `timeline[]`, `evidence[]`, `hypotheses[]`, `recovery[]`, `prevention[]`, `upstream[]` (with `state: "planned"` for issues/PRs not yet filed). Flip `.status` from `"draft"` to `"investigating"` (or `"triaged"` if root cause is clear). Bump `.updated_at` to now.
   - Keep the two files in sync — the JSON is the machine twin of the markdown.

5. **File the review issue** in `mbarlow/tasks` via the `/issues` skill. Invoke:
   ```
   Skill(skill: "issues", args: "create")
   ```
   When the `/issues` flow asks for details, supply:
   - **Title:** `Review incident <YYYY-MM-DD-slug>: <title>`
   - **Body:** Include (a) absolute path to the markdown: `~/git/github.com/mbarlow/support/incidents/<folder>/incident.md`, (b) a 3-bullet summary (symptoms / likely cause / recovery), (c) candidate follow-up actions — upstream issues to file, local config changes, alternative tools to consider.
   - **Source repo:** `support`
   - **Type:** `bug` (default) — use `documentation` or `enhancement` if more appropriate.
   - **Related issues:** any URLs found during investigation (upstream bug trackers with matching signatures).

6. **Back-link the issue** into the incident:
   ```bash
   support link <slug> --task <issue-url>
   ```

7. **Print a summary** to the user: incident folder path, tracking-issue URL, candidate next actions (e.g., "file upstream issue against hyprwm/Hyprland", "switch screen locker to swaylock").

### `/support list [filters]`

Non-interactive. Pass through filters: `--status`, `--severity`, `--category`.

```bash
support list --severity high --status investigating
```

### `/support show <slug>`

Non-interactive. Prints the JSON and the markdown path.

```bash
support show hyprlock-crash
```

### `/support status <slug> <new-status>`

Update the incident's status. Valid: `draft`, `investigating`, `triaged`, `resolved`, `wontfix`, `deferred`.

If the new status is `resolved` and the incident has a linked tasks issue, also close it:

```bash
# After updating the incident:
tasks_url=$(jq -r '.tracking.tasks_issue // empty' "$(support path <slug>)/incident.json")
```
If `tasks_url` matches `https://github.com/mbarlow/tasks/issues/<n>`, invoke `/issues update <n> done`.

### `/support link <slug> ...`

Pass through. Two modes:

```bash
support link <slug> --task https://github.com/mbarlow/tasks/issues/42
support link <slug> --upstream hyprwm/Hyprland --url https://github.com/hyprwm/Hyprland/issues/12345 --type issue --notes "matches our crash signature"
```

### `/support path <slug>` / `/support validate [<slug>]`

Simple pass-throughs to the CLI.

## Behavior Notes

- **Investigation is read-only.** Do not run `pkill`, `kill`, `systemctl restart`, `chvt`, or edits to system configs. Document what the user _should_ run in the `recovery` section — they run it themselves.
- `support new`, `support list`, `support show`, `support status`, `support link`, `support path`, `support validate` are all safe, non-interactive, and may be run directly.
- `support` never talks to the network. Issue creation is always routed through `/issues` so the `mbarlow/tasks` label conventions stay consistent.
- The `SUPPORT_REPO` env var overrides the repo path (default: `~/git/github.com/mbarlow/support`).
- When inferring severity, bias toward the user's productivity impact. A crash that forces a reboot or locks them out = `high`. Data loss / security / keys leaked = `critical`.
- Evidence that includes secrets (tokens, passwords, API keys, session cookies) must be summarized in the report, NOT pasted verbatim. Reference the source path instead.

## Examples

User: "my hyprlock crashed and I'm stuck on tty3"
→ Parse → title="hyprlock crashed on Hyprland session", severity=`high`, category=`wm`.
→ Run `support new --title "..." --severity high --category wm`.
→ Investigate `~/.cache/hyprland/`, `pacman -Q hyprland hyprlock hypridle`, `pgrep`, `loginctl`.
→ Fill incident.md + incident.json.
→ `Skill(skill: "issues", args: "create")` → issue in `mbarlow/tasks`.
→ `support link <slug> --task <url>`.

User: "log an incident for the printer driver hanging print jobs"
→ severity=`medium`, category=`hardware` (or `app` if CUPS).
→ Same flow.

User: "list all open wm incidents"
→ `support list --category wm --status investigating`.

User: "mark hyprlock-crash triaged"
→ `support status hyprlock-crash triaged`.

User: "link the upstream bug for hyprlock-crash, hyprwm/Hyprland#12345"
→ `support link hyprlock-crash --upstream hyprwm/Hyprland --url https://github.com/hyprwm/Hyprland/issues/12345 --type issue`.

## When to use this skill

- User reports a crash, hang, misconfiguration, boot failure, network flake, or other incident they want logged.
- User asks to "open an incident", "log this", "write this up", "track this".
- User asks to list, show, or update the status of past incidents.
- User says "mark this as resolved / triaged / deferred".
