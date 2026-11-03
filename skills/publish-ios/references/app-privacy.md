# App Privacy from the readiness inventory

How to fill App Store Connect's App Privacy form from `.app-creators/readiness.md`. Never interview the creator: this list holds the answers. Skills install separately, so this file carries its own mapping. Bracketed numbers point to `## Sources`.

## Scope

Use `data_inventory.items` whose `platforms` holds `ios`. Responses are at the app level across Apple platforms, and you answer the most comprehensive way if a platform collects more [2]. You also answer for third-party partners' code [2].

An item with `linked_to_user`, `used_for_tracking`, or `optional` set to `unknown` was confirmed that way. Flag it in the worksheet as "not settled in the inventory; decide in the form", and do not ask here. A store form with the answer `unknown` does not exist, so the creator chooses, and the next `publish-readiness` run can record it.

## The form

Role: Account Holder, Admin, or App Manager. Apps, the app, App Privacy, Get Started [2].

- **No items for `ios`:** "No, we do not collect data from this app", then Save [2]. A privacy policy URL is still required [2].
- **Items:** "Yes, we collect data from this app", Next. Select each data type, Save. Then for each one, answer its questions, Save [2].
- **Publish.** A dialog confirms the responses are accurate. They are published on the product page; if it is not live yet, they publish when it goes live [2]. With a version on sale, follow the next section.

## An app with a version on sale

"On sale" is the reading in `SKILL.md`, not `targets.ios.status`. Apple's rule decides this section: if the app is currently available, your responses reflect the data collected only from that app version [2]. Publish changes the product page itself [2]. So while another version is on sale, this build's changes are not published, whether they add or remove a data type: a removal now would drop a disclosure the version on sale still needs, and an addition now would declare data it does not collect. No page read gives an exception.

1. Ask what the form shows now. Name the version on sale and its build from the reading.
2. Compare with this build's `data_inventory` items for `ios`, and list each data type added, removed, or answered differently. With no difference, nothing is published.
3. With a difference, and this build's version not on sale: show no block. Write it in the notes right away, on one line: `Held App Privacy change for <version>: <each data type and change>`, with no build number, because the build that ships can differ. Keep one such line with no `published`: a later comparison rewrites it. Tell the creator it is held, and why. If the run moves to a new version number before that version is on sale, or Step 13 or 15 finds another build on sale at that version, that version will never carry the change: rewrite the line to the new version, and the comparison above updates it for the new build.
4. Once that version is on sale, Step 15, in its proof and in its reuse branch, reads the notes. For a held line with no `published` on it, show the block with `Release:` naming the version on sale and its build from this session's reading, and the action "publish these App Privacy responses on the live product page of version <version on sale>, build <build from that reading>: <each data type and change>". This block has no `Held App Privacy:` line.
5. Until the line has `published`, every other go-ahead block names it in `Held App Privacy:`, including the release block of that version. Anything but a yes to the publish block leaves the line as it is: the change stays unpublished, and the live page keeps its current answers and omits any added data.

Give the path only after the yes. Proof: the creator reports the Product Page Preview now shows those responses [2]. Then add `published <date>` to the held line.

A first release with no version on sale is not this section: responses publish when the product page goes live [2].

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
