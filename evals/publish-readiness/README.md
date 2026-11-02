# publish-readiness evals

Level-2 eval cases (spec §4.5) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format. Four cases, each with an English and a Chinese prompt and equal graders. Case names carry the prefix `publish-readiness-`, because `--case` matches names and the report keys on them.

Run, from the repo root. It grants Bash and Write so the script runs and the report is written. Nothing reaches a store or an account:

    claude plugin eval . --case 'publish-readiness-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --model sonnet --max-cost-usd 8 --allow-tools Bash Write

Keep `--allow-tools` last: it takes a list. AskUserQuestion is not granted, because a question would stop a run that no one can answer. So each run shows what a session that ends after the skill's questions leaves behind.

Each `scaffold.sh` sources `lib/scaffold.sh`, which finds the app-creators-fixtures repo next to this repo, or next to the main checkout from inside a git worktree, and extracts `todo-expo` at `ff71355` or `todo-vite` at `95c2f95` with `git archive`. The fixtures checkout may be on any branch. The scaffold then runs `git init` and commits, so a real revision exists. It stops with a message if the repo or the commit is absent.

## Cases and what each grader proves

Every case: `skill-fired` (the Skill tool loaded `publish-readiness`) and a Bash call that invokes `check-readiness.py` with `--platform`; `ls` or `cat` of the file does not count. `web-nodata` requires that call to carry `--collects-data no`.

Result regexes read the frontmatter of `.app-creators/readiness.md` and `.app-creators/state.md`. They accept flow or block YAML, and read `result` as the first key under the platform, which `SKILL.md` requires. A check's `result`, a sibling platform, `targets:`, and the notes below the frontmatter cannot satisfy them. Each loop in them consumes one whole line in one way, so they run in linear time.

- `expo-gaps`: `todo-expo` with `photosPermission` removed and an alpha `assets/icon.png`; iOS wanted, Android undecided, no privacy URL.
  - `readiness-written`, `ios-fail-in-readiness`, `ios-fail-in-state`: this proves slice D's proof line, a clean session writes the report and sets `state.md`.
  - `reply-names-three-gaps-with-fixes` (llm): the gaps reach the creator with their fixes.
  - `asks-only-human-facts` (llm): no question about framework, bundle id, or a secret.
  - `changed-nothing-outside-app-creators-without-agreement` (llm): no fix without a go-ahead.
- `expo-rerun`: clean `todo-expo`, iOS and Android wanted, privacy URL set. Rev A is the app. Rev B adds an earlier report recording `revision: A`, with a confirmed inventory, age rating answers, and both platforms at `unknown`, so only `.app-creators/` differs.
  - `ios-pass-*`, `android-pass-*`: these fail on the scaffold alone, so the skill has to rewrite both files. `pass` needs the confirmed answers kept with no one to ask, a revision accepted despite the commit that changed only `.app-creators/`, and `smoke-run` allowed to stay `unknown`. This proves the §4.1 exclusion and the §3.4 smoke rule together: a run that treats the state commit as a code change would drop the confirmation, and could not pass.
  - `inventory-confirmation-kept`, `apple-answer-kept`, `play-answer-kept`: the confirmed answers survive the rewrite. They match the seed by design, so they prove something only alongside the `pass` graders.
  - `did-not-re-ask-confirmed-answers` (llm): nothing confirmed is asked twice.
  - `said-smoke-run-did-not-run-and-the-risk` (llm): the creator is told. On a machine with full Xcode and a JDK, this grader and the case's premise no longer hold, because the smoke run would run.
- `expo-dirty`: as `expo-rerun`, with both platforms seeded at `pass`, plus an uncommitted change to `App.tsx`.
  - `ios-unknown-*`, `android-unknown-*`: these fail on the scaffold alone, so the skill has to overwrite the earlier `pass`. Uncommitted changes cannot record a pass, and do not become a `fail`.
  - `asked-creator-to-commit` (llm).
- `web-nodata`: `todo-vite`, web wanted, no privacy URL, and a prompt that confirms nothing leaves the device.
  - `ran-script-with-collects-data-no`, `web-pass-*`: a site that collects nothing passes without a URL, per §3.4.
  - `names-publish-web-next` (llm).

Each llm judge takes the majority of three votes. The ceiling is 1.0 per case.

## Known environment issue

On a Mac without a full Xcode, `/usr/bin/git` is a shim that fails inside the eval's OS sandbox with exit 72, because it cannot write its cache. `PATH` there may not list another git. The skill's Troubleshooting row sends the agent to a real binary such as `/opt/homebrew/bin/git`. An earlier run where the agent found none recorded an honest `unknown` and failed the `web-pass-*` graders, so read a `pass` grader's failure with that in mind.

## What these evals cannot prove

- The smoke run itself. This machine has no full Xcode and no JDK, so no `pass` or `fail` on `smoke-run` is exercised.
- The step that resolves a dynamic Expo config. No case has an `app.config.js` or `app.config.ts`. `tests/check-readiness.test.sh` covers `--expo-config`.
- Flutter, Xcode, Kotlin, Next.js, and static routes. `tests/check-readiness.test.sh` covers their static checks; no skill run does.
- A second turn. Nobody answers in a run, so applying answers, applying an agreed fix, and the rerun after a commit are not exercised.
- That store forms accept these answers. No store is touched.

Per-route status lives in `skills/publish-readiness/references/verified-runs.md`.

Reports go to `evals/results/`, which is gitignored.
