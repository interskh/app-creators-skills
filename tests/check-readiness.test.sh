#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
check="$root/skills/publish-readiness/scripts/check-readiness.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0
total=0
failed=""
out=""
err=""
code=0
dir=""

fail() {
  failed="$failed
FAIL $1: $2"
}

# png <path> <w> <h> <colour type> [trns]: a real PNG with zeroed pixels.
png() {
  mkdir -p "$(dirname "$1")"
  python3 -I -c 'import struct,sys,zlib
p,w,h,c=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4])
ch=lambda t,d:struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
n={0:1,2:3,3:1,4:2,6:4}[c]
s=b"\x89PNG\r\n\x1a\n"+ch(b"IHDR",struct.pack(">IIBBBBB",w,h,8,c,0,0,0))
s+=ch(b"PLTE",bytes(3)) if c==3 else b""
s+=ch(b"tRNS",b"\x00") if len(sys.argv)>5 else b""
s+=ch(b"IDAT",zlib.compress((b"\x00"+bytes(n*w))*h,1))+ch(b"IEND",b"")
open(p,"wb").write(s)' "$@"
}

# webp <path> <VP8|VP8L|VP8X> <w> <h>: a header-only WebP; the checker reads only the header.
webp() {
  mkdir -p "$(dirname "$1")"
  python3 -I -c 'import struct,sys
p,k,w,h=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
if k=="VP8": f=b"VP8 ";d=b"\x00\x00\x00\x9d\x01\x2a"+struct.pack("<HH",w,h)
elif k=="VP8L": f=b"VP8L";d=b"\x2f"+struct.pack("<I",(w-1)|((h-1)<<14))
else: f=b"VP8X";d=bytes(4)+(w-1).to_bytes(3,"little")+(h-1).to_bytes(3,"little")
open(p,"wb").write(b"RIFF"+struct.pack("<I",12+len(d))+b"WEBP"+f+struct.pack("<I",len(d))+d)' "$@"
}

sub() {
  python3 -I -c 'import sys
p,a,b=sys.argv[1:4]
s=open(p).read()
assert a in s,a
open(p,"w").write(s.replace(a,b))' "$1" "$2" "$3"
}

put() {
  mkdir -p "$(dirname "$1")"
  printf '%b' "$2" >"$1"
}

state() {
  put "$1/.app-creators/state.md" "---\nschema: \"1.0\"\nprovided:\n  publish-readiness:\n    privacy_policy_url: $2\n    support_email_env: \"\"\n---\nnotes\n"
}

variant() {
  dir="$tmp/v/$2"
  mkdir -p "$tmp/v"
  rm -rf "$dir"
  cp -R "$tmp/$1" "$dir"
}

run_check() {
  set +e
  out="$(python3 -I "$check" "$@" 2>"$tmp/stderr")"
  code=$?
  set -e
  err="$(cat "$tmp/stderr")"
}

# expect <label> <exit> [line-regex...]: exit code, no traceback, line format, each regex hits a line.
# A regex starting with ! must hit no line.
expect() {
  local label="$1" want="$2" re bad=""
  shift 2
  total=$((total + 1))
  [ "$code" = "$want" ] || bad="exit $code, wanted $want"
  case "$err" in
    *Traceback*) bad="$bad; traceback" ;;
    *) ;;
  esac
  if [ -n "$out" ] && printf '%s\n' "$out" | grep -Evq '^(PASS [a-z-]+: |UNKNOWN [a-z-]+: |FAIL [a-z-]+: .*; fix: )'; then
    bad="$bad; malformed line"
  fi
  for re in "$@"; do
    case "$re" in
      !*)
        if printf '%s\n' "$out" | grep -Eq -- "${re#!}"; then
          bad="$bad; unwanted '${re#!}'"
        fi
        ;;
      *)
        if ! printf '%s\n' "$out" | grep -Eq -- "$re"; then
          bad="$bad; no line '$re'"
        fi
        ;;
    esac
  done
  if [ -z "$bad" ]; then
    pass=$((pass + 1))
  else
    fail "$label" "$bad
$out
$err"
  fi
}

# seed <base tree> <label> <check id> <platform> <shell command run in the copy> <regex naming the gap>:
# exit 1 and a FAIL <id> whose reason, before "; fix:", names the seeded gap.
seed() {
  local base="$1" label="$2" id="$3" platform="$4" cmd="$5" reason="${6:?seed needs a reason regex}" name
  name="$base-$(printf '%s' "$label" | tr -c 'a-zA-Z0-9' '-')"
  variant "$base" "$name"
  (cd "$dir" && eval "$cmd")
  run_check "$dir" --platform "$platform"
  expect "$base/$platform: $label" 1 "^FAIL $id: .*$reason.*; fix: "
}

# ---- Trees -----------------------------------------------------------------

pbxproj() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  {
    printf '// !$*UTF8*$!\n{\n\tobjects = {\n'
    printf '\t\t97C146ED1CF9000F007C117D /* Runner */ = {\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = 97C147051CF9000F007C117D;\n\t\t\tname = Runner;\n\t\t\tproductType = "com.apple.product-type.application";\n\t\t};\n'
    printf '\t\t97C146E61CF9000F007C117D /* Project object */ = {\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {\n\t\t\t\tTargetAttributes = {\n\t\t\t\t\t97C146ED1CF9000F007C117D = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n\t\t\t\t\t};\n\t\t\t\t};\n\t\t\t};\n\t\t\tbuildConfigurationList = 97C146E91CF9000F007C117D;\n\t\t};\n'
    printf '\t\t97C146E91CF9000F007C117D = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t97C147031CF9000F007C117D /* Debug */,\n\t\t\t\t97C147041CF9000F007C117D /* Release */,\n\t\t\t);\n\t\t};\n'
    printf '\t\t97C147051CF9000F007C117D = {\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t97C147061CF9000F007C117D /* Debug */,\n\t\t\t\t97C147071CF9000F007C117D /* Release */,\n\t\t\t);\n\t\t};\n'
    printf '\t\t97C147031CF9000F007C117D /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tSDKROOT = iphoneos;\n\t\t\t};\n\t\t\tname = Debug;\n\t\t};\n'
    printf '\t\t97C147041CF9000F007C117D /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tSDKROOT = iphoneos;\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n'
    printf '\t\t97C147061CF9000F007C117D /* Debug */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "bad_debug_id";\n\t\t\t};\n\t\t\tname = Debug;\n\t\t};\n'
    printf '\t\t97C147071CF9000F007C117D /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;\n\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n'
    printf '\t};\n}\n'
  } >"$file"
}

info_plist() {
  put "$1" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict>\n<key>CFBundleDisplayName</key><string>Todo</string>\n<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>\n<key>$2</key><string>$3</string>\n</dict></plist>\n"
}

apple_tree() {
  local at="$1" set="$1/Runner/Assets.xcassets/AppIcon.appiconset"
  pbxproj "$at/Runner.xcodeproj/project.pbxproj"
  info_plist "$at/Runner/Info.plist" NSCameraUsageDescription "Todo scans a code to add an item."
  put "$set/Contents.json" '{"images":[{"filename":"Icon-60-2x.png","idiom":"iphone","scale":"2x","size":"60x60"},{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"},{"idiom":"iphone","scale":"3x","size":"60x60"}],"info":{"author":"xcode","version":1}}\n'
  png "$set/Icon-60-2x.png" 120 120 2
  png "$set/Icon-1024.png" 1024 1024 2
}

android_tree() {
  local at="$1" main="$1/app/src/main" d s
  put "$at/app/build.gradle.kts" 'plugins {\n  id("com.android.application")\n}\nandroid {\n  namespace = "io.github.test.todo"\n  defaultConfig {\n    applicationId = "io.github.test.todo"\n    versionCode = 1\n  }\n}\n'
  put "$main/AndroidManifest.xml" '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n  <uses-permission android:name="android.permission.CAMERA" />\n  <application android:label="@string/app_name" android:icon="@mipmap/ic_launcher"></application>\n</manifest>\n'
  put "$main/res/values/strings.xml" '<resources><string name="app_name">Todo</string></resources>\n'
  put "$main/res/mipmap-anydpi-v26/ic_launcher.xml" '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n  <background android:drawable="@color/white" />\n  <foreground android:drawable="@drawable/ic_launcher_foreground" />\n</adaptive-icon>\n'
  put "$main/res/drawable/ic_launcher_foreground.xml" '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108" />\n'
  for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
    s="${d#*:}"
    webp "$main/res/mipmap-${d%:*}/ic_launcher.webp" VP8L "$s" "$s"
  done
}

t="$tmp/expo"
put "$t/app.json" '{"expo":{"name":"Todo","icon":"./assets/icon.png","ios":{"bundleIdentifier":"io.github.test.todo"},"android":{"package":"io.github.test.todo","adaptiveIcon":{"foregroundImage":"./assets/fg.png","backgroundImage":"./assets/bg.png"}},"web":{"favicon":"./assets/favicon.png"},"plugins":[["expo-image-picker",{"photosPermission":"Todo reads one photo you attach."}]]}}\n'
put "$t/package.json" '{"name":"todo","dependencies":{"expo":"~58.0.0","react-dom":"19.0.0"}}\n'
put "$t/App.tsx" "import * as ImagePicker from 'expo-image-picker';\nexport default async function App() { await ImagePicker.launchImageLibraryAsync({}); }\n"
png "$t/assets/icon.png" 1024 1024 2
png "$t/assets/fg.png" 512 512 6
png "$t/assets/bg.png" 512 512 2
png "$t/assets/favicon.png" 48 48 6
state "$t" '"https://example.org/privacy"'

t="$tmp/flutter"
put "$t/pubspec.yaml" 'name: todo\ndependencies:\n  flutter:\n    sdk: flutter\n  image_picker: ^1.0.0\n'
put "$t/lib/main.dart" "import 'package:image_picker/image_picker.dart';\nfinal f = ImagePicker().pickImage(source: ImageSource.camera);\n"
apple_tree "$t/ios"
android_tree "$t/android"
put "$t/web/index.html" '<!doctype html><html><head><base href="$FLUTTER_BASE_HREF"><title>Todo</title><link rel="icon" type="image/png" href="favicon.png"><link rel="manifest" href="manifest.json"></head></html>\n'
put "$t/web/manifest.json" '{"name":"Todo","icons":[{"src":"icons/Icon-192.png","sizes":"192x192","type":"image/png"}]}\n'
png "$t/web/favicon.png" 16 16 6
png "$t/web/icons/Icon-192.png" 192 192 6
state "$t" '"https://example.org/privacy"'

t="$tmp/xcode"
apple_tree "$t"
put "$t/Runner/App.swift" 'import AVFoundation\nfunc go() { AVCaptureDevice.requestAccess(for: .video) { _ in } }\n'
state "$t" '"https://example.org/privacy"'

t="$tmp/kotlin"
android_tree "$t"
put "$t/app/src/main/java/io/test/MainActivity.kt" 'import android.Manifest\nval p = Manifest.permission.CAMERA\n'
state "$t" '"https://example.org/privacy"'

t="$tmp/vite"
put "$t/package.json" '{"name":"todo","devDependencies":{"vite":"^6.0.0"}}\n'
put "$t/vite.config.ts" 'export default {};\n'
put "$t/index.html" '<!doctype html><html><head><title>Todo</title><link rel="icon" href="/favicon.svg"><link rel="manifest" href="/manifest.webmanifest"></head></html>\n'
put "$t/public/favicon.svg" '<svg xmlns="http://www.w3.org/2000/svg"/>\n'
put "$t/public/manifest.webmanifest" '{"name":"Todo","icons":[{"src":"/icon-64.png","sizes":"64x64","type":"image/png"}]}\n'
png "$t/public/icon-64.png" 64 64 6
state "$t" '"https://example.org/privacy"'

t="$tmp/nextjs"
put "$t/next.config.mjs" 'export default {};\n'
put "$t/package.json" '{"name":"todo","dependencies":{"next":"16.0.0"}}\n'
put "$t/app/layout.tsx" 'export const metadata = { title: "Todo", description: "x" };\nexport default function L({children}) { return children; }\n'
png "$t/app/icon.png" 32 32 6
state "$t" '"https://example.org/privacy"'

t="$tmp/static"
put "$t/index.html" '<!doctype html><html><head><title>Todo</title><link rel="icon" sizes="32x32" href="favicon.png"></head></html>\n'
png "$t/favicon.png" 32 32 6
state "$t" '"https://example.org/privacy"'

# ---- Clean trees -----------------------------------------------------------

run_check "$tmp/expo" --platform ios
expect "expo ios clean" 0 '^PASS app-name: ' '^PASS bundle-id: ' '^PASS icon-sizes: ' '^PASS icon-alpha: ' '^PASS permission-strings: ' '^PASS privacy-policy-url: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/expo" --platform android
expect "expo android clean" 0 '^PASS app-name: ' '^PASS package: ' '^PASS icon-sizes: ' '^PASS permissions-declared: ' '^PASS privacy-policy-url: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/expo" --platform web
expect "expo web clean (react-dom carries web)" 0 '^PASS app-name: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/flutter" --platform ios
expect "flutter ios clean" 0 '^PASS bundle-id: "io.github.test.todo" from PRODUCT_BUNDLE_IDENTIFIER' '^PASS icon-alpha: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/flutter" --platform android
expect "flutter android clean" 0 '^PASS package: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/flutter" --platform web
expect "flutter web clean" 0 '^PASS app-name: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/xcode" --platform ios
expect "xcode ios clean" 0 '^PASS app-name: "Todo" from CFBundleDisplayName' '^PASS permission-strings: .*needed by code: "NSCameraUsageDescription"' '!^(FAIL|UNKNOWN) '
run_check "$tmp/kotlin" --platform android
expect "kotlin android clean, WebP launcher" 0 '^PASS app-name: "Todo"' '^PASS permissions-declared: declared dangerous: "CAMERA"; needed by code: "CAMERA"' '!^(FAIL|UNKNOWN) '
run_check "$tmp/vite" --platform web
expect "vite web clean" 0 '^PASS app-name: "Todo" from "public/manifest.webmanifest"' '!^(FAIL|UNKNOWN) '
run_check "$tmp/nextjs" --platform web
expect "nextjs web clean" 0 '^PASS app-name: "Todo" from metadata.title' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/static" --platform web
expect "static web clean" 0 '^PASS app-name: "Todo" from index.html' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '

# ---- Seeded gaps: expo -----------------------------------------------------

seed expo "missing icon" icon-sizes ios 'rm assets/icon.png' 'icon points at "\./assets/icon\.png", which is missing'
seed expo "no icon key" icon-sizes ios 'sub app.json "\"icon\":\"./assets/icon.png\"," ""' 'no icon in the app config'
seed expo "wrong size" icon-sizes ios 'png assets/icon.png 512 512 2' 'is 512x512, expected 1024x1024'
seed expo "non-square" icon-sizes ios 'png assets/icon.png 1024 1023 2' 'is 1024x1023, expected 1024x1024'
seed expo "alpha RGBA" icon-alpha ios 'png assets/icon.png 1024 1024 6' 'icon\.png" has an alpha'
seed expo "alpha grey" icon-alpha ios 'png assets/icon.png 1024 1024 4' 'icon\.png" has an alpha'
seed expo "alpha palette tRNS" icon-alpha ios 'png assets/icon.png 1024 1024 3 trns' 'icon\.png" has an alpha'
seed expo "alpha RGB tRNS" icon-alpha ios 'png assets/icon.png 1024 1024 2 trns' 'icon\.png" has an alpha'
seed expo "declared option empty" permission-strings ios 'sub app.json "Todo reads one photo you attach." ""' 'NSPhotoLibraryUsageDescription" is declared but empty'
seed expo "declared infoPlist empty" permission-strings ios 'sub app.json "\"ios\":{" "\"ios\":{\"infoPlist\":{\"NSMotionUsageDescription\":\"  \"},"' 'NSMotionUsageDescription" is declared but empty'
seed expo "no photo option" permission-strings ios 'sub app.json ",\"plugins\":[[\"expo-image-picker\",{\"photosPermission\":\"Todo reads one photo you attach.\"}]]" ""' 'needs "NSPhotoLibraryUsageDescription"'
seed expo "plugin string form only" permission-strings ios 'sub app.json "[\"expo-image-picker\",{\"photosPermission\":\"Todo reads one photo you attach.\"}]" "\"expo-image-picker\""' 'needs "NSPhotoLibraryUsageDescription"'
seed expo "option false" permission-strings ios 'sub app.json "\"Todo reads one photo you attach.\"" "false"' 'needs "NSPhotoLibraryUsageDescription"; a plugin option of false'
seed expo "missing bundle id" bundle-id ios 'sub app.json "\"bundleIdentifier\":\"io.github.test.todo\"" "\"supportsTablet\":true"' 'no bundle id'
seed expo "bad bundle id" bundle-id ios 'sub app.json "\"bundleIdentifier\":\"io.github.test.todo\"" "\"bundleIdentifier\":\"io_github.todo\""' '"io_github\.todo" must be'
seed expo "empty name" app-name ios 'sub app.json "\"name\":\"Todo\"" "\"name\":\"\""' 'name is empty'
seed expo "no name" app-name ios 'sub app.json "\"name\":\"Todo\"," ""' 'name is empty'
seed expo "empty privacy" privacy-policy-url ios 'state . "\"\""' 'App Store Connect requires'
seed expo "foreground gone" icon-sizes android 'rm assets/fg.png' 'foregroundImage points at "\./assets/fg\.png", which is missing'
seed expo "foreground small" icon-sizes android 'png assets/fg.png 256 256 6; png assets/bg.png 256 256 2' 'fg\.png" is 256x256'
seed expo "background mismatch" icon-sizes android 'png assets/bg.png 1024 1024 2' 'background image is not the same size'
seed expo "no android package" package android 'sub app.json "\"package\":\"io.github.test.todo\"," ""' 'no application id'
seed expo "android bad segment" package android 'sub app.json "\"package\":\"io.github.test.todo\"" "\"package\":\"io.1github.todo\""' '"io\.1github\.todo" needs'
seed expo "android one segment" package android 'sub app.json "\"package\":\"io.github.test.todo\"" "\"package\":\"todo\""' '"todo" needs'
seed expo "camera blocked" permissions-declared android 'sub App.tsx "launchImageLibraryAsync" "launchCameraAsync"; sub app.json "\"photosPermission\":\"Todo reads one photo you attach.\"" "\"cameraPermission\":false"' '"CAMERA", which the project removes'
seed expo "blockedPermissions" permissions-declared android 'sub App.tsx "launchImageLibraryAsync" "launchCameraAsync"; sub app.json "\"android\":{" "\"android\":{\"blockedPermissions\":[\"android.permission.CAMERA\"],"' '"CAMERA", which the project removes'
seed expo "calendar undeclared" permissions-declared android "sub App.tsx 'ImagePicker.launchImageLibraryAsync({})' 'ImagePicker.requestCalendarPermissionsAsync()'" '"READ_CALENDAR", which is not declared.*"WRITE_CALENDAR", which is not declared'
seed expo "android empty name" app-name android 'sub app.json "\"name\":\"Todo\"" "\"name\":\" \""' 'name is empty'
seed expo "android empty privacy" privacy-policy-url android 'state . "\"\""' 'Google Play requires'
seed expo "web favicon gone" icon-sizes web 'rm assets/favicon.png' 'web.favicon points at .*missing'
seed expo "web no favicon" icon-sizes web 'sub app.json "\"web\":{\"favicon\":\"./assets/favicon.png\"}," ""' 'no web\.favicon'
seed expo "web empty name" app-name web 'sub app.json "\"name\":\"Todo\"" "\"name\":\"\""' 'name is empty'

variant expo camera-api
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
run_check "$dir" --platform ios
expect "launchCameraAsync needs the camera key, not photos" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

variant expo photo-only
run_check "$dir" --platform android
expect "launchImageLibraryAsync needs no Android permission" 0 '^PASS permissions-declared: '

variant expo camera-comment
sub "$dir/App.tsx" 'await ImagePicker.launchImageLibraryAsync({});' '// await ImagePicker.launchCameraAsync({});'
sub "$dir/app.json" ',"plugins":[["expo-image-picker",{"photosPermission":"Todo reads one photo you attach."}]]' ''
run_check "$dir" --platform ios
expect "an API in a comment is not usage" 0 '^PASS permission-strings: '

variant expo url-before-api
sub "$dir/App.tsx" 'await ImagePicker.launchImageLibraryAsync({});' 'const u = "https://example.org"; await ImagePicker.launchCameraAsync({});'
run_check "$dir" --platform ios
expect "a URL string does not hide the API after it" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

variant expo infoplist-string
sub "$dir/app.json" ',"plugins":[["expo-image-picker",{"photosPermission":"Todo reads one photo you attach."}]]' ''
sub "$dir/app.json" '"ios":{' '"ios":{"infoPlist":{"NSPhotoLibraryUsageDescription":"Todo reads one photo."},'
run_check "$dir" --platform ios
expect "ios.infoPlist supplies the string" 0 '^PASS permission-strings: .*declared: "NSPhotoLibraryUsageDescription"; needed by code: "NSPhotoLibraryUsageDescription"'

variant expo false-beats-infoplist
sub "$dir/app.json" '"Todo reads one photo you attach."' 'false'
sub "$dir/app.json" '"ios":{' '"ios":{"infoPlist":{"NSPhotoLibraryUsageDescription":"Todo reads one photo."},'
run_check "$dir" --platform ios
expect "a plugin option of false removes an infoPlist string" 1 '^FAIL permission-strings: .*needs "NSPhotoLibraryUsageDescription"; a plugin option of false'

variant expo calendar-declared
sub "$dir/App.tsx" 'ImagePicker.launchImageLibraryAsync({})' 'ImagePicker.requestCalendarPermissionsAsync()'
sub "$dir/app.json" '"android":{' '"android":{"permissions":["android.permission.READ_CALENDAR","WRITE_CALENDAR"],'
run_check "$dir" --platform android
expect "declared calendar permissions pass with dangerous evidence" 0 '^PASS permissions-declared: declared dangerous: "READ_CALENDAR", "WRITE_CALENDAR"; needed by code: "READ_CALENDAR", "WRITE_CALENDAR"'

variant expo no-wrapper
put "$dir/app.json" '{"name":"Todo","icon":"./assets/icon.png","ios":{"bundleIdentifier":"io.github.test.todo"},"plugins":[["expo-image-picker",{"photosPermission":"Todo reads one photo."}]]}\n'
run_check "$dir" --platform ios
expect "app.json without the expo wrapper" 0 '^PASS app-name: ' '!^(FAIL|UNKNOWN) '

variant expo app-config-json
mv "$dir/app.json" "$dir/app.config.json"
run_check "$dir" --platform ios
expect "app.config.json is read" 0 '^PASS app-name: ' '!^(FAIL|UNKNOWN) '

variant expo dark-alpha
sub "$dir/app.json" '"ios":{' '"ios":{"icon":{"light":"./assets/icon.png","dark":"./assets/dark.png"},'
png "$dir/assets/dark.png" 1024 1024 6
run_check "$dir" --platform ios
expect "a dark variant may carry alpha" 0 '^PASS icon-alpha: ' '!^FAIL '

variant expo icon-composer
sub "$dir/app.json" '"ios":{' '"ios":{"icon":"./assets/app.icon",'
mkdir -p "$dir/assets/app.icon"
run_check "$dir" --platform ios
expect "Icon Composer .icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '!^FAIL '

variant expo remote-icon
sub "$dir/app.json" './assets/icon.png' 'https://example.org/icon.png'
run_check "$dir" --platform ios
expect "remote icon URL is UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: '

variant expo dynamic
mv "$dir/app.json" "$tmp/dyn-expo-config.json"
put "$dir/app.config.js" 'module.exports = { name: "Todo" };\n'
run_check "$dir" --platform ios
expect "dynamic app.config.js without --expo-config" 0 '^UNKNOWN app-name: .*npx expo config --json' '^UNKNOWN bundle-id: ' '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '^UNKNOWN permission-strings: ' '!^PASS (app-name|bundle-id|icon-sizes|icon-alpha|permission-strings): ' '!^FAIL '
run_check "$dir" --platform android
expect "dynamic app.config.js on android" 0 '^UNKNOWN package: ' '^UNKNOWN icon-sizes: ' '^UNKNOWN permissions-declared: ' '!^FAIL '
run_check "$dir" --platform ios --expo-config "$tmp/dyn-expo-config.json"
expect "same project with --expo-config (wrapper) passes" 0 '^PASS app-name: ' '^PASS permission-strings: ' '!^(FAIL|UNKNOWN) '
python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))["expo"]
json.dump(d,open(sys.argv[2],"w"))' "$tmp/dyn-expo-config.json" "$tmp/dyn-expo-root.json"
run_check "$dir" --platform ios --expo-config "$tmp/dyn-expo-root.json"
expect "same project with --expo-config (expo root) passes" 0 '^PASS app-name: ' '!^(FAIL|UNKNOWN) '
put "$dir/app.config.ts" 'export default { name: "Todo" };\n'
rm "$dir/app.config.js"
run_check "$dir" --platform ios
expect "dynamic app.config.ts without --expo-config" 0 '^UNKNOWN app-name: .*app.config.ts'

variant expo native-ios
apple_tree "$dir/ios"
png "$dir/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png" 1024 1024 6
run_check "$dir" --platform ios
expect "expo: ios/ wins over the app config" 1 '^PASS bundle-id: .* from PRODUCT_BUNDLE_IDENTIFIER' '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha'
put "$dir/.gitignore" 'node_modules\n/ios\n'
run_check "$dir" --platform ios
expect "expo: a gitignored ios/ does not win" 0 '^PASS bundle-id: .* from ios.bundleIdentifier' '^PASS icon-alpha: "\./assets/icon.png"'

variant expo native-android
android_tree "$dir/android"
run_check "$dir" --platform android
expect "expo: android/ wins over the app config" 0 '^PASS package: .* from "android/app/build.gradle.kts"' '^PASS permissions-declared: declared dangerous: "CAMERA"'
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
sub "$dir/android/app/src/main/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission xmlns:tools="http://schemas.android.com/tools" android:name="android.permission.CAMERA" tools:node="remove" />'
run_check "$dir" --platform android
expect "expo native: tools:node=remove blocks a needed permission" 1 '^FAIL permissions-declared: .*"CAMERA", which the project removes'

variant expo malformed-appjson
put "$dir/app.json" '{"expo": {"name": '
run_check "$dir" --platform ios
expect "malformed app.json gives UNKNOWN (expo from package.json)" 0 '^UNKNOWN app-name: .*not valid JSON' '^UNKNOWN bundle-id: ' '^UNKNOWN icon-sizes: ' '^UNKNOWN permission-strings: ' '!^FAIL '

variant expo malformed-png
put "$dir/assets/icon.png" 'not a png\n'
run_check "$dir" --platform ios
expect "text in icon.png gives UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '!^FAIL '

variant expo truncated-png
head -c 40 "$tmp/expo/assets/icon.png" >"$dir/assets/icon.png"
run_check "$dir" --platform ios
expect "truncated PNG gives UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: '

# ---- Seeded gaps: flutter --------------------------------------------------

set_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
seed flutter "missing icon file" icon-sizes ios "rm $set_dir/Icon-1024.png" '"Icon-1024\.png" is listed .* missing'
seed flutter "no marketing entry" icon-sizes ios "sub $set_dir/Contents.json '{\"filename\":\"Icon-1024.png\",\"idiom\":\"ios-marketing\",\"scale\":\"1x\",\"size\":\"1024x1024\"},' ''" 'no 1024x1024 App Store icon'
seed flutter "wrong marketing size" icon-sizes ios "png $set_dir/Icon-1024.png 512 512 2" '"Icon-1024\.png" is 512x512'
seed flutter "wrong small size" icon-sizes ios "png $set_dir/Icon-60-2x.png 60 60 2" '"Icon-60-2x\.png" is 60x60, expected 120x120'
seed flutter "string empty" permission-strings ios "sub ios/Runner/Info.plist 'Todo scans a code to add an item.' ''" 'NSCameraUsageDescription" is declared but empty'
seed flutter "api without string" permission-strings ios "sub lib/main.dart 'ImageSource.camera' 'ImageSource.gallery'" 'needs "NSPhotoLibraryUsageDescription"'
seed flutter "missing id" bundle-id ios "sub ios/Runner.xcodeproj/project.pbxproj 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' ''; sub ios/Runner/Info.plist '<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''" 'no bundle id'
seed flutter "bad id" bundle-id ios "sub ios/Runner.xcodeproj/project.pbxproj 'io.github.test.todo' 'io_github.todo'" '"io_github\.todo" must be'
seed flutter "empty name" app-name ios "sub ios/Runner/Info.plist '<string>Todo</string>' '<string></string>'" 'name is empty'
seed flutter "ios empty privacy" privacy-policy-url ios 'state . "\"\""' 'App Store Connect requires'
seed flutter "android icon gone" icon-sizes android "sub android/app/src/main/AndroidManifest.xml ' android:icon=\"@mipmap/ic_launcher\"' ''" 'android:icon is missing'
seed flutter "android icon wrong size" icon-sizes android "webp android/app/src/main/res/mipmap-hdpi/ic_launcher.webp VP8L 96 96" 'mipmap-hdpi/ic_launcher\.webp" is 96x96, expected 72x72'
seed flutter "android host permission undeclared" permissions-declared android "put android/app/src/main/kotlin/M.kt 'val p = Manifest.permission.READ_CONTACTS\n'" '"READ_CONTACTS", which is not declared'
seed flutter "android missing id" package android "sub android/app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' ''" 'no application id'
seed flutter "android empty name" app-name android "sub android/app/src/main/res/values/strings.xml '>Todo<' '><'" 'name is empty'
seed flutter "android empty privacy" privacy-policy-url android 'state . "\"\""' 'Google Play requires'
seed flutter "web icon gone" icon-sizes web "rm web/icons/Icon-192.png" 'Icon-192\.png", which is missing'
seed flutter "web manifest size" icon-sizes web "png web/icons/Icon-192.png 96 96 6" 'is 96x96 but manifest declares'
seed flutter "web empty name" app-name web "sub web/manifest.json '\"name\":\"Todo\",' ''; sub web/index.html '<title>Todo</title>' '<title></title>'" 'name is empty'

variant flutter gallery-camera
sub "$dir/lib/main.dart" 'pickImage(source: ImageSource.camera)' 'pickVideo(source: ImageSource.camera)'
run_check "$dir" --platform ios
expect "flutter: pickVideo from camera needs the microphone key" 1 '^FAIL permission-strings: .*needs "NSMicrophoneUsageDescription"'

variant flutter no-web
rm -rf "$dir/web"
run_check "$dir" --platform web
expect "flutter on web without web/ exits 2" 2
[ -n "$err" ] || fail "flutter no-web" "no message"

variant flutter xcconfig-missing-id
sub "$dir/ios/Runner.xcodeproj/project.pbxproj" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' ''
sub "$dir/ios/Runner.xcodeproj/project.pbxproj" 'isa = XCBuildConfiguration;' 'isa = XCBuildConfiguration; baseConfigurationReference = AAA;'
sub "$dir/ios/Runner/Info.plist" '<key>CFBundleIdentifier</key><string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''
run_check "$dir" --platform ios
expect "an id absent from pbxproj with an xcconfig is UNKNOWN" 0 '^UNKNOWN bundle-id: .*xcconfig'

# ---- Seeded gaps: xcode ----------------------------------------------------

xset="Runner/Assets.xcassets/AppIcon.appiconset"
seed xcode "missing icon set" icon-sizes ios "rm -rf Runner/Assets.xcassets" 'no "AppIcon\.appiconset"'
seed xcode "missing marketing file" icon-sizes ios "rm $xset/Icon-1024.png" '"Icon-1024\.png" is listed .* missing'
seed xcode "wrong size" icon-sizes ios "png $xset/Icon-1024.png 1023 1023 2" '"Icon-1024\.png" is 1023x1023'
seed xcode "string empty" permission-strings ios "sub Runner/Info.plist 'Todo scans a code to add an item.' '   '" 'NSCameraUsageDescription" is declared but empty'
seed xcode "api without string" permission-strings ios "sub Runner/App.swift '.video' '.audio'" 'needs "NSMicrophoneUsageDescription"'
seed xcode "missing id" bundle-id ios "sub Runner.xcodeproj/project.pbxproj 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' ''; sub Runner/Info.plist '<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''" 'no bundle id'
seed xcode "bad id" bundle-id ios "sub Runner.xcodeproj/project.pbxproj 'io.github.test.todo' 'io.github.test.todo_app'" 'todo_app" must be'
seed xcode "empty name" app-name ios "sub Runner/Info.plist '<string>Todo</string>' '<string></string>'" 'name is empty'
seed xcode "empty privacy" privacy-policy-url ios 'state . "\"\""' 'App Store Connect requires'

variant xcode location
put "$dir/Runner/App.swift" 'import CoreLocation\nfunc go(m: CLLocationManager) { m.requestAlwaysAuthorization() }\n'
run_check "$dir" --platform ios
expect "requestAlwaysAuthorization needs location keys" 1 '^FAIL permission-strings: .*needs "NSLocationAlwaysAndWhenInUseUsageDescription".*needs "NSLocationWhenInUseUsageDescription"'

variant xcode objc
rm "$dir/Runner/App.swift"
put "$dir/Runner/App.m" '[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:nil];\n'
run_check "$dir" --platform ios
expect "objc API scan" 1 '^FAIL permission-strings: .*needs "NSMicrophoneUsageDescription"'

variant xcode pods-skip
put "$dir/Pods/X/X.swift" 'func go() { AVCaptureDevice.requestAccess(for: .audio) { _ in } }\n'
put "$dir/build/Y.swift" 'func go() { AVCaptureDevice.requestAccess(for: .audio) { _ in } }\n'
run_check "$dir" --platform ios
expect "Pods and build are not scanned" 0 '^PASS permission-strings: ' '!^FAIL '

variant xcode unresolved-var
sub "$dir/Runner.xcodeproj/project.pbxproj" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' 'PRODUCT_BUNDLE_IDENTIFIER = "io.github.$(TEAM_SUFFIX).todo";'
run_check "$dir" --platform ios
expect "unresolved \$(VAR) is UNKNOWN" 0 '^UNKNOWN bundle-id: .*TEAM_SUFFIX' '!^FAIL ' '!^PASS bundle-id: '

variant xcode resolved-var
sub "$dir/Runner.xcodeproj/project.pbxproj" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' 'PRODUCT_BUNDLE_IDENTIFIER = "io.github.$(SUFFIX).todo";
				SUFFIX = test;'
run_check "$dir" --platform ios
expect "resolvable \$(VAR) passes" 0 '^PASS bundle-id: "io.github.test.todo"'

variant xcode unresolved-icon
sub "$dir/Runner.xcodeproj/project.pbxproj" 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' 'ASSETCATALOG_COMPILER_APPICON_NAME = "$(ICON_NAME)";'
run_check "$dir" --platform ios
expect "unresolved icon set name is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*ICON_NAME' '^UNKNOWN icon-alpha: '

variant xcode two-targets
sub "$dir/Runner.xcodeproj/project.pbxproj" '	objects = {' '	objects = {
		BBBBBBBBBBBBBBBBBBBBBBBB /* Second */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 97C147051CF9000F007C117D;
			name = Second;
			productType = "com.apple.product-type.application";
		};'
run_check "$dir" --platform ios
expect "more than one app target is UNKNOWN" 0 '^UNKNOWN app-name: .*2 application targets' '^UNKNOWN bundle-id: ' '^UNKNOWN icon-sizes: ' '!^PASS (app-name|bundle-id|icon-sizes|icon-alpha|permission-strings): '

variant xcode broken-pbx
put "$dir/Runner.xcodeproj/project.pbxproj" '{ objects = { AAAA = { isa = PBXNativeTarget;\n'
run_check "$dir" --platform ios
expect "unbalanced pbxproj gives UNKNOWN" 0 '^UNKNOWN app-name: ' '^UNKNOWN bundle-id: ' '!^FAIL '

variant xcode malformed-plist
put "$dir/Runner/Info.plist" '<plist><dict><key>oops'
run_check "$dir" --platform ios
expect "malformed Info.plist gives UNKNOWN" 0 '^UNKNOWN app-name: .*plist' '^UNKNOWN permission-strings: .*plist' '^PASS bundle-id: ' '!^FAIL '

variant xcode malformed-contents
put "$dir/$xset/Contents.json" '{"images": ['
run_check "$dir" --platform ios
expect "malformed Contents.json gives UNKNOWN" 0 '^UNKNOWN icon-sizes: .*not valid JSON' '^UNKNOWN icon-alpha: ' '!^FAIL '

variant xcode malformed-marketing
put "$dir/$xset/Icon-1024.png" 'junk'
run_check "$dir" --platform ios
expect "malformed marketing PNG gives UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '!^FAIL '

variant xcode single-size
put "$dir/$xset/Contents.json" '{"images":[{"appearances":[{"appearance":"luminosity","value":"dark"}],"filename":"Dark.png","idiom":"universal","platform":"ios","size":"1024x1024"},{"filename":"Icon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}]}\n'
rm "$dir/$xset/Icon-60-2x.png"
png "$dir/$xset/Dark.png" 1024 1024 6
run_check "$dir" --platform ios
expect "single-size set passes; dark appearance may carry alpha" 0 '^PASS icon-sizes: ' '^PASS icon-alpha: "Icon-1024.png"'
png "$dir/$xset/Icon-1024.png" 1024 1024 6
run_check "$dir" --platform ios
expect "single-size default icon with alpha is UNKNOWN" 0 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document'

variant xcode icon-composer
mkdir -p "$dir/Runner/AppIcon.icon"
run_check "$dir" --platform ios
expect "AppIcon.icon wins and is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*Icon Composer' '^UNKNOWN icon-alpha: .*Icon Composer'

variant xcode generated-plist
sub "$dir/Runner.xcodeproj/project.pbxproj" 'INFOPLIST_FILE = Runner/Info.plist;' 'GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Todo;
				INFOPLIST_KEY_NSCameraUsageDescription = "Scan a code.";'
run_check "$dir" --platform ios
expect "generated Info.plist reads INFOPLIST_KEY_*" 0 '^PASS app-name: "Todo" from INFOPLIST_KEY_CFBundleDisplayName' '^PASS permission-strings: declared: "NSCameraUsageDescription"'
sub "$dir/Runner.xcodeproj/project.pbxproj" 'INFOPLIST_KEY_NSCameraUsageDescription = "Scan a code.";' 'INFOPLIST_KEY_NSCameraUsageDescription = "";'
run_check "$dir" --platform ios
expect "empty INFOPLIST_KEY string fails" 1 '^FAIL permission-strings: "NSCameraUsageDescription" is declared but empty; fix: '

variant xcode swiftpm
rm -rf "$dir/Runner.xcodeproj"
put "$dir/Package.swift" '// swift-tools-version:5.9\nimport PackageDescription\nlet p = Package(name: "T", targets: [.executableTarget(name: "T")])\n'
run_check "$dir" --platform ios
expect "Package.swift without an Xcode project gives UNKNOWN" 0 '^UNKNOWN bundle-id: .*xcodeproj'

# ---- Seeded gaps: kotlin ---------------------------------------------------

km="app/src/main"
seed kotlin "icon attr gone" icon-sizes android "sub $km/AndroidManifest.xml ' android:icon=\"@mipmap/ic_launcher\"' ''" 'android:icon is missing'
seed kotlin "icon files gone" icon-sizes android "rm -rf $km/res/mipmap-*" '"@mipmap/ic_launcher" has no file'
seed kotlin "wrong VP8L size" icon-sizes android "webp $km/res/mipmap-xxxhdpi/ic_launcher.webp VP8L 96 96" 'mipmap-xxxhdpi/ic_launcher.webp" is 96x96, expected 192x192'
seed kotlin "wrong VP8 size" icon-sizes android "webp $km/res/mipmap-mdpi/ic_launcher.webp VP8 96 96" 'mipmap-mdpi/ic_launcher.webp" is 96x96, expected 48x48'
seed kotlin "wrong VP8X size" icon-sizes android "webp $km/res/mipmap-xhdpi/ic_launcher.webp VP8X 48 48" 'mipmap-xhdpi/ic_launcher.webp" is 48x48, expected 96x96'
seed kotlin "wrong PNG size" icon-sizes android "rm $km/res/mipmap-hdpi/ic_launcher.webp; png $km/res/mipmap-hdpi/ic_launcher.png 48 48 6" 'mipmap-hdpi/ic_launcher.png" is 48x48, expected 72x72'
seed kotlin "adaptive foreground gone" icon-sizes android "rm $km/res/drawable/ic_launcher_foreground.xml" '"@drawable/ic_launcher_foreground" has no file'
seed kotlin "adaptive no foreground" icon-sizes android "sub $km/res/mipmap-anydpi-v26/ic_launcher.xml '<foreground android:drawable=\"@drawable/ic_launcher_foreground\" />' ''" 'has no <foreground>'
seed kotlin "adaptive vector not 108dp" icon-sizes android "sub $km/res/drawable/ic_launcher_foreground.xml 'android:width=\"108dp\"' 'android:width=\"96dp\"'" 'android:width "96dp", expected 108dp'
seed kotlin "permission undeclared" permissions-declared android "sub $km/AndroidManifest.xml '<uses-permission android:name=\"android.permission.CAMERA\" />' ''" '"CAMERA", which is not declared'
seed kotlin "second permission undeclared" permissions-declared android "put $km/java/io/test/L.java 'class L { String a = android.Manifest.permission.ACCESS_FINE_LOCATION; }\n'" '"ACCESS_FINE_LOCATION", which is not declared'
seed kotlin "literal permission undeclared" permissions-declared android "put $km/java/io/test/L.kt 'val a = \"android.permission.RECORD_AUDIO\"\n'" '"RECORD_AUDIO", which is not declared'
seed kotlin "missing id" package android "sub app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' ''" 'no application id'
seed kotlin "bad id" package android "sub app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' 'applicationId = \"io.github.2todo\"'" '"io\.github\.2todo" needs'
seed kotlin "label gone" app-name android "sub $km/AndroidManifest.xml ' android:label=\"@string/app_name\"' ''" 'android:label is missing'
seed kotlin "string gone" app-name android "sub $km/res/values/strings.xml 'name=\"app_name\"' 'name=\"other\"'" '"@string/app_name" is not in res/values'
seed kotlin "empty name" app-name android "sub $km/res/values/strings.xml '>Todo<' '> <'" 'name is empty'
seed kotlin "empty privacy" privacy-policy-url android 'state . "\"\""' 'Google Play requires'

variant kotlin dangerous-evidence
sub "$dir/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission android:name="android.permission.CAMERA" /><uses-permission android:name="android.permission.READ_CONTACTS" /><uses-permission android:name="android.permission.INTERNET" />'
run_check "$dir" --platform android
expect "evidence lists dangerous permissions only" 0 '^PASS permissions-declared: declared dangerous: "CAMERA", "READ_CONTACTS"; ' '!INTERNET'

variant kotlin nonliteral
sub "$dir/app/build.gradle.kts" 'applicationId = "io.github.test.todo"' 'applicationId = libs.versions.appId.get()'
run_check "$dir" --platform android
expect "non-literal applicationId is UNKNOWN" 0 '^UNKNOWN package: ' '!^FAIL '

variant kotlin interpolated
sub "$dir/app/build.gradle.kts" 'applicationId = "io.github.test.todo"' 'applicationId = "io.github.$suffix"'
run_check "$dir" --platform android
expect "interpolated applicationId is UNKNOWN" 0 '^UNKNOWN package: '

variant kotlin groovy
rm "$dir/app/build.gradle.kts"
put "$dir/app/build.gradle" "apply plugin: 'com.android.application'\nandroid {\n  defaultConfig {\n    applicationId 'io.github.test.todo'\n    applicationIdSuffix '.x'\n  }\n}\n"
run_check "$dir" --platform android
expect "groovy applicationId with a suffix line" 0 '^PASS package: "io.github.test.todo" from "app/build.gradle"'

variant kotlin gradle-url
sub "$dir/app/build.gradle.kts" 'android {' 'repositories { maven { url = uri("https://example.org/maven") } } // note {
android {'
run_check "$dir" --platform android
expect "a URL or a comment in gradle is not malformed" 0 '^PASS package: "io.github.test.todo"'

variant kotlin malformed-gradle
put "$dir/app/build.gradle.kts" 'plugins { id("com.android.application")\nandroid { defaultConfig {\n'
run_check "$dir" --platform android
expect "malformed gradle gives UNKNOWN" 0 '^UNKNOWN package: ' '!^FAIL '

variant kotlin malformed-manifest
put "$dir/$km/AndroidManifest.xml" '<manifest><application'
run_check "$dir" --platform android
expect "malformed manifest gives UNKNOWN" 0 '^UNKNOWN app-name: .*XML' '^UNKNOWN icon-sizes: .*XML' '^UNKNOWN permissions-declared: .*XML' '!^FAIL '

variant kotlin malformed-strings
put "$dir/$km/res/values/strings.xml" '<resources><string'
run_check "$dir" --platform android
expect "malformed strings.xml gives UNKNOWN" 0 '^UNKNOWN app-name: ' '!^FAIL '

variant kotlin malformed-adaptive
put "$dir/$km/res/mipmap-anydpi-v26/ic_launcher.xml" '<adaptive-icon'
run_check "$dir" --platform android
expect "malformed adaptive XML gives UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '!^FAIL '

variant kotlin malformed-webp
put "$dir/$km/res/mipmap-mdpi/ic_launcher.webp" 'RIFFxxxxWEBPVP8Lzz'
run_check "$dir" --platform android
expect "malformed WebP gives UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '!^FAIL '

variant kotlin placeholder-label
sub "$dir/$km/AndroidManifest.xml" '@string/app_name' '${appLabel}'
run_check "$dir" --platform android
expect "Gradle placeholder label is UNKNOWN" 0 '^UNKNOWN app-name: '

variant kotlin alias-catalog
rm "$dir/app/build.gradle.kts"
put "$dir/app/build.gradle.kts" 'plugins {\n  alias(libs.plugins.android.application)\n}\nandroid {\n  defaultConfig {\n    applicationId = "io.github.test.todo"\n  }\n}\n'
put "$dir/gradle/libs.versions.toml" '[plugins]\nandroid-application = { id = "com.android.application", version = "9.0.0" }\n'
run_check "$dir" --platform android
expect "version-catalog alias detects kotlin" 0 '^PASS package: '

# ---- Seeded gaps: web ------------------------------------------------------

seed vite "icon link gone" icon-sizes web "rm public/favicon.svg" 'favicon\.svg", which is missing'
seed vite "manifest icon gone" icon-sizes web "rm public/icon-64.png" 'icon-64\.png", which is missing'
seed vite "manifest size mismatch" icon-sizes web "png public/icon-64.png 32 32 6" 'is 32x32 but manifest declares'
seed vite "no icons declared" icon-sizes web "rm public/manifest.webmanifest; sub index.html '<link rel=\"icon\" href=\"/favicon.svg\">' ''; sub index.html '<link rel=\"manifest\" href=\"/manifest.webmanifest\">' ''" 'no icon declared'
seed vite "empty title, no manifest" app-name web "rm public/manifest.webmanifest; sub index.html '<title>Todo</title>' '<title> </title>'" 'name is empty'
seed vite "no title, no manifest" app-name web "rm public/manifest.webmanifest; sub index.html '<title>Todo</title>' ''" 'no name in a web manifest'
seed nextjs "icon gone" icon-sizes web "rm app/icon.png" 'no icon declared'
seed nextjs "empty title" app-name web "sub app/layout.tsx 'title: \"Todo\"' 'title: \"\"'" 'name is empty'
seed nextjs "no title" app-name web "sub app/layout.tsx 'export const metadata = { title: \"Todo\", description: \"x\" };' ''" 'sets no metadata.title'
seed static "icon gone" icon-sizes web "rm favicon.png" 'favicon\.png", which is missing'
seed static "declared size mismatch" icon-sizes web "png favicon.png 16 16 6" 'is 16x16 but index.html declares'
seed static "empty title" app-name web "sub index.html '<title>Todo</title>' '<title></title>'" 'name is empty'

variant vite no-pwa-192
run_check "$dir" --platform web
expect "web does not require 192 and 512" 0 '^PASS icon-sizes: '

variant vite inline-manifest
rm "$dir/public/manifest.webmanifest"
sub "$dir/index.html" '<link rel="manifest" href="/manifest.webmanifest">' ''
sub "$dir/index.html" '<title>Todo</title>' ''
put "$dir/vite.config.ts" 'export default { plugins: [VitePWA({ manifest: { name: "Todo" } })] };\n'
run_check "$dir" --platform web
expect "a name only in an inline vite manifest is UNKNOWN" 0 '^UNKNOWN app-name: ' '!^FAIL '

variant vite title-placeholder
rm "$dir/public/manifest.webmanifest"
sub "$dir/index.html" '<link rel="manifest" href="/manifest.webmanifest">' ''
sub "$dir/index.html" '<title>Todo</title>' '<title>%VITE_APP_TITLE%</title>'
run_check "$dir" --platform web
expect "a build placeholder in <title> is UNKNOWN" 0 '^UNKNOWN app-name: '

variant vite remote-icon
sub "$dir/index.html" 'href="/favicon.svg"' 'href="https://cdn.example.org/favicon.svg"'
run_check "$dir" --platform web
expect "a remote icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: '

variant vite malformed-manifest
put "$dir/public/manifest.webmanifest" '{"name": '
run_check "$dir" --platform web
expect "malformed manifest gives UNKNOWN" 0 '^UNKNOWN app-name: .*not valid JSON' '^UNKNOWN icon-sizes: .*not valid JSON' '!^FAIL '

variant vite malformed-icon
put "$dir/public/icon-64.png" 'junk'
run_check "$dir" --platform web
expect "malformed PNG gives UNKNOWN on web" 0 '^UNKNOWN icon-sizes: ' '!^FAIL '

variant nextjs metadata-runtime
sub "$dir/app/layout.tsx" 'export const metadata = { title: "Todo", description: "x" };' 'export async function generateMetadata() { return { title: "Todo" }; }'
run_check "$dir" --platform web
expect "generateMetadata is UNKNOWN" 0 '^UNKNOWN app-name: '

variant nextjs metadata-variable
sub "$dir/app/layout.tsx" 'title: "Todo"' 'title: siteName'
run_check "$dir" --platform web
expect "a non-literal title is UNKNOWN" 0 '^UNKNOWN app-name: '

variant nextjs dynamic-manifest
put "$dir/app/manifest.ts" 'export default function m() { return { name: "Todo" }; }\n'
sub "$dir/app/layout.tsx" 'export const metadata = { title: "Todo", description: "x" };' ''
run_check "$dir" --platform web
expect "app/manifest.ts is UNKNOWN" 0 '^UNKNOWN app-name: '

variant nextjs icon-code
rm "$dir/app/icon.png"
put "$dir/app/icon.tsx" 'export default function Icon() { return null; }\n'
run_check "$dir" --platform web
expect "a generated icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: '

variant nextjs src-app
mkdir "$dir/src"
mv "$dir/app" "$dir/src/app"
run_check "$dir" --platform web
expect "src/app is read" 0 '^PASS app-name: ' '^PASS icon-sizes: '

variant nextjs manifest-json
put "$dir/app/manifest.json" '{"name":"Todo App"}\n'
run_check "$dir" --platform web
expect "app/manifest.json name wins" 0 '^PASS app-name: "Todo App"'

# ---- Web privacy matrix ----------------------------------------------------

variant vite privacy-empty
state "$dir" '""'
run_check "$dir" --platform web --collects-data yes
expect "web empty URL, --collects-data yes" 1 '^FAIL privacy-policy-url: '
run_check "$dir" --platform web --collects-data no
expect "web empty URL, --collects-data no" 0 '^PASS privacy-policy-url: '
run_check "$dir" --platform web
expect "web empty URL, no flag" 0 '^UNKNOWN privacy-policy-url: '
state "$dir" '"not a url"'
run_check "$dir" --platform web --collects-data no
expect "web invalid URL fails whatever the flag" 1 '^FAIL privacy-policy-url: '
run_check "$tmp/vite" --platform web --collects-data no
expect "web valid URL passes with no" 0 '^PASS privacy-policy-url: "https://example.org/privacy"'
run_check "$tmp/vite" --platform web
expect "web valid URL passes with no flag" 0 '^PASS privacy-policy-url: "https://example.org/privacy"'
rm -f "$dir/.app-creators/state.md"
run_check "$dir" --platform web --collects-data no
expect "web missing state is UNKNOWN even with no" 0 '^UNKNOWN privacy-policy-url: '

# ---- State reader ----------------------------------------------------------

variant static st
url_case() {
  local label="$1" content="$2" want="$3" re="$4"
  put "$dir/.app-creators/state.md" "$content"
  run_check "$dir" --platform web --collects-data yes
  expect "state: $label" "$want" "$re"
}
good='^PASS privacy-policy-url: "https://example.org/p"$'
url_case "double quotes" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"\n---\n' 0 "$good"
url_case "single quotes" "---\nprovided:\n  publish-readiness:\n    privacy_policy_url: 'https://example.org/p'\n---\n" 0 "$good"
url_case "plain" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p\n---\n' 0 "$good"
url_case "trailing comment" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p   # the page\n---\n' 0 "$good"
url_case "quoted trailing comment" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"  # the page\n---\n' 0 "$good"
url_case "fragment stays" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p#top\n---\n' 0 '^PASS privacy-policy-url: "https://example.org/p#top"$'
url_case "flow map" '---\nprovided:\n  publish-readiness: { privacy_policy_url: "https://example.org/p", support_email_env: "" }\n---\n' 0 "$good"
url_case "flow map, plain value" '---\nprovided:\n  publish-readiness: {privacy_policy_url: https://example.org/p}  # note\n---\n' 0 "$good"
url_case "flow map at provided" '---\nprovided: { publish-readiness: { privacy_policy_url: "https://example.org/p" } }\n---\n' 0 "$good"
url_case "flow map on several lines" '---\nprovided:\n  publish-readiness: {\n    privacy_policy_url: "https://example.org/p"\n  }\n---\n' 0 "$good"
url_case "broken flow map" '---\nprovided:\n  publish-readiness: { privacy_policy_url "x"\n---\n' 0 '^UNKNOWN privacy-policy-url: '
url_case "comments and blanks between" '---\nprovided: # facts\n\n  # by skill\n  publish-readiness:\n\n    # url\n    privacy_policy_url: https://example.org/p\n---\n' 0 "$good"
url_case "other skill is not read" '---\nprovided:\n  store-listing:\n    privacy_policy_url: https://example.org/wrong\n  publish-readiness:\n    privacy_policy_url: ""\n---\n' 1 '^FAIL privacy-policy-url: '
url_case "same key at the top is not read" '---\nprivacy_policy_url: https://example.org/wrong\nprovided:\n  publish-readiness:\n    other: x\n---\n' 1 '^FAIL privacy-policy-url: '
url_case "null value" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: ~\n---\n' 1 '^FAIL privacy-policy-url: '
url_case "ftp URL" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: ftp://example.org/p\n---\n' 1 '^FAIL privacy-policy-url: .*not an http'
url_case "scheme only" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://\n---\n' 1 '^FAIL privacy-policy-url: .*not an http'
url_case "no frontmatter" 'just text\n' 0 '^UNKNOWN privacy-policy-url: '
url_case "unclosed frontmatter" '---\nprovided:\n' 0 '^UNKNOWN privacy-policy-url: '
url_case "unterminated quote" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p\n---\n' 0 '^UNKNOWN privacy-policy-url: '
printf '\377\376bad' >"$dir/.app-creators/state.md"
run_check "$dir" --platform web --collects-data yes
expect "state: not UTF-8" 0 '^UNKNOWN privacy-policy-url: '

variant xcode missing-state
rm -rf "$dir/.app-creators"
run_check "$dir" --platform ios
expect "ios missing state is UNKNOWN" 0 '^UNKNOWN privacy-policy-url: '

variant xcode bad-url-ios
state "$dir" '"www.example.org"'
run_check "$dir" --platform ios
expect "ios invalid URL fails" 1 '^FAIL privacy-policy-url: '

# ---- Exit 2 ----------------------------------------------------------------

two() {
  local label="$1" re="$2"
  shift 2
  run_check "$@"
  total=$((total + 1))
  if [ "$code" != 2 ] || [ -n "$out" ] || ! printf '%s\n' "$err" | grep -Eq -- "$re"; then
    fail "exit 2: $label" "exit $code, out '$out', err '$err'"
  else
    case "$err" in
      *Traceback*) fail "exit 2: $label" "traceback" ;;
      *) pass=$((pass + 1)) ;;
    esac
  fi
}

mkdir -p "$tmp/empty"
two "no args" 'usage:'
two "bad platform" 'invalid choice' "$tmp/xcode" --platform windows
two "missing platform" 'required' "$tmp/xcode"
two "bad collects-data" 'invalid choice' "$tmp/vite" --platform web --collects-data maybe
two "missing project" 'not found' "$tmp/does-not-exist" --platform ios
two "kotlin on ios" 'kotlin has no ios route' "$tmp/kotlin" --platform ios
two "xcode on android" 'xcode has no android route' "$tmp/xcode" --platform android
two "vite on ios" 'vite has no ios route' "$tmp/vite" --platform ios
two "vite on android" 'vite has no android route' "$tmp/vite" --platform android
two "nextjs on ios" 'nextjs has no ios route' "$tmp/nextjs" --platform ios
two "static on android" 'static has no android route' "$tmp/static" --platform android
two "unknown framework" 'no supported framework' "$tmp/empty" --platform ios
two "unreadable --expo-config" 'could not be read' "$tmp/expo" --platform ios --expo-config "$tmp/no-such-file.json"
put "$tmp/not-json.json" 'module.exports = {};\n'
two "non-JSON --expo-config" 'could not be read' "$tmp/expo" --platform ios --expo-config "$tmp/not-json.json"
variant expo no-web-carry
put "$dir/package.json" '{"name":"todo","dependencies":{"expo":"~58.0.0"}}\n'
two "expo without react-dom on web" 'no web route' "$dir" --platform web
put "$dir/package.json" '{"name":"todo","dependencies":{"expo":"~58.0.0","react-dom":"19.0.0"}}\n'
sub "$dir/app.json" '"expo":{' '"expo":{"platforms":["ios"],'
two "expo platforms list without web" 'no web route' "$dir" --platform web
two "expo platforms list without android" 'no android route' "$dir" --platform android
put "$tmp/dart-only/pubspec.yaml" 'name: lib\ndependencies:\n  path: ^1.0.0\n'
two "plain Dart package is not flutter" 'no supported framework' "$tmp/dart-only" --platform ios

variant expo dyn-web
rm "$dir/app.json"
put "$dir/app.config.ts" 'export default {};\n'
run_check "$dir" --platform web
expect "dynamic expo on web with react-dom" 0 '^UNKNOWN app-name: ' '^UNKNOWN icon-sizes: '

# ---- Detection order -------------------------------------------------------

variant expo expo-with-vite
put "$dir/vite.config.ts" 'export default {};\n'
run_check "$dir" --platform ios
expect "expo wins over a vite config" 0 '^PASS bundle-id: '

variant vite next-over-vite
put "$dir/next.config.mjs" 'export default {};\n'
two "next beats vite in the table" 'nextjs has no ios route' "$dir" --platform ios

# ---- Bounded reads (SEC-1) -------------------------------------------------

# watched <args>: like run_check, with a limit, so a read that blocks gives exit 124 instead of hanging the suite.
watched() {
  set +e
  python3 -I -c 'import subprocess,sys
out,err=open(sys.argv[1],"wb"),open(sys.argv[2],"wb")
try:
    sys.exit(subprocess.run(sys.argv[3:],stdin=subprocess.DEVNULL,stdout=out,stderr=err,timeout=20).returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)' "$tmp/w.out" "$tmp/w.err" python3 -I "$check" "$@"
  code=$?
  set -e
  out="$(cat "$tmp/w.out")"
  err="$(cat "$tmp/w.err")"
}

variant expo fifo-source
mkfifo "$dir/Pipe.ts"
watched "$dir" --platform ios
expect "FIFO source file: no hang, UNKNOWN names it" 0 '^UNKNOWN permission-strings: .*"Pipe.ts" is not a regular file' '^PASS app-name: '

variant expo fifo-appjson
rm "$dir/app.json"
mkfifo "$dir/app.json"
watched "$dir" --platform ios
expect "FIFO app.json: no hang, UNKNOWN" 0 '^UNKNOWN app-name: .*"app.json" is not a regular file' '^UNKNOWN bundle-id: ' '!^(PASS|FAIL) (app-name|bundle-id)'

variant expo dev-zero-icon
rm "$dir/assets/icon.png"
ln -s /dev/zero "$dir/assets/icon.png"
watched "$dir" --platform ios
expect "/dev/zero symlink as icon: no hang, UNKNOWN" 0 '^UNKNOWN icon-sizes: .*outside the project' '^UNKNOWN icon-alpha: .*outside the project'

variant expo outside-name
put "$tmp/outside.json" '{"expo":{"name":"OUTSIDE-VALUE","ios":{"bundleIdentifier":"io.github.out.side"}}}\n'
rm "$dir/app.json"
ln -s "$tmp/outside.json" "$dir/app.json"
watched "$dir" --platform ios
expect "symlink to an outside app.json does not supply the name" 0 '^UNKNOWN app-name: .*outside the project' '!OUTSIDE-VALUE' '!io.github.out.side'

variant expo outside-source
put "$tmp/outside.ts" 'launchCameraAsync();\n'
ln -s "$tmp/outside.ts" "$dir/Linked.ts"
watched "$dir" --platform ios
expect "symlink to an outside source file is not scanned" 0 '^UNKNOWN permission-strings: .*"Linked.ts" points outside' '!needs "NSCameraUsageDescription"'

variant expo big-appjson
python3 -I -c 'import sys
open(sys.argv[1],"w").write("{\"expo\":{\"name\":\"Todo\"},\"pad\":\""+"x"*(17*1024*1024)+"\"}")' "$dir/app.json"
watched "$dir" --platform ios
expect "oversized app.json is UNKNOWN" 0 '^UNKNOWN app-name: .*"app.json" is larger than' '!^PASS app-name: '

variant expo fifo-package
rm "$dir/app.json"
rm "$dir/package.json"
mkfifo "$dir/package.json"
watched "$dir" --platform ios
total=$((total + 1))
if [ "$code" = 2 ] && [ -z "$out" ]; then pass=$((pass + 1)); else fail "FIFO package.json" "exit $code, out '$out'"; fi

mkfifo "$tmp/config.fifo"
watched "$tmp/expo" --platform ios --expo-config "$tmp/config.fifo"
total=$((total + 1))
if [ "$code" = 2 ] && [ -z "$out" ] && printf '%s\n' "$err" | grep -q 'not a regular file'; then pass=$((pass + 1)); else fail "FIFO --expo-config" "exit $code, out '$out', err '$err'"; fi

python3 -I -c 'import sys
open(sys.argv[1],"w").write("{\"expo\":"+" "*(17*1024*1024)+"{}}")' "$tmp/big-config.json"
watched "$tmp/expo" --platform ios --expo-config "$tmp/big-config.json"
total=$((total + 1))
if [ "$code" = 2 ] && [ -z "$out" ] && printf '%s\n' "$err" | grep -q 'larger than'; then pass=$((pass + 1)); else fail "oversized --expo-config" "exit $code, err '$err'"; fi

put "$tmp/outside-config.json" '{"expo":{"name":"Operator"}}\n'
watched "$tmp/expo" --platform ios --expo-config "$tmp/outside-config.json"
expect "--expo-config outside the project is read" 1 '^PASS app-name: "Operator"'

for rel in "$xset/Contents.json" "Runner.xcodeproj/project.pbxproj" "Runner/Info.plist" ".app-creators/state.md"; do
  variant xcode fifo-any
  rm "$dir/$rel"
  mkfifo "$dir/$rel"
  watched "$dir" --platform ios
  expect "FIFO $rel: no hang" 0 'not a regular file' '!^FAIL '
done
for rel in "$km/AndroidManifest.xml" "$km/res/values/strings.xml" "app/build.gradle.kts" "$km/res/mipmap-mdpi/ic_launcher.webp" "$km/res/mipmap-anydpi-v26/ic_launcher.xml"; do
  variant kotlin fifo-any
  rm "$dir/$rel"
  mkfifo "$dir/$rel"
  put "$dir/build.gradle.kts" 'plugins { id("com.android.application") }\n'
  watched "$dir" --platform android
  expect "FIFO $rel: no hang" 0 'not a regular file' '!^FAIL '
done
for rel in index.html public/manifest.webmanifest public/favicon.svg public/icon-64.png; do
  variant vite fifo-any
  rm "$dir/$rel"
  mkfifo "$dir/$rel"
  watched "$dir" --platform web
  expect "FIFO $rel: no hang" 0 'not a regular file' '!^FAIL '
done

variant xcode dir-as-file
rm "$dir/Runner/Info.plist"
mkdir "$dir/Runner/Info.plist"
watched "$dir" --platform ios
expect "a directory where a file belongs is UNKNOWN" 0 '^UNKNOWN app-name: ' '!^FAIL '

variant kotlin xml-entities
put "$dir/$km/res/values/strings.xml" '<!DOCTYPE r [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]><resources><string name="app_name">&b;</string></resources>\n'
watched "$dir" --platform android
expect "XML with entity declarations is not expanded" 0 '^UNKNOWN app-name: .*declares XML entities'

# bigpng <path> <w> <h> <colour> <bytes in the first chunk> <chunk name>: a PNG whose first chunk after IHDR is large.
bigpng() {
  python3 -I -c 'import struct,sys,zlib
p,w,h,c,n,t=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]),int(sys.argv[5]),sys.argv[6].encode()
ch=lambda t,d:struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
open(p,"wb").write(b"\x89PNG\r\n\x1a\n"+ch(b"IHDR",struct.pack(">IIBBBBB",w,h,8,c,0,0,0))+ch(t,bytes(n))+ch(b"IDAT",bytes(16))+ch(b"IEND",b""))' "$@"
}

variant expo big-icon
bigpng "$dir/assets/icon.png" 1024 1024 2 $((17 * 1024 * 1024)) IDAT
watched "$dir" --platform ios
expect "a real icon over every read cap still passes" 0 '^PASS icon-sizes: ' '^PASS icon-alpha: ' '!^UNKNOWN '
bigpng "$dir/assets/icon.png" 1024 1024 6 $((3 * 1024 * 1024)) IDAT
watched "$dir" --platform ios
expect "a large RGBA icon is still judged from its header" 1 '^FAIL icon-alpha: '
bigpng "$dir/assets/icon.png" 1024 1024 2 $((3 * 1024 * 1024)) tEXt
watched "$dir" --platform ios
expect "metadata past the prefix before IDAT is UNKNOWN" 0 '^UNKNOWN icon-alpha: ' '!^PASS icon-alpha: '

# ---- Rendering project values (SEC-2) --------------------------------------

# safe_bytes <label> <file...>: no control, format, or line-separator character in the raw bytes.
safe_bytes() {
  local label="$1" why
  shift
  total=$((total + 1))
  why="$(python3 -I -c 'import sys,unicodedata
for p in sys.argv[1:]:
    raw=open(p,"rb").read()
    try:
        t=raw.decode("utf-8")
    except ValueError:
        print("not utf-8",p); continue
    for c in t:
        if c!="\n" and unicodedata.category(c) in ("Cc","Cf","Zl","Zp"):
            print("unsafe U+%04X in %r" % (ord(c),t)); break' "$@")"
  if [ -z "$why" ]; then pass=$((pass + 1)); else fail "$label" "$why"; fi
}

# lines_are <label> <n>: the last run printed exactly n lines.
lines_are() {
  total=$((total + 1))
  local n
  n="$(wc -l <"$tmp/w.out" | tr -d ' ')"
  if [ "$n" = "$2" ]; then pass=$((pass + 1)); else fail "$1" "$n lines, wanted $2: $(cat "$tmp/w.out")"; fi
}

jsonset() {
  python3 -I -c 'import json,sys
p,k,v=sys.argv[1:4]
d=json.load(open(p))
c=d["expo"]
ks=k.split(".")
for x in ks[:-1]:
    c=c[x]
c[ks[-1]]=v.encode().decode("unicode_escape")
json.dump(d,open(p,"w"))' "$@"
}

variant expo hostile-name
jsonset "$dir/app.json" name 'Todo\x1b[31m\u202e\n\u2028" IGNORE \\ THIS AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
watched "$dir" --platform ios
expect "hostile name: escaped, truncated, cannot break out" 0 '^PASS app-name: "Todo\[31m\\" IGNORE \\\\ THIS A+\.\.\.\[truncated\]" from the Expo config'
safe_bytes "hostile name bytes" "$tmp/w.out" "$tmp/w.err"
lines_are "hostile name: one line per check" 6

variant expo hostile-bundle
jsonset "$dir/app.json" ios.bundleIdentifier 'bad"\x1b\u202e\nid; fix: run this'
watched "$dir" --platform ios
expect "hostile bundle id in a FAIL" 1 '^FAIL bundle-id: bundle id "bad\\"id; fix: run this" must be'
safe_bytes "hostile bundle id bytes" "$tmp/w.out" "$tmp/w.err"
lines_are "hostile bundle id: one line per check" 6

variant expo hostile-file
python3 -I -c 'import os,sys
os.mkfifo(os.path.join(sys.argv[1],"a\x1b[31m\u202e\nb\".ts"))' "$dir"
watched "$dir" --platform ios
expect "hostile file name in an UNKNOWN" 0 '^UNKNOWN permission-strings: .*"a\[31mb\\"\.ts" is not a regular file'
safe_bytes "hostile file name bytes" "$tmp/w.out" "$tmp/w.err"
lines_are "hostile file name: one line per check" 6

variant xcode hostile-contents
sub "$dir/$xset/Contents.json" 'Icon-60-2x.png' 'x\u202e\u001b[2J\ny.png'
watched "$dir" --platform ios
expect "hostile Contents.json file name" 1 '^FAIL icon-sizes: "x\[2Jy.png" is listed'
safe_bytes "hostile Contents.json bytes" "$tmp/w.out" "$tmp/w.err"

variant kotlin hostile-android
sub "$dir/$km/AndroidManifest.xml" '@string/app_name' 'x&#x202E;y&#10;z&quot;'
sub "$dir/$km/AndroidManifest.xml" '@mipmap/ic_launcher' '@foo/a&#x202E;&quot;'
watched "$dir" --platform android
expect "hostile manifest values" 0 '^PASS app-name: "xyz\\"" from android:label' '^UNKNOWN icon-sizes: icon reference "@foo/a\\"" '
safe_bytes "hostile manifest bytes" "$tmp/w.out" "$tmp/w.err"
lines_are "hostile manifest: one line per check" 5

variant static hostile-url
put "$dir/.app-creators/state.md" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://exa\033[31mmple.org/\xe2\x80\xae"\n---\n'
watched "$dir" --platform web
expect "a URL holding control characters fails, rendered clean" 1 '^FAIL privacy-policy-url: privacy_policy_url "https://exa\[31mmple.org/" is not an http'
safe_bytes "hostile URL bytes" "$tmp/w.out" "$tmp/w.err"
lines_are "hostile URL: one line per check" 3

hostile_arg="$(printf 'no\033[31m\342\200\256\nsuch"project')"
watched "$tmp/$hostile_arg" --platform ios
total=$((total + 1))
if [ "$code" = 2 ] && printf '%s\n' "$err" | grep -q 'not found'; then pass=$((pass + 1)); else fail "hostile project path" "exit $code err '$err'"; fi
safe_bytes "hostile project path bytes" "$tmp/w.out" "$tmp/w.err"
total=$((total + 1))
if [ "$(wc -l <"$tmp/w.err" | tr -d ' ')" = 1 ]; then pass=$((pass + 1)); else fail "hostile project path: one line" "$err"; fi

watched "$tmp/expo" --platform ios --expo-config "$tmp/$hostile_arg"
total=$((total + 1))
if [ "$code" = 2 ] && printf '%s\n' "$err" | grep -q 'could not be read'; then pass=$((pass + 1)); else fail "hostile --expo-config path" "exit $code err '$err'"; fi
safe_bytes "hostile --expo-config bytes" "$tmp/w.out" "$tmp/w.err"
total=$((total + 1))
if [ "$(wc -l <"$tmp/w.err" | tr -d ' ')" = 1 ]; then pass=$((pass + 1)); else fail "hostile --expo-config: one line" "$err"; fi

# ---- Incomplete scans ------------------------------------------------------

variant expo big-source
python3 -I -c 'import sys
open(sys.argv[1],"w").write("launchCameraAsync();\n"+"// pad\n"*400000)' "$dir/Big.tsx"
run_check "$dir" --platform ios
expect "a source file over the scan cap is UNKNOWN, not none detected" 0 '^UNKNOWN permission-strings: .*"Big.tsx" is larger than' '!^PASS permission-strings: '
run_check "$dir" --platform android
expect "same on android" 0 '^UNKNOWN permissions-declared: .*"Big.tsx" is larger than' '!^PASS permissions-declared: '
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
run_check "$dir" --platform ios
expect "a detected gap still FAILs beside a skipped file" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

if [ "$(id -u)" != 0 ]; then
  variant expo locked-source
  put "$dir/Locked.tsx" 'launchCameraAsync();\n'
  chmod 000 "$dir/Locked.tsx"
  run_check "$dir" --platform ios
  expect "an unreadable source file is UNKNOWN" 0 '^UNKNOWN permission-strings: .*"Locked.tsx" could not be read' '!^PASS permission-strings: '
  chmod 644 "$dir/Locked.tsx"
fi

variant kotlin big-kotlin
python3 -I -c 'import sys
open(sys.argv[1],"w").write("// pad\n"*400000)' "$dir/$km/java/Big.kt"
run_check "$dir" --platform android
expect "kotlin: a skipped source file is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*Big.kt" is larger than'

variant xcode big-swift
python3 -I -c 'import sys
open(sys.argv[1],"w").write("// pad\n"*400000)' "$dir/Runner/Big.swift"
run_check "$dir" --platform ios
expect "xcode: a skipped source file is UNKNOWN" 0 '^UNKNOWN permission-strings: .*Big.swift" is larger than'

variant flutter big-dart
python3 -I -c 'import sys
open(sys.argv[1],"w").write("// pad\n"*400000)' "$dir/lib/big.dart"
run_check "$dir" --platform ios
expect "flutter: a skipped source file is UNKNOWN" 0 '^UNKNOWN permission-strings: .*big.dart" is larger than'

# ---- Android layers that cannot be judged ----------------------------------

android_icon_is() {
  variant kotlin icon-xml
  rm -rf "$dir/$km/res/mipmap-"* "$dir/$km/res/drawable"
  put "$dir/$km/res/mipmap-anydpi-v26/ic_launcher.xml" "$1"
  run_check "$dir" --platform android
}
android_icon_is '<layer-list xmlns:android="http://schemas.android.com/apk/res/android"/>\n'
expect "layer-list launcher is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"layer-list" drawable' '!^PASS icon-sizes: '
android_icon_is '<shape xmlns:android="http://schemas.android.com/apk/res/android"/>\n'
expect "shape launcher is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"shape" drawable' '!^PASS icon-sizes: '
android_icon_is '<bitmap xmlns:android="http://schemas.android.com/apk/res/android" android:src="@drawable/missing"/>\n'
expect "bitmap launcher is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"bitmap" drawable' '!^PASS icon-sizes: '
android_icon_is '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp"/>\n'
expect "legacy vector launcher is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"vector" drawable' '!^PASS icon-sizes: '
android_icon_is '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android" xmlns:aapt="http://schemas.android.com/aapt"><foreground><aapt:attr name="android:drawable"><vector/></aapt:attr></foreground></adaptive-icon>\n'
expect "inline aapt:attr foreground is UNKNOWN" 0 '^UNKNOWN icon-sizes: <foreground> in .*inline drawable' '!^PASS icon-sizes: '
android_icon_is '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><foreground/></adaptive-icon>\n'
expect "an empty adaptive foreground fails" 1 '^FAIL icon-sizes: <foreground> in .* has no drawable'

variant kotlin layer-in-adaptive
put "$dir/$km/res/drawable/ic_launcher_foreground.xml" '<layer-list xmlns:android="http://schemas.android.com/apk/res/android"/>\n'
run_check "$dir" --platform android
expect "a layer-list adaptive layer is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"layer-list" drawable' '!^PASS icon-sizes: '

variant kotlin no-density
mkdir -p "$dir/$km/res/mipmap"
png "$dir/$km/res/mipmap/ic_launcher.png" 48 48 6
run_check "$dir" --platform android
expect "a bitmap with no density qualifier is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"mipmap/ic_launcher.png" has no density' '!^PASS icon-sizes: '

variant kotlin non-resource-icon
sub "$dir/$km/AndroidManifest.xml" '@mipmap/ic_launcher' '@android:drawable/sym_def_app_icon'
run_check "$dir" --platform android
expect "a framework icon reference is UNKNOWN" 0 '^UNKNOWN icon-sizes: icon reference'

variant expo remote-android-icon
sub "$dir/app.json" './assets/fg.png' 'https://example.org/fg.png'
run_check "$dir" --platform android
expect "a remote Android icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*remote URL' '!^PASS icon-sizes: '

# ---- Comments and template literals ----------------------------------------

variant expo template-literal
sub "$dir/App.tsx" 'await ImagePicker.launchImageLibraryAsync({});' 'const glob = `assets/*`; await ImagePicker.launchCameraAsync({}); /* end */'
run_check "$dir" --platform ios
expect "a glob in a template literal does not open a comment" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

# ---- xcconfig layers -------------------------------------------------------

# with_xcconfig <project-file> <target|project> <file reference path>: point a Release configuration at an .xcconfig.
with_xcconfig() {
  local cfg
  case "$2" in
    target) cfg=97C147071CF9000F007C117D ;;
    project) cfg=97C147041CF9000F007C117D ;;
  esac
  sub "$1" "$cfg /* Release */ = {
			isa = XCBuildConfiguration;" "$cfg /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = C${cfg#?};"
  sub "$1" '	objects = {' "	objects = {
		C${cfg#?} = {
			isa = PBXFileReference;
			path = $3;
			sourceTree = \"<group>\";
		};"
}
pbx=Runner.xcodeproj/project.pbxproj
target_id='PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;'
project_id='SDKROOT = iphoneos;
			};
			name = Release;'

variant xcode xc-target-over-project
sub "$dir/$pbx" "$target_id" ''
sub "$dir/$pbx" "$project_id" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.project.level;
			};
			name = Release;'
with_xcconfig "$dir/$pbx" target Target.xcconfig
put "$dir/Target.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.from.xcconfig // note\n'
run_check "$dir" --platform ios
expect "target xcconfig beats project settings" 0 '^PASS bundle-id: "io.github.from.xcconfig" '
put "$dir/Target.xcconfig" 'OTHER = 1\n'
run_check "$dir" --platform ios
expect "project settings apply when the target xcconfig does not set it" 0 '^PASS bundle-id: "io.github.project.level" '

variant xcode xc-target-settings-win
with_xcconfig "$dir/$pbx" target Target.xcconfig
put "$dir/Target.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.from.xcconfig\n'
run_check "$dir" --platform ios
expect "target settings beat the target xcconfig" 0 '^PASS bundle-id: "io.github.test.todo" '

variant xcode xc-project-layers
sub "$dir/$pbx" "$target_id" ''
with_xcconfig "$dir/$pbx" project Project.xcconfig
put "$dir/Project.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.project.xc\n'
run_check "$dir" --platform ios
expect "the project xcconfig is the lowest layer" 0 '^PASS bundle-id: "io.github.project.xc" '
sub "$dir/$pbx" "$project_id" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.project.level;
			};
			name = Release;'
run_check "$dir" --platform ios
expect "project settings beat the project xcconfig" 0 '^PASS bundle-id: "io.github.project.level" '

variant xcode xc-include
sub "$dir/$pbx" "$target_id" ''
with_xcconfig "$dir/$pbx" target Target.xcconfig
put "$dir/Target.xcconfig" '#include "Base.xcconfig"\n#include? "Absent.xcconfig"\n'
put "$dir/Base.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.included\n#include "Deep.xcconfig"\n'
put "$dir/Deep.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.too.deep\n'
run_check "$dir" --platform ios
expect "one level of include, a missing include ignored" 0 '^PASS bundle-id: "io.github.included" '
put "$dir/Target.xcconfig" '#include "Base.xcconfig"\nPRODUCT_BUNDLE_IDENTIFIER = io.github.later\n'
run_check "$dir" --platform ios
expect "a later line beats an include" 0 '^PASS bundle-id: "io.github.later" '

variant xcode xc-inherited
sub "$dir/$pbx" "$target_id" ''
with_xcconfig "$dir/$pbx" target Target.xcconfig
put "$dir/Target.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = $(inherited).todo\n'
run_check "$dir" --platform ios
expect "\$(inherited) is UNKNOWN" 0 '^UNKNOWN bundle-id: .*inherited' '!^PASS bundle-id: '
put "$dir/Target.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER[sdk=iphoneos*] = io.github.only.device\nPRODUCT_BUNDLE_IDENTIFIER = io.github.other\n'
run_check "$dir" --platform ios
expect "a conditional in an xcconfig is UNKNOWN" 0 '^UNKNOWN bundle-id: .*conditional' '!^PASS bundle-id: '

variant xcode pbx-conditional
sub "$dir/$pbx" "$target_id" "$target_id
				\"PRODUCT_BUNDLE_IDENTIFIER[sdk=iphoneos*]\" = io.github.only.device;"
run_check "$dir" --platform ios
expect "a conditional in pbxproj settings is UNKNOWN" 0 '^UNKNOWN bundle-id: .*conditional' '!^PASS bundle-id: '

variant xcode xc-string
sub "$dir/Runner/Info.plist" '<key>NSCameraUsageDescription</key><string>Todo scans a code to add an item.</string>' ''
with_xcconfig "$dir/$pbx" target Target.xcconfig
put "$dir/Target.xcconfig" 'INFOPLIST_KEY_NSCameraUsageDescription = Scan a code.\n'
run_check "$dir" --platform ios
expect "INFOPLIST_KEY_NS* from an xcconfig counts" 0 '^PASS permission-strings: declared: "NSCameraUsageDescription"'
put "$dir/Target.xcconfig" 'INFOPLIST_KEY_NSCameraUsageDescription[sdk=iphoneos*] = Scan.\n'
run_check "$dir" --platform ios
expect "a conditional INFOPLIST_KEY string is UNKNOWN" 0 '^UNKNOWN permission-strings: "NSCameraUsageDescription" holds' '!^FAIL '

variant xcode xc-dangling
sub "$dir/Runner/Info.plist" '<key>NSCameraUsageDescription</key><string>Todo scans a code to add an item.</string>' ''
with_xcconfig "$dir/$pbx" target Absent.xcconfig
run_check "$dir" --platform ios
expect "a missing xcconfig leaves a missing string UNKNOWN" 0 '^UNKNOWN permission-strings: .*xcconfig' '^PASS bundle-id: "io.github.test.todo"' '!^FAIL '
sub "$dir/$pbx" "$target_id" ''
run_check "$dir" --platform ios
expect "a missing xcconfig leaves a setting only it could give UNKNOWN" 0 '^UNKNOWN bundle-id: .*xcconfig' '!^(PASS|FAIL) bundle-id: '

variant xcode xc-group
sub "$dir/$pbx" "$target_id" ''
with_xcconfig "$dir/$pbx" target Target.xcconfig
sub "$dir/$pbx" '	objects = {' '	objects = {
		D7C147071CF9000F007C117D = {
			isa = PBXGroup;
			children = (
				C7C147071CF9000F007C117D,
			);
			path = Config;
			sourceTree = "<group>";
		};'
put "$dir/Config/Target.xcconfig" 'PRODUCT_BUNDLE_IDENTIFIER = io.github.in.group\n'
run_check "$dir" --platform ios
expect "an xcconfig path resolves through its group" 0 '^PASS bundle-id: "io.github.in.group" '

variant xcode xc-var-path
sub "$dir/$pbx" "$target_id" ''
with_xcconfig "$dir/$pbx" target '"$(SRCROOT)/T.xcconfig"'
run_check "$dir" --platform ios
expect "an xcconfig path with a variable is UNKNOWN" 0 '^UNKNOWN bundle-id: .*xcconfig' '!^(PASS|FAIL) bundle-id: '

# ---- iOS icon set ----------------------------------------------------------

marketing='{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}'

variant xcode marketing-smaller
sub "$dir/$xset/Contents.json" "$marketing" '{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"512x512"}'
png "$dir/$xset/Icon-1024.png" 512 512 2
run_check "$dir" --platform ios
expect "a marketing entry declaring 512x512 with a small file fails" 1 '^FAIL icon-sizes: the App Store icon entry declares size "512x512"' '!1024x1024 App Store icon present'

variant xcode marketing-no-size
sub "$dir/$xset/Contents.json" "$marketing" '{"filename":"Icon-1024.png","idiom":"ios-marketing"}'
png "$dir/$xset/Icon-1024.png" 512 512 2
run_check "$dir" --platform ios
expect "a marketing entry with no size and a small file fails" 1 '^FAIL icon-sizes: the App Store icon entry declares size "none".*"Icon-1024.png" is 512x512, expected 1024x1024' '!1024x1024 App Store icon present'

variant xcode marketing-only
put "$dir/$xset/Contents.json" '{"images":[{"idiom":"iphone","scale":"2x","size":"60x60"},{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}]}\n'
run_check "$dir" --platform ios
expect "only the marketing well filled is UNKNOWN" 0 '^UNKNOWN icon-sizes: the set lists device sizes' '!^PASS icon-sizes: '

variant xcode two-iconsets
mkdir -p "$dir/Other/Assets.xcassets"
cp -R "$dir/$xset" "$dir/Other/Assets.xcassets/"
run_check "$dir" --platform ios
expect "two matching icon sets are UNKNOWN" 0 '^UNKNOWN icon-sizes: more than one "AppIcon.appiconset"' '^UNKNOWN icon-alpha: more than one'

variant xcode two-xcodeproj
cp -R "$dir/Runner.xcodeproj" "$dir/Other.xcodeproj"
run_check "$dir" --platform ios
expect "two .xcodeproj are UNKNOWN" 0 '^UNKNOWN app-name: more than one .xcodeproj' '^UNKNOWN bundle-id: more than one'

variant xcode no-release
sub "$dir/$pbx" 'name = Release;' 'name = Staging;'
run_check "$dir" --platform ios
expect "no Release configuration is UNKNOWN" 0 '^UNKNOWN bundle-id: .*no Release configuration' '!^PASS bundle-id: '

variant xcode no-app-target
sub "$dir/$pbx" 'com.apple.product-type.application' 'com.apple.product-type.framework'
run_check "$dir" --platform ios
expect "no application target is UNKNOWN" 0 '^UNKNOWN bundle-id: .*no application target'

# Native routes: alpha has no Apple source, so it is UNKNOWN; Expo's config route stays FAIL.
variant xcode alpha-native
png "$dir/$xset/Icon-1024.png" 1024 1024 6
run_check "$dir" --platform ios
expect "xcode: an alpha channel is UNKNOWN, with the reason" 0 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document' '!^FAIL '
variant flutter alpha-native
png "$dir/$set_dir/Icon-1024.png" 1024 1024 3 trns
run_check "$dir" --platform ios
expect "flutter: tRNS is UNKNOWN, with the reason" 0 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document' '!^FAIL '
variant expo alpha-expo-native
apple_tree "$dir/ios"
png "$dir/ios/$xset/Icon-1024.png" 1024 1024 6
run_check "$dir" --platform ios
expect "expo with a native ios/: an alpha channel is UNKNOWN" 1 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document' '!^FAIL icon-alpha: '
variant expo alpha-expo-config
png "$dir/assets/icon.png" 1024 1024 6
run_check "$dir" --platform ios
expect "the Expo config route: an alpha channel still FAILs, from Expo's docs" 1 "^FAIL icon-alpha: .*has an alpha channel or transparency; Expo's docs say"

variant xcode webp-alpha
webp "$dir/$xset/Icon-1024.png" VP8L 1024 1024
run_check "$dir" --platform ios
expect "xcode: WebP alpha cannot be read" 0 '^UNKNOWN icon-alpha: .*not a PNG' '^PASS icon-sizes: '
variant expo webp-alpha-expo
webp "$dir/assets/icon.png" VP8L 1024 1024
run_check "$dir" --platform ios
expect "expo: WebP alpha cannot be read" 0 '^UNKNOWN icon-alpha: .*not a PNG'

# ---- Every gap on one line -------------------------------------------------

variant xcode all-gaps
put "$dir/Runner/App.swift" 'import CoreBluetooth\nlet a = CBCentralManager()\nlet b = CMPedometer()\n'
png "$dir/$xset/Icon-1024.png" 512 512 2
png "$dir/$xset/Icon-60-2x.png" 60 60 2
run_check "$dir" --platform ios
expect "strings: every gap on one line" 1 '^FAIL permission-strings: .*needs "NSBluetoothAlwaysUsageDescription".*needs "NSMotionUsageDescription".*; fix: .*NSBluetoothAlwaysUsageDescription.*NSMotionUsageDescription'
expect "icons: every gap on one line" 1 '^FAIL icon-sizes: .*"Icon-60-2x.png" is 60x60.*"Icon-1024.png" is 512x512.*; fix: .*120x120.*1024x1024'

variant kotlin all-android-gaps
put "$dir/$km/java/io/test/L.kt" 'val a = Manifest.permission.READ_SMS\nval b = Manifest.permission.READ_CONTACTS\n'
webp "$dir/$km/res/mipmap-hdpi/ic_launcher.webp" VP8L 96 96
webp "$dir/$km/res/mipmap-mdpi/ic_launcher.webp" VP8L 96 96
run_check "$dir" --platform android
expect "permissions and icons: every gap on one line" 1 '^FAIL permissions-declared: .*"READ_CONTACTS", which is not declared.*"READ_SMS", which is not declared; fix: .*READ_CONTACTS.*READ_SMS' '^FAIL icon-sizes: .*mipmap-hdpi.*is 96x96, expected 72x72.*mipmap-mdpi.*is 96x96, expected 48x48; fix: .*72x72.*48x48'

variant expo unknown-beside-fail
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
mkfifo "$dir/Pipe.ts"
watched "$dir" --platform ios
expect "a FAIL outranks a skipped file" 1 '^FAIL permission-strings: ' '!^UNKNOWN permission-strings: '

# ---- False FAILs -----------------------------------------------------------

variant kotlin other-values-file
sub "$dir/$km/res/values/strings.xml" '<string name="app_name">Todo</string>' ''
put "$dir/$km/res/values/app.xml" '<resources><string name="app_name">Todo</string></resources>\n'
run_check "$dir" --platform android
expect "app_name in another values file is found" 0 '^PASS app-name: "Todo" from "app/src/main/res/values/app.xml"'

variant kotlin res-value
sub "$dir/$km/res/values/strings.xml" '<string name="app_name">Todo</string>' ''
sub "$dir/app/build.gradle.kts" 'versionCode = 1' 'resValue("string", "app_name", "Todo")'
run_check "$dir" --platform android
expect "resValue in gradle is UNKNOWN" 0 '^UNKNOWN app-name: .*resValue' '!^FAIL '

variant kotlin bad-other-values
sub "$dir/$km/res/values/strings.xml" '<string name="app_name">Todo</string>' ''
put "$dir/$km/res/values/broken.xml" '<resources><string'
run_check "$dir" --platform android
expect "a malformed values file leaves a missing name UNKNOWN" 0 '^UNKNOWN app-name: .*broken.xml'

variant expo empty-native
mkdir -p "$dir/ios" "$dir/android"
run_check "$dir" --platform ios
expect "an empty ios/ does not win" 0 '^PASS bundle-id: .* from ios.bundleIdentifier'
run_check "$dir" --platform android
expect "an empty android/ does not win" 0 '^PASS package: .* from android.package'

variant expo partial-native
mkdir -p "$dir/ios/Runner" "$dir/android/app/src"
run_check "$dir" --platform ios
expect "ios/ with no .xcodeproj does not win" 0 '^PASS bundle-id: .* from ios.bundleIdentifier'
run_check "$dir" --platform android
expect "android/ with no app/build.gradle does not win" 0 '^PASS package: .* from android.package'

for plugin in '"./plugins/with-strings.js"' '"../shared/plugin"' '"expo-some-other-module"' '["./plugins/with-strings.js",{"x":1}]'; do
  variant expo local-plugin
  sub "$dir/app.json" '"plugins":[' "\"plugins\":[$plugin,"
  sub "$dir/app.json" '"photosPermission":"Todo reads one photo you attach."' '"x":1'
  run_check "$dir" --platform ios
  expect "plugin $plugin can set a string: UNKNOWN" 0 '^UNKNOWN permission-strings: .*can set it' '!^FAIL '
done

variant expo plugin-empty-still-fails
sub "$dir/app.json" '"plugins":[' '"plugins":["./plugins/x.js",'
sub "$dir/app.json" 'Todo reads one photo you attach.' ''
run_check "$dir" --platform ios
expect "a declared empty string still fails beside a plugin" 1 '^FAIL permission-strings: .*is declared but empty'

variant expo plugin-blocked-still-fails
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
sub "$dir/app.json" '"plugins":[' '"plugins":["./plugins/x.js",'
sub "$dir/app.json" '"android":{' '"android":{"blockedPermissions":["android.permission.CAMERA"],'
run_check "$dir" --platform android
expect "a blocked permission still fails beside a plugin" 1 '^FAIL permissions-declared: .*"CAMERA", which the project removes'

variant expo plugin-undeclared
sub "$dir/App.tsx" 'ImagePicker.launchImageLibraryAsync({})' 'ImagePicker.requestCalendarPermissionsAsync()'
sub "$dir/app.json" '"plugins":[' '"plugins":["./plugins/x.js",'
run_check "$dir" --platform android
expect "an undeclared permission beside a plugin is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*"READ_CALENDAR", and the config plugin "./plugins/x.js" can set it' '!^FAIL '

variant expo plugin-non-string
sub "$dir/app.json" '"plugins":[' '"plugins":[{"x":1},'
sub "$dir/app.json" '"photosPermission":"Todo reads one photo you attach."' '"x":1'
run_check "$dir" --platform ios
expect "a plugin entry that is not a name is UNKNOWN" 0 '^UNKNOWN permission-strings: .*not a name can set it' '!^FAIL '

variant nextjs pages-router
rm -rf "$dir/app"
put "$dir/pages/index.tsx" 'export default function P() { return null; }\n'
png "$dir/public/favicon.png" 32 32 6
run_check "$dir" --platform web
expect "pages router: public/favicon.* is a declared icon; the title is runtime" 0 '^PASS icon-sizes: ' '^UNKNOWN app-name: .*pages router' '!^PASS app-name: '
put "$dir/public/favicon.ico" 'x'
rm "$dir/public/favicon.png"
run_check "$dir" --platform web
expect "pages router: favicon.ico counts" 0 '^PASS icon-sizes: '
rm "$dir/public/favicon.ico"
run_check "$dir" --platform web
expect "pages router with no favicon fails" 1 '^FAIL icon-sizes: no icon declared'
variant nextjs src-pages-router
rm -rf "$dir/app"
put "$dir/src/pages/index.tsx" 'export default function P() { return null; }\n'
png "$dir/public/favicon.png" 32 32 6
run_check "$dir" --platform web
expect "src/pages counts as the pages router" 0 '^PASS icon-sizes: ' '^UNKNOWN app-name: .*pages router'

variant nextjs no-router-favicon
rm -rf "$dir/app"
png "$dir/public/favicon.png" 32 32 6
run_check "$dir" --platform web
expect "no router at all: public/favicon does not count" 1 '^FAIL icon-sizes: no icon declared' '^FAIL app-name: no root layout'

variant nextjs metadata-icons
rm "$dir/app/icon.png"
sub "$dir/app/layout.tsx" 'description: "x"' 'icons: { icon: "/x.png" }'
run_check "$dir" --platform web
expect "metadata.icons is UNKNOWN" 0 '^UNKNOWN icon-sizes: metadata.icons'

# ---- Next.js metadata.title ------------------------------------------------

meta_is() {
  variant nextjs meta
  put "$dir/app/layout.tsx" "$1"
  run_check "$dir" --platform web
}
meta_is 'export const metadata = { title: runtimeTitle, openGraph: { title: "Share title" } };\n'
expect "a nested title is not the title" 0 '^UNKNOWN app-name: .*not a literal' '!Share title'
meta_is 'export const metadata = { description: "x" };\nconst nav = { title: "Home" };\n'
expect "a later object is not metadata" 1 '^FAIL app-name: metadata in the root layout has no title' '!Home'
meta_is 'export const metadata = { openGraph: { title: "Share" }, description: "title: nope" };\n'
expect "nested and quoted titles do not count" 1 '^FAIL app-name: metadata in the root layout has no title'
meta_is 'export const metadata = { title: { default: "Todo", template: "%s | Todo" } };\n'
expect "the default form" 0 '^PASS app-name: "Todo" from metadata.title'
meta_is 'export const metadata = { title: { template: "%s | Todo" } };\n'
expect "a title object with no default is UNKNOWN" 0 '^UNKNOWN app-name: metadata.title has no default'
meta_is 'export const metadata = { title: { default: name } };\n'
expect "a non-literal default is UNKNOWN" 0 '^UNKNOWN app-name: .*not a literal'
meta_is 'export const metadata = { "title": "Quoted" };\n'
expect "a quoted key" 0 '^PASS app-name: "Quoted" from metadata.title'
meta_is 'export const metadata = { subtitle: "No", my_title: "No" };\n'
expect "a longer key is not title" 1 '^FAIL app-name: metadata in the root layout has no title'
meta_is 'export const metadata: Metadata = { title: `Todo`, };\n'
expect "a typed metadata and a plain template" 0 '^PASS app-name: "Todo" from metadata.title'
meta_is 'export const metadata = { title: `Todo ${x}` };\n'
expect "an interpolated template is UNKNOWN" 0 '^UNKNOWN app-name: .*not a literal'
meta_is 'export const metadata = { title: "Todo" + suffix };\n'
expect "concatenation is UNKNOWN" 0 '^UNKNOWN app-name: .*not a literal'
meta_is 'export const metadata = { ...base, description: "x" };\n'
expect "a spread with no title is UNKNOWN" 0 '^UNKNOWN app-name: .*spreads'
meta_is 'export const metadata = buildMetadata();\n'
expect "metadata that is not an object is UNKNOWN" 0 '^UNKNOWN app-name: .*not an object literal'
meta_is 'export default function L({children}) { return children; }\n'
expect "no metadata fails" 1 '^FAIL app-name: the root layout sets no metadata.title'

# ---- .easignore ------------------------------------------------------------

variant expo ignore-native
apple_tree "$dir/ios"
android_tree "$dir/android"
ios_wins='^PASS bundle-id: .* from PRODUCT_BUNDLE_IDENTIFIER'
ios_config='^PASS bundle-id: .* from ios.bundleIdentifier'
for form in ios ios/ /ios /ios/ 'ios/*' '/ios/*' 'ios/**' '/ios/**'; do
  put "$dir/.gitignore" "node_modules\n$form\n"
  run_check "$dir" --platform ios
  expect "the .gitignore form $form means the folder is ignored" 0 "$ios_config"
done
put "$dir/.gitignore" 'ios-old/\niosx\n# ios\n'
run_check "$dir" --platform ios
expect "other .gitignore lines do not ignore ios/" 1 "$ios_wins"
put "$dir/.gitignore" 'ios/\n'
put "$dir/.easignore" 'node_modules\n'
run_check "$dir" --platform ios
expect ".easignore replaces .gitignore: not ignored there, ios/ wins" 1 "$ios_wins"
rm "$dir/.gitignore"
put "$dir/.easignore" '/ios/*\n'
run_check "$dir" --platform ios
expect ".easignore alone can ignore ios/" 0 "$ios_config"
put "$dir/.easignore" '/android/*\n'
run_check "$dir" --platform android
expect ".easignore can ignore android/" 0 '^PASS package: .* from android.package'

# ---- Web icons -------------------------------------------------------------

variant vite data-icon
sub "$dir/index.html" 'href="/favicon.svg"' 'href="data:image/svg+xml,%3Csvg/%3E"'
run_check "$dir" --platform web
expect "a data: icon link is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*inline data: URL' '!^PASS icon-sizes: '

variant vite data-manifest-icon
sub "$dir/public/manifest.webmanifest" '"/icon-64.png"' '"data:image/png;base64,AAAA"'
run_check "$dir" --platform web
expect "a data: manifest icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: an icon in manifest is an inline data: URL'

# ---- Identifiers and scan scope --------------------------------------------

variant expo double-dot
sub "$dir/app.json" 'io.github.test.todo"},"android"' 'com..foo"},"android"'
run_check "$dir" --platform ios
expect "an empty bundle id segment fails" 1 '^FAIL bundle-id: bundle id "com..foo" must be'
for bad in '.com.foo' 'com.foo.'; do
  variant expo edge-dot
  sub "$dir/app.json" 'io.github.test.todo"},"android"' "$bad\"},\"android\""
  run_check "$dir" --platform ios
  expect "bundle id $bad fails" 1 '^FAIL bundle-id: '
done

variant expo hyphen-id
sub "$dir/app.json" 'io.github.test.todo"},"android"' 'io.github.my-app"},"android"'
run_check "$dir" --platform ios
expect "a hyphen in a bundle id passes" 0 '^PASS bundle-id: "io.github.my-app"'

for ext in mjs cjs mts; do
  variant expo scan-ext
  put "$dir/extra.$ext" 'launchCameraAsync();\n'
  run_check "$dir" --platform ios
  expect "expo scans .$ext" 1 "^FAIL permission-strings: \"extra.$ext\" uses an API that needs \"NSCameraUsageDescription\""
done

variant flutter android-scope
put "$dir/packages/x/android/P.kt" 'val a = Manifest.permission.READ_SMS\n'
put "$dir/tool/T.java" 'class T { String a = "android.permission.READ_SMS"; }\n'
run_check "$dir" --platform android
expect "flutter's Android scan covers only android/" 0 '^PASS permissions-declared: ' '!READ_SMS'

for id in com.example.todo com.example; do
  variant kotlin example-id
  sub "$dir/app/build.gradle.kts" 'applicationId = "io.github.test.todo"' "applicationId = \"$id\""
  run_check "$dir" --platform android
  expect "$id has no sourced store rule, so it passes" 0 "^PASS package: \"$id\""
done

variant kotlin two-app-ids
sub "$dir/app/build.gradle.kts" 'versionCode = 1' 'applicationId = "io.github.test.other"'
run_check "$dir" --platform android
expect "two different applicationIds are UNKNOWN" 0 '^UNKNOWN package: .*more than one applicationId' '!^PASS package: '

# ---- Permission rows -------------------------------------------------------

variant xcode unresolved-string
sub "$dir/Runner/Info.plist" 'Todo scans a code to add an item.' '$(CAMERA_REASON)'
run_check "$dir" --platform ios
expect "an unresolved \$(VAR) on a permission string is UNKNOWN" 0 '^UNKNOWN permission-strings: "NSCameraUsageDescription" holds a build variable' '!^(PASS|FAIL) permission-strings: '
sub "$dir/$pbx" "$target_id" "$target_id
				CAMERA_REASON = Scan.;"
run_check "$dir" --platform ios
expect "a resolved \$(VAR) on a permission string passes" 0 '^PASS permission-strings: '

variant xcode nonstring-plist
sub "$dir/Runner/Info.plist" '<string>Todo scans a code to add an item.</string>' '<integer>1</integer>'
run_check "$dir" --platform ios
expect "a non-string permission value fails" 1 '^FAIL permission-strings: "NSCameraUsageDescription" is declared but empty'
variant xcode nonstring-name
sub "$dir/Runner/Info.plist" '<key>CFBundleDisplayName</key><string>Todo</string>' '<key>CFBundleDisplayName</key><integer>1</integer>'
run_check "$dir" --platform ios
expect "a non-string display name fails" 1 '^FAIL app-name: the app name is empty'

variant kotlin sdk23
sub "$dir/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission-sdk-23 android:name="android.permission.CAMERA" />'
run_check "$dir" --platform android
expect "uses-permission-sdk-23 declares a permission" 0 '^PASS permissions-declared: declared dangerous: "CAMERA"'

variant xcode always-half
put "$dir/Runner/App.swift" 'func go(m: CLLocationManager) { m.requestAlwaysAuthorization() }\n'
sub "$dir/Runner/Info.plist" '<key>NSCameraUsageDescription</key><string>Todo scans a code to add an item.</string>' '<key>NSLocationAlwaysAndWhenInUseUsageDescription</key><string>Todo tracks a route.</string>'
run_check "$dir" --platform ios
expect "requestAlwaysAuthorization also needs the when-in-use key" 1 '^FAIL permission-strings: .*needs "NSLocationWhenInUseUsageDescription"' '!needs "NSLocationAlwaysAndWhenInUse'
sub "$dir/Runner/Info.plist" '<key>NSLocationAlwaysAndWhenInUseUsageDescription</key><string>Todo tracks a route.</string>' '<key>NSLocationWhenInUseUsageDescription</key><string>Todo tracks a route.</string>'
run_check "$dir" --platform ios
expect "requestAlwaysAuthorization also needs the always key" 1 '^FAIL permission-strings: .*needs "NSLocationAlwaysAndWhenInUseUsageDescription"' '!needs "NSLocationWhenInUse'

apple_row() {
  variant xcode apple-row
  put "$dir/Runner/App.swift" "$1\n"
  run_check "$dir" --platform ios
  expect "swift row $2" 1 "^FAIL permission-strings: \"Runner/App.swift\" uses an API that needs \"$2\""
}
apple_row 'let c = CBCentralManager()' NSBluetoothAlwaysUsageDescription
apple_row 'let c = CBPeripheralManager()' NSBluetoothAlwaysUsageDescription
apple_row 'let c = CMPedometer()' NSMotionUsageDescription
apple_row 'let c = CMMotionActivityManager()' NSMotionUsageDescription
apple_row 'ATTrackingManager.requestTrackingAuthorization { _ in }' NSUserTrackingUsageDescription
apple_row 'c.evaluatePolicy(p, localizedReason: "x") { _, _ in }' NSFaceIDUsageDescription

variant flutter dart-faceid
put "$dir/lib/auth.dart" 'final a = LocalAuthentication();\n'
run_check "$dir" --platform ios
expect "dart LocalAuthentication needs the Face ID key" 1 '^FAIL permission-strings: "lib/auth.dart" uses an API that needs "NSFaceIDUsageDescription"'

expo_row() {
  variant expo expo-row
  put "$dir/Row.ts" "$1\n"
  run_check "$dir" --platform ios
  expect "expo row $2" 1 "^FAIL permission-strings: \"Row.ts\" uses an API that needs \"$2\""
}
expo_row 'requestTrackingPermissionsAsync();' NSUserTrackingUsageDescription
expo_row "import * as C from 'expo-contacts'; C.getContactsAsync();" NSContactsUsageDescription
expo_row "import * as C from 'expo-contacts'; C.requestPermissionsAsync();" NSContactsUsageDescription
expo_row "import * as L from 'expo-local-authentication'; L.authenticateAsync();" NSFaceIDUsageDescription

# The base tree declares the photo string, which satisfies both media-library rows, so these drop it.
expo_media_row() {
  variant expo expo-media-row
  put "$dir/App.tsx" 'export default function App() { return null; }\n'
  sub "$dir/app.json" '"photosPermission":"Todo reads one photo you attach."' '"x":1'
  put "$dir/Row.ts" "$1\n"
  run_check "$dir" --platform ios
  expect "expo media row $2" 1 "^FAIL permission-strings: \"Row.ts\" uses an API that needs \"$2\""
}
expo_media_row "import * as M from 'expo-media-library'; M.getAssetsAsync();" NSPhotoLibraryUsageDescription
expo_media_row "import * as M from 'expo-media-library'; M.saveToLibraryAsync(x);" NSPhotoLibraryAddUsageDescription

variant expo expo-module-guard
put "$dir/Row.ts" 'requestPermissionsAsync();\n'
run_check "$dir" --platform ios
expect "requestPermissionsAsync without a named module is not contacts" 0 '^PASS permission-strings: ' '!NSContactsUsageDescription'

variant expo record-audio-off
put "$dir/Row.ts" 'useMicrophonePermissions();\n'
sub "$dir/app.json" '"plugins":[' '"plugins":[["expo-camera",{"recordAudioAndroid":false}],'
run_check "$dir" --platform android
expect "recordAudioAndroid false blocks a needed microphone" 1 '^FAIL permissions-declared: "Row.ts" uses an API that needs "RECORD_AUDIO", which the project removes'

variant expo record-audio-off-audio
put "$dir/Row.ts" 'useAudioRecorder();\n'
sub "$dir/app.json" '"plugins":[' '"plugins":[["expo-audio",{"recordAudioAndroid":false}],'
run_check "$dir" --platform android
expect "expo-audio's recordAudioAndroid false blocks it too" 1 '^FAIL permissions-declared: "Row.ts" uses an API that needs "RECORD_AUDIO", which the project removes'

# ---- State reader, block scalars -------------------------------------------

variant static block-scalar
put "$dir/.app-creators/state.md" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: |\n      https://example.org/p\n---\n'
run_check "$dir" --platform web --collects-data yes
expect "a block scalar URL is UNKNOWN, not read as a URL" 0 '^UNKNOWN privacy-policy-url: .*block scalar' '!^PASS privacy-policy-url: '

# ---- Crafted input stays fast ----------------------------------------------

# pad <file> <anchor> <token> [closing token]: 2 MB of tokens after the anchor; an empty anchor writes a new file.
pad() {
  python3 -I -c 'import os,sys
p,a,t=sys.argv[1:4]
c=sys.argv[4] if len(sys.argv)>4 else ""
n=2097152//(len(t)+len(c))
s=open(p).read() if a else ""
assert not a or a in s,a
os.makedirs(os.path.dirname(p),exist_ok=True)
open(p,"w").write(s.replace(a,a+t*n+c*n,1) if a else t*n)' "$@"
}

for token in '/* ' '\"' "\\'" '\`'; do
  variant expo slow-source
  pad "$dir/Slow.ts" '' "$token"
  watched "$dir" --platform ios
  expect "2 MB of $token in a source file" 0 '^PASS permission-strings: '
done

variant flutter slow-dart
pad "$dir/lib/slow.dart" '' 'pickVideo('
watched "$dir" --platform ios
expect "2 MB of pickVideo( in Dart" 0 '^PASS app-name: '

variant xcode slow-pbx-nested
pad "$dir/$pbx" '	objects = {' '
		97C146ED1CF9000F007C117E = {' '
		}'
watched "$dir" --platform ios
expect "2 MB of nested pbxproj blocks" 0 '^PASS bundle-id: "io.github.test.todo"'

variant xcode slow-pbx-blank
pad "$dir/$pbx" '	objects = {' '
' 'x'
watched "$dir" --platform ios
expect "2 MB of blank pbxproj lines" 0 '^PASS bundle-id: "io.github.test.todo"'

variant xcode slow-pbx-equals
pad "$dir/$pbx" "$target_id
" '=' '
'
watched "$dir" --platform ios
expect "2 MB of = on a pbxproj settings line" 0 '^PASS bundle-id: '

variant xcode slow-pbx-list
pad "$dir/$pbx" '97C147061CF9000F007C117D /* Debug */,' '97C147061CF9000F007C117D /* '
sub "$dir/$pbx" '97C147061CF9000F007C117D /* Debug */,' ''
watched "$dir" --platform ios
expect "2 MB of unclosed comments on a configuration list line" 0 '^PASS bundle-id: "io.github.test.todo"'

variant xcode slow-plist-var
pad "$dir/Runner/Info.plist" '<string>Todo scans a code to add an item.' '$('
watched "$dir" --platform ios
expect "2 MB of \$( in a plist string" 0 '^PASS app-name: '

variant kotlin slow-res-value
sub "$dir/$km/res/values/strings.xml" '<string name="app_name">Todo</string>' ''
pad "$dir/app/build.gradle.kts" 'versionCode = 1' ' resValue'
watched "$dir" --platform android
expect "2 MB of resValue on a gradle line" 1 '^FAIL app-name: '

variant vite slow-catalog
pad "$dir/app/build.gradle.kts" '' 'alias(libs.plugins.a)
'
pad "$dir/gradle/libs.versions.toml" '' 'x = 1
'
watched "$dir" --platform web
expect "2 MB of plugin aliases against a 2 MB catalog" 0 '^PASS app-name: '

variant static slow-state-key
put "$dir/.app-creators/state.md" '---\nprovided\n---\n'
pad "$dir/.app-creators/state.md" 'provided' ' '
watched "$dir" --platform web --collects-data no
expect "2 MB of spaces after a state key" 0 '^PASS privacy-policy-url: '

variant static slow-state-flow
put "$dir/.app-creators/state.md" '---\nprovided:\n  publish-readiness: {\n---\n'
pad "$dir/.app-creators/state.md" 'readiness: {
' '{
'
watched "$dir" --platform web --collects-data no
expect "2 MB of open flow lines in state" 0 '^UNKNOWN privacy-policy-url: .*flow map'

variant nextjs slow-metadata
pad "$dir/app/layout.tsx" '' 'metadata '
watched "$dir" --platform web
expect "2 MB of metadata tokens with no object" 0 '^UNKNOWN app-name: .*not an object literal'

# The faster stripper keeps what it decides.
variant expo unclosed-comment
sub "$dir/App.tsx" 'await ImagePicker.launchImageLibraryAsync({});' 'const r = /\/*/; await ImagePicker.launchCameraAsync({});'
run_check "$dir" --platform ios
expect "an unclosed /* does not hide code after it" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

variant expo closed-comments
put "$dir/Row.ts" '/* launchCameraAsync(); */ const u = "http://x"; // launchCameraAsync();\n/* useMicrophonePermissions(); */\n'
run_check "$dir" --platform ios
expect "closed comments still hide an API" 0 '^PASS permission-strings: ' '!NSCameraUsageDescription' '!NSMicrophoneUsageDescription'

variant expo unclosed-string
put "$dir/Row.ts" "const a = 'open\nlaunchCameraAsync();\n"
run_check "$dir" --platform ios
expect "an unclosed quote ends at its line" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

variant flutter pick-video-args
put "$dir/lib/v.dart" 'final v = ImagePicker().pickVideo(\n  maxDuration: d,\n  source: ImageSource.camera);\n'
run_check "$dir" --platform ios
expect "pickVideo with several arguments still needs the microphone" 1 '^FAIL permission-strings: .*needs "NSMicrophoneUsageDescription"'

variant kotlin catalog-alias
sub "$dir/app/build.gradle.kts" 'id("com.android.application")' 'alias(libs.plugins.android.application)'
put "$dir/gradle/libs.versions.toml" '[plugins]\nandroid-application = { id = "com.android.application", version = "8" }\n'
run_check "$dir" --platform android
expect "a version catalog alias still marks an Android app" 0 '^PASS package: '

# ---- Fixtures --------------------------------------------------------------

fixture_repo=""
for candidate in \
  "$root/../app-creators-fixtures" \
  "$(dirname "$(cd "$root" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo .)")/../app-creators-fixtures"; do
  if [ -e "$candidate/.git" ]; then
    fixture_repo="$candidate"
    break
  fi
done

skip_why=""
if [ -z "$fixture_repo" ]; then
  skip_why="no app-creators-fixtures checkout next to the repo or the main checkout"
else
  for sha in ff71355 95c2f95; do
    if ! (cd "$fixture_repo" && git cat-file -e "$sha^{commit}" 2>/dev/null); then
      skip_why="commit $sha is not in $fixture_repo"
    fi
  done
fi

if [ -n "$skip_why" ]; then
  echo "SKIP fixture cases: $skip_why"
else
  mkdir -p "$tmp/fx"
  (cd "$fixture_repo" && git archive --format=tar ff71355 todo-expo) | tar -xf - -C "$tmp/fx"
  (cd "$fixture_repo" && git archive --format=tar 95c2f95 todo-vite) | tar -xf - -C "$tmp/fx"
  state "$tmp/fx/todo-expo" '"https://example.org/privacy"'
  state "$tmp/fx/todo-vite" '"https://example.org/privacy"'
  run_check "$tmp/fx/todo-expo" --platform ios
  expect "fixture todo-expo ios" 0 '^PASS bundle-id: ' '^PASS icon-alpha: ' '^PASS permission-strings: .*needed by code: "NSPhotoLibraryUsageDescription"' '!^FAIL '
  run_check "$tmp/fx/todo-expo" --platform android
  expect "fixture todo-expo android" 0 '^PASS package: ' '^PASS icon-sizes: ' '!^FAIL '
  run_check "$tmp/fx/todo-vite" --platform web
  expect "fixture todo-vite web" 0 '^PASS app-name: "Todo" from index.html' '^PASS icon-sizes: ' '!^FAIL '

  gap="$tmp/fx/todo-expo-gap"
  cp -R "$tmp/fx/todo-expo" "$gap"
  python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
del d["expo"]["plugins"][0][1]["photosPermission"]
json.dump(d,open(sys.argv[1],"w"))' "$gap/app.json"
  png "$gap/assets/icon.png" 1024 1024 6
  rm "$gap/assets/android-icon-foreground.png"
  state "$gap" '""'
  run_check "$gap" --platform ios
  expect "seeded todo-expo ios" 1 '^FAIL permission-strings: .*needs "NSPhotoLibraryUsageDescription"' '^FAIL icon-alpha: .*has an alpha channel' '^FAIL privacy-policy-url: no privacy policy URL'
  run_check "$gap" --platform android
  expect "seeded todo-expo android" 1 '^FAIL icon-sizes: .*foregroundImage.*missing' '^FAIL privacy-policy-url: no privacy policy URL'
fi

if [ "$pass" -eq "$total" ]; then
  echo "PASS $pass/$total"
  exit 0
fi
printf '%s\n' "$failed"
echo "FAIL $((total - pass))/$total"
exit 1
