# Play Console languages

How an `app.languages` key maps to a Play Console listing language. The key stays as it is in `state.md` and in `listing.md`; only Play Console uses Google's code. Bracketed numbers point to `## Sources`.

## The mapping

| `listing.md` key | Play Console language | rule |
|---|---|---|
| a code in the table below, such as `en-GB` or `pt-BR` | that language | exact |
| `zh` | `zh-CN`, `zh-TW`, or `zh-HK` | Google has no bare `zh` [1]. Read the copy: Simplified characters are `zh-CN`, Chinese (Simplified); Traditional characters are `zh-TW`, Chinese (Traditional), or `zh-HK`, Chinese (Hong Kong). If the text does not decide it, ask once |
| `en` | `en-US` | Google has no bare `en` [1], and en-US is the default language when you upload an app [2]. Ask only if the creator names another English |
| another bare language, such as `fr` or `es` | see the table | where Google has one code, use it, even with a region, such as `ja-JP`; where it has several, such as French or Spanish, ask once |

Play Console shows language names; show the name and the code in the worksheet. Write the mapping you used in the notes below the frontmatter, so no later run re-asks.

**Default language.** The first key in `app.languages`, mapped. The creator selects it when creating the app [2]. With no translation for a user's language, Google Play shows an automated translation or the default language [2].

## Languages Google lists [1]

| language | code | language | code | language | code |
|---|---|---|---|---|---|
| Afrikaans | `af` | Finnish | `fi-FI` | Norwegian | `no-NO` |
| Albanian | `sq` | French (Canada) | `fr-CA` | Persian | `fa`, `fa-AE`, `fa-AF`, `fa-IR` |
| Amharic | `am` | French (France) | `fr-FR` | Polish | `pl-PL` |
| Arabic | `ar` | Galician | `gl-ES` | Portuguese (Brazil) | `pt-BR` |
| Armenian | `hy-AM` | Georgian | `ka-GE` | Portuguese (Portugal) | `pt-PT` |
| Azerbaijani | `az-AZ` | German | `de-DE` | Punjabi | `pa` |
| Bangla | `bn-BD` | Greek | `el-GR` | Romanian | `ro` |
| Basque | `eu-ES` | Gujarati | `gu` | Romansh | `rm` |
| Belarusian | `be` | Hebrew | `iw-IL` | Russian | `ru-RU` |
| Bulgarian | `bg` | Hindi | `hi-IN` | Serbian | `sr` |
| Burmese | `my-MM` | Hungarian | `hu-HU` | Sinhala | `si-LK` |
| Catalan | `ca` | Icelandic | `is-IS` | Slovak | `sk` |
| Chinese (Hong Kong) | `zh-HK` | Indonesian | `id` | Slovenian | `sl` |
| Chinese (Simplified) | `zh-CN` | Italian | `it-IT` | Spanish (Latin America) | `es-419` |
| Chinese (Traditional) | `zh-TW` | Japanese | `ja-JP` | Spanish (Spain) | `es-ES` |
| Croatian | `hr` | Kannada | `kn-IN` | Spanish (United States) | `es-US` |
| Czech | `cs-CZ` | Kazakh | `kk` | Swahili | `sw` |
| Danish | `da-DK` | Khmer | `km-KH` | Swedish | `sv-SE` |
| Dutch | `nl-NL` | Korean | `ko-KR` | Tamil | `ta-IN` |
| English (Australia) | `en-AU` | Kyrgyz | `ky-KG` | Telugu | `te-IN` |
| English (Canada) | `en-CA` | Lao | `lo-LA` | Thai | `th` |
| English (United States) | `en-US` | Latvian | `lv` | Turkish | `tr-TR` |
| English (United Kingdom) | `en-GB` | Lithuanian | `lt` | Ukrainian | `uk` |
| English | `en-IN`, `en-SG`, `en-ZA` | Macedonian | `mk-MK` | Urdu | `ur` |
| Estonian | `et` | Malay (Malaysia), Malay | `ms-MY`, `ms` | Vietnamese | `vi` |
| Filipino | `fil` | Malayalam, Marathi | `ml-IN`, `mr-IN` | | |
| | | Mongolian, Nepali | `mn-MN`, `ne-NP` | | |

Hebrew's code is `iw-IL` on Google's list, not `he` [1].

## Sources

All fetched with curl and read 2026-11-03.

1. Translate and localize your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9844778?hl=en
2. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
