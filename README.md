# App Creators skills

Open-source agent skills for creators who built an app with AI and now
need to publish it. They install into Claude Code, Codex, and other
coding agents that skills.sh supports.

**Status:** pre-release. Two skills so far, not yet verified on a real
account.

**Ships today:** `app-creators` detects the project and writes its state
file. `publish-web` deploys a web app to Vercel or Cloudflare Pages.

**Planned, not shipped:** publishing to the App Store and Google Play,
user acquisition, and monetization. See [docs/ROADMAP.md](docs/ROADMAP.md).

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

The Claude Code commands install both skills for your user. Run the
`npx skills` commands from your project root; by default they write to
the project, under `.agents/skills/` for Codex. In a terminal, the `npx skills` CLI
shows a picker. Select both skills, because `publish-web` reads the state
file that `app-creators` writes. When the CLI detects a coding agent, it
installs both without asking.

## Skills

| skill | stage | platform | verified |
|---|---|---|---|
| `app-creators` | core | all | unverified |
| `publish-web` | publish | web | unverified |

### app-creators

[`app-creators`](skills/app-creators/SKILL.md) is the first skill to run.
It detects the framework and which destinations the project already has
config for, asks the creator what they want now and where the app should
go, writes `.app-creators/state.md`, and names the next skill. Today that
next skill is `publish-web`; for anything else it says the skill has not
shipped. Use it when the creator says start, where do I begin, set up app
creators, what's next, or ship my app (开始, 从哪开始, 下一步, 发布我的应用),
or when another App Creators skill reports that `state.md` is missing or
on a different schema major. Install it with
`npx skills add interskh/app-creators-skills` or the Claude Code commands
above. Chinese version: [`SKILL.zh.md`](skills/app-creators/SKILL.zh.md).

### publish-web

[`publish-web`](skills/publish-web/SKILL.md) deploys a Next.js, Vite, or
static web app to Vercel, or to Cloudflare Pages as the alternative. It
adds a custom domain if the creator has one and checks PWA installability
before and after the deploy. The default path needs a Vercel account,
whose free Hobby plan covers only personal, non-commercial apps. Use it
when the creator says publish, deploy, go live, put it online, PWA, or custom
domain (发布网站, 部署, 上线, 网页版). It does not ship native iOS or Android
apps. Install it with `npx skills add interskh/app-creators-skills` or
the Claude Code commands above; it needs `app-creators` installed too.
Chinese version: [`SKILL.zh.md`](skills/publish-web/SKILL.zh.md).

An index of these files for coding agents is at [llms.txt](llms.txt).

## Contributing

- Conventions every skill follows: `docs/specs/2026-10-26-skill-conventions-design.md`
- State file schema every skill reads and writes: `docs/STATE.md`
- Requirements: `docs/prds/prd-phase1-skills.md`
- Work items: `docs/ROADMAP.md`

MIT licensed.
