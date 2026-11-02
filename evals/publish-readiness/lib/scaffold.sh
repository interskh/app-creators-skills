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

put_state() {
  mkdir -p .app-creators
  cp "$lib_dir/$1" .app-creators/state.md
}

# Rev A is the app. Rev B adds an earlier assessment of rev A, so only .app-creators/ differs.
# $1 is the seeded result: the opposite of what the case's graders require, so they fail with no session.
scaffold_expo_assessed() {
  local rev seed="$1"
  extract_fixture todo-expo ff71355
  commit_all "app"
  rev="$(git rev-parse HEAD)"
  mkdir -p .app-creators
  sed "s/__REV__/$rev/g;s/__RESULT__/$seed/g" "$lib_dir/state-expo-assessed.md" > .app-creators/state.md
  sed "s/__REV__/$rev/g;s/__RESULT__/$seed/g" "$lib_dir/readiness-expo-assessed.md" > .app-creators/readiness.md
  commit_all "record readiness"
}

scaffold_expo_gaps() {
  extract_fixture todo-expo ff71355
  python3 -I -c '
import json
with open("app.json") as f:
    config = json.load(f)
for plugin in config["expo"]["plugins"]:
    if isinstance(plugin, list) and plugin[0] == "expo-image-picker":
        del plugin[1]["photosPermission"]
with open("app.json", "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")
'
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
  put_state state-expo-gaps.md
  commit_all "app with gaps"
}

scaffold_web_nodata() {
  extract_fixture todo-vite 95c2f95
  put_state state-web-nodata.md
  commit_all "app"
}
