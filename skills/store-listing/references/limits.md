# Store listing limits

`scripts/check-listing.py` reads the table below and enforces it. Change a limit here, with its source and check date; the script holds no store value of its own.

| store | kind | id | rule | required | source | checked |
|---|---|---|---|---|---|---|
| app_store | field | name | 30 chars | yes | [Apple: App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) | 2026-11-03 |
| app_store | field | subtitle | 30 chars | no | [Apple: App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information) | 2026-11-03 |
| app_store | field | description | 4000 chars | yes | [Apple: Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) | 2026-11-03 |
| app_store | field | keywords | 100 bytes | yes | [Apple: Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) | 2026-11-03 |
| app_store | field | promotional_text | 170 chars | unverified | [Apple: Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) | 2026-11-03 |
| google_play | field | title | 30 chars | unverified | [Google: Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en) | 2026-11-03 |
| google_play | field | short_description | 80 chars | yes | [Google: Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en) | 2026-11-03 |
| google_play | field | full_description | 4000 chars | unverified | [Google: Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en) | 2026-11-03 |
| app_store | image | iphone_duo_outer | exact 1398x2034 2034x1398 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_duo_inner | exact 2007x2853 2853x2007 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_dynamic_island_large | exact 1260x2736 2736x1260 1290x2796 2796x1290 1320x2868 2868x1320 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_face_id_large | exact 1284x2778 2778x1284 1242x2688 2688x1242 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_dynamic_island_medium | exact 1179x2556 2556x1179 1206x2622 2622x1206 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_face_id_medium | exact 1170x2532 2532x1170 1125x2436 2436x1125 1080x2340 2340x1080 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_home_button_large | exact 1242x2208 2208x1242 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_home_button_medium | exact 750x1334 1334x750 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_home_button_4in | exact 640x1096 640x1136 1136x600 1136x640 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | iphone_home_button_3_5in | exact 640x920 640x960 960x600 960x640 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | ipad_13in | exact 2064x2752 2752x2064 2048x2732 2732x2048 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | ipad_12_9in | exact 2048x2732 2732x2048 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | ipad_11in | exact 1488x2266 2266x1488 1668x2420 2420x1668 1668x2388 2388x1668 1640x2360 2360x1640 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | ipad_10_5in | exact 1668x2224 2224x1668 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | ipad_9_7in | exact 1536x2008 1536x2048 2048x1496 2048x1536 768x1004 768x1024 1024x748 1024x768 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | mac | exact 1280x800 1440x900 2560x1600 2880x1800 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | apple_tv | exact 1920x1080 3840x2160 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | apple_vision_pro | exact 3840x2160 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| app_store | image | apple_watch | exact 422x514 410x502 416x496 396x484 368x448 312x390 no-alpha | | [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) | 2026-11-03 |
| google_play | image | phone | range 320-3840 ratio 2 no-alpha | | [Google: Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) | 2026-11-03 |
| google_play | image | feature_graphic | exact 1024x500 no-alpha | | [Google: Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) | 2026-11-03 |
| google_play | image | tv_banner | exact 1280x720 no-alpha | | [Google: Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) | 2026-11-03 |
| google_play | image | automotive | exact 800x1280 1024x768 no-alpha | | [Google: Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) | 2026-11-03 |

`required: unverified` means the source states the limit but not whether the field is required. The script enforces the limit and reports an empty field as `UNKNOWN`. `checked: unverified` makes the whole row `UNKNOWN`.

On a `no-alpha` row, PNG colour type 4 or 6 fails. Any other PNG is `UNKNOWN` when its first 1 MiB holds the bytes `tRNS` or lacks the bytes `IDAT`, because the script does not walk chunks; export without alpha.

## Not checked by the script

All lines checked 2026-11-03.

- Apple required device classes: the page's list names `iphone_dynamic_island_medium` for iPhone and `ipad_13in` if the app supports iPadOS. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Apple's iPhone sections differ from that list: `iphone_face_id_large` says it is required if the app runs on iPhone and `iphone_dynamic_island_large` screenshots are not provided. Provide `iphone_dynamic_island_medium` and read the page in App Store Connect before submission. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Apple states `mac`, `apple_tv`, `apple_vision_pro`, and `apple_watch` are required for apps on those platforms. `iphone_duo_outer` and `iphone_duo_inner` become required in April 2027 for apps using the iOS 27.1 SDK or later. Use one Apple Watch size across all localizations. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Apple scales the highest required resolution down when the interface is the same across sizes and localizations. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Apple screenshot count: at least 1, up to 10 per device size. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Apple screenshot formats: `.jpeg`, `.jpg`, `.png`. [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- Apple app name minimum: 2 characters. [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information).
- Apple keywords: each keyword is longer than 2 characters; do not repeat the app or company name; do not use names of other apps or companies. [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).
- Apple description is plain text with line breaks; HTML is not supported. [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).
- Apple app previews are optional: up to 3 per supported device size and language, 15 to 30 seconds, up to 500MB, H.264 (`.mov`, `.m4v`, `.mp4`) or ProRes 422 HQ (`.mov`), with their own accepted resolutions. [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications).
- Google required assets: a feature graphic and at least 2 screenshots across device types. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google screenshot count: up to 8 per supported device type. Chromebook and tablet listings can add at least 4. Automotive listings that provide screenshots need at least 2 portrait and 2 landscape. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google recommendation eligibility: apps need at least 4 screenshots at 1080px or more, 16:9 or 9:16; games need at least 3. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google screenshot and feature graphic formats: JPEG or 24-bit PNG with no alpha. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google device classes with no table row, so the script reports `UNKNOWN`: Chromebook and tablets (1,080 to 7,680px, exactly 16:9 or 9:16), Wear OS (1:1, at least 384x384), Android XR (8:5, at least 1920x1200, up to 8 MB), Android TV (no size stated). The rule grammar cannot state an exact ratio or an open maximum. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google app icon: 32-bit PNG with alpha, 512x512, up to 1024KB. `publish-readiness` owns icons. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google preview video is not required: one YouTube URL, public or unlisted, ads off, not age restricted. [Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).
- Google CJK count: character limits apply to full-width and half-width characters alike, and the listed numbers are the maximum regardless of character type. [Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en).
- Apple CJK count: the pages read state none. The script counts Unicode code points for `chars` on both stores; this is an assumption, including for emoji and combining marks.
- Apple keywords unit conflict: the Help page says 100 bytes, and [Creating Your Product Page](https://developer.apple.com/app-store/product-page/) says 100 characters. The table uses bytes, the stricter one for CJK.

## Sources

Every source checked 2026-11-03. Fetched as rendered HTML from the vendor.

- [Apple: App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information): `name` and `subtitle` limits.
- [Apple: Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties): `name` required; `subtitle` has an empty Required cell.
- [Apple: Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information): `description`, `keywords`, `promotional_text` limits; `description` and `keywords` required. No page read says whether `promotional_text` is required.
- [Apple: Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications): every `app_store` image row, including no alpha.
- [Apple: App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications): preview video.
- [Apple: Creating Your Product Page](https://developer.apple.com/app-store/product-page/): keywords unit conflict.
- [Google: Create and set up your app](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en): `title`, `short_description`, `full_description` limits; CJK statement. No page read says whether `title` or `full_description` is required.
- [Google: Add preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en): `short_description` required; every `google_play` image row, including no alpha.
