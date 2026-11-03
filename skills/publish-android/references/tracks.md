# Tracks and testers

What Step 12 and Step 13 act on. Bracketed numbers point to `## Sources`.

| | internal testing | closed testing | open testing | production |
|---|---|---|---|---|
| who gets it | up to 100 testers per app, by email list [1][2] | testers you choose: email lists, Google Groups, or an organization [1] | anyone who joins; the test is visible on Google Play [1] | all Google Play users in the chosen countries [2] |
| when available | before app setup is complete [1] | after app setup [3] | after production access, on personal accounts that need it [3] | after production access, on personal accounts that need it [3] |
| review | not covered by managed publishing, and usually live at once with no review, but the first release roll-out and the release after a rejection are reviewed first [4]. Internal tests "might not be subject to standard Play policy or security reviews" [1] | treat as reviewed: Google names only internal testing as outside managed publishing and review [4] | the same [4] | yes [4][6] |
| Data safety form | exempt while the app is only on this track [5] | required [5] | required [5] | required [5] |
| class here | **go-ahead** | **go-ahead** | **go-ahead** | **go-ahead** |

**Why internal testing is a go-ahead.** Its testers are any Google accounts the creator lists by email, not only the team [1], and a new bundle reaches them within minutes [1]. Its first roll-out and any roll-out after a rejection go to Google's review [4]. So it reaches people outside the team and sometimes a reviewer, the same reasons `publish-ios` gives external TestFlight its blocks. A draft release on the track reaches no one: uploading as a draft stays **effective**.

## Testers

- Internal: Test and release, Testing, Internal testing, Testers tab, Create email list, then select lists, add a feedback URL or email, copy the link, Save changes [1].
- Closed: Closed testing, Manage track, Testers tab, the same steps; or Google Groups; or an organization [1]. Additional closed tracks can be created with Create track [1].
- Open: Open testing, Testers tab, Manage testers, unlimited or a limit of at least 1,000 [1].
- Each tester opts in through the link. The opt-in link shows only once the app status is Published, not in Draft or Pending publication [1].

The creator types addresses into Play Console, never into chat. A change to the membership of an email list or Google Group used by a track is not held back by managed publishing [4], so on a track that already serves a release it reaches those people at once: a **go-ahead** with its own block, action "change the tester list <list> of track <track>, which serves version code <code>: <count> added, <count> removed".

## Releases on a track

- A release holds one or more app bundles. Create it on the track's page: Create new release [2]. You cannot create a new release while another is outstanding: roll staged releases out to 100%, or remove changes and discard unpublished releases first [2]. Rolling out to 100% reaches users: it is `SKILL.md` Step 18's go-ahead.
- Save as draft keeps it in Play Console and reaches no one [2].
- Next leads to Preview and confirm. Errors must be fixed before publishing; warnings can be published over [2].
- Then the button is Save, which adds the release to the changes ready to send for review, or Publish, which "pushes changes live immediately", depending on whether the change needs review [2]. Either way, the click that sends or publishes is the go-ahead; `references/release.md` has both.
- A release from another track: Promote release on the track's Releases summary [7].
- A draft, a release ready to send for review, and a rejected release can be discarded. One in review or ready to publish needs its changes removed from the Publishing overview first [2].

## Which version a tester gets

A device receives the highest version code that it supports, among the tracks the user is eligible for. All users are eligible for production. A user opted in to internal testing receives only the internal track's version code [1]. So a production release with a higher version code than a closed test reaches that closed test's testers too [1]. Name this in a production block when a test track holds a lower version code.

## Sources

All fetched with curl and read 2026-11-03.

1. Set up an open, closed, or internal test, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9845334?hl=en
2. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
3. App testing requirements for new personal developer accounts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
4. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
5. Provide information for Google Play's Data safety section, Play Console Help: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
6. Publish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859751?hl=en
7. Manually submit an Android app to the Google Play Store, Expo: https://docs.expo.dev/submit/android-manual/
