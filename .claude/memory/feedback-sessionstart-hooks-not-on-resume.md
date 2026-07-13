---
name: feedback-sessionstart-hooks-not-on-resume
description: SessionStart context-injection hooks must not fire on resume — re-injecting burns context; matcher is startup|clear|compact only
metadata:
  type: feedback
---

The eng-workflow SessionStart hook (`paywhere-eng-workflow/hooks/hooks.json`)
uses matcher `startup|clear|compact` and deliberately excludes `resume`.

**Why:** Brett's explicit requirement (2026-07-13). A resumed session
already carries the injected org rules from its original startup, so
firing again on `resume` duplicates ~3 KB of context for nothing —
context burn with zero information gain. `clear` and `compact` stay in
the matcher because those events wipe or squash the previously injected
context, so re-injection is genuinely needed there.

**How to apply:** When adding or editing any SessionStart
context-injection hook in this repo (or reviewing one), keep `resume`
out of the matcher unless the hook is idempotent-by-content and the
injected payload would otherwise be lost on resume (it isn't — resume
preserves conversation context). The same reasoning applies to any
future always-on instruction payloads delivered via
`hookSpecificOutput.additionalContext`.
