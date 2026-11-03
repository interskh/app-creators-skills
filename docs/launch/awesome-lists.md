# Awesome-list submissions

Checked on 2026-11-02 against each list's own README or CONTRIBUTING.
Nothing has been submitted. Recheck the rules before submitting, because
they change.

This repo on that date: first commit 2026-10-25, repo created 2026-10-26,
0 stars, MIT, pre-release, two skills, neither verified on a real account.
We have no measurement of what a listing does for discovery, so treat each
submission as a cheap bet.

`publish-readiness`, `store-listing`, and `publish-ios` landed after that check. The drafts
below name five skills, which holds only once `main` is pushed; rerun the
install commands then, because the dated `Public Evidence` line covers the two
skills public on 2026-11-02.

The order is what can be filed today first, then by fit and reach. Open one
submission at a time and read the target list first.

| # | list | stars | last push | meets its rules today |
|---|---|---|---|---|
| 1 | BehiSecc/awesome-claude-skills | 10,334 | 2026-11-02 | yes, no stated bar |
| 2 | acvnace/awesome-vibe-coding-resources | 330 | 2026-11-02 | yes, no stated bar |
| 3 | roboco-io/awesome-vibecoding | 215 | 2026-11-01 | probably; expect a manual review |
| 4 | hesreallyhim/awesome-claude-code | 57,091 | 2026-11-02 | no; earliest 2026-11-08 18:34 UTC |
| 5 | VoltAgent/awesome-agent-skills | 36,758 | 2026-11-02 | no; needs real usage |
| 6 | heilcheng/awesome-agent-skills | 6,334 | 2026-11-02 | no; needs 20 stars and 14 days |
| 7 | hashgraph-online/awesome-codex-plugins | 1,486 | 2026-11-02 | no; needs a Codex plugin manifest |

## 1. BehiSecc/awesome-claude-skills

https://github.com/BehiSecc/awesome-claude-skills

Route: fork, change, open a pull request. Its README lists only those
steps and no eligibility rule. The most recent merged PR found closed on
2026-11-01.

Meets the rules today: yes. Add to `🛠 Development & Code Tools`.

PR title: `Add app-creators-skills`

```markdown
- [app-creators-skills](https://github.com/interskh/app-creators-skills) - Pre-release Claude Code plugin with five skills: write a project state file, check publish readiness, write App Store and Google Play listing copy, take an Expo app to App Store review and release, and deploy a Next.js, Vite, or static app to Vercel, or a Vite, static, or Next.js static-export app to Cloudflare Pages. Not yet verified on a real account.
```

PR body:

```markdown
Adds app-creators-skills to Development & Code Tools. I maintain it.

It is pre-release: five skills ship, and none has been verified on a real account. MIT.
```

## 2. acvnace/awesome-vibe-coding-resources

https://github.com/acvnace/awesome-vibe-coding-resources

Route: pull request. The repo has no CONTRIBUTING file, and its table of
contents links a Contribute section that the README does not contain. The
six most recently closed PRs were all merged, each titled
`Add <name> to <section>`, so this is observed practice and not a written
rule.

Meets the rules today: no rule is stated. Add to `Plugins and Extensions`.

PR title: `Add App Creators skills to Plugins and Extensions`

```markdown
- [App Creators skills](https://github.com/interskh/app-creators-skills) - Agent skills that install into Claude Code and Codex, write a project state file, and deploy a Next.js, Vite, or static app to Vercel, or a Vite, static, or Next.js static-export app to Cloudflare Pages. Pre-release, not yet verified on a real account. MIT.
```

## 3. roboco-io/awesome-vibecoding

https://github.com/roboco-io/awesome-vibecoding

Route: its `Add Resource` issue form. Its CONTRIBUTING says "Please Submit
Issues, Not PRs", because an AI pipeline edits the list. Self-submissions are
allowed with the affiliation disclosed, and "GitHub stars are neither a
minimum requirement nor sufficient evidence on their own". A submission must
pass five conditions: relevance, usable public evidence, distinct value,
transparent claims, and maintenance.

Meets the rules today: probably. The install commands ran and github.com
counts as an independent host in its policy, but a resource that is
pre-release and unverified may get the `needs-review` label.

Form fields:

```text
Category: Deployment & Execution
Resource Name: App Creators skills
URL: https://github.com/interskh/app-creators-skills
Description: Agent skills that install into Claude Code and Codex. app-creators writes a project state file; publish-readiness checks readiness for the App Store, Google Play, or the web; store-listing writes App Store and Google Play listing copy and a screenshot plan; publish-ios takes an Expo app to App Store review and release; publish-web deploys a Next.js, Vite, or static app to Vercel, or a Vite, static, or Next.js static-export app to Cloudflare Pages. Pre-release.
Public Evidence: The README lists install commands. On 2026-11-02 each one ran against the public repo and installed both skill files; no agent session has loaded the skills yet. Skill source: https://github.com/interskh/app-creators-skills/blob/main/skills/publish-web/SKILL.md
Access and License: Free, MIT. Deploying needs a Vercel account or a Cloudflare account. The Vercel Hobby plan covers personal, non-commercial apps only.
Current Availability: A new user can install it today. It is pre-release, and no skill has been verified on a real account.
Affiliation: I maintain this repo.
```

## 4. hesreallyhim/awesome-claude-code

https://github.com/hesreallyhim/awesome-claude-code

Route: the web issue form only, filed by a person. Its CONTRIBUTING says "Do
not open a PR", that submitting with the `gh` CLI is not possible, and that
recommendations "must be created by human beings". Only one resource at a
time.

Rules: at least 14 days since the first commit on the default branch with
commits after the first day, or at least 100 stars. Resources that fail "will
be closed automatically". A project that "requires any form of signup or
payment" is "a blocker for reviewing it", and the list then recommends it only
on community adoption signals.

Meets the rules today: no. The repo has 0 stars. The first commit is
2026-10-25 18:34 UTC, so the 14 days end at 18:34 UTC on 2026-11-08. Filing
earlier gets an automatic close. `publish-web` needs a Vercel or Cloudflare
account, so the signup rule may block review; `app-creators` needs no account.

The form requires ticking "I have visited this repo before with my own eyes,
and I have confirmed that this resource is sufficiently distinct from any
existing resource", so the person filing must do that first. It also requires
ticking "This resource is specific to Claude Code". The plugin is, but these
skills also install into Codex, so the person filing decides whether that box
is honest. The form's last checkbox must stay
unchecked. The list warns against relying on a listing for promotion and
promises no response.

Form fields:

```text
Display Name: App Creators skills
Category: Skills
Link: https://github.com/interskh/app-creators-skills
Author Name: interskh
Author Link: https://github.com/interskh
Description: Claude Code plugin with five skills. app-creators detects the project and writes a state file; publish-readiness checks readiness for the App Store, Google Play, or the web; store-listing writes App Store and Google Play listing copy and a screenshot plan; publish-ios takes an Expo app to App Store review and release; publish-web deploys a Next.js, Vite, or static app to Vercel, or a Vite, static, or Next.js static-export app to Cloudflare Pages. Pre-release, not yet verified on a real account.
```

## 5. VoltAgent/awesome-agent-skills

https://github.com/VoltAgent/awesome-agent-skills

Route: pull request adding one line to the matching Community Skills
subcategory. Its CONTRIBUTING requires a working public skill, documentation,
an author prefix, and a description of 10 words or fewer. It also says "Brand
new skills that were just created are not accepted".

Meets the rules today: no. The repo is 7 days old with no usage to show. The
list states no numeric bar. Wait until install counts or stars show usage. Add
to `Development and Testing`.

`publish-readiness`, `store-listing`, `publish-ios`, and `publish-web` read the state file
that `app-creators` writes, so the entry covers the repo and names all five
skills.

PR title: `Add skill: interskh/app-creators-skills`

```markdown
- **[interskh/app-creators-skills](https://github.com/interskh/app-creators-skills)** - app-creators setup, publish-readiness, store-listing, publish-ios (Expo), publish-web; pre-release
```

## 6. heilcheng/awesome-agent-skills

https://github.com/heilcheng/awesome-agent-skills

Route: pull request appending one line to an existing Community Skills
category in `README.md`. Its AGENTS.md requires a public repo with a
`SKILL.md`, "at least 20 GitHub stars", and no PR for a repo created in the
last 14 days. Below 20 stars a PR is labelled `on hold`. Issues are not
reviewed. The template asks you to disclose authorship and any AI agent that
wrote the PR. Triage runs in weekly batches, and 296 PRs
were open on the check date.

Meets the rules today: no. It needs 20 stars and a date of 2026-11-09 or later.

PR title: `Add interskh/app-creators-skills to Development and Testing`

```markdown
- [interskh/app-creators-skills](https://github.com/interskh/app-creators-skills) - Set up project state; deploy web apps to Vercel or Cloudflare Pages. Pre-release.
```

## 7. hashgraph-online/awesome-codex-plugins

https://github.com/hashgraph-online/awesome-codex-plugins

Route: pull request adding one line to `README.md`, alphabetical by name. A
generator then mirrors the plugin from the source repo. Its CONTRIBUTING
requires `.codex-plugin/plugin.json`, `SECURITY.md`, `LICENSE`, `README.md`,
SHA-pinned GitHub Actions, dependency lockfiles, and a score of at least
75/100 on its own scanner.

Meets the rules today: no. This repo has no `.codex-plugin/plugin.json` and no
`SECURITY.md`, and `.github/workflows/lint.yml` uses `actions/checkout@v4`
without a SHA. The scanner has not been run. This is the only active
Codex-specific list found that links to outside repos and still merges, and
it needs that repo work first.

```markdown
- [App Creators skills](https://github.com/interskh/app-creators-skills) - Pre-release skills that write a project state file and deploy a web app to Vercel or Cloudflare Pages.
```

## Dropped

- travisvn/awesome-claude-skills: requires 10 stars and refuses AI-assisted PRs; last merged PR found is January 2026, with 861 open.
- ComposioHQ/awesome-claude-skills: skills are copied into its tree; 1,683 PRs open and last merge found is May 2026.
- composio-community/awesome-codex-skills: 308 PRs open and no merge since 2026-07-26.
- composio-community/awesome-claude-plugins: plugins are copied into its tree; 478 PRs open and no merge since 2026-07-26.
- sickn33/agentic-awesome-skills: copies skills into its tree, and scripts like the one in `publish-web` need a separate maintainer review.
- Prat011/awesome-llm-skills: skills are copied into its tree; last push 2026-07-14.
- filipecalegario/awesome-vibe-coding: last push 2026-04-16 with 279 PRs open.
- awesome-vibe-coding/awesome-vibe-coding: 151 PRs open; the four newest closed PRs were not merged.
- ccplugins/awesome-claude-code-plugins: issues are off and no merged PR was found, so there is no working route.
- quemsah/awesome-claude-plugins: an automated index with no submission step.
- hemanth/awesome-pwa: lists PWA apps and tooling; an agent skill does not fit.
- johackim/awesome-indiehackers: lists people, blogs, and books, with no tools section; issues are off.
- bradAGI/awesome-cli-coding-agents: lists agents and harnesses, not skills.
- mezod/awesome-indie: last push 2024-06-12.

## No submission needed

skills.sh lists a repo automatically once installs report through its CLI
telemetry, according to its [FAQ](https://skills.sh/docs/faq). The repo's page
returned 404 on the check date. A Claude Code marketplace is a git repo with
`.claude-plugin/marketplace.json`, according to the
[plugin marketplace docs](https://code.claude.com/docs/en/plugin-marketplaces),
and this repo already works that way.
