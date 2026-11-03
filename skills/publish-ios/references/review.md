# App Review: time, rejection, appeal

Bracketed numbers point to `## Sources`. `store-review` does the pre-submit review and the rejection reading, and holds the block for the messages its reference lists. Any other message below keeps its own block in `publish-ios`. This file is the fallback when `store-review` is not installed.

## How long

Apple: "App Review works around the clock, typically reviewing at least 50% of submissions in less than 24 hours and 90% in less than 48 hours" [1]. An incomplete submission can take longer or not pass [1]. Apps with little review history, required documents, or complex issues can take longer [9]. Submissions may not be reviewed in the order sent [2]. Apple emails status changes, and shows them in App Store Connect and its app [1].

After approval, it can take up to 24 hours to go live [3].

TestFlight App Review has no stated time on the pages read. An export compliance review takes about two business days with complete information [7].

## On a rejection

The message states how the app breaks the guidelines [4]. The creator reads it in the app's App Review section. Do not resubmit until every issue is resolved: it delays review and gives the same outcome [9].

- **Metadata, or a fix in App Store Connect or on the server**, such as providing or activating demo credentials. Make the change, then reply to App Review [9]. Status Metadata Rejected says to edit the metadata and reply [5]. Default: the reply, a message below; Apple reserves resubmissions for changes that need a new review [9]. Alternative: resubmit the same build after the fix [4].
- **More information asked for**, and nothing else open. Reply, a message below. Resubmitting starts a new review, after which App Review can no longer reply to the earlier message [9].
- **A fix in the build.** Upload the new build and submit that version [9]: a new build and build number, from Step 8, then a new Step 13 with a new block.
- **A rejected item among others.** Status Unresolved Issues. Edit it and resubmit, or remove it [6][9]. Resubmitting is a new Step 13 with a new block.
- **Bug-fix update.** If App Review finds other issues in a bug-fix update, it may offer to approve it now and take them next time. Accepting is a message below; do not resubmit, which starts a new review [10]. Not with legal or safety concerns, and a deferred issue cannot be deferred again [10].
- **The creator believes the app complies.** First reply with a clarification; appeal only if that does not resolve it [11]. Resubmitting closes an open appeal [9].

## Messages to App Review

Each of these reaches a reviewer, so each is a **go-ahead** with its own block. The block's action is in the words below, and the message itself is shown in full below the block. Give the route only after the yes. The creator writes the message; draft on request; the creator sends it. Proof: the creator reports it sent.

| message | action | route |
|---|---|---|
| Reply to a rejection, including Metadata Rejected | "send this reply to App Review" | Role: Account Holder, Admin, or App Manager. Apps, the app, the unresolved issues link, Resolve next to the submission, Reply to App Review, then the reply; a file can be attached [4] |
| Bug-fix acceptance | "reply to App Review accepting the bug-fix offer: approve the current submission, and address the issues in the next update" | Reply to the offer message in App Store Connect, saying you want the current submission approved [1][10] |
| Appeal | "send this appeal to the App Review Board" | The "Submit an appeal to App Review" form [11]. The form sits behind Apple sign-in, so its fields were not read [8] |
| Expedited review request | "send this expedited review request to App Review" | The "Request an Expedited App Review" form, only for a submission already sent to App Review [12] |
| Appointment request | "request an App Review appointment" | The link on Apple's App Review page [1] |
| Contact us | "send this message about the rejection or removal to App Review" | Apple's "contact us" [1] |

An appeal is for a creator who believes the app follows the guidelines, or was treated unfairly [11]. Reply with a clarification first [11]. Cite each guideline the rejection names and explain point by point how the app meets it, in one appeal per rejected app [11]. Never appeal an information request, a status question, or an expedite request, and never after resubmitting with the issues addressed [11].

An expedited review can be requested for a critical bug fix, with reproduction steps, or an event the app is directly associated with [1][12]. The appointment is 30 minutes over Webex [1]. "Contact us" takes an unresolved rejection or removal [1].

## Sources

All fetched with curl and read 2026-11-04.

1. App Review, Apple: https://developer.apple.com/distribute/app-review/
2. Overview of submitting for review, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/
3. Overview of publishing your app on the App Store, Apple: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/
4. Reply to App Review messages, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages
5. App and submission statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/
6. Manage a submission with unresolved issues, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/manage-a-submission-with-unresolved-issues
7. Determine and upload app encryption documentation, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/
8. Contact form, appeal topic, Apple: https://developer.apple.com/contact/app-store/?topic=appeal returned a 302 to an Apple sign-in page on 2026-11-04, so its fields were not read.
9. Track a submission's review status, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/review-status
10. Accept Bug Fix Submission offers, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/bug-fix-submissions
11. Appeal to the App Review Board, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/appeal-to-the-app-review-board
12. Request an expedited review, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/request-expedited-review
