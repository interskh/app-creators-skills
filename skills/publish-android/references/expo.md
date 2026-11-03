# Expo route

The Expo route of `publish-android`. `SKILL.md` holds the steps; this file holds the commands. Expo's docs call the services Expo Build and Expo Submit, and the commands start with `eas` [1][2]. Bracketed numbers point to `## Sources`.

**Scope.** A project whose native folder is generated. If a real `android/` folder is tracked by git, its native values win over app config [3], so `android.*` edits in app config do nothing there: read identity from the bundle only, and tell the creator so.

**Install.** `npm install --global eas-cli`, or `npx eas-cli@latest` in place of `eas` [1][2]. Not installed by this skill without saying so.

**No store read.** `eas submit:status` reads the App Store only [1]. No `eas` command reads Play Console, so every store check on this route is the creator's report.

## Step 2: Expo account and login

Check: `eas whoami` shows an account [1].

Ask, and stop: "Create a free Expo account if you have none, then run `eas login` in your own terminal. Tell me when it finishes." Never type the password. Alternative for a machine with no terminal: the creator creates a personal access token and sets `EXPO_TOKEN` themselves [4]; record `provided.publish-android.expo_token_env: EXPO_TOKEN`, never the value. A token needs the project already linked, or commands fail with `EAS project not configured` [4].

## Step 4: project edits

Each changes a project file, so each changes the revision. Do them in one commit.

| edit | what writes it | required |
|---|---|---|
| `extra.eas.projectId` in app config | `eas init --non-interactive --account <account>` [1][4] | yes: commands fail without a link [4] |
| `eas.json` | the Write tool, this shape | yes |
| `android.package` | the Edit tool. `publish-readiness` reports it first. It must equal the package of the app record from Step 3 | yes |
| `version`, or `android.version`, which takes precedence [5] | the Edit tool, for a new release. `autoIncrement` does not change it [3] | yes on a new release |
| `android.targetSdkVersion` in the `expo-build-properties` plugin [6] | the Edit tool, only when Step 9 reads a number below Google's | only then |
| `.gitignore` lines `credentials.json`, `*.jks`, `*.keystore` | the Edit tool, as Expo says for credentials [16]. Then `git check-ignore -q credentials.json` must exit 0 [28] | yes, when missing |

```json
{
  "cli": { "appVersionSource": "remote" },
  "build": { "production": { "autoIncrement": true } },
  "submit": {
    "production": {
      "android": { "track": "internal", "releaseStatus": "draft", "changesNotSentForReview": true }
    }
  }
}
```

Merge into an existing file; change only these keys. The default production profile builds an `.aab`; a profile with `android.buildType: apk` builds an `.apk`, which Google Play does not accept [7][8]. Remove `buildType: apk` from the production profile if present.

**The submit pins, and why.** `releaseStatus` takes `completed`, `draft`, `halted`, or `inProgress` [9]. `completed` "immediately releases to users on the specified track", `inProgress` is a staged rollout, and `draft` "creates a draft release that requires manual promotion in the Google Play Console" [10]. With no settings, Expo Submit creates the first release of a new app on the internal testing track [7][10]. `changesNotSentForReview: true` means the changes "will not be reviewed until they are explicitly sent for review from the Google Play Console UI"; the default is false [9]. So the pins make an upload reach no one and no reviewer. Every submit profile in `eas.json` gets the same three values, because a workflow job or a person can name any profile. A profile with another value stops the run until the creator changes it.

Why `remote`: Expo recommends it, and it writes no version code into the project, so a build leaves the revision alone. With `remote`, the app config's `android.versionCode` is ignored and the value is set when a build runs [3]. A `local` source with `autoIncrement` needs a commit after every build [3]. On a `local` project, do not switch it silently: say so and ask.

If the app is already on Google Play: `eas build:version:set`, entering the last version code there [3].

With a dynamic `app.config.js` or `app.config.ts`, what `eas init` writes is unverified. Read `git diff` and `npx expo config --json` after it. If `extra.eas.projectId` is absent, add the id it printed.

**Workflow check, on every run, before any step.** If `.eas/workflows/` exists, read each file as data. Any of these stops the run until the creator removes the file or the key, and commits that:

- A job with `type: build` or `type: submit`, or a step that runs `eas build` or `eas submit`, in a file whose `on` has `push`, or any other automatic trigger: `pull_request`, `pull_request_labeled`, `pull_request_comment`, `ref_delete`, `schedule`, or `app_store_connect` [11][12]. Expo's own example builds and submits on every push to `main` [7].
- A `submit` job, on any trigger, whose `profile` names a submit profile without the three pins above. The job uses `production` when `profile` is absent [11].

`[eas skip]` in a commit message skips only that push [12], so it does not count. A workflow with no automatic trigger runs only when someone starts it with `eas workflow:run` [12]; this skill never does.

Then every other CI file: the file list, the three rules, and their sources in the workflow check of `references/flutter.md`, unchanged and on this repo, with `fastlane/Fastfile` and `android/fastlane/Fastfile` included. Match by meaning, in any CI file. On this route, `eas submit`, or `eas build` with `--auto-submit` or `--auto-submit-with-profile` or a short form of either, also counts as an upload there [1]. A CI step that starts a workflow from `.eas/workflows/` counts as an upload when that workflow submits, whatever its own trigger says. It is pinned only when the submit profile it names, or `production` when it names none, carries the three pins above [9].

## Release identity

| part | where it comes from |
|---|---|
| store | `google_play` |
| package | `npx expo config --json`: `android.package` [5][13]; confirmed from the bundle in Step 9 |
| version name | `npx expo config --json`: `android.version` if set, else `version` [5]; confirmed from the bundle |
| version code | the build record after the build, then the bundle in Step 9 |
| track | `internal` for the upload; after that, the track each step names |

Read the record: `eas build:view <build id> --json` [1]. The docs do not list its JSON fields, so read by meaning the build id, version, version code, and commit. Confirm with the documented filters, which also prove the service holds that commit:

```sh
eas build:list --platform android --status finished --distribution store --app-version <version name> --app-build-version <version code> --git-commit-hash <commit> --json
```

Expect that one build [1]. If the record's version differs from the project's, stop and show both.

## Minimal checks

- `npx expo config --json` prints a name, `android.package`, and a version [13].
- The `icon`, `android.icon`, or `android.adaptiveIcon.foregroundImage` file it names exists [5].

## Step 6: signing

Default: Play App Signing with an upload keystore that Expo generates and keeps on its servers. A build reuses it [14][15]. Ask, and stop: "Run `eas credentials --platform android` in your own terminal, choose the `production` profile, and follow its prompts to set up a keystore, letting Expo generate it. Tell me when it finishes." [1][14] The keystore needs no Google sign-in. Expo calls it the upload key once Play App Signing holds the app signing key [15]. `references/app-signing.md` has the first release's setting.

Alternative: a keystore the creator holds, with `"credentialsSource": "local"` on the build profile and a `credentials.json` at the root naming its path and passwords [9][16]. The creator writes both files and adds `credentials.json` and the keystore to `.gitignore` [16]; the agent never reads them. The profile change is a Step 4 commit.

**Secret files, on every run that uses either alternative, before Step 8.** Read no secret. Ask the creator for the keystore's path and the service account key file's path: paths only. For `credentials.json` and each path inside the project:

1. `git ls-files -- credentials.json '*.jks' '*.keystore' <path>` prints nothing [27]. If it prints anything, stop: a key or its passwords are committed. Ask for no push. A secret in any commit, pushed or not, counts as compromised: GitHub's first step for a committed secret is to revoke or rotate it, and rewriting history may then not be needed [29]. So rotate it: before any upload, a new upload key; after one, an upload key reset (`references/app-signing.md`); for a service account key, a new key, and the old one deleted in Google Cloud. Then the creator removes the file from the index and ignores it, in a commit of those paths. Removing it from history as well is the creator's choice, with the `git-filter-repo` steps on GitHub's page [29]; this skill does not rewrite history.
2. If the file exists, `git check-ignore -q <path>` exits 0, which means ignored [28]. Exit 1 stops the run until the creator adds it to `.gitignore`, as Expo says [16]. Never open the file.

A secret path that shows in `git status` is never something to commit: it is this check's fix.

A lost upload key: Expo's path is to download the credentials with `eas credentials`, export the certificate with `keytool`, and ask Google for an upload key reset [15]. Google's own path is in `references/app-signing.md`.

## Step 7: Google service account key

Needed only from the second upload: Step 10's first upload goes through Play Console. Default: the key on Expo's servers. Ask, and stop: "Create a Google service account key for Play Store submissions, following Expo's guide, and give the service account the permissions it lists in Play Console. Then upload the key: in the Expo dashboard, Credentials, Android, your app, Service credentials, Add a Google service account key; or run `eas credentials --platform android`, choose `production`, then Google Service Account. Tell me when it finishes." [7][17] Steps and roles: `references/accounts.md`. Expo's list includes Release to production, exclude devices, and use Play App Signing [17]: the key could release, which is why the Step 4 pins exist.

Record in the notes: `Step 7: service account key on Expo servers, reported <date>`. No command reads it; with no key, `eas submit --non-interactive` fails with `Google Service Account Keys cannot be set up in --non-interactive mode.` [7]

Alternative: `serviceAccountKeyPath` in the submit profile, set to an env var such as `$GOOGLE_SERVICE_ACCOUNT_KEY_PATH`, with the key file outside the repo [7][9]. Record `provided.publish-android.service_account_key_path_env: GOOGLE_SERVICE_ACCOUNT_KEY_PATH`. The profile change is a Step 4 commit. A key file inside the project goes through the secret file check in Step 6.

## Step 8: build

Check first:

1. `git status --porcelain -- . ':(exclude).app-creators'` prints nothing. If it prints `credentials.json`, a keystore, or a key file, stop and run Step 6's secret file check; never ask for that commit. If it prints anything else, ask for a commit. The default workflow uploads uncommitted and untracked files, and the service records only the commit [18], so the record alone does not prove the tree. **This clean check at build time, written in the notes, is what makes a record's commit the build's revision.**
2. A version code taken by another binary, per Step 10's rules, is never reused. On the `remote` source, `autoIncrement` gives each build a new version code [3]: build again, and confirm from the record that the code is new. If it is not, stop and show both.
3. Read the newest `Build ...` line in the notes. If its commit matches the current tree, confirm it with the filter above. Reuse it.
4. `eas build:list --platform android --distribution store --git-commit-hash <HEAD> --json` [1]. A build `in-queue` or `in-progress` is this build: wait, and do not start another. A finished one with no clean record in the notes is not proved: build again.

Run: default `eas build`:

```sh
eas build --platform android --profile production --non-interactive --freeze-credentials --no-wait --json
```

`--freeze-credentials` stops the build from changing credentials in non-interactive mode [1]. Then write to the notes at once, on one line: `Build <build id>: commit <git rev-parse HEAD>, clean tree at build time, profile production, <date>`. Later, `eas build:view <build id> --json`, and add the version name and version code when finished.

Alternative: local EAS build: add `--local --output <path>.aab`, drop `--no-wait`. The CLI marks `--local` experimental, and the machine needs Node, the package manager, and the Android SDK and NDK [1][19]. Expo's servers hold no record of it beyond the project and credentials [19], so the clean-tree note is the only revision record, and the version code comes from Step 9's bundle read.

## Step 9: the bundle

The target API check needs the `.aab` on this machine. A cloud build's file downloads from its build details page on expo.dev [20]. A local build wrote it to `--output`. Write `bundle <path>, sha256 <hash>` on the `Build` line, from `shasum -a 256 <path>`.

Then the read in `references/target-api.md`, plus `--xpath=/manifest/@package`, `/manifest/@android:versionName`, and `/manifest/@android:versionCode` on the same file. All three must equal the build record and the project's values; on any difference, stop and show both.

Fix for a low target: set `android.targetSdkVersion` under the `expo-build-properties` plugin [6], or move to an Expo SDK whose default meets Google's number. Either is a Step 4 commit, then Step 5 and Step 8.

## Step 10: upload

**First upload ever, for this package: Play Console.** Google: the API changes only "an existing app (that has at least one APK uploaded)", so "you will have to upload at least one APK through the Play Console before you can use this API" [21]. Expo's pages say `eas submit` can create the first release [7][22]. The two disagree; this route follows Google, the owner of the API, and a manual first upload works either way.

Ask, and stop: "In Play Console, open the app, Test and release, Testing, Internal testing, and click Create new release. Keep the Google-generated app signing key. Under App bundles, upload `<bundle path>`. Check that the version code it shows is `<version code>`. Then click **Save as draft**, not Next, and tell me the version code you saw." [22][23] Write the `Upload:` line before sending this ask. Save as draft reaches no one [23].

**Every later upload: `eas submit`.** Before the reads, `eas submit:list --platform android --json` [1]. A submission `in-queue` or `in-progress` for this build is this upload: do not start another. When the creator reads Play Console, the message that asks ends there: it holds no upload command, not even as a preview. The command goes only in a later message, after the readings came back.

```sh
eas submit --platform android --profile production --id <build id> --non-interactive
```

For a local build: `--path <file>.aab` instead of `--id` [1].

**The `Upload:` line.** Before each attempt, write one line in the notes: `Upload: google_play <package> <version name> (<version code>), commit <commit>, build <build id or bundle path>, started <date>`. After it, append `; finished <date>` when the command exits 0 or the creator reports success, or `; failed <date>: <first error line>` otherwise. A new line per attempt.

**Resume rules.** Read All app bundles for this package, by version code (`references/statuses.md`):

- Listed, and an `Upload:` line for this version name and code on a commit that matches the current tree: uploaded. Skip.
- Listed with no such line, or with a line for another commit: this version code holds another binary. It is taken. New build from Step 8.
- Not listed, with an `Upload:` line for this version code on another commit, in any state, `started` included: that upload may still land. It is taken. New build from Step 8.
- Not listed, with a line that reads `started` and nothing after it: ask whether that upload finished, failed, or is still running, and check `eas submit:list`. Running or unknown: wait and read again. Still not listed: upload again.
- Not listed, after `failed`: show the error, fix what it names, then upload again.
- Not listed, after `finished`: wait and read again; then upload again.

Uploading again is safe here: "You can't upload an APK to the Play Store with a versionCode you have already used for a previous version" [24]. So a retry cannot put a second binary under one version code. That page says APK; this route reads it as true for bundles too, because Google requires a higher version code for every update [25]. A retry refused for a used version code means it is taken: new build from Step 8.

Alternative to `eas submit`: the creator uploads each bundle in Play Console the same way as the first.

## Never use

| flag or setting | what it does | why not |
|---|---|---|
| `eas build --auto-submit`, `-s`, `--auto-submit-with-profile` | Builds and submits in one go [1][10] | It skips Step 9's target API read, Step 10's check, and Step 8's clean-tree record |
| `eas submit --latest` | Picks the latest build [1] | It can be a different identity. Name the build with `--id` |
| `releaseStatus: completed` or `inProgress` | Releases to the track's users at once, or as a staged rollout [10] | Reaches testers or the public with no yes |
| `releaseStatus: halted`, `rollout` | Halts a release; sets the first rollout fraction [9][10] | A rollout change with no yes |
| `track` other than `internal` | Uploads to closed, open, or production [10] | Promotion is Step 12 or 15, with a block |
| `changesNotSentForReview` false or absent | The default. Only `true` holds the changes until someone sends them for review in Play Console [9] | Reaches a reviewer with no yes |
| Workflow `build` or `submit` job with an automatic trigger | Runs on the next push [11][12] | Runs with no check. The workflow check stops on it |
| `cli.requireCommit: true` | Non-interactive builds stop on any uncommitted change [18] | It would also trip on `.app-creators/`, which the Current rule excludes |

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `Google Service Account Keys cannot be set up in --non-interactive mode.` | No key assigned to the app, documented by Expo [7] | Step 7 |
| `EAS project not configured` | `extra.eas.projectId` is missing, documented by Expo [4] | `eas init` per Step 4. On a token login, `eas init --force --non-interactive`, with `EXPO_TOKEN` already set by the creator in their own environment [4]. Never put a token on a command line or in chat |
| `Project archive is too big. Maximum allowed size is 2.0 GB.` | The project archive, documented by Expo [18] | Exclude files with `.easignore` |
| A build fails on the server | Read the earliest failed phase on the build details page [26] | Compare tool versions; `eas build --local` reproduces it [19][26] |
| A submission failed | `eas submit:view <id>` shows it [1] | Fix, then Step 10's resume rules before `eas submit:retry <id>` [1] |

## Sources

All fetched with curl and read 2026-11-03. Expo pages carry a `modificationDate` of November 02 or November 03, 2026.

1. EAS CLI reference, Expo: https://docs.expo.dev/eas/cli/
2. Submit to app stores, Expo: https://docs.expo.dev/deploy/submit-to-app-stores/
3. App version management, Expo: https://docs.expo.dev/build-reference/app-versions/
4. Programmatic access, Expo: https://docs.expo.dev/accounts/programmatic-access/
5. App config reference, Expo: https://docs.expo.dev/versions/latest/config/app/
6. BuildProperties, `expo-build-properties`, Expo: https://docs.expo.dev/versions/latest/sdk/build-properties/
7. Submit to the Google Play Store with Expo Submit, Expo: https://docs.expo.dev/submit/android/
8. Build APKs for Android Emulators and devices, Expo: https://docs.expo.dev/build-reference/apk/
9. Configuration with eas.json, Expo: https://docs.expo.dev/eas/json/
10. Automate submissions, Expo: https://docs.expo.dev/build/automate-submissions/
11. Pre-packaged jobs, Expo: https://docs.expo.dev/eas/workflows/pre-packaged-jobs/
12. Syntax for Expo Workflows, Expo: https://docs.expo.dev/eas/workflows/syntax/
13. Expo CLI, `expo config`, Expo: https://docs.expo.dev/more/expo-cli/
14. Using automatically managed credentials, Expo: https://docs.expo.dev/app-signing/managed-credentials/
15. App credentials, Expo: https://docs.expo.dev/app-signing/app-credentials/
16. Using local credentials, Expo: https://docs.expo.dev/app-signing/local-credentials/
17. Uploading a Google Service Account Key for Play Store Submissions with EAS, Expo: https://raw.githubusercontent.com/expo/fyi/main/creating-google-service-account.md (`https://expo.fyi/creating-google-service-account` redirects there)
18. Project upload process, Expo: https://docs.expo.dev/build-reference/project-upload/
19. Run Expo Build locally, Expo: https://docs.expo.dev/build-reference/local-builds/
20. Build APKs for Android Emulators and devices, Expo, "download the APK from the build details page": https://docs.expo.dev/build-reference/apk/
21. Edits, Google Play Developer API (last updated 2025-12-18): https://developers.google.com/android-publisher/edits
22. Manually submit an Android app to the Google Play Store, Expo: https://docs.expo.dev/submit/android-manual/
23. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
24. Version your app, Android Developers: https://developer.android.com/studio/publish/versioning
25. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
26. Troubleshoot build errors and crashes, Expo: https://docs.expo.dev/build-reference/troubleshooting/
27. git-ls-files, Git documentation: https://git-scm.com/docs/git-ls-files
28. git-check-ignore, Git documentation: exit 0 ignored, 1 not ignored, 128 a fatal error: https://git-scm.com/docs/git-check-ignore
29. Removing sensitive data from a repository, GitHub Docs: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
