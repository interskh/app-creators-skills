# From listing.md to App Store Connect

How to read `.app-creators/listing.md`, written by `store-listing`, into the version page. Sizes and limits stay in that skill's `references/limits.md`; this file does not restate them. Bracketed numbers point to `## Sources`.

## Text fields

Read `stores.app_store.<key>`, one block per locale. Map each key per `references/localizations.md`.

| `listing.md` field | App Store Connect field | where [1][2] |
|---|---|---|
| `name` | Name | App Information, per language |
| `subtitle` | Subtitle | App Information, per language |
| `description` | Description | the version page, per language |
| `keywords` | Keywords | the version page, per language |
| `promotional_text` | Promotional Text | the version page, per language |

To enter another language: the language pop-up at the top right, then add it under Not Localized, then Save [3]. A language can be managed only while the app status is editable [3].

App Information's name can be edited until submission, and a later change needs a new version or an editable status [1]. On a new version, metadata transfers from the current one, so compare before pasting [4]. Keep what already matches.

Never show `stores.google_play` to this store.

## Screenshots

Read `screenshots` rows where `store` is `app_store`. Each has `device_class`, `path`, `size`, and an optional `locale`. `device_class` values and accepted sizes are `store-listing`'s table.

**How a file reads.** For one locale and one device class, in this order:

1. Rows with that `locale` win.
2. Otherwise rows with no `locale` apply.
3. Otherwise there are none for this pair.

So a mixed file, which `store-listing` says never to write for one device class, still has one reading. Rows with a `locale` go on that language only. Rows with no `locale` go on the primary language. A locale with neither gets no upload, and inherits if App Store Connect shows it inheriting.

**Inheritance is read, not assumed.** Apple states that a language you add defaults to the primary language's screenshots [3]. It states that for adding a language. For a language added earlier, no page read says the same. So after uploading, ask the creator to switch to each locale with the pop-up menu [5] and report what it shows. If a locale shows no screenshots where the row says it should, upload that row's set there.

**Stops.** If a required device class has no row that applies to the primary language, or an applying row has an empty `path`, stop and name `store-listing`. Required classes are in that skill's `references/limits.md`.

Upload path: the version page, Previews and Screenshots, the language pop-up, then the device class [5]. While Waiting for Review, screenshots cannot be uploaded or edited, and in Ready for Review images are not editable [6].

## Everything else the version needs

Not in `listing.md`. The creator types these directly, and nothing here stores them:

- Privacy Policy URL, in App Information. From `provided.publish-readiness.privacy_policy_url`, one per language [1].
- Support URL, which must lead to actual contact information, and Copyright, which is required [2].
- What's New, on an update [2].
- Category, Content Rights, and Primary Language [1].
- Price and tax category; availability in all or specific regions [7][8]. `monetization.model` shows the intent, and the creator sets it.
- App Review Information: contact details, and notes up to 4000 bytes. If sign-in is required, a demo account that must not expire [2]. It is not visible to customers [2]. The creator types the password directly into the form and never into this chat.

Apple's own list of what to finish before review: age rating, privacy details, and accessibility support, which is optional [9]. The Accessibility section is left to the creator.

## Sources

All fetched with curl and read 2026-11-03.

1. App information, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
2. Platform version information, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
3. Localize app information, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information
4. Create a new version, Apple: https://developer.apple.com/help/app-store-connect/update-your-app/create-a-new-version
5. Manage your App Store assets, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets
6. App and submission statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/
7. Set a price, Apple: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price
8. Manage availability for your app on the App Store, and Overview of publishing, Apple: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store and https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/overview-of-publishing-your-app-on-the-app-store/
9. Submit your apps and games today, Apple: https://developer.apple.com/app-store/submitting/
