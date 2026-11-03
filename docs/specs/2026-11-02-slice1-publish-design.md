# Slice 1 Publish skills: design

spec-review: completed 2026-11-02

Scope: roadmap Slice 1. The skills `publish-readiness`, `store-listing`,
`publish-ios`, `publish-android`, and `store-review`, each with its zh
file, plus registry submission. Requirements:
`docs/prds/prd-phase1-skills.md`. Contract every skill follows:
`docs/specs/2026-10-26-skill-conventions-design.md`. Field rules:
`docs/STATE.md`.

## 1. Problem & goals

`publish-web` proves the pattern for the web. The PRD's first goal also
needs a creator's agent to reach the App Store and Google Play without
the creator reading store documentation. Those paths differ from the web
in three ways: the store holds legal, paid, and identity steps only a
human can do; a submission cannot be quietly retried; and four frameworks
take four build routes.

Goals, with evidence:

- A creator's agent can take an Expo, Flutter, or Xcode app to App Store
  review, and an Expo, Flutter, or Kotlin app to Google Play review, and
  stop at every human step with one exact ask. Evidence: level 2 evals,
  en and zh, per route; level 3 runs for every step that needs no paid
  account, recorded per route in `verified-runs.md`. A step this machine
  cannot run stays open in that record; it is never counted as done.
- A gap found before submission is reported with its fix, not found in a
  rejection. Evidence: `check-readiness.py` fails on seeded gaps per
  framework and passes on the fixtures.
- No skill re-asks a fact another skill recorded. Evidence: eval graders
  on `publish-ios` and `publish-android` reading readiness and listing
  files instead of asking.
- A rerun never submits, pays, or creates twice. Evidence: every
  effective step checks the store first, and an eval grader requires
  that check before the action.
- Every store fact traces to a dated primary source. Evidence: `## Sources`
  in each skill; reviewers spot-check against the live pages.

## 2. Non-goals

- Chinese app stores, WeChat, or mainland-China distribution. zh language
  files stay.
- ASO, paid UA, analytics, monetization setup. Roadmap Slices 2 and 3.
  In-app purchase appears only as a disclosure check in `store-review`.
- macOS, watchOS, tvOS, visionOS, Wear OS, Android TV, enterprise and
  custom-app distribution.
- Building app features. Readiness fixes such as icons and permission
  strings are in scope, and only when the creator agrees to each one.
- Agent-run steps on a personal or production account. See §3.5.
- A shared library between skills. Skills install separately, so each
  ships what it runs.

## 3. Architecture & decisions

### 3.1 Skill order and how the skills connect

```
app-creators -> publish-readiness -> store-listing -> publish-ios / publish-android
                                                       ^
                                         store-review -+ (pre-submit checks, rejections)
```

Build order is readiness, listing, iOS, Android, review, registry. The
roadmap lists listing after iOS and Android, yet both submission steps
read its output, so listing moves up. The roadmap's own header allows
reordering on evidence.

Each downstream skill runs without its upstream skill being installed:
it names the missing skill, gives the install command for the creator to
run, and proceeds only on the gate rules in §4.4. Rejected: hard
dependencies between skills, because the `npx skills` picker can install
one skill alone.

### 3.2 One skill per platform, one reference per route

A route is a framework plus a store path. `SKILL.md` holds the shared
steps under the 300-line budget. Route detail goes to `references/`:
`expo.md`, `flutter.md`, `xcode.md` for iOS; `expo.md`, `flutter.md`,
`gradle.md` for Android. Rejected: one skill per framework, which
multiplies listings and splits install counts. FR-7 and FR-8 require the
siblings and the native paths.

A framework with no route on a platform says so and stops. Kotlin to
`publish-ios` and Xcode to `publish-android` are the two cases.

### 3.3 Defaults

One default and one alternative per step, per FR-6. Doers confirm each
against current vendor docs before writing it and replace it if the docs
no longer support it, recording why in the handoff.

| step | default | alternative |
|---|---|---|
| iOS signing, Expo | EAS managed credentials | Xcode automatic signing |
| iOS signing, Flutter and Xcode | Xcode automatic signing | manual certificates and profiles |
| iOS build, Expo | `eas build` | local EAS build |
| iOS build, Flutter | `flutter build ipa` | Xcode archive |
| iOS build, Xcode | Xcode archive | `xcodebuild` |
| iOS upload | `eas submit` for Expo; the documented Apple upload tool otherwise | Xcode Organizer |
| Android signing | Play App Signing with an EAS upload key for Expo | Gradle keystore |
| Android build, Expo | `eas build` | local EAS build |
| Android build, Flutter | `flutter build appbundle` | Gradle |
| Android build, Kotlin | `./gradlew bundleRelease` | Android Studio bundle generation |
| Android upload | `eas submit` for Expo; Play Console for the first upload | Play Developer API |
| Screenshots | creator's device or simulator captures, sized by `check-listing.py` | Fastlane `snapshot` for Xcode routes |

### 3.4 Deterministic checks are scripts; judgment stays in the skill

`publish-readiness/scripts/check-readiness.py` and
`store-listing/scripts/check-listing.py` run on Python 3 standard library
only, with `python3 -I`. They parse JSON, plist, XML, and PNG headers,
which bash and awk handle poorly. Rejected: bash, after `check-pwa.sh`
needed a hand-written scanner for a smaller job.

`check-readiness.py <project> --platform ios|android|web` prints one
`PASS`, `FAIL`, or `UNKNOWN` line per check and exits 0 when nothing
fails, 1 on a failure, 2 on a usage or environment error. A check it
cannot decide statically is `UNKNOWN`, never `PASS`. Every `PASS` needs an
authoritative input: a data format the tools themselves consume or emit,
meaning JSON, plist, Android manifest XML, HTML, a web manifest, image files,
and the framework's own resolved output, plus `.app-creators/state.md`, this
skill family's own data file. The script never interprets source that only a
compiler or a build system can evaluate, so a Gradle file, a `.pbxproj`, an
`.xcconfig`, or a JS or TS config is not an input. A native project with no
resolved input gives `UNKNOWN` for the affected checks, neither `FAIL` nor
`PASS`. The skill runs the framework's own commands where it can, and passes
their output with repeatable `--resolved <file>`; the script classifies each
file by content as Xcode's resolved build settings, an Expo config, or the
manifest of a built Android release.

`check-readiness.py` checks only what files show: app name, bundle id or
package, icon presence and pixel sizes per platform, an alpha channel on
the iOS marketing icon where Apple forbids one, permission usage strings
for declared permissions and for permission APIs detected in the code,
and privacy policy URL present in state. The skill handles what needs
judgment: the data collection inventory, age rating answers, and the
smoke run.

Web readiness covers name and icons. A missing privacy policy URL fails web
readiness only when the confirmed inventory lists collected data, because a
`fail` stops `publish-web` and a site that collects nothing must still deploy.
PWA installability stays `publish-web`'s check.

The smoke run means: the app builds in release configuration and launches
on a simulator or emulator without crashing through its first screen. If
the toolchain is absent, the check is `UNKNOWN` and the skill says so; it
does not block a pass on its own, and the creator is told the risk.

### 3.5 Human gates and the credential boundary

Three classes of step, and each step in a publish skill names its class:

- **Human-only:** enrollment, payment, identity verification, legal
  agreements, two-factor login, creating API keys. The skill gives one
  exact ask and waits.
- **Effective:** creating an app record, uploading a build, submitting
  for review, promoting a track, starting a rollout. Conventions §3.2 applies:
  check the store first, act, record the outcome. Where the agent has no read
  access to the store, the check is asking the creator to look and report; it
  is never skipped.
- **Go-ahead:** the effective steps that reach the public or a reviewer.
  They are submit for review, promote to production, and rollout
  percentage changes. The skill shows what it is about to submit and needs
  the creator's explicit yes in the same session. Rejected: a standing yes
  in state, because a stale yes would submit a changed app.

Secrets stay out of the repo and out of `state.md`. State records env var
names under `provided.<skill>`, such as the App Store Connect key path
variable.

When a creator runs a skill, the creator logs in and the agent operates that
session. Verification is different: agent-run levels 2 and 3 use fixture-only
accounts, and no agent verifying these skills logs into or operates a personal
Apple, Google, or Expo account. With no
fixture account, level 3 stops at the first step that needs one and the
verified-runs row records where and why. `metadata.verified` stays
`unverified` until a level 4 run.

### 3.6 Research discipline

Store rules change and models remember stale ones. Doers fetch every store
fact from a current primary source before writing it: Apple Developer and
App Store Connect help, Google Play Console help and Android developer
docs, Expo, Flutter. Nothing goes in from memory. Each fact in a skill
either has its source in `## Sources` with the check date, or is removed.

This spec names facts to verify and asserts no values:

- Apple: program enrollment types and D-U-N-S, encryption export
  compliance, App Privacy categories, age rating questions, required
  screenshot sizes, required upload toolchain version, current upload tool.
- Google: developer account types and verification, closed-testing rule for
  new personal accounts, target API level requirement, Data safety form,
  content rating, whether a first upload must be manual, staged rollout.
- Both: listing field character limits, review time statements, appeal routes.

Troubleshooting rows follow the convention: seen in a verified run, or
documented by the vendor. Third-party blogs may suggest where to look, but
they never count as the source.

### 3.7 Fixtures

Per conventions §3.5, `todo-expo`, `todo-flutter`, `todo-swift`, and
`todo-kotlin` arrive with the slice that needs them, on a branch in the
fixtures repo. Each is the same to-do app with name, id, icons, and a
privacy-relevant permission so readiness has something real to check.
Generate from the framework's own template where one exists. Fixture evals
use `git archive` at a pinned sha, so the local commit suffices until Kyle
pushes it.

This machine lacks a full Xcode install and a JDK. A missing toolchain is not an
exemption from conventions §3.4 level 3. Each affected route's level 3 stays open:
its `verified-runs.md` row names the step and the missing tool, and its slice's
handoff lists it as a blocked prerequisite for Kyle. The slice ships at the
`unverified` status level 3 already allows, and it does not install system
toolchains itself.

## 4. Data contracts

### 4.1 `.app-creators/readiness.md`

Written by `publish-readiness`, which also sets `state.md.readiness.<platform>`.
`revision` is the project's commit at assessment.

A revision is current when no project file outside `.app-creators/` differs
from it, in commits or the working tree. Excluding that directory is required:
the skill writes there, and the creator is told to commit it, so comparing raw
commits would make every pass stale at once. Slice D applies this definition to
`docs/STATE.md` and to `publish-web`'s readiness gate. A project with uncommitted
changes outside that directory, or with no git history, cannot record a pass:
the platform is written as `unknown` and the skill asks the creator to commit.

A rerun keeps the creator's confirmed inventory items and age rating answers,
and asks only about what is new. They are provided facts under the ownership
rule in `docs/STATE.md`.

```yaml
---
schema: "1.0"
revision: "<commit>"
date: 2026-11-02
platforms:
  ios:
    result: pass | fail | unknown
    checks:
      - { id: icon-sizes, result: pass | fail | unknown, evidence: "", fix: "" }
data_inventory:
  confirmed: false              # the creator reviewed this list
  items:
    - data_type: ""             # plain name, e.g. email address
      platforms: []             # ios, android, web: where this build collects it
      evidence: ""              # file or SDK that shows it
      purpose: ""
      linked_to_user: unknown   # yes | no | unknown
      used_for_tracking: unknown
      shared_with: []           # third parties
      optional: unknown
age_rating:
  answers: {}                   # question id -> creator's answer
---
```

Rules: any failing check makes the platform `fail`, whatever else is unknown,
because publishing stops on a failure and proceeds on uncertainty. Otherwise
`result: pass` needs `data_inventory.confirmed: true` and no `unknown` check other
than the smoke run, per §3.4. Anything else is `unknown`. The publish skills map
`data_inventory` to App Privacy and Data safety at submission, using the items
scoped to that platform, and each form's answers come from this list, never from a
new interview.

A privacy disclosure must describe the build being submitted. The inventory's
confirmation therefore binds to `revision`. When the revision is not current,
the inventory scan runs again before submission, and the creator confirms only
the items it added or changed.

### 4.2 `.app-creators/listing.md`

Written by `store-listing`, read by the submission steps.

```yaml
---
schema: "1.0"
revision: "<commit>"
date: 2026-11-02
stores:
  app_store:
    en: { name: "", subtitle: "", description: "", keywords: "", promotional_text: "" }
  google_play:
    en: { title: "", short_description: "", full_description: "" }
screenshots:
  - { store: app_store, device_class: "", path: "", size: "" }
---
```

`check-listing.py` enforces field limits and image sizes from one table in
`references/limits.md`, which carries the source and check date. Locales
follow `app.languages`; en and zh are the two the skill generates.

### 4.3 `state.md`

No schema change. `targets.ios` and `targets.android` already hold status,
ids, and the review states. New creator-given facts go in `provided:`.
Status values are written only after the store confirms them. `testflight`,
`testing`, and `review` come from the store's own status, never from a
successful upload command.

A destination status says nothing about which release it describes, so every
effective step binds to a release identity: the store, the app id, the version,
and the build number, read from the project. Rerun safety comes from the store,
not from local records: the check looks for that identity, and an older release
does not count. A release existing does not prove a step finished, so each
effective step names the store state that proves its own completion: the build
listed for an upload, a review state for a submission, the track or percentage
for a promotion or rollout. Only that state reuses the step. Each step's outcome
goes in the frontmatter through `targets.*.status` and a `history` row.

Each go-ahead request names the release identity, the revision the build came
from, and the assessed revision. If the build's revision is not current by the
§4.1 definition, the skill rebuilds or treats readiness as stale. A current
assessment never stands in for a different build.

### 4.4 Gates

| reader | missing or stale input | behavior |
|---|---|---|
| any publish skill | readiness `fail` at the current revision | stop, list the fixes |
| any publish skill | readiness `unknown` or stale | run minimal checks, say so, and state it again in every go-ahead request |
| submission step | `data_inventory.confirmed` not true, or its revision not current | stop before the privacy form and run or name `publish-readiness` |
| submission step | listing file missing or a limit fails | stop and run or name `store-listing` |
| submission step | listing revision not current | show the creator the listing and screenshots in the go-ahead request and ask whether they still match the app |
| submission step | `store-review` not installed | say the pre-submit review was skipped, continue to the go-ahead |

### 4.5 Evals

Same shape as `evals/publish-web/`: `<case>-en` and `<case>-zh`, equal
graders. `publish-readiness` and `store-listing` cases grant Bash and Write
so their scripts run; they touch no network. Publish skill cases grant no
shell, so nothing can reach a store, and their command graders follow the
known `publish-web` ceiling. Required graders for publish skills:

- asked only for human-only facts and go-aheads;
- read readiness and listing rather than asking;
- named the route for the fixture's framework;
- stopped at the first human-only step;
- proposed no submit, promote, or rollout without an explicit yes.

## 5. Slice plan

All slices share one worktree and branch. Each ends with lint, its eval,
the next-skill routing update in `app-creators`, removal of its "not shipped
yet" labels across skills, README and `llms.txt` updates per the conventions
rule, and a roadmap tick. The README lists verification status per route, per
conventions §3.4. Fixture commits land on a same-named branch in the fixtures
repo.

### Slice D: publish-readiness

Proof: on `todo-expo`, a clean session writes `readiness.md`, sets
`state.md.readiness.ios`, and reports seeded gaps with fixes.

1. `todo-expo` fixture and a seeded-gap variant built by the test script.
2. `check-readiness.py` and `tests/check-readiness.test.sh`, with file trees
   for all four mobile frameworks and web. CI step.
3. `SKILL.md`, `SKILL.zh.md`, references, evals. Applies the §4.1 revision rule to `docs/STATE.md` and `publish-web`'s gate, and points the roadmap's Slice 1 at this file in this build order.

Depends on: none.

### Slice E: store-listing

Proof: on `todo-expo`, listing copy in en and zh passes `check-listing.py`, and
a one-over-limit field fails it.

1. `check-listing.py`, `references/limits.md`, tests, CI step.
2. `SKILL.md`, `SKILL.zh.md`, evals.
3. A lint rule that derives per-route status from `verified-runs.md` and fails when
   the README disagrees, per conventions §3.4. It covers every route listed so far.

Depends on: Slice D for the fixture.

### Slice F: publish-ios, Expo route

Proof: level 2 evals pass. Level 3 reaches the first account step on `todo-expo`
and records it.

1. `SKILL.md` with shared steps: account and signing, build and TestFlight,
   submission. `references/expo.md`.
2. `SKILL.zh.md`, evals.

Depends on: Slices D and E.

### Slice G: publish-ios, Flutter and Xcode routes

Proof: an eval on each fixture names the right route and stops at the right
step. Build-checked if the toolchain is present.

1. `todo-flutter` and `todo-swift` fixtures.
2. `references/flutter.md`, `references/xcode.md`, skill and zh route lines, evals.

Depends on: Slice F.

### Slice H: publish-android, all routes

Proof: evals on `todo-expo`, `todo-flutter`, and `todo-kotlin`. Level 3 reaches the
first account step. Build-checked if the toolchain is present.

1. `todo-kotlin` fixture.
2. `SKILL.md`, `references/expo.md`, `flutter.md`, `gradle.md`, target API check.
3. `SKILL.zh.md`, evals.

Depends on: Slices D, E, and G for the Flutter fixture.

### Slice I: store-review

Proof: on a seeded app with a login and no demo account, the skill flags it
before submission, and given a pasted rejection it names the guideline and the
response route.

1. `SKILL.md`, references per store, rejection reading and appeal steps.
2. `SKILL.zh.md`, evals, the pre-submit call in both publish skills.

Depends on: Slices F and H.

### Slice J: registry submission

Proof: the printed install commands load the skills in a clean Claude Code
session and a clean Codex session, against the public repo.

1. Clean-session verification, README updates, and a skills.sh listing check.

Depends on: Kyle pushing `main`, an external prerequisite. Without it this slice
reports `blocked-prerequisite`.

## 6. Assumed decisions

- **Slice 1 starts before `publish-web`'s level 3 run.** Kyle said to continue
  after that run was flagged as open (2026-11-02). Publish skills may copy the
  pattern; the run remains open on the roadmap.
- **Listing before the publish skills**, §3.1.
- **Python for readiness and listing scripts**, §3.4. Conventions §3.2 permits it.
- **Go-ahead is per session and per submission**, §3.5.
- **No schema change**, §4.3.
- **Build toolchains are not installed by the run**, §3.7.
- **Models.** Opus 5.5 at most, Sonnet where a doer's task allows, no Fable
  (Kyle, 2026-11-02).

## 7. Deferred hardening

- A lint rule that fails when a new skill misses README or `llms.txt` updates.
- Different disclosures per build variant within one platform.
- Fastlane as a full route rather than a screenshot alternative.
- A Codex-side eval of the same cases.
- Automated re-verification of store facts past the staleness window. Roadmap
  Slice 4 has the sweep.
- App Store Connect API and Play Developer API automation beyond what a step needs.

## 8. Review status

spec-review: completed 2026-11-02

## Decisions needing Kyle's attention

None block Slices D through I.

1. **Push `main`.** Slice J needs the public repo current, and creators get the old
   skills until then.
2. **Fixture accounts.** Apple Developer, Google Play, Expo, and Vercel accounts
   that exist only for fixtures. The first two cost money. Without them, level 3
   stops at the first account step on every store route.
3. **Toolchains.** A full Xcode and a JDK on this machine let the Xcode, Flutter
   iOS, Flutter Android, and Kotlin routes finish level 3. Otherwise those routes
   ship with level 3 open.
4. **Real app for level 4.** Still open from the conventions spec.
5. **Fixtures branch.** It merges and pushes separately from this repo. The pinned
   shas must be public before an outside contributor can run the evals.
