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

## Task 3 — Lint script and CI

**Decisions**
- Template mode is set when the dir's physical path is under `$root/templates/` (not a substring "/templates/" check): it skips `name-matches-dir` and accepts `__NAME__`/`__STAGE__`/`__PLATFORM__`. A test proves a real skill with `stage: __STAGE__` still fails `metadata-stage`.
- `export LC_ALL=C` at the top: macOS awk in a UTF-8 locale compared `验证` and `来源` as equal (strcoll), which hid zh URL findings. Byte comparison is exact for headings and the redirect line.
- Description length counts UTF-8 characters (`tr -d '\200-\277' | wc -c`), not bytes; a test with an ~800-char CJK description (>2400 bytes) must pass.
- `secret-like` exempts assignment values shaped like env var names (`^[A-Z][A-Z0-9_]*$`, e.g. `api_key: CLOUDFLARE_API_TOKEN`). The finding never echoes the matched text.
- Scanned for secrets: `*.md`, `*.sh`, `*.py`, and anything under the skill's `scripts/`.
- `##` heading extraction skips fenced code blocks; URL check also tracks sections outside fences.
- A frontmatter-present failure skips the field rules (they would be noise); body rules still run.
- An empty body reports `redirect-line` at line 0 (test `empty-body`), so every finding keeps the `path:line:` shape.
- Missing dir / no SKILL.md / `-flag` arg → exit 2. No-arg mode `cd`s to the repo root and prints `skills/<name>` paths.
- Tests: the fixture repo lives in mktemp (copies of `new-skill.sh`, `lint-skills.sh`, template); each mutant is at `mutants/<case>/good-skill/` so the name still matches the dir. Assertions match `:<line>: <rule>: ` (so `metadata-verified` cannot match `metadata-verified-version`) and check every output line's format.
- Credential-shaped fixtures are built at runtime by concatenation; the test file holds no literal key.
- CI: the four steps as given, `permissions: contents: read`, only `actions/checkout@v4`.

**Rejected**
- An ERR trap mapping every failure to exit 2: it would also fire on grep no-match in subshells; exit 2 is explicit at usage/missing-dir points only.
- Bash associative arrays / mapfile: macOS ships bash 3.2 (the local run used it).
- Linting a generated copy instead of the template: template mode keeps `lint templates/skill` a direct CI step.
- Scanning every file for secrets: the task names .md and script files only.

**Assumptions**
- GNU grep/sed/mawk behavior on ubuntu-latest was not exercised locally (no gawk/gsed/ggrep/mawk here); the first CI run is the check. The constructs used: ERE without `\s`, no awk intervals, `grep -o`, `sed -E`.
- The credential regex literals in `scripts/lint-skills.sh` are patterns, not values; `privacy-scan` has no per-file mode, so its verdict on them shows only at `--staged`/`--range`.
- "Under 300 lines" means NR < 300 (awk NR, so a missing final newline still counts).

**Deferred**
- `npx skills add <path> --list`: `skills` CLI not installed, and `npx` would fetch it from the network; the skills.sh discovery check moves to Registry submission (roadmap Slice 1).
- `skills-ref validate` in CI: not installed; spec §7.
- shellcheck: not installed locally; not run.

**Touches**
- `scripts/lint-skills.sh`, `tests/lint-skills.test.sh`, `.github/workflows/lint.yml`.
- Shared surface: lint hardcodes the en/zh heading sets, the redirect string, and the verified-runs header from task 2's template; any change there must update `scripts/lint-skills.sh` too.

## Gate fix round

**Fixes**
1. Inline ` # comment` stripped (outside quotes) before unquoting. 2. `>`/`|` indicator followed by a comment is a block scalar. 3. Plain scalar continuation lines join. 4. `metadata:` children at any consistent indent; non-empty value after `metadata:` → `metadata-mapping`. 5. No-arg scan: dir without `SKILL.md` → `skill-md-present`. 6. `line-budget` on `SKILL.zh.md`. 7. New secret shapes; env-var exemption needs caps + an underscore. 8. grep exit ≥2 → `tool-error` on stderr, exit 2. 9. `verified-consistency`. 10. Redirect checks prefix + remainder naming `SKILL.zh.md`. 11. Quote passed via `awk -v q="'"`; no octal escape.

**Decisions**
- Parser mode is chosen by the key's own value after comment-strip: block indicator → fold; non-empty plain → continuation; empty → mapping (metadata children). One discriminator lets fixes 3 and 4 coexist.
- Quoted values are never continued; quoted multi-line scalars stay unsupported.
- Children deeper than the first `metadata:` child's indent are ignored (nested values), not reported.
- `metadata-mapping` skips the six `metadata.*` field checks (noise), like `frontmatter-present` skips field rules.
- `verified-consistency` row check runs only when `verified_version` is valid semver and the runs file exists; a non-semver version or missing file is already reported by `metadata-verified-version` / `verified-runs-present`.
- `sk-` gets a left boundary `(^|[^A-Za-z0-9_-])`: with `-` now in the class, `task-…`/`risk-…` words of 20+ chars matched. Test `sk- inside a hyphenated word` guards it.
- Fix 8 test uses a fake `grep` (exit 2) on PATH for one lint call; portable and works as root, unlike `chmod 000`.
- No-arg summary count includes dirs without `SKILL.md`.

**Rejected**
- `chmod 000` simulation for fix 8: a no-op as root (containers).
- Reporting deeper or inconsistent metadata indents: YAML parsers already reject inconsistent siblings; nested values are legal.
- Keeping one exact English redirect sentence: fix 10 asks for tolerance.

**Assumptions**
- `docs/SKILL-CONVENTIONS.md` copies spec §3.4 with "Kyle" replaced by "maintainer" (corrects Task 2's "verbatim" line).
- The fix-1 test extracts the first ```` ```yaml ```` block of `docs/SKILL-CONVENTIONS.md`; adding an earlier yaml block there would change the fixture.
- mawk/GNU tools still not exercised locally; constructs used: `match()`/`RLENGTH`, `index`, `substr`, `-v`, ERE without intervals in awk. No other GNU/BSD divergence seen.

**Deferred**
- `claude plugin eval` exists in the local CLI and expects `case.yaml` or `prompt.md` plus `graders/*.md`, not `<case>.json` as spec §4.4 sketches, so Slice B's eval item must follow the CLI's format.
- CRLF input handling.
- Duplicated name validation between `new-skill.sh` and lint.
- `new-skill.sh` usage exit 1 vs lint exit 2.

**Touches**
- `scripts/lint-skills.sh`, `tests/lint-skills.test.sh`. New rule names (public lint surface): `metadata-mapping`, `skill-md-present`, `verified-consistency`, `tool-error`. Constant `REDIRECT` renamed `REDIRECT_PREFIX`.

Orchestrator note (gate): skills.sh discovery verified. `npx skills add <local path> --list` on a copy of the committed tree with one skill generated by `new-skill.sh` reported "Found 1 skill", so the `skills/<name>/SKILL.md` layout is discoverable by the skills CLI as well as Claude Code. The Slice A proof's two checks (plugin details, skills.sh listing) are both met via a generated sample skill; the template itself is not a skill and is not meant to appear.
