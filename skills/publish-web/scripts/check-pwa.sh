#!/usr/bin/env bash
# Check that a deployed web app is an installable PWA.
# usage: check-pwa.sh [--allow-http] <url>
# Prints one line per check, "PASS <check>" or "FAIL <check>: <reason>".
# Exit 0 when every check passes, 1 on any FAIL, 2 on usage or missing tools.
set -euo pipefail

usage() {
  echo "usage: check-pwa.sh [--allow-http] <url>" >&2
  exit 2
}

allow_http=0
url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow-http) allow_http=1 ;;
    -*) usage ;;
    *)
      [ -z "$url" ] || usage
      url="$1"
      ;;
  esac
  shift
done
[ -n "$url" ] || usage
case "$url" in
  http://* | https://*) ;;
  *)
    echo "error: URL must start with https:// (or http:// with --allow-http)" >&2
    exit 2
    ;;
esac

if ! command -v curl >/dev/null 2>&1; then
  echo "error: check-pwa.sh needs curl" >&2
  exit 2
fi
if command -v node >/dev/null 2>&1; then
  json_tool=node
elif command -v jq >/dev/null 2>&1; then
  json_tool=jq
else
  echo "error: check-pwa.sh needs node or jq to read the manifest JSON; install Node.js or jq" >&2
  exit 2
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/check-pwa.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fails=0
pass() { printf 'PASS %s\n' "$1"; }
fail() {
  printf 'FAIL %s: %s\n' "$1" "$2"
  fails=$((fails + 1))
}

code=000
final=""
ctype=""
curl_err=""
fetch() {
  local w rc=0 rest
  : >"$2"
  w="$(curl -sS -L --max-time 15 --max-redirs 10 -o "$2" \
    -w '%{http_code}\t%{url_effective}\t%{content_type}' "$1" 2>"$tmp/curl.err")" || rc=$?
  code="${w%%$'\t'*}"
  rest="${w#*$'\t'}"
  final="${rest%%$'\t'*}"
  ctype="${rest#*$'\t'}"
  [ -n "$code" ] || code=000
  [ -n "$final" ] || final="$1"
  curl_err=""
  if [ "$rc" -ne 0 ]; then
    curl_err="curl exit $rc: $(head -n 1 "$tmp/curl.err")"
  fi
}

why() {
  if [ "$code" = 000 ]; then
    printf 'no response from %s (%s)' "$1" "$curl_err"
  else
    printf 'HTTP %s from %s' "$code" "$final"
  fi
}

normalize_path() {
  local p="$1" seg out="" trail=""
  local -a parts stack
  stack=()
  case "$p" in */ | */. | */..) trail="/" ;; esac
  IFS=/ read -ra parts <<<"$p"
  for seg in ${parts[@]+"${parts[@]}"}; do
    case "$seg" in
      "" | .) ;;
      ..)
        if [ "${#stack[@]}" -gt 0 ]; then
          unset "stack[$((${#stack[@]} - 1))]"
        fi
        ;;
      *) stack+=("$seg") ;;
    esac
  done
  for seg in ${stack[@]+"${stack[@]}"}; do
    out="$out/$seg"
  done
  if [ -z "$out" ]; then
    printf '/'
  elif [ -n "$trail" ]; then
    printf '%s/' "$out"
  else
    printf '%s' "$out"
  fi
}

resolve_url() {
  local base="$1" ref="${2%%#*}" scheme rest host path query=""
  scheme="${base%%://*}"
  rest="${base#*://}"
  rest="${rest%%#*}"
  host="${rest%%[/?]*}"
  path="${rest#"$host"}"
  path="${path%%\?*}"
  [ -n "$path" ] || path="/"
  case "$ref" in
    *\?*) query="?${ref#*\?}"; ref="${ref%%\?*}" ;;
  esac
  case "$ref" in
    [a-zA-Z]*://*) printf '%s%s' "$ref" "$query"; return ;;
    //*) printf '%s:%s%s' "$scheme" "$ref" "$query"; return ;;
    /*) path="$ref" ;;
    "") ;;
    *) path="${path%/*}/$ref" ;;
  esac
  printf '%s://%s%s%s' "$scheme" "$host" "$(normalize_path "$path")" "$query"
}

html_tags() {
  LC_ALL=C awk -v mode="$1" -v q="'" '
    function attr(tag, low, name,   re, v, c, i) {
      re = "[[:space:]]" name "[[:space:]]*=[[:space:]]*"
      if (!match(low, re)) return ""
      v = substr(tag, RSTART + RLENGTH)
      c = substr(v, 1, 1)
      if (c == "\"" || c == q) {
        v = substr(v, 2)
        i = index(v, c)
        return i ? substr(v, 1, i - 1) : v
      }
      sub(/[[:space:]].*/, "", v)
      return v
    }
    BEGIN { RS = "<" }
    {
      tag = $0
      i = index(tag, ">")
      if (i) tag = substr(tag, 1, i - 1)
      gsub(/[\t\r\n]/, " ", tag)
      low = tolower(tag)
      if (mode == "manifest" && low ~ /^link[[:space:]]/) {
        n = split(attr(tag, low, "rel"), rels, /[[:space:]]+/)
        for (j = 1; j <= n; j++) {
          if (tolower(rels[j]) == "manifest") { print attr(tag, low, "href"); exit }
        }
      }
      if (mode == "scripts" && low ~ /^script[[:space:]]/) {
        s = attr(tag, low, "src")
        if (s != "") print s
      }
    }
  ' "$2"
}

read_manifest() {
  if [ "$json_tool" = node ]; then
    node -e '
      const fs = require("fs");
      const out = (k, v) => console.log(k + "\t" + String(v).replace(/[\t\r\n]/g, " "));
      let m;
      try {
        m = JSON.parse(fs.readFileSync(process.argv[1], "utf8").replace(/^\uFEFF/, ""));
      } catch (e) {
        out("parse_error", String(e.message).split("\n")[0]);
        process.exit(0);
      }
      if (!m || typeof m !== "object" || Array.isArray(m)) {
        out("parse_error", "not a JSON object");
        process.exit(0);
      }
      const str = (v) => (typeof v === "string" ? v : "");
      const toks = (v) => str(v).split(/\s+/).filter(Boolean);
      const png = (i) => {
        const t = str(i.type).toLowerCase();
        return t === "image/png" || (t === "" && /\.png$/i.test(i.src.split(/[?#]/)[0]));
      };
      const anyPurpose = (i) => i.purpose === undefined || i.purpose === null || toks(i.purpose).includes("any");
      const pick = (size) => {
        const icons = Array.isArray(m.icons) ? m.icons : [];
        const hit = icons.find((i) => i && typeof i === "object" && typeof i.src === "string" &&
          toks(i.sizes).map((s) => s.toLowerCase()).includes(size) && png(i) && anyPurpose(i));
        return hit ? hit.src : "";
      };
      out("name", str(m.name));
      out("short_name", str(m.short_name));
      out("start_url", typeof m.start_url === "string" ? "present" : "");
      out("display", str(m.display));
      out("prefer", m.prefer_related_applications === true ? "true" : "");
      out("icon_192x192", pick("192x192"));
      out("icon_512x512", pick("512x512"));
    ' "$1"
  else
    jq -r '
      def str: if type == "string" then gsub("[\t\r\n]"; " ") else "" end;
      def toks: str | split(" ") | map(select(. != ""));
      def png: ((.type | str | ascii_downcase) as $t
        | $t == "image/png" or ($t == "" and (.src | split("?")[0] | split("#")[0] | ascii_downcase | endswith(".png"))));
      def anypurpose: .purpose == null or ((.purpose | toks | index(["any"])) != null);
      def pick($size): [(.icons | if type == "array" then .[] else empty end)
        | select(type == "object" and (.src | type) == "string"
          and ((.sizes | toks | map(ascii_downcase) | index([$size])) != null) and png and anypurpose)]
        | (.[0].src // "") | str;
      if type != "object" then "parse_error\tnot a JSON object" else
        "name\t\(.name | str)",
        "short_name\t\(.short_name | str)",
        "start_url\t\(if (.start_url | type) == "string" then "present" else "" end)",
        "display\t\(.display | str)",
        "prefer\t\(if .prefer_related_applications == true then "true" else "" end)",
        "icon_192x192\t\(pick("192x192"))",
        "icon_512x512\t\(pick("512x512"))"
      end
    ' "$1" 2>/dev/null || printf 'parse_error\tjq could not parse the manifest as JSON\n'
  fi
}

field() {
  awk -F'\t' -v k="$1" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }' "$tmp/manifest.tsv"
}

# 1. HTTPS
case "$url" in
  https://*) pass https ;;
  *)
    if [ "$allow_http" -eq 1 ]; then
      pass "https: http allowed by --allow-http"
    else
      fail https "$url is not https; deploy over HTTPS (use --allow-http only for a local preview)"
    fi
    ;;
esac

# 2. HTML
fetch "$url" "$tmp/page.html"
page_url="$final"
if [ "$code" != 200 ]; then
  fail html "$(why "$url")"
  fail manifest-link "skipped: HTML not fetched"
  fail service-worker-registration "skipped: HTML not fetched"
  exit 1
fi
case "$url $page_url" in
  https://*" http://"*)
    if [ "$allow_http" -eq 1 ]; then
      pass "html: 200 $page_url"
    else
      fail html "$url redirects to $page_url, which is not https"
    fi
    ;;
  *) pass "html: 200 $page_url" ;;
esac

# 3. Manifest link, fetch, and members
href="$(html_tags manifest "$tmp/page.html")"
if [ -z "$href" ]; then
  fail manifest-link 'no <link rel="manifest" href="..."> in the HTML'
else
  manifest_url="$(resolve_url "$page_url" "$href")"
  pass "manifest-link: $manifest_url"
  fetch "$manifest_url" "$tmp/manifest.json"
  manifest_url="$final"
  if [ "$code" != 200 ]; then
    fail manifest-json "$(why "$manifest_url")"
  else
    read_manifest "$tmp/manifest.json" >"$tmp/manifest.tsv"
    err="$(field parse_error)"
    if [ -n "$err" ]; then
      fail manifest-json "$manifest_url is not valid JSON ($err)"
    else
      pass manifest-json
      if [ -n "$(field name)$(field short_name)" ]; then
        pass manifest-name
      else
        fail manifest-name "name and short_name are both missing or empty"
      fi
      if [ -n "$(field start_url)" ]; then
        pass manifest-start-url
      else
        fail manifest-start-url "start_url is missing"
      fi
      display="$(field display)"
      case "$display" in
        standalone | fullscreen | minimal-ui) pass "manifest-display: $display" ;;
        *) fail manifest-display "display is '${display}'; use standalone, fullscreen, or minimal-ui" ;;
      esac
      if [ -z "$(field prefer)" ]; then
        pass manifest-prefer-related-applications
      else
        fail manifest-prefer-related-applications "prefer_related_applications is true; browsers offer the store app instead of installing the PWA"
      fi
      for size in 192x192 512x512; do
        src="$(field "icon_$size")"
        if [ -z "$src" ]; then
          fail "icon-$size" "no icons entry with sizes $size, a PNG type or .png src, and purpose any or unset"
          continue
        fi
        icon_url="$(resolve_url "$manifest_url" "$src")"
        fetch "$icon_url" "$tmp/icon"
        if [ "$code" = 200 ]; then
          pass "icon-$size: $icon_url"
        else
          fail "icon-$size" "$(why "$icon_url")"
        fi
      done
    fi
  fi
fi

# 4. Service worker
cp "$tmp/page.html" "$tmp/haystack"
found=0
if grep -qE 'navigator\.serviceWorker|serviceWorker\.register\(|registerSW\.js' "$tmp/page.html"; then
  found=1
fi
n=0
while IFS= read -r src; do
  [ -n "$src" ] || continue
  n=$((n + 1))
  [ "$n" -le 10 ] || break
  fetch "$(resolve_url "$page_url" "$src")" "$tmp/script"
  if [ "$code" = 200 ]; then
    cat "$tmp/script" >>"$tmp/haystack"
    if grep -q 'serviceWorker\.register(' "$tmp/script"; then
      found=1
    fi
  fi
done < <(html_tags scripts "$tmp/page.html")

if [ "$found" -eq 0 ]; then
  fail service-worker-registration "no navigator.serviceWorker.register( call or registerSW.js in the page or its scripts"
  fail service-worker-script "skipped: no registration found"
else
  sw_ref="$( (grep -oE "serviceWorker\.register\([[:space:]]*[\"'][^\"']+[\"']" "$tmp/haystack" || true) |
    head -n 1 | sed -E "s/^serviceWorker\.register\([[:space:]]*[\"']//; s/[\"']$//")"
  [ -n "$sw_ref" ] || sw_ref="sw.js"
  sw_url="$(resolve_url "$page_url" "$sw_ref")"
  pass "service-worker-registration: $sw_url"
  fetch "$sw_url" "$tmp/sw.js"
  lc="$(printf '%s' "$ctype" | tr 'A-Z' 'a-z')"
  if [ "$code" != 200 ]; then
    fail service-worker-script "$(why "$sw_url")"
  else
    case "$lc" in
      *javascript* | *ecmascript*) pass "service-worker-script: $sw_url ($ctype)" ;;
      *text/html*) fail service-worker-script "$sw_url is served as text/html; a rewrite or fallback page answers for the script" ;;
      *)
        if [ -s "$tmp/sw.js" ]; then
          pass "service-worker-script: $sw_url (${ctype:-no content-type})"
        else
          fail service-worker-script "$sw_url returned an empty body"
        fi
        ;;
    esac
  fi
fi

if [ "$fails" -gt 0 ]; then
  exit 1
fi
exit 0
