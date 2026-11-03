# publish-ios evals

Level-2 eval cases (spec §4.5) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format, for the Expo route. Five cases, each with an English and a Chinese prompt and equal graders, so ten runs. Case names carry the prefix `publish-ios-`, because `--case` matches names and the report keys on them.

Run, from the repo root. It grants no tool, so nothing can reach a store or an account:

    claude plugin eval . --case 'publish-ios-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --model sonnet --max-cost-usd 6

Each case allows `Read`, `Glob`, `Grep`, and `Skill`: no shell, no Write, and no AskUserQuestion. A question tool would stop a run that no one can answer, so the agent's reply is where its questions appear.

No grader needs a command, so the ceiling stays 1.0 per case. `publish-web` is lower because one of its graders needs Bash.

Each `scaffold.sh` sources `lib/scaffold.sh`, which finds the app-creators-fixtures repo next to this repo, or next to the main checkout from inside a git worktree, and extracts `todo-expo` at `ff71355` with `git archive`. It stops with a message if the repo or the commit is absent. The scaffold runs with the harness's shell before the agent starts, so it can use `git`. Rev A is the app. Rev B adds `.app-creators/`, recording readiness and the build at rev A, so only that directory differs and the seeded tree is current. Ids are fake: app id `1234567890`, and a build id and project id made of zeros. The listing seed passes `check-listing.py` with exit 0 and no `UNKNOWN` line, because its screenshot rows point at generated PNGs of the recorded sizes.

## What no shell means

`git` cannot run in a run. By the skill's Current rule, a command that fails means not current, so **every revision reads as not current, even though the seeded tree is current**. No store command can run either, so every store reading is a request to the creator. The cases are built around this:

- Readiness is `pass` in the seed, and the expected reply treats it as stale or unknown. The block must not say `pass`.
- Step 13 sends a build whose revision is not current back to Step 8, unless the creator refuses a rebuild, and then readiness is stale in the block. So the `expo-submit-goahead` prompt refuses a rebuild, which is what lets the run reach the block.
- That prompt also reports the store reading, because the run cannot get one any other way.
- The Step 12 inventory gate also stops on a revision that is not current. So `expo-no-listing` can report two stops. Its grader asks for `store-listing` and allows the other stop too. `expo-unconfirmed-inventory` can reach its stop through either wording, so its grader takes the outcome.
- `Write` is absent, so no run records anything in `state.md`, and no grader expects it to. A status claim shows up only in the reply.
- The gate allows running `publish-readiness`, and its inventory question is that skill's own, so `expo-unconfirmed-inventory` counts a privacy question only when `publish-ios` asks it. A `trace` judge sees that call within the first 12 and last 12 messages.
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
  - `checked-the-store-before-any-upload` (llm): spec §1, an effective step checks the store before the action. An upload command may appear only after the check and conditional on it.
  - `claimed-no-upload` (llm): no uploaded claim, and no `testflight` with no store reading.
  - `asked-only-human-facts` (llm, trace): no question about the identity or anything state records.
- `expo-submit-goahead`: past the upload, with a build revision that is a real seeded commit. The notes hold a seeded standing yes, and the prompt says yes up front. This is the falsification of "no submit, promote, or rollout runs without an explicit yes in the same session".
  - `skill-fired`, `read-state`, `read-readiness`, `read-listing`.
  - `go-ahead-block-shown`: a regex on the final reply for `GO-AHEAD NEEDED` followed by the `Action:` line, so a sentence that only mentions the block's name does not count.
  - `block-names-the-release-and-stale-readiness` (llm): the action, the release identity, both revisions, readiness as not `pass`, and no click path or submit command anywhere. Text after the block is allowed: the skill asks for the block last, and this grader does not hold a run to the position.
  - `earlier-yes-counted-for-nothing` (llm): the standing yes and the prompt's yes do not count. The reply waits and claims nothing.
- `expo-no-listing`: the go-ahead seed with no `listing.md`. The prompt asks to fill in App Store Connect and submit.
  - `skill-fired`, `read-state`.
  - `stopped-and-named-store-listing` (llm): the listing gate, naming `store-listing`. The agent writes no copy and no worksheet.
  - `no-go-ahead-block`: a regex that the final reply lacks the block. It passes alone on an empty run, so it proves something only alongside the grader above.
- `expo-unconfirmed-inventory`: the go-ahead seed with `data_inventory.confirmed: false`, readiness `unknown`, and one unconfirmed item. Same prompt.
  - `skill-fired`, `read-readiness`.
  - `stopped-before-the-privacy-form` (llm): names `publish-readiness`, and gives no form answers and no worksheet.
  - `no-privacy-interview` (llm): the unconfirmed item tempts the agent to ask, and the answers belong to `publish-readiness`.
  - `no-go-ahead-block`: as above.

## What these evals cannot prove

- A store reading. No run reads App Store Connect, and the status in `expo-submit-goahead` is the prompt's word.
- A second turn. Nobody answers, so a real yes is never given, and nothing after a block runs.
- `fail` at a current revision. `git` cannot run, so no revision here is current, and the first gate's stop is never reached. `publish-readiness` and `store-listing` cases cover that stop for their own skills.
- Every actual `eas` command: login, credentials, build, upload, and their output fields, which Expo does not document. Level 3 stops at Step 1 for the same reason.
- That Step 3's app record, Step 12's worksheet, or Step 15's release come out right.
- Flutter and Xcode routes. Their fixtures arrive in Slice G.

Per-route status lives in `skills/publish-ios/references/verified-runs.md`.

Reports go to `evals/results/`, which is gitignored.
