# Data safety from the readiness inventory

How to fill Play Console's Data safety form from `.app-creators/readiness.md`. Never interview the creator: this list holds the answers. Skills install separately, so this file carries its own mapping. Bracketed numbers point to `## Sources`.

## Scope

Use `data_inventory.items` whose `platforms` holds `android`. The form is one per app, at the package level [1], and covers data collected by third-party libraries and SDKs in the app [1].

Who must fill it: every app with a release on closed, open, or production testing tracks. An app active only on internal testing is exempt [1]. An app that collects nothing still fills it, and links a privacy policy [1].

An item with `linked_to_user`, `used_for_tracking`, or `optional` set to `unknown` was confirmed that way. Flag it in the worksheet as "not settled in the inventory; decide in the form", and do not ask here. The form has no `unknown` answer.

## The form

Play Console, App content, Data safety [1]. A privacy policy must be added first [1]: `references/app-content.md`.

1. Overview: read it, Next [1].
2. Data collection and security: does the app collect or share any required data type? Then whether all collected data is encrypted in transit, and whether users can request deletion [1]. The inventory does not hold the last two: flag them for the creator to answer in the form.
3. Data types: select each type below, Next [1].
4. Data usage and handling: per type, Start, then answer [1].
5. Store listing preview, then Submit, or Save as draft [1].

After Submit, Google reviews the answers as part of the app review process, and they are shown on the store listing [1]. On an app already on Google Play, the change joins the Publishing overview and goes out with Send for review [2]. Our reading, not Google's words: send a change in the same submission as the release that needs it, so an added data type is not declared before the build that collects it, and do not remove a type while any release on closed, open, or production still collects it. The form is global per package [1], so it must cover every build those tracks serve.

## Data types

| `data_type` | Data safety type [1] |
|---|---|
| name | Personal info: Name |
| email address | Personal info: Email address |
| phone number | Personal info: Phone number |
| postal address | Personal info: Address |
| account id | Personal info: User IDs |
| device or advertising id | Device or other IDs |
| precise location | Location: Precise location |
| approximate location | Location: Approximate location. One inferred from an IP address goes here too |
| contacts | Contacts: Contacts |
| photos | Photos and videos: Photos |
| videos | Photos and videos: Videos |
| voice or sound recordings | Audio files: Voice or sound recordings |
| emails or text messages | Messages: Emails; SMS or MMS; Other in-app messages |
| other text the user writes | App activity: Other user-generated content |
| files and documents | Files and docs: Files and docs |
| calendar events | Calendar: Calendar events |
| health data | Health and fitness: Health info |
| fitness data | Health and fitness: Fitness info |
| payment details | Financial info: User payment info |
| purchase history | Financial info: Purchase history |
| search history in the app | App activity: In-app search history |
| web browsing history | Web browsing: Web browsing history |
| app interactions | App activity: App interactions |
| installed apps | App activity: Installed apps |
| crash logs | App info and performance: Crash logs |
| performance data | App info and performance: Diagnostics |
| sensitive traits | Personal info: Race and ethnicity; Political or religious beliefs; Sexual orientation |

An item with a `data_type` not in this table: show it, and let the creator pick from the form, which also lists Other info, Credit score, Other financial info, Music files, Other audio files, Other actions, and Other app performance data [1].

## Each data type's questions

| form question | from the item |
|---|---|
| Collected, shared, or both. Sharing means a transfer to a third party, not to a service provider acting on the developer's instructions [1] | `shared_with`: empty means collected only |
| Processed ephemerally: held in memory only for the request [1] | not in the inventory: flag it |
| Required, or optional: users can choose [1] | `optional` |
| Purposes: App functionality, Analytics, Developer communications, Advertising or marketing, Fraud prevention, security, and compliance, Personalization, Account management [1] | `purpose`, in plain words. Pick the closest, and show the word you read |

`linked_to_user` and `used_for_tracking` have no question of their own on this form on the page read. Show them as context.

## Sources

All fetched with curl and read 2026-11-03.

1. Provide information for Google Play's Data safety section, Play Console Help: https://support.google.com/googleplay/android-developer/answer/10787469?hl=en
2. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
