# App Creators — skills

AI builds the app. These skills help the creator publish it, get users,
and make money.

Open-source agent skills for Claude Code, Codex, and other agentic
coding tools. Install once; your agent learns how to ship to the App
Store, Google Play, and the web, then how to get users and earn from
them.

**Status:** pre-release. One skill so far, not yet verified on a real
account. See [docs/ROADMAP.md](docs/ROADMAP.md).

### Skills

| skill | stage | platform | verified |
|---|---|---|---|
| `publish-web` | publish | web | unverified |

## Install

```bash
# Claude Code
claude plugin marketplace add interskh/app-creators-skills
claude plugin install app-creators@app-creators

# Codex and other agents (skills.sh)
npx skills add interskh/app-creators-skills
```

## Contributing

- Conventions every skill follows: `docs/specs/2026-10-26-skill-conventions-design.md`
- State file schema every skill reads and writes: `docs/STATE.md`
- Requirements: `docs/prds/prd-phase1-skills.md`
- Work items: `docs/ROADMAP.md`

MIT licensed.
