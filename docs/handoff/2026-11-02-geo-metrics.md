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
