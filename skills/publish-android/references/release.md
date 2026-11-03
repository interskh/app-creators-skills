# Review, publishing, and rollout

The Play Console paths for Steps 14 to 18, the settings that would skip a yes, and changes to an app already on Google Play. Bracketed numbers point to `## Sources`.

## The two gates Google gives

1. **Send for review.** Every change that needs review lands in "Changes not yet sent for review" on the Publishing overview page. "Items are not sent for review until you click Send for review" [1][2]. Changes can be held back with Save for later [1].
2. **Publish.** "The changes will be published automatically as soon as they're reviewed and approved by Google unless managed publishing is turned on" [1]. With it on, approved changes wait in "Changes ready to publish" until Publish changes [1].

So with managed publishing off, a yes to Send for review is also a yes to publishing on approval, with no second yes. This skill handles it the way `publish-ios` handles "Manually release this version": managed publishing on before any send for review, wherever Google allows it.

## Managed publishing

- On or off at any time, including during review [1]. Path: Publishing overview, Managed publishing status, Turn on managed publishing, Save. It then shows "Managed publishing is turned on" [1].
- **Not available on an app's first publish:** "Your app must already be available to use Managed publishing. You can't use it when publishing an app for the first time" [1]. Google recommends publishing to a closed testing track first, for a launch under managed publishing [1].
- Held back: full and staged roll-outs, store listing changes, App content changes, category, testers configuration, and pre-registration [1].
- **Not held back**, so each reaches users at once: increasing a staged rollout to 100%, release notes updates, device exclusion rules, membership of tester email lists or Google Groups, unpublishing, the in-app products page, price changes, and stopping store listing experiments [1]. The list says "include but are not limited to".
- Internal testing is not covered by managed publishing [1]: `references/tracks.md`.

| action | class | why |
|---|---|---|
| Turn managed publishing on | **effective** | It holds changes back and reaches no one |
| Turn managed publishing off | **go-ahead** | Google does not say what happens to changes waiting at Ready to publish when it is turned off. From then on, approval publishes with no further yes. The block names every row in review and ready to publish, with its version code: `SKILL.md` Step 18 |

## Send for review

Role: a permission from `references/accounts.md` Users and permissions.

1. Publishing overview, "Changes not yet sent for review". Ask the creator to read every row: item changed and description [1]. The block names every row, because Send for review sends them all, except rows Saved for later [1].
2. Pre-review checks run there. Critical issues must be fixed; others allow Proceed anyway [3]. If checks are still running and found nothing, Send for review is allowed, and Play Console submits once they finish [3].
3. After the yes: Send for review [1].

Proof: the rows move to "Changes in review", and the submission shows In review [1][4].

A change made while others are in review restarts the review clock from the last change [1]. A rejected update's later changes are not sent automatically: Send for review again [1].

**Withdraw.** Changes in review or ready to publish can be moved back to "Changes not yet sent for review" [1]. Google notes they "may still be subject to review" [1]. It reaches no one, so it is the creator's choice, with no block.

## Release the bundle to production

Default: promote the tested release, or create a production release from the uploaded bundle. Production, Create new release, Add from library, the bundle with this version code [5]. Release name, release notes in `<en-US>` tags, up to 500 characters each [5]. Next, Preview and confirm [5].

- **Staged rollout**, updates only: enter a rollout percentage on the preview [5][6]. "Rollout percentage options are unavailable for a first release" [5].
- Then Save: the release joins "Changes not yet sent for review". This reaches no one: **effective**.
- If the button reads Publish, the change needs no review, and "Clicking Publish pushes changes live immediately" [5]. Treat that click as the **go-ahead** itself, with its own block.
- A first production release publishes the app to all users in the chosen countries [5].

## Publish changes (managed publishing)

When "Changes in review" is empty and every change is under "Changes ready to publish": Publishing overview, Publish changes, confirm. The update goes live within a few minutes [1]. The block names every row under "Changes ready to publish", because the button publishes them together.

## Rollout changes

Production, Releases tab, the release, Manage rollout [6]:

| change | path | what happens |
|---|---|---|
| Increase | Update rollout, the new percentage, Confirm update [6] | More users get it. The percentage never rises by itself [6]. With managed publishing on, a new percentage below 100% is held until Publish changes, because full and staged roll-outs are held [1]; 100% is not held [1] |
| Halt | Halt rollout [6] | No more users get it; those who have it keep it [6]. A fully rolled-out release can be halted too, except internal testing and a track's first release; the previous fully rolled-out release then serves in its place [7] |
| Resume | Resume rollout, a percentage, Confirm update [6] | The same set of users as before the halt [6]. Google's pages do not say whether managed publishing holds a resume [1][6], so treat it as reaching users on the yes |

Each change is its own **go-ahead**, and a yes to one does not cover the next. Proof: the release shows the new state, and its Rollout history, a timeline of when releases were halted, resumed, or served to new user percentages [5], shows the event. A held increase has neither until Publish changes: Step 17's proof reads them.

Once a staged rollout has started, its countries cannot be removed [6].

## Changes to an app on Google Play

"On Google Play" is the reading in `SKILL.md`. Outside a release:

| change | what Google says | here |
|---|---|---|
| Store listing, store settings, category, App content, country targeting | Listed on the Publishing overview and sent with Send for review [1] | Make the edit, which reaches no one. Then the Send for review block, and the Publish changes block if managed publishing is on |
| Price | Not held back by managed publishing [1]. After a price change, "it can take a few hours for your changes to be shown on Google Play" [8] | **Go-ahead.** Action: "change the price of the live app to <price> in <countries>" |
| Free to paid | Not possible once offered free [8] | Stop: a new app with a new package name |
| Unpublish | New users can no longer find it; existing users keep it and get updates. Needs managed publishing off [9] | **Go-ahead.** Action: "unpublish the app from Google Play". Turning managed publishing off for it is its own block first |
| Tester list membership | Not held back [1] | **Go-ahead**: `references/tracks.md` |

## Sources

All fetched with curl and read 2026-11-03.

1. Control when app changes are reviewed and published, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859654?hl=en
2. Publish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859751?hl=en
3. Detect app issues early with pre-review checks, Play Console Help: https://support.google.com/googleplay/android-developer/answer/14807773?hl=en
4. About your submission activity, Play Console Help: https://support.google.com/googleplay/android-developer/answer/17118609?hl=en
5. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
6. Release app updates with staged rollouts, Play Console Help: https://support.google.com/googleplay/android-developer/answer/6346149?hl=en
7. Halting a fully rolled-out release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/16285429?hl=en
8. Set up your app's prices, Play Console Help: https://support.google.com/googleplay/android-developer/answer/6334373?hl=en
9. Update or unpublish your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859350?hl=en
