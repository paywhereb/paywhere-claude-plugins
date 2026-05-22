---
name: tc-reconcile
description: Fold the patches from an auto-raised TeamCity reconcile PR back into the repo's TeamCity DSL file, then delete the patch files so the PR can pass the `no-tc-patches` check and merge to the default branch. Run this whenever a `Reconcile TeamCity UI edits to main` PR is open.
---

Reconcile an auto-raised TeamCity UI-edit PR by folding each
`.teamcity/patches/*.kts` script back into the repo's TeamCity DSL file
and deleting it. This is the **intended developer workflow** for any
reconcile PR — the `no-tc-patches` required check blocks the PR from
merging until the patches are absorbed.

## Preamble — read `.claude/eng-workflow.json`

Before the steps below, load `.claude/eng-workflow.json`:

- If missing, stop and tell the user to run `/eng-init`.
- If `guards.tcReconcile.enabled === false`, stop with the message:
  *"`tc-reconcile` is disabled for this repo (set
  `guards.tcReconcile.enabled: true` in `.claude/eng-workflow.json` to
  enable)."* — do nothing else.
- Read `guards.tcReconcile.settingsPath` (default
  `.teamcity/settings.kts`) and use it everywhere `settings.kts` is
  referenced below.
- Read `repo.defaultBranch` (default `main`) and use it everywhere
  `main` is referenced below.

If the repo has additional context, `docs/teamcity-versioned-settings.md`
(when present) explains the topology — TC's two-way sync writes UI edits
to a `teamcity-settings` branch as patch scripts, a workflow opens a
reconcile PR back to the default branch, and this skill closes the loop.

## Prerequisites

1. Working tree must be clean. If `git status --porcelain` is non-empty, stop and tell the user.
2. `gh` CLI authenticated.
3. **`mvn` installed.** The skill validates the resulting DSL with `cd .teamcity && mvn -B teamcity-configs:generate`. Without it, validation can't run; note this to the user and ask them to validate before merging instead of skipping silently.

## Step 1 — Locate the reconcile PR

Find the open reconcile PR:

```bash
gh pr list --base <defaultBranch> --head teamcity-settings --state open \
  --json number,title,headRefName,url
```

There should be exactly one. If zero, stop — there's nothing to reconcile. If more than one, something's wrong with the workflow; stop and tell the user.

Stash the PR number, then check out the branch:

```bash
git fetch origin teamcity-settings:teamcity-settings
git checkout teamcity-settings
git pull --ff-only origin teamcity-settings
```

## Step 2 — Align with the default branch if diverged

The `tc-sync-on-main` workflow normally keeps `teamcity-settings`
fast-forwarded to the default branch, but it bails out the moment
`teamcity-settings` has commits ahead (e.g. TC pushed before sync ran).
Check:

```bash
git fetch origin <defaultBranch>
git rev-list --count origin/<defaultBranch>..HEAD   # commits ahead of default
git rev-list --count HEAD..origin/<defaultBranch>   # commits behind default
```

- Both zero → branch matches the default branch exactly; nothing to do, the reconcile PR shouldn't exist. Stop and investigate.
- Ahead > 0, behind 0 → normal case. Continue to Step 3.
- Ahead > 0, behind > 0 → diverged. **Rebase** `teamcity-settings` onto the default branch so the PR is up to date and the patch edits apply on top of the latest DSL:

  ```bash
  git rebase origin/<defaultBranch>
  ```

  If the rebase conflicts on a patch file (TC's `.teamcity/patches/*.kts`), accept the patch-side version (it represents the UI state). If it conflicts on the settings DSL file, stop and tell the user — the default branch and the UI edit are touching the same DSL block and a human needs to resolve.

## Step 3 — Classify each patch

For every file under `.teamcity/patches/**/*.kts`, read it and classify:

| Pattern | What it means | What to do |
|---|---|---|
| Every `val featureN = find<...> { ... }` has an empty `featureN.apply { }` block | **No-op patch.** TC re-serialized the project state without any real change (typically after a project-setting toggle like `buildSettings = PREFER_VCS`). | Delete the patch file — no settings-DSL edit needed. |
| `featureN.apply { <one or more assignments> }` | **Field changed.** TC edited a field in an existing feature. | Mirror the assignments into the matching `awsConnection { ... }` (or other DSL block) in the settings DSL, then delete the patch file. |
| `val featureN = add(<FeatureType> { ... })` | **Feature added in UI.** | Append the new DSL block to the right `features { }` (or other parent) section in the settings DSL, then delete the patch file. |
| `remove(find<...> { ... })` | **Feature deleted in UI.** | Remove the matching DSL block from the settings DSL, then delete the patch file. |
| `changeBuildType(...)` / other `change*` wrappers | UI edited a non-project entity (build type, VCS root, template). | Apply the change to the matching `object Xyz : BuildType({ ... })` (or `GitVcsRoot`, `Template`) in the settings DSL, then delete the patch file. |

**Matching rule:** in `find<TypeName> { ... }` blocks, the identifier inside is what TC uses to locate the feature — usually the `id`. Match it to the same `id` in the settings DSL (case-sensitive). Don't rely on declaration order.

**If you can't confidently classify a patch** (unexpected wrapper, unfamiliar feature type, ambiguous match), stop and tell the user which patch and why. Don't guess — a wrong reconciliation can silently corrupt the DSL and only surface when TC fails to sync.

## Step 4 — Apply and validate

After every patch is folded in and the patch files are deleted:

1. Run `cd .teamcity && mvn -B teamcity-configs:generate`. **BUILD SUCCESS** means the DSL still compiles against the real TeamCity plugin JARs. Any error here means the reconciliation introduced a syntax or type problem — fix it before committing.
2. Verify no patch files remain: `find .teamcity/patches -type f -name '*.kts' | head -5`. Should be empty.
3. Verify the directory is either empty or only contains the parent `projects/` subdirectory — either is fine, TC re-creates the tree on its next patch push.

## Step 5 — Commit and push

```bash
git add -A .teamcity/
git commit -m "$(cat <<'EOF'
Reconcile TeamCity UI edits into settings.kts

<one-line summary of what the UI edit actually changed — e.g.
"Bump AWS_CD_PUSHER session name from tc-cd-pusher to tc-cd-pusher-v2"
or "No-op patch from buildSettings = PREFER_VCS toggle">
EOF
)"
git push origin teamcity-settings
```

The push retriggers the workflow that opens / refreshes the reconcile PR, which refreshes the existing PR's title and body to reflect the new commit list.

## Step 6 — Verify the PR is mergeable

Wait a few seconds for the checks to start, then:

```bash
gh pr checks <PR-number> --watch
```

The `no-tc-patches` check must now pass (no patch files in the diff vs. the default branch). If the rest of the required checks pass too, the PR is ready to merge.

Tell the user:
- The PR number and URL.
- What the UI edit actually changed (one sentence — pulled from the patch contents in Step 3).
- That they can squash-merge it, after which the reset workflow will force-push `teamcity-settings` back to the default branch automatically.

## Edge cases

**The patch references a feature `id` that doesn't exist in the settings DSL.** The DSL is stale — someone removed the feature in DSL without TC catching up. Either the DSL change hasn't been deployed to TC yet (in which case wait for sync and re-run), or TC is genuinely out of step. Stop and tell the user.

**The patch sets a field to a value that's already in the settings DSL.** Likely a benign re-serialization; treat as no-op for that field and continue with the rest.

**Rebase conflicts on a patch file.** Accept the patch-side (`--theirs` if the patch is in `teamcity-settings` HEAD). The patch is the source of truth for what TC's UI thinks the state should be.

**Multiple back-to-back UI edits piled into one reconcile PR.** Each push from TC creates a separate patch file (or modifies the existing one). Process them in commit order — apply the oldest patch's effect first, then the next, etc. After all are folded, delete every patch file.

**The reconcile PR has been manually pushed to with non-TC commits.** Stop and ask — someone may be in the middle of a manual fix.

## Why this design

- **The patches are TC's source of truth for UI state.** Reading and folding them keeps the DSL the canonical representation without losing the human's UI intent.
- **No-op patches are a real and common case.** Toggling project-level settings (versioned-settings mode, VCS root selection) re-serializes everything as `find { ... }.apply { }` with no body. Recognizing and deleting them avoids cluttering the settings DSL with phantom edits.
- **`mvn teamcity-configs:generate` is the only reliable validation.** Visual inspection of the resulting DSL misses plugin-typed helper problems that only surface when compiled against the real TC plugin JARs.
- **Rebase, not merge, on divergence.** Squash-merging the reconcile PR collapses everything to one commit anyway; rebasing keeps the diff readable while it's in review and avoids a noisy merge commit in the PR.
- **Stop on ambiguity, don't guess.** A bad reconciliation only surfaces when TC fails to sync hours later, by which point the offending commit is buried. The cost of stopping for clarification is far lower than the cost of silently corrupting the DSL.
