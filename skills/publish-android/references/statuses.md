# Play Console statuses

Google's status names as fetched, what each one proves, and what `targets.android.status` it writes. Google's words are shown exactly. Read a status only for this release identity: an older release's status proves nothing. An app status and an update status name no version code, so read each with the version codes the track's release lists. Bracketed numbers point to `## Sources`.

## Where the creator reads them

| reading | where |
|---|---|
| App status, Update status | under the app's name and package name, when the app is selected in Play Console [1] |
| Changes not yet sent for review, Changes in review, Changes ready to publish, Managed publishing status | Publishing overview [2] |
| Submission status and Submission ID | submission activity [3] |
| A track's releases, their version codes, and release status | the track's page, Releases tab; and Test and release, Latest releases and bundles [4][5] |
| Every uploaded bundle by version code | Latest releases and bundles, View all app bundles; it filters by upload status and release status [6] |

## Which status proves which step

| step | proof, for this identity | not proof |
|---|---|---|
| Upload | This version code is listed under All app bundles for this package, in a draft release on the track the route names [6][4] | A finished upload command. Another version code |
| Testing release | The track's release with this version code is no longer a draft, and the app status is Internal testing, Closed testing, or Open testing [1], or the change sits in Changes in review | Save as draft. A tester link alone |
| Send for review | Changes in review, or submission status In review, holding this track's release with this version code [2][3] | Changes not yet sent for review. Pre-review checks |
| Publish | App status Production, and the production track's active release holds this version code [1][6] | Ready to publish. A yes |
| Rollout change | The production track's release shows the new percentage or Halted; the release details show the event in Rollout history [4][7] | The click alone |

## App status

| status [1] | Google says | `targets.android.status` |
|---|---|---|
| Draft | No presence on Google Play: not published yet, or rejected during review | `ready` |
| Internal testing | Available to internal testers via URL only | `testing` |
| Closed testing | Discoverable, but only selected testers can install it | `testing` |
| Open testing | Discoverable, and any user can become a tester | `testing` |
| Pre-registration | Users can pre-register. This skill does not set it up | `ready` |
| Production | Available to Google Play users in the chosen countries or regions | `live` |
| No active releases | No updates rolled out on any track, or they were rejected | `ready` |
| Unpublished | Discoverable for existing users only | no write: stop and tell the creator |
| Removed by Google | Not discoverable; needs a policy-compliant update | no write: `references/review.md` |
| Suspended by Google | Not discoverable; needs a successful appeal | no write: `references/review.md` |

## Update status

| status [1] | Google says | `targets.android.status` |
|---|---|---|
| No pending changes | Nothing to submit | from the app status |
| Changes not yet sent for review | Changes that need review, not sent. "Your changes are not automatically sent for review" | from the app status |
| In review | Google is reviewing the update | `review`, or keep `live` |
| Update rejected | A change in an update is not compliant; fix and resubmit, or appeal | from the app status |
| App rejected | The same, for an app in Draft published for the first time | `ready` |
| Previous | A valid past update | from the app status |

Item status adds Draft, Available, and Previous for single parts of an update [1].

## Submission status

| status [3] | Google says | `targets.android.status` |
|---|---|---|
| In review | Being evaluated, until all reviews finish | `review`, or keep `live` |
| Ready to publish | Passed all reviews; "You must manually publish when you're ready" | `review`, or keep `live` |
| Published | Live on Google Play | from the app status |
| Rejected | Not published. "If an update is rejected, your last approved version remains live" | from the app status |
| Cancelled | Withdrawn: changes removed, superseded by a newer submission, or the app blocked or suspended | from the app status |

Google keeps submission records from May 1, 2026, for one year [3].

## Releases and bundles

A release's bundles are Draft (never served), Active (served), or Archived (once served) [6]. The Releases tab and Latest releases list the track, the release status, the last update, and the countries [4]. The release details page holds Rollout history: when a release was halted, resumed, or served to a new percentage [4].

## Field rules

- `ready` needs a reading that the app exists. `none` needs a reading that it does not.
- `review` means changes sit with Google or wait at Ready to publish; nothing reached users from them yet.
- A `live` field stays `live` while a newer release moves through testing and review: the production track keeps serving its active release until the new one is published [3][8]. Only a reading that the app status is not Production rewrites it.

## Sources

All fetched with curl and read 2026-11-03.

1. Publish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859751?hl=en
2. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
3. About your submission activity, Play Console Help: https://support.google.com/googleplay/android-developer/answer/17118609?hl=en
4. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
5. Inspect app versions on the Latest releases and bundles page, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9844279?hl=en
6. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
7. Release app updates with staged rollouts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/6346149?hl=en
8. My app has been removed from Google Play, Play Console Help: https://support.google.com/googleplay/android-developer/answer/2477981?hl=en
