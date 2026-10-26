---
name: app-creators
description: >
  Start here. Detect the project's framework and which destinations it
  already carries config for, ask the creator two questions (the outcome
  they want now, the destinations they want), create .app-creators/state.md,
  and name the next skill to run. Use when the creator says start, where do
  I begin, set up app creators, what's next, ship my app, or when any
  App Creators skill reports that state.md is missing or on a different
  schema major. 开始, 从哪开始, 下一步, 发布我的应用.
license: MIT
metadata:
  stage: core
  platform: all
  version: "0.1.0"
  verified: "unverified"
  verified_version: ""
  zh: SKILL.zh.md
---

中文版：先读 SKILL.zh.md。If the creator writes in Chinese, read SKILL.zh.md and follow it instead.

## When to use

- The creator wants to begin: "start", "where do I begin", "set up app creators", "ship my app".
- The creator asks what to do next: "what's next".
- Another App Creators skill reported that `.app-creators/state.md` is missing, or that its `schema` has a different major version.
- Not this skill: the creator wants the app published now and state exists. Use `publish-web`, or the platform skill for their destination.
- Not this skill: the creator asks whether the app is ready to publish. Use `publish-readiness` (not shipped yet).

## What you must provide

- The outcome you want now: publish, get users, or make money. It decides which skill runs next. Takes 1 minute.
- The destinations you want: web, iOS, Android, any subset. Later skills act only on wanted destinations and never ask again. Takes 1 minute.

If the request already states an answer (for example "publish this to the web"), record it and do not ask. Ask only for what is missing, once, in one message.

Optional, never required: the app's display name and a one-sentence description. If the creator does not give them, leave `app.name` and `app.description` as `""`, say so, and continue. Never ask for a token or credential; this skill records no accounts.

## Before you start

This skill requires no fields. It is the only skill that creates `.app-creators/state.md` and the only one that migrates it across a schema major. Run it from the project root. It needs only directory listings, file reads, and one file write; never use a shell for detection.

Check for `.app-creators/state.md` and take the matching branch:

- (a) No file: create it (steps 1 to 5).
- (b) `schema` major `1`: read the whole frontmatter. Re-detect only the detected facts (`framework.*`, `app.slug`, `app.languages`, `targets.*.detected`) and overwrite them on evidence. If the table gives `unknown` and the stored `framework.evidence` is `creator`, keep the stored `framework.kind` and `framework.package_manager` and do not ask again; a real table match overwrites the stored answer, because project evidence wins. Preserve every provided fact, recorded outcome, unknown key, the `schema` value, and every `history` row verbatim. Ask only for `goal` when it is `""` and for `targets.*.intent` when it is `undecided`. Record `app.name` and `app.description` only if the creator offers them. Never ask about `accounts.*`, `tools.*`, `monetization.model`, or `provided.*`: the skills that need them ask, and this skill cannot write them. Never overwrite a provided fact without asking the creator.
- (c) Older major: migrate. Carry every provided fact, recorded outcome, and `history` row forward under the new names, re-detect the detected facts, then write. Only major `1` exists today, so this branch has no mapping yet; it is listed for completeness.
- (d) Newer major than `1`: stop. Tell the creator to update the plugin. Never downgrade the file.

## Steps

1. Detect the framework. Default: list the project root and read the files in the table. Alternative: ask the creator, only if the table gives `unknown` and no earlier `creator` answer is stored (branch (b)).
   Run: list the project root only; do not recurse. The only subdirectories to look into are `app/` and `gradle/` (row 4) and, in step 2, whether `ios/`, `android/`, and `web/` exist. Walk the table top to bottom; the first match wins. Set `framework.evidence` to the file that decided it.

   | # | evidence at the project root | `framework.kind` |
   |---|---|---|
   | 1 | `app.json` or `app.config.json` with a top-level `expo` key; or `expo` in `package.json` `dependencies` (an Expo project with `app.config.js` or `app.config.ts` has it there) | `expo` |
   | 2 | `pubspec.yaml` whose `dependencies` include `flutter` (`sdk: flutter`); a `pubspec.yaml` without it is a plain Dart package: continue down the table | `flutter` |
   | 3 | a `*.xcodeproj` or `*.xcworkspace` directory, or `Package.swift` declaring an `executableTarget` | `xcode` |
   | 4 | `build.gradle` or `build.gradle.kts`, at the root or in `app/`, that applies `com.android.application` by id, or by a version-catalog alias such as `alias(libs.plugins.android.application)` whose entry in `gradle/libs.versions.toml` has that id | `kotlin` |
   | 5 | `next.config.js`, `next.config.mjs`, or `next.config.ts`; or `next` in `package.json` `dependencies` | `nextjs` |
   | 6 | `vite.config.js`, `vite.config.ts`, `vite.config.mjs`, or `vite.config.mts`; or `vite` in `package.json` `dependencies` or `devDependencies` | `vite` |
   | 7 | `index.html` and none of the above | `static` |
   | 8 | none of the above | `unknown` |

   Order matters: an Expo app may carry a web bundler, so row 1 comes before rows 5 and 6; Flutter, Xcode, and Kotlin come before the JavaScript rows. The enum value for Xcode projects is `xcode`. On `unknown`, ask the creator which framework the app uses, record the answer, and set `framework.evidence: "creator"`; on a rerun, branch (b) keeps an earlier answer instead.
   Package manager, first match: `pnpm-lock.yaml` → `pnpm`; `yarn.lock` → `yarn`; `bun.lock` or `bun.lockb` → `bun`; `package-lock.json`, or `package.json` alone → `npm`; no `package.json` → `none`.
   Expect: one `framework.kind`, one `framework.evidence`, one `framework.package_manager`.

2. Detect destinations. Default: the result of step 1 plus the root listing. Alternative: none needed.
   Run: set `targets.<destination>.detected` to `"yes"` when the row below matches, else `"no"`.
   - `web`: `vite`, `nextjs`, or `static`; `expo` with `web` in its platforms; `flutter` with a `web/` directory.
   - `ios`: `xcode`; `expo` with `ios` in its platforms; `flutter` with an `ios/` directory.
   - `android`: `kotlin`; `expo` with `android` in its platforms; `flutter` with an `android/` directory.
   Expo platforms: the `platforms` list in the app config: under `expo` in `app.json` or `app.config.json`, or at the top level of `app.config.js` or `app.config.ts` when it is written there as a literal list. When it is absent, or the JS/TS config does not state it as a literal, use the Expo default: `ios` and `android`, plus `web` when `react-dom` is in `package.json` `dependencies`.
   Expect: each `detected` is `"yes"` or `"no"`. Detection never sets `intent` or `status`.

3. Ask the creator. Default: one message with only the questions the request did not already answer. Alternative: none; never split the questions across messages.
   Run: ask which outcome they want now (publish, get users, make money) and which destinations they want (web, iOS, Android).
   Expect: outcome maps to `goal`: publish → `publish`, get users → `acquire`, make money → `monetize`. Each destination the creator names → `intent: wanted`; each one they decline → `not-wanted`; each one not mentioned → `undecided`. Record `app.name` and `app.description` only if given.

4. Write `.app-creators/state.md`. Default: the Write tool, the whole file in one write. Alternative: none; never write the file in pieces, not even on a rerun.
   Run: write the frontmatter per the schema in the plugin's `docs/STATE.md`; when that file is not installed alongside the skill, the example below is complete and sufficient. Then write a notes paragraph below it: the date, what was detected, what was asked. Write every field; unknown is `""` or `unknown`, never omitted. Values on first run:
   - every `targets.*.status`: `unknown`; every `readiness.*`: `{ result: unknown, revision: "", date: "" }`.
   - `accounts.*`, `tools.*`, `monetization.model`, and every leaf of `provided`: `""`. Do not invent `missing` or `none`.
   - `app.slug`: kebab-case of `package.json` `name` (drop an `@scope/` prefix), else `pubspec.yaml` `name`, else the Expo `slug`, else the directory name.
   - `app.languages`: `[en]`, unless the project shows otherwise (for example an `i18n` or `locales` directory: list the locales it shows).
   - `updated`: today. `history`: `[{ skill: app-creators, version: "0.1.0", date: <today>, result: ok }]`.

   Example for the Vite to-do fixture:

   ```yaml
   ---
   schema: "1.0"
   updated: 2026-10-26
   app:
     name: ""
     slug: todo-vite
     description: ""
     languages: [en]
   framework:
     kind: vite
     package_manager: npm
     evidence: vite.config.ts
   targets:
     web:
       intent: wanted
       detected: "yes"
       status: unknown
       url: ""
       provider: ""
       domain: ""
     ios:
       intent: undecided
       detected: "no"
       status: unknown
       bundle_id: ""
       asc_app_id: ""
     android:
       intent: undecided
       detected: "no"
       status: unknown
       package: ""
   readiness:
     web: { result: unknown, revision: "", date: "" }
     ios: { result: unknown, revision: "", date: "" }
     android: { result: unknown, revision: "", date: "" }
   accounts:
     apple_developer: ""
     google_play: ""
     vercel: ""
   tools:
     deploy: ""
     analytics: ""
     iap: ""
     ads: ""
     payments: ""
     attribution: ""
   monetization:
     model: ""
   goal: publish
   provided:
     publish-readiness:
       privacy_policy_url: ""
       support_email_env: ""
   history:
     - { skill: app-creators, version: "0.1.0", date: 2026-10-26, result: ok }
   ---
   ```

   Expect: the file exists. Tell the creator it holds no secrets and to commit it.

5. Name the next skill and stop. Default: the routing table. Alternative: none.
   Run: pick the row for `goal` and each wanted destination. Skills marked "not shipped yet" do not exist; never invent one.

   | `goal` | destination | next skill |
   |---|---|---|
   | `publish` | web | `publish-web` |
   | `publish` | iOS | `publish-ios` (not shipped yet) |
   | `publish` | Android | `publish-android` (not shipped yet) |
   | `publish` | any, before publishing | `publish-readiness` (not shipped yet); until it exists, each publish skill runs its own minimal checks |
   | `acquire` | any | `analytics-setup` (not shipped yet) first, then `launch-channels` (not shipped yet); also `growth-loops` and `paid-ua` (not shipped yet) |
   | `acquire` | iOS or Android | also `aso` (not shipped yet) |
   | `monetize` | any | `monetize-strategy` (not shipped yet); for ads, `monetize-ads` (not shipped yet); then `payouts-and-tax` (not shipped yet) |
   | `monetize` | iOS or Android | `monetize-iap` (not shipped yet) |
   | `monetize` | web | `monetize-web` (not shipped yet) |

   Expect: one final reply with the detected framework and its evidence, the recorded `goal` and intents, the path `.app-creators/state.md`, and "Next: run `publish-web`" or the routed name. For a skill that is not shipped yet, say so and what the creator can do meanwhile. Never perform a pipeline step and never claim an external outcome: never say the app is published, listed, or live.

## Verify

- `.app-creators/state.md` exists. Re-read it with the Read tool and compare it with what you meant to write.
- The frontmatter parses as YAML and starts with `schema`: `"1.0"` on create, the earlier value of major `1` on a rerun.
- `framework.kind` is one of `expo`, `flutter`, `xcode`, `kotlin`, `nextjs`, `vite`, `static`, `unknown`, and `framework.evidence` names a file that exists, or is `creator`.
- Every `targets.*.status` is `unknown` on first run, and every `targets.*.detected` is the string `"yes"` or `"no"`.
- `goal` is set.
- The next skill you named exists in this plugin's `skills/` directory, or you labelled it not shipped yet.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| The project has both `vite.config.*` and `next.config.*` | A Next.js app with a Vite-powered tool, for example Vitest | Table order gives `nextjs` when `next` is in `dependencies`; confirm with the creator |
| `app.json` has no `expo` key | A React Native CLI app or another app, not Expo | Do not record `expo`; continue down the table, and on `unknown` ask the creator |
| `schema` major is newer than `1` | The plugin is older than the state file | Stop; tell the creator to update the plugin |
| The creator wants a destination the project has no config for | The platform has not been set up yet | Record `intent: wanted` and `detected: "no"`; the platform skill handles setup |
| The file already has provided facts | An earlier run or another skill recorded them | Preserve them; ask only for `goal` when it is `""` and `targets.*.intent` when it is `undecided`; never ask about `accounts.*`, `tools.*`, `monetization.model`, or `provided.*` |

## Update state

Read the whole frontmatter first if the file exists, change only these fields, append one `history` row, and write the whole frontmatter back in one write.

- Detected facts, from this run's evidence: `framework.kind`, `framework.package_manager`, `framework.evidence`, `app.slug`, `app.languages`, `targets.*.detected`.
- Provided facts, only from answers given in this run: `goal`, `targets.*.intent`, `app.name`, `app.description`.
- `schema`: `"1.0"` on create only. On a rerun with major `1`, keep the existing value verbatim: a newer minor such as `"1.1"` stays, and so do the keys it added. Never downgrade the file. `updated`: today.
- `history`: append `{ skill: app-creators, version: "0.1.0", date: <YYYY-MM-DD>, result: ok }`.

On create, write every other field at its first-run value from step 4; `targets.*.status` is always `unknown` there. Never write `readiness.*`, `accounts.*`, `tools.*`, `monetization`, or `provided`: leave them at the first-run value on create and preserve them on a rerun.

## Sources

- [Expo: configure with app config](https://docs.expo.dev/workflow/configuration/), checked 2026-10-26.
- [Expo: app.json / app.config.js reference](https://docs.expo.dev/versions/latest/config/app/), checked 2026-10-26.
- [Expo: install Expo modules in an existing React Native project](https://docs.expo.dev/bare/installing-expo-modules/), checked 2026-10-26.
- [Flutter: the pubspec file](https://docs.flutter.dev/tools/pubspec), checked 2026-10-26.
- [Flutter: build a web app](https://docs.flutter.dev/platform-integration/web/building), checked 2026-10-26.
- [Flutter: build and release an iOS app](https://docs.flutter.dev/deployment/ios), checked 2026-10-26.
- [Flutter: build and release an Android app](https://docs.flutter.dev/deployment/android), checked 2026-10-26.
- [Xcode: managing multiple projects and their dependencies](https://developer.apple.com/documentation/xcode/managing-multiple-projects-and-their-dependencies), checked 2026-10-26.
- [Xcode: creating a standalone Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode), checked 2026-10-26.
- [Swift Package Manager: creating a Swift package](https://docs.swift.org/latest/documentation/packagemanagerdocs/creatingswiftpackage), checked 2026-10-26.
- [Android: configure your build](https://developer.android.com/build), checked 2026-10-26.
- [Android: migrate your build to version catalogs](https://developer.android.com/build/migrate-to-catalogs), checked 2026-10-26.
- [Next.js: next.config.js](https://nextjs.org/docs/app/api-reference/config/next-config-js), checked 2026-10-26.
- [Next.js: installation](https://nextjs.org/docs/app/getting-started/installation), checked 2026-10-26.
- [Vite: configuring Vite](https://vite.dev/config/), checked 2026-10-26.
- [Vite: getting started](https://vite.dev/guide/), checked 2026-10-26.
- [npm: package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json), checked 2026-10-26.
- [npm: package.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-json), checked 2026-10-26.
- [pnpm: pnpm install](https://pnpm.io/cli/install), checked 2026-10-26.
- [Yarn: yarn.lock](https://classic.yarnpkg.com/lang/en/docs/yarn-lock/), checked 2026-10-26.
- [Bun: lockfile](https://bun.com/docs/pm/lockfile), checked 2026-10-26.
