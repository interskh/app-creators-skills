# Skill conventions — design

spec-review: completed 2026-10-26

Scope: the rules every skill in this repo follows, the shared state file,
how a skill is proven to work, and one exemplar (`publish-web`) that the
other ~20 skills copy. Thesis: `VISION.md` in the private workroom
repo (`app-creators`); the one-line vision is in this repo's README.
Requirements: `docs/prds/prd-phase1-skills.md`. Roadmap:
`docs/ROADMAP.md` Slice 0.

## 1. Problem & goals

Ralph will write ~50 roadmap items that all say "follows conventions".
Without a fixed template, state schema, and definition of "verified",
each doer guesses and the library drifts before Slice 1 ends.

Goals, with evidence:

- A new skill written by an agent from the template passes lint on the
  first try and reads the same as the exemplar. Evidence: lint green,
  reviewer finds no structural diffs against the exemplar.
- The repo installs as one command in Claude Code and one in Codex.
  Evidence: `claude plugin install app-creators@app-creators` and
  `npx skills add interskh/app-creators-skills` both load `publish-web` in a
  clean session.
- The entry skill writes `state.md` and `publish-web` reads it without
  re-asking. Evidence: fixture run transcript.
- `publish-web` has a verified end-to-end run on a real Vercel account.
  Evidence: a dated entry in its `references/verified-runs.md`.

## 2. Non-goals

- Writing any skill other than the exemplar. Those are roadmap items.
- Per-platform format converters (Cursor, Windsurf, personal agents).
  Roadmap Slice 4; this spec only keeps the source neutral enough.
- Telemetry or install counting. Skills call the network only to
  operate the tools a step names (deploy providers, store consoles,
  vendor CLIs) and never to report back to us.
- Fixture apps beyond the web to-do app. The Expo, Flutter, Xcode, and
  Kotlin to-do apps arrive with the skills that need them.
- The website and how it renders skills.

## 3. Architecture & decisions

### 3.1 Repo is the plugin and the marketplace

This public repo is the plugin root. Everything in it ships to a
creator's machine on install, so it holds only the skills, their
tooling, and the three docs contributors need (roadmap, requirements,
this spec). The thesis, business plans, website, and services live in
the private workroom repo.

```
app-creators-skills/
├── .claude-plugin/
│   ├── plugin.json          # name: app-creators
│   └── marketplace.json     # one entry, source "./"
├── skills/
│   ├── app-creators/        # entry skill
│   ├── publish-web/
│   │   ├── SKILL.md
│   │   ├── SKILL.zh.md
│   │   ├── scripts/
│   │   └── references/
│   └── ...
├── templates/skill/         # copied by `scripts/new-skill.sh`
├── scripts/
│   ├── lint-skills.sh
│   └── new-skill.sh
├── docs/
├── LICENSE                  # MIT
└── README.md
```

Why one plugin, not one per skill: creators install once and get the
pipeline; registry listings stay one line; `/app-creators:publish-web`
namespacing is self-explaining. Rejected: a marketplace of 20 plugins
(install friction, 20 listings to keep current).

Codex reads `.agents/skills/` in a repo or `~/.agents/skills/`. The
agentskills spec defines `<name>/SKILL.md`; the `skills/` parent
directory is the common layout `npx skills add` scans, but its docs do
not state the discovery rule, so Slice A's proof step verifies it. No build step in
Phase 1; "one source compiled to all" starts in Slice 4 when a target
needs a different shape. Rejected: a generator from day one (nothing to
generate yet).

### 3.2 SKILL.md contract

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

### 3.3 Chinese delivery

`SKILL.zh.md` is a sibling file, not a second skill. The English
`SKILL.md` carries Chinese trigger keywords in `description` so the
skill activates for Chinese prompts, and its first line redirects a
Chinese-speaking agent to the zh body. Headings in `SKILL.zh.md` are
Chinese; lint maps them 1:1 to the English order. `metadata.verified`
is shared; the zh file does not get its own verification.

Cost accepted: activation loads the English body first, so a Chinese
session carries both files in context. That is the same cost as a
bilingual body, but keeps each file inside the line budget and lets
lint check parity between two files instead of inside one.

Rejected: `publish-web-zh/` directories (doubles the listing, splits
install counts, two places to update). Rejected: bilingual body in one
file (blows the line budget, no parity check possible).

### 3.4 Verification ladder

| Level | Name | What runs | Who | Required for |
|---|---|---|---|---|
| 1 | Lint | `scripts/lint-skills.sh`: frontmatter fields and constraints, name equals directory, heading order, line count, zh pair and heading parity, `verified-runs.md` present, no URLs outside `## Sources` and tool docs, no secret-looking strings | CI on every push | merge |
| 2 | Eval | `claude plugin eval` cases under `evals/<skill>/`: a fixture prompt plus a grader checklist (asked only for human prerequisites, read `state.md`, named the default tool, ran the verify script). Verify `claude plugin eval` availability at scaffold; fall back to a transcript review checklist in `docs/EVAL.md` if absent | doer before handoff, CI nightly | merge of a new or changed skill |
| 3 | Fixture run | The skill executed by an agent against the fixture app for every step that needs no paid account. For `publish-web` that is the whole skill on a free Vercel account | doer | `metadata.verified` may stay `unverified` |
| 4 | Human run | Kyle runs the skill on a real app with real accounts, records date, framework, outcome, and surprises in `references/verified-runs.md`, sets `metadata.verified` | Kyle | `metadata.verified` date; README may call the skill verified |

A skill with `verified: unverified` still ships. The README lists
verification status per skill so creators and agents can see it.

Verification binds to a revision and a route. A route is one
framework plus one provider or store path through the skill. A
level-4 record names the skill version and the route it exercised;
`metadata.verified` and `verified_version` summarize the latest. Lint
derives per-route status from `references/verified-runs.md`, and the
README shows it per route, so one exercised route never certifies an
unexercised one. When `version` moves past `verified_version`, every
route is "verified at an earlier version", not "verified". Any change
to steps, prerequisites, or verify checks bumps `version`;
wording-only edits do not.

Bilingual parity is behavioral, not only structural. Every level-2
eval case runs twice, once with an English prompt and once with a
Chinese prompt, against the same expected checks. The zh file shares
the English skill's verified status only while both runs pass.

Credential boundary: an agent-run level (2 or 3) uses accounts that
exist only for fixtures, with the narrowest token the provider offers,
never Kyle's personal or production accounts. Level 4 is the only
level that touches real accounts, and a human holds the session.

### 3.5 Fixture

The fixture is a to-do list app, the same app in every framework the
skills support, so every skill and every guide uses one running
example. This spec needs only the web version: a Vite to-do app with
a manifest and service worker. Expo, Flutter, Xcode, and Kotlin
versions arrive with the skills that need them (Roadmap Slice 1).

Fixtures live in a separate public repo `interskh/app-creators-fixtures`,
one directory per framework (`todo-vite/`, `todo-swift/`,
`todo-kotlin/`, `todo-flutter/`, `todo-expo/`), so the
plugin clone stays small. Eval cases reference a fixture by path and
pin a commit.

### 3.6 Entry skill and state

`skills/app-creators/` is the router. It detects framework and which
destinations the project already carries config for, asks the creator
two questions (which outcome: publish, get users, make money; which
destinations they want), writes `state.md`, and names the next skill.
It never performs a pipeline step itself and never claims an external
outcome: on first run every `targets.*.status` is `unknown`. It is the
only skill that may create `state.md` and the only one that migrates
it across a schema major.

Until `publish-readiness` exists (Roadmap Slice 1), every readiness
entry stays `unknown` and the exemplar proceeds under the readiness
gate's `unknown` rule with its own checks.

## 4. Data contracts

### 4.1 `.app-creators/state.md`

Lives in the creator's project. YAML frontmatter is the contract;
markdown below it is free notes. Skills read and update the
frontmatter only. Recommend committing it; it holds no secrets.

```yaml
---
schema: "1.0"                  # major.minor, see evolution rules
updated: 2026-10-26
app:
  name: ""                     # display name
  slug: ""                     # kebab-case
  description: ""              # one sentence, used by store-listing
  languages: [en]              # content locales
framework:
  kind: expo | flutter | xcode | kotlin | nextjs | vite | static | unknown
  package_manager: npm | pnpm | yarn | bun | none
  evidence: ""                 # file that decided it, e.g. app.json
targets:                       # per destination: what the creator wants, what the project shows, what the store says
  web:
    intent: wanted | not-wanted | undecided
    detected: "yes" | "no"       # project carries config for this destination
    status: unknown | none | ready | live
    url: ""
    provider: vercel | cloudflare-pages | ""
    domain: ""
  ios:
    intent: wanted | not-wanted | undecided
    detected: "yes" | "no"
    status: unknown | none | ready | testflight | review | live
    bundle_id: ""
    asc_app_id: ""
  android:
    intent: wanted | not-wanted | undecided
    detected: "yes" | "no"
    status: unknown | none | ready | testing | review | live
    package: ""
readiness:                     # written by publish-readiness; a pass is bound to a revision
  web: { result: pass | fail | unknown, revision: "", date: "" }
  ios: { result: pass | fail | unknown, revision: "", date: "" }
  android: { result: pass | fail | unknown, revision: "", date: "" }
accounts:                      # presence only, never credentials; strings, never YAML booleans
  apple_developer: has | missing | pending
  google_play: has | missing | pending
  vercel: has | missing
tools:                         # chosen defaults, set by the skill that chose them
  deploy: ""
  analytics: ""
  iap: ""
  ads: ""
  payments: ""
  attribution: ""
monetization:
  model: none | paid | freemium | subscription | ads | hybrid
goal: publish | acquire | monetize | ""
history:                       # append-only, newest last
  - { skill: app-creators, version: "0.1.0", date: 2026-10-26, result: ok }
---
```

Rules: unknown is written as the empty string or `unknown`, never
omitted. A skill that needs a field another skill sets names that
skill in `## Before you start`.

Schema evolution. `schema` is `major.minor`. Adding a field bumps
minor; a rename, type change, or change of meaning bumps major. A
reader on the same major treats a missing field as unknown; a reader
on a different major stops and asks the creator to run
`app-creators`, which migrates the file (see Migration direction).
That is how "not detected", "older compatible state", and
"incompatible state" stay distinguishable.

Readiness validity. A readiness `pass` is bound to the project
revision it assessed. A skill that reads a `pass` whose revision is
not the current one treats it as `unknown`.

Ownership. Every field is one of three classes, and the class decides
who may overwrite it:

- **Detected facts** (`framework`, `app.slug`, `app.languages`,
  `targets.*.detected`): a cache of what the project shows. Any skill
  re-detects them when cheap and overwrites on evidence, recording the
  evidence. A skill that finds state and project in conflict trusts
  the project.
- **Provided facts** (`accounts`, `tools`, `monetization`, `goal`,
  `targets.*.intent`, `app.name`, `app.description`, and the
  `provided:` map below): given by the creator once. No skill
  overwrites one without asking the creator; detection never does.
- **Recorded outcomes** (`targets.*.status`, `targets.*.url`,
  `targets.*.domain`, `targets.*.provider`, `targets.*.bundle_id`,
  `targets.*.package`, `targets.*.asc_app_id`, `readiness.*`): facts
  established by an external system or by a dedicated assessment.
  Written only by the skill that performed or confirmed the action;
  never inferred from local files. Their initial value is `unknown`,
  and `none` is written only after a skill has confirmed with the
  external system that nothing exists there. On a conflict with the
  external system, the external system wins and the skill rewrites
  the record. `readiness.*` is written only by `publish-readiness`;
  every other skill reads it and downgrades a stale `pass` to
  `unknown` in its own reasoning, never in the file.

Routing intent lives in `targets.*.intent`, set by `app-creators`
from the creator's answer, so later skills act on wanted destinations
and never reconstruct or re-ask which ones the creator meant.

```yaml
provided:                      # creator-given facts with no field above, keyed by skill
  publish-readiness:
    privacy_policy_url: ""
    support_email_env: ""      # env var name, never the value
```

Write discipline. A skill reads the whole frontmatter, changes only
the fields its `## Update state` section lists, appends to `history`,
and writes the whole frontmatter back in one write. Fields it does not
own and keys it does not recognize (from a newer minor) are preserved
verbatim. `history` is never edited or truncated. One agent session
per project at a time is assumed; a half-written file is the only
corruption mode, and the previous value is recoverable from git.

Migration direction. `app-creators` upgrades state from an older
major by carrying every provided fact, recorded outcome, and history
row forward under the new names, and re-detecting only detected
facts. On a newer major than it knows, it stops and tells the creator
to update the plugin. State is never downgraded.

### 4.2 `.app-creators/readiness.md`

Written by `publish-readiness`; out of scope here except that
`state.md.readiness.<platform>` summarizes it.

### 4.3 `references/verified-runs.md`

```markdown
| date | level | skill_version | route | account | outcome | notes |
|---|---|---|---|---|---|---|
| 2026-10-26 | 4 | 0.1.0 | vite+vercel | real | live | first run; domain step needed DNS wait |

`route` is `<framework>+<provider or store>`; one row per route per run.
```

### 4.4 Eval case

`evals/<skill>/<case>.json`: `{ "prompt": {"en", "zh"}, "fixture", "expect": [checks] }`
where each check is a sentence a grader can answer yes or no, and the
case passes only when both prompts pass every check. Exact shape
follows the `claude plugin eval` format verified at scaffold.

### 4.5 Lint exit contract

`scripts/lint-skills.sh [skill-dir...]` exits 0 clean, 1 with one line
per finding `path:line: rule: message`. Rules are named so a skill may
not opt out; there is no ignore file.

## 5. Slice plan

Each slice maps to Roadmap Slice 0 items; the roadmap gets a
`**Requirements:**` pointer to this file.

### Slice A — Installable skeleton (smallest end-to-end proof)

Prerequisites: none.

1. `LICENSE`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
   `README.md` install section. `claude plugin validate .` passes.
2. `templates/skill/` with `SKILL.md`, `SKILL.zh.md`,
   `references/verified-runs.md` following §3.2, and `scripts/new-skill.sh <name>`
   that copies and renames it.
3. `scripts/lint-skills.sh` implementing §3.4 level 1, plus a GitHub
   Actions workflow. Lint passes on the template.

Proof: `claude plugin marketplace add ./` then install; the template
skill appears in `/plugin` details. `npx skills add` from the local
path lists it.

### Slice B — Exemplar `publish-web`

Prerequisites: Slice A. Parallel-eligible with Slice C (disjoint files).

1. `skills/publish-web/SKILL.md` per §3.2, default Vercel, alternative
   Cloudflare Pages; `scripts/check-pwa.sh` (manifest, service worker,
   HTTPS, Lighthouse PWA via `npx`), `references/vercel.md`,
   `references/cloudflare-pages.md`, `references/pwa-checklist.md`.
2. `skills/publish-web/SKILL.zh.md`, written in the register
   `zh-rewrite` produces. Lint parity passes.
3. `todo-vite/` fixture in the fixtures repo (Kyle creates the repo,
   see decisions); level 3 run by the doer; one eval case.

Proof: a clean Claude Code session with the plugin installed, pointed at
the fixture, reaches a live Vercel URL that passes `check-pwa.sh`.
Kyle's level 4 run follows and is recorded in `verified-runs.md`; it
is not a slice exit condition.

### Slice C — Entry skill and state

Prerequisites: Slice A.

1. `docs/STATE.md` publishing §4.1 as the normative schema with field
   notes.
2. `skills/app-creators/SKILL.md` + `SKILL.zh.md`: detection table
   (file → framework), the two questions (outcome, wanted
   destinations), `state.md` write, routing table (goal × target →
   skill name).
3. Eval case: fixture project with no state; expect `state.md` with
   `framework.kind: vite`, `targets.web.intent: wanted`,
   `targets.web.status: unknown`, `goal: publish`, and the next skill
   named as `publish-web`.

Proof: after Slice B and C, running `/app-creators:app-creators` then
`publish-web` on the fixture never asks for the framework twice.

## 6. Assumed decisions

- **Plugin and marketplace both named `app-creators`.** Install id
  `app-creators@app-creators`; skills invoke as
  `/app-creators:<skill>`. Matches the working repo name; renaming
  later means a marketplace rename, which the docs support.
- **License MIT** (Kyle, 2026-10-26).
- **Chinese via sibling file** (§3.3), not separate skills.
- **Fixtures in a separate repo** (§3.5), to keep installs small.
- **No build step in Phase 1.** Codex and skills.sh consume the same
  `skills/<name>/SKILL.md`; converters wait for Slice 4.
- **`state.md` is YAML frontmatter + notes**, not JSON, so creators can
  read and hand-edit it and skills can append notes.
- **Level 4 runs are Kyle's.** No skill touching a paid store is called
  verified on an agent's run alone.
- **Vercel is the exemplar default**, Cloudflare Pages the alternative,
  per the roadmap's provisional defaults.
- **Line budget 300**, below the 500 the spec allows, for compaction
  headroom.

## 7. Deferred hardening

- Lint rule that `metadata.verified` older than 60 days warns
  (Roadmap Slice 4 staleness sweep).
- A `skills-ref validate` pass in CI once the agentskills reference
  tool is confirmed stable.
- Secret scanning of `state.md` writes beyond a regex.
- `argument-hint` and `when_to_use` frontmatter for Claude Code once
  skills take arguments.
- Snapshot tests for `new-skill.sh` output.
- Level 2 evals run only in Claude Code. A Codex-side eval of the same
  cases, once a Codex eval harness exists.
- Concurrent writers to `state.md` (two agent sessions on one
  project): a lock or merge rule, if it ever happens in practice.

## 8. Review status

spec-review: completed 2026-10-26

## Decisions needing Kyle's attention

None block Slice A. Confirm or change before Slice B.

1. **GitHub owner.** Decided: `interskh` (Kyle, 2026-10-26); the
   install commands, `plugin.json`, and README name
   `interskh/app-creators-skills`. Repo split decided
   (Kyle, 2026-10-26): this public repo holds the skills; the private
   workroom repo `app-creators` holds thesis, website, and services.
2. **Accounts for level 4 runs.** Decided: Apple Developer, Google
   Play, and Vercel (2026-10-26). Still open: which real app the runs
   use.
3. **Create the fixtures repo before Slice B.3.** Decided: a to-do
   list app per framework (Kyle, 2026-10-26). Assumed separate public
   repo `interskh/app-creators-fixtures`; creating and pushing it is
   yours. Say so if you prefer `fixtures/` inside this repo despite
   the heavier clone.
4. **License.** Decided: MIT (2026-10-26).
5. **Chinese as a sibling file** (assumed). The alternative is separate
   `-zh` skills with their own listing; it costs maintenance but shows
   up as its own entry on registries.
