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
