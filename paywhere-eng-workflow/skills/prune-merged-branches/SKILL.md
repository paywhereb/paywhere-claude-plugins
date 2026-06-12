---
name: prune-merged-branches
description: Safely delete local branches whose PR has been merged. Reports first, deletes only after confirmation. Skips any branch with commits past the PR's merged head so un-pushed work is never lost.
disable-model-invocation: true
---

Delete the local branches that already shipped via a merged PR, while
refusing to touch any branch that still has commits past what was
merged.

## Why a dedicated skill

`git branch -d` and `git branch --merged` check commit *ancestry*. A
squash-merge creates a fresh commit on the default branch with no
parent link back to the feature branch tip — so to git, the feature
branch looks "unmerged" even though every line shipped. The naive
catch-all `git branch --merged origin/main | xargs git branch -d` will
miss every squash-merged branch.

`git branch -D` (force) deletes anything but doesn't protect un-pushed
commits — if a local branch had an extra commit that never reached the
remote, force-deleting after the PR was merged silently loses that
commit.

This skill threads the needle: ask GitHub which branch names had a
merged PR (squash-aware), then for each candidate, refuse to delete
unless the local tip is exactly the SHA GitHub recorded at merge time.

## Prerequisites

1. `gh` CLI authenticated against the right host (`gh auth status`).
2. Working tree clean. If `git status --porcelain` is non-empty, stop
   and tell the user — switching branches while editing is the kind of
   accident this skill should not enable.
3. Run from the repo root.

## Step 1 — Determine the default branch

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
```

If empty, fall back to `main` or `master` (whichever exists). If
neither, stop and ask the user.

## Step 2 — Refresh remote state

```bash
git fetch --prune --quiet
```

`--prune` drops `refs/remotes/origin/*` whose remote branch is gone.
This is purely a tracking-ref cleanup — local branches are untouched.

## Step 3 — Build the merged-PR map

**Pin `gh` to the `origin` remote.** With bare `gh pr list`, `gh`
resolves the repo from its own default, which is *not* guaranteed to be
`origin`. In a fork — e.g. this org forks `intuit/quickbooks-online-mcp-server`,
so the repo has `origin` (the paywhere fork) **and** `upstream` (intuit)
— and with no `gh repo set-default`, `gh` silently queries `upstream`.
The map then describes the wrong repository, every local branch falls
into SKIP-noPR, and the skill quietly does nothing. Derive the slug
from `origin`'s URL and pass it explicitly:

**Write the map to a unique temp path**, not a fixed `/tmp/merged-prs.tsv`.
A hardcoded shared filename can be clobbered mid-run by a concurrent
invocation (another Claude session, a parallel checkout) — and the
silent failure is dangerous: the map gets overwritten with *another
repo's* merged PRs, so your local branches either all fall into
SKIP-noPR or, worse, a same-named branch matches an unrelated SHA. Use
`mktemp` so every run gets its own file:

```bash
ORIGIN_SLUG=$(git remote get-url origin \
  | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')

MAP=$(mktemp "${TMPDIR:-/tmp}/merged-prs.XXXXXX")

gh pr list --repo "$ORIGIN_SLUG" --state merged --limit 200 \
  --json headRefName,headRefOid \
  --jq '.[] | [.headRefName, .headRefOid] | @tsv' \
  > "$MAP"
```

Each line: `<branch-name>\t<head-SHA-at-merge>`.

Sanity-check the map before trusting it: if `"$MAP"` is empty or none
of its branch names resemble your local branches, you are probably
pointed at the wrong repo (or the file was clobbered) — re-derive
`ORIGIN_SLUG`, confirm it matches `git remote get-url origin`, and
rebuild the map at a fresh `mktemp` path. Remove `"$MAP"` when the
skill finishes.

200 is a sensible upper bound for normal repos; bump it (`--limit
1000`) if the repo has a long tail of stale merged PRs that still
correspond to local branches.

## Step 4 — Classify each local branch

For every local branch except the default branch and the current
branch (you can't delete the branch you're on):

```bash
git for-each-ref --format='%(refname:short)' refs/heads \
  | grep -vE "^(${DEFAULT_BRANCH}|teamcity-settings)$" \
  | while read BRANCH; do
      # Skip the current branch.
      [[ "$BRANCH" == "$(git branch --show-current)" ]] && continue
      ...
    done
```

For each branch, look up its PR head SHA from the map. Four
classifications:

| Class | Meaning | Action |
|---|---|---|
| **DELETE** | A merged PR's head SHA equals the local branch tip | mark for deletion |
| **KEEP** | A merged PR exists, the PR head is in the local branch's ancestry, but the local tip is past that SHA | refuse — there are commits past what shipped |
| **SKIP-noPR** | No merged PR has this branch name | refuse — could be active work, a draft branch, or a branch whose PR was closed without merging |
| **SKIP-divergent** | A merged PR exists but its head SHA is *not* in the local branch's ancestry | refuse — the local branch is something else that happens to share a name (rebased away, force-pushed away, or an unrelated reuse) |

The check:

```bash
PR_HEAD=$(awk -v b="$BRANCH" -F'\t' '$1==b {print $2; exit}' "$MAP")

if [[ -z "$PR_HEAD" ]]; then
    classify "$BRANCH" "SKIP-noPR" ""
    continue
fi

# Ensure the PR head object is in the local object DB. After PR merge
# GitHub usually deletes the remote branch, so it may not be in any
# remote-tracking ref. Fetch on demand. If even that fails, the SHA
# was force-pushed away on GitHub and we can't verify safety.
if ! git cat-file -e "$PR_HEAD" 2>/dev/null; then
    if ! git fetch origin "$PR_HEAD" --depth=1 --quiet 2>/dev/null; then
        classify "$BRANCH" "SKIP-divergent" "can't fetch PR head $PR_HEAD"
        continue
    fi
fi

if ! git merge-base --is-ancestor "$PR_HEAD" "$BRANCH"; then
    classify "$BRANCH" "SKIP-divergent" "PR head $PR_HEAD not in ancestry"
    continue
fi

AHEAD=$(git rev-list --count "$PR_HEAD..$BRANCH")
if [[ "$AHEAD" == "0" ]]; then
    classify "$BRANCH" "DELETE" "PR head matches local tip"
else
    classify "$BRANCH" "KEEP" "$AHEAD commit(s) past merged PR head"
fi
```

## Step 5 — Report

Show the user a table with every classified branch, grouped by class.
Example:

```
DELETE (5)
  dev-42/split-copy-step           PR head matches local tip
  dev-42/hardcode-paywhereadmin    PR head matches local tip
  ...

KEEP (1)
  dev-42/wip-feature               2 commit(s) past merged PR head
    abc1234 WIP: untested cleanup
    def5678 typo fix

SKIP (3)
  dev-99/never-PR'd                no merged PR found
  brett/old-experiment             no merged PR found
  team-fork-of-something           PR head <sha> not in ancestry
```

For each KEEP, list the local-only commits (`git log --oneline
"$PR_HEAD..$BRANCH"`) so the user can see exactly what they'd lose if
they manually force-deleted.

## Step 6 — Confirm and delete

**Default behaviour: report only.** Do not delete without explicit
confirmation in the same turn.

If the user already passed `--yes` (or equivalent affirmative) in the
slash-command arguments, skip the confirmation prompt. Otherwise, ask:

> *"Delete the N branches marked DELETE? [y/N]"*

On confirmation, delete with `-D` (force is needed because squash-merge
breaks `-d`'s ancestry check — the safety lives in the PR-head check
above, not in git's flag).

```bash
for BRANCH in "${DELETE_LIST[@]}"; do
    git branch -D "$BRANCH"
done
```

Never delete KEEP or SKIP branches automatically, even with `--yes`.
Those are the safety net — if you've made the rule "only delete when
the local tip equals the merged PR head," every other state is "I'm
not sure, leave it alone."

## Step 7 — Final report

Print a summary: `Deleted N branches. Kept M with un-shipped commits.
Skipped K with no merged PR.` and the working directory state (`git
status --short`).

## Edge cases

**Repo with a long merged-PR history.** Bump `--limit` on the `gh pr
list` call. The default 200 covers most active repos.

**A branch whose PR is open (not merged).** The map only contains
merged PRs, so it falls into SKIP-noPR. Correct — never delete a
branch with an open PR.

**A branch whose PR was closed without merging.** Same as above: only
merged PRs are in the map. SKIP-noPR. Correct — that work is
abandoned but the user should make that call manually.

**A branch with the same name as some old merged PR that's unrelated.**
The `merge-base --is-ancestor` check rejects it — the old PR's head
SHA isn't in the unrelated branch's history. Falls into SKIP-divergent.

**The default branch (`main` / `master`).** Excluded by the grep
filter. Never deleted.

**A repo-specific protected branch (e.g. `teamcity-settings` in
paywhere-admin).** Excluded by the grep filter. If the repo has other
long-lived non-default branches the user wants to protect, suggest
adding them to the filter — it's a one-character edit per branch.

**The currently-checked-out branch.** Excluded explicitly. Git would
refuse anyway, but skipping before the loop produces a cleaner report.

**`gh` returns nothing because the user isn't authenticated for this
host.** `gh pr list` fails with a clear error. Surface it and stop.

**A fork with an `upstream` remote (`gh` queries the wrong repo).**
The most dangerous *quiet* failure: the map is built, has plenty of
rows, and looks healthy — but the rows are `upstream`'s merged PRs, not
`origin`'s. None match local branch names, so everything becomes
SKIP-noPR and the skill reports "nothing to clean up" while real merged
branches sit there. Step 3's `--repo "$ORIGIN_SLUG"` pin prevents this;
the sanity-check (do the map's branch names resemble local ones?)
catches it if the pin is ever dropped. This bit us on
`paywhere-qbo-mcp`, which forks `intuit/quickbooks-online-mcp-server`.

## Why this design

- **GitHub is the source of truth for "did this ship".** The PR's
  merged state is the only signal that survives a squash-merge.
  Anything inferred from local git state (`--merged`, `git cherry`)
  has a failure mode where it disagrees with what's actually in main.
- **Report-first by default.** Cleanup that runs without the user
  looking at the output is exactly how someone loses an un-pushed
  commit they forgot about. The skill exists; you invoke it when
  you're in the headspace to look at the table.
- **Three classes of "no" beat one class of "no".** SKIP-noPR,
  SKIP-divergent, and KEEP all mean "don't delete," but the
  *reasons* are different and worth surfacing — each one points the
  user at a different follow-up (push the PR? abandon manually?
  rebase?).
- **`-D`, not `-d`, on the actual delete.** The safety is in the
  pre-check; making the delete itself conservative would just block
  the legitimate squash-merge cases this skill exists to handle.
