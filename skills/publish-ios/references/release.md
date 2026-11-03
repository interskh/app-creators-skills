# Submitting and releasing

The App Store Connect paths for Steps 12 to 16, and the settings that would skip a yes. Bracketed numbers point to `## Sources`.

## Submit for review

No tool in this skill submits. Expo's `eas submit` uploads a build, and App Review is a separate submission you start in App Store Connect [6]. The API can do it [1], but this skill gives no sourced command for it.

Role: Account Holder, Admin, or App Manager [1].

1. Apps, the app, the version in the sidebar [1].
2. Build section: confirm this identity's build. Only one build per version; it can change until you submit. To add one: add (+) next to Build, select it, Done, Save [2]. If an earlier version is Ready for Distribution, the list shows only builds uploaded since [2].
3. Top right, Add for Review, then pick a draft or a new submission. Status becomes Ready for Review. **Nothing is sent yet** [1].
4. Submit for Review [1]. This is the click the go-ahead covers. Status becomes Waiting for Review [4], and In Review when review starts [1].

One app version per platform is under review at a time [5].

## Release options

Set on the version, in App Store Version Release, Save. Role: Account Holder, Admin, or App Manager [3].

| Apple's option [3] | what happens [3][7] | here |
|---|---|---|
| Manually release this version | After approval it waits at Pending Developer Release | **Required.** Step 12 sets it, and Step 13's block names it |
| Automatically release this version | It goes live automatically on approval | **Forbidden:** it reaches the public with no further yes |
| Automatically release this version after App Review, no earlier than | Released automatically at the date | **Forbidden**, for the same reason |

A pre-order on a never-released app is released manually, and the section is dimmed [3]. A creator who wants a scheduled release sets it themselves, outside this skill, and the skill says it did not ask for that.

Read the section back before the block. A setting the creator changed after the block means a new block.

## Release this version

Status Pending Developer Release only. Role: Account Holder, Admin, or App Manager. Apps, the app, the version with that status, top right Release This Version, Confirm [3]. It can take up to 24 hours to appear; cancel with Cancel This Release on the version page [3]. Apple emails a reminder after 30 days at that status [3]. With pre-order enabled, this also publishes pre-orders and availability [3].

Each platform releases separately [3].

## Phased release (updates only)

Available for a version update, at Prepare for Submission, Waiting for Review, In Review, Waiting for Export Compliance, Pending Developer Release, Developer Rejected, Rejected, or Metadata Rejected. Select "Release update over a 7-day period using phased release" under Phased Release for Automatic Updates, Save [8].

The update reaches a share of users with automatic updates on, on a fixed schedule; anyone can still download it manually [8].

| day [8] | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| users | 1% | 2% | 5% | 10% | 20% | 50% | 100% |

**A percentage cannot be set.** The changes that exist are pause, resume, and release to all, and each is a **go-ahead**:

| change [8] | path |
|---|---|
| Pause | The Ready for Distribution version, Phased Release section, Pause Phased Release, Save. Up to 30 days in total, with no limit on the number of pauses |
| Resume | The same section, Use Phased Release, Save. It picks up on the day it paused |
| Release to all users | The version, top right, Release to All Users |

Choosing phased release while filling the version, with the release itself still manual, reaches no one: it goes in Step 15's block. Removing the app from sale stops the phased release for that version [8].

## Sources

All fetched with curl and read 2026-11-03.

1. Submit an app, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
2. Choose a build to submit, Apple: https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit
3. Select an App Store version release option, Apple: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/
4. Overview of publishing your app on the App Store, Apple: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/
5. Overview of submitting for review, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
6. Submit to the Apple App Store with Expo Submit, Expo: https://docs.expo.dev/submit/ios/
7. Platform version information, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
8. Release a version update in phases, Apple: https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/
