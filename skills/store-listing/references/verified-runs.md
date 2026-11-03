| date | level | skill_version | route | account | outcome | notes |
|---|---|---|---|---|---|---|
| 2026-11-03 | 3 | 0.1.0 | expo+app-store | none | open | eval `expo-copy`, 1.00 in en and zh: copy and script ran, last run has no `FAIL` line. No screenshots captured, because no one answers in an eval and this machine has no full Xcode. Not exercised: applying answers, the rerun after a commit |
| 2026-11-03 | 3 | 0.1.0 | expo+google-play | none | open | eval `expo-copy`, 1.00 in en and zh: copy and script ran, last run has no `FAIL` line. No screenshots captured, because no one answers in an eval and this machine has no JDK. Not exercised: applying answers, the rerun after a commit |
| 2026-11-03 | 3 | 0.1.0 | flutter+app-store | none | open | not run: `todo-flutter` arrives in Slice G |
| 2026-11-03 | 3 | 0.1.0 | flutter+google-play | none | open | not run: `todo-flutter` arrives in Slice G |
| 2026-11-03 | 3 | 0.1.0 | xcode+app-store | none | open | not run: `todo-swift` arrives in Slice G |
| 2026-11-03 | 3 | 0.1.0 | kotlin+google-play | none | open | not run: `todo-kotlin` arrives in Slice H |
| 2026-11-03 | 3 | 0.2.0 | expo+app-store | none | open | eval `store-listing-*` at 0.2.0, with the optional screenshot `locale`: 5 of 6 at 1.00, `expo-readiness-fail-zh` 0.67 on a reply that stopped and gave the fix, judges' reason not recorded, then 1.00 in 2 reruns. No row in a run carries `locale`; `tests/check-listing.test.sh` covers it. No screenshots captured: no full Xcode |
| 2026-11-03 | 3 | 0.2.0 | expo+google-play | none | open | eval `store-listing-*` at 0.2.0, with the optional screenshot `locale`: 5 of 6 at 1.00, `expo-readiness-fail-zh` 0.67 on a reply that stopped and gave the fix, judges' reason not recorded, then 1.00 in 2 reruns. No row in a run carries `locale`; `tests/check-listing.test.sh` covers it. No screenshots captured: no JDK |
| 2026-11-03 | 3 | 0.2.0 | flutter+app-store | none | open | `check-listing.py` ran on `todo-flutter` at `de83d0f` with the hand-written eval seed listing and generated PNGs: 12 `PASS`, no `FAIL` or `UNKNOWN`, exit 0. No skill run, and no real screenshot: capture needs a full Xcode (`xcodebuild -version` exits 1) |
| 2026-11-03 | 3 | 0.2.0 | flutter+google-play | none | open | not run; `todo-flutter` exists at `de83d0f`, and no seed listing holds `google_play`. Screenshots stay open: no JDK (`java -version` exits 1), so no release build to capture |
| 2026-11-03 | 3 | 0.2.0 | xcode+app-store | none | open | `check-listing.py` ran on `todo-swift` at `de83d0f` with the hand-written eval seed listing and generated PNGs: 12 `PASS`, no `FAIL` or `UNKNOWN`, exit 0. No skill run, and no real screenshot: capture needs a full Xcode (`xcodebuild -version` exits 1) |

`route` is `<framework>+<provider or store>`; one row per route per run.
