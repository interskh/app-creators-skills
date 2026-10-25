# Handoff — 2026-10-26-skill-conventions-design

## Task 1 — Plugin scaffold

**Decisions**
- `plugin.json` has no component keys; the default `skills/` scan covers Slice B/C skills.
- `skills/.gitkeep` keeps the scan directory in git while no skill exists.
- Added a top-level `description` to `marketplace.json`: the validator warned when it was missing.
- README Install: commands were already in final form; replaced the "Placeholders" line with a one-line note to substitute `<owner>`.

**Rejected**
- Icon file: not in spec; only a plugin-directory listing warning, which does not affect validation or install.
- Real URL in `repository`: `<owner>` placeholder is a recorded decision; the validator only drops it from the listing preview.
- Removing root `CLAUDE.md` to silence its warning: pre-existing contributor file, outside this task's scope.

**Assumptions**
- Kept warnings (`claude plugin validate .` still passes): root CLAUDE.md not loaded as plugin context; ICON_MISSING; LISTING_URL_SCHEME on the `<owner>` URL. Recheck with `claude plugin validate .`.
- An empty component inventory (Skills 0) is acceptable until task 2/Slice B adds skills; install succeeded with it.

**Deferred**
- Icon and real repository URL: wait until the repo is published under a real owner.
- `npx skills add` discovery proof: Slice A proof step, after the template exists (task 2).

**Touches**
- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (names `app-creators`; install id `app-creators@app-creators` — shared public surface).
- `README.md` (Install section only), `skills/.gitkeep`.
