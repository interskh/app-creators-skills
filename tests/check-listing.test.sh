#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd -P)"
check="$root/skills/store-listing/scripts/check-listing.py"
limits="$root/skills/store-listing/references/limits.md"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0
total=0
failed=""
out=""
err=""
code=0
esc="$(printf '\033')"
rlo="$(printf '\342\200\256')"
link='[x](https://example.com/a)'
header='| store | kind | id | rule | required | source | checked |
|---|---|---|---|---|---|---|'

fail() {
  failed="$failed
FAIL $1: $2"
}

# pngh <path> <w> <h> <colour type> [trns|text-idat|text-trns|big]: signature, IHDR, the variant's chunks, IDAT. big pushes IDAT past the prefix.
pngh() {
  mkdir -p "$(dirname "$1")"
  python3 -I -c 'import struct,sys,zlib
p,w,h,c=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4])
x=sys.argv[5] if len(sys.argv)>5 else ""
ch=lambda t,d:struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
s=b"\x89PNG\r\n\x1a\n"+ch(b"IHDR",struct.pack(">IIBBBBB",w,h,8,c,0,0,0))
s+=ch(b"tEXt",b"note\0IDAT")+ch(b"tRNS",b"\x00") if x=="text-idat" else b""
s+=ch(b"tEXt",b"note\0tRNS") if x=="text-trns" else b""
s+=ch(b"tRNS",b"\x00") if x=="trns" else b""
s+=ch(b"iTXt",bytes(1<<20))+ch(b"tRNS",b"\x00") if x=="big" else b""
s+=ch(b"IDAT",b"\x00")
open(p,"wb").write(s)' "$@"
}

# jpeg <path> <w> <h> <sof marker hex> <full APP segments before SOF>: a DHT segment, the APP segments, then SOF.
jpeg() {
  mkdir -p "$(dirname "$1")"
  python3 -I -c 'import struct,sys
p,w,h,m,n=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4],16),int(sys.argv[5])
seg=lambda k,d:bytes([0xFF,k])+struct.pack(">H",len(d)+2)+d
s=b"\xff\xd8"+seg(0xC4,bytes(20))+seg(0xE1,bytes(65533))*n
s+=seg(m,b"\x08"+struct.pack(">HH",h,w)+b"\x03"+bytes(9))
open(p,"wb").write(s+b"\xff\xd9")' "$@"
}

listing() {
  mkdir -p "$1/.app-creators"
  printf '%s\n' "$2" >"$1/.app-creators/listing.md"
}

# shot <dir> <device_class> <path> [size]: a listing with one screenshot row on the synthetic store.
shot() {
  listing "$1" '---
schema: "1.0"
stores:
  s:
    en: { req: "x" }
screenshots:
  - { store: s, device_class: "'"$2"'", path: "'"$3"'", size: "'"${4:-}"'" }
---'
}

run_check() {
  set +e
  out="$(python3 -I "$check" "$@" 2>"$tmp/stderr")"
  code=$?
  set -e
  err="$(cat "$tmp/stderr")"
}

# run_watched: the same run, killed after 10 seconds with exit 124, so a blocking open cannot hang the suite.
run_watched() {
  set +e
  out="$(python3 -I -c 'import subprocess,sys
try:
    sys.exit(subprocess.run(sys.argv[1:],timeout=10).returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)' python3 -I "$check" "$@" 2>"$tmp/stderr")"
  code=$?
  set -e
  err="$(cat "$tmp/stderr")"
}

# expect <label> <exit> [line-regex...]: exit code, no traceback, line format, each regex hits a line.
# A regex starting with ! must hit no line.
expect() {
  local label="$1" want="$2" re bad=""
  shift 2
  total=$((total + 1))
  [ "$code" = "$want" ] || bad="exit $code, wanted $want"
  case "$err" in
    *Traceback*) bad="$bad; traceback" ;;
    *) ;;
  esac
  if [ -n "$out" ] && printf '%s\n' "$out" | grep -Evq '^(PASS .+: |UNKNOWN .+: |FAIL .+: .*; fix: )'; then
    bad="$bad; malformed line"
  fi
  for re in "$@"; do
    case "$re" in
      !*)
        if printf '%s\n' "$out" | grep -Eq -- "${re#!}"; then
          bad="$bad; unwanted '${re#!}'"
        fi
        ;;
      *)
        if ! printf '%s\n' "$out" | grep -Eq -- "$re"; then
          bad="$bad; no line '$re'"
        fi
        ;;
    esac
  done
  if [ -z "$bad" ]; then
    pass=$((pass + 1))
  else
    fail "$label" "$bad; out: $out; err: $err"
  fi
}

# stops <label> <stderr-regex>: exit 2, empty stdout, no traceback, stderr matches.
stops() {
  local label="$1" re="$2" bad=""
  total=$((total + 1))
  [ "$code" = 2 ] || bad="exit $code, wanted 2"
  [ -z "$out" ] || bad="$bad; stdout not empty"
  case "$err" in
    *Traceback*) bad="$bad; traceback" ;;
    *) ;;
  esac
  printf '%s\n' "$err" | grep -Eq -- "$re" || bad="$bad; stderr lacks '$re'"
  if [ -z "$bad" ]; then
    pass=$((pass + 1))
  else
    fail "$label" "$bad; out: $out; err: $err"
  fi
}

# shape <label> <key path> <listing text>: the shape check rejects it, naming the key path.
shape() {
  local d="$tmp/rej"
  rm -rf "$d"
  listing "$d" "$3"
  run_check "$d" --limits "$syn"
  stops "shape: $1" "^$2: "
}

# rej <label> <line> <listing text>: the reader rejects it on that line.
rej() {
  local d="$tmp/rej"
  rm -rf "$d"
  listing "$d" "$3"
  run_check "$d" --limits "$syn"
  stops "reader: $1" "^line $2: "
}

# bad_limits <label> <table text> [stderr-regex]
bad_limits() {
  printf '%s\n' "$2" >"$tmp/bad.md"
  run_check "$base" --limits "$tmp/bad.md"
  stops "limits: $1" "${3:-limits}"
}

clean() {
  total=$((total + 1))
  case "$out$err" in
    *"$esc"* | *"$rlo"*)
      fail "$1" "raw control or format character printed"
      ;;
    *)
      if [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" != "$2" ]; then
        fail "$1" "wanted $2 output lines: $out"
      else
        pass=$((pass + 1))
      fi
      ;;
  esac
}

# table_rows <file>: read the table without the script: store|kind|id|rule|required|source|checked.
table_rows() {
  python3 -I -c 'import sys
head="| store | kind | id | rule | required | source | checked |"
ls=open(sys.argv[1],encoding="utf-8").read().split("\n")
i=ls.index(head)+2
while ls[i].startswith("|"):
    print("|".join(c.strip() for c in ls[i].split("|")[1:8]))
    i+=1' "$1"
}

# fill <limits> <out dir> <target store|key|locale or -> <delta>: every field at its limit, the target at limit+delta, in en and zh.
fill() {
  mkdir -p "$2/.app-creators"
  python3 -I -c 'import json,sys
src,out,target,delta=sys.argv[1],sys.argv[2],sys.argv[3],int(sys.argv[4])
ls=open(src,encoding="utf-8").read().split("\n")
i=ls.index("| store | kind | id | rule | required | source | checked |")+2
rows={}
while ls[i].startswith("|"):
    c=[x.strip() for x in ls[i].split("|")[1:8]]
    if c[1]=="field": rows.setdefault(c[0],[]).append((c[2],c[3]))
    i+=1
def value(locale,rule,d):
    n,unit=rule.split()
    n=int(n)+d
    if locale=="en": return "a"*n
    return "\u6587"*n if unit=="chars" else "\u6587"*(n//3)+"a"*(n%3)
t=["---","schema: \"1.0\"","stores:"]
for store in rows:
    t.append("  %s:"%store)
    for locale in ("en","zh"):
        p=", ".join("%s: %s"%(k,json.dumps(value(locale,r,delta if target=="|".join((store,k,locale)) else 0),ensure_ascii=False)) for k,r in rows[store])
        t.append("    %s: { %s }"%(locale,p))
t.append("---")
open(out+"/.app-creators/listing.md","w",encoding="utf-8").write("\n".join(t)+"\n")' "$1" "$2" "$3" "$4"
}

syn="$tmp/syn.md"
printf '%s\n' "$header
| s | field | req | 10 chars | yes | $link | 2026-01-01 |
| s | field | opt | 10 chars | no | $link | 2026-01-01 |
| s | field | byt | 10 bytes | no | $link | 2026-01-01 |
| s | field | unv | 10 chars | yes | $link | unverified |
| s | field | unk | 10 chars | unverified | $link | 2026-01-01 |
| s | image | ex | exact 100x200 200x100 no-alpha | | $link | 2026-01-01 |
| s | image | loose | exact 100x200 | | $link | 2026-01-01 |
| s | image | rng | range 320-3840 ratio 2 | | $link | 2026-01-01 |
| s | image | frac | range 100-1000 ratio 1.5 | | $link | 2026-01-01 |
| s | image | blind | exact 100x200 | | $link | unverified |" >"$syn"

# --- the real table ---
real_rows="$(table_rows "$limits")"
total=$((total + 1))
if bad="$(printf '%s\n' "$real_rows" | python3 -I -c 'import re,sys
rows=[l.rstrip("\n").split("|") for l in sys.stdin]
stores=set()
for s,k,i,rule,req,src,chk in rows:
    stores.add((s,k))
    if not re.fullmatch(r"\[[^\]]+\]\(https://(developer\.apple\.com|support\.google\.com)/[^\s()]+\)",src): print("source",i)
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}|unverified",chk): print("checked",i)
    if s not in ("app_store","google_play"): print("store",i)
    if not re.fullmatch("[a-z0-9_]+",i): print("id",i)
    if k=="field" and req not in ("yes","no","unverified"): print("required",i)
    if k=="image" and (req or not re.match("exact |range ",rule)): print("image",i)
if len(stores)!=4: print("a store or kind has no rows",sorted(stores))')" && [ -z "$bad" ]; then
  pass=$((pass + 1))
else
  fail "real table: every row sourced and dated" "$bad"
fi

base="$tmp/base"
listing "$base" '---
schema: "1.0"
stores:
  app_store:
    en: { description: "x" }
---'
run_check "$base"
expect "real table parses by default path" 1 '^PASS field\.app_store\.en\.description: 1/[0-9]+ ' '^FAIL field\.app_store\.en\.name: empty and required' '^UNKNOWN field\.app_store\.en\.promotional_text: empty; no source says whether this field is required$' '^UNKNOWN screenshots: none listed$'

# --- slice proof: listing copy at every limit in en and zh; one over on each field ---
fill "$limits" "$tmp/fill" - 0
run_check "$tmp/fill"
at_limit_out="$out"
expect "at every limit, en and zh" 0
fields=0
while IFS='|' read -r store kind id rule required source checked; do
  [ "$kind" = field ] || continue
  fields=$((fields + 1))
  n="${rule%% *}"
  unit="${rule##* }"
  word=PASS
  tail=""
  [ "$checked" != unverified ] || {
    word=UNKNOWN
    tail="; limits row is unverified"
  }
  out="$at_limit_out"
  for locale in en zh; do
    code=0
    expect "at limit $store.$locale.$id" 0 "^$word field\.$store\.$locale\.$id: $n/$n $unit$tail\$"
    fill "$limits" "$tmp/over" "$store|$id|$locale" 1
    run_check "$tmp/over"
    if [ "$checked" = unverified ]; then
      expect "one over $store.$locale.$id" 0 "^UNKNOWN field\.$store\.$locale\.$id: $((n + 1))/$n $unit; limits row is unverified\$" '!^FAIL '
    else
      expect "one over $store.$locale.$id" 1 "^FAIL field\.$store\.$locale\.$id: $((n + 1))/$n $unit; fix: rewrite 1 $unit shorter, do not truncate\$"
    fi
    out="$at_limit_out"
  done
done <<<"$real_rows"
total=$((total + 1))
if [ "$fields" -ge 8 ]; then pass=$((pass + 1)); else fail "real table fields" "only $fields"; fi
fill "$limits" "$tmp/over" 'app_store|name|zh' 1
run_check "$tmp/over"
expect "slice proof: copy passes, one-over-limit field fails" 1 '^FAIL field\.app_store\.zh\.name: ' '^PASS field\.app_store\.en\.name: ' '!^FAIL field\.app_store\.en'

for id in title full_description; do
  fill "$limits" "$tmp/over" "google_play|$id|en" 1
  run_check "$tmp/over"
  expect "one over google_play $id fails though required is unverified" 1 "^FAIL field\.google_play\.en\.$id: "
done

# --- field rules on a synthetic table ---
d="$tmp/fields"
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "文文文文文", opt: "文文文文文", byt: "文文文文文" }
---'
run_check "$d" --limits "$syn"
expect "bytes vs chars on one CJK value" 1 '^PASS field\.s\.en\.opt: 5/10 chars$' '^FAIL field\.s\.en\.byt: 15/10 bytes; fix: rewrite 5 bytes shorter' '^PASS field\.s\.en\.req: 5/10 chars$'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "", opt: "" }
---'
run_check "$d" --limits "$syn"
expect "required empty fails, optional empty passes, absent too" 1 '^FAIL field\.s\.en\.req: empty and required; fix: ' '^PASS field\.s\.en\.opt: empty and optional$' '^PASS field\.s\.en\.byt: empty and optional$'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { opt: "" }
---'
run_check "$d" --limits "$syn"
expect "required absent fails" 1 '^FAIL field\.s\.en\.req: empty and required'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "   " }
---'
run_check "$d" --limits "$syn"
expect "whitespace only is empty" 1 '^FAIL field\.s\.en\.req: empty and required'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "aaaaaaaaaa", opt: "aaaaaaaaaaa" }
---'
run_check "$d" --limits "$syn"
expect "at limit passes, over limit fails" 1 '^PASS field\.s\.en\.req: 10/10 chars$' '^FAIL field\.s\.en\.opt: 11/10 chars; fix: rewrite 1 chars shorter, do not truncate$'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x", other: "x" }
  nowhere:
    en: { req: "x" }
---'
run_check "$d" --limits "$syn"
expect "no row and no store are UNKNOWN" 0 '^UNKNOWN field\.s\.en\.other: no limits row' '^UNKNOWN field\.nowhere\.en\.req: no limits row'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x", unv: "aaaaaaaaaaaaaaa" }
---'
run_check "$d" --limits "$syn"
expect "unverified over limit is UNKNOWN with the count" 0 '^UNKNOWN field\.s\.en\.unv: 15/10 chars; limits row is unverified$'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x" }
---'
run_check "$d" --limits "$syn"
expect "unverified required empty is UNKNOWN" 0 '^UNKNOWN field\.s\.en\.unv: 0/10 chars; limits row is unverified$' '!FAIL'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "a\nb", opt: "\u6587", byt: "\u6587\ud83d\ude00" }
---'
run_check "$d" --limits "$syn"
expect "JSON escapes decode before counting" 0 '^PASS field\.s\.en\.req: 3/10 chars$' '^PASS field\.s\.en\.opt: 1/10 chars$' '^PASS field\.s\.en\.byt: 7/10 bytes$'

listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x", unk: "aaaaaaaaaaa" }
---'
run_check "$d" --limits "$syn"
expect "required unverified over the limit fails" 1 '^FAIL field\.s\.en\.unk: 11/10 chars; fix: rewrite 1 chars shorter'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x", unk: "aaaaaaaaaa" }
---'
run_check "$d" --limits "$syn"
expect "required unverified within the limit passes" 0 '^PASS field\.s\.en\.unk: 10/10 chars$'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x", unk: "" }
---'
run_check "$d" --limits "$syn"
expect "required unverified empty is UNKNOWN" 0 '^UNKNOWN field\.s\.en\.unk: empty; no source says whether this field is required$' '!FAIL'
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "x" }
---'
run_check "$d" --limits "$syn"
expect "required unverified absent is UNKNOWN" 0 '^UNKNOWN field\.s\.en\.unk: empty; no source says'

# --- images ---
p="$tmp/img"
mkdir -p "$p"
listing "$p" '---
schema: "1.0"
stores:
  s:
    en: { req: "x" }
screenshots: []
---'
run_check "$p" --limits "$syn"
expect "screenshots [] is none listed" 0 '^UNKNOWN screenshots: none listed$'
shot "$p" ex ""
run_check "$p" --limits "$syn"
expect "empty path" 0 '^UNKNOWN image\.s\.ex\.1: empty path, not captured yet$'
pngh "$p/a.png" 100 200 2
shot "$p" nosuch a.png
run_check "$p" --limits "$syn"
expect "no row for the device class" 0 '^UNKNOWN image\.s\.nosuch\.1: no verified limits row'
shot "$p" blind a.png
run_check "$p" --limits "$syn"
expect "unverified image row" 0 '^UNKNOWN image\.s\.blind\.1: no verified limits row'
shot "$p" ex a.png
run_check "$p" --limits "$syn"
expect "exact portrait" 0 '^PASS image\.s\.ex\.1: "a\.png" PNG 100x200 '
pngh "$p/a.png" 200 100 2
run_check "$p" --limits "$syn"
expect "exact landscape" 0 '^PASS image\.s\.ex\.1: "a\.png" PNG 200x100 '
pngh "$p/a.png" 100 201 2
run_check "$p" --limits "$syn"
expect "exact wrong size names both" 1 '^FAIL image\.s\.ex\.1: "a\.png" is 100x201; the row accepts 100x200 200x100; fix: '

real_size="$(printf '%s\n' "$real_rows" | python3 -I -c 'import sys
for l in sys.stdin:
    c=l.split("|")
    if c[1]=="image" and c[2]=="iphone_dynamic_island_medium":
        print(c[3].split()[1].replace("x"," "))')"
real_w="${real_size% *}"
real_h="${real_size#* }"
pngh "$p/r.png" "$real_w" "$real_h" 2
listing "$p" '---
schema: "1.0"
stores:
  app_store:
    en: { description: "x" }
screenshots:
  - { store: app_store, device_class: iphone_dynamic_island_medium, path: r.png, size: "" }
---'
run_check "$p"
expect "real table portrait" 1 "^PASS image\.app_store\.iphone_dynamic_island_medium\.1: \"r\.png\" PNG ${real_w}x${real_h} "
pngh "$p/r.png" "$real_h" "$real_w" 2
run_check "$p"
expect "real table landscape" 1 "^PASS image\.app_store\.iphone_dynamic_island_medium\.1: \"r\.png\" PNG ${real_h}x${real_w} "
pngh "$p/r.png" "$real_w" "$((real_h + 1))" 2
run_check "$p"
expect "real table wrong size" 1 '^FAIL image\.app_store\.iphone_dynamic_island_medium\.1: '
pngh "$p/r.png" "$real_w" "$real_h" 6
run_check "$p"
expect "real table no alpha" 1 '^FAIL image\.app_store\.iphone_dynamic_island_medium\.1: "r\.png" has an alpha channel'

for case in 320:640:0 3840:1920:0 319:400:1 3841:2000:1 400:319:1 1000:2001:1 2001:1000:1 1000:2000:0 3840:3840:0; do
  w="${case%%:*}"
  rest="${case#*:}"
  h="${rest%%:*}"
  want="${rest#*:}"
  pngh "$p/a.png" "$w" "$h" 2
  shot "$p" rng a.png
  run_check "$p" --limits "$syn"
  if [ "$want" = 0 ]; then
    expect "range ${w}x$h" 0 "^PASS image\.s\.rng\.1: \"a\.png\" PNG ${w}x$h "
  else
    expect "range ${w}x$h" 1 "^FAIL image\.s\.rng\.1: \"a\.png\" is ${w}x$h; the row accepts 320-3840 px per side, long side at most 2 times"
  fi
done
pngh "$p/a.png" 200 300 2
shot "$p" frac a.png
run_check "$p" --limits "$syn"
expect "fractional ratio at the bound" 0 '^PASS image\.s\.frac\.1:'
pngh "$p/a.png" 200 301 2
run_check "$p" --limits "$syn"
expect "fractional ratio over the bound" 1 '^FAIL image\.s\.frac\.1:'

for c in 4 6; do
  pngh "$p/a.png" 100 200 "$c"
  shot "$p" ex a.png
  run_check "$p" --limits "$syn"
  expect "no-alpha colour type $c" 1 '^FAIL image\.s\.ex\.1: "a\.png" has an alpha channel; fix: export without alpha$'
  shot "$p" loose a.png
  run_check "$p" --limits "$syn"
  expect "alpha allowed without the token, colour type $c" 0 '^PASS image\.s\.loose\.1:'
done
for c in 0 2 3; do
  pngh "$p/a.png" 100 200 "$c"
  shot "$p" ex a.png
  run_check "$p" --limits "$syn"
  expect "no-alpha colour type $c passes" 0 '^PASS image\.s\.ex\.1:'
done

for variant in trns text-idat text-trns big; do
  pngh "$p/a.png" 100 200 2 "$variant"
  shot "$p" ex a.png
  run_check "$p" --limits "$syn"
  expect "undecided alpha, $variant" 0 '^UNKNOWN image\.s\.ex\.1: "a\.png" PNG 100x200 may hold a tRNS chunk; export without alpha$' '!^FAIL ' '!^PASS image'
  shot "$p" loose a.png
  run_check "$p" --limits "$syn"
  expect "undecided alpha ignored without the token, $variant" 0 '^PASS image\.s\.loose\.1:'
done
pngh "$p/a.png" 100 201 2 trns
shot "$p" ex a.png
run_check "$p" --limits "$syn"
expect "wrong size beats undecided alpha" 1 '^FAIL image\.s\.ex\.1: "a\.png" is 100x201' '!alpha'
pngh "$p/a.png" 100 200 2 trns
shot "$p" ex a.png 200x100
run_check "$p" --limits "$syn"
expect "wrong recorded size beats undecided alpha" 1 '^FAIL image\.s\.ex\.1: the listing records the wrong size' '!alpha'
pngh "$p/a.png" 100 200 2
shot "$p" ex a.png
run_check "$p" --limits "$syn"
expect "plain colour type 2 passes" 0 '^PASS image\.s\.ex\.1: "a\.png" PNG 100x200 '
pngh "$p/a.png" 100 200 6 trns
run_check "$p" --limits "$syn"
expect "colour type 6 fails even beside tRNS" 1 '^FAIL image\.s\.ex\.1: "a\.png" has an alpha channel'

jpeg "$p/j.jpg" 100 200 c0 0
shot "$p" ex j.jpg
run_check "$p" --limits "$syn"
expect "JPEG SOF0 skipping DHT" 0 '^PASS image\.s\.ex\.1: "j\.jpg" JPEG 100x200 '
jpeg "$p/j.jpg" 200 100 c2 0
run_check "$p" --limits "$syn"
expect "JPEG SOF2" 0 '^PASS image\.s\.ex\.1: "j\.jpg" JPEG 200x100 '
jpeg "$p/j.jpg" 100 200 c0 3
run_check "$p" --limits "$syn"
expect "JPEG large APP segments before SOF" 0 '^PASS image\.s\.ex\.1: "j\.jpg" JPEG 100x200 '
jpeg "$p/j.jpg" 101 200 c0 1
run_check "$p" --limits "$syn"
expect "JPEG wrong size" 1 '^FAIL image\.s\.ex\.1: "j\.jpg" is 101x200'
jpeg "$p/j.jpg" 100 200 c0 20
run_check "$p" --limits "$syn"
expect "JPEG SOF past the prefix" 0 '^UNKNOWN image\.s\.ex\.1: "j\.jpg" shows no PNG or JPEG size'
printf '\377\330\377\332\000\010aaaaaa\377\331' >"$p/j.jpg"
run_check "$p" --limits "$syn"
expect "JPEG SOS before SOF" 0 '^UNKNOWN image\.s\.ex\.1: '
printf '\377\330\377\341\377\377abc' >"$p/j.jpg"
run_check "$p" --limits "$syn"
expect "JPEG truncated segment" 0 '^UNKNOWN image\.s\.ex\.1: '

printf '\211PNG\r\n\032\n\000\000\000\015IHDR\000\000' >"$p/t.png"
shot "$p" ex t.png
run_check "$p" --limits "$syn"
expect "truncated PNG" 0 '^UNKNOWN image\.s\.ex\.1: "t\.png" shows no PNG or JPEG size'
printf 'GIF89a' >"$p/t.gif"
shot "$p" ex t.gif
run_check "$p" --limits "$syn"
expect "unknown format" 0 '^UNKNOWN image\.s\.ex\.1: "t\.gif" shows no PNG or JPEG size'

pngh "$p/a.png" 100 200 2
shot "$p" ex a.png 100x200
run_check "$p" --limits "$syn"
expect "size cell matches" 0 '^PASS image\.s\.ex\.1:'
shot "$p" ex a.png 200x100
run_check "$p" --limits "$syn"
expect "size cell mismatch" 1 '^FAIL image\.s\.ex\.1: the listing records the wrong size "200x100" for "a\.png", which is 100x200; fix: write size 100x200$'

shot "$p" ex gone.png
run_check "$p" --limits "$syn"
expect "missing file" 1 '^FAIL image\.s\.ex\.1: "gone\.png" is missing; fix: '
shot "$p" ex a.png/x.png
run_check "$p" --limits "$syn"
expect "path below a file is missing" 1 '^FAIL image\.s\.ex\.1: .* is missing'
pngh "$tmp/outside.png" 100 200 2
shot "$p" ex ../outside.png
run_check "$p" --limits "$syn"
expect "path traversal" 0 '^UNKNOWN image\.s\.ex\.1: "\.\./outside\.png" resolves outside the project$'
shot "$p" ex "$tmp/outside.png"
run_check "$p" --limits "$syn"
expect "absolute path" 0 '^UNKNOWN image\.s\.ex\.1: .* is absolute'
ln -s "$tmp/outside.png" "$p/out.png"
shot "$p" ex out.png
run_check "$p" --limits "$syn"
expect "symlink out" 0 '^UNKNOWN image\.s\.ex\.1: "out\.png" resolves outside the project$'
ln -s a.png "$p/in.png"
shot "$p" ex in.png
run_check "$p" --limits "$syn"
expect "symlink inside the project" 0 '^PASS image\.s\.ex\.1: "in\.png" PNG 100x200 '
mkfifo "$p/f.png"
shot "$p" ex f.png
run_watched "$p" --limits "$syn"
expect "FIFO does not hang" 0 '^UNKNOWN image\.s\.ex\.1: "f\.png" is not a readable regular file$'
mkdir "$p/d.png"
shot "$p" ex d.png
run_check "$p" --limits "$syn"
expect "directory" 0 '^UNKNOWN image\.s\.ex\.1: "d\.png" is not a readable regular file$'
shot "$p" ex 'a\u0000.png'
run_check "$p" --limits "$syn"
expect "NUL in a path" 0 '^UNKNOWN image\.s\.ex\.1: '
listing "$p" '---
schema: "1.0"
stores:
  s:
    en: { req: "x" }
screenshots:
  - { store: s, device_class: ex, path: a.png, size: "" }
  - { store: s, device_class: ex, path: "", size: "" }
  - { store: s, device_class: "", path: "", size: "" }
---'
run_check "$p" --limits "$syn"
expect "n is the 1-based position" 0 '^PASS image\.s\.ex\.1:' '^UNKNOWN image\.s\.ex\.2:' '^UNKNOWN image\.s\.""\.3:'

# --- the reader accepts ---
listing "$d" '---
# comment first
schema: 1.0

revision: "abc123" # trailing comment
date: 2026-11-02
stores: # comment on a block key
  # comment inside a block
  s:
    en:
      req: "x"   # a block map
      opt: a b/1.0+x
    zh: { req: "y", opt: plain word } # a flow map
screenshots: [] # none yet
---
Body text: anything, { even: [this.
'
run_check "$d" --limits "$syn"
expect "reader accepts the subset" 0 '^PASS field\.s\.en\.opt: 9/10 chars$' '^PASS field\.s\.zh\.opt: 10/10 chars$' '^UNKNOWN screenshots: none listed$'
listing "$d" '---
schema: "1.7"
stores:
  s:
    zh-Hans: { req: "x" }
---'
run_check "$d" --limits "$syn"
expect "schema minor and a hyphenated locale" 0 '^PASS field\.s\.zh-Hans\.req: 1/10 chars$'

# --- the reader rejects ---
rej "no opening marker" 1 'schema: "1.0"
---'
rej "no closing marker" 3 '---
schema: "1.0"'
rej "tab in indentation" 4 '---
schema: "1.0"
stores:
	s: { a: "x" }
---'
rej "block scalar |" 3 '---
schema: "1.0"
revision: |
  text
---'
rej "block scalar >" 3 '---
schema: "1.0"
revision: >
  text
---'
rej "single-quoted string" 3 "---
schema: \"1.0\"
revision: 'abc'
---"
rej "multi-line string" 3 '---
schema: "1.0"
revision: "abc
  def"
---'
rej "multi-line flow map" 5 '---
schema: "1.0"
stores:
  s:
    en: { a: "x",
      b: "y" }
---'
rej "block-style list item" 7 '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots:
  - store: s
---'
rej "duplicate key in a block" 4 '---
schema: "1.0"
date: a
date: b
---'
rej "duplicate key in a flow map" 5 '---
schema: "1.0"
stores:
  s:
    en: { a: "x", a: "y" }
---'
rej "unexpected indent" 3 '---
schema: "1.0"
  date: a
---'
rej "skipped indent level" 4 '---
schema: "1.0"
stores:
    s:
      en: { a: "x" }
---'
rej "odd indent" 4 '---
schema: "1.0"
stores:
   s: { a: "x" }
---'
rej "indented first key" 2 '---
  schema: "1.0"
---'
rej "YAML-only escape" 3 '---
schema: "1.0"
revision: "\x41"
---'
rej "raw tab in a string" 3 '---
schema: "1.0"
revision: "a	b"
---'
rej "lone surrogate" 3 '---
schema: "1.0"
revision: "\ud800"
---'
rej "plain scalar with a colon" 3 '---
schema: "1.0"
revision: a:b
---'
rej "plain scalar with two spaces" 3 '---
schema: "1.0"
revision: a  b
---'
rej "non-ASCII plain scalar" 3 '---
schema: "1.0"
revision: 文
---'
rej "text after a quoted value" 3 '---
schema: "1.0"
revision: "a" b
---'
rej "trailing space" 3 '---
schema: "1.0"
revision: "a" 
---'
rej "key without a space" 3 '---
schema: "1.0"
revision:"a"
---'
rej "key with no value or block" 3 '---
schema: "1.0"
revision:
---'
rej "quoted key" 3 '---
schema: "1.0"
"revision": a
---'
rej "bare line" 3 '---
schema: "1.0"
revision
---'
rej "flow map trailing comma" 5 '---
schema: "1.0"
stores:
  s:
    en: { a: "x", }
---'
rej "empty flow map" 5 '---
schema: "1.0"
stores:
  s:
    en: { }
---'
rej "nested flow map" 5 '---
schema: "1.0"
stores:
  s:
    en: { a: { b: "x" } }
---'
rej "non-empty flow list" 7 '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots:
  - [a]
---'
rej "other list syntax" 6 '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots: [ ]
---'
rej "list item beside a key" 8 '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots:
  - { store: s, device_class: a, path: "", size: "" }
  key: value
---'
shape "stores as text" stores '---
schema: "1.0"
stores: text
---'
shape "stores as a list" stores '---
schema: "1.0"
stores: []
---'
shape "store as a flat map" 'stores\.s\.en' '---
schema: "1.0"
stores:
  s: { en: "x" }
---'
shape "field as a nested map" 'stores\.s\.en\.req' '---
schema: "1.0"
stores:
  s:
    en:
      req:
        deep: "x"
---'
shape "screenshots as text" screenshots '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots: text
---'
shape "screenshot row missing a key" 'screenshots item 1' '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots:
  - { store: s, device_class: a, path: "" }
---'
shape "screenshot row with an extra key" 'screenshots item 1' '---
schema: "1.0"
stores:
  s:
    en: { a: "x" }
screenshots:
  - { store: s, device_class: a, path: "", size: "", extra: b }
---'
shape "a list at the top" listing '---
- { a: "x" }
---'
shape "stores absent" stores '---
schema: "1.0"
---'
shape "schema absent" schema '---
stores:
  s:
    en: { a: "x" }
---'
shape "schema not a version" schema '---
schema: one
---'
shape "schema major 2" schema '---
schema: "2.0"
stores:
  s:
    en: { a: "x" }
---'
shape "schema major 2 plain" schema '---
schema: 2
stores:
  s:
    en: { a: "x" }
---'
mkdir -p "$tmp/deep/.app-creators"
python3 -I -c 'import sys
t=["---"]+["  "*k+"a:" for k in range(1020)]+["  "*1020+"b: c","---"]
open(sys.argv[1],"w").write("\n".join(t)+"\n")' "$tmp/deep/.app-creators/listing.md"
run_check "$tmp/deep" --limits "$syn"
stops "nesting within the size cap gives no traceback" "recursion"
rej "CRLF line ends" 1 "$(printf -- '---\r\nschema: \"1.0\"\r\n---')"

# --- environment errors ---
set +e
out="$(python3 -I "$check" 2>"$tmp/stderr")"
code=$?
set -e
err="$(cat "$tmp/stderr")"
stops "no project argument" "usage"
run_check "$tmp/fill" --no-such-flag
stops "unknown flag" "usage"
run_check "$tmp/no-such-dir"
stops "project missing" "listing\.md cannot be read"
mkdir -p "$tmp/empty"
run_check "$tmp/empty"
stops "listing missing" "listing\.md cannot be read"
mkdir -p "$tmp/dirlisting/.app-creators/listing.md"
run_check "$tmp/dirlisting"
stops "listing is a directory" "listing\.md cannot be read"
mkdir -p "$tmp/binlisting/.app-creators"
printf -- '---\n\377\n---\n' >"$tmp/binlisting/.app-creators/listing.md"
run_check "$tmp/binlisting"
stops "listing not UTF-8" "listing\.md cannot be read"
mkdir -p "$tmp/fifolisting/.app-creators"
mkfifo "$tmp/fifolisting/.app-creators/listing.md"
run_watched "$tmp/fifolisting"
stops "listing is a FIFO" "listing\.md cannot be read"
mkdir -p "$tmp/biglisting/.app-creators"
python3 -I -c 'import sys;open(sys.argv[1],"w").write("---\n"+"#"*(1<<21)+"\n---\n")' "$tmp/biglisting/.app-creators/listing.md"
run_check "$tmp/biglisting"
stops "listing over the size cap" "larger than"

# --- malformed limits ---
run_check "$base" --limits "$tmp/no-such-limits.md"
stops "limits missing" "limits file cannot be read"
mkfifo "$tmp/fifo-limits.md"
run_watched "$base" --limits "$tmp/fifo-limits.md"
stops "limits is a FIFO" "limits file cannot be read"
bad_limits "no table" '# nothing here'
bad_limits "other header" '| store | kind | id | rule | source | checked |
|---|---|---|---|---|---|'
bad_limits "two tables" "$header
| s | field | a | 1 chars | yes | $link | 2026-01-01 |

$header
| s | field | b | 1 chars | yes | $link | 2026-01-01 |"
bad_limits "no rows" "$header" "limits line [0-9]+: the table has no rows"
good_row="| s | field | a | 1 chars | yes | $link | 2026-01-01 |"
for row in \
  "| s | field | a | 1 chars | yes | $link |" \
  "| s | field | a | 1 chars | yes | $link | 2026-01-01 | x |" \
  "| s | other | a | 1 chars | yes | $link | 2026-01-01 |" \
  "| s | field | a | 1 words | yes | $link | 2026-01-01 |" \
  "| s | field | a | 0 chars | yes | $link | 2026-01-01 |" \
  "| s | field | a | 1 chars | maybe | $link | 2026-01-01 |" \
  "| s | field | a | 1 chars | | $link | 2026-01-01 |" \
  "| s | image | a | exact 1x1 | unverified | $link | 2026-01-01 |" \
  "| s | field | a | 1 chars | yes | none | 2026-01-01 |" \
  "| s | field | a | 1 chars | yes | [x](http://example.com) | 2026-01-01 |" \
  "| s | field | a | 1 chars | yes | $link | yesterday |" \
  "| s | field | a | 1 chars | yes | $link | 2026-13-01 |" \
  "| s | field | a | 1 chars | yes | $link | |" \
  "| s | image | a | exact 1x1 | yes | $link | 2026-01-01 |" \
  "| s | image | a | exact | | $link | 2026-01-01 |" \
  "| s | image | a | exact 1x1 alpha | | $link | 2026-01-01 |" \
  "| s | image | a | range 10-5 ratio 2 | | $link | 2026-01-01 |" \
  "| s | image | a | range 5-10 | | $link | 2026-01-01 |" \
  "| s | image | a | 1 chars | | $link | 2026-01-01 |"; do
  bad_limits "row: $row" "$header
$row" "limits line 3: "
done
bad_limits "duplicate row" "$header
$good_row
$good_row" "limits line 4: duplicate"

# --- output safety ---
d="$tmp/safe"
mkdir -p "$d/.app-creators"
printf -- '---\nschema: "1.0"\nstores:\n  s:\n    e\033[31mn: { req: "x" }\n---\n' >"$d/.app-creators/listing.md"
run_check "$d" --limits "$syn"
stops "raw control sequence in a locale key is rejected" "^line 5: "
clean "raw control sequence in a locale key is not printed" 1
shot "$d" 'x\u001b[31m\u202e\ny\"z\\w' 'p\u001b[2J\u202e\n\"q\\r.png'
run_check "$d" --limits "$syn"
expect "sanitized id and path" 0 '^UNKNOWN image\.s\."x\[31my\\"z\\\\w"\.1: empty|^UNKNOWN image\.s\."x\[31my\\"z\\\\w"\.1: no verified'
clean "control sequence in device_class and path is not printed raw" 6
pngh "$d/a.png" 100 200 2
shot "$d" ex 'q\u001b[2J\u202e\n\"r\\.png'
run_check "$d" --limits "$syn"
expect "sanitized path, missing file" 1 '^FAIL image\.s\.ex\.1: "q\[2J\\"r\\\\\.png" is missing'
clean "control sequence in a path is not printed raw" 6
shot "$d" ex a.png '1x1\u001b[2J\u202e\n'
run_check "$d" --limits "$syn"
expect "sanitized size cell" 1 '^FAIL image\.s\.ex\.1: the listing records the wrong size "1x1\[2J" for "a\.png"'
clean "control sequence in a size cell is not printed raw" 6
long="$(python3 -I -c 'print("a"*5000)')"
shot "$d" "$long" "$long"
run_check "$d" --limits "$syn"
total=$((total + 1))
if [ "${#out}" -lt 600 ]; then pass=$((pass + 1)); else fail "length cap" "${#out} chars"; fi
listing "$d" '---
schema: "1.0"
stores:
  s:
    en: { req: "SENTINEL", opt: "SENTINELSENTINEL", byt: "SENTINELSENTINEL", unv: "SENTINEL", other: "SENTINEL" }
---'
run_check "$d" --limits "$syn"
expect "no value text is printed" 1 '^PASS field\.s\.en\.req: ' '^FAIL field\.s\.en\.opt: ' '^FAIL field\.s\.en\.byt: ' '^UNKNOWN field\.s\.en\.unv: ' '^UNKNOWN field\.s\.en\.other: ' '!SENTINEL'

if [ "$pass" -eq "$total" ]; then
  echo "PASS $pass/$total"
  exit 0
fi
printf '%s\n' "$failed"
echo "FAIL $((total - pass))/$total"
exit 1
