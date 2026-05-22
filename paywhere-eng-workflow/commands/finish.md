---
description: Finish work on a Linear ticket by committing, pushing, opening a PR, and posting a Linear comment
parameters: []
---

# Finish work on a Linear ticket

Commit the working changes, push, open a PR, post a Linear comment, and
transition the ticket to the review state. **Does not close the
ticket** — the same ticket can still spawn more PRs.

## Preamble

Read `.claude/eng-workflow.json`. If missing, stop and tell the user to
run `/eng-init`. Use `linear.team`, `linear.reviewState`,
`repo.defaultBranch`, `repo.branchPattern`, and `repo.name` from it.
Follow the canonical [CONVENTIONS](../skills/conventions/CONVENTIONS.md)
for commit, PR, and Linear comment formats.

## Steps

### 1. Extract the ticket ID from the current branch — REQUIRED

Run `git branch --show-current`. Parse the branch name against
`repo.branchPattern`.

If parsing fails (the branch doesn't encode a ticket id), **stop and
refuse**:

> *"This branch (`<name>`) isn't associated with a Linear ticket. To
> finish work on a ticket, branch off using `/start <TICKET-ID>` or
> create a fresh ticket from this diff with `/create`."*

Do not prompt the user for a ticket ID and do not invent one — the whole
point of the guardrail is that ticket association must be set up
front. Exit cleanly.

If parsing succeeds, normalize the ticket id to uppercase.

### 2. Verify the ticket exists in Linear

Call `get_issue` / `list_issues` with `team = linear.team` and the
ticket id. If it doesn't exist, the branch name is stale or
mistyped — stop and tell the user. (Catching this here is the point of
this step; don't try to proceed.)

### 3. Review what's about to ship

- `git status` — list modified/added/deleted files.
- `git diff` — read the actual diff for unstaged changes.
- `git diff --staged` — read staged changes.
- `git log <repo.defaultBranch>..HEAD` — see prior commits already on
  this branch (this PR may include them too).

Build a mental model of what this PR is changing. You'll need it for
the commit body, PR body, and Linear comment.

### 4. Commit

Follow the **commit message format** in CONVENTIONS. Always use the
HEREDOC pattern. **No Claude attribution / Co-Authored-By trailer.**

If everything is already committed (no staged + no unstaged changes),
skip this step and go to push.

### 5. Push

```bash
git push -u origin <branch>
```

If the branch already tracks origin, plain `git push` is fine.

### 6. Open the PR

`gh pr create` with:

- `--base <repo.defaultBranch>`
- `--head <branch>`
- `--title "<TICKET-ID>: <brief summary>"` (PR title format from
  CONVENTIONS)
- `--body` from the PR body template (HEREDOC). Include the Linear
  ticket URL under `## Related`.

If a PR is already open from this branch (`gh pr list --head <branch>
--state open`), do not create a duplicate. Report the existing URL and
continue.

### 7. Post a Linear comment

Use the **ticket comment template** from CONVENTIONS. Use the wording
"Implementation Update" — not "Complete" — because the ticket stays
open for further work.

Include:
- 1-2 sentence summary.
- Key changes.
- Test coverage (automated + manual).
- The PR URL.

### 8. Transition the ticket

Call `save_issue` to move the ticket to `linear.reviewState`. Do not
close it.

### 9. Report

Tell the user:

- The PR URL.
- The Linear ticket URL.
- That the ticket is now in `linear.reviewState`, **still open** — they
  can run `/start <same-ticket-id>` again on a new slug if they need a
  follow-up PR.
- Suggest running `/review` if they want a quality check before
  requesting reviewers.

## Notes

- The branch-association check in step 1 is non-negotiable. The
  alternative (asking the user for a ticket id when extraction fails)
  defeats the purpose — a stray `/finish` from `main` should not be
  able to manufacture an arbitrary ticket association after the fact.
- This command does not run tests or type checks. Use `/review` for
  that, or run them in CI.
