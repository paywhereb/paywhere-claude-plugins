#!/bin/sh
# SessionStart hook — inject the Paywhere org-wide rules
# (rules/ORG-RULES.md) into sessions opened inside a paywhereb repo.
#
# Fires on startup/clear/compact only, deliberately NOT on resume: a
# resumed session already carries the rules from its original startup,
# and re-injecting them burns context for nothing. clear and compact
# stay in because those events wipe or squash the injected context.
#
# Gating: the plugin is enabled at user scope, so this script runs in
# every project — it must decide for itself whether the rules apply.
#   1. `origin` remote points at the paywhereb GitHub org → inject.
#   2. Fallback: .claude/eng-workflow.json exists         → inject.
#   3. Otherwise (personal / non-Paywhere project)        → exit silently.
set -eu

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# Match the org segment across every remote form in use here: https
# (with or without embedded token), git@github.com:, ssh:// — and
# custom SSH host aliases like git@github-paywhere:paywhereb/… (see
# prune-merged-branches, DEV-71: a github.com-only pattern misses them).
origin="$(git remote get-url origin 2>/dev/null || true)"
case "$origin" in
  *github.com[:/]paywhereb/*) ;;
  git@*:paywhereb/*) ;;
  ssh://git@*/paywhereb/*) ;;
  *) [ -f .claude/eng-workflow.json ] || exit 0 ;;
esac

rules_file="${CLAUDE_PLUGIN_ROOT:-}/rules/ORG-RULES.md"
[ -f "$rules_file" ] || exit 0

context="$(cat "$rules_file")"

if [ ! -f .claude/eng-workflow.json ]; then
  context="$context

---

This paywhereb repo is not onboarded to the Paywhere eng workflow yet
(no \`.claude/eng-workflow.json\`). Proactively offer the user
\`/paywhere-eng-workflow:eng-init\` — it writes \`.claude/eng-workflow.json\`
and the shared \`.claude/settings.json\` so the repo picks up the standard
Linear-ticket-driven workflow and teammates auto-load the plugin."
fi

if command -v jq >/dev/null 2>&1; then
  printf '%s' "$context" |
    jq -Rs '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: .}}'
else
  printf '%s' "$context" | python3 -c '
import json, sys
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": sys.stdin.read()}}))'
fi
