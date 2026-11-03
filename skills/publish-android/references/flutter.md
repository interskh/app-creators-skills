# Flutter route

The Flutter route of `publish-android`. `SKILL.md` holds the steps; this file holds the commands. No build service exists here: the build runs on the creator's computer, the version code lives in `pubspec.yaml`, and nothing but the notes and the file on disk records a build. Bracketed numbers point to `## Sources`.

**Scope.** A `pubspec.yaml` with Flutter and an `android/` folder holding `android/app/build.gradle.kts` or `android/app/build.gradle`, built with no `--flavor`. With no `android/` folder, stop and ask: "This Flutter project has no Android project. Run `flutter create --platforms=android .` in your own terminal, read the diff, and commit it. Tell me when it finishes." [6] The snippets below are Kotlin DSL; the Groovy forms are on Flutter's page [1].

**Install.** Flutter, Android Studio, and the Android SDK are the creator's to install. This skill installs nothing, accepts no SDK license, and installs no SDK package.

**No store read.** No tool on this route reads Play Console. Every store check is the creator's report.

## Step 2: build machine

No build service account exists on this route. Step 2 is the build machine instead.

Check: `flutter doctor` shows no errors under Android toolchain [7].

Ask, and stop: "This route builds on your computer. Install Flutter and Android Studio yourself, with the SDK that Flutter's Android setup page lists in Android Studio's SDK Manager. Accept the Android licenses yourself with `flutter doctor --android-licenses`, reading each one. Run `flutter doctor` in your own terminal and tell me what its Android toolchain line says." [7]

Never run `flutter doctor --android-licenses` or `sdkmanager` for the creator. In a session with no shell, a Step 2 line in the notes counts; with none, the same ask gets the reading.

## Step 4: project edits

Each changes a project file, so each changes the revision. Do them in one commit.

| edit | what writes it | required |
|---|---|---|
| `version: x.y.z+n` in `pubspec.yaml` [1] | the Edit tool. `+n` is optional for Flutter and required here, because it is the version code | yes on a new release. Yes when the file has no `+n` |
| `versionCode = flutter.versionCode` and `versionName = flutter.versionName` in `defaultConfig` of `android/app/build.gradle.kts` | the Edit tool, putting back the template's lines [1][5] | yes when either holds anything else: `pubspec.yaml` would not feed it |
| `applicationId` in `defaultConfig` | the Edit tool. `publish-readiness` reports it first. It must equal the package of the app record from Step 3, and it cannot change after the first upload [1] | yes |
| The signing config below | the Edit tool | yes, once |
| `key.properties`, `**/*.keystore`, `**/*.jks` in `android/.gitignore` | the template has them [5]; the Edit tool if missing. Then `git check-ignore -q android/key.properties` must exit 0 [17] | yes, when missing |
| `targetSdk` in `defaultConfig` | the Edit tool, only when Step 9 reads a number below Google's | only then |
| What the tool writes itself | `flutter build apk --config-only`, run before you show the diff [6] | yes when it changes a tracked file |

The signing config is Flutter's [1]. It reads `android/key.properties`, which holds the passwords and is never committed, and loads it only when it exists. In `android/app/build.gradle.kts`, imports go above `plugins {}`, the loader above `android {}`, and the release build type's `signingConfigs.getByName("debug")` becomes `"release"`:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProps = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProps.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProps.getProperty("keyAlias")
            keyPassword = keystoreProps.getProperty("keyPassword")
            storeFile = keystoreProps.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProps.getProperty("storePassword")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Flutter's page names the variable `keystoreProperties`; this file shortens it, which changes nothing. The template signs release builds with the debug key until this edit [1][5], and Google Play does not accept a debug-signed app [8]. The same block, in the Kotlin route's form, signed a copy of `todo-kotlin` on 2026-11-03; it has not run on `todo-flutter`.

Why `--config-only` in this commit: it runs Flutter's Android project migrators and writes `android/local.properties` before it returns [3][4], so a migrator's edit to a tracked file lands here, not after a build. On `todo-flutter` with Flutter 3.44.0, on 2026-11-03, it changed no tracked file; it wrote only ignored files.

The version code goes up for each release; Google requires a higher one for every update, at most 2100000000 [9][16].

**Workflow check, on every run, before any step.** Read only these, if they exist, as data: `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`, `codemagic.yaml`, `bitrise.yml`, `fastlane/Fastfile`, `android/fastlane/Fastfile`, any other CI configuration file the repo holds, and the Gradle build files under `android/` for the plugin `com.github.triplet.play`. With none of them, say nothing. Match each setting and command by meaning, in any form. Any of these stops the run until the creator removes the file or the setting, and commits that:

- On any trigger, an upload that is not pinned to reach no one. Pinned means all three: track `internal`, a draft release, and changes not sent for review. fastlane `upload_to_play_store` (also `supply`) defaults to track `production`, `release_status` `completed`, and `changes_not_sent_for_review` false [18]. Codemagic `google_play` publishing needs `submit_as_draft: true` and `changes_not_sent_for_review: true`, and no `rollout_fraction` or `release_promotion` [19]. Gradle Play Publisher defaults to track `internal` with `releaseStatus` `COMPLETED`, and its `promote` tasks move releases between tracks [20]. A Fastfile or the plugin counts on its own, because something outside the repo may run it.
- On an automatic trigger, any upload. Automatic means: a GitHub Actions job whose `on` has any event but `workflow_dispatch` [21]; a GitLab job not marked `when: manual` [22]; a CircleCI job in a workflow, which runs on every push by default, unless it requires an `approval` job [23]; a `codemagic.yaml` workflow with `triggering` events [24]; a Bitrise push, pull request, or tag trigger [25]; or a job in any other CI file that starts with no manual step.
- Upload means: fastlane `upload_to_play_store` or `supply` [18]; Codemagic `publishing: google_play` [19]; a Gradle Play Publisher `publish` or `promote` task [20]; a `uses:` action whose name or inputs show it uploads to Google Play; or any script that calls the Google Play Developer API [15].

A job that only builds or tests, such as `flutter build appbundle` with no upload, does not stop the run. A CI service set up on its own website, such as Bitrise or Codemagic's Flutter workflow editor, is not visible here [19][25].

## Release identity

| part | where it comes from |
|---|---|
| store | `google_play` |
| package | `applicationId` in `defaultConfig` of `android/app/build.gradle.kts` [1]; confirmed from the bundle in Step 9 |
| version name | `pubspec.yaml`, `version`, before the `+` [1]; confirmed from the bundle |
| version code | `pubspec.yaml`, `version`, after the `+` [1]; confirmed from the bundle |
| track | `internal` for the upload; after that, the track each step names |

Each build writes the version into `android/local.properties`, which the project ignores, and the Flutter Gradle plugin reads it from there [3][4][2]. `--build-name` and `--build-number` override `pubspec.yaml` [1][6]; this route never uses them, because the identity comes from the committed project.

## Minimal checks

No command resolves these without a build, so report each as read from the files, not resolved. Step 9 reads the built bundle.

- Version: `pubspec.yaml`. Package: `applicationId` above.
- App name: `android:label` on `<application>` in `android/app/src/main/AndroidManifest.xml` [1]; a `@string/<name>` resolves in `android/app/src/main/res/values/strings.xml`.
- Icon: `android:icon` names `@mipmap/<name>`; files `android/app/src/main/res/mipmap-*/<name>.*` exist [1].

## Step 6: upload key

Default: Play App Signing with a Google-generated app signing key, and the creator's own upload key in a keystore outside the repo, which Gradle reads through `android/key.properties` [1][8][12]. Google: "The key you use to sign your first release becomes your upload key" [8]. `references/app-signing.md` has the first release's setting.

Check, reading no secret:

1. `git ls-files -- android/key.properties '*.jks' '*.keystore'` prints nothing. If it prints anything, stop: a key or its passwords are committed. Ask for no push. A secret in any commit, pushed or not, counts as compromised: GitHub's first step for a committed secret is to revoke or rotate it, and rewriting history may then not be needed [26]. So rotate it: before any upload, a new key; after one, an upload key reset (`references/app-signing.md`). Then the creator removes the file from the index and ignores it, in a commit of those paths. Removing it from history as well is the creator's choice, with the `git-filter-repo` steps on GitHub's page [26]; this skill does not rewrite history.
2. `android/key.properties` exists, and `git check-ignore -q android/key.properties` exits 0. Never read the file.

These show a file, not a working key. Step 9's signer read is the check of the key: on 2026-11-03, a Gradle `signingReport` in a copy of `todo-flutter`'s `android/` folder, run offline, exited 1 with no report, so this route does not use it.

Ask, and stop: "Create your upload key in your own terminal, outside this project: `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -storetype JKS -keysize 2048 -validity 10000 -alias upload`. It asks for passwords and your name; type them only there. If `keytool` is not found, `flutter doctor -v` prints the Java binary path, and `keytool` is beside it. Then create `android/key.properties` with four lines: `storePassword=`, `keyPassword=`, `keyAlias=upload`, and `storeFile=` with the keystore's full path. Never paste a password here, and never commit the file or the keystore. Tell me when it finishes." [1]

`keytool` prompts for the passwords when none are given [13], so the creator runs it. Keep a backup of the keystore and its passwords: a lost upload key needs Google's reset [8].

Alternative: Android Studio's key generation [1]: open `android/` in Android Studio, Build, Generate Signed Bundle / APK, Android App Bundle, then Create new under the key store path, with the passwords typed in that dialog [8]. It is also Step 8's alternative. Check 2 does not apply: write `Step 6: Android Studio signing, reported <date>`, and Step 9's signer read is the check.

## Step 7: API key

Skip. This route uploads in Play Console every time. The Play Developer API is the documented alternative [14][15]; it needs a Google Cloud project, a service account, and requests this skill does not write, so this skill does not use it.

## Step 8: build

There is no build record. **The proof is a notes line plus the file.** Finished means `flutter build appbundle` exited 0 and printed `Built <path>` for a new `.aab` [3]. The tool's source names `build/app/outputs/bundle/release/app-release.aab` and Flutter's page names `app.aab` in that folder [1][3]: use the path the tool prints. This revision means the tree was clean before and after, at that commit. In a session with no shell, the build, `git`, `shasum`, and the bundle reads are the creator's terminal: give the commands, and the creator reports the output.

Check first:

1. `git status --porcelain -- . ':(exclude).app-creators'` prints nothing. If it prints anything, ask for a commit.
2. A version code is taken when an `Upload:` line for it, in any state, has a commit that does not match the current tree, or Step 10's reading lists it with no `Upload:` line on a matching commit. Do not build it: follow **New version code**.
3. Read the newest `Build flutter-appbundle` line. If it says finished and its commit matches the current tree, confirm the file: `shasum -a 256 "<path>"` gives the recorded hash. Then reuse it. A different hash means that file is not this build: treat it as gone. If the file is gone, an `Upload:` line for this version code on the current commit sends the run to Step 10's resume rules first; otherwise build again with the same version code.
4. A line with no `finished` is a build that did not end, or is still running in this session. If it is running, wait. Otherwise build again.

Run, default `flutter build appbundle` [1]:

1. Write to the notes: `Build flutter-appbundle: commit <git rev-parse HEAD>, clean tree at build time, <date>`.
2. Clear old output. If `git check-ignore -q build/app/outputs/bundle` exits 0, run `rm -rf build/app/outputs/bundle`. If it exits 1, stop: the folder is not ignored. The fix is `/build/` in `.gitignore`, as the `flutter create` template has [5], in a commit. Any other exit is a git error [17]: stop and show it. Flutter takes the first `.aab` it finds in a folder named for the build mode [3], so a leftover file could stand in for this build. With the folder clear, a file after the build is this build's.
3. `flutter build appbundle`. A non-zero exit: show the first error, write no `finished`, and use Troubleshooting.
4. `git status --porcelain -- . ':(exclude).app-creators'` again. **If it prints anything, this bundle is not this revision.** See **A dirty tree after a build**.
5. Add to the same line: `; finished, clean tree after build, bundle <path>, sha256 <hash>`.

**A dirty tree after a build.** The build runs Flutter's Android migrators and `pub get` first [3][6], and either can write a tracked file, such as an `android/` Gradle file or `pubspec.lock`. Write to the notes at once: `Dirty build: commit <sha>, files <each path>, <date>`. Show the files and the diff, and ask the creator to commit them. Then `SKILL.md` Step 5, then Step 8 again with the same version code: nothing was uploaded. If the next build dirties a file a `Dirty build` line already names, stop and show both.

**New version code.** A project edit, so a commit before the build. Ask the creator for every version code listed under All app bundles for this package. Raise `+n` in `pubspec.yaml` above all of them and above every version code in an `Upload:` line, check that `defaultConfig` still reads `flutter.versionCode`, show the diff, and ask the creator to commit. Then `SKILL.md` Step 5, then Step 8.

**Choice: no `--build-number`.** The flag overrides `pubspec.yaml` with no edit, so the revision would stay put [1]. With it, one commit could mean two bundles with two version codes, and only a notes line would say which.

Alternative: Gradle, through Android Studio, as Flutter's release FAQ describes [1]. Run `flutter build apk --config-only` first, so `android/local.properties` holds the version from `pubspec.yaml` [3][4]. Then open `android/` in Android Studio, Build, Generate Signed Bundle / APK, Android App Bundle, the `release` build type, with a destination folder outside this repo [8]. Write the line as `Build studio-bundle`. The creator reports the file's path; run steps 4 and 5 on it.

## Step 9: the bundle

Run on the bundle path from the `Build` line:

```sh
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/@package
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/@android:versionName
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/@android:versionCode
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/uses-sdk/@android:targetSdkVersion
keytool -printcert -jarfile "<aab>"
```

bundletool comes from Google's GitHub releases as `bundletool-all-<version>.jar`; the latest on 2026-11-03 was 1.18.3 [11]. Flutter's page sends you to the same repository [1]. The creator downloads it and gives its path; this skill downloads nothing. `java` is the one `flutter doctor -v` names [1]. With no bundletool, the alternative in `references/target-api.md`.

The first three must equal the release identity, read from the project at the build's commit; on any difference, stop and show both. The target goes to `references/target-api.md`.

`keytool -printcert -jarfile` prints the signer's certificate [13]. Read it as seen on 2026-11-03:

- `Not a signed jar file`, with exit 0: unsigned. Stop: Step 6 is not done.
- `Owner:` holding `CN=Android Debug`: signed with the debug key, which the template uses until Step 4's edit [5]. Stop: Google Play does not accept it [8]. After the signing edit, Flutter's page says `flutter clean` may be needed [1]: run it, then Step 8.
- `SHA256:` differs from an `Upload key:` line in the notes: stop and show both. Every upload must be signed with the same upload key (`references/app-signing.md`). With no such line, and no bundle yet in Play Console, write `Upload key: SHA-256 <fingerprint>, from version code <n>, <date>`. With no line and an app that has bundles, ask for the upload key certificate's SHA-256 on the app signing page in Play Console [12] with Step 10's reading, before any upload.

Write the readings on the `Build` line.

Fix for a low target: `targetSdk = flutter.targetSdkVersion` follows the Flutter release. It is 36 in the stable branch's source on 2026-11-03 [2], and in Flutter 3.44.0 on the machine that wrote this. Upgrade Flutter, or replace the value with an integer [1], and work through Android's behavior changes for each version passed [10]. A Step 4 commit, then Step 5 and Step 8, with the same version code: nothing was uploaded.

## Step 10: upload

Every upload, first and later, is the creator's, in Play Console. Google requires the first one there [15], and this route uses no API.

Read first, as `SKILL.md` Step 10 says: ask the creator for All app bundles for this version code. That message asks only for the reading.

Ask, and stop, only after the reading came back: "In Play Console, open the app, Test and release, Testing, Internal testing, and click Create new release. On a first release, keep the Google-generated app signing key. Under App bundles, upload `<bundle path>`. Check that the version code it shows is `<version code>`. Then click **Save as draft**, not Next, and tell me the version code you saw, or the error." [14] Write the `Upload:` line before sending this ask. Save as draft reaches no one [14].

**The `Upload:` line.** Before each attempt: `Upload: google_play <package> <version name> (<version code>), commit <commit>, bundle <path>, sha256 <hash>, started <date>`. Append `; finished <date>` when the creator reports the version code under App bundles, or `; failed <date>: <first error line>`. A new line per attempt, and a line's state is the last one written. If the creator reports an upload you did not see, write the line from that report at that moment, with `commit unknown` if they cannot name it. An unknown commit matches nothing.

**Resume rules.** Read All app bundles for this package by version code (`references/statuses.md`):

- Listed, with an `Upload:` line for this version code on a commit that matches the current tree: uploaded. Append `finished` if the line has none, and skip.
- Listed with no such line: this version code holds another binary. It is taken: **New version code**.
- An `Upload:` line for this version code whose commit does not match the current tree, in any state: **New version code**. Raising is always safe.
- Not listed, the newest line `started`: ask whether that upload finished, failed, or is still in the browser. Still running or unknown: wait and read again. Then, still not listed: upload again, after `shasum` shows the same file.
- Not listed, after `failed`: show the error. A fix in Play Console: upload again. A fix in the project is a commit, so the line's commit no longer matches: **New version code**.
- Not listed, after `finished`: wait and read again once; then upload again.

Uploading again under one version code cannot add a second binary: "You can't upload an APK to the Play Store with a versionCode you have already used for a previous version" [9]. That page says APK; this route reads it as true for bundles too, because Google requires a higher version code for every update [16]. A retry refused for a used version code means it is taken: **New version code**.

## Never use

| flag or setting | what it does | why not |
|---|---|---|
| `flutter build appbundle --build-number`, `--build-name` | Overrides `pubspec.yaml` for one build [1][6] | The bundle no longer matches the committed identity |
| The template's `signingConfigs.getByName("debug")` on `release` | Signs the release with the debug key [1][5] | Google Play does not accept it [8] |
| `android/key.properties` or a keystore committed | | Flutter's page: keep both out of source control [1]. Step 6's check stops on it |
| `flutter build apk` for the upload | Builds APKs [1] | This route uploads the app bundle Google Play prefers [1] |
| fastlane `upload_to_play_store` or `supply` with its defaults | Uploads to `production` as `completed` [18] | Reaches the public with no yes, and skips Step 10's check |
| Gradle Play Publisher `publish` or `promote` tasks | Uploads, releases as `COMPLETED` by default, or moves a release to another track [20] | Reaches testers or the public with no yes |
| Codemagic `google_play` publishing | Publishes on every build of the workflow [19] | The same. The workflow check stops on it |

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `flutterVersionCode must not be null.` or `flutterVersionCode must be an integer.` | Flutter's Gradle plugin read no integer version code [2] | `version: x.y.z+n` in `pubspec.yaml`, Step 4 |
| `Gradle task bundleRelease failed with exit code <n>` | Flutter's wrapper around the Gradle error [3] | Read the Gradle error above it |
| `Gradle build failed to produce an .aab file.` | Flutter found no bundle in `build/app/outputs/bundle` [3] | Read the build output; build again |
| `Release app bundle failed to strip debug symbols from native libraries.` | Flutter's check on a release bundle [3] | `flutter doctor`, Step 2 |
| An Android toolchain or license line in `flutter doctor` | Setup the creator owns [7] | Step 2 |
| `Not a signed jar file`, or `CN=Android Debug`, from `keytool -printcert` | Step 6 or the Step 4 signing edit is missing | Step 9's signer rules |
| Upload refused for a version code already used | A version code cannot be used twice [9] | **New version code** |

## Sources

All fetched with curl and read 2026-11-03. The lines marked "seen 2026-11-03" ran on copies of `todo-flutter` and `todo-kotlin` in a temporary folder, with Flutter 3.44.0 and Android Studio's JDK 21.

1. Build and release an Android app, Flutter (page last updated 2026-09-10, reflects Flutter 3.47): https://docs.flutter.dev/deployment/android
2. `FlutterExtension.kt`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt
3. `gradle.dart`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/android/gradle.dart
4. `gradle_utils.dart`, Flutter source, stable branch, `updateLocalProperties`: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/android/gradle_utils.dart
5. `flutter create` templates, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/templates/app/android.tmpl/.gitignore , https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/templates/app/android-kotlin.tmpl/app/build.gradle.kts.tmpl , and https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/templates/app/.gitignore.tmpl
6. `flutter build appbundle --help`, `flutter build apk --help`, and `flutter create --help`, Flutter 3.44.0, read 2026-11-03.
7. Set up Android development, Flutter (page last updated 2026-06-08): https://docs.flutter.dev/platform-integration/android/setup
8. Sign your app, Android Developers (last updated 2026-03-06): https://developer.android.com/studio/publish/app-signing
9. Version your app, Android Developers (last updated 2025-08-20): https://developer.android.com/studio/publish/versioning
10. Meet Google Play's target API level requirement, Android Developers: https://developer.android.com/google/play/requirements/target-sdk
11. bundletool, Android Developers (last updated 2026-08-28): https://developer.android.com/tools/bundletool , and the latest release, Google, GitHub: https://api.github.com/repos/google/bundletool/releases/latest
12. Use Play App Signing, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9842756?hl=en
13. keytool, Java SE 21 documentation, Oracle: https://docs.oracle.com/en/java/javase/21/docs/specs/man/keytool.html
14. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
15. Edits, Google Play Developer API (last updated 2025-12-18): https://developers.google.com/android-publisher/edits
16. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
17. git-check-ignore, Git documentation: exit 0 ignored, 1 not ignored, 128 a fatal error: https://git-scm.com/docs/git-check-ignore
18. upload_to_play_store, fastlane: https://docs.fastlane.tools/actions/upload_to_play_store/
19. Publish to Google Play, Codemagic: https://docs.codemagic.io/yaml-publishing/google-play/
20. Gradle Play Publisher README, Triple-T, GitHub: https://raw.githubusercontent.com/Triple-T/gradle-play-publisher/master/README.md
21. Events that trigger workflows, GitHub: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
22. CI/CD YAML syntax reference, GitLab: https://docs.gitlab.com/ci/yaml/
23. Orchestrate workflows, CircleCI: https://circleci.com/docs/guides/orchestrate/workflows/
24. Starting builds automatically, Codemagic: https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/
25. Build triggers, Bitrise: https://docs.bitrise.io/en/bitrise-ci/run-and-analyze-builds/build-triggers.html
26. Removing sensitive data from a repository, GitHub Docs: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
