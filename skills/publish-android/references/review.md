# Google Play review: time, rejection, appeal

Bracketed numbers point to `## Sources`. Pre-submit checks and reading a rejection in depth belong to `store-review`, which has not shipped.

## How long

- Processing before publishing "can take a few hours or up to seven days (or longer in exceptional cases), as it depends on the review time that your app is subject to". Google recommends a buffer of at least a week between submitting and going live [1].
- "For certain developer accounts, we'll take more time to thoroughly review your app", up to seven days or longer in exceptional cases [2]. Extended reviews can also apply to certain categories of apps [3].
- Sending more changes while others are in review counts the time from the last change, and can move the app to the back of the queue [1].
- A production access application usually takes seven days or less [4].
- After Publish changes, the update is live "within a few minutes" [1]; edits made through the API "can take several hours to take effect, just as when you make changes through the Play Console" [5]. Existing users receive an update over time [6].

## On a rejection

Update status Update rejected, or App rejected for a first publish. Fix the issue and resubmit, or appeal [2]. Rejected submissions link to the Policy status page with the issue and how to fix it [7]. If an update is rejected, the last approved version stays live [7][8]. A rejection does not affect the account's standing; repeated rejections can lead to suspension [8].

- **Resubmit.** A fix in App content or the listing: change it, then a new Step 15 block for Send for review [9]. A fix in code: a new build with a new version code, from Step 8. After a rejection, changes are not sent automatically [1], and the next internal testing release is reviewed too [1].
- **Removed by Google.** The published version stays unavailable until a compliant update. Google's steps: upload the compliant bundle to every track that holds the old one, and keep the non-compliant bundles under Not included, or the resubmission fails [8]. Each roll-out is a block.
- **Suspended by Google.** Needs a successful appeal [2].

## Messages to Google

Each reaches a reviewer or Google's policy team, so each is a **go-ahead** with its own block. The block's action is in the words below, and the message itself is shown in full below the block. The creator writes it; draft on request; the creator sends it. Give the route only after the yes. Proof: the creator reports it sent.

| message | action | route |
|---|---|---|
| Appeal a rejection, removal, suspension, or other enforcement | "send this appeal to Google Play about <the enforcement>" | The "File an appeal" link on Google's removal page [8]. One appeal per removal, suspension, or other enforcement action [8]. Google answers appeals in Chinese, English, Japanese, and Korean [8] |
| Appeal a content rating | "send this content rating appeal to <rating authority>" | The link in the rating certificate email, to the IARC rating authority directly [10] |
| Resubmit after a sign-in details fix | "send the updated sign-in details for review" | App content, Sign-in details, Save; then Publishing overview, Send for review [9]. No message to the policy team is needed [9] |

Misusing the appeals process can end email support [8].

## Sources

All fetched with curl and read 2026-11-03.

1. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
2. Publish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859751?hl=en
3. Manage target audience and app content settings, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9867159?hl=en
4. App testing requirements for new personal developer accounts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
5. Edits, Google Play Developer API: https://developers.google.com/android-publisher/edits
6. Update or unpublish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859350?hl=en
7. About your submission activity, Play Console Help: https://support.google.com/googleplay/android-developer/answer/17118609?hl=en
8. My app has been removed from Google Play, Play Console Help: https://support.google.com/googleplay/android-developer/answer/2477981?hl=en
9. Prepare your app for review, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859455?hl=en
10. Content rating requirements for apps, games, and the ads served on both, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859655?hl=en
