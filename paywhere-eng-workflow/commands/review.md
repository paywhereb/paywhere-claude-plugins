---
description: Review the current implementation against the ticket and project conventions
parameters:
  - name: ticketId
    description: Linear ticket ID. Optional — inferred from the branch when absent.
    required: false
---

# Review the current implementation

Read the current diff against the ticket and the project's conventions,
report what's solid and what's missing.

## Preamble

Read `.claude/eng-workflow.json`. If missing, stop and tell the user to
run `/eng-init`. Use `linear.team`, `repo.defaultBranch`, and
`repo.branchPattern` from it. Follow the canonical
[CONVENTIONS](../skills/conventions/CONVENTIONS.md).

## Steps

### 1. Determine the ticket

- If the user passed a ticket id, use it.
- Otherwise extract from the current branch via `repo.branchPattern`.
- If neither works, ask the user. (`/review` is allowed to fall back to
  asking — unlike `/finish`, it isn't taking any destructive action.)

### 2. Pull ticket context

`get_issue` for the resolved id (`team = linear.team`). Note the
acceptance criteria and any open questions in the description or
comments.

### 3. Read the changes

- `git status` for the file list.
- `git diff <repo.defaultBranch>...HEAD` for everything since the
  branch diverged.
- Read the diff in depth, file by file.

### 4. Review against these dimensions

**Functionality**
- Does the implementation fulfil the ticket?
- Are acceptance criteria met?
- Edge cases handled?
- Error handling sensible?

**Testing** *(high priority)*
- Apply the **Test planning** and **Test documentation** checklists
  from CONVENTIONS.
- For bug fixes: regression test required.
- For features: happy path + key error scenarios.
- Be specific — name the test files and scenarios you'd add if
  coverage is missing.

**Code quality**
- TypeScript / linter errors? (Suggest the project's check command
  rather than running it for them.)
- Project patterns from `CLAUDE.md`?
- Security concerns?
- Readability and maintainability?

**Documentation**
- Comments needed for non-obvious logic?
- README / `.env.example` need updating?
- API changes documented?

**Architecture**
- Follows the project's architectural patterns from `CLAUDE.md`?
- Any duplication that warrants refactoring?
- Right level of abstraction?

**Completeness**
- TODOs left behind?
- Debug `console.log` or `print` calls?
- Missing files?
- New dependencies declared in `package.json` / equivalent?

### 5. Report

Organise the report into three sections:

- ✅ **Looks good** — what's right.
- ⚠️ **Recommendations** — actionable, with file paths and (where
  possible) line numbers.
- 🔴 **Issues** — anything that should block the PR.

Prioritise impact. If the implementation is solid, say so plainly — do
not manufacture problems.

End by offering to help fix any of the flagged items.

## Notes

- `/review` is read-only. It does not run tests, commit, push, or move
  the ticket. Those are explicit user actions.
- If the ticket is in `linear.reviewState` already, this is a
  pre-merge sanity check, not a gate.
