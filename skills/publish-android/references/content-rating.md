# Content rating from the readiness answers

How to fill Play Console's content rating questionnaire from `age_rating.answers` in `.app-creators/readiness.md`. Never interview: `publish-readiness` asked. If an id below has no answer, stop and name `publish-readiness`. Skills install separately, so this file carries its own mapping. Bracketed numbers point to `## Sources`.

The questions are IARC's, and IARC shows them only inside a participating store's console [1]. So the `play_*` ids are `publish-readiness`'s own, one per topic. They prepare the creator's answers; the wording in Play Console decides, and the creator answers each question there.

## The questionnaire

Play Console, the app, App content, Content rating, Start [2]:

1. Read the information and enter an email address. It is used for correspondence with IARC [2]. The creator types it.
2. Select a category, Next [2]. From `play_category`.
3. Answer the questions. Edit changes a finished section; Save draft keeps one draft per app [2].
4. The Summary page shows calculated ratings. Submit, or Start new questionnaire to retake it [2].

Show one line per id, with the creator's answer, beside the question it prepares:

| id | topic |
|---|---|
| `play_category` | the category step |
| `play_violence` | violence |
| `play_sexual_content` | sexual content or nudity |
| `play_language` | strong language or crude humor |
| `play_gambling` | gambling, simulated or real money |
| `play_fear` | scary content |
| `play_drugs` | drug use |
| `play_user_interaction` | users can interact with each other |
| `play_shares_location` | the app shares users' location |
| `play_digital_purchases` | in-app purchases |
| `play_internet_access` | the app accesses the Internet |

`play_target_age` belongs to Target audience and content: `references/app-content.md`. Ids without `play_` are Apple's: ignore them. A question in the form with no id here: show it, and let the creator answer from the form.

## Rules Google states

- Every new app needs one, and so does any update whose change would alter the answers [2]. Unrated apps may be removed [3].
- Misrepresenting the content may lead to removal or suspension, and updates can be rejected for it [2].
- The calculated rating on the Summary page may differ from the rating users see; rating authorities may change a rating after review [2].
- On an app already on Google Play, a new questionnaire joins the Publishing overview and goes out with Send for review [4].
- An appeal of a rating goes to the rating authority, through the link in the certificate email [2]: `references/review.md`.

## Sources

All fetched with curl and read 2026-11-03.

1. Frequently asked questions, IARC: https://www.globalratings.com/faq/
2. Content rating requirements for apps, games, and the ads served on both, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859655?hl=en
3. Prepare your app for review, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859455?hl=en
4. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
