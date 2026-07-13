---
name: tf-drift
description: Explain and remediate Terraform drift in plain English. Use when the nightly drift sweep alerts in Slack #aws-alerts, when someone asks "what drifted / what changed in the estate / is this drift safe / how do I revert this drift", or references the terraform-drift workflow. Reads the latest drift run, interprets each workspace, distinguishes an unapplied merge (apply it) from an out-of-band change (revert it), attributes the change via CloudTrail, and drives the gated revert or drafts a codify PR — without ever bypassing the human approval gate.
version: 0.2.0
allowed-tools: Read, Bash, WebFetch
---

Interpret the latest Terraform **drift sweep** for a no-CLI, low-Terraform
operator and guide remediation. The durable approval + audit gate stays in
GitHub — this skill makes drift *legible* (plain-English interpretation +
CloudTrail attribution) and *easy to act on* (routes to the one-click apply,
drives the one-click revert workflow, or drafts a codify PR), but **never
approves or applies anything itself**.

## Preamble — read `.claude/eng-workflow.json`

Before the steps below, load `.claude/eng-workflow.json`:

- If missing, stop and tell the user to run `/eng-init`.
- If `guards.tfDrift.enabled === false` (or the block is absent), stop with:
  *"`tf-drift` is disabled for this repo (set `guards.tfDrift.enabled: true`
  in `.claude/eng-workflow.json` to enable)."* — do nothing else.
- Read, with defaults:
  - `guards.tfDrift.driftWorkflow` (default `terraform-drift.yml`)
  - `guards.tfDrift.remediateWorkflow` (default `terraform-remediate-drift.yml`)
  - `guards.tfDrift.applyWorkflow` (default `terraform-apply.yml`) — the
    post-merge apply the **unapplied-merge** case routes to.
  - `repo.name`, `repo.defaultBranch` (default `main`), `linear.team`
- Use these everywhere below instead of hardcoding. If `gh` is not
  installed / authenticated, stop and tell the user to run `gh auth login`.

If the repo ships `docs/terraform-cicd-runbook.md`, its **§ 6 (Drift
triage)** is the authoritative description of the gate and evidence
semantics — read it if you need the full context. Also read any
`.claude/memory/` entries about known non-drift exceptions (see Important).

## Step 1 — Find the latest drift run and pull its outputs

```bash
gh run list --workflow "$DRIFT_WORKFLOW" -R paywhereb/$REPO_NAME \
  --limit 5 --json databaseId,conclusion,createdAt,event,url
```

Pick the most recent completed run (usually the one the Slack alert links
to; if the user pasted a run URL, use that run id instead). Read its summary
and download the per-workspace plan artifacts:

```bash
gh run view <run-id> -R paywhereb/$REPO_NAME            # aggregate summary
gh run download <run-id> -R paywhereb/$REPO_NAME -p 'drift-*' -D /tmp/tf-drift
```

Each `drift-<ws>/` has:

- `exitcode` — `0` clean / `2` drifted / other = plan error. Only `2` and
  error workspaces need triage. If everything is clean, say so and stop.
- `plan.txt` — the full plan.
- `pending_apply` — `true` if the sweep decided this is an **unapplied
  merge** (merged code not yet applied) rather than an out-of-band change.
- `last_applied` — the commit SHA this workspace was last applied at (or
  `unknown` if it has no `refs/applied/<ws>` marker yet).

`pending_apply` / `last_applied` come from the sweep's classify step; treat
them as the authoritative signal for the apply-vs-revert fork below, and
confirm them against the plan text.

## Step 2 — Interpret each drift in plain English (the core value)

For every drifted/errored workspace, read `plan.txt` and explain to the
operator **in plain language**, not Terraform jargon:

- **What resource(s) changed** and how (e.g. "a security-group rule opening
  port 22 to the world was added outside Terraform", not `~ ingress { ... }`).
- **Unapplied merge vs. out-of-band change — decide this first.** Read
  `pending_apply`:
  - **`pending_apply=true` → unapplied merge.** Code was merged to
    `$DEFAULT_BRANCH` but its apply was never dispatched, so reality is behind
    code. The fix is to **APPLY it** (Step 5), *not* revert — reverting would
    try to destroy legitimately-merged infrastructure. A plan that is all
    `+ create` for a coherent new module is the classic shape here (something
    was *added in code*, not deleted by hand). Confirm by looking: does the
    plan match a recent merged PR touching this workspace? (`last_applied`
    tells you the commit it's behind.)
  - **`pending_apply=false` → treat as out-of-band drift.** Someone changed
    reality outside Terraform. Now the plan direction tells you what `apply`
    would do to reconcile: a `~`/`-` is Terraform *undoing* an out-of-band
    edit; a `+` is Terraform *recreating* something someone deleted by hand.
    Fix = **revert** (Step 7) or **codify** (Step 6).
  - **No marker (`last_applied=unknown`).** The sweep can't tell, so it
    reported plain drift. Don't assume — fall back to reading the plan +
    attribution (Step 3) and **ask** if it's genuinely ambiguous.
- **Flag anything destructive or risky** loudly — resource *replacement*
  (`-/+`), deletes, IAM/security-group/bucket-policy/KMS changes, anything
  touching a tenant or log-archive workspace. Do not gloss over these.

For a **plan error** (not drift), say so: it's usually broken credentials
(spoke trust edited?), a provider/API change, or a half-applied workspace —
pipeline breakage to fix forward, **not** something to revert or apply. Do
not run the revert or apply workflow for an errored workspace.

## Step 3 — Attribute the change (read-only CloudTrail)

Answer *who* made the change so the operator can decide intent.

- **Unapplied merge (`pending_apply=true`):** attribution is **git, not
  CloudTrail** — no out-of-band actor exists, and the resources may not exist
  yet (an all-`+` plan). Name the merged PR / commit instead:

  ```bash
  gh api repos/paywhereb/$REPO_NAME/commits/<last_applied>..HEAD  # or:
  git -C <repo> log --oneline <last_applied>..HEAD -- terraform/<ws>/
  ```

  Report which PR introduced the not-yet-applied change. Do **not** go
  hunting CloudTrail for a console actor here.
- **Out-of-band drift:** determine the owning AWS account + region for the
  workspace (from its provider config / `allowed_account_ids`, or the
  runbook), then look up recent events on the drifted resource with
  **read-only** CloudTrail, using the operator's own credentials:

  ```bash
  aws cloudtrail lookup-events \
    --lookup-attributes AttributeKey=ResourceName,AttributeValue=<resource-id> \
    --region <region> --max-results 20 \
    --query 'Events[].{Time:EventTime,User:Username,Event:EventName}' --output table
  ```

  Console/CLI/SSO principals **stand out** because every pipeline apply is a
  `paywhere-tf-runner-spoke` session — a human name or an `assumed-role/AWS…`
  console session is the out-of-band actor. Report who + when. If CloudTrail
  access isn't available from the operator's session, say so and continue with
  the interpretation alone (don't guess an author).

## Step 4 — Recommend and present

Summarize per workspace: what changed, who did it (PR for an unapplied merge;
CloudTrail actor for out-of-band), destructive? and a clear recommendation —
one of three:

- **Apply** — unapplied merge; roll the merged code forward (Step 5).
- **Revert** — out-of-band edit; undo it (Step 7).
- **Codify** — out-of-band change that should stay; write it into code (Step 6).

Present it and let the operator choose. **Stop and ask on any ambiguity**
rather than guessing which way to go.

## Step 5 — On APPLY: hand off to `/tf-apply`

If the workspace is an **unapplied merge**, it goes through the normal
post-merge apply gate (`$APPLY_WORKFLOW`), not the revert workflow. Do **not**
dispatch it yourself from here — route the operator to the **`/tf-apply`**
skill, which finds the right `plan_run_id` automatically, shows the plan, and
drives the second-person dispatch (dispatcher ≠ the merged-PR author).

Tell them: *"`<ws>` is a merged change that was never applied — run `/tf-apply`
to review the plan and apply it (a person who did not author the PR must
dispatch)."* If `/tf-apply` isn't available, the manual path is Actions →
**$APPLY_WORKFLOW** → Run workflow with the merged PR's push-run `plan_run_id`
(runbook § 2/5). Never revert an unapplied merge.

## Step 6 — On CODIFY: draft the normal PR

If the operator wants to keep an out-of-band change, it goes through the
**standard reviewed path**, not the revert workflow: create a branch off
`$DEFAULT_BRANCH`, edit the workspace `.tf` so code matches the current
(now-intended) reality, and open a normal PR (follow the repo's
`/start` → `/create` eng-workflow conventions, `linear.team` = `$LINEAR_TEAM`).
That PR runs `terraform-plan.yml` and merges through the usual second-person
apply gate. Do not add any Claude attribution to the branch, commits, or PR.

## Step 7 — On REVERT: drive the gated remediate workflow (PLAN only)

The revert path is the two-phase `$REMEDIATE_WORKFLOW`. **You drive the PLAN
phase; a human drives the APPLY phase.** Never dispatch the apply — that
would be self-approving past the second-person gate.

1. With the operator's confirmation, dispatch the **PLAN phase** (workspace
   only, no `plan_run_id`):

   ```bash
   gh workflow run "$REMEDIATE_WORKFLOW" -R paywhereb/$REPO_NAME \
     -f workspace=<ws>
   ```

2. **Read the resulting run id from the API** (the operator never copies a
   number). Give the dispatch a couple of seconds, then:

   ```bash
   gh run list --workflow "$REMEDIATE_WORKFLOW" -R paywhereb/$REPO_NAME \
     --event workflow_dispatch --limit 1 --json databaseId,status,url
   ```

   Watch it to completion (`gh run watch <id>`), then read its summary
   (`gh run view <id>`) and show the operator the produced revert plan and
   confirm it matches what you interpreted in Step 2. If the PLAN phase
   reports "no drift", stop — state already matches code.

3. **Hand off to the gated apply.** Tell the operator (and, if relevant, the
   named second reviewer) to run the exact **APPLY-phase** command printed in
   that run's summary — it needs `plan_run_id`, a `reason`, and either a repo
   admin dispatcher or a named `acknowledger` (≠ dispatcher). Explain that
   this second person, the reason, and the CC8.1 evidence block are the
   audit gate. **You do not run the apply command yourself.**

4. After the human applies, offer to re-dispatch `$DRIFT_WORKFLOW` to confirm
   the workspace is clean again.

## Important

- **Never bypass the second-person / CC8.1 evidence chain.** You interpret,
  attribute, and drive the PLAN phase — the APPLY dispatch is always a human,
  never you. You are not the system-of-record; GitHub is.
- **Never revert an unapplied merge.** When `pending_apply=true`, the fix is
  to apply the merged code (Step 5 / `/tf-apply`), never the revert workflow —
  a revert there tries to destroy legitimately-merged infrastructure. This is
  the exact confusion the classify signal exists to prevent.
- **Never widen credentials** or suggest doing so. Use the operator's
  read-only session for CloudTrail; never propose editing spoke trust, role
  policies, or the runner tiers to make attribution/remediation "easier".
- **No Claude attribution** on any branch, commit, or PR (`Co-Authored-By`
  or otherwise).
- **Stop on ambiguity** — a wrong revert can delete a legitimate resource; a
  wrong codify can freeze an accidental change into code; a wrong apply rolls
  out infra out of sequence. When unsure which way a drift should go, or which
  account/resource it maps to, ask.
- **Plan errors are not drift.** Do not run the revert or apply workflow
  against an errored workspace — treat it as pipeline breakage to fix forward.
- **Honor known non-drift exceptions.** Some "drift" is expected by design
  and must not be reverted or codified away — check `.claude/memory/` for
  entries like `project_qbo_mcp_alerts_off_exception.md` (Dependabot
  vulnerability alerts deliberately pinned off) before recommending action
  on a matching workspace.
- **Tenant + log-archive workspaces are extra-sensitive.** Never recommend a
  revert that would touch a tenant account's IAM/network/bucket policy, or
  anything that could delete audit evidence under log-archive Object Lock —
  surface it to a human instead.
