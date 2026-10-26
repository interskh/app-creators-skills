# publish-web evals

Level-2 eval cases (spec §3.4) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format. `vite-en` and `vite-zh` run the same check with an English and a Chinese prompt, so the zh path is held to the same bar.

Each case's `scaffold.sh` extracts `../app-creators-fixtures/todo-vite` as of commit `95c2f95` (`git archive`, so the fixtures checkout may be on any later commit) into the workspace and adds the case's `state.md` as `.app-creators/state.md`. Clone app-creators-fixtures next to this repo; the script stops if the fixture is missing or the commit is not fetched. Inside a git worktree it finds the fixtures repo next to the main checkout.

Graders, equal weight: `skill-fired` (the Skill tool loaded `publish-web`), `read-state` (llm judge on the trace: `.app-creators/state.md` was read and its Vite + web facts were used, not asked for), `names-vercel` (llm judge on the trace: Vercel is recommended as the deployment path, not offered in a menu; neither prompt nor the state file names a provider, so the recommendation has to come from the skill), `asks-only-human-prerequisites` (llm judge: questions cover only accounts, domains, DNS access, app names, or a go-ahead), `ran-verify-script` (a Bash call to `check-pwa.sh`). Each llm judge takes the majority of three votes.

Level-2 run, no shell, nothing can deploy:

    claude plugin eval . --case 'vite-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin

Without Bash, `ran-verify-script` cannot pass, so the ceiling is 4 of 5 graders, a score of 0.8 per case; the default `--threshold 1.0` makes the command exit 1. Read the per-grader results in the report.

Nightly form, once a fixture-only Vercel account exists (spec §3.4 credential boundary):

    claude plugin eval . --case 'vite-*' --scaffold --no-publish --trust-plugin --allow-tools Bash

Not worked out yet: a run passes only `EVAL_*` variables and allowlisted ones to the agent, and granted Bash runs under the OS sandbox's network rules, so the deploy steps also need the token and network access plumbed through.

Reports go to `evals/results/`, which is gitignored.
