# Skill conventions

The normative source is `docs/specs/2026-10-26-skill-conventions-design.md`
(§3.2 and §3.4). This file is the readable copy. If the two disagree,
the spec wins.

## SKILL.md contract

Frontmatter (agentskills spec plus Claude Code fields that both tolerate):

```yaml
---
name: publish-web                 # must equal directory name
description: >                    # ≤1024 chars; what + when; en then zh keywords
  Deploy a Next.js, Vite, or static web app to Vercel or Cloudflare Pages
  with a custom domain and PWA install support. Use when the creator says
  publish, deploy, go live, put it online, PWA, custom domain,
  发布网站, 部署, 上线, 网页版.
license: MIT
metadata:
  stage: publish                  # publish | acquire | monetize | core
  platform: web                   # web | ios | android | all
  version: "0.1.0"
  verified: "unverified"          # template default; a level-4 run replaces it with the date
  verified_version: ""            # the version that level-4 run exercised
  zh: SKILL.zh.md
---
```

Body, fixed section order. Lint enforces the headings exactly:

| # | Heading | Content |
|---|---|---|
| 0 | (first line) | `中文版：先读 SKILL.zh.md。` plus one sentence: if the creator writes in Chinese, read `SKILL.zh.md` and follow it instead. |
| 1 | `## When to use` | Trigger situations and two "not this skill, use X" lines. |
| 2 | `## What you must provide` | Human-only prerequisites: accounts, money, legal documents, decisions. Each with why and how long it takes. Ask once; record in `state.md`. |
| 3 | `## Before you start` | Read `.app-creators/state.md`; which fields must exist; run `app-creators` if the file is missing. Readiness gate: `fail` stops the skill; `unknown` or stale lets it proceed with its own minimal checks and says so. Bootstrap exemptions: `app-creators` creates state and reads nothing; `publish-readiness` never requires readiness. |
| 4 | `## Steps` | Numbered. Each step: goal, default tool, alternative tool in one line, exact command or UI path, expected result. No step longer than one screen; detail goes to `references/`. A step that creates, submits, or spends on an external system is marked **effective**: before acting it checks that system for an existing result and reuses it, and right after acting it records the outcome in state, so a rerun never publishes or pays twice. |
| 5 | `## Verify` | Observable checks the agent runs before saying done. Script in `scripts/` where possible. |
| 6 | `## Troubleshooting` | Table: symptom, cause, fix. Only failures seen in a verified run or documented by the vendor. |
| 7 | `## Update state` | Exact `state.md` fields this skill sets. |
| 8 | `## Sources` | Primary vendor docs with the date each was checked. |

Rules:

- Under 300 lines. The spec limit is 500; the margin is for `zh`
  parity and compaction budgets (Claude Code keeps 5k tokens per skill
  after compaction).
- Addressed to the agent, imperative. The human appears only in
  section 2 and in explicit "ask the creator" lines.
- One default tool per step, named in the step. One alternative,
  named in one line. Comparisons are website content, not skill
  content.
- Never write secrets to `state.md` or any file in the repo. Reference
  env var names only.
- Scripts are bash or Python with no third-party dependencies beyond
  what the step already installs. Python runs with `-I`.
- `references/` files are one topic each, named by topic
  (`vercel.md`, `pwa-checklist.md`). One level deep.
- `references/verified-runs.md` exists in every skill, possibly with
  only the header row.

## SKILL.zh.md headings

Headings in `SKILL.zh.md` are Chinese; lint maps them 1:1 to the
English order:

| SKILL.md | SKILL.zh.md |
|---|---|
| `## When to use` | `## 何时使用` |
| `## What you must provide` | `## 你需要准备` |
| `## Before you start` | `## 开始之前` |
| `## Steps` | `## 步骤` |
| `## Verify` | `## 验证` |
| `## Troubleshooting` | `## 排查` |
| `## Update state` | `## 更新状态` |
| `## Sources` | `## 来源` |

## Verification ladder

| Level | Name | What runs | Who | Required for |
|---|---|---|---|---|
| 1 | Lint | `scripts/lint-skills.sh`: frontmatter fields and constraints, name equals directory, heading order, line count, zh pair and heading parity, `verified-runs.md` present, no URLs outside `## Sources` and tool docs, no secret-looking strings | CI on every push | merge |
| 2 | Eval | `claude plugin eval` cases under `evals/<skill>/`: a fixture prompt plus a grader checklist (asked only for human prerequisites, read `state.md`, named the default tool, ran the verify script). Verify `claude plugin eval` availability at scaffold; fall back to a transcript review checklist in `docs/EVAL.md` if absent | doer before handoff, CI nightly | merge of a new or changed skill |
| 3 | Fixture run | The skill executed by an agent against the fixture app for every step that needs no paid account. For `publish-web` that is the whole skill on a free Vercel account | doer | `metadata.verified` may stay `unverified` |
| 4 | Human run | A maintainer runs the skill on a real app with real accounts, records date, framework, outcome, and surprises in `references/verified-runs.md`, sets `metadata.verified` | maintainer | `metadata.verified` date; README may call the skill verified |

Credential boundary: an agent-run level (2 or 3) uses accounts that
exist only for fixtures, with the narrowest token the provider offers,
never a maintainer's personal or production accounts. Level 4 is the only
level that touches real accounts, and a human holds the session.
