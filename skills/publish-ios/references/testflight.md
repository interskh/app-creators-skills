# TestFlight

Bracketed numbers point to `## Sources`.

| | internal testing | external testing |
|---|---|---|
| class | **effective** | **go-ahead**: it reaches TestFlight App Review |
| who | up to 100 App Store Connect users with access to the app [1][2] | up to 10,000 people per app, no App Store Connect account needed [1][3] |
| review | none [5] | the first build you add goes to TestFlight App Review; later builds of that version might not need a full review [1][3] |
| role | Account Holder, Admin, App Manager, Developer, or Marketing [2] | Account Holder, Admin, or App Manager [3] |
| limits | | one build of each version in review at a time; up to six builds submitted in 24 hours [3] |

A build is testable for up to 90 days [1]. Missing Compliance blocks it: `references/export-compliance.md`.

TestFlight reaches testers before the app is released publicly on the App Store [5]. Testers with an invitation can keep testing it after it goes live, unless you expire it [1].

## Internal

Apps, TestFlight tab, add (+) next to Internal Testing, name the group, Create; then Invite Testers and Add Builds [2]. "Enable automatic distribution" sends each new build to the group [2]. It reaches only that team.

Builds uploaded as TestFlight Internal Only can go only to internal groups, and cannot be submitted to customers [2].

## External

An internal group must exist first [3]. Apps, TestFlight tab, add (+) next to External Testing, name the group, Create. Then Add Builds, choose the platform, version, and build, write What to Test [3]. A beta app description and a feedback email are required [5]. Click Submit Review; the wording depends on the build's status [3]. "Automatically notify testers" tells testers on approval [3]. After approval, invite by email or public link [3].

Each of these reaches a person outside the team only after this skill's go-ahead block. A rejection shows Rejected on the build, and the App Review section holds the detail; a new build is needed [3][4].

## Sources

All fetched with curl and read 2026-11-03.

1. TestFlight overview, Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/overview-of-testflight/
2. Add internal testers, Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/
3. Invite external testers, Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
4. App build statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses
5. TestFlight, Expo: https://docs.expo.dev/submit/testflight/
