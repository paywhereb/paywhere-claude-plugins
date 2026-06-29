---
name: safe-deps
description: Curated dependency refresh. Classifies every outdated npm package each run, bundles the safe ones into a single rolled-up PR, and reports the risky ones with grouped recommendations. No persisted skip-list — every decision is recomputed from the current lockfile and registry data.
---

Run a curated dependency refresh on this repo. The skill assesses **all** outdated packages from scratch, bundles the safe ones into a single PR, and produces a structured report on the risky ones for human triage.

There is intentionally **no persisted skip-list**. Every classification is derived from the current lockfile and registry data at run time, so the skill stays correct as the project evolves without anyone curating the list.

## Preamble — read `.claude/eng-workflow.json`

Load `.claude/eng-workflow.json` before doing anything else:

- If missing, stop and tell the user to run `/eng-init`.
- If `guards.safeDeps.enabled === false`, stop with the message:
  *"`safe-deps` is disabled for this repo (set
  `guards.safeDeps.enabled: true` in `.claude/eng-workflow.json` to
  enable)."* — do nothing else.
- Use the following keys throughout this skill:
  - `linear.team`, `linear.teamId` — team identity for ticket creation.
  - `linear.defaultLabels` — flatten across all groups (`type`,
    `component`, `category`) and pass every UUID as the `labels` array.
  - `linear.reviewState` — state to move the ticket to after the PR is up.
  - `repo.defaultBranch` — branch to base the safe-deps branch on.
  - `repo.name` — used in the Linear ticket title to disambiguate the
    refresh across repos sharing the same team.
  - `guards.safeDeps.mirrorPins` — drives Step 4.3.
  - `extraGuardsSkill` — invoked by the per-repo guard hook near the end of Step 4 if present.

## Prerequisites

1. Working tree must be clean. If `git status --porcelain` is non-empty, stop and tell the user.
2. Must be on `repo.defaultBranch` with latest pulled. Run the `pull-latest` skill if needed.
3. `gh` CLI authenticated and the Linear MCP tools available (the skill opens a PR and a Linear ticket).
4. **Port 5000 must be free** if the repo's test suite spins up a server on it. Stop any running dev server before proceeding, or ask the user to.
5. **`mvn` installed** if the settings DSL file from `guards.tcReconcile.settingsPath` is in scope (i.e., a bumped package has a TeamCity mirror pin pointing at it). Without it, the DSL revalidation step in 4.3 can't run; note this to the user rather than skipping silently.

## Step 1 — Enumerate

Run `npm outdated --json`. Empty output means everything is current; report that and stop.

For each package in the output, capture: `current`, `wanted`, `latest`, `type` (dependencies / devDependencies / optionalDependencies).

Also read `package.json`'s `overrides` block — any package name appearing there is **SKIP** (don't fight the pins).

Finally, capture a **security baseline**: run `npm audit --json` on the clean default branch and keep it. This is the "before" picture the Step 4 security remediation pass and the Step 7 pressing assessment compare against. `npm outdated` and `npm audit` are *different lenses* — outdated sees only direct, declared deps vs. `latest`; audit sees the whole resolved tree (transitive included) vs. known advisories. A package can be fully up to date by the outdated lens while still harbouring a fixable transitive CVE, which is exactly why the remediation pass in Step 4 exists.

## Step 2 — Classify

For every package, compute the semver delta from `current` → `latest` and assign one bucket:

| Condition | Bucket |
|-----------|--------|
| Package name appears in `package.json` `overrides` | **SKIP** |
| Major bump (`X.y.z` → `X'.y.z`, X' > X, both ≥ 1) | **RISKY** |
| Package is on `0.x` and minor changes (`0.Y.z` → `0.Y'.z`) | **RISKY** *(0.x convention: minor = breaking)* |
| Minor bump on a `≥1.x` package (`x.Y.z` → `x.Y'.z`) | **SAFE** |
| Patch bump (`x.y.Z` → `x.y.Z'`) | **SAFE** |

`@types/*` packages: classify by their own semver delta, **but** if a `@types/foo` would jump to a major ahead of its source `foo`, force it to RISKY regardless. Types should track the runtime.

## Step 3 — Group RISKY by peer dependencies

For each RISKY package, run `npm view <pkg>@<latest> peerDependencies --json` and collect the peer ranges.

Two RISKY packages belong in the same group when one's target peer range names the other (and the other's `latest` satisfies that range). Walk the graph to transitive closure.

Common pattern this catches: `@vitejs/plugin-react@6` peers `vite@^8`, so a `vite` + `@vitejs/plugin-react` co-bump becomes one group.

Packages with no peer-dep matches stand alone.

## Step 4 — Apply SAFE bucket

If SAFE is empty, skip to Step 6.

1. Create a fresh branch off `repo.defaultBranch`: `safe-deps-YYYY-MM-DD`.
2. For each SAFE package, run `npm install <pkg>@<latest> --save-exact=false` (preserves the existing range prefix from `package.json`).
3. **Sync out-of-lockfile version pins.** Some packages have versions pinned outside `package.json` (CI Docker images, Dockerfiles, AMI scripts, env files). The pins for this repo come from `guards.safeDeps.mirrorPins`. For each SAFE bump:
   - If the package name appears in any `mirrorPins[i].package`, edit every path under `mirrorPins[i].syncedWith` so the version literal there matches the new `latest`. Use a `grep -n` on the file to locate the literal, then a precise `Edit` (do not blanket-replace — only the spots that reference this package's version).
   - If `mirrorPins[i].syncedWith` includes the settings DSL file from `guards.tcReconcile.settingsPath`, validate it after editing with `cd .teamcity && mvn teamcity-configs:generate` (BUILD SUCCESS = DSL still compiles). If `mvn` isn't installed, tell the user and ask them to validate.
   - As a generic safety net (in case the config is out of date), also run `grep -rn "<pkg-name-or-image-tag>:v" --include="*.kts" --include="*.yml" --include="*.yaml" --include="*.sh" --include="Dockerfile*" --include="*.hcl"` for each SAFE bump. If you find references the config didn't predict, surface them to the user and ask whether to add to `guards.safeDeps.mirrorPins`. Don't silently rewrite files the config doesn't authorize.
4. **Security remediation pass (vulnerability-driven).** `npm outdated` only sees *direct, declared* deps compared against `latest`, so it is structurally blind to two classes of fixable vulnerability: (a) **transitive** CVEs that never surface as a top-level outdated entry (e.g. `markdown-it` / `@babel/core` pulled in by a dev tool), and (b) **in-range security patches of a direct dep whose `latest` is a major** — e.g. a `qs` DoS fixed by `express` 4.22.1 → 4.22.2 while `express` itself is bucketed RISKY for its 5.x major, so the safe 4.22.2 patch is never even considered. Close both gaps with `npm audit`, which the outdated-driven buckets never consult:
   - Run `npm audit fix` **without `--force`**. Non-force audit fix is, by construction, limited to in-range, non-SemVer-major changes — exactly this skill's definition of SAFE — so whatever it applies belongs in the SAFE bundle. It edits `package-lock.json` (and may bump a direct dep within its existing range) to pull deps up to their fixed, in-range versions. (Heads up: `npm audit fix --dry-run --package-lock-only` can report *0 changes* even when a real in-range fix exists — that flag combination is over-conservative. Trust a real `npm audit fix` run, or a plain `--dry-run` without `--package-lock-only`.)
   - **Durability for tracked vulns.** `npm audit fix` only nudges the lockfile, so a later re-resolution can regress. When a cleared CVE is tracked externally with a due date (e.g. a Vanta finding), pin the fixed floor in `package.json` `overrides` instead — e.g. `"markdown-it": "^14.2.0"`. Only pin **within the same major** as the resolved version (non-breaking); a fix that needs a major is RISKY, not SAFE. Any name you add to `overrides` here is naturally SKIP for the outdated buckets (Step 2), so there's no double-handling.
   - **Re-audit.** After the pass, `npm audit` should report only residual advisories whose `fixAvailable` is `false` or `{ "isSemVerMajor": true }` — fixes that need a major bump. Do **not** run `npm audit fix --force`. Carry each residual into the Step 6 RISKY report and the Step 7 pressing assessment, tagged with its CVE as the driver.
5. After all bumps applied, pins synced, and the security pass complete, run the **gates in this order**, stopping on first failure:
   - `npm audit --json` — capture and keep the JSON. After the step-4 remediation pass this should be **0 fixable vulnerabilities**: any advisory still listed must be major-gated (`fixAvailable` false or `isSemVerMajor`), with no regression vs. the Step 1 security baseline. The JSON is reused in Step 7.
   - `npm run check` (if it exists in `package.json` scripts) — TypeScript must pass.
   - `npm run generate:api` (if it exists in `package.json` scripts) — codegen must complete without errors. Do **not** diff the output if it's gitignored; downstream gates catch behavior breakage.
   - `npm run build` — production build must complete.
   - `npm test` — test suite must pass.
   - **Note:** the local gate suite does **not** typically run end-to-end browser tests, so any Playwright/image-pin mismatch will only surface in CI. That is why step 3 above exists — fix it pre-emptively, don't wait for the red build.
6. If any gate fails:
   - Bisect: remove the most recently added bump (including a security-pass `overrides` pin), rerun the failing gate.
   - When you find the offender, move it from SAFE → RISKY with a `failure_reason` annotation, then continue with the remaining SAFE bumps.
   - Do **not** force-merge a failing gate.
7. **Per-repo guard hook.** If `extraGuardsSkill` is set in the config and `<extraGuardsSkill>/SKILL.md` exists, invoke that skill now. Treat its exit condition the same as the gates above — failure means bisect or stop. The hook is the place for invariants the plugin can't model generically (e.g. cross-file version constraints the repo cares about beyond simple mirror pins).
8. When all gates pass on the remaining SAFE set, commit `package.json` + `package-lock.json` plus any mirror-pin files from step 3 and any `overrides` edits from the security pass (step 4).

## Step 5 — Linear ticket + PR for the SAFE bundle

1. Create a Linear ticket via the MCP tool:
   - `team`: `linear.team` (and pass `linear.teamId` if the tool accepts it).
   - `title`: `<repo.name>: Safe dependency refresh — YYYY-MM-DD`. The `<repo.name>:` prefix disambiguates this repo from other team work in Linear.
   - `labels`: flatten `linear.defaultLabels` across all groups and pass every UUID.
   - `priority`: 3 (Medium).
   - `description`: table of the bumps applied (package, current → latest, type), plus a short note that risky bumps are listed separately in Step 6's report.
2. Retitle the branch's commit with the `<TICKET-ID>:` prefix from the ticket. **Drop the `<repo.name>:` prefix in the commit title** (it's redundant inside the repo) — keep it as `<TICKET-ID>: Safe dependency refresh — YYYY-MM-DD`.
3. `git push -u origin <branch>`.
4. `gh pr create` with `<TICKET-ID>: Safe dependency refresh — YYYY-MM-DD` as the title (same drop of the `<repo.name>:` prefix). Body should list the bumps and link the ticket. **No Claude attribution.**
5. Move the ticket to `linear.reviewState` by passing it as `state` to `save_issue` (state IDs are per-team — let the MCP resolve by name).

## Step 6 — RISKY report

Emit a markdown report to the user (do **not** write it to a file in the repo — this is conversational output). Structure:

```
## Risky bumps — manual triage required

### Group: <group-name-or-"standalone">
- **<pkg>**: <current> → <latest> (<semver-gap>, 0.x: <yes/no>)
  Peer deps that pulled it into this group: <list, if any>
  Failure reason (if bisected out of SAFE): <reason>
  Recommendation: **do alone** | **do as group** | **no immediate driver — skip this cycle**
```

Recommendation heuristics (no persisted state — derive each time):

- A single major bump with no peer-group → **do alone** (its own ticket and PR when there's appetite).
- Two or more packages in a peer-dep group → **do as group** (one ticket covering the whole group, since they have to land together).
- Major bump where the package's `latest` is < 30 days old (check `npm view <pkg> time.<latest>`) → **skip this cycle, recheck in 30 days** (let the version stabilize).
- Package bisected out of SAFE with a real test/build failure → **do alone, with the failure as the starting investigation**.

## Step 7 — Pressing-to-schedule assessment

Step 6's recommendations are *how* to land each risky bump (alone, as a group, or skip while fresh). This step is the cross-cutting question: **does anything in the risky set have a forcing function that should override the default "defer until stable"?**

Evaluate every risky bump against the signals below and report a single verdict. Default position is "nothing is pressing" — only call something pressing when you can point to a concrete signal.

| Signal | How to check | When it makes a bump pressing |
|---|---|---|
| **Active CVE in current version** | Re-read the `npm audit --json` output captured in Step 4's gate (or rerun if not captured). The step-4 remediation pass has already cleared every *in-range* CVE, so what remains here is **major-gated** — a fix that needs a SemVer-major bump. For extra coverage, spot-check the GitHub Security Advisory page for the package. | A residual advisory whose only fix is this major → schedule now regardless of freshness (the in-range CVEs are already handled, so anything left is genuinely pressing). |
| **EOL / unsupported current version** | Cross-check the current major against the package's published support window. Node.js → [LTS schedule](https://nodejs.org/en/about/previous-releases). Frameworks usually publish support tables (React, Vue, Express, etc.). | Current version has dropped out of active support, or will within the next quarter → schedule before drop-off so security backports keep coming. |
| **Ecosystem peer pressure** | Scope this carefully — don't `npm view` every dep in the lockfile. For each risky package, list the lockfile deps that *currently* peer-name it (you already have this data from Step 3's `npm view <pkg> peerDependencies` runs), then re-check only those deps' latest peer ranges. | A peer now narrowly requires the new major (no longer accepting the current one) → schedule to unblock other bumps. |
| **Live deprecation warnings** | Check recent CI logs and local `npm test` / `npm run build` / `npm run dev` output for noisy deprecation messages from the current version. | The runtime is already shouting and the warning is fixed in the new major → schedule to clear the noise. |
| **Package abandoned upstream** | Look at `npm view <pkg> time.modified`, the GitHub repo's open-issues count, and whether the repo is archived. | No release in 12+ months, archived repo, or unanswered security issues → schedule a migration (often a replacement rather than an upgrade). |

Emit this as conversational output (do **not** write to a file):

```
## Pressing scheduling assessment

| Signal | Hit? | Packages |
|---|---|---|
| Active CVE in current version | No / Yes | <list or "—"> |
| EOL on current version | No / Yes | <list or "—"> |
| Ecosystem peer pressure | No / Yes | <list or "—"> |
| Live deprecation warnings | No / Yes | <list or "—"> |
| Upstream abandoned | No / Yes | <list or "—"> |

**Verdict:** <"Nothing pressing — let the queue ride at its default cadence." | "X packages are pressing, listed below.">

**Lowest-risk pick to schedule now (optional):** <one risky bump that's safe enough to take today — stable for >90 days, peer constraints already satisfied, isolated blast radius. Skip this section if nothing qualifies.>

**Watch list:** <2-4 bullets naming risky packages worth tracking, with the specific signal to watch for and a rough recheck date.>
```

Practical notes:

- Default to "nothing pressing." Most refresh cycles will have a clean audit and no ecosystem pressure — say so plainly rather than manufacturing urgency.
- The lowest-risk pick is **optional** and **at most one**. Two safe-ish picks become a batch; just one is the highest signal-to-noise way to chip away at the queue between full refresh cycles.
- For the watch list, prefer concrete recheck dates ("recheck after 2026-06-12") over vague phrasing ("in a few weeks").

## Step 8 — Wrap up

Tell the user:
- How many bumps landed in the SAFE PR, with the PR URL.
- How many packages are RISKY, broken down by recommendation.
- The Linear ticket URL.
- The pressing-to-schedule verdict from Step 7 (one line — the full table is already in the report).
- If everything was already up to date or all RISKY, say so explicitly — no empty PR.

## Why this design

- **Source of truth is the lockfile + registry.** Each run reclassifies from scratch. A package that was RISKY today (major bump) will silently drop off the report once the major bump is done — no human has to remember to remove it from a list because there is no list.
- **0.x heuristic is a rule, not a list.** It's a property of the version string, so it stays correct as packages graduate to 1.x or new 0.x deps get added.
- **Peer-dep grouping is derived from `npm view`.** Catches the "you can't bump A without bumping B" case at run time, no manual mapping.
- **Bisect-on-failure** keeps the SAFE PR shippable even when one bump regresses. The failing package moves to RISKY with a real failure reason, which is more useful than a blanket "this is major, skip."
- **Security remediation is vulnerability-driven, not freshness-driven (Step 4 pass).** `npm outdated` is blind to transitive CVEs and to in-range patches hidden behind a major bump, so an audit-as-gate-only design lets fixable vulnerabilities sit in a "green" refresh. A non-`--force` `npm audit fix` pass closes both gaps and is provably SAFE — it can only make in-range, non-major changes. What it *can't* fix without a major falls through to the RISKY report with its CVE attached, turning Step 7's "active CVE" signal from a passive flag into an actioned remediation.
- **Recommendations are heuristics**, not policies — the agent suggests, the human decides. The 30-day freshness check is the one bit of "wait for stability" baked in, because brand-new majors regularly land follow-up patches in the first month.
- **Mirror-pin sync (Step 4.3) is config-driven, not hard-coded.** The repo lists its pins in `guards.safeDeps.mirrorPins`. A generic grep still runs as a safety net so a forgotten pin gets flagged for the human rather than slipping into a green PR that breaks in CI.
- **Per-repo guard hook (Step 4.7).** Repo-only invariants live in the host repo's `extraGuardsSkill`, not in this plugin. The plugin stays generic; quirks stay where they belong.
- **Pressing-to-schedule (Step 7) defaults to "nothing pressing."** It only escalates when a concrete signal (CVE, EOL, peer pressure, deprecation, abandonment) is hit. Without that default, the agent will manufacture urgency every cycle and the verdict loses meaning.
