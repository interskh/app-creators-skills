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
base=""
rargs=""

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
  base="$1"
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

# ---- Resolved inputs, hand-written to the documented shape -------------------

# over <KEY=VALUE>...: extra settings for the next resolve. KEY= removes a key, KEY=EMPTY is "", KEY=NUM is a number.
over() {
  printf '%s\n' "$@" >>"$tmp/over"
}

# resolve <SRCROOT> [KEY=VALUE...]: write $tmp/xc.json as `xcodebuild -showBuildSettings -json` would, with one app target and one extension.
resolve() {
  local srcroot="$1"
  shift
  python3 -I -c 'import json,os,sys
out,root,over=sys.argv[1:4]
s={"PRODUCT_TYPE":"com.apple.product-type.application","CONFIGURATION":"Release","PLATFORM_NAME":"iphoneos","SRCROOT":root,"INFOPLIST_FILE":"Runner/Info.plist","GENERATE_INFOPLIST_FILE":"NO","PRODUCT_BUNDLE_IDENTIFIER":"io.github.test.todo","PRODUCT_NAME":"Runner","TARGET_NAME":"Runner","ASSETCATALOG_COMPILER_APPICON_NAME":"AppIcon"}
second=False
for o in (open(over).read().splitlines() if os.path.exists(over) else [])+sys.argv[4:]:
    k,v=o.split("=",1)
    if k=="SECOND_APP": second=True
    elif v=="": s.pop(k,None)
    else: s[k]={"EMPTY":"","NUM":5}.get(v,v)
e=[{"action":"build","buildSettings":s,"target":"Runner"},{"action":"build","buildSettings":{"PRODUCT_TYPE":"com.apple.product-type.app-extension","CONFIGURATION":"Debug"},"target":"Share"}]
if second: e.append({"action":"build","buildSettings":dict(s),"target":"Second"})
json.dump(e,open(out,"w"))' "$tmp/xc.json" "$srcroot" "$tmp/over" "$@"
  rm -f "$tmp/over"
}

# built_app <package> <application element> [manifest children]: write $tmp/built.xml as `apkanalyzer manifest print` would.
built_app() {
  put "$tmp/built.xml" "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\" package=\"$1\" android:versionCode=\"1\">\n  ${3-<uses-permission android:name=\"android.permission.CAMERA\" />}\n  $2\n</manifest>\n"
}

# built <package> [more attributes of <application>] [manifest children]: label and icon are references, as in a real build.
built() {
  built_app "$1" "<application ${2:-} android:label=\"@ref/0x7f100001\" android:icon=\"@ref/0x7f0d0000\" />" "${3-<uses-permission android:name=\"android.permission.CAMERA\" />}"
}

built_no_label() {
  built_app io.github.test.todo '<application android:icon="@ref/0x7f0d0000" />'
}

built_no_icon() {
  built_app io.github.test.todo '<application android:label="@ref/0x7f100001" />'
}

built_permissions() {
  built io.github.test.todo '' "$(for perm in "$@"; do printf '<uses-permission android:name="android.permission.%s" />' "$perm"; done)"
}

# native_args <platform>: set rargs for the current variant.
native_args() {
  rargs=""
  case "$base:$1" in
    xcode:ios) resolve "$dir"; rargs="--resolved $tmp/xc.json" ;;
    flutter:ios) resolve "$dir/ios"; rargs="--resolved $tmp/xc.json" ;;
    kotlin:android | flutter:android)
      [ -f "$tmp/built.xml" ] || built io.github.test.todo
      rargs="--resolved $tmp/built.xml"
      ;;
    *) ;;
  esac
}

# native <platform> [flags]: run the current variant with its resolved input.
native() {
  local platform="$1"
  shift
  native_args "$platform"
  # shellcheck disable=SC2086
  run_check "$dir" --platform "$platform" $rargs "$@"
}

# seed <base tree> <label> <check id> <platform> <shell command run in the copy> <regex naming the gap>:
# exit 1 and a FAIL <id> whose reason, before "; fix:", names the seeded gap.
seed() {
  local tree="$1" label="$2" id="$3" platform="$4" cmd="$5" reason="${6:?seed needs a reason regex}"
  variant "$tree" "$tree-$(printf '%s' "$label" | tr -c 'a-zA-Z0-9' '-')"
  rm -f "$tmp/built.xml" "$tmp/over"
  (cd "$dir" && eval "$cmd")
  native "$platform"
  expect "$tree/$platform: $label" 1 "^FAIL $id: .*$reason.*; fix: "
}

# ---- Trees -----------------------------------------------------------------

info_plist() {
  put "$1" "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\"><dict>\n<key>CFBundleDisplayName</key><string>Todo</string>\n<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>\n<key>$2</key><string>$3</string>\n</dict></plist>\n"
}

apple_tree() {
  local at="$1" set="$1/Runner/Assets.xcassets/AppIcon.appiconset"
  put "$at/Runner.xcodeproj/project.pbxproj" '// !$*UTF8*$!\n{\n\tobjects = {\n\t\tA /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tINFOPLIST_FILE = Runner/Info.plist;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = io.github.test.todo;\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n\t};\n}\n'
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
put "$t/web/index.html" '<!doctype html><html><head><title>Todo</title><link rel="icon" type="image/png" href="favicon.png"><link rel="manifest" href="manifest.json"></head></html>\n'
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

km="app/src/main"
set_dir="ios/Runner/Assets.xcassets/AppIcon.appiconset"
xset="Runner/Assets.xcassets/AppIcon.appiconset"
built io.github.test.todo

# ---- Clean trees -----------------------------------------------------------

run_check "$tmp/expo" --platform ios
expect "expo ios clean" 0 '^PASS app-name: ' '^PASS bundle-id: ' '^PASS icon-sizes: ' '^PASS icon-alpha: ' '^PASS permission-strings: ' '^PASS privacy-policy-url: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/expo" --platform android
expect "expo android clean" 0 '^PASS app-name: ' '^PASS package: ' '^PASS icon-sizes: ' '^PASS permissions-declared: ' '^PASS privacy-policy-url: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/expo" --platform web
expect "expo web clean (react-dom carries web)" 0 '^PASS app-name: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
variant flutter clean
native ios
expect "resolved happy: flutter ios" 0 '^PASS bundle-id: "io.github.test.todo" from PRODUCT_BUNDLE_IDENTIFIER' '^PASS icon-alpha: ' '!^(FAIL|UNKNOWN) '
built io.github.test.todo
native android
expect "resolved happy: flutter android" 0 '^PASS package: "io.github.test.todo" from the built manifest' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
run_check "$tmp/flutter" --platform web
expect "flutter web clean" 0 '^PASS app-name: ' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '
variant xcode clean
native ios
expect "resolved happy: xcode" 0 '^PASS app-name: "Todo" from CFBundleDisplayName' '^PASS permission-strings: .*needed by code: "NSCameraUsageDescription"' '!^(FAIL|UNKNOWN) '
variant kotlin clean
native android
expect "resolved happy: kotlin, WebP launcher" 0 '^PASS app-name: "Todo"' '^PASS package: "io.github.test.todo" from the built manifest' '^PASS permissions-declared: declared dangerous: "CAMERA"; needed by code: "CAMERA"' '!^(FAIL|UNKNOWN) '
run_check "$tmp/vite" --platform web
expect "vite web clean" 0 '^PASS app-name: "Todo" from "public/manifest.webmanifest"' '!^(FAIL|UNKNOWN) '
run_check "$tmp/static" --platform web
expect "static web clean" 0 '^PASS app-name: "Todo" from index.html' '^PASS icon-sizes: ' '!^(FAIL|UNKNOWN) '

# ---- Permission scope in the PASS line --------------------------------------

scope='this covers declared permissions and the known API patterns'
variant xcode scope
native ios
expect "permission-strings PASS states its scope" 0 "^PASS permission-strings: .*$scope.*does not claim the app needs no permission"
variant kotlin scope
native android
expect "permissions-declared PASS states its scope" 0 "^PASS permissions-declared: .*$scope.*does not claim the app needs no permission"

# ---- No resolved input: native routes are UNKNOWN, never PASS or FAIL ---------

ios_all_unknown=('^UNKNOWN app-name: no resolved Xcode settings' '^UNKNOWN bundle-id: no resolved Xcode settings' '^UNKNOWN icon-sizes: no resolved' '^UNKNOWN icon-alpha: no resolved' '^UNKNOWN permission-strings: no resolved' '!^(PASS|FAIL) (app-name|bundle-id|icon-sizes|icon-alpha|permission-strings)')
run_check "$tmp/xcode" --platform ios
expect "no resolved input: xcode with a complete pbxproj and plist is UNKNOWN" 0 "${ios_all_unknown[@]}" '^UNKNOWN app-name: .*xcodebuild -showBuildSettings -json -configuration Release -sdk iphoneos'
run_check "$tmp/flutter" --platform ios
expect "no resolved input: flutter ios is UNKNOWN and names config-only" 0 "${ios_all_unknown[@]}" '^UNKNOWN app-name: .*flutter build ios --release --no-codesign --config-only'
variant expo native-no-resolved
apple_tree "$dir/ios"
run_check "$dir" --platform ios
expect "no resolved input: expo with ios/ is UNKNOWN" 0 "${ios_all_unknown[@]}"
variant xcode empty-string-no-resolved
sub "$dir/Runner/Info.plist" 'Todo scans a code to add an item.' ''
run_check "$dir" --platform ios
expect "no resolved input: an empty plist string is no FAIL" 0 "${ios_all_unknown[@]}"
variant kotlin gradle-no-resolved
run_check "$dir" --platform android
expect "no resolved input: a complete Gradle file leaves package UNKNOWN" 0 '^UNKNOWN package: the application id comes from Gradle' '^PASS app-name: ' '!^(PASS|FAIL) package: '
run_check "$tmp/flutter" --platform android
expect "no resolved input: flutter android package is UNKNOWN" 0 '^UNKNOWN package: ' '!^(PASS|FAIL) package: '

# ---- Resolved Xcode settings gates ------------------------------------------

xgate() {
  local label="$1" re="$2"
  shift 2
  variant xcode xgate
  rm -f "$tmp/over"
  resolve "$dir" "$@"
  run_check "$dir" --platform ios --resolved "$tmp/xc.json"
  expect "$label" 0 "^UNKNOWN app-name: $re" "^UNKNOWN bundle-id: $re" "^UNKNOWN icon-sizes: $re" "^UNKNOWN icon-alpha: $re" "^UNKNOWN permission-strings: $re" '!^(PASS|FAIL) (app-name|bundle-id|icon-sizes|icon-alpha|permission-strings)'
}
xgate "resolved gate: Debug CONFIGURATION" 'the resolved Xcode settings are not for Release on iphoneos' CONFIGURATION=Debug
xgate "resolved gate: no CONFIGURATION" 'the resolved Xcode settings are not for Release on iphoneos' CONFIGURATION=
xgate "resolved gate: simulator PLATFORM_NAME" 'the resolved Xcode settings are not for Release on iphoneos' PLATFORM_NAME=iphonesimulator
xgate "resolved gate: no PLATFORM_NAME" 'the resolved Xcode settings are not for Release on iphoneos' PLATFORM_NAME=
xgate "resolved gate: foreign SRCROOT" 'SRCROOT in the resolved Xcode settings is not inside' "SRCROOT=$tmp/expo"
xgate "resolved gate: no SRCROOT" 'SRCROOT in the resolved Xcode settings is not inside' SRCROOT=
xgate "resolved gate: relative SRCROOT" 'SRCROOT in the resolved Xcode settings is not inside' SRCROOT=Runner
xgate "resolved gate: two application entries" 'the resolved Xcode settings hold 2 application' SECOND_APP=1
xgate "resolved gate: no application entry" 'the resolved Xcode settings hold 0 application' PRODUCT_TYPE=com.apple.product-type.framework
xgate "resolved gate: a non-string PRODUCT_TYPE is ignored" 'the resolved Xcode settings hold 0 application' PRODUCT_TYPE=NUM

variant xcode nonstring-setting
resolve "$dir" PRODUCT_BUNDLE_IDENTIFIER=NUM
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "a non-string setting is ignored, leaving the plist's variable UNKNOWN" 0 '^UNKNOWN bundle-id: .*PRODUCT_BUNDLE_IDENTIFIER' '!^(PASS|FAIL) bundle-id: '

variant xcode generated-keys
sub "$dir/Runner/Info.plist" '<key>NSCameraUsageDescription</key><string>Todo scans a code to add an item.</string>' ''
sub "$dir/Runner/Info.plist" '<key>CFBundleDisplayName</key><string>Todo</string>' ''
resolve "$dir" GENERATE_INFOPLIST_FILE=YES "INFOPLIST_KEY_NSCameraUsageDescription=Scan a code." INFOPLIST_KEY_CFBundleDisplayName=Todo
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "INFOPLIST_KEY_* counts with GENERATE_INFOPLIST_FILE=YES" 0 '^PASS app-name: "Todo" from INFOPLIST_KEY_CFBundleDisplayName' '^PASS permission-strings: declared: "NSCameraUsageDescription"'
resolve "$dir" GENERATE_INFOPLIST_FILE=NO "INFOPLIST_KEY_NSCameraUsageDescription=Scan a code." INFOPLIST_KEY_CFBundleDisplayName=Todo
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "INFOPLIST_KEY_* does not count with GENERATE_INFOPLIST_FILE=NO" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"' '^PASS app-name: "Runner" from PRODUCT_NAME' '!INFOPLIST_KEY'
resolve "$dir" GENERATE_INFOPLIST_FILE= "INFOPLIST_KEY_NSCameraUsageDescription=Scan a code."
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "INFOPLIST_KEY_* does not count with GENERATE_INFOPLIST_FILE absent" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'
resolve "$dir" GENERATE_INFOPLIST_FILE=YES INFOPLIST_KEY_NSCameraUsageDescription=EMPTY
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "an empty INFOPLIST_KEY string fails" 1 '^FAIL permission-strings: "NSCameraUsageDescription" is declared but empty; fix: '
resolve "$dir" GENERATE_INFOPLIST_FILE=YES INFOPLIST_FILE= "INFOPLIST_KEY_NSCameraUsageDescription=Scan a code." INFOPLIST_KEY_CFBundleDisplayName=Todo
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "a generated Info.plist with no plist file" 0 '^PASS app-name: "Todo"' '^PASS permission-strings: '

variant xcode plist-var
sub "$dir/Runner/Info.plist" 'Todo scans a code to add an item.' '$(CAMERA_REASON)'
native ios
expect "unresolved \$(X) in a plist string is UNKNOWN" 0 '^UNKNOWN permission-strings: "NSCameraUsageDescription" holds a build variable' '!^(PASS|FAIL) permission-strings: '
resolve "$dir" CAMERA_REASON=Scan.
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "\$(X) in a plist expands from the settings" 0 '^PASS permission-strings: '
sub "$dir/Runner/Info.plist" '$(CAMERA_REASON)' '${CAMERA_REASON}'
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "\${X} in a plist expands from the settings" 0 '^PASS permission-strings: '
sub "$dir/Runner/Info.plist" '${CAMERA_REASON}' '$(CAMERA_REASON:rfc1034identifier)'
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "a modifier form in a plist is UNKNOWN" 0 '^UNKNOWN permission-strings: "NSCameraUsageDescription" holds a build variable'

variant xcode id-var
resolve "$dir" 'PRODUCT_BUNDLE_IDENTIFIER=io.github.$(TEAM_SUFFIX).todo'
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "unresolved \$(X) in a setting is UNKNOWN" 0 '^UNKNOWN bundle-id: .*TEAM_SUFFIX' '!^(FAIL|PASS) bundle-id: '
resolve "$dir" 'PRODUCT_BUNDLE_IDENTIFIER=io.github.$(SUFFIX).todo' SUFFIX=test
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "resolvable \$(X) in a setting passes" 0 '^PASS bundle-id: "io.github.test.todo"'
resolve "$dir" 'ASSETCATALOG_COMPILER_APPICON_NAME=$(ICON_NAME)'
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "unresolved icon set name is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*ICON_NAME' '^UNKNOWN icon-alpha: '

put "$tmp/outside.plist" '<plist version="1.0"><dict><key>CFBundleDisplayName</key><string>OUTSIDE-VALUE</string></dict></plist>\n'
for rel in "$tmp/outside.plist" ../../outside.plist ../../outside-missing.plist; do
  variant xcode plist-outside
  resolve "$dir" "INFOPLIST_FILE=$rel"
  run_check "$dir" --platform ios --resolved "$tmp/xc.json"
  expect "security: resolved INFOPLIST_FILE $rel outside the project is UNKNOWN either way" 0 '^UNKNOWN app-name: .*points outside the project' '^UNKNOWN permission-strings: .*points outside the project' '!OUTSIDE-VALUE' '!could not be read'
done

variant xcode srcroot-subfolder
mkdir "$dir/sub"
mv "$dir/Runner" "$dir/sub/Runner"
resolve "$dir/sub"
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "root becomes SRCROOT, wherever it sits in the project" 0 '^PASS app-name: ' '^PASS icon-sizes: '

# ---- Resolved Android manifest gates ----------------------------------------

variant kotlin debuggable
built io.github.test.todo 'android:debuggable="true"'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a debuggable artifact leaves package UNKNOWN" 0 '^UNKNOWN package: .*debuggable' '!^(PASS|FAIL) package: '
built_app io.github.test.todo '<application android:debuggable="true" android:label="Debug Only" android:icon="@ref/0x1" />'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a debuggable manifest decides no label and no permissions" 0 '^UNKNOWN app-name: .*not the release truth' '^UNKNOWN permissions-declared: .*not the release truth' '!^(PASS|FAIL) (app-name|permissions-declared|package)' '!Debug Only'
built_app io.github.test.todo '<application android:debuggable="true" />' ''
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a debuggable manifest with no label or icon confirms nothing" 0 '^UNKNOWN app-name: .*not the release truth' '^UNKNOWN icon-sizes: .*not the release truth' '^UNKNOWN permissions-declared: .*not the release truth' '!^(PASS|FAIL) (app-name|icon-sizes|permissions-declared)'
built io.github.test.todo 'android:debuggable="true"'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a debuggable manifest holding references leaves label and icon to src/main" 0 '^PASS app-name: "Todo"' '^PASS icon-sizes: ' '^UNKNOWN permissions-declared: .*not the release truth'
built io.github.test.todo 'android:debuggable="false"'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "debuggable=false is a release artifact" 0 '^PASS package: '
built io.github.test.todo
for id in com.example.todo com.example; do
  sub "$tmp/built.xml" 'package="' "package=\"$id\" x=\""
  run_check "$dir" --platform android --resolved "$tmp/built.xml"
  expect "$id has no sourced store rule, so it passes" 0 "^PASS package: \"$id\""
  built io.github.test.todo
done

# ---- Classifying --resolved --------------------------------------------------

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

two "the old --expo-config flag is gone" 'unrecognized arguments: --expo-config' "$tmp/expo" --platform ios --expo-config "$tmp/x.json"
two "unreadable --resolved" 'could not be read' "$tmp/expo" --platform ios --resolved "$tmp/no-such-file.json"
put "$tmp/not-json.json" 'module.exports = {};\n'
two "malformed --resolved, not JSON" 'could not be read' "$tmp/expo" --platform ios --resolved "$tmp/not-json.json"
put "$tmp/scalar.json" '5\n'
two "malformed --resolved, a JSON scalar" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/scalar.json"
put "$tmp/empty-array.json" '[]\n'
two "malformed --resolved, an empty array" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/empty-array.json"
put "$tmp/no-settings.json" '[{"target":"Runner"}]\n'
two "malformed --resolved, entries with no buildSettings" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/no-settings.json"
put "$tmp/other.xml" '<resources />\n'
two "malformed --resolved, an XML root other than manifest" 'could not be read' "$tmp/kotlin" --platform android --resolved "$tmp/other.xml"
put "$tmp/broken.xml" '<manifest package="a.b"'
two "malformed --resolved, broken XML" 'not well-formed' "$tmp/kotlin" --platform android --resolved "$tmp/broken.xml"
put "$tmp/entities.xml" '<!DOCTYPE m [<!ENTITY a "x">]><manifest package="a.b"><application android:label="&a;"/></manifest>\n'
two "security: --resolved XML with entities is refused" 'declares XML entities' "$tmp/kotlin" --platform android --resolved "$tmp/entities.xml"
put "$tmp/one.json" '{"expo":{"name":"One"}}\n'
put "$tmp/two.json" '{"slug":"two"}\n'
two "two Expo files" 'two expo files' "$tmp/expo" --platform ios --resolved "$tmp/one.json" --resolved "$tmp/two.json"
variant xcode two-xcode
resolve "$dir"
two "two Xcode files" 'two xcode files' "$dir" --platform ios --resolved "$tmp/xc.json" --resolved "$tmp/xc.json"
two "two Android files" 'two android files' "$tmp/kotlin" --platform android --resolved "$tmp/built.xml" --resolved "$tmp/built.xml"

variant expo unused-kinds
resolve "$dir"
run_check "$dir" --platform ios --resolved "$tmp/built.xml" --resolved "$tmp/xc.json"
expect "a resolved kind that does not apply is unused" 0 '^PASS bundle-id: .* from ios.bundleIdentifier'

# ---- Expo with native folders ------------------------------------------------

variant expo native-ios
apple_tree "$dir/ios"
sub "$dir/app.json" '"bundleIdentifier":"io.github.test.todo"' '"bundleIdentifier":"io.github.from.config"'
info_plist "$dir/ios/Runner/Info.plist" NSPhotoLibraryUsageDescription "Todo reads a photo."
resolve "$dir/ios"
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "resolved happy: expo with ios/, native wins over the app config" 0 '^PASS bundle-id: "io.github.test.todo" from PRODUCT_BUNDLE_IDENTIFIER' '^PASS permission-strings: declared: "NSPhotoLibraryUsageDescription"' '!^(FAIL|UNKNOWN) '
info_plist "$dir/ios/Runner/Info.plist" NSCameraUsageDescription "Scan."
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "resolved seeded gap: expo with ios/, the app's API needs a key the plist lacks" 1 '^FAIL permission-strings: .*needs "NSPhotoLibraryUsageDescription"'
resolve "$dir/ios" PRODUCT_BUNDLE_IDENTIFIER=io_github.todo
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "resolved seeded gap: expo with ios/, bad id" 1 '^FAIL bundle-id: bundle id "io_github.todo" must be'
python3 -I -c 'import json,sys
json.dump(json.load(open(sys.argv[1])),open(sys.argv[2],"w"))' "$dir/app.json" "$tmp/expo-native.json"
resolve "$dir/ios"
run_check "$dir" --platform ios --resolved "$tmp/expo-native.json" --resolved "$tmp/xc.json"
expect "an Expo project with native folders may pass two files" 1 '^PASS bundle-id: .* from PRODUCT_BUNDLE_IDENTIFIER'
put "$dir/.gitignore" 'node_modules\n/ios\n'
run_check "$dir" --platform ios
expect "expo: a gitignored ios/ does not win" 0 '^PASS bundle-id: "io.github.from.config" from ios.bundleIdentifier' '^PASS icon-alpha: "\./assets/icon.png"'

variant expo native-android
android_tree "$dir/android"
run_check "$dir" --platform android
expect "expo: android/ wins over the app config, and with no input package is UNKNOWN" 0 '^UNKNOWN package: ' '^PASS permissions-declared: declared dangerous: "CAMERA"'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "resolved happy: expo with android/" 0 '^PASS package: .* from the built manifest'
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
sub "$dir/android/app/src/main/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission xmlns:tools="http://schemas.android.com/tools" android:name="android.permission.CAMERA" tools:node="remove" />'
run_check "$dir" --platform android
expect "expo native: tools:node=remove blocks a needed permission" 1 '^FAIL permissions-declared: .*"CAMERA", which the project removes'

for pair in empty:"" partial:"ios/Runner android/app/src"; do
  variant expo "${pair%%:*}-native"
  # shellcheck disable=SC2086
  (cd "$dir" && mkdir -p ios android ${pair#*:})
  run_check "$dir" --platform ios
  expect "a ${pair%%:*} ios/ does not win" 0 '^PASS bundle-id: .* from ios.bundleIdentifier'
  run_check "$dir" --platform android
  expect "a ${pair%%:*} android/ does not win" 0 '^PASS package: .* from android.package'
done

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

for icon in '{"light":"./assets/icon.png","dark":"./assets/dark.png"}' '"./assets/app.icon"'; do
  variant expo icon-variants
  sub "$dir/app.json" '"ios":{' "\"ios\":{\"icon\":$icon,"
  run_check "$dir" --platform ios
  expect "ios.icon $icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '!^FAIL '
done

variant expo remote-icon
sub "$dir/app.json" './assets/icon.png' 'https://example.org/icon.png'
run_check "$dir" --platform ios
expect "remote icon URL is UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: '

variant expo dynamic
mv "$dir/app.json" "$tmp/dyn-expo-config.json"
put "$dir/app.config.js" 'module.exports = { name: "Todo" };\n'
run_check "$dir" --platform ios
expect "dynamic app.config.js without --resolved" 0 '^UNKNOWN app-name: .*npx expo config --json.*--resolved' '^UNKNOWN bundle-id: ' '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '^UNKNOWN permission-strings: ' '!^PASS (app-name|bundle-id|icon-sizes|icon-alpha|permission-strings): ' '!^FAIL '
run_check "$dir" --platform android
expect "dynamic app.config.js on android" 0 '^UNKNOWN package: ' '^UNKNOWN icon-sizes: ' '^UNKNOWN permissions-declared: ' '!^FAIL '
run_check "$dir" --platform ios --resolved "$tmp/dyn-expo-config.json"
expect "same project with --resolved (wrapper) passes" 0 '^PASS app-name: ' '^PASS permission-strings: ' '!^(FAIL|UNKNOWN) '
python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))["expo"]
d["slug"]="todo"
json.dump(d,open(sys.argv[2],"w"))' "$tmp/dyn-expo-config.json" "$tmp/dyn-expo-root.json"
run_check "$dir" --platform ios --resolved "$tmp/dyn-expo-root.json"
expect "same project with --resolved (expo root) passes" 0 '^PASS app-name: ' '!^(FAIL|UNKNOWN) '
put "$dir/app.config.ts" 'export default { name: "Todo" };\n'
rm "$dir/app.config.js"
run_check "$dir" --platform ios
expect "dynamic app.config.ts without --resolved" 0 '^UNKNOWN app-name: .*app.config.ts'
run_check "$dir" --platform web
expect "dynamic expo on web with react-dom" 0 '^UNKNOWN app-name: ' '^UNKNOWN icon-sizes: '

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

seed flutter "missing icon file" icon-sizes ios "rm $set_dir/Icon-1024.png" '"Icon-1024\.png" is listed .* missing'
seed flutter "no marketing entry" icon-sizes ios "sub $set_dir/Contents.json '{\"filename\":\"Icon-1024.png\",\"idiom\":\"ios-marketing\",\"scale\":\"1x\",\"size\":\"1024x1024\"},' ''" 'no 1024x1024 App Store icon'
seed flutter "wrong marketing size" icon-sizes ios "png $set_dir/Icon-1024.png 512 512 2" '"Icon-1024\.png" is 512x512'
seed flutter "wrong small size" icon-sizes ios "png $set_dir/Icon-60-2x.png 60 60 2" '"Icon-60-2x\.png" is 60x60, expected 120x120'
seed flutter "string empty" permission-strings ios "sub ios/Runner/Info.plist 'Todo scans a code to add an item.' ''" 'NSCameraUsageDescription" is declared but empty'
seed flutter "api without string" permission-strings ios "sub lib/main.dart 'ImageSource.camera' 'ImageSource.gallery'" 'needs "NSPhotoLibraryUsageDescription"'
seed flutter "missing id" bundle-id ios "over PRODUCT_BUNDLE_IDENTIFIER=; sub ios/Runner/Info.plist '<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''" 'no bundle id'
seed flutter "bad id" bundle-id ios "over PRODUCT_BUNDLE_IDENTIFIER=io_github.todo" '"io_github\.todo" must be'
seed flutter "empty name" app-name ios "sub ios/Runner/Info.plist '<string>Todo</string>' '<string></string>'" 'name is empty'
seed flutter "ios empty privacy" privacy-policy-url ios 'state . "\"\""' 'App Store Connect requires'
seed flutter "android icon gone" icon-sizes android "built_no_icon; sub android/$km/AndroidManifest.xml ' android:icon=\"@mipmap/ic_launcher\"' ''" 'android:icon is missing'
seed flutter "android icon wrong size" icon-sizes android "webp android/$km/res/mipmap-hdpi/ic_launcher.webp VP8L 96 96" 'mipmap-hdpi/ic_launcher\.webp" is 96x96, expected 72x72'
seed flutter "android host permission undeclared" permissions-declared android "put android/$km/kotlin/M.kt 'val p = Manifest.permission.READ_CONTACTS\n'" '"READ_CONTACTS", which is not declared'
seed flutter "android empty name" app-name android "sub android/$km/res/values/strings.xml '>Todo<' '><'" 'name is empty'
seed flutter "android empty privacy" privacy-policy-url android 'state . "\"\""' 'Google Play requires'
seed flutter "web icon gone" icon-sizes web "rm web/icons/Icon-192.png" 'Icon-192\.png", which is missing'
seed flutter "web manifest size" icon-sizes web "png web/icons/Icon-192.png 96 96 6" 'is 96x96 but manifest declares'
seed flutter "web empty name" app-name web "sub web/manifest.json '\"name\":\"Todo\",' ''; sub web/index.html '<title>Todo</title>' '<title></title>'" 'name is empty'
seed flutter "web nothing named" app-name web "sub web/manifest.json '\"name\":\"Todo\",' ''; sub web/index.html '<title>Todo</title>' ''" 'no name in a web manifest'
rm -f "$tmp/built.xml"
built io.github.test.todo

variant flutter gallery-camera
sub "$dir/lib/main.dart" 'pickImage(source: ImageSource.camera)' 'pickVideo(source: ImageSource.camera)'
native ios
expect "flutter: pickVideo from camera needs the microphone key" 1 '^FAIL permission-strings: .*needs "NSMicrophoneUsageDescription"'

variant flutter no-web
rm -rf "$dir/web"
run_check "$dir" --platform web
expect "flutter on web without web/ exits 2" 2
[ -n "$err" ] || fail "flutter no-web" "no message"

# ---- Seeded gaps: xcode ----------------------------------------------------

seed xcode "missing icon set" icon-sizes ios "rm -rf Runner/Assets.xcassets" 'no "AppIcon\.appiconset"'
seed xcode "no icon set name" icon-sizes ios "over ASSETCATALOG_COMPILER_APPICON_NAME=" 'no ASSETCATALOG_COMPILER_APPICON_NAME'
seed xcode "missing marketing file" icon-sizes ios "rm $xset/Icon-1024.png" '"Icon-1024\.png" is listed .* missing'
seed xcode "wrong size" icon-sizes ios "png $xset/Icon-1024.png 1023 1023 2" '"Icon-1024\.png" is 1023x1023'
seed xcode "string empty" permission-strings ios "sub Runner/Info.plist 'Todo scans a code to add an item.' '   '" 'NSCameraUsageDescription" is declared but empty'
seed xcode "api without string" permission-strings ios "sub Runner/App.swift '.video' '.audio'" 'needs "NSMicrophoneUsageDescription"'
seed xcode "missing id" bundle-id ios "over PRODUCT_BUNDLE_IDENTIFIER=; sub Runner/Info.plist '<key>CFBundleIdentifier</key><string>\$(PRODUCT_BUNDLE_IDENTIFIER)</string>' ''" 'no bundle id'
seed xcode "bad id" bundle-id ios "over PRODUCT_BUNDLE_IDENTIFIER=io.github.test.todo_app" 'todo_app" must be'
seed xcode "empty name" app-name ios "sub Runner/Info.plist '<string>Todo</string>' '<string></string>'" 'name is empty'
seed xcode "no name anywhere" app-name ios "over PRODUCT_NAME=; sub Runner/Info.plist '<key>CFBundleDisplayName</key><string>Todo</string>' ''" 'no app name'
seed xcode "non-string display name" app-name ios "sub Runner/Info.plist '<key>CFBundleDisplayName</key><string>Todo</string>' '<key>CFBundleDisplayName</key><integer>1</integer>'" 'the app name is empty'
seed xcode "non-string permission value" permission-strings ios "sub Runner/Info.plist '<string>Todo scans a code to add an item.</string>' '<integer>1</integer>'" 'NSCameraUsageDescription" is declared but empty'
seed xcode "empty privacy" privacy-policy-url ios 'state . "\"\""' 'App Store Connect requires'

variant xcode location
put "$dir/Runner/App.swift" 'import CoreLocation\nfunc go(m: CLLocationManager) { m.requestAlwaysAuthorization() }\n'
native ios
expect "requestAlwaysAuthorization needs location keys" 1 '^FAIL permission-strings: .*needs "NSLocationAlwaysAndWhenInUseUsageDescription".*needs "NSLocationWhenInUseUsageDescription"'

variant xcode objc
rm "$dir/Runner/App.swift"
put "$dir/Runner/App.m" '[AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:nil];\n'
native ios
expect "objc API scan" 1 '^FAIL permission-strings: .*needs "NSMicrophoneUsageDescription"'

variant xcode pods-skip
put "$dir/Pods/X/X.swift" 'func go() { AVCaptureDevice.requestAccess(for: .audio) { _ in } }\n'
put "$dir/build/Y.swift" 'func go() { AVCaptureDevice.requestAccess(for: .audio) { _ in } }\n'
native ios
expect "Pods and build are not scanned" 0 '^PASS permission-strings: ' '!^FAIL '

variant xcode malformed-plist
put "$dir/Runner/Info.plist" '<plist><dict><key>oops'
native ios
expect "malformed Info.plist gives UNKNOWN" 0 '^UNKNOWN app-name: .*plist' '^UNKNOWN permission-strings: .*plist' '^PASS bundle-id: ' '!^FAIL '

variant xcode malformed-contents
put "$dir/$xset/Contents.json" '{"images": ['
native ios
expect "malformed Contents.json gives UNKNOWN" 0 '^UNKNOWN icon-sizes: .*not valid JSON' '^UNKNOWN icon-alpha: ' '!^FAIL '

variant xcode malformed-marketing
put "$dir/$xset/Icon-1024.png" 'junk'
native ios
expect "malformed marketing PNG gives UNKNOWN" 0 '^UNKNOWN icon-sizes: ' '^UNKNOWN icon-alpha: ' '!^FAIL '

variant xcode single-size
put "$dir/$xset/Contents.json" '{"images":[{"appearances":[{"appearance":"luminosity","value":"dark"}],"filename":"Dark.png","idiom":"universal","platform":"ios","size":"1024x1024"},{"filename":"Icon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}]}\n'
rm "$dir/$xset/Icon-60-2x.png"
png "$dir/$xset/Dark.png" 1024 1024 6
native ios
expect "single-size set passes; dark appearance may carry alpha" 0 '^PASS icon-sizes: ' '^PASS icon-alpha: "Icon-1024.png"'
png "$dir/$xset/Icon-1024.png" 1024 1024 6
native ios
expect "single-size default icon with alpha is UNKNOWN" 0 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document'

variant xcode icon-composer
mkdir -p "$dir/Runner/AppIcon.icon"
native ios
expect "AppIcon.icon wins and is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*Icon Composer' '^UNKNOWN icon-alpha: .*Icon Composer'

variant xcode marketing-no-size
sub "$dir/$xset/Contents.json" '{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}' '{"filename":"Icon-1024.png","idiom":"ios-marketing"}'
png "$dir/$xset/Icon-1024.png" 512 512 2
native ios
expect "a marketing file under 1024 fails whatever its entry declares" 1 '^FAIL icon-sizes: "Icon-1024.png" is 512x512, expected 1024x1024' '!1024x1024 App Store icon present'

variant xcode marketing-only
put "$dir/$xset/Contents.json" '{"images":[{"idiom":"iphone","scale":"2x","size":"60x60"},{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}]}\n'
native ios
expect "only the marketing well filled is UNKNOWN" 0 '^UNKNOWN icon-sizes: the set lists device sizes' '!^PASS icon-sizes: '

variant xcode two-iconsets
mkdir -p "$dir/Other/Assets.xcassets"
cp -R "$dir/$xset" "$dir/Other/Assets.xcassets/"
native ios
expect "two matching icon sets are UNKNOWN" 0 '^UNKNOWN icon-sizes: more than one "AppIcon.appiconset"' '^UNKNOWN icon-alpha: more than one'

variant xcode alpha-native
png "$dir/$xset/Icon-1024.png" 1024 1024 6
native ios
expect "xcode: an alpha channel is UNKNOWN, with the reason" 0 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document' '!^FAIL '
variant flutter alpha-native
png "$dir/$set_dir/Icon-1024.png" 1024 1024 3 trns
native ios
expect "flutter: tRNS is UNKNOWN, with the reason" 0 '^UNKNOWN icon-alpha: "Icon-1024.png" has an alpha.*no current Apple document' '!^FAIL '
variant expo alpha-expo-config
png "$dir/assets/icon.png" 1024 1024 6
run_check "$dir" --platform ios
expect "the Expo config route: an alpha channel still FAILs, from Expo's docs" 1 "^FAIL icon-alpha: .*has an alpha channel or transparency; Expo's docs say"

variant xcode webp-alpha
webp "$dir/$xset/Icon-1024.png" VP8L 1024 1024
native ios
expect "xcode: WebP alpha cannot be read" 0 '^UNKNOWN icon-alpha: .*not a PNG' '^PASS icon-sizes: '
variant expo webp-alpha-expo
webp "$dir/assets/icon.png" VP8L 1024 1024
run_check "$dir" --platform ios
expect "expo: WebP alpha cannot be read" 0 '^UNKNOWN icon-alpha: .*not a PNG'

variant xcode all-gaps
put "$dir/Runner/App.swift" 'import CoreBluetooth\nlet a = CBCentralManager()\nlet b = CMPedometer()\n'
png "$dir/$xset/Icon-1024.png" 512 512 2
png "$dir/$xset/Icon-60-2x.png" 60 60 2
native ios
expect "strings: every gap on one line" 1 '^FAIL permission-strings: .*needs "NSBluetoothAlwaysUsageDescription".*needs "NSMotionUsageDescription".*; fix: .*NSBluetoothAlwaysUsageDescription.*NSMotionUsageDescription'
expect "icons: every gap on one line" 1 '^FAIL icon-sizes: .*"Icon-60-2x.png" is 60x60.*"Icon-1024.png" is 512x512.*; fix: .*120x120.*1024x1024'

variant xcode one-fix
put "$dir/$xset/Contents.json" '{"images":[{"filename":"Gone1.png","idiom":"iphone","scale":"2x","size":"60x60"},{"filename":"Gone2.png","idiom":"iphone","scale":"3x","size":"60x60"},{"filename":"Icon-1024.png","idiom":"ios-marketing","scale":"1x","size":"1024x1024"}]}\n'
native ios
expect "a repeated fix prints once, every gap still named" 1 '^FAIL icon-sizes: .*Gone1.*Gone2.*; fix: ' '!fix: .*alpha channel.*alpha channel'

# ---- Seeded gaps: kotlin ---------------------------------------------------

seed kotlin "icon attr gone" icon-sizes android "built_no_icon; sub $km/AndroidManifest.xml ' android:icon=\"@mipmap/ic_launcher\"' ''" 'android:icon is missing'
seed kotlin "icon files gone" icon-sizes android "rm -rf $km/res/mipmap-*" '"@mipmap/ic_launcher" has no file'
seed kotlin "wrong VP8L size" icon-sizes android "webp $km/res/mipmap-xxxhdpi/ic_launcher.webp VP8L 96 96" 'mipmap-xxxhdpi/ic_launcher.webp" is 96x96, expected 192x192'
seed kotlin "wrong VP8 size" icon-sizes android "webp $km/res/mipmap-mdpi/ic_launcher.webp VP8 96 96" 'mipmap-mdpi/ic_launcher.webp" is 96x96, expected 48x48'
seed kotlin "wrong VP8X size" icon-sizes android "webp $km/res/mipmap-xhdpi/ic_launcher.webp VP8X 48 48" 'mipmap-xhdpi/ic_launcher.webp" is 48x48, expected 96x96'
seed kotlin "wrong PNG size" icon-sizes android "rm $km/res/mipmap-hdpi/ic_launcher.webp; png $km/res/mipmap-hdpi/ic_launcher.png 48 48 6" 'mipmap-hdpi/ic_launcher.png" is 48x48, expected 72x72'
seed kotlin "adaptive foreground gone" icon-sizes android "rm $km/res/drawable/ic_launcher_foreground.xml" '"@drawable/ic_launcher_foreground" has no file'
seed kotlin "adaptive vector not 108dp" icon-sizes android "sub $km/res/drawable/ic_launcher_foreground.xml 'android:width=\"108dp\"' 'android:width=\"96dp\"'" 'android:width "96dp", expected 108dp'
seed kotlin "permission undeclared" permissions-declared android "built_permissions" '"CAMERA", which is not declared'
seed kotlin "second permission undeclared" permissions-declared android "put $km/java/io/test/L.java 'class L { String a = android.Manifest.permission.ACCESS_FINE_LOCATION; }\n'" '"ACCESS_FINE_LOCATION", which is not declared'
seed kotlin "literal permission undeclared" permissions-declared android "put $km/java/io/test/L.kt 'val a = \"android.permission.RECORD_AUDIO\"\n'" '"RECORD_AUDIO", which is not declared'
seed kotlin "bad id in the artifact" package android "built io.github.2todo" '"io\.github\.2todo" needs'
seed kotlin "label gone" app-name android "built_no_label; sub $km/AndroidManifest.xml ' android:label=\"@string/app_name\"' ''" 'android:label is missing'
seed kotlin "empty name" app-name android "sub $km/res/values/strings.xml '>Todo<' '> <'" 'name is empty'
seed kotlin "empty privacy" privacy-policy-url android 'state . "\"\""' 'Google Play requires'
rm -f "$tmp/built.xml"
built io.github.test.todo

variant kotlin dangerous-evidence
built_permissions CAMERA READ_CONTACTS INTERNET
native android
expect "evidence lists dangerous permissions only" 0 '^PASS permissions-declared: declared dangerous: "CAMERA", "READ_CONTACTS"; ' '!INTERNET'
built io.github.test.todo

variant kotlin malformed-manifest
put "$dir/$km/AndroidManifest.xml" '<manifest><application'
native android
expect "malformed manifest gives UNKNOWN; the built manifest still decides permissions" 0 '^UNKNOWN app-name: .*XML' '^UNKNOWN icon-sizes: .*XML' '^PASS permissions-declared: ' '!^FAIL '
run_check "$dir" --platform android
expect "malformed manifest with no built manifest: permissions UNKNOWN" 0 '^UNKNOWN permissions-declared: .*XML' '!^FAIL '

variant flutter missing-manifest
rm "$dir/android/$km/AndroidManifest.xml"
native android
expect "a missing manifest is UNKNOWN: Gradle can relocate it" 0 '^UNKNOWN app-name: .*missing' '^UNKNOWN icon-sizes: .*missing' '^PASS permissions-declared: ' '!^FAIL '
run_check "$dir" --platform android
expect "a missing manifest with no built manifest: permissions UNKNOWN" 0 '^UNKNOWN permissions-declared: .*missing' '!^FAIL '

variant kotlin string-gone
sub "$dir/$km/res/values/strings.xml" 'name="app_name"' 'name="other"'
native android
expect "@string/x absent from res/values is UNKNOWN: resValue or a flavor can supply it" 0 '^UNKNOWN app-name: "@string/app_name" is not in res/values' '!^FAIL '

variant kotlin other-values-file
sub "$dir/$km/res/values/strings.xml" '<string name="app_name">Todo</string>' ''
put "$dir/$km/res/values/app.xml" '<resources><string name="app_name">Todo</string></resources>\n'
native android
expect "app_name in another values file is found" 0 '^PASS app-name: "Todo" from "app/src/main/res/values/app.xml"'

for bad in "$km/res/values/strings.xml:<resources><string" "$km/res/mipmap-anydpi-v26/ic_launcher.xml:<adaptive-icon" "$km/res/mipmap-mdpi/ic_launcher.webp:RIFFxxxxWEBPVP8Lzz"; do
  variant kotlin malformed-res
  put "$dir/${bad%%:*}" "${bad#*:}"
  native android
  expect "malformed ${bad%%:*} gives UNKNOWN" 0 '^UNKNOWN ' '!^FAIL '
done

variant kotlin placeholder-label
sub "$dir/$km/AndroidManifest.xml" '@string/app_name' '${appLabel}'
native android
expect "Gradle placeholder label is UNKNOWN" 0 '^UNKNOWN app-name: '

variant kotlin sdk23
sub "$dir/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' '<uses-permission-sdk-23 android:name="android.permission.CAMERA" />'
run_check "$dir" --platform android
expect "uses-permission-sdk-23 in src/main declares a permission" 0 '^PASS permissions-declared: declared dangerous: "CAMERA"'
built io.github.test.todo '' '<uses-permission-sdk-23 android:name="android.permission.CAMERA" />'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "uses-permission-sdk-23 in the built manifest declares a permission" 0 '^PASS permissions-declared: declared dangerous: "CAMERA"'
built io.github.test.todo

variant kotlin all-android-gaps
put "$dir/$km/java/io/test/L.kt" 'val a = Manifest.permission.READ_SMS\nval b = Manifest.permission.READ_CONTACTS\n'
webp "$dir/$km/res/mipmap-hdpi/ic_launcher.webp" VP8L 96 96
webp "$dir/$km/res/mipmap-mdpi/ic_launcher.webp" VP8L 96 96
native android
expect "permissions and icons: every gap on one line" 1 '^FAIL permissions-declared: .*"READ_CONTACTS", which is not declared.*"READ_SMS", which is not declared; fix: .*READ_CONTACTS.*READ_SMS' '^FAIL icon-sizes: .*mipmap-hdpi.*is 96x96, expected 72x72.*mipmap-mdpi.*is 96x96, expected 48x48; fix: .*72x72.*48x48'

variant flutter android-scope
put "$dir/packages/x/android/P.kt" 'val a = Manifest.permission.READ_SMS\n'
put "$dir/tool/T.java" 'class T { String a = "android.permission.READ_SMS"; }\n'
native android
expect "flutter's Android scan covers only android/" 0 '^PASS permissions-declared: ' '!READ_SMS'

mkdir -p "$tmp/gradle-root/src/main"
put "$tmp/gradle-root/build.gradle" 'apply plugin: "com.android.application"\n'
put "$tmp/gradle-root/src/main/AndroidManifest.xml" '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Todo" android:icon="@mipmap/x"/></manifest>\n'
run_check "$tmp/gradle-root" --platform android
expect "a Gradle file plus a manifest at the project root is an Android app" 1 '^PASS app-name: "Todo"' '^UNKNOWN package: '

# ---- Android layers that cannot be judged ----------------------------------

android_icon_is() {
  variant kotlin icon-xml
  rm -rf "$dir/$km/res/mipmap-"* "$dir/$km/res/drawable"
  put "$dir/$km/res/mipmap-anydpi-v26/ic_launcher.xml" "$1"
  native android
}
android_icon_is '<layer-list xmlns:android="http://schemas.android.com/apk/res/android"/>\n'
expect "layer-list launcher is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"layer-list" drawable' '!^PASS icon-sizes: '
android_icon_is '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp"/>\n'
expect "legacy vector launcher is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"vector" drawable' '!^PASS icon-sizes: '
android_icon_is '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android" xmlns:aapt="http://schemas.android.com/aapt"><background android:drawable="@color/white"/><foreground><aapt:attr name="android:drawable"><vector/></aapt:attr></foreground></adaptive-icon>\n'
expect "inline aapt:attr foreground is UNKNOWN" 0 '^UNKNOWN icon-sizes: <foreground> in .*inline drawable' '!^PASS icon-sizes: '
android_icon_is '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/white"/><foreground/></adaptive-icon>\n'
expect "an empty adaptive foreground fails" 1 '^FAIL icon-sizes: <foreground> in .* has no drawable'

variant kotlin layer-in-adaptive
put "$dir/$km/res/drawable/ic_launcher_foreground.xml" '<layer-list xmlns:android="http://schemas.android.com/apk/res/android"/>\n'
native android
expect "a layer-list adaptive layer is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"layer-list" drawable' '!^PASS icon-sizes: '

variant kotlin no-density
mkdir -p "$dir/$km/res/mipmap"
png "$dir/$km/res/mipmap/ic_launcher.png" 48 48 6
native android
expect "a bitmap with no density qualifier is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*"mipmap/ic_launcher.png" has no density' '!^PASS icon-sizes: '

variant kotlin non-resource-icon
sub "$dir/$km/AndroidManifest.xml" '@mipmap/ic_launcher' '@android:drawable/sym_def_app_icon'
native android
expect "a framework icon reference is UNKNOWN" 0 '^UNKNOWN icon-sizes: icon reference'

variant expo remote-android-icon
sub "$dir/app.json" './assets/fg.png' 'https://example.org/fg.png'
run_check "$dir" --platform android
expect "a remote Android icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*remote URL' '!^PASS icon-sizes: '

# ---- Web: names and icons come from data files --------------------------------

seed vite "icon link gone" icon-sizes web "rm public/favicon.svg" 'favicon\.svg", which is missing'
seed vite "manifest icon gone" icon-sizes web "rm public/icon-64.png" 'icon-64\.png", which is missing'
seed vite "manifest size mismatch" icon-sizes web "png public/icon-64.png 32 32 6" 'is 32x32 but manifest declares'
variant vite empty-title-vite
rm "$dir/public/manifest.webmanifest"
sub "$dir/index.html" '<title>Todo</title>' '<title> </title>'
run_check "$dir" --platform web
expect "vite: an empty title with no manifest is UNKNOWN" 0 '^UNKNOWN app-name: .*a JS or TS config may set it' '!^FAIL '
seed static "icon gone" icon-sizes web "rm favicon.png" 'favicon\.png", which is missing'
seed static "no icons declared" icon-sizes web "sub index.html '<link rel=\"icon\" sizes=\"32x32\" href=\"favicon.png\">' ''" 'no icon declared'
seed static "declared size mismatch" icon-sizes web "png favicon.png 16 16 6" 'is 16x16 but index.html declares'
seed static "empty title" app-name web "sub index.html '<title>Todo</title>' '<title></title>'" 'name is empty'
seed static "no title" app-name web "sub index.html '<title>Todo</title>' ''" 'no name in a web manifest'

variant vite nothing-declared
rm "$dir/public/manifest.webmanifest"
put "$dir/index.html" '<!doctype html><html><head></head></html>\n'
put "$dir/vite.config.ts" 'export default { plugins: [VitePWA({ manifest: { name: "Todo" } })] };\n'
run_check "$dir" --platform web
expect "vite with no manifest and no title or icon link: a config may set them" 0 '^UNKNOWN app-name: .*a JS or TS config may set it' '^UNKNOWN icon-sizes: .*a JS or TS config may set one' '!^FAIL '

variant vite title-placeholder
rm "$dir/public/manifest.webmanifest"
sub "$dir/index.html" '<link rel="manifest" href="/manifest.webmanifest">' ''
sub "$dir/index.html" '<title>Todo</title>' '<title>%VITE_APP_TITLE%</title>'
run_check "$dir" --platform web
expect "a build placeholder in <title> is UNKNOWN" 0 '^UNKNOWN app-name: '

for ref in 'https://cdn.example.org/favicon.svg' 'data:image/svg+xml,%3Csvg/%3E' '%BASE%/favicon.svg'; do
  variant vite odd-icon
  sub "$dir/index.html" 'href="/favicon.svg"' "href=\"$ref\""
  run_check "$dir" --platform web
  expect "icon reference $ref is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*remote, inline, or a build placeholder' '!^PASS icon-sizes: '
done

variant vite malformed-manifest
put "$dir/public/manifest.webmanifest" '{"name": '
run_check "$dir" --platform web
expect "malformed manifest gives UNKNOWN" 0 '^UNKNOWN app-name: .*not valid JSON' '^UNKNOWN icon-sizes: .*not valid JSON' '!^FAIL '

variant vite malformed-icon
put "$dir/public/icon-64.png" 'junk'
run_check "$dir" --platform web
expect "malformed PNG gives UNKNOWN on web" 0 '^UNKNOWN icon-sizes: ' '!^FAIL '

layout_is() {
  variant nextjs layout
  put "$dir/app/layout.tsx" "$1"
}
layout_is 'export const metadata = { title: "Todo", [runtimeKey]: "" };\n'
run_check "$dir" --platform web
expect "next layout with a computed key and no data file: UNKNOWN" 0 '^UNKNOWN app-name: .*a JS or TS config may set it' '!^PASS app-name: '
layout_is 'const title = "x";\nexport const metadata = { title: "Todo", description: title };\n'
run_check "$dir" --platform web
expect "next layout with a value reference and no data file: UNKNOWN" 0 '^UNKNOWN app-name: ' '!^PASS app-name: '
put "$dir/app/manifest.json" '{"name":"From Manifest"}\n'
run_check "$dir" --platform web
expect "next layout is not read: app/manifest.json decides" 0 '^PASS app-name: "From Manifest" from "app/manifest.json"'
run_check "$tmp/nextjs" --platform web
expect "next layout with a literal title and no data file: UNKNOWN, never PASS" 0 '^UNKNOWN app-name: ' '!^PASS app-name: ' '^PASS icon-sizes: '

variant nextjs no-icon
rm "$dir/app/icon.png"
run_check "$dir" --platform web
expect "nextjs with no icon declared: UNKNOWN, a config may set it" 0 '^UNKNOWN icon-sizes: .*a JS or TS config may set one' '!^FAIL '
put "$dir/app/layout.tsx" 'export const metadata = { icons: { icon: "/x.png" } };\n'
run_check "$dir" --platform web
expect "metadata.icons is not read" 0 '^UNKNOWN icon-sizes: .*a JS or TS config may set one' '!metadata'
rm "$dir/app/layout.tsx"
png "$dir/public/favicon.png" 32 32 6
run_check "$dir" --platform web
expect "public/favicon alone does not count" 0 '^UNKNOWN icon-sizes: .*a JS or TS config may set one' '!^PASS icon-sizes: '

variant nextjs icon-code
rm "$dir/app/icon.png"
put "$dir/app/icon.tsx" 'export default function Icon() { return null; }\n'
run_check "$dir" --platform web
expect "a generated icon is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*generates its icon' '!^PASS icon-sizes: '

for name in favicon.ico icon2.jpg; do
  variant nextjs convention-icon
  rm "$dir/app/icon.png"
  put "$dir/app/$name" 'x'
  run_check "$dir" --platform web
  expect "next file-convention icon $name counts" 0 '^PASS icon-sizes: '
done

variant nextjs src-app
mkdir "$dir/src"
mv "$dir/app" "$dir/src/app"
run_check "$dir" --platform web
expect "src/app is read" 0 '^PASS icon-sizes: '

variant nextjs manifest-json
put "$dir/app/manifest.json" '{"name":"Todo App"}\n'
run_check "$dir" --platform web
expect "app/manifest.json decides the name" 0 '^PASS app-name: "Todo App"'

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
empty='^FAIL privacy-policy-url: no privacy policy URL'
unread='^UNKNOWN privacy-policy-url: '
url_case "double quotes" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"\n---\n' 0 "$good"
url_case "single quotes" "---\nprovided:\n  publish-readiness:\n    privacy_policy_url: 'https://example.org/p'\n---\n" 0 "$good"
url_case "plain" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p\n---\n' 0 "$good"
url_case "trailing comment" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p   # the page\n---\n' 0 "$good"
url_case "quoted trailing comment" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"  # the page\n---\n' 0 "$good"
url_case "fragment stays" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p#top\n---\n' 0 '^PASS privacy-policy-url: "https://example.org/p#top"$'
url_case "comments and blanks between" '---\nprovided: # facts\n\n  # by skill\n  publish-readiness:\n\n    # url\n    privacy_policy_url: https://example.org/p\n---\n' 0 "$good"
url_case "the seed shape, with a sibling after" '---\nschema: "1.0"\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p"\n    support_email_env: ""\nhistory:\n  - { skill: app-creators, version: "0.1.1", date: 2026-11-02, result: ok }\n---\n' 0 "$good"
url_case "a flow map elsewhere is not on the path" '---\nreadiness: { ios: { result: pass } }\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://example.org/p\n---\n' 0 "$good"
url_case "absent provided is empty" '---\nschema: "1.0"\n---\n' 1 "$empty"
url_case "provided: {} is empty" '---\nprovided: {}\n---\n' 1 "$empty"
url_case "provided: {} with a comment is empty" '---\nprovided: {}   # none yet\n---\n' 1 "$empty"
url_case "publish-readiness: {} is empty" '---\nprovided:\n  publish-readiness: {}\n---\n' 1 "$empty"
url_case "empty string" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: ""\n---\n' 1 "$empty"
url_case "null value" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: ~\n---\n' 1 "$empty"
url_case "other skill is not read" '---\nprovided:\n  store-listing:\n    privacy_policy_url: https://example.org/wrong\n  publish-readiness:\n    privacy_policy_url: ""\n---\n' 1 "$empty"
url_case "same key at the top is not read" '---\nprivacy_policy_url: https://example.org/wrong\nprovided:\n  publish-readiness:\n    other: x\n---\n' 1 "$empty"
url_case "the key after its block ended is not read" '---\nprovided:\n  publish-readiness:\n    other: x\n  privacy_policy_url: https://example.org/wrong\n---\n' 1 "$empty"
url_case "a sibling block of the skill is not read" '---\nprovided:\n  publish-readiness:\n    other: x\n  store-listing:\n    privacy_policy_url: https://example.org/wrong\n---\n' 1 "$empty"
url_case "a scalar parent with nested text is not read" '---\nprovided:\n  publish-readiness: none\n    privacy_policy_url: https://example.org/wrong\n---\n' 1 "$empty"
url_case "a deeper nested key is not read" '---\nprovided:\n  publish-readiness:\n    other:\n      privacy_policy_url: https://example.org/wrong\n---\n' 1 "$empty"
url_case "a flow map at provided is UNKNOWN" '---\nprovided: { publish-readiness: { privacy_policy_url: "https://example.org/p" } }\n---\n' 0 "$unread"
url_case "a flow map at the skill is UNKNOWN" '---\nprovided:\n  publish-readiness: { privacy_policy_url: "https://example.org/p" }\n---\n' 0 "$unread"
url_case "a block scalar is UNKNOWN" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: |\n      https://example.org/p\n---\n' 0 "$unread"
url_case "a folded block scalar is UNKNOWN" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: >-\n      https://example.org/p\n---\n' 0 "$unread"
url_case "an escape in a quoted value is UNKNOWN" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p\\\\q"\n---\n' 0 "$unread"
url_case "unterminated quote" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "https://example.org/p\n---\n' 0 "$unread"
url_case "no frontmatter" 'just text\n' 0 "$unread"
url_case "unclosed frontmatter" '---\nprovided:\n' 0 "$unread"
url_case "ftp URL" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: ftp://example.org/p\n---\n' 1 '^FAIL privacy-policy-url: .*not an http'
url_case "scheme only" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: https://\n---\n' 1 '^FAIL privacy-policy-url: .*not an http'
printf '\377\376bad' >"$dir/.app-creators/state.md"
run_check "$dir" --platform web --collects-data yes
expect "state: not UTF-8" 0 "$unread"

variant xcode missing-state
rm -rf "$dir/.app-creators"
native ios
expect "ios missing state is UNKNOWN" 0 "$unread"

variant xcode bad-url-ios
state "$dir" '"www.example.org"'
native ios
expect "ios invalid URL fails" 1 '^FAIL privacy-policy-url: '

# ---- Exit 2 ----------------------------------------------------------------

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
two "kotlin on web" 'kotlin has no web route' "$tmp/kotlin" --platform web
two "unknown framework" 'no supported framework' "$tmp/empty" --platform ios
variant expo no-web-carry
put "$dir/package.json" '{"name":"todo","dependencies":{"expo":"~58.0.0"}}\n'
two "expo without react-dom on web" 'no web route' "$dir" --platform web
put "$dir/package.json" '{"name":"todo","dependencies":{"expo":"~58.0.0","react-dom":"19.0.0"}}\n'
sub "$dir/app.json" '"expo":{' '"expo":{"platforms":["ios"],'
two "expo platforms list without web" 'no web route' "$dir" --platform web
two "expo platforms list without android" 'no android route' "$dir" --platform android
put "$tmp/dart-only/pubspec.yaml" 'name: lib\ndependencies:\n  path: ^1.0.0\n'
two "plain Dart package is not flutter" 'no supported framework' "$tmp/dart-only" --platform ios

variant expo expo-with-vite
put "$dir/vite.config.ts" 'export default {};\n'
run_check "$dir" --platform ios
expect "expo wins over a vite config" 0 '^PASS bundle-id: '

variant vite next-over-vite
put "$dir/next.config.mjs" 'export default {};\n'
two "next beats vite in the table" 'nextjs has no ios route' "$dir" --platform ios

# ---- Bounded reads (SEC-1) -------------------------------------------------

# guarded <command>: run with a limit, so a block gives exit 124 instead of hanging the suite.
guarded() {
  set +e
  python3 -I -c 'import subprocess,sys
out,err=open(sys.argv[1],"wb"),open(sys.argv[2],"wb")
try:
    sys.exit(subprocess.run(sys.argv[3:],stdin=subprocess.DEVNULL,stdout=out,stderr=err,timeout=20).returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)' "$tmp/w.out" "$tmp/w.err" "$@"
  code=$?
  set -e
  out="$(cat "$tmp/w.out")"
  err="$(cat "$tmp/w.err")"
}

# watched <args>: run_check under guarded.
watched() {
  guarded python3 -I "$check" "$@"
}

# watched_native <platform>: the current variant with its resolved input, under guarded.
watched_native() {
  local platform="$1"
  native_args "$platform"
  # shellcheck disable=SC2086
  watched "$dir" --platform "$platform" $rargs
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
watched "$tmp/expo" --platform ios --resolved "$tmp/config.fifo"
total=$((total + 1))
if [ "$code" = 2 ] && [ -z "$out" ] && printf '%s\n' "$err" | grep -q 'not a regular file'; then pass=$((pass + 1)); else fail "FIFO --resolved" "exit $code, out '$out', err '$err'"; fi

python3 -I -c 'import sys
open(sys.argv[1],"w").write("{\"expo\":"+" "*(17*1024*1024)+"{}}")' "$tmp/big-config.json"
watched "$tmp/expo" --platform ios --resolved "$tmp/big-config.json"
total=$((total + 1))
if [ "$code" = 2 ] && [ -z "$out" ] && printf '%s\n' "$err" | grep -q 'larger than'; then pass=$((pass + 1)); else fail "oversized --resolved" "exit $code, err '$err'"; fi

put "$tmp/outside-config.json" '{"expo":{"name":"Operator"}}\n'
watched "$tmp/expo" --platform ios --resolved "$tmp/outside-config.json"
expect "--resolved outside the project is read" 1 '^PASS app-name: "Operator"'

for rel in "$xset/Contents.json" "Runner/Info.plist" ".app-creators/state.md"; do
  variant xcode fifo-any
  rm "$dir/$rel"
  mkfifo "$dir/$rel"
  watched_native ios
  expect "FIFO $rel: no hang" 0 'not a regular file' '!^FAIL '
done
for rel in "$km/AndroidManifest.xml" "$km/res/values/strings.xml" "$km/res/mipmap-mdpi/ic_launcher.webp" "$km/res/mipmap-anydpi-v26/ic_launcher.xml"; do
  variant kotlin fifo-any
  rm "$dir/$rel"
  mkfifo "$dir/$rel"
  watched_native android
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
watched_native ios
expect "a directory where a file belongs is UNKNOWN" 0 '^UNKNOWN app-name: ' '!^FAIL '

variant xcode plist-symlink-out
rm "$dir/Runner/Info.plist"
ln -s "$tmp/outside.plist" "$dir/Runner/Info.plist"
watched_native ios
expect "a symlinked Info.plist out of the project is UNKNOWN" 0 '^UNKNOWN app-name: .*outside the project' '!OUTSIDE-VALUE'

variant kotlin xml-entities
put "$dir/$km/res/values/strings.xml" '<!DOCTYPE r [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]><resources><string name="app_name">&b;</string></resources>\n'
watched_native android
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
watched_native ios
expect "hostile Contents.json file name" 1 '^FAIL icon-sizes: "x\[2Jy.png" is listed'
safe_bytes "hostile Contents.json bytes" "$tmp/w.out" "$tmp/w.err"

variant xcode hostile-settings
resolve "$dir" "$(printf 'PRODUCT_BUNDLE_IDENTIFIER=bad\033[31m\342\200\256"id; fix: run this')"
watched "$dir" --platform ios --resolved "$tmp/xc.json"
expect "a hostile value in resolved settings stays one clean line" 1 '^FAIL bundle-id: bundle id "bad\[31m\\"id; fix: run this" must be'
safe_bytes "hostile settings bytes" "$tmp/w.out" "$tmp/w.err"

variant kotlin hostile-android
sub "$dir/$km/AndroidManifest.xml" '@string/app_name' 'x&#x202E;y&#10;z&quot;'
sub "$dir/$km/AndroidManifest.xml" '@mipmap/ic_launcher' '@foo/a&#x202E;&quot;'
watched_native android
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

watched "$tmp/expo" --platform ios --resolved "$tmp/$hostile_arg"
total=$((total + 1))
if [ "$code" = 2 ] && printf '%s\n' "$err" | grep -q 'could not be read'; then pass=$((pass + 1)); else fail "hostile --resolved path" "exit $code err '$err'"; fi
safe_bytes "hostile --resolved bytes" "$tmp/w.out" "$tmp/w.err"
total=$((total + 1))
if [ "$(wc -l <"$tmp/w.err" | tr -d ' ')" = 1 ]; then pass=$((pass + 1)); else fail "hostile --resolved: one line" "$err"; fi

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
native android
expect "kotlin: a skipped source file is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*Big.kt" is larger than'

variant expo unknown-beside-fail
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
mkfifo "$dir/Pipe.ts"
watched "$dir" --platform ios
expect "a FAIL outranks a skipped file" 1 '^FAIL permission-strings: ' '!^UNKNOWN permission-strings: '

mkdir -p "$tmp/outside-code"
put "$tmp/outside-code/Away.ts" 'launchCameraAsync();\n'
variant expo link-outside
ln -s "$tmp/outside-code" "$dir/src"
run_check "$dir" --platform ios
expect "a linked folder outside the project is UNKNOWN, naming it" 0 '^UNKNOWN permission-strings: "src" points outside the project' '!^PASS permission-strings: '
run_check "$dir" --platform android
expect "same for permissions-declared" 0 '^UNKNOWN permissions-declared: "src" points outside the project'

variant expo link-inside
put "$dir/lib/Near.ts" 'launchCameraAsync();\n'
ln -s lib "$dir/lib2"
run_check "$dir" --platform ios
expect "a linked folder the walk already scans stays silent" 1 '^FAIL permission-strings: "lib/Near.ts" uses' '!lib2'

variant expo link-to-skipped
put "$dir/node_modules/x/Vendored.ts" 'launchCameraAsync();\n'
ln -s node_modules/x "$dir/vendored"
run_check "$dir" --platform ios
expect "a linked folder into a skipped folder is UNKNOWN" 0 '^UNKNOWN permission-strings: "vendored" points at a folder that is not scanned'

variant flutter link-out-of-scan-root
put "$dir/lib/Near.kt" 'val a = Manifest.permission.READ_SMS\n'
ln -s ../lib "$dir/android/linked"
native android
expect "a linked folder out of the scan root is UNKNOWN" 0 '^UNKNOWN permissions-declared: "android/linked" points at a folder that is not scanned'

variant flutter dot-symlinks
mkdir -p "$dir/ios/.symlinks/plugins"
ln -s "$tmp/outside-code" "$dir/ios/.symlinks/plugins/image_picker_ios"
native ios
expect "Flutter's ios/.symlinks is skipped" 0 '^PASS permission-strings: '

# ---- Raw-only versus code: a comment stripper error can never produce PASS ------

row_only_in_raw() {
  variant expo raw-only
  put "$dir/Row.ts" "$1\n"
  run_check "$dir" --platform ios
  expect "$2" 0 '^UNKNOWN permission-strings: "Row.ts" mentions an API that needs "NSCameraUsageDescription", but only in what reads as a comment' '!^(PASS|FAIL) permission-strings: '
}
row_only_in_raw 'const r =  /[/*]/; launchCameraAsync(); /* n */' 'raw-only: a regex with /* and two spaces hides the call, no key: UNKNOWN, not PASS'
row_only_in_raw 'const t = s => /[/*]/.test(s);\nlaunchCameraAsync(); /* n */' 'raw-only: an arrow function regex hides the call, no key: UNKNOWN, not PASS'
row_only_in_raw '// launchCameraAsync();' 'raw-only: a line comment, no key: UNKNOWN, not PASS'
row_only_in_raw '/* launchCameraAsync(); */ const u = "http://x";' 'raw-only: a closed comment, no key: UNKNOWN, not PASS'
row_only_in_raw '/* launchCameraAsync();' 'raw-only: an unclosed comment, no key: UNKNOWN, not PASS'

variant expo raw-only-key-present
sub "$dir/app.json" '"plugins":[' '"plugins":[["expo-camera",{"cameraPermission":"Scan a code."}],'
put "$dir/Row.ts" '// launchCameraAsync();\n'
run_check "$dir" --platform ios
expect "raw-only: a commented call with the key present stays PASS" 0 '^PASS permission-strings: ' '!needed by code: .*NSCamera'

variant expo raw-only-android
sub "$dir/app.json" '"android":{' '"android":{"blockedPermissions":["android.permission.CAMERA"],'
put "$dir/Row.ts" '// launchCameraAsync();\n'
run_check "$dir" --platform android
expect "raw-only: a blocked permission in a comment is UNKNOWN, not FAIL" 0 '^UNKNOWN permissions-declared: .*"CAMERA", but only in what reads as a comment'

variant expo raw-then-code
put "$dir/a.ts" '// launchCameraAsync();\n'
put "$dir/z.ts" 'launchCameraAsync();\n'
run_check "$dir" --platform ios
expect "raw-only in the first file, code in the second: FAIL" 1 '^FAIL permission-strings: "z.ts" uses an API that needs "NSCameraUsageDescription"'
variant expo code-then-raw
put "$dir/a.ts" 'launchCameraAsync();\n'
put "$dir/z.ts" '// launchCameraAsync();\n'
run_check "$dir" --platform ios
expect "code in the first file, raw-only in the second: FAIL" 1 '^FAIL permission-strings: "a.ts" uses an API that needs "NSCameraUsageDescription"'

variant xcode swift-raw-then-code
sub "$dir/Runner/App.swift" '.video' '.audio'
sub "$dir/Runner/Info.plist" 'NSCameraUsageDescription' 'NSMotionUsageDescription'
put "$dir/Runner/A.swift" '// let c = CMPedometer()\nlet d = CBCentralManager()\n'
put "$dir/Runner/Z.swift" '// let d = CBCentralManager()\n'
native ios
expect "swift: code wins over raw-only for a row, and raw-only alone costs nothing beside a key" 1 '^FAIL permission-strings: .*"Runner/A.swift" uses an API that needs "NSBluetoothAlwaysUsageDescription"'

for order in "A.kt:Z.kt" "Z.kt:A.kt"; do
  variant kotlin kt-order
  put "$dir/$km/java/${order%%:*}" '// val a = Manifest.permission.READ_SMS\n'
  put "$dir/$km/java/${order#*:}" 'val a = Manifest.permission.READ_SMS\n'
  native android
  expect "kotlin: comment in ${order%%:*}, code in ${order#*:}: FAIL" 1 "^FAIL permissions-declared: \"app/src/main/java/${order#*:}\" uses an API that needs \"READ_SMS\", which is not declared"
done
variant kotlin kt-raw-only
put "$dir/$km/java/A.kt" '// val a = Manifest.permission.READ_SMS\n'
native android
expect "kotlin: a permission only in a comment is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*"READ_SMS", but only in what reads as a comment'
built_permissions CAMERA READ_SMS
native android
expect "kotlin: a commented permission that is declared costs nothing" 0 '^PASS permissions-declared: .*needed by code: "CAMERA"; '
built io.github.test.todo

variant expo module-in-comment
put "$dir/Row.ts" "// from 'expo-contacts'\nrequestPermissionsAsync();\n"
run_check "$dir" --platform ios
expect "the module gate reads the same text: module only in a comment is raw-only, not FAIL" 0 '^UNKNOWN permission-strings: .*"NSContactsUsageDescription", but only in what reads as a comment' '!^FAIL permission-strings: '
variant expo module-in-code
put "$dir/Row.ts" "import * as C from 'expo-contacts';\n// C.getContactsAsync();\n"
run_check "$dir" --platform ios
expect "the module gate reads the same text: call only in a comment is raw-only" 0 '^UNKNOWN permission-strings: .*"NSContactsUsageDescription", but only in what reads as a comment'
variant expo module-across-files
put "$dir/a.ts" "// from 'expo-contacts'\nrequestPermissionsAsync();\n"
put "$dir/z.ts" "import * as C from 'expo-contacts';\nC.requestPermissionsAsync();\n"
run_check "$dir" --platform ios
expect "the module gate: raw-only in one file, code in the next: FAIL" 1 '^FAIL permission-strings: "z.ts" uses an API that needs "NSContactsUsageDescription"'
variant expo expo-module-guard
put "$dir/Row.ts" 'requestPermissionsAsync();\n'
run_check "$dir" --platform ios
expect "requestPermissionsAsync without a named module is not contacts" 0 '^PASS permission-strings: ' '!NSContactsUsageDescription'

variant expo template-literal
sub "$dir/App.tsx" 'await ImagePicker.launchImageLibraryAsync({});' 'const glob = `assets/*`; await ImagePicker.launchCameraAsync({}); /* end */'
run_check "$dir" --platform ios
expect "a glob in a template literal does not open a comment" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

variant expo unclosed-string
put "$dir/Row.ts" "const a = 'open\nlaunchCameraAsync();\n"
run_check "$dir" --platform ios
expect "an unclosed quote ends at its line" 1 '^FAIL permission-strings: .*needs "NSCameraUsageDescription"'

variant expo escaped-slash
put "$dir/Row.ts" 'p.replace(/\\/*$/, "");\nlaunchCameraAsync();\n/** docs */\n'
run_check "$dir" --platform ios
expect "an escaped slash and star opens no comment" 1 '^FAIL permission-strings: "Row.ts" uses an API that needs "NSCameraUsageDescription"'

# ---- .easignore ------------------------------------------------------------

variant expo ignore-native
apple_tree "$dir/ios"
android_tree "$dir/android"
ios_wins='^UNKNOWN bundle-id: no resolved Xcode settings'
ios_config='^PASS bundle-id: .* from ios.bundleIdentifier'
for form in ios ios/ /ios /ios/ 'ios/*' '/ios/*' 'ios/**' '/ios/**'; do
  put "$dir/.gitignore" "node_modules\n$form\n"
  run_check "$dir" --platform ios
  expect "the .gitignore form $form means the folder is ignored" 0 "$ios_config"
done
put "$dir/.gitignore" 'ios-old/\niosx\n# ios\n'
run_check "$dir" --platform ios
expect "other .gitignore lines do not ignore ios/" 0 "$ios_wins"
put "$dir/.gitignore" 'ios/\n'
put "$dir/.easignore" 'node_modules\n'
run_check "$dir" --platform ios
expect ".easignore replaces .gitignore: not ignored there, ios/ wins" 0 "$ios_wins"
rm "$dir/.gitignore"
put "$dir/.easignore" '/ios/*\n'
run_check "$dir" --platform ios
expect ".easignore alone can ignore ios/" 0 "$ios_config"
put "$dir/.easignore" '/android/*\n'
run_check "$dir" --platform android
expect ".easignore can ignore android/" 0 '^PASS package: .* from android.package'

# ---- Config plugins --------------------------------------------------------

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

# ---- Identifiers -----------------------------------------------------------

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

for ext in mjs cjs mts cts; do
  variant expo scan-ext
  put "$dir/extra.$ext" 'launchCameraAsync();\n'
  run_check "$dir" --platform ios
  expect "expo scans .$ext" 1 "^FAIL permission-strings: \"extra.$ext\" uses an API that needs \"NSCameraUsageDescription\""
done

# ---- Permission rows -------------------------------------------------------

variant xcode always-half
put "$dir/Runner/App.swift" 'func go(m: CLLocationManager) { m.requestAlwaysAuthorization() }\n'
sub "$dir/Runner/Info.plist" '<key>NSCameraUsageDescription</key><string>Todo scans a code to add an item.</string>' '<key>NSLocationAlwaysAndWhenInUseUsageDescription</key><string>Todo tracks a route.</string>'
native ios
expect "requestAlwaysAuthorization also needs the when-in-use key" 1 '^FAIL permission-strings: .*needs "NSLocationWhenInUseUsageDescription"' '!needs "NSLocationAlwaysAndWhenInUse'
sub "$dir/Runner/Info.plist" '<key>NSLocationAlwaysAndWhenInUseUsageDescription</key><string>Todo tracks a route.</string>' '<key>NSLocationWhenInUseUsageDescription</key><string>Todo tracks a route.</string>'
native ios
expect "requestAlwaysAuthorization also needs the always key" 1 '^FAIL permission-strings: .*needs "NSLocationAlwaysAndWhenInUseUsageDescription"' '!needs "NSLocationWhenInUse'

apple_row() {
  variant xcode apple-row
  put "$dir/Runner/App.swift" "$1\n"
  native ios
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
native ios
expect "dart LocalAuthentication needs the Face ID key" 1 '^FAIL permission-strings: "lib/auth.dart" uses an API that needs "NSFaceIDUsageDescription"'

variant flutter pick-video-far
sub "$dir/lib/main.dart" 'pickImage(source: ImageSource.camera)' 'pickImage(source: ImageSource.gallery)'
python3 -I -c 'import sys
open(sys.argv[1],"w").write("final v = ImagePicker().pickVideo(\n"+"  // note\n  x: 1,\n"*200+"  source: ImageSource.camera);\n")' "$dir/lib/v.dart"
native ios
expect "pickVideo with its camera source far away still needs the microphone" 1 '^FAIL permission-strings: .*needs "NSMicrophoneUsageDescription"'
variant flutter camera-no-video
native ios
expect "ImageSource.camera with no pickVideo needs no microphone" 0 '^PASS permission-strings: ' '!NSMicrophoneUsageDescription'

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
watched_native ios
expect "2 MB of pickVideo( in Dart" 0 '^PASS app-name: '

variant xcode slow-plist-var
pad "$dir/Runner/Info.plist" '<string>Todo scans a code to add an item.' '$('
watched_native ios
expect "2 MB of \$( in a plist string" 0 '^PASS app-name: ' '^UNKNOWN permission-strings: '

variant static slow-state-key
put "$dir/.app-creators/state.md" '---\nprovided\n---\n'
pad "$dir/.app-creators/state.md" 'provided' ' '
watched "$dir" --platform web --collects-data no
expect "2 MB of spaces after a state key" 0 '^PASS privacy-policy-url: '

variant static slow-state-value
put "$dir/.app-creators/state.md" '---\nprovided:\n  publish-readiness:\n    privacy_policy_url: "x\n---\n'
pad "$dir/.app-creators/state.md" 'privacy_policy_url: "x' '\\'
watched "$dir" --platform web --collects-data no
expect "2 MB of backslashes in an unclosed state quote" 0 '^UNKNOWN privacy-policy-url: '

variant static read-budget
python3 -I -c 'import sys
open(sys.argv[1],"w").write("<title>x</title>"+"<link rel=\"icon\" href=\"big.ico\">"*900)
open(sys.argv[2],"wb").write(bytes(2*1024*1024))' "$dir/index.html" "$dir/big.ico"
watched "$dir" --platform web
expect "past the per-run read limit, a check is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*per-run read limit' '!^PASS icon-sizes: '

variant static too-many-icons
python3 -I -c 'import sys
open(sys.argv[1],"w").write("<title>x</title>"+"".join("<link rel=\"icon\" href=\"m%d.png\">"%i for i in range(1001)))' "$dir/index.html"
watched "$dir" --platform web
expect "over the icon cap is UNKNOWN, not a FAIL for each" 0 '^UNKNOWN icon-sizes: the project declares 1001 icons'

variant xcode too-many-entries
python3 -I -c 'import json,sys
json.dump({"images":[{"filename":"m%d.png"%i,"idiom":"iphone","scale":"2x","size":"60x60"} for i in range(1001)]},open(sys.argv[1],"w"))' "$dir/$xset/Contents.json"
watched_native ios
expect "over the icon cap in Contents.json is UNKNOWN" 0 '^UNKNOWN icon-sizes: Contents.json lists 1001 icons'

png "$tmp/outside-icon.png" 1024 1024 2
for rel in outside-icon.png outside-missing.png; do
  variant expo oracle
  sub "$dir/app.json" './assets/icon.png' "../../$rel"
  run_check "$dir" --platform ios
  expect "expo icon $rel: outside reads the same either way" 0 '^UNKNOWN icon-sizes: .*outside the project' '^UNKNOWN icon-alpha: .*outside the project' '!(is|but) missing'
  variant static oracle
  sub "$dir/index.html" 'href="favicon.png"' "href=\"../../$rel\""
  run_check "$dir" --platform web
  expect "web icon $rel: outside reads the same either way" 0 '^UNKNOWN icon-sizes: .*outside the project' '!(is|but) missing'
  variant xcode oracle
  sub "$dir/$xset/Contents.json" 'Icon-60-2x.png' "../../../../../$rel"
  native ios
  expect "asset catalog icon $rel: outside reads the same either way" 0 '^UNKNOWN icon-sizes: .*outside the project' '!(is|but) missing'
  variant xcode oracle
  sub "$dir/$xset/Contents.json" 'Icon-1024.png' "../../../../../$rel"
  native ios
  expect "App Store icon $rel: outside reads the same either way" 0 '^UNKNOWN icon-alpha: .*outside the project' '!(is|but) missing'
done

variant static run-limit
guarded python3 -I -c 'import importlib.util,sys,time
s=importlib.util.spec_from_file_location("check",sys.argv[1])
m=importlib.util.module_from_spec(s)
s.loader.exec_module(m)
m.RUN_LIMIT_SECONDS=0.3
m.web_checks=lambda *a:[("done-check",lambda:"ok"),("slow-check",lambda:time.sleep(15) or "late")]
sys.exit(m.main([sys.argv[2],"--platform","web"]))' "$check" "$dir"
total=$((total + 1))
if [ "$code" = 2 ] && printf '%s\n' "$out" | grep -q '^PASS done-check' && ! printf '%s\n' "$out" | grep -q 'slow-check' && printf '%s\n' "$err" | grep -q 'run limit passed'; then pass=$((pass + 1)); else fail "the run limit exits 2 with no PASS for undone checks" "exit $code, out '$out', err '$err'"; fi

# ---- Next.js: only app/ data decides ------------------------------------------

variant nextjs next-app-manifest
put "$dir/app/manifest.json" '{"name":"From App"}\n'
put "$dir/public/manifest.json" '{"name":"Stale Public"}\n'
put "$dir/index.html" '<title>Stray Root</title>\n'
run_check "$dir" --platform web
expect "next: app/manifest.json decides over a stale public manifest and a stray index.html" 0 '^PASS app-name: "From App" from "app/manifest.json"' '!Stale Public' '!Stray Root'
rm "$dir/app/manifest.json"
run_check "$dir" --platform web
expect "next: a stale public manifest and a stray index.html are UNKNOWN" 0 '^UNKNOWN app-name: ' '!^PASS app-name: ' '!Stale Public' '!Stray Root'

variant nextjs next-public-ignored
rm "$dir/app/icon.png"
put "$dir/public/manifest.json" '{"name":"Stale","icons":[{"src":"/gone.png"}]}\n'
put "$dir/index.html" '<link rel="icon" href="/gone.png"><link rel="manifest" href="/manifest.json">\n'
run_check "$dir" --platform web
expect "next: icons in public manifests and a root index.html do not count" 0 '^UNKNOWN icon-sizes: .*a JS or TS config may set one' '^UNKNOWN app-name: ' '!gone.png'

variant nextjs next-webmanifest
put "$dir/app/manifest.webmanifest" '{"name":"Todo Web","icons":[{"src":"/missing.png"}]}\n'
run_check "$dir" --platform web
expect "next: app/manifest.webmanifest decides, and its icons count" 1 '^PASS app-name: "Todo Web" from "app/manifest.webmanifest"' '^FAIL icon-sizes: .*missing.png'

variant nextjs next-src-manifest
mkdir "$dir/src"
mv "$dir/app" "$dir/src/app"
put "$dir/src/app/manifest.json" '{"name":"Todo Src"}\n'
run_check "$dir" --platform web
expect "next: src/app/manifest.json decides" 0 '^PASS app-name: "Todo Src" from "src/app/manifest.json"'

for ext in ts js; do
  variant nextjs next-code-manifest
  put "$dir/app/manifest.json" '{"name":"Todo"}\n'
  put "$dir/app/manifest.$ext" 'export default function manifest() { return {}; }\n'
  run_check "$dir" --platform web
  expect "next: app/manifest.$ext is UNKNOWN for name and icons, whatever else exists" 0 "^UNKNOWN app-name: \"app/manifest.$ext\" generates" "^UNKNOWN icon-sizes: \"app/manifest.$ext\" generates" '!^(PASS|FAIL) (app-name|icon-sizes)'
done

# ---- Web: a manifest counts only when the HTML links it --------------------------

variant static unlinked-static
put "$dir/manifest.json" '{"name":"Unlinked","icons":[{"src":"gone.png"}]}\n'
run_check "$dir" --platform web
expect "static: an unlinked manifest does not count, name or icons" 0 '^PASS app-name: "Todo" from index.html' '^PASS icon-sizes: ' '!Unlinked' '!gone.png'
sub "$dir/index.html" '<title>Todo</title>' '<title></title>'
run_check "$dir" --platform web
expect "static: an empty title beside an unlinked manifest fails" 1 '^FAIL app-name: .*name is empty' '!Unlinked'

variant vite unlinked-vite
sub "$dir/index.html" '<link rel="manifest" href="/manifest.webmanifest">' ''
sub "$dir/index.html" '<title>Todo</title>' '<title></title>'
run_check "$dir" --platform web
expect "vite: an empty title beside an unlinked manifest is UNKNOWN" 0 '^UNKNOWN app-name: .*a JS or TS config may set it' '!^(PASS|FAIL) app-name: '

variant flutter unlinked-flutter
sub "$dir/web/index.html" '<link rel="manifest" href="manifest.json">' ''
sub "$dir/web/index.html" '<title>Todo</title>' ''
run_check "$dir" --platform web
expect "flutter web: an unlinked manifest does not name the app" 1 '^FAIL app-name: no name in a web manifest'

variant static linked-other-name
sub "$dir/index.html" '</title>' '</title><link rel="manifest" href="site.json">'
put "$dir/site.json" '{"name":"Linked"}\n'
run_check "$dir" --platform web
expect "a manifest of any file name counts when linked" 0 '^PASS app-name: "Linked" from "site.json"'

variant static public-index
mkdir -p "$dir/public"
put "$dir/public/index.html" '<title>Public</title>\n'
sub "$dir/index.html" '<title>Todo</title>' ''
run_check "$dir" --platform web
expect "public/index.html is not the HTML read" 1 '^FAIL app-name: no name' '!Public'

# ---- HeadReader: the head only ------------------------------------------------

head_is() {
  variant static head-case
  put "$dir/index.html" "$1"
  run_check "$dir" --platform web
}
head_is '<head></head><body><svg><title>Logo</title></svg></body>\n'
expect "a title in an svg in the body is not the name" 1 '^FAIL app-name: no name' '!Logo'
head_is '<head><svg><title>Logo</title></svg></head>\n'
expect "a title inside an svg in the head is not the name" 1 '^FAIL app-name: no name' '!Logo'
head_is '<head></head><title>Late</title>\n'
expect "a title after </head> is not the name" 1 '^FAIL app-name: no name' '!Late'
head_is '<body><title>Body</title></body>\n'
expect "a title after <body> is not the name" 1 '^FAIL app-name: no name' '!Body'
head_is '<head><title>First</title><title>Second</title></head>\n'
expect "the first title wins" 1 '^PASS app-name: "First" from index.html' '!Second'
head_is '<head><title>Todo</title></head><body><link rel="icon" href="favicon.png"></body>\n'
expect "a link in the body is not read" 1 '^FAIL icon-sizes: no icon declared'

variant static base-href
put "$dir/index.html" '<head><base href="/assets/"><title>Demo</title><link rel="icon" href="i.svg"></head>\n'
put "$dir/assets/i.svg" '<svg/>\n'
run_check "$dir" --platform web
expect "beside a <base>: a relative icon is UNKNOWN, and the title decides" 0 '^PASS app-name: "Demo" from index.html' '^UNKNOWN icon-sizes: "i.svg" is relative beside a <base>' '!^FAIL ' '!^PASS icon-sizes: '
put "$dir/site.json" '{"name":"Linked"}\n'
put "$dir/index.html" '<head><base href="/assets/"><link rel="manifest" href="site.json"><link rel="icon" sizes="32x32" href="/favicon.png"></head>\n'
run_check "$dir" --platform web
expect "beside a <base> with no title: app-name is UNKNOWN, and a relative manifest link too" 0 '^UNKNOWN app-name: index.html has a <base> and no <title>' '^UNKNOWN icon-sizes: "site.json" is relative beside a <base>' '!Linked' '!^(PASS|FAIL) (app-name|icon-sizes)'
put "$dir/index.html" '<head><base href="/assets/"><title>Demo</title><link rel="manifest" href="/site.json"><link rel="icon" sizes="32x32" href="/favicon.png"></head>\n'
run_check "$dir" --platform web
expect "beside a <base>: the title decides over a rooted manifest, and a rooted icon is read" 0 '^PASS app-name: "Demo" from index.html' '^PASS icon-sizes: ' '!Linked'
put "$dir/index.html" '<head><title>Demo</title><link rel="icon" sizes="32x32" href="favicon.png"></head><body><base href="/assets/"></body>\n'
run_check "$dir" --platform web
expect "a <base> after the head does not count" 0 '^PASS icon-sizes: '
variant flutter base-template
sub "$dir/web/index.html" '<title>Todo</title>' '<base href="$FLUTTER_BASE_HREF"><title>Template</title>'
run_check "$dir" --platform web
expect "flutter web template: <base> makes relative links UNKNOWN, and the title decides" 0 '^PASS app-name: "Template" from index.html' '^UNKNOWN icon-sizes: .*relative beside a <base>' '!^FAIL '

# ---- A declared web icon must be an image ---------------------------------------

variant static icon-not-image
sub "$dir/index.html" 'href="favicon.png"' 'href="icon.ts"'
put "$dir/icon.ts" 'export default 1;\n'
run_check "$dir" --platform web
expect "a declared icon that is not an image is UNKNOWN" 0 '^UNKNOWN icon-sizes: "icon.ts" does not have an image file extension' '!^PASS icon-sizes: '
for ext in ico svg jpg jpeg gif avif ICO; do
  variant static icon-ext
  sub "$dir/index.html" ' sizes="32x32" href="favicon.png"' " href=\"f.$ext\""
  put "$dir/f.$ext" 'x'
  run_check "$dir" --platform web
  expect "a declared .$ext icon counts" 0 '^PASS icon-sizes: '
  : >"$dir/f.$ext"
  run_check "$dir" --platform web
  expect "an empty .$ext icon is UNKNOWN" 0 "^UNKNOWN icon-sizes: \"f.$ext\" is empty" '!^PASS icon-sizes: '
done
variant static icon-upper-png
sub "$dir/index.html" 'href="favicon.png"' 'href="f.PNG"'
png "$dir/f.PNG" 16 16 6
run_check "$dir" --platform web
expect "an upper-case .PNG still has its size read" 1 '^FAIL icon-sizes: "f.PNG" is 16x16'

variant nextjs icon-odd-ext
rm "$dir/app/icon.png"
put "$dir/app/icon.txt" 'x'
run_check "$dir" --platform web
expect "next: app/icon with an unknown extension is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*image file extension' '!^PASS icon-sizes: '

variant expo favicon-not-image
put "$dir/assets/favicon.ts" 'x'
sub "$dir/app.json" './assets/favicon.png' './assets/favicon.ts'
run_check "$dir" --platform web
expect "expo: a web.favicon that is not an image is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*favicon.ts" does not have an image' '!^PASS icon-sizes: '
put "$dir/assets/favicon.ico" ''
sub "$dir/app.json" './assets/favicon.ts' './assets/favicon.ico'
run_check "$dir" --platform web
expect "expo: an empty web.favicon is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*favicon.ico" is empty' '!^PASS icon-sizes: '

# ---- Expo: config order, classification, name default, local plugins --------------

variant expo both-static
python3 -I -c 'import json,sys
d=json.load(open(sys.argv[1]))
d["expo"]["ios"]["bundleIdentifier"]="io.github.from.configjson"
json.dump(d,open(sys.argv[2],"w"))' "$dir/app.json" "$dir/app.config.json"
run_check "$dir" --platform ios
expect "app.config.json wins over app.json, as getStaticConfigFilePath orders them" 0 '^PASS bundle-id: "io.github.from.configjson"'

put "$tmp/empty-object.json" '{}\n'
two "--resolved {} is not an Expo config" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/empty-object.json"
put "$tmp/pkg-copy.json" '{"name":"todo","dependencies":{"expo":"~58.0.0"},"expo":"~58.0.0"}\n'
two "--resolved package.json copy is not an Expo config" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/pkg-copy.json"
put "$tmp/slug-number.json" '{"slug":5}\n'
two "--resolved with a non-string slug is not an Expo config" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/slug-number.json"
put "$tmp/expo-scalar.json" '{"expo":"x"}\n'
two "--resolved with a non-object expo is not an Expo config" 'is not Xcode settings' "$tmp/expo" --platform ios --resolved "$tmp/expo-scalar.json"

variant expo name-from-package
sub "$dir/app.json" '"name":"Todo",' ''
run_check "$dir" --platform ios
expect "no config name: package.json name, stating the source" 0 '^PASS app-name: "todo" from package.json name'
run_check "$dir" --platform web
expect "no config name on web: package.json name" 0 '^PASS app-name: "todo" from package.json name'
run_check "$dir" --platform android
expect "no config name on android: package.json name" 0 '^PASS app-name: "todo" from package.json name'
put "$dir/package.json" '{"dependencies":{"expo":"~58.0.0","react-dom":"19.0.0"}}\n'
run_check "$dir" --platform ios
expect "no name in either file is UNKNOWN: Expo then uses the folder name" 0 '^UNKNOWN app-name: no name in the Expo config or package.json' '!^(PASS|FAIL) app-name: '
sub "$dir/app.json" '"web":{' '"web":{"name":"Web Todo",'
run_check "$dir" --platform web
expect "a valid web.name stays PASS with no name in either file" 0 '^PASS app-name: "Web Todo" from the Expo config \(web.name\)'
put "$dir/package.json" '{"name":"","dependencies":{"expo":"~58.0.0","react-dom":"19.0.0"}}\n'
run_check "$dir" --platform ios
expect "an empty package.json name fails, as ?? keeps it" 1 '^FAIL app-name: the app name is empty in package.json name'
sub "$dir/app.json" '"plugins":[' '"plugins":["./plugins/x.js",'
run_check "$dir" --platform web
expect "web.name beside a local plugin is UNKNOWN" 0 '^UNKNOWN app-name: the local config plugin'
sub "$dir/app.json" '"plugins":["./plugins/x.js",' '"plugins":['
sub "$dir/app.json" '"web":{"name":"Web Todo",' '"web":{'
put "$dir/package.json" '{"name": '
run_check "$dir" --platform ios
expect "a malformed package.json is UNKNOWN for the fallback name" 0 '^UNKNOWN app-name: "package.json" is not valid JSON'
variant expo name-null
sub "$dir/app.json" '"name":"Todo"' '"name":null'
run_check "$dir" --platform ios
expect "a null config name falls back, as ?? does" 0 '^PASS app-name: "todo" from package.json name'
variant expo name-empty
sub "$dir/app.json" '"name":"Todo"' '"name":""'
run_check "$dir" --platform ios
expect "an empty config name does not fall back, as ?? does" 1 '^FAIL app-name: the app name is empty in the Expo config'

for plugin in '"./plugins/x.js"' '"/abs/plugin"' '["../shared/x",{"a":1}]'; do
  variant expo local-plugin-ids
  sub "$dir/app.json" '"plugins":[' "\"plugins\":[$plugin,"
  run_check "$dir" --platform ios
  expect "local plugin $plugin: name and bundle id are UNKNOWN" 0 '^UNKNOWN app-name: the local config plugin' '^UNKNOWN bundle-id: the local config plugin' '!^(PASS|FAIL) (app-name|bundle-id)'
  run_check "$dir" --platform android
  expect "local plugin $plugin: package is UNKNOWN" 0 '^UNKNOWN app-name: the local config plugin' '^UNKNOWN package: the local config plugin' '!^(PASS|FAIL) (app-name|package)'
  run_check "$dir" --platform web
  expect "local plugin $plugin: web name is UNKNOWN" 0 '^UNKNOWN app-name: the local config plugin'
done
variant expo packaged-plugin-ids
sub "$dir/app.json" '"plugins":[' '"plugins":["expo-some-other-module",'
run_check "$dir" --platform ios
expect "a packaged plugin keeps name and bundle id" 0 '^PASS app-name: ' '^PASS bundle-id: '

variant expo ignore-negated
apple_tree "$dir/ios"
android_tree "$dir/android"
put "$dir/.gitignore" 'ios/\n!ios/Podfile\n'
run_check "$dir" --platform ios
expect "a negated line naming ios/ is UNKNOWN on the whole route" 0 '^UNKNOWN app-name: \.gitignore has a negated' '^UNKNOWN bundle-id: .*negated' '^UNKNOWN permission-strings: .*negated' '!^(PASS|FAIL) (app-name|bundle-id|icon-sizes|icon-alpha|permission-strings)'
put "$dir/.gitignore" 'android/\n!/android/app\n'
run_check "$dir" --platform android
expect "a negated line naming android/ is UNKNOWN on the whole route" 0 '^UNKNOWN package: .*negated' '^UNKNOWN permissions-declared: .*negated' '!^(PASS|FAIL) (app-name|package|icon-sizes|permissions-declared)'
put "$dir/.gitignore" 'ios/\n!ios-old/\n!iosx\n'
run_check "$dir" --platform ios
expect "a negated line naming another folder does not count" 0 '^PASS bundle-id: .* from ios.bundleIdentifier'
rm "$dir/.gitignore"
put "$dir/.easignore" '!**/ios/\n'
run_check "$dir" --platform ios
expect ".easignore negation is UNKNOWN too" 0 '^UNKNOWN bundle-id: \.easignore has a negated'

# ---- Route detection --------------------------------------------------------

variant flutter quoted-sdk
sub "$dir/pubspec.yaml" 'sdk: flutter' 'sdk: "flutter"'
put "$dir/index.html" '<title>Landing</title>\n'
run_check "$dir" --platform web
expect "a quoted flutter sdk takes the Flutter route over a root landing page" 0 '^PASS app-name: "Todo" from "web/manifest.json"' '!Landing'
variant flutter unreadable-pubspec
printf '\377\376' >"$dir/pubspec.yaml"
run_check "$dir" --platform ios
expect "an unreadable pubspec.yaml takes the Flutter route" 0 '^UNKNOWN app-name: .*flutter build ios'

put "$tmp/swiftpm-only/Package.swift" '// swift-tools-version:5.9\n'
run_check "$tmp/swiftpm-only" --platform ios
expect "Package.swift alone is the Xcode route: UNKNOWN with the resolve command" 0 '^UNKNOWN app-name: no resolved Xcode settings' '^UNKNOWN bundle-id: no resolved Xcode settings' '!^(PASS|FAIL) (app-name|bundle-id)'
two "Package.swift has no Android route" 'xcode has no android route' "$tmp/swiftpm-only" --platform android
for at in build.gradle build.gradle.kts app/build.gradle app/build.gradle.kts; do
  rm -rf "$tmp/gradle-only"
  put "$tmp/gradle-only/$at" 'x\n'
  run_check "$tmp/gradle-only" --platform android
  expect "a Gradle file at $at with no manifest is the Kotlin route: UNKNOWN" 0 '^UNKNOWN app-name: .*is missing; a Gradle source set can relocate it' '^UNKNOWN package: the application id comes from Gradle' '!^(PASS|FAIL) (app-name|package|icon-sizes|permissions-declared)'
done
variant static static-over-fallback
put "$dir/Package.swift" 'x\n'
put "$dir/build.gradle" 'x\n'
run_check "$dir" --platform web
expect "the fallback sits at the unknown end: index.html stays static" 0 '^PASS app-name: "Todo"'

# ---- Android: a built manifest decides what it holds ------------------------------

variant kotlin built-permission-both-ways
sub "$dir/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' ''
built_permissions CAMERA
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a permission only the built manifest holds counts" 0 '^PASS permissions-declared: declared dangerous: "CAMERA"; needed by code: "CAMERA"'
variant kotlin built-permission-removed
built_permissions
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a permission only src/main holds does not count once a build dropped it" 1 '^FAIL permissions-declared: .*"CAMERA", which is not declared'

variant kotlin built-label
sub "$dir/$km/AndroidManifest.xml" '@string/app_name' 'From Source'
built_app io.github.test.todo '<application android:label="From Build" android:icon="@ref/0x1" />'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a literal built label decides" 0 '^PASS app-name: "From Build" from the built manifest' '!From Source'
built_app io.github.test.todo '<application android:label="" android:icon="@ref/0x1" />'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "an empty built label fails" 1 '^FAIL app-name: the app name is empty in the built manifest'
for ref in '@ref/0x7f100001' '@string/app_name'; do
  built_app io.github.test.todo "<application android:label=\"$ref\" android:icon=\"@ref/0x1\" />"
  run_check "$dir" --platform android --resolved "$tmp/built.xml"
  expect "a built label $ref falls back to src/main" 0 '^PASS app-name: "From Source" from android:label'
done
variant kotlin built-label-no-source
rm "$dir/$km/AndroidManifest.xml"
built_app io.github.test.todo '<application android:label="From Build" android:icon="@ref/0x1" />'
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a built manifest decides with no src/main manifest" 0 '^PASS app-name: "From Build"' '^PASS permissions-declared: ' '^UNKNOWN icon-sizes: .*missing'
built io.github.test.todo

variant kotlin no-built-api
sub "$dir/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' ''
run_check "$dir" --platform android
expect "kotlin, no built manifest: an API whose permission is absent is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*"CAMERA", and no built manifest shows it, and a library can supply it' '!^FAIL permissions-declared: '
variant flutter no-built-api
put "$dir/android/$km/kotlin/M.kt" 'val p = Manifest.permission.READ_CONTACTS\n'
run_check "$dir" --platform android
expect "flutter, no built manifest: an API whose permission is absent is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*"READ_CONTACTS", and no built manifest shows it' '!^FAIL permissions-declared: '
variant expo native-auto-permission
android_tree "$dir/android"
sub "$dir/android/$km/AndroidManifest.xml" '<uses-permission android:name="android.permission.CAMERA" />' ''
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
run_check "$dir" --platform android
expect "expo with android/, no built manifest: an absent permission is UNKNOWN" 0 '^UNKNOWN permissions-declared: .*"CAMERA", and no built manifest shows it'
built_permissions
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "expo with android/, built manifest without it: FAIL" 1 '^FAIL permissions-declared: .*"CAMERA", which is not declared'
built io.github.test.todo
variant expo config-auto-permission
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
sub "$dir/app.json" '"expo-image-picker",{' '"expo-image-picker",{"cameraPermission":"Scan a code.",'
run_check "$dir" --platform android
expect "the Expo config route keeps its how rules: auto needs no declaration" 0 '^PASS permissions-declared: .*needed by code: "CAMERA"'

variant kotlin no-built-attrs
sub "$dir/$km/AndroidManifest.xml" ' android:label="@string/app_name"' ''
sub "$dir/$km/AndroidManifest.xml" ' android:icon="@mipmap/ic_launcher"' ''
run_check "$dir" --platform android
expect "no built manifest: a missing label or icon is UNKNOWN" 0 '^UNKNOWN app-name: android:label is missing from src/main' '^UNKNOWN icon-sizes: android:icon is missing from src/main' '!^FAIL '
built io.github.test.todo
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a built manifest holding them: a missing source attribute stays UNKNOWN" 0 '^UNKNOWN app-name: android:label is missing from src/main' '^UNKNOWN icon-sizes: android:icon is missing from src/main' '!^FAIL '
variant kotlin no-application
put "$dir/$km/AndroidManifest.xml" '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.CAMERA" /></manifest>\n'
run_check "$dir" --platform android
expect "no built manifest: no <application> is UNKNOWN" 0 '^UNKNOWN app-name: ' '^UNKNOWN icon-sizes: ' '!^FAIL '
built_app io.github.test.todo ''
run_check "$dir" --platform android --resolved "$tmp/built.xml"
expect "a built manifest with no <application> confirms it: FAIL" 1 '^FAIL app-name: android:label is missing .* in the built manifest' '^FAIL icon-sizes: android:icon is missing .* in the built manifest'
built io.github.test.todo
variant kotlin bad-label-no-built
sub "$dir/$km/AndroidManifest.xml" '@string/app_name' ' '
run_check "$dir" --platform android
expect "no built manifest: a present but empty label still fails" 1 '^FAIL app-name: the app name is empty'
variant kotlin bad-icon-no-built
rm -rf "$dir/$km/res/mipmap-"*
run_check "$dir" --platform android
expect "no built manifest: a present icon with no file still fails" 1 '^FAIL icon-sizes: "@mipmap/ic_launcher" has no file'

put "$tmp/no-package.xml" '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><application android:label="Todo"/></manifest>\n'
two "--resolved manifest with no package is not a built manifest" 'is not a built manifest' "$tmp/kotlin" --platform android --resolved "$tmp/no-package.xml"
put "$tmp/empty-package.xml" '<manifest package=""><application/></manifest>\n'
two "--resolved manifest with an empty package is not a built manifest" 'is not a built manifest' "$tmp/kotlin" --platform android --resolved "$tmp/empty-package.xml"

adaptive='<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">'
android_icon_is "$adaptive<foreground android:drawable=\"#ffffff\" /></adaptive-icon>\n"
expect "an adaptive icon with no background is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*has no <background>' '!^(PASS|FAIL) icon-sizes: '
android_icon_is "$adaptive<background android:drawable=\"@color/white\" /></adaptive-icon>\n"
expect "an adaptive icon with no foreground is UNKNOWN" 0 '^UNKNOWN icon-sizes: .*has no <foreground>' '!^(PASS|FAIL) icon-sizes: '
android_icon_is "$adaptive<background android:drawable=\"@color/white\" /><foreground android:drawable=\"#ffffff\" /></adaptive-icon>\n"
expect "a colour foreground is UNKNOWN" 0 '^UNKNOWN icon-sizes: icon reference "#ffffff" is not a @mipmap or @drawable file' '!^PASS icon-sizes: '
android_icon_is "$adaptive<background android:drawable=\"@color/white\" /><foreground android:drawable=\"@color/white\" /></adaptive-icon>\n"
expect "a colour reference foreground is UNKNOWN" 0 '^UNKNOWN icon-sizes: icon reference "@color/white"' '!^PASS icon-sizes: '
android_icon_is "$adaptive<background android:drawable=\"#ffffff\" /><foreground android:drawable=\"@mipmap/ic_launcher_fg\" /></adaptive-icon>\n"
webp "$dir/$km/res/mipmap-mdpi/ic_launcher_fg.webp" VP8L 108 108
native android
expect "a colour background stays allowed" 0 '^PASS icon-sizes: '

# ---- Apple values --------------------------------------------------------------

variant xcode dollar-name
sub "$dir/Runner/Info.plist" '<key>CFBundleDisplayName</key><string>Todo</string>' '<key>CFBundleDisplayName</key><string>$PRODUCT_NAME</string>'
sub "$dir/Runner/Info.plist" 'Todo scans a code to add an item.' 'Costs $PRICE'
native ios
expect "a dollar left after expansion is UNKNOWN" 0 '^UNKNOWN app-name: "\$PRODUCT_NAME" does not resolve' '^UNKNOWN permission-strings: "NSCameraUsageDescription" holds a build variable' '!^(PASS|FAIL) (app-name|permission-strings)'

for name in ../AppIcon Sub/AppIcon; do
  variant xcode icon-name-path
  resolve "$dir" "ASSETCATALOG_COMPILER_APPICON_NAME=$name"
  run_check "$dir" --platform ios --resolved "$tmp/xc.json"
  expect "an icon set name $name is UNKNOWN, not FAIL" 0 '^UNKNOWN icon-sizes: ASSETCATALOG_COMPILER_APPICON_NAME .* is not a plain' '^UNKNOWN icon-alpha: ' '!^(PASS|FAIL) (icon-sizes|icon-alpha)'
done

variant xcode iconset-outside-catalog
mv "$dir/$xset" "$dir/Runner/AppIcon.appiconset"
native ios
expect "an .appiconset outside a .xcassets folder does not count" 1 '^FAIL icon-sizes: no "AppIcon.appiconset"'
variant xcode iconset-decoy
mkdir -p "$dir/Docs"
cp -R "$dir/$xset" "$dir/Docs/AppIcon.appiconset"
native ios
expect "a decoy .appiconset outside the catalog is not a second set" 0 '^PASS icon-sizes: '
variant xcode iconset-group
mkdir -p "$dir/Runner/Assets.xcassets/Icons"
mv "$dir/$xset" "$dir/Runner/Assets.xcassets/Icons/AppIcon.appiconset"
native ios
expect "an .appiconset in a catalog group counts" 0 '^PASS icon-sizes: '

# ---- Permission scan -----------------------------------------------------------

variant expo not-utf8
printf 'launchCameraAsync();\n// \377\n' >"$dir/Row.ts"
run_check "$dir" --platform ios
expect "a source file that is not UTF-8 goes to skipped" 0 '^UNKNOWN permission-strings: "Row.ts" is not UTF-8 text' '!^(PASS|FAIL) permission-strings: '
sub "$dir/App.tsx" 'launchImageLibraryAsync' 'launchCameraAsync'
run_check "$dir" --platform ios
expect "a gap elsewhere still FAILs beside a file that is not UTF-8" 1 '^FAIL permission-strings: "App.tsx" uses'
variant expo nul-byte
printf 'launchCameraAsync();\000\n' >"$dir/Row.ts"
run_check "$dir" --platform ios
expect "a source file with a NUL byte goes to skipped" 0 '^UNKNOWN permission-strings: "Row.ts" holds a NUL byte' '!^(PASS|FAIL) permission-strings: '

variant expo nested-build
put "$dir/src/build/Cam.tsx" 'launchCameraAsync();\n'
put "$dir/src/dist/Mic.tsx" 'useMicrophonePermissions();\n'
run_check "$dir" --platform ios
expect "src/build and src/dist are scanned" 1 '^FAIL permission-strings: .*"src/build/Cam.tsx" uses.*"src/dist/Mic.tsx" uses'
variant expo root-output
put "$dir/build/Cam.tsx" 'launchCameraAsync();\n'
put "$dir/dist/Cam.tsx" 'launchCameraAsync();\n'
run_check "$dir" --platform ios
expect "build and dist at the scan root are skipped" 0 '^PASS permission-strings: '
variant expo gradle-output
put "$dir/lib/mod/build.gradle" 'x\n'
put "$dir/lib/mod/build/Cam.tsx" 'launchCameraAsync();\n'
run_check "$dir" --platform ios
expect "build beside a Gradle file is skipped" 0 '^PASS permission-strings: '
variant expo gradle-kts-output
put "$dir/lib/mod/build.gradle.kts" 'x\n'
put "$dir/lib/mod/build/Cam.tsx" 'launchCameraAsync();\n'
put "$dir/lib/mod/dist/Mic.tsx" 'useMicrophonePermissions();\n'
run_check "$dir" --platform ios
expect "only build is skipped beside a Gradle file, not dist" 1 '^FAIL permission-strings: "lib/mod/dist/Mic.tsx" uses' '!Cam.tsx'
variant expo deep-node-modules
put "$dir/packages/x/node_modules/y/Cam.tsx" 'launchCameraAsync();\n'
run_check "$dir" --platform ios
expect "other skip folders keep any depth" 0 '^PASS permission-strings: '
variant expo link-to-src-build
put "$dir/src/build/Cam.ts" 'launchPhotos();\n'
ln -s src/build "$dir/linked"
run_check "$dir" --platform ios
expect "a link to a scanned src/build folder stays silent" 0 '^PASS permission-strings: ' '!linked'
variant expo link-to-root-build
put "$dir/build/Cam.ts" 'launchPhotos();\n'
ln -s build "$dir/linked"
run_check "$dir" --platform ios
expect "a link to the root build folder is UNKNOWN" 0 '^UNKNOWN permission-strings: "linked" points at a folder that is not scanned'

# ---- Surviving mutants -----------------------------------------------------------

two "an abbreviated flag is refused" 'unrecognized arguments' "$tmp/expo" --platform ios --resol "$tmp/x.json"

variant expo bg-location
put "$dir/Row.ts" 'requestBackgroundPermissionsAsync();\n'
sub "$dir/app.json" '"plugins":[' '"plugins":[["expo-location",{"isAndroidBackgroundLocationEnabled":true}],'
run_check "$dir" --platform android
expect "isAndroidBackgroundLocationEnabled declares the background permission" 0 '^PASS permissions-declared: declared dangerous: "ACCESS_BACKGROUND_LOCATION"'
sub "$dir/app.json" '"isAndroidBackgroundLocationEnabled":true' '"isAndroidBackgroundLocationEnabled":false'
run_check "$dir" --platform android
expect "isAndroidBackgroundLocationEnabled false does not declare it" 1 '^FAIL permissions-declared: .*"ACCESS_BACKGROUND_LOCATION", which is not declared'

variant xcode srcroot-link-out
ln -s "$tmp/expo" "$dir/away"
resolve "$dir/away"
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "a symlinked SRCROOT that leaves the project is UNKNOWN" 0 '^UNKNOWN app-name: SRCROOT in the resolved Xcode settings is not inside' '!^(PASS|FAIL) (app-name|bundle-id)'
variant xcode srcroot-link-in
ln -s "$dir" "$tmp/v/srcroot-link"
resolve "$tmp/v/srcroot-link"
run_check "$dir" --platform ios --resolved "$tmp/xc.json"
expect "a symlinked SRCROOT that resolves into the project is read" 0 '^PASS bundle-id: ' '^PASS icon-sizes: '
rm "$tmp/v/srcroot-link"

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
