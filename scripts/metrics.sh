#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "$0")/.." && pwd -P)"
repo="interskh/app-creators-skills"
out="$root/docs/metrics.md"
COLUMNS_ROW='| date | stars | forks | clones_14d | unique_cloners_14d | views_14d | unique_visitors_14d | plugin_installs | skills_sh_installs | site_visits |'
INT_RE='^(0|[1-9][0-9]*)$'

usage() {
  echo "usage: scripts/metrics.sh [--plugin-installs N] [--skills-sh-installs N] [--site-visits N]" >&2
  echo "  N is a non-negative integer. An omitted value is kept from today's row, else written as -." >&2
  echo "  METRICS_DATE=YYYY-MM-DD overrides today's UTC date." >&2
  exit 2
}

die() {
  echo "metrics: $*" >&2
  exit 1
}

plugin="" skills="" site=""

need_int() {
  [ "$#" -ge 2 ] || { echo "metrics: $1 needs a value" >&2; usage; }
  [[ "$2" =~ $INT_RE ]] || { echo "metrics: $1 must be a non-negative integer, got '$2'" >&2; usage; }
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plugin-installs) need_int "$@"; plugin="$2"; shift 2 ;;
    --skills-sh-installs) need_int "$@"; skills="$2"; shift 2 ;;
    --site-visits) need_int "$@"; site="$2"; shift 2 ;;
    *) echo "metrics: unknown argument: $1" >&2; usage ;;
  esac
done

date_utc="${METRICS_DATE:-$(date -u +%Y-%m-%d)}"
[[ "$date_utc" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "METRICS_DATE must be YYYY-MM-DD, got '$date_utc'"

command -v gh >/dev/null 2>&1 || die "gh is not installed; install it from https://cli.github.com and run 'gh auth login'"
gh auth status >/dev/null 2>&1 || die "gh is not logged in; run 'gh auth login' with an account that has push access to $repo"

errfile="$(mktemp)"
tmpfile=""
trap 'rm -f "$errfile" "$tmpfile"' EXIT

fetch() {
  local label="$1" endpoint="$2" jq_expr="$3" val
  if ! val="$(gh api "$endpoint" --jq "$jq_expr" 2>"$errfile")"; then
    if grep -q 'HTTP 403' "$errfile"; then
      die "GitHub returned 403 for $label; traffic data needs a token with push access to $repo"
    fi
    die "gh api failed for $label: $(head -n 1 "$errfile")"
  fi
  printf '%s' "$val"
}

pair() {
  local label="$1" val="$2" a b extra
  IFS=$'\t' read -r a b extra <<EOF || true
$val
EOF
  if [ -n "$extra" ] || ! [[ "$a" =~ $INT_RE ]] || ! [[ "$b" =~ $INT_RE ]]; then
    die "malformed $label response from gh"
  fi
  pa="$a" pb="$b"
}

repo_raw="$(fetch "repo stats" "repos/$repo" '[.stargazers_count,.forks_count]|@tsv')"
clones_raw="$(fetch "traffic/clones" "repos/$repo/traffic/clones" '[.count,.uniques]|@tsv')"
views_raw="$(fetch "traffic/views" "repos/$repo/traffic/views" '[.count,.uniques]|@tsv')"

pair "repo stats" "$repo_raw"
stars="$pa" forks="$pb"
pair "traffic/clones" "$clones_raw"
clones="$pa" uclones="$pb"
pair "traffic/views" "$views_raw"
views="$pa" uviews="$pb"

if [ -f "$out" ]; then
  grep -qxF "$COLUMNS_ROW" "$out" || die "$out has no table header matching the expected columns; refusing to edit it"
  prev="$(awk -F'|' -v d="$date_utc" '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    /^\|/ && trim($2) == d { print NF "\t" trim($9) "\t" trim($10) "\t" trim($11) }
  ' "$out")"
  if [ -n "$prev" ]; then
    case "$prev" in *$'\n'*) die "$out has more than one row for $date_utc" ;; esac
    IFS=$'\t' read -r nf pp ps pv <<EOF
$prev
EOF
    [ "$nf" = 12 ] || die "existing $date_utc row in $out is malformed"
    for v in "$pp" "$ps" "$pv"; do
      [ "$v" = "-" ] || [[ "$v" =~ $INT_RE ]] || die "existing $date_utc row in $out is malformed"
    done
    [ -n "$plugin" ] || plugin="$pp"
    [ -n "$skills" ] || skills="$ps"
    [ -n "$site" ] || site="$pv"
  fi
fi

row="| $date_utc | $stars | $forks | $clones | $uclones | $views | $uviews | ${plugin:--} | ${skills:--} | ${site:--} |"

mkdir -p "$(dirname "$out")"
tmpfile="$(mktemp "$(dirname "$out")/.metrics.XXXXXX")"

if [ -f "$out" ]; then
  awk -F'|' -v d="$date_utc" -v row="$row" '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    /^\|/ && trim($2) == d { print row; done = 1; next }
    { print }
    END { if (!done) print row }
  ' "$out" > "$tmpfile"
else
  {
    echo "# Metrics"
    echo
    echo "One row per date, written by \`scripts/metrics.sh\`. Aggregate counts only."
    echo
    echo "- stars, forks: totals on the date."
    echo "- clones_14d, unique_cloners_14d, views_14d, unique_visitors_14d: GitHub's rolling 14-day totals on the date. Rows overlap, so do not sum them across rows. Unique counts are per window, so they cannot be added or de-duplicated either."
    echo "- plugin_installs, skills_sh_installs: entered by hand. Neither Claude Code plugin marketplaces nor skills.sh documents an install-count API."
    echo "- site_visits: entered by hand. The website is not live."
    echo "- \`-\` means not recorded. It is not zero."
    echo
    echo "$COLUMNS_ROW"
    echo '|---|---|---|---|---|---|---|---|---|---|'
    echo "$row"
  } > "$tmpfile"
fi

chmod 644 "$tmpfile"
mv "$tmpfile" "$out"
tmpfile=""
echo "$row"
