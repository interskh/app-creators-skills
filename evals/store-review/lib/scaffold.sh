# Sourced by each case's scaffold.sh. Runs in the eval workspace.
lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

asc_app_id=1234567890
bundle_id=io.github.interskh.todo
package=io.github.interskh.todo
build_id=00000000-0000-4000-8000-000000000007
expo_pin=ff71355

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

# An in-app privacy policy link in todo-expo's App.tsx, to the URL the state seeds record, so the privacy policy row can clear.
add_privacy_link() {
  python3 -I -c '
import re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    url = re.search(r"^\s*privacy_policy_url: \"([^\"]+)\"$", f.read(), re.M).group(1)
with open("App.tsx", encoding="utf-8") as f:
    text = f.read()
for old, new in (
    ("  Image,\n", "  Image,\n  Linking,\n"),
    ("const STORAGE_KEY = \x27todos\x27;\n", "const STORAGE_KEY = \x27todos\x27;\nconst PRIVACY_POLICY_URL = \x27" + url + "\x27;\n"),
    ("      <StatusBar style=\"auto\" />\n", "      <Pressable onPress={() => Linking.openURL(PRIVACY_POLICY_URL)}>\n        <Text style={styles.link}>Privacy policy</Text>\n      </Pressable>\n      <StatusBar style=\"auto\" />\n"),
    ("  thumb: { width: 40, height: 40, borderRadius: 4 },\n", "  thumb: { width: 40, height: 40, borderRadius: 4 },\n  link: { color: \x27#06c\x27, paddingVertical: 8 },\n"),
):
    if text.count(old) != 1:
        sys.exit("scaffold: App.tsx holds %r %d times, not 1" % (old, text.count(old)))
    text = text.replace(old, new)
with open("App.tsx", "w", encoding="utf-8") as f:
    f.write(text)
' "$lib_dir/state-ios.md"
}

# A sign-in screen in todo-expo: email and password, sign-in only, no sign-up. App.tsx shows it until signIn returns a session token. Run after add_privacy_link.
add_login_screen() {
  cp "$lib_dir/login/auth.ts" auth.ts
  python3 -I -c '
import re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    url = re.search(r"^\s*privacy_policy_url: \"([^\"]+)\"$", f.read(), re.M).group(1)
with open(sys.argv[2], encoding="utf-8") as f:
    screen = f.read()
with open("LoginScreen.tsx", "w", encoding="utf-8") as f:
    f.write(screen.replace("__PRIVACY_POLICY_URL__", url))
with open("App.tsx", encoding="utf-8") as f:
    text = f.read()
for old, new in (
    ("} from \x27react-native\x27;\n", "} from \x27react-native\x27;\n\nimport LoginScreen from \x27./LoginScreen\x27;\n"),
    ("  const [photoUri, setPhotoUri] = useState<string | undefined>();\n", "  const [photoUri, setPhotoUri] = useState<string | undefined>();\n  const [sessionToken, setSessionToken] = useState<string | undefined>();\n"),
    ("\n  return (\n", "\n  if (!sessionToken) return <LoginScreen onSignedIn={setSessionToken} />;\n\n  return (\n"),
):
    if text.count(old) != 1:
        sys.exit("scaffold: App.tsx holds %r %d times, not 1" % (old, text.count(old)))
    text = text.replace(old, new)
with open("App.tsx", "w", encoding="utf-8") as f:
    f.write(text)
' "$lib_dir/state-ios.md" "$lib_dir/login/LoginScreen.tsx"
}

# Rev A: todo-expo with the privacy link and the sign-in screen. Sets seed_rev.
seed_login_app() {
  extract_fixture todo-expo "$expo_pin"
  add_privacy_link
  add_login_screen
  commit_all "app with a sign-in screen"
  seed_rev="$(git rev-parse HEAD)"
}

# $1 revision, $2 iOS status, $3 readiness result.
write_state_ios() {
  mkdir -p .app-creators
  sed "s|__REV__|$1|g;s|__STATUS__|$2|g;s|__BUNDLE__|$bundle_id|g;s|__ASC__|$asc_app_id|g;s|__APPLE__|has|g;s|__RESULT__|$3|g" "$lib_dir/state-ios.md" > .app-creators/state.md
}

# $1 revision, $2 Android status, $3 readiness result.
write_state_android() {
  mkdir -p .app-creators
  sed "s|__REV__|$1|g;s|__STATUS__|$2|g;s|__PACKAGE__|$package|g;s|__PLAY__|has|g;s|__RESULT__|$3|g" "$lib_dir/state-android.md" > .app-creators/state.md
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

# $1 ios or android, $2 revision. Readiness pass with a confirmed inventory that holds the sign-in screen's email.
write_readiness() {
  local item="{ data_type: \"email address\", platforms: [$1], evidence: \"LoginScreen.tsx: the email field, sent by signIn in auth.ts\", purpose: \"sign in\", linked_to_user: yes, used_for_tracking: no, shared_with: [], optional: no }"
  sed "s|__REV__|$2|g;s|__RESULT__|pass|g;s|__INV_CHECK__|pass|g;s|__INV_EVIDENCE__|confirmed by the creator|g;s|__CONFIRMED__|true|g;s|__ITEMS__|[$item]|g" "$lib_dir/readiness-$1.md" > .app-creators/readiness.md
}

# $1 revision. The app_store listing, one opaque PNG per screenshot row at the size the row records, and its history row.
write_listing() {
  sed "s|__REV__|$1|g" "$lib_dir/listing.md" > .app-creators/listing.md
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

# Before submission: build 7 is in TestFlight, readiness pass at rev A, a valid app_store listing at rev A. No demo account is recorded anywhere.
scaffold_login_presubmit() {
  seed_login_app
  write_state_ios "$seed_rev" testflight pass
  write_readiness ios "$seed_rev"
  write_listing "$seed_rev"
  append_history "{ skill: publish-ios, version: \"0.2.1\", date: 2026-11-03, result: \"Ready to Submit: app_store $asc_app_id 1.0.0 (7)\" }"
  printf '\nBuild %s: commit %s, clean tree at build time, profile production, 2026-11-03. Finished: version 1.0.0, build 7.\n' "$build_id" "$seed_rev" >> .app-creators/state.md
  commit_all "record readiness, listing, and the build"
}

# Submitted: publish-ios recorded review for 1.0.0 (7). The rejection itself arrives in the prompt.
scaffold_apple_rejection() {
  seed_login_app
  write_state_ios "$seed_rev" review pass
  write_readiness ios "$seed_rev"
  write_listing "$seed_rev"
  append_history "{ skill: publish-ios, version: \"0.2.1\", date: 2026-11-03, result: \"Waiting for Review: app_store $asc_app_id 1.0.0 (7)\" }"
  printf '\nBuild %s: commit %s, clean tree at build time, profile production, 2026-11-03. Finished: version 1.0.0, build 7.\nStep 13: build 7 of 1.0.0 went to App Review after a yes in that session. Waiting for Review, reported by the creator on 2026-11-03.\n' "$build_id" "$seed_rev" >> .app-creators/state.md
  commit_all "record readiness, listing, the build, and the submission"
}

# Sent for review: publish-android recorded review for 1.0.0 (7) on internal testing. The rejection itself arrives in the prompt.
scaffold_play_rejection() {
  seed_login_app
  write_state_android "$seed_rev" review pass
  write_readiness android "$seed_rev"
  append_history "{ skill: publish-android, version: \"0.1.1\", date: 2026-11-03, result: \"In review: google_play $package 1.0.0 (7) internal\" }"
  printf '\nBuild %s: commit %s, clean tree at build time, profile production, 2026-11-03. Finished: version 1.0.0, version code 7.\nStep 12: version code 7 rolled out to internal testing and sent for review after a yes in that session. In review, reported by the creator on 2026-11-03.\n' "$build_id" "$seed_rev" >> .app-creators/state.md
  commit_all "record readiness, the build, and the send for review"
}
