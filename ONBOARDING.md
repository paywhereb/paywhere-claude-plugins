# Claude Code onboarding — Paywhere engineering

One-time setup below, then every `paywhereb` repo just works: the
org-wide Claude rules load automatically at session start, and the
shared eng workflow (`/paywhere-eng-workflow:start`, `:finish`,
`safe-deps`, …) is available wherever the repo is onboarded.

## One-time setup

1. **Install Claude Code** — <https://claude.com/claude-code> (CLI,
   desktop app, or IDE extension; the CLI is what the steps below use).

2. **Make sure you have GitHub access to the `paywhereb` org.** The
   marketplace is fetched with your existing git credentials — `gh auth
   login` or a working SSH key both do. If `git clone
   https://github.com/paywhereb/paywhere-claude-plugins.git` works, so
   will the marketplace.

3. **Add the marketplace and install the plugin:**

   ```bash
   claude plugin marketplace add paywhereb/paywhere-claude-plugins
   claude plugin install paywhere-eng-workflow@paywhere-claude-plugins
   ```

   (Inside a session, `/plugin marketplace add …` and `/plugin install …`
   are equivalent.)

4. **Confirm the plugin is enabled at user scope.** The two commands in
   step 3 record this automatically — your `~/.claude/settings.json`
   should now contain both of these keys (alongside anything you already
   had there):

   ```json
   {
     "extraKnownMarketplaces": {
       "paywhere-claude-plugins": {
         "source": { "source": "github", "repo": "paywhereb/paywhere-claude-plugins" }
       }
     },
     "enabledPlugins": {
       "paywhere-eng-workflow@paywhere-claude-plugins": true
     }
   }
   ```

   If either key is missing (e.g. the install landed at project scope),
   add them by hand. User scope is what matters: plugin hooks only fire
   where the plugin is *enabled*. Repos with a checked-in
   `.claude/settings.json` enable it per-project, but user scope covers
   everything else — the plugin's SessionStart hook then decides
   per-directory whether to inject (it gates on the `origin` remote
   being a `paywhereb` repo and stays silent in personal projects).

That's it. Open `claude` in any paywhereb repo and ask "what Paywhere
org rules apply?" to confirm the injection is live.

## Per-repo setup

**Nothing.**

- Repos that check in `.claude/settings.json` (paywhere, paywhere-admin,
  paywhere-mcp, paywhere-devops, …): the first session asks you to trust
  the repo's settings and confirm the plugin install — accept once and
  it keeps loading automatically.
- paywhereb repos that aren't onboarded yet: Claude will proactively
  offer `/paywhere-eng-workflow:eng-init`, which writes the repo's
  `.claude/eng-workflow.json` and shared `.claude/settings.json`.

## Staying current

Rules and workflow changes ship as plugin releases. To pick them up:

```bash
claude plugin update paywhere-eng-workflow
```

`claude plugin marketplace update paywhere-claude-plugins` refreshes the
catalog itself if a brand-new plugin was added.

## What you get

- **Org-wide rules, always on** — no attribution trailers in
  commits/PRs, source-controlled memory convention, no PATs in
  workflows, IaC-managed branch protection, and the other headlines in
  [`paywhere-eng-workflow/rules/ORG-RULES.md`](paywhere-eng-workflow/rules/ORG-RULES.md).
- **The shared eng workflow** — Linear-ticket-driven branching
  (`/paywhere-eng-workflow:start` … `:finish`), `safe-deps`,
  `tc-reconcile`, `pr-to-production`, and friends. Full catalog in
  [`paywhere-eng-workflow/README.md`](paywhere-eng-workflow/README.md).

## Appendix: isolating your Paywhere Claude config (optional)

If you keep personal and Paywhere Claude state separate, you can scope a
dedicated config dir to the Paywhere tree with
[direnv](https://direnv.net/):

```bash
# ~/Projects/Paywhere/.envrc
export CLAUDE_CONFIG_DIR=$HOME/.claude-paywhere
```

Then `direnv allow`, and every `claude` launched under
`~/Projects/Paywhere/` uses `~/.claude-paywhere` (its own settings,
plugins, and history) while `claude` elsewhere keeps using `~/.claude`.
If you do this, the one-time setup above (marketplace add, install,
user-scope settings) has to be done *inside* the Paywhere tree so it
lands in the scoped config dir.

This is a personal-preference pattern, not something the team relies
on — `CLAUDE_CONFIG_DIR` is honored by the CLI but this isolation setup
is otherwise undocumented/unsupported. Skipping it is fine.
