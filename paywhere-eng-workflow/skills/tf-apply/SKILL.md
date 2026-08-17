---
name: tf-apply
description: Walk a human operator through the post-merge Terraform apply (verifying the merged PR carries the review this repo's gate requires, where it has one) without hunting for a run id. Use when the Slack #aws-alerts "Terraform apply pending" / "unapplied merge" message fires, when someone asks "how do I apply this / apply the merged terraform / run the pending apply / apply <workspace>", or when /tf-drift routes an unapplied merge here. Finds the right plan_run_id automatically, shows the plan, verifies the merged PR is reviewed per this repo's gate, and dispatches the apply on the operator's confirmation. Also handles workspaces that plan in CI but apply only locally (e.g. paywhere-devops's terraform/github) — see Step 0.
version: 0.4.0
allowed-tools: Read, Bash
---

Drive the **post-merge Terraform apply** for a no-CLI operator. A merge saves
a reviewed plan artifact; in most repos the PR that produced it required a
**non-author approval to merge at all** — some repos (`repo.environment:
"nonprod"`, see Preamble) deliberately have no such gate and allow
unreviewed self-merge by design. Once that review is on record, **any
operator with permission — the PR's author included — may dispatch the
apply**: `terraform apply` refuses the saved plan outright if anything has
changed since it was reviewed, so the apply step itself is mechanical, not a
second decision point. The friction this skill removes is finding the right
`plan_run_id` from a Slack ping and typing the dispatch correctly — it
locates the dispatchable plan run, shows what will apply, confirms the
review this repo's gate requires is actually on record, and dispatches it
**as the operator**, with whatever gate the repo actually has still enforced
server-side. It is a convenience for the eligible dispatcher, **not** a
bypass of any gate.

**Scope.** This is the normal PR-driven apply (`terraform-apply.yml`), plus
the local-apply procedure for workspaces that have no CI apply path at all
(Step 0). Neither is the drift *revert* apply (that's
`terraform-remediate-drift.yml`, with its own `reason` + acknowledger gate —
driven via `/tf-drift`). A drift revert has no merged PR behind it, so that
acknowledger *is* the first review, not a redundant second one — don't
confuse the two models. If the operator wants to revert out-of-band drift,
send them to `/tf-drift`.

## Preamble — read `.claude/eng-workflow.json`

- If missing, stop and tell the user to run `/eng-init`.
- Read, with defaults:
  - `guards.tfDrift.applyWorkflow` (default `terraform-apply.yml`)
  - `guards.tfDrift.localApplyOnlyWorkspaces` (default `[]`) — workspace
    names under `terraform/` in this repo that plan in CI but have **no**
    CI apply path (e.g. paywhere-devops sets `["github"]` — its `github`
    provider auth doesn't fit the AWS-OIDC pattern `terraform-apply.yml`
    assumes, by deliberate design, not a gap — see
    `docs/terraform-cicd-runbook.md`'s Scope note in that repo). A
    workspace in this list will **never** produce a `tfplan-<ws>` artifact,
    so Step 1's lookup would silently find nothing for it — check this list
    first (Step 0) for any workspace the operator names, before assuming
    Steps 1-4 apply.
  - `repo.name`, `repo.defaultBranch` (default `main`)
  - `repo.environment` (default `"prod"` — treat any missing, empty, or
    unrecognized value as `"prod"`, never as `"nonprod"`. An existing
    config file written before this field existed has no opinion here,
    and the safe reading of silence is "the gate applies." Only an
    explicit `"nonprod"` skips Step 3's review check.)
- Use these below instead of hardcoding. If `gh` is not installed /
  authenticated, stop and tell the user to run `gh auth login`.

## Step 0 — Local-apply-only workspaces (no CI apply path)

Check this **before** Step 1 whenever the operator names a specific
workspace (or a drift alert names one): is it in
`guards.tfDrift.localApplyOnlyWorkspaces`? If not, skip straight to Step 1 —
everything below is specific to this small set of workspaces.

These workspaces plan in CI (drift sweep + PR-time plan comment) but were
deliberately never wired into `terraform-apply.yml` — there is no
`plan_run_id` to find, no guard job, no `workflow_dispatch`. The apply is a
**local** `terraform apply`, run from this machine (Bash). The review-gate
and plan-fidelity principles from Step 3 still apply exactly the same way —
this workspace's PRs merge through the same `main` branch and the same
branch ruleset as everything else in the repo — only the *executor* of the
apply differs (your Bash, not a workflow job).

**0a — Find the plan-of-record, and the PR behind it.**

```bash
# The most recent merged PR touching this workspace:
gh pr list -R paywhereb/$REPO_NAME --search "terraform/$WS in:title,body" --state merged --limit 5 --json number,title,url,mergeCommit
```

Confirm the PR you pick is really the next one pending apply (nothing else
touching `terraform/$WS` should have merged after it — there's no
`refs/applied/` marker for this workspace to check that for you). Then get
its exact plan-of-record — prefer the binary artifact so the apply below can
replay it exactly, the same guarantee AWS workspaces get:

```bash
PR_NUMBER=<the PR above>
PR_HEAD_SHA=$(gh pr view $PR_NUMBER -R paywhereb/$REPO_NAME --json headRefOid --jq '.headRefOid')
RUN_ID=$(gh run list --workflow terraform-plan.yml -R paywhereb/$REPO_NAME \
  --json databaseId,headSha --jq --arg sha "$PR_HEAD_SHA" '[.[] | select(.headSha==$sha)] | first(.[]) | .databaseId')
gh run download "$RUN_ID" -R paywhereb/$REPO_NAME -n "tfplan-github" -D /tmp/tf-apply/"$WS"
```

If `tfplan-github` isn't there (artifact expired — 5-day retention — or this
PR predates the DEV-98 binary-artifact change), fall back to the rendered
text instead, and say plainly that what follows is lower-fidelity:

```bash
gh pr view $PR_NUMBER -R paywhereb/$REPO_NAME --json comments \
  --jq '.comments[] | select(.body | startswith("<!-- terraform-plan -->")) | .body'
```

**0b — Local credentials.** These workspaces' backends and providers don't
use the CI OIDC pattern; check the repo's own `CLAUDE.md` ("Running Terraform
applies" section) for the exact local-execution steps (which AWS SSO
profile the backend needs, and how the non-AWS provider — e.g. a GitHub App
token or `gh auth token` — is supplied). Ask the operator to run any missing
`aws sso login`; don't assume a session is live.

**0c — Apply the exact plan-of-record, when you have the binary.**

```bash
terraform -chdir="terraform/$WS" init -input=false   # backend-config overrides per CLAUDE.md if needed
terraform -chdir="terraform/$WS" apply /tmp/tf-apply/"$WS"/tfplan
```

Terraform refuses this the moment the workspace's state serial has moved
since the plan was taken — the same hard guarantee the AWS path gets, no
manual judgment call needed. **Only when you had to fall back to rendered
text in 0a** (no binary artifact available): re-plan fresh instead —

```bash
terraform -chdir="terraform/$WS" plan -out=/tmp/tf-apply/"$WS"/tfplan
```

— and manually compare its `Plan: N to add, M to change, P to destroy` line
and resource list against the rendered text from 0a. **Say plainly that this
is a manual eyeball comparison, not the exact-replay guarantee 0c's normal
path gets.** If they don't match, stop and explain why; don't apply a
surprise.

**0d — Confirm the PR's review, same check as Step 3.** This workspace's PRs
merge under the same branch ruleset as everything else in the repo
(`soc2-review-paywhere-devops`), so the same rule applies: any operator —
the PR's author included — may apply once it carries a non-author `APPROVED`
review.

```bash
PR_AUTHOR=$(gh pr view $PR_NUMBER -R paywhereb/$REPO_NAME --json author --jq '.author.login')
gh api "repos/paywhereb/$REPO_NAME/pulls/$PR_NUMBER/reviews" --paginate \
  --jq --arg author "$PR_AUTHOR" '[.[] | select(.state=="APPROVED" and .user.login != $author)] | last | .user.login // empty'
```

- **Approval found** → any operator, author included, may apply. Proceed.
- **No approval found** (this PR merged via the branch ruleset's admin
  bypass_actor — a normal PR cannot merge without one) → treat this like
  Step 4's break-glass: only a repo admin proceeds, only with an explicit,
  recorded justification, and it belongs in the same CC8.1 evidence trail
  (Linear ticket + quarterly Vanta change-management evidence task) since
  there's no workflow run to write it into automatically. Don't self-apply
  around a missing approval just because there's no server-side guard here
  to stop you — the absence of a technical gate is not permission to skip
  the control.

**0e — Apply and report.** On explicit confirmation, run 0c's apply command.
Report exactly like Step 5: the `Apply complete! Resources: X added, Y
changed, Z destroyed` line, and **every** `Warning:` block or
`local-exec` banner verbatim, each turned into a numbered manual-follow-up
item. Note in the report that this was a **local apply** (no `refs/applied/`
marker gets recorded — the next drift sweep will show this workspace clean,
which is the only confirmation that exists for this path).

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

## Step 3 — Verify the merged PR carries the review this repo's gate requires

**If `repo.environment` is `"nonprod"`** — this repo's own
`terraform-apply.yml` has no review gate by design (relaxed gate,
compensated for elsewhere — e.g. single-account isolation). Say so plainly
("`$REPO_NAME` is configured as nonprod — self-apply is allowed here, no
review check to run") and go straight to Step 4. Don't run the check below;
it isn't the real gate for this repo and a false read either way just
muddies the report.

**Otherwise (`"prod"`, or the field absent/unrecognized)** — the apply guard
rejects the dispatch if the merged PR lacks a non-author `APPROVED` review.
Check it **before** dispatching so the operator isn't surprised by a red
run. Who is about to dispatch is not the question — a normal PR cannot merge
without this review (this repo's own branch protection enforces it), so the
only way it's missing is an admin merge via the branch ruleset's bypass
path:

```bash
PR_JSON=$(gh api "repos/paywhereb/$REPO_NAME/commits/$MAIN_SHA/pulls" \
  --jq '[.[] | select(.merged_at != null)][0]')
PR_AUTHOR=$(jq -r '.user.login // empty' <<<"$PR_JSON")
PR_NUMBER=$(jq -r '.number // empty' <<<"$PR_JSON")
APPROVER=$(gh api "repos/paywhereb/$REPO_NAME/pulls/$PR_NUMBER/reviews" --paginate \
  --jq --arg author "$PR_AUTHOR" '[.[] | select(.state=="APPROVED" and .user.login != $author)] | last | .user.login // empty')
```

- **`APPROVER` non-empty** → PR #`$PR_NUMBER` has a non-author approval on
  record. Any operator, the PR's author included, may dispatch. Continue —
  no need to check who's actually running this skill.
- **`APPROVER` empty** → no non-author approval found, which on a repo with
  this gate normally means the PR merged through an admin's branch-ruleset
  bypass, not through the standard path. Stop and explain: get it reviewed
  (or re-merged normally), or — genuine emergency only — a repo admin
  dispatches with break-glass (Step 4). Do **not** work around this by
  dispatching anyway.

Never fabricate or impersonate a review; report only what the PR's actual
review history shows.

If you ever suspect `repo.environment` is wrong for this repo (e.g. a `"prod"`
run's dispatch fails with no review-related message, or a `"nonprod"` run's
dispatch fails with one anyway), say so and suggest fixing the config —
`.claude/eng-workflow.json` is a hint for this skill, not the actual gate; the
workflow's own guard job is authoritative regardless of what's configured.

## Step 4 — Dispatch the apply (with explicit confirmation)

Confirm with the operator ("apply `<workspaces>` from run `$RUN_ID`?"), then
dispatch. This is the operator acting as an eligible dispatcher — legitimate,
with the guard still enforcing the review requirement + freshness
server-side:

```bash
gh workflow run "$APPLY_WORKFLOW" -R paywhereb/$REPO_NAME -f plan_run_id="$RUN_ID"
# subset only:
# gh workflow run "$APPLY_WORKFLOW" -R paywhereb/$REPO_NAME -f plan_run_id="$RUN_ID" -f workspaces="ws-a ws-b"
```

**Break-glass (rare, admin-only).** Only if Step 3 found no non-author
approval on record, the operator is a repo admin, and they state a real
emergency with no reviewer available — and
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
- **Guard failure** ("no non-author approval" / "stale plan") → relay the
  guard's message plainly and the fix: get the PR reviewed (or re-merged
  normally) and re-dispatch, or re-run the plan job if main moved (Step 1's
  expired/stale branch). Do not retry blindly.
- **Apply failure** → surface the error from the run; a failed leg applied
  nothing for that workspace. Re-plan / re-review before retrying (runbook § 3).

## Important

- **Green ≠ done.** Job conclusions and annotations don't carry terraform's
  warnings or `local-exec` banners; only the job logs do. Step 5's log scrape
  is mandatory before declaring success, and every banner must reach the
  operator verbatim with its follow-up called out.
- **You are a convenience, not a gate bypass.** Whatever gate the repo
  actually has — the review check (non-author `APPROVED` review on the
  merged PR) in `"prod"` repos, freshness, and plan fidelity — is enforced
  by the workflow's guard server-side. You only remove the run-id hunt and
  typing.
- **Who dispatches is not the gate — review is.** Once a PR carries the
  required non-author approval, any operator with permission may dispatch
  it, the PR's author included: `terraform apply` refuses a plan the moment
  anything's changed since it was reviewed, so the dispatch step adds no
  independent check beyond that review. Don't invent a "different person
  must click apply" requirement that isn't in Step 3 — that was this skill's
  old model and it's gone.
- **`repo.environment` is a hint, not the gate.** It tells you whether to
  *run* the review check client-side so the operator isn't surprised by a red
  run — it does not change what the workflow itself enforces. Default to
  `"prod"` behavior whenever the field is missing or unrecognized.
- **Never fabricate a review.** Report only what the PR's actual review
  history shows. If Step 3 finds no non-author approval in a `"prod"` repo,
  stop — don't reach for break-glass unless the operator explicitly declares
  an emergency and is an admin.
- **Never widen credentials** or edit the workflow / runner roles to make an
  apply "work". A gate failure is the gate working.
- **No Claude attribution** anywhere.
- **This is not the revert path.** Reverting out-of-band drift is
  `/tf-drift` → `terraform-remediate-drift.yml`, which has different
  (acknowledger + reason) semantics — a drift revert has no merged PR behind
  it, so that check is the first review, not a redundant second one. Don't
  apply a revert from here.
- **Local-apply-only workspaces (Step 0) get no free pass.** No server-side
  guard existing is not the same as no gate — still find the plan-of-record
  (prefer the exact binary artifact over a fresh re-plan), still confirm the
  PR's non-author approval (0d), still require admin + justification when
  that approval is missing. Never treat the absence of a `workflow_dispatch`
  path as license to skip a check the CI-gated workspaces enforce for you.
- **Stop on ambiguity** — multiple candidate runs, an unclear plan, a
  destructive action, or a tenant/log-archive workspace: surface it and ask.
