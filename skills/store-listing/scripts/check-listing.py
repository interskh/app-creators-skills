#!/usr/bin/env python3
import argparse
import errno
import fractions
import json
import os
import re
import stat
import struct
import sys
import unicodedata

MAX_TEXT = IMAGE_PREFIX = 1 << 20
HEADER = "| store | kind | id | rule | required | source | checked |"
KEY = r"[A-Za-z0-9][A-Za-z0-9_-]*"
WORD = r"[A-Za-z0-9._/+-]+"
KEY_LINE = re.compile("(%s):(?: +|$)" % KEY)
FLOW_KEY = re.compile(" *(%s): +" % KEY)
FLOW_NEXT = re.compile(" *([,}])")
TAIL = re.compile(r"(?: +#.*)?")
PLAIN = re.compile("%s(?: %s)*" % (WORD, WORD))
QUOTED = re.compile(r'"(?:[^"\\]|\\.)*"')
LINK = re.compile(r"\[[^\]]+\]\(https://[^\s()]+\)")
DATE = re.compile(r"\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])")
FIELD_RULE = re.compile(r"([1-9]\d{0,8}) (chars|bytes)")
EXACT = re.compile(r"exact((?: [1-9]\d{0,8}x[1-9]\d{0,8})+)( no-alpha)?")
RANGE = re.compile(r"range ([1-9]\d{0,8})-([1-9]\d{0,8}) ratio ([1-9]\d{0,8}(?:\.\d{1,9})?)( no-alpha)?")
SAFE = re.compile(r"[A-Za-z0-9_-]{1,64}")
FLOW_HELP = 'write the map on one line as { a: "x", b: plain }'
ROW_HELP = "write kind field with '<n> chars' or '<n> bytes' and required yes, no, or unverified, or kind image with an exact or range rule and empty required; source one https Markdown link; checked YYYY-MM-DD or unverified"

class Stop(Exception):
    pass

def need(ok, where, what):
    if not ok:
        raise Stop("%s: %s" % ("line %d" % where if isinstance(where, int) else where, what))

def show(text, cap=120):
    kept = "".join(c for c in text if unicodedata.category(c)[0] != "C" and unicodedata.category(c) not in ("Zl", "Zp"))
    return '"%s"' % kept[:cap].replace("\\", "\\\\").replace('"', '\\"')

def token(text):
    return text if SAFE.fullmatch(text) else show(text)

def read_regular(path, cap):
    with os.fdopen(os.open(path, os.O_RDONLY | getattr(os, "O_NONBLOCK", 0)), "rb") as f:
        if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
            raise IsADirectoryError(errno.EISDIR, "not a regular file")
        return f.read(cap)

def read_text(path, name):
    try:
        data = read_regular(path, MAX_TEXT + 1)
        if len(data) > MAX_TEXT:
            raise Stop("%s is larger than %d bytes" % (name, MAX_TEXT))
        return data.decode("utf-8")
    except (OSError, ValueError) as e:
        raise Stop("%s cannot be read (%s)" % (name, type(e).__name__))

def scalar(s, pos, no):
    first = s[pos:pos + 1]
    need(first != "'", no, "use double quotes, not single quotes")
    need(first not in ("|", ">"), no, "write the text as one double-quoted line, with \\n for a line break")
    m = (QUOTED if first == '"' else PLAIN).match(s, pos)
    need(m, no, "write a double-quoted string closed on this line, or plain words of A-Z a-z 0-9 . _ / + -")
    if first != '"':
        return m.group(), m.end()
    try:
        value = json.loads(m.group())
        value.encode("utf-8")
    except ValueError:
        need(False, no, "use only JSON escapes and paired surrogates in a double-quoted string, with no raw control character")
    return value, m.end()

def flow(s, pos, no):
    out, pos = {}, pos + 1
    while True:
        m = FLOW_KEY.match(s, pos)
        need(m, no, FLOW_HELP)
        need(m.group(1) not in out, no, "remove the duplicate key %s" % m.group(1))
        out[m.group(1)], pos = scalar(s, m.end(), no)
        m = FLOW_NEXT.match(s, pos)
        need(m, no, FLOW_HELP)
        pos = m.end()
        if m.group(1) == "}":
            return out, pos

def value_at(s, pos, no):
    if s.startswith("[", pos):
        need(s.startswith("[]", pos), no, 'write [] for an empty list, or items of the form - { a: "x" }')
        value, pos = [], pos + 2
    else:
        value, pos = flow(s, pos, no) if s.startswith("{", pos) else scalar(s, pos, no)
    need(TAIL.fullmatch(s, pos), no, "end the line after the value; only a trailing ' # comment' may follow")
    return value

def frontmatter(text):
    lines = text.split("\n")
    need(lines[0] == "---", 1, "start the file with a --- line")
    items = []
    for no, line in enumerate(lines[1:], 2):
        if line == "---":
            break
        body = line.lstrip(" ")
        indent = len(line) - len(body)
        need(body[:1] != "\t", no, "indent with two spaces, not a tab")
        if body.strip() and body[0] != "#":
            need(indent % 2 == 0, no, "indent two spaces per level")
            items.append((no, indent, body))
    else:
        need(False, len(lines), "close the frontmatter with a --- line")
    need(items, 1, 'add schema: "1.0"')
    def block(i, indent):
        out = [] if items[i][2].startswith("-") else {}
        while i < len(items) and items[i][1] == indent:
            no, _, body = items[i]
            i += 1
            if isinstance(out, list):
                need(body.startswith("- {"), no, 'write each list item as one line: - { a: "x", b: plain }')
                out.append(value_at(body, 2, no))
                continue
            m = KEY_LINE.match(body)
            need(m, no, 'write key: "value", or key: to open a nested block')
            key, pos = m.group(1), m.end()
            need(key not in out, no, "remove the duplicate key %s" % key)
            if pos < len(body) and body[pos] != "#":
                out[key] = value_at(body, pos, no)
                continue
            need(i < len(items) and items[i][1] > indent, no, "give %s a value, or indent a nested block under it" % key)
            need(items[i][1] == indent + 2, items[i][0], "indent two spaces per level")
            out[key], i = block(i, indent + 2)
        if i < len(items):
            need(items[i][1] <= indent, items[i][0], "remove the unexpected indent")
        return out, i
    return block(0, 0)[0]

def check_shape(doc):
    def strings_at(node, path, depth):
        need(isinstance(node, dict if depth else str), ".".join(path), "write this in the shape stores.<store>.<locale>.<field>: string")
        for key, value in node.items() if depth else ():
            strings_at(value, path + (key,), depth - 1)
    need(isinstance(doc, dict), "listing", 'write top-level keys, starting with schema: "1.0"')
    need(str(doc.get("schema")).split(".")[0] == "1", "schema", 'this script reads schema major 1; write schema: "1.0"')
    strings_at(doc.get("stores"), ("stores",), 3)
    shots = doc.get("screenshots", [])
    need(isinstance(shots, list), "screenshots", 'write [] or items of the form - { store: "x" }')
    for n, row in enumerate(shots, 1):
        need(set(row) - {"locale"} == {"store", "device_class", "path", "size"}, "screenshots item %d" % n, "give the item exactly store, device_class, path, and size, plus locale when it belongs to one locale")
        need("locale" not in row or row["locale"] in doc["stores"].get(row["store"], {}), "screenshots item %d" % n, "locale %s is not under stores.%s; add that locale's text there, correct the locale, or remove it so the row applies to every locale" % (token(row.get("locale", "")), token(row["store"])))
    return doc["stores"], shots

def parse_rule(kind, rule, required):
    if kind == "field":
        m = FIELD_RULE.fullmatch(rule)
        return {"limit": int(m[1]), "unit": m[2], "required": required} if m and required in ("yes", "no", "unverified") else None
    m = EXACT.fullmatch(rule)
    if m and not required:
        return {"sizes": m[1].split(), "no_alpha": bool(m[2])}
    m = RANGE.fullmatch(rule)
    if m and not required and int(m[1]) <= int(m[2]):
        return {"low": int(m[1]), "high": int(m[2]), "ratio": m[3], "no_alpha": bool(m[4])}
    return None

def read_limits(path):
    lines = read_text(path, "limits file").split("\n")
    heads = [n for n, line in enumerate(lines) if line == HEADER]
    if len(heads) != 1:
        raise Stop("limits file: expected one table with the header %s, found %d" % (HEADER, len(heads)))
    i = heads[0] + 2
    def good(ok, what):
        need(ok, "limits line %d" % (i + 1), what)
    table = {"field": {}, "image": {}}
    while i < len(lines) and lines[i].startswith("|"):
        cells = [c.strip() for c in lines[i].split("|")]
        good(len(cells) == 9 and not cells[0] and not cells[8], "a row must have seven columns")
        store, kind, rid, rule, required, source, checked = cells[1:8]
        row = parse_rule(kind, rule, required)
        good(kind in table and row and LINK.fullmatch(source) and (checked == "unverified" or DATE.fullmatch(checked)), ROW_HELP)
        good(rid not in table[kind].setdefault(store, {}), "duplicate row")
        row["verified"] = checked != "unverified"
        table[kind][store][rid] = row
        i += 1
    good(any(table.values()), "the table has no rows")
    return table

def check_field(store, locale, key, value, rows):
    cid = "field.%s.%s.%s" % (store, locale, key)
    row = rows.get(store, {}).get(key)
    if not row:
        return "UNKNOWN %s: no limits row for this store and key" % cid
    value, limit, unit = value or "", row["limit"], row["unit"]
    n = len(value.encode("utf-8")) if unit == "bytes" else len(value)
    if not row["verified"]:
        return "UNKNOWN %s: %d/%d %s; limits row is unverified" % (cid, n, limit, unit)
    if n > limit:
        return "FAIL %s: %d/%d %s; fix: rewrite %d %s shorter, do not truncate" % (cid, n, limit, unit, n - limit, unit)
    if not value.strip():
        if row["required"] == "unverified":
            return "UNKNOWN %s: empty; no source says whether this field is required" % cid
        return "FAIL %s: empty and required; fix: write this field" % cid if row["required"] == "yes" else "PASS %s: empty and optional" % cid
    return "PASS %s: %d/%d %s" % (cid, n, limit, unit)

def image_info(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        if len(data) < 29 or data[8:16] != b"\0\0\0\x0dIHDR" or data[25] not in (0, 2, 3, 4, 6):
            return None
        w, h = struct.unpack(">II", data[16:24])
        return ("PNG", w, h, data[25] in (4, 6) or (None if b"tRNS" in data or b"IDAT" not in data else False)) if w and h else None
    pos = 2 if data.startswith(b"\xff\xd8") else len(data)
    while pos + 4 <= len(data) and data[pos] == 0xFF:
        marker = data[pos + 1]
        if marker == 0xFF or marker == 0x01 or 0xD0 <= marker <= 0xD7:
            pos += 1 if marker == 0xFF else 2
            continue
        length = struct.unpack(">H", data[pos + 2:pos + 4])[0]
        if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
            h, w = struct.unpack(">HH", data[pos + 5:pos + 9]) if length >= 8 and pos + 9 <= len(data) else (0, 0)
            return ("JPEG", w, h, False) if w and h else None
        if marker in (0x00, 0xD8, 0xD9, 0xDA) or length < 2:
            return None
        pos += 2 + length
    return None

def check_image(project, n, shot, rows):
    device, path = shot["device_class"], shot["path"]
    cid = "image.%s.%d" % (".".join(token(shot[k]) for k in ("store", "locale", "device_class") if k in shot), n)
    row = rows.get(shot["store"], {}).get(device)
    shown = show(path)
    if not path:
        return "UNKNOWN %s: empty path, not captured yet" % cid
    if not row or not row["verified"]:
        return "UNKNOWN %s: no verified limits row for this store and device class" % cid
    if os.path.isabs(path):
        return "UNKNOWN %s: %s is absolute; only paths inside the project are read" % (cid, shown)
    try:
        root = os.path.realpath(project)
        real = os.path.realpath(os.path.join(root, path))
        if not real.startswith(root.rstrip(os.sep) + os.sep):
            return "UNKNOWN %s: %s resolves outside the project" % (cid, shown)
        info = image_info(read_regular(real, IMAGE_PREFIX))
    except (OSError, ValueError) as e:
        if getattr(e, "errno", None) in (errno.ENOENT, errno.ENOTDIR):
            return "FAIL %s: %s is missing; fix: capture it or correct the path" % (cid, shown)
        return "UNKNOWN %s: %s is not a readable regular file" % (cid, shown)
    if not info:
        return "UNKNOWN %s: %s shows no PNG or JPEG size in its first %d bytes" % (cid, shown, IMAGE_PREFIX)
    kind, w, h, alpha = info
    actual, short, wide = "%dx%d" % (w, h), min(w, h), max(w, h)
    if "sizes" in row:
        fits, accepts = actual in row["sizes"], " ".join(row["sizes"])
    else:
        fits = row["low"] <= short and wide <= row["high"] and wide <= fractions.Fraction(row["ratio"]) * short
        accepts = "%d-%d px per side, long side at most %s times the short side" % (row["low"], row["high"], row["ratio"])
    problems = [] if fits else [("%s is %s; the row accepts %s" % (shown, actual, accepts), "capture or export at an accepted size")]
    if row["no_alpha"] and alpha:
        problems.append(("%s has an alpha channel" % shown, "export without alpha"))
    if shot["size"] and shot["size"] != actual:
        problems.append(("the listing records the wrong size %s for %s, which is %s" % (show(shot["size"]), shown, actual), "write size %s" % actual))
    if problems:
        return "FAIL %s: %s; fix: %s" % (cid, " and ".join(p[0] for p in problems), " and ".join(p[1] for p in problems))
    if row["no_alpha"] and alpha is None:
        return "UNKNOWN %s: %s %s %s may hold a tRNS chunk; export without alpha" % (cid, shown, kind, actual)
    return "PASS %s: %s %s %s fits the limits row" % (cid, shown, kind, actual)

def main(argv):
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8", errors="backslashreplace")
    here = os.path.dirname(os.path.realpath(__file__))
    parser = argparse.ArgumentParser(prog="check-listing.py", allow_abbrev=False)
    parser.add_argument("project")
    parser.add_argument("--limits", default=os.path.join(here, "..", "references", "limits.md"))
    args = parser.parse_args(argv)
    try:
        table = read_limits(args.limits)
        listing = read_text(os.path.join(args.project, ".app-creators", "listing.md"), ".app-creators/listing.md")
        stores, shots = check_shape(frontmatter(listing))
    except (Stop, RecursionError) as e:
        print(e, file=sys.stderr)
        return 2
    lines = []
    for store, locales in stores.items():
        known = table["field"].get(store, {})
        for locale, fields in locales.items():
            for key in list(known) + [k for k in fields if k not in known]:
                lines.append(check_field(store, locale, key, fields.get(key), table["field"]))
    if not shots:
        lines.append("UNKNOWN screenshots: none listed")
    lines += [check_image(args.project, n, shot, table["image"]) for n, shot in enumerate(shots, 1)]
    print("\n".join(lines))
    return 1 if any(line.startswith("FAIL ") for line in lines) else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
