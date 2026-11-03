# Accounts, app record, and API access

What the human-only and app record steps need, on any route. Everything here is the creator's: give the facts, never an answer to a legal question. Bracketed numbers point to `## Sources`.

## Play Console developer account

Needs a Google Account and an age of at least 18. Sign up in Play Console, accept the Developer Distribution Agreement, pay, choose an account type, and verify identity [1].

| | personal | organization |
|---|---|---|
| for | personal use, such as a student, hobbyist, or amateur developer. You can still earn money and invite others [2] | an organization or business. Required for financial products, health apps, apps using the VpnService class, and government apps [2] |
| D-U-N-S Number | not needed | required, free from Dun & Bradstreet; a government body without one contacts support [2][3] |
| identity documents, when the payments profile is not yet verified | an official government identity document [3] | the D-U-N-S Number, an official government identity document, and an official organization document [3] |
| also verified | developer email, shown on Google Play; device verification [3] | developer email and phone, both shown on Google Play; website, for organization accounts created since February 2024 [3] |
| before production | a closed test and a production access application, below, for accounts created after November 13, 2023 [4] | no such testing requirement on the pages read |

Fee: US$25, once. Mastercard, Visa, American Express, Discover (US only), or Visa Electron (outside the US); no prepaid cards [1]. Google may ask for a government ID and a credit card under the legal name, and does not refund the fee if they are found invalid [1].

The account links a Google payments profile, which verifies identity; a personal account's legal name and address come from it [3]. A contact phone and email are verified too, and not shown on Google Play [3]. "You must verify your developer account before you can submit apps" [3]. If Google cannot verify the information, apps may be removed [3].

**Device verification**, new personal accounts: the account owner scans a code from the Play Console home page, signs in to the Play Console mobile app on a non-rooted Android device running Android 10 or later, and taps Verify. It takes under a minute [5].

**Android developer verification.** Google's new program begins enforcement on September 30, 2026 for apps installed from participating stores in Brazil, Indonesia, Singapore, and Thailand, and expands globally in 2027 [6]. A developer who distributes only on Google Play uses the existing Play Console account and is registered automatically. Google says Play registers 99% of apps automatically, and the rest are registered manually in Play Console [6][7]. If the Play Console home page shows a registration task, it is the creator's.

## Testing requirement for new personal accounts

For a personal account created after November 13, 2023 [4]:

- The Production page and Pre-registration stay disabled until the requirement is met [4].
- Run a closed test with at least 12 testers who have been opted in continuously for the 14 days before applying [4]. A tester who opts out and back in restarts that count [4]. Open testing becomes available only after production access [4].
- Then, on the Dashboard, Apply for production. The form has three parts: About your closed test, About your app/game, and About your production readiness [4]. The creator writes every answer. Unsaved parts are lost on Discard [4].
- Google reviews the application and emails the account owner. It "usually takes seven days or less, but can occasionally take longer" [4]. Google may ask for more testing, for example with fewer than 12 opted-in testers or low engagement [4].
- Approval enables the Production page and Open testing [4].

Recruiting testers is the creator's. Google suggests personal and professional networks [4]. Never ask for testers' addresses in chat: the creator enters them in Play Console.

## App record

Path: Play Console, Create app [8]. Fields:

- App name, as it appears on Google Play: `title` from `listing.md` for the default language. It can change later [8].
- Package name: `targets.android.package`, from the project. Package names are unique and permanent, and cannot be deleted or reused [8]. Once a bundle is uploaded, the app's package name is fixed [9].
- Default language: `references/localizations.md`.
- App or game: can change later [8].
- Free or paid: **the creator decides.** A paid app can become free, but once an app has been offered for free it cannot become paid; charging then needs a new app with a new package name [10]. `monetization.model` shows the intent; it is not the answer.
- Contact email that users can use: typed by the creator [8].
- Declarations: Developer Program Policies, US export laws, and the Play App Signing Terms of Service [8]. Legal: the creator reads and accepts them.

Then the app's Dashboard lists the setup tasks [8][11].

## Users and permissions

The account owner or an admin invites users and grants permissions, account-wide or per app: Users and permissions, Invite new users [12]. Turning managed publishing on or off, and proceeding past pre-review checks, need one of: Release to production, exclude devices, and use Play App Signing; Release apps to testing tracks; Manage testing tracks and edit tester lists; Manage store presence; or Admin [13][14].

## Google Play Developer API access

Needed only by a route that uploads through the API, such as `eas submit`. All of it is the creator's [15][16]:

1. A Google Cloud project, with the Google Play Android Developer API enabled [15][16].
2. A service account in Google Cloud, and a JSON key for it, downloaded once and kept outside the repo [15][16].
3. In Play Console, Users and permissions, Invite new users, the service account's email, with the permissions the route lists [15][16].

The API changes only an app that has at least one APK uploaded through Play Console, and it cannot fill the legal consents needed to publish [17]. So the first upload is in Play Console on every route. Never ask to see the key file, and record only an env var name.

## Sources

All fetched with curl and read 2026-11-03.

1. Get started with Play Console, Play Console Help: https://support.google.com/googleplay/android-developer/answer/6112435?hl=en
2. Choose a developer account type, Play Console Help: https://support.google.com/googleplay/android-developer/answer/13634885?hl=en
3. Verify your developer identity information, Play Console Help: https://support.google.com/googleplay/android-developer/answer/10841920?hl=en
4. App testing requirements for new personal developer accounts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
5. Device verification requirements for new developer accounts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/14316361?hl=en
6. Android developer verification, Android Developers: https://developer.android.com/developer-verification
7. Android developer verification guides (last updated 2026-08-18), Android Developers: https://developer.android.com/developer-verification/guides
8. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
9. Set up an open, closed, or internal test, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9845334?hl=en
10. Set up your app's prices, Play Console Help: https://support.google.com/googleplay/android-developer/answer/6334373?hl=en
11. Set up your app on the app dashboard, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859454?hl=en
12. Add developer account users and manage permissions, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9844686?hl=en
13. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
14. Detect app issues early with pre-review checks, Play Console Help: https://support.google.com/googleplay/android-developer/answer/14807773?hl=en
15. Getting started, Google Play Developer API: https://developers.google.com/android-publisher/getting_started
16. Uploading a Google Service Account Key for Play Store Submissions with EAS, Expo: https://raw.githubusercontent.com/expo/fyi/main/creating-google-service-account.md (the page `https://expo.fyi/creating-google-service-account` redirects to it on GitHub)
17. Edits, Google Play Developer API (last updated 2025-12-18): https://developers.google.com/android-publisher/edits
