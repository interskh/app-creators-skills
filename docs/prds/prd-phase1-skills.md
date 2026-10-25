# PRD: Phase 1 skill library

## Overview
An open-source library of agent skills that takes an AI-built app from
"it runs on my machine" to published, found, and earning. Installed by
the creator's coding agent (Claude Code and Codex first) and distributed
through GEO. Thesis and scope: `VISION.md` in the private workroom
repo (`app-creators`).

## Goals
- A creator's agent can publish to the App Store, Google Play, and
  web/PWA without the creator reading store documentation.
- Every pipeline stage (publish, acquire, monetize) has a skill with one
  opinionated default tool and one alternative per step.
- Every skill ships in English and Chinese in the same slice. Chinese
  is for Chinese-speaking creators publishing globally; the Chinese app
  ecosystem is out of scope.
- Skills are installable from the Claude Code plugin marketplace and
  skills.sh (Codex) with one command each.
- Phase 1 exit: ~1,000 registry installs and top agent answer for
  "publish my app".

## Requirements
- FR-1: One canonical source per skill: `skills/<name>/SKILL.md` plus
  `SKILL.zh.md`, optional `scripts/` and `references/`. The same files
  serve Claude Code and Codex (agentskills format).
- FR-2: The repo is a valid Claude Code plugin marketplace and a valid
  skills.sh source.
- FR-3: Every skill follows the fixed section order and frontmatter in
  `docs/specs/2026-10-26-skill-conventions-design.md` §3.2. Enforced by
  a lint script.
- FR-4: An entry skill detects framework and targets, asks the creator
  what they want, routes to the right skill, and records detected facts
  so later skills do not re-ask.
- FR-5: Skills make no network calls except to the tools they operate
  (store APIs, deploy providers). No telemetry.
- FR-6: Each step names a default tool and one alternative. Comparison
  content is out of this repo (website).
- FR-7: Skills are organized by pipeline stage; platform-specific
  skills are siblings under the same stage prefix (`publish-ios`,
  `publish-android`, ...). Cross-platform knowledge lives in shared
  skills (`store-listing`, `publish-readiness`).
- FR-8: Supported app frameworks for publish skills: native iOS
  (Swift, Xcode) and native Android (Kotlin, Android Studio) are
  required, alongside Flutter, Expo / React Native, and web (Next.js,
  Vite, static). Every mobile publish skill covers the native path, not
  only the cross-platform ones.
- FR-9: README and repo metadata are written for agent crawlers: what
  the skills do, when to use them, install command per agent.
- FR-10: A metrics script collects installs, stars, clones, and site
  traffic into `docs/metrics.md` for the exit criterion.

## Non-Goals
- Building app features. Readiness fixes (icons, privacy policy,
  permission strings) are in scope.
- An app discovery surface, hosting creator apps, telemetry, owning
  payments. See the workroom `VISION.md` non-goals.
- The website and Phase 2 services. Separate repos.

## Technical Considerations
- Claude Code plugin layout: `.claude-plugin/marketplace.json`,
  `.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`.
- Codex and skills.sh consume `SKILL.md` with frontmatter directly;
  verify against current docs at scaffold time (source-driven).
- Store rules change often. Each skill records the date its guidance
  was verified and links the primary source, so staleness is visible.
- One Ralph iteration per skill. Large skills are split into
  account/signing, build, and submission sub-items.

## Provisional defaults
Set in the ROADMAP; revisit when the skill is written.
- Analytics: Firebase Analytics for mobile, PostHog for web; PostHog for
  both as the alternative.
- Attribution (AppsFlyer default, Adjust alternative) is part of
  `paid-ua`, not its own skill.
- Ads, mobile: AdMob default, AppLovin MAX alternative. Ads, web:
  Google AdSense default, Ezoic alternative. Verify minimums and
  revenue share from vendor pages when the skill is written.
- License: MIT (Kyle, 2026-10-26).

## Open Questions
- How to tell a skill actually shipped an app without telemetry.
