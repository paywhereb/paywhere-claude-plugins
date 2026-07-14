---
name: tf-apply
description: Walk a human operator through the post-merge Terraform apply (the second-person gate) without hunting for a run id. Use when the Slack #aws-alerts "Terraform apply pending" / "unapplied merge" message fires, when someone asks "how do I apply this / apply the merged terraform / run the pending apply / apply <workspace>", or when /tf-drift routes an unapplied merge here. Finds the right plan_run_id automatically, shows the plan, verifies the operator is a valid non-author dispatcher, and dispatches the apply on their confirmation.
version: 0.2.0
allowed-tools: Read, Bash
---

Drive the **post-merge Terraform apply** for a no-CLI operator. A merge saves
a reviewed plan artifact; a **second person (not the PR author)** must then
dispatch the apply of that exact plan. The friction is finding the right
`plan_run_id` from a Slack ping and typing the dispatch correctly — this skill
removes that: it locates the dispatchable plan run, shows what will apply, and
dispatches it **as the operator**, with the second-person gate still enforced
server-side. It is a convenience for the eligible dispatcher, **not** a bypass
of any gate.

**Scope.** This is the normal PR-driven apply (`terraform-apply.yml`). It is
**not** the drift *revert* apply (that's `terraform-remediate-drift.yml`, with
its own `reason` + acknowledger gate — driven via `/tf-drift`). If the operator
wants to revert out-of-band drift, send them to `/tf-drift`.

## Preamble — read `.claude/eng-workflow.json`

- If missing, stop and tell the user to run `/eng-init`.
- Read, with defaults:
  - `guards.tfDrift.applyWorkflow` (default `terraform-apply.yml`)
  - `repo.name`, `repo.defaultBranch` (default `main`)
- Use these below instead of hardcoding. If `gh` is not installed /
  authenticated, stop and tell the user to run `gh auth login`.

## Step 1 — Find the dispatchable plan run (no run id to copy)

The apply guard requires the saved plan to have been produced at the commit
`$DEFAULT_BRANCH` points at **now** — so the only dispatchable plan run is the
push-triggered `$APPLY_WORKFLOW` run whose `headSha` == current HEAD. Find it:

```bash
MAIN_SHA=$(gh api "repos/paywhereb/$REPO_NAME/branches/$DEFAULT_BRANCH" --jq '.commit.sha')

RUN_ID=$(gh run list --workflow "$APPLY_WORKFLOW" -R paywhereb/$REPO_NAME \
  --event push --limit 20 \
  --json databaseId,headSha,conclusion,createdAt,url \
  | jq -r --arg s "$MAIN_SHA" \
      'map(select(.headSha==$s and .conclusion=="success")) | first | .databaseId // empty')
```

If the user pasted a run id or run URL, use that instead of the lookup.

Then read that run's **unexpired** `tfplan-*` artifacts — these are the
workspaces that actually have pending changes:

```bash
gh api "repos/paywhereb/$REPO_NAME/actions/runs/$RUN_ID/artifacts" --paginate \
  --jq '.artifacts[] | select(.expired|not) | .name | select(startswith("tfplan-")) | sub("^tfplan-";"")'
```

Branch on what you find:

- **A run id with ≥1 unexpired `tfplan-*`** → proceed to Step 2.
- **No matching push run, or the run has no `tfplan-*`** → nothing is pending;
  tell the operator there is nothing to apply (main is already applied) and
  stop.
- **The run exists but its `tfplan-*` artifacts are expired** (merge older than
  the retention window) → don't dispatch a stale/absent plan. Tell the operator
  to regenerate it: open that push run in Actions → **Re-run** → the `plan`
  job (same run id, fresh artifacts), then re-run `/tf-apply`. (Runbook § 3.)

## Step 2 — Show what will be applied

The operator must see the plan before it runs. Read the run summary and/or the
per-workspace `plan.txt` bundled in each artifact:

```bash
gh run view "$RUN_ID" -R paywhereb/$REPO_NAME                       # rendered plans in the summary
# or, for a specific workspace's full text:
gh run download "$RUN_ID" -R paywhereb/$REPO_NAME -n "tfplan-<ws>" -D /tmp/tf-apply/<ws>
```

Summarize per workspace in plain English: what will be created / changed /
destroyed. **Flag destructive actions loudly** — replacements (`-/+`),
deletes, IAM/security-group/bucket-policy/KMS changes, anything touching a
tenant or log-archive workspace — and pause for explicit acknowledgement on
those. If the operator only wants a subset, note it (you'll pass a
`workspaces=` filter in Step 4).

## Step 3 — Verify the operator is an eligible dispatcher (the gate)

The apply guard rejects the dispatch if the dispatcher authored the merged PR.
Check it **before** dispatching so the operator isn't surprised by a red run:

```bash
ME=$(gh api user --jq '.login')
PR_JSON=$(gh api "repos/paywhereb/$REPO_NAME/commits/$MAIN_SHA/pulls" \
  --jq '[.[] | select(.merged_at != null)][0]')
PR_AUTHOR=$(jq -r '.user.login // empty' <<<"$PR_JSON")
PR_NUMBER=$(jq -r '.number // empty' <<<"$PR_JSON")
```

- **`ME` ≠ `PR_AUTHOR`** → the operator is a valid second person. Continue.
- **`ME` == `PR_AUTHOR`** → the operator authored PR #`$PR_NUMBER` and
  **cannot self-apply**. Stop and explain: another engineer runs `/tf-apply`
  (or dispatches the apply) to be the second person. Do **not** work around
  this. Only mention break-glass (Step 4) if they explicitly raise a genuine
  emergency — it is admin-only and leaves a CC8.1 evidence block.

Never fabricate or impersonate a second identity; the dispatcher is always the
real `gh` user running this skill.

## Step 4 — Dispatch the apply (with explicit confirmation)

Confirm with the operator ("apply `<workspaces>` from run `$RUN_ID`?"), then
dispatch. This is the operator acting as the eligible dispatcher — legitimate,
with the guard still enforcing non-authorship + freshness server-side:

```bash
gh workflow run "$APPLY_WORKFLOW" -R paywhereb/$REPO_NAME -f plan_run_id="$RUN_ID"
# subset only:
# gh workflow run "$APPLY_WORKFLOW" -R paywhereb/$REPO_NAME -f plan_run_id="$RUN_ID" -f workspaces="ws-a ws-b"
```

**Break-glass (rare, admin-only).** Only if the operator authored the PR, is a
repo admin, and states a real emergency with no second person reachable — and
only on their explicit instruction — dispatch with `-f break_glass=true -f
justification="…"`. The justification is mandatory and lands in the run's CC8.1
evidence block. Never suggest this as a convenience.

## Step 5 — Read the dispatched run and report (no run id to copy)

The operator never copies a number. Give the dispatch a couple of seconds, find
the run from the API, watch it, and report:

```bash
APPLY_RUN=$(gh run list --workflow "$APPLY_WORKFLOW" -R paywhereb/$REPO_NAME \
  --event workflow_dispatch --limit 1 --json databaseId,status,url \
  --jq '.[0].databaseId')
gh run watch "$APPLY_RUN" -R paywhereb/$REPO_NAME
gh run view "$APPLY_RUN" -R paywhereb/$REPO_NAME
```

`gh run view` shows job conclusions and annotations **only**. Terraform's
operator-facing output — `Warning:` blocks and `local-exec` provisioner
banners, which is how our modules tell the applier about required manual
follow-ups (e.g. the ci-dev ECS workspaces' "task definition changed → the
service will NOT pick this up automatically → run `aws ecs update-service …`")
— exists **only in the job logs**. Scraping them is a mandatory part of this
step, not an optional extra:

```bash
mkdir -p /tmp/tf-apply
gh run view "$APPLY_RUN" -R paywhereb/$REPO_NAME --json jobs \
  --jq '.jobs[] | select(.name|startswith("apply")) | "\(.databaseId)\t\(.name)"' \
| while IFS=$'\t' read -r JOB_ID JOB_NAME; do
    LOG="/tmp/tf-apply/job-$JOB_ID.log"
    gh run view --job "$JOB_ID" -R paywhereb/$REPO_NAME --log > "$LOG"
    echo "===== $JOB_NAME ====="
    grep -E 'Apply complete!|Destroy complete!' "$LOG"
    # Module-authored operator banners (local-exec provisioner output).
    grep '(local-exec):' "$LOG" | grep -v 'Executing:' | sed 's/^.*(local-exec): \{0,1\}//'
    # Terraform warnings.
    grep -A8 'Warning:' "$LOG"
  done
```

- **Success** → per workspace, report the `Apply complete! Resources: X added,
  Y changed, Z destroyed` line, then **relay every warning and local-exec
  banner verbatim** and turn each into an explicit, numbered "manual follow-up
  required" item. The apply is not done until those are relayed — a green run
  with an unread banner is exactly how required follow-ups get lost. (The
  workflow also comments the outcome on the merged PR and records
  `refs/applied/<ws>`.) If this apply came from a `/tf-drift` unapplied-merge
  hand-off, offer to re-run the drift sweep (`gh workflow run
  terraform-drift.yml`) to confirm the workspace is clean.
- **Report only what the logs state — never infer side effects.** A replaced
  `aws_ecs_task_definition` does **not** mean the service deployed: the ci-dev
  ECS workspaces set `lifecycle { ignore_changes = [task_definition] }`, and
  their banner names the exact `aws ecs update-service` command (or TeamCity
  Deploy build re-trigger) still required. If the log doesn't show it
  happening, do not claim it happened.
- **Guard failure** ("second-person gate" / "stale plan") → relay the guard's
  message plainly and the fix: a different person dispatches, or re-run the
  plan job if main moved (Step 1's expired/stale branch). Do not retry blindly.
- **Apply failure** → surface the error from the run; a failed leg applied
  nothing for that workspace. Re-plan / re-review before retrying (runbook § 3).

## Important

- **Green ≠ done.** Job conclusions and annotations don't carry terraform's
  warnings or `local-exec` banners; only the job logs do. Step 5's log scrape
  is mandatory before declaring success, and every banner must reach the
  operator verbatim with its follow-up called out.
- **You are a convenience, not a gate bypass.** The second-person check
  (dispatcher ≠ PR author), freshness, and plan fidelity are all enforced by
  the workflow's guard server-side. You only remove the run-id hunt and typing.
- **Never dispatch on behalf of a mismatched identity.** The dispatcher is the
  real `gh` user. If they're the PR author, stop (Step 3) — don't reach for
  break-glass unless they explicitly declare an emergency and are an admin.
- **Never widen credentials** or edit the workflow / runner roles to make an
  apply "work". A gate failure is the gate working.
- **No Claude attribution** anywhere.
- **This is not the revert path.** Reverting out-of-band drift is
  `/tf-drift` → `terraform-remediate-drift.yml`, which has different
  (acknowledger + reason) semantics. Don't apply a revert from here.
- **Stop on ambiguity** — multiple candidate runs, an unclear plan, a
  destructive action, or a tenant/log-archive workspace: surface it and ask.
