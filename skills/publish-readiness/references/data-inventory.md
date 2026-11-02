# Data inventory

How to build `data_inventory` in `.app-creators/readiness.md`. Bracketed numbers point to `## Sources`. The creator confirms the list; the publish skills later copy App Privacy and Data safety answers from it.

## What counts as collected

An item goes in the inventory only when data leaves the device.

| question | App Store | Google Play |
|---|---|---|
| What is "collect"? | Transmitting data off the device so you or a third-party partner can access it for longer than it takes to service the request in real time [1] | Transmitting data from your app off the user's device [2] |
| Data that stays on the device | Not collected; no disclosure. Anything derived from it and sent off the device counts separately [1] | Not in scope for collection [2]. Moving it to another app on the device is sharing, and must be disclosed even if nothing leaves the device [2] |
| Sent, used for the request, not kept | Need not be disclosed [1] | Goes in the form; if processed ephemerally, not shown on the listing [2] |
| End-to-end encrypted so that you cannot read it | No rule found on the page fetched | Need not be disclosed [2] |
| Sent by an SDK or library | Counts; you answer for third-party partners' code [1] | Counts, whichever server receives it [2] |
| Web view | Web traffic data counts, unless the user is navigating the open web [1] | Counts if your app controls the view's code; not for open-web navigation [2] |
| Nothing is collected | A privacy policy URL is still required [1][3] | The form and a privacy policy link are still required [2] |

Web has no store form. An item scoped to `web` decides `--collects-data` for `check-readiness.py`: any such item in a confirmed inventory is `yes`, none is `no`. Apply the Google Play meaning of "collect", because the rule the script enforces asks only whether data leaves the browser.

## How to scan

1. List dependencies: `package.json`, `pubspec.yaml`, `Podfile`, `Package.swift`, `build.gradle` or `build.gradle.kts`, `gradle/libs.versions.toml`.
2. Mark each dependency that does analytics, ads, crash reporting, auth, payments, push, a backend client, or maps.
3. Search the code for network calls: `fetch(`, `axios`, `XMLHttpRequest`, `sendBeacon`, `WebSocket`, `http.`, `dio`, `URLSession`, `Alamofire`, `Retrofit`, `OkHttp`, `HttpURLConnection`.
4. Search for what those calls send: login and profile fields, form values, location, contacts, photos, device ids, purchase records.
5. Read the permission lines from `check-readiness.py`. A permission shows access, not collection. Local use with no network path adds no item.

For an SDK, read what its vendor publishes: its `PrivacyInfo.xcprivacy` with `NSPrivacyCollectedDataTypes` [4][5], and its data safety guidance, linked from Google Play SDK Index [6]. Apple notes that an app's own manifest need not cover what linked SDKs collect [5], and a privacy report from Xcode summarizes them [5]. Google notes the form must reflect third-party code, and that the developer alone answers for it [2].

Never invent what an SDK does. If the vendor publishes nothing and the code does not show it, add the item with `evidence` naming the SDK, and leave the fields `unknown`. Ask the creator only about what the code cannot show.

## Item fields

| field | fill with | leave |
|---|---|---|
| `data_type` | the plain name from the table below | never empty |
| `platforms` | the builds that collect it, from `ios`, `android`, `web`. A dependency in one platform's code only scopes to that platform | `[]` only while unknown; ask the creator to scope it |
| `evidence` | the file and line, or the SDK | never empty |
| `purpose` | what the app uses it for, in the creator's terms | `""` when unknown |
| `linked_to_user` | `yes` or `no`: linked to identity through an account, device, or other detail [1] | `unknown` |
| `used_for_tracking` | `yes` or `no`: combined with other companies' data for ads or ad measurement, or shared with a data broker [1] | `unknown` |
| `shared_with` | third parties that receive it, excluding service providers acting on the developer's instructions [2] | `[]` |
| `optional` | `yes` when users can use the app without providing it [2] | `unknown` |

Record `unknown` honestly, and ask the creator to settle those fields in the inventory review, because the store forms are later filled from this list and never from a new interview. If the creator cannot say, the field stays `unknown` and the list can still be confirmed.

On a rerun, match items by `data_type` and `evidence`. Keep a matching confirmed item verbatim. Ask only about an item that is new or whose `evidence` or `platforms` changed. Say which items disappeared from the scan, and remove one only after the creator agrees.

## Plain types and their form entries

| plain `data_type` | App Privacy [1] | Data safety [2] |
|---|---|---|
| name | Contact Info: Name | Personal info: Name |
| email address | Contact Info: Email Address | Personal info: Email address |
| phone number | Contact Info: Phone Number | Personal info: Phone number |
| postal address | Contact Info: Physical Address | Personal info: Address |
| account id | Identifiers: User ID | Personal info: User IDs |
| device or advertising id | Identifiers: Device ID | Device or other IDs |
| precise location | Location: Precise Location | Location: Precise location |
| approximate location | Location: Coarse Location | Location: Approximate location |
| contacts | Contacts | Contacts |
| photos | User Content: Photos or Videos | Photos and videos: Photos |
| videos | User Content: Photos or Videos | Photos and videos: Videos |
| voice or sound recordings | User Content: Audio Data | Audio files: Voice or sound recordings |
| emails or text messages | User Content: Emails or Text Messages | Messages: Emails; SMS or MMS; Other in-app messages |
| other text the user writes | User Content: Other User Content | App activity: Other user-generated content |
| files and documents | User Content: Other User Content | Files and docs |
| calendar events | Other Data Types | Calendar: Calendar events |
| health data | Health & Fitness: Health | Health and fitness: Health info |
| fitness data | Health & Fitness: Fitness | Health and fitness: Fitness info |
| payment details | Financial Info: Payment Info; not collected if a payment service takes it outside the app and you never have access | Financial info: User payment info |
| purchase history | Purchases: Purchase History | Financial info: Purchase history |
| search history in the app | Search History | App activity: In-app search history |
| web browsing history | Browsing History | Web browsing: Web browsing history |
| app interactions | Usage Data: Product Interaction | App activity: App interactions |
| crash logs | Diagnostics: Crash Data | App info and performance: Crash logs |
| performance data | Diagnostics: Performance Data | App info and performance: Diagnostics |
| installed apps | Other Data Types | App activity: Installed apps |
| sensitive traits, such as race, beliefs, or orientation | Sensitive Info | Personal info: Race and ethnicity; Political or religious beliefs; Sexual orientation |

`Other Data Types` here means no closer App Privacy type is listed on the page fetched [1]. An IP address has no type of its own on App Privacy: declare it by use, such as location, device id, or diagnostics [1]. On Data safety, a location inferred from an IP address goes under location [2].

## Purposes

| App Privacy [1] | Data safety [2] |
|---|---|
| Third-Party Advertising; Developer's Advertising or Marketing | Advertising or marketing |
| Analytics | Analytics |
| Product Personalization | Personalization |
| App Functionality | App functionality; Account management; Fraud prevention, security, and compliance |
| no match | Developer communications |
| Other Purposes | no match |

Write `purpose` in plain words; a publish skill picks the form's entry at submission. App Privacy also offers optional disclosure for narrow cases, each with all-of criteria [1]. List the item here regardless.

## Sources

Fetched with curl and read 2026-11-02 (UTC).

1. App privacy details on the App Store, Apple: https://developer.apple.com/app-store/app-privacy-details/
2. Provide information for Google Play's Data safety section, Play Console Help: https://support.google.com/googleplay/android-developer/answer/10787469
3. Manage app privacy, App Store Connect Help: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
4. Privacy manifest files, Apple: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
5. Describing data use in privacy manifests, Apple: https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests
6. Google Play SDK Index: https://developer.android.com/distribute/sdk-index
