# Target API level check

Step 9 of `SKILL.md`. One number read from the built bundle, compared with one number Google states. No script: the route file names the command. Bracketed numbers point to `## Sources`.

## Google Play's requirement today

Google's definitions: a **new app** is not yet published on Google Play; an **app update** is a new version you submit for review to replace your existing app [1].

| app type | new apps and app updates must target | since | source |
|---|---|---|---|
| phone and tablet (this skill's scope) | Android 16, API level 36, or higher | August 31, 2026 | [1][2] |
| Wear OS, Android Automotive OS | API level 35 or higher | August 31, 2026 | [1] |
| Android TV, Android XR | API level 34 or higher | August 31, 2026, in the page's summary | [1] |

The extension Google offered ran to November 1, 2026 [1]. That date has passed on this file's check date, so this skill offers no extension.

An existing app below API level 35 stays installed for its users, but new users on devices running a newer Android than its target cannot find or install it [1]. This is about an app already live. It does not let a new upload through.

Exception: permanently private apps restricted to one organization [1]. Out of this skill's scope.

## What Play does with a lower target

Google: "When you upload an APK, it must meet Google Play's target API level requirements" [2], and "When you upload an app bundle, it must meet target API level requirements for Google Play" [3]. New apps and app updates must target the level above "to be submitted to Google Play" [1]. No page read gives the exact error text or says whether a refused upload uses up its version code. So a lower target stops before upload: fixing it after costs a new build either way.

## How to read it

The route file runs the read on the bundle the build produced, never on a project file: the app's manifest is merged with the manifests of its libraries during the build [5], and Gradle can set the value outside the manifest file [2].

- Default: `bundletool`, on the `.aab`:

  ```sh
  java -jar <bundletool jar> dump manifest --bundle=<file>.aab --xpath=/manifest/uses-sdk/@android:targetSdkVersion
  ```

  `dump manifest` and `--xpath` are bundletool's own [4]. On 2026-11-03 this exact form printed `37` on `todo-kotlin`'s release bundle, run with bundletool 1.18.3. The same run printed the identity: `--xpath=/manifest/@package` gave the package, `/manifest/@android:versionCode` the version code, and `/manifest/@android:versionName` the version name. The example in bundletool's own help, `--xpath=/manifest/@versionCode`, printed nothing on that bundle, so use the `android:` forms. bundletool is downloaded from Google's GitHub releases [4]; this skill installs nothing. A machine with no bundletool goes to the alternative.
- Alternative, on an APK only: `apkanalyzer manifest target-sdk <file>.apk` [6]. It needs the Android SDK command-line tools. The Expo default route builds an `.aab`, so this applies only where a route builds an APK of the same commit.
- With no tool and no shell: ask the creator for a reading in Android Studio. Build, Analyze APK, select the `.aab`, open `AndroidManifest.xml`, and report `android:targetSdkVersion` in `<uses-sdk>`. Android Studio's APK Analyzer opens app bundles and shows the merged manifest as XML [5]. Ask with the step's other readings, never alone in a human-only step's message.

## Compare

| reading | do this |
|---|---|
| at or above the row for this app type | Pass. Write `Target API: <n> read from <file> at commit <commit>, requires <m>` in the notes. |
| below it | Stop before upload. Say the number read, the number required, and Google's date. Fix: the route file's target SDK setting, then a new build from Step 8 |
| no reading: no tool, no shell, and no Android Studio reading | Say "target API level unknown". Say what Google states above: an upload below the requirement does not meet it. Continue only after the creator says to, and restate it in every go-ahead block's `Target API:` line |

A new app uses the new apps column; an update uses the app updates column. Today both columns hold the same number [1], so the type matters only when Google changes one.

Recheck the source on any run past the next August 31: Google has set this requirement for August 31 each year on the page read [1].

## Sources

All fetched with curl and read 2026-11-03.

1. Target API level requirements for Google Play apps, Play Console Help: https://support.google.com/googleplay/android-developer/answer/11926878?hl=en
2. Meet Google Play's target API level requirement, Android Developers (last updated 2026-10-28): https://developer.android.com/google/play/requirements/target-sdk
3. Create and set up your app, Play Console Help: https://support.google.com/googleplay/android-developer/answer/9859152?hl=en
4. `DumpCommand.java` and `README.md`, bundletool, Google, GitHub: https://raw.githubusercontent.com/google/bundletool/master/src/main/java/com/android/tools/build/bundletool/commands/DumpCommand.java and https://raw.githubusercontent.com/google/bundletool/master/README.md
5. Analyze your build with the APK Analyzer, Android Developers: https://developer.android.com/studio/debug/apk-analyzer
6. apkanalyzer, Android Developers (last updated 2026-03-05): https://developer.android.com/tools/apkanalyzer
