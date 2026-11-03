# Gradle route (Kotlin)

The Kotlin route of `publish-android`. `SKILL.md` holds the steps; this file holds the commands. No build service exists here: the build runs on the creator's computer with the project's Gradle wrapper, the version code lives in the project, and nothing but the notes and the file on disk records a build. Bracketed numbers point to `## Sources`.

**Scope.** One app module, `app/`, with `app/build.gradle.kts` or `app/build.gradle`, and no `productFlavors`: flavors can override the version and the package [3], and this route builds only the `release` build type. Anything else stops: say what you found. The snippets below are Kotlin DSL; the Groovy forms are on the same pages [1][3].

**Install.** Android Studio, a JDK, and the Android SDK are the creator's to install. This skill installs nothing, accepts no SDK license, and installs no SDK package.

**No store read.** No tool on this route reads Play Console. Every store check is the creator's report.

## Step 2: build machine

No build service account exists on this route. Step 2 is the build machine instead.

Check, both:

1. `./gradlew --version` exits 0. It prints the Gradle version and the JVM it runs on [10].
2. The SDK location is set: `sdk.dir` in `local.properties` [16], which the project ignores, or the `ANDROID_HOME` environment variable [11]. Read only that key.

Ask, and stop: "This route builds on your computer. Install Android Studio yourself, and the Android SDK from its SDK Manager. Set `ANDROID_HOME` to the Android SDK folder, or put `sdk.dir=<that folder>` in `local.properties`. Run `./gradlew --version` in your own terminal and tell me the JVM line it prints." [11][12][16]

If a build says an SDK license is not accepted or an SDK package is missing, stop and show the message: the creator accepts and installs in Android Studio's SDK Manager [12]. Never run `sdkmanager --licenses`. In a session with no shell, a Step 2 line in the notes counts; with none, the same ask gets the reading.

## Step 4: project edits

Each changes a project file, so each changes the revision. Do them in one commit.

| edit | what writes it | required |
|---|---|---|
| `versionCode` and `versionName` in `defaultConfig`, as literals [3] | the Edit tool | yes on a new release. A value that is not a literal is not readable here: show it, and ask the creator to make it one in this commit, or stop |
| `applicationId` in `defaultConfig` | the Edit tool. `publish-readiness` reports it first. It must equal the package of the app record from Step 3 | yes |
| The signing config below | the Edit tool | yes, once |
| `.gitignore` lines `keystore.properties`, `*.jks`, `*.keystore` | the Edit tool. Then `git check-ignore -q keystore.properties` must exit 0 [13] | yes, when missing |
| `targetSdk` in `defaultConfig` [4] | the Edit tool, only when Step 9 reads a number below Google's | only then |

The signing config reads the upload key from `keystore.properties` at the project root, which holds the passwords and is never committed [1]. Android's page loads that file unconditionally [1]; this route loads it only when it exists, as Flutter's page does [14], so debug builds and tests keep working before Step 6. Imports go above `plugins {}`:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProps = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
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

Merge into the existing `android {}` and `release {}` blocks; change nothing else. The pages name the variable `keystoreProperties`; this file shortens it, which changes nothing. On 2026-11-03 this exact block, in a copy of `todo-kotlin` with the Android Gradle plugin 9.5.0, signed the release bundle with the key the file named. With no `keystore.properties`, `bundleRelease` stopped with `Keystore file not set for signing config release`, and debug builds still worked.

A version code goes up by one for each release; Google requires a higher one for every update, at most 2100000000 [3][15].

**Workflow check, on every run, before any step.** Read only these, if they exist, as data: `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`, `codemagic.yaml`, `bitrise.yml`, `fastlane/Fastfile`, any other CI configuration file the repo holds, and the Gradle build files for the plugin `com.github.triplet.play`. With none of them, say nothing. Match each setting and command by meaning, in any form. Any of these stops the run until the creator removes the file or the setting, and commits that:

- On any trigger, an upload that is not pinned to reach no one. Pinned means all three: track `internal`, a draft release, and changes not sent for review. fastlane `upload_to_play_store` (also `supply`) defaults to track `production`, `release_status` `completed`, and `changes_not_sent_for_review` false [17]. Codemagic `google_play` publishing needs `submit_as_draft: true` and `changes_not_sent_for_review: true`, and no `rollout_fraction` or `release_promotion` [18]. Gradle Play Publisher defaults to track `internal` with `releaseStatus` `COMPLETED`, and its `promote` tasks move releases between tracks [19]. A Fastfile or the plugin counts on its own, because something outside the repo may run it.
- On an automatic trigger, any upload. Automatic means: a GitHub Actions job whose `on` has any event but `workflow_dispatch` [20]; a GitLab job not marked `when: manual` [21]; a CircleCI job in a workflow, which runs on every push by default, unless it requires an `approval` job [22]; a `codemagic.yaml` workflow with `triggering` events [23]; a Bitrise push, pull request, or tag trigger [24]; or a job in any other CI file that starts with no manual step.
- Upload means: fastlane `upload_to_play_store` or `supply` [17]; Codemagic `publishing: google_play` [18]; a Gradle Play Publisher `publish` or `promote` task [19]; a `uses:` action whose name or inputs show it uploads to Google Play; or any script that calls the Google Play Developer API [9].

A job that only builds or tests, such as `./gradlew bundleRelease` with no upload, does not stop the run. A CI service set up on its own website, such as Bitrise or Codemagic's workflow editor, is not visible here [18][24].

## Release identity

| part | where it comes from |
|---|---|
| store | `google_play` |
| package | `applicationId` in `defaultConfig` of `app/build.gradle.kts` [3]; confirmed from the bundle in Step 9 |
| version name | `versionName` in `defaultConfig` [3]; confirmed from the bundle |
| version code | `versionCode` in `defaultConfig` [3]; confirmed from the bundle |
| track | `internal` for the upload; after that, the track each step names |

All are complete before the build. A build type can override them [3]: if `release {}` sets `applicationIdSuffix`, `versionNameSuffix`, or a version, show it, and Step 9's read decides.

## Minimal checks

No command resolves these without a build, so report each as read from the files, not resolved. Step 9 reads the built bundle.

- Package and version: the three `defaultConfig` values above.
- App name: `android:label` on `<application>` in `app/src/main/AndroidManifest.xml`; a `@string/<name>` resolves in `app/src/main/res/values/strings.xml`.
- Icon: `android:icon` names `@mipmap/<name>`; files `app/src/main/res/mipmap-*/<name>.*` exist.

## Step 6: upload key

Default: Play App Signing with a Google-generated app signing key, and the creator's own upload key in a keystore outside the repo, which Gradle reads through `keystore.properties` [1][6]. Google: "The key you use to sign your first release becomes your upload key" [1]. `references/app-signing.md` has the first release's setting.

Check, reading no secret:

1. `git ls-files -- keystore.properties '*.jks' '*.keystore'` prints nothing. If it prints anything, stop: a key or its passwords are committed. Ask for no push. A secret in any commit, pushed or not, counts as compromised: GitHub's first step for a committed secret is to revoke or rotate it, and rewriting history may then not be needed [25]. So rotate it: before any upload, a new key; after one, an upload key reset (`references/app-signing.md`). Then the creator removes the file from the index and ignores it, in a commit of those paths. Removing it from history as well is the creator's choice, with the `git-filter-repo` steps on GitHub's page [25]; this skill does not rewrite history.
2. `keystore.properties` exists, and `git check-ignore -q keystore.properties` exits 0. Never read the file.
3. `./gradlew -q :app:signingReport`. The `Variant: release` block shows `Config: release`, a `Store` other than `debug.keystore`, and a `SHA-256` line [1]. Write in the notes `Upload key: SHA-256 <fingerprint>, from signingReport, <date>`, never the `Store` path, which holds a home folder. Seen 2026-11-03 on the Android Gradle plugin 9.5.0: with no `keystore.properties`, the release block shows no store and the command exits 1.

Ask, and stop: "Create your upload key in your own terminal, outside this project: `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`. It asks for passwords and your name; type them only there. Then create `keystore.properties` in the project root with four lines: `storePassword=`, `keyPassword=`, `keyAlias=upload`, and `storeFile=` with the keystore's full path. Never paste a password here, and never commit the file or the keystore. Tell me when it finishes." [1][2][7]

`keytool` prompts for the passwords when none are given [7], so the creator runs it. Android asks for a key valid at least 25 years [1]; 10,000 days is about 27. Keep a backup of the keystore and its passwords: a lost upload key needs Google's reset [1].

Alternative: Android Studio, Build, Generate Signed Bundle / APK, Android App Bundle, then Create new under the key store path, with the passwords typed in that dialog [1]. No properties file; it is also Step 8's alternative. Checks 2 and 3 do not apply: write `Step 6: Android Studio signing, reported <date>`, and Step 9's signer read is the check.

## Step 7: API key

Skip. This route uploads in Play Console every time. The Play Developer API is the documented alternative [8][9]; it needs a Google Cloud project, a service account, and requests this skill does not write, so this skill does not use it.

## Step 8: build

There is no build record. **The proof is a notes line plus the file.** Finished means `./gradlew bundleRelease` exited 0 and left a new `app/build/outputs/bundle/release/app-release.aab`, which is where the 2026-11-03 build of `todo-kotlin` wrote it [2]. This revision means the tree was clean before and after, at that commit. In a session with no shell, the build, `git`, `shasum`, and the bundle reads are the creator's terminal: give the commands, and the creator reports the output.

Check first:

1. `git status --porcelain -- . ':(exclude).app-creators'` prints nothing. If it prints anything, ask for a commit.
2. A version code is taken when an `Upload:` line for it, in any state, has a commit that does not match the current tree, or Step 10's reading lists it with no `Upload:` line on a matching commit. Do not build it: follow **New version code**.
3. Read the newest `Build gradle-bundle` line. If it says finished and its commit matches the current tree, confirm the file: `shasum -a 256 "<path>"` gives the recorded hash. Then reuse it. A different hash means that file is not this build: treat it as gone. If the file is gone, an `Upload:` line for this version code on the current commit sends the run to Step 10's resume rules first; otherwise build again with the same version code.
4. A line with no `finished` is a build that did not end, or is still running in this session. If it is running, wait. Otherwise build again.

Run, default `./gradlew bundleRelease` [2]:

1. Write to the notes: `Build gradle-bundle: commit <git rev-parse HEAD>, clean tree at build time, <date>`.
2. Clear old output. If `git check-ignore -q app/build/outputs/bundle/release` exits 0, run `rm -rf app/build/outputs/bundle/release`. If it exits 1, stop: the folder is not ignored. The fix is `/build` in `app/.gitignore`, in a commit. Any other exit is a git error [13]: stop and show it. With the folder clear, a file after the build is this build's.
3. `./gradlew bundleRelease`. A non-zero exit: show the first error, write no `finished`, and use Troubleshooting.
4. `git status --porcelain -- . ':(exclude).app-creators'` again. **If it prints anything, this bundle is not this revision.** See **A dirty tree after a build**.
5. Add to the same line: `; finished, clean tree after build, bundle app/build/outputs/bundle/release/app-release.aab, sha256 <hash>`.

**A dirty tree after a build.** Write to the notes at once: `Dirty build: commit <sha>, files <each path>, <date>`. Show the files. A tool cache, such as a `.kotlin/` folder, gets an ignore line; anything else, ask what wrote it. Either way, a commit. Then `SKILL.md` Step 5, then Step 8 again with the same version code: nothing was uploaded. If the next build dirties a file a `Dirty build` line already names, stop and show both.

**New version code.** A project edit, so a commit before the build. Ask the creator for every version code listed under All app bundles for this package. Raise `versionCode` above all of them and above every version code in an `Upload:` line, show the diff, and ask the creator to commit. Then `SKILL.md` Step 5, then Step 8.

Alternative: Android Studio, Build, Generate Signed Bundle / APK, Android App Bundle, the `release` build type, with a destination folder outside this repo [1]. Write the line as `Build studio-bundle`. The creator reports the file's path; run steps 4 and 5 on it.

## Step 9: the bundle

Run on `app/build/outputs/bundle/release/app-release.aab`, or the Studio file:

```sh
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/@package
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/@android:versionName
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/@android:versionCode
java -jar "<bundletool jar>" dump manifest --bundle="<aab>" --xpath=/manifest/uses-sdk/@android:targetSdkVersion
keytool -printcert -jarfile "<aab>"
```

bundletool comes from Google's GitHub releases as `bundletool-all-<version>.jar`; the latest on 2026-11-03 was 1.18.3 [5]. The creator downloads it and gives its path; this skill downloads nothing. Use the `java` of the JDK `./gradlew --version` names. With no bundletool, the alternative in `references/target-api.md`.

The first three must equal the release identity, read from the project at the build's commit; on any difference, stop and show both. The target goes to `references/target-api.md`.

`keytool -printcert -jarfile` prints the signer's certificate [7]. Read it as seen on 2026-11-03:

- `Not a signed jar file`, with exit 0: unsigned. Stop: Step 6 is not done.
- `Owner:` holding `CN=Android Debug`: signed with the debug key. Stop: Google Play does not accept it [1][2].
- `SHA256:` differs from the `Upload key:` line: stop and show both. Every upload must be signed with the same upload key (`references/app-signing.md`). With no `Upload key:` line, and no bundle yet in Play Console, write one from this read. With no line and an app that has bundles, ask for the upload key certificate's SHA-256 on the app signing page in Play Console [6] with Step 10's reading, before any upload.

Write the readings on the `Build` line.

Fix for a low target: raise `targetSdk` in `defaultConfig`, and work through Android's behavior changes for each version passed [4]. A Step 4 commit, then Step 5 and Step 8, with the same version code: nothing was uploaded.

## Step 10: upload

Every upload, first and later, is the creator's, in Play Console. Google requires the first one there [9], and this route uses no API.

Read first, as `SKILL.md` Step 10 says: ask the creator for All app bundles for this version code. That message asks only for the reading.

Ask, and stop, only after the reading came back: "In Play Console, open the app, Test and release, Testing, Internal testing, and click Create new release. On a first release, keep the Google-generated app signing key. Under App bundles, upload `<bundle path>`. Check that the version code it shows is `<version code>`. Then click **Save as draft**, not Next, and tell me the version code you saw, or the error." [8] Write the `Upload:` line before sending this ask. Save as draft reaches no one [8].

**The `Upload:` line.** Before each attempt: `Upload: google_play <package> <version name> (<version code>), commit <commit>, bundle <path>, sha256 <hash>, started <date>`. Append `; finished <date>` when the creator reports the version code under App bundles, or `; failed <date>: <first error line>`. A new line per attempt, and a line's state is the last one written. If the creator reports an upload you did not see, write the line from that report at that moment, with `commit unknown` if they cannot name it. An unknown commit matches nothing.

**Resume rules.** Read All app bundles for this package by version code (`references/statuses.md`):

- Listed, with an `Upload:` line for this version code on a commit that matches the current tree: uploaded. Append `finished` if the line has none, and skip.
- Listed with no such line: this version code holds another binary. It is taken: **New version code**.
- An `Upload:` line for this version code whose commit does not match the current tree, in any state: **New version code**. Raising is always safe.
- Not listed, the newest line `started`: ask whether that upload finished, failed, or is still in the browser. Still running or unknown: wait and read again. Then, still not listed: upload again, after `shasum` shows the same file.
- Not listed, after `failed`: show the error. A fix in Play Console: upload again. A fix in the project is a commit, so the line's commit no longer matches: **New version code**.
- Not listed, after `finished`: wait and read again once; then upload again.

Uploading again under one version code cannot add a second binary: "You can't upload an APK to the Play Store with a versionCode you have already used for a previous version" [3]. That page says APK; this route reads it as true for bundles too, because Google requires a higher version code for every update [15]. A retry refused for a used version code means it is taken: **New version code**.

## Never use

| setting or tool | what it does | why not |
|---|---|---|
| Passwords written in `build.gradle.kts` | Android's first example shows them in plain text [2] | They would be committed. Use `keystore.properties` [1] |
| `signingConfig = signingConfigs.getByName("debug")` on `release` | Signs the release with the debug key, as Flutter's template does [14] | Google Play does not accept it [1] |
| A keystore or `keystore.properties` inside the repo and not ignored | | Committed secrets. Step 6's check stops on it |
| fastlane `upload_to_play_store` or `supply` with its defaults | Uploads to `production` as `completed` [17] | Reaches the public with no yes, and skips Step 10's check |
| Gradle Play Publisher `publish` or `promote` tasks | Uploads, releases as `COMPLETED` by default, or moves a release to another track [19] | Reaches testers or the public with no yes |
| Codemagic `google_play` publishing | Publishes on every build of the workflow [18] | The same. The workflow check stops on it |

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `Execution failed for task ':app:validateSigningRelease'` with `Keystore file not set for signing config release` | No `keystore.properties`, or no `storeFile` in it. Seen 2026-11-03, Android Gradle plugin 9.5.0 | Step 6 |
| `./gradlew` reports no SDK location | Neither `sdk.dir` nor `ANDROID_HOME` is set [11] | Step 2 |
| A license or SDK package error | The SDK is the creator's to manage [12] | The creator, in Android Studio's SDK Manager |
| `Not a signed jar file` from `keytool -printcert` | An unsigned bundle | Step 6, then Step 8 |
| Upload refused: signed with the wrong key | The bundle's key is not the upload key Play holds [6] | Sign with the upload key, or request an upload key reset (`references/app-signing.md`) |
| Upload refused for a version code already used | A version code cannot be used twice [3] | **New version code** |

## Sources

All fetched with curl and read 2026-11-03. The Android Gradle plugin lines marked "seen 2026-11-03" ran on a copy of `todo-kotlin` in a temporary folder, with the Android Gradle plugin 9.5.0, Gradle 9.8.2, and Android Studio's JDK 21.

1. Sign your app, Android Developers (last updated 2026-03-06): https://developer.android.com/studio/publish/app-signing
2. Build your app from the command line, Android Developers (last updated 2026-02-26): https://developer.android.com/build/building-cmdline
3. Version your app, Android Developers (last updated 2025-08-20): https://developer.android.com/studio/publish/versioning
4. Meet Google Play's target API level requirement, Android Developers: https://developer.android.com/google/play/requirements/target-sdk
5. bundletool, Android Developers (last updated 2026-08-28): https://developer.android.com/tools/bundletool , and the latest release, Google, GitHub: https://api.github.com/repos/google/bundletool/releases/latest
6. Use Play App Signing, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9842756?hl=en
7. keytool, Java SE 21 documentation, Oracle: https://docs.oracle.com/en/java/javase/21/docs/specs/man/keytool.html
8. Prepare and roll out a release, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859348?hl=en
9. Edits, Google Play Developer API (last updated 2025-12-18): https://developers.google.com/android-publisher/edits
10. Command-line interface, Gradle: https://docs.gradle.org/current/userguide/command_line_interface.html
11. Environment variables, Android Developers: https://developer.android.com/tools/variables
12. Set up Android development, Flutter, the SDK Manager and license steps: https://docs.flutter.dev/platform-integration/android/setup
13. git-check-ignore, Git documentation: exit 0 ignored, 1 not ignored, 128 a fatal error: https://git-scm.com/docs/git-check-ignore
14. Build and release an Android app, Flutter (page last updated 2026-09-10): https://docs.flutter.dev/deployment/android
15. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
16. Configure your build, Android Developers, `local.properties` and `sdk.dir` (last updated 2026-10-28): https://developer.android.com/build
17. upload_to_play_store, fastlane: https://docs.fastlane.tools/actions/upload_to_play_store/
18. Publish to Google Play, Codemagic: https://docs.codemagic.io/yaml-publishing/google-play/
19. Gradle Play Publisher README, Triple-T, GitHub: https://raw.githubusercontent.com/Triple-T/gradle-play-publisher/master/README.md
20. Events that trigger workflows, GitHub: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
21. CI/CD YAML syntax reference, GitLab: https://docs.gitlab.com/ci/yaml/
22. Orchestrate workflows, CircleCI: https://circleci.com/docs/guides/orchestrate/workflows/
23. Starting builds automatically, Codemagic: https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/
24. Build triggers, Bitrise: https://docs.bitrise.io/en/bitrise-ci/run-and-analyze-builds/build-triggers.html
25. Removing sensitive data from a repository, GitHub Docs: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
