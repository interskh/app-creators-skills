---
name: publish-readiness
description: >
  Check whether an app is ready to publish to the App Store, Google Play, or
  the web, and write a per-platform report with a fix for every gap. Runs
  static checks on name, bundle id or package, icons, permission strings, and
  privacy policy URL; builds the data collection inventory; records age rating
  answers; runs a release smoke test when the toolchain exists. Writes
  .app-creators/readiness.md and touches no store or account. Use when the
  creator asks is my app ready, readiness check, pre-flight, before I submit,
  what is missing before publishing, privacy policy, age rating, data
  inventory, 发布前检查, 能发布了吗, 就绪检查, 上架前检查, 隐私政策, 年龄分级.
license: MIT
metadata:
  stage: publish
  platform: all
  version: "0.1.0"
  verified: "unverified"
  verified_version: ""
  zh: SKILL.zh.md
---

中文版：先读 SKILL.zh.md。If the creator writes in Chinese, read SKILL.zh.md and follow it instead.

## When to use

- The creator asks whether the app is ready to publish, or what is missing: "is this ready", "readiness check", "pre-flight", "before I submit".
- `app-creators` named this skill as the next step for goal `publish`.
- The code changed since the last assessment, and `.app-creators/readiness.md` needs a new one.
- Not this skill: the creator wants the web app deployed now and has no readiness question. Use `publish-web`.
- Not this skill: `.app-creators/state.md` does not exist yet, or the creator asks where to begin. Use `app-creators`.

## What you must provide

- The privacy policy URL, for every platform where the rule needs one: a public page the creator has published. App Store and Google Play require it. The web needs it only when the app collects data. Takes 1 minute if the page exists; writing one is the creator's job and can take an hour. Recorded under `provided.publish-readiness.privacy_policy_url`.
- A review of the data inventory: only the creator knows what their servers keep and what their partners receive. The skill scans first, so this takes 5 minutes.
- Age rating answers, only for `ios` or `android`: only the creator can state what the app contains. Takes 5 minutes; "none of these" is a valid answer.

Ask once, in one message, and only for what is missing. If the request already answers something (for example "nothing leaves the device, I confirm"), record it and do not ask. Never ask for a secret, a token, a keystore, or a password, and never write one to `readiness.md` or `state.md`.

## Before you start

Read `.app-creators/state.md`. If the file is missing, run `app-creators` first and come back; if it is not installed, ask the creator to run `npx skills add interskh/app-creators-skills --skill app-creators`. If `schema` has a different major version than `1`, stop and ask the creator to run `app-creators`.

These fields must exist:

| field | set by |
|---|---|
| `framework.kind` | `app-creators` |
| `framework.package_manager` | `app-creators` |
| `targets.*.intent` | `app-creators` |
| `provided.publish-readiness.privacy_policy_url` | the creator (ask once, see above) |

Assess the platforms with `targets.<p>.intent: wanted`, or the platform the creator named. If neither gives a platform, ask which one, in the same single message as Step 7. Readiness gate: this skill never requires readiness; it writes it. Read `.app-creators/readiness.md` if it exists.

`scripts/` and `references/` in this skill mean this skill's own directories. Run every command below from the project root.

## Steps

No step here is **effective**: this skill touches no external system. It creates no app record, uploads nothing, and logs into nothing. Steps run in this order so that a session that ends leaves a record: both files are written before the first question.

1. Determine the revision. Default: git. Alternative: none.
   Run: `git rev-parse --verify HEAD`, then `git status --porcelain -- . ':(exclude).app-creators'`.
   Expect: `revision` is the printed commit. A failure of the first command means no commits (or no repository): `revision` is `""`. If git itself cannot run, see Troubleshooting; never read this as no commits without saying so. Any output from the second means uncommitted changes outside `.app-creators/`. In either case the platform cannot be `pass`: it is written `unknown`, unless a check fails, and Step 7 asks the creator to commit.
   If `.app-creators/readiness.md` has a `revision`, that recorded revision is current when the second command prints nothing and `git diff --quiet <revision> HEAD -- . ':(exclude).app-creators'` exits 0. Any other exit, or a command failure, means not current. `.app-creators/` is excluded because this skill writes there and the creator commits it, so comparing raw commits would make every assessment stale at once.

2. Resolve a dynamic Expo config. Default: Expo CLI. Alternative: none.
   Run, only when `app.config.js` or `app.config.ts` exists: `npx expo config --json > "$(mktemp -d)/expo-config.json"`, keeping that path. Never write it inside the project.
   Expect: a JSON file to pass as `--expo-config <file>` in Step 3. If the command fails, say so to the creator and run Step 3 without the flag: the affected lines stay `UNKNOWN`.

3. Run the checks, once per platform. Default: `scripts/check-readiness.py`. Alternative: none.
   Run: `python3 -I scripts/check-readiness.py . --platform <p>`, adding `--expo-config <file>` from Step 2. On `web`, add `--collects-data yes` when the confirmed inventory has an item scoped to `web`, `--collects-data no` when it has none, and no flag while it is unconfirmed. A confirmation in the request counts once the scan in Step 4 agrees with it; if the scan disagrees, show the creator what it found and treat the inventory as unconfirmed.
   Expect: one `PASS`, `FAIL`, or `UNKNOWN` line per check. Exit 0 means nothing failed, 1 means a failure. Exit 2 is a usage or environment error: stop and show the creator the message. Copy every line into `platforms.<p>.checks`: `id` is the name before the colon, `result` the lowercased word, `evidence` the text after the colon up to any `; fix:`, and `fix` the entry for that check and framework in `references/checks.md` (empty on a pass). Rules behind each check: `references/checks.md`.

4. Scan the data inventory. Default: read dependencies and code as `references/data-inventory.md` says. Alternative: none.
   Run: when `readiness.md` holds a confirmed inventory and the recorded revision is current, keep it and skip the scan. Otherwise scan, keep every matching confirmed item verbatim, and add what is new as unconfirmed.
   Expect: `data_inventory.items`, each with `evidence`, scoped by `platforms`, with `unknown` wherever code and vendor documents do not say. Never invent what an SDK does. `confirmed` stays `true` only when the scan added and changed nothing, or the creator has just confirmed the list.

5. Add the judgment checks and write both files. Default: the Write tool, each whole file in one write. Alternative: none.
   Run: append to `checks`:
   - `data-inventory`, every platform: `pass` when `data_inventory.confirmed` is `true`, else `unknown`.
   - `age-rating`, `ios` and `android` only: `pass` when every question in `references/age-rating.md` for that platform has an answer, else `unknown`.
   - `smoke-run`, `ios` and `android` only: `unknown` until Step 6 runs. The web has no smoke run and no age rating.

   Result rule, per platform: any `fail` makes the platform `fail`. Otherwise `pass` needs `data_inventory.confirmed: true`, no `unknown` check other than `smoke-run`, and a clean committed revision from Step 1. Anything else is `unknown`.

   Write `.app-creators/readiness.md`, keeping `age_rating.answers` and any confirmed items from the earlier file. Keep another platform's block only when the recorded revision is current, because the file has one `revision`.

   ```yaml
   ---
   schema: "1.0"
   revision: "<commit, or empty>"
   date: YYYY-MM-DD
   platforms:
     ios:
       result: pass | fail | unknown
       checks:
         - { id: icon-sizes, result: pass | fail | unknown, evidence: "", fix: "" }
   data_inventory:
     confirmed: false
     items:
       - data_type: ""
         platforms: []
         evidence: ""
         purpose: ""
         linked_to_user: unknown
         used_for_tracking: unknown
         shared_with: []
         optional: unknown
   age_rating:
     answers: {}
   ---
   ```

   Below the frontmatter, note in plain words why a platform is `unknown`. Then write `state.md` per Update state.
   Expect: both files exist, even if nobody ever answers. Every later change repeats this write.

6. Run the smoke test (`ios`, `android`). Default: the framework's command in `references/smoke-run.md`. Alternative: none.
   Run: check the toolchain first. If it is absent, the check stays `unknown`, and you tell the creator the risk: a crash that shows only in a release build will first appear after upload or in review. Absence does not block a `pass` by itself. If the toolchain exists and the tree is clean, run in a temp export of `HEAD`, never in the project tree: a prebuild there would create native folders, dirty the tree, and change which config wins.
   Expect: `pass` when a release build launches on a simulator or emulator through its first screen, `fail` when the build or launch fails for a reason in the project, and `unknown` otherwise. Flutter cannot run release mode on a simulator or emulator, so `references/smoke-run.md` gives its rule. Update both files.

7. Report, then ask once. Default: one message. Alternative: none.
   Run: for each platform give `result` and each `FAIL` with what to do about it, taken from its `fix`; a cause alone is not enough. An empty privacy URL's fix is to publish a policy page, then send its URL. Then ask, together and only for what is missing: the privacy policy URL; a review of the inventory (show the list, say what each item rests on, ask them to confirm it and settle `unknown` fields; on a rerun show only added or changed items); the age rating answers (`references/age-rating.md`, only for `ios` or `android`, only unanswered ids); which fixes they want applied; and a commit, if Step 1 found no clean commit. Never ask for the framework, the bundle id, or anything else a file shows.
   Expect: the creator answers, or the session ends with both files already recording the state.

8. Apply the answers. Default: the Write tool. Alternative: none.
   Run: write the URL to `state.md`. Set `data_inventory.confirmed: true` only when the creator confirms. Store answers under `age_rating.answers` by question id. Then repeat Steps 3 and 5, so the script sees the URL and the web check sees the confirmed inventory.
   Expect: `checks` and `result` reflect the answers.

9. Fix what the creator agreed to. Default: the fix in `references/checks.md`. Alternative: none.
   Run: for each `FAIL`, show the fix. Change a file only after the creator agrees to that fix. A fix dirties the tree, so ask for a commit, then repeat from Step 1. Building app features is out of scope: name what is missing and leave it to the creator.
   Expect: a rerun at the new commit shows the line as `PASS`.

10. Name the next skill and stop. Default: this list. Alternative: none.
    Run: first do Verify. Then tell the creator to commit `.app-creators/`; it holds no secrets, and the next skill reads it. Then name the next skill: `publish-web` for web; for iOS, `store-listing` and `publish-ios` (not shipped yet); for Android, `store-listing` and `publish-android` (not shipped yet).
    Expect: one final reply with each platform's `result` and the path to the report. A `pass` with `smoke-run: unknown` says the smoke run did not run, and states the risk. Never say the app is approved, published, or live.

## Verify

- Re-read `.app-creators/readiness.md` and `.app-creators/state.md` with the Read tool, and compare them with what you meant to write. `readiness.<p>.result` equals `platforms.<p>.result`.
- Rerun `python3 -I scripts/check-readiness.py . --platform <p>` with the same flags, and compare each line with its entry in `platforms.<p>.checks`.
- Recompute the result rule from `checks`, `data_inventory.confirmed`, and Step 1. Expect the written `result`.
- `revision` equals the output of `git rev-parse HEAD` when it is not empty. Expect the same value in `readiness.<p>.revision`.
- No file holds a secret. No project file outside `.app-creators/` changed, unless the creator agreed to that fix.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `xcodebuild -version` fails: "requires Xcode, but active developer directory ... is a command line tools instance" | Only Command Line Tools are installed | `smoke-run` stays `unknown`; say the risk. If the creator wants the run: install Xcode, then select it with `xcode-select -s` |
| `java -version` fails: "Unable to locate a Java Runtime" | No JDK is installed | `smoke-run` stays `unknown`; say the risk. Expo's Android build needs Android Studio and Java |
| `git` exits 72: "couldn't create cache file ... xcrun_db" | A sandboxed agent on macOS, where `/usr/bin/git` is an Xcode shim that cannot write its cache | Use a real git binary if one exists, such as `/opt/homebrew/bin/git`. If none exists, write `revision: ""` and `unknown`, and tell the creator git could not run |
| A Flutter app reports it cannot run release mode on an emulator | Flutter supports release mode only on physical devices | Run only the release build; `smoke-run` stays `unknown` unless a physical device is connected |
| The release build from `npx expo run:android --variant release` is not signed for Google Play | Expo documents this build as a test of production-only bugs | Expected; signing belongs to `publish-android` (not shipped yet) |

## Update state

Read the whole frontmatter, change only these fields, and write the whole frontmatter back in one write. Keep the notes below it.

- `readiness.<p>`: `{ result, revision, date }` for each assessed platform. `revision` is `""` with no commits.
- `provided.publish-readiness.privacy_policy_url`: only when the creator answered.
- `updated`: today.
- `history`: append one `{ skill: publish-readiness, version: "0.1.0", date: <YYYY-MM-DD>, result: <pass | fail | unknown> }`, where `result` is `fail` if any platform failed, else `unknown` if any is unknown, else `pass`. If the creator's answers later change it, append one more row; never edit a row.

## Sources

- Rules behind each script check, with their sources: `references/checks.md`. Inventory, age rating, and smoke run: `references/data-inventory.md`, `references/age-rating.md`, `references/smoke-run.md`.
- [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/), checked 2026-11-02.
- [Manage app privacy, App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), checked 2026-11-02.
- [Age ratings values and definitions, App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/), checked 2026-11-02.
- [Provide information for Google Play's Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469), checked 2026-11-02.
- [User Data policy, Play Console Help](https://support.google.com/googleplay/android-developer/answer/10144311), checked 2026-11-02.
- [Content ratings, Play Console Help](https://support.google.com/googleplay/android-developer/answer/9859655), checked 2026-11-02.
- [Expo CLI: config and compiling](https://docs.expo.dev/more/expo-cli/), checked 2026-11-02.
- [Expo: Continuous Native Generation](https://docs.expo.dev/workflow/continuous-native-generation/), checked 2026-11-02.
- [Flutter: set up iOS development](https://docs.flutter.dev/platform-integration/ios/setup), checked 2026-11-02.
- [Flutter's build modes](https://docs.flutter.dev/testing/build-modes), checked 2026-11-02.
- [Git pathspec, exclude magic](https://git-scm.com/docs/gitglossary), checked 2026-11-02.
- [git-rev-parse](https://git-scm.com/docs/git-rev-parse), checked 2026-11-02.
- [git-status](https://git-scm.com/docs/git-status), checked 2026-11-02.
- [git-diff](https://git-scm.com/docs/git-diff), checked 2026-11-02.
