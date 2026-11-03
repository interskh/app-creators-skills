# Age rating from the readiness answers

How to fill App Store Connect's age rating form from `age_rating.answers` in `.app-creators/readiness.md`. Never interview: `publish-readiness` asked. If an id below has no answer, stop and name `publish-readiness`. Skills install separately, so this file carries its own mapping. Bracketed numbers point to `## Sources`.

An age rating is required, and an Unrated app cannot be published on the App Store [1]. Apple generates the rating from the answers [1]. Role: Account Holder, Admin, App Manager, or Marketing [1]. Path: Apps, the app, General, App Information, Age Ratings, Set Up Age Ratings; review in-app controls and capabilities, Next; then each section of the progress bar, Next [1]. To change it later: App Information, Edit [1].

Show one line per id. Frequency answers are `NONE`, `INFREQUENT`, and `FREQUENT`; yes-or-no answers are `true` and `false` [3].

| id [3] | form label [2] |
|---|---|
| `parentalControls` | Parental Controls |
| `ageAssurance` | Age Assurance |
| `unrestrictedWebAccess` | Unrestricted Web Access |
| `userGeneratedContent` | User-Generated Content |
| `socialMedia` | Social Media |
| `socialMediaAgeRestricted` | Social Media Disabled for Users Under 13 |
| `messagingAndChat` | Messaging and Chat |
| `advertising` | Advertising |
| `profanityOrCrudeHumor` | Profanity or Crude Humor |
| `horrorOrFearThemes` | Horror/Fear Themes |
| `alcoholTobaccoOrDrugUseOrReferences` | Alcohol, Tobacco, or Drug Use or References |
| `medicalOrTreatmentInformation` | Medical or Treatment Information |
| `healthOrWellnessTopics` | Health or Wellness Topics |
| `matureOrSuggestiveThemes` | Mature or Suggestive Themes |
| `sexualContentOrNudity` | Sexual Content or Nudity |
| `sexualContentGraphicAndNudity` | Graphic Sexual Content and Nudity |
| `violenceCartoonOrFantasy` | Cartoon or Fantasy Violence |
| `violenceRealistic` | Realistic Violence |
| `violenceRealisticProlongedGraphicOrSadistic` | Prolonged Graphic or Sadistic Realistic Violence |
| `gunsOrOtherWeapons` | Guns or Other Weapons |
| `gambling` | Gambling |
| `gamblingSimulated` | Simulated Gambling |
| `contests` | Contests |
| `lootBox` | Loot Boxes |

If the form shows a question with no id here, or an id here has no question, Apple has moved it: show it, and let the creator answer from the form. Ids starting `play_` are Google's: ignore them.

Made for Kids and the rating override are decisions for the creator, not answers [1]. Made for Kids cannot be changed once App Review approves the app [1].

## Sources

All fetched with curl and read 2026-11-03. The ids and answer values in [3] were read from the page's JSON data, because its HTML is empty without a browser.

1. Set an app age rating, Apple: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
2. Age ratings values and definitions, Apple: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
3. AgeRatingDeclaration.Attributes, App Store Connect API, Apple: https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclaration/attributes-data.dictionary
