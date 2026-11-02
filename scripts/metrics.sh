#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

root="$(cd "$(dirname "$0")/.." && pwd -P)"
repo="interskh/app-creators-skills"
out="$root/docs/metrics.md"
COLUMNS_ROW='| date | stars | forks | clones_14d | unique_cloners_14d | views_14d | unique_visitors_14d | plugin_installs | skills_sh_installs | site_visits |'
INT_RE='^(0|[1-9][0-9]*)$'
DATE_RE='^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'
SEP_ROW='|---|---|---|---|---|---|---|---|---|---|'

usage() {
  echo "usage: scripts/metrics.sh [--plugin-installs N] [--skills-sh-installs N] [--site-visits N]" >&2
  echo "  N is a non-negative integer. An omitted value is kept from today's row, else written as -." >&2
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
[[ "$date_utc" =~ $DATE_RE ]] || die "METRICS_DATE must be a valid YYYY-MM-DD date, got '$date_utc'"

dy=$((10#${date_utc:0:4})) dm=$((10#${date_utc:5:2})) dd=$((10#${date_utc:8:2}))
case "$dm" in
  4|6|9|11) dim=30 ;;
  2) if [ $((dy % 4)) -eq 0 ] && { [ $((dy % 100)) -ne 0 ] || [ $((dy % 400)) -eq 0 ]; }; then dim=29; else dim=28; fi ;;
  *) dim=31 ;;
esac
[ "$dd" -le "$dim" ] || die "METRICS_DATE must be a valid YYYY-MM-DD date, got '$date_utc' (no such day)"
today="$(date -u +%Y-%m-%d)"
[[ ! "$date_utc" > "$today" ]] || die "$date_utc is later than today ($today, UTC); refusing to write a future row"

command -v gh >/dev/null 2>&1 || die "gh is not installed; install it from https://cli.github.com and run 'gh auth login'"

errfile="$(mktemp)"
tmpfile=""
trap 'rm -f "$errfile" "$tmpfile"' EXIT

fetch() {
  local label="$1" endpoint="$2" jq_expr="$3" val st
  val="$(gh api --hostname github.com "$endpoint" --jq "$jq_expr" 2>"$errfile")" && st=0 || st=$?
  if [ "$st" -ne 0 ]; then
    if [ "$st" -eq 4 ]; then
      die "gh is not logged in to github.com; run 'gh auth login' (or set GH_TOKEN) with an account that has push access to $repo"
    fi
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
  scan="$(awk -F'|' -v hdr="$COLUMNS_ROW" -v sep="$SEP_ROW" -v d="$date_utc" '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    $0 == hdr && !seen { st = 1; seen = 1; next }
    st == 1 { st = ($0 == sep) ? 2 : 9; next }
    st == 2 && /^\|/ {
      k = trim($2)
      if (k ~ /^[0-9][0-9][0-9][0-9]-/ && k > latest) latest = k
      if (k == d) { n++; nf = NF; pp = trim($9); ps = trim($10); pv = trim($11) }
      next
    }
    st == 2 { st = 3 }
    END { printf "%d|%s|%d|%s|%s|%s|%s\n", st, latest, n, nf, pp, ps, pv }
  ' "$out")"
  IFS="|" read -r tstate latest nmatch nf pp ps pv <<EOF
$scan
EOF
  [ "$tstate" = 2 ] || [ "$tstate" = 3 ] || die "$out has a damaged metrics table (missing or altered separator row, or no room for rows); refusing to edit it"
  [ "$nmatch" -le 1 ] || die "$out has more than one row for $date_utc"
  if [ -n "$latest" ] && [[ "$date_utc" < "$latest" ]]; then
    die "$date_utc is earlier than the latest row ($latest) in $out; refusing to overwrite history"
  fi
  if [ "$nmatch" -eq 1 ]; then
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
  awk -F'|' -v hdr="$COLUMNS_ROW" -v sep="$SEP_ROW" -v d="$date_utc" -v row="$row" '
    function trim(v) { gsub(/^[ \t]+|[ \t]+$/, "", v); return v }
    function flush() { if (!done) { print row; done = 1 } }
    $0 == hdr && !seen { st = 1; seen = 1; print; next }
    st == 1 { st = ($0 == sep) ? 2 : 9; print; next }
    st == 2 && /^\|/ {
      if (trim($2) == d) { print row; done = 1 } else print
      next
    }
    st == 2 { flush(); st = 3 }
    { print }
    END { if (st == 2) flush() }
  ' "$out" > "$tmpfile"
else
  {
    echo "# Metrics"
    echo
    echo "One row per date, written by \`scripts/metrics.sh\`. Aggregate counts only."
    echo
    echo "- stars, forks: totals on the date."
    echo "- clones_14d, unique_cloners_14d, views_14d, unique_visitors_14d: GitHub's rolling 14-day totals on the date. Rows overlap, so do not sum them across rows. Unique counts are per window, so they cannot be added or de-duplicated either."
    echo "- Run the script at least every 14 days. GitHub keeps only 14 days of traffic, so a longer gap loses traffic for good."
    echo "- plugin_installs: entered by hand. Claude Code plugin marketplaces document no install-count API."
    echo "- skills_sh_installs: entered by hand. skills.sh documents an install-count API (https://www.skills.sh/docs/api), but it needs a short-lived Vercel OIDC token from a linked Vercel project (vercel link, then vercel env pull). This script does not automate that."
    echo "- site_visits: entered by hand. The website is not live."
    echo "- \`-\` means not recorded. It is not zero."
    echo
    echo "$COLUMNS_ROW"
    echo "$SEP_ROW"
    echo "$row"
  } > "$tmpfile"
fi

chmod 644 "$tmpfile"
mv "$tmpfile" "$out"
tmpfile=""
echo "$row"
