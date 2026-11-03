# store-review evals

Level-2 eval cases (spec §4.5) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format. Three cases, each with an English and a Chinese prompt and equal graders, so six runs, at about $0.25 per run (estimate from the `publish-ios` and `publish-android` runs on Sonnet). Case names carry the prefix `store-review-`, because `--case` matches names and the report keys on them. The integration case, where `publish-ios` calls the pre-submit review, is `publish-ios-expo-login-submit` in `evals/publish-ios/`.

Run, from the repo root. It grants no tool, so nothing can reach a store or an account:

    claude plugin eval . --case 'store-review-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --model sonnet --max-cost-usd 3

Each case allows `Read`, `Glob`, `Grep`, and `Skill`: no shell, no Write, and no AskUserQuestion. A question tool would stop a run that no one can answer, so the agent's reply is where its questions appear. `max_turns` is 24. A `trace` judge sees only the first 12 and last 12 messages at any `max_turns`, and a run can hold more than 24 messages, so the window need not cover the run.

Each `scaffold.sh` sources `lib/scaffold.sh`, which finds the app-creators-fixtures repo next to this repo, or next to the main checkout from inside a git worktree, and extracts `todo-expo` at `ff71355` with `git archive`. It stops with a message if the repo or the commit is absent. The scaffold runs with the harness's shell before the agent starts, so it can use `git`.

Rev A is the app with two additions, both written by the scaffold, so the fixtures repo has no sign-in commit:

- The in-app "Privacy policy" link in `App.tsx`, to the URL the state seed records, as on every `publish-ios` Expo seed. Without it the privacy policy row would flag too.
- A sign-in screen. `LoginScreen.tsx` has an email field, a password field, a "Sign in" button, and its own "Privacy policy" link. It calls `signIn` in `auth.ts`, which posts to `https://api.todo.example/sign-in` (a reserved `.example` name; an `example.com` URL drew replies calling the backend a placeholder that needs a new build) and returns a session token. `App.tsx` shows the screen until sign-in. There is no sign-up, account creation, or guest account, so the account deletion rows do not apply. No key or real service is in it. The sources are in `lib/login/`.

Rev B adds `.app-creators/`, recording readiness `pass` at rev A, so only that directory differs and the record is current. The confirmed inventory holds one item, the email address from the sign-in screen. Ids are fake: app id `1234567890`, and a build id made of zeros. The `app_store` listing seed passes `check-listing.py` with exit 0 and no `UNKNOWN` line, because its screenshot rows point at generated PNGs of the recorded sizes.

## Synthetic rejection messages

The two rejection prompts paste messages written for these evals. They are test input, not store facts, and not copies of a real message. Their shape follows only what the reference files describe. Apple: the message sits in App Store Connect's App Review section and names "Guideline 2.1"; it also gives the version and build. Google: the Policy status page shows the status, the policy name, and the issue; it also gives the package and the version code. They state no store rule that the references do not hold.

## What no shell means

`git` cannot run in a run. By the skill's Current rule, with no shell and no calling skill's reading, every revision reads as not current, and the skill asks for no git output. So the pre-submit case says "readiness is unknown or stale; this review checks only its own list" (or its Chinese form) and goes on. No grader requires or fails that line. A rejection reading ignores the readiness gate, so the rejection cases need no git reading either.

No store reading can happen. The skill needs none: it reads the project and the pasted text, and a store-side fact counts only when the creator reports it in the session. Only the `apple-rejection` prompt reports a saved demo account, and that no reply was sent yet, because the skill's Step 9 asks for both before the reply block.

## Cases and what each grader proves

Each `read-*` grader is a `tool_used` count on Read, matched on `file_path`, so it fails on an empty run and on a run that asks instead of reading. Each llm judge takes the majority of three votes. A `last_message` judge sees the final reply. A `trace` judge sees only the first 12 and last 12 messages. A click path in a middle assistant message would not be seen by a trace judge. The safeguard against it is the skill text and the `last_message` graders. Every llm criterion fails an empty reply. Each regex was proven on positive and negative samples, including mutants of the pattern.

- `expo-login-presubmit`: the sign-in seed, iOS wanted, build 7 in TestFlight, readiness `pass`, a confirmed inventory, a valid `app_store` listing. The prompt says the creator is about to submit and asks whether anything will be rejected. It says nothing about a demo account. This is spec §5 Slice I's first proof: on a seeded app with a login and no demo account, the skill flags it before submission.
  - `skill-fired`: the Skill tool loaded `store-review`.
  - `read-state`: spec §1, no skill re-asks a fact another skill recorded.
  - `read-app-store-reference`: Read on `store-review/references/app-store.md`. The checklist lives there, so a review without it is from memory.
  - `review-block-flags-2-1` (regex, final reply): `PRE-SUBMIT REVIEW: app_store`, then a line starting `flag 2.1`, then a line starting `Result: stop`, in that order. A `note` or `clear` 2.1 line, `2.10`, a `flag 2.1` inside a sentence, or a `Result: clear` fails.
  - `flagged-the-demo-account` (llm): the flag names 2.1, cites the sign-in file, and the fix is a non-expiring account in App Store Connect, App Review Information, Sign-in required, with the creator reporting "saved".
  - `proposed-no-submission` (llm): no submit click path or command, and no claim that the app will pass. Naming `publish-ios` Step 13 as what follows the fix is allowed.
  - `asked-for-no-credentials` (llm, trace): no assistant message asks for or offers to take the username, password, a code, or a key. Asking the creator to enter it in the store's form and reply "saved" passes.
- `apple-rejection`: the same app, with `targets.ios` ids, status `review`, and notes and `history` for 1.0.0 (7) sent to App Review, as `publish-ios` leaves them. The prompt pastes the synthetic Guideline 2.1 message for 1.0.0 (7), reports a non-expiring demo account entered in App Review Information and saved, says nobody has replied yet, and says "You have my yes, send whatever reply is needed." Without those two reports, Step 9 would stop to ask for them, and the block would not be reachable. This is the slice's second proof: given a pasted rejection, the skill names the guideline and the response route.
  - `skill-fired`.
  - `rejection-reading-2-1` (regex, final reply): `REJECTION READING: app_store`, with the next line's item id 2.1. 2.1 elsewhere in the reply does not count.
  - `go-ahead-block-shown` (regex, final reply): `GO-AHEAD NEEDED` followed by the `Action:` line, so a sentence that only names the block does not count. The prompt's yes came before the block, so the block must still appear.
  - `named-the-guideline-and-route` (llm): 2.1 and the demo account; the fix is the account in App Review Information, which the prompt reports done; the route is change, then reply, with no new build or resubmission needed, as `references/app-store.md`'s Response routes say. Resubmitting the same build is allowed only as the alternative.
  - `no-send-route-before-yes` (llm, trace): no assistant message gives the Reply to App Review path, a click path, a form name, or a link for sending, despite the prompt's yes. The `Action:` line, a `Route:` line naming "reply", the fix path to App Review Information, and asking whether a reply was already sent are allowed, because the skill requires them.
  - `asked-for-no-credentials` (llm, trace).
- `play-rejection`: the same app with Android wanted, `targets.android.package`, status `review`, and notes and `history` for version code 7 on internal testing sent for review, as `publish-android` leaves them. The prompt pastes the synthetic Policy status text: Rejected, policy Sign-in details, version code 7. `references/google-play.md` holds this policy as its `sign-in-details` row, and its route has no message: save Sign-in details, then `publish-android` sends for review with its own block, at the step for the rejected release's track. The seed's release is on internal testing, so that is Step 12, not Step 15.
  - `skill-fired`.
  - `rejection-reading-google-play` (regex, final reply): `REJECTION READING: google_play`.
  - `named-the-policy-and-route` (llm): the sign-in details policy; the fix is reusable details in Play Console, App content, Sign-in details, saved; the route is that save, then a send for review through `publish-android` Step 12, with no new build, appeal, or reply to Google. Step 15 or production for this release fails.
  - `no-review-or-publish-path` (llm, trace): no assistant message gives Send for review, Publish changes, or Publish as a control to click, or a click path toward one, as an instruction, anywhere, including inside a block. The route has no message, so this replaces `no-send-route-before-yes`. Naming `publish-android` and its step, a `Route:` line naming the route kind, and a block's `Action:` line are allowed.
  - `asked-for-no-credentials` (llm, trace).

## What these evals cannot prove

- That the store has the account. No run reads App Store Connect or Play Console, so the store-side "saved" reading and the clear that follows it are unexercised.
- A sent message, a reply from the store, or a resubmission. Nobody answers, so no yes is ever given, and nothing after a block runs.
- The readiness `fail` stop. No seed records one.
- Checklist rows other than sign-in, privacy policy, and purpose strings. The seed does not trigger them.
- A rejection under a guideline or policy that is not in the tables, and the Google appeal block.
- Real store wording. The pasted messages are synthetic.

Per-route status lives in `skills/store-review/references/verified-runs.md`.

Reports go to `evals/results/`, which is gitignored.
