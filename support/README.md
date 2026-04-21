# support — Incident Report CLI + Claude Skill

`support` is a small CLI for logging system incidents (crashes, hangs, misconfigurations) as structured reports in the [`mbarlow/support`](https://github.com/mbarlow/support) repo. It pairs with a Claude Code skill (`SKILL.md`) so that after you kick off a skeleton with a single command, Claude investigates the system read-only, fills in the narrative + metadata, and files a tracking issue in `mbarlow/tasks` via the `/issues` skill.

Each incident is a folder under `incidents/YYYY-MM-DD-<slug>/` containing an `incident.md` (narrative) and an `incident.json` (structured twin that conforms to `schema/incident.schema.json`).

## Install

```bash
git clone git@github.com:mbarlow/skills.git ~/git/github.com/mbarlow/skills
cd ~/git/github.com/mbarlow/skills/support
./install.sh
```

The installer symlinks:

- `bin/support` → `~/.local/bin/support`
- `SKILL.md` → `~/.claude/skills/support/SKILL.md`

Existing files at those paths are backed up as `*.bak` before being replaced. Because these are symlinks, edits you make in the repo take effect immediately — no re-install needed.

Make sure `~/.local/bin` is on your `PATH`, and that `~/git/github.com/mbarlow/support` exists (clone or create it from the `support` repo template).

## Aliases

Enable shortcut aliases by adding this line to your `~/.bashrc` (or `~/.zshrc`):

```bash
source ~/git/github.com/mbarlow/skills/support/aliases.sh
```

Then reload your shell (`source ~/.bashrc`). You'll get:

| Alias          | Runs                |
|----------------|---------------------|
| `sup-new`      | `support new`       |
| `sup-list`     | `support list`      |
| `sup-show`     | `support show`      |
| `sup-status`   | `support status`    |
| `sup-link`     | `support link`      |
| `sup-path`     | `support path`      |
| `sup-validate` | `support validate`  |

## Commands

```bash
support new    [--slug NAME] [--title "..."] [--severity LVL] [--category CAT]
               [--date YYYY-MM-DD] [--no-issue]
support list   [--status STATUS] [--severity SEV] [--category CAT]
support show   <slug>
support path   <slug>
support status <slug> <new-status>
support link   <slug> --task URL
support link   <slug> --upstream REPO --url URL --type issue|pr [--notes "..."]
support validate [<slug>]
support help
```

**Severity:** `low` \| `medium` \| `high` \| `critical`
**Category:** `wm` \| `boot` \| `gpu` \| `network` \| `app` \| `security` \| `hardware` \| `other`
**Status:**   `draft` \| `investigating` \| `triaged` \| `resolved` \| `wontfix` \| `deferred`

`<slug>` may be either the bare slug (`hyprlock-crash`) or the full dated folder (`2026-04-15-hyprlock-crash`). The CLI resolves both.

`support new`, `support list`, `support show`, `support status`, `support link`, `support path`, and `support validate` are all non-interactive and safe to run directly. `support` never touches the network.

## Typical workflow

```bash
# 1. Kick off a skeleton.
support new --title "hyprlock crashed on Hyprland 0.54.3" --severity high --category wm

# 2. Let Claude fill it in.
#    In a Claude Code session:  /support new hyprlock crashed, stuck on tty3

# 3. Later, as upstream work lands:
support status hyprlock-crash triaged
support link  hyprlock-crash --upstream hyprwm/Hyprland \
              --url https://github.com/hyprwm/Hyprland/issues/12345 --type issue
support status hyprlock-crash resolved
```

## Where data lives

Incidents live under `$SUPPORT_REPO/incidents/`, default `~/git/github.com/mbarlow/support`. Override with the env var:

```bash
export SUPPORT_REPO=/path/to/other/support
```

## Dependencies

- [`jq`](https://jqlang.github.io/jq/) — required, used for all JSON manipulation
- [`gh`](https://cli.github.com/) — required by the Claude `/issues` skill flow (not by this CLI directly)
- [`git`](https://git-scm.com/) — required to track the support repo
- [`check-jsonschema`](https://pypi.org/project/check-jsonschema/) — optional, unlocks schema-aware `support validate`. Without it, validate falls back to a structural required-fields check.

The installer warns if `jq` / `gh` / `git` are missing.

## Claude Code integration

`SKILL.md` is a Claude Code skill definition. Once `install.sh` symlinks it into `~/.claude/skills/support/`, Claude Code will pick up on prompts like:

- "my hyprlock crashed and I'm stuck on tty3" → `/support new` → Claude investigates, fills the report, files a review issue in `mbarlow/tasks`
- "log an incident for the printer driver hang" → `/support new ...`
- "list high-severity incidents that are still open" → `support list --severity high --status investigating`
- "mark hyprlock-crash triaged" → `support status hyprlock-crash triaged`
- "link the upstream bug for hyprlock-crash" → `support link hyprlock-crash --upstream ... --url ... --type issue`

Investigation happens read-only. Claude will _document_ recovery commands (e.g. `pkill -TERM hyprlock && sudo chvt 1`) rather than running them for you. If you want Claude to actually execute recovery, ask explicitly — it won't assume.

See `SKILL.md` for the full trigger and behavior spec.

## Why CLI + skill split?

- The CLI creates deterministic skeletons. It's offline, fast, scriptable, and doesn't need any judgment — safe to run from a cron job or a keybind.
- Claude does the investigation, the prose, and the GitHub-issue filing. That way issue labels + the kanban convention in `mbarlow/tasks` stay consistent with the existing `/issues` skill, and the report itself gets a human-level write-up.

## Layout

```
support/
├── README.md         # this file
├── SKILL.md          # Claude Code skill definition
├── install.sh        # idempotent symlink installer
├── aliases.sh        # sourceable sup-* shell aliases
└── bin/
    └── support       # the bash CLI
```
