#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
check="$root/skills/publish-web/scripts/check-pwa.sh"
tmp="$(mktemp -d)"
server=""

stop() {
  if [ -n "$server" ]; then
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
    server=""
  fi
}
trap 'stop; rm -rf "$tmp"' EXIT

pass=0
total=0
failed=""

fail() {
  failed="$failed
FAIL $1: $2"
}

serve() {
  local i=0
  port=""
  python3 -u -m http.server --bind 127.0.0.1 --directory "$1" 0 >"$tmp/server.log" 2>&1 &
  server=$!
  while [ -z "$port" ] && [ "$i" -lt 100 ]; do
    port="$(sed -n 's/.* port \([0-9][0-9]*\).*/\1/p' "$tmp/server.log" | head -n 1)"
    [ -n "$port" ] || sleep 0.1
    i=$((i + 1))
  done
  if [ -z "$port" ]; then
    echo "error: python3 http.server did not start: $(cat "$tmp/server.log")" >&2
    exit 2
  fi
}

page() {
  printf '<!doctype html>\n<html>\n<head>\n<title>Todo</title>\n%s\n</head>\n<body><div id="app"></div></body>\n</html>\n' "$2" >"$1/index.html"
}

site() {
  local d="$tmp/$1"
  mkdir -p "$d"
  printf '{"name":"Todo","short_name":"Todo","start_url":"/","display":"standalone","icons":[%s]}\n' \
    '{"src":"/pwa-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/pwa-512x512.png","sizes":"512x512","type":"image/png"}' \
    >"$d/manifest.webmanifest"
  printf '\211PNG\r\n\032\n' >"$d/pwa-192x192.png"
  printf '\211PNG\r\n\032\n' >"$d/pwa-512x512.png"
  printf "self.addEventListener('fetch', () => {});\n" >"$d/sw.js"
  printf "if('serviceWorker' in navigator) {window.addEventListener('load', () => {navigator.serviceWorker.register('/sw.js', { scope: '/' })})}\n" >"$d/registerSW.js"
  page "$d" '<link rel="manifest" href="/manifest.webmanifest"><script id="vite-plugin-pwa:register-sw" src="/registerSW.js"></script>'
  dir="$d"
}

run_check() {
  serve "$dir"
  set +e
  out="$(bash "$check" --allow-http "http://127.0.0.1:$port/" 2>&1)"
  code=$?
  set -e
  stop
}

# expect <label> <exit> [line-regex...]: exit code, 12 check lines, and each regex matches a line.
expect() {
  local label="$1" want="$2" re lines seen
  shift 2
  total=$((total + 1))
  if [ "$code" -ne "$want" ]; then
    fail "$label" "want exit $want, got $code: $out"
    return
  fi
  lines="$(printf '%s\n' "$out" | grep -cE '^(PASS|FAIL) [a-z0-9-]+' || true)"
  if [ "$lines" -ne 12 ]; then
    fail "$label" "want 12 check lines, got $lines: $out"
    return
  fi
  for re in '^PASS html: ' "$@"; do
    case "$re" in
      *skipped*) seen="$out" ;;
      *) seen="$(printf '%s\n' "$out" | grep -v ': skipped: ' || true)" ;;
    esac
    if ! printf '%s\n' "$seen" | grep -qE -- "$re"; then
      fail "$label" "want a line matching '$re' in: $out"
      return
    fi
  done
  pass=$((pass + 1))
}

reg_line() {
  printf '^PASS service-worker-registration: http://127\\.0\\.0\\.1:%s%s \\(static scan\\)$' "$port" "$1"
}

raw_line() {
  printf '^FAIL service-worker-registration: a register\\( call appears only inside a comment, or inside code the static scanner could not parse: http://127\\.0\\.0\\.1:%s%s$' "$port" "$1"
}

site valid
run_check
expect "valid Vite-PWA page passes every check" 0 "$(reg_line /sw.js)"
total=$((total + 1))
if [ "$(printf '%s\n' "$out" | grep -c '^PASS ')" -eq 12 ]; then pass=$((pass + 1)); else fail "valid page prints 12 PASS lines" "$out"; fi

site inlinejs
page "$dir" '<script>var s="<!--";</script><link rel="manifest" href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "unclosed <!-- in an inline script does not hide later tags" 0 '^PASS manifest-link: ' "$(reg_line /sw.js)"

site inlinecss
page "$dir" '<STYLE>a::before{content:"<!--"}</STYLE><link rel="manifest" href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "unclosed <!-- in an inline style does not hide later tags" 0 '^PASS manifest-link: '

site commented
page "$dir" '<!-- <link rel="manifest" href="/manifest.webmanifest"> --><script src="/registerSW.js"></script>'
run_check
expect "manifest link inside an HTML comment is ignored" 1 '^FAIL manifest-link: ' '^FAIL manifest-json: skipped: ' "$(reg_line /sw.js)"

site oldsw
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><script>
// navigator.serviceWorker.register('/old-sw.js')
navigator.serviceWorker.register('/sw.js')
</script>"
run_check
expect "line-commented register call is skipped" 0 "$(reg_line /sw.js)"

site oldsw-block
printf "/* navigator.serviceWorker.register('/old-sw.js') */navigator.serviceWorker.register('/sw.js')\n" >"$dir/registerSW.js"
run_check
expect "block-commented register call in a loaded script is skipped" 0 "$(reg_line /sw.js)"

site globs
mkdir -p "$dir/app"
mv "$dir/sw.js" "$dir/app/sw.js"
printf "var a=\"image/*\";navigator.serviceWorker.register('/app/sw.js');var b=\"*/*\";var c=\"src/**/*.js\"\n" >"$dir/registerSW.js"
run_check
expect "/* inside string literals does not hide the register call" 0 "$(reg_line /app/sw.js)"

site oldsw-html
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><!-- <script>navigator.serviceWorker.register('/old-sw.js')</script> --><script src=\"/registerSW.js\"></script>"
run_check
expect "register call inside an HTML comment is skipped" 0 "$(reg_line /sw.js)"

site urlsw
mkdir -p "$dir/app"
mv "$dir/sw.js" "$dir/app/sw.js"
serve "$dir"
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><script>navigator.serviceWorker.register(\"http://127.0.0.1:$port/app/sw.js\")</script>"
set +e
out="$(bash "$check" --allow-http "http://127.0.0.1:$port/" 2>&1)"
code=$?
set -e
expect "// after a colon is a URL, not a comment" 0 "$(reg_line /app/sw.js)"
stop

appsw() {
  mkdir -p "$dir/app"
  mv "$dir/sw.js" "$dir/app/sw.js"
}

site oneline-url
appsw
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><style>@import url(//fonts.example/css?family=Roboto);</style><div style="background:url(//cdn.example/bg.png)"></div><script>navigator.serviceWorker.register("/app/sw.js")</script>'
run_check
expect "// in CSS and attributes is not a JS comment" 0 "$(reg_line /app/sw.js)"

site oneline-text
appsw
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><p>Help // FAQ</p><script>navigator.serviceWorker.register('/app/sw.js')</script>"
run_check
expect "// in HTML text is not a JS comment" 0 "$(reg_line /app/sw.js)"

site strsep
appsw
printf 'var sep=" // ";navigator.serviceWorker.register("/app/sw.js")\n' >"$dir/registerSW.js"
run_check
expect "// inside a string literal is kept" 0 "$(reg_line /app/sw.js)"

site regexlit
appsw
printf "const r=/[ /*]/;navigator.serviceWorker.register('/app/sw.js');const s=\"*/\";\n" >"$dir/registerSW.js"
run_check
expect "/* inside a regex literal is kept" 0 "$(reg_line /app/sw.js)"

site regexkeyword
appsw
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><script>function f(a){return/'/.test(a)}var u='https://x.example/';navigator.serviceWorker.register(\"/app/sw.js\")</script>"
run_check
expect "a regex literal after return is not division" 0 "$(reg_line /app/sw.js)"

site nestedtpl
appsw
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>var a=`${b?`https://x.example/`:""}`;navigator.serviceWorker.register("/app/sw.js")</script>'
run_check
expect "a template nested in \${} keeps string state" 0 "$(reg_line /app/sw.js)"

site parencomment
appsw
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><script>x()//navigator.serviceWorker.register('/old.js')
navigator.serviceWorker.register('/app/sw.js')</script>"
run_check
expect "// after ) is a comment" 0 "$(reg_line /app/sw.js)"

site parenregex
appsw
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><script>if(x)/'/.test(y);var u='https://x.example/';navigator.serviceWorker.register(\"/app/sw.js\")</script>"
run_check
expect "a call hidden by a regex after ) fails closed and the message names it" 1 "$(raw_line /app/sw.js)" '^FAIL service-worker-script: skipped: '

site parenregex-oldsw
appsw
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><!-- <script>navigator.serviceWorker.register('/old-sw.js')</script> --><script>if(x)/'/.test(y);var u='https://x.example/';navigator.serviceWorker.register(\"/app/sw.js\")</script>"
run_check
expect "the fail-closed message names the first raw-only URL" 1 "$(raw_line /old-sw.js)"

inferred_line() {
  printf '^PASS service-worker-registration: http://127\\.0\\.0\\.1:%s/sw\\.js \\(inferred from sw\\.js, static scan\\)$' "$port"
}

site inferred
printf "if('serviceWorker' in navigator) import('./pwa.js')\n" >"$dir/registerSW.js"
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script src="/lazy.js"></script>'
mv "$dir/registerSW.js" "$dir/lazy.js"
run_check
expect "a script that only mentions serviceWorker infers sw.js" 0 "$(inferred_line)"

site oldsw-deployed
printf 'self.x=1;\n' >"$dir/old-sw.js"
page "$dir" "<link rel=\"manifest\" href=\"/manifest.webmanifest\"><script>
// navigator.serviceWorker.register('/old-sw.js')
navigator.serviceWorker.register('/sw.js')
</script>"
run_check
expect "a commented call to a deployed old script is not picked over the live call" 0 "$(reg_line /sw.js)"

site comment-only-deployed
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>// navigator.serviceWorker.register("/sw.js")
console.log(1)</script>'
run_check
expect "a line-commented call fails even when its script is deployed" 1 "$(raw_line /sw.js)"

site html-comment-only-deployed
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><!-- <script>navigator.serviceWorker.register("/sw.js")</script> -->'
run_check
expect "an HTML-commented call fails even when its script is deployed" 1 "$(raw_line /sw.js)"

site live404-old-deployed
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>// navigator.serviceWorker.register("/sw.js")
navigator.serviceWorker.register("/new-sw.js")</script>'
run_check
expect "a live call to a missing script is reported, not the commented deployed one" 1 "$(reg_line /new-sw.js)" \
  '^FAIL service-worker-script: HTTP 404 from http://127\.0\.0\.1:[0-9]+/new-sw\.js$'

site live-first404
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>navigator.serviceWorker.register("/gone.js")</script><script src="/registerSW.js"></script>'
run_check
expect "the first live call served as JavaScript is reported" 0 "$(reg_line /sw.js)"

site onload-attr
page "$dir" '<link rel="manifest" href="/manifest.webmanifest">'
sed -i.bak "s|<body>|<body onload=\"navigator.serviceWorker.register('/sw.js')\">|" "$dir/index.html"
run_check
expect "a register call in an onload attribute is live JS" 0 "$(reg_line /sw.js)"
total=$((total + 1))
if [ "$(printf '%s\n' "$out" | grep -c '^PASS ')" -eq 12 ]; then pass=$((pass + 1)); else fail "onload-attr prints 12 PASS lines" "$out"; fi

site onload-attr-entities
page "$dir" '<link rel="manifest" href="/manifest.webmanifest">'
sed -i.bak 's|<body>|<body onload="navigator.serviceWorker.register(\&quot;/sw.js\&quot;)">|' "$dir/index.html"
run_check
expect "&quot; in an onload attribute is decoded before the scan" 0 "$(reg_line /sw.js)"

site onload-commented
page "$dir" '<link rel="manifest" href="/manifest.webmanifest">'
sed -i.bak "s|<body>|<body onload=\"/* navigator.serviceWorker.register('/old.js') */ navigator.serviceWorker.register('/sw.js')\">|" "$dir/index.html"
run_check
expect "a commented call in an onload attribute is skipped" 0 "$(reg_line /sw.js)"

site varurl-oldcomment
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>// navigator.serviceWorker.register("/old.js")
var u="/sw.js";navigator.serviceWorker.register(u)</script>'
run_check
expect "register(u) with a commented old call infers sw.js" 0 "$(inferred_line)"

site prose-registersw
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><p>registerSW.js</p>'
run_check
expect "registerSW.js in page text is not a registration" 1 \
  '^FAIL service-worker-registration: no navigator' '^FAIL service-worker-script: skipped: '

site attrgt-link
page "$dir" '<link title="1 > 0" rel="manifest" href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "> in a quoted attribute before rel does not hide the manifest link" 0 '^PASS manifest-link: http://127\.0\.0\.1:[0-9]+/manifest\.webmanifest$'

site attrlink-fake
page "$dir" "<div data-x='<link rel=\"manifest\" href=\"/manifest.webmanifest\">'></div><script src=\"/registerSW.js\"></script>"
run_check
expect "a manifest link inside an attribute value is not a link" 1 '^FAIL manifest-link: ' "$(reg_line /sw.js)"

site attrscript-src
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><div data-x="<script src=/registerSW.js></script>"></div>'
run_check
expect "a script tag inside an attribute value is not loaded" 1 '^FAIL service-worker-registration: no navigator'

site nospace-attr
page "$dir" '<link rel="manifest"href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "an attribute right after a quoted value is read" 0 '^PASS manifest-link: http://127\.0\.0\.1:[0-9]+/manifest\.webmanifest$'

site attrscript
page "$dir" '<div data-x="<script>"></div><!--<link rel="manifest" href="/manifest.webmanifest">--><script src="/registerSW.js"></script>'
run_check
expect "<script> inside a quoted attribute value is not a script tag" 1 '^FAIL manifest-link: ' "$(reg_line /sw.js)"

site attrgt
page "$dir" '<div title="1 > 0" data-x="<script>"></div><link rel="manifest" href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "> inside a quoted attribute value does not end the tag" 0 '^PASS manifest-link: ' "$(reg_line /sw.js)"

site unclosedscript
page "$dir" '<script src="/registerSW.js"></script><script>var a=1;<link rel="manifest" href="/manifest.webmanifest">'
run_check
expect "a manifest link after an unclosed <script> is script text, as in a browser" 1 '^FAIL manifest-link: ' "$(reg_line /sw.js)"

site selfclosescript
appsw
printf 'var y=1;\n' >"$dir/x.js"
page "$dir" '<script src="/x.js"/><link rel="manifest" href="/manifest.webmanifest"><!-- <script>navigator.serviceWorker.register("/old.js")</script> --><script>navigator.serviceWorker.register("/app/sw.js")</script>'
run_check
expect "<script/> does not self-close; the link after it is script text" 1 '^FAIL manifest-link: ' "$(reg_line /app/sw.js)"

site selfclose-registersw
printf 'var y=1;\n' >"$dir/x.js"
page "$dir" '<script src="/x.js"/><link rel="manifest" href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "registerSW.js named in script text is not a loaded script" 1 '^FAIL manifest-link: ' '^FAIL service-worker-registration: ' '^FAIL service-worker-script: skipped: '

site multilineblock
appsw
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>
/* old:
navigator.serviceWorker.register("/old.js")
*/
navigator.serviceWorker.register("/app/sw.js")
</script>'
run_check
expect "a multi-line block comment hides the old register call" 0 "$(reg_line /app/sw.js)"

site commentstar
appsw
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>/* a "*/" b */navigator.serviceWorker.register("/app/sw.js")</script>'
run_check
expect "a quote inside a block comment does not open a string" 0 "$(reg_line /app/sw.js)"

site upperscript
appsw
page "$dir" '<SCRIPT TYPE=module>var s="<!--";</SCRIPT><link rel="manifest" href="/manifest.webmanifest"><script>navigator.serviceWorker.register("/app/sw.js")</script>'
run_check
expect "an upper-case <SCRIPT> with an unquoted attribute is a script tag" 0 '^PASS manifest-link: ' "$(reg_line /app/sw.js)"

site strsep-inline
appsw
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script>var sep=" // ";navigator.serviceWorker.register("/app/sw.js")</script>'
run_check
expect "// inside a string literal in an inline script is kept" 0 "$(reg_line /app/sw.js)"

site fakeclose
page "$dir" '<script>const s="</scripture><!--";</script><link rel="manifest" href="/manifest.webmanifest"><script src="/registerSW.js"></script>'
run_check
expect "</scripture> does not close a script" 0 '^PASS manifest-link: ' "$(reg_line /sw.js)"

site crossscript
appsw
printf 'var s="/*";var b=1;/*\n' >"$dir/a.js"
printf "navigator.serviceWorker.register('/app/sw.js')\n" >"$dir/b.js"
page "$dir" '<link rel="manifest" href="/manifest.webmanifest"><script src="/a.js"></script><script src="/b.js"></script>'
run_check
expect "an unclosed /* in one script does not hide the next script" 0 "$(reg_line /app/sw.js)"

site noicon
printf '{"name":"Todo","start_url":"/","display":"standalone","icons":[{"src":"/pwa-192x192.png","sizes":"192x192","type":"image/png"}]}\n' >"$dir/manifest.webmanifest"
run_check
expect "missing 512x512 icon fails" 1 '^FAIL icon-512x512: ' '^PASS icon-192x192: '

site nosw
rm "$dir/registerSW.js" "$dir/sw.js"
page "$dir" '<link rel="manifest" href="/manifest.webmanifest">'
run_check
expect "page without a registration fails" 1 '^FAIL service-worker-registration: ' '^FAIL service-worker-script: skipped: '

if [ "$pass" -eq "$total" ]; then
  echo "PASS $pass/$total"
  exit 0
fi
printf '%s\n' "$failed"
echo "FAIL $((total - pass))/$total"
exit 1
