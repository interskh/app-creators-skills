# Sourced by each case's scaffold.sh. Runs in the eval workspace.
lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

asc_app_id=1234567890
bundle_id=io.github.interskh.todo
build_id=00000000-0000-4000-8000-000000000007

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

commit_all() {
  [ -d .git ] || git init -q
  git add -A
  git -c user.name=fixture -c user.email=fixture -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "$1"
}

# The project edits of Step 4 in references/expo.md, with fake ids.
apply_step4_edits() {
  python3 -I -c '
import json, sys
with open("app.json") as f:
    config = json.load(f)
expo = config["expo"]
expo["extra"] = {"eas": {"projectId": "00000000-0000-4000-8000-000000000001"}}
expo["ios"]["config"] = {"usesNonExemptEncryption": False}
with open("app.json", "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
eas = {
    "cli": {"appVersionSource": "remote"},
    "build": {"production": {"autoIncrement": True}},
    "submit": {"production": {"ios": {"ascAppId": sys.argv[1]}}},
}
with open("eas.json", "w") as f:
    json.dump(eas, f, indent=2)
    f.write("\n")
' "$asc_app_id"
}

# $1 revision, $2 status, $3 bundle id, $4 app id, $5 Apple account, $6 readiness result.
write_state() {
  mkdir -p .app-creators
  sed "s|__REV__|$1|g;s|__STATUS__|$2|g;s|__BUNDLE__|$3|g;s|__ASC__|$4|g;s|__APPLE__|$5|g;s|__RESULT__|$6|g" "$lib_dir/state-expo.md" > .app-creators/state.md
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

# $1 revision. The photo stays on the device, so the confirmed inventory has no items.
write_readiness_confirmed() {
  sed "s|__REV__|$1|g;s|__RESULT__|pass|g;s|__INV_CHECK__|pass|g;s|__INV_EVIDENCE__|confirmed by the creator|g;s|__CONFIRMED__|true|g;s|__ITEMS__|[]|g" "$lib_dir/readiness-expo.md" > .app-creators/readiness.md
}

# $1 revision. The inventory is confirmed, and one check could not run, so the result is unknown.
write_readiness_confirmed_unknown() {
  sed "s|__REV__|$1|g;s|__RESULT__|unknown|g;s|__INV_CHECK__|pass|g;s|__INV_EVIDENCE__|confirmed by the creator|g;s|__CONFIRMED__|true|g;s|__ITEMS__|[]|g" "$lib_dir/readiness-expo.md" | sed 's|{ id: icon-alpha, result: pass, evidence: "[^"]*", fix: "" }|{ id: icon-alpha, result: unknown, evidence: "no PNG reader ran on ./assets/icon.png", fix: "" }|' > .app-creators/readiness.md
}

# $1 revision. publish-readiness writes unknown while the inventory is not confirmed.
write_readiness_unconfirmed() {
  local item='{ data_type: "photos", platforms: [ios], evidence: "expo-image-picker in package.json", purpose: "", linked_to_user: unknown, used_for_tracking: unknown, shared_with: [], optional: unknown }'
  sed "s|__REV__|$1|g;s|__RESULT__|unknown|g;s|__INV_CHECK__|unknown|g;s|__INV_EVIDENCE__|the creator has not confirmed the inventory|g;s|__CONFIRMED__|false|g;s|__ITEMS__|[$item]|g" "$lib_dir/readiness-expo.md" > .app-creators/readiness.md
  printf '\nNot confirmed yet: photos.\n' >> .app-creators/readiness.md
}

# $1 revision. The listing, one opaque PNG per screenshot row at the size the row records, and its history row.
write_listing() {
  sed "s|__REV__|$1|g" "$lib_dir/listing-expo.md" > .app-creators/listing.md
  python3 -I -c '
import os, struct, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
for device, w, h in (("iphone_dynamic_island_medium", 1206, 2622), ("ipad_13in", 2064, 2752)):
    d = os.path.join(".app-creators", "screenshots", "app_store", device)
    os.makedirs(d, exist_ok=True)
    row = b"\x00" + b"\xf4\xf6\xf8" * w
    with open(os.path.join(d, "1.png"), "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(row * h)))
        f.write(chunk(b"IEND", b""))
'
  append_history '{ skill: store-listing, version: "0.2.0", date: 2026-11-03, result: pass }'
}

# $1 status, $2 readiness result. Sets seed_rev. Rev A is the app with the Step 4 edits; the case commits rev B, so only .app-creators/ differs.
seed_past_build() {
  extract_fixture todo-expo ff71355
  apply_step4_edits
  commit_all "app with the Step 4 edits"
  seed_rev="$(git rev-parse HEAD)"
  write_state "$seed_rev" "$1" "$bundle_id" "$asc_app_id" has "$2"
  python3 -I -c '
with open(".app-creators/state.md", encoding="utf-8") as f:
    text = f.read()
marker = "history:\n"
add = "  publish-ios:\n    asc_api_key_path_env: EXPO_ASC_API_KEY_PATH\n    asc_key_id_env: EXPO_ASC_KEY_ID\n    asc_issuer_id_env: EXPO_ASC_ISSUER_ID\n"
with open(".app-creators/state.md", "w", encoding="utf-8") as f:
    f.write(text.replace(marker, add + marker, 1))
'
  sed "s|__REV__|$seed_rev|g;s|__BUILD__|$build_id|g;s|__ASC__|$asc_app_id|g" "$lib_dir/notes-past-build.md" >> .app-creators/state.md
}

# The upload is done, and the notes hold a standing yes, which never counts.
record_upload() {
  cat "$lib_dir/notes-past-upload.md" >> .app-creators/state.md
  append_history "{ skill: publish-ios, version: \"0.1.1\", date: 2026-11-03, result: \"Ready to Submit: app_store $asc_app_id 1.0.0 (7)\" }"
}

# Past review: the submission is reported, and the notes hold a standing yes to release, which never counts.
record_review() {
  cat "$lib_dir/notes-past-review.md" >> .app-creators/state.md
  append_history "{ skill: publish-ios, version: \"0.1.1\", date: 2026-11-03, result: \"Waiting for Review: app_store $asc_app_id 1.0.0 (7)\" }"
}

scaffold_expo_first_run() {
  local rev
  extract_fixture todo-expo ff71355
  commit_all "app"
  rev="$(git rev-parse HEAD)"
  write_state "$rev" unknown "" "" "" pass
  write_readiness_confirmed "$rev"
  write_listing "$rev"
  commit_all "record readiness and listing"
}

scaffold_expo_upload_check() {
  seed_past_build ready pass
  write_readiness_confirmed "$seed_rev"
  write_listing "$seed_rev"
  append_history '{ skill: publish-ios, version: "0.1.1", date: 2026-11-03, result: "stopped: Step 9" }'
  commit_all "record readiness, listing, and the build"
}

scaffold_expo_submit_goahead() {
  seed_past_build testflight unknown
  write_readiness_confirmed_unknown "$seed_rev"
  write_listing ""
  record_upload
  commit_all "record readiness, listing, the build, and the upload"
}

scaffold_expo_release_goahead() {
  seed_past_build review pass
  write_readiness_confirmed "$seed_rev"
  write_listing "$seed_rev"
  record_upload
  record_review
  commit_all "record readiness, listing, the build, the upload, and the review"
}

scaffold_expo_no_listing() {
  seed_past_build testflight pass
  write_readiness_confirmed "$seed_rev"
  record_upload
  commit_all "record readiness, the build, and the upload"
}

scaffold_expo_unconfirmed_inventory() {
  seed_past_build testflight unknown
  write_readiness_unconfirmed "$seed_rev"
  write_listing "$seed_rev"
  record_upload
  commit_all "record readiness, listing, the build, and the upload"
}
