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

## Gate fix round 2

**Fixes**
1. Quoted values that do not close on their line are read on until the closing quote. `\"` (double-quoted) and `''` (single-quoted) do not close the value and are unescaped before measuring.
2. Comment-only lines (`#…`) are skipped when joining plain continuation lines.
3. `description:` with an empty value takes its value from the indented plain lines below it. An empty-valued key whose first indented line is `key:` is still a mapping (`metadata:`).
4. The `verified-consistency` row must also have `date` equal to `verified`.
5. Added `rk_(live|test)_…`. Added `sk-(proj|ant|svcacct)-…` with no left boundary, so `Bearer%20sk-proj-…` is caught. The generic `sk-…` keeps its boundary.

**Decisions**
- Parser modes are now `block | pending | quote | plain`. `pending` (empty value) decides scalar or mapping from the first non-blank, non-comment indented line.
- A blank line inside a quoted multi-line value adds nothing, so length is slightly under-counted versus YAML's newline. This is accepted.
- The next-line description test also asserts the message `chars; max 1024`. Round 1 lint reported `description-length` there for the wrong reason (empty).

**Deferred**
- A trailing ` # comment` on a plain continuation line is still joined into the value. It was not in scope, and it can only over-count.

implement-loop: slice A shipped 55f17ad; remaining: [B, C]

## Slice B — Task 1 — todo-vite fixture

Fixtures commit: `95c2f95` in `../app-creators-fixtures` (todo-vite at that sha is the pin for the eval cases).

Resolved versions: vite 8.3.4, vite-plugin-pwa 1.3.0, typescript 6.0.3.
PWA artifacts emitted in `dist/` (generateSW mode): `manifest.webmanifest`, `registerSW.js`, `sw.js`, `workbox-<hash>.js` (this build: `workbox-9c191d2f.js`). The index links `<link rel="manifest" href="/manifest.webmanifest">`.

**Decisions**
- Two TS modules: `src/main.ts` (DOM and events) and `src/store.ts` (one `localStorage` key, `todo-vite:items`). A bad stored value loads as an empty list.
- Added `src/vite-env.d.ts` (`/// <reference types="vite/client" />`). Without it, `tsc` fails with TS2882 on `import './style.css'`. It is a declaration file, not a module. This matches the house project.
- Manifest stays inline in `vite.config.ts`. vite-plugin-pwa defaults are used (no `workbox` options). The default precache picks up the manifest icons (8 entries).
- Icons are solid blue with a white square. A `zlib` + `struct` script generated them. The maskable icon has a smaller square, so it stays inside the safe zone. The generator is not committed.
- The list renders with `createElement` and `textContent`. User text never goes through `innerHTML`.

**Rejected**
- `overrides` to move `glob` off 11.x: that changes the fixture's dependency graph away from a plain vite-plugin-pwa install.
- (doer) A root `.gitleaksignore`: it adds a shared file outside the task paths, and its line-keyed fingerprint moves on every lockfile change. Overruled by the orchestrator, see Deferred.
- `/// <reference types="vite-plugin-pwa/client" />`: the app does not import `virtual:pwa-register`, because `registerSW.js` is injected.

**Assumptions**
- `npm audit` reports 2 transitive advisories under workbox-build (fast-uri, serialize-javascript). `npm audit fix` changed nothing within the ranges. These are build-time only. Check with `npm audit` in `todo-vite/`.

**Deferred**
- Commit blocker, resolved by the orchestrator: privacy-scan BLOCK `email-address` at `todo-vite/package-lock.json:3519`. The match is the npm registry `deprecated` text of `glob@11.1.0` (via `vite-plugin-pwa -> workbox-build@7.4.1`, range `^11.0.1`). Every glob 11.x carries this text, so `npm update` cannot remove it. Judged a false positive (public registry metadata, not project data) and recorded in the fixtures repo's `.gitleaksignore` by gitleaks fingerprint, which is the scanner's own false-positive route; `--no-verify` was not used. The fingerprint is line-keyed: re-add it when the lockfile is regenerated.
- No browser smoke test (not required by the brief).

**Touches**
- `../app-creators-fixtures`: new `todo-vite/` tree, one line in root `README.md`, root `.gitleaksignore`. No shared surface in the skills repo.

## Slice B — Task 2 — publish-web skill

**Decisions**
- Deliberate deviation from spec §5 B.1 "Lighthouse PWA via `npx`": Lighthouse 12.0.0 (2024-04-22) removed the PWA category. Source: Lighthouse changelog 12.0.0 entry (github.com/GoogleChrome/lighthouse/blob/main/changelog.md) and the v12.0.0 release page, checked 2026-10-26. `check-pwa.sh` implements the install criteria directly; `pwa-checklist.md` says why.
- CLI forms (Vercel docs, checked 2026-10-26): `vercel deploy --prod` (cli/deploy, projects/deploy-from-cli), `vercel link --yes --project` (cli/link), `vercel project ls --filter` / `vercel project create` (cli/project), `vercel list --prod --status READY -m` (cli/list), `vercel domains add|verify` (cli/domains, domains/set-up-custom-domain), `vercel certs ls` (set-up-custom-domain). Cloudflare: `npx wrangler pages project list|create`, `pages deploy <dir> --project-name --commit-hash`, `pages deployment list` (workers/wrangler/commands/pages, pages/get-started/direct-upload). Pages custom domains: dashboard only (pages/configuration/custom-domains).
- Rerun key for the deploy: `--meta commit=<sha>` on deploy, `vercel list -m commit=<sha>` before; a dirty tree asks the creator to commit first. The dirty check uses `':(exclude).vercel'`, because step 4 creates `.vercel/` (pathspec tested in a scratch repo). `history.result` is a bare token (`live|ready|stopped`); the reason goes in the notes, because `stopped: x` would break the flow mapping.
- `vercel domains add <domain> <project>` (two args): add-a-domain says pass the project even when linked; set-up-custom-domain shows one arg. The two-arg form is correct under both.
- node over jq: Node is already there for any Vite/Next build; jq is the fallback. Both paths tested (jq by PATH without node). Neither → exit 2.
- Icon rule: exact `sizes` token, PNG by `type` or `.png` src, `purpose` unset or containing `any` (MDN icons: `any` is the default). A maskable-only 512 fails; the fixture's two 512 entries made this decision necessary.
- Service-worker script served as `text/html` → FAIL (catches an SPA rewrite answering for a missing `sw.js`). This is my heuristic, not a vendor rule.
- `display` accepts standalone|fullscreen|minimal-ui. web.dev also lists `window-controls-overlay`; MDN has it only in `display_override`.
- Dependent checks after an HTML failure print `FAIL <check>: skipped: ...` and exit 1, so a skipped check never reads as passed.
- Removed the scaffold's copied `SKILL.zh.md` (byte-identical to the template); Task 3 writes the real one.
- Hobby is "free, personal, non-commercial" (plans/hobby), so section 2 says a commercial app needs a paid plan.

**Rejected**
- `npx lighthouse`: no PWA category since 12.0.0.
- Running `check-pwa.sh` on the unique deployment URL: Standard Protection can put it behind a login (deployment-protection); production domains stay public.
- Accepting any 512 PNG, regardless of purpose: test (c) would not catch it, and a maskable icon is not a general-purpose icon.
- Treating "non-empty body" alone as a valid SW script: an HTML fallback passes it.

**Assumptions**
- `vercel list --prod --status READY -m commit=<sha>` combines filters; the docs show each flag on its own. Check on the level-3 run.
- `wrangler pages deployment list` output shows the commit hash; the docs do not show its output. The reference says so.
- The production domain comes from the dashboard Overview tab; generated-urls does not document a `<project>.vercel.app` form or an inspect alias field.
- The `vite preview` port 4173 is from Vite's static-deploy guide; the `python3 -I -m http.server` preview for static sites and Next exports is my choice, tested here.

**Deferred**
- Level-3 run and live-URL proof (§5 Slice B proof): blocked. No fixture-only Vercel/Cloudflare account exists, and §3.4 forbids agent runs on the personal account. No `vercel`/`wrangler` command was run.
- `SKILL.zh.md` (Task 3); the `zh-present` lint finding stays until then.
- Doc fetch 404s, so their claims are left out: vercel.com/docs/deployments/configure-a-build.md (used builds/configure-a-build.md instead), developer.chrome.com/blog/lighthouse-12-0 (used the changelog and the release page instead). The Vite static-deploy page was read from its source file in the vitejs/vite repo (`docs/guide/static-deploy.md`); Sources cites the published page.
- `display_override` and the `<base href>` resolution are not handled by the script.

**Touches**
- `skills/publish-web/` (SKILL.md, scripts/check-pwa.sh, references/{vercel,cloudflare-pages,pwa-checklist,verified-runs}.md).
- state.md fields written: `targets.web.status|url|provider|domain`, `tools.deploy`, `accounts.vercel`, plus one `history` row. Reads `framework.*`, `targets.web.intent`, `app.slug`, `readiness.web`. Slice C's `app-creators` must set `app.slug` (I added it to the required fields: it is the project name).
- `README.md` Skills table (shared with every future skill), `AGENTS.md` status line.

## Slice B — Task 3 — SKILL.zh.md and eval cases

Pre-declared before the level-2 run: Bash is not granted, so `ran-verify-script` cannot pass. Ceiling = 4 of 5 equal-weight graders = 0.8 per case; the default `--threshold 1.0` makes the command exit 1 even at the ceiling.

Result (claude 2.1.310, `--runs 1 --ablation none --scaffold --no-publish`, no Bash): vite-en 0.8, vite-zh 0.8 (skill-fired, read-state, names-vercel, asks-only-human-prerequisites PASS 3/3 votes; ran-verify-script FAIL, 0 Bash calls). Cost $0.54 total (en $0.30, zh $0.24), `partial: false`. Exploratory probe run on vite-en: $0.13. Both traces read `.app-creators/state.md` and the fixture files; the zh run loaded `SKILL.zh.md` via the redirect line. Neither run asked about framework, package manager, build command, or a token.

**Decisions**
- Glossary (fixed once): deploy 部署, production deployment 生产部署, production domain 生产域名, custom domain 自定义域名, apex 根域名, subdomain 子域名, link 关联, preview 预览, readiness 就绪检查 (gate: 就绪检查关口), creator 创作者, provider 服务商, dashboard 控制台, scope kept as `scope`, Cloudflare zone kept as `zone`. UI labels kept in English (Overview, Application, Manifest, Installability, Custom domains); Chrome's Install shown as 安装（Install）.
- "Takes N minutes" → 要 N 分钟, not the template's 耗时约: 约 would add a hedge the English lacks.
- Token parity (backtick spans, en vs zh): 129/129 distinct spans, none missing or extra; only count difference is `public` (1 → 2, step 1 `static` line names it twice). URLs 33/33 same order; `**effective**（有副作用）` 3/3; 7 steps; 7 troubleshooting rows.
- Scaffold cwd finding (probe with `--keep-temp`): the script runs in place from the case dir (`$0` is its absolute path in the plugin tree), cwd is the empty workspace, env is only PATH, HOME/TMPDIR (temp), TERM=dumb, GIT_CONFIG_NOSYSTEM=1. No `EVAL_*` reaches it, so no env override for the fixture path is possible.
- The brief's `$case/../../../../app-creators-fixtures` resolves only in the canonical checkout; in a worktree the fallback resolves the main checkout via `git rev-parse --git-common-dir`. Both paths reach the same `../app-creators-fixtures/todo-vite`.
- Copy via `git archive HEAD .` from the fixture subdir: exactly the tracked set at the pinned commit, no node_modules/dist, no uncommitted edits. `HEAD:./` and `HEAD:todo-vite` give an empty tar from a subdir (found by test).
- Two cases (`vite-en`, `vite-zh`), because one case takes one prompt; §3.4 parity = both pass the same graders. Files identical except name/description/prompt.
- `ran-verify-script` kept although it cannot pass without Bash: it is the §3.4 contract for the nightly run.

**Rejected**
- Adding `Bash` to `allowed_tools` (the harness warning suggests it): docs say only read-only tools are granted from the list, but the hard rule was no Bash in this run, so I kept the list as specified. The nightly form passes `--allow-tools Bash`; if that alone does not grant it, add Bash to the list then.
- Env var for the fixture path: the scaffold env is fixed.

**Assumptions**
- `read-state` (`tool_used` Read on `state\.md`) passes on any Read call, even of a missing file (the probe passed it with an empty workspace). Tighten with a trace regex on a state value if it turns noisy.
- The en run used the `Agent` tool though it is not in `allowed_tools`; the harness allows it. Harmless here (no shell in the subagent either).
- The zh run guessed "大概是 `todo-vite.vercel.app`" for the production domain; the skill says read it from the dashboard. Not graded; watch on the next run.

**Deferred**
- Level-3 fixture run and live-URL proof: blocked on a fixture-only Vercel account (§3.4 credential boundary).
- Nightly CI eval: needs that account, `--allow-tools Bash`, and a way to pass the token (`EVAL_*` only) and network through the OS sandbox. README says so.
- The workspace has no commits (the agent saw "no commits, untracked"), so step 5 asks the creator to commit. A scaffold `git init` + commit would make it realistic; not in scope.

**Touches**
- `skills/publish-web/SKILL.zh.md` (new), `evals/publish-web/{README.md,vite-en/*,vite-zh/*}` (new), `.gitignore` (`evals/results/`). No shared surface beyond `.gitignore`.

## Slice B — Gate fix round 1

**Fixes**
1. Icons pass only on an `image/*` type or a PNG signature; `text/html` fails as a rewrite answering for the icon.
2. The SW script passes only on the five JavaScript MIME types; any other type fails and is named (W3C Service Workers spec).
3. `fetch()` keeps curl's rc; a non-zero rc fails the check even after a 200, and the reason carries the curl error.
4. Registration is inferred when a loaded script mentions `serviceWorker` and `sw.js` next to the page is JavaScript; the PASS line says "(inferred from sw.js)". Tested on a `injectRegister: false` + `registerSW({ immediate: true })` build.
5. HTML comments (multi-line too) are stripped before the tag scan and the SW grep.
6. Every run prints the same 12 check lines; dependents print `FAIL <check>: skipped: <reason>`.
7. Preflight checks curl, grep, sed, awk, head, od, tr, cp, cat, mktemp, rm (exit 2).
8. Production domain: the CLI docs do not document `vercel inspect` / `vercel project inspect` output, so step 5 asks the creator for the domain on the project's Overview tab when `targets.web.url` is empty.
9. Rerun guard: the dirty check excludes `.app-creators` and `.vercel`. The key `<src>` is `git log -1 --format=%H -- . ':(exclude).app-creators' ':(exclude).vercel'`, the last commit that changed the app. Reuse only if the deployment `vercel inspect <targets.web.url>` shows is in `vercel list --prod --status READY -m commit=<src>`; otherwise deploy. Outside git, or with no commits: deploy without `--meta`.
10. The Cloudflare alternative passes `--branch=main` (step 4 creates with `--production-branch=main`; ask the creator if the project existed).
11. Step 2 covers a server-rendered Next.js app: `<pm> run start` (`next start`, port 3000, Next.js CLI docs).
12. Step 4 records `vercel` or `cloudflare-pages`, whichever was used.
13. Both `scaffold.sh` files `git archive` commit `95c2f95` (no HEAD check) and stop when the commit is not fetched; README updated; the files stay identical.

**Decisions**
- Fix 9 uses `<src>` rather than diffing against the current deployment's meta: the docs show no CLI way to read a deployment's meta (cli/list points to the REST API), and they state no `vercel list` sort order. `-m` filtering is documented, and the `inspect` comparison only needs the deployment identity. A failed or unclear `inspect` means deploy, so the error direction is "build again", never "skip a needed deploy".
- No `vercel promote`: the promotion docs limit promote to staged deployments; a deployment that was current before needs a rollback (`vercel rollback` was not fetched). Redeploying unchanged code is safe.
- A JavaScript MIME type is required by the W3C Service Workers spec (MDN `register()` does not say it).
- New Troubleshooting row for `served as text/html` (reproduced with a SPA-fallback server).

**Deferred**
- `version` stays `0.1.0`. Steps changed, but the skill is unreleased and unverified (`verified: unverified`, no verified-runs rows), so no prior version exists for a bump to distinguish.
- That `vercel inspect` accepts a production domain (the docs say "deployment URL or ID") is unverified until the level-3 run; the fallback is to deploy.

**Touches**
- `skills/publish-web/{SKILL.md,scripts/check-pwa.sh,references/vercel.md,references/cloudflare-pages.md,references/pwa-checklist.md}`, `evals/publish-web/{README.md,vite-en/scaffold.sh,vite-zh/scaffold.sh}`. `SKILL.zh.md` was not touched; the zh doer mirrors steps 2, 4, 5, the new Troubleshooting row, and the Sources additions.

**zh mirror** (`skills/publish-web/SKILL.zh.md`, 147 lines): steps 2, 4, and 5 (all four lines), the new `served as text/html` row before `FAIL https`, and the four Sources entries now match SKILL.md, with the same order and 核对于 2026-10-26. Parity: 137/137 distinct backtick spans, none missing or extra. Count differences are intentional: `public` 1→2, and `vercel domains verify` 1→3, because the bare "verify" became that code span. URLs match 37/37 in the same order. Steps 7/7, troubleshooting rows 8/8. Bare-word fixes: exclude → dropped (SKILL.md removed that aside), stdout → 标准输出, verify → `vercel domains verify` (twice), scope → 作用域, zone → 区域（zone）, http → HTTP, git → Git, state → 状态文件. The prose keeps keep-list words, product and UI names, plus skill and frontmatter as project terms.

## Slice B — Gate fix round 2

**Fixes**
1. The comment-stripped page is used only for tag extraction (manifest `<link>`, `<script src>`). Registration strings are searched in the raw page plus the loaded scripts, so `<script>const a="<!--";navigator.serviceWorker.register("/sw.js");const b="-->";</script>` passes.
2. `is_js_mime` accepts exactly the WHATWG mimesniff JavaScript MIME type essences (mimesniff.spec.whatwg.org/#javascript-mime-type, checked 2026-10-26), case-insensitive with parameters dropped; cited in `pwa-checklist.md`. SKILL.md does not name the list, so it is unchanged.

**Evidence**
- Battery under `/bin/bash`, node and jq-only PATH, identical results, 12 lines every case. New cases: `inlinejs` (that exact page) PASS; `xecma` (`application/x-ecmascript`) PASS; `mimecase` (`TEXT/JavaScript1.5; charset=utf-8`) PASS; `commented` (old manifest link in a comment) still PASS on the real link. Earlier cases unchanged.
- Mutations 8/8 caught, including M7 (search the stripped page → `inlinejs` exit 1) and M8 (drop `x-ecmascript` and `javascript1.x` → `xecma`, `mimecase` exit 1); restore verified by checksum.
- Fixture preview 12/12 PASS, exit 0 (node and jq). `lint-skills.sh` clean; `lint-skills.test.sh` 77/77.

**Deferred**
- A page that only unregisters service workers (mentions `serviceWorker`, ships a stale `sw.js`) still reads as registered by inference: telling it apart needs JS execution.
