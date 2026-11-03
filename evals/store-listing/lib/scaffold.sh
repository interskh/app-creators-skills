# Sourced by each case's scaffold.sh. Runs in the eval workspace.
lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# $1 languages, $2 iOS readiness, $3 Android readiness, $4 the icon-alpha check line. Records readiness of rev A in rev B, so only .app-creators/ differs.
record_readiness() {
  local rev history
  rev="$(git rev-parse HEAD)"
  history=pass
  if [ "$2" = fail ]; then
    history=fail
  fi
  mkdir -p .app-creators
  sed "s|__REV__|$rev|g;s|__LANGS__|$1|g;s|__IOS__|$2|g;s|__ANDROID__|$3|g;s|__HISTORY__|$history|g" "$lib_dir/state-expo.md" > .app-creators/state.md
  sed "s|__REV__|$rev|g;s|__IOS__|$2|g;s|__ANDROID__|$3|g;s|__ALPHA__|$4|g" "$lib_dir/readiness-expo.md" > .app-creators/readiness.md
}

alpha_pass='{ id: icon-alpha, result: pass, evidence: "./assets/icon.png has no alpha channel or tRNS chunk", fix: "" }'
alpha_fail='{ id: icon-alpha, result: fail, evidence: "./assets/icon.png has an alpha channel", fix: "Re-export assets/icon.png without an alpha channel, commit, and rerun publish-readiness." }'

scaffold_expo_copy() {
  extract_fixture todo-expo ff71355
  commit_all "app"
  record_readiness "en, zh" pass pass "$alpha_pass"
  commit_all "record readiness"
}

# A valid listing whose Google Play short_description is one over the limit in the real limits.md.
scaffold_expo_overlimit() {
  extract_fixture todo-expo ff71355
  commit_all "app"
  record_readiness "en" pass pass "$alpha_pass"
  python3 -I -c '
import re, sys
limits, seed, out, rev = sys.argv[1:5]
core = "Keep your to-do list on this device, add a photo to any item, tick off when done"
with open(limits, encoding="utf-8") as f:
    row = re.search(r"^\| google_play \| field \| short_description \| (\d+) chars \|", f.read(), re.M)
if not row:
    sys.exit("scaffold: limits.md has no short_description chars row")
over = int(row.group(1)) + 1
if len(core) > over:
    sys.exit("scaffold: the seeded text is longer than the limit plus one; shorten it and the graders")
with open(seed, encoding="utf-8") as f:
    text = f.read()
with open(out, "w", encoding="utf-8") as f:
    f.write(text.replace("__REV__", rev).replace("__OVER__", core + "." * (over - len(core))))
' "$lib_dir/../../../skills/store-listing/references/limits.md" "$lib_dir/listing-overlimit.md" .app-creators/listing.md "$(git rev-parse HEAD)"
  commit_all "record readiness and listing"
}

# The readiness failure is real: the icon gets an alpha channel, as in the publish-readiness expo-gaps case.
scaffold_expo_readiness_fail() {
  extract_fixture todo-expo ff71355
  python3 -I -c '
import struct, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
size = 1024
row = b"\x00" + b"\x20\x60\xc0\x80" * size
with open("assets/icon.png", "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)))
    f.write(chunk(b"IDAT", zlib.compress(row * size)))
    f.write(chunk(b"IEND", b""))
'
  commit_all "app with an alpha icon"
  record_readiness "en, zh" fail pass "$alpha_fail"
  commit_all "record readiness"
}
