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

An internal group must exist first [3]. A beta app description and a feedback email are required [5]. Each action below reaches a reviewer or a person outside the team, so each is its own block in Step 11 and its own proof. Give its path only after the yes.

| action | what it reaches | path |
|---|---|---|
| Submit Review | TestFlight App Review. With "Automatically notify testers" on, testers hear on approval, so leave it off; then you notify them yourself after approval [3] | Apps, TestFlight tab, add (+) next to External Testing, name the group, Create. Add Builds, choose the platform, version, and build, write What to Test, Submit Review [3] |
| Start Testing | The group's testers, with no review first. The button depends on the build's status, and later builds of a version might not need a full review [3] | The same path; the button reads Start Testing [3] |
| Notify Testers | The group's testers. The build status changes to Testing [3] | TestFlight tab, Builds, the platform, the version, Notify Testers on the build's row [3] |
| Invite by email | Each person named, by invitation email [3] | The group, add (+) next to Testers [3] |
| Public link | Anyone with the link: anyone can share it, so people you did not invite can join [3] | The group, testers tab, Create Public Link, Open to Anyone or Filter by Criteria, optional Tester Limit, Confirm [3] |

A later change that lets more people in through a public link, under Manage next to Public Link [3], is a new block too.

A rejection shows Rejected on the build, and the App Review section holds the detail; a new build is needed [3][4].

## Sources

All fetched with curl and read 2026-11-03.

1. TestFlight overview, Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/overview-of-testflight/
2. Add internal testers, Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/
3. Invite external testers, Apple: https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
4. App build statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses
5. TestFlight, Expo: https://docs.expo.dev/submit/testflight/
