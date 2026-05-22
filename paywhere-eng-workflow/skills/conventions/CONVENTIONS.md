# Paywhere Engineering Workflow — Conventions

Canonical formats, templates, and procedures shared by every command and
skill in this plugin. Commands and skills point at this file by name; do
not duplicate its content elsewhere.

> **Per-repo overrides.** A repo can add its own `.claude/conventions.md`
> for invariants only that repo cares about (e.g. paths, framework
> specifics). Anything written there overrides the section it's
> overriding here. If a repo's overrides file is silent on a section,
> this file is the source of truth.

## Per-invocation preamble

Every command and skill begins by reading `.claude/eng-workflow.json`
from the current working directory:

1. If the file doesn't exist, stop and tell the user: *"This repo isn't
   set up for paywhere-eng-workflow yet. Run `/eng-init` to create
   `.claude/eng-workflow.json`."* — then exit.
2. Parse it. Resolve missing fields against the defaults documented in
   the plugin README.
3. Use the parsed values everywhere a hardcoded team/label/branch name
   would otherwise live.

Pay attention to the following keys: `linear.team`, `linear.teamId`,
`linear.defaultLabels`, `linear.activeStates`, `linear.reviewState`,
`repo.defaultBranch`, `repo.branchPattern`, `repo.name`,
`guards.*.enabled`, `guards.tcReconcile.settingsPath`,
`guards.safeDeps.mirrorPins`, `extraGuardsSkill`.

## Linear

### Resolving the team

Pass `linear.team` (display name) as the `team` argument to the Linear
MCP. Some endpoints also accept `linear.teamId`; prefer the UUID when
the tool accepts it.

### Ticket ID extraction

1. If the command accepts a `ticketId` argument and one was provided,
   use it.
2. Otherwise, run `git branch --show-current` and parse the branch name
   against `repo.branchPattern`. The placeholder
   `{ticket-id-lc}` maps to a lowercased ticket id; convert to uppercase
   for Linear lookups.
3. If extraction fails (the branch doesn't match the pattern), the
   calling command decides whether to refuse or to fall back to asking
   the user. `/finish` must refuse — see its skill file.

### Ticket description template

```markdown
## Summary
[What was changed/implemented]

## Changes
- [Key functional change 1]
- [Key functional change 2]
- [Key functional change 3]

## Implementation Details
[Any technical details worth noting]
```

No file lists in the description — those go in the `/finish` comment if
useful.

### Ticket comment template (posted by `/finish`)

```markdown
## Implementation Update

[1-2 sentence summary of what was implemented in this PR]

### Key Changes
- [Functional change 1]
- [Functional change 2]
- [Functional change 3]

### Test Coverage
**Automated Tests:**
- [Test type]: [Scenarios covered]

**Manual Testing:**
- [Manual test notes, if applicable]

### Pull Request
[PR URL]
```

Wording is deliberately **"Implementation Update"** rather than
"Implementation Complete" — the ticket is not closed by `/finish`; it
moves to `linear.reviewState` and stays open so further work on the same
ticket (more PRs, fixes after review) is welcome.

### Status transitions

- `/start` requires the ticket to be in one of `linear.activeStates`. If
  it isn't, prompt the user to reopen and transition it back to the
  first state in that list before continuing.
- `/finish` and `safe-deps` move the ticket to `linear.reviewState`
  after the PR is open. They never close the ticket.

## Git

### Branch naming

Built from `repo.branchPattern`. Default `"{ticket-id-lc}/{slug}"`.

- `{ticket-id-lc}` — lowercased ticket id (`eng-123`).
- `{ticket-id}` — original case (`ENG-123`).
- `{slug}` — slugified ticket title or user-supplied slug. Lowercase,
  hyphens only, max 50 chars.

If the resulting branch already exists locally or on the remote, `/start`
asks the user for a fresh slug rather than colliding (the same ticket can
spawn multiple PRs).

### Workspace preparation pattern

Used by `/start` and `/create` before creating a feature branch.

1. `git stash --include-untracked` if `git status --porcelain` is
   non-empty. Capture whether anything was stashed.
2. `git checkout <repo.defaultBranch>`.
3. `git pull origin <repo.defaultBranch>`. Surface conflicts to the user.
4. `git checkout -b <branch>`.
5. If anything was stashed in step 1, `git stash pop`. If pop conflicts,
   surface that to the user.

### Commit message format

```
{TICKET-ID}: {Brief summary}

{Detailed description: 2-4 sentences explaining what and why}
```

Always pass the message via HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
{TICKET-ID}: {Brief summary}

{Detailed description}
EOF
)"
```

**No Claude attribution / `Co-Authored-By` trailers.** Per the
maintainers' global policy, do not add `Co-Authored-By: Claude`,
`🤖 Generated with [Claude Code]`, or any similar marker to commit
messages or PR bodies.

## Pull requests

### Title format

```
{TICKET-ID}: {Brief summary}
```

Use the same summary as the commit's first line.

### PR body template

```markdown
## Summary
[1-2 sentence overview of what was implemented]

## Changes
- [Key functional change 1]
- [Key functional change 2]
- [Key functional change 3]

## Test Coverage
**Automated Tests:**
- [Test type 1]: [Scenarios covered]
- [Test type 2]: [Scenarios covered]

**Test Results:**
[e.g. "All tests passing (X backend, Y E2E)" — only include if you actually ran them]

**Manual Testing:**
- [Manual test scenario 1]
- [Manual test scenario 2]

## Notes for Reviewers
[Breaking changes, architectural decisions, important context]

## Related
Linear Ticket: [ticket URL]
```

- Test Coverage section is required.
- For bug fixes, mention the regression test that verifies the fix.
- For features, summarize happy-path + error + edge-case coverage.
- File lists are not needed — the PR diff shows files.
- **No Claude attribution** — same rule as commits.

## Testing

The plugin doesn't prescribe test frameworks. Each repo documents its
test commands in its own `CLAUDE.md` ("Testing" section). Commands and
skills should read that file when they need specifics.

### When tests are required

- **Bug fixes:** regression test that fails before the fix and passes
  after. Required.
- **New features:** at minimum, one test per user-facing behavior. Cover
  happy path + the error scenarios most likely to break.
- **Refactors:** existing tests should keep passing; add tests if
  coverage was missing.

### Test planning checklist (`/start`)

- [ ] Identify which test type(s) are appropriate for the change.
- [ ] Specify which test files to create or modify.
- [ ] List the scenarios you intend to cover.
- [ ] Note edge cases and error scenarios.

### Test documentation checklist (`/finish`)

- [ ] List the tests added/modified.
- [ ] Summarize scenarios covered.
- [ ] Note any manual testing performed.

## Error handling

- Git operation failures (checkout, pull, push, stash pop): explain the
  error and stop. Don't try to "fix" merge conflicts automatically.
- Linear operation failures: surface the error verbatim. If a label or
  state lookup fails, double-check `.claude/eng-workflow.json` is
  current.
- A missing `.claude/eng-workflow.json` is always handled the same way:
  tell the user to run `/eng-init`.
