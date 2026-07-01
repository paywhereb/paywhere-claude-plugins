---
name: pr-to-production
description: Raise a Linear release ticket and a PR to merge the default branch into production, listing all included changes with a summary
disable-model-invocation: true
---

Open a Linear ticket with the **`release`** label, then create a pull
request that merges the repo's default branch into `production` and
references the ticket. The PR body lists every change included in the
merge (one line per commit) plus a concise summary of the major changes.

## Preamble — read `.claude/eng-workflow.json`

Before the steps below, load `.claude/eng-workflow.json`:

- If missing, stop and tell the user to run `/eng-init`.
- If `guards.prToProduction.enabled === false`, stop with the message:
  *"`pr-to-production` is disabled for this repo (set
  `guards.prToProduction.enabled: true` in `.claude/eng-workflow.json`
  to enable)."* — do nothing else.
- Use `linear.team`, `repo.defaultBranch`, and `repo.name` in place of
  any hardcoded values below.

## Steps

1. **Verify branches exist**: Confirm both the default branch and
   `production` exist on the remote:
   ```bash
   git ls-remote --heads origin <defaultBranch> production
   ```
   If either is missing, stop and tell the user.

2. **Fetch latest**: Run `git fetch origin` so comparisons are against
   current remote state.

3. **Find the commits to be merged**: Run
   ```bash
   git log --no-merges --pretty=format:'%h %s' origin/production..origin/<defaultBranch>
   ```
   This is the authoritative list of changes the PR will include. If
   the output is empty, stop — production is already up to date with
   the default branch.

4. **Get commit bodies for the summary**: Run
   ```bash
   git log --no-merges --pretty=format:'%h%n%s%n%b%n---' origin/production..origin/<defaultBranch>
   ```
   Use this to understand what each change does so you can write the
   summary. Do NOT just paraphrase commit subjects — read bodies for
   context.

5. **Check for an existing open release PR first** before creating
   anything else — this prevents duplicate Linear tickets:
   ```bash
   gh pr list --base production --head <defaultBranch> --state open --json url,number,title
   ```
   If one is open, do NOT create a new ticket or PR — report the
   existing PR URL and stop.

6. **Compose the PR body** (you'll need it for the ticket description
   too) with this exact structure:

   ```markdown
   ## Summary

   <2-5 sentence summary of the major changes — focus on the "why" and grouping related work, not a literal restatement of every commit>

   ## Changes

   - <hash> <commit subject>
   - <hash> <commit subject>
   ...
   ```

   Rules for the Changes list:
   - One line per commit, in the order returned by `git log` (newest first).
   - Use the short hash and the commit subject verbatim — do not rewrite subjects.
   - Do not include merge commits (the `--no-merges` flag handles this).

   Rules for the Summary:
   - Group related commits into themes rather than listing each one again.
   - Call out anything operationally significant: migrations, infra/CI changes, feature flags, breaking changes, deploy ordering.
   - Keep it tight — this is a release-style summary, not a changelog.

7. **Pick a title**: Use `Release: <repo.name> <defaultBranch> → production (<YYYY-MM-DD>)` with today's date, unless the user has already specified one. Use the same title for both the Linear ticket and the PR.

8. **Create the Linear release ticket** in `linear.team` with label `release`. Use the `mcp__claude_ai_Linear__save_issue` tool:
   - `team`: `linear.team`
   - `title`: the title from step 7
   - `labels`: `["release"]`
   - `description`: the same body composed in step 6
   - Do NOT set `relatedTo`, `blockedBy`, `parentId`, or any other relation — release tickets are intentionally standalone and must not be linked to other issues.

   Capture the returned identifier (e.g. `ENG-###`) and URL — you'll need both for the PR.

9. **Create the PR**: Push is not needed (both branches are already on the remote). Prepend the ticket identifier to the title and add a `Linear ticket:` line at the top of the body so it appears above `## Summary`.

   Label the PR `release`. This marks it as release plumbing so
   auto-generated release-notes tooling (e.g. a repo's
   `.github/release.yml` `exclude.labels`) can keep these
   `main→production` PRs out of the changelog. `gh pr create --label`
   fails if the label doesn't exist, so ensure it first (idempotent):

   ```bash
   gh label create release \
     --description "main→production release PR; excluded from auto-generated release notes" \
     --color 5319e7 2>/dev/null || true

   gh pr create \
     --base production \
     --head <defaultBranch> \
     --title "<ENG-###>: <title>" \
     --label release \
     --body "$(cat <<'EOF'
   Linear ticket: <ENG-### URL>

   <body from step 6>
   EOF
   )"
   ```

10. **Report both URLs** to the user: the Linear ticket URL and the PR URL.

## Important

- The base branch is `production`, the head branch is the repo's default branch. Do NOT swap these.
- Do NOT push, force-push, or modify either branch — this skill only opens a Linear ticket and a PR.
- Do NOT add any Claude attribution / `Co-Authored-By` trailer to the PR body or the Linear ticket.
- Do NOT link the Linear ticket to any other issue. Release tickets are standalone — no parent, no blocks/blocked-by, no related-to.
- If `gh` is not installed or not authenticated, stop and tell the user to run `gh auth login`.
- If an open release PR already exists (step 5), do NOT create a duplicate ticket or PR — report the existing PR URL and stop.
