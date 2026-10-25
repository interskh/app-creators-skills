#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "$0")/.." && pwd -P)"

REDIRECT_PREFIX='中文版：先读 SKILL.zh.md。'
EN_HEADINGS=("When to use" "What you must provide" "Before you start" "Steps" "Verify" "Troubleshooting" "Update state" "Sources")
ZH_HEADINGS=("何时使用" "你需要准备" "开始之前" "步骤" "验证" "排查" "更新状态" "来源")
RUNS_HEADER='| date | level | skill_version | route | account | outcome | notes |'
NAME_RE='^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'
SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
SECRET_RE='AKIA[0-9A-Z]{16}|(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,}|sk_(live|test)_[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{30,}|xox[baprs]-|-----BEGIN [A-Z ]*PRIVATE KEY'
ASSIGN_RE="(token|secret|password|api[_-]?key)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9/+_-]{16,}"

usage() {
  echo "usage: scripts/lint-skills.sh [skill-dir...]" >&2
  exit 2
}

findings=0
report() {
  printf '%s:%s: %s: %s\n' "$1" "$2" "$3" "$4"
  findings=$((findings + 1))
}

parse_frontmatter() {
  awk -v q="'" '
    function trim(v) { sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); return v }
    function strip(v,  c, i) {
      v = trim(v)
      c = substr(v, 1, 1)
      if (c == "\"" || c == q) {
        i = index(substr(v, 2), c)
        if (i > 0) return substr(v, 1, i + 1)
        return v
      }
      if (substr(v, 1, 1) == "#") return ""
      sub(/[ \t]+#.*$/, "", v)
      return v
    }
    function clean(v,  c) {
      v = strip(v)
      c = substr(v, 1, 1)
      if (length(v) >= 2 && (c == "\"" || c == q) && substr(v, length(v), 1) == c) return substr(v, 2, length(v) - 2)
      return v
    }
    function emit(k, v,  s) {
      s = strip(v)
      if (s ~ /^[>|][-+]?$/) { fold = k; foldline = NR; foldval = ""; return }
      if (cont && s != "" && substr(s, 1, 1) != "\"" && substr(s, 1, 1) != q) { fold = k; foldline = NR; foldval = s; return }
      print k "\t" NR "\t" clean(v)
    }
    function flush() {
      if (fold != "") print fold "\t" foldline "\t" foldval
      fold = ""
    }
    NR == 1 { next }
    $0 == "---" { flush(); exit }
    fold != "" && ($0 ~ /^[ \t]/ || $0 == "") {
      t = trim($0)
      if (t != "") foldval = (foldval == "" ? t : foldval " " t)
      next
    }
    { flush() }
    /^[A-Za-z_][A-Za-z0-9_-]*:/ {
      k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:/, "", v)
      top = k; indent = 0; cont = 1; emit(k, v); cont = 0; next
    }
    top == "metadata" && /^ +[A-Za-z_][A-Za-z0-9_-]*:/ {
      k = $0; match(k, /^ +/); if (indent == 0) indent = RLENGTH
      if (RLENGTH != indent) next
      sub(/^ +/, "", k); sub(/:.*/, "", k); v = $0; sub(/^[^:]*:/, "", v)
      emit("metadata." k, v); next
    }
  ' "$1"
}

fm=""
fm_line=0
fm_val=""
fm_get() {
  local row
  row="$(printf '%s\n' "$fm" | awk -F'\t' -v k="$1" '$1 == k { print $2 "\t" $3; exit }')"
  if [ -z "$row" ]; then
    fm_line=0
    fm_val=""
    return 1
  fi
  fm_line="${row%%$'\t'*}"
  fm_val="${row#*$'\t'}"
}

check_field() {
  local file="$1" rule="$2" key="$3" re="$4" want="$5"
  if ! fm_get "$key"; then
    report "$file" 0 "$rule" "missing $key"
    return
  fi
  if ! [[ "$fm_val" =~ $re ]]; then
    report "$file" "$fm_line" "$rule" "$key '$fm_val' must be $want"
  fi
}

headings() {
  awk '
    /^[ ]*(```|~~~)/ { fence = !fence; next }
    !fence && /^## / { print NR "\t" substr($0, 4) }
  ' "$1"
}

check_headings() {
  local file="$1" rule="$2" i=0 line text prev="start of file"
  shift 2
  local expected=("$@")
  while IFS=$'\t' read -r line text; do
    if [ "$i" -ge "${#expected[@]}" ]; then
      report "$file" "$line" "$rule" "unexpected heading '## $text' after $prev"
      return
    fi
    if [ "$text" != "${expected[$i]}" ]; then
      report "$file" "$line" "$rule" "expected '## ${expected[$i]}', found '## $text'"
      return
    fi
    prev="'## $text'"
    i=$((i + 1))
  done < <(headings "$file")
  if [ "$i" -lt "${#expected[@]}" ]; then
    report "$file" 0 "$rule" "missing '## ${expected[$i]}' after $prev"
  fi
}

check_urls() {
  local file="$1" section="$2" n
  while IFS= read -r n; do
    report "$file" "$n" url-outside-sources "URL outside '## $section'; move it to '## $section' or references/"
  done < <(awk -v s="$section" '
    /^[ ]*(```|~~~)/ { fence = !fence }
    !fence && /^## / { sec = substr($0, 4) }
    sec != s && /https?:\/\// { print NR }
  ' "$file")
}

secret_lines() {
  local f="$1" shapes assigns rc m v
  rc=0
  shapes="$(grep -nE -e "$SECRET_RE" "$f")" || rc=$?
  [ "$rc" -le 1 ] || return 2
  rc=0
  assigns="$(grep -noiE -e "$ASSIGN_RE" "$f")" || rc=$?
  [ "$rc" -le 1 ] || return 2
  {
    if [ -n "$shapes" ]; then
      printf '%s\n' "$shapes" | cut -d: -f1
    fi
    if [ -n "$assigns" ]; then
      while IFS= read -r m; do
        v="${m#*:}"
        v="$(printf '%s' "$v" | sed -E "s/^[^:=]*[:=][[:space:]]*['\"]?//")"
        if ! [[ "$v" =~ ^[A-Z][A-Z0-9]*_[A-Z0-9_]*$ ]]; then
          printf '%s\n' "${m%%:*}"
        fi
      done <<< "$assigns"
    fi
  } | sort -un
}

check_secrets() {
  local dir="$1" f n lines
  while IFS= read -r f; do
    if ! lines="$(secret_lines "$f")"; then
      printf '%s:0: tool-error: grep failed while scanning for secrets\n' "$f" >&2
      exit 2
    fi
    [ -n "$lines" ] || continue
    while IFS= read -r n; do
      report "$f" "$n" secret-like "credential-shaped string; keep secrets out of the repo and name the env var instead"
    done <<< "$lines"
  done < <(find "$dir" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -path "$dir/scripts/*" \) | sort)
}

check_metadata() {
  local md="$1" runs="$2" verified version
  check_field "$md" metadata-stage metadata.stage "$3" "one of publish | acquire | monetize | core"
  check_field "$md" metadata-platform metadata.platform "$4" "one of web | ios | android | all"
  check_field "$md" metadata-version metadata.version "$SEMVER_RE" "semver X.Y.Z"
  check_field "$md" metadata-verified metadata.verified '^(unverified|[0-9]{4}-[0-9]{2}-[0-9]{2})$' "\"unverified\" or YYYY-MM-DD"
  check_field "$md" metadata-verified-version metadata.verified_version '^([0-9]+\.[0-9]+\.[0-9]+)?$' "\"\" or semver X.Y.Z"
  check_field "$md" metadata-zh metadata.zh '^SKILL\.zh\.md$' "SKILL.zh.md"

  fm_get metadata.verified_version || true
  version="$fm_val"
  fm_get metadata.verified || return 0
  verified="$fm_val"
  if [ "$verified" = "unverified" ]; then
    if [ -n "$version" ]; then
      report "$md" "$fm_line" verified-consistency "verified is \"unverified\" but verified_version is '$version'; set it to \"\""
    fi
  elif [[ "$verified" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    if [ -z "$version" ]; then
      report "$md" "$fm_line" verified-consistency "verified is a date but verified_version is empty; set the semver that level-4 run exercised"
    elif [[ "$version" =~ $SEMVER_RE ]] && [ -f "$runs" ] && ! awk -F'|' -v v="$version" '
        function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        trim($3) == "4" && trim($4) == v { found = 1; exit }
        END { exit !found }
      ' "$runs"; then
      report "$md" "$fm_line" verified-consistency "verified is a date but references/verified-runs.md has no level 4 row for skill_version $version"
    fi
  fi
}

lint_skill() {
  local dir="$1" abs base template=0 md zh runs close first n
  abs="$(cd "$dir" && pwd -P)"
  base="$(basename "$abs")"
  case "$abs/" in "$root/templates/"*) template=1 ;; esac
  md="$dir/SKILL.md"
  zh="$dir/SKILL.zh.md"
  runs="$dir/references/verified-runs.md"

  close="$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { print NR; exit }' "$md")"
  if [ -z "$close" ]; then
    report "$md" 1 frontmatter-present "SKILL.md must start with '---' and close the frontmatter with '---'"
    close=0
  else
    fm="$(parse_frontmatter "$md")"

    if ! fm_get name; then
      report "$md" 0 name-format "missing name"
    elif [ "$template" -eq 1 ] && [ "$fm_val" = "__NAME__" ]; then
      :
    else
      if ! [[ "$fm_val" =~ $NAME_RE ]] || [ "${#fm_val}" -gt 64 ] || [[ "$fm_val" == *--* ]]; then
        report "$md" "$fm_line" name-format "name '$fm_val' must be 1-64 chars of [a-z0-9-], no leading/trailing '-', no '--'"
      fi
      if [ "$template" -eq 0 ] && [ "$fm_val" != "$base" ]; then
        report "$md" "$fm_line" name-matches-dir "name '$fm_val' must equal directory name '$base'"
      fi
    fi

    if ! fm_get description || [ -z "$fm_val" ]; then
      report "$md" "$fm_line" description-length "description must be non-empty"
    else
      n="$(printf '%s' "$fm_val" | tr -d '\200-\277' | wc -c | tr -d ' ')"
      if [ "$n" -gt 1024 ]; then
        report "$md" "$fm_line" description-length "description is $n chars; max 1024"
      fi
    fi

    local stage_re='^(publish|acquire|monetize|core)$' platform_re='^(web|ios|android|all)$'
    if [ "$template" -eq 1 ]; then
      stage_re='^(publish|acquire|monetize|core|__STAGE__)$'
      platform_re='^(web|ios|android|all|__PLATFORM__)$'
    fi
    check_field "$md" license-mit license '^MIT$' "MIT"
    if fm_get metadata && [ -n "$fm_val" ]; then
      report "$md" "$fm_line" metadata-mapping "metadata: must be followed only by an indented block of fields"
    else
      check_metadata "$md" "$runs" "$stage_re" "$platform_re"
    fi
  fi

  first="$(awk -v s="$((close + 1))" 'NR >= s && $0 !~ /^[[:space:]]*$/ { print NR "\t" $0; exit }' "$md")"
  [ -n "$first" ] || first="0"$'\t'
  local rest="${first#*$'\t'}"
  case "$rest" in
    "$REDIRECT_PREFIX"*) rest="${rest#"$REDIRECT_PREFIX"}" ;;
    *) rest="" ;;
  esac
  case "$rest" in
    *SKILL.zh.md*) ;;
    *) report "$md" "${first%%$'\t'*}" redirect-line "first body line must start with '$REDIRECT_PREFIX' and add one sentence naming SKILL.zh.md" ;;
  esac

  check_headings "$md" heading-order "${EN_HEADINGS[@]}"

  n="$(awk 'END { print NR }' "$md")"
  if [ "$n" -ge 300 ]; then
    report "$md" 0 line-budget "SKILL.md has $n lines; must be under 300"
  fi

  check_urls "$md" "Sources"

  if [ ! -f "$zh" ]; then
    report "$zh" 0 zh-present "SKILL.zh.md missing next to SKILL.md"
  else
    if [ "$(head -n 1 "$zh")" = "---" ]; then
      report "$zh" 1 zh-heading-parity "SKILL.zh.md must not have frontmatter"
    fi
    check_headings "$zh" zh-heading-parity "${ZH_HEADINGS[@]}"
    n="$(awk 'END { print NR }' "$zh")"
    if [ "$n" -ge 300 ]; then
      report "$zh" 0 line-budget "SKILL.zh.md has $n lines; must be under 300"
    fi
    check_urls "$zh" "来源"
  fi

  if [ ! -f "$runs" ]; then
    report "$runs" 0 verified-runs-present "references/verified-runs.md missing"
  elif [ "$(head -n 1 "$runs")" != "$RUNS_HEADER" ]; then
    report "$runs" 1 verified-runs-present "first line must be: $RUNS_HEADER"
  fi

  check_secrets "$dir"
}

dirs=()
if [ "$#" -gt 0 ]; then
  for arg in "$@"; do
    case "$arg" in -*) usage ;; esac
    if [ ! -f "${arg%/}/SKILL.md" ]; then
      echo "error: ${arg%/} is not a skill directory (no SKILL.md)" >&2
      exit 2
    fi
    dirs+=("${arg%/}")
  done
else
  cd "$root"
  for d in skills/*/; do
    if [ -d "$d" ]; then
      dirs+=("${d%/}")
    fi
  done
fi

count=0
for d in ${dirs[@]+"${dirs[@]}"}; do
  count=$((count + 1))
  if [ ! -f "$d/SKILL.md" ]; then
    report "$d/SKILL.md" 0 skill-md-present "every directory under skills/ is a skill and needs SKILL.md"
    continue
  fi
  lint_skill "$d"
done

if [ "$findings" -gt 0 ]; then
  exit 1
fi
echo "lint: $count skills clean"
