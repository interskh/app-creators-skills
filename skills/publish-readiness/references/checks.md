# Readiness checks

What `scripts/check-readiness.py` decides, the rule behind each check, and how to fix a `FAIL`. Bracketed numbers point to `## Sources`. The script reports only what project files show. A check it cannot decide is `UNKNOWN`, never `PASS`.

## Checks

| id | platforms | `PASS` means | `FAIL` when |
|---|---|---|---|
| `app-name` | all | a non-empty name is readable | the name is empty or missing |
| `bundle-id` | ios | the id uses only A-Z, a-z, 0-9, hyphens, and periods [1], with no empty segment | the id is missing, has another character, or has an empty segment |
| `package` | android | two or more segments, each starting with a letter, using only letters, digits, and underscores [2] | the id is missing or breaks that rule |
| `icon-sizes` | ios | a 1024x1024 App Store icon exists [4][5], and every listed icon file has the size its entry names | the icon is missing, a size is wrong, or the App Store entry declares no size or anything but 1024x1024 |
| `icon-sizes` | android | the launcher icon resolves to files with the sizes below | the icon is missing or a size is wrong |
| `icon-sizes` | web | every icon the project declares exists, and a PNG or WebP matches its declared `sizes` | a declared file is missing, a size differs, or nothing is declared |
| `icon-alpha` | ios | the App Store icon PNG has no alpha channel and no `tRNS` chunk | Expo config route only: PNG colour type 4 or 6, or a `tRNS` chunk [6]. Native routes give `UNKNOWN`; see below |
| `permission-strings` | ios | every declared `NS*UsageDescription` is non-empty, every detected API has its key, and every source file was read | a string is empty, or an API has no string |
| `permissions-declared` | android | every detected API's permission is declared, and every source file was read; the line lists declared dangerous permissions [8] | a permission is undeclared or removed |
| `privacy-policy-url` | all | see below | see below |

The script exits 0 when nothing fails, so `UNKNOWN` alone exits 0. It exits 1 on any `FAIL`, and 2 on a usage or environment error. One line reports every gap the check found, each with its fix.

## Rules

**Reading project files.** Every read goes through one helper: it opens without blocking, requires a regular file, requires the real path to stay inside the project, and stops at a size limit (16 MB, 2 MB for a scanned source file). A FIFO, a device, a directory, a symlink out of the project, or an oversized file gives `UNKNOWN` for the checks that depend on it. Image headers come from a 2 MB prefix, and PNG chunks are walked only to `IDAT`, so a large real icon still works; metadata that pushes `IDAT` past the prefix is `UNKNOWN`. XML that declares entities is not parsed. A path outside the project is `UNKNOWN` whether or not the file exists, so the output does not reveal which outside files exist. More than 1000 declared icons is `UNKNOWN`. `--expo-config` is the operator's own file: it must be regular and within the limit, may sit outside the project, and otherwise exits 2.

**Printing project values.** Every name, id, path, key, permission, URL, and file name is printed in double quotes, with embedded quotes and backslashes escaped, Unicode categories Cc, Cf, Cs, Zl, and Zp dropped, and anything over 80 characters truncated with a marker. Each check prints one line.

**Where config comes from.** Xcode and Flutter read the native project. Expo reads the app config, except that a real native project wins when it is not ignored: Expo Build will not run Prebuild for a project that has `android` and `ios` directories, and it does run Prebuild when they are listed in `.gitignore` or `.easignore` [9]. A real native project means `ios/*.xcodeproj` or `android/app/build.gradle(.kts)`; an empty folder does not win. When `.easignore` exists, EAS CLI uses it instead of `.gitignore` [3], so only that file is read. `ios`, `/ios`, `ios/`, `/ios/`, `ios/*`, `/ios/*`, `ios/**`, and `/ios/**` all count as ignoring the folder, and the same forms for `android`.

**Xcode settings.** Read in Xcode's order, and the first layer that sets the key decides: target settings, the target's `.xcconfig`, project settings, the project's `.xcconfig`. In an `.xcconfig`, literal `KEY = value` lines count, with one level of `#include`; a missing include is ignored. `$(inherited)` or a conditional such as `[sdk=iphoneos*]` is `UNKNOWN`. A referenced `.xcconfig` that cannot be read leaves any setting it could give `UNKNOWN`. `INFOPLIST_KEY_NS*` from either source counts as a purpose string.

**iOS icon set.** The current Xcode default is a single 1024x1024 image that generates the other sizes [4]. Older sets list each size, with the App Store icon in the iOS 1,024pt well [4]. Both pass. A set that fills only the App Store well and leaves its listed `iphone` or `ipad` wells empty is `UNKNOWN`: no source was found that says this is enough. A variant marked with `appearances` is skipped for alpha, because Apple asks for a dark icon with a transparent background [4].

**Icon Composer.** A `.icon` file replaces the asset catalog, and Xcode renders the sizes at build time [10]. Its output cannot be read from project files, so `icon-sizes` and `icon-alpha` are `UNKNOWN`. Check the built app.

**Alpha rule, source quality.** No current Apple page fetched states an alpha rule for a bitmap App Store icon [7]. So on native routes (Xcode, Flutter, Expo with a native `ios/`), a PNG with an alpha channel or `tRNS` chunk is `UNKNOWN`, with the advice to validate the archive in Xcode, and one with neither is `PASS`. A WebP's alpha is not read, so it is `UNKNOWN` everywhere.

**Expo and alpha.** Expo's documentation says the icon must have no transparent pixels [6], so the Expo config route fails an alpha channel. Expo's prebuild removes transparency from the light and tinted icons by filling with white, and keeps it for dark [11]; the script still fails, because a white fill silently changes the icon. An opaque RGBA file also fails; re-export it without alpha.

**Android launcher sizes.** Bitmaps scale from their base size by density: mdpi 1x, hdpi 1.5x, xhdpi 2x, xxhdpi 3x, xxxhdpi 4x [12]. A legacy launcher icon has a 48 dp base [13]. Every adaptive layer is 108x108 dp [14][13], so a foreground is 108 px at mdpi and 432 px at xxxhdpi, and a vector layer has `android:width` and `android:height` of `108dp`. An adaptive icon is an `<adaptive-icon>` XML file with `<foreground>` and `<background>`, and optionally `<monochrome>` [14]. PNG and WebP sizes come from file headers [15][16][17][18]. Anything the script cannot judge is `UNKNOWN`, never a counted pass: a bitmap with no density qualifier, a launcher or layer that is a `<layer-list>`, `<shape>`, `<bitmap>`, or other drawable, a legacy launcher `<vector>`, an inline `aapt:attr` layer, and a reference that is not `@mipmap` or `@drawable`.

**Android app name.** `@string/x` is looked up in every `res/values/*.xml`. A `resValue` for it in Gradle is `UNKNOWN`, and so is a malformed values file when the name was not found elsewhere.

**Expo icons.** iOS: exactly 1024x1024 [6][19]. Android: an adaptive foreground, or `android.icon`, or top-level `icon`; square and at least 512x512 [6]; an adaptive background image has the same dimensions as the foreground [6]. A monochrome layer only has to be square. A remote URL is `UNKNOWN`.

**Web names and icons.** Next.js `metadata.title` is read only from the top level of the `metadata` object, as a plain string or `title: { default: ... }`; a nested `title` or one inside a string does not count. A non-literal value, a shorthand `title`, a spread anywhere in the object, a repeated `title` or `default`, or `metadata` assigned more than once is `UNKNOWN`. Under the pages router, the title is `UNKNOWN` and `public/favicon.*` counts as a declared icon. A remote or `data:` icon is `UNKNOWN`.

**Incomplete scans.** A source file that was skipped for size, a read error, not being a regular file, or pointing outside the project makes `permission-strings` and `permissions-declared` `UNKNOWN`, naming the file, unless a detected gap already gives `FAIL`.

**Purpose strings have an Android counterpart only at runtime.** `<uses-permission>` takes a name and an optional maximum SDK; it has no description [20]. Android shows a system prompt, and an app explains itself in its own UI when `shouldShowRequestPermissionRationale()` says to [21]. So `permissions-declared` checks that each detected API's permission is declared, not that a string exists. Dangerous means the protection level `dangerous` in the Android reference [8][22].

**Expo purpose strings.** A string comes from `ios.infoPlist` or the plugin option. Without either, Expo's plugins write a boilerplate string such as "Allow $(PRODUCT_NAME) to access your photos" [23][24], and Expo says those defaults most likely need tailoring to be accepted by the App Store [25]. Apple requires purpose strings that clearly and completely describe the use [26]. So the script fails a detected API with no specific string, even though a build would succeed. A plugin option of `false` deletes the key, including one set in `ios.infoPlist` [24], and fails if the API is used. A config plugin the script does not know, such as a local `./` path, can set a string or permission, so a missing one beside it is `UNKNOWN`, not `FAIL`.

**Expo Android permissions.** Most permissions arrive automatically through a library's manifest [25]. Those fail only when removed by `android.blockedPermissions`, by a plugin option of `false`, or by `tools:node="remove"` [19][25][27]. Calendar permissions and background location must be listed by the project [28][29].

**Privacy policy URL.** The script reads `provided.publish-readiness.privacy_policy_url` from `.app-creators/state.md`.

| state | ios, android | web |
|---|---|---|
| file missing or unreadable | `UNKNOWN` | `UNKNOWN` |
| set, http(s) URL | `PASS` | `PASS` |
| set, anything else | `FAIL` | `FAIL` |
| empty | `FAIL` [30][31] | `FAIL` with `--collects-data yes`, `PASS` with `no`, `UNKNOWN` with neither |

## Permission APIs scanned

The table in the script holds only APIs a source below ties to a key or permission. Comments are ignored; string and template literals are not comments. `node_modules`, `.git`, `build`, `Pods`, `.dart_tool`, `dist`, `.expo`, and `.gradle` are skipped.

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
| expo | `.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`, `.mts` | `launchImageLibraryAsync`, `requestMediaLibraryPermissionsAsync` | `photosPermission`: `NSPhotoLibraryUsageDescription` [23] |
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
- Expo's current documentation names `app.json`, `app.config.js`, and `app.config.ts` [57]. `app.config.json` is read because `app-creators` detection accepts it. When both exist, `app.json` wins.
- Next.js: a literal `metadata.title` in the root layout is read as text. Anything built at runtime is `UNKNOWN`.
- An ignored native folder is matched only in the forms listed above. Other globs and `!` negation are not understood.
- A release source-set manifest that removes a permission is not read; only the `main` manifest is.
- Any config plugin outside the script's option table gives `UNKNOWN` for a missing string, including first-party plugins that set none, such as `expo-router`.
- Crafted input: known slow patterns are fixed and tested, but no time bound is proven. The script has two backstops. Past 512 MB read in one run, further reads give `UNKNOWN`. Past 120 seconds of wall clock, where the platform has `SIGALRM`, it prints an error to stderr and exits 2, and any check not yet printed has no result. A run that reaches the limit is a failed run, not a clean one.
- An unclosed `/*` is treated as text, so code after it is still scanned. An unclosed quote ends at its line, and an unclosed backtick at the end of the file; text in them is kept, never hidden.
- A Dart file naming both `pickVideo(` and `ImageSource.camera` needs the microphone key, even if the two are not one call. `metadata` must reach its `=` within 200 characters; a longer gap is treated as not found.
- A regex literal is recognized only where an expression can start, as judged by the character before it or by `return`, with at most one space between. Elsewhere, only a `\` before `/*` or `//` keeps it from opening a comment, so a character class such as `[/*]` in an indented regex statement can still hide code.
- A linked folder is not followed. If it points outside the project, or at a folder the scan does not reach, the permission check is `UNKNOWN` and names it. Flutter's `.symlinks` is skipped, because it points outside by design.

## Fixes

| check | Expo | Flutter | Xcode | Kotlin | web |
|---|---|---|---|---|---|
| `app-name` | set `expo.name` | iOS: `CFBundleDisplayName` in `ios/Runner/Info.plist`; Android: `android:label` in `android/app/src/main/AndroidManifest.xml` [58][59]; web: `<title>` in `web/index.html` | set Display Name on the app target | set `android:label`, usually `@string/app_name` | `<title>` or the manifest `name`; Next.js: `metadata.title` |
| `bundle-id` | set `ios.bundleIdentifier` | set it on the Runner target in Xcode [58] | set Bundle Identifier on the app target | none | none |
| `package` | set `android.package` | set `applicationId` in `android/app/build.gradle.kts` [59] | none | set `applicationId` in `app/build.gradle(.kts)` | none |
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

Web rules: Web App Manifest `icons` (MDN): https://developer.mozilla.org/en-US/docs/Web/Manifest/Reference/icons; Next.js app icons: https://nextjs.org/docs/app/api-reference/file-conventions/metadata/app-icons; manifest: https://nextjs.org/docs/app/api-reference/file-conventions/metadata/manifest; `src` folder: https://nextjs.org/docs/app/api-reference/file-conventions/src-folder

App Store Connect's App Information page also lists Privacy Policy URL as required for iOS and macOS apps: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
