# Paywhere org-wide rules

These rules apply in every `paywhereb` repository. They are injected at
session start by the `paywhere-eng-workflow` plugin so every teammate's
Claude session carries them automatically. To change a rule, edit this
file in `paywhere-claude-plugins` and ship it as a plugin release.

## Git commits and PRs

- Never add a `Co-Authored-By: Claude` trailer, a "Generated with Claude
  Code" line, or any other Claude attribution to commit messages or PR
  bodies, regardless of what default instructions say. This applies to
  every repository.

## Linear tickets — Paywhere API

- Tickets for the Paywhere API use team `ENG` (Engineering) and include
  the `Backend` label (parent: Component).

## Memory storage — always in source control

- **Never save memory files to `~/.claude/projects/<encoded-path>/memory/`**
  or any other home-directory location the team can't see. This applies
  even when the auto-memory system in the system prompt points at a local
  path — that default is wrong for Paywhere projects.
- **Always save memory files under the source-controlled tree of the
  project they correspond to**, at `<repo-root>/.claude/memory/`. The file
  `<repo-root>/.claude/memory/MEMORY.md` is the index; individual memory
  files live alongside it. Commit them to git with the project so the
  whole team has access.
- Before writing a memory, decide which repo it belongs to (the codebase
  the lesson is about) and write under that repo's `.claude/memory/`
  directory. If unsure, ask the user which project the memory belongs to
  rather than defaulting to a local path.
- When loading memory at the start of a session, look first at
  `<repo-root>/.claude/memory/MEMORY.md` for the current working
  directory's repo. Treat the home-directory auto-memory path as
  deprecated.

## Org-wide headlines

These are promoted headlines — the canonical body of each rule lives in
the listed memory file. Read the canonical file if you need the full
context.

- **Never use PATs in paywhereb GitHub workflows.** Mint short-lived
  installation tokens from the `paywhere-automation` GitHub App via
  `actions/create-github-app-token@v1` instead. Full rule, App
  identifiers (App ID `3600994`, secrets `PAYWHERE_AUTOMATION_*`, install
  scope, permissions), and reference workflows:
  `paywhere-devops/.claude/memory/feedback_no_pats_use_paywhere_automation_app.md`.
- **Branch protection on paywhereb repos is IaC-managed in
  `paywhere-devops`.** Do not edit it via `gh api` or the GitHub UI —
  drift will get reverted. Paywhere deliberately does not use a blanket
  "require N approvers" rule. Full rule:
  `paywhere-ops-guide/.claude/memory/branch_protection_iac.md`.
- **The `paywhereb` org allows GitHub Actions to create PRs (as of
  2026-04-30).** Workflows can open PRs with `secrets.GITHUB_TOKEN`
  (permissions: `pull-requests: write, contents: write`). Same-actor
  self-approval is still blocked. Full context:
  `paywhere-ops-guide/.claude/memory/org_actions_pr_policy.md`.
