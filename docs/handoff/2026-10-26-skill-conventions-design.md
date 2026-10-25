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

## Task 2 — Skill template and new-skill script

**Decisions**
- Fixed zh heading set (何时使用, 你需要准备, 开始之前, 步骤, 验证, 排查, 更新状态, 来源) is a task-2 decision; task-3 lint enforces it 1:1 against the English order.
- `SKILL.zh.md` has no frontmatter and no redirect line; `metadata` lives only in `SKILL.md` (§3.3: verified is shared).
- zh Steps keeps the literal `**effective**` token with a Chinese gloss（有副作用）, so both files share one marker lint or reviewers can grep.
- Placeholder guidance is HTML comments plus bracketed `[...]` stubs; no comment line starts with `## `, so heading counts stay 8.
- Troubleshooting ships a real empty table header (`| symptom | cause | fix |` / `| 现象 | 原因 | 解决 |`) so authors only add rows.
- Sources stub uses `https://example.com/` inside `## Sources`, the one section where §3.4 lint allows URLs.
- `new-skill.sh`: regex `^[a-z0-9]([a-z0-9-]*[a-z0-9])?$` plus explicit `*--*` check (the regex alone accepts `a--b`) plus `${#name}` 1–64.
- Portable `sed -i.bak … && rm .bak` so the script runs on macOS and Linux CI.
- Repo root resolved from the script path; works from any cwd (checked from `/`).
- `docs/SKILL-CONVENTIONS.md` copies §3.2 and §3.4 table + credential boundary verbatim; route-binding and bilingual-parity paragraphs left out (task named only table + boundary).

**Rejected**
- Repeating frontmatter in `SKILL.zh.md`: two copies of `metadata` to drift; spec says verified is shared.
- `故障排查` for Troubleshooting: task fixed `排查`.
- `sed -i ''` (BSD-only) and perl: breaks on GNU / adds a dependency for no gain.
- Example row in `verified-runs.md`: task says header + `route` note only.
- Auto-filling `__STAGE__`/`__PLATFORM__` with defaults: a wrong default passes lint silently; leaving tokens forces a choice.

**Assumptions**
- Leftover `__STAGE__`/`__PLATFORM__` will fail task-3 lint (enum check on `metadata.stage`/`platform`); check when lint lands.
- The template under `templates/` is not scanned as a skill by the plugin loader (`claude plugin validate .` still reports the same three warnings, no new ones).
- HTML comments in a shipped SKILL.md are harmless to agents; Slice B authors delete them.

**Deferred**
- Lint run on the template and snapshot tests for `new-skill.sh` output (task 3 / spec §7).
- `npx skills add` discovery proof with a generated skill: Slice A proof step.

**Touches**
- `templates/skill/SKILL.md`, `templates/skill/SKILL.zh.md`, `templates/skill/references/verified-runs.md`, `scripts/new-skill.sh`, `docs/SKILL-CONVENTIONS.md`.
- Shared surface: the en and zh heading sets, the first-line redirect string, and the template frontmatter keys; task-3 lint hardcodes against these.
- Collision for task 3: spec A.3 says "lint passes on the template", but `__NAME__`/`__STAGE__`/`__PLATFORM__` fail name-equals-directory and the enums. Task 3 must lint a generated copy (`new-skill.sh` into a temp dir) or exempt the tokens under `templates/`.
