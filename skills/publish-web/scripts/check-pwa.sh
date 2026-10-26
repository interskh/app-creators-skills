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

for tool in curl grep sed awk head od tr cp cat mktemp rm; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: check-pwa.sh needs $tool" >&2
    exit 2
  fi
done
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

skip() {
  local reason="$1" c
  shift
  for c in "$@"; do
    fail "$c" "skipped: $reason"
  done
}

code=000
final=""
ctype=""
mime=""
curl_rc=0
curl_err=""
fetch() {
  local w rest
  curl_rc=0
  : >"$2"
  w="$(curl -sS -L --max-time 15 --max-redirs 10 -o "$2" \
    -w '%{http_code}\t%{url_effective}\t%{content_type}' "$1" 2>"$tmp/curl.err")" || curl_rc=$?
  code="${w%%$'\t'*}"
  rest="${w#*$'\t'}"
  final="${rest%%$'\t'*}"
  ctype="${rest#*$'\t'}"
  [ "$ctype" != "$w" ] || ctype=""
  [ -n "$code" ] || code=000
  [ -n "$final" ] || final="$1"
  mime="$(printf '%s' "${ctype%%;*}" | tr 'A-Z' 'a-z' | tr -d ' ')"
  curl_err=""
  if [ "$curl_rc" -ne 0 ]; then
    curl_err="curl exit $curl_rc: $(head -n 1 "$tmp/curl.err")"
  fi
}

fetched() {
  [ "$curl_rc" -eq 0 ] && [ "$code" = 200 ]
}

why() {
  if [ "$code" = 000 ]; then
    printf 'no response from %s (%s)' "$1" "$curl_err"
  elif [ "$curl_rc" -ne 0 ]; then
    printf 'transfer from %s failed after HTTP %s (%s)' "$final" "$code" "$curl_err"
  else
    printf 'HTTP %s from %s' "$code" "$final"
  fi
}

is_js_mime() {
  case "$1" in
    application/ecmascript | application/javascript | application/x-ecmascript | application/x-javascript | \
      text/ecmascript | text/javascript | text/javascript1.[0-5] | text/jscript | text/livescript | \
      text/x-ecmascript | text/x-javascript) return 0 ;;
  esac
  return 1
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

js_awk='
  function js_reset() {
    st = ""; esc = 0; cls = 0; prev = ""; word = ""; inw = 0; sp = 0
    idc = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$"
    kw = " return typeof instanceof in of new delete void throw case do else yield await "
  }
  function js(ch, from, to,   i, c, d) {
    for (i = from; i <= to; i++) {
      c = ch[i]
      d = i < to ? ch[i + 1] : ""
      if (st == "") {
        if (c == "/" && (d == "/" || d == "*")) {
          st = d == "/" ? "line" : "block"
          i++
          inw = 0
          printf " "
          continue
        }
        printf "%s", c
        if (c == "\"" || c == q || c == "`") st = c
        else if (c == "/" && (prev == "" || index("(,=:[!&|?{};", prev) || (index(idc, prev) && index(kw, " " word " ")))) { st = "re"; cls = 0 }
        else if (c == "{" && sp) dep[sp]++
        else if (c == "}" && sp) { if (dep[sp]) dep[sp]--; else { sp--; st = "`" } }
        if (index(idc, c)) { word = inw ? word c : c; inw = 1 } else inw = 0
        if (c !~ /[[:space:]]/) prev = c
        continue
      }
      if (st == "line") {
        if (c == "\n") { st = ""; printf "\n" }
        continue
      }
      if (st == "block") {
        if (c == "*" && d == "/") { st = ""; i++ }
        else if (c == "\n") printf "\n"
        continue
      }
      printf "%s", c
      if (esc) { esc = 0; continue }
      if (c == "\\") { esc = 1; continue }
      if (st == "re") {
        if (c == "\n") st = ""
        else if (cls) { if (c == "]") cls = 0 }
        else if (c == "[") cls = 1
        else if (c == "/") { st = ""; prev = c }
        continue
      }
      if (st == "`" && c == "$" && d == "{") {
        printf "{"
        i++
        dep[++sp] = 0
        st = ""
        prev = "{"
        continue
      }
      if (c == st) { st = ""; prev = c }
      else if (c == "\n" && st != "`") st = ""
    }
  }
'

strip_comments() {
  LC_ALL=C awk -v q="'" -v tags="$2" "$js_awk"'
    function put(a, b, both,   m, x, y, t) {
      while (a <= b) {
        m = int((a - 1) / B) + 1
        x = a - (m - 1) * B
        y = b - (m - 1) * B
        if (y > B) y = B
        t = substr(blk[m], x, y - x + 1)
        printf "%s", t
        if (both) printf "%s", t > tags
        a += y - x + 1
      }
    }
    function closer(k, name,   len, m, p, w, x, c) {
      len = length(name)
      while (k <= n) {
        m = int((k - 1) / B) + 1
        p = index(substr(blk[m], k - (m - 1) * B) substr(blk[m + 1], 1, 1), "</")
        if (!p) { k = m * B + 1; continue }
        k += p - 1
        w = ""
        for (x = k + 2; x < k + 2 + len; x++) w = w hc[x]
        c = hc[k + 2 + len]
        if (tolower(w) == name && c != "" && index(" \t\n\r\f/>", c)) return k
        k++
      }
      return n + 1
    }
    BEGIN { B = 8192 }
    {
      t = $0 "\n"
      if (NR == 1) n = split(t, hc, "")
      else {
        m = split(t, tc, "")
        for (x = 1; x <= m; x++) hc[++n] = tc[x]
      }
      while (t != "") {
        need = B - length(cur)
        cur = cur substr(t, 1, need)
        t = substr(t, need + 1)
        if (length(cur) == B) { blk[++nb] = cur; cur = "" }
      }
    }
    END {
      if (cur != "") blk[++nb] = cur
      printf "" > tags
      alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
      i = 1
      from = 1
      while (i <= n) {
        if (hc[i] != "<") { i++; continue }
        if (hc[i + 1] == "!" && hc[i + 2] == "-" && hc[i + 3] == "-") {
          put(from, i - 1, 1)
          for (j = i + 4; j + 2 <= n && !(hc[j] == "-" && hc[j + 1] == "-" && hc[j + 2] == ">"); j++) ;
          if (j + 2 > n) { from = n + 1; break }
          i = j + 3
          from = i
          continue
        }
        if (!index(alpha "/", hc[i + 1])) { i++; continue }
        eq = 0
        qt = ""
        for (j = i + 1; j <= n; j++) {
          c = hc[j]
          if (qt != "") { if (c == qt) qt = "" ; continue }
          if (c == ">") break
          if (index(" \t\n\r\f", c)) continue
          if (eq && (c == "\"" || c == q)) qt = c
          eq = c == "="
        }
        if (j > n) break
        name = ""
        for (k = i + 1; k < j && !index(" \t\n\r\f/", hc[k]); k++) name = name hc[k]
        name = tolower(name)
        if (name != "script" && name != "style") { i = j + 1; continue }
        put(from, j, 1)
        b = j + 1
        k = closer(b, name)
        if (name == "script") {
          js_reset()
          js(hc, b, k - 1)
        } else {
          put(b, k - 1, 0)
        }
        i = k
        from = k
      }
      put(from, n, 1)
    }
  ' "$1"
}

strip_js_comments() {
  LC_ALL=C awk -v q="'" "$js_awk"'
    BEGIN { js_reset() }
    { n = split($0 "\n", lc, ""); js(lc, 1, n) }
  ' "$1"
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
manifest_checks="manifest-name manifest-start-url manifest-display manifest-prefer-related-applications icon-192x192 icon-512x512"
fetch "$url" "$tmp/page.raw.html"
page_url="$final"
if ! fetched; then
  fail html "$(why "$url")"
  skip "HTML not fetched" manifest-link manifest-json $manifest_checks service-worker-registration service-worker-script
  exit 1
fi
strip_comments "$tmp/page.raw.html" "$tmp/page.tags.html" >"$tmp/page.html"
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
href="$(html_tags manifest "$tmp/page.tags.html")"
if [ -z "$href" ]; then
  fail manifest-link 'no <link rel="manifest" href="..."> in the HTML'
  skip "no manifest link" manifest-json $manifest_checks
else
  manifest_url="$(resolve_url "$page_url" "$href")"
  pass "manifest-link: $manifest_url"
  fetch "$manifest_url" "$tmp/manifest.json"
  manifest_url="$final"
  if ! fetched; then
    fail manifest-json "$(why "$manifest_url")"
      skip "manifest not fetched" $manifest_checks
  else
    read_manifest "$tmp/manifest.json" >"$tmp/manifest.tsv"
    err="$(field parse_error)"
    if [ -n "$err" ]; then
      fail manifest-json "$manifest_url is not valid JSON ($err)"
          skip "manifest is not valid JSON" $manifest_checks
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
        if ! fetched; then
          fail "icon-$size" "$(why "$icon_url")"
        elif [ "$mime" = text/html ]; then
          fail "icon-$size" "$icon_url is served as text/html; a rewrite answers for the icon"
        elif [ "${mime#image/}" != "$mime" ] || [ "$(head -c 4 "$tmp/icon" | od -An -tx1 | tr -d ' \n')" = 89504e47 ]; then
          pass "icon-$size: $icon_url"
        else
          fail "icon-$size" "$icon_url is served as '${mime:-no content-type}', not an image"
        fi
      done
    fi
  fi
fi

# 4. Service worker
cp "$tmp/page.html" "$tmp/haystack"
cp "$tmp/page.raw.html" "$tmp/haystack.raw"
n=0
while IFS= read -r src; do
  [ -n "$src" ] || continue
  n=$((n + 1))
  [ "$n" -le 10 ] || break
  fetch "$(resolve_url "$page_url" "$src")" "$tmp/script"
  if fetched; then
    printf '\n' >>"$tmp/haystack"
    strip_js_comments "$tmp/script" >>"$tmp/haystack"
    printf '\n' >>"$tmp/haystack.raw"
    cat "$tmp/script" >>"$tmp/haystack.raw"
  fi
done < <(html_tags scripts "$tmp/page.tags.html")

register_refs() {
  (grep -oE "serviceWorker\.register\([[:space:]]*[\"'][^\"']+[\"']" "$1" || true) |
    sed -E "s/^serviceWorker\.register\([[:space:]]*[\"']//; s/[\"']$//"
}

candidates="$({ register_refs "$tmp/haystack"; register_refs "$tmp/haystack.raw"; } |
  awk '$0 != "" && !seen[$0]++' | head -n 5)"
first="$(printf '%s\n' "$candidates" | head -n 1)"
sw_url=""
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  u="$(resolve_url "$page_url" "$ref")"
  fetch "$u" "$tmp/sw.js"
  if fetched && is_js_mime "$mime"; then
    sw_url="$u"
    break
  fi
done <<<"$candidates"

sw_script_check() {
  if ! fetched; then
    fail service-worker-script "$(why "$1")"
  elif is_js_mime "$mime"; then
    pass "service-worker-script: $1 ($mime)"
  elif [ "$mime" = text/html ]; then
    fail service-worker-script "$1 is served as text/html; a rewrite or fallback page answers for the script"
  else
    fail service-worker-script "$1 is served as '${mime:-no content-type}'; browsers register only scripts with a JavaScript MIME type"
  fi
}

report_first() {
  sw_url="$(resolve_url "$page_url" "${first:-sw.js}")"
  pass "service-worker-registration: $sw_url (static scan)"
  fetch "$sw_url" "$tmp/sw.js"
  sw_script_check "$sw_url"
}

if [ -n "$sw_url" ]; then
  pass "service-worker-registration: $sw_url (static scan)"
  sw_script_check "$sw_url"
elif grep -q 'serviceWorker\.register(' "$tmp/haystack" || grep -q 'registerSW\.js' "$tmp/page.tags.html"; then
  report_first
elif grep -q 'serviceWorker' "$tmp/haystack"; then
  sw_url="$(resolve_url "$page_url" sw.js)"
  fetch "$sw_url" "$tmp/sw.js"
  if fetched && is_js_mime "$mime"; then
    pass "service-worker-registration: $sw_url (inferred from sw.js, static scan)"
  else
    fail service-worker-registration "the page mentions serviceWorker but has no register( call, and $sw_url is not a JavaScript file"
  fi
  sw_script_check "$sw_url"
elif [ -n "$first" ]; then
  report_first
else
  fail service-worker-registration "no navigator.serviceWorker.register( call or registerSW.js in the page or its scripts"
  skip "no registration found" service-worker-script
fi

if [ "$fails" -gt 0 ]; then
  exit 1
fi
exit 0
