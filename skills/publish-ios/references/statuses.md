# App Store Connect statuses

Apple's status names as fetched, what each one proves, and what `targets.ios.status` it writes. Apple's words are shown exactly. Read a status only for this release identity: an older release's status proves nothing. Bracketed numbers point to `## Sources`.

## Which status proves which step

| step | proof, for this identity | not proof |
|---|---|---|
| Upload | The build is listed under TestFlight, Builds, iOS [3], with a build status below other than Invalid Binary, and its build upload state is not Processing or Failed [2] | A finished upload command. An older build. |
| Submit for review | App status Waiting for Review or In Review, or a later status from the table [1] | Ready for Review, which means added but not submitted [1]. Rejected or Developer Rejected, which need a new go-ahead. |
| Release | App status Ready for Distribution. In a phased release it has "Phased Release" appended [1][4] | Pending Developer Release. Processing for Distribution, which is on its way. A yes. |
| Phased change | The version's Phased Release for Automatic Updates section shows the change [4] | The click alone. |

## App status (the version)

| status [1] | Apple says | `targets.ios.status` |
|---|---|---|
| Prepare for Submission | Record created, information still being prepared | `ready` |
| Ready for Review | All metadata entered and intended for review, not yet submitted | `ready` |
| Invalid Binary | Submitted, but the build does not meet the binary requirements | from the build's status |
| Waiting for Review | Received, review not started | `review` |
| In Review | App Review is reviewing | `review` |
| Accepted | Accepted, but other items in the submission were rejected. It publishes only when all items are accepted | `review` |
| Waiting for Export Compliance | The CCATS file is in export compliance review | `review` |
| Pending Developer Release | Accepted; you still need to release it | `review` |
| Processing for Distribution | Processing, ready within 24 hours | `review` |
| Pending Apple Release | Apple is holding it until an operating system version releases | `review` |
| Ready for Distribution | Accepted and ready for distribution; agreements must be in effect | `live` |
| Rejected | Not accepted | from the build's status |
| Metadata Rejected | Metadata not accepted; edit it and reply | from the build's status |
| Developer Rejected | You removed it from review | from the build's status |

`review` here means the version is in Apple's hands or waiting for the creator's release, not on sale. Removal from review is possible from Waiting for Export Compliance, Waiting for Review, In Review, Pending Developer Release, and Pending Apple Release [5].

Pending App Transfer and Processing App Transfer are not handled by this skill [1]: stop and tell the creator.

## Submission and item statuses

On the App Review page, submissions show Waiting for Review, In Review, Processing, Unresolved Issues, or Rejected. Items show Ready for Review, Waiting for Review, In Review, Accepted, or Rejected [1]. A submission with Unresolved Issues has a rejected item: `references/review.md`.

## App build status (the build, in TestFlight)

| status [3] | Apple says | `targets.ios.status` |
|---|---|---|
| Invalid Binary | Build received, but it did not meet the upload requirements; not visible in TestFlight | no write |
| Missing Compliance | Missing export compliance documentation; action is needed | `ready` |
| Waiting for Export Compliance Review | Documentation submitted, in review | `ready` |
| In Compliance Review | Documentation in review | `ready` |
| Ready to Submit | Can go to internal testers, TestFlight App Review, or App Review | `testflight` |
| Waiting for Review | Submitted to TestFlight App Review | `testflight` |
| In Beta Review | Being reviewed by TestFlight App Review | `testflight` |
| Ready to Test | Testable, no testers added yet | `testflight` |
| Testing | Being tested by at least one group or tester | `testflight` |
| Not Available for Testing | Provisioning profile is missing an application identifier; upload a new build | `ready` |
| Expired | Past its 90-day window | `ready` |
| Rejected | Rejected by TestFlight App Review; upload a new build | `ready` |

## Build upload state

Processing, Failed, or Complete, in the Build Uploads table. Processing for more than 24 hours may mean an issue: submit a Feedback Assistant ticket or contact Apple. After Failed, the same build number can be reused [2].

## Field rules

- `ready` needs a store reading that the record exists. `none` needs a reading that it does not.
- "From the build's status" means: ask for this build's status, and map it from the build table; with no such build, write `ready`.
- A `live` field stays `live` while an older version is on sale and a newer one moves through: Apple tracks each version separately, and a build can still be chosen while an earlier version is Ready for Distribution [6]. Only a reading that no version is on sale rewrites it.
- API status names such as `PENDING_DEVELOPER_RELEASE` and `READY_FOR_SALE` exist [7]. This skill uses the page names, which are what the creator sees.

## Sources

All fetched with curl and read 2026-11-03.

1. App and submission statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/
2. Build upload statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-uploads/build-upload-statuses
3. App build statuses, and View build status and metrics, Apple: https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses and https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-build-status-and-metrics
4. Release a version update in phases, Apple: https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/
5. Remove a submission from review, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/remove-a-submission-from-review
6. Choose a build to submit, Apple: https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit
7. AppStoreVersionState, App Store Connect API, Apple: https://developer.apple.com/documentation/appstoreconnectapi/appstoreversionstate
