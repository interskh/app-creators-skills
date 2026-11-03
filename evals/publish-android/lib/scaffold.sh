# Sourced by each case's scaffold.sh. Runs in the eval workspace.
lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

package=io.github.interskh.todo
build_id=00000000-0000-4000-8000-000000000007
fake_sha=0000000000000000000000000000000000000000000000000000000000000007
fingerprint=00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:07
expo_pin=ff71355
flutter_pin=de83d0f
kotlin_pin=a4c56a0

# Names the state and readiness seeds: state-$route.md, readiness-$route.md.
route=expo

fixtures_repo() {
  local repo="$lib_dir/../../../../app-creators-fixtures" common
  if [ ! -e "$repo/.git" ]; then
    common="$(cd "$lib_dir" && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -n "$common" ]; then
      repo="$(dirname "$common")/../app-creators-fixtures"
    fi
  fi
  if [ ! -e "$repo/.git" ]; then
    echo "scaffold: app-creators-fixtures not found; clone it next to the plugin repo" >&2
    exit 1
  fi
  printf '%s\n' "$repo"
}

extract_fixture() {
  local dir="$1" pin="$2" repo
  repo="$(fixtures_repo)"
  if ! (cd "$repo" && git cat-file -e "$pin^{commit}" 2>/dev/null); then
    echo "scaffold: commit $pin is not in app-creators-fixtures; run git fetch there" >&2
    exit 1
  fi
  (cd "$repo" && git archive --format=tar "$pin" "$dir") | tar -xf - --strip-components=1
}

# $1 expo, flutter, or kotlin. Extracts that route's fixture at its pin.
extract_route() {
  route="$1"
  case "$route" in
    expo) extract_fixture todo-expo "$expo_pin" ;;
    flutter) extract_fixture todo-flutter "$flutter_pin" ;;
    kotlin) extract_fixture todo-kotlin "$kotlin_pin" ;;
    *) echo "scaffold: no route named $route" >&2; exit 1 ;;
  esac
}

commit_all() {
  [ -d .git ] || git init -q
  git add -A
  git -c user.name=fixture -c user.email=fixture -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "$1"
}

# The project edits of Step 4 in references/expo.md, with a fake project id. $1 the version name.
apply_expo_edits() {
  python3 -I -c '
import json, sys
with open("app.json") as f:
    config = json.load(f)
expo = config["expo"]
expo["version"] = sys.argv[1]
expo["extra"] = {"eas": {"projectId": "00000000-0000-4000-8000-000000000001"}}
with open("app.json", "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
eas = {
    "cli": {"appVersionSource": "remote"},
    "build": {"production": {"autoIncrement": True}},
    "submit": {"production": {"android": {"track": "internal", "releaseStatus": "draft", "changesNotSentForReview": True}}},
}
with open("eas.json", "w") as f:
    json.dump(eas, f, indent=2)
    f.write("\n")
with open(".gitignore", encoding="utf-8") as f:
    lines = f.read().splitlines()
missing = [p for p in ("credentials.json", "*.jks", "*.keystore") if p not in lines]
if missing:
    with open(".gitignore", "a", encoding="utf-8") as f:
        f.write("\n# Step 4: secret files\n" + "".join(p + "\n" for p in missing))
' "$1"
}

# The release signing config of Step 4 in references/flutter.md and references/gradle.md. $1 the Gradle file, $2 the properties file.
apply_signing_config() {
  python3 -I -c '
import sys
path, props = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    text = f.read()
def once(old, new):
    global text
    if text.count(old) != 1:
        sys.exit("scaffold: %s holds %r %d times, not 1" % (path, old, text.count(old)))
    text = text.replace(old, new)
once("plugins {\n", "import java.io.FileInputStream\nimport java.util.Properties\n\nplugins {\n")
once("\nandroid {\n", "\nval keystoreProps = Properties()\nval keystorePropertiesFile = rootProject.file(\"" + props + "\")\nif (keystorePropertiesFile.exists()) {\n    keystoreProps.load(FileInputStream(keystorePropertiesFile))\n}\n\nandroid {\n")
once("    buildTypes {\n", "    signingConfigs {\n        create(\"release\") {\n            keyAlias = keystoreProps.getProperty(\"keyAlias\")\n            keyPassword = keystoreProps.getProperty(\"keyPassword\")\n            storeFile = keystoreProps.getProperty(\"storeFile\")?.let { file(it) }\n            storePassword = keystoreProps.getProperty(\"storePassword\")\n        }\n    }\n    buildTypes {\n")
if "signingConfigs.getByName(\"debug\")" in text:
    once("signingConfig = signingConfigs.getByName(\"debug\")", "signingConfig = signingConfigs.getByName(\"release\")")
else:
    once("        release {\n", "        release {\n            signingConfig = signingConfigs.getByName(\"release\")\n")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
' "$1" "$2"
}

# Step 4 in references/flutter.md: the version code in pubspec.yaml and the signing config.
apply_flutter_edits() {
  python3 -I -c '
with open("pubspec.yaml", encoding="utf-8") as f:
    text = f.read()
assert text.count("version: 1.0.0+1\n") == 1, "scaffold: pubspec.yaml has no version: 1.0.0+1"
with open("pubspec.yaml", "w", encoding="utf-8") as f:
    f.write(text.replace("version: 1.0.0+1\n", "version: 1.0.0+7\n"))
'
  apply_signing_config android/app/build.gradle.kts key.properties
}

# Step 4 in references/gradle.md: version literals, the signing config, and the ignore lines. $1 the targetSdk to commit.
apply_kotlin_edits() {
  python3 -I -c '
import sys
path = "app/build.gradle.kts"
with open(path, encoding="utf-8") as f:
    text = f.read()
for old, new in (
    ("        targetSdk = 37\n", "        targetSdk = " + sys.argv[1] + "\n"),
    ("        versionCode = 1\n", "        versionCode = 7\n"),
    ("        versionName = \"1.0\"\n", "        versionName = \"1.0.0\"\n"),
):
    if text.count(old) != 1:
        sys.exit("scaffold: %s holds %r %d times, not 1" % (path, old, text.count(old)))
    text = text.replace(old, new)
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
with open(".gitignore", "a", encoding="utf-8") as f:
    f.write("keystore.properties\n*.jks\n*.keystore\n")
' "$1"
  apply_signing_config app/build.gradle.kts keystore.properties
}

# $1 revision, $2 status, $3 package, $4 Google Play account, $5 readiness result.
write_state() {
  mkdir -p .app-creators
  sed "s|__REV__|$1|g;s|__STATUS__|$2|g;s|__PACKAGE__|$3|g;s|__PLAY__|$4|g;s|__RESULT__|$5|g" "$lib_dir/state-$route.md" > .app-creators/state.md
}

append_history() {
  python3 -I -c '
import sys
with open(".app-creators/state.md", encoding="utf-8") as f:
    lines = f.readlines()
end = next(i for i, line in enumerate(lines) if i > 0 and line.rstrip("\n") == "---")
lines.insert(end, "  - " + sys.argv[1] + "\n")
with open(".app-creators/state.md", "w", encoding="utf-8") as f:
    f.writelines(lines)
' "$1"
}

# $1 a notes file in lib, then pairs of placeholder and value. Appends it to the notes in state.md.
append_notes() {
  python3 -I -c '
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    text = f.read()
pairs = sys.argv[2:]
for key, value in zip(pairs[::2], pairs[1::2]):
    text = text.replace(key, value)
if "__" in text:
    sys.exit("scaffold: a placeholder is left in " + sys.argv[1])
with open(".app-creators/state.md", "a", encoding="utf-8") as f:
    f.write(text)
' "$lib_dir/$1" "${@:2}"
}

# $1 revision, $2 result, $3 inventory check, $4 its evidence, $5 confirmed, $6 items.
write_readiness() {
  sed "s|__REV__|$1|g;s|__RESULT__|$2|g;s|__INV_CHECK__|$3|g;s|__INV_EVIDENCE__|$4|g;s|__CONFIRMED__|$5|g;s|__ITEMS__|$6|g" "$lib_dir/readiness-$route.md" > .app-creators/readiness.md
}

# $1 revision. The photo stays on the device, so the confirmed inventory has no items.
write_readiness_confirmed() {
  write_readiness "$1" pass pass "confirmed by the creator" true "[]"
}

# $1 revision. The inventory is confirmed, and one check could not run, so the result is unknown.
write_readiness_confirmed_unknown() {
  write_readiness "$1" unknown pass "confirmed by the creator" true "[]"
  python3 -I -c '
with open(".app-creators/readiness.md", encoding="utf-8") as f:
    lines = f.readlines()
rows = [i for i, line in enumerate(lines) if line.startswith("      - { id: icon-sizes, result: pass,")]
assert len(rows) == 1, "scaffold: no icon-sizes row"
lines[rows[0]] = "      - { id: icon-sizes, result: unknown, evidence: \"no PNG reader ran on ./assets/android-icon-foreground.png\", fix: \"\" }\n"
with open(".app-creators/readiness.md", "w", encoding="utf-8") as f:
    f.writelines(lines + ["\nandroid is unknown: icon-sizes could not run.\n"])
'
}

# $1 revision. publish-readiness writes unknown while the inventory is not confirmed.
write_readiness_unconfirmed() {
  local item='{ data_type: "photos", platforms: [android], evidence: "expo-image-picker in package.json", purpose: "", linked_to_user: unknown, used_for_tracking: unknown, shared_with: [], optional: unknown }'
  write_readiness "$1" unknown unknown "the creator has not confirmed the inventory" false "[$item]"
  printf '\nNot confirmed yet: photos.\n' >> .app-creators/readiness.md
}

# $1 revision. The listing, one opaque PNG per screenshot row at the size the row records, and its history row.
write_listing() {
  sed "s|__REV__|$1|g" "$lib_dir/listing.md" > .app-creators/listing.md
  python3 -I -c '
import os, struct, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
for device, name, w, h in (("phone", "1.png", 1080, 1920), ("phone", "2.png", 1080, 1920), ("feature_graphic", "1.png", 1024, 500)):
    d = os.path.join(".app-creators", "screenshots", "google_play", device)
    os.makedirs(d, exist_ok=True)
    row = b"\x00" + b"\xf4\xf6\xf8" * w
    with open(os.path.join(d, name), "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(row * h)))
        f.write(chunk(b"IEND", b""))
'
  append_history '{ skill: store-listing, version: "0.2.0", date: 2026-11-03, result: pass }'
}

# $1 a path. Writes a placeholder file there, which is not a bundle, and prints its sha256.
write_placeholder_bundle() {
  mkdir -p "$(dirname "$1")"
  printf 'eval placeholder: not an Android App Bundle\n' > "$1"
  python3 -I -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
}

# $1 route. Rev A is the app as the fixture has it; rev B adds .app-creators/ with no answer on the Google Play account.
scaffold_first_run() {
  local rev
  extract_route "$1"
  commit_all "app"
  rev="$(git rev-parse HEAD)"
  write_state "$rev" unknown "" "" pass
  write_readiness_confirmed "$rev"
  write_listing "$rev"
  commit_all "record readiness and listing"
}

# $1 status, $2 readiness result, $3 version name. Sets seed_rev and seed_sha. Rev A is todo-expo with the Step 4 edits.
seed_expo_past_build() {
  extract_route expo
  apply_expo_edits "$3"
  commit_all "app with the Step 4 edits"
  seed_rev="$(git rev-parse HEAD)"
  write_state "$seed_rev" "$1" "$package" has "$2"
  append_notes notes-expo-past-build.md __BUILD__ "$build_id" __REV__ "$seed_rev" __SHA__ "$fake_sha"
}

# $1 route, $2 the targetSdk to commit on Kotlin, $3 kotlin readings or none. Rev A is the app with the Step 4 edits; rev B adds .app-creators/ and a finished build whose bundle sits in ignored build output.
seed_native_past_build() {
  local bundle sha readings=""
  extract_route "$1"
  case "$route" in
    flutter) apply_flutter_edits; bundle=build/app/outputs/bundle/release/app-release.aab ;;
    kotlin) apply_kotlin_edits "$2"; bundle=app/build/outputs/bundle/release/app-release.aab ;;
  esac
  commit_all "app with the Step 4 edits"
  seed_rev="$(git rev-parse HEAD)"
  sha="$(write_placeholder_bundle "$bundle")"
  write_state "$seed_rev" ready "$package" has pass
  if [ "$route" = kotlin ] && [ "$3" = readings ]; then
    readings="; package $package, version name 1.0.0, version code 7, signer SHA-256 $fingerprint
Target API: $2 read from $bundle at commit $seed_rev, requires 36"
  fi
  append_notes "notes-$route-past-build.md" __REV__ "$seed_rev" __SHA__ "$sha" __FINGERPRINT__ "$fingerprint" __READINGS__ "$readings"
  write_readiness_confirmed "$seed_rev"
  write_listing "$seed_rev"
  append_history '{ skill: publish-android, version: "0.1.0", date: 2026-11-03, result: "stopped: Step 10" }'
  commit_all "record readiness, listing, and the build"
}

scaffold_expo_upload_check() {
  seed_expo_past_build ready pass 1.0.0
  write_readiness_confirmed "$seed_rev"
  write_listing "$seed_rev"
  append_history '{ skill: publish-android, version: "0.1.0", date: 2026-11-03, result: "stopped: Step 10" }'
  commit_all "record readiness, listing, and the build"
}

# Past the upload: the draft on internal testing is recorded.
record_upload() {
  append_notes notes-expo-past-upload.md __REV__ "$seed_rev" __BUILD__ "$build_id"
  append_history "{ skill: publish-android, version: \"0.1.0\", date: 2026-11-03, result: \"Draft: google_play $package 1.0.0 (7) internal\" }"
}

scaffold_expo_no_listing() {
  seed_expo_past_build ready pass 1.0.0
  write_readiness_confirmed "$seed_rev"
  record_upload
  commit_all "record readiness, the build, and the upload"
}

scaffold_expo_unconfirmed_inventory() {
  seed_expo_past_build ready unknown 1.0.0
  write_readiness_unconfirmed "$seed_rev"
  write_listing "$seed_rev"
  record_upload
  commit_all "record readiness, listing, the build, and the upload"
}

# Readiness unknown, a listing with an empty revision, the sections saved, and a standing yes in the notes.
scaffold_expo_review_goahead() {
  seed_expo_past_build ready unknown 1.0.0
  write_readiness_confirmed_unknown "$seed_rev"
  write_listing ""
  record_upload
  append_notes notes-expo-filled.md
  commit_all "record readiness, listing, the build, the upload, and the filled sections"
}

# Live: 1.0.0 (7) published at rev A1; 1.0.1 (8) built at rev A2 and published at a 20% rollout; a standing yes to raise it.
scaffold_expo_rollout_goahead() {
  local rev1
  extract_route expo
  apply_expo_edits 1.0.0
  commit_all "app with the Step 4 edits"
  rev1="$(git rev-parse HEAD)"
  apply_expo_edits 1.0.1
  commit_all "1.0.1"
  seed_rev="$(git rev-parse HEAD)"
  write_state "$seed_rev" live "$package" has pass
  append_notes notes-expo-live.md __REV1__ "$rev1" __REV__ "$seed_rev" __SHA__ "$fake_sha"
  write_readiness_confirmed "$seed_rev"
  write_listing "$seed_rev"
  append_history "{ skill: publish-android, version: \"0.1.0\", date: 2026-11-03, result: \"Published: google_play $package 1.0.0 (7) production\" }"
  append_history "{ skill: publish-android, version: \"0.1.0\", date: 2026-11-03, result: \"Published: google_play $package 1.0.1 (8) production\" }"
  commit_all "record readiness, listing, both builds, and the 20% rollout"
}
