# App Store: pre-submit checklist, rejections, responses

Bracketed numbers point to `## Sources`. Quotes are Apple's words. The guidelines page read was "Last Updated: October 16, 2026" [1]. A guideline not in this file: read it on that page [1].

## Checklist

One review line per row that applies. Search terms are where to look, not proof: read the file around each hit before you decide. A row that does not apply is left out.

| id | short name | applies when | Apple requires | line |
|---|---|---|---|---|
| 2.1(a) | Demo account | The files show a sign-in: a login or sign-up screen, a password field, an auth SDK in the dependencies, or a sign-in call. Search terms: `login`, `log in`, `sign in`, `signIn`, `sign_in`, `signUp`, `register`, `password`, `auth` | "include demo account info (and turn on your back-end service!) if your app includes a login" [1]. In App Store Connect, App Review Information, "Sign-in required: Username and password", "Sign-in information for a demo account ... must not expire" [3]. "Credentials that expire or change before your review starts may result in the submission being rejected" [2]. A built-in demo mode in place of a demo account is for apps that cannot give one "due to legal or security obligations", "with prior approval by Apple", and it must exhibit the app's full features [1] | `flag` unless the creator reports in this session that Sign-in required holds a working demo account, or that the app has a full demo mode Apple approved. A report that every section is saved is not this report. Fix: the creator types a username and password that will not expire into App Review Information, Sign-in required, and Saves; extra accounts and any authentication code go in the Notes field [2][3]; the creator reports "saved", never the account. With auto-renewable subscriptions, also add "a demo account with an expired subscription" [2] |
| 4.3 | Spam | The files show one of the kinds Apple names as well established: "dating, flashlight, sound effects, wallpaper, simple timers, and fortune telling", or several bundle ids or targets of the same app [1] | 4.3(a): "Don't create multiple Bundle IDs of the same app". 4.3(b): those kinds are not accepted "unless they offer a meaningfully different or improved experience" [1] | `note`: the creator judges what makes this app different |
| 4.2 | Minimum Functionality | The main screen loads a website in a web view, or the app is mostly links, marketing, or static content, or it needs another app installed to work | "include features, content, and UI that elevate it beyond a repackaged website" [1]. 4.2.2: "Other than catalogs, apps shouldn't primarily be marketing materials, advertisements, web clippings, content aggregators, or a collection of links". 4.2.3(i): "work on its own without requiring installation of another app" [1] | `note`: the creator judges whether the app does more than the website |
| 5.1.1(i) | Privacy policy | Every app | "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner" [1] | `flag` when `provided.publish-readiness.privacy_policy_url` is empty. Fix: run `publish-readiness`, which records it. `flag` when no screen or component people can reach renders a link to that URL or a link labeled privacy policy. A URL only in config, in state, or in a constant no screen uses does not count: Apple requires the link within the app. Fix: add the link to a screen people can reach, such as settings or about, or the creator shows which screen links it. `clear` with both pieces of evidence: the state field and the screen file |
| 5.1.1(ii) | Purpose strings | The project declares a permission usage string (`NS...UsageDescription`) | "Ensure your purpose strings clearly and completely describe your use of the data" [1]. "A purpose string that only restates the name of the resource, or promises a general benefit without saying what your app actually does, doesn't meet the requirement" [5]. Localized apps need localized strings [5] | `flag` per string that is empty or only names the resource. Quote it. Fix: one sentence naming the feature and an example of use [5]. `note` on a string that names a benefit but no feature. `clear` otherwise. A missing string is `publish-readiness`'s check: cite its result, do not repeat it |
| 5.1.1(v) | Account deletion | The files show account creation: a sign-up or register screen, a create-account call, or an automatic or guest account | "If your app supports account creation, you must also offer account deletion within the app" [1]. Guest accounts count. Deactivating alone is not enough. A website step needs "a link directly to the page" [4] | `flag` when no file shows a delete-account path in the app. Fix: add one, findable in account settings [4]. `clear` with the file that shows it |
| 4.8 | Login Services | The files show a third-party or social login, such as Google, Facebook, X, LinkedIn, Amazon, or WeChat, for the app's primary account | Such apps "must also offer as an equivalent option another login service" that limits data to name and email, lets people keep their email private, and collects no interactions for advertising without consent. Exceptions: the app uses only the company's own sign-in, is an education, enterprise, or business app using an existing account, uses a government or industry citizen ID, or is a client for a specific third-party service [1] | `flag` when that login is the only sign-in and no file shows Sign in with Apple. Fix: add a login service with those three features, or the creator names the exception that applies. `note` when the app also has its own sign-in: the creator judges whether it meets the three features. `clear` when the files show Sign in with Apple |
| 2.3.2 | In-app purchase disclosure | `monetization.model` is `freemium`, `subscription`, or `hybrid`, or the files show in-app purchase or subscription code | "make sure your app description, screenshots, and previews clearly indicate whether any featured items, levels, subscriptions, etc. require additional purchases" [1] | `flag` when no `app_store` description in `listing.md` says what costs extra. Fix: rerun `store-listing` with that fact. `clear` with the sentence. With no `listing.md`, `note` that it could not be checked |
| 3.1.2(c) | Subscription information | `monetization.model` is `subscription` or `hybrid`, or the files show a subscription offer | "Before asking a customer to subscribe, you should clearly describe what the user will get for the price" [1] | `note`, with the paywall file: the creator judges whether it says what the price buys |

In-app purchase and subscription rows are disclosure checks only. Setting up purchases is not this skill's.

## Reading a rejection

The message arrives in App Store Connect, in the app's App Review section, and states how the app violates the guidelines [6]. A rejected version shows Rejected or Metadata Rejected, and a submission with a rejected item shows Unresolved Issues [13]. Read the guideline number as the message writes it, such as "Guideline 2.1". Look it up in the checklist above. If it is not there, say so, work from the message's own words, and name the number so the creator can read it on the guidelines page [1].

## Response routes

A `Route:` line takes the route kind and who acts from the last column. Control names, click paths, and forms are only in the Messages table, given after the yes.

| situation | route | who acts |
|---|---|---|
| A build issue, fixed in code | Resubmit: "Upload the new build and submit that version" [8]. A new build and build number | resubmit: `publish-ios`, from Step 8, then its Step 13 block |
| A metadata issue, or a fix on the server or in App Store Connect, "such as providing or activating demo credentials" | Default: make the change, then reply; Apple says a resubmission is not necessary [8]. Alternative: resubmit the same build [6] | reply: this skill's message block. Alternative, resubmit: `publish-ios` Step 13 |
| App Review asked for more information, and nothing else is open | Reply; "Resubmitting starts a new review, after which App Review can no longer reply to your previous message" [8] | reply: this skill's message block |
| The message says "Bug Fix Submissions: The issues we've identified below are eligible to be resolved on your next update." | Reply accepting the offer. "Do not resubmit the app at this time, as it will trigger a new review." Only for updates to apps approved before; deferred issues cannot be deferred again [9] | reply: this skill's message block |
| Some items rejected, others accepted | "Remove the rejected items and resubmit" [8] | resubmit: `publish-ios` Step 13 |
| The creator believes the app complies, or was treated unfairly | First reply with a clarification; if that does not resolve it, appeal [10]. Resubmitting closes the appeal [8] | reply, then appeal: this skill's message blocks |

Never appeal an information request, a status question, or an expedite request [10]. Do not resubmit until every issue is resolved [8].

## Messages

Each message reaches a reviewer, so each is a go-ahead. The `Action:` line uses the words below. Give the route only after the yes. The creator sends it. Proof: the creator reports it sent.

| message | action | route, after the yes |
|---|---|---|
| Reply | "send this reply to App Review" | Role: Account Holder, Admin, or App Manager. In Apps, the app; the link at the top for unresolved issues; In Progress, Resolve next to the submission; Reply to App Review; the Reply field; Attach File if needed; Reply [6] |
| Bug-fix acceptance | "reply to App Review accepting the bug-fix offer: approve the current submission, and address the issues in the next update" | The same Reply to App Review path, on the rejection message [6][9] |
| Call request | "ask App Review for a call about this rejection" | In the Reply to App Review window, after App Review has replied. Include the time zone and a preferred language. "Calls are typically completed within three to five business days" [7] |
| Appeal | "send this appeal to the App Review Board" | The "Submit an appeal to App Review" form [10][14]. Its fields were not read: the form sits behind Apple sign-in [14] |
| Expedited review request | "send this expedited review request to App Review" | The "Request an Expedited App Review" form; only for a submission already sent to App Review [12][15]. Its fields were not read: the form sits behind Apple sign-in [15] |

What to write:

- Reply: be specific about the feature, guideline, or step; add what helps App Review understand the app. Do not use it to appeal or to ask for an expedite [7].
- Appeal: "Cite the specific guideline or terms your app was rejected or removed under, and explain point by point how your app meets it." One appeal per rejected or removed app, covering every cited guideline. Apple's complete example: "My app was rejected under Guideline 2.1 for incomplete information. The demo account and setup steps needed to test the flagged feature are included in the App Review Information section of this submission, along with screenshots showing the feature working as described." [10]
- Expedite: a critical bug fix, with steps to reproduce on the current version, or an event the app is directly associated with, with its date [11][12].

## Review times

"App Review works around the clock, typically reviewing at least 50% of submissions in less than 24 hours and 90% in less than 48 hours" [11]. Apps with little review history, required documents, or complex issues can take longer [8]. Repeated rejections for the same guideline make review take longer [1]. After approval, it "can take up to 24-hours" to appear on every selected storefront [1].

## Sources

All fetched with curl and read 2026-11-04.

1. App Review Guidelines, Apple: https://developer.apple.com/app-store/review/guidelines/
2. Provide information for a complete review, Apple: https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review
3. Platform version information, App Review information, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
4. 5.1.1(v) Offering account deletion in your app, Apple: https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion (the older `support/offering-account-deletion-in-your-app/` path redirects here)
5. 5.1.1(ii) Write clear purpose strings, Apple: https://developer.apple.com/help/app-review/guideline-reference/5-1-1-purpose-strings
6. Reply to App Review messages, Apple: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/reply-to-app-review-messages
7. Contact App Review for help with a submission, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/contact-app-review
8. Track a submission's review status, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/review-status
9. Accept Bug Fix Submission offers, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/bug-fix-submissions
10. Appeal to the App Review Board, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/appeal-to-the-app-review-board
11. App Review, Apple: https://developer.apple.com/distribute/app-review/
12. Request an expedited review, Apple: https://developer.apple.com/help/app-review/after-submitting-for-review/request-expedited-review
13. App and submission statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/
14. Contact form, appeal topic, Apple: https://developer.apple.com/contact/app-store/?topic=appeal
15. Contact form, expedite topic, Apple: https://developer.apple.com/contact/app-store/?topic=expedite
