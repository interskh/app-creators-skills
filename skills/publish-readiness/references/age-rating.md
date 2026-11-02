# Age rating answers

The keys for `age_rating.answers` in `.app-creators/readiness.md`. Bracketed numbers point to `## Sources`. Ask the creator what the app contains. Never infer an answer from the code and never answer for them. A publish skill copies these answers into the store form at submission.

Applies to `ios` and `android`. Web has no age rating.

Ask in one message, in plain words, and offer the shortcut: "If none of these is in the app, say none." On "none", write each question's none value (`NONE`, `false`, or `none`) for that platform, except `play_category` and `play_target_age`: their answers are a few words and age groups, so they are always asked. On a rerun, ask only for ids with no answer.

## App Store

Apple generates the rating from these answers [1]. An unrated app cannot be published on the App Store [1]. Ids are the attribute names of `AgeRatingDeclaration` in the App Store Connect API [2], so they stay stable when labels move.

Frequency questions take `NONE`, `INFREQUENT`, or `FREQUENT`. The API also allows `INFREQUENT_OR_MILD` and `FREQUENT_OR_INTENSE` [2], but the help page's rating tables speak of infrequent and frequent [1], so do not offer them. Yes-or-no questions take `true` or `false` [2].

| id | answer | label in App Store Connect [1] | what it means [1] |
|---|---|---|---|
| `parentalControls` | yes or no | Parental Controls | tools for a parent to monitor or restrict access |
| `ageAssurance` | yes or no | Age Assurance | a way to confirm a person's age |
| `unrestrictedWebAccess` | yes or no | Unrestricted Web Access | any webpage reachable in the app, such as an embedded browser |
| `userGeneratedContent` | yes or no | User-Generated Content | users' content broadly distributed |
| `socialMedia` | yes or no | Social Media | users' content spread through a feed or similar |
| `socialMediaAgeRestricted` | yes or no | Social Media Disabled for Users Under 13 | under-13s have no access, checked at least through the Declared Age Range API |
| `messagingAndChat` | yes or no | Messaging and Chat | users communicate directly |
| `advertising` | yes or no | Advertising | paid promotion in the app |
| `profanityOrCrudeHumor` | frequency | Profanity or Crude Humor | offensive or vulgar language |
| `horrorOrFearThemes` | frequency | Horror/Fear Themes | stories that evoke anxiety, dread, or terror |
| `alcoholTobaccoOrDrugUseOrReferences` | frequency | Alcohol, Tobacco, or Drug Use or References | consumption shown or referred to |
| `medicalOrTreatmentInformation` | frequency | Medical or Treatment Information | diagnoses or guidance on conditions |
| `healthOrWellnessTopics` | yes or no | Health or Wellness Topics | self-care or lifestyle advice, such as calorie tracking |
| `matureOrSuggestiveThemes` | frequency | Mature or Suggestive Themes | implied sexual or mature topics, or real-world crime and abuse |
| `sexualContentOrNudity` | frequency | Sexual Content or Nudity | non-explicit depictions, brief or partial nudity |
| `sexualContentGraphicAndNudity` | frequency | Graphic Sexual Content and Nudity | explicit depictions; any amount makes the app Unrated, which the App Store does not publish |
| `violenceCartoonOrFantasy` | frequency | Cartoon or Fantasy Violence | exaggerated, clearly unreal harm |
| `violenceRealistic` | frequency | Realistic Violence | lifelike physical conflict |
| `violenceRealisticProlongedGraphicOrSadistic` | frequency | Prolonged Graphic or Sadistic Realistic Violence | prolonged, detailed conflict, gore |
| `gunsOrOtherWeapons` | frequency | Guns or Other Weapons | guns, swords, knives |
| `gambling` | yes or no | Gambling | wagers with real money, or currency exchangeable for it |
| `gamblingSimulated` | frequency | Simulated Gambling | wagers with neither |
| `contests` | frequency | Contests | users compete for rankings or rewards |
| `lootBox` | yes or no | Loot Boxes | paid containers of random virtual items |

Not asked, because they are overrides or regional numbers rather than statements about content: `kidsAgeBand`, `ageRatingOverride`, `ageRatingOverrideV2`, `koreaAgeRatingOverride`, `gracRatingClassificationNumber`, `developerAgeRatingInfoUrl` [2].

## Google Play

The questions are not public. IARC says developers can reach its questionnaire only through a participating storefront's portal, and that it is not available outside those storefronts [3]. Play Console asks for an email address and a category, then shows the questions [4]. So the ids below are this skill's own, one per topic that the published rating descriptions and IARC's notices cover. They prepare the creator's answers. The wording in Play Console decides at submission, and the creator reads it there.

Each app needs a completed questionnaire, and an update needs a new one when a change affects the answers [4]. Misrepresenting content may lead to removal or suspension [4]. The calculated rating on the Summary page may differ from the one users see [4].

| id | answer | topic | source |
|---|---|---|---|
| `play_category` | a few words | what the app is, for the category step | [4] |
| `play_target_age` | age groups | who it is for. An audience that includes children brings the Families policy | [4][5] |
| `play_violence` | none, mild, or a description | violence, cartoon or real | [4] |
| `play_sexual_content` | none, or a description | sexual content or nudity | [4] |
| `play_language` | none, mild, or a description | strong language or crude humor | [4] |
| `play_gambling` | none, simulated, or real money | gambling | [4] |
| `play_fear` | none, or a description | scary content | [4] |
| `play_drugs` | none, or a description | drug use | [4] |
| `play_user_interaction` | yes or no | users can interact with each other | [6] |
| `play_shares_location` | yes or no | the app shares users' location | [6] |
| `play_digital_purchases` | none, yes, or randomized | in-app purchases | [6] |
| `play_internet_access` | yes or no | the app accesses the Internet | [6] |

## Sources

Fetched with curl and read 2026-11-02 (UTC).

1. Age ratings values and definitions, App Store Connect Help: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
2. AgeRatingDeclaration.Attributes, App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi/ageratingdeclaration/attributes-data.dictionary
3. IARC frequently asked questions: https://www.globalratings.com/faq/
4. Content ratings, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859655
5. Manage target audience and app content settings, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9867159
6. How IARC works: https://www.globalratings.com/how-iarc-works
