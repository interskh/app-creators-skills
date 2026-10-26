# app-creators evals

Level-2 eval cases (spec §3.4) in the [`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals.md) `case.yaml` format. `vite-en` and `vite-zh` run the same check with an English and a Chinese prompt, so the zh path is held to the same bar. Both prompts state the outcome (publish) and the destination (web), so the run needs no answers from anyone.

Each case's `scaffold.sh` extracts `../app-creators-fixtures/todo-vite` as of commit `95c2f95` (`git archive`, so the fixtures checkout may be on any later commit) into the workspace. Unlike the `publish-web` cases, it writes no `.app-creators/state.md`: the skill has to create it. Clone app-creators-fixtures next to this repo; the script stops if the fixture is missing or the commit is not fetched. Inside a git worktree it finds the fixtures repo next to the main checkout.

Graders, equal weight:

- `skill-fired`: the Skill tool loaded `app-creators`.
- `state-created`: Claude created `.app-creators/state.md`.
- `schema-1-0`, `kind-vite`, `package-manager-npm`, `slug-todo-vite`, `web-intent-wanted`, `web-status-unknown`, `goal-publish`: regexes on the written file. `intent` and `status` are matched only inside the `targets.web` block.
- `asks-only-the-two-questions` (llm judge on the trace): any question covers only the outcome, the destinations, or a go-ahead; never the framework, package manager, build tool, output directory, or an account or secret.
- `names-publish-web-no-outcome-claims` (llm judge on the final reply): names `publish-web` as the next skill and claims no external outcome.

Each llm judge takes the majority of three votes. The ceiling is 1.0 per case.

Level-2 run, no shell, nothing can deploy:

    claude plugin eval . --case 'app-creators-vite-*' --runs 1 --ablation none --scaffold --no-publish --trust-plugin --max-cost-usd 3 --allow-tools Write

`allowed_tools` grants only read-only tools; `Write` stays out of the session unless the command grants it, and without it the skill cannot create `state.md`. Keep `--allow-tools Write` last: it takes a list. Bash and AskUserQuestion are not granted: detection needs no shell, and a question would stop a run that no one can answer.

The case names carry an `app-creators-` prefix because `--case` matches names and the report keys on them, and the `publish-web` cases already own `vite-en` and `vite-zh`.

What this proves: the `state.md` written here carries every field that `publish-web`'s `## Before you start` requires from `app-creators` (`framework.kind`, `framework.package_manager`, `targets.web.intent`, `app.slug`), and the `publish-web` eval shows that skill reading `state.md` instead of asking for the framework. So the creator is never asked for the framework twice.

Reports go to `evals/results/`, which is gitignored.
