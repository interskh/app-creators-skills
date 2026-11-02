# Handoff: 2026-11-02-slice1-publish-design

## Slice D / T1 todo-expo fixture

Expo SDK 58 (expo ~58.0.19, RN 0.88.0). Docs checked 2026-11-02: https://docs.expo.dev/versions/latest/sdk/imagepicker/ and https://docs.expo.dev/develop/user-interface/app-icons/

**Decisions**
- Generated with `create-expo-app@latest -t blank-typescript --no-agents-md --no-install`; it is inside an existing git repo so it ran no `git init`. Deps via `npx expo install` (image-picker, async-storage).
- Persistence is AsyncStorage; photo is stored as a URI only (fixture, not a production-grade copy to document dir).
- Plugin config: `photosPermission` with a specific string, `cameraPermission: false`, `microphonePermission: false` (doc: false blocks CAMERA / RECORD_AUDIO on Android). App only calls `launchImageLibraryAsync`.
- Template `assets/icon.png` is already 1024x1024, colour type 2, no tRNS: kept as is. Adaptive foreground/background 512x512, monochrome 432x432 (all RGBA, fine): docs say at least 512 and background must match foreground dims; no exact adaptive size is stated.
- Deleted the template `LICENSE` (Expo copyright, MIT); todo-vite has none and the repo has its own.

**Rejected**
- Replacing template icons: they already meet the docs. Camera permission left on: app does not use it.
- `.gitleaksignore` entry: not needed; the lockfile has zero `deprecated` notices, grep for emails and home paths is empty, `privacy-scan --staged` rc=0.

**Assumptions**
- `splash-icon.png` (indexed, tRNS) is not referenced by app.json, so the alpha rule does not apply; recheck if a splash plugin is added.
- Doc text was read from rendered HTML via curl; adaptive-icon sizes beyond the quoted lines may exist in Android guidelines.

**Deferred**
- No device or simulator run; only `expo export --platform ios` bundling. No EAS config by design.

**Touches**
- fixtures repo: `todo-expo/` (new), root `README.md` (one bullet). No shared config; `.gitleaksignore` unchanged.

## Slice D / T2 check-readiness.py

**Decisions**
- Expo `icon-alpha` FAILs on an alpha channel although `withIosIcons.ts` flattens light and tinted icons onto white: Expo's docs say no transparent pixels, and a white fill silently changes the icon. The fix text says so.
- Expo API with no plugin option and no `ios.infoPlist` key FAILs `permission-strings`, although the plugin writes a boilerplate string (`Permissions.ts`): Expo's permissions guide says defaults likely need tailoring, Apple 5.1.1(ii) requires purpose strings that describe the use. This is what makes the seeded `photosPermission` removal fail.
- `com.example` flagged on Android only, from the Play Console error in a Google-hosted community thread (raw page fetched). No iOS store rule found; Flutter's `build_ios.dart` warning is tooling.
- Native folder wins for Expo unless listed in `.gitignore` or `.easignore`: the CNG page says EAS runs no Prebuild when the folders exist, and shows ignoring them to get fresh ones.
- `.icon` gives `UNKNOWN` on `icon-sizes` and `icon-alpha`: Xcode renders it at build time, and it replaces the asset catalog when its name matches the app icon setting.
- Android bases: legacy 48 dp and adaptive 108 dp at the density ratios. 108 is in Android docs; 48 as a launcher base is in Expo's `withAndroidIcons.ts` only, Android shows it only as a density example.
- Expo Android: `auto` permissions fail only when blocked; calendar and background location need declaring. Monochrome layer only has to be square, because T1's fixture ships 432x432 and the docs state 512 for the icon.
- Flutter `permissions-declared` also scans `.kt` and `.java` under `android/`: the first-party plugins list no manifest step, so Dart has no Android row. This extends the brief's `.dart` scan so a gap can be seeded.
- Next.js literal `metadata.title` is read as text; anything non-literal is `UNKNOWN`. This keeps a default Next app from an `UNKNOWN` name.
- Comment stripper respects strings, so a URL in gradle or JS neither unbalances braces nor hides an API after it.
- pbxproj object index only keeps blocks with `isa`: real `TargetAttributes` reuse the target id and overwrote it. Found by running on Expo's real template; regression is in the test tree.

**Rejected**
- `defusedxml`, flagged by a security hook: the contract is standard library only, and input is the creator's own project.
- Decoding PNG pixels to tell an opaque RGBA file from a transparent one: the validator message names the channel, and the brief says colour type and tRNS.
- `UNKNOWN` for native `icon-alpha` for lack of an Apple doc page: the brief's test matrix needs `FAIL`. See Assumptions.
- `UNKNOWN` for Flutter on Android when no API is detected: the table limit is stated in `references/checks.md`, as the brief allows.

**Assumptions**
- Native `icon-alpha` rests on Apple's validator message ("can't be transparent or contain an alpha channel"), read only in a search listing of Apple Developer Forums threads. The thread pages return a bot check to curl, and no Apple documentation page fetched states it. Check: an upload of an RGBA icon, or Apple text if one surfaces.
- `com.example` rests on a community thread quoting the console, not a policy page. Check: try creating a Play app with that id.
- Source dates are UTC. Local clock passed midnight during the fetches; every fetch is 2026-11-02 UTC.
- Real-file check was on fetched Expo and Flutter template files only, with placeholders; no real Xcode, Android Studio, or Flutter build ran here.

**Removed or left out for lack of a source**
- Flutter `google_maps_flutter` location row: no permission text on its pub.dev page.
- A 15-character limit on `CFBundleName`: stated as "can contain", no store rule, so no check.
- `com.android` and other id prefixes: nothing sourced.
- Permission rows for third-party Flutter plugins such as `permission_handler`: not first party.

**Deferred**
- An opaque RGBA Expo icon fails, though Expo would flatten it harmlessly. Safe: the fix is a re-export.
- Gitignore matching is exact-line, no globs. Safe: a miss reads the native folder, which is what a local build uses.
- `recordAudioAndroid: false` counts as blocking `RECORD_AUDIO` even if another module adds it. Safe: it can only over-report on an unusual config.

**Touches**
- New: `skills/publish-readiness/` (skeleton from `new-skill.sh`, `metadata.stage: publish`, `metadata.platform: all`), `scripts/check-readiness.py`, `references/checks.md`, `tests/check-readiness.test.sh`.
- `.github/workflows/lint.yml`: one step. Check ids and CLI are read by T3's `SKILL.md`.

**Kill rate**
- mutations: 23/23 caught, after closing two gaps the first pass (21/23) found: dark-appearance entry ordered first; nested target id written after the target. Restores verified by sha256.
