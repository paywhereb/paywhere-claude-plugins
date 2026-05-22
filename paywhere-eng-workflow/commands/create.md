---
description: Create a Linear ticket from current changes, branch off the default branch, and commit
parameters: []
---

# Create a Linear ticket from current changes

For when you have uncommitted work that isn't yet associated with a
ticket. Creates a Linear ticket summarising the diff, opens a fresh
branch off the default branch, and lands the changes as the first
commit.

## Preamble

Read `.claude/eng-workflow.json`. If missing, stop and tell the user to
run `/eng-init`. Use `linear.team`, `linear.teamId`,
`linear.defaultLabels`, `repo.defaultBranch`, and `repo.branchPattern`
from it. Follow the canonical
[CONVENTIONS](../skills/conventions/CONVENTIONS.md).

## Steps

### 1. Check for changes

`git status --porcelain`. If empty, tell the user there's nothing to
ticketize and exit.

### 2. Analyze the diff

- `git status` for the file list.
- `git diff` for unstaged.
- `git diff --staged` for staged.

Summarize what the changes do — focus on user-facing or behavioural
effects, not file lists.

### 3. Draft the ticket

- **Title**: `Verb + what was done` (e.g. *"Add environment variable
  controls for E2E test execution"*).
- **Description**: use the **ticket description template** from
  CONVENTIONS. Do not include file lists in the description.
- **Type**: infer from the diff — feature, bug fix, refactor, docs,
  chore.

### 4. Create the ticket via Linear MCP

`save_issue` with:

- `team`: `linear.team`
- `title`: from step 3
- `description`: from step 3
- `labels`: collect every UUID from `linear.defaultLabels` (across all
  groups — `type`, `component`, `category`). Apply all of them.

Capture the returned identifier (e.g. `ENG-NN`) and URL.

### 5. Prepare the workspace

Follow the **workspace preparation pattern** in CONVENTIONS. The
current diff will be stashed at the start and popped after the new
branch is checked out.

### 6. Build the branch name

Slugify the ticket title (lowercase, hyphens, max 50 chars). Substitute
into `repo.branchPattern`. If that branch already exists, ask the user
for a fresh slug.

### 7. Commit

After `git stash pop` restores the changes, commit them using the
**commit message format** from CONVENTIONS. The commit subject should
mirror the ticket title. **No Claude attribution.**

If `git stash pop` reports conflicts, stop and tell the user — don't
auto-resolve.

### 8. Report

Show the user:

- The Linear ticket (id, title, URL).
- The branch.
- The commit hash.
- A reminder that they can push and `/finish` when ready, or keep
  iterating locally first.

## Notes

- If the user wants to commit *without* a Linear ticket, this is the
  wrong command — they should just `git commit` directly. `/create`
  exists for when they want a Linear ticket retroactively from work
  they've started.
