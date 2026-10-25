---
name: __NAME__
description: >
  [What this skill does, in one sentence: the outcome and the tools it uses.]
  Use when the creator says [English trigger words, comma-separated],
  [中文触发词, 用逗号分隔].
license: MIT
metadata:
  stage: __STAGE__
  platform: __PLATFORM__
  version: "0.1.0"
  verified: "unverified"
  verified_version: ""
  zh: SKILL.zh.md
---

中文版：先读 SKILL.zh.md。If the creator writes in Chinese, read SKILL.zh.md and follow it instead.

## When to use

<!-- Trigger situations, one per line, addressed to the agent. -->
<!-- Then exactly two "not this skill" lines: -->
- Not this skill: [situation]. Use `[other-skill]`.
- Not this skill: [situation]. Use `[other-skill]`.

## What you must provide

<!-- Human-only prerequisites: accounts, money, legal documents, decisions. -->
<!-- For each: what it is, why the skill needs it, how long it takes to get. -->
<!-- Ask the creator once; record the answer in `.app-creators/state.md`. -->
<!-- Never ask for or store secrets; name the env var only. -->
- [Prerequisite]: [why]. Takes [time].

## Before you start

<!-- Read `.app-creators/state.md`. If the file is missing, run `app-creators` first. -->
<!-- List the fields that must exist, and the skill that sets each one. -->
<!-- Readiness gate: `fail` stops the skill; `unknown` or stale lets it proceed -->
<!-- with its own minimal checks and says so. -->
<!-- Bootstrap exemptions: `app-creators` creates state and reads nothing; -->
<!-- `publish-readiness` never requires readiness. -->

## Steps

<!-- Numbered. Each step: goal, default tool, alternative tool in one line, -->
<!-- exact command or UI path, expected result. -->
<!-- No step longer than one screen; detail goes to `references/<topic>.md`. -->
<!-- Mark a step that creates, submits, or spends on an external system **effective**: -->
<!-- before acting it checks that system for an existing result and reuses it, and -->
<!-- right after acting it records the outcome in state, so a rerun never publishes or pays twice. -->
1. [Goal]. Default: [tool]. Alternative: [tool].
   Run: `[exact command or UI path]`
   Expect: [result].

## Verify

<!-- Observable checks the agent runs before saying done. -->
<!-- Put the check in `scripts/` where possible and name the command here. -->
- Run `[scripts/check-...]`. Expect: [observable result].

## Troubleshooting

<!-- Only failures seen in a verified run or documented by the vendor. -->

| symptom | cause | fix |
|---|---|---|

## Update state

<!-- The exact `state.md` fields this skill sets, and nothing else. -->
<!-- Write the whole frontmatter back in one write and append one `history` row. -->
- `[field.path]`: [value it sets].

## Sources

<!-- Primary vendor docs only, each with the date it was checked. -->
- [Doc title](https://example.com/), checked [YYYY-MM-DD].
