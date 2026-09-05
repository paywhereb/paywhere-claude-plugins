---
name: feedback-skills-stay-real-no-demo-steering
description: Plugin skills must read as real product behaviour; never reference the intent/sentiment capture params, answer keys, FI screens or demo beats. Demo steering lives in the Cowork project prompt (demo/cowork-project-prompt.md), which is also the eval system prompt.
metadata:
  type: feedback
---

Skills in `paywhere-smb` must look like genuine small-business finance workflows. They must NOT
mention the `intent` / `sentiment` capture parameters, intent categories (`financing_debt` …),
the FI admin screens, answer keys, "demo beats", or any other hint that behaviour is staged.
The only demo-shaped constraints allowed inside skills are the product constraints we actually
ship with: draft emails, never send; narrate QuickBooks writes instead of performing them;
propose payments and hand over the `/confirm` link; unattended runs stamp `sessionType`.
`demo-setup` and `demo-inject` are presenter tools and may talk about the demo.

**Why:** Brett (2026-09-02): "Don't make the skills obviously drive demo-only/canned behaviour.
They should look generally real." A bank evaluating the connector reads the skills.

**How to apply:** anything that steers a demo (persona context, what to emphasise, how to phrase
the intent field, which questions to lead with) goes into `demo/cowork-project-prompt.md`,
pasted into the Cowork project's instructions and loaded by the scenario eval as its system
prompt preamble. Grep `paywhere-smb/skills` for `intent`, `financing_debt`, `answerKey`,
`answer key`, `FI seat`, `Intents` before every release. See [[project-nicks-hvac-skills]].
