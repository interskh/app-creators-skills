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

A pre-order on a never-released app is released manually, and the section is dimmed [3]. Every automatic or scheduled option is forbidden in this skill, whoever sets it, because it goes public with no further yes: this skill shows no Step 13 block with one set.

Read the section back before the block, and read the Build section with it. On any setting other than "Manually release this version", ask the creator to change it and Save, then read it back again. A setting the creator changed after the block means a new block.

**Already submitted with an automatic or scheduled setting.** Step 13's reuse branch reads the setting. Approval then publishes with no yes [3][7], and with a date not yet passed, the version waits at Pending Developer Release and releases itself at that date [7]. Tell the creator so in plain words, and ask them to select "Manually release this version" and Save, then read it back. Apple's pages do not say whether this section can change after submission: its release option page names no status [3], and its table does not mark Version Release Settings as editable at any time [10]. So the creator tries it. If the section will not change, the sourced route is removing the version from review, at Waiting for Export Compliance, Waiting for Review, In Review, Pending Developer Release, or Pending Apple Release: "remove this version from review" on the version page, Remove. The status becomes Developer Rejected and review starts over [15]. Then set the release option, and submit through a new Step 13 block. At Accepted, no page read gives a route: say so. This is the creator's choice. If they keep the setting, write that in the notes, say that no yes covers the release, and stop.

## Release this version

Status Pending Developer Release, with this identity's build in the Build section, only. Role: Account Holder, Admin, or App Manager. Apps, the app, the version with that status, top right Release This Version, Confirm [3]. It can take up to 24 hours to appear; cancel with Cancel This Release on the version page [3]. Apple emails a reminder after 30 days at that status [3]. With pre-order enabled, this also publishes pre-orders and availability [3].

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

Choosing phased release while filling the version, with the release itself still manual, reaches no one: it goes in Step 15's block. Read this section back before that block. With the option not selected or not saved, the release goes to everyone. On approval the status is Ready for Distribution with "Phased Release" appended [8], and that suffix is the proof of a release in phases. Removing the app from sale stops the phased release for that version [8].

## Changes to an app with a version on sale

"On sale" is the reading in `SKILL.md`. These apply outside any new version. Apple's table marks the properties that can be edited at any time without submitting a new version [10].

| item | what Apple says | here |
|---|---|---|
| App Availability | "The changes take effect immediately but may require up to 24 hours to be visible to all users". Deselecting a region removes the app from the App Store there [9] | **Go-ahead.** Action: "change App Availability of the live app: <regions added and removed>" |
| Remove App From Sale | Removed in all countries or regions within 24 hours [9] | **Go-ahead.** Action: "remove the live app from sale in all countries or regions" |
| Price | A change of base country or region goes into effect immediately [11]. A scheduled price change starts on its effective date, which can be today [12] | **Go-ahead.** Action: "change the price of the live app to <price>, effective <date>" |
| App Privacy responses | Publish updates the product page [13] | **Go-ahead:** `references/app-privacy.md` |
| Trader status | Marked editable [10]. Once verified, Apple publishes a trader's address, phone number, and email on the product page in the EU [14]. No page read says when | **Go-ahead.** Action: "change the trader status of the live app to <status>" |
| Copyright, App Review information | Marked editable [10], and they sit on a version's page [7]. No page read says when a change to the version on sale shows | Step 12, on the new version's page. This skill gives no path for changing them on the version on sale |
| Category, support URL, content rights | Not marked editable [10] | Step 12, on the new version's page |

Before a version is on sale, setting availability takes effect once the app becomes Ready for Distribution [9], and setting a price reaches no one: both are ordinary Step 12 work.

Path, after the yes: Apps, the app, Pricing and Availability [9][11]. Availability: under App Availability, Manage, Manage Availability, select or deselect, Next, confirm [9]. Remove: Remove App From Sale at the bottom of the page, Remove [9]. Price: Price Schedule [11][12]. Proof: the creator reports what that section now shows.

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
9. Manage availability for your app on the App Store, Apple: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store/
10. Required, localizable, and editable properties, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
11. Set a price, Apple: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/
12. Schedule price changes for apps, Apple: https://developer.apple.com/help/app-store-connect/manage-app-pricing/schedule-price-changes-for-apps/
13. Manage app privacy, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
14. Manage European Union Digital Services Act trader requirements, Apple: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
15. Remove a submission from review, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/remove-a-submission-from-review
