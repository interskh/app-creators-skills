#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
lint="$root/scripts/lint-skills.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0
total=0
failed=""

fail() {
  failed="$failed
FAIL $1: $2"
}

run_lint() {
  set +e
  out="$(bash "$lint" "$@" 2>&1)"
  code=$?
  set -e
}

edit() {
  sed "$1" "$2" > "$2.tmp"
  mv "$2.tmp" "$2"
}

expect_clean() {
  local label="$1"
  shift
  total=$((total + 1))
  run_lint "$@"
  if [ "$code" -ne 0 ]; then
    fail "$label" "want exit 0, got $code: $out"
    return
  fi
  pass=$((pass + 1))
}

expect_rule() {
  local label="$1" rule="$2" dir="$3"
  total=$((total + 1))
  run_lint "$dir"
  if [ "$code" -ne 1 ]; then
    fail "$label" "want exit 1, got $code: $out"
    return
  fi
  if ! printf '%s\n' "$out" | grep -q -- ":[0-9]*: $rule: "; then
    fail "$label" "want rule '$rule' in: $out"
    return
  fi
  if printf '%s\n' "$out" | grep -qvE '^[^:]+:[0-9]+: [a-z-]+: .+$'; then
    fail "$label" "malformed finding line in: $out"
    return
  fi
  pass=$((pass + 1))
}

mkdir -p "$tmp/repo/scripts" "$tmp/repo/templates" "$tmp/repo/skills"
cp "$root/scripts/new-skill.sh" "$root/scripts/lint-skills.sh" "$tmp/repo/scripts/"
cp -R "$root/templates/skill" "$tmp/repo/templates/skill"
bash "$tmp/repo/scripts/new-skill.sh" good-skill > /dev/null
good="$tmp/repo/skills/good-skill"
edit 's/__STAGE__/core/;s/__PLATFORM__/all/' "$good/SKILL.md"

mutant() {
  m="$tmp/mutants/$1/good-skill"
  mkdir -p "$tmp/mutants/$1"
  cp -R "$good" "$m"
}

long_text() {
  local n="$1" s=""
  while [ "${#s}" -lt "$n" ]; do s="${s}word "; done
  printf '%s' "$s"
}

expect_clean "good skill" "$good"
expect_clean "template" "$root/templates/skill"

total=$((total + 1))
set +e
out="$(cd "$tmp/repo" && bash scripts/lint-skills.sh 2>&1)"
code=$?
set -e
if [ "$code" -eq 0 ] && [ "$out" = "lint: 1 skills clean" ]; then pass=$((pass + 1)); else fail "no-arg scan" "got $code: $out"; fi

total=$((total + 1))
run_lint "$tmp/does-not-exist"
if [ "$code" -eq 2 ]; then pass=$((pass + 1)); else fail "missing dir" "want exit 2, got $code: $out"; fi

mutant env-var-name
printf '\nSet api_key: CLOUDFLARE_API_TOKEN in the environment.\n' >> "$m/references/verified-runs.md"
expect_clean "env var name is not a secret" "$m"

mutant description-counts-chars
zh_desc=""
while [ "$(printf '%s' "$zh_desc" | wc -c)" -lt 2400 ]; do zh_desc="${zh_desc}发布网站"; done
edit "s/^  \[What this skill does.*/  $zh_desc/" "$m/SKILL.md"
expect_clean "description counts chars, not bytes" "$m"

mutant frontmatter-present
edit '1d' "$m/SKILL.md"
expect_rule frontmatter-present frontmatter-present "$m"

mutant name-format
edit 's/^name: .*/name: good--skill/' "$m/SKILL.md"
expect_rule name-format name-format "$m"

mutant name-format-upper
edit 's/^name: .*/name: Good-Skill/' "$m/SKILL.md"
expect_rule name-format-upper name-format "$m"

mutant name-format-hyphen
edit 's/^name: .*/name: -good-skill/' "$m/SKILL.md"
expect_rule name-format-hyphen name-format "$m"

mutant name-format-long
edit "s/^name: .*/name: $(long_text 70 | tr ' ' 'x')/" "$m/SKILL.md"
expect_rule name-format-long name-format "$m"

mutant name-matches-dir
edit 's/^name: .*/name: other-skill/' "$m/SKILL.md"
expect_rule name-matches-dir name-matches-dir "$m"

mutant description-length
edit "s/^  \[What this skill does.*/  $(long_text 1100)/" "$m/SKILL.md"
expect_rule description-length description-length "$m"

mutant description-empty
edit '/^description:/,/^license:/{/^license:/!d;}' "$m/SKILL.md"
edit 's/^license:/description: ""\
license:/' "$m/SKILL.md"
expect_rule description-empty description-length "$m"

mutant license-mit
edit 's/^license: .*/license: Apache-2.0/' "$m/SKILL.md"
expect_rule license-mit license-mit "$m"

mutant metadata-stage
edit 's/^  stage: .*/  stage: launch/' "$m/SKILL.md"
expect_rule metadata-stage metadata-stage "$m"

mutant placeholder-outside-template
edit 's/^  stage: .*/  stage: __STAGE__/' "$m/SKILL.md"
expect_rule placeholder-outside-template metadata-stage "$m"

mutant metadata-platform
edit 's/^  platform: .*/  platform: desktop/' "$m/SKILL.md"
expect_rule metadata-platform metadata-platform "$m"

mutant metadata-version
edit 's/^  version: .*/  version: "0.1"/' "$m/SKILL.md"
expect_rule metadata-version metadata-version "$m"

mutant metadata-verified
edit 's/^  verified: .*/  verified: "26-10-2026"/' "$m/SKILL.md"
expect_rule metadata-verified metadata-verified "$m"

mutant metadata-verified-version
edit 's/^  verified_version: .*/  verified_version: "1.0"/' "$m/SKILL.md"
expect_rule metadata-verified-version metadata-verified-version "$m"

mutant metadata-verified-version-missing
edit '/^  verified_version:/d' "$m/SKILL.md"
expect_rule metadata-verified-version-missing metadata-verified-version "$m"

mutant metadata-zh
edit 's/^  zh: .*/  zh: SKILL.zh.txt/' "$m/SKILL.md"
expect_rule metadata-zh metadata-zh "$m"

mutant redirect-line
edit 's/^中文版：.*/Chinese version: see SKILL.zh.md./' "$m/SKILL.md"
expect_rule redirect-line redirect-line "$m"

mutant empty-body
edit '16,$d' "$m/SKILL.md"
expect_rule empty-body redirect-line "$m"

mutant heading-order
edit 's/^## Verify$/## Check/' "$m/SKILL.md"
expect_rule heading-order heading-order "$m"

mutant heading-order-missing
edit '/^## Sources$/d' "$m/SKILL.md"
expect_rule heading-order-missing heading-order "$m"

mutant line-budget
i=0
while [ "$i" -lt 300 ]; do echo "filler"; i=$((i + 1)); done >> "$m/SKILL.md"
expect_rule line-budget line-budget "$m"

mutant zh-present
rm "$m/SKILL.zh.md"
expect_rule zh-present zh-present "$m"

mutant zh-heading-parity
edit 's/^## 排查$/## 故障排查/' "$m/SKILL.zh.md"
expect_rule zh-heading-parity zh-heading-parity "$m"

mutant zh-frontmatter
{ printf -- '---\nname: good-skill\n---\n'; cat "$m/SKILL.zh.md"; } > "$m/zh.tmp"
mv "$m/zh.tmp" "$m/SKILL.zh.md"
expect_rule zh-frontmatter zh-heading-parity "$m"

mutant verified-runs-present
rm "$m/references/verified-runs.md"
expect_rule verified-runs-present verified-runs-present "$m"

mutant verified-runs-header
edit '1s/.*/| date | outcome |/' "$m/references/verified-runs.md"
expect_rule verified-runs-header verified-runs-present "$m"

mutant url-outside-sources
edit 's/^## Verify$/## Verify\
\
See https:\/\/example.com\/docs for details./' "$m/SKILL.md"
expect_rule url-outside-sources url-outside-sources "$m"

mutant url-outside-sources-zh
edit 's/^## 验证$/## 验证\
\
参见 https:\/\/example.com\/docs。/' "$m/SKILL.zh.md"
expect_rule url-outside-sources-zh url-outside-sources "$m"

fake="$(long_text 24 | tr -d ' ')"

mutant secret-like
printf '\napi_key = "%s"\n' "$fake" >> "$m/SKILL.md"
expect_rule secret-like secret-like "$m"

mutant secret-like-script
mkdir -p "$m/scripts"
printf '#!/usr/bin/env bash\nTOKEN=%s\n' "$fake" > "$m/scripts/check.sh"
expect_rule secret-like-script secret-like "$m"

mutant secret-like-aws
printf '\nkey %s%s\n' "AKIA" "ABCDEFGHIJKLMNOP" >> "$m/references/verified-runs.md"
expect_rule secret-like-aws secret-like "$m"

mutant secret-like-pem
printf '\n%s%s\n' "-----BEGIN RSA " "PRIVATE KEY-----" >> "$m/references/verified-runs.md"
expect_rule secret-like-pem secret-like "$m"

if [ "$pass" -eq "$total" ]; then
  echo "PASS $pass/$total"
  exit 0
fi
printf '%s\n' "$failed"
echo "FAIL $((total - pass))/$total"
exit 1
