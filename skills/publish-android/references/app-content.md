# App content declarations

Play Console's App content page holds the safety, policy, and legal declarations Google needs before publishing [1]. Every answer is the creator's: legal, or about what the app does. The worksheet gives what the project files say, and the creator answers in the form. Bracketed numbers point to `## Sources`.

Path: Play Console, the app, Monitor and improve, Policy and programs, App content [1]. Two tabs: Needs attention, and Actioned [1]. Read Needs attention back: every item there is a declaration this app still owes, including any this file does not list.

| declaration | what Google requires | the worksheet line |
|---|---|---|
| Privacy policy | Required for every app, even one that collects nothing, on the store listing and in the app. A public, active URL with valid SSL, reachable worldwide with no login, on a normal web page and not a PDF, specific to this app [1] | `provided.publish-readiness.privacy_policy_url`. Whether its text is accurate is the creator's |
| Ads | Declare whether the app contains ads, including ads from third-party SDKs. Yes shows "Contains ads" on the listing. Misrepresenting it can suspend the app [1] | Ad SDKs in the inventory's `evidence`, and `monetization.model`. The creator answers |
| Sign-in details (app access) | If any part of the app needs a login, membership, location, or other access, give reviewers working access: reusable, never expiring, valid anywhere, in English, with a way past 2-Step codes [1][2]. Up to five sets of instructions [1] | Whether the code shows a login. The creator types the demo account in Play Console, never in chat |
| Target audience and content | Declare the target age groups; any group with children brings the Families policy. Ads, app access, and the privacy policy must be declared first [1][3] | `play_target_age` from `age_rating.answers` |
| Content rating | IARC questionnaire: `references/content-rating.md` [1] | From `age_rating.answers` |
| Data safety | `references/data-safety.md` [1] | From `data_inventory` |
| Permissions declaration | High-risk or sensitive permissions, such as SMS or Call Log, may need this form and Google's approval [1] | The declared permissions `publish-readiness` reported. The creator fills the form |

On an app already on Google Play, each saved change joins "Changes not yet sent for review" and goes out with Send for review [4]. Saving reaches no one.

## Sources

All fetched with curl and read 2026-11-03.

1. Prepare your app for review, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859455?hl=en
2. Requirements for providing sign in details for review, Play Console Help: https://support.google.com/googleplay/android-developer/answer/15748846?hl=en
3. Manage target audience and app content settings, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9867159?hl=en
4. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
