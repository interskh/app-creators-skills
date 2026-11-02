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
