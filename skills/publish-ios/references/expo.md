# Expo route

The Expo route of `publish-ios`. `SKILL.md` holds the steps; this file holds the commands. Expo's docs now call the services Expo Build, Expo Submit, and Expo Metadata, and the commands still start with `eas` [1][2]. Bracketed numbers point to `## Sources`.

**Scope.** A project whose native folder is generated. If a real `ios/` folder is tracked by git, its native values win over app config [4], so `ios.config.*` edits do nothing there: read identity from the build record only, and tell the creator so.

**Install.** `npm install --global eas-cli`, or `npx eas-cli@latest` in place of `eas` [1]. `eas-cli` is not installed by this skill without saying so.

## Step 2: Expo account and login

Check: `eas whoami` shows an account [1].

Ask, and stop: "Create a free Expo account if you have none, then run `eas login` in your own terminal. Tell me when it finishes." Never type the password. Alternative for a machine with no terminal: the creator creates a personal access token and sets `EXPO_TOKEN` themselves [3][5]; record `provided.publish-ios.expo_token_env: EXPO_TOKEN`, never the value. This is not an App Store Connect key: Step 7's check does not count it. A token needs the project already linked, or commands fail with `EAS project not configured` [5].

## Step 3 warning: implicit app record

`eas submit` creates an app record on its own when the first build goes up, and `ascAppId` in the submit profile skips that [9]. That creation would have no check before it. So Step 3 comes first, and every upload here carries `ascAppId`.

## Step 4: project edits

Each of these changes a project file, so each changes the revision. Do them in one commit.

| edit | what writes it | required |
|---|---|---|
| `extra.eas.projectId` in app config | `eas init --non-interactive --account <account>` [1][5] | yes: commands fail without a link [5] |
| `eas.json` | the Write tool, this shape. `eas build:configure --platform ios` creates a default file too [1][8], but the reference lists no non-interactive flag for it [1], so it is the alternative, in the creator's terminal | yes |
| `ascAppId` in the submit profile | the same file | yes: non-interactive submit needs it [6] |
| `ios.config.usesNonExemptEncryption` in app config | the Edit tool, on the creator's answer | no; without it App Store Connect asks each time. `references/export-compliance.md` |
| `ios.bundleIdentifier` | prompted by `eas build` if absent [8]; `publish-readiness` reports it first | yes |
| `version` for a new release | the Edit tool. You set it yourself; `autoIncrement` does not bump it on the remote source [4] | yes on a new release |

```json
{
  "cli": { "appVersionSource": "remote" },
  "build": { "production": { "autoIncrement": true } },
  "submit": { "production": { "ios": { "ascAppId": "<targets.ios.asc_app_id>" } } }
}
```

Merge into an existing file; change only these keys. `credentialsSource` defaults to `remote`, and the `production` profile defaults to `"distribution": "store"`, so neither needs a line [7][9].

Why `remote`: Expo recommends it, and it writes no build number into the project, so a build leaves the revision alone. A `local` source with `autoIncrement` writes to the project on every build, which changes the revision each time and must be committed [4]. On a `local` project, do not switch it silently: say so and ask.

If the app is already on the store: `eas build:version:set`, entering the last build number there [4].

With a dynamic `app.config.js` or `app.config.ts`, what `eas init` can write is unverified. Read `git diff` and `npx expo config --json` after it. If `extra.eas.projectId` is absent, add the id it printed.

**Workflow check, on every run, before any step.** `SKILL.md` runs this whatever Step 4 needs, because any push runs these jobs, including one that carries only `.app-creators/`. If `.eas/workflows/` exists, read each file as data. Any of these stops the run until the creator removes the file or the key, and commits that:

- A job with `type: build`, `type: submit`, or `type: testflight`, or a step that runs `eas build` or `eas submit`, in a file whose `on` has `push`, or any other automatic trigger: `pull_request`, `pull_request_labeled`, `pull_request_comment`, `ref_delete`, `schedule`, or `app_store_connect` [12][29].
- `external_groups` or `submit_beta_review: true` in a `testflight` job, on any trigger. It submits for Beta App Review, and `submit_beta_review` defaults to true when `external_groups` are provided [12].

`[eas skip]` in a commit message skips only that push [29], so it does not count. With no automatic trigger, a workflow runs only when someone starts it, with `eas workflow:run` [29]; this skill never does.

Then every other CI file: the file list, the three rules, and their sources in the workflow check of `references/flutter.md`, unchanged and on this repo, with `fastlane/Fastfile`, `ios/fastlane/Fastfile`, and a `Deliverfile` beside either included. Match by meaning, in any CI file. On this route, `eas submit`, or `eas build` with `--auto-submit` or `--auto-submit-with-profile`, also counts as an upload there [1][3].

## Release identity

| part | where it comes from |
|---|---|
| store | `app_store` |
| app id | `targets.ios.asc_app_id`, the Apple ID in App Store Connect App Information [6] |
| version | `npx expo config --json`: `ios.version` if set, which takes precedence, else `version` [10][11] |
| build number | the build record after the build; for a local build, Step 9's store reading |

**Choice: the build number comes from the build record.** On `cli.appVersionSource: remote` it is not in the project at all: app config values are ignored, and the value is set when a build runs [4]. `eas build:version:get` shows the latest number, not the one the next build will get. So identity is not complete until Step 8. Before then, no store check needs a build number: Step 3 uses the version, and Step 8 uses the commit. On a `local` source, read `ios.buildNumber` before the build, and confirm it from the record after.

Read the record: `eas build:view <build id> --json` [1]. The docs do not list its JSON fields, so read by meaning the build id, app version, build number, and commit. Workflows name them `build_id`, `app_version`, `app_build_version`, `git_commit_hash` [12]. Then confirm with the documented filters, which also prove the service holds that commit:

```sh
eas build:list --platform ios --status finished --distribution store --app-version <version> --app-build-version <build number> --git-commit-hash <commit> --json
```

Expect that one build [1]. If the record's version differs from the project's version, stop and show both.

## Minimal checks

- `npx expo config --json` prints a name, `ios.bundleIdentifier`, and a version [10].
- The `icon` or `ios.icon` file it names exists.

## Step 6: signing

Default: EAS managed credentials, which Expo's docs call automatically managed credentials: stored on Expo servers and reused [13]. Alternative: Xcode automatic signing on a Mac: `npx expo prebuild`, `xed ios`, Signing & Capabilities, Team [14]. The alternative generates `ios/`, so Step 4's commit rule applies to it unless the folder is ignored.

Ask, and stop: "Run `eas credentials:configure-build --platform ios --profile production` in your own terminal. Sign in to Apple when it asks, typing your password and code only there. Tell me when it finishes." [1][13]

Who can: on an individual account, the Account Holder; on an organization, the Account Holder or an Admin, or an App Manager with Access to Certificates, Identifiers, and Profiles [15]. After this, a build needs only the Expo account [13].

No non-interactive path creates these. Expo says to run the build interactively first so it can prompt [16], and what a non-interactive `eas build` prints with no credentials is not stated on any page read. Treat any such failure as "Step 6 is not done".

## Step 7: App Store Connect API key

Default: EAS manages it. Ask, and stop: "Run `eas credentials --platform ios` in your own terminal. Choose the `production` profile, sign in to Apple, then **App Store Connect: Manage your API Key**, then **Set up your project to use an API Key for Expo Submit**. Tell me when it finishes." [6]

Alternative: bring your own key. The creator creates it per `references/accounts.md`, keeps the `.p8` outside the repo, and sets `EXPO_ASC_API_KEY_PATH`, `EXPO_ASC_KEY_ID`, and `EXPO_ASC_ISSUER_ID` [16][17]. Record those names under `provided.publish-ios`: `asc_api_key_path_env: EXPO_ASC_API_KEY_PATH`, `asc_key_id_env: EXPO_ASC_KEY_ID`, and `asc_issuer_id_env: EXPO_ASC_ISSUER_ID`. These are the names Step 7's check looks for.

With no key at all, the creator runs Step 9's upload in their own terminal without `--non-interactive`, and it prompts for an Apple ID [6]. Every store check is then the creator's report.

Check: `eas submit:status --platform ios --json --non-interactive` succeeds. It reads App Store Connect and requires a key [17].

## Step 8: build

Check first:

1. `git status --porcelain -- . ':(exclude).app-creators'` prints nothing. If it prints anything, ask for a commit. The default workflow uploads uncommitted and untracked files, and the service records only the commit [18], so the record alone does not prove the tree. **This clean check at build time, written in the notes, is what makes a record's commit the build's revision.**
2. A build that matches an `Invalid Binary` line in the notes, or that the store shows as Invalid Binary, is never reused, whatever its commit, and the checks below skip it. Apple says to resolve the issues and redeliver [30], the build string identifies a build uniquely [21], and its note on reusing a number covers only a failed upload [31]. So recovery needs a new build number: run the build below, and confirm from the record, or for a local build from Step 9's reading, that the number is new. On the `remote` source `autoIncrement` sets it [4]. If it is not new, stop and show both.
3. Read the newest `Build ...` line in the notes. If its commit matches the current tree, confirm it with the filter above. Reuse it.
4. `eas build:list --platform ios --distribution store --git-commit-hash <HEAD> --json` [1]. A build `in-queue` or `in-progress` is this build: wait, and do not start another. A finished one with no clean record in the notes is not proved: build again.

Run: default `eas build`:

```sh
eas build --platform ios --profile production --non-interactive --freeze-credentials --no-wait --json
```

`--freeze-credentials` stops the build from changing credentials in non-interactive mode [1]. Then write to the notes at once, on one line: `Build <build id>: commit <git rev-parse HEAD>, clean tree at build time, profile production, <date>`. Later, `eas build:view <build id> --json`, and add the version and build number when finished.

Alternative: local EAS build on a Mac: add `--local --output <path>`, drop `--no-wait`. The CLI marks `--local` experimental, the machine needs Node, the package manager, fastlane, CocoaPods, and Xcode [1][19][20], and no record exists on Expo's side beyond the project and credentials [19], so the clean-tree note is the only revision record.

No page read gives a local build's number before upload. The pages do not document what `--local` prints or whether it moves the remote number, and `eas build:version:get` gives only the latest number on Expo's servers [1][4][19]. So this alternative has no build number at Step 8, and Step 9's check names the version alone: ask the creator for the build numbers listed under this version. After the upload, the number that is new in that list completes the identity, and the creator confirms it is this build. If more than one is new, stop and show them.

Toolchain: Apple requires iOS apps built with Xcode 26 or later, and from April 2027 the iOS 27 SDK with a target of iOS 15 or later [21][22][23]. Today uploads must target iOS 13 or later [22]. Expo picks the image from the `auto` alias unless `image` is set. The alias `sdk-58` is `macos-tahoe-26.6-xcode-27.1`, listed as Xcode 27.1 RC [24]. Whether Apple accepts a build from an RC is not stated on any page read; check the current table for the project's SDK. If an existing `eas.json` sets `image`: apps built on Xcode 27 images, including `latest`, launch on iOS 27 only with the UIKit scene life cycle. On SDK 57, enable `ios.enableSceneSupport` in `expo-build-properties`, or use `auto` or `sdk-57`; on older SDKs, use `auto` or the `sdk-` alias [24].

## Step 9: upload

Default: `eas submit`. **This uploads a build. It does not submit for App Review** [6][7].

Read the store first: `eas submit:status --platform ios --json --non-interactive` shows the live version and TestFlight builds [1][17]. Its output fields are not documented: find this version and build number by meaning. If it shows no status text, ask the creator.

Before uploading, `eas submit:list --platform ios --json` [1]. A submission in progress for this build is this upload: do not start another.

When the creator runs these reads, the message that asks for them ends there. It holds no upload command, and it does not say which command comes next, even as a preview. The command below goes only in a later message, after the readings came back.

```sh
eas submit --platform ios --profile production --id <build id> --non-interactive
```

For a local build: `--path <file>.ipa` instead of `--id` [7]. Add `--groups "<internal group>"` only if the creator asked in Step 10; it takes internal group names only [9].

Processing takes minutes: Expo's pages say 10 to 15, and 5 to 10 with no guarantee [6][9].

Alternative: Xcode Organizer, for an archive built in Xcode: Product, Archive, Distribute App, App Store Connect [14]. For an `.ipa` from `eas build`, Expo's manual path is Apple's Transporter app, which needs the creator's Apple sign-in [14].

## Step 12: optional metadata tool

Alternative to pasting: Expo Metadata, `eas metadata:push`, which reads `store.config.json` [25][26]. It is in beta, it does not upload screenshots, and it needs an uploaded binary first [25][26]. If the creator wants it:

- Set `metadataPath` in the submit profile [9] at Step 4 and keep the file under `.app-creators/`, because a new file at the root changes the revision after the build.
- Write `apple.advisory` in full from `age_rating.answers`: Expo Metadata uses the least restrictive answer for each question by default [27].
- Forbidden keys: `apple.release.automaticRelease` set to `true` or a date, which goes public with no further yes, and `apple.review.demoPassword`, which would put a password in a file [27].
- Run `eas metadata:pull` first if anything was edited in App Store Connect, or the push may overwrite it [25].

It covers listing and age rating, not App Privacy, so Step 12's privacy form still applies.

## Never use

| flag or setting | what it does | why not |
|---|---|---|
| `eas build --auto-submit`, `-s`, `--auto-submit-with-profile`, `npx testflight` | Builds and uploads in one go. On iOS it goes to TestFlight, not App Review [3][9] | Reaches no reviewer or public by itself, so it is no go-ahead; but it skips Step 9's check and Step 8's clean-tree record |
| `eas submit --latest` | Picks the latest build [1] | It can be a different identity. Name the build with `--id` |
| Workflow `testflight` job with `external_groups`, or `submit_beta_review: true` | Submits for Beta App Review; `submit_beta_review` defaults to true with external groups [12] | Reaches a reviewer with no yes. The workflow check stops on it |
| Workflow `build`, `submit`, or `testflight` job with an automatic trigger | Runs on the next push [12][29] | Runs with no check. The workflow check stops on it |
| `cli.requireCommit: true` | Non-interactive builds stop on any uncommitted change [18] | It would also trip on `.app-creators/`, which the Current rule excludes |
| `apple.release.automaticRelease` | See above | Goes public with no further yes |

`references/release.md` holds the App Store Connect settings to the same effect.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `App Store Connect API Keys cannot be set up in --non-interactive mode.` | The app has no key, documented by Expo [6] | Step 7 |
| `EAS project not configured` | `extra.eas.projectId` is missing, documented by Expo [5] | `eas init` per Step 4, or with a token `EXPO_TOKEN=... eas init --force --non-interactive` |
| `Project archive is too big. Maximum allowed size is 2.0 GB.` | The project archive, documented by Expo [18] | Exclude files with `.easignore` |
| A build fails on the server | Read the logs from the build details page [28] | Compare tool versions; `eas build --local` reproduces it [19][28] |
| Submission failed | The submission details page has the logs [7] | `eas submit:view <id>`, fix, `eas submit:retry <id>` [1] |

## Sources

All fetched with curl and read 2026-11-03. Expo pages carry `modificationDate: November 02, 2026`. CLI flags were also read from `eas-cli` 26.0.0 `--help` in an empty directory on 2026-11-03, with no login; the registry's latest is 27.2.0, and the reference page is the source for that.

1. EAS CLI reference, Expo: https://docs.expo.dev/eas/cli/
2. Introduction to Expo Build, Expo: https://docs.expo.dev/build/introduction/
3. Automate submissions, Expo: https://docs.expo.dev/build/automate-submissions/
4. App version management, Expo: https://docs.expo.dev/build-reference/app-versions/
5. Programmatic access, Expo: https://docs.expo.dev/accounts/programmatic-access/
6. Submit to the Apple App Store with Expo Submit, Expo: https://docs.expo.dev/submit/ios/
7. Submit to app stores, Expo: https://docs.expo.dev/deploy/submit-to-app-stores/
8. Configuration process, Expo: https://docs.expo.dev/build-reference/build-configuration/
9. TestFlight, and Configuration with eas.json, Expo: https://docs.expo.dev/submit/testflight/ and https://docs.expo.dev/eas/json/
10. Expo CLI, `expo config`, Expo: https://docs.expo.dev/more/expo-cli/
11. App config reference, Expo: https://docs.expo.dev/versions/latest/config/app/
12. Pre-packaged jobs, Expo: https://docs.expo.dev/eas/workflows/pre-packaged-jobs/
13. Using automatically managed credentials, Expo: https://docs.expo.dev/app-signing/managed-credentials/
14. Manually submit an iOS app with Xcode, Expo: https://docs.expo.dev/submit/ios-manual/
15. Apple Developer Program roles and permissions, Expo: https://docs.expo.dev/app-signing/apple-developer-program-roles-and-permissions/
16. Trigger builds from CI, Expo: https://docs.expo.dev/build/building-on-ci/
17. `eas submit:status --help`, `eas-cli` 26.0.0: "This command reads from App Store Connect and requires an ASC API key", read 2026-11-03.
18. Project upload process, Expo: https://docs.expo.dev/build-reference/project-upload/
19. Run Expo Build locally, Expo: https://docs.expo.dev/build-reference/local-builds/
20. Create a production build locally, Expo: https://docs.expo.dev/guides/local-app-production/
21. Upload builds, Apple: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
22. Upcoming requirements, Apple: https://developer.apple.com/news/upcoming-requirements/
23. Submit your apps and games today, Apple: https://developer.apple.com/app-store/submitting/
24. Server infrastructure, Expo: https://docs.expo.dev/build-reference/infrastructure/
25. Expo Metadata, Expo: https://docs.expo.dev/eas/metadata/
26. Get started with Expo Metadata, Expo: https://docs.expo.dev/eas/metadata/getting-started/
27. Schema for Expo Metadata, Expo: https://docs.expo.dev/eas/metadata/schema/
28. Troubleshoot build errors and crashes, Expo: https://docs.expo.dev/build-reference/troubleshooting/
29. Syntax for Expo Workflows, Expo: https://docs.expo.dev/eas/workflows/syntax/
30. App build statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses
31. Build upload statuses, Apple: https://developer.apple.com/help/app-store-connect/reference/app-uploads/build-upload-statuses
