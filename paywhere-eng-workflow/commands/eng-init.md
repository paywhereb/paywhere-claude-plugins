---
description: Bootstrap .claude/eng-workflow.json for a fresh repo
parameters: []
---

# Bootstrap eng-workflow config

Generate `.claude/eng-workflow.json` for the current repo, detecting
defaults from git and asking the user for the Linear bits we can't
infer.

## Steps

### 1. Refuse if already configured

If `.claude/eng-workflow.json` already exists, read it, summarise it
back to the user, and ask whether to overwrite via AskUserQuestion. If
they decline, stop. If they accept, continue.

### 2. Detect defaults from git

- `repo.defaultBranch`:
  - `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`.
  - Fall back to checking which of `main` / `master` exists on the
    remote. If neither, ask the user.
- `repo.name`:
  - Parse the `origin` remote URL. For
    `git@github.com:paywhereb/paywhere-admin.git` → `paywhere-admin`.
    For an HTTPS URL, take the last path segment minus `.git`.
  - If parsing fails, fall back to the current directory's basename.

Default `repo.branchPattern` to `"{ticket-id-lc}/{slug}"` unless the
user wants something else (see step 4).

### 3. Ask for Linear config

The on-disk schema for the file you're about to write is defined in
the plugin README's "Schema" section — every key you emit must match
those names exactly (`linear.team`, `linear.teamId`,
`linear.defaultLabels`, etc.), since every consumer command and skill
reads those names. Don't invent alternates (no `teamName`, no plain
`labels`).

Use AskUserQuestion. Offer these choices on the team (the answers
land as `linear.team` for the display name and `linear.teamId` for the
UUID):

- **Engineering (recommended)** — pre-fills `linear.team =
  "Engineering"` and `linear.teamId =
  "19c916e9-7be3-40f1-adc3-fbf03fe53b5d"`.
- **Other** — prompt for the team name; the user runs
  `mcp__claude_ai_Linear__list_teams` ahead of time to find the id, or
  asks Claude to call it directly during this command.

For labels (the answers land under `linear.defaultLabels`, an object
keyed by Linear label-group — `type`, `component`, `category` — each
mapping `<label-name>` → `<uuid>`), offer:

- **Admin App defaults** — pre-fills:

  ```json
  "defaultLabels": {
    "type":      { "Change":    "c1eebf96-1092-4a84-a136-16d830d9b9e1" },
    "component": { "Admin App": "4309ea9d-6978-4d79-b7aa-1b4c92cd308e" },
    "category":  { "Admin":     "9cf65af6-fa6d-4ec0-a0ca-a4b48dbb82a4" }
  }
  ```

- **Custom** — prompt for one label per axis (`type`, `component`,
  `category`). Use
  `mcp__claude_ai_Linear__list_issue_labels` against the chosen team to
  resolve names → UUIDs. If the team doesn't use a given axis, write
  it as an empty object (`"component": {}`) — keep the key present so
  consumer commands' `defaultLabels[<axis>]` iteration succeeds.

Confirm `linear.activeStates` (default `["Todo", "In Progress"]`) and
`linear.reviewState` (default `"In Review"`) — keep the defaults
unless the user objects.

### 4. Ask about guards

- `guards.tcReconcile`: ask if the repo uses TeamCity versioned
  settings.
  - If yes: default `enabled: true`, `settingsPath:
    ".teamcity/settings.kts"`.
  - If no: `enabled: false`, omit `settingsPath`.
- `guards.safeDeps`: default `enabled: true`. Skip the `mirrorPins`
  list at init time — the user can add entries when a real mirror-pin
  shows up. Mention the schema in the closing message.
- `guards.prToProduction`: ask if the repo deploys via a
  `main → production` PR cut. Default `enabled: true` for repos that
  do.

### 5. Ask about an extra guards skill

Look for `.claude/skills/local-checks/SKILL.md`. If it exists, set
`extraGuardsSkill` to `.claude/skills/local-checks`. Otherwise omit
the field — `safe-deps` will skip the hook when it's absent.

### 6. Write `.claude/eng-workflow.json`

Compose the JSON to **exactly match the canonical schema** in the
plugin README's "Schema" section. Top-level key order: `linear`,
`repo`, `guards`, then `extraGuardsSkill` if present. Pretty-print
with two-space indentation.

Template (drop optional keys when not applicable — `extraGuardsSkill`
when no repo-local skill exists, `guards.tcReconcile.settingsPath`
when `tcReconcile.enabled` is `false`, `guards.safeDeps.mirrorPins`
when there are no pins yet):

```json
{
  "linear": {
    "team": "<display name>",
    "teamId": "<uuid>",
    "defaultLabels": {
      "type":      { "<name>": "<uuid>" },
      "component": { "<name>": "<uuid>" },
      "category":  { "<name>": "<uuid>" }
    },
    "activeStates": ["Todo", "In Progress"],
    "reviewState": "In Review"
  },
  "repo": {
    "name": "<repo-name>",
    "defaultBranch": "main",
    "branchPattern": "{ticket-id-lc}/{slug}"
  },
  "guards": {
    "tcReconcile":    { "enabled": <bool>, "settingsPath": "<path>" },
    "safeDeps":       { "enabled": <bool> },
    "prToProduction": { "enabled": <bool> }
  },
  "extraGuardsSkill": "<path>"
}
```

Do not rename keys (no `teamName` instead of `team`, no plain `labels`
instead of `defaultLabels`) — every consumer command and skill reads
the exact names above and will silently fail to find the team/labels
otherwise.

If `.claude/` does not exist yet, create it.

### 7. Declare the plugin requirement in `.claude/settings.json`

So teammates who trust this repo get prompted to install the plugin
automatically (and so any IDE / sandbox tooling that respects
`extraKnownMarketplaces` picks it up), update `.claude/settings.json`
to register the marketplace and enable the plugin.

Procedure:

1. Read `.claude/settings.json` if it exists. Parse the JSON. If the
   file is missing, start from `{}`.
2. Merge in (do **not** overwrite other top-level keys like
   `permissions`):

   ```json
   {
     "extraKnownMarketplaces": {
       "paywhere-claude-plugins": {
         "source": {
           "source": "github",
           "repo": "paywhereb/paywhere-claude-plugins"
         }
       }
     },
     "enabledPlugins": {
       "paywhere-eng-workflow@paywhere-claude-plugins": true
     }
   }
   ```

   For nested keys: deep-merge. If the user already has an entry under
   `extraKnownMarketplaces["paywhere-claude-plugins"]` with a different
   `source`, **stop and surface the conflict** rather than silently
   overwriting it — they may be pointing at a fork or a local checkout
   on purpose.

3. Write the merged JSON back, pretty-printed with two-space
   indentation. Preserve any unrelated existing fields.

If the user has both `.claude/settings.json` and
`.claude/settings.local.json`, write only to the shared
`settings.json` (so the requirement is committed and shared with the
team — `settings.local.json` is user-only).

### 8. Report next steps

Tell the user:

- That `.claude/eng-workflow.json` was written (with the path).
- That `.claude/settings.json` was updated to register the marketplace
  and enable `paywhere-eng-workflow` (mention if the file was created
  vs. merged into an existing file).
- That the plugin's `/start`, `/finish`, `/create`, `/review`, and the
  `safe-deps`, `tc-reconcile`, `pr-to-production` skills are now active
  in this repo.
- That if they had a previous repo-local copy of any of those (in
  `.claude/commands/` or `.claude/skills/`), they should delete it so
  the plugin version takes over.
- That they should commit both `.claude/eng-workflow.json` and
  `.claude/settings.json` so the rest of the team picks up the same
  config and the plugin requirement.

## Notes

- This command is the only one in the plugin that's safe to run without
  a pre-existing config — every other command/skill stops with the
  "run `/eng-init`" message when the config is missing.
- If the user is in a repo with multiple Linear teams (uncommon), this
  command captures only one team's config. They can hand-edit
  `eng-workflow.json` afterwards, or run with `--force` later.
