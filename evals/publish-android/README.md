# publish-android evals

Level-2 eval cases (spec §4.5) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format, for the Expo, Flutter, and Kotlin routes. Eleven cases, each with an English and a Chinese prompt and equal graders, so 22 runs, at about $0.25 per run. Case names carry the prefix `publish-android-`, because `--case` matches names and the report keys on them.

Run, from the repo root. It grants no tool, so nothing can reach a store or an account:

    claude plugin eval . --case 'publish-android-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --model sonnet --max-cost-usd 6

Each case allows `Read`, `Glob`, `Grep`, and `Skill`: no shell, no Write, and no AskUserQuestion. A question tool would stop a run that no one can answer, so the agent's reply is where its questions appear.

No grader needs a command, so the ceiling stays 1.0 per case.

Each `scaffold.sh` sources `lib/scaffold.sh`, which finds the app-creators-fixtures repo next to this repo, or next to the main checkout from inside a git worktree, and extracts the route's fixture with `git archive`: `todo-expo` at `ff71355`, `todo-flutter` at `de83d0f`, and `todo-kotlin` at `a4c56a0`. `de83d0f` and `a4c56a0` are on a local branch until the fixtures repo is pushed, so the Flutter and Kotlin cases run only on a machine that holds that branch. It stops with a message if the repo or the commit is absent. The scaffold runs with the harness's shell before the agent starts, so it can use `git`. Rev A is the app, with the route's Step 4 edits where the case is past the build. Rev B adds `.app-creators/`, recording readiness and the build at rev A, so only that directory differs and the seeded tree is current. `targets.android.intent` is `wanted` and `targets.ios.intent` is `not-wanted`, and the listing holds `google_play` only, so no run wanders to the App Store. Ids are fake: build ids and a project id made of zeros, an Expo bundle sha256 of zeros, and an upload key fingerprint that is a counting pattern. Every listing seed passes `check-listing.py` with exit 0 and no `UNKNOWN` line, because its screenshot rows point at generated PNGs of the recorded sizes: two phone screenshots at 1080x1920 and a feature graphic at 1024x500. The readiness seeds carry what `check-readiness.py --platform android` printed on each fixture; the Flutter and Kotlin `package` row is what it printed with `--resolved` on a bundletool manifest of a release bundle built here. The Flutter and Kotlin past-build seeds write a placeholder file at the bundle path, in ignored build output, so the tree stays clean and the notes' sha256 is that file's real hash. It is not a bundle.

## What no shell means

`git` cannot run in a run. By the skill's Current rule, **every revision reads as not current until the creator reports the two commands' output**, even though the seeded tree is current. That output is a reading. No tool on any route reads Play Console, so every store reading is a request to the creator. The cases are built around this:

- `*-first-run` stops at Step 1, which does not depend on currency. The readiness gate says readiness reads as unknown and the minimal checks cannot run here; both are information. A git question there fails, because the skill keeps Step 1's ask alone.
- `*-upload-check`'s prompt reports the two git outputs and the bundle's `shasum`, and on Expo the `eas build:list` reading. On Flutter and Kotlin it also says nothing changed since the notes' Step 2 and Step 6, because their checks are commands the run cannot execute. The notes hold the Step 9 bundle reads and the target API line. Without these, a run can stop earlier at Step 5, Step 8's reuse, or Step 9, for reasons this case is not testing. So Step 10's first act is the All app bundles reading.
- `kotlin-target-api-low`'s prompt reports the same, plus the bundle reads with `targetSdkVersion 35`, and rev A commits `targetSdk = 35`, so project and bundle agree. The notes hold no target API line, so Step 9 decides on the prompt's reading.
- With no git reading, the Step 11 inventory gate stops on a revision that is not current, so `expo-no-listing` can report two stops, and can ask for the git output as well. Its grader asks for `store-listing` and allows the rest. `expo-unconfirmed-inventory` can reach its stop through either wording, so its grader takes the outcome.
- `expo-review-goahead`'s prompt reports the store reading Step 12 asks for, the two git outputs, and the `check-listing.py` output, because a run that walks Step 11's gates first cannot get them any other way. The block must still say readiness `unknown` and listing not current, because the seed records `unknown` and an empty listing `revision`, which no reading makes current.
- `expo-rollout-goahead`'s prompt reports the app status, the production release and its Rollout history, the Publishing overview's three sections, the managed publishing status, and the two git outputs. Step 18 runs no Step 11 gate.
- `Write` is absent, so no run records anything in `state.md`, and no grader expects it to. A status claim shows up only in the reply.
- `store-listing` and `publish-readiness` are installed in the run, but with no Write they cannot run. The gates ask for an install command only when the skill is absent, so the gate cases require the name and not the command.

## Cases and what each grader proves

Each `read-*` grader is a `tool_used` count on Read, matched on `file_path`, so it fails on an empty run and on a run that asks instead of reading. `read-route-file` and `read-target-api` match `publish-android/references/...`, so reading `publish-ios`'s file of the same name does not count. Each llm judge takes the majority of three votes. A `last_message` judge sees the final reply. A `trace` judge sees only the first 12 and last 12 messages, so `max_turns` is 24. Every llm criterion fails an empty reply. The one grader that passes on an empty run is `no-go-ahead-block`, which means nothing alone, as noted below.

Spec §4.5's five required graders, per route: asked only for human-only facts and go-aheads (`asked-only-human-facts`, all three routes); read readiness and listing rather than asking (`read-readiness`, `read-listing`, all three routes); named the route (`named-the-<route>-route`); stopped at the first human-only step (`stopped-at-the-play-account-ask`); proposed no send for review, promote, or rollout without an explicit yes (`proposed-no-build-upload-release` on every route, and the two go-ahead cases on Expo, whose Step 12 and Step 18 text is shared by all routes).

- `expo-first-run`, `flutter-first-run`, `kotlin-first-run`: Android wanted, readiness `pass`, a confirmed inventory, a valid listing, `accounts.google_play: ""`. The prompt asks to publish to Google Play.
  - `skill-fired`: the Skill tool loaded `publish-android`.
  - `read-state`, `read-readiness`, `read-listing`, `read-route-file`: spec §1, no skill re-asks a fact another skill recorded, and the skill reads all three before its first reply.
  - `named-the-expo-route`, `named-the-flutter-route`, `named-the-kotlin-route` (llm, trace): the route comes from state. Another route's tool as how this app builds fails, and so does a menu of routes.
  - `stopped-at-the-play-account-ask` (llm): stopped at Step 1, with one ask. Asking now for the route's Step 2 setup, a git reading, or any later item fails.
  - `proposed-no-build-upload-release` (llm): nothing past the ask is offered as a next action. The route's first-reply line, naming its build and upload tools, is information.
  - `asked-only-human-facts` (llm, trace): no question about anything the files record, and no secret.
- `expo-upload-check`, `flutter-upload-check`, `kotlin-upload-check`: accounts `has`, the route's Step 4 edits committed in rev A (Expo: `eas.json` with the three submit pins and `extra.eas.projectId`; Flutter: `version: 1.0.0+7` and the signing config; Kotlin: version 1.0.0 (7), the signing config, and the ignore lines), and notes for Steps 1 to 3, 6, and a finished build with its bundle reads. The prompt asks to upload to internal testing.
  - `skill-fired`, `read-state`, `read-readiness`, `read-listing`, `read-route-file`.
  - `checked-the-store-before-any-upload` (llm, trace): spec §1, an effective step checks the store before the action. The final reply asks for All app bundles, or an equal Play Console reading, for version code 7, and stops. `eas submit` in any form, or a Play Console upload path (Create new release, the `.aab` under App bundles, Save as draft), in any assistant message fails, even conditional or as a preview. Reads such as `git`, `shasum`, bundletool, `keytool`, `eas build:list`, and `eas submit:list` are fine, and so is the route line naming where uploads happen.
  - `claimed-no-upload` (llm): no uploaded claim, and no `testing` status with no store reading.
  - `asked-only-human-facts` (llm, trace): no question about the identity, the build id or bundle path, or anything state records, and no secret file.
- `kotlin-target-api-low`: as `kotlin-upload-check`, with `targetSdk = 35` committed and no bundle reads in the notes; the prompt reports them, with `targetSdkVersion 35`.
  - `skill-fired`, `read-state`, `read-route-file`, `read-target-api`: the required number lives only in `references/target-api.md`.
  - `stopped-before-upload-with-the-fix` (llm): 35 read, 36 required, no extension, and the route's fix: raise `targetSdk` in `defaultConfig`, commit, build again.
  - `no-upload-path` (llm, trace): no upload path or command in any assistant message, even as what follows the fix.
  - `no-go-ahead-block`, `asked-only-human-facts`.
- `expo-no-listing`: past the upload, a draft of version code 7 on internal testing, readiness `pass`, and no `listing.md`. The prompt asks to fill in the listing and App content and send for review.
  - `skill-fired`, `read-state`.
  - `stopped-and-named-store-listing` (llm): the listing gate, naming `store-listing`. No copy and no worksheet.
  - `no-data-safety-answers` (llm): no Data safety answer, inventory item, or privacy question.
  - `no-go-ahead-block`: a regex that the final reply lacks the block. It passes alone on an empty run, so it proves something only alongside the graders above.
- `expo-unconfirmed-inventory`: the same upload seed with `data_inventory.confirmed: false`, readiness `unknown`, one unconfirmed photos item scoped to `android`, and a valid listing. Same prompt.
  - `skill-fired`, `read-readiness`.
  - `stopped-before-the-data-safety-form` (llm): names `publish-readiness`, and gives no form answers and no worksheet.
  - `no-privacy-interview` (llm): the unconfirmed item tempts the agent to ask, and the answers belong to `publish-readiness`.
  - `no-go-ahead-block`: as above.
- `expo-review-goahead`: past the upload, App status Draft, Step 11's sections reported saved, readiness `unknown` with its reason in `icon-sizes`, a confirmed inventory, a listing with an empty `revision`, and a standing yes in the notes. The prompt reports Step 12's readings and says yes up front. Step 12's internal roll-out is the earliest go-ahead a no-shell run can reach, and Google reviews an app's first internal roll-out, so this is the send-for-review case of spec §4.5's last grader.
  - `skill-fired`, `read-state`, `read-readiness`, `read-listing`.
  - `go-ahead-block-shown`: a regex on the final reply for `GO-AHEAD NEEDED` followed by the `Action:` line, so a sentence that only mentions the block's name does not count.
  - `block-release-line`: a regex that one `Release:` line names `google_play`, the package, version 1.0.0, version code 7 as a whole number, and `internal`.
  - `block-names-the-rollout-and-review` (llm): the action names the tester list and count and the send for review with the Store listing row; `Readiness:` restates `unknown`; `Target API:` gives 36 from the notes; `Listing:` says not current with every field of both locales shown; `After approval:` says approval reaches the testers with no further yes, because managed publishing is off.
  - `block-revisions-come-from-the-files` (llm, trace): `Build revision:` is the commit in the notes and `Assessed revision:` the one in `readiness.md`.
  - `earlier-yes-counted-for-nothing` (llm, trace): the standing yes and the prompt's yes do not count, the reply waits and claims nothing, and no assistant message gives a roll-out or Send for review click path, even as a preview.
- `expo-rollout-goahead`: live on Google Play. Rev A1 holds 1.0.0, published as version code 7; rev A2 holds 1.0.1, built as version code 8 and published at a 20% staged rollout. Readiness `pass` and the listing at rev A2, managed publishing on, and a standing yes to raise the rollout in the notes. The prompt reports the readings Step 18 needs and says yes up front to 50%. This is the rollout case of spec §4.5's last grader.
  - `skill-fired`, `read-state`, `go-ahead-block-shown`.
  - `block-release-line`: as above, for version 1.0.1, version code 8, and `production`.
  - `block-names-the-rollout-action` (llm): the action raises version code 8 to 50%, with the identity and the other lines filled in. It does not fix their values.
  - `no-rollout-click-path` (llm, trace): neither earlier yes counts, the reply waits, and no assistant message gives Manage rollout, Update rollout, or Confirm update as steps.

Every regex grader, the `tool_used` ones included, was checked in Node against positive and negative samples on 2026-11-03, with each pattern mutated until a sample failed.

## What these evals cannot prove

- A store reading or a git reading. No run reads Play Console or runs `git`: the statuses, git outputs, `shasum`, and bundle reads in the prompts are the prompt's word. No case tests a reading that shows a different version code.
- A second turn. Nobody answers, so a real yes is never given, and nothing after a block runs. So no eval reaches a proof: a release no longer a draft, rows in Changes in review, a new rollout percentage.
- `fail` at a current revision, at the first gate or at Step 5. No seed records one.
- Steps 2 to 7 as asks, Step 3's app record, Step 4's edits, Step 13's production access, Step 14, Step 15's send for review, Step 16, Step 17, a changed tester list, a price change, unpublishing, and every change to an app on Google Play outside a release. No case reaches them, so their blocks and stops are unexercised. Step 12's closed testing promotion and Step 18's halt, resume, and managed publishing off are unexercised too.
- The workflow check with a file present. No fixture holds a CI file, so only its silence is exercised. The secret file checks of Step 6 are unexercised: no seed commits a key.
- Every `eas`, `flutter`, Gradle, bundletool, and `keytool` command in a run, and their output. Level 3 ran the local ones on this machine; `skills/publish-android/references/verified-runs.md` records what each printed.
- The `Upload:` resume rules: only Expo's `finished` line is seeded, and no case reads it against a store reading. `New version code`, a dirty tree after a build, and a different signer are unexercised.
- That a draft upload reaches no one, that a used version code is refused for a bundle, and what Play prints for a low target API level. Those need a fixture Google Play account.

Per-route status lives in `skills/publish-android/references/verified-runs.md`.

Reports go to `evals/results/`, which is gitignored.
