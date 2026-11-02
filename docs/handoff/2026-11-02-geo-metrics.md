# Handoff: 2026-11-02-geo-metrics

## Task 1: roadmap ticks

**Decisions**
- Ticked each Slice 0 item only after checking its deliverable in the tree; ran `lint-skills.sh` on skills and template and `claude plugin validate .`.
- Split "Fixture, eval, level 3 run": the checkbox now covers fixture and eval; the level 3 run is a plain `Kyle:` bullet because it needs a fixture-only Vercel account.
- Ticked the parent "Exemplar: publish-web" so Ralph does not pick it; plain bullets record the remaining verification.

**Rejected**
- Leaving the level 3 run as a checkbox: Ralph would stall on a human-blocked item.
- Leaving the parent unticked: Ralph would re-pick it with no checkbox work under it.

**Assumptions**
- Ralph reads only checkbox lines, per the task brief. Check: the Ralph picker in its loop config.
- Plugin validation with warnings counts as passing: it prints "Validation passed with warnings" (root `CLAUDE.md` not loaded; no icon).
- `scripts/new-skill.sh` was read, not run, to avoid writing a skill into the tree. Check: `tests/` or a scratch run.

**Deferred**
- Level 3 and level 4 runs: both need Kyle; `skills/publish-web/SKILL.md` stays `verified: "unverified"`, so nothing claims they happened.
- "GitHub GEO pass" and "Metrics script": ticked by later tasks in this run.
- Spec wording on the level 3 run is unchanged: this task edits Slice 0 of the roadmap only.

**Touches**
- `docs/ROADMAP.md` (Slice 0 only). Tasks 2 and 3 edit the two remaining unticked lines.
- `docs/handoff/2026-11-02-geo-metrics.md` (new).

## Task 2: GEO pass

**Decisions**
- README states "Ships today" and "Planned, not shipped" as separate lines; the old App Store and Google Play intro is gone. Status line and `verified` column stay as they were.
- Printed `-a codex` for Codex and bare `npx skills add` for other agents. Both ran for real and installed both skills.
- No per-skill `--skill` command printed: `publish-web` runs `app-creators` when state is missing, so installing it alone breaks. The README tells terminal users to select both in the picker.
- `llms.txt` "install" means the install commands in the body plus a link to raw `README.md`. References and roadmap sit under `## Optional`, which the spec defines as skippable.
- `awesome-lists.md` orders by fit, with lists the repo meets today first. Blocked lists stay with drafts and the exact unmet rule, because they become usable with age and stars.
- `Plugins and Extensions` for acvnace and `Development & Code Tools` for BehiSecc, matching where similar entries sit.
- Topics below omit `deployment`: too broad to help anyone find this repo.

**Rejected**
- `--skill publish-web` in the README: tested and works, but leaves the creator without `app-creators`.
- `--all` or `--yes` in printed commands: the skills CLI's `--all` targets every agent, and neither is needed by a person or a detected agent.
- FAQ-style README sections and keyword lists: plain prose only, per the brief. Trigger phrases come from each skill's `description` only.
- Dropping the blocked lists: hesreallyhim alone is worth a dated reminder.
- Composio's Codex list as the Codex entry: 308 PRs open, no merge found since 2026-07-26.

**Assumptions**
- First commit 2026-10-25 gives 2026-11-08 for hesreallyhim's rule; repo creation 2026-10-26 gives 2026-11-09 for heilcheng's. Check: commits API before submitting.
- Merge recency comes from `search/issues` sorted by `updated`, so it is close but not exact. Check: the list's PR tab.
- `.agents/skills/` is what Codex reads, per the skills CLI output. No Codex session was run.
- The skills.sh 404 for this repo comes from no recorded installs. My test runs set `DISABLE_TELEMETRY=1`. Check: the URL after a real install.

**Deferred**
- Submissions: a person files them. hesreallyhim requires a human filer, and nothing was opened.
- `.claude-plugin/plugin.json` keywords still list `app-store`, `google-play`, `monetization`, `user-acquisition`, and both manifests say "get users, and make money". Same overclaim as the old README; outside this task's paths and it ships in the plugin, so the orchestrator should schedule it.
- Repo `description` overclaims the same way. Concrete reason to change it; suggested text: `Agent skills that set up an AI-built app's project state and deploy it to Vercel or Cloudflare Pages. Pre-release.` Not applied.
- Codex plugin manifest, `SECURITY.md`, and SHA-pinned Actions for the hashgraph-online list: new repo surface, no demand yet.
- `templates/skill/SKILL.md` ships inside the installed plugin cache. Harmless so far; not changed here.

**Topics** (orchestrator applies; each confirmed by exact match in `gh api search/topics`)
`agent-skills`, `claude-code`, `claude-code-plugin`, `claude-code-skills`, `codex`, `skills-sh`, `pwa`, `vercel`, `cloudflare-pages`, `vibe-coding`

**Touches**
- `README.md`, `llms.txt` (new), `docs/launch/awesome-lists.md` (new), `docs/SKILL-CONVENTIONS.md` (one rule), `docs/ROADMAP.md` (line for this item only).
- Shared surface: repo topics and possibly `description` via the orchestrator. A sibling that adds a skill must now update `README.md` and `llms.txt`.

## Task 3: metrics script

**Decisions**
- Flags `--plugin-installs/--skills-sh-installs/--site-visits N`; absent writes `-`; a same-day rerun reads the existing row and keeps omitted manual cells. Explicit `0` is kept as 0.
- Date from `METRICS_DATE` (default UTC today); tests copy the script into a temp tree, so no path override exists.
- All three `gh api` calls and number validation finish before any write; the file is built in a temp file beside it, chmod 644, then `mv`.
- Refuses to edit a metrics.md whose header row differs, or whose same-date row is malformed or duplicated.
- Test uses `tests/fake-gh.sh` (separate file, copied as `gh`) and a symlinked PATH without `gh` for the missing-gh case, because CI runners ship gh.
- The test found a real bug: `die` inside `$(pair ...)` only left the subshell and wrote an empty row. `pair` now sets globals.
- Install counts: no documented API. Claude Code plugin docs (code.claude.com/docs/en/plugin-marketplaces, plugins-reference) mention none. skills.sh/docs documents only an SVG badge at `skills.sh/b/owner/repo`, which is a display image, not a data API.

**Rejected**
- Scraping the skills.sh badge SVG or page: undocumented, can break, and the repo has no skills.sh page yet (404).
- Storing per-day traffic arrays, referrers, or paths: public repo, aggregates only, and the rolling totals are what FR-10 needs.
- Summing or de-duplicating 14d windows from daily arrays: possible, but out of scope; the header says not to sum.
- `--flag=N` syntax: one form is enough.

**Assumptions**
- `--jq` on `traffic/*` returns top-level `count` and `uniques` (verified on the real repo, 2026-11-02). 403 detection greps gh stderr for `HTTP 403` (fake emits it; real wording not triggered, the local login has push access).
- The first real row shows clones 55/37: it includes this run's own clones and Task 2 test installs, so it is not organic traffic.

**Deferred**
- Scheduling the script (cron or Action): the Action token would need push access to read traffic; Kyle runs it by hand for now.
- Install counts via skills.sh if it ever documents an API; re-check before the exit-criterion review.
- A killed run (SIGKILL) can leave a hidden `.metrics.*` temp file in `docs/`; metrics.md itself stays intact.

**Touches**
- New: `scripts/metrics.sh`, `tests/metrics.test.sh`, `tests/fake-gh.sh`, `docs/metrics.md` (first real row 2026-11-02).
- Edited: `.github/workflows/lint.yml` (one step), `docs/ROADMAP.md` (Metrics script tick).
- Shared: `docs/metrics.md` column order; the Community launch item also writes there.

## Whole-run gate

Suite, fresh reviewer, and Codex all ran on ec37121. The suite passed. Round 1 fixes landed in two commits: one for the metrics script, one for the prose.

**Fixed in round 1**
- `docs/metrics.md` said skills.sh documents no install API. It documents one that needs a Vercel OIDC token, so the field stays manual and the sentence now says why.
- `tests/fake-gh.sh` ignored `--jq`, so swapped columns passed. It now rejects any call other than the contracted one.
- New rows could land in a later table in `docs/metrics.md`. Reads and writes are now scoped to the metrics table.
- `gh auth status` gave false "not logged in" errors; the precheck is gone and exit 4 maps to the login message. `--hostname github.com` is pinned on every call. The script is executable. Dates earlier than the latest row are refused.
- README, `llms.txt`, drafts, and the `publish-web` description overclaimed Next.js on Cloudflare Pages. Cloudflare Pages takes Next.js only as a static export.
- `publish-web` named unshipped skills without saying so and gave no way forward when `app-creators` was absent. Both are fixed in English and Chinese.
- README now discloses the `npx skills` CLI's own telemetry and the no-terminal case, which needs `-a <agent> -y`.
- The new-skill rule now also covers the skill count, the shipped list, the `llms.txt` summary, and both manifest descriptions. The spec carries the same sentence.

**Corrects Task 2's Deferred entry**
- The orchestrator corrected both manifests in the Task 2 commit, so that entry is closed. The manifests also belong in Task 2's Touches.
- The orchestrator applies the repo topics and description after the gate.

**Rejected**
- A script run through a symlink writes to the symlink's tree: nobody runs it that way.
- Preserving a `600` mode on `docs/metrics.md`: the file is tracked at `644`.

**Open, for Kyle**
- The level 3 run is spec Slice B's exit proof and has not happened. The roadmap bullet says so, but nothing enforces it, and Ralph's next pick is `publish-readiness`.
- No Claude Code or Codex session has loaded the skills after a real install.
- The `SKILL-CONVENTIONS.md` and spec examples still show the old `publish-web` description. They are illustrations.

**Round 2**
- The `publish-web` install clause from round 1 told the agent to run `npx skills add ... -y`. That sent the CLI's install telemetry from a skill and installed code without asking, against FR-5 and Task 2's rejection of `--yes`. The skill now asks the creator to run the command, without `-y`.
- `publish-web` moves to `0.1.1`, because spec §3.4 says a prerequisite change bumps `version`. It stays unverified.
- The round 1 skills.sh sentence was also wrong: a linked Vercel project can get a short-lived OIDC token. Staying manual is a choice, not a limit, and the wording now says so. Task 3's earlier wording is superseded.
- `scripts/metrics.sh` now fails on a damaged table instead of losing or duplicating a row, and rejects impossible and future dates.

**Gate cap reached:** two of two fix cycles are used.
