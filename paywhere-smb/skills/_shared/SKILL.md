---
name: conventions
version: 1.0.2
description: >
  (Reference skill) Explains how money moves and how unattended runs behave in
  this plugin: every payment or transfer is staged as a proposal and approved
  on the bank's /confirm page with a passkey; scheduled runs propose and never
  execute; email is drafts only, never sent. Use when the owner asks
  "how do approvals work," "did that payment go through," "why do I need a
  passkey," "what runs while I'm away," "is anything scheduled," or "what
  can the agent do on its own."
---

# Conventions (approval + autonomy)

This directory holds the two conventions every money and agent skill in the
plugin follows. Read the relevant file and answer from it; do not paraphrase
from memory.

- [`APPROVAL.md`](APPROVAL.md) — the propose → `/confirm` → passkey path:
  what the money tools return, how to print the approval step, words to use,
  why transfers go through the batch tool's `transfer` rail.
- [`AUTONOMY.md`](AUTONOMY.md) — scheduled-run rules: `sessionType` /
  `taskId` stamps, output files and dedupe, propose-never-execute, graceful
  degradation, drafts only, the run-output shape.

When the owner asks whether a payment "went through": the honest answer is a
bank check — `query_transactions` (`direction: "debit"`, the date, the
amount) — never the proposal's own status. If the debit is not there, the
proposal has not been approved yet; give them the confirmation URL again if
you have it, or tell them where to find it (the bank's confirm page, the
Cowork run output, or the brief that staged it).
