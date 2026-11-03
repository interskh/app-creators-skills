# App Store Connect localizations

How an `app.languages` key maps to an App Store Connect locale. The key stays as it is in `state.md` and in `listing.md`; only the App Store Connect side uses the Apple locale. Bracketed numbers point to `## Sources`.

## The mapping

| `listing.md` key | App Store Connect locale | rule |
|---|---|---|
| a code in the table below, such as `zh-Hans` or `en-GB` | that locale | exact |
| `zh` | `zh-Hans` or `zh-Hant` | Apple has no bare `zh` [1]. Read the copy: Simplified characters are `zh-Hans`, Chinese (Simplified); Traditional characters are `zh-Hant`, Chinese (Traditional). If the text does not decide it, ask once |
| `en` | `en-US` | Apple has no bare `en` [1], and `en-US` is the default primary language in Expo's `language` option [3]. Ask only if the creator names another English |
| another bare language, such as `fr` or `es` | see the table | where Apple has one code for the language, use it; where it has several, such as French or Spanish, ask once |

A locale's language page has no code of its own in App Store Connect. The creator sees the language name [2]. Show both in the worksheet. Write the mapping you used in the notes below the frontmatter, so no later run re-asks.

**Primary language.** The first key in `app.languages`, mapped. The creator sets it when creating the app record, and it is the fallback when no localization fits a customer [2][4]. It can be changed later only for a language already added to an earlier version and approved [2].

Metadata languages are separate from the languages in the app binary [2].

## Locale shortcodes [1]

| language | code | language | code |
|---|---|---|---|
| Arabic | `ar-SA` | Korean | `ko` |
| Bengali | `bn-BD` | Malay | `ms` |
| Catalan | `ca` | Malayalam | `ml-IN` |
| Chinese (Simplified) | `zh-Hans` | Marathi | `mr-IN` |
| Chinese (Traditional) | `zh-Hant` | Norwegian | `no` |
| Croatian | `hr` | Oriya | `or-IN` |
| Czech | `cs` | Polish | `pl` |
| Danish | `da` | Portuguese (Brazil) | `pt-BR` |
| Dutch | `nl-NL` | Portuguese (Portugal) | `pt-PT` |
| English (Australia) | `en-AU` | Punjabi | `pa-IN` |
| English (Canada) | `en-CA` | Romanian | `ro` |
| English (U.K.) | `en-GB` | Russian | `ru` |
| English (U.S.) | `en-US` | Slovak | `sk` |
| Finnish | `fi` | Slovenian | `sl-SI` |
| French | `fr-FR` | Spanish (Mexico) | `es-MX` |
| French (Canada) | `fr-CA` | Spanish (Spain) | `es-ES` |
| German | `de-DE` | Swedish | `sv` |
| Greek | `el` | Tamil | `ta-IN` |
| Gujarati | `gu-IN` | Telugu | `te-IN` |
| Hebrew | `he` | Thai | `th` |
| Hindi | `hi` | Turkish | `tr` |
| Hungarian | `hu` | Ukrainian | `uk` |
| Indonesian | `id` | Urdu | `ur-PK` |
| Italian | `it` | Vietnamese | `vi` |
| Japanese | `ja` | | |
| Kannada | `kn-IN` | | |

Apple's help page calls two of these Bangla and Odia, and spells a third Slovenia [4]. The codes come from the API page [1].

## Sources

All fetched with curl and read 2026-11-03.

1. Managing metadata in your app by using locale shortcodes, Apple: https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes
2. Localize app information, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information
3. Configuration with eas.json, `language`, Expo: https://docs.expo.dev/eas/json/
4. App Store localizations, and App information, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/ and https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
