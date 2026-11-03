# App Creators skills

Open-source agent skills for creators who built an app with AI and now
need to publish it. They install into Claude Code, Codex, and other
coding agents that skills.sh supports.

This is a pre-release. Seven skills ship today, and none has been
verified on a real account. `app-creators` detects the project and
writes its state file. `publish-readiness` checks whether the app is
ready for the App Store, Google Play, or the web, and reports each gap
with its fix. `store-listing` writes App Store and Google Play listing
copy in English and Chinese and plans the screenshots. `publish-ios` takes
an Expo, Flutter, or Xcode app to App Store review and release. `publish-android`
takes an Expo, Flutter, or Kotlin app to Google Play review and release.
`store-review` checks an app against App Store and Google Play review rules
before submission, and reads a rejection with its fix and response route.
`publish-web` deploys a web app to Vercel or Cloudflare Pages.

User acquisition and monetization are planned and have not shipped. See
[docs/ROADMAP.md](docs/ROADMAP.md).

## Install

```bash
# Claude Code
claude plugin marketplace add interskh/app-creators-skills
claude plugin install app-creators@app-creators

# Codex
npx skills add interskh/app-creators-skills -a codex

# Other agents (skills.sh)
npx skills add interskh/app-creators-skills
```

The Claude Code commands install all seven skills for your user. Run the
`npx skills` commands from your project root; by default they write to
the project, under `.agents/skills/` for Codex.

In a terminal, the `npx skills` CLI shows a picker. Select all the skills,
because `publish-readiness`, `store-listing`, `publish-ios`,
`publish-android`, `store-review`, and `publish-web` read the state file that `app-creators` writes. When the CLI detects a coding agent, it installs
them all without asking.
With no terminal and no detected agent, it stops with "Nothing was
installed"; add `-a <agent> -y`.

The `npx skills` CLI sends its own anonymous install telemetry, which is
how skills.sh lists skills. Set `DISABLE_TELEMETRY=1` to opt out. These
skills add no telemetry of their own.

## Skills

| skill | stage | platform | verified |
|---|---|---|---|
| `app-creators` | core | all | unverified |
| `publish-readiness` | publish | all | unverified |
| `store-listing` | publish | all | unverified |
| `publish-ios` | publish | ios | unverified |
| `publish-android` | publish | android | unverified |
| `store-review` | publish | all | unverified |
| `publish-web` | publish | web | unverified |

### app-creators

[`app-creators`](skills/app-creators/SKILL.md) is the first skill to run.
It detects the framework and which destinations the project already has
config for, asks the creator what they want now and where the app should
go, writes `.app-creators/state.md`, and names the next skill. To publish,
that is `publish-readiness`, then `publish-web` for the web, or
`store-listing`, then `publish-ios` for iOS, or `store-listing`, then `publish-android` for Android,
with `store-review` before a store submission and after a rejection;
for anything else it says the skill has not shipped. Use it when the creator says start, where do I begin, set up app
creators, what's next, or ship my app (开始, 从哪开始, 下一步, 发布我的应用),
or when another App Creators skill reports that `state.md` is missing or
on a different schema major. Install it with
`npx skills add interskh/app-creators-skills` or the Claude Code commands
above. Chinese version: [`SKILL.zh.md`](skills/app-creators/SKILL.zh.md).

### publish-readiness

[`publish-readiness`](skills/publish-readiness/SKILL.md) checks whether an
app is ready for the App Store, Google Play, or the web, before anything is
submitted. It runs static checks on the name, bundle id or package, icons,
permission strings, and privacy policy URL, builds the data collection
inventory for the creator to confirm, records age rating answers, and runs a
release smoke test when the toolchain is present. It writes
`.app-creators/readiness.md` with a fix for every gap, and changes a project
file only after the creator agrees to that fix. It touches no store or
account. Use it when the creator asks is my app ready, readiness check,
pre-flight, before I submit, privacy policy, age rating, or data inventory
(发布前检查, 能发布了吗, 就绪检查, 上架前检查, 隐私政策, 年龄分级). Install it with
`npx skills add interskh/app-creators-skills` or the Claude Code commands
above; it needs `app-creators` installed too. Chinese version:
[`SKILL.zh.md`](skills/publish-readiness/SKILL.zh.md).

### store-listing

[`store-listing`](skills/store-listing/SKILL.md) writes App Store and Google
Play listing copy in English and Chinese from what the app's code shows, and
plans the screenshots each store needs. It checks every field and image against
a dated limits table with `check-listing.py`, rewrites a field that is over
rather than cutting it, and writes `.app-creators/listing.md`. The creator
reviews the copy and captures the screenshots. It touches no store or account,
and a readiness failure at the current revision stops it. Use it when the
creator asks for a store listing, app description, keywords, screenshot plan,
or character limits (商店文案, 上架文案, 应用描述, 关键词, 截图规划, 字数限制). Install it
with `npx skills add interskh/app-creators-skills` or the Claude Code commands
above; it needs `app-creators` installed too. Chinese version:
[`SKILL.zh.md`](skills/store-listing/SKILL.zh.md).

### publish-ios

[`publish-ios`](skills/publish-ios/SKILL.md) takes an Expo, Flutter, or Xcode
app to App Store review and release: Apple Developer Program, App Store Connect
app record, signing, build and upload with EAS, `flutter build ipa`, or an Xcode
archive, TestFlight, App Privacy and age rating from the readiness report, and
listing from `listing.md`. A Kotlin app has no iOS route. It stops at every
human step with one exact ask, and asks for a yes before anything reaches a
reviewer or the public. Every route needs a paid Apple Developer Program
membership. The Expo route needs an Expo account; the Flutter and Xcode routes
need a Mac with the full Xcode. Use it when the creator says publish to the
App Store, ship to iOS, TestFlight, submit for review, or App Store Connect
(发布到 App Store, 上架 iOS, 上架苹果, 提交审核, 苹果开发者账号). Install it with
`npx skills add interskh/app-creators-skills` or the Claude Code commands
above; it needs `app-creators` installed too, and it names `publish-readiness`
and `store-listing` when they are missing. Chinese version:
[`SKILL.zh.md`](skills/publish-ios/SKILL.zh.md).

### publish-android

[`publish-android`](skills/publish-android/SKILL.md) takes an Expo, Flutter, or
Kotlin app to Google Play review and release: Play Console developer account,
app record, Play App Signing with an upload key, an Android App Bundle built
with EAS, `flutter build appbundle`, or Gradle, the target API level check,
testing tracks, Data safety and content rating from the readiness report,
listing from `listing.md`, managed publishing, and staged rollout. An Xcode app
has no Android route. It stops at every human step with one exact ask, and asks
for a yes before anything reaches a reviewer, a tester, or the public. Every
route needs a Google Play developer account, and a personal account created after
November 13, 2023 must run a closed test with 12 testers for 14 days before
production. The Expo route
needs an Expo account; the Flutter and Kotlin routes build on the creator's
computer with Android Studio and upload in Play Console. Use it when the creator
says publish to Google Play, ship to Android, Play Console, internal testing,
closed testing, or submit for review (发布到 Google Play, 上架安卓, 上架谷歌商店,
提交审核, Google Play 开发者账号). Install it with
`npx skills add interskh/app-creators-skills` or the Claude Code commands
above; it needs `app-creators` installed too, and it names `publish-readiness`
and `store-listing` when they are missing. Chinese version:
[`SKILL.zh.md`](skills/publish-android/SKILL.zh.md).

### store-review

[`store-review`](skills/store-review/SKILL.md) reviews an app against the App
Store Review Guidelines or Google Play policy before submission, from what the
project files show: a demo account for a login, spam and minimum functionality,
privacy policy, purpose strings, account deletion, login services, misleading
claims, and in-app purchase and subscription disclosure. Each finding is a
`flag` that stops a submission until it is fixed, a `note` for the creator to
judge, or `clear`, each with its evidence. Given a pasted rejection, it names the
guideline or policy, what it requires, the fix, and the route: resubmit through
`publish-ios` or `publish-android`, reply, or appeal. It drafts replies and
appeals, and the creator sends each after a yes. It never asks for a demo
account; the creator types it into the store's form. It touches no store or
account and needs no shell. Use it when the creator asks will my app pass
review, pre-submit check, app rejected, or appeal (审核前检查, 会不会被拒, 被拒了,
审核被拒, 申诉). Install it with `npx skills add interskh/app-creators-skills` or
the Claude Code commands above; it needs `app-creators` installed too. Chinese
version: [`SKILL.zh.md`](skills/store-review/SKILL.zh.md).

### publish-web

[`publish-web`](skills/publish-web/SKILL.md) deploys a Next.js, Vite, or
static web app to Vercel. The alternative, Cloudflare Pages, takes a Vite
or static app, or a Next.js app only as a static export. It adds a custom
domain if the creator has one and checks PWA installability before and
after the deploy. The default path needs a Vercel account, whose free
Hobby plan covers only personal, non-commercial apps. Use it when the
creator says publish, deploy, go live, put it online, PWA, or custom
domain (发布网站, 部署, 上线, 网页版). It does not ship native iOS or Android apps.
Install it with `npx skills add interskh/app-creators-skills` or the
Claude Code commands above; it needs `app-creators` installed too. Chinese
version: [`SKILL.zh.md`](skills/publish-web/SKILL.zh.md).

An index of these files for coding agents is at [llms.txt](llms.txt).

## Verification per route

A route is one framework plus one provider or store path. Status comes from
each skill's `references/verified-runs.md`. One route's run says nothing
about another.

| skill | route | status |
|---|---|---|
| `app-creators` | all frameworks | unverified, no run recorded |
| `publish-readiness` | expo+app-store | unverified, level 3 open: smoke run needs a full Xcode; answers, fixes, and rerun not exercised |
| `publish-readiness` | expo+google-play | unverified, level 3 open: smoke run needs a JDK; answers, fixes, and rerun not exercised |
| `publish-readiness` | vite+web | unverified, level 3 open: answers, fixes, and rerun not exercised |
| `publish-readiness` | flutter+app-store | unverified, level 3 open: script ran on `todo-flutter`, resolved settings and smoke run need a full Xcode; no skill run |
| `publish-readiness` | flutter+google-play | unverified, level 3 open: script ran on `todo-flutter`, package passed on a built bundle's manifest; smoke run not run; no skill run |
| `publish-readiness` | xcode+app-store | unverified, level 3 open: script ran on `todo-swift`, resolved settings and smoke run need a full Xcode; no skill run |
| `publish-readiness` | kotlin+google-play | unverified, level 3 open: script ran on `todo-kotlin`, package passed on a built bundle's manifest; smoke run not run; no skill run |
| `publish-readiness` | expo+web | unverified, level 3 open: not run; no shipped skill publishes this route to the web |
| `publish-readiness` | flutter+web | unverified, level 3 open: not run, `todo-flutter` has no `web/` folder; no shipped skill publishes this route to the web |
| `publish-readiness` | nextjs+web | unverified, level 3 open: no fixture |
| `publish-readiness` | static+web | unverified, level 3 open: no fixture |
| `store-listing` | expo+app-store | unverified, level 3 open: no screenshots captured, no full Xcode; answers and rerun not exercised |
| `store-listing` | expo+google-play | unverified, level 3 open: no screenshots captured, no JDK; answers and rerun not exercised |
| `store-listing` | flutter+app-store | unverified, level 3 open: script ran on a seed listing, no screenshots captured, no full Xcode; no skill run |
| `store-listing` | flutter+google-play | unverified, level 3 open: script ran on a seed listing, no screenshots captured; no skill run |
| `store-listing` | xcode+app-store | unverified, level 3 open: script ran on a seed listing, no screenshots captured, no full Xcode; no skill run |
| `store-listing` | kotlin+google-play | unverified, level 3 open: script ran on a seed listing, no screenshots captured; no skill run |
| `publish-ios` | expo+app-store | unverified, level 3 open: stops at Step 1, no Apple or Expo fixture account |
| `publish-ios` | flutter+app-store | unverified, level 3 open: stops at Step 1, no Apple fixture account; Step 2's check fails too, no full Xcode |
| `publish-ios` | xcode+app-store | unverified, level 3 open: stops at Step 1, no Apple fixture account; Step 2's check fails too, no full Xcode |
| `publish-android` | expo+google-play | unverified, level 3 open: stops at Step 1, no Google Play or Expo fixture account; Step 2's check fails too, `eas` is not installed and has no login |
| `publish-android` | flutter+google-play | unverified, level 3 open: stops at Step 1, no Google Play fixture account; Step 2's check fails too, `flutter doctor` reports Android license status unknown; the later local steps ran through a signed bundle and its target API read, with a throwaway key |
| `publish-android` | kotlin+google-play | unverified, level 3 open: stops at Step 1, no Google Play fixture account; the local steps ran through a signed bundle and its target API read, with a throwaway key |
| `store-review` | expo+app-store | unverified, level 3 open: pre-submit review and rejection reading need no account and run in evals on a seeded sign-in; the store-side "saved" reading and sending a reply need an account |
| `store-review` | expo+google-play | unverified, level 3 open: rejection reading needs no account and runs in an eval on a seeded sign-in; the store-side "saved" reading and the send for review need an account |
| `store-review` | other routes | unverified, no run recorded |
| `publish-web` | vite+vercel | unverified, no run recorded |
| `publish-web` | nextjs+vercel | unverified, no run recorded |
| `publish-web` | static+vercel | unverified, no run recorded |
| `publish-web` | vite+cloudflare-pages | unverified, no run recorded |
| `publish-web` | nextjs+cloudflare-pages | unverified, no run recorded |
| `publish-web` | static+cloudflare-pages | unverified, no run recorded |

## Contributing

- Conventions every skill follows: `docs/specs/2026-10-26-skill-conventions-design.md`
- State file schema every skill reads and writes: `docs/STATE.md`
- Requirements: `docs/prds/prd-phase1-skills.md`
- Work items: `docs/ROADMAP.md`

MIT licensed.
