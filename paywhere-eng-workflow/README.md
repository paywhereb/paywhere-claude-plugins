# Paywhere Eng Workflow Plugin

Shared engineering workflow for Paywhere repos. Drop the plugin in, drop
`.claude/eng-workflow.json` in your repo, and every Paywhere repo gets the
same Linear-ticket-driven branch/PR flow plus the standard dependency,
TeamCity, and release skills.

## What's in the box

### Commands (user-triggered)

| Command | What it does |
| --- | --- |
| `/start <ticket-id> [slug]` | Open a feature branch off the default branch for an existing Linear ticket. Reopens the ticket if closed. |
| `/finish` | Commit, push, open a PR, post a Linear comment, transition the ticket to In Review. Refuses if the current branch isn't associated with a ticket. |
| `/create` | Bootstrap a Linear ticket from the working diff, then `/start` + commit. |
| `/review` | Review the current implementation against the ticket and project conventions. |
| `/eng-init` | Bootstrap `.claude/eng-workflow.json` for a fresh repo. |

### Skills (model-invocable)

| Skill | What it does |
| --- | --- |
| `pull-latest` | Checkout the default branch and pull. |
| `squash` | Squash the current branch into one commit. |
| `pr-to-production` | Create a Linear release ticket + a `main → production` PR. |
| `tc-reconcile` | Fold the auto-raised TeamCity reconcile PR's patches back into `.teamcity/settings.kts`. |
| `safe-deps` | Curated dependency refresh: bundle safe bumps into a single PR, report risky ones. Can hand off to a per-repo `local-checks` skill for repo-specific invariants. |
| `conventions` | Reference document (not a runnable skill) — the canonical commit, branch, PR, and Linear formats other skills point at. |

## Installation

### Claude Code

```
/plugin marketplace add paywhereb/paywhere-claude-plugins
/plugin install paywhere-eng-workflow@paywhere-claude-plugins
```

### Cowork (side-load)

```bash
git clone https://github.com/paywhereb/paywhere-claude-plugins.git
cd paywhere-claude-plugins
./scripts/package.sh paywhere-eng-workflow
# → dist/paywhere-eng-workflow-<version>.plugin
```

Then load the `.plugin` archive through Cowork's plugin file picker.

## Per-repo configuration: `.claude/eng-workflow.json`

Every host repo ships one of these. All commands and skills load it at the
start of every invocation; if it's missing, they stop and tell the user to
run `/eng-init`. Run `/eng-init` once per repo to generate it.

### Schema

```json
{
  "linear": {
    "team": "Engineering",
    "teamId": "19c916e9-7be3-40f1-adc3-fbf03fe53b5d",
    "defaultLabels": {
      "type":      { "Change":   "c1eebf96-1092-4a84-a136-16d830d9b9e1" },
      "component": { "Admin App": "4309ea9d-6978-4d79-b7aa-1b4c92cd308e" },
      "category":  { "Admin":     "9cf65af6-fa6d-4ec0-a0ca-a4b48dbb82a4" }
    },
    "activeStates": ["Todo", "In Progress"],
    "reviewState": "In Review"
  },
  "repo": {
    "defaultBranch": "main",
    "branchPattern": "{ticket-id-lc}/{slug}",
    "name": "paywhere-admin"
  },
  "guards": {
    "tcReconcile":    { "enabled": true,  "settingsPath": ".teamcity/settings.kts" },
    "safeDeps":       { "enabled": true,  "mirrorPins": [
      { "package": "@playwright/test", "syncedWith": [".teamcity/settings.kts", "CLAUDE.md"] }
    ]},
    "prToProduction": { "enabled": true }
  },
  "extraGuardsSkill": ".claude/skills/local-checks"
}
```

### Field reference

- `linear.team` — display name passed to the Linear MCP `team` argument.
- `linear.teamId` — UUID of the same team. Skills prefer the UUID; the
  name is for display.
- `linear.defaultLabels` — label-set the workflow attaches when creating
  tickets (`safe-deps` and `pr-to-production` use this most). Keyed by
  Linear's "label group" parent (`type`, `component`, `category`) to
  document the intent of each one.
- `linear.activeStates` — workflow states considered "ok to work on" by
  `/start`. If the ticket is in any other state, `/start` prompts to
  reopen and transitions it back to the first state in this list.
- `linear.reviewState` — the state `/finish` and `safe-deps` move tickets
  to when the PR is up.
- `repo.defaultBranch` — what `pull-latest`, `/start`, `/finish`, and
  `pr-to-production` treat as the integration branch.
- `repo.branchPattern` — placeholder template used by `/start` and
  `/finish`. Supported placeholders:
  - `{ticket-id-lc}` — `eng-123` (lowercased).
  - `{ticket-id}` — `ENG-123`.
  - `{slug}` — slugified ticket title or user-supplied slug.
- `repo.name` — repo display name (used in commit/PR templates and
  `pr-to-production`).
- `guards.tcReconcile.enabled` — `false` opts the repo out of TC
  reconciliation entirely (skill exits with a polite message).
- `guards.tcReconcile.settingsPath` — path to the Kotlin DSL file.
- `guards.safeDeps.enabled` — `false` opts the repo out of `safe-deps`.
- `guards.safeDeps.mirrorPins` — packages whose version is duplicated in
  files outside `package.json`. `safe-deps` syncs each listed file when it
  bumps the package.
- `guards.prToProduction.enabled` — `false` disables the
  `pr-to-production` skill for this repo.
- `extraGuardsSkill` — path to an optional repo-local skill the plugin
  invokes for invariants only that repo cares about. `safe-deps` calls it
  after its standard gates pass.

### Defaults assumed when a field is missing

| Field | Default |
| --- | --- |
| `linear.activeStates` | `["Todo", "In Progress"]` |
| `linear.reviewState` | `"In Review"` |
| `repo.defaultBranch` | inferred from `git symbolic-ref refs/remotes/origin/HEAD` |
| `repo.branchPattern` | `"{ticket-id-lc}/{slug}"` |
| `repo.name` | inferred from the remote URL |
| `guards.*.enabled` | `true` |
| `extraGuardsSkill` | unset — no extra hook |

A missing `linear.team` or `linear.teamId` is a hard error — the workflow
has nowhere to file tickets without them.

## Multi-PR-per-ticket

`/finish` deliberately does **not** close the Linear ticket. The same
ticket can spawn multiple branches and PRs — running `/start <ticket-id>`
again on an open ticket creates a fresh branch off the default branch
(prompting for a new slug if the previous branch still exists).

Prefer this multi-PR pattern over splitting related fixes into new
tickets. When a fix surfaces a follow-up issue in the same problem
domain (e.g. fix A lands, the next run reveals bug B, that fix reveals
bug C), keep all the PRs under the original ticket and widen its
title/description as the scope grows. Don't proactively propose
splitting — let the user ask if they want narrower tracking.

## Repo-local invariants

Anything that's specific to one repo lives in that repo's
`.claude/skills/local-checks/` (or whatever path `extraGuardsSkill` points
at). The plugin invokes it as a hook from `safe-deps`. Keep the plugin
generic; keep your repo's quirks in your repo.

## License

Inherits the upstream license. See the parent repo's
[`README.md`](../README.md).
