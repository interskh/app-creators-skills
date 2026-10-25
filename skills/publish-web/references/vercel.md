# Vercel CLI for publish-web

Commands the skill uses, in the order it uses them, with what each
doc says about them. Everything here comes from the Vercel docs listed
under Sources, checked 2026-10-26.

## Install and sign in

- Install: `npm i -g vercel` (or `pnpm i -g vercel`). Update by running
  the install again with `vercel@latest`.
- Interactive sign-in: `vercel login`.
- Non-interactive (CI, scripts): the CLI reads the `VERCEL_TOKEN`
  environment variable. A `--token` flag also exists, but the docs
  recommend the variable because flags show up in process lists and
  logs. Never write the token into the repo or `state.md`.
- `--non-interactive` runs a command without prompts. The CLI turns it
  on by default when it detects an agent.

## Projects and linking

- `vercel project ls` lists projects in the current scope. `--filter
  <name>` does a substring match; `--format=json` gives JSON.
- `vercel project create <name>` creates a project; the name is required.
- `vercel link` links the current directory to a project. `--yes` skips
  the questions; `--yes --project <name>` picks a project that does not
  match the directory name.
- Linking writes `.vercel/project.json` with `orgId` and `projectId`.
  Removing `.vercel` unlinks the directory.
- Project precedence: `--project` flag, then `VERCEL_PROJECT_ID`, then
  `.vercel/project.json`. CI can set `VERCEL_ORG_ID` and
  `VERCEL_PROJECT_ID` instead of linking.
- When the CLI creates a project it detects the framework and offers
  its build command and output directory. With the "Other" preset the
  output directory is `public` if it exists, else the project root.

## Deploying

- `vercel deploy` (or plain `vercel`) deploys the linked directory.
  `--prod` makes a production deployment.
- The first deployment of a new project is always production, even
  without `--prod`.
- stdout is always the deployment URL; errors go to stderr, and a
  non-zero exit code means failure.
- `--meta KEY=value` attaches metadata. `vercel list -m KEY=value`
  filters on it; the skill uses `commit=<sha>` so a rerun can find the
  deployment it already made.
- `vercel list --prod` shows only production deployments;
  `--status READY` keeps only successful ones.
- `vercel inspect <url>` shows a deployment; `--logs` prints its build
  logs and `--wait` blocks until it finishes.
- Each deployment gets a unique URL. Under Standard Protection that URL
  needs a Vercel login, while production domains stay public, so run
  `check-pwa.sh` against the production domain.

## Custom domains

- `vercel domains ls` lists the scope's domains.
- `vercel domains add <domain> <project>`. The domain guide says to
  pass the project name even from a linked directory; without it an
  apex domain is added to the team but not to a project.
- `vercel domains verify <domain> --project <project>` prints the
  records to set and exits non-zero while the domain is misconfigured.
- Apex domain: an `A` record. Subdomain: a `CNAME` to the
  project-specific target. A domain in use by another Vercel account
  needs a `TXT` record at `_vercel` on the apex.
- Copy the `CNAME` value exactly, including the trailing period. The
  record name is the prefix (`www`), not the full hostname.
- `vercel certs ls` shows whether the certificate was issued; it
  usually arrives within minutes of DNS verification.
- Nameserver changes can take 24 to 48 hours to propagate; `A` and
  `CNAME` changes are usually faster.

## Plan limits

- The Hobby plan is free and limited to personal, non-commercial use.
- Hobby allows 50 custom domains per project.

## Sources

- https://vercel.com/docs/cli (checked 2026-10-26)
- https://vercel.com/docs/cli/deploy (checked 2026-10-26)
- https://vercel.com/docs/cli/link (checked 2026-10-26)
- https://vercel.com/docs/cli/project-linking (checked 2026-10-26)
- https://vercel.com/docs/cli/project (checked 2026-10-26)
- https://vercel.com/docs/cli/list (checked 2026-10-26)
- https://vercel.com/docs/cli/inspect (checked 2026-10-26)
- https://vercel.com/docs/cli/domains (checked 2026-10-26)
- https://vercel.com/docs/cli/login (checked 2026-10-26)
- https://vercel.com/docs/cli/global-options (checked 2026-10-26)
- https://vercel.com/docs/projects/deploy-from-cli (checked 2026-10-26)
- https://vercel.com/docs/builds/configure-a-build (checked 2026-10-26)
- https://vercel.com/docs/deployments/generated-urls (checked 2026-10-26)
- https://vercel.com/docs/deployment-protection (checked 2026-10-26)
- https://vercel.com/docs/domains/working-with-domains/add-a-domain (checked 2026-10-26)
- https://vercel.com/docs/domains/set-up-custom-domain (checked 2026-10-26)
- https://vercel.com/docs/domains/troubleshooting (checked 2026-10-26)
- https://vercel.com/docs/plans/hobby (checked 2026-10-26)
