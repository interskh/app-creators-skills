| date | level | skill_version | route | account | outcome | notes |
|---|---|---|---|---|---|---|
| 2026-11-02 | 3 | 0.1.0 | expo+app-store | none | open | eval `expo-rerun`, rerun 2026-11-02 with graders that fail on the seed, 1.00 in en and zh: checks and report ran, `ios` pass. `smoke-run` did not run: no full Xcode. Not exercised, because no one answers in an eval: applying answers, an agreed fix, the rerun after a commit |
| 2026-11-02 | 3 | 0.1.0 | expo+google-play | none | open | eval `expo-rerun`, rerun 2026-11-02 with graders that fail on the seed, 1.00 in en and zh: checks and report ran, `android` pass. `smoke-run` did not run: no JDK. Not exercised, because no one answers in an eval: applying answers, an agreed fix, the rerun after a commit |
| 2026-11-02 | 3 | 0.1.0 | vite+web | none | open | eval `web-nodata`: checks and report ran, `web` pass with `--collects-data no`. The web has no smoke run. Nothing was deployed. Not exercised, because no one answers in an eval: applying answers, an agreed fix, the rerun after a commit |
| 2026-11-02 | 3 | 0.1.0 | flutter+app-store | none | open | not run: `todo-flutter` arrives in Slice G; `smoke-run` also needs a full Xcode |
| 2026-11-02 | 3 | 0.1.0 | flutter+google-play | none | open | not run: `todo-flutter` arrives in Slice G; `smoke-run` also needs a JDK |
| 2026-11-02 | 3 | 0.1.0 | xcode+app-store | none | open | not run: `todo-swift` arrives in Slice G; `smoke-run` also needs a full Xcode |
| 2026-11-02 | 3 | 0.1.0 | kotlin+google-play | none | open | not run: `todo-kotlin` arrives in Slice H; `smoke-run` also needs a JDK |
| 2026-11-02 | 3 | 0.1.0 | expo+web | none | open | not run: `todo-expo` has no eval on this route. No shipped skill publishes it to the web: `publish-web` takes only `vite`, `nextjs`, and `static` |
| 2026-11-02 | 3 | 0.1.0 | flutter+web | none | open | not run: `todo-flutter` arrives in Slice G. No shipped skill publishes it to the web: `publish-web` takes only `vite`, `nextjs`, and `static` |
| 2026-11-02 | 3 | 0.1.0 | nextjs+web | none | open | not run: no fixture exists and no slice plans one |
| 2026-11-02 | 3 | 0.1.0 | static+web | none | open | not run: no fixture exists and no slice plans one |

`route` is `<framework>+<provider or store>`; one row per route per run.
