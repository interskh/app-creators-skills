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

# seed <base tree> <label> <check id> <platform> <shell command run in the copy>: FAIL <id> and exit 1.
seed() {
  local base="$1" label="$2" id="$3" platform="$4" cmd="$5" name
  name="$base-$(printf '%s' "$label" | tr -c 'a-zA-Z0-9' '-')"
  variant "$base" "$name"
  (cd "$dir" && eval "$cmd")
  run_check "$dir" --platform "$platform"
  expect "$base/$platform: $label" 1 "^FAIL $id: "
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
expect "flutter ios clean" 0 '^PASS bundle-id: io.github.test.todo from PRODUCT_BUNDLE_IDENTIFIER' '^PASS icon-alpha: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/flutter" --platform android
expect "flutter android clean" 0 '^PASS package: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/flutter" --platform web
expect "flutter web clean" 0 '^PASS app-name: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/xcode" --platform ios
expect "xcode ios clean" 0 '^PASS app-name: "Todo" from CFBundleDisplayName' '^PASS permission-strings: .*NSCameraUsageDescription' '!^(FAIL|UNKNOWN) '
run_check "$tmp/kotlin" --platform android
expect "kotlin android clean, WebP launcher" 0 '^PASS app-name: "Todo"' '^PASS permissions-declared: declared dangerous: CAMERA' '!^(FAIL|UNKNOWN) '
run_check "$tmp/vite" --platform web
expect "vite web clean" 0 '^PASS app-name: "Todo" from public/manifest.webmanifest' '!^(FAIL|UNKNOWN) '
run_check "$tmp/nextjs" --platform web
expect "nextjs web clean" 0 '^PASS app-name: "Todo" from metadata.title' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/static" --platform web
expect "static web clean" 0 '^PASS app-name: "Todo" from index.html' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '

# ---- Seeded gaps: expo -----------------------------------------------------

seed expo "missing icon" icon-sizes ios 'rm assets/icon.png'
seed expo "no icon key" icon-sizes ios 'sub app.json "\"icon\":\"./assets/icon.png\"," ""'
seed expo "wrong size" icon-sizes ios 'png assets/icon.png 512 512 2'
seed expo "non-square" icon-sizes ios 'png assets/icon.png 1024 1023 2'
seed expo "alpha RGBA" icon-alpha ios 'png assets/icon.png 1024 1024 6'
seed expo "alpha grey" icon-alpha ios 'png assets/icon.png 1024 1024 4'
seed expo "alpha palette tRNS" icon-alpha ios 'png assets/icon.png 1024 1024 3 trns'
seed expo "alpha RGB tRNS" icon-alpha ios 'png assets/icon.png 1024 1024 2 trns'
seed expo "declared option empty" permission-strings ios 'sub app.json "Todo reads one photo you attach." ""'
seed expo "declared infoPlist empty" permission-strings ios 'sub app.json "\"ios\":{" "\"ios\":{\"infoPlist\":{\"NSMotionUsageDescription\":\"  \"},"'
seed expo "no photo option" permission-strings ios 'sub app.json ",\"plugins\":[[\"expo-image-picker\",{\"photosPermission\":\"Todo reads one photo you attach.\"}]]" ""'
seed expo "plugin string form only" permission-strings ios 'sub app.json "[\"expo-image-picker\",{\"photosPermission\":\"Todo reads one photo you attach.\"}]" "\"expo-image-picker\""'
seed expo "option false" permission-strings ios 'sub app.json "\"Todo reads one photo you attach.\"" "false"'
seed expo "missing bundle id" bundle-id ios 'sub app.json "\"bundleIdentifier\":\"io.github.test.todo\"" "\"supportsTablet\":true"'
seed expo "bad bundle id" bundle-id ios 'sub app.json "\"bundleIdentifier\":\"io.github.test.todo\"" "\"bundleIdentifier\":\"io_github.todo\""'
seed expo "empty name" app-name ios 'sub app.json "\"name\":\"Todo\"" "\"name\":\"\""'
seed expo "no name" app-name ios 'sub app.json "\"name\":\"Todo\"," ""'
seed expo "empty privacy" privacy-policy-url ios 'state . "\"\""'
seed expo "foreground gone" icon-sizes android 'rm assets/fg.png'
seed expo "foreground small" icon-sizes android 'png assets/fg.png 256 256 6; png assets/bg.png 256 256 2'
seed expo "background mismatch" icon-sizes android 'png assets/bg.png 1024 1024 2'
seed expo "no android package" package android 'sub app.json "\"package\":\"io.github.test.todo\"," ""'
seed expo "android com.example" package android 'sub app.json "\"package\":\"io.github.test.todo\"" "\"package\":\"com.example.todo\""'
seed expo "android bad segment" package android 'sub app.json "\"package\":\"io.github.test.todo\"" "\"package\":\"io.1github.todo\""'
seed expo "android one segment" package android 'sub app.json "\"package\":\"io.github.test.todo\"" "\"package\":\"todo\""'
seed expo "camera blocked" permissions-declared android 'sub App.tsx "launchImageLibraryAsync" "launchCameraAsync"; sub app.json "\"photosPermission\":\"Todo reads one photo you attach.\"" "\"cameraPermission\":false"'
seed expo "blockedPermissions" permissions-declared android 'sub App.tsx "launchImageLibraryAsync" "launchCameraAsync"; sub app.json "\"android\":{" "\"android\":{\"blockedPermissions\":[\"android.permission.CAMERA\"],"'
seed expo "calendar undeclared" permissions-declared android "sub App.tsx 'ImagePicker.launchImageLibraryAsync({})' 'ImagePicker.requestCalendarPermissionsAsync()'"
seed expo "android empty name" app-name android 'sub app.json "\"name\":\"Todo\"" "\"name\":\" \""'
seed expo "android empty privacy" privacy-policy-url android 'state . "\"\""'
seed expo "web favicon gone" icon-sizes web 'rm assets/favicon.png'
seed expo "web no favicon" icon-sizes web 'sub app.json "\"web\":{\"favicon\":\"./assets/favicon.png\"}," ""'
seed expo "web empty name" app-name web 'sub app.json "\"name\":\"Todo\"" "\"name\":\"\""'

variant expo camera-api
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
run_check "$dir" --platform ios
expect "launchCameraAsync needs the camera key, not photos" 1 '^FAIL permission-strings: .*NSCameraUsageDescription'

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
expect "a URL string does not hide the API after it" 1 '^FAIL permission-strings: .*NSCameraUsageDescription'

variant expo infoplist-string
sub "$dir/app.json" ',"plugins":[["expo-image-picker",{"photosPermission":"Todo reads one photo you attach."}]]' ''
sub "$dir/app.json" '"ios":{' '"ios":{"infoPlist":{"NSPhotoLibraryUsageDescription":"Todo reads one photo."},'
run_check "$dir" --platform ios
expect "ios.infoPlist supplies the string" 0 '^PASS permission-strings: .*NSPhotoLibraryUsageDescription'

variant expo false-beats-infoplist
sub "$dir/app.json" '"Todo reads one photo you attach."' 'false'
sub "$dir/app.json" '"ios":{' '"ios":{"infoPlist":{"NSPhotoLibraryUsageDescription":"Todo reads one photo."},'
run_check "$dir" --platform ios
expect "a plugin option of false removes an infoPlist string" 1 '^FAIL permission-strings: .*NSPhotoLibraryUsageDescription'

variant expo calendar-declared
sub "$dir/App.tsx" 'ImagePicker.launchImageLibraryAsync({})' 'ImagePicker.requestCalendarPermissionsAsync()'
sub "$dir/app.json" '"android":{' '"android":{"permissions":["android.permission.READ_CALENDAR","WRITE_CALENDAR"],'
run_check "$dir" --platform android
expect "declared calendar permissions pass with dangerous evidence" 0 '^PASS permissions-declared: declared dangerous: READ_CALENDAR, WRITE_CALENDAR'

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
expect "expo: ios/ wins over the app config" 1 '^PASS bundle-id: .* from PRODUCT_BUNDLE_IDENTIFIER' '^FAIL icon-alpha: Icon-1024.png'
put "$dir/.gitignore" 'node_modules\n/ios\n'
run_check "$dir" --platform ios
expect "expo: a gitignored ios/ does not win" 0 '^PASS bundle-id: .* from ios.bundleIdentifier' '^PASS icon-alpha: \./assets/icon.png'

variant expo native-android
android_tree "$dir/android"
run_check "$dir" --platform android
expect "expo: android/ wins over the app config" 0 '^PASS package: .* from android/app/build.gradle.kts' '^PASS permissions-declared: declared dangerous: CAMERA'
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
sub "$dir/android/app/src/main/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission xmlns:tools="http://schemas.android.com/tools" android:name="android.permission.CAMERA" tools:node="remove" />'
run_check "$dir" --platform android
expect "expo native: tools:node=remove blocks a needed permission" 1 '^FAIL permissions-declared: .*CAMERA'

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
seed flutter "missing icon file" icon-sizes ios "rm $set_dir/Icon-1024.png"
seed flutter "no marketing entry" icon-sizes ios "sub $set_dir/Contents.json '{\"filename\":\"Icon-1024.png\",\"idiom\":\"ios-marketing\",\"scale\":\"1x\",\"size\":\"1024x1024\"},' ''"
seed flutter "wrong marketing size" icon-sizes ios "png $set_dir/Icon-1024.png 512 512 2"
seed flutter "wrong small size" icon-sizes ios "png $set_dir/Icon-60-2x.png 60 60 2"
seed flutter "alpha marketing" icon-alpha ios "png $set_dir/Icon-1024.png 1024 1024 6"
seed flutter "string empty" permission-strings ios "sub ios/Runner/Info.plist 'Todo scans a code to add an item.' ''"
seed flutter "api without string" permission-strings ios "sub lib/main.dart 'ImageSource.camera' 'ImageSource.gallery'"
seed flutter "missing id" bundle-id ios "sub ios/Runner.xcodeproj/project.pbxproj 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' ''; sub ios/Runner/Info.plist '<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''"
seed flutter "bad id" bundle-id ios "sub ios/Runner.xcodeproj/project.pbxproj 'io.github.test.todo' 'io_github.todo'"
seed flutter "empty name" app-name ios "sub ios/Runner/Info.plist '<string>Todo</string>' '<string></string>'"
seed flutter "ios empty privacy" privacy-policy-url ios 'state . "\"\""'
seed flutter "android icon gone" icon-sizes android "sub android/app/src/main/AndroidManifest.xml ' android:icon=\"@mipmap/ic_launcher\"' ''"
seed flutter "android icon wrong size" icon-sizes android "webp android/app/src/main/res/mipmap-hdpi/ic_launcher.webp VP8L 96 96"
seed flutter "android host permission undeclared" permissions-declared android "put android/app/src/main/kotlin/M.kt 'val p = Manifest.permission.READ_CONTACTS\n'"
seed flutter "android missing id" package android "sub android/app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' ''"
seed flutter "android com.example" package android "sub android/app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' 'applicationId = \"com.example.todo\"'"
seed flutter "android empty name" app-name android "sub android/app/src/main/res/values/strings.xml '>Todo<' '><'"
seed flutter "android empty privacy" privacy-policy-url android 'state . "\"\""'
seed flutter "web icon gone" icon-sizes web "rm web/icons/Icon-192.png"
seed flutter "web manifest size" icon-sizes web "png web/icons/Icon-192.png 96 96 6"
seed flutter "web empty name" app-name web "sub web/manifest.json '\"name\":\"Todo\",' ''; sub web/index.html '<title>Todo</title>' '<title></title>'"

variant flutter gallery-camera
sub "$dir/lib/main.dart" 'pickImage(source: ImageSource.camera)' 'pickVideo(source: ImageSource.camera)'
run_check "$dir" --platform ios
expect "flutter: pickVideo from camera needs the microphone key" 1 '^FAIL permission-strings: .*NSMicrophoneUsageDescription'

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
seed xcode "missing icon set" icon-sizes ios "rm -rf Runner/Assets.xcassets"
seed xcode "missing marketing file" icon-sizes ios "rm $xset/Icon-1024.png"
seed xcode "wrong size" icon-sizes ios "png $xset/Icon-1024.png 1023 1023 2"
seed xcode "alpha" icon-alpha ios "png $xset/Icon-1024.png 1024 1024 6"
seed xcode "string empty" permission-strings ios "sub Runner/Info.plist 'Todo scans a code to add an item.' '   '"
seed xcode "api without string" permission-strings ios "sub Runner/App.swift '.video' '.audio'"
seed xcode "missing id" bundle-id ios "sub Runner.xcodeproj/project.pbxproj 'PRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;' ''; sub Runner/Info.plist '<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''"
seed xcode "bad id" bundle-id ios "sub Runner.xcodeproj/project.pbxproj 'io.github.test.todo' 'io.github.test.todo_app'"
seed xcode "empty name" app-name ios "sub Runner/Info.plist '<string>Todo</string>' '<string></string>'"
seed xcode "empty privacy" privacy-policy-url ios 'state . "\"\""'

variant xcode location
put "$dir/Runner/App.swift" 'import CoreLocation\nfunc go(m: CLLocationManager) { m.requestAlwaysAuthorization() }\n'
run_check "$dir" --platform ios
expect "requestAlwaysAuthorization needs location keys" 1 '^FAIL permission-strings: .*NSLocationAlwaysAndWhenInUseUsageDescription'

variant xcode objc
rm "$dir/Runner/App.swift"
put "$dir/Runner/App.m" '[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:nil];\n'
run_check "$dir" --platform ios
expect "objc API scan" 1 '^FAIL permission-strings: .*NSMicrophoneUsageDescription'

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
expect "resolvable \$(VAR) passes" 0 '^PASS bundle-id: io.github.test.todo'

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
expect "single-size set passes; dark appearance may carry alpha" 0 '^PASS icon-sizes: ' '^PASS icon-alpha: Icon-1024.png'
png "$dir/$xset/Icon-1024.png" 1024 1024 6
run_check "$dir" --platform ios
expect "single-size default icon with alpha fails" 1 '^FAIL icon-alpha: Icon-1024.png'

variant xcode icon-composer
mkdir -p "$dir/Runner/AppIcon.icon"
run_check "$dir" --platform ios
expect "AppIcon.icon wins and is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*Icon Composer' '^UNKNOWN icon-alpha: .*Icon Composer'

variant xcode generated-plist
sub "$dir/Runner.xcodeproj/project.pbxproj" 'INFOPLIST_FILE = Runner/Info.plist;' 'GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Todo;
				INFOPLIST_KEY_NSCameraUsageDescription = "Scan a code.";'
run_check "$dir" --platform ios
expect "generated Info.plist reads INFOPLIST_KEY_*" 0 '^PASS app-name: "Todo" from INFOPLIST_KEY_CFBundleDisplayName' '^PASS permission-strings: .*NSCameraUsageDescription'
sub "$dir/Runner.xcodeproj/project.pbxproj" 'INFOPLIST_KEY_NSCameraUsageDescription = "Scan a code.";' 'INFOPLIST_KEY_NSCameraUsageDescription = "";'
run_check "$dir" --platform ios
expect "empty INFOPLIST_KEY string fails" 1 '^FAIL permission-strings: NSCameraUsageDescription is declared but empty'

variant xcode swiftpm
rm -rf "$dir/Runner.xcodeproj"
put "$dir/Package.swift" '// swift-tools-version:5.9\nimport PackageDescription\nlet p = Package(name: "T", targets: [.executableTarget(name: "T")])\n'
run_check "$dir" --platform ios
expect "Package.swift without an Xcode project gives UNKNOWN" 0 '^UNKNOWN bundle-id: .*xcodeproj'

# ---- Seeded gaps: kotlin ---------------------------------------------------

km="app/src/main"
seed kotlin "icon attr gone" icon-sizes android "sub $km/AndroidManifest.xml ' android:icon=\"@mipmap/ic_launcher\"' ''"
seed kotlin "icon files gone" icon-sizes android "rm -rf $km/res/mipmap-*"
seed kotlin "wrong VP8L size" icon-sizes android "webp $km/res/mipmap-xxxhdpi/ic_launcher.webp VP8L 96 96"
seed kotlin "wrong VP8 size" icon-sizes android "webp $km/res/mipmap-mdpi/ic_launcher.webp VP8 96 96"
seed kotlin "wrong VP8X size" icon-sizes android "webp $km/res/mipmap-xhdpi/ic_launcher.webp VP8X 48 48"
seed kotlin "wrong PNG size" icon-sizes android "rm $km/res/mipmap-hdpi/ic_launcher.webp; png $km/res/mipmap-hdpi/ic_launcher.png 48 48 6"
seed kotlin "adaptive foreground gone" icon-sizes android "rm $km/res/drawable/ic_launcher_foreground.xml"
seed kotlin "adaptive no foreground" icon-sizes android "sub $km/res/mipmap-anydpi-v26/ic_launcher.xml '<foreground android:drawable=\"@drawable/ic_launcher_foreground\" />' ''"
seed kotlin "adaptive vector not 108dp" icon-sizes android "sub $km/res/drawable/ic_launcher_foreground.xml 'android:width=\"108dp\"' 'android:width=\"96dp\"'"
seed kotlin "permission undeclared" permissions-declared android "sub $km/AndroidManifest.xml '<uses-permission android:name=\"android.permission.CAMERA\" />' ''"
seed kotlin "second permission undeclared" permissions-declared android "put $km/java/io/test/L.java 'class L { String a = android.Manifest.permission.ACCESS_FINE_LOCATION; }\n'"
seed kotlin "literal permission undeclared" permissions-declared android "put $km/java/io/test/L.kt 'val a = \"android.permission.RECORD_AUDIO\"\n'"
seed kotlin "missing id" package android "sub app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' ''"
seed kotlin "com.example" package android "sub app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' 'applicationId = \"com.example.todo\"'"
seed kotlin "bad id" package android "sub app/build.gradle.kts 'applicationId = \"io.github.test.todo\"' 'applicationId = \"io.github.2todo\"'"
seed kotlin "label gone" app-name android "sub $km/AndroidManifest.xml ' android:label=\"@string/app_name\"' ''"
seed kotlin "string gone" app-name android "sub $km/res/values/strings.xml 'name=\"app_name\"' 'name=\"other\"'"
seed kotlin "empty name" app-name android "sub $km/res/values/strings.xml '>Todo<' '> <'"
seed kotlin "empty privacy" privacy-policy-url android 'state . "\"\""'

variant kotlin dangerous-evidence
sub "$dir/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission android:name="android.permission.CAMERA" /><uses-permission android:name="android.permission.READ_CONTACTS" /><uses-permission android:name="android.permission.INTERNET" />'
run_check "$dir" --platform android
expect "evidence lists dangerous permissions only" 0 '^PASS permissions-declared: declared dangerous: CAMERA, READ_CONTACTS; ' '!INTERNET'

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
expect "groovy applicationId with a suffix line" 0 '^PASS package: io.github.test.todo from app/build.gradle'

variant kotlin gradle-url
sub "$dir/app/build.gradle.kts" 'android {' 'repositories { maven { url = uri("https://example.org/maven") } } // note {
android {'
run_check "$dir" --platform android
expect "a URL or a comment in gradle is not malformed" 0 '^PASS package: io.github.test.todo'

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

seed vite "icon link gone" icon-sizes web "rm public/favicon.svg"
seed vite "manifest icon gone" icon-sizes web "rm public/icon-64.png"
seed vite "manifest size mismatch" icon-sizes web "png public/icon-64.png 32 32 6"
seed vite "no icons declared" icon-sizes web "rm public/manifest.webmanifest; sub index.html '<link rel=\"icon\" href=\"/favicon.svg\">' ''; sub index.html '<link rel=\"manifest\" href=\"/manifest.webmanifest\">' ''"
seed vite "empty title, no manifest" app-name web "rm public/manifest.webmanifest; sub index.html '<title>Todo</title>' '<title> </title>'"
seed vite "no title, no manifest" app-name web "rm public/manifest.webmanifest; sub index.html '<title>Todo</title>' ''"
seed nextjs "icon gone" icon-sizes web "rm app/icon.png"
seed nextjs "empty title" app-name web "sub app/layout.tsx 'title: \"Todo\"' 'title: \"\"'"
seed nextjs "no title" app-name web "sub app/layout.tsx 'export const metadata = { title: \"Todo\", description: \"x\" };' ''"
seed static "icon gone" icon-sizes web "rm favicon.png"
seed static "declared size mismatch" icon-sizes web "png favicon.png 16 16 6"
seed static "empty title" app-name web "sub index.html '<title>Todo</title>' '<title></title>'"

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
expect "web valid URL passes with no" 0 '^PASS privacy-policy-url: https://example.org/privacy'
run_check "$tmp/vite" --platform web
expect "web valid URL passes with no flag" 0 '^PASS privacy-policy-url: https://example.org/privacy'
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
good='^PASS privacy-policy-url: https://example.org/p$'
url_case "double quotes" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"\n---\n' 0 "$good"
url_case "single quotes" "---\nprovided:\n  publish-readiness:\n    privacy_policy_url: 'https://example.org/p'\n---\n" 0 "$good"
url_case "plain" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p\n---\n' 0 "$good"
url_case "trailing comment" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p   # the page\n---\n' 0 "$good"
url_case "quoted trailing comment" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"  # the page\n---\n' 0 "$good"
url_case "fragment stays" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p#top\n---\n' 0 '^PASS privacy-policy-url: https://example.org/p#top$'
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
  expect "fixture todo-expo ios" 0 '^PASS bundle-id: ' '^PASS icon-alpha: ' '^PASS permission-strings: .*NSPhotoLibraryUsageDescription' '!^FAIL '
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
  expect "seeded todo-expo ios" 1 '^FAIL permission-strings: ' '^FAIL icon-alpha: ' '^FAIL privacy-policy-url: '
  run_check "$gap" --platform android
  expect "seeded todo-expo android" 1 '^FAIL icon-sizes: ' '^FAIL privacy-policy-url: '
fi

if [ "$pass" -eq "$total" ]; then
  echo "PASS $pass/$total"
  exit 0
fi
printf '%s\n' "$failed"
echo "FAIL $((total - pass))/$total"
exit 1
