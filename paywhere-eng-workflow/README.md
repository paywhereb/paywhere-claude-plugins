# Paywhere Eng Workflow Plugin

Shared engineering workflow for Paywhere repos. Drop the plugin in, drop
`.claude/eng-workflow.json` in your repo, and every Paywhere repo gets the
same Linear-ticket-driven branch/PR flow plus the standard dependency,
TeamCity, and release skills.

## What's in the box

### Commands (always invoked with the `paywhere-eng-workflow:` prefix)

| Command | Invocation | What it does |
| --- | --- | --- |
| `start` | `/paywhere-eng-workflow:start <ticket-id> [slug]` | Open a feature branch off the default branch for an existing Linear ticket. Reopens the ticket if closed. |
| `finish` | `/paywhere-eng-workflow:finish` | Commit, push, open a PR, post a Linear comment, transition the ticket to In Review. Refuses if the current branch isn't associated with a ticket. |
| `create` | `/paywhere-eng-workflow:create` | Bootstrap a Linear ticket from the working diff, then `/start` + commit. |
| `review` | `/paywhere-eng-workflow:review` | Review the current implementation against the ticket and project conventions. |
| `eng-init` | `/paywhere-eng-workflow:eng-init` | Bootstrap `.claude/eng-workflow.json` for a fresh repo, and declare the plugin requirement in `.claude/settings.json` so teammates auto-install it. |

### Skills (invokable by short name)

| Skill | Invocation | What it does |
| --- | --- | --- |
| `pull-latest` | `/pull-latest` | Checkout the default branch and pull. |
| `squash` | `/squash` | Squash the current branch into one commit. |
| `pr-to-production` | `/pr-to-production` | Create a Linear release ticket + a `main → production` PR. |
| `tc-reconcile` | `/tc-reconcile` | Fold the auto-raised TeamCity reconcile PR's patches back into `.teamcity/settings.kts`. |
| `safe-deps` | `/safe-deps` | Curated dependency refresh: bundle safe bumps into a single PR, report risky ones. Can hand off to a per-repo `local-checks` skill for repo-specific invariants. |
| `prune-merged-branches` | `/prune-merged-branches` | Safely delete local branches whose PR has been merged. Reports first, deletes only after confirmation. Refuses any branch with commits past the merged PR head, so un-pushed work is never lost. Squash-merge-aware — uses GitHub's merged-PR signal, not git's ancestry check. |
| `tf-drift` | `/tf-drift` | Interpret the nightly Terraform drift sweep in plain English, attribute changes via CloudTrail, and route each workspace to the right fix — apply (unapplied merge), revert (out-of-band), or codify — driving the gated PLAN phase only. |
| `tf-apply` | `/tf-apply` | Walk an eligible operator through the post-merge apply: find the right `plan_run_id` automatically, show the plan, verify they're a valid non-author dispatcher (skipped for `repo.environment: "nonprod"` repos, where self-apply is by design), and dispatch. |
| `conventions` | — | Reference document (not a runnable skill) — the canonical commit, branch, PR, and Linear formats other skills point at. |

### Always-on org rules (SessionStart hook)

The plugin injects [`rules/ORG-RULES.md`](rules/ORG-RULES.md) — the
Paywhere org-wide Claude rules (no attribution trailers, source-controlled
memory, no PATs, IaC-managed branch protection, …) — into every Claude
session opened inside a paywhereb repo. Mechanics:

- [`hooks/hooks.json`](hooks/hooks.json) registers a `SessionStart` hook
  with matcher `startup|clear|compact`. It deliberately does **not** fire
  on `resume`: a resumed session already carries the rules from its
  original startup, and re-injecting them burns context for nothing.
  `clear` and `compact` stay in because those events wipe or squash the
  injected context.
- [`scripts/session-start.sh`](scripts/session-start.sh) gates on the
  `origin` remote pointing at the `paywhereb` GitHub org (https, ssh, and
  custom SSH host-alias forms all match), with the presence of
  `.claude/eng-workflow.json` as a fallback. Personal and non-Paywhere
  projects get nothing injected.
- **Workspace roots count too**: a session started from a parent
  directory whose immediate children include a paywhereb clone (e.g.
  `~/Projects/Paywhere/`) also gets the rules — multi-repo sessions are
  common. Workspace mode skips the eng-init nudge, since the parent
  directory isn't itself a repo to onboard. Note that repo-level Claude
  config (checked-in settings, CLAUDE.md, memory) still only loads when
  the session starts inside that repo.
- In a paywhereb repo that has no `.claude/eng-workflow.json` yet, the
  hook additionally asks Claude to proactively offer
  `/paywhere-eng-workflow:eng-init` to onboard the repo.
- Rule changes ship as plugin releases: edit `rules/ORG-RULES.md`, bump
  the plugin version, merge; teammates pick it up with
  `claude plugin update paywhere-eng-workflow`.
- Plugin hooks only fire where the plugin is *enabled*, so enable it at
  **user scope** (see the repo-root [ONBOARDING.md](../ONBOARDING.md)) —
  that's what makes the rules and the eng-init nudge follow you into
  every paywhereb clone, including ones without checked-in settings.

### Why the prefix split

It's a Claude Code convention, not a Paywhere choice:

- **Commands** (files in `commands/`) are namespaced because `/start`,
  `/finish`, and similar names would collide across plugins. Claude
  Code requires the `<plugin-name>:` prefix on every invocation.
- **Skills** (directories with `SKILL.md`) get a globally unique
  invocation name from their frontmatter `name:` field. Claude Code
  resolves the short form (`/pr-to-production`) directly when the name
  is unambiguous. Skills with `disable-model-invocation: true` (e.g.
  `pull-latest`, `squash`, `pr-to-production`) are still user-invokable
  by short name; the flag only hides them from automatic model
  discovery.

The namespaced form `/paywhere-eng-workflow:<name>` always works for
both commands and skills — use it explicitly if you ever hit a
collision with another plugin that defines a same-named skill.

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
    "name": "paywhere-admin",
    "environment": "prod"
  },
  "guards": {
    "tcReconcile":    { "enabled": true,  "settingsPath": ".teamcity/settings.kts" },
    "safeDeps":       { "enabled": true,  "mirrorPins": [
      { "package": "@playwright/test", "syncedWith": [".teamcity/settings.kts", "CLAUDE.md"] }
    ]},
    "prToProduction": { "enabled": true },
    "tfDrift":        { "enabled": true,  "driftWorkflow": "terraform-drift.yml", "remediateWorkflow": "terraform-remediate-drift.yml" }
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
- `repo.environment` — `"prod"` (default) or `"nonprod"`. Read by
  `tf-apply`'s second-person gate: `"nonprod"` means the repo's own
  `terraform-apply.yml` has no author/dispatcher check by design (single
  AWS account, compensating isolation control instead — see e.g.
  `paywhere-nonprod-infra`), so self-apply is legitimate and `tf-apply`
  skips the dispatcher-≠-PR-author check. `"prod"` (or absent) keeps the
  check enforced. This does not change the workflow itself — it only
  tells the skill which behavior to expect, so get it right.
- `guards.tcReconcile.enabled` — `false` opts the repo out of TC
  reconciliation entirely (skill exits with a polite message).
- `guards.tcReconcile.settingsPath` — path to the Kotlin DSL file.
- `guards.safeDeps.enabled` — `false` opts the repo out of `safe-deps`.
- `guards.safeDeps.mirrorPins` — packages whose version is duplicated in
  files outside `package.json`. `safe-deps` syncs each listed file when it
  bumps the package.
- `guards.prToProduction.enabled` — `false` disables the
  `pr-to-production` skill for this repo.
- `guards.tfDrift.enabled` — `false` (or absent) disables the `tf-drift`
  skill for this repo. Only Terraform repos with a drift-sweep workflow
  should enable it.
- `guards.tfDrift.driftWorkflow` — the nightly drift-sweep workflow file
  (default `terraform-drift.yml`) the skill reads runs from.
- `guards.tfDrift.remediateWorkflow` — the one-click revert workflow file
  (default `terraform-remediate-drift.yml`) the skill drives for a revert.
- `guards.tfDrift.applyWorkflow` — the post-merge apply workflow file
  (default `terraform-apply.yml`) the `tf-drift` unapplied-merge route and the
  `tf-apply` skill dispatch. `tf-apply` reads this same block.
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
| `repo.environment` | `"prod"` (strictest — `tf-apply` enforces the second-person gate) |
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
