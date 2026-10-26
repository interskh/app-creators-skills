## 何时使用

- 创作者想开始：“开始”“从哪开始”“设置 app creators”“发布我的应用”。
- 创作者问下一步做什么：“下一步”。
- 另一个 App Creators skill 报告 `.app-creators/state.md` 不存在，或者它的 `schema` 主版本号不同。
- 不适用：state 已经存在，创作者想现在就发布应用，改用 `publish-web`，或对应目标平台的 skill。
- 不适用：创作者问的是应用能不能发布，改用 `publish-readiness`（暂未提供）。

## 你需要准备

- 现在想要的目标：发布、获取用户，还是赚钱。它决定下一个 skill 是哪个。要 1 分钟。
- 想要的目标平台：web、iOS、Android，任选几个。后面的 skill 只处理想要的目标平台，不会再问。要 1 分钟。

请求里已经给出答案时（例如“把它发布到网页上”），直接记下，不要再问。只问缺的那部分，只问一次，放在一条消息里。

可选，不强制：应用的显示名称和一句话介绍。创作者没给时，`app.name` 和 `app.description` 留为 `""`，告诉创作者，然后继续。绝不索取 token 或任何凭据；本 skill 不记录账号。

## 开始之前

本 skill 不依赖任何字段。只有它能创建 `.app-creators/state.md`，也只有它能跨 schema 主版本号迁移这个文件。在项目根目录运行。它只需要列目录、读文件和写一个文件；识别时绝不用 shell。

先看 `.app-creators/state.md`，按情况走对应分支：

- (a) 文件不存在：创建它（第 1 到第 5 步）。
- (b) `schema` 主版本号是 `1`：读取整个 frontmatter。只重新识别识别类事实（`framework.*`、`app.slug`、`app.languages`、`targets.*.detected`），有证据就覆盖。表格结果是 `unknown`、且已存的 `framework.evidence` 是 `creator` 时，保留已存的 `framework.kind` 和 `framework.package_manager`，不要再问；表格有真正的匹配时，覆盖已存的回答，因为项目里的证据优先。创作者提供的事实、记录的结果、不认识的键、`schema` 的值和 `history` 里的每一行都原样保留。只在 `goal` 是 `""` 时问它，只在 `targets.*.intent` 是 `undecided` 时问它。`app.name` 和 `app.description` 只在创作者主动给出时才记。绝不问 `accounts.*`、`tools.*`、`monetization.model` 或 `provided.*`：需要它们的 skill 会自己问，本 skill 也不能写它们。没问过创作者，绝不覆盖提供类事实。
- (c) 主版本号更旧：迁移。把每个提供类事实、记录的结果和 `history` 行按新名字带过去，重新识别识别类事实，然后写入。目前只有主版本号 `1`，所以这个分支还没有映射，列在这里只为完整。
- (d) 主版本号比 `1` 新：停下。告诉创作者更新插件。绝不把文件降级。

## 步骤

1. 识别框架。默认：列出项目根目录，读表里列的文件。备选：只在表格结果是 `unknown`、且没有已存的 `creator` 回答时问创作者（分支 (b)）。
   执行：只列项目根目录，不递归。只会看两类子目录：`app/` 和 `gradle/`（第 4 行），以及第 2 步里 `ios/`、`android/`、`web/` 是否存在。从上往下对照表格，第一条匹配的为准。`framework.evidence` 写决定结果的那个文件。

   | # | 项目根目录里的证据 | `framework.kind` |
   |---|---|---|
   | 1 | `app.json` 或 `app.config.json` 顶层有 `expo` 键；或者 `package.json` 的 `dependencies` 里有 `expo`（用 `app.config.js` 或 `app.config.ts` 的 Expo 项目，这里也有） | `expo` |
   | 2 | `dependencies` 里有 `flutter`（`sdk: flutter`）的 `pubspec.yaml`；没有它的 `pubspec.yaml` 是普通 Dart 包：继续往下对照表格 | `flutter` |
   | 3 | `*.xcodeproj` 或 `*.xcworkspace` 目录，或者声明了 `executableTarget` 的 `Package.swift` | `xcode` |
   | 4 | 根目录或 `app/` 里的 `build.gradle` 或 `build.gradle.kts` 应用了 `com.android.application`：直接用 id，或者用版本目录别名，例如 `alias(libs.plugins.android.application)`，且它在 `gradle/libs.versions.toml` 里的条目是这个 id | `kotlin` |
   | 5 | `next.config.js`、`next.config.mjs` 或 `next.config.ts`；或者 `package.json` 的 `dependencies` 里有 `next` | `nextjs` |
   | 6 | `vite.config.js`、`vite.config.ts`、`vite.config.mjs` 或 `vite.config.mts`；或者 `package.json` 的 `dependencies` 或 `devDependencies` 里有 `vite` | `vite` |
   | 7 | `index.html`，且上面都不匹配 | `static` |
   | 8 | 上面都不匹配 | `unknown` |

   顺序有讲究：Expo 应用可能带着网页打包工具，所以第 1 行排在第 5、6 行前面；Flutter、Xcode、Kotlin 排在 JavaScript 那几行前面。Xcode 项目的枚举值是 `xcode`。结果是 `unknown` 时，问创作者应用用的是什么框架，记下回答，并设 `framework.evidence: "creator"`；重跑时，分支 (b) 会保留之前的回答，不再问。
   包管理器，第一条匹配的为准：`pnpm-lock.yaml` → `pnpm`；`yarn.lock` → `yarn`；`bun.lock` 或 `bun.lockb` → `bun`；`package-lock.json`，或者只有 `package.json` → `npm`；没有 `package.json` → `none`。
   预期：得到一个 `framework.kind`、一个 `framework.evidence`、一个 `framework.package_manager`。

2. 识别目标平台。默认：第 1 步的结果加根目录列表。备选：不需要。
   执行：下面某行匹配时，把 `targets.<destination>.detected` 设为 `"yes"`，否则设为 `"no"`。
   - `web`：`vite`、`nextjs` 或 `static`；平台列表里有 `web` 的 `expo`；有 `web/` 目录的 `flutter`。
   - `ios`：`xcode`；平台列表里有 `ios` 的 `expo`；有 `ios/` 目录的 `flutter`。
   - `android`：`kotlin`；平台列表里有 `android` 的 `expo`；有 `android/` 目录的 `flutter`。
   Expo 的平台列表：`app.json` 或 `app.config.json` 里 `expo` 下的 `platforms`。没有这一项，或者配置文件是 `app.config.js` 或 `app.config.ts` 时，用 Expo 的默认值：`ios` 和 `android`；`package.json` 的 `dependencies` 里有 `react-dom` 时再加上 `web`。
   预期：每个 `detected` 都是 `"yes"` 或 `"no"`。识别从不设置 `intent` 或 `status`。

3. 问创作者。默认：一条消息，只问请求里还没回答的问题。备选：没有；绝不把问题拆成几条消息。
   执行：问创作者现在想要哪个目标（发布、获取用户、赚钱），想要哪些目标平台（web、iOS、Android）。
   预期：目标对应 `goal`：发布 → `publish`，获取用户 → `acquire`，赚钱 → `monetize`。创作者点名的目标平台 → `intent: wanted`；明确不要的 → `not-wanted`；没提到的 → `undecided`。`app.name` 和 `app.description` 只在创作者给了时才记。

4. 写入 `.app-creators/state.md`。默认：Write 工具，一次写完整个文件。备选：没有；重跑时也绝不分几次写。
   执行：按插件里 `docs/STATE.md` 的 schema 写 frontmatter；这个文件没有和 skill 一起安装时，下面的示例已经完整，照它写就够了。然后在下面写一段备注：日期、识别出了什么、问了什么。每个字段都写上；未知写 `""` 或 `unknown`，绝不省略。首次运行时的取值：
   - 每个 `targets.*.status`：`unknown`；每个 `readiness.*`：`{ result: unknown, revision: "", date: "" }`。
   - `accounts.*`、`tools.*`、`monetization.model` 和 `provided` 下的每个叶子：`""`。不要自己写成 `missing` 或 `none`。
   - `app.slug`：取 `package.json` 的 `name`（去掉 `@scope/` 前缀）转成 kebab-case；没有就取 `pubspec.yaml` 的 `name`，再没有就取 Expo 的 `slug`，最后取目录名。
   - `app.languages`：`[en]`，除非项目显示了别的语言（例如有 `i18n` 或 `locales` 目录，就列出里面的语言）。
   - `updated`：今天。`history`：`[{ skill: app-creators, version: "0.1.0", date: <today>, result: ok }]`。

   以 Vite 待办示例应用为例：

   ```yaml
   ---
   schema: "1.0"
   updated: 2026-10-26
   app:
     name: ""
     slug: todo-vite
     description: ""
     languages: [en]
   framework:
     kind: vite
     package_manager: npm
     evidence: vite.config.ts
   targets:
     web:
       intent: wanted
       detected: "yes"
       status: unknown
       url: ""
       provider: ""
       domain: ""
     ios:
       intent: undecided
       detected: "no"
       status: unknown
       bundle_id: ""
       asc_app_id: ""
     android:
       intent: undecided
       detected: "no"
       status: unknown
       package: ""
   readiness:
     web: { result: unknown, revision: "", date: "" }
     ios: { result: unknown, revision: "", date: "" }
     android: { result: unknown, revision: "", date: "" }
   accounts:
     apple_developer: ""
     google_play: ""
     vercel: ""
   tools:
     deploy: ""
     analytics: ""
     iap: ""
     ads: ""
     payments: ""
     attribution: ""
   monetization:
     model: ""
   goal: publish
   provided:
     publish-readiness:
       privacy_policy_url: ""
       support_email_env: ""
   history:
     - { skill: app-creators, version: "0.1.0", date: 2026-10-26, result: ok }
   ---
   ```

   预期：文件已存在。告诉创作者这个文件里没有密钥，请把它 commit 进仓库。

5. 说出下一个 skill，然后停下。默认：下面的路由表。备选：没有。
   执行：按 `goal` 和每个想要的目标平台找到对应行。标着“暂未提供”的 skill 还不存在；绝不自己编一个。

   | `goal` | 目标平台 | 下一个 skill |
   |---|---|---|
   | `publish` | web | `publish-web` |
   | `publish` | iOS | `publish-ios`（暂未提供） |
   | `publish` | Android | `publish-android`（暂未提供） |
   | `publish` | 任意，发布之前 | `publish-readiness`（暂未提供）；它出来之前，各个发布 skill 自己做最小检查 |
   | `acquire` | 任意 | 先 `analytics-setup`（暂未提供），再 `launch-channels`（暂未提供）；还有 `growth-loops` 和 `paid-ua`（暂未提供） |
   | `acquire` | iOS 或 Android | 再加 `aso`（暂未提供） |
   | `monetize` | 任意 | `monetize-strategy`（暂未提供）；做广告用 `monetize-ads`（暂未提供）；然后 `payouts-and-tax`（暂未提供） |
   | `monetize` | iOS 或 Android | `monetize-iap`（暂未提供） |
   | `monetize` | web | `monetize-web`（暂未提供） |

   预期：最后一条回复写清识别出的框架和证据、记下的 `goal` 和各平台意向、文件路径 `.app-creators/state.md`，以及“下一步：运行 `publish-web`”或路由到的名字。下一个 skill 暂未提供时，照实说，并告诉创作者这段时间能做什么。绝不执行流水线里的任何一步，也绝不声称外部结果：绝不说应用已经发布、已经上架或已经上线。

## 验证

- `.app-creators/state.md` 存在。用 Read 工具重新读一遍，和你打算写的内容对照。
- frontmatter 能按 YAML 解析，并以 `schema` 开头：创建时是 `"1.0"`，重跑时是原来那个主版本号为 `1` 的值。
- `framework.kind` 是 `expo`、`flutter`、`xcode`、`kotlin`、`nextjs`、`vite`、`static`、`unknown` 之一，`framework.evidence` 指向一个存在的文件，或者是 `creator`。
- 首次运行时每个 `targets.*.status` 都是 `unknown`，每个 `targets.*.detected` 都是字符串 `"yes"` 或 `"no"`。
- `goal` 已设置。
- 你说出的下一个 skill 在本插件的 `skills/` 目录里存在，或者你标明了它暂未提供。

## 排查

| 现象 | 原因 | 解决 |
|---|---|---|
| 项目里同时有 `vite.config.*` 和 `next.config.*` | Next.js 应用用了基于 Vite 的工具，例如 Vitest | `dependencies` 里有 `next` 时，按表格顺序得到 `nextjs`；和创作者确认 |
| `app.json` 里没有 `expo` 键 | 这是 React Native CLI 应用或别的应用，不是 Expo | 不要记成 `expo`；继续往下对照表格，结果是 `unknown` 时问创作者 |
| `schema` 主版本号比 `1` 新 | 插件比 state 文件旧 | 停下；告诉创作者更新插件 |
| 创作者想要的目标平台在项目里没有配置 | 这个平台还没搭起来 | 记下 `intent: wanted` 和 `detected: "no"`；由对应平台的 skill 负责搭建 |
| 文件里已经有提供类事实 | 之前某次运行或别的 skill 记下的 | 保留它们；只在 `goal` 是 `""` 时问它，只在 `targets.*.intent` 是 `undecided` 时问它；绝不问 `accounts.*`、`tools.*`、`monetization.model` 或 `provided.*` |

## 更新状态

文件已存在时先读取整个 frontmatter，只改下列字段，在 `history` 末尾追加一行，然后一次性写回整个 frontmatter。

- 识别类事实，按本次的证据写：`framework.kind`、`framework.package_manager`、`framework.evidence`、`app.slug`、`app.languages`、`targets.*.detected`。
- 提供类事实，只按创作者本次给的回答写：`goal`、`targets.*.intent`、`app.name`、`app.description`。
- `schema`：只在创建时写 `"1.0"`。重跑时主版本号是 `1`，就原样保留已有的值：更新的次版本号（例如 `"1.1"`）不变，它加的键也保留。绝不把文件降级。`updated`：今天。
- `history`：追加 `{ skill: app-creators, version: "0.1.0", date: <YYYY-MM-DD>, result: ok }`。

创建文件时，其他字段都按第 4 步的首次运行取值写，其中 `targets.*.status` 一律是 `unknown`。绝不写 `readiness.*`、`accounts.*`、`tools.*`、`monetization` 或 `provided`：创建时保持首次运行的取值，重跑时原样保留。

## 来源

- [Expo: configure with app config](https://docs.expo.dev/workflow/configuration/)，核对于 2026-10-26。
- [Expo: app.json / app.config.js reference](https://docs.expo.dev/versions/latest/config/app/)，核对于 2026-10-26。
- [Expo: install Expo modules in an existing React Native project](https://docs.expo.dev/bare/installing-expo-modules/)，核对于 2026-10-26。
- [Flutter: the pubspec file](https://docs.flutter.dev/tools/pubspec)，核对于 2026-10-26。
- [Flutter: build a web app](https://docs.flutter.dev/platform-integration/web/building)，核对于 2026-10-26。
- [Flutter: build and release an iOS app](https://docs.flutter.dev/deployment/ios)，核对于 2026-10-26。
- [Flutter: build and release an Android app](https://docs.flutter.dev/deployment/android)，核对于 2026-10-26。
- [Xcode: managing multiple projects and their dependencies](https://developer.apple.com/documentation/xcode/managing-multiple-projects-and-their-dependencies)，核对于 2026-10-26。
- [Xcode: creating a standalone Swift package](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode)，核对于 2026-10-26。
- [Swift Package Manager: creating a Swift package](https://docs.swift.org/latest/documentation/packagemanagerdocs/creatingswiftpackage)，核对于 2026-10-26。
- [Android: configure your build](https://developer.android.com/build)，核对于 2026-10-26。
- [Android: migrate your build to version catalogs](https://developer.android.com/build/migrate-to-catalogs)，核对于 2026-10-26。
- [Next.js: next.config.js](https://nextjs.org/docs/app/api-reference/config/next-config-js)，核对于 2026-10-26。
- [Next.js: installation](https://nextjs.org/docs/app/getting-started/installation)，核对于 2026-10-26。
- [Vite: configuring Vite](https://vite.dev/config/)，核对于 2026-10-26。
- [Vite: getting started](https://vite.dev/guide/)，核对于 2026-10-26。
- [npm: package-lock.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json)，核对于 2026-10-26。
- [npm: package.json](https://docs.npmjs.com/cli/v11/configuring-npm/package-json)，核对于 2026-10-26。
- [pnpm: pnpm install](https://pnpm.io/cli/install)，核对于 2026-10-26。
- [Yarn: yarn.lock](https://classic.yarnpkg.com/lang/en/docs/yarn-lock/)，核对于 2026-10-26。
- [Bun: lockfile](https://bun.com/docs/pm/lockfile)，核对于 2026-10-26。
