---
name: publish-web
description: >
  Deploy a Next.js, Vite, or static web app to Vercel or Cloudflare Pages
  with a custom domain and PWA install support. Use when the creator says
  publish, deploy, go live, put it online, PWA, custom domain,
  发布网站, 部署, 上线, 网页版.
license: MIT
metadata:
  stage: publish
  platform: web
  version: "0.1.0"
  verified: "unverified"
  verified_version: ""
  zh: SKILL.zh.md
---

中文版：先读 SKILL.zh.md。If the creator writes in Chinese, read SKILL.zh.md and follow it instead.

## When to use

- The creator wants a web app live on a public HTTPS URL: "publish", "deploy", "go live", "put it online".
- The creator wants the app installable from the browser (PWA) or served on their own domain.
- `.app-creators/state.md` has `targets.web.intent: wanted` and `targets.web.status` is not `live`.
- Not this skill: the app ships as a native iOS or Android binary. Use `publish-ios` or `publish-android`.
- Not this skill: the creator asks whether the app is ready to publish, not to publish it. Use `publish-readiness`.

## What you must provide

- A Vercel account: the deploy target. The free Hobby plan is enough for a personal, non-commercial app; a commercial app needs a paid plan. Takes 5 minutes to sign up.
- A custom domain and access to its DNS settings (optional): only for the domain step. Buying a domain takes 10 minutes; `A` and `CNAME` changes usually propagate faster than nameserver changes, which can take 24 to 48 hours.
- A decision on the app's display name and short name (`name`, `short_name` in the manifest): shown under the installed icon. Takes 1 minute.

Ask once; record in `.app-creators/state.md`. Never ask for, paste, or store a token. Interactive runs use `vercel login`, which the creator completes in the browser. For CI or other non-interactive runs, the creator sets `VERCEL_TOKEN` in the environment. The Cloudflare Pages alternative reads `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

## Before you start

Read `.app-creators/state.md`. If the file is missing, run `app-creators` first and come back. If `schema` has a different major version than `1`, stop and ask the creator to run `app-creators`.

These fields must exist:

| field | set by |
|---|---|
| `framework.kind` (`vite`, `nextjs`, or `static`) | `app-creators` |
| `framework.package_manager` | `app-creators` |
| `targets.web.intent` | `app-creators` |
| `app.slug` | `app-creators` |
| `accounts.vercel` | the creator (ask once, see above) |
| `readiness.web` | `publish-readiness` |

If `framework.kind` is another value, stop: this skill deploys web builds only. If the project contradicts `framework.kind` (for example a `next.config.*` file in a project marked `vite`), trust the project and say so.

Readiness gate. `readiness.web.result: fail` stops the skill; tell the creator to fix what `publish-readiness` reported. `unknown`, or a `pass` whose `revision` is not the current commit, lets the skill proceed with its own minimal checks; say "readiness is unknown, running minimal checks" to the creator. The minimal checks are: the production build succeeds (step 1) and `scripts/check-pwa.sh` passes on the local preview (step 2).

`scripts/` in this skill means this skill's own `scripts/` directory. Run every command below from the project root.

## Steps

1. Build the app. Default: the project's own build script. Alternative: none needed; Cloudflare Pages uses the same build.
   Run: `<pm> run build`, where `<pm>` is `framework.package_manager`.
   Expect: exit 0 and an output directory:
   - `vite`: `dist`.
   - `nextjs`: Vercel uses its Next.js defaults; Cloudflare Pages takes only a static export (`output: 'export'` in `next.config.*`), written to `out`.
   - `static`: no build; Vercel serves `public` if it exists, else the project root.
   If the build fails, stop and show the creator the first error.

2. Check PWA installability locally. Default: `scripts/check-pwa.sh`. Alternative: Chrome DevTools, Application panel, Manifest tab, Installability section.
   Run: `<pm> run preview` (Vite serves `dist` on port 4173), or `python3 -I -m http.server 4173 --directory <output-dir>` for `static` and a Next.js export. Then `bash scripts/check-pwa.sh --allow-http <preview-url>` against the address the server prints.
   Expect: every line `PASS`. On a `FAIL`, fix the manifest, icons, or service worker with `references/pwa-checklist.md` and rebuild. If the creator says install support is not wanted, continue and skip the PWA lines in Verify. Stop the preview server afterwards.

3. Install the CLI and sign in. Default: Vercel CLI. Alternative: Wrangler, `npm i -D wrangler@latest`, then `npx wrangler login`.
   Run: `npm i -g vercel`, then `vercel login` if `vercel project ls` reports that you are not logged in.
   Expect: `vercel project ls` prints the projects in the creator's scope.

4. **effective** Link the Vercel project. Default: Vercel CLI. Alternative: `npx wrangler pages project list`, then `npx wrangler pages project create <app.slug>` only if it is absent.
   Check first: if `.vercel/project.json` exists, the directory is already linked; reuse it and skip to step 5. Otherwise run `vercel project ls --filter <app.slug>`.
   Run: `--filter` matches substrings, so look for a project named exactly `<app.slug>`. If it exists, `vercel link --yes --project <app.slug>`. If not, `vercel project create <app.slug>`, then the same `vercel link` command.
   Expect: `.vercel/project.json` with `orgId` and `projectId`. Record `tools.deploy: vercel` and `targets.web.provider: vercel` right away.

5. **effective** Deploy to production. Default: Vercel CLI. Alternative: `npx wrangler pages deploy <output-dir> --project-name=<app.slug> --commit-hash=<sha>`; check `npx wrangler pages deployment list --project-name=<app.slug>` for this commit first.
   Check first: `git rev-parse HEAD` gives `<sha>`. If `git status --porcelain -- . ':(exclude).vercel'` prints anything, ask the creator to commit, so one deployment maps to one commit (the exclude skips the link directory step 4 created). Then run `vercel list --prod --status READY -m commit=<sha>`. If it lists a deployment, reuse it and skip the deploy command.
   Run: `vercel deploy --prod --meta commit=<sha>`
   Expect: stdout is the unique deployment URL. The first deployment of a new project is production even without `--prod`. The unique URL can require a Vercel login under Standard Protection; production domains stay public. Read the production domain from the project's Overview tab in the dashboard. Record `targets.web.url` as the HTTPS URL of that production domain right away. On Cloudflare Pages the production domain is `<app.slug>.pages.dev`.

6. **effective** Add the custom domain (only if the creator gave one). Default: Vercel CLI. Alternative: Cloudflare dashboard, Workers & Pages, the project, Custom domains, Set up a domain.
   Check first: `vercel domains ls`. If the domain is listed for this project, skip the add command.
   Run: `vercel domains add <domain> <app.slug>`, then `vercel domains verify <domain> --project <app.slug>`.
   Expect: verify prints the records to set. Apex domain (`example.com`): an `A` record. Subdomain (`www.example.com`): a `CNAME` to the project-specific target, copied exactly, including the trailing period. A domain used by another Vercel account first needs the `TXT` record at `_vercel`. The creator adds these at the DNS provider. Rerun verify until it exits 0, then check the certificate with `vercel certs ls`. Record `targets.web.domain: <domain>` and set `targets.web.url` to the HTTPS URL of `<domain>`.
   On Cloudflare Pages, a subdomain needs a `CNAME` to `<app.slug>.pages.dev`, added after the domain is set up in the dashboard; an apex domain must be a zone on the same Cloudflare account.

7. Check the live site. Default: `scripts/check-pwa.sh`. Alternative: Chrome DevTools, Application panel, Manifest tab, on the live URL.
   Run: `bash scripts/check-pwa.sh <targets.web.url>`
   Expect: every line `PASS` and exit 0. Then run Verify and Update state.

Provider details and more commands: `references/vercel.md`, `references/cloudflare-pages.md`.

## Verify

- Run `bash scripts/check-pwa.sh <targets.web.url>` (no `--allow-http`). Expect: exit 0 and one `PASS` line each for `https`, `html`, `manifest-link`, `manifest-json`, `manifest-name`, `manifest-start-url`, `manifest-display`, `manifest-prefer-related-applications`, `icon-192x192`, `icon-512x512`, `service-worker-registration`, `service-worker-script`. Any `FAIL` line names the check and the reason; fix it and redeploy before you say done.
- If a custom domain was added, run `vercel domains verify <domain> --project <app.slug>`. Expect: exit 0.
- Ask the creator to open the live URL in Chrome, click the page once, and stay on it for 30 seconds. Expect: an Install button on the right of the address bar, or an Install item in the browser's overflow menu. After they install it, expect the app on the device's launch surface: the Applications folder on macOS, the Start menu on Windows, the home screen on Android.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| Vercel shows **Invalid Configuration** for the domain | DNS records at the provider are missing or conflict with old `A`, `AAAA`, or `CNAME` records | Set the values from `vercel domains verify`; remove conflicting records for the same hostname |
| Subdomain does not resolve | Record name entered as the full hostname, or the `CNAME` value lost its trailing period | Use `www` as the name; copy the value exactly, including the final `.` |
| Certificate is not issued for the custom domain | A `CAA` record does not allow Let's Encrypt | Add `0 issue "letsencrypt.org"` to the domain's `CAA` records |
| Deep links in a Vite single-page app return 404 on Vercel | No rewrite to `index.html` | Add a `rewrites` entry from `/(.*)` to `/index.html` in `vercel.json`, then rerun `check-pwa.sh` |
| Cloudflare Pages custom domain shows error 522 | The `CNAME` was added before the domain was set up in the Pages dashboard | Set up the domain under the project's Custom domains first, then keep the `CNAME` |
| `check-pwa.sh`: `FAIL icon-512x512: no icons entry ...` while a 512 icon exists | The only 512 icon has `purpose: maskable` | Add a 512x512 PNG entry with no `purpose` or `purpose: any` |
| `check-pwa.sh`: `FAIL https` on a local preview | Local previews use http | Pass `--allow-http` for the local preview only, never for the live URL |

## Update state

Read the whole frontmatter, change only these fields, append one `history` row, and write the whole frontmatter back in one write. Never write `readiness.*`.

- `targets.web.status`: `live` after step 7 passes on the live URL; `ready` if the deploy succeeded but Verify still fails.
- `targets.web.url`: the HTTPS URL of the production domain, or of the custom domain once it verifies.
- `targets.web.provider`: `vercel` or `cloudflare-pages`.
- `targets.web.domain`: the custom domain, or `""` if none.
- `tools.deploy`: `vercel` or `cloudflare-pages`.
- `accounts.vercel`: `has` or `missing`, only if the creator answered in this run.
- `history`: append `{ skill: publish-web, version: "0.1.0", date: <YYYY-MM-DD>, result: <live | ready | stopped> }`. Write the reason for `ready` or `stopped` in the notes below the frontmatter, not in the row.

## Sources

- [Vercel CLI overview](https://vercel.com/docs/cli), checked 2026-10-26.
- [vercel deploy](https://vercel.com/docs/cli/deploy), checked 2026-10-26.
- [vercel link](https://vercel.com/docs/cli/link), checked 2026-10-26.
- [Linking projects with Vercel CLI](https://vercel.com/docs/cli/project-linking), checked 2026-10-26.
- [vercel project](https://vercel.com/docs/cli/project), checked 2026-10-26.
- [vercel list](https://vercel.com/docs/cli/list), checked 2026-10-26.
- [vercel domains](https://vercel.com/docs/cli/domains), checked 2026-10-26.
- [vercel login](https://vercel.com/docs/cli/login), checked 2026-10-26.
- [Vercel CLI global options](https://vercel.com/docs/cli/global-options), checked 2026-10-26.
- [Deploying a project from the CLI](https://vercel.com/docs/projects/deploy-from-cli), checked 2026-10-26.
- [Generated URLs](https://vercel.com/docs/deployments/generated-urls), checked 2026-10-26.
- [Deployment Protection](https://vercel.com/docs/deployment-protection), checked 2026-10-26.
- [Configuring a build](https://vercel.com/docs/builds/configure-a-build), checked 2026-10-26.
- [Vite on Vercel](https://vercel.com/docs/frameworks/frontend/vite), checked 2026-10-26.
- [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs), checked 2026-10-26.
- [Hobby plan](https://vercel.com/docs/plans/hobby), checked 2026-10-26.
- [Adding and configuring a custom domain](https://vercel.com/docs/domains/working-with-domains/add-a-domain), checked 2026-10-26.
- [Setting up a custom domain](https://vercel.com/docs/domains/set-up-custom-domain), checked 2026-10-26.
- [Troubleshooting domains](https://vercel.com/docs/domains/troubleshooting), checked 2026-10-26.
- [Cloudflare Pages Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/), checked 2026-10-26.
- [Wrangler Pages commands](https://developers.cloudflare.com/workers/wrangler/commands/pages/), checked 2026-10-26.
- [Install Wrangler](https://developers.cloudflare.com/workers/wrangler/install-and-update/), checked 2026-10-26.
- [Direct Upload with continuous integration](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/), checked 2026-10-26.
- [Cloudflare Pages build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/), checked 2026-10-26.
- [Next.js on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/nextjs/), checked 2026-10-26.
- [Cloudflare Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/), checked 2026-10-26.
- [Vite: deploying a static site](https://vite.dev/guide/static-deploy), checked 2026-10-26.
- [Next.js static exports](https://nextjs.org/docs/app/guides/static-exports), checked 2026-10-26.
- [web.dev: What does it take to be installable?](https://web.dev/articles/install-criteria), checked 2026-10-26.
- [Chrome DevTools: debug Progressive Web Apps](https://developer.chrome.com/docs/devtools/progressive-web-apps/), checked 2026-10-26.
- [MDN: Making PWAs installable](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable), checked 2026-10-26.
- [MDN: manifest icons](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/icons), checked 2026-10-26.
- [MDN: ServiceWorkerContainer.register()](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerContainer/register), checked 2026-10-26.
