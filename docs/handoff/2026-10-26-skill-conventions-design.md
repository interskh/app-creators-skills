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

## Slice B — Whole-run gate verdict

Fresh whole-run reviewer: no blockers; three defects and a tail, fixed in round 1 (f7551aa); blocker-only rechecks PASS at f7551aa and e5b39dd; zh-fidelity 0 missing / 0 changed / 0 added on the full file and again on the changed lines. Codex (codex-companion, two passes): 8 MAJOR in pass 1 (seven fixed in round 1; the eval's Bash denial rejected as a run rule), 3 in pass 2 (two fixed in round 2; unregister-only page deferred). Full suite PASS after each fix commit (lint tests 77/77, lint clean, template lint clean, manifests parse, `claude plugin validate .` with the three known warnings). Fix-cycle cap (2) reached.

**Deferred at the cap (recorded, not fixed)**
- `check-pwa.sh` `strip_comments`: an unclosed `<!--` inside an inline `<script>` placed before the manifest `<link>` hides every later tag, so a valid page gets `FAIL manifest-link` and seven skipped FAILs. Fix idea: treat `<!--` as a comment only outside `<script>` elements, or strip only when a matching `-->` exists. Found by the reviewer at the second recheck; it came in with f7551aa.
- A commented-out `register('/old-sw.js')` before the real call is picked as the script URL (raw-page search; same as before f7551aa).
- `names-vercel` grader passes trivially because both prompts say the creator has a Vercel account; a stronger case needs a prompt without the account hint and a rerun.
- Nightly level-2 eval with `--allow-tools Bash`, the level-3 fixture run, and the live-URL proof: all wait for a fixture-only Vercel account (§3.4 credential boundary).

**Rejected**
- Codex: "both cases deny Bash while requiring `check-pwa.sh`" — the run rule forbids Bash until a fixture-only account exists; the README documents the ceiling and the nightly form.
- `vercel promote` in step 5: docs limit it to staged deployments.

## Follow-up — check-pwa.sh comment handling

**Decisions**
- F1: `strip_comments` finds the earliest of `<!--`, `<script`, `<style` (case-insensitive, name followed by whitespace, `/` or `>`); a script/style body is copied verbatim up to its `</script`/`</style` and never scanned for `<!--`. `<!-- <script> -->` stays a comment because the earliest opener wins.
- Bodies are kept, not blanked, so `page.html` serves both tag extraction (unchanged) and the page part of the registration haystack.
- F2: haystack = `page.html` + loaded scripts (newline between each), then `strip_js_comments`; `found`, the `sw_ref` grep, and the inference grep all read that cleaned file. The separate raw-page and per-script `found` greps are gone.
- `//` starts a comment only at text start or after whitespace, `;`, `{`, `}`, `(`, `,`; so `https://` survives.
- `/*` gets the same preceding-character guard, and an unguarded or unclosed `/*` is kept (copy two chars, keep scanning): `"image/*" … "*/*"` in a one-line minified bundle would otherwise wipe the register call between them (test case `globs`).
- No `metadata.version` bump: same 12 checks, same output lines; only which register call is picked and which tags are seen changed. `pwa-checklist.md` updated for both rules.
- Test: one `python3 -m http.server` per case on port 0 (port read from its `-u` stdout), files built with printf; 12 assertions over 11 sites. `urlsw` uses `http://127.0.0.1:<port>/app/sw.js` (local server; the `/app/` path makes a lost call visible, since the `sw.js` fallback would pass).

**Rejected**
- String-aware JS tokenizer: regex literals with quotes (`/'/`) flip its state on a minified one-line bundle, so it trades one false result for another at much more code.
- Applying JS stripping only inside page script bodies: needs a second HTML-aware pass; HTML text rarely holds `register(` and `//` after `"`/`=` is kept.
- One server for all cases in subdirectories: the cases use absolute `/sw.js` paths as on a real deploy.
- node static server: python3 is on ubuntu-latest and macOS; node is optional for check-pwa itself (jq fallback).

**Assumptions**
- ubuntu-latest's awk (gawk or mawk) handles `match` with a dynamic `[[:space:]/>]` regex; check: the CI step `check-pwa tests`. Only BWK awk (macOS) was run locally; no bash 5 or docker on this host.
- Python's `http.server` serves `.png` as `image/png` and `.js` as a JavaScript MIME type (3.12+: `text/javascript`).

**Deferred**
- A string holding ` // ` or ` /* … */` (space before) in a one-line bundle still strips text; the todo-vite fixture still passes 12/12. A real-app counterexample would justify a tokenizer.
- `>` inside a quoted attribute of the `<script>` open tag ends the tag early (pre-existing in `html_tags` too).
- Unregister-only page still reads as registered by inference (needs JS execution).

**Touches**
- `skills/publish-web/scripts/check-pwa.sh`, `skills/publish-web/references/pwa-checklist.md`, new `tests/check-pwa.test.sh`, `.github/workflows/lint.yml` (new step after the lint rule tests). SKILL.md/SKILL.zh.md untouched.

## Follow-up — `names-vercel` grader no longer trivial

**Decision:** both eval prompts drop the "I already have a Vercel account" sentence, so `names-vercel` (regex on the last message) checks that the skill names its default provider rather than echoing the prompt. The README grader line says so.
**Evidence:** rerun 2026-10-26 (claude 2.1.310, `--runs 1 --ablation none --scaffold --no-publish`, no Bash): vite-en 0.8 (9 turns), vite-zh 0.8 (10 turns), total $0.53; `names-vercel` and `asks-only-human-prerequisites` pass in both; `ran-verify-script` fails as the declared ceiling.
**Deferred:** `read-state` still passes on any Read naming `state.md`; a content assertion needs a grader type that can read the tool result.

## Follow-up — gate fix round 1

**Decisions**
- JS comment removal runs only on JavaScript: each inline `<script>` body inside `strip_comments` (one `js_reset()` per body) and each loaded script in its own awk run, appended to the search text. HTML and CSS text are never JS-stripped; nothing is concatenated before stripping.
- Scanner: one pass over `split(t, ch, "")`, shared as `js_awk` by both functions. States: code, `'`/`"`/backtick string with backslash escapes (backtick spans lines, the others resync at a newline), line comment, block comment (unclosed runs to the end of that script), regex literal with `[...]` classes. `/` starts a regex after `( , = : [ ! & | ? { } ;` or at input start. Comments print one space; newlines inside are kept.
- `split` instead of `substr(s, i, 1)`: BWK awk's `substr` measures the whole string each call (12 s for an 0.87 MB char loop vs 0.3 s with `split`); mawk and gawk accept the empty separator too.
- Closing tags need `>`, `/`, or whitespace after `</script` / `</style`; `/` is included because the HTML tokenizer ends the end-tag name on it.
- `page.html` (tag extraction) now carries the JS-stripped inline bodies too: one output, no mode flag. Tag text inside an inline JS comment is now ignored, which is correct.
- `crossscript` uses `var s="/*";var b=1;/*` (string with `/*`, then an unclosed block comment) rather than a script ending inside a string: the scanner resyncs an unterminated `"` at the newline, so only the unclosed `/*` tells per-script stripping from concatenation. It passes on 506d2b6 too; the "scripts stripped as one text" mutant guards it.
- Correction to the previous entry: its preceding-character guard (and the Rejected note that `//` after `"` or `=` is kept) no longer applies; `//` outside a literal is always a comment, after `)` too.

**Rejected**
- Keeping the guard heuristic: cases (a)–(d) from the gate fail under it.
- perl or node for scanning: perl is not a listed prerequisite, node is optional (jq fallback).
- Building output by string concatenation: quadratic in BWK; `printf` per char costs 0.6 s per MB.

**Evidence (timings, BWK awk 20200816)**
- Synthetic 1.16 MB one-line script, 20k `https://` tokens: 1.20 s. Same text inline in a page through `strip_comments`: 1.21 s.
- Real Vite bundle (a local app's `dist/assets/index-*.js`, 1.23 MB): 1.24 s, size unchanged, no text lost. Fixture `dist` scripts: under 0.02 s each.

**Assumptions**
- mawk and gawk on ubuntu-latest split on `""` into characters; check: CI step `check-pwa tests`.

**Deferred**
- A regex literal after a keyword (`return /x/`), after `)` (`if (x) /re/.test(y)`), or after an operator outside the start set reads as division; nested templates inside `${…}` are not tracked; non-JS script types (`importmap`, `text/template`) are JS-stripped too. Each only matters if a `//` or `/*` sits in that text.
- Limits documented in `pwa-checklist.md`: `<script` inside a quoted attribute value; a `<script>` with no closing tag.

**Touches**
- `skills/publish-web/scripts/check-pwa.sh`, `skills/publish-web/references/pwa-checklist.md`, `tests/check-pwa.test.sh`. No version bump: same checks and output.

## Follow-up — gate fix round 2

**Decisions**
- Regex start also after a keyword: the scanner keeps the last identifier (`word`, contiguous `[A-Za-z0-9_$]`); a `/` whose previous non-space char ends that identifier starts a regex when it is one of `return typeof instanceof in of new delete void throw case do else yield await`.
- `${…}` tracking: `${` in a backtick string pushes a level (`sp`, `dep[sp] = 0`) and returns to code mode; `{`/`}` adjust `dep[sp]`; a `}` at depth 0 pops back into the template string. Nested backticks, strings, comments, and regexes inside work as in code.
- Identifier test uses `index()` on a 64-char set rather than a regex per char; the 1.23 MB bundle stays at 1.46 s.
- Correction to the round-1 entry: "Each only matters if a `//` or `/*` sits in that text" is wrong. A missed regex or template boundary flips string/code state for the rest of that script line, so a later URL string can be read as a comment and hide a `register(` call. `pwa-checklist.md` now says so.

**Rejected**
- Treating `/` after `)` as a regex: `(a)/2` is division and common in minified code; telling `if(x)/re/` apart needs a parser.

**Evidence**
- Real Vite bundle (1.23 MB): 1.46 s; output equals the input plus one trailing newline. A local `react-dom-client.production.js` (536 KB, 16k lines): 0.53 s, only the React license block and the Modernizr license line removed (12 lines), `node --check` parses the output.

**Deferred**
- `if(x)/'/.test(y);var u='https://x.example/';…register(…)` (a regex after `)`) still fails `service-worker-registration`; kept out of the suite.
- Regex after `]` or a non-keyword identifier, and `a.return/x/` (a keyword used as a property, read as regex), stay heuristic.

**Touches**
- `skills/publish-web/scripts/check-pwa.sh` (`js_awk` only), `skills/publish-web/references/pwa-checklist.md`, `tests/check-pwa.test.sh` (cases `regexkeyword`, `nestedtpl`).

## Follow-up 2 — check-pwa.sh fetch-verified registration and tag-aware scan

**Decisions**
- G1: candidates = quoted `serviceWorker.register(...)` URLs from the stripped haystack, then from a raw haystack (raw page + raw loaded scripts), deduped in order, cap 5; the first served with `is_js_mime` wins. The comment pass is now an ordering heuristic, not a correctness gate.
- No JS candidate: a stripped `register(` (or a `registerSW.js` tag) reports the first candidate (else `sw.js`) and `service-worker-script` fails as before; then the `sw.js` inference branch; only after that a raw-only candidate is reported. Inference goes before raw-only so a commented-out call to a missing script cannot displace a working inferred `sw.js`.
- `registerSW.js` detection reads the tag text (`page.tags.html`), not the haystack, so the name inside script text (after `<script src="/x.js"/>`) is not a loaded script.
- G2: `strip_comments` splits the page into chars once, walks HTML text, reads each tag to `>` (a quote opens only right after `=`), and recognises `script`/`style` by the full tag name. A second output (`$2`, `page.tags.html`) carries HTML text without script/style bodies; `html_tags` reads it. Behaviour change, not an assertion of old behaviour: before, a manifest link inside an unclosed `<script>` or after `<script src/>` PASSed because bodies were scanned for tags.
- Output emitted from 8 KB blocks and `js()` now walks an array range, so cost is linear: no whole-string `substr` per comment (BWK measures the whole string each call) and no `s = s $0` read loop (0.74 s on a 12k-line page).
- G3: PASS lines read `<url> (static scan)` and `<url> (inferred from sw.js, static scan)`; check names unchanged. SKILL.md and SKILL.zh.md list check names only, no quoted registration line: untouched. SKILL-CONVENTIONS.md has no bump rule beyond `version`; following earlier entries, output wording only = no bump.
- G4 cases added: `parenregex` (12 PASS), `parenregex-oldsw`, `inferred`, `attrscript`, `attrgt`, `unclosedscript`, `selfclosescript` (reviewer's `script_selfclose_unclosed`), `selfclose-registersw`, `multilineblock`, `commentstar`, `upperscript`, `strsep-inline`. Dropped as duplicates: `css_protorel_oneline` and `attr_style_protorel` (both in `oneline-url`), `nested_template` (`nestedtpl`), `return_regex_quote` (`regexkeyword`), `js_axios_accept` (`globs`), `paren_regex_quote` (`parenregex`).
- `attrgt` exists because `attrscript` passes without quote handling (the tag scan alone consumes `<script>`); only a `>` inside a quoted value tells them apart.

**Rejected**
- Headless-browser mode: heavy dependency (Chromium) and out of scope for a POSIX-tools check.
- Script-data escape states (`<!--` / double-escaped `<script>` inside a script body): a spec tokenizer for a rare pattern; listed as a limit.
- Accepting a raw-only candidate before inference: regresses lazy-chunk apps that also keep a commented-out old call.
- Blanking script bodies in the single output: the haystack needs inline bodies; two outputs from one pass cost nothing extra.

**Assumptions**
- Python `http.server` serves `.js` as a JavaScript MIME type (test fixtures rely on it, as before).
- A real page rarely keeps a commented-out call to an old script that is still deployed while the live one fails; if it does, the old URL is accepted. Check: the `pwa-checklist.md` limit line.

**Evidence**
- `tests/check-pwa.test.sh` 34/34 and `tests/lint-skills.test.sh` 77/77 under (a) `LC_ALL=C /bin/bash` + BWK awk 20200816, (b) bash 5.3.20 + GNU Awk 5.4.1, (c) bash 5.3.20 + mawk 1.3.4 (temp dir first on PATH with `awk` and `bash` symlinks, so check-pwa ran under them); `scripts/lint-skills.sh` clean under (b) and (c).
- Timings (BWK): Vite bundles 1.23 MB 1.54 s, 1.37 MB 1.71 s; 1.16 MB inline page 1.35 s; 1.35 MB page with 12k tags and 12k comments 1.2 s. `page.html` byte-identical to the previous version on those pages and the fixture `dist/index.html`.
- Fixture `todo-vite` build + `npm run preview -- --port 4179 --strictPort`: 12/12 PASS, exit 0.
- Mutants: no fetch verification → `parenregex-oldsw`, `selfclosescript` fail (`parenregex` alone has one candidate, so it cannot catch this); no raw fallback → `parenregex`, `parenregex-oldsw` fail; no quoted-attribute handling → `attrgt` fails; tags read from text with bodies → `unclosedscript`, `selfclosescript`, `selfclose-registersw` fail; `registerSW.js` searched in script text → `selfclose-registersw` fails. 5/5.

**Deferred**
- Runtime-only behaviour (unregister-only page, registration behind a runtime branch), non-JS `<script type>` and ignored `<script src>` bodies scanned as JS, script-data escape states, and RCDATA/RAWTEXT elements other than script/style (`textarea`, `title`, `noscript` with scripting on) not special-cased. All in `pwa-checklist.md` except the last.
- Correction to earlier Deferred lists: "`>` inside a quoted attribute", "`<script` inside a quoted attribute value", "a `<script>` with no closing tag", and the `parenregex` failure no longer apply.

**Touches**
- `skills/publish-web/scripts/check-pwa.sh` (`js()` signature now `(array, from, to)`, `strip_comments` takes a second path), `skills/publish-web/references/pwa-checklist.md`, `tests/check-pwa.test.sh` (`reg_line` now expects ` (static scan)`).

## Follow-up 2 — eval graders that cannot pass for the wrong reason

**Decisions**
- `read-state` is an `llm` judge on the trace: PASS only if `.app-creators/state.md` was read and its Vite + web facts were used instead of asked for. The old `tool_used: Read` grader passed on any Read naming `state.md`, even against an empty workspace.
- `names-vercel` is an `llm` judge on the final message: PASS only if Vercel is recommended as the deployment path; a mention or a rejection fails. The old substring regex could not tell them apart.
- Both fixture `state.md` files now record `accounts.vercel: missing` (allowed values per spec §4.1: `has | missing`). With `has`, the earlier run's final message cited "state.md says you have a Vercel account", so the recommendation was partly an echo of the state file. With `missing`, it can only come from the skill's default, and asking for the account is a human prerequisite the `asks-only-human-prerequisites` judge allows.
- Grader field spelling (`focus: trace` / `focus: last_message`, three-vote majority) checked against the plugin-evals doc on 2026-10-26.

**Evidence**
- Run with `has` and the new judges: vite-en 0.8 (10 turns, `read-state` 2/3 votes), vite-zh 0.8 (9 turns, 3/3), $0.43.
- Run with `missing`: vite-en 0.8 (6 turns), vite-zh 0.8 (8 turns), every judge 3/3, $0.39. `ran-verify-script` fails in both as the declared no-Bash ceiling.

**Deferred**
- Nightly run with Bash, the level-3 fixture run, and the live-URL proof still wait for a fixture-only Vercel account.

**Touches**
- `evals/publish-web/vite-en/{case.yaml,state.md}`, `evals/publish-web/vite-zh/{case.yaml,state.md}`, `evals/publish-web/README.md`.

## Follow-up 2 — gate fix round 1

**Correction:** the Follow-up 2 claim that fetch verification stops a misread regex from hiding a registration is withdrawn. Accepting raw-text candidates passed a commented-out `register("/sw.js")` whenever `sw.js` still shipped, which is the common "SW disabled, file still deployed" state.

**Decisions**
- Fail closed. L = quoted `register(` URLs in comment-stripped JS only (inline bodies + loaded scripts); R = URLs only in raw text. L non-empty: first JS-MIME response of up to 5 wins, else the first L URL is reported and `service-worker-script` fails (line notes "first 5 of N" past 5); R and inference are never consulted. L empty: a `<script src>` ending in `registerSW.js`, then `sw.js` inference, then FAIL; with R non-empty the FAIL names the first R URL.
- `strip_comments` stdout is now the JS bodies only (HTML prose like `<p>registerSW.js</p>` no longer feeds the search); tag text still goes to `page.tags.html`.
- `html_tags` is a char-level tag reader sharing `html_awk` (`tag_end`, `tag_name`, char reading) with `strip_comments`; attributes parsed as name, optional `=`, quoted/unquoted value, first occurrence wins; URL values lose tabs/newlines and outer spaces.
- Candidate URLs resolved before dedupe (`./sw.js` = `/sw.js`); all lists go through temp files, no `head` in a pipeline under pipefail.
- Block size scales with input (`max(8192, size/64)`), so the remainder copy is bounded at ~64 per line.
- Harness: every case also asserts `PASS html:`; a `: skipped:` line satisfies only a regex that names `skipped`.

**Rejected**
- Keeping raw candidates behind fetch verification: the false PASS above outweighs the regex-after-`)` gain; the failure message now names the hidden URL instead.
- `awk 'NR == FNR'` for the raw-minus-live set: wrong when the live file is empty (all raw lines read as the first file); uses `getline` in BEGIN.

**Evidence**
- `check-pwa.test.sh` 44/44, `lint-skills.test.sh` 77/77 under BWK awk + `/bin/bash`, gawk 5.4.1 + bash 5.3.20, mawk 1.3.4 + bash 5.3.20; `lint-skills.sh` clean under the latter two.
- Fixture `todo-vite` preview 12/12, exit 0. Bundles 1.23/1.37 MB: 1.54/1.66 s; tag-heavy 1.35 MB page 1.26 s; single-line pages 0.89/1.79/3.59 MB: 1.09/2.19/4.58 s (linear).
- Mutants 9/9 caught: no fetch verification (2 cases), R never computed (4), no quoted-attribute handling (2), manifest from raw page (5), `registerSW.js` matched in text (3), JS comment detection off (6), R accepted (5), inference when L fails (1), attribute name needs preceding whitespace (1).

**Deferred**
- The cap of 5 can report a 404 when only a 6th live URL is deployed (the line says so).
- A regex literal after `)`/`]` can still hide a live call; it fails closed with the URL named.

**Touches**
- `check-pwa.sh` (`html_awk` new; `strip_comments` stdout semantics; `html_tags` rewritten; SW section), `pwa-checklist.md`, `tests/check-pwa.test.sh` (`raw_line`, `inferred_line`, `expect` html/skipped rule; 11 new cases).

## Follow-up 2 — gate fix round 2

**Decisions**
- Inline event-handler attributes are live JS: in `strip_comments`, every opening tag whose text contains `on` gets `attrs()`; each attribute named `on*` (first occurrence, document order via `AN[]`) is entity-decoded (`&quot; &#34; &#x22; &#39; &#x27; &apos; &lt; &gt; &amp;`, left to right, so `&amp;quot;` stays `&quot;`), run through `js()`, and appended to stdout. The fail-closed rule is unchanged; raw-only URLs are still never accepted.
- `attrs()` moved into the shared `html_awk`; `unent()` decodes by `index`/`substr` instead of `gsub`, because `&` in a `gsub` replacement differs across awks.
- Cases: `onload-attr` (12 PASS), `onload-attr-entities`, `onload-commented`.

**Rejected**
- Decoding all HTML entities: the five plus `&apos;`/`&#x27;` cover minifier output; numeric and named entities beyond them are rare in handler code.

**Evidence**
- 48/48 and 77/77 under all three interpreter pairs; `lint-skills.sh` clean under gawk and mawk; fixture preview 12/12, exit 0. Bundles 1.56/1.69 s (unchanged); 12k-tag page 1.47 s (was 1.26; the `on` prefilter keeps `attrs()` off most tags).
- Mutants 11/11: the nine from round 1 plus on* values skipped (4 cases) and entities not decoded (1).

**Deferred**
- Other entity forms (`&QUOT;`, `&#0034;`) inside handlers are not decoded: such a call is not seen as a quoted URL, so the page falls to `sw.js` inference (it still mentions `serviceWorker`) or FAILs.

**Touches**
- `check-pwa.sh` (`html_awk`: `attrs`, `unent`; `strip_comments` tag branch), `pwa-checklist.md`, `tests/check-pwa.test.sh`.

implement-loop: slice B deferred: level-3 run and live-URL proof await a fixture-only Vercel account (B.1, B.2, fixture, eval case shipped e5b39dd); remaining: [C]

## Slice C — Task 1 — docs/STATE.md

**Decisions**
- Both YAML blocks copied verbatim from spec §4.1 (lines 233-286, 333-338) and checked by `diff`; the enum keeps `xcode` (not `swift`) for Xcode projects because the schema is copied, not redesigned.
- Rules split into one short section each (unknown, evolution, readiness validity, ownership, routing intent, write discipline, migration), paraphrased closely so the spec stays the single source.
- Field table: one row per concrete field, wildcard rows only where values are uniform (`targets.*.intent`, `targets.*.detected`, `readiness.*.*`, `tools.*`); per-platform `status` rows because their enums differ.
- `updated` set by "the skill that writes the file"; `history` by "every skill that writes" (spec is silent on `updated`; write discipline implies it).
- Header mirrors `SKILL-CONVENTIONS.md` ("If the two disagree, the spec wins").

**Rejected**
- One wildcard row for `targets.*.status`: would hide that iOS has `testflight` and Android `testing`.
- Restating `publish-web`'s exact `## Update state` values: duplicates the skill; table only names it as today's writer.

**Assumptions**
- `app.slug` and `app.languages` are set by `app-creators` (detected class; any skill may re-detect). Check against §3.6 when `app-creators` ships.

**Deferred**
- No `app-creators` skill exists yet; "Who creates it" describes the contract it must follow.

**Touches**
- `docs/STATE.md` (new), `README.md` (one Contributing line). No skill, lint, or test file.

## Slice C — Task 2 — app-creators SKILL.md and SKILL.zh.md

**Decisions**
- Detection: root listing only, first match wins: expo → flutter → xcode → kotlin → nextjs → vite → static → unknown (ask; `evidence: "creator"`). Enum is `xcode` per STATE.md.
- Expo row follows the Expo app config reference, not the brief: properties sit under the `expo` key in `app.json`/`app.config.json` but at the top level of `app.config.js`/`.ts`, so the row is "`expo` key in app.json/app.config.json, or `expo` in `package.json` `dependencies`". A bare `app.config.ts` is not evidence (other frameworks use that name).
- Intent mapping per STATE.md field notes: named → `wanted`, declined → `not-wanted`, unmentioned → `undecided`. outcome → `goal` (publish/acquire/monetize).
- First run: recorded outcomes `unknown` (`targets.*.status`, `readiness.*.result`); `url`/`provider`/`domain`/`bundle_id`/`asc_app_id`/`package`, `accounts.*`, `tools.*`, `monetization.model` → `""`. `provided` is written as the STATE.md map with both `publish-readiness` leaves `""`, not a bare `""`.
- Slug: drop an npm `@scope/` prefix before kebab-casing.
- zh glossary: outcome 目标, destination 目标平台, detect 识别, not shipped yet 暂未提供, detected/provided facts 识别类事实/提供类事实, schema major 主版本号.
- Token parity: check_tokens.py exit 0; 119/119 distinct inline spans, 238/238 occurrences; only count-only note is number `0.1.0` (en frontmatter `version`, zh has no frontmatter). Example YAML block byte-identical (diff), parses with PyYAML.

**Rejected**
- `app.config.js/ts` alone as an Expo signal: SolidStart and others ship `app.config.ts`.
- Edit-tool partial writes on rerun: write discipline is one whole-file write.

**Assumptions**
- `Package.swift` with an `executableTarget` → `xcode` also catches CLI-only packages (brief mandates the row). Check when `publish-ios` ships.
- `monetization.model: ""` is outside the STATE.md enum, but the brief and the "unknown is `""`" rule allow it. Check: STATE.md field table row for `monetization.model`.
- Sources: Apple and swift.org human URLs are JS shells; content was confirmed through their `tutorials/data` / `data` JSON twins. Re-check with the same JSON paths.

**Deferred**
- Eval case and level-3 run (C.3). Expected output on fixture `todo-vite` @ 95c2f95: `framework.kind: vite`, `evidence: vite.config.ts` (no app.json/pubspec/xcodeproj/gradle/next.config; `index.html` loses to row 6), `package_manager: npm` (package-lock.json), `slug: todo-vite`, `languages: [en]`, web `"yes"`, ios/android `"no"`, next skill `publish-web`.
- Migration branch (c) has no mapping until a schema major 2 exists.

**Touches**
- `skills/app-creators/` (new: SKILL.md, SKILL.zh.md, references/verified-runs.md from the template), `README.md` (Skills row, "Two skills so far").

## Slice C — Task 3 — app-creators eval cases

Result (claude 2.1.310, 2026-10-26; `--case 'app-creators-vite-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --max-cost-usd 3 --allow-tools Write`, one run): app-creators-vite-en 1.00 (11/11, 8 turns, $0.16); app-creators-vite-zh 1.00 (11/11, 10 turns, $0.23); both llm judges PASS 3/3 in both cases; total $0.39, 74 s, `partial: false`, exit 0. No second run needed.

**Decisions**
- Case names `app-creators-vite-en`/`-zh` (dirs stay `vite-en`/`vite-zh`): `--case` and the report key on name, and publish-web owns `vite-*`.
- `Write` listed in `allowed_tools` and granted with `--allow-tools Write` (last, variadic). No Bash (detection needs none), no AskUserQuestion (a question dead-ends an unattended run).
- Regexes: scalars anchored `^...$` with `flags: m`, optional quotes; `intent`/`status` anchored to the `web:` block by backreferencing its indent (`^([ \t]*)web:` then only deeper-indented lines), so ios/android values cannot satisfy them. `schema-1-0` kept as its own grader (11 total). Patterns parsed from the real case.yaml (PyYAML) and tested with node: pass the SKILL.md example and its CRLF form; reject web `intent: undecided` with ios `wanted`, web `status: deployed`, and wrong kind/pm/slug/goal/schema.
- Grader-asserted: `framework.kind`, `framework.package_manager`, `targets.web.intent`, `app.slug`. Only covered by the SKILL.md example block (no grader): `accounts.vercel`, `readiness.web`.
- Last-message judge allows mentions of skills labelled "not shipped yet"/暂未提供, so the routing table's honest labels do not read as invented names.

**Rejected**
- Unanchored `web:\s*\n(?:[ \t]+.*\n)*?[ \t]+intent:` (brief's sketch): lazily crosses into the ios block and passes when web is `undecided` but ios is `wanted`.
- Graders for `accounts.vercel`/`readiness.web`: brief fixed the grader list; both are first-run constants.

**Assumptions**
- `file_exists` counts the Write-created file even though the Write tool also creates `.app-creators/`; confirmed by the run.

**Deferred**
- Multi-run stability (`--runs 3`) and a two-arm baseline; one run is the level-2 bar here.

**Touches**
- `evals/app-creators/` (new: README.md, vite-en/{case.yaml,scaffold.sh}, vite-zh/{case.yaml,scaffold.sh}; scaffolds are publish-web's minus the state.md copy, mode 755). No skill, lint, or test file.

**Proof** ("never asks for the framework twice"): this run shows app-creators writing the four publish-web inputs it owns (grader-asserted) without asking for the framework; publish-web's own eval shows it reading state.md instead of asking. `accounts.vercel` and `readiness.web` are set by other actors and only appear in the written file per the example block.

## Slice C — Gate fix round 1

Reviewer D1–D5 and Codex MAJOR/MINOR labels were not passed to this round; fixes keep the brief's 1–11 numbering.

**Fixes**
1. Rerun asks only `goal` (when `""`) and `targets.*.intent` (when `undecided`); name/description only if offered; never `accounts.*`/`tools.*`/`monetization.model`/`provided.*`. Branch (b) and the Troubleshooting row now say the same.
2. Rerun with table `unknown` and stored `evidence: creator` keeps `framework.kind`/`package_manager` and does not re-ask (branch (b), step 1 Alternative and its `unknown` sentence); a real match overwrites.
3. `schema: "1.0"` on create only; rerun keeps the existing major-1 value (no minor downgrade). Verify bullet adjusted so a preserved `"1.1"` does not fail it.
4. Kotlin row: id or version-catalog alias (`gradle/libs.versions.toml`); `settings.gradle(.kts)` clause removed; step 1 lists `gradle/` as a readable subdirectory. Source added: Android "migrate your build to version catalogs".
5. Flutter row: requires `flutter` (`sdk: flutter`) in `dependencies`; else plain Dart package, continue. Grounded in the cited pubspec page.
6. Expo destinations from `expo.platforms`. Deviation from the brief: the Expo reference says the default is `["ios", "android"]`, plus web only if `react-dom` is installed; the skill states that, not "ios, android, web". `web`-key test dropped. JS/TS configs fall back to the default.
7. Step 4: the example is complete and sufficient when `docs/STATE.md` is not installed with the skill.
8. 223/201 lines; `metadata.version` stays `0.1.0` (skill unreleased; no consumer pins it).
- STATE.md (unnumbered in the brief): `""` allowed for `accounts.*` and `monetization.model`, with the first-run note.
9. Eval regexes scoped to the frontmatter, start-anchored with `(?<![\s\S])` (without it, `^---` re-anchors on the closing line and scans the notes); trailing comments and blank lines in `web:` allowed.
10. Outcome judge now `focus: trace`: final reply names `publish-web`, no assistant message claims an external outcome.
11. README fixed for `allowed_tools`/`--allow-tools Write`, the judge's new focus, and the frontmatter-only regex scope.

**Rejected**
- None.

**Resolved**
- Task 1 Deferred "No app-creators skill exists yet" and its `app.slug`/`app.languages` assumption: the skill sets both. Task 2 `monetization.model: ""` assumption: the STATE.md row now allows `""`.

**Deferred**
- Swift CLI `Package.swift` with `executableTarget` is detected as `xcode`.
- SvelteKit/Remix match the `vite` row and publish-web assumes a Vite SPA: a limit of the spec enum.
- Flow-style `web: {…}` fails the block regexes; the skill writes block style.

**Evidence**
- Regex test (`node regex-test.js`, scratch): both cases (a) example 7/7 pass, (b) comment + blank line in `web:` 7/7 pass, (c) wrong frontmatter + correct notes 7/7 fail, (d) CRLF 7/7 pass. Mutants (anchor removed; `---` stop removed) pass (c), so the test catches both.
- `lint: 2 skills clean`; `PASS 77/77`; `claude plugin validate .` passed (pre-existing CLAUDE.md and icon warnings); check_tokens exit 0 (only count-only note `0.1.0`).
- Eval (one run): vite-en 1.00 (11/11, 7 turns, $0.16), vite-zh 1.00 (11/11, 8 turns, $0.24), both judges 3/3 PASS; total $0.40, 74 s, `partial: false`.

**Touches**
- `skills/app-creators/SKILL.md`, `SKILL.zh.md`, `docs/STATE.md` (4 table rows), `evals/app-creators/{README.md,vite-en/case.yaml,vite-zh/case.yaml}`.
