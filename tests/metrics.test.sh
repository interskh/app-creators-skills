#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

work="$tmp/repo"
fakebin="$tmp/fakebin"
nogh="$tmp/nogh"
log="$tmp/gh.log"
snap="$tmp/snap"
tab=$'\t'

mkdir -p "$fakebin" "$nogh"
cp "$root/tests/fake-gh.sh" "$fakebin/gh"
chmod +x "$fakebin/gh"
for tool in dirname mktemp date awk grep mv rm mkdir chmod head cat; do
  ln -s "$(command -v "$tool")" "$nogh/$tool"
done

pass=0
total=0
failed=""

fail() {
  failed="$failed
FAIL $1: $2"
}

newrepo() {
  rm -rf "$work"
  mkdir -p "$work/scripts"
  cp "$root/scripts/metrics.sh" "$work/scripts/metrics.sh"
  : > "$log"
  f="$work/docs/metrics.md"
}

run() {
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
    envs+=("$1")
    shift
  done
  shift
  set +e
  out="$(env PATH="$fakebin:$PATH" METRICS_DATE=2026-11-01 FAKE_GH_LOG="$log" ${envs[@]+"${envs[@]}"} "$BASH" "$work/scripts/metrics.sh" "$@" 2>&1)"
  code=$?
  set -e
}

row_count() {
  grep -c '^| 20' "$f" || true
}

check() {
  local label="$1" cond="$2"
  total=$((total + 1))
  if eval "$cond"; then
    pass=$((pass + 1))
  else
    fail "$label" "condition false: $cond (exit $code, out: $out)"
  fi
}

# Run expecting failure: exit code, message pattern, and file state untouched.
expect_fail() {
  local label="$1" want="$2" pattern="$3"
  shift 3
  local existed=0
  if [ -f "$f" ]; then
    existed=1
    cp "$f" "$snap"
  fi
  run "$@"
  total=$((total + 1))
  if [ "$code" -ne "$want" ]; then
    fail "$label" "want exit $want, got $code: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q -- "$pattern"; then
    fail "$label" "want message matching '$pattern', got: $out"
    return
  fi
  if [ "$existed" = 1 ]; then
    if ! cmp -s "$f" "$snap"; then
      fail "$label" "metrics.md changed"
      return
    fi
  elif [ -e "$f" ]; then
    fail "$label" "metrics.md was created"
    return
  fi
  if ls "$work/docs/".metrics.* >/dev/null 2>&1; then
    fail "$label" "temp file left behind"
    return
  fi
  pass=$((pass + 1))
}

hdr='| date | stars | forks | clones_14d | unique_cloners_14d | views_14d | unique_visitors_14d | plugin_installs | skills_sh_installs | site_visits |'

# first run creates the file
newrepo
run -- --
check "first run exits 2 on '--' as unknown argument" '[ "$code" -eq 2 ]'
check "'--' leaves no file" '[ ! -e "$f" ]'

newrepo
run --
check "first run exit 0" '[ "$code" -eq 0 ]'
check "first run creates docs/metrics.md" '[ -f "$f" ]'
check "first run row" 'grep -qxF "| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | - | - | - |" "$f"'
check "first run prints the row" '[ "$out" = "| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | - | - | - |" ]'
check "header columns" 'grep -qxF "$hdr" "$f"'
check "header says 14d windows overlap" 'grep -q "Rows overlap" "$f"'
check "header says do not sum" 'grep -q "do not sum" "$f"'
check "absent values are - not 0" '! grep -q "| 0 | 0 | 0 |" "$f"'
check "exactly one row" '[ "$(row_count)" -eq 1 ]'
check "only read calls to the repo endpoints" '! grep -v -E "^(auth status|api repos/interskh/app-creators-skills(/traffic/(clones|views))? --jq )" "$log" | grep -q .'
check "no write method used" '! grep -q -E -- "-X|--method|-f |-F |--input" "$log"'

# append on a new date, earlier rows untouched
cp "$f" "$snap"
run METRICS_DATE=2026-11-02 FAKE_VAL_REPO="7${tab}3" -- --plugin-installs 4
check "append exit 0" '[ "$code" -eq 0 ]'
check "append keeps earlier rows byte-identical" 'head -n "$(wc -l < "$snap")" "$f" | cmp -s - "$snap"'
check "append adds the new row last" '[ "$(tail -n 1 "$f")" = "| 2026-11-02 | 7 | 3 | 55 | 37 | 10 | 4 | 4 | - | - |" ]'
check "append gives two rows" '[ "$(row_count)" -eq 2 ]'

# same-date replace keeps manual values the rerun omits
run METRICS_DATE=2026-11-02 -- --skills-sh-installs 9 --site-visits 120
check "second same-day run exit 0" '[ "$code" -eq 0 ]'
check "manual values merge within a day" '[ "$(tail -n 1 "$f")" = "| 2026-11-02 | 5 | 2 | 55 | 37 | 10 | 4 | 4 | 9 | 120 |" ]'
run METRICS_DATE=2026-11-02 FAKE_VAL_REPO="8${tab}3" FAKE_VAL_CLONES="60${tab}40" --
check "rerun without flags exit 0" '[ "$code" -eq 0 ]'
check "rerun keeps manual values, refreshes gh values" '[ "$(tail -n 1 "$f")" = "| 2026-11-02 | 8 | 3 | 60 | 40 | 10 | 4 | 4 | 9 | 120 |" ]'
check "rerun does not add a row" '[ "$(row_count)" -eq 2 ]'
check "rerun leaves the other date alone" 'grep -qxF "| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | - | - | - |" "$f"'
run METRICS_DATE=2026-11-02 -- --plugin-installs 0 --site-visits 130
check "a flag overrides the stored value" '[ "$(tail -n 1 "$f")" = "| 2026-11-02 | 5 | 2 | 55 | 37 | 10 | 4 | 0 | 9 | 130 |" ]'
check "explicit 0 is written as 0" 'tail -n 1 "$f" | grep -q "| 0 | 9 |"'

# replace in the middle keeps order
run -- --site-visits 3
check "replace of an earlier date edits in place" '[ "$(row_count)" -eq 2 ] && [ "$(grep -n "^| 2026-11-01 " "$f" | cut -d: -f1)" -lt "$(grep -n "^| 2026-11-02 " "$f" | cut -d: -f1)" ] && grep -qxF "| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | - | - | 3 |" "$f"'

# default date is today's UTC date
newrepo
before="$(date -u +%Y-%m-%d)"
run METRICS_DATE= --
after="$(date -u +%Y-%m-%d)"
check "default date is UTC today" 'grep -q -E "^\| ($before|$after) \| 5 \|" "$f"'

# manual flag validation
newrepo
run -- --site-visits 1
for bad in -1 abc 1.5 "" 01 " 3" 1e3; do
  expect_fail "reject plugin-installs '$bad'" 2 "non-negative integer" -- --plugin-installs "$bad"
done
expect_fail "reject skills-sh-installs text" 2 "non-negative integer" -- --skills-sh-installs ten
expect_fail "reject site-visits negative" 2 "non-negative integer" -- --site-visits -5
expect_fail "missing value" 2 "needs a value" -- --site-visits
expect_fail "unknown flag prints usage" 2 "usage:" -- --bogus
expect_fail "unknown flag names the flag" 2 "unknown argument: --bogus" -- --bogus 1
expect_fail "positional argument" 2 "unknown argument" -- stray
check "valid flags with existing file still work" 'run -- --plugin-installs 12 --skills-sh-installs 0 --site-visits 7; [ "$code" -eq 0 ] && tail -n 1 "$f" | grep -qxF "| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | 12 | 0 | 7 |"'

# validation also fails first on a fresh repo with nothing created
newrepo
expect_fail "invalid flag on a fresh repo creates nothing" 2 "non-negative integer" -- --plugin-installs x
expect_fail "bad METRICS_DATE" 1 "METRICS_DATE" METRICS_DATE=11/01/2026 --

# failure paths on a fresh repo: nothing is created
newrepo
expect_fail "gh missing (fresh)" 1 "gh is not installed" PATH="$nogh" --
expect_fail "gh not logged in (fresh)" 1 "not logged in" FAKE_AUTH=fail --
expect_fail "403 on clones (fresh)" 1 "403 for traffic/clones" FAKE_FAIL_CLONES=403 --
expect_fail "network failure (fresh)" 1 "gh api failed for repo stats: error connecting" FAKE_FAIL_REPO=net --

# failure paths with an existing file: byte-identical
newrepo
run -- --plugin-installs 3
expect_fail "gh missing" 1 "gh is not installed" PATH="$nogh" --
expect_fail "gh not logged in" 1 "not logged in" FAKE_AUTH=fail --
expect_fail "403 on clones" 1 "403 for traffic/clones.*push access" FAKE_FAIL_CLONES=403 --
expect_fail "403 on views" 1 "403 for traffic/views" FAKE_FAIL_VIEWS=403 --
expect_fail "403 on repo stats" 1 "403 for repo stats" FAKE_FAIL_REPO=403 --
expect_fail "network failure on repo" 1 "gh api failed for repo stats" FAKE_FAIL_REPO=net --
expect_fail "network failure on clones" 1 "gh api failed for traffic/clones" FAKE_FAIL_CLONES=net --
expect_fail "network failure on views" 1 "gh api failed for traffic/views" FAKE_FAIL_VIEWS=net --
expect_fail "network failure after a good first call, same date" 1 "gh api failed" METRICS_DATE=2026-11-01 FAKE_FAIL_VIEWS=net -- --site-visits 9
expect_fail "malformed repo: text" 1 "malformed repo stats" FAKE_VAL_REPO="abc${tab}def" --
expect_fail "malformed repo: one field" 1 "malformed repo stats" FAKE_VAL_REPO="5" --
expect_fail "malformed repo: three fields" 1 "malformed repo stats" FAKE_VAL_REPO="5${tab}2${tab}1" --
expect_fail "malformed repo: empty" 1 "malformed repo stats" FAKE_VAL_REPO="" --
expect_fail "malformed repo: null" 1 "malformed repo stats" FAKE_VAL_REPO="null${tab}null" --
expect_fail "malformed clones" 1 "malformed traffic/clones" FAKE_VAL_CLONES="{\"message\":\"x\"}" --
expect_fail "malformed views: negative" 1 "malformed traffic/views" FAKE_VAL_VIEWS="-1${tab}2" --

# damaged existing files are refused, not rewritten
newrepo
mkdir -p "$work/docs"
printf '%s\n' "# my notes" "nothing here" > "$f"
expect_fail "file without the table header" 1 "no table header" --
newrepo
run --
sed 's/^| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | - | - | - |$/| 2026-11-01 | 5 | 2 | 55 | 37 | 10 | 4 | x | - | - |/' "$f" > "$f.new"
mv "$f.new" "$f"
expect_fail "malformed manual cell in today's row" 1 "malformed" --
newrepo
run --
printf '%s\n' "| 2026-11-01 | 1 | 1 | 1 | 1 | 1 | 1 | - | - | - |" >> "$f"
expect_fail "duplicate rows for the date" 1 "more than one row" --

echo "metrics tests: $pass/$total passed"
if [ "$pass" -ne "$total" ]; then
  printf '%s\n' "$failed"
  exit 1
fi
