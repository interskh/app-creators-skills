# Readiness checks

What `scripts/check-readiness.py` decides, the rule behind each check, and how to fix a `FAIL`. Bracketed numbers point to `## Sources`. A check the script cannot decide is `UNKNOWN`, never `PASS`.

**The rule: every `PASS` needs an authoritative input.** Authoritative inputs are data formats the tools themselves consume or emit: JSON, plist, Android manifest XML, HTML, a web manifest, image files, and the framework's own resolved output passed with `--resolved`, plus `.app-creators/state.md`, this skill family's own data file. Anything else is `UNKNOWN`. The script does not read a `.pbxproj`, an `.xcconfig`, a Gradle file, or a JS or TS config, because only a compiler or a build system can evaluate them. A native project with no resolved input gives `UNKNOWN` for the affected checks, neither `FAIL` nor `PASS`.

## Checks

| id | platforms | `PASS` means | `FAIL` when |
|---|---|---|---|
| `app-name` | all | a non-empty name is readable from an authoritative input | the name is empty, or a config route, `static`, or Flutter web project has none. `UNKNOWN` instead for native iOS with no resolved settings, native Android with `android:label` missing and no built manifest confirming it, Vite with no linked manifest name and no non-empty `<title>`, Next.js with no `name` in `app/manifest.json` or `app/manifest.webmanifest`, and Expo beside a local config plugin |
| `bundle-id` | ios | the id uses only A-Z, a-z, 0-9, hyphens, and periods [1], with no empty segment | the id is missing, has another character, or has an empty segment. Native iOS with no resolved settings, and Expo beside a local config plugin, give `UNKNOWN` |
| `package` | android | two or more segments, each starting with a letter, using only letters, digits, and underscores [2] | the id is missing or breaks that rule. A native project with no built manifest, and Expo beside a local config plugin, give `UNKNOWN` |
| `icon-sizes` | ios | a 1024x1024 App Store icon exists [4][5], and every listed icon file has the size its entry names | the icon is missing or a size is wrong. Native iOS with no resolved settings gives `UNKNOWN` |
| `icon-sizes` | android | the launcher icon resolves to files with the sizes below | the icon's files are missing, a size is wrong, or a built manifest confirms `android:icon` is missing. With no built manifest, a missing `android:icon` is `UNKNOWN`, and so is an adaptive icon that lacks `<foreground>` or `<background>` |
| `icon-sizes` | web | every icon the project declares exists with an image extension and at least one byte, and a PNG or WebP matches its declared `sizes` | a declared file is missing, a size differs, or nothing is declared on a static or Flutter web project. Vite and Next.js with nothing declared give `UNKNOWN`: a JS or TS config may set it |
| `icon-alpha` | ios | the App Store icon PNG has no alpha channel and no `tRNS` chunk | Expo config route only: PNG colour type 4 or 6, or a `tRNS` chunk [6]. Native routes give `UNKNOWN`; see below |
| `permission-strings` | ios | every declared `NS*UsageDescription` is non-empty, every detected API has its key, and every source file was read. The line states its scope: declared permissions and the known API patterns the table lists, not a claim that the app needs no permission | a string is empty, or an API in code has no string. Native iOS with no resolved settings gives `UNKNOWN` |
| `permissions-declared` | android | every detected API's permission is declared, and every source file was read; the line lists declared dangerous permissions [8]. It states the same scope. The data inventory step remains the judgment | a permission is removed, or a built manifest does not hold it, for an API in code. With no built manifest, an undeclared one is `UNKNOWN` on native routes, because a library can supply it |
| `privacy-policy-url` | all | see below | see below |

The script exits 0 when nothing fails, so `UNKNOWN` alone exits 0. It exits 1 on any `FAIL`, and 2 on a usage or environment error. One line reports every gap the check found, each with its fix.

## Rules

**Reading project files.** Every read goes through one helper: it opens without blocking, requires a regular file, requires the real path to stay inside the project, and stops at a size limit (16 MB, 2 MB for a scanned source file). A FIFO, a device, a directory, a symlink out of the project, or an oversized file gives `UNKNOWN` for the checks that depend on it. Image headers come from a 2 MB prefix, and PNG chunks are walked only to `IDAT`, so a large real icon still works; metadata that pushes `IDAT` past the prefix is `UNKNOWN`. XML that declares entities is not parsed. A path outside the project is `UNKNOWN` whether or not the file exists, so the output does not reveal which outside files exist. More than 1000 declared icons is `UNKNOWN`. A `--resolved` file is the operator's own: it must be regular and within the limit, may sit outside the project, and otherwise exits 2.

**Printing project values.** Every name, id, path, key, permission, URL, and file name is printed in double quotes, with embedded quotes and backslashes escaped, Unicode categories Cc, Cf, Cs, Zl, and Zp dropped, and anything over 80 characters truncated with a marker. Each check prints one line.

**Where config comes from.** Xcode and Flutter on iOS read resolved Xcode settings. Kotlin and Flutter on Android read `src/main/AndroidManifest.xml` and `res`, and a built manifest for what it holds. Expo reads the app config, except that a real native project wins when it is not ignored: Expo Build will not run Prebuild for a project that has `android` and `ios` directories, and it does run Prebuild when they are listed in `.gitignore` or `.easignore` [9]. A real native project means `ios/*.xcodeproj` or `android/app/build.gradle(.kts)`; an empty folder does not win. When `.easignore` exists, EAS CLI uses it instead of `.gitignore` [3], so only that file is read. `ios`, `/ios`, `ios/`, `/ios/`, `ios/*`, `/ios/*`, `ios/**`, and `/ios/**` all count as ignoring the folder, and the same forms for `android`. A line starting with `!` that names the folder is not interpreted, so that platform's route is `UNKNOWN`.

**Resolved inputs.** `--resolved <file>` repeats, and each file is classified by content. A JSON array whose entries carry a `buildSettings` object is Xcode settings. A JSON object is an Expo config when it holds an `expo` object or a string `slug`; `npx expo config --json` prints the config with `slug` always set [68][69]. XML with the root `manifest` and a `package` attribute is a built Android manifest; XML that declares entities is refused. Anything else, including `{}`, a copy of `package.json`, and a source manifest with no `package`, an unreadable file, or two files of one kind exits 2. A kind that does not apply to the project is unused.

| input | command | used for |
|---|---|---|
| Expo config | `npx expo config --json` | a dynamic `app.config.js` or `app.config.ts` |
| Xcode settings | `xcodebuild -showBuildSettings -json -configuration Release -sdk iphoneos` with `-project`, or `-workspace` and `-scheme` [62], from the real project. Flutter first runs `flutter build ios --release --no-codesign --config-only` [63] | iOS on Xcode, Flutter, and Expo with a real `ios/` |
| Android manifest | `apkanalyzer manifest print <apk>` [64] or `bundletool dump manifest --bundle=<aab>` [65], on a release built from the current commit | `package`, `permissions-declared`, and a literal `android:label` on Kotlin, Flutter, and Expo with a real `android/` |

**Xcode settings.** The script picks the one entry whose `PRODUCT_TYPE` is `com.apple.product-type.application`; none or several is `UNKNOWN`. `CONFIGURATION` other than `Release` or `PLATFORM_NAME` other than `iphoneos` is `UNKNOWN`, because a debug or simulator resolve is not the release truth. `SRCROOT` absent or not inside the project is `UNKNOWN`, because that output came from another checkout. Non-string settings are ignored. `SRCROOT` is then the root for the plist and the icon walk. `INFOPLIST_FILE` joins to it and goes through the bounded reader, so a path outside the project is `UNKNOWN`. `$(VAR)` and `${VAR}` in a value expand from the same settings only; anything else, including a modifier such as `$(VAR:rfc1034identifier)` and any `$` left after expansion such as `$PRODUCT_NAME`, is `UNKNOWN`. `INFOPLIST_KEY_*` counts only when `GENERATE_INFOPLIST_FILE` is `YES`, because the build uses those keys only then [60]. With resolved settings a missing name, id, or icon set is `FAIL`. `ASSETCATALOG_COMPILER_APPICON_NAME` holding `/` or `..` is `UNKNOWN`. An `.appiconset` counts only inside a folder ending `.xcassets`. Name order: `CFBundleDisplayName`, `INFOPLIST_KEY_CFBundleDisplayName`, `CFBundleName`, `PRODUCT_NAME`. Id order: `PRODUCT_BUNDLE_IDENTIFIER`, `CFBundleIdentifier`.

**Android package.** The source is the `package` attribute in the manifest of a built release artifact. Build configuration overrides the source manifest, and a build type can add an id suffix [66][67]; the script reads no Gradle file. No documented command prints the resolved id without building: `apkanalyzer manifest application-id` also needs an APK [64], and the Merged Manifest view is in Android Studio [66]. `android:debuggable` set to anything but `false` on the artifact's `<application>` is `UNKNOWN`, because a debug artifact may carry a suffix and is not the release truth. Creator confirmation is not a `PASS` input: the creator can read the id in Gradle, and the line stays `UNKNOWN` until an artifact exists.

**iOS icon set.** The current Xcode default is a single 1024x1024 image that generates the other sizes [4]. Older sets list each size, with the App Store icon in the iOS 1,024pt well [4]. Both pass. A set that fills only the App Store well and leaves its listed `iphone` or `ipad` wells empty is `UNKNOWN`: no source was found that says this is enough. A variant marked with `appearances` is skipped for alpha, because Apple asks for a dark icon with a transparent background [4].

**Icon Composer.** A `.icon` file replaces the asset catalog, and Xcode renders the sizes at build time [10]. Its output cannot be read from project files, so `icon-sizes` and `icon-alpha` are `UNKNOWN`. Check the built app.

**Alpha rule, source quality.** No current Apple page fetched states an alpha rule for a bitmap App Store icon [7]. So on native routes (Xcode, Flutter, Expo with a native `ios/`), a PNG with an alpha channel or `tRNS` chunk is `UNKNOWN`, with the advice to validate the archive in Xcode, and one with neither is `PASS`. A WebP's alpha is not read, so it is `UNKNOWN` everywhere.

**Expo and alpha.** Expo's documentation says the icon must have no transparent pixels [6], so the Expo config route fails an alpha channel. Expo's prebuild removes transparency from the light and tinted icons by filling with white [11]; the script still fails, because a white fill silently changes the icon. An opaque RGBA file also fails; re-export it without alpha.

**Android launcher sizes.** Bitmaps scale from their base size by density: mdpi 1x, hdpi 1.5x, xhdpi 2x, xxhdpi 3x, xxxhdpi 4x [12]. A legacy launcher icon has a 48 dp base [13]. Every adaptive layer is 108x108 dp [14][13], so a foreground is 108 px at mdpi and 432 px at xxxhdpi, and a vector layer has `android:width` and `android:height` of `108dp`. An adaptive icon is an `<adaptive-icon>` XML file with `<foreground>` and `<background>`, and optionally `<monochrome>` [14]; a missing `<foreground>` or `<background>` is `UNKNOWN`, because no source says the build tools reject that form. Only the background may be a colour. PNG and WebP sizes come from file headers [15][16][17][18]. Anything the script cannot judge is `UNKNOWN`, never a counted pass: a bitmap with no density qualifier, a launcher or layer that is a `<layer-list>`, `<shape>`, `<bitmap>`, or other drawable, a legacy launcher `<vector>`, an inline `aapt:attr` layer, and a reference that is not `@mipmap` or `@drawable`.

**Android app name and manifest.** A built manifest decides what it holds. `permissions-declared` reads `uses-permission` from it instead of `src/main`, in both directions. `app-name` uses a literal `android:label` from it, including an empty one; a reference such as `@ref/...` or `@string/...` falls back to `src/main`. With no built manifest, `app-name`, `icon-sizes`, and `permissions-declared` read `src/main/AndroidManifest.xml` and `res/`, because manifest XML is authoritative. Other manifests merge into the build, so what `src/main` lacks is not yet missing: a missing `android:label`, `android:icon`, or `<application>`, and an API whose permission is absent, are `UNKNOWN` until a built manifest confirms it, then `FAIL`. A value that is present but bad still fails. A manifest whose `android:debuggable` is anything but `false` is not the release truth, so `package`, `permissions-declared`, and any label or icon gap it would decide are `UNKNOWN`; a reference in it still falls back to `src/main`. A missing `src/main` manifest is `UNKNOWN`, because Gradle can relocate it. `@string/x` is looked up in every `res/values/*.xml`; absent from there is `UNKNOWN`, because a Gradle `resValue` or a flavor can supply it, and a malformed values file met on the way is `UNKNOWN`. A Kotlin project is detected by a `build.gradle` or `build.gradle.kts` plus `src/main/AndroidManifest.xml`, in `app/` or the project root. When no other framework matches, a Gradle file alone, in `app/` or the root, takes the Kotlin route, and `Package.swift` takes the Xcode route; no file content is read, and with no resolved input their lines are `UNKNOWN`. Flutter is a `pubspec.yaml` that holds the text `flutter` or cannot be read.

**Expo icons.** iOS: exactly 1024x1024 [6][19]. Android: an adaptive foreground, or `android.icon`, or top-level `icon`; square and at least 512x512 [6]; an adaptive background image has the same dimensions as the foreground [6]. A monochrome layer only has to be square. A remote URL is `UNKNOWN`. `ios.icon` as a set of `light`, `dark`, and `tinted` variants is `UNKNOWN`: check the built app.

**Web names and icons.** On `static`, `vite`, and Flutter web, the HTML read is `index.html` at the web root, a manifest counts only when that HTML links it with `<link rel="manifest">`, and its name or the `<title>` decides `app-name`. Only `<title>` and `<link>` in the head are read: reading stops at `</head>`, `<body>`, or `<svg>`, and the first title wins. A `<base>` in the head is not resolved: a relative icon or manifest link beside it is `UNKNOWN` on `icon-sizes`, and `<title>` decides `app-name`, or `UNKNOWN` with no title; Flutter's default template carries one. With no name, or an empty title, `vite` is `UNKNOWN`, because a JS or TS config may set it, and `static` and Flutter web `FAIL`. Next.js ignores a root `index.html` and any manifest in `public/` unless source links them, so only `app/manifest.json` or `app/manifest.webmanifest` (or `src/app/`) decide `app-name` and contribute icons, along with the file-convention icons in `app/` (`favicon`, `icon*`, `apple-icon*`). `app/manifest.ts` or `app/manifest.js` is `UNKNOWN` for `app-name` and `icon-sizes`, whatever else exists, and a generated icon (`.ts`, `.tsx`, `.js`, `.jsx`) is `UNKNOWN`. Next.js layouts and `metadata` are not read. `icon-sizes` with nothing declared is `UNKNOWN` on `vite` and `nextjs`, and `FAIL` elsewhere. A declared icon counts by extension only (`.png`, `.webp`, `.ico`, `.svg`, `.jpg`, `.jpeg`, `.gif`, `.avif`); any other extension or an empty file is `UNKNOWN`, also for Expo's `web.favicon`. A remote, `data:`, or build-placeholder icon reference is `UNKNOWN`. Expo web stays on the app config.

**Incomplete scans.** A source file that was skipped for size, a read error, not being a regular file, failing strict UTF-8 decoding, holding a NUL byte, or pointing outside the project makes `permission-strings` and `permissions-declared` `UNKNOWN`, naming the file, unless a detected gap already gives `FAIL`.

**Purpose strings have an Android counterpart only at runtime.** `<uses-permission>` takes a name and an optional maximum SDK; it has no description [20]. Android shows a system prompt, and an app explains itself in its own UI when `shouldShowRequestPermissionRationale()` says to [21]. So `permissions-declared` checks that each detected API's permission is declared, not that a string exists. Dangerous means the protection level `dangerous` in the Android reference [8][22].

**Expo purpose strings.** A string comes from `ios.infoPlist` or the plugin option. Without either, Expo's plugins write a boilerplate string such as "Allow $(PRODUCT_NAME) to access your photos" [23][24], and Expo says those defaults most likely need tailoring to be accepted by the App Store [25]. Apple requires purpose strings that clearly and completely describe the use [26]. So the script fails a detected API with no specific string, even though a build would succeed. A plugin option of `false` deletes the key, including one set in `ios.infoPlist` [24], and fails if the API is used. A config plugin the script does not know, such as a local `./` path, can set a string or permission, so a missing one beside it is `UNKNOWN`, not `FAIL`. A local plugin, a string starting with `.` or `/`, can also rewrite the name and ids, so `app-name`, `bundle-id`, and `package` are `UNKNOWN` beside it.

**Expo app name.** With no `name` in the config, Expo uses `name` from `package.json` (`exp.name ?? pkgName`) [68], and the line says so. With neither, `app-name` is `UNKNOWN`, because Expo then uses the folder name. An explicit empty `name` is `FAIL`, because `??` keeps it. A valid `web.name` decides the web route first.

**Expo Android permissions.** On the config route, most permissions arrive automatically through a library's manifest [25]. Those fail only when removed by `android.blockedPermissions`, by a plugin option of `false`, or by `tools:node="remove"` [19][25][27]. Calendar permissions and background location must be listed by the project [28][29].

**Privacy policy URL.** The script reads `provided.publish-readiness.privacy_policy_url` from `.app-creators/state.md`, in block form with a plain or simply quoted value. An absent key or `provided: {}` is empty. Any other flow map or block scalar on that path is `UNKNOWN`.

| state | ios, android | web |
|---|---|---|
| file missing, unreadable, or in a form above that is not read | `UNKNOWN` | `UNKNOWN` |
| set, http(s) URL | `PASS` | `PASS` |
| set, anything else | `FAIL` | `FAIL` |
| empty | `FAIL` [30][31] | `FAIL` with `--collects-data yes`, `PASS` with `no`, `UNKNOWN` with neither |

## Permission APIs scanned

The table in the script holds only APIs a source below ties to a key or permission. The script scans comment-stripped text and raw text. A row in stripped text may `FAIL`. A row only in raw text is `UNKNOWN` when its key or permission is unsatisfied, and costs nothing when it is satisfied, so a comment-stripping mistake can never give `PASS`. Code in any file outranks a comment in another. A module condition such as `expo-contacts` is checked on the same text the API matched. String and template literals are not comments. `node_modules`, `.git`, `Pods`, `.dart_tool`, `.expo`, `.gradle`, and `.symlinks` are skipped at any depth. `build` and `dist` are skipped only at the scan root, and `build` also beside a `build.gradle` or `build.gradle.kts`.

| framework | files | API | needs |
|---|---|---|---|
| xcode | `.swift`, `.m`, `.mm` | `requestAccess(for: .video)` / `.audio` | `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` [32] |
| | | `PHPhotoLibrary.requestAuthorization` | `NSPhotoLibraryUsageDescription`; `.addOnly` may use `NSPhotoLibraryAddUsageDescription` [33][34] |
| | | `requestWhenInUseAuthorization` | `NSLocationWhenInUseUsageDescription` [35] |
| | | `requestAlwaysAuthorization` | `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationWhenInUseUsageDescription` [35][36] |
| | | `requestAccess(for: .contacts)` | `NSContactsUsageDescription` [37] |
| | | `requestFullAccessToEvents`, `requestWriteOnlyAccessToEvents` | `NSCalendarsFullAccessUsageDescription`; write-only may use `NSCalendarsWriteOnlyAccessUsageDescription` [38] |
| | | `requestFullAccessToReminders` | `NSRemindersFullAccessUsageDescription` [39] |
| | | `evaluatePolicy` | `NSFaceIDUsageDescription` [40] |
| | | `requestTrackingAuthorization` | `NSUserTrackingUsageDescription` [41] |
| | | `SFSpeechRecognizer.requestAuthorization` | `NSSpeechRecognitionUsageDescription` [42] |
| | | `CBCentralManager`, `CBPeripheralManager` | `NSBluetoothAlwaysUsageDescription` [43] |
| | | `CMPedometer`, `CMMotionActivityManager`, `CMSensorRecorder`, `CMMovementDisorderManager` | `NSMotionUsageDescription` [44] |
| flutter | `.dart` | `ImageSource.gallery`, `pickMultiImage`, `pickMedia`, `pickMultipleMedia`, `pickMultiVideo` | `NSPhotoLibraryUsageDescription` [45] |
| | | `ImageSource.camera` | `NSCameraUsageDescription`; `pickVideo` also needs `NSMicrophoneUsageDescription` [45] |
| | | `CameraController(` | `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` [46] |
| | | `LocalAuthentication()` | `NSFaceIDUsageDescription` [47] |
| kotlin; flutter's `android/` | `.kt`, `.java` | `Manifest.permission.X`, `"android.permission.X"` | `<uses-permission>` for X [20] |
| expo | `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`, `.mts`, `.cts` | `launchImageLibraryAsync`, `requestMediaLibraryPermissionsAsync` | `photosPermission`: `NSPhotoLibraryUsageDescription` [23] |
| | | `launchCameraAsync`, `requestCameraPermissionsAsync` | `cameraPermission`: `NSCameraUsageDescription`; Android `CAMERA`, blocked by `false` [23] |
| | | `CameraView`, `useCameraPermissions`, `useMicrophonePermissions`, `requestMicrophonePermissionsAsync` | expo-camera `cameraPermission`, `microphonePermission`; Android `CAMERA`, `RECORD_AUDIO` [48] |
| | | `useAudioRecorder`, `requestRecordingPermissionsAsync` | expo-audio `microphonePermission`; Android `RECORD_AUDIO` [49] |
| | | `requestForegroundPermissionsAsync`, `getCurrentPositionAsync` | `locationWhenInUsePermission`; Android location added by the library [29] |
| | | `requestBackgroundPermissionsAsync` | `locationAlwaysAndWhenInUsePermission`; Android `ACCESS_BACKGROUND_LOCATION` through `isAndroidBackgroundLocationEnabled` [29] |
| | | `getMotionActivityAsync`, `watchMotionActivityAsync` | `motionUsagePermission`: `NSMotionUsageDescription` [29] |
| | | `getContactsAsync`, `Contact.getAll`, `requestPermissionsAsync` in a file naming `expo-contacts` | `contactsPermission`; Android contacts added by the library [50] |
| | | `getCalendarsAsync`, `requestCalendarPermissionsAsync`, `useCalendarPermissions` | `calendarPermission`; Android `READ_CALENDAR`, `WRITE_CALENDAR` listed by the project [28] |
| | | `requestRemindersPermissionsAsync` | `remindersPermission` [28] |
| | | `requestPermissionsAsync`, `usePermissions`, `getAssetsAsync` in a file naming `expo-media-library` | `photosPermission` [51] |
| | | `saveToLibraryAsync` in a file naming `expo-media-library` | `savePhotosPermission` [51] |
| | | `authenticateAsync` in a file naming `expo-local-authentication` | `faceIDPermission` [52] |
| | | `requestTrackingPermissionsAsync`, `useTrackingPermissions` | `userTrackingPermission` [53] |
| | | `Pedometer`, `DeviceMotion` in a file naming `expo-sensors` | `motionPermission` [54] |

## Known limits

- The API table is short by design. An API not in it is not detected, and a third-party plugin is not covered. Flutter has no Dart row for Android: the first-party plugins fetched list no manifest step [45][46], so only Kotlin and Java under `android/` are scanned.
- The photo picker: `PHPickerViewController` gives access without library permission [55], and Expo's sample says no permission request is needed to open the image library [23]. The keys stay required by the table because Expo lists them as used by that module [23], and Flutter's `image_picker` says App Store policy requires the entry even when no permission is requested [45].
- A string's quality is judgment. The script checks that a string exists, and treats Expo's boilerplate as missing. The skill judges the wording.
- `com.example` is not checked. No Google policy or Android page fetched states a store rule against it: Android's application ID page uses it as the example to replace [2], and Android's prepare-for-release page does not name it. On iOS, Flutter's build warning about it is tooling [56].
- Expo's current documentation names `app.json`, `app.config.js`, and `app.config.ts` [57]. `app.config.json` is also read, and when both exist it wins, because `getStaticConfigFilePath` in `@expo/config` tries it first [68].
- A `PASS` on `permission-strings` or `permissions-declared` covers declared permissions and the known API patterns the table lists. It is not a claim that the app needs no permission.
- A project with a Gradle file and `src/main/AndroidManifest.xml` is treated as an app even if it is a library, because Gradle is not read.
- A Vite `root` setting is not read, so `index.html` at the project root is the HTML read.
- A built manifest is not tied to the checkout: no field names the project or commit. Only a manifest built from `HEAD` by Step 6 may be passed.
- An ignored native folder is matched only in the forms listed above. Other globs are not understood, and `!` negation naming the folder is `UNKNOWN`.
- A build variant's manifest, including a release source-set manifest that removes a permission, is not read; only the `main` manifest is.
- The resolved Xcode and Android paths have not run against real tool output. The script's tests use hand-written files of the shape the sources show. `-json` and the `PRODUCT_TYPE` and `PLATFORM_NAME` settings appear in no Apple page fetched. A tool whose output differs fails the classification or a gate, which gives exit 2 or `UNKNOWN`, not `PASS`.
- Any config plugin outside the script's option table gives `UNKNOWN` for a missing string, including first-party plugins that set none, such as `expo-router`.
- Crafted input: known slow patterns are fixed and tested, but no time bound is proven. The script has two backstops. Past 512 MB read in one run, further reads give `UNKNOWN`. Past 120 seconds of wall clock, where the platform has `SIGALRM`, it prints an error to stderr and exits 2, and any check not yet printed has no result. A run that reaches the limit is a failed run, not a clean one.
- An unclosed quote ends at its line, and an unclosed backtick at the end of the file; text in them is kept. An unclosed `/*` runs to the end of the file, so what follows it is raw-only.
- A Dart file naming both `pickVideo(` and `ImageSource.camera` needs the microphone key, even if the two are not one call.
- A linked folder is not followed. If it points outside the project, or at a folder the scan does not reach, the permission check is `UNKNOWN` and names it. Flutter's `.symlinks` is skipped, because it points outside by design.

## Fixes

| check | Expo | Flutter | Xcode | Kotlin | web |
|---|---|---|---|---|---|
| `app-name` | set `expo.name` | iOS: `CFBundleDisplayName` in `ios/Runner/Info.plist`; Android: `android:label` in `android/app/src/main/AndroidManifest.xml` [58][59]; web: `<title>` in `web/index.html` | set Display Name on the app target | set `android:label`, usually `@string/app_name` | `<title>` or `name` in a manifest linked from the HTML; Next.js: a `name` in `app/manifest.json` |
| `bundle-id` | set `ios.bundleIdentifier` | set it on the Runner target in Xcode [58] | set Bundle Identifier on the app target | none | none |
| `package` | set `android.package`; with a native `android/`, set `applicationId` in `android/app/build.gradle(.kts)`, then build | set `applicationId` in `android/app/build.gradle.kts` [59], then build | none | set `applicationId` in `app/build.gradle(.kts)`, then build | none |
| `icon-sizes` | fix the path in `icon`, `ios.icon`, or `android.adaptiveIcon`; export at the required size | replace the files in `ios/Runner/Assets.xcassets/AppIcon.appiconset` [58] and `android/app/src/main/res/mipmap-*` [59] | add the image to the App Icon set | run Image Asset Studio [13] | add the file or correct the declaration |
| `icon-alpha` | re-export `icon` without alpha, on your intended background | re-export the App Store icon without alpha | same as Flutter | none | none |
| `permission-strings` | set the plugin option or `ios.infoPlist` key to a specific reason | add the key to `ios/Runner/Info.plist` [45][46] | add the key to Info.plist or set `INFOPLIST_KEY_<key>` [60] | none | none |
| `permissions-declared` | add to `android.permissions`, or remove the block | add `<uses-permission>` to the manifest | none | add `<uses-permission>` [61] | none |
| `privacy-policy-url` | publish a policy page, then set the field in `.app-creators/state.md` | same | same | same | same, or confirm no data is collected |

## Sources

Fetched with curl and read 2026-11-02 (UTC).

1. CFBundleIdentifier, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleidentifier
2. Set the application ID, Android: https://developer.android.com/build/configure-app-module
3. Ignore files via .easignore, Expo: https://docs.expo.dev/build-reference/easignore/
4. Configuring your app icon using an asset catalog, Apple: https://developer.apple.com/documentation/xcode/configuring-your-app-icon
5. App icons, specifications, Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/app-icons
6. Splash screen and app icon, Expo: https://docs.expo.dev/develop/user-interface/app-icons/
7. Apple pages searched for a bitmap alpha rule, with none found: App icons, Human Interface Guidelines, https://developer.apple.com/design/human-interface-guidelines/app-icons; Configuring your app icon, https://developer.apple.com/documentation/xcode/configuring-your-app-icon; Platform version information, App Store Connect Help, https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information; CFBundleIcons, https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleicons
8. Manifest.permission, Android reference: https://developer.android.com/reference/android/Manifest.permission
9. Continuous Native Generation, Usage with Expo Build, Expo: https://docs.expo.dev/workflow/continuous-native-generation/
10. Creating your app icon using Icon Composer, Apple: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
11. `withIosIcons.ts`, Expo source: https://github.com/expo/expo/blob/main/packages/@expo/prebuild-config/src/plugins/icons/withIosIcons.ts
12. Support different pixel densities, Android: https://developer.android.com/training/multiscreen/screendensities
13. Create app icons, Android Studio, and `withAndroidIcons.ts`, Expo source, which sets the 48 and 108 bases: https://developer.android.com/studio/write/create-app-icons and https://github.com/expo/expo/blob/main/packages/@expo/prebuild-config/src/plugins/icons/withAndroidIcons.ts
14. Adaptive icons, Android: https://developer.android.com/develop/ui/views/launch/icon_design_adaptive
15. PNG specification, W3C: https://www.w3.org/TR/png-3/
16. WebP container specification, Google: https://developers.google.com/speed/webp/docs/riff_container
17. WebP lossless bitstream, Google: https://developers.google.com/speed/webp/docs/webp_lossless_bitstream_specification
18. VP8 data format, RFC 6386: https://www.rfc-editor.org/rfc/rfc6386.txt
19. App config reference, Expo: https://docs.expo.dev/versions/latest/config/app/
20. `<uses-permission>`, Android: https://developer.android.com/guide/topics/manifest/uses-permission-element
21. Request runtime permissions, Android: https://developer.android.com/training/permissions/requesting
22. Permissions on Android, Android: https://developer.android.com/guide/topics/permissions/overview
23. ImagePicker, Expo: https://docs.expo.dev/versions/latest/sdk/imagepicker/
24. `Permissions.ts`, Expo source: https://github.com/expo/expo/blob/main/packages/@expo/config-plugins/src/ios/Permissions.ts
25. Permissions guide, Expo: https://docs.expo.dev/guides/permissions/
26. App Review Guidelines 5.1.1(ii), Apple: https://developer.apple.com/app-store/review/guidelines/
27. `withImagePicker.ts`, Expo source: https://github.com/expo/expo/blob/main/packages/expo-image-picker/plugin/src/withImagePicker.ts
28. Calendar, Expo: https://docs.expo.dev/versions/latest/sdk/calendar/
29. Location, Expo: https://docs.expo.dev/versions/latest/sdk/location/
30. Manage app privacy, App Store Connect Help: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
31. User Data policy, Play Console Help: https://support.google.com/googleplay/android-developer/answer/10144311
32. `requestAccess(for:completionHandler:)`, Apple: https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:)
33. `requestAuthorization(for:handler:)`, Apple: https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)
34. Delivering an Enhanced Privacy Experience in Your Photos App, Apple: https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app
35. `requestWhenInUseAuthorization()`, Apple: https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization()
36. NSLocationAlwaysAndWhenInUseUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationalwaysandwheninuseusagedescription
37. NSContactsUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nscontactsusagedescription
38. NSCalendarsFullAccessUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nscalendarsfullaccessusagedescription
39. NSRemindersFullAccessUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription
40. NSFaceIDUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nsfaceidusagedescription
41. NSUserTrackingUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nsusertrackingusagedescription
42. NSSpeechRecognitionUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nsspeechrecognitionusagedescription
43. NSBluetoothAlwaysUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription
44. NSMotionUsageDescription, Apple: https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription
45. image_picker, flutter.dev: https://pub.dev/packages/image_picker
46. camera, flutter.dev: https://pub.dev/packages/camera
47. local_auth_darwin, flutter.dev: https://pub.dev/packages/local_auth_darwin
48. Camera, Expo: https://docs.expo.dev/versions/latest/sdk/camera/
49. Audio, Expo: https://docs.expo.dev/versions/latest/sdk/audio/
50. Contacts, Expo: https://docs.expo.dev/versions/latest/sdk/contacts/
51. MediaLibrary, Expo: https://docs.expo.dev/versions/latest/sdk/media-library/ and https://docs.expo.dev/versions/latest/sdk/media-library-legacy/
52. LocalAuthentication, Expo: https://docs.expo.dev/versions/latest/sdk/local-authentication/
53. TrackingTransparency, Expo: https://docs.expo.dev/versions/latest/sdk/tracking-transparency/
54. Sensors and Pedometer, Expo: https://docs.expo.dev/versions/latest/sdk/sensors/ and https://docs.expo.dev/versions/latest/sdk/pedometer/
55. PHPickerViewController, Apple: https://developer.apple.com/documentation/photosui/phpickerviewcontroller
56. `build_ios.dart`, Flutter source: https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/build_ios.dart
57. Configure with app config, Expo: https://docs.expo.dev/workflow/configuration/
58. Build and release an iOS app, Flutter: https://docs.flutter.dev/deployment/ios
59. Build and release an Android app, Flutter: https://docs.flutter.dev/deployment/android
60. Build settings reference, Apple: https://developer.apple.com/documentation/xcode/build-settings-reference
61. Declare app permissions, Android: https://developer.android.com/training/permissions/declaring

Read 2026-11-03. Source 60 was read again the same day for `GENERATE_INFOPLIST_FILE`, `INFOPLIST_KEY_*`, `INFOPLIST_FILE`, `SRCROOT`, `CONFIGURATION`, and `ASSETCATALOG_COMPILER_APPICON_NAME`.

62. xcodebuild(1), a mirror of the man page Xcode installs, read because no Xcode is on the fetch machine; it documents `-showBuildSettings`, `-configuration`, `-sdk`, `-project`, `-workspace`, and `-scheme`, and does not list `-json`: https://keith.github.io/xcode-man-pages/xcodebuild.1.html
63. Continuous delivery with Flutter, which shows `flutter build ios --release --no-codesign --config-only`: https://docs.flutter.dev/deployment/cd
64. apkanalyzer, Android: https://developer.android.com/tools/apkanalyzer
65. `DumpCommand.java`, bundletool source, whose help text shows `bundletool dump manifest --bundle=`; the page https://developer.android.com/tools/bundletool does not mention `dump`: https://github.com/google/bundletool/blob/master/src/main/java/com/android/tools/build/bundletool/commands/DumpCommand.java
66. Merge multiple manifest files, Android: https://developer.android.com/build/manage-manifests
67. Configure build variants, Android: https://developer.android.com/build/build-variants
68. `Config.ts`, `@expo/config` source, for `getStaticConfigFilePath` and `ensureConfigHasDefaultValues`: https://github.com/expo/expo/blob/main/packages/@expo/config/src/Config.ts
69. `configAsync.ts`, Expo CLI source, which prints `config.exp` for `npx expo config --json`: https://github.com/expo/expo/blob/main/packages/@expo/cli/src/config/configAsync.ts

Web rules: Web App Manifest `icons` (MDN): https://developer.mozilla.org/en-US/docs/Web/Manifest/Reference/icons; Next.js app icons: https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons; manifest: https://nextjs.org/docs/app/api-reference/file-conventions/metadata/manifest; `src` folder: https://nextjs.org/docs/app/api-reference/file-conventions/src-folder

App Store Connect's App Information page also lists Privacy Policy URL as required for iOS and macOS apps: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
