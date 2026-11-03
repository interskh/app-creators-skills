# App Review: time, rejection, appeal

Bracketed numbers point to `## Sources`. Pre-submit checks and reading a rejection in depth belong to `store-review`, which has not shipped.

## How long

Apple: "App Review works around the clock, typically reviewing at least 50% of submissions in less than 24 hours and 90% in less than 48 hours" [1]. An incomplete submission can take longer or not pass [1]. Submissions may not be reviewed in the order sent [2]. Apple emails status changes, and shows them in App Store Connect and its app [1].

After approval, it can take up to 24 hours to go live [3].

TestFlight App Review has no stated time on the pages read. An export compliance review takes about two business days with complete information [7].

## On a rejection

The message states how the app breaks the guidelines [4]. The creator reads it in the app's App Review section.

- **Reply.** Role: Account Holder, Admin, or App Manager. Apps, the app, the unresolved issues link, Resolve next to the submission, Reply to App Review, then the reply; a file can be attached [4]. Correspond until you resubmit [4].
- **Metadata issue.** The same build can be resubmitted after fixing it [4]. Status Metadata Rejected [5].
- **A rejected item among others.** Status Unresolved Issues. Edit it once and resubmit, or remove it [6].
- **Resubmit.** It reaches a reviewer again, so it is a new Step 13 with a new block. Changed code means a new build, from Step 8.
- **Bug-fix update.** If App Review finds other issues in a bug-fix update, it may offer to approve it now and take them next time: reply to that message to accept. Not with legal or safety concerns [1].

The creator writes the reply and the appeal. Draft on request; the creator sends it.

## Appeal

If the creator believes App Review misunderstood the app or treated them unfairly, they can appeal to the App Review Board [1]. Give specific reasons the app complies, one appeal per rejected submission, and answer any open request for information first [1]. The form sits on Apple's contact pages behind sign-in; the form itself could not be read [8].

## Other routes

An expedited review can be requested for a critical bug fix, with reproduction steps, or an event the app is directly associated with [1]. A 30-minute App Review appointment over Webex is available [1]. Apple's "contact us" takes an unresolved rejection or removal [1].

## Sources

All fetched with curl and read 2026-11-03.

1. App Review, Apple: https://developer.apple.com/distribute/app-review/
2. Overview of submitting for review, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
3. Overview of publishing your app on the App Store, Apple: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/
4. Reply to App Review messages, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages
5. App and submission statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/
6. Manage a submission with unresolved issues, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/manage-a-submission-with-unresolved-issues
7. Determine and upload app encryption documentation, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/
8. Contact form, appeal topic, Apple: https://developer.apple.com/contact/app-store/?topic=appeal redirected to an Apple sign-in page on 2026-11-03, so its fields were not read.
