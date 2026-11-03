# From listing.md to the Play store listing

How to read `.app-creators/listing.md`, written by `store-listing`, into Play Console. Sizes and limits stay in that skill's `references/limits.md`; this file does not restate them. Bracketed numbers point to `## Sources`.

## Text fields

Read `stores.google_play.<key>`, one block per locale. Map each key per `references/localizations.md`.

| `listing.md` field | Play Console field [1] |
|---|---|
| `title` | App name |
| `short_description` | Short description |
| `full_description` | Full description |

Path: Grow users, Store presence, Store listings, App details [1]. Other languages: Store listing, Manage translations, Select languages, add them, Apply and Save [2]. The store listing is shared across tracks, testing tracks included [1].

Never show `stores.app_store` to this store.

## Graphics

Read `screenshots` rows where `store` is `google_play`. `device_class` values and accepted sizes are `store-listing`'s table. Google requires a feature graphic, "a minimum of two screenshots across different device types", a short description, and an app icon of 512 by 512 pixels to publish the listing [3]. `publish-readiness` owns the icon.

**How a file reads.** For one locale and one device class: rows with that `locale` win; otherwise rows with no `locale` apply, on the default language; otherwise none. Rows with a `locale` go on that language's listing.

Google: "If you add text translations without localized graphic assets, your app's graphic assets show from the default language" [2]. So a language with no rows of its own shows the default language's graphics. Upload a language's own set only where rows name it.

**Stops.** If `feature_graphic` or `phone` has no row that applies to the default language, or an applying row has an empty `path`, stop and name `store-listing`.

## Everything else the listing needs

Not in `listing.md`. The creator types these, and nothing here stores them:

- App category and tags [1].
- Contact details, on Store settings: a support email is required; phone and website are optional and shown to users [1].
- Release notes, on each release: up to 500 characters per language [4].
- Countries and regions, and price: the creator's.

On an app already on Google Play, a listing change joins "Changes not yet sent for review" [5]. Google suggests changing the listing after a staged rollout reaches 100% when an update needs a new listing [6].

## Sources

All fetched with curl and read 2026-11-03.

1. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
2. Translate and localize your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9844778?hl=en
3. Add preview assets, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en
4. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
5. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
6. Release app updates with staged rollouts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/6346149?hl=en
