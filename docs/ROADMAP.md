# App Creators — Roadmap

**Requirements:** docs/prds/prd-phase1-skills.md
**Conventions:** docs/specs/2026-10-26-skill-conventions-design.md
**Thesis:** private workroom repo (`app-creators`), not here.

Phase 1 ships in four slices. Order is a default; reorder on evidence.
Every skill has an English item and a `zh` item directly after it, so
Chinese ships with each skill rather than as a pass at the end.

## Slice 0 — Foundation

**Requirements:** docs/specs/2026-10-26-skill-conventions-design.md (spec slices A, B, C)

- [ ] `p0` **Repo scaffold** `🟢 S` — Spec slice A.1. Add `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (one entry, source `./`, both named `app-creators`), README install section for Claude Code and Codex. `claude plugin validate .` passes.
- [ ] `p0` **Skill template and new-skill script** `🟡 M` — Spec slice A.2 and §3.2. `templates/skill/` with `SKILL.md`, `SKILL.zh.md`, `references/verified-runs.md` in the fixed section order; `scripts/new-skill.sh <name>` copies and renames it. `docs/SKILL-CONVENTIONS.md` is the human-readable copy of §3.2 and §3.4.
- [ ] `p0` **Skill lint script** `🟡 M` — Spec slice A.3 and §3.4 level 1, §4.5 exit contract. `scripts/lint-skills.sh` plus GitHub Actions workflow on push and PR. Passes on the template.
- [ ] `p0` **Exemplar: publish-web** `🔴 L` — Spec slice B. **Requirements:** `docs/specs/2026-10-26-skill-conventions-design.md`
  - [ ] `p0` **publish-web SKILL.md and scripts** `🟡 M` — Default Vercel, alternative Cloudflare Pages. `scripts/check-pwa.sh`, `references/vercel.md`, `references/cloudflare-pages.md`, `references/pwa-checklist.md`. Under 300 lines. Lint passes.
  - [ ] `p0` **publish-web zh** `🟡 M` — `SKILL.zh.md` in the `zh-rewrite` register. Heading parity lint passes.
  - [ ] `p0` **Fixture, eval, level 3 run** `🟡 M` — `todo-vite/` to-do app fixture in the fixtures repo (Kyle creates the repo first), one eval case under `evals/publish-web/`, level 3 run by the doer reaches a live Vercel URL that passes `check-pwa.sh`.
  - Kyle: level 4 run of `publish-web` on a real app, recorded in `references/verified-runs.md`.
- [ ] `p0` **State schema doc** `🟢 S` — Spec slice C.1. `docs/STATE.md` publishes §4.1 as the normative `state.md` schema with per-field notes.
- [ ] `p0` **Entry skill: app-creators** `🟡 M` — Spec slice C.2 and C.3. Detection table (file → framework), two questions (outcome: publish, get users, make money; wanted destinations), write `.app-creators/state.md`, routing table (goal × target → skill). `SKILL.zh.md` included. Eval case on the fixture expects `framework.kind: vite` and next skill `publish-web`.
- [ ] `p0` **GitHub GEO pass** `🟢 S` — README rewritten for agent crawlers: one paragraph per skill (what, when, install), repo topics, `llms.txt` at repo root, list of awesome-lists to PR with the PR text drafted. Done early so indexing starts while skills are written.
- [ ] `p1` **Metrics script** `🟢 S` — `scripts/metrics.sh` pulls GitHub stars, clones, and traffic via `gh api`, and records marketplace install counts where an API exists (manual field otherwise). Appends a dated row to `docs/metrics.md`.

## Slice 1 — Publish

- [ ] `p0` **publish-readiness** `🟡 M` — Pre-flight for any target: app name and bundle id, icons and splash at every required size, privacy policy URL, permission usage strings, age rating answers, data collection inventory, crash-free smoke run. Outputs a per-platform readiness report in `.app-creators/readiness.md` with fix steps for each gap.
- [ ] `p0` **publish-readiness zh** `🟡 M` — `skills/publish-readiness/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p0` **publish-ios** `🔴 L` — Ship to the App Store from Expo, Flutter, or Xcode. **Requirements:** `docs/prds/prd-phase1-skills.md`
  - [ ] `p0` **Account and signing** `🟡 M` — Apple Developer Program enrollment (individual vs organization, D-U-N-S), App Store Connect app record, bundle id registration, certificates and provisioning via EAS (default) or Xcode automatic signing (alternative).
  - [ ] `p0` **Build and TestFlight** `🟡 M` — Produce a release build per framework (EAS Build, `flutter build ipa`, Xcode archive), upload, TestFlight internal testing, export compliance answer.
  - [ ] `p0` **Submission** `🟡 M` — Fill App Store Connect metadata from `store-listing` output, pricing and availability, App Privacy nutrition labels from the readiness inventory, submit for review, read review status.
  - [ ] `p0` **publish-ios zh** `🟡 M` — `skills/publish-ios/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p0` **publish-android** `🔴 L` — Ship to Google Play from Expo, Flutter, or Android Studio. **Requirements:** `docs/prds/prd-phase1-skills.md`
  - [ ] `p0` **Account and signing** `🟡 M` — Play Console account and identity verification, app creation, upload key and Play App Signing via EAS (default) or Gradle keystore (alternative), 20-tester closed-testing requirement for new personal accounts.
  - [ ] `p0` **Build and testing tracks** `🟡 M` — AAB build per framework, internal testing track, closed testing, promote to production. Target API level check.
  - [ ] `p0` **Submission** `🟡 M` — Store listing fields, Data safety form from the readiness inventory, content rating questionnaire, countries and pricing, rollout percentage.
  - [ ] `p0` **publish-android zh** `🟡 M` — `skills/publish-android/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **store-review** `🟡 M` — Apple and Google guideline distillation into pre-submit checks: demo account for login, 4.3 spam and minimum functionality, 5.1.1 data collection, subscription disclosure, Play deceptive behavior. How to read a rejection, respond, and appeal. Expected review times.
- [ ] `p1` **store-review zh** `🟡 M` — `skills/store-review/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **store-listing** `🟡 M` — Generate name, subtitle, description, keywords, and screenshot plan from the app code and `state.md`. Screenshot sizes per device class, preview video specs, en and zh listing copy, character limits per store.
- [ ] `p1` **store-listing zh** `🟡 M` — `skills/store-listing/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **Registry submission** `🟢 S` — Publish the marketplace, verify `/plugin install` in a clean Claude Code session and `npx skills add` for Codex, submit to skills.sh index. Record install commands in README.

## Slice 2 — Acquire and analytics

- [ ] `p1` **analytics-setup** `🟡 M` — Install analytics per framework with a default (Firebase Analytics for mobile, PostHog for web) and alternative (PostHog for both). Standard event set: install, first open, activation, key action, retention day 1/7/30. Dashboard setup steps and what each number means for a solo creator.
- [ ] `p1` **analytics-setup zh** `🟡 M` — `skills/analytics-setup/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **aso** `🟡 M` — Keyword research with free tools, title and subtitle optimization, custom product pages and store listing experiments, ratings prompt timing per platform, reply-to-reviews routine.
- [ ] `p1` **aso zh** `🟡 M` — `skills/aso/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **launch-channels** `🟡 M` — Launch playbook: Product Hunt, Reddit (subreddit rules), X, Hacker News Show HN, TikTok, 小红书 (for Chinese-speaking creators reaching global users). Per channel: what to post, when, what gets banned, template drafts generated from `state.md`.
- [ ] `p1` **launch-channels zh** `🟡 M` — `skills/launch-channels/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **paid-ua** `🔴 L` — Apple Search Ads (default for iOS), Google App Campaigns, Meta Ads: account setup, first campaign structure, budget and CPI targets by category, creative requirements, attribution setup (AppsFlyer default, Adjust alternative), kill criteria.
- [ ] `p1` **paid-ua zh** `🟡 M` — `skills/paid-ua/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **growth-loops** `🟡 M` — Referral and share mechanics, deep links (Branch default, Firebase Dynamic Links deprecated note), push notification setup and consent, email capture for web.
- [ ] `p1` **growth-loops zh** `🟡 M` — `skills/growth-loops/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.

## Slice 3 — Monetize

- [ ] `p1` **monetize-strategy** `🟡 M` — Choose paid, freemium, subscription, ads, or hybrid from app type and `state.md`. Pricing anchors by category, trial length, regional pricing, what Apple and Google take and when.
- [ ] `p1` **monetize-strategy zh** `🟡 M` — `skills/monetize-strategy/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **monetize-iap** `🔴 L` — In-app purchases and subscriptions with RevenueCat (default) or StoreKit 2 and Play Billing direct (alternative). Product setup in both consoles, paywall implementation per framework, sandbox testing, receipt validation, subscription disclosure text for review.
- [ ] `p1` **monetize-iap zh** `🟡 M` — `skills/monetize-iap/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **monetize-ads** `🔴 L` — Mobile: AdMob (default, simplest) and AppLovin MAX (alternative, mediation at scale), covering account, app-ads.txt, placement types and where they are allowed, consent (UMP, ATT), policy violations that get accounts banned, expected eCPM by region. Web: Google AdSense (default) and Ezoic (alternative), with the traffic thresholds for Mediavine and Raptive noted as the upgrade path. Research step first: verify each network's current minimums, revenue share, and PWA support from vendor pages, since third-party roundups are affiliate-driven.
- [ ] `p1` **monetize-ads zh** `🟡 M` — `skills/monetize-ads/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **monetize-web** `🟡 M` — Stripe (default) or Lemon Squeezy (alternative) checkout for web apps, subscription portal, tax handling, webhook for entitlement, pricing page.
- [ ] `p1` **monetize-web zh** `🟡 M` — `skills/monetize-web/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.
- [ ] `p1` **payouts-and-tax** `🟢 S` — Agreements, tax forms, and banking in App Store Connect, Play Console, AdMob, Stripe. Payout schedules, thresholds, common holds.
- [ ] `p1` **payouts-and-tax zh** `🟡 M` — `skills/payouts-and-tax/SKILL.zh.md`: same sections and verified date as the English skill, written as a Chinese engineer would write it, not a literal translation. Lint passes.

## Slice 4 — Ports and parity

- [ ] `p2` **Cursor and Windsurf export** `🟡 M` — `scripts/export-rules.sh` emits `.cursor/rules/*.mdc` and Windsurf rules from each `SKILL.md`. Install instructions in README. Verify one skill end to end in each editor.
- [ ] `p2` **Personal agent packaging** `🟡 M` — Package skills for OpenClaw-style personal agents (verify current format at build time). Install instructions in README.
- [ ] `p2` **Chinese parity check** `🟢 S` — Lint rule: every `SKILL.md` has a `SKILL.zh.md` with matching section headings and verified dates within 30 days. Fix gaps.
- [ ] `p2` **Community launch** `🟡 M` — Launch the skills themselves: Product Hunt listing, Show HN, X thread, Reddit posts, agent Discord posts, 即刻 and V2EX. Drafts in `docs/launch/`. Track referrals in `docs/metrics.md`.
- [ ] `p2` **Staleness sweep** `🟡 M` — Script lists skills whose verified date is older than 60 days with their primary sources. Re-verify Slice 1 store rules.

