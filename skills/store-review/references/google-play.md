# Google Play: pre-submit checklist, rejections, responses

Bracketed numbers point to `## Sources`. Quotes are Google's words. Google's policies have no numbers, so the `id` column is this skill's short key, and the policy name is Google's. A policy not in this file: read it in the Policy Center [11].

## Checklist

One review line per row that applies. Search terms are where to look, not proof: read the file around each hit before you decide. A row that does not apply is left out.

| id | short name | applies when | Google requires | line |
|---|---|---|---|---|
| sign-in-details | Sign-in details | The files show a sign-in: a login or sign-up screen, a password field, an auth SDK in the dependencies, or a sign-in call. Search terms: `login`, `log in`, `sign in`, `signIn`, `sign_in`, `signUp`, `register`, `password`, `auth`. Also when a subscription paywall hides content | "If your entire app or parts of your app are restricted based on login credentials, sign in details, memberships, location, or other forms of authentication, you must provide all required details to enable access to your app" [1]. The details must be "accessible at all times, reusable, and valid regardless of user location", in English, and get past a 2-Step code or one-time password. "If the provided password expires, we may not be able to review your app and, therefore, the app may be rejected." With content behind a paywall, give access to it too [2] | `flag` unless the creator reports in this session that App content, Sign-in details, holds working details that meet those rules. A report that every section is saved is not this report. Fix: the creator types them in Play Console, App content, Sign-in details, Add new instructions, and Saves; anything special about the login goes in "Any other instructions" [1]; the creator reports "saved", never the account |
| deceptive-behavior | Deceptive Behavior: Misleading Claims | Every app with a `google_play` listing in `listing.md` | "Apps must provide an accurate disclosure, description and images/video of their functionality in all parts of the metadata." "Attempts to manipulate Play review processes, including misleading reviewers as to the purpose and functionality of your apps, are strictly prohibited." No title such as "Official" without the rights [3] | `flag` per listing claim that no project file shows. Quote it. Fix: rerun `store-listing`, which writes only what the code shows. `note` on "Official" or a brand name in the title: the creator judges the rights. `clear` when every feature claim traces to a file |
| spam-webview | Spam: Webviews and Affiliate Spam | The main screen loads a website in a web view, or the app mostly sends people to a website | "We don't allow apps whose primary purpose is to drive affiliate traffic to a website or provide a webview of a website without permission from the website owner or administrator" [4] | `note`: only the creator knows whether they own the site or have permission |
| functionality | Functionality, Content, and User Experience: Limited Functionality and Content | The app is static text, a PDF, or a single image, or shows very little content | "We do not allow apps that only have limited functionality and content." Examples: "text only or PDF file apps", "single wallpaper apps", apps "designed to do nothing or have no function" [5] | `note`: the creator judges whether the app has enough to do |
| privacy-policy | User Data: Privacy Policy | Every app | "All apps must post a privacy policy link in the designated field within Play Console, and a privacy policy link or text within the app itself." Apps with no personal data still need one [6]. The page must be public, not geofenced, not a PDF, and not editable [1][6] | `flag` when `provided.publish-readiness.privacy_policy_url` is empty. Fix: run `publish-readiness`. `flag` when no project file holds that URL, a link labeled privacy policy, or the policy text. Fix: add it in the app, or the creator shows where the app has it. `clear` with both pieces of evidence |
| prominent-disclosure | User Data: Prominent Disclosure and Consent | The manifest or `data_inventory` shows personal or sensitive data that people may not expect, such as background location, contacts, the list of installed apps, or SMS and call data [6] | When collection "may not be within the reasonable expectation of the user", the app needs an in-app disclosure "displayed in the normal usage of the app", that describes the data and its use, and that is "not only in a privacy policy or terms of service". Runtime permission requests "must be immediately preceded by" it, and consent needs an affirmative action [6] | `note`, with the permission and its file: the creator judges whether a disclosure screen comes before the request. `flag` only when no screen in the files describes that data before the request |
| account-deletion | User Data: Account Deletion Requirement | The files show account creation: a sign-up or register screen, a create-account call, or a link to a sign-up page outside the app | Apps that allow account creation "must also allow users to request for their account to be deleted", "from within your app and outside of your app (for example, by visiting your website)". Freezing an account is not deletion [6][7]. The web link goes in a Play Console field [6] | `flag` when no file shows a delete-account path in the app, or a link in the app to a deletion web page [7]. Fix: add one. The web link for Play Console is a Data safety answer, which `publish-android` fills from `publish-readiness`: name it, do not ask it. `clear` with the file |
| payments-disclosure | Payments: pricing disclosure | `monetization.model` is `freemium`, `subscription`, or `hybrid`, or the files show in-app purchase or subscription code | "If your product description on Google Play refers to in-app features that may require a specific or additional charge, your app listing must clearly notify users that payment is required to access those features" [8] | `flag` when a `google_play` description in `listing.md` names a paid feature and does not say it costs extra. Fix: rerun `store-listing` with that fact. `clear` otherwise. With no `listing.md`, `note` that it could not be checked |
| subscriptions | Subscriptions | `monetization.model` is `subscription` or `hybrid`, or the files show a subscription offer | Disclose "your offer terms, the cost of your subscription, the frequency of your billing cycle, the automatic renewal terms, whether a subscription is required to use the app". The app must show how to manage or cancel, for example "A link to Google Play's Subscription Center" in account settings [9] | `flag` when no file shows a manage or cancel link for the subscription. Fix: add one to account settings [9]. `note`, with the paywall file: the creator judges the offer screen against the disclosure list |

Payments and Subscriptions rows are disclosure checks only. Setting up billing is not this skill's. Data safety answers are not reviewed here: they come from `publish-readiness` and `publish-android`.

## Reading a rejection

For a policy violation, Google says to "Check your Notifications and email for information about the policy your app violated" [13]. In Play Console, the submission shows Rejected. "Latest rejected submissions include a link to the Policy status page, where you can see details of the issue and get instructions on how to fix them" [10]. The Policy status page shows each active enforcement: rejection, removal, or suspension [12]. If an update is rejected, "your last approved version remains live" [10]. Read the policy name as the message writes it. Look it up in the checklist above. If it is not there, say so, work from the message's own words, and name the policy so the creator can read it in the Policy Center [11].

## Response routes

| situation | route | who acts |
|---|---|---|
| A fix in App content, such as Sign-in details, or in the listing | Make the change and Save; then the Publishing overview, Send for review. Google: "You can complete these steps without contacting or waiting for a reply from the policy support team" [1] | The creator saves; `publish-android` Step 15 sends it, with its block |
| A fix in code | A new build with a new version code | `publish-android`, from Step 8, then its Step 15 block |
| Removed from Google Play | A compliant update on every track that holds the old bundle, with the non-compliant bundles under "Not included", rolled out to 100%. "If you fail to deactivate the non-compliant app bundle(s), your attempt to resubmit your app will fail" [13] | `publish-android`; each roll-out is its own block |
| Suspended | "You can select Appeal to initiate an appeal" on the Policy status page [12] | This skill's message block |
| The creator believes the app complies | Appeal: Google reinstates apps "if an error was made" [13] | This skill's message block |

The pages read give no route to reply to a reviewer on Google Play. "Until a policy violation has been fixed, don't republish a rejected or removed app" [12].

## Messages

Each message reaches Google's policy team, so each is a go-ahead. The `Action:` line uses the words below. Give the route only after the yes. The creator sends it. Proof: the creator reports it sent.

| message | action | route, after the yes |
|---|---|---|
| Appeal | "send this appeal to Google Play about <the rejection, removal, or suspension>" | For a suspension, Policy status, Appeal [12]. Otherwise the "File an appeal" link on Google's removal page [13] |

"You may submit one appeal per app removal, suspension, or other enforcement action." Google answers appeals "in Chinese, English, Japanese, and Korean". Misusing the appeals process can end email support [13]. In the appeal, name the policy, and explain with evidence how the app meets it.

## Review times

"Processing can take a few hours or up to seven days (or longer in exceptional cases), as it depends on the review time that your app is subject to" [14]. "For certain developer accounts, we'll take more time to thoroughly review your app", up to seven days or longer [10].

## Sources

All fetched with curl and read 2026-11-04.

1. Prepare your app for review, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859455?hl=en
2. Requirements for providing sign in details for review, Play Console Help: https://support.google.com/googleplay/android-developer/answer/15748846?hl=en
3. Deceptive Behavior, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9888077?hl=en (redirected to answer 17006354)
4. Spam, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9899034?hl=en
5. Functionality, Content, and User Experience, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9898783?hl=en
6. User Data, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9888076?hl=en (redirected to answer 10144311)
7. Understanding Google Play's app account deletion requirements, Play Console Help: https://support.google.com/googleplay/android-developer/answer/13327111?hl=en
8. Payments, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9858738?hl=en
9. Subscriptions, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9900533?hl=en
10. Publish your app, and About your submission activity, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859751?hl=en and https://support.google.com/googleplay/android-developer/answer/17118609?hl=en
11. Developer Program Policy Center, Google Play: https://play.google/developer-content-policy/
12. Check your app's policy status, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9842754?hl=en
13. My app has been removed from Google Play, Play Console Help: https://support.google.com/googleplay/android-developer/answer/2477981?hl=en
14. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
