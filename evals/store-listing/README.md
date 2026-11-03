# store-listing evals

Level-2 eval cases (spec §4.5) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format. Three cases, each with an English and a Chinese prompt and equal graders, so six runs. Case names carry the prefix `store-listing-`, because `--case` matches names and the report keys on them.

Run, from the repo root. It grants Bash and Write so the script runs and the listing is written. Nothing reaches a store or an account:

    claude plugin eval . --case 'store-listing-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --model sonnet --max-cost-usd 6 --allow-tools Bash Write

Keep `--allow-tools` last: it takes a list. AskUserQuestion is not granted, because a question would stop a run that no one can answer. So each run shows what a session that ends after the skill's questions leaves behind.

Each `scaffold.sh` sources `lib/scaffold.sh`, which finds the app-creators-fixtures repo next to this repo, or next to the main checkout from inside a git worktree, and extracts `todo-expo` at `ff71355` with `git archive`. The fixtures checkout may be on any branch. Rev A is the app. Rev B adds `.app-creators/`, recording readiness of rev A, so only that directory differs and the record is current. It stops with a message if the repo or the commit is absent.

## Cases and what each grader proves

Regexes read the frontmatter of `.app-creators/listing.md`. They start at the file's first line and cannot pass its closing `---`, so notes below it cannot satisfy them. They walk `stores:` at column 0, then the store at two spaces, then the locale at four, so another top-level key, a sibling store, or a sibling locale cannot satisfy them either. They need a one-line flow map for the locale, which `SKILL.md` and spec §4.2 require. A blank field does not count. Each loop reads one line in one way, so they run in linear time.

- `expo-copy`: clean `todo-expo`, `app.languages: [en, zh]`, iOS and Android wanted, readiness `pass` at the current revision. The prompt asks for both stores in English and Chinese.
  - `skill-fired` and `ran-check-script`: the Skill tool loaded `store-listing`, and a Bash call names both Python and `check-listing.py`, in either order, so a path held in a shell variable counts; `ls` or `cat` of the file alone does not count.
  - `listing-written`: the run created the file. The scaffold does not.
  - `app-store-en`, `app-store-zh`, `google-play-en`, `google-play-zh`: each store holds each locale in the frontmatter, with its main fields written.
  - `last-check-has-no-fail-line` (llm): half of slice E's proof line, copy in en and zh passes the script.
  - `copy-claims-only-what-the-app-does` (llm): reads the file. No cloud sync, accounts, or other invented claim.
  - `keywords-longer-than-two-characters` (llm): reads the file. Each `app_store` keyword in every locale has more than 2 characters, the rule in `limits.md`, which the script does not check.
  - `asks-only-human-facts` (llm): no question about framework, bundle id, or a secret.
  - `changed-nothing-outside-app-creators` (llm).
- `expo-overlimit`: a valid listing committed in rev B, whose Google Play `short_description` is one over. The scaffold reads the limit from the real `limits.md`, so the seed tracks the table, and stops if the seeded words no longer fit. `check-listing.py` exits 1 on this seed. Every grader fails on the seed alone. This is the other half of the proof line, with the skill's response to it.
  - `skill-fired`, `ran-check-script`.
  - `seeded-text-left-the-field`: the field holds something else, in `google_play`, `en`. The field has to be non-empty. Cutting the seed's last character leaves the seeded words, so this grader fails too. A move of the text to the notes or to another store does not pass it.
  - `last-check-has-no-fail-line` (llm): the rewrite fits. A regex here would have to restate the limit.
  - `reply-names-field-and-shows-rewrite` (llm): the creator sees what changed.
  - `rewrite-is-not-a-truncation` (llm): reads the file, ignoring the notes. Keeps the three meanings and ends on a whole word.
- `expo-readiness-fail`: `todo-expo` with a real alpha icon, and readiness recorded at the current revision: iOS `fail` with a fix, Android `pass`. The prompt asks for the listing.
  - `skill-fired`.
  - `stopped-and-listed-the-fix` (llm): spec §4.4. One failing store stops the run even though the other store passes.
  - `no-listing-written`: no file was created. It passes alone on an empty run, so it proves something only alongside the two above.

Each llm judge takes the majority of three votes, and a `trace` judge sees only the first 12 and last 12 messages. The ceiling is 1.0 per case.

## Known environment issue

On a Mac without a full Xcode, `/usr/bin/git` is a shim that fails inside the eval's OS sandbox with exit 72, because it cannot write its cache. The skill's Troubleshooting row sends the agent to a real binary such as `/opt/homebrew/bin/git`. With no real binary, the agent cannot show that readiness is current, so it proceeds as the gate says, and `expo-readiness-fail` fails for that reason alone.

## What these evals cannot prove

- Screenshots. No one captures any in a run, and this machine has no full Xcode or JDK, so no image row is ever `PASS` or `FAIL` here. `tests/check-listing.test.sh` covers images on generated files.
- A second turn. Nobody answers in a run, so the review of the copy, applying answers, and filling `path` and `size` are not exercised.
- That the stores accept this copy. No store is touched, and the limits come from vendor pages rather than from a submission.
- That the copy is good. The graders check that it is true to the app and fits; a person judges whether it sells.
- The rerun rule on a field the creator edited, beyond the seeded case. `expo-overlimit` shows a failing field rewritten; no case edits a passing field and checks that it survives.
- The readiness gate's `unknown`, stale, or missing branches. `expo-copy` and `expo-overlimit` hold a current `pass`, and `expo-readiness-fail` holds a current `fail`; no case exercises the other branches.
- Flutter, Xcode, and Kotlin routes. Their fixtures arrive in Slices G and H.

Per-route status lives in `skills/store-listing/references/verified-runs.md`.

Reports go to `evals/results/`, which is gitignored.
