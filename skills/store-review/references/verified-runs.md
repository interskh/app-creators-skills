| date | level | skill_version | route | account | outcome | notes |
|---|---|---|---|---|---|---|
| 2026-11-04 | 2 | 0.1.0 | expo+app-store | none | open | eval pending: `store-review-expo-login-presubmit` and `store-review-apple-rejection`, en and zh, no shell, on `todo-expo` at `ff71355` with a sign-in screen added by the scaffold; and `publish-ios-expo-login-submit`, the Step 13 call |
| 2026-11-04 | 2 | 0.1.0 | expo+google-play | none | open | eval pending: `store-review-play-rejection`, en and zh, no shell, on the same seed with Android wanted |
| 2026-11-04 | 3 | 0.1.0 | expo+app-store | none | open | The pre-submit review and the rejection reading need no account, and run in the evals above on the seeded fixture: eval pending. Open, because they need a store account: the store-side reading that the demo account is saved and the clear that follows it, sending the reply to App Review, and the store's answer |
| 2026-11-04 | 3 | 0.1.0 | expo+google-play | none | open | The rejection reading needs no account, and runs in the eval above on the seeded fixture: eval pending. No Google Play pre-submit case runs yet. Open, because they need a store account: the store-side reading that Sign-in details are saved, and the send for review through `publish-android` |

`route` is `<framework>+<provider or store>`; one row per route per run.
