# Xcode route

The Xcode route of `publish-ios`. `SKILL.md` holds the steps; this file holds the commands and the exact asks. No build service exists here: the creator builds on their Mac, the build number lives in the project, and nothing but notes and the exported file records a build. Bracketed numbers point to `## Sources`.

**Scope.** An Xcode project with an iOS app target. `xcodebuild -list` shows the schemes [16]. Below, `<project>` is one of these, and every command and ask uses the same one:

- With a `.xcworkspace` beside the project, such as one CocoaPods made: the workspace, `-workspace <name>.xcworkspace -scheme <scheme>`. Archive it, not the project [22][23]. The `project.xcworkspace` inside a `.xcodeproj` does not count.
- Otherwise: `-project <name>.xcodeproj -scheme <scheme>`. The man page's forms with `archive` and `-destination` take a scheme, on a project with one target too [16].

**A `Package.swift` with no Xcode project has no route yet.** `app-creators` classifies an `executableTarget` as `xcode`, but Apple describes that as executable code, "for example a script" [20]. The bundle id, team, icon, and version are all set on a target in the project editor [2]. No page read shows a standalone package archived for the App Store. Apple's upload list also names Swift Playground [3], which this route does not cover. Stop and ask: "This is a Swift package with no Xcode project, so there is no app to archive yet. In Xcode, choose File, New, Project, make an iOS App project, add this package to it, and commit that. Tell me when it finishes." [21][24]

**Install.** Xcode is the creator's to install. This skill does not install it.

## Step 2: Mac, Xcode, and Apple Account

No build service account exists on this route. Step 2 is the build machine instead, and with no Xcode the skill stops here.

Login check, both:

1. `xcodebuild -version` exits 0 and prints Xcode 26 or later (the toolchain line in Step 8). With Command Line Tools alone it exits non-zero: `xcode-select: error: tool 'xcodebuild' requires Xcode`, seen on a Mac with Command Line Tools only, 2026-11-03.
2. The creator reports an Apple Account in Xcode, under Xcode, Settings, Accounts [9]. No tool here reads that, so write the report in the notes and do not ask again.

Ask, and stop: "This route builds on your Mac. Install or update the full Xcode yourself, then choose Xcode, Settings, Accounts and add the Apple Account that holds your membership, typing your password and code only there. Run `xcodebuild -version` in your own terminal and tell me what it prints, and that the account is added."

In a session with no shell, the agent can run none of these. A Step 2 reading in the notes counts: go to Step 3 unless the creator says the toolchain changed. With no such line, the same ask gets the reading. Never install Xcode for the creator.

## Step 3 warning: implicit app record

Xcode's distribution flow can create the record: "If you haven't done this already, Xcode asks you for the information it needs to create this record for you" [1]. Xcode Cloud setup offers the same [41]. So if Xcode asks for app information, the creator cancels, and Step 3 runs first. No page read says `altool` or Transporter creates a record. Apple's page starts from "after adding an app to your account" [3], and `altool` takes the record's Apple ID in its upload command [14]. Step 3 comes first on every path.

## Step 4: project edits

Each of these changes a project file, so each changes the revision. Do them in one commit.

| edit | what writes it | required |
|---|---|---|
| `MARKETING_VERSION` on the app target, every configuration | the Edit tool in `project.pbxproj`, or the creator under General, Identity [2]. Sets `CFBundleShortVersionString` when `GENERATE_INFOPLIST_FILE` is enabled [11] | yes on a new release |
| `CURRENT_PROJECT_VERSION` on the app target, every configuration | the same. An integer or a floating point number [11]. Sets `CFBundleVersion` when `GENERATE_INFOPLIST_FILE` is enabled [11] | yes when it is empty, or on **New build number** |
| The encryption answer | the Edit tool, on the creator's answer. With `GENERATE_INFOPLIST_FILE = YES`: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;` on the app target, every configuration. It is Apple's build setting "App Uses Non-Exempt Encryption" [11]. With a real `Info.plist`: `<key>ITSAppUsesNonExemptEncryption</key>` then `<false/>` in that file [10]. `references/export-compliance.md` | no; without it App Store Connect asks each time |
| Bundle Identifier | the creator, under Signing & Capabilities [2]; `publish-readiness` reports it first | yes |
| `Package.resolved`, if new or changed | Xcode. Apple says to commit it [24] | yes |

Read a setting back after the edit, from `-showBuildSettings`. If it did not change, an `.xcconfig` or a target value wins: ask the creator to set it under General. With a real `Info.plist`, read its `CFBundleVersion` too. A literal there wins over the setting.

No project file holds `targets.ios.asc_app_id` on this route: only Step 9's command uses it.

The version may restart its build numbers at 1 [2]. Do not: raise the number on every new build, so a number never repeats.

**Workflow check, on every run, before any step.** Read only these, if they exist, as data: `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/config.yml`, `codemagic.yaml`, `fastlane/Fastfile`, a `Deliverfile` beside it, and `ci_scripts/` beside the project. With none of them, say nothing: this check adds no question. Match each setting and command by meaning, in any form: `submit_for_review: true`, `submit_for_review(true)` in a `Deliverfile`, `--submit_for_review` on a command line, and an inline command in a CI step with no Fastfile all count. Any of these stops the run until the creator removes the file or the key, and commits that:

- On any trigger, a setting that reaches a reviewer or the public. Fastlane: `submit_for_review`, `automatic_release`, or `distribute_external` turned on, or `auto_release_date` set; external distribution also carries `submit_beta_review`, which defaults to true [25][26]. Codemagic: `submit_to_testflight: true`, `submit_to_app_store: true`, `beta_groups`, or `release_type` of `AFTER_APPROVAL` or `SCHEDULED` [28]. A Fastfile counts on its own, because something outside the repo may run it.
- On an automatic trigger, any upload. Automatic means: a GitHub Actions job whose `on` has any event but `workflow_dispatch` [30]; a GitLab job not marked `when: manual` [42][43]; a CircleCI job in a workflow, which runs on every push by default, unless it requires an `approval` job [44][45]; a `codemagic.yaml` workflow with `triggering` events [29]; or a script in the `ci_scripts/` folder [32].
- Upload means any of these: `altool --upload-package` or `--upload-app` [14]; `iTMSTransporter -m upload` [37]; `app-store-connect publish` [40]; `xcodebuild -exportArchive` with an export options file whose destination is upload [1][16]; a Fastlane lane or command calling `upload_to_testflight`, `pilot`, `upload_to_app_store`, or `deliver` [25][26]; a `uses:` action whose name or inputs show it uploads to App Store Connect or TestFlight; or `publishing: app_store_connect` in `codemagic.yaml` [28].

These do not stop the run, because they reach no store: `altool --validate-app`, `--list-apps`, `--list-providers`, and `--build-status` [14], and a build or a test with no upload.

**What this check cannot see.** Xcode Cloud workflows are not files in the repo: you edit them in Xcode or App Store Connect [31]. A workflow can start on every change to a branch [31][33], and a post-action can distribute to TestFlight testers, where external testing is subject to beta app review, or upload a version you can submit [31][35]. `ci_scripts/` with `ci_post_clone.sh`, `ci_pre_xcodebuild.sh`, or `ci_post_xcodebuild.sh` shows use [32]; its absence proves nothing. The same holds for any CI service configured on its own site.

So the first store reading of each session, whatever files exist, also asks: "In App Store Connect, open this app's Xcode Cloud tab. Does any workflow have a start condition and a TestFlight or App Store post-action? Tell me its name. If this app has no record yet, or no workflows, say none." It goes with that reading only: never with Step 1's or Step 2's ask, and never as a question of its own. On the first run, Step 1's ask stays alone. On a workflow named, stop until the creator deactivates it, in Manage Workflows or in that tab [34].

## Release identity

| part | where it comes from |
|---|---|
| store | `app_store` |
| app id | `targets.ios.asc_app_id`, the Apple ID in App Store Connect App Information |
| version | `MARKETING_VERSION`, from the app entry of the Minimal checks output [11] |
| build number | `CURRENT_PROJECT_VERSION`, from the same entry [11] |

Both are complete before the build. Then the exported `.ipa` must confirm them, because other things can set the number: a preset in Organizer [1], a real `Info.plist`, or a setting passed on the command line [16].

```sh
d="$(mktemp -d)"; unzip -q "<folder>/<name>.ipa" -d "$d"; plutil -extract CFBundleVersion raw -o - "$d"/Payload/*.app/Info.plist; plutil -extract CFBundleShortVersionString raw -o - "$d"/Payload/*.app/Info.plist; plutil -extract CFBundleIdentifier raw -o - "$d"/Payload/*.app/Info.plist
```

An `.ipa` holds `Payload/<app>/Info.plist` [39], and `plutil -extract <key> raw` prints the value [17]. If any value differs from the identity, stop, show both, and upload nothing. Every later check would read the wrong build.

**Reading the store.** No tool in this route gives a version's status, or lists a version's builds. `altool --build-status` reads one delivery's upload, and `--list-apps` reads apps [14]. The App Store Connect API can read builds [13], and this route does not use it: it needs a signed token and hand-written requests, and the steps need no more than the creator's reading. Every store check on this route is the creator's report.

## Minimal checks

```sh
xcodebuild -showBuildSettings -json -configuration Release -sdk iphoneos <project>
```

`-json` is in no page read [16], and `publish-readiness` already relies on it. The man page's `-showBuildSettings` form names a scheme only with a workspace [16]; if a project rejects `-scheme` here, drop it. From the entry whose `PRODUCT_TYPE` is `com.apple.product-type.application`:

- Bundle id: `PRODUCT_BUNDLE_IDENTIFIER`.
- App name: with `GENERATE_INFOPLIST_FILE` at `YES`, `INFOPLIST_KEY_CFBundleDisplayName` [11]. Otherwise `CFBundleDisplayName` in the file `INFOPLIST_FILE` names. Failing both, `PRODUCT_NAME`.
- Version: `MARKETING_VERSION`.
- Icon: the set named by `ASSETCATALOG_COMPILER_APPICON_NAME` [11] exists in the target's asset catalog, and holds the files its `Contents.json` lists. An Icon Composer `.icon` file cannot be read here: say so.

Two causes can stop this command, and they read differently. If it fails because Xcode is absent, report "could not run: no full Xcode here. Step 2 stops the run". In a session with no shell, report "could not run: this session has no shell". A reading from the creator is what counts then: a Step 2 line in the notes shows whether Xcode exists, and the creator can run the command and report the output when a step needs it, never with Step 1's ask. Either way, give what the files alone show, marked as not resolved: the same settings as text in `project.pbxproj`, and the asset catalog.

## Step 6: signing

Default: Xcode automatic signing. Xcode creates the signing assets when you upload or export [2], and manages the distribution profile [19]. Alternative: manual certificates and profiles. Turn off automatic signing, have an Account Holder or Admin create an App Store provisioning profile, download it in Xcode, and choose it [19].

Check: `DEVELOPMENT_TEAM` is not empty on the app entry of the Minimal checks output [11]. That shows a team, not a certificate: no project file shows one. A signing error from the first archive means this step is not done. In a session with no shell, the check is a reading: a Step 6 line in the notes, or a non-empty `DEVELOPMENT_TEAM` on the app target, read as text in `project.pbxproj`. An empty value there proves nothing, because an `.xcconfig` can set it. With neither, the ask below gets the report.

Ask, and stop: "Open `<workspace or project>` in Xcode. Select the app target, then Signing & Capabilities. Turn on Automatically manage signing and choose your team from the Team menu, typing your password and code only in Xcode if it asks. Tell me when it finishes." [1][2]

**This moves the revision.** The team is a build setting [11], so choosing one changes the project, normally `<name>.xcodeproj/project.pbxproj`. No page read names the file, so go by `git status`. Step 6 comes after Step 5: run `git status --porcelain -- . ':(exclude).app-creators'`. If it prints anything, show the diff and ask the creator to commit it. Then go back to `SKILL.md` Step 5, which reassesses this commit and asks only about what changed. Step 6's check now holds, so the run goes on to Step 7. This happens once: a team already set writes nothing.

## Step 7: App Store Connect API key

`altool` is the tool that takes the key [14]. Transporter and Xcode Organizer use the creator's sign-in instead [1][37].

Ask, and stop: "In App Store Connect, open Users and Access, Integrations, App Store Connect API, Team Keys. Generate a key with the App Manager role and download the `.p8`, which downloads only once. Put it at `~/.appstoreconnect/private_keys/AuthKey_<key id>.p8`, outside this repo. In the shell that runs me, set `ASC_KEY_ID` to the key id and `ASC_ISSUER_ID` to the issuer id. Never paste the key here. Tell me when it finishes, or say no key to upload by hand instead." [12][14][40]

`altool` looks for that file name in `./private_keys`, `~/private_keys`, `~/.private_keys`, `~/.appstoreconnect/private_keys`, or `API_PRIVATE_KEYS_DIR` [14]. Never use `./private_keys`, which is inside the repo [12].

Record the names under `provided.publish-ios`: `asc_key_id_env: ASC_KEY_ID` and `asc_issuer_id_env: ASC_ISSUER_ID`, and `asc_key_dir_env: API_PRIVATE_KEYS_DIR` only if the creator set it. These are the names Step 7's check looks for. The key and the issuer id stay out of state and out of the repo.

Check: `xcrun altool --list-providers --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID"` succeeds [14]. It reads no build and no status.

With no key at all, Step 9 is the creator's: the Transporter app, or Xcode Organizer. Every store check is the creator's report either way.

## Step 8: build

There is no build record. **The proof is a notes line plus the exported file.** Finished means the creator reports the archive and export finished, and the `.ipa` is in the folder they name. This revision means the tree was clean before and after, at that commit. A resume finds the notes line, checks the file's hash, and reads the `.ipa` again. In a session with no shell, the creator runs the commands below and reports the output, as the Current rule in `SKILL.md` says.

Check first:

1. `git status --porcelain -- . ':(exclude).app-creators'` prints nothing. If it prints anything, ask for a commit.
2. A build number in an `Invalid Binary` line in the notes, or that the store shows as Invalid Binary, is taken: follow **New build number**, below.
3. Read the newest `Build ...` line in the notes. If it says finished, and its commit matches the current tree, confirm the file: `shasum -a 256 "<path>"` [36] gives the recorded hash, and the `.ipa` read gives the recorded identity. Then reuse it. A different hash or identity means that file is not this build: do not use it, and treat it as gone. If the file is gone, go to Step 9's reading: listed means nothing to rebuild, and not listed means build again with the same number. A line with `no ipa` has no file to check: ask whether Organizer, Archives still lists that version and build [1]. If so, Step 9's Organizer alternative uploads it. If not, treat it as gone.
4. A line with no `finished` is a build that did not end, or that the creator is still running. Ask, and if it is running, wait. Otherwise build again.

Run, default Xcode archive:

1. Write to the notes: `Build xcode-archive: commit <git rev-parse HEAD>, clean tree at build time, <date>`.
2. Ask, and stop: "Open `<workspace or project>` in Xcode. Choose the scheme `<scheme>` and an iOS device destination, then Product, Archive. When Organizer shows the archive, choose Distribute App, Custom, App Store Connect, Export. Turn off Manage version and build number, and turn off TestFlight internal testing only. Keep Automatically manage signing. Save it in a new, empty folder outside this repo. Tell me the folder's path, and the version and build number Organizer shows." [1]

The export is what gives Step 9 a file to read and to upload: it holds the `.ipa` [40]. Apple says the preset methods update the build number, and that Custom with this setting off leaves it to you [1][2]. Outside the repo keeps the tree clean. A new, empty folder means an `.ipa` there is this build's, not a leftover from an earlier commit with the same unuploaded number. No `.ipa` there means the export did not finish: write no `finished`.

Then, in this order:

3. `git status --porcelain -- . ':(exclude).app-creators'` again. **If it prints anything, this `.ipa` is not this revision.** See **A dirty tree after a build**.
4. The `.ipa` read in Release identity. A difference stops here; if the project holds another value, the fix is in **New build number**.
5. Add to the same notes line: `; finished, clean tree after build, version <version>, build <build number>, ipa <path>, sha256 <hash>`. Write `<path>` with `~` for the home folder, never as an absolute home path: `.app-creators/` gets committed. In a command, `~` becomes `"$HOME/..."`.

**A dirty tree after a build.** Xcode wrote tracked files, such as `project.pbxproj` or `Package.resolved` [24], or Swift Package Manager or CocoaPods did, in `Podfile.lock` [23]. The revision moved. Write to the notes at once: `Dirty build: commit <sha>, files <each path>, <date>`. Show the files and the diff, and ask the creator to commit them. Then `SKILL.md` Step 5, then Step 8 again, with the same build number: nothing was uploaded, so it is still free [40]. If only `xcuserdata` shows, add it to `.gitignore` in that commit, as the `ios/.gitignore` from `flutter create` does (seen 2026-11-03). If the next build dirties a file a `Dirty build` line already names, in this session or a later one, stop and show both diffs. No page read covers a build that never settles, so do not loop. A build that finishes clean ends the matter.

**New build number.** `SKILL.md` Step 13 sends recovery to Step 8, and Step 8 needs a clean tree, so the number has to be a commit first. It is a project edit. Ask the creator for every build number listed under this version, in TestFlight, Builds, iOS: Step 13's reading returns one build. Raise the number above all of them, where the build's value comes from. To see where, read `GENERATE_INFOPLIST_FILE` and `INFOPLIST_FILE` in the same entry of the Minimal checks output, and `CFBundleVersion` in the file `INFOPLIST_FILE` names. With `GENERATE_INFOPLIST_FILE` on and no such key, or with `$(CURRENT_PROJECT_VERSION)` in the file, the setting decides [11]: raise `CURRENT_PROJECT_VERSION`. With a literal in the file, raise that literal and the setting together. Raising the setting alone can leave the `.ipa` at the old number, and the identity check then stops every rebuild. `MARKETING_VERSION` and `CFBundleShortVersionString` work the same way. Read it back, show the diff, and ask the creator to commit. The revision moved: go to `SKILL.md` Step 5, then Step 6's and Step 7's checks hold, then Step 8 builds it. A number is taken when any of these holds:

- It is in an `Invalid Binary` line. Apple says resolve and redeliver [3].
- Step 9's reading lists this version and number, and no finished `Build` line with that number has a commit matching the current tree.
- A revision that is not current sends Step 13 to Step 8, and the store already lists the number. "The build string is used to uniquely identify the build throughout the system" [3].

A failed upload does not take it: `references/statuses.md`. Before any upload, the number can be reused [40].

Alternative: `xcodebuild`, with no Xcode window.

```sh
d="$(mktemp -d)"; echo "$d"
xcodebuild archive <project> -configuration Release -destination generic/platform=iOS -archivePath "$d/app.xcarchive" -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath "$d/app.xcarchive" -exportPath "$d/export" -exportOptionsPlist "<plist>" -allowProvisioningUpdates
```

The man page documents these flags, and they need the account from Step 2 [16][18]. Stop at the first non-zero exit. `mktemp -d` gives a new folder each time, so no older `.ipa` can sit in it. `xcodebuild -help` prints the export options [16], no page read lists them or their defaults, and no Xcode was here to read them. So run `xcodebuild -help`. If it lists `manageAppVersionAndBuildNumber`, set it to false. Use the Write tool to put this file in the temp directory, never in the project:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
```

`app-store-connect` is what Flutter's source sends for an App Store export on Xcode 15.4 or later [38]. On manual signing, add the keys `xcodebuild -help` lists. If the option is not listed, the `.ipa` read is the only guard. Write the notes line with `xcodebuild` in place of `xcode-archive`, and the same steps 3 to 5 apply.

Toolchain: Apple requires apps built with Xcode 26 or later using an iOS 26 SDK, since April 28, 2026 [4]. Apps must target iOS 13 or later since September 9, 2026 [4]. From April 2027 they must be built with the iOS 27 SDK and target iOS 15 or later [5]. The current release is Xcode 27.2, on macOS Tahoe 26.6 or later [6][7]. When built with the latest SDK after iOS 26, a UIKit app that does not use the scene life cycle will not launch [8].

## Step 9: upload

Default: `altool`. **This uploads a build. It does not submit for App Review.** Read the store first, as `SKILL.md` Step 9 says: ask the creator to open Apps, this app, TestFlight, Builds, iOS, and report whether this version and build number are listed, with the status. A listed number with no matching finished `Build` line is **New build number**, not a reason to skip.

```sh
xcrun altool --upload-package "<ipa>" --platform ios --apple-id <targets.ios.asc_app_id> --bundle-id <bundle id> --bundle-version <build number> --bundle-short-version-string <version> --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --wait --output-format json
```

These are the flags of the current `altool` man page, read from a mirror dated 2025-06-23, because no Xcode is on the machine that wrote this [14]. Apple's page shows an older form, with `--upload-app` [3][15]. If the command rejects a flag, read `man altool` on the creator's machine and follow it. `--wait` returns at status PROCESSING [14], which is not Step 9's proof: the creator's TestFlight reading is.

Apple emails when processing ends [3].

Alternative, and the path with no key: the creator uploads by hand. Xcode Organizer: the archive, then Distribute App, **Custom**, App Store Connect, Upload, with "Manage version and build number" off and "TestFlight internal testing only" off [1]. If Step 8 made no `.ipa`, finish its notes line with `; finished, clean tree after build, version <version>, build <build number> as Organizer shows, no ipa`. That is only the creator's report: the store's listing is what confirms the number. A listed number other than the identity stops at Step 9's proof: show both, and that number is now taken, so follow **New build number**. Or Transporter: open the app, sign in, and add the `.ipa` [3][37]. Never a preset: see Never use.

**Step 10.** This route has no group option. Use App Store Connect, per `references/testflight.md`.

## Step 12: metadata tool and screenshots

This route names no metadata tool. The creator pastes from the worksheet. `altool --app-store-text` can upload store text [14]; the skill does not use it.

Screenshots are as `store-listing` says. Its alternative on this route is Fastlane `snapshot`, which runs the app's UI Tests across simulators [27]. It needs a UI Test target and `SnapshotHelper.swift` in the project [27]: those are project edits, in Step 4's commit. Run it only if the creator asks. Point its `output_directory` [27] under `.app-creators/`, so the tree stays clean, and copy each capture to the path `store-listing` names. `deliver` is what uploads them [27], and it is forbidden below.

## Never use

| flag or setting | what it does | why not |
|---|---|---|
| Organizer's **TestFlight & App Store** preset | Updates the build number in the archive, among its defaults [1] | The uploaded number differs from the identity, so every later check reads the wrong build |
| "Manage version and build number" on, in Custom | "Allows Xcode to update the build number" [1] | The same |
| Organizer's **TestFlight Internal Only**, or "TestFlight internal testing only" | Restricts the build to your team [1]. It cannot go to customers (`references/testflight.md`) | A build that must reach App Review never can |
| `xcodebuild ... CURRENT_PROJECT_VERSION=<n>` or `MARKETING_VERSION=<v>` | Overrides the setting for one build [16] | The build no longer matches the committed identity |
| An export option that uploads directly (Upload as the destination, in `xcodebuild -help`) [1][16] | Uploads during the export | It skips Step 9's check |
| Fastlane `submit_for_review`, `automatic_release`, `auto_release_date` [26] | Submits for App Review, or releases on approval | Reaches a reviewer or the public with no yes. The workflow check stops on it |
| Fastlane `distribute_external`, with `submit_beta_review` defaulting to true [25] | Sends the build to external testers, and to beta review | The same |
| Fastlane `deliver`, `upload_to_app_store` | Uploads metadata, screenshots, and an `.ipa` [26] | Step 12 is the creator's paste, with its own checks, and it skips Step 9's check |
| Codemagic `submit_to_testflight`, `submit_to_app_store`, `beta_groups`, `release_type` [28] | Submits or releases after publishing, in post-processing | The same |
| Xcode Cloud post-action to external TestFlight testers, or to App Store upload [31][35] | Reaches beta app review, or skips Step 9 | The same. Lives outside the repo |
| `./private_keys` for the key [14] | The tool would find it there | It is inside the repo [12] |

`references/release.md` holds the App Store Connect settings to the same effect.

## Troubleshooting

| symptom | cause | fix |
|---|---|---|
| `xcode-select: error: tool 'xcodebuild' requires Xcode` | Command Line Tools alone. Seen 2026-11-03 | Step 2 |
| The project has only `Package.swift` | No app target exists [20] | The Scope section above |
| `-showBuildSettings` returns several application entries | The project has several app targets | Choose the scheme that builds this app, per `xcodebuild -list` [16] |
| The app does not launch on iOS 27 | A UIKit app with no scene life cycle, built with the latest SDK [8] | TN3187 [8] |
| Upload refused for a number already used | The build string identifies a build uniquely [3]. No page read gives the error text | **New build number** |
| Xcode asks for app information during distribution | It would create the record [1] | Cancel, and run Step 3 |

## Sources

All fetched with curl and read 2026-11-03. No full Xcode is on the machine that wrote this, so no Xcode command here has run, and `xcodebuild -help` was not read.

1. Distributing your app for beta testing and releases, Apple: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
2. Preparing your app for distribution, Apple: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution
3. Upload builds, and App build statuses, Apple: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/ and https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses
4. Upcoming requirements, Apple: https://developer.apple.com/news/upcoming-requirements/
5. Submit your apps and games today, Apple: https://developer.apple.com/app-store/submitting/
6. SDKs and system requirements, Apple: https://developer.apple.com/xcode/system-requirements
7. Releases, Apple (Xcode 27.2, October 29, 2026): https://developer.apple.com/news/releases/
8. TN3187, Migrating to the UIKit scene-based life cycle, Apple: https://developer.apple.com/documentation/technotes/tn3187-migrating-to-the-uikit-scene-based-life-cycle
9. Synchronizing code signing identities with your developer account, Apple: https://developer.apple.com/documentation/xcode/sharing-your-teams-signing-certificates
10. ITSAppUsesNonExemptEncryption, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
11. Build settings reference, Apple: https://developer.apple.com/documentation/xcode/build-settings-reference
12. Creating API Keys for App Store Connect API, Apple: https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api
13. Builds, App Store Connect API, Apple: https://developer.apple.com/documentation/appstoreconnectapi/builds
14. altool(1), a mirror of the man page Xcode installs, dated 2025-06-23, read because no Xcode was on the machine these were written on: https://keith.github.io/xcode-man-pages/altool.1.html
15. altool(7), the old altool manual, same mirror, dated 9 Nov 2023; it marks `--upload-app` deprecated: https://keith.github.io/xcode-man-pages/altool.7.html
16. xcodebuild(1), same mirror. It documents `-list`, `-showBuildSettings`, `-allowProvisioningUpdates`, `-exportArchive`, `-exportOptionsPlist`, `generic/platform=iOS`, settings on the command line, and that `xcodebuild -help` prints the options. It does not list `-json`: https://keith.github.io/xcode-man-pages/xcodebuild.1.html
17. plutil(1), same mirror: https://keith.github.io/xcode-man-pages/plutil.1.html
18. TN2339, Building from the Command Line with Xcode FAQ, Apple (last revised 2017): https://developer.apple.com/library/archive/technotes/tn2339/_index.html
19. Create an App Store Connect provisioning profile, Apple: https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile
20. Creating a standalone Swift package with Xcode, Apple: https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode
21. Creating an Xcode project for an app, Apple: https://developer.apple.com/documentation/xcode/creating-an-xcode-project-for-an-app
22. Managing multiple projects and their dependencies, Apple: https://developer.apple.com/documentation/xcode/managing-multiple-projects-and-their-dependencies
23. Using CocoaPods: https://guides.cocoapods.org/using/using-cocoapods.html
24. Adding package dependencies to your app, Apple: https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app
25. upload_to_testflight, fastlane: https://docs.fastlane.tools/actions/upload_to_testflight/
26. upload_to_app_store, fastlane: https://docs.fastlane.tools/actions/upload_to_app_store/
27. snapshot, fastlane: https://docs.fastlane.tools/actions/snapshot/
28. Publish to App Store Connect, Codemagic: https://docs.codemagic.io/yaml-publishing/app-store-connect/
29. Starting builds automatically, Codemagic: https://docs.codemagic.io/yaml-running-builds/starting-builds-automatically/
30. Events that trigger workflows, GitHub: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
31. Xcode Cloud workflow reference, Apple: https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference
32. Writing custom build scripts, Apple: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
33. Configuring start conditions, Apple: https://developer.apple.com/documentation/xcode/configuring-start-conditions
34. Developing a workflow strategy for Xcode Cloud, Apple: https://developer.apple.com/documentation/xcode/developing-a-workflow-strategy-for-xcode-cloud
35. Configuring your Xcode Cloud workflow's actions, Apple: https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions
36. shasum, Perl documentation: https://perldoc.perl.org/shasum
37. Transporter User Guide 4.2, Apple: https://help.apple.com/itc/transporteruserguide/en.lproj/static.html
38. `build_ios.dart`, Flutter source, stable branch, the only page read that names an export `method` value: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/commands/build_ios.dart
39. `application_package.dart`, Flutter source, stable branch, the only page read that gives the `.ipa` layout: https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/lib/src/ios/application_package.dart
40. Build and release an iOS app, Flutter, for the export folder, reusing a number before upload, the App Manager key role, and `app-store-connect publish`: https://docs.flutter.dev/deployment/ios
41. Configuring your first Xcode Cloud workflow, Apple: https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow
42. CI/CD YAML syntax reference, GitLab: https://docs.gitlab.com/ci/yaml/
43. CI/CD pipelines, GitLab: https://docs.gitlab.com/ci/pipelines/
44. Configuration reference, CircleCI: https://circleci.com/docs/reference/configuration-reference/
45. Orchestrate workflows, CircleCI: https://circleci.com/docs/guides/orchestrate/workflows/
