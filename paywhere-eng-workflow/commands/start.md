---
description: Start work on a Linear ticket by setting up a feature branch off the default branch
parameters:
  - name: ticketId
    description: Linear ticket ID (e.g., ENG-123). Required.
    required: true
  - name: slug
    description: Branch slug (lowercase, hyphens). Optional — falls back to the ticket title.
    required: false
---

# Start work on a Linear ticket

Open a feature branch off the default branch for an existing Linear
ticket. Same ticket can be reused across multiple PRs — running this
command a second time on the same ticket creates a second branch (with a
new slug). If the ticket is closed, this command will prompt to reopen
it before proceeding.

## Preamble

Read `.claude/eng-workflow.json` from the current working directory. If
it's missing, stop and tell the user to run `/eng-init`. Use
`linear.team`, `linear.teamId`, `linear.activeStates`,
`repo.defaultBranch`, and `repo.branchPattern` from that file in place of
any hardcoded values. See the canonical [CONVENTIONS](../skills/conventions/CONVENTIONS.md)
for shared formats.

## Steps

### 1. Validate the ticket argument

A ticket ID is **required**. If the user did not pass one, stop and tell
them:

> *"`/start` needs an existing Linear ticket ID. If you don't have one
> yet, run `/create` to make one from your current diff, or create the
> ticket in Linear first and rerun this command."*

Normalize the ticket ID to uppercase (`eng-123` → `ENG-123`).

### 2. Fetch the ticket from Linear

Use the Linear MCP (`get_issue` / `list_issues`) with `team =
linear.team` and the ticket identifier. If the ticket doesn't exist,
stop and tell the user.

Read the ticket's title, description, status, and recent comments.

### 3. Confirm the ticket is workable

If the ticket's state is **not** in `linear.activeStates`:

1. Tell the user the current state (e.g. *"ENG-123 is currently in 'Done'"*).
2. Ask via AskUserQuestion whether to reopen and transition it back to
   the first state in `linear.activeStates`.
3. If they decline, stop.
4. If they accept, call `save_issue` to move the state. Verify it took.

### 4. Choose a slug

- If the user supplied a slug argument, use it (slugify if it isn't
  already lowercase-hyphen).
- Otherwise, slugify the ticket title (lowercase, hyphens, max 50 chars,
  drop punctuation).

Build the branch name by substituting `{ticket-id-lc}`, `{ticket-id}`,
and `{slug}` into `repo.branchPattern`.

### 5. Handle branch collisions

Run `git rev-parse --verify <branch>` and `git ls-remote --heads origin
<branch>`. If either reports the branch already exists, ask the user for
a fresh slug. Loop until you have a non-colliding branch name. Do not
overwrite or reuse an existing branch — the same ticket can have
multiple branches, but each one must be distinct.

### 6. Prepare the workspace

Follow the **workspace preparation pattern** from CONVENTIONS. Summary:
stash dirty changes → checkout default branch → pull → `git checkout -b
<branch>` → pop stash if anything was stashed. Surface any conflict to
the user.

### 7. Plan the work

- Read the ticket carefully. Note acceptance criteria, edge cases,
  unanswered design questions.
- Search the codebase for relevant files. Reference `CLAUDE.md` for
  project-specific patterns.
- Draft an implementation plan that calls out:
  - Files to create or modify.
  - The testing approach (see **Test planning checklist** in CONVENTIONS).
  - Any decisions you can't make alone — surface them with
    AskUserQuestion.

### 8. Present and wait

Show the user:

- The Linear ticket details you found.
- The branch you created.
- The implementation plan.
- Any clarifying questions you need answered before starting.

**Do not start implementing until the user approves the plan.**

## Notes

- This command never closes a ticket and never updates its status to
  something past `linear.activeStates` — that's `/finish`'s job.
- If the user passes a ticket from a different Linear team, fetch it
  anyway (don't refuse), but warn that team conventions may differ.
