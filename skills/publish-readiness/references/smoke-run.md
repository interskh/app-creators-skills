# Smoke run

The check `smoke-run`: the app builds in release configuration and launches on a simulator or emulator without crashing through its first screen. Bracketed numbers point to `## Sources`. It runs on `ios` and `android`. Web has none.

Results:

- `pass`: built in release configuration, launched, and the first screen came up with no crash.
- `fail`: the build failed for a reason in the project, or the app crashed at launch.
- `unknown`: the toolchain is absent, no simulator or emulator exists, or a required step needs the creator. Tell the creator the risk: a release-only crash will first appear for them after the upload, or in review. `unknown` alone does not block a `pass`.

Put the failing command and its first error in `evidence`. A build error about signing is `unknown`, not `fail`: this run does not hold release signing.

## Run in a temp export, never in the project

A prebuild in the project creates native folders. That dirties the tree, and when the folders exist EAS Build skips Prebuild, which changes which config wins [1]. So export the committed code:

```bash
smoke="$(mktemp -d)"
git archive --format=tar HEAD | tar -xf - -C "$smoke"
```

`git archive` writes the tree of the commit [2], so run this step only when the tree is clean; otherwise the export is not what was assessed. Work inside `$smoke`, install dependencies there with `framework.package_manager`, and run the build commands there. Print the temp path for the creator; do not delete anything outside it.

## Expo

| platform | toolchain check | run in the export |
|---|---|---|
| ios | `xcodebuild -version` exits 0. Expo needs a Mac with Xcode installed [3]; Command Line Tools alone fail this check. `xcrun simctl list devices available` lists a device [4] | `npx expo run:ios --configuration Release --device "<simulator>"` [3] |
| android | `java -version` exits 0 and `emulator -list-avds` prints a name [5]. Expo needs Android Studio and Java [3] | `npx expo run:android --variant release --device "<avd>"` [3] |

`--device` takes a name or id and covers virtual devices [3]. With no native folder, `run` executes Prebuild first [3], which is why this stays in the export. These builds are not code-signed for store submission, and Expo says the commands are for testing production-only bugs [3], which is this check's purpose. On a simulator, native error logs pipe to the terminal [3]: read them for a fatal error.

## Flutter

Flutter does not support release mode on a simulator or emulator [6], so the check's definition cannot hold there. Do not run a debug build instead and call it a pass.

| platform | toolchain check | run in the export |
|---|---|---|
| ios | `flutter doctor` reports Xcode without errors [7], `flutter devices` lists a device | `flutter build ios --release` [6][8]. Then, only on a connected physical device, `flutter run --release -d <device>` [6] |
| android | `flutter doctor` reports the Android toolchain without errors [7], `flutter devices` lists a device | `flutter build apk --release` [9]. Then, only on a connected physical device, `flutter run --release -d <device>` [6] |

With no physical device, a successful build leaves `smoke-run` at `unknown`, with evidence that Flutter's release mode cannot launch on a simulator or emulator. A failed build is `fail`. A physical iOS device needs the creator's signing setup [8], so the skill's one message (Step 7) asks the creator to run that step.

## Xcode

| toolchain check | run in the export |
|---|---|
| `xcodebuild -version` exits 0 | `xcodebuild -list` shows the schemes and build configurations [10]. The skill's one message (Step 7) asks the creator to open the exported project in Xcode, set the scheme's Run action **Build Configuration** to Release [11], choose a simulator as the run destination, and choose **Product > Run** [12], then report what the first screen did |

TN2339 shows `-configuration` and `-destination` in `xcodebuild` usage [10], but no Apple documentation fetched covers a command-line install and launch on a simulator, so this route uses Xcode's own path. If the creator does not run it, the check is `unknown`.

## Kotlin

| toolchain check | run in the export |
|---|---|
| `java -version` exits 0, `adb devices` runs [14], `emulator -list-avds` prints a name [5] | `emulator -avd <avd>` [5], then `./gradlew assembleRelease` [13], then `adb install <apk>` [14], then `adb shell am start -W -n <package>/<activity>` [14], with the launcher activity from the manifest. Read `adb logcat -b crash -d` afterwards [15] |

Android requires a release build to be signed before it installs [13]. If the project has no release signing config, the output cannot install on the emulator: the build result stands, and `smoke-run` stays `unknown` with that reason, so on such a project this check can never reach `pass`. Never ask for a keystore password.

JAVA_HOME, when set, decides which JDK Gradle uses on the command line [16].

## Sources

Fetched with curl and read 2026-11-02 (UTC).

1. Continuous Native Generation, Expo: https://docs.expo.dev/workflow/continuous-native-generation/
2. git-archive: https://git-scm.com/docs/git-archive
3. Expo CLI, Compiling: https://docs.expo.dev/more/expo-cli/
4. iOS Simulator, Expo: https://docs.expo.dev/workflow/ios-simulator/
5. Start the emulator from the command line, Android: https://developer.android.com/studio/run/emulator-commandline
6. Flutter's build modes: https://docs.flutter.dev/testing/build-modes
7. Flutter CLI reference, and platform setup: https://docs.flutter.dev/reference/flutter-cli and https://docs.flutter.dev/platform-integration/ios/setup and https://docs.flutter.dev/platform-integration/android/setup
8. Build and release an iOS app, and continuous delivery, Flutter: https://docs.flutter.dev/deployment/ios and https://docs.flutter.dev/deployment/cd
9. Build and release an Android app, Flutter: https://docs.flutter.dev/deployment/android
10. TN2339, Building from the Command Line with Xcode FAQ, Apple (last revised 2017): https://developer.apple.com/library/archive/technotes/tn2339/_index.html
11. Customizing the build schemes for a project, Apple: https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project
12. Running your app on simulated or physical devices, Apple: https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices
13. Build your app from the command line, Android: https://developer.android.com/build/building-cmdline
14. Android Debug Bridge: https://developer.android.com/tools/adb
15. Logcat command-line tool, Android: https://developer.android.com/tools/logcat
16. Java versions in Android builds: https://developer.android.com/build/jdks
