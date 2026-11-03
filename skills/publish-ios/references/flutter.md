# Flutter route

The Flutter route of `publish-ios`. `SKILL.md` holds the steps; this file holds the commands. No build service exists here: the build runs on the creator's Mac, the build number lives in the project, and nothing but notes and the file on disk records a build. Bracketed numbers point to `## Sources`.

**Scope.** A `pubspec.yaml` with Flutter and an `ios/` folder holding `ios/Runner.xcodeproj` [9]. With no `ios/` folder this route has nothing to build. Stop and ask: "This Flutter project has no iOS project. Run `flutter create --platforms=ios .` in your own terminal, read the diff, and commit it. Tell me when it finishes." [11]

**Install.** Xcode and Flutter are the creator's to install. This skill installs neither.

## Step 2: Mac, Xcode, Flutter, and Apple Account

No build service account exists on this route. Step 2 is the build machine instead. A Mac is required [1], and with no Xcode the skill stops here.

Login check, all three:

1. `xcodebuild -version` exits 0 and prints Xcode 26 or later (the toolchain line in Step 8). With Command Line Tools alone it exits non-zero: `xcode-select: error: tool 'xcodebuild' requires Xcode`, seen in the slice G fixture run.
2. `flutter doctor` reports Xcode without errors [3].
3. The creator reports an Apple Account in Xcode, under Xcode, Settings, Accounts [20]. No tool here reads that, so write the report in the notes and do not ask again. `flutter build ipa` needs it, because `-allowProvisioningUpdates` requires a developer account added in Xcode [7][26].

Ask, and stop: "This route builds on your Mac. Install or update the full Xcode and Flutter yourself, then in Xcode choose Settings, Accounts and add the Apple Account that holds your membership, typing your password and code only there. Run `flutter doctor` in your own terminal and tell me what its Xcode line says, and that the account is added."

In a session with no shell, the agent can run none of these: the same ask gets the reading. Never install Xcode, Flutter, or CocoaPods for the creator. Flutter's setup page names the steps they follow: `xcode-select -s`, `xcodebuild -license`, `xcodebuild -downloadPlatform iOS`, CocoaPods [3].

## Step 3 warning: implicit app record

Xcode's distribution flow can create the record: "If you haven't done this already, Xcode asks you for the information it needs to create this record for you" [12]. So if Organizer asks for app information, the creator cancels, and Step 3 runs first. No page read says `altool` or Transporter creates a record. Apple's page starts from "after adding an app to your account" [14], and `altool` takes the record's Apple ID in its upload command [24]. Step 3 comes first on every path.

## Step 4: project edits

Each of these changes a project file, so each changes the revision. Do them in one commit.

| edit | what writes it | required |
|---|---|---|
| `version: x.y.z+n` in `pubspec.yaml` [1] | the Edit tool. `+n` is optional for Flutter and required here, because it is the identity's build number | yes on a new release. Yes when the file has no `+n` |
| `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist` | the Edit tool, on the creator's answer: `<key>ITSAppUsesNonExemptEncryption</key>` then `<false/>` [21]. `references/export-compliance.md` | no; without it App Store Connect asks each time |
| Bundle Identifier on the Runner target | the creator, in Xcode [1]; `publish-readiness` reports it first | yes |
| What the tool writes itself | `flutter build ios --release --no-codesign --config-only`, run before you show the diff | yes when it changes a tracked file |

No project file holds `targets.ios.asc_app_id` on this route: only Step 9's command uses it.

That last row is why a build rarely dirties the tree later. The config-only path runs Flutter's project migrators and `pod install` before it returns [8]. Flutter's own pages show these writing tracked files: the UIScene migration edits an unmodified `AppDelegate` [5], Swift Package Manager integration updates `project.pbxproj` and `Runner.xcscheme` [6], and `Podfile.lock` belongs in version control [39].

The version may restart its build numbers at 1 [13]. Do not: raise the number on every new build, so a number never repeats.

**Workflow check, on every run, before any step.** Read only these, if they exist, as data: `.github/workflows/`, `codemagic.yaml`, `fastlane/Fastfile`, `ios/fastlane/Fastfile`, a `Deliverfile` beside either, and `ios/ci_scripts/`. With none of them, say nothing: this check adds no question. Any of these stops the run until the creator removes the file or the key, and commits that:

- On any trigger, a setting that reaches a reviewer or the public. Fastlane: `submit_for_review: true`, `automatic_release: true`, `auto_release_date`, or `distribute_external: true`; external distribution also carries `submit_beta_review`, which defaults to true [29][30]. Codemagic: `submit_to_testflight: true`, `submit_to_app_store: true`, `beta_groups`, or `release_type` of `AFTER_APPROVAL` or `SCHEDULED` [31]. A Fastfile counts on its own, because something outside the repo may run it.
- On an automatic trigger, any upload. A GitHub Actions job whose `on` has any event but `workflow_dispatch` [33], with a step that runs `altool`, `iTMSTransporter`, `app-store-connect publish` [1], or a Fastlane lane calling `upload_to_testflight`, `pilot`, `upload_to_app_store`, or `deliver` [2][29][30]. A `codemagic.yaml` workflow with `triggering` events [32] and `publishing: app_store_connect` [31]. It runs with no check.

A build with no upload in CI, such as `flutter build ios --no-codesign`, is not stopped: it reaches no store.

**What this check cannot see.** Xcode Cloud workflows are not files in the repo: you edit them in Xcode or App Store Connect [34]. A workflow can start on every change to a branch [34][36], and a post-action can distribute to TestFlight testers, where external testing is subject to beta app review, or upload a version you can submit [34][38]. `ios/ci_scripts/` with `ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, or `ci_post_xcodebuild.sh` shows use [2][35]; its absence proves nothing. The same holds for any service configured on its own site, such as Bitrise or Appcircle [2].

So when `ios/ci_scripts/` exists, the next store reading of this session, never Step 1's ask, also asks: "In App Store Connect, open this app's Xcode Cloud tab. Does any workflow have a start condition and a TestFlight or App Store post-action? Tell me its name." On yes, stop until the creator deactivates it, in Manage Workflows or in that tab [37].

## Release identity

| part | where it comes from |
|---|---|
| store | `app_store` |
| app id | `targets.ios.asc_app_id`, the Apple ID in App Store Connect App Information |
| version | `pubspec.yaml`, `version`, before the `+` [1] |
| build number | `pubspec.yaml`, `version`, after the `+` [1] |

Both are complete before the build. Then the `.ipa` must confirm them, because other things can set the number: `--build-number` [1], the Identity section in Xcode [1], a literal in `Info.plist`, or the export.

```sh
d="$(mktemp -d)"; unzip -q build/ios/ipa/<name>.ipa -d "$d"; plutil -extract CFBundleVersion raw -o - "$d"/Payload/*.app/Info.plist; plutil -extract CFBundleShortVersionString raw -o - "$d"/Payload/*.app/Info.plist; plutil -extract CFBundleIdentifier raw -o - "$d"/Payload/*.app/Info.plist
```

An `.ipa` holds `Payload/<app>/Info.plist` [9], and `plutil -extract <key> raw` prints the value [27]. `flutter build ipa` also prints a Version Number and Build Number, but it reads those from the archive, before the export [7]. **Only the `.ipa` read confirms the number.** If any value differs from the identity, stop, show both, and upload nothing. Every later check would read the wrong build.

**Reading the store.** No tool in this route gives a version's status, or lists a version's builds. `altool --build-status` reads one delivery's upload, and `--list-apps` reads apps [24]. The App Store Connect API can read builds [23], and this route does not use it: it needs a signed token and hand-written requests, and the steps need no more than the creator's reading. Every store check on this route is the creator's report.

## Minimal checks

```sh
flutter build ios --release --no-codesign --config-only
xcodebuild -showBuildSettings -json -configuration Release -sdk iphoneos -workspace ios/Runner.xcworkspace -scheme Runner
```

The config-only command comes from Flutter's page [2]. `-json` is in no page read [26], and `publish-readiness` already relies on it. From the entry whose `PRODUCT_TYPE` is `com.apple.product-type.application`:

- Bundle id: `PRODUCT_BUNDLE_IDENTIFIER`.
- App name: `CFBundleDisplayName` in the file `INFOPLIST_FILE` names, or `CFBundleName`.
- Version: `pubspec.yaml`, as above.
- Icon: the folder named by `ASSETCATALOG_COMPILER_APPICON_NAME` under `ios/Runner/Assets.xcassets/` exists, and holds the files its `Contents.json` lists.

If `git status` then lists a new change, the tool wrote it: treat it as an uncommitted change that joins Step 4's commit.

With no Xcode, or no shell, the commands cannot run. Report "could not run: no full Xcode here. Step 2 stops the run", and give what the files alone show, marked as not resolved: `pubspec.yaml`, and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

## Step 6: signing

Default: Xcode automatic signing, which Flutter says is sufficient for most apps [1]. Xcode then manages the certificates and profiles [12][28]. Alternative: manual certificates and profiles. Turn off automatic signing, have an Account Holder or Admin create an App Store provisioning profile, download it in Xcode, and choose it [28]. On that path, build with plain `flutter build ipa` in Step 8: Flutter reads the manual settings only for the plist it generates itself [7].

Check: `DEVELOPMENT_TEAM` is not empty on the app entry of the Minimal checks output [8][7]. That shows a team, not a certificate: no project file shows one. A signing error from the first `flutter build ipa` means this step is not done.

Ask, and stop: "Run `open ios/Runner.xcworkspace` in your own terminal. Select the Runner target, then Signing & Capabilities. Turn on Automatically manage signing and choose your team under Team. Choose Add Account if Xcode asks, typing your password and code only there. Tell me when it finishes." [1]

**This moves the revision.** The team is a build setting, `DEVELOPMENT_TEAM` [42], so choosing one changes the project, normally `ios/Runner.xcodeproj/project.pbxproj`. No page read names the file, so go by `git status`. Step 6 comes after Step 5: run `git status --porcelain -- . ':(exclude).app-creators'`. If it prints anything, show the diff and ask the creator to commit it. Then go back to `SKILL.md` Step 5, which reassesses this commit and asks only about what changed. Step 6's check now holds, so the run goes on to Step 7. This happens once: a team already set writes nothing.

## Step 7: App Store Connect API key

`altool` is the tool that takes the key [24]. Transporter and Xcode Organizer use the creator's sign-in instead [1][12][41].

Ask, and stop: "In App Store Connect, open Users and Access, Integrations, App Store Connect API, Team Keys. Generate a key with the App Manager role and download the `.p8`, which downloads only once. Put it at `~/.appstoreconnect/private_keys/AuthKey_<key id>.p8`, outside this repo. In the shell that runs me, set `ASC_KEY_ID` to the key id and `ASC_ISSUER_ID` to the issuer id. Never paste the key here. Tell me when it finishes, or say no key to upload by hand instead." [1][22][24]

`altool` looks for that file name in `./private_keys`, `~/private_keys`, `~/.private_keys`, `~/.appstoreconnect/private_keys`, or `API_PRIVATE_KEYS_DIR` [24]. Never use `./private_keys`, which is inside the repo [22].

Record the names under `provided.publish-ios`: `asc_key_id_env: ASC_KEY_ID` and `asc_issuer_id_env: ASC_ISSUER_ID`, and `asc_key_dir_env: API_PRIVATE_KEYS_DIR` only if the creator set it. These are the names Step 7's check looks for. The key and the issuer id stay out of state and out of the repo.

Check: `xcrun altool --list-providers --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"` succeeds [24]. It reads no build and no status.

With no key at all, Step 9 is the creator's: the Transporter app, or Xcode Organizer. Every store check is the creator's report either way.

## Step 8: build

There is no build record. **The proof is a notes line plus the file.** Finished means `flutter build ipa` exited 0 and left `build/ios/ipa/<name>.ipa` [1]. This revision means the tree was clean before and after, at that commit. A resume finds the notes line, checks the file's hash, and reads the `.ipa` again.

Check first:

1. `git status --porcelain -- . ':(exclude).app-creators'` prints nothing. If it prints anything, ask for a commit.
2. A build number in an `Invalid Binary` line in the notes, or that the store shows as Invalid Binary, is taken: follow **New build number**, below.
3. Read the newest `Build ...` line in the notes. If it says finished, and its commit matches the current tree, confirm the file: `shasum -a 256 <path>` [40] gives the recorded hash, and the `.ipa` read gives the recorded identity. Then reuse it. If the file is gone, go to Step 9's reading: listed means nothing to rebuild, and not listed means build again with the same number.
4. A line with no `finished` is a build that did not end, or is still running in this session. If it is running, wait, and do not start another. Otherwise build again.

Run, default `flutter build ipa`:

1. Write to the notes: `Build flutter-ipa: commit <git rev-parse HEAD>, clean tree at build time, <date>`.
2. Close off a changed number. Apple says the preset distribution methods update the build number, and the Custom path has a "Manage version and build number" setting [12][13]. `xcodebuild -help` prints the export options [26], no page read lists them or their defaults, and Flutter's generated plist sets only `method` and `uploadBitcode` [7]. So run `xcodebuild -help`. If it lists `manageAppVersionAndBuildNumber`, use the Write tool to create this file in a new temp directory, outside the project, and pass it. If it does not, or on manual signing, run plain `flutter build ipa`; the `.ipa` read below is then the only guard.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
```

```sh
flutter build ipa --export-options-plist=<temp>/ExportOptions.plist
```

`--export-options-plist` is documented [1][11], and `app-store-connect` is what Flutter sends for an App Store export on Xcode 15.4 or later [7].

Then, in this order:

3. `git status --porcelain -- . ':(exclude).app-creators'` again. **If it prints anything, this `.ipa` is not this revision.** See **A dirty tree after a build**.
4. The `.ipa` read in Release identity. A difference stops here.
5. Add to the same notes line: `; finished, clean tree after build, version <version>, build <build number>, ipa <path>, sha256 <hash>`.

**A dirty tree after a build.** The tools wrote tracked files, such as `ios/Podfile`, `ios/Podfile.lock`, `project.pbxproj`, or `Package.resolved` [5][6][39][43][44]. The revision moved. Show the files and the diff, and ask the creator to commit them. Then `SKILL.md` Step 5, then Step 8 again, with the same build number: nothing was uploaded, so it is still free [1]. If the next build dirties the same files again, stop and show both diffs. No page read covers a build that never settles, so do not loop.

**New build number.** `SKILL.md` Step 13 sends recovery to Step 8, and Step 8 needs a clean tree, so the number has to be a commit first. It is a project edit. Raise `+n` in `pubspec.yaml` above every number the creator's reading lists under this version, show the diff, and ask the creator to commit. The revision moved: go to `SKILL.md` Step 5, then Step 6's and Step 7's checks hold, then Step 8 builds it. A number is taken when any of these holds:

- It is in an `Invalid Binary` line. Apple says resolve and redeliver [14].
- Step 9's reading lists this version and number, and no finished `Build` line with that number has a commit matching the current tree.
- A revision that is not current sends Step 13 to Step 8, and the store already lists the number. "Each upload requires a unique build number" [1].

A failed upload does not take it: `references/statuses.md`. Before any upload, the number can be reused [1].

**Choice: no `--build-number`.** The flag overrides `pubspec.yaml` with no edit, so the revision would stay put [1]. It looks like the easy way out of an Invalid Binary. It is not used, because the spec's identity is read from the project. With the flag, the same commit could mean two builds, and only a notes line would say which.

Alternative: Xcode archive. Run the config-only command first, so Xcode gets the `pubspec.yaml` values [2]. Then `open ios/Runner.xcworkspace`, Product, Archive [12]. Or open the `build/ios/archive/<name>.xcarchive` that `flutter build ipa` made [1]. Step 9's alternative uploads it. The same notes line applies, with `flutter-archive` and the creator's report of the version and build Organizer shows; there is no `.ipa` to hash.

Toolchain: Apple requires apps built with Xcode 26 or later using an iOS 26 SDK, since April 28, 2026 [15]. Apps must target iOS 13 or later since September 9, 2026 [15]. From April 2027 they must be built with the iOS 27 SDK and target iOS 15 or later [16]. The current release is Xcode 27.2, on macOS Tahoe 26.6 or later [17][18]. Flutter's own floor is lower, at Xcode 15 with 16 recommended [10], so Apple's line decides. Flutter 3.47 supports iOS 15 to 27 [4], though its release page still says 13 [1]. With Xcode 27, an app that does not adopt the UIScene life cycle will not launch [5][19]. Flutter 3.41 and later migrates an unmodified `AppDelegate`, and a custom one needs the manual steps [5].

## Step 9: upload

Default: `altool`. **This uploads a build. It does not submit for App Review.** Read the store first, as `SKILL.md` Step 9 says: ask the creator to open Apps, this app, TestFlight, Builds, iOS, and report whether this version and build number are listed, with the status. A listed number with no matching finished `Build` line is **New build number**, not a reason to skip.

```sh
xcrun altool --upload-package <ipa> --platform ios --apple-id <targets.ios.asc_app_id> --bundle-id <bundle id> --bundle-version <build number> --bundle-short-version-string <version> --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --wait --output-format json
```

These are the flags of the current `altool` man page, read from a mirror dated 2025-06-23, because no Xcode is on the machine that wrote this [24]. Apple's and Flutter's pages show older forms: `--upload-app`, `--type`, `--apiKey`, `--apiIssuer` [1][14][25]. If the command rejects a flag, read `man altool` on the creator's machine and follow it. `--wait` returns at status PROCESSING [24], which is not Step 9's proof: the creator's TestFlight reading is.

Apple emails when processing ends, and Flutter's page says within 30 minutes [1][14].

Alternative, and the path with no key: the creator uploads by hand. Transporter: open the app, sign in, and drag in the `.ipa` [1][41]. Xcode Organizer: open the archive, then Distribute App, **Custom**, App Store Connect, Upload, with "Manage version and build number" off and "TestFlight internal testing only" off [12]. Never a preset: see Never use.

**Step 10.** This route has no group option. Use App Store Connect, per `references/testflight.md`.

## Step 12: metadata tool

This route names none. The creator pastes from the worksheet. `altool --app-store-text` can upload store text [24]; the skill does not use it. Screenshots are as `store-listing` says: Fastlane `snapshot` is its alternative on `xcode` routes only.

## Never use

| flag or setting | what it does | why not |
|---|---|---|
| `flutter build ipa --build-number`, `--build-name` | Overrides `pubspec.yaml` for one build [1] | The build no longer matches the committed identity |
| Organizer's **TestFlight & App Store** preset | Updates the build number in the archive, among its defaults [12] | The uploaded number differs from the identity, so every later check reads the wrong build |
| "Manage version and build number" on, in Custom | "Allows Xcode to update the build number" [12] | The same |
| Organizer's **TestFlight Internal Only**, or "TestFlight internal testing only" | Restricts the build to your team [12]. It cannot go to customers (`references/testflight.md`) | A build that must reach App Review never can |
| An export option that uploads directly (Upload as the destination, in `xcodebuild -help`) [12][26] | Uploads during the export | It skips Step 9's check |
| Fastlane `submit_for_review`, `automatic_release`, `auto_release_date` [30] | Submits for App Review, or releases on approval | Reaches a reviewer or the public with no yes. The workflow check stops on it |
| Fastlane `distribute_external`, with `submit_beta_review` defaulting to true [29] | Sends the build to external testers, and to beta review | The same |
| Fastlane `deliver`, `upload_to_app_store` | Uploads metadata, screenshots, and an `.ipa` [30] | Step 12 is the creator's paste, with its own checks, and it skips Step 9's check |
| Codemagic `submit_to_testflight`, `submit_to_app_store`, `beta_groups`, `release_type` [31] | Submits or releases after publishing, in post-processing | The same |
| Xcode Cloud post-action to external TestFlight testers, or to App Store upload [34][38] | Reaches beta app review, or skips Step 9 | The same. Lives outside the repo |
| `./private_keys` for the key [24] | The tool would find it there | It is inside the repo [22] |

`references/release.md` holds the App Store Connect settings to the same effect.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `Application not configured for iOS` | Seen in the slice G fixture run on `todo-flutter`, on a machine with Command Line Tools only, after `pub get`. Flutter throws this when it has no iOS app package: no `ios/` project, or no bundle id it can resolve [7][9]. Which one it was here is unconfirmed: no full Xcode was available to compare | Run Step 2's check first. With a full Xcode and the message still there, confirm `ios/Runner.xcodeproj` exists and read `PRODUCT_BUNDLE_IDENTIFIER` |
| `Expected ios/Runner.xcodeproj but this file is missing.` | Flutter's source [9] | The Scope line above |
| `xcode-select: error: tool 'xcodebuild' requires Xcode` | Command Line Tools alone. Seen in the slice G fixture run | Step 2 |
| `"--export-options-plist" is not compatible with "--export-method"` | Flutter's source [7] | Drop `--export-method` |
| `exportArchive` fails on provisioning profiles, on manual signing | Flutter's source falls back to a plain plist when it finds no matching profile [7] | Check the profile from Step 6, or give `--export-options-plist` with the signing keys `xcodebuild -help` lists |
| The app does not launch on iOS 27 | No UIScene life cycle, on Xcode 27 [5][19] | Flutter's migration guide [5] |
| Upload refused for a number already used | "Each upload requires a unique build number" [1]. No page read gives the error text | **New build number** |
| Organizer asks for app information | It would create the record [12] | Cancel, and run Step 3 |

## Sources

All fetched with curl and read 2026-11-03. No full Xcode is on the machine that wrote this, so no Xcode command here has run, and `xcodebuild -help` was not read.

1. Build and release an iOS app, Flutter (page dated 2026-07-31): https://docs.flutter.dev/deployment/ios
2. Continuous delivery with Flutter: https://docs.flutter.dev/deployment/cd
3. Set up iOS development, Flutter: https://docs.flutter.dev/platform-integration/ios/setup
4. Supported deployment platforms, Flutter (page dated 2026-09-22): https://docs.flutter.dev/reference/supported-platforms
5. UISceneDelegate adoption, Flutter: https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
6. Swift Package Manager for app developers, Flutter: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers
7. `build_ios.dart`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/commands/build_ios.dart
8. `mac.dart`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/ios/mac.dart
9. `application_package.dart`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/ios/application_package.dart
10. `xcode.dart`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/macos/xcode.dart
11. `flutter build ipa --help` and `flutter create --help`, Flutter 3.44.0, read 2026-11-03.
12. Distributing your app for beta testing and releases, Apple: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
13. Preparing your app for distribution, Apple: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution
14. Upload builds, and App build statuses, Apple: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/ and https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses
15. Upcoming requirements, Apple: https://developer.apple.com/news/upcoming-requirements/
16. Submit your apps and games today, Apple: https://developer.apple.com/app-store/submitting/
17. SDKs and system requirements, Apple: https://developer.apple.com/xcode/system-requirements
18. Releases, Apple (Xcode 27.2, October 29, 2026): https://developer.apple.com/news/releases/
19. TN3187, Migrating to the UIKit scene-based life cycle, Apple: https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle
20. Synchronizing code signing identities with your developer account, Apple: https://developer.apple.com/documentation/xcode/sharing-your-teams-signing-certificates
21. ITSAppUsesNonExemptEncryption, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
22. Creating API Keys for App Store Connect API, Apple: https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api
23. Builds, App Store Connect API, Apple: https://developer.apple.com/documentation/appstoreconnectapi/builds
24. altool(1), a mirror of the man page Xcode installs, dated 2025-06-23, read because no Xcode is on the fetch machine: https://keith.github.io/xcode-man-pages/altool.1.html
25. altool(7), the old altool manual, same mirror, dated 9 Nov 2023; it marks `--upload-app` deprecated: https://keith.github.io/xcode-man-pages/altool.7.html
26. xcodebuild(1), same mirror. It documents `-showBuildSettings`, `-allowProvisioningUpdates`, `-exportOptionsPlist`, and that `xcodebuild -help` prints the options. It does not list `-json`: https://keith.github.io/xcode-man-pages/xcodebuild.1.html
27. plutil(1), same mirror: https://keith.github.io/xcode-man-pages/plutil.1.html
28. Create an App Store Connect provisioning profile, Apple: https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile
29. upload_to_testflight, fastlane: https://docs.fastlane.tools/actions/upload_to_testflight/
30. upload_to_app_store, fastlane: https://docs.fastlane.tools/actions/upload_to_app_store/
31. Publish to App Store Connect, Codemagic: https://docs.codemagic.io/yaml-publishing/app-store-connect/
32. Starting builds automatically, Codemagic: https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/
33. Events that trigger workflows, GitHub: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
34. Xcode Cloud workflow reference, Apple: https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference
35. Writing custom build scripts, Apple: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
36. Configuring start conditions, Apple: https://developer.apple.com/documentation/xcode/configuring-start-conditions
37. Developing a workflow strategy for Xcode Cloud, Apple: https://developer.apple.com/documentation/xcode/developing-a-workflow-strategy-for-xcode-cloud
38. Configuring your Xcode Cloud workflow's actions, Apple: https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions
39. Using CocoaPods: https://guides.cocoapods.org/using/using-cocoapods.html
40. shasum, Perl documentation: https://perldoc.perl.org/shasum
41. Transporter User Guide 4.2, Apple: https://help.apple.com/itc/transporteruserguide/en.lproj/static.html
42. Build settings reference, Apple: https://developer.apple.com/documentation/xcode/build-settings-reference
43. `cocoapods.dart`, Flutter source, stable branch: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/macos/cocoapods.dart
44. Adding package dependencies to your app, Apple: https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app
