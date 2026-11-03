# Handoff: 2026-11-02-slice1-publish-design

## Slice D / T1 todo-expo fixture

Expo SDK 58 (expo ~58.0.19, RN 0.88.0). Docs checked 2026-11-02: https://docs.expo.dev/versions/latest/sdk/imagepicker/ and https://docs.expo.dev/develop/user-interface/app-icons/

**Decisions**
- Generated with `create-expo-app@latest -t blank-typescript --no-agents-md --no-install`; it is inside an existing git repo so it ran no `git init`. Deps via `npx expo install` (image-picker, async-storage).
- Persistence is AsyncStorage; photo is stored as a URI only (fixture, not a production-grade copy to document dir).
- Plugin config: `photosPermission` with a specific string, `cameraPermission: false`, `microphonePermission: false` (doc: false blocks CAMERA / RECORD_AUDIO on Android). App only calls `launchImageLibraryAsync`.
- Template `assets/icon.png` is already 1024x1024, colour type 2, no tRNS: kept as is. Adaptive foreground/background 512x512, monochrome 432x432 (all RGBA, fine): docs say at least 512 and background must match foreground dims; no exact adaptive size is stated.
- Deleted the template `LICENSE` (Expo copyright, MIT); todo-vite has none and the repo has its own.

**Rejected**
- Replacing template icons: they already meet the docs. Camera permission left on: app does not use it.
- `.gitleaksignore` entry: not needed; the lockfile has zero `deprecated` notices, grep for emails and home paths is empty, `privacy-scan --staged` rc=0.

**Assumptions**
- `splash-icon.png` (indexed, tRNS) is not referenced by app.json, so the alpha rule does not apply; recheck if a splash plugin is added.
- Doc text was read from rendered HTML via curl; adaptive-icon sizes beyond the quoted lines may exist in Android guidelines.

**Deferred**
- No device or simulator run; only `expo export --platform ios` bundling. No EAS config by design.

**Touches**
- fixtures repo: `todo-expo/` (new), root `README.md` (one bullet). No shared config; `.gitleaksignore` unchanged.

## Slice D / T2 check-readiness.py

**Decisions**
- Expo `icon-alpha` FAILs on an alpha channel although `withIosIcons.ts` flattens light and tinted icons onto white: Expo's docs say no transparent pixels, and a white fill silently changes the icon. The fix text says so.
- Expo API with no plugin option and no `ios.infoPlist` key FAILs `permission-strings`, although the plugin writes a boilerplate string (`Permissions.ts`): Expo's permissions guide says defaults likely need tailoring, Apple 5.1.1(ii) requires purpose strings that describe the use. This is what makes the seeded `photosPermission` removal fail.
- `com.example` flagged on Android only, from the Play Console error in a Google-hosted community thread (raw page fetched). No iOS store rule found; Flutter's `build_ios.dart` warning is tooling.
- Native folder wins for Expo unless listed in `.gitignore` or `.easignore`: the CNG page says EAS runs no Prebuild when the folders exist, and shows ignoring them to get fresh ones.
- `.icon` gives `UNKNOWN` on `icon-sizes` and `icon-alpha`: Xcode renders it at build time, and it replaces the asset catalog when its name matches the app icon setting.
- Android bases: legacy 48 dp and adaptive 108 dp at the density ratios. 108 is in Android docs; 48 as a launcher base is in Expo's `withAndroidIcons.ts` only, Android shows it only as a density example.
- Expo Android: `auto` permissions fail only when blocked; calendar and background location need declaring. Monochrome layer only has to be square, because T1's fixture ships 432x432 and the docs state 512 for the icon.
- Flutter `permissions-declared` also scans `.kt` and `.java` under `android/`: the first-party plugins list no manifest step, so Dart has no Android row. This extends the brief's `.dart` scan so a gap can be seeded.
- Next.js literal `metadata.title` is read as text; anything non-literal is `UNKNOWN`. This keeps a default Next app from an `UNKNOWN` name.
- Comment stripper respects strings, so a URL in gradle or JS neither unbalances braces nor hides an API after it.
- pbxproj object index only keeps blocks with `isa`: real `TargetAttributes` reuse the target id and overwrote it. Found by running on Expo's real template; regression is in the test tree.

**Rejected**
- `defusedxml`, flagged by a security hook: the contract is standard library only, and input is the creator's own project.
- Decoding PNG pixels to tell an opaque RGBA file from a transparent one: the validator message names the channel, and the brief says colour type and tRNS.
- `UNKNOWN` for native `icon-alpha` for lack of an Apple doc page: the brief's test matrix needs `FAIL`. See Assumptions.
- `UNKNOWN` for Flutter on Android when no API is detected: the table limit is stated in `references/checks.md`, as the brief allows.

**Assumptions**
- Native `icon-alpha` rests on Apple's validator message ("can't be transparent or contain an alpha channel"), read only in a search listing of Apple Developer Forums threads. The thread pages return a bot check to curl, and no Apple documentation page fetched states it. Check: an upload of an RGBA icon, or Apple text if one surfaces.
- `com.example` rests on a community thread quoting the console, not a policy page. Check: try creating a Play app with that id.
- Source dates are UTC. Local clock passed midnight during the fetches; every fetch is 2026-11-02 UTC.
- Real-file check was on fetched Expo and Flutter template files only, with placeholders; no real Xcode, Android Studio, or Flutter build ran here.

**Removed or left out for lack of a source**
- Flutter `google_maps_flutter` location row: no permission text on its pub.dev page.
- A 15-character limit on `CFBundleName`: stated as "can contain", no store rule, so no check.
- `com.android` and other id prefixes: nothing sourced.
- Permission rows for third-party Flutter plugins such as `permission_handler`: not first party.

**Deferred**
- An opaque RGBA Expo icon fails, though Expo would flatten it harmlessly. Safe: the fix is a re-export.
- Gitignore matching is exact-line, no globs. Safe: a miss reads the native folder, which is what a local build uses.
- `recordAudioAndroid: false` counts as blocking `RECORD_AUDIO` even if another module adds it. Safe: it can only over-report on an unusual config.

**Touches**
- New: `skills/publish-readiness/` (skeleton from `new-skill.sh`, `metadata.stage: publish`, `metadata.platform: all`), `scripts/check-readiness.py`, `references/checks.md`, `tests/check-readiness.test.sh`.
- `.github/workflows/lint.yml`: one step. Check ids and CLI are read by T3's `SKILL.md`.

**Kill rate**
- mutations: 23/23 caught, after closing two gaps the first pass (21/23) found: dark-appearance entry ordered first; nested target id written after the target. Restores verified by sha256.

## Slice D / T3 skill, evals, routing

**Decisions**
- Flutter smoke run departs from §3.4's wording: Flutter's build-modes page says release mode is not supported on a simulator or emulator. It builds release, launches only on a physical device, and otherwise stays `unknown`; a debug launch never counts.
- Xcode route's launch is Xcode's UI (scheme Run action set to Release, Product > Run), done by the creator: no fetched Apple source documents `simctl install`, `simctl launch`, or `xcodebuild -configuration`, and the machine has no man page for them. Removed as from memory.
- Play age rating ids are this skill's own topic ids (`play_*`). IARC's FAQ says the questionnaire exists only inside storefront portals, so no stable question ids can be sourced. App Store ids are the API's `AgeRatingDeclaration` attribute names.
- `history`: one row on the first write of a run, one more only if answers change the result. Rows are append-only and a run writes twice.
- A confirmation in the prompt counts only once the scan agrees, so `web-nodata` needs no second turn and a wrong claim is surfaced.
- `git` failure is its own Troubleshooting row, from a verified run: under the eval's OS sandbox `/usr/bin/git` exits 72 on this machine, and a real binary works.
- A platform block in `readiness.md` from another run is kept only when the recorded revision is current, because the file has one `revision`.
- An empty `revision` or a failing git command counts as not current in `publish-web`, so a `fail` recorded with no commits does not stop it. §4.4 stops only "at the current revision".
- `docs/launch/awesome-lists.md`: drafts now say three skills; the dated snapshot and `Public Evidence` line stay, with a note to rerun install commands after push.

**Rejected**
- A `clean-tree` check id: the brief fixes the judgment checks, and the rule already reads the revision separately. The reason goes in the notes below the frontmatter.
- Asking `unknown` inventory fields at submission: §4.1 says forms never come from a new interview, so the review here asks them.
- Mapping Apple's frequency answers from `INFREQUENT_OR_MILD`: allowed by the API, absent from the help tables.
- `--keep-temp` runs as evidence: used only to diagnose. Scores below are from plain runs.

**Assumptions**
- Eval rows count as level 3, per the brief. They ran `check-readiness.py` and wrote the report through a real agent session on the fixtures; nobody answered a question and no fix was applied.
- `calendar events` and `installed apps` map to App Privacy `Other Data Types`, and `files and documents` to `Other User Content`: Apple lists no closer type. Check at the first real submission.
- `java -version` and `xcodebuild -version` as toolchain checks rest on running them here, not on a vendor page.
- TN2339 is the only Apple page found for `xcodebuild -list`; it was last revised 2017.

**Deferred**
- No lint rule for README route status: Slice E item 3.
- The second turn (answers, an agreed fix, rerun after commit) has no eval: runs cannot answer. `evals/publish-readiness/README.md` says so.
- Dynamic Expo config has no skill-level eval; `tests/check-readiness.test.sh` covers `--expo-config`.
- `check-readiness.py` unchanged: no eval showed a defect.

**Touches**
- New: `skills/publish-readiness/references/{data-inventory,age-rating,smoke-run}.md`, `evals/publish-readiness/`. Rewritten: `skills/publish-readiness/SKILL.md`, `SKILL.zh.md`, `references/verified-runs.md`.
- Shared: `docs/STATE.md` (readiness validity), `skills/publish-web/` gate and `0.1.2`, `skills/app-creators/` routing and `0.1.1`, `evals/app-creators/` grader rename, `README.md`, `llms.txt`, `.claude-plugin/*.json`, `docs/ROADMAP.md`, `docs/launch/awesome-lists.md`.
- `age_rating.answers` ids and `readiness.md` shape are read by the later publish skills.

**Eval results (`--no-publish`, `--model sonnet`, reports under gitignored `evals/results/`)**
- `publish-readiness-*`, final skill except for one wording change in Step 7: `evals/results/2026-11-02T17-05-58-398Z/aggregate-result.json`, 8 cases, $1.58. 1.00 on 7; `expo-gaps-en` 0.88 (`reply-names-three-gaps-with-fixes`, votes FAIL FAIL PASS: the reply gave the URL gap with no fix). Skill fixed.
- `publish-readiness-expo-gaps-*` after that fix: `evals/results/2026-11-02T17-16-30-062Z/aggregate-result.json`, 1.00 and 1.00, $0.51.
- First full run: `evals/results/2026-11-02T16-54-52-517Z/aggregate-result.json`, $1.75. `web-nodata-en` 0.60: git could not run in the sandbox, so an honest `unknown`. One `--keep-temp` diagnosis rerun of it (0.40, $0.14) and of `expo-rerun-en` (1.00, $0.14). Skill gained the Troubleshooting row and Verify before the final reply.
- `app-creators-vite-*`: `evals/results/2026-11-02T17-12-58-797Z/aggregate-result.json`, 1.00 and 1.00, $0.22.
- `vite-*`: `evals/results/2026-11-02T17-14-21-254Z/aggregate-result.json`, 0.80 and 0.80, $0.30; only `ran-verify-script` fails, the known ceiling.
- Regex graders: 15 regexes tested in Node against flow and block samples. mutations: 6/6 caught, restored by sha256.

**Blocked prerequisites for Kyle**
- Full Xcode: `smoke-run` on `expo+app-store`, `flutter+app-store`, `xcode+app-store`.
- JDK: `smoke-run` on `expo+google-play`, `flutter+google-play`, `kotlin+google-play`.
- A physical device: Flutter's release launch, because its release mode does not run on a simulator or emulator.
- Fixture accounts are not needed by this skill; it touches no store. They stay needed by Slices F and H.
- Push the fixtures branch so `ff71355` is public.

## Slice D / gate fix round 1: script

Finished by a third doer after two earlier doers stalled on multi-line Bash calls. All items were rechecked against the working file; earlier drafts were read as intent only.

**Outcomes**
- SEC-1 fixed: one bounded reader for all project reads; FIFO, `/dev/zero`, outside symlink, and oversized files give `UNKNOWN` with no hang. Repro: no hang, no leak.
- SEC-2 fixed: `show()` at every echo of a project value, `_one_line` strips again. Tests assert raw bytes and one line per check.
- 3 fixed: a skipped source file gives `UNKNOWN` naming it, unless a detected gap gives `FAIL`.
- 4 fixed: launcher or layer drawables the code cannot judge give `UNKNOWN`, never a counted pass.
- 5 fixed: template literals are strings to `strip_comments`.
- 6 fixed: Xcode layer order, literal xcconfig lines, one `#include` level, `$(inherited)` and conditionals `UNKNOWN`, `INFOPLIST_KEY_NS*` from xcconfig counts.
- 7 fixed: bad marketing entry `FAIL`s; only the marketing well filled is `UNKNOWN`, no rule sourced.
- 8 fixed: every gap on one line, with every fix.
- 9 fixed: all `res/values/*.xml`, `resValue` `UNKNOWN`, real native project required, unknown plugin `UNKNOWN`, pages-router `public/favicon.*`.
- 10 fixed: depth-1 walk of `metadata`; `default:` form kept and tested.
- 11 fixed: `.easignore` replaces `.gitignore`, cited from Expo's easignore page; `ios/*`, `/ios/*`, `ios/**` accepted.
- 12 fixed: `data:` icon `UNKNOWN`. 13 fixed: `com..foo`, `.mjs`/`.cjs`/`.mts`, Flutter scan scope, `checks.md` says "Expo Build" as the page does.
- 14: no Apple primary source. Searched HIG app-icons, configuring-your-app-icon, ASC platform-version-information, CFBundleIcons on 2026-11-02 UTC. Native PNG with alpha is `UNKNOWN` with the reason, no alpha is `PASS`, Expo config route stays `FAIL` from Expo's "no transparent pixels". Forum citation removed.
- 15: no Google primary source. Android's configure-app-module only uses `com.example.myapp` as the value to replace; prepare-for-release and Play Help 9859152 do not name it. Rule, its test, and the claim removed; a test now pins that it passes.
- Added mid-round, crafted-input slowdown fixed: 15 inputs of 2 MB hung past a 15-second watchdog before, and now each ends in about 2 seconds or less under 3.14 and 3.9. Fixed: `strip_comments`, Dart `pickVideo`, pbxproj object index, nesting, settings keys, configuration lists, `resolve`, `resValue`, catalog aliases, state keys and flow lines, Next.js `metadata`. Tests use the watchdog. Other tokens tried, including HTML and the Swift and Expo tables, were already fast.
- 16 and 17: rows and branches tested; `needed by code:` half asserted; `seed` and the fixture-seeded cases assert the reason. Kill rate: listed and round mutants 35/35, run before the speed fix; speed-fix mutants 19/19 after four gaps were closed (first pass 15/19; those inputs closed their own match too early). Every restore passed a sha256 check.

**Decisions**
- A bad `--expo-config` exits 2, not `UNKNOWN`: it is the operator's argument, and the spec's exit 2 covers a usage error. A project file stays `UNKNOWN`.
- `checks.md` source numbers stay stable: [3] is now the easignore page, [7] lists the Apple pages searched. No renumbering.
- Tests from the recovered draft were corrected to what is right, not copied: xc-dangling and xc-var-path now remove the target-level id, because target settings correctly outrank a broken xcconfig; media-library rows drop the base tree's photo string, which satisfied them.

**Rejected**
- `\Z` as a closer for `/*`, the suggested one-line fix: `/\/*/` in a regex literal would then hide every API after it, a false `PASS`. `strip_comments` uses a short loop and `rfind` instead; quotes and backticks do use end-of-input closers, because their text is kept, not hidden.
- `FAIL` for native alpha from the forum-quoted validator message: spec §3.6 does not count a community post.
- Keeping `com.example` because Android's page says to replace the sample id: that is build advice, not a store rule.
- Treating first-party plugins such as `expo-router` as known non-string plugins: no source states the negative.

**Assumptions**
- `/ios/*` and `ios/**` ignore the folder for Expo Build: the page shows only `/android` and `/ios`; the forms follow gitignore semantics. Check: an EAS build with that line.
- The Edit tool decoded `‮` and ` ` in test text into raw characters; a scratch script restored the escapes. Check: `LC_ALL=C grep -c $'\xe2\x80' tests/check-readiness.test.sh` prints 0.

**Deferred**
- A release source-set manifest removing a permission: per the round's script; listed in Known limits.
- `expo-router` and similar plugins make a missing string `UNKNOWN`, not `FAIL`, as item 9 specifies. A common template loses that `FAIL`; listed in Known limits.
- `SKILL.md`, `SKILL.zh.md`, evals, README, and `verified-runs.md`: the next doer's. A grep of `SKILL.md` and evals for `alpha` and `com.example` finds nothing stale; the others were not checked.

**Touches**
- `skills/publish-readiness/scripts/check-readiness.py`, `tests/check-readiness.test.sh`, `skills/publish-readiness/references/checks.md`. Output wording changed: values are now quoted, which any eval grader matching old lines must follow.

## Slice D / gate fix round 1: skill and evals

Outcomes, by finding number:
1. Regex graders rewritten: each loop consumes one whole line in one way, and `result` is read as the platform's first key, which SKILL en and zh now require in both files. 178 Node runs in flow, block, CRLF, and flow-parent form, slowest 0.21 ms. Negatives are built from a real seeded report by one edit: platform result flipped with a nested check carrying the value; the gate's example `{checks: [{id: smoke-run, result: unknown}], result: pass}`; a sibling platform carrying it; value under `targets:`; value only below the frontmatter; value inside another key; answer changed, dropped, or under another parent; 400 whitespace lines plus an 8000-character line.
2. Scaffold takes a seed result. `expo-rerun` seeds `unknown`, `expo-dirty` seeds `pass`; `web-nodata` and `expo-gaps` already seed `unknown` or nothing. Scaffold alone: every result grader fails in all four cases. The three `*-kept` graders match by design; README says so, and "This proves" is rewritten.
3. `ran-check-script` requires `check-readiness\.py[^\n]*--platform\b`. `ls`, `cat`, and `sed` of the file do not match; a call that holds the path in a variable set earlier in the same command matches.
4. Step 10 names `publish-web` only for `vite`, `nextjs`, `static`. `expo+web` and `flutter+web` added to `verified-runs.md` and the README table.
5. Step 2 command prints the file path, en and zh.
6. Inventory scan is now Step 3 and the checks Step 4, so the web flag is known on the first run. Write-before-ask is unchanged. All step references updated, en and zh.
7. `age-rating.md`: the "none" shortcut excludes `play_category` and `play_target_age`.
8. `publish-web` en and zh name a non-current `fail`. The gate is unchanged. No version bump: 0.1.2 is still unreleased in this branch.
9. `vite+web` is `open`. All three rows name what no eval exercises: applying answers, an agreed fix, the rerun after a commit. `expo+*` rows cite the 2026-11-02 rerun.
10. Notes below the frontmatter hold `Unconfirmed inventory items:`; a rerun reads them. No list with `confirmed: false` means all are unconfirmed. `data-inventory.md`, SKILL en and zh. No schema change.
11. The Xcode and physical-iOS smoke asks are in `## What you must provide` and Step 7, en and zh.
12. SEC-2 line added at the step that reads the script's output, en and zh.
13. Corrections below.

Handoff corrections to the T3 entry:
- TN2339 does show `-configuration` and `-destination` in `xcodebuild` usage. It does not cover install and launch on a simulator. The human step stands for that reason. `smoke-run.md` now says this.
- Kotlin's smoke run can never reach `pass` on a project with no release signing. `smoke-run.md` now says this.
- The `xcodebuild -version` and `java -version` Troubleshooting rows rested only on this machine, so they are removed, en and zh, with the Flutter iOS setup source they alone used. The `git` exit 72 row now states its basis: the 2026-11-02 eval runs.

Script changes (quoted values, native alpha `UNKNOWN`, `com.example`, one-line gaps): grep of SKILL en and zh, references, README, `llms.txt`, and evals found no stale claim. Expo icon alpha stays `FAIL`, so `expo-gaps` is still right.

Evals, `--model sonnet --no-publish`:
- `publish-readiness-*`: `evals/results/2026-11-02T20-12-49-227Z`, all 8 cases 1.00, $1.66.
- `vite-*`: `evals/results/2026-11-02T20-12-55-930Z`, 0.80 and 0.80, $0.25; only `ran-verify-script` fails, the known ceiling, because the case grants no Bash.
- `app-creators-*`: not run, skill unchanged.

Regex mutations: 9/9 caught (generated from a copy of `regexes.json`, restored and compared).

Decisions:
- `expo-dirty` seeds `pass` and `expo-rerun` seeds `unknown`: each seed is the opposite of what that case's graders require.
- Reordered Steps 3 and 4 rather than state a rerun: one run of the script on every path, fewer ways to forget it.

Rejected:
- Parsing YAML in the graders: the eval format has only regex file graders.
- A `confirmed` flag per item for finding 10: a schema change, which the finding rules out.

Assumptions:
- The eval runner evaluates `regex` graders with the JavaScript engine. Check: the original finding reproduced in Node, and the graders passed under the runner.

Deferred:
- CI skips fixture assertions until Kyle pushes the fixtures branch.
- Applying answers, an agreed fix, and the rerun after a commit stay unexercised: an eval has no second turn. Level 3 stays `open` until a run does them.

Touches: `skills/publish-readiness/` (SKILL en and zh, `age-rating.md`, `data-inventory.md`, `smoke-run.md`, `verified-runs.md`), `skills/publish-web/SKILL.md`, `SKILL.zh.md`, `README.md`, `evals/publish-readiness/`.

## Slice D / gate fix round 2: script

**Outcomes**
- 1 fixed: a PBXGroup cycle gives `UNKNOWN` through the xcconfig layer, with no hang.
- 2 fixed: `applicationId` plus spaces gives `UNKNOWN package`: 1.5 s at 16 MB.
- 3 fixed: `_pbx_settings` parses the value without a regex tail: `FOO =` plus spaces takes 3.4 s at 16 MB on 3.9. Same class found and fixed: `name =`, `path =`, and list openings repeated with no closer. The false time claim in `checks.md` is removed.
- 4 fixed: a linked folder outside the project, or at a folder the scan does not reach, gives `UNKNOWN` naming it. One the walk reaches stays silent. `.symlinks` is skipped.
- 5 fixed: both regex examples `FAIL`. `(?<!\\)` proved necessary for indented statements, but `/[/*]/` still hid code, so regex literals also count as strings where an expression can start.
- 6 fixed: both tokens in one Dart file need the microphone key, by one anchored linear pattern.
- 7 fixed: the walker reads the whole object. A spread, a repeated `title` or `default`, or a shorthand `title` gives `UNKNOWN`.
- 8 fixed: discovery runs on text with literals blanked. `metadata` assigned twice gives `UNKNOWN`.
- 9 fixed: 512 MB per-run budget in `read_bytes`; `verdict` dedupes with `dict.fromkeys`. The budget alone left the 14 MB `index.html` hanging, so 1000 declared icons is now a cap and `head()` is cached: 2.1 s on 3.9.
- 10 fixed: `contain()` runs before existence for Expo icons, web icons, asset catalog entries, and xcconfig includes. Missing and present outside paths read the same.
- 11 fixed: `setitimer` at 120 s when `SIGALRM` exists; the handler flushes finished lines, writes to stderr, and exits 2. Tested in process with a 0.3 s limit. `checks.md` calls it a backstop.

**Evidence**
- `tests/check-readiness.test.sh`: `PASS 475/475` under 3.14.7 and 3.9.6. Lint clean. Three fixture runs have no `FAIL`. Repro: no hang, no leak.
- 39 probes, none hung. Slowest on 3.14: 1.4 s. Slowest on 3.9: 3.4 s.
- Kill rate: 36/36 on this round's branches; first pass 34/36, and both survivors exposed test inputs that matched early. Every restore passed a sha256 check. Round 1's 54 mutants were not rerun on this code.

**Decisions**
- `_layout` now uses the 2 MB scan cap: a larger root layout gives `UNKNOWN`.
- `_file_ref_path` returns `None` on a cycle, the path the xcconfig layer already treats as unreadable.

**Rejected**
- A per-file `[^)]{0,200}` for `pickVideo`: the silent drop in item 6.
- Only `(?<!\\)` for item 5: it leaves `/[/*]/` hiding code.

**Assumptions**
- The regex-literal rule fits Swift, Dart, and Kotlin too. An unclosed false match keeps text to its line end, so it can only over-detect. Check: run on real projects in those languages.
- Flutter desktop `.plugin_symlinks` was not skipped: no source was read, so such a project may get `UNKNOWN`. Check: a Flutter project with desktop folders.

**Deferred**
- A character class such as `[/*]` in an indented regex statement can still hide code; listed in Known limits.
- No time bound is proven; the 120-second limit is the backstop. Without `SIGALRM`, as on Windows, there is no limit.

**Touches**
- `skills/publish-readiness/scripts/check-readiness.py`, `tests/check-readiness.test.sh`, `skills/publish-readiness/references/checks.md`. New exit-2 path on the time limit, and new `UNKNOWN` wording that an eval grader may match.

## Slice D / gate fix round 2: evals

**Outcome**
- Fixed: evidence can no longer stand in for a platform result. In block form, the platform key must sit at the indentation of the parent's first child, captured from the file. In a one-line flow parent, the regex walks complete earlier entries, so a key inside a nested value or a string is never reached.
- Same flaw closed in `inventory-confirmation-kept` and the two answer graders, which share the builder. `confirmed` must be a direct child of `data_inventory:`, and an answer a direct child of `age_rating.answers`.
- `SKILL.md` needs no indentation rule, because the pattern reads the indentation from the file. `result` stays the first key, from round 1. No schema change.
- `evals/publish-readiness/README.md` describes the new anchoring.

**Evidence**
- Node: 386 runs, slowest 0.31 ms, 0 problems. Flow, block, CRLF, four-space, and flow-parent positives kept.
- Both Codex inputs are negatives for every result regex: quoted evidence holding `<p>: { result: <v> }`, and block-scalar evidence holding indented `<p>:` and `result: <v>`. Also: the platform key in a deeper map, in a check item, and in a sibling's nested value or string.
- New timing inputs: whitespace lines after the first child and inside `answers`, an 8000-space run, an unclosed map, 1500 siblings, an unterminated string, and deep openers.
- Regex mutations: 15/15 caught. The first pass was 12/15; the three misses were test gaps, closed with new inputs. `regexes.json` restored and compared with `cmp`.
- Scaffold alone, rerun with the new patterns: all 12 result graders fail; the three `*-kept` graders match by design.
- `scripts/lint-skills.sh` clean. Tests 77/77, 475/475, 48/48. `SKILL.md` 180 lines, `SKILL.zh.md` 156. `privacy-scan --staged` rc=0 after a path-scoped add, then unstaged by path.

**Evals**, `--model sonnet --no-publish`:
- `publish-readiness-*`: `evals/results/2026-11-02T21-36-11-213Z`, 7 of 8 at 1.00, $1.68. `expo-gaps-en` scored 0.88 on `reply-names-three-gaps-with-fixes`, votes FAIL PASS FAIL. The judges gave no reasons. The final reply names all three gaps, each with a fix, so I read this as judge noise.
- `publish-readiness-expo-gaps-en` re-run once: `evals/results/2026-11-02T21-45-24-184Z`, 1.00, $0.27. Total $1.95.

**`UNKNOWN` wording at HEAD**
- No grader or doc matches the new wording: result graders read frontmatter only, and the llm graders name gaps, not script text. The three fixtures give the same results.
- One stale sentence fixed, en and zh: SKILL's exit 2 line now includes the script's new time limit.

**Rejected**
- A fixed two-space indentation rule in `SKILL.md`: the captured indentation gives the same anchor with no new rule, and fails no valid report.
- Dropping the one-line flow parent: the brief keeps flow positives.

**Assumptions**
- `evidence` stays on one line, as the script prints it. A multi-line quoted scalar with a continuation line at the platform's own indentation would still fool the block anchor; a regex cannot tell. Check: only a hand-edited report could produce it.
- A one-line flow parent's plain scalar holding `'` or an unbalanced bracket fails to match. The error is a false fail, never a false pass.

**Deferred**
- CI skips fixture assertions until Kyle pushes the fixtures branch, as in round 1.

**Touches**: `evals/publish-readiness/` (all `case.yaml`, `README.md`), `skills/publish-readiness/SKILL.md`, `SKILL.zh.md`.

## Slice D / whole-run gate result

Cap spent: two fix rounds. Suite at f016003 passes: 77/77, 106/106, 48/48, 475/475, lint clean. Same reviewer, blocker-only at f016003: no blockers, all round 2 findings fixed. Coordinator security findings: both confirmed and fixed in round 1 (SEC-1, SEC-2, above), with regression tests and the project-data line in both SKILL files; round 2 added the read budget and the run limit.

Codex third pass at f016003 returned 3 MAJOR and 2 MINOR. All five are concrete and reproduced, none is fixed, and none meets the blocker bar: each needs an unusual input, and none crosses a security boundary. No third round, per the cap. These defects remain open:

**Deferred**
- False PASS `permission-strings`: `const r =  /[/*]/; launchCameraAsync(); /* n */` (two spaces before the regex). The camera call is stripped as a comment. The reviewer found the same with an arrow function, `s => /[/*]/.test(s)`. `references/checks.md` states the one-space limit. `check-readiness.py:284`.
- False PASS `app-name`: `{ title: "Todo", [runtimeKey]: "" }`. A computed key that could override the title should give `UNKNOWN`. `check-readiness.py:1626`.
- False UNKNOWN `app-name`: `{ title: "Todo", description: title }`. A value reference is read as a second key. Introduced by round 2. `check-readiness.py:1641`.
- Eval graders only: a multi-line quoted `evidence` holding `  ios: { result: pass }` at the platform indentation satisfies the block anchor. Needs a hand-written report; the script prints one line per check.
- Eval graders only: `result: pass-pending` satisfies the pass grader, because the match ends on a word boundary. Same pattern on the other result graders.
- Eval graders only: a comment between `ios:` and `result`, or a BOM, gives a visible false fail. A one-line flow parent holding `'` or an unbalanced bracket does the same.
- A release source-set manifest that removes a permission is not modelled. Second-turn eval coverage is not built. `check-pwa` failed once (47/48, connection refused) under reviewer load; 8/8 repeats and the suite at f016003 pass, and the file has no diff in this slice.

**Process**
- Two doers (a1f564b, ac51dc6) stalled on multi-line Bash calls that never started. A third fresh doer (acbd3cd) finished with one-line Bash calls. Recovery used no fix cycle. After the slice finished at 956f27b, both stalled doers woke. a1f564b wrote nothing. A queued command from ac51dc6 ran and patched `tests/check-readiness.test.sh` with 99 stale added lines that duplicate tests already at HEAD. The patch was never committed. It was discarded for this one file, and the file passes 475/475. Both doers have now stopped.
- T2 doer a1f564b called the advisor once before it was told not to. No other agent used it.

implement-loop: slice D shipped f016003; remaining: [E, F, G, H, I, J]

## Slice D follow-up

Every PASS now needs an authoritative input. Script at 1558 lines, tests at 1855 lines, 463/463 tests, mutations: 14/14 caught.

**Decisions**
- `-json` kept on `xcodebuild -showBuildSettings`. The man page documents the action, `-configuration`, `-sdk`, `-project`, `-workspace`, and `-scheme`, and is silent on `-json`; silence is not a contradiction, and if the flag fails the skill's "command failed" path leaves `UNKNOWN`.
- Doc change to the design: Flutter's command is `flutter build ios --release --no-codesign --config-only`, the form docs.flutter.dev/deployment/cd shows. The iOS deployment page has no such flag.
- Doc finding: `developer.android.com/tools/bundletool` does not mention `dump`. `bundletool dump manifest --bundle=` is cited from Google's `DumpCommand.java` help text.
- Doc finding: no documented Android command prints the resolved id without building. `apkanalyzer manifest application-id` exists but needs an APK; the Merged Manifest view is Android Studio only. The built-artifact design stands, and `manifest print` stays because `--resolved` takes XML.
- `android:debuggable` with any value but `false` is `UNKNOWN`, stricter than `true` only, because the printed form was not seen on real output.
- `allow_abbrev=False` on argparse, so `--res` or a mistyped flag cannot pass as `--resolved`.
- Unclosed `/*` now runs to end of file. The raw-only rule makes the stripper's mistakes harmless, which let the "leave it as text" branch go.
- Extra fine distinctions turned to `UNKNOWN` beyond the design, for H: Expo `ios.icon` as light/dark/tinted variants; a non-string Expo image path; any malformed `res/values` file met before the name is found. Removed: the App Store entry "declares size" check, since the file's pixels are still required to be 1024x1024.
- `check_strings` and `check_android_permissions` share `_code_gap` and `_scan_verdict`. Rows dedupe by table index, with `verdict` dropping repeated reasons on the line.
- `_package_deps` merges dev and prod dependencies, since it is only a detection signal.

**Rejected**
- Parsing the text form of `-showBuildSettings` in case `-json` is missing: that is a new hand-written parser, which the rule forbids.
- A `--expo-config` alias: nothing shipped depends on it.
- Reaching about 1,000 lines by single blank lines, removing section banners, or moving the API tables to a data file: the count would fall with no fall in complexity.
- Cutting a KEEP item to hit the number: API tables (about 120 lines), PNG/WebP and per-framework icon checks (about 300), bounded reads and security (about 130), plugin and route logic that prevents false results.
- Stopping the dedupe at the first file per row: a row raw-only in file A and code in file B has to end FAIL-capable in either order.

**Assumptions**
- Real `-showBuildSettings -json` output is a JSON array of objects with `buildSettings`, and holds `PRODUCT_TYPE`, `PLATFORM_NAME`, `CONFIGURATION`, and `SRCROOT` as strings. `PRODUCT_TYPE` and `PLATFORM_NAME` are not entries in Apple's build settings reference, and `-json` is in no Apple page fetched. Check: the `Kyle:` line in `docs/ROADMAP.md`.
- `apkanalyzer manifest print` output is XML with `package` on the root and `xmlns:android` declared. Same check. No resolved Xcode or Android path has run against real tool output; fixtures are hand-written to the documented shape, and this machine has no full Xcode, JDK, apkanalyzer, or bundletool.
- A mismatch in either shape fails safe: exit 2 from classification, or `UNKNOWN` from a gate, never `PASS`.
- `flutter build ios --config-only` writes only files Flutter's template ignores. The skill treats a new `git status` entry as uncommitted changes, so a wrong assumption gives `unknown`.

**Deferred**
- Script size: about 1,000 not reached, see Rejected. Tests shrink less than asked because the K list adds about 300 lines back.
- `Package.swift` alone, or a Gradle project with a relocated manifest, now exits 2 with "no supported framework" while `app-creators` detection still names them `xcode` or `kotlin`. Safe: no PASS, and the message stops the skill. `skills/app-creators/SKILL.md` was not changed because its detection serves other skills.
- Eval graders: the multi-line `evidence` case and the comment-or-BOM false fail stay open, as the earlier gate recorded.
- A native Android `package` line stays `UNKNOWN` until a release build runs, so on a machine with no JDK a native Android route cannot reach `pass`. That is the intended honest result.

**Touches**
- `skills/publish-readiness/scripts/check-readiness.py`, `tests/check-readiness.test.sh`.
- `skills/publish-readiness/SKILL.md`, `SKILL.zh.md` (`metadata.version` 0.2.0, history template), `references/checks.md`, `references/smoke-run.md`.
- `docs/specs/2026-11-02-slice1-publish-design.md` §3.4, `docs/ROADMAP.md` (one `Kyle:` line).
- `evals/publish-readiness/*/case.yaml` (result graders), `evals/publish-readiness/README.md`.
- Shared surface: the script's CLI, `--expo-config` replaced by repeatable `--resolved`. Any sibling calling it must change; `store-listing` does not call it.

## Slice D follow-up / gate fix round 1

**Decisions**
- The `Package.swift` and relocated-Gradle divergence with `skills/app-creators/SKILL.md` is fixed, not deferred: both now take a route and print `UNKNOWN`. The fallback reads no file content and sits at the `unknown` end of detection.
- `app.config.json` wins over `app.json`, confirmed in `getStaticConfigFilePath` in `@expo/config`.
- `exp.name ?? pkgName` means null falls back and an empty string does not; the script matches both. A malformed `package.json` is `UNKNOWN`, not `FAIL`.
- `slug` is a reliable marker: `ensureConfigHasDefaultValues` always sets it, and `npx expo config --json` prints `config.exp`.
- On Expo with a real `android/`, every detected permission is treated as `declare`, not `auto`: a built manifest is the merged result, so an absent one is a real gap there, and with no built manifest it is `UNKNOWN`. The Expo config route keeps its `how` rules.
- The HTML read is `index.html` at the web root only; `public/index.html` is dropped, because the stated Vite limit needs that to be true.
- A missing attribute in `src/main` is `FAIL` only when the built manifest also lacks it. A built manifest holding a reference leaves the line `UNKNOWN`, since the reference cannot be followed.
- The test helper `built` now writes `@ref/...` label and icon, the form a real build prints, so existing `src/main` seeds still exercise `src/main`.
- Symlinks into a scan-skipped folder use the same `_skip_dir` rule as the walk, so a link to `src/build` stays silent and a link to root `build` is `UNKNOWN`.

**Rejected**
- Vite `root` relocation: the follow-up's rule says a web manifest or HTML title decides, and reading the config is forbidden; `UNKNOWN` for every `vite.config.*` would make every Vite app unable to pass. Stated as a limit.
- Expo auto permissions `PASS` on `launchCameraAsync()`: delete the source file and the same `PASS` prints, so source does not decide it; source can only remove the `PASS`, and `app.json`'s block list is the data.
- A raw-only match with the key already declared stays `PASS`: the declared key is the authoritative input and a stripper error cannot make it false. The orchestrator reports this reading to the coordinator.
- `<Text>it's</Text> // launchCameraAsync()` false `FAIL`: the rule allows a stripped-text `FAIL`; fixing it needs a parser.
- A built manifest from another project: no field ties it to a checkout; documented instead.
- A guard for body text joining an unclosed `<title>`: Python 3.14's parser reads the title as RCDATA, so the branch could not be tested here.

**Assumptions**
- `apkanalyzer manifest print` shows resource references as `@ref/...`; no real output was available. A literal label is what the script trusts, and a reference falls back, so a different form fails safe.

**Deferred**
- Flutter and native Expo not scanning Swift with `APPLE_APIS`, within the stated scope line.
- Barrel re-exports, same.
- A tracked `ios/` also listed in `.gitignore`, unverified.
- Expo's third name fallback, the folder name when `package.json` has no `name`: the fix list says `FAIL` when neither file has one, so this `FAIL` can be stricter than Expo.
- A `package.json` holding an `expo` object still classifies as an Expo config under E2's rule.

## Slice D follow-up / gate fix round 2

**Decisions**
- A debuggable built manifest decides nothing: `package`, `permissions-declared`, a literal label, and a missing label or icon are `UNKNOWN`. A reference in it decides nothing either, so label and icon read `src/main` as with no built manifest.
- A non-string `package.json` name is the no-name case, because Expo then uses the folder name. An empty string stays `FAIL`, because `pkgName` keeps it.
- `<base>` is recorded and never resolved. A rooted reference is still read.

**Rejected**
- Exempting `$FLUTTER_BASE_HREF` from the `<base>` rule: that adds interpretation. Consequence: Flutter's default web template gives `UNKNOWN` on `icon-sizes`, so it does not reach `PASS` on that line. No false `PASS`.

**Deferred**
- `pubspec.yaml` mentioning `flutter` in prose with a root `index.html` exits 2: no `PASS`, it needs an unusual repository, and any fix would add interpretation.
- A `<title>` inside `<body>` prints `FAIL`: rare, and not run in a browser.

## Slice D follow-up / whole-run gate result

Gate on `git diff 849ff80...HEAD`: full suite, one reviewer, and Codex, with two fix rounds. Both rounds are spent. The gate is not passed: one concrete false `PASS` stays open at dc338d9.

Suite at dc338d9 passes: 77/77, 106/106, 48/48, 593/593, lint clean, template lint clean, manifests parse. Eval `publish-readiness-*` at 50d6e51: 8/8 at 1.00, $1.76. Eval at dc338d9: 8/8 at 1.00, $2.01. `privacy-scan --range 849ff80..HEAD` printed one author identity warning, which is contributor attribution; the full branch scan belongs to the slice loop. Script 1680 lines against about 1,000. Tests 2360 lines.

What the gate proved: the three earlier open defects are gone with regression tests; no `PASS` comes from JS, TS, Gradle, pbxproj, or xcconfig; a native route with no resolved input prints `UNKNOWN` on the affected checks. Route choice was the remaining way a data file could pass when the build uses something else, and round 1 closed the cases found. Round 1 fixed 14 reviewer findings and 3 Codex findings; round 2 fixed two reviewer blockers and one Codex finding.

**Open, at the cap**
- False `PASS` `icon-sizes`: `<head><base href="https://example.invalid/assets/"><title>Demo</title><link rel="icon" href="/i.svg"></head>` with a local `i.svg`. The browser loads the icon from the other origin. `Web._base_relative` in `check-readiness.py:1251` exempts rooted references. Fix: remove `|/` from that regex, which also clears the false `FAIL` below. Reviewer and Codex found this independently.
- False `FAIL` `icon-sizes`: the same HTML with no local file.
- False `FAIL` `app-name`: `<head><base href="/"><title></title><link rel="manifest" href="/m.json"></head>` with `m.json` holding a name. `Web.app_name` skips the manifest whenever a `<base>` exists, so the empty title decides. It should be `UNKNOWN`.

**Rejected**
- Reviewer finding 8, Vite `root` relocation: the follow-up's rule says a web manifest or HTML title decides, reading the config is forbidden, and `UNKNOWN` for every `vite.config.*` would stop every Vite app. Stated in `references/checks.md`.
- Codex finding 4, Expo automatic permissions: the same `PASS` prints with the source file deleted, so source does not decide it.
- Codex finding 5, a raw-only match with the key declared stays `PASS`: the declared key is the authoritative input, and a stripper error cannot make it false. This narrows the instruction "a match only in raw text gives `UNKNOWN`" to the unsatisfied case; `UNKNOWN` there would be a false `UNKNOWN`.
- Reviewer finding 15, `<Text>it's</Text> // launchCameraAsync()` false `FAIL`: the rule allows a stripped-text `FAIL`, and a fix needs a parser.

**Deferred**
- Script size: the rule's reviewer named no remaining source interpretation worth cutting, apart from the permission scan and API tables, which the contract allows. The file grew through rounds 1 and 2, which turned distinctions into `UNKNOWN`.
- No resolved Xcode or Android path has run against real tool output. `-json`, `PRODUCT_TYPE`, `PLATFORM_NAME`, and the `apkanalyzer` form are assumptions. The `Kyle:` line in `docs/ROADMAP.md` holds that check.
- A built manifest is not tied to a checkout. Flutter's default web template holds `<base>`, so Flutter web `icon-sizes` is `UNKNOWN`.
- Flutter and native Expo do not scan Swift with `APPLE_APIS`. A barrel re-export is not detected. Both sit inside the stated scope line.

**Process**
- Advisor not called. No Fable. Kyle's `/tmp/cc-<task>.sh` Bash rule reached every agent during the run.

implement-loop: slice D follow-up deferred: gate blocked at the fix cap by one open false PASS (HTML base with a rooted icon) at dc338d9; remaining: [E, F, G, H, I, J]

## Slice D follow-up / orchestrator fix past the cap

The coordinator closed the open `<base>` defects with one fail-closed change, past the two-round cap, because it only removes interpretation. A rooted link beside a `<base>` is now `UNKNOWN`, like a relative one, and a `<base>` with an empty title leaves `app-name` `UNKNOWN`. This covers the open false `PASS` and both false `FAIL`s above.

Evidence: `tests/check-readiness.test.sh` 596/596 under bash 3.2 and bash 5. Restoring the rooted exemption fails 3 tests, and treating an empty title as a title fails 1. Full suite and lint pass.

Not rechecked: no reviewer or Codex read this change, and the eval did not rerun. No eval case has a `<base>`, and the only output change is on `<base>` pages.

Accepted from the gate: a raw-only permission match with the key declared stays `PASS`, because the declared key is the authoritative input.

implement-loop: slice D follow-up shipped; remaining: [E, F, G, H, I, J]

## Slice E / T1 check-listing.py and limits

**Decisions**
- `required` takes `yes`, `no`, or `unverified`, split from `checked`. `promotional_text`, `title`, `full_description` have a sourced limit but no source on required status, so they carry `required: unverified` and `checked: 2026-11-03`: over the limit `FAIL`, within it `PASS`, empty or absent `UNKNOWN`. `checked: unverified` stays `UNKNOWN` for the whole row; no real row uses it now.
- `keywords` is `100 bytes` from the Help page. The product page says 100 characters. The conflict is written in `limits.md`.
- `subtitle` is `no` because Apple's required-properties table has an explicit Required column and that cell is empty. `name` is `yes` from the same table.
- Google `phone` uses the page's general screenshot requirement (320-3840, ratio 2, no alpha). That requirement is not limited to phones; the page gives other device types their own rules.
- Keys in the listing follow `[A-Za-z0-9][A-Za-z0-9_-]*`, so a raw control sequence in a locale key is exit 2. Field ids print reader keys as they are; image ids go through `token`, unquoted when safe and sanitized when not; paths and size cells are always quoted.
- Over-limit is checked before empty, and whitespace-only counts as empty.
- Image rows must hold exactly `store, device_class, path, size`; a missing or extra key is exit 2.
- Reader rejections give `line N:`. Shape rejections name the key path, for example `stores.s.en: `.
- A PNG has alpha at colour type 4 or 6, or with `tRNS` between IHDR and the first IDAT.
- Parsing without `MAX_INDENT` keeps `RecursionError` caught in `main`. Shape runs after parsing, so it does not bound depth: 1020 levels fit in the 1 MiB cap and gave a traceback. The suite covers it.

**Rejected**
- Inferring "not required" from a missing statement: Apple's required table omits `description` and `keywords` too, though another page says they are required. Absence there is not evidence.
- Google rows for tablets, Chromebook, Wear OS, Android XR: the rule grammar cannot state an exact ratio or an open maximum, and the large-screen numbers differ from the general ones. No row gives `UNKNOWN`, which is true.
- A Google `app_icon` row: `publish-readiness` owns icons.

**Assumptions**
- `chars` means Unicode code points. Google's page only says full-width and half-width count alike; Apple states nothing for CJK. Check: submit a CJK name at the limit in a level-4 run.
- A 1 MiB prefix holds the first SOF of a normal JPEG. Past it the result is `UNKNOWN`.

**Deferred**
- The limits reader skips the line after the header without checking it. A table with no separator loses its first row, which then gives `UNKNOWN`, not a false `PASS`. `tests/check-listing.test.sh` checks the real table.
- `scripts/lint-skills.sh` fails on `skills/store-listing/SKILL.md` missing until T2 adds it. Expected; only that one line.
- Apple's required-device list and its iPhone section notes do not agree; `limits.md` states both, and the script enforces neither.

**Line count**
- `check-listing.py` is 291 lines. It uses one blank line between functions. Imports and constants are one per line, which costs 14 lines; with them compressed it was 277. Above the 260 line; the next cuts are in the T1 report.

**Value sources, all fetched 2026-11-03**
- `name`, `subtitle` limits: developer.apple.com/help/app-store-connect/reference/app-information/app-information.
- `name`, `subtitle` required: same path, `required-localizable-and-editable-properties`.
- `description`, `keywords`, `promotional_text` limits; `description`, `keywords` required: same path, `platform-version-information`.
- All `app_store` image rows, no-alpha, formats, counts, required classes: same path, `screenshot-specifications`.
- Apple preview video: same path, `app-preview-specifications`.
- Keywords conflict: developer.apple.com/app-store/product-page/.
- `title`, `short_description`, `full_description` limits and the CJK statement: support.google.com/googleplay/android-developer/answer/9859152.
- `short_description` required and all `google_play` image rows: answer/9866151.
- Read without a required statement for `title` or `full_description`: answers 9859454, 9859455, 9859751, 9844778, and the `edits.listings` API page.

**Left out or marked**
- `required: unverified`: `promotional_text`, `title`, `full_description`.
- Left out: Google tablets and Chromebook, Wear OS, XR (grammar), Android TV screenshots (no size stated), `app_icon` (other skill).

**Touches**
- `skills/store-listing/references/limits.md`, `skills/store-listing/scripts/check-listing.py`, `tests/check-listing.test.sh`, `.github/workflows/lint.yml`.
- Shared surface: the `device_class` slugs and output line format, which T2's skill and later submission steps read.

## Slice E / T2 store-listing skill and evals

**Decisions**
- One store's readiness `fail` stops the whole run, even when the other store passes: one file per run, and the creator can name the other store alone. `expo-readiness-fail` seeds iOS `fail`, Android `pass`, and a real alpha icon, so `check-readiness.py` agrees with the record.
- With no store from intent or the request, the skill asks and stops before writing. The reader rejects an empty `stores`, so this is the one question that precedes the file.
- Over-limit seed: fixed 80-char words plus padding dots to limit + 1. At today's limit the seed ends in one period, so cutting one character leaves the seeded words and fails `seeded-text-left-the-field`. The regex stays static while the seed tracks `limits.md`; the scaffold exits if the words outgrow the limit.
- Regexes accept only the one-line flow map per locale. The reader rejects nested flow, so no flow parent can exist above it; that made them far simpler than the readiness ones. Linear on an 800 KB input in Node (5 ms).
- `seeded-text` is a positive match with a lookahead, not `not_contains`: a deleted file or a missing field then fails too.
- Added beyond the brief: `skill-fired` and `last-check-has-no-fail-line` on `expo-overlimit`. Without the second, a different over-limit text would pass every grader.
- Copy graders that read the output use `focus: { source: file }`, because a `trace` judge sees only the first and last 12 messages. The truncation judge is told to ignore notes, which quote the old text.
- Screenshot row count defers to `limits.md`, with several `phone` rows where a count spans device types. What each shot shows goes in the notes, because rows hold exactly four keys.
- `size` is copied from the script's `PASS` line after `path` is set, so the agent never computes it.
- `app-creators` to 0.1.2: routing table, Expect line, its version strings. `publish-readiness` left alone: its "(not shipped yet)" sits after `publish-ios` and `publish-android` only.
- `docs/STATE.md` unchanged: it lists no skills, `history` is open to every writer, and it already names store-listing on `app.description`.

**Rejected**
- Capture commands (`simctl`, `adb screencap`). Apple's simulator page gave 404 on the docs JSON and Android's docs looped on redirects, so neither is sourced. The ask names the path and accepted sizes.
- A `not_contains` or a literal-length regex on the rewritten field: the first passes on a missing file, the second restates the limit in the evals.
- Writing `app.name` from the config into state: provided fact; the skill's state writes are only `updated` and `history`.
- Stopping on a stale or `unknown` readiness: spec 4.4 proceeds.
- A deterministic `tool_used Write` grader for "nothing outside `.app-creators/`": a temp file would fail it. The llm grader stays, with the 12 and 12 window as its limit.

**Assumptions**
- The minute estimates in `## What you must provide` are estimates, marked "about"; conventions ask for a duration. Check at level 4.
- `app.languages` keys such as `zh-Hans` map to zh and stay as the listing key. The App Store Connect and Play locale mapping is for the submission steps. Check in Slice F.
- Regex and format proofs ran; the skill itself has not. `claude plugin eval` is the orchestrator's, so the `verified-runs.md` rows and README say `eval pending`.
- zh-rewrite's fresh-context check ran as one self pass, because this run dispatches no agents; `check_tokens.py` exits 0.

**Deferred**
- Fill the eval scores into `verified-runs.md` and README after the eval.
- No case proves a passing edited field survives a rerun. `evals/store-listing/README.md` says so.
- Locale rows for screenshots: the agreed path has no locale, so localized captures would need a schema decision.

**Touches**
- New: `skills/store-listing/SKILL.md`, `SKILL.zh.md`, `references/verified-runs.md`, `evals/store-listing/`.
- Edited: `skills/app-creators/SKILL.md`, `SKILL.zh.md`, `README.md`, `llms.txt`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `docs/ROADMAP.md`, `docs/launch/awesome-lists.md`.
- Shared surface: README route rows that T3's lint compares, `listing.md` frontmatter that the submission skills read.

**T2 evals (run by the slice orchestrator)**
- `store-listing-*`, first run: `evals/results/2026-11-03T01-39-40-555Z`, $1.17. `expo-overlimit-en` 0.33: asked only to check, the agent reported the failure and did not rewrite. `expo-overlimit-zh` 0.83: the script ran, but the grader's one-line regex did not match the Bash call. `expo-copy-en` 0.91: `copy-claims-only-what-the-app-does` votes FAIL PASS FAIL; the judges gave no reasons, and two reruns voted PASS PASS PASS.
- Diagnosis reruns: `evals/results/2026-11-03T01-45-43-272Z` overlimit 1.00 and 1.00, $0.41; `evals/results/2026-11-03T01-48-09-946Z` copy 1.00 and 1.00, $0.59.
- Orchestrator edits: Step 6 now rewrites on exit 1 even when the creator only asked for a check; zh copy uses full-width punctuation, after a run wrote a half-width comma; `ran-check-script` names Python and the script in either order.
- Final run after those edits: `evals/results/2026-11-03T01-51-54-082Z`, 6/6 at 1.00, $1.29.
