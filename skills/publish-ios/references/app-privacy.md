# App Privacy from the readiness inventory

How to fill App Store Connect's App Privacy form from `.app-creators/readiness.md`. Never interview the creator: this list holds the answers. Skills install separately, so this file carries its own mapping. Bracketed numbers point to `## Sources`.

## Scope

Use `data_inventory.items` whose `platforms` holds `ios`. Responses are at the app level across Apple platforms, and you answer the most comprehensive way if a platform collects more [2]. You also answer for third-party partners' code [2]. For a live app, your responses reflect only that app version [2].

An item with `linked_to_user`, `used_for_tracking`, or `optional` set to `unknown` was confirmed that way. Flag it in the worksheet as "not settled in the inventory; decide in the form", and do not ask here. A store form with the answer `unknown` does not exist, so the creator chooses, and the next `publish-readiness` run can record it.

## The form

Role: Account Holder, Admin, or App Manager. Apps, the app, App Privacy, Get Started [2].

- **No items for `ios`:** "No, we do not collect data from this app", then Save [2]. A privacy policy URL is still required [2].
- **Items:** "Yes, we collect data from this app", Next. Select each data type, Save. Then for each one, answer its questions, Save [2].
- **Publish.** A dialog confirms the responses are accurate. They are published on the product page; if it is not live yet, they publish when it goes live [2]. On a `live` app, Publish reaches the public at once, so it is a **go-ahead** step.

## Data types

| `data_type` | App Privacy data type [1] |
|---|---|
| name | Contact Info: Name |
| email address | Contact Info: Email Address |
| phone number | Contact Info: Phone Number |
| postal address | Contact Info: Physical Address |
| account id | Identifiers: User ID |
| device or advertising id | Identifiers: Device ID |
| precise location | Location: Precise Location |
| approximate location | Location: Coarse Location |
| contacts | Contacts: Contacts |
| photos, videos | User Content: Photos or Videos |
| voice or sound recordings | User Content: Audio Data |
| emails or text messages | User Content: Emails or Text Messages |
| other text the user writes, files and documents | User Content: Other User Content |
| health data | Health & Fitness: Health |
| fitness data | Health & Fitness: Fitness |
| payment details | Financial Info: Payment Info. Not collected if a payment service takes it outside the app and you never have access |
| purchase history | Purchases: Purchase History |
| search history in the app | Search History: Search History |
| web browsing history | Browsing History: Browsing History |
| app interactions | Usage Data: Product Interaction |
| crash logs | Diagnostics: Crash Data |
| performance data | Diagnostics: Performance Data |
| sensitive traits | Sensitive Info: Sensitive Info |
| calendar events, installed apps | Other Data: Other Data Types, as no closer type is listed |

An item with a `data_type` not in this table: show it, and let the creator pick from the form. An IP address has no type of its own: declare it by use [1].

## Each data type's questions

| form question | from the item |
|---|---|
| Purposes: Third-Party Advertising, Developer's Advertising or Marketing, Analytics, Product Personalization, App Functionality, Other Purposes [1] | `purpose`, in plain words. Pick the closest, and show the word you read |
| Linked to the user's identity [1] | `linked_to_user` |
| Used for tracking: linking with third-party data for targeted advertising or measurement, or sharing with a data broker [1] | `used_for_tracking` |

`optional` and `shared_with` have no question of their own on the pages read. Show them as context for the tracking and linking answers.

## Sources

All fetched with curl and read 2026-11-03.

1. App privacy details on the App Store, Apple: https://developer.apple.com/app-store/app-privacy-details/
2. Manage app privacy, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
