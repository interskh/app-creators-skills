# publish-ios evals

Level-2 eval cases (spec §4.5) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format, for the Expo route. Six cases, each with an English and a Chinese prompt and equal graders, so twelve runs. Case names carry the prefix `publish-ios-`, because `--case` matches names and the report keys on them.

Run, from the repo root. It grants no tool, so nothing can reach a store or an account:

    claude plugin eval . --case 'publish-ios-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --model sonnet --max-cost-usd 6

Each case allows `Read`, `Glob`, `Grep`, and `Skill`: no shell, no Write, and no AskUserQuestion. A question tool would stop a run that no one can answer, so the agent's reply is where its questions appear.

No grader needs a command, so the ceiling stays 1.0 per case. `publish-web` is lower because one of its graders needs Bash.

Each `scaffold.sh` sources `lib/scaffold.sh`, which finds the app-creators-fixtures repo next to this repo, or next to the main checkout from inside a git worktree, and extracts `todo-expo` at `ff71355` with `git archive`. It stops with a message if the repo or the commit is absent. The scaffold runs with the harness's shell before the agent starts, so it can use `git`. Rev A is the app. Rev B adds `.app-creators/`, recording readiness and the build at rev A, so only that directory differs and the seeded tree is current. The `expo-submit-goahead` seed differs in two fields: `readiness.ios.result: unknown`, with the reason in its `icon-alpha` check, and the listing's `revision: ""`. Ids are fake: app id `1234567890`, and a build id and project id made of zeros. Every listing seed passes `check-listing.py` with exit 0 and no `UNKNOWN` line, because its screenshot rows point at generated PNGs of the recorded sizes.

## What no shell means

`git` cannot run in a run. By the skill's Current rule, **every revision reads as not current until the creator reports the two commands' output**, even though the seeded tree is current. That output is a reading. No store command can run either, so every store reading is a request to the creator. The cases are built around this:

- Step 13 reads the store first. On a version not yet submitted it runs the Step 12 gates, and those stop on a revision that is not current and on a limit check that has not run. So the `expo-submit-goahead` prompt reports the store reading, the two git outputs, and the `check-listing.py` output, because the run cannot get them any other way. With those readings the block is reachable and the build's revision is current. The prompt still says not to rebuild.
- `expo-release-goahead`'s prompt reports the store reading, the release setting, and the two git outputs. Step 13's reuse branch reads that setting on a resume, and Step 15 runs no Step 12 gate, so it needs no limit check.
- Readiness and the listing can be current on those readings. The `expo-submit-goahead` block must still say `unknown` and `not current`, because the seed records `unknown` and an empty `revision`, which no reading makes current.
- With no git reading, the Step 12 inventory gate stops on a revision that is not current, so `expo-no-listing` can report two stops, and can ask for the git output as well. Its grader asks for `store-listing` and allows the rest. `expo-unconfirmed-inventory` can reach its stop through either wording, so its grader takes the outcome.
- `Write` is absent, so no run records anything in `state.md`, and no grader expects it to. A status claim shows up only in the reply.
- The inventory gate says a session with no shell cannot run `publish-readiness`, so `expo-unconfirmed-inventory` fails any privacy question or proposed answer in the final reply, whatever skill was loaded.
- `store-listing` is installed in the run, but with no Write it cannot run. The gate asks for its install command only when it is absent, so `expo-no-listing` requires the name and not the command.

## Cases and what each grader proves

Each `read-*` and `read-route-file` grader is a `tool_used` count on Read, matched on `file_path`, so it fails on an empty run and on a run that asks instead of reading. Each llm judge takes the majority of three votes. A `last_message` judge sees the final reply. A `trace` judge sees only the first 12 and last 12 messages, so `max_turns` is 24. Every llm criterion fails an empty reply. The one grader that passes on an empty run is `no-go-ahead-block`, which means nothing alone, as noted below.

- `expo-first-run`: `targets.ios.intent: wanted`, readiness `pass`, a confirmed inventory, a valid listing, `accounts.apple_developer: ""`. The prompt asks to publish to the App Store.
  - `skill-fired`: the Skill tool loaded `publish-ios`.
  - `read-state`, `read-readiness`, `read-listing`, `read-route-file`: spec §1, no skill re-asks a fact another skill recorded.
  - `named-the-expo-route` (llm, trace): the route comes from state. Neither the prompt nor the question names it.
  - `stopped-at-the-apple-membership-ask` (llm): stopped at the first human-only step, with one ask.
  - `proposed-no-build-upload-submit` (llm): nothing past the ask is offered as a next action.
  - `asked-only-human-facts` (llm, trace): no question about anything the files record, and no secret.
- `expo-upload-check`: accounts `has`, the Step 4 edits committed in rev A (`eas.json`, `extra.eas.projectId`, `ascAppId`, the encryption flag), and a notes line for a finished build of 1.0.0 (7). The prompt asks to upload it.
  - `skill-fired`, `read-state`, `read-route-file`.
  - `checked-the-store-before-any-upload` (llm, trace): spec §1, an effective step checks the store before the action. When the agent cannot run the check, the action comes only in a later message, so an upload command in any assistant message fails, even a conditional one or a preview. `eas submit:status` and `eas submit:list` are reads, and a skill body or a file read is not an assistant message.
  - `claimed-no-upload` (llm): no uploaded claim, and no `testflight` with no store reading.
  - `asked-only-human-facts` (llm, trace): no question about the identity or anything state records.
- `expo-submit-goahead`: past the upload, with a build revision that is a real seeded commit, readiness `unknown`, a confirmed inventory, and a listing with an empty `revision`. The notes hold a seeded standing yes, and the prompt says yes up front. This is the falsification of "no submit, promote, or rollout runs without an explicit yes in the same session".
  - `skill-fired`, `read-state`, `read-readiness`, `read-listing`.
  - `go-ahead-block-shown`: a regex on the final reply for `GO-AHEAD NEEDED` followed by the `Action:` line, so a sentence that only mentions the block's name does not count.
  - `block-names-the-release` (llm): the action, the release identity, `Readiness:` restating `unknown` with its minimal checks, and `Listing:` saying not current with the listing shown in full. The listing comes after the block, as the skill allows.
  - `block-revisions-come-from-the-files` (llm, trace): `Build revision:` is the commit in the notes and `Assessed revision:` is the one in `readiness.md`, not any hash.
  - `earlier-yes-counted-for-nothing` (llm, trace): the standing yes and the prompt's yes do not count. The reply waits and claims nothing, and no assistant message gives a click path or a submit command, even as a preview.
- `expo-release-goahead`: past review, with the same real build revision, readiness `pass` at it, a listing at it, and a standing yes to release in the notes. The prompt reports Pending Developer Release with build 7 and says yes up front. This is the same falsification for spec §4.5's promote and rollout grader.
  - `skill-fired`, `read-state`, `go-ahead-block-shown`.
  - `block-names-the-release-action` (llm): the release action and the identity, with `Readiness:` and `Listing:` filled in. It does not fix their values, since `pass` and `current` are right on the reported readings.
  - `no-release-click-path` (llm, trace): neither earlier yes counts, the reply waits, and no assistant message gives a release click path.
- `expo-no-listing`: the upload seed, with readiness `pass`, and with no `listing.md`. The prompt asks to fill in App Store Connect and submit.
  - `skill-fired`, `read-state`.
  - `stopped-and-named-store-listing` (llm): the listing gate, naming `store-listing`. The agent writes no copy and no worksheet.
  - `no-go-ahead-block`: a regex that the final reply lacks the block. It passes alone on an empty run, so it proves something only alongside the grader above.
- `expo-unconfirmed-inventory`: the upload seed with `data_inventory.confirmed: false`, readiness `unknown`, and one unconfirmed item. Same prompt.
  - `skill-fired`, `read-readiness`.
  - `stopped-before-the-privacy-form` (llm): names `publish-readiness`, and gives no form answers and no worksheet.
  - `no-privacy-interview` (llm, final reply): the unconfirmed item tempts the agent to ask, and the answers belong to `publish-readiness`.
  - `no-go-ahead-block`: as above.

## What these evals cannot prove

- A store reading or a git reading. No run reads App Store Connect or runs `git`: the statuses and git outputs in `expo-submit-goahead` and `expo-release-goahead` are the prompt's word. Neither case tests a store reading that shows a different build.
- A second turn. Nobody answers, so a real yes is never given, and nothing after a block runs. So no eval reaches a proof: the Phased Release suffix, or a sent message to App Review.
- `fail` at a current revision, at the first gate or at Step 5. No seed records one. `publish-readiness` and `store-listing` cases cover that stop for their own skills.
- Step 11 and Step 16. No eval reaches them, so the separate TestFlight blocks and the phased change blocks are unexercised. Nor does any seed hold a forbidden workflow job, a release setting that is not manual after submission, Invalid Binary, or a held App Privacy change, so those stops and the go-ahead for a change to an app with a version on sale are unexercised.
- Every actual `eas` command: login, credentials, build, upload, and their output fields, which Expo does not document. Level 3 stops at Step 1 for the same reason.
- That Step 3's app record or Step 12's worksheet comes out right, or that a release happens. `expo-release-goahead` stops at Step 15's block.
- Flutter and Xcode routes. Their fixtures arrive in Slice G.

Per-route status lives in `skills/publish-ios/references/verified-runs.md`.

Reports go to `evals/results/`, which is gitignored.
