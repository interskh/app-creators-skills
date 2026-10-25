## 何时使用

- 创作者想让网页应用上线，用公开的 HTTPS URL 访问：“发布”“部署”“上线”“放到网上”。
- 创作者想让应用能从浏览器安装（PWA），或者用自己的域名访问。
- `.app-creators/state.md` 里 `targets.web.intent: wanted`，且 `targets.web.status` 不是 `live`。
- 不适用：应用要发布成 iOS 或 Android 原生安装包，改用 `publish-ios` 或 `publish-android`。
- 不适用：创作者问的是应用能不能发布，并没有要现在发布，改用 `publish-readiness`。

## 你需要准备

- Vercel 账号：部署目标。个人、非商业的应用用免费的 Hobby 套餐就够；商业应用需要付费套餐。注册要 5 分钟。
- 自定义域名，以及修改它 DNS 设置的权限（可选）：只有添加域名那一步用得到。买域名要 10 分钟；修改 `A` 和 `CNAME` 记录通常比更换域名服务器生效快，后者可能要 24 到 48 小时。
- 定下应用的显示名称和短名称（manifest 里的 `name`、`short_name`）：安装后显示在图标下方。定下来要 1 分钟。

只问一次，答案记到 `.app-creators/state.md`。绝不索取、粘贴或保存 token。交互式运行用 `vercel login`，由创作者在浏览器里完成登录。CI 或其他非交互式运行，由创作者在环境变量里设置 `VERCEL_TOKEN`。备选的 Cloudflare Pages 读取 `CLOUDFLARE_API_TOKEN` 和 `CLOUDFLARE_ACCOUNT_ID`。

## 开始之前

先读 `.app-creators/state.md`。文件不存在时，先运行 `app-creators` 再回来。`schema` 的主版本号不是 `1` 时，停下来，请创作者运行 `app-creators`。

下列字段必须存在：

| 字段 | 由谁写入 |
|---|---|
| `framework.kind`（`vite`、`nextjs` 或 `static`） | `app-creators` |
| `framework.package_manager` | `app-creators` |
| `targets.web.intent` | `app-creators` |
| `app.slug` | `app-creators` |
| `accounts.vercel` | 创作者（只问一次，见上文） |
| `readiness.web` | `publish-readiness` |

`framework.kind` 是其他值时停止，本 skill 只部署网页构建。项目和 `framework.kind` 不一致时（例如标为 `vite` 的项目里有 `next.config.*` 文件），以项目为准，并告诉创作者。

就绪检查关口。`readiness.web.result: fail` 时停止本 skill，告诉创作者先修好 `publish-readiness` 报告的问题。结果是 `unknown`，或者是 `pass` 但 `revision` 不是当前 commit，本 skill 可以继续，做自己的最小检查，同时对创作者说“就绪检查结果未知，正在运行最小检查”。最小检查指生产构建成功（第 1 步）和 `scripts/check-pwa.sh` 在本地预览上通过（第 2 步）。

本 skill 里说的 `scripts/` 是本 skill 自己的 `scripts/` 目录。下面每条命令都在项目根目录运行。

## 步骤

1. 构建应用。默认：项目自带的构建脚本。备选：不需要，Cloudflare Pages 用同样的构建。
   执行：`<pm> run build`，`<pm>` 取 `framework.package_manager`。
   预期：退出码 0，并生成输出目录：
   - `vite`：`dist`。
   - `nextjs`：Vercel 用它对 Next.js 的默认设置；Cloudflare Pages 只接受静态导出（`next.config.*` 里设 `output: 'export'`），输出到 `out`。
   - `static`：不用构建；有 `public` 时 Vercel 托管 `public`，没有就托管项目根目录。
   构建失败就停下，把第一条错误给创作者看。

2. 在本地检查 PWA 能否安装。默认：`scripts/check-pwa.sh`。备选：Chrome DevTools 的 Application 面板，Manifest 标签页里的 Installability 部分。
   执行：`<pm> run preview`（Vite 在 4173 端口托管 `dist`）；`static` 和 Next.js 静态导出用 `python3 -I -m http.server 4173 --directory <output-dir>`。然后对服务器打印的地址运行 `bash scripts/check-pwa.sh --allow-http <preview-url>`。
   预期：每一行都是 `PASS`。出现 `FAIL` 时，按 `references/pwa-checklist.md` 修好 manifest、图标或 service worker，再重新构建。创作者说不需要安装支持时，继续往下，验证时跳过 PWA 那几行。检查完停掉预览服务器。

3. 安装 CLI 并登录。默认：Vercel CLI。备选：Wrangler，先 `npm i -D wrangler@latest`，再 `npx wrangler login`。
   执行：`npm i -g vercel`；`vercel project ls` 报告未登录时，再运行 `vercel login`。
   预期：`vercel project ls` 列出创作者 scope 下的项目。

4. **effective**（有副作用）关联 Vercel 项目。默认：Vercel CLI。备选：`npx wrangler pages project list`，项目不存在时才运行 `npx wrangler pages project create <app.slug>`。
   先检查：`.vercel/project.json` 存在说明目录已经关联，直接复用，跳到第 5 步。否则运行 `vercel project ls --filter <app.slug>`。
   执行：`--filter` 按子串匹配，要找名字正好是 `<app.slug>` 的项目。有这个项目就运行 `vercel link --yes --project <app.slug>`；没有就先 `vercel project create <app.slug>`，再运行同一条 `vercel link` 命令。
   预期：生成 `.vercel/project.json`，里面有 `orgId` 和 `projectId`。马上记下 `tools.deploy: vercel` 和 `targets.web.provider: vercel`。

5. **effective**（有副作用）部署到生产环境。默认：Vercel CLI。备选：`npx wrangler pages deploy <output-dir> --project-name=<app.slug> --commit-hash=<sha>`；先在 `npx wrangler pages deployment list --project-name=<app.slug>` 里查这个 commit。
   先检查：`git rev-parse HEAD` 得到 `<sha>`。`git status --porcelain -- . ':(exclude).vercel'` 有任何输出时，请创作者先 commit，让一次部署对应一个 commit（exclude 排除的是第 4 步创建的关联目录）。然后运行 `vercel list --prod --status READY -m commit=<sha>`。列出了部署就复用，跳过部署命令。
   执行：`vercel deploy --prod --meta commit=<sha>`
   预期：stdout 是这次部署的唯一 URL。新项目的第一次部署即使不加 `--prod` 也是生产部署。开了 Standard Protection 时，打开唯一 URL 可能要先登录 Vercel；生产域名仍然公开。生产域名在控制台里项目的 Overview 标签页查看。马上把 `targets.web.url` 记为这个生产域名的 HTTPS URL。在 Cloudflare Pages 上，生产域名是 `<app.slug>.pages.dev`。

6. **effective**（有副作用）添加自定义域名（创作者给了域名才做）。默认：Vercel CLI。备选：Cloudflare 控制台，依次进入 Workers & Pages、该项目、Custom domains、Set up a domain。
   先检查：`vercel domains ls`。域名已经列在本项目下时，跳过添加命令。
   执行：`vercel domains add <domain> <app.slug>`，然后 `vercel domains verify <domain> --project <app.slug>`。
   预期：verify 打印要设置的记录。根域名（`example.com`）用一条 `A` 记录。子域名（`www.example.com`）用一条 `CNAME`，指向项目专属的目标，值原样复制，包括末尾的句点。域名已被另一个 Vercel 账号使用时，先要在 `_vercel` 上加 `TXT` 记录。这些记录由创作者到 DNS 服务商那里添加。反复运行 verify，直到退出码为 0，再用 `vercel certs ls` 检查证书。记下 `targets.web.domain: <domain>`，并把 `targets.web.url` 改为 `<domain>` 的 HTTPS URL。
   在 Cloudflare Pages 上，子域名要一条指向 `<app.slug>.pages.dev` 的 `CNAME`，先在控制台设置好域名再添加；根域名必须是同一个 Cloudflare 账号下的 zone。

7. 检查线上站点。默认：`scripts/check-pwa.sh`。备选：对线上 URL 打开 Chrome DevTools 的 Application 面板，Manifest 标签页。
   执行：`bash scripts/check-pwa.sh <targets.web.url>`
   预期：每一行都是 `PASS`，退出码 0。然后做“验证”和“更新状态”两节。

服务商细节和更多命令见 `references/vercel.md`、`references/cloudflare-pages.md`。

## 验证

- 运行 `bash scripts/check-pwa.sh <targets.web.url>`（不加 `--allow-http`）。预期：退出码 0，`https`、`html`、`manifest-link`、`manifest-json`、`manifest-name`、`manifest-start-url`、`manifest-display`、`manifest-prefer-related-applications`、`icon-192x192`、`icon-512x512`、`service-worker-registration`、`service-worker-script` 各有一行 `PASS`。每条 `FAIL` 行都写明检查项和原因；修好并重新部署后，再说完成。
- 添加了自定义域名时，运行 `vercel domains verify <domain> --project <app.slug>`。预期：退出码 0。
- 请创作者用 Chrome 打开线上 URL，在页面上点一下，停留 30 秒。预期：地址栏右侧出现安装（Install）按钮，或浏览器的更多菜单里出现安装（Install）项。安装后，应用出现在设备的启动入口：macOS 上是“应用程序”文件夹，Windows 上是“开始”菜单，Android 上是主屏幕。

## 排查

| 现象 | 原因 | 解决 |
|---|---|---|
| Vercel 里域名显示 **Invalid Configuration** | DNS 服务商那里的记录缺失，或者和旧的 `A`、`AAAA`、`CNAME` 记录冲突 | 按 `vercel domains verify` 给出的值设置；删掉同一主机名下冲突的记录 |
| 子域名解析不了 | 记录名填成了完整主机名，或者 `CNAME` 的值丢了末尾的句点 | 记录名填 `www`；值原样复制，包括最后的 `.` |
| 自定义域名的证书没有签发 | 某条 `CAA` 记录不允许 Let's Encrypt | 在域名的 `CAA` 记录里加上 `0 issue "letsencrypt.org"` |
| Vercel 上的 Vite 单页应用，深层链接返回 404 | 没有重写到 `index.html` | 在 `vercel.json` 里加一条 `rewrites`，从 `/(.*)` 指向 `/index.html`，然后重新运行 `check-pwa.sh` |
| Cloudflare Pages 自定义域名报 522 错误 | 在 Pages 控制台设置域名之前就加了 `CNAME` | 先在项目的 Custom domains 里设置域名，再保留这条 `CNAME` |
| 有 512 图标，`check-pwa.sh` 却报 `FAIL icon-512x512: no icons entry ...` | 唯一的 512 图标是 `purpose: maskable` | 加一个 512x512 PNG 条目，不设 `purpose` 或设 `purpose: any` |
| 本地预览上 `check-pwa.sh` 报 `FAIL https` | 本地预览用的是 http | 只在本地预览时加 `--allow-http`，线上 URL 绝不加 |

## 更新状态

读取整个 frontmatter，只改下列字段，在 `history` 末尾追加一行，然后一次性写回整个 frontmatter。绝不写入 `readiness.*`。

- `targets.web.status`：第 7 步在线上 URL 上通过后写 `live`；部署成功但验证仍不通过时写 `ready`。
- `targets.web.url`：生产域名的 HTTPS URL；自定义域名验证通过后，改为自定义域名的 HTTPS URL。
- `targets.web.provider`：`vercel` 或 `cloudflare-pages`。
- `targets.web.domain`：自定义域名；没有就写 `""`。
- `tools.deploy`：`vercel` 或 `cloudflare-pages`。
- `accounts.vercel`：`has` 或 `missing`，只在创作者本次回答过时写。
- `history`：追加 `{ skill: publish-web, version: "0.1.0", date: <YYYY-MM-DD>, result: <live | ready | stopped> }`。`ready` 或 `stopped` 的原因写在 frontmatter 下方的备注里，不写进这一行。

## 来源

- [Vercel CLI overview](https://vercel.com/docs/cli)，核对于 2026-10-26。
- [vercel deploy](https://vercel.com/docs/cli/deploy)，核对于 2026-10-26。
- [vercel link](https://vercel.com/docs/cli/link)，核对于 2026-10-26。
- [Linking projects with Vercel CLI](https://vercel.com/docs/cli/project-linking)，核对于 2026-10-26。
- [vercel project](https://vercel.com/docs/cli/project)，核对于 2026-10-26。
- [vercel list](https://vercel.com/docs/cli/list)，核对于 2026-10-26。
- [vercel domains](https://vercel.com/docs/cli/domains)，核对于 2026-10-26。
- [vercel login](https://vercel.com/docs/cli/login)，核对于 2026-10-26。
- [Vercel CLI global options](https://vercel.com/docs/cli/global-options)，核对于 2026-10-26。
- [Deploying a project from the CLI](https://vercel.com/docs/projects/deploy-from-cli)，核对于 2026-10-26。
- [Generated URLs](https://vercel.com/docs/deployments/generated-urls)，核对于 2026-10-26。
- [Deployment Protection](https://vercel.com/docs/deployment-protection)，核对于 2026-10-26。
- [Configuring a build](https://vercel.com/docs/builds/configure-a-build)，核对于 2026-10-26。
- [Vite on Vercel](https://vercel.com/docs/frameworks/frontend/vite)，核对于 2026-10-26。
- [Next.js on Vercel](https://vercel.com/docs/frameworks/full-stack/nextjs)，核对于 2026-10-26。
- [Hobby plan](https://vercel.com/docs/plans/hobby)，核对于 2026-10-26。
- [Adding and configuring a custom domain](https://vercel.com/docs/domains/working-with-domains/add-a-domain)，核对于 2026-10-26。
- [Setting up a custom domain](https://vercel.com/docs/domains/set-up-custom-domain)，核对于 2026-10-26。
- [Troubleshooting domains](https://vercel.com/docs/domains/troubleshooting)，核对于 2026-10-26。
- [Cloudflare Pages Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/)，核对于 2026-10-26。
- [Wrangler Pages commands](https://developers.cloudflare.com/workers/wrangler/commands/pages/)，核对于 2026-10-26。
- [Install Wrangler](https://developers.cloudflare.com/workers/wrangler/install-and-update/)，核对于 2026-10-26。
- [Direct Upload with continuous integration](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/)，核对于 2026-10-26。
- [Cloudflare Pages build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/)，核对于 2026-10-26。
- [Next.js on Cloudflare Pages](https://developers.cloudflare.com/pages/framework-guides/nextjs/)，核对于 2026-10-26。
- [Cloudflare Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/)，核对于 2026-10-26。
- [Vite: deploying a static site](https://vite.dev/guide/static-deploy)，核对于 2026-10-26。
- [Next.js static exports](https://nextjs.org/docs/app/guides/static-exports)，核对于 2026-10-26。
- [web.dev: What does it take to be installable?](https://web.dev/articles/install-criteria)，核对于 2026-10-26。
- [Chrome DevTools: debug Progressive Web Apps](https://developer.chrome.com/docs/devtools/progressive-web-apps/)，核对于 2026-10-26。
- [MDN: Making PWAs installable](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable)，核对于 2026-10-26。
- [MDN: manifest icons](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest/Reference/icons)，核对于 2026-10-26。
- [MDN: ServiceWorkerContainer.register()](https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerContainer/register)，核对于 2026-10-26。
