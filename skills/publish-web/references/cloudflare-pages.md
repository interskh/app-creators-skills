# Cloudflare Pages for publish-web

The alternative provider. The skill uses Direct Upload with Wrangler:
build locally, then upload the output directory. Everything here comes
from the Cloudflare and Vite docs listed under Sources, checked
2026-10-26.

## Install and sign in

- Install Wrangler in the project: `npm i -D wrangler@latest`, then run
  it with `npx wrangler ...`.
- Interactive sign-in: `npx wrangler login`.
- Non-interactive (CI): the creator creates an API token with the
  Account, Cloudflare Pages, Edit permission and sets it as
  `CLOUDFLARE_API_TOKEN`, with the account ID as
  `CLOUDFLARE_ACCOUNT_ID`. Never write either value into the repo or
  `state.md`.

## Build output directory

From the Pages framework presets:

| framework | build command | output directory |
|---|---|---|
| Vite (React, Vue) | `npm run build` | `dist` |
| Next.js static HTML export | `npx next build` | `out` |
| plain static site | `exit 0` | the site folder |

Pages takes a Next.js app only as a static export. For server
rendering, Cloudflare points to Workers instead; this skill then uses
Vercel.

## Projects (effective)

- List first: `npx wrangler pages project list` (`--json` for JSON).
- Create only if absent: `npx wrangler pages project create <name>`.
  `--production-branch <branch>` sets the production branch.
- The project is served at `<name>.pages.dev`, or the name plus a few
  random characters if the name is taken. Read the real host from the
  create or deploy output.

## Deploying (effective)

- Check first: `npx wrangler pages deployment list --project-name=<name>`
  (`--environment` filters, `--json` for JSON).
- Deploy: `npx wrangler pages deploy <dir> --project-name=<name>`.
  `--commit-hash <sha>` attaches the commit SHA to the deployment. The
  docs do not show the list output; check that it carries the SHA
  before relying on it to skip a deploy.
- `--branch <branch>` picks the branch. Any branch other than the
  production branch gives a preview at `<branch>.<name>.pages.dev`, and
  in a Git workspace Wrangler takes the current branch when the flag is
  absent. So the skill always passes `--branch=<production branch>`
  (`main` when step 4 created the project with `--production-branch=main`).
- Wrangler uploads one folder, not a zip. Limits: 20,000 files and
  25 MiB per file.
- A Direct Upload project cannot switch to Git integration later; Git
  needs a new project.

## Custom domains

There is no Wrangler command for this in the docs; use the dashboard.

1. Workers & Pages, select the project, Custom domains.
2. Set up a domain, enter it, Continue.
3. Subdomain: add a `CNAME` from the subdomain to `<name>.pages.dev` at
   the DNS provider. If the zone is on Cloudflare, the record is added
   for you.
4. Apex domain: the domain must be a Cloudflare zone on the same
   account, with its nameservers pointed at Cloudflare.

Known failures:

- Adding the `CNAME` before step 2 gives error 522.
- `CAA` records that do not allow Cloudflare's certificate authorities
  block the certificate; add `CAA` records for them.
- Pointing the DNS record elsewhere and back makes the domain inactive
  until it is reactivated.

## Sources

- https://developers.cloudflare.com/pages/get-started/direct-upload/ (checked 2026-10-26)
- https://developers.cloudflare.com/workers/wrangler/commands/pages/ (checked 2026-10-26)
- https://developers.cloudflare.com/workers/wrangler/install-and-update/ (checked 2026-10-26)
- https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/ (checked 2026-10-26)
- https://developers.cloudflare.com/pages/configuration/build-configuration/ (checked 2026-10-26)
- https://developers.cloudflare.com/pages/framework-guides/nextjs/ (checked 2026-10-26)
- https://developers.cloudflare.com/pages/framework-guides/deploy-anything/ (checked 2026-10-26)
- https://developers.cloudflare.com/pages/configuration/custom-domains/ (checked 2026-10-26)
- https://vite.dev/guide/static-deploy (checked 2026-10-26)
