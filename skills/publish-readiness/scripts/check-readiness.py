#!/usr/bin/env python3
# Static publish-readiness checks. Rules and sources: references/checks.md.
# usage: python3 -I check-readiness.py <project> --platform ios|android|web
#          [--resolved <file>]... [--collects-data yes|no]
# Prints PASS, FAIL, or UNKNOWN per check. Every PASS needs an authoritative input:
# a data format the tools consume or emit, never source that only a compiler can
# interpret. Exit 0 when nothing fails, 1 on a failure, 2 on a usage or environment
# error. No network; writes nothing.
import argparse
import json
import os
import plistlib
import re
import signal
import stat
import struct
import sys
import unicodedata
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from urllib.parse import urlsplit

SKIP_DIRS = {"node_modules", ".git", "build", "Pods", ".dart_tool", "dist", ".expo", ".gradle", ".symlinks"}
MAX_SCAN_BYTES = 2 * 1024 * 1024
MAX_READ_BYTES = 16 * 1024 * 1024
MAX_RUN_READ_MB = 512
READS = {"left": MAX_RUN_READ_MB * 1024 * 1024}
RUN_LIMIT_SECONDS = 120
MAX_DECLARED_ICONS = 1000
IMAGE_PREFIX_BYTES = 2 * 1024 * 1024
SHOW_LIMIT = 80
MAX_LINE = 8000
UNSAFE_CATEGORIES = {"Cc", "Cf", "Cs", "Zl", "Zp"}
EXPO_EXTENSIONS = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts")
WEB_ICON_EXTENSIONS = (".png", ".webp", ".ico", ".svg", ".jpg", ".jpeg", ".gif", ".avif")
GRADLE_FILES = ("build.gradle", "build.gradle.kts")
APP_PRODUCT_TYPE = "com.apple.product-type.application"
PERMISSION_SCOPE = ("this covers declared permissions and the known API patterns the script's table lists; "
                    "it does not claim the app needs no permission")
PROJECT = {"path": "", "real": ""}

PHOTOS = "NSPhotoLibraryUsageDescription"
PHOTOS_ADD = "NSPhotoLibraryAddUsageDescription"
CAMERA = "NSCameraUsageDescription"
MIC = "NSMicrophoneUsageDescription"
LOC_WHEN = "NSLocationWhenInUseUsageDescription"
LOC_ALWAYS = "NSLocationAlwaysAndWhenInUseUsageDescription"
LOC_ALWAYS_OLD = "NSLocationAlwaysUsageDescription"
CONTACTS = "NSContactsUsageDescription"
CAL = "NSCalendarsUsageDescription"
CAL_FULL = "NSCalendarsFullAccessUsageDescription"
CAL_WRITE = "NSCalendarsWriteOnlyAccessUsageDescription"
REM = "NSRemindersUsageDescription"
REM_FULL = "NSRemindersFullAccessUsageDescription"
FACE_ID = "NSFaceIDUsageDescription"
TRACKING = "NSUserTrackingUsageDescription"
MOTION = "NSMotionUsageDescription"
SPEECH = "NSSpeechRecognitionUsageDescription"
BLUETOOTH = "NSBluetoothAlwaysUsageDescription"

# (API regex, any one of these keys satisfies it)
APPLE_APIS = [
    (r"requestAccess\(for:\s*\.video|requestAccessForMediaType:\s*AVMediaTypeVideo", (CAMERA,)),
    (r"requestAccess\(for:\s*\.audio|requestAccessForMediaType:\s*AVMediaTypeAudio", (MIC,)),
    (r"PHPhotoLibrary\.requestAuthorization\(for:\s*\.addOnly", (PHOTOS_ADD, PHOTOS)),
    (r"PHPhotoLibrary\.requestAuthorization\((?!for:\s*\.addOnly)|\[PHPhotoLibrary requestAuthorization", (PHOTOS,)),
    (r"requestWhenInUseAuthorization", (LOC_WHEN,)),
    (r"requestAlwaysAuthorization", (LOC_ALWAYS, LOC_ALWAYS_OLD)),
    (r"requestAlwaysAuthorization", (LOC_WHEN,)),
    (r"requestAccess\(for:\s*\.contacts|requestAccessForEntityType:\s*CNEntityTypeContacts", (CONTACTS,)),
    (r"requestFullAccessToEvents", (CAL_FULL,)),
    (r"requestWriteOnlyAccessToEvents", (CAL_WRITE, CAL_FULL)),
    (r"requestFullAccessToReminders", (REM_FULL,)),
    (r"evaluatePolicy", (FACE_ID,)),
    (r"requestTrackingAuthorization", (TRACKING,)),
    (r"SFSpeechRecognizer\.requestAuthorization|\[SFSpeechRecognizer requestAuthorization", (SPEECH,)),
    (r"\bCBCentralManager\b|\bCBPeripheralManager\b", (BLUETOOTH,)),
    (r"\bCMPedometer\b|\bCMMotionActivityManager\b|\bCMSensorRecorder\b|\bCMMovementDisorderManager\b", (MOTION,)),
]

DART_APIS = [
    (r"ImageSource\.gallery|pickMultiImage|pickMedia\b|pickMultipleMedia|pickMultiVideo", (PHOTOS,)),
    (r"ImageSource\.camera", (CAMERA,)),
    (r"(?s)\A(?=.*pickVideo\().*ImageSource\.camera", (MIC,)),
    (r"\bCameraController\(", (CAMERA,)),
    (r"\bCameraController\(", (MIC,)),
    (r"\bLocalAuthentication\(\)", (FACE_ID,)),
]

# (API regex, module the file must name or None, iOS keys (any one), Android permissions)
# Android "auto": the module's own manifest adds it. "declare": the app config must list it.
EXPO_APIS = [
    (r"launchImageLibraryAsync|requestMediaLibraryPermissionsAsync", None, (PHOTOS,), ()),
    (r"launchCameraAsync", None, (CAMERA,), (("CAMERA", "auto"),)),
    (r"\bCameraView\b|useCameraPermissions|requestCameraPermissionsAsync", None, (CAMERA,), (("CAMERA", "auto"),)),
    (r"useMicrophonePermissions|requestMicrophonePermissionsAsync", None, (MIC,), (("RECORD_AUDIO", "auto"),)),
    (r"\buseAudioRecorder\b|requestRecordingPermissionsAsync", None, (MIC,), (("RECORD_AUDIO", "auto"),)),
    (r"requestForegroundPermissionsAsync|getCurrentPositionAsync", None, (LOC_WHEN,), (("ACCESS_FINE_LOCATION", "auto"),)),
    (r"requestBackgroundPermissionsAsync", None, (LOC_ALWAYS, LOC_ALWAYS_OLD), (("ACCESS_BACKGROUND_LOCATION", "declare"),)),
    (r"getMotionActivityAsync|watchMotionActivityAsync", None, (MOTION,), ()),
    (r"getContactsAsync|\bContact\.getAll|requestPermissionsAsync", "expo-contacts", (CONTACTS,), (("READ_CONTACTS", "auto"),)),
    (r"getCalendarsAsync|requestCalendarPermissionsAsync|useCalendarPermissions", None, (CAL_FULL, CAL, CAL_WRITE),
     (("READ_CALENDAR", "declare"), ("WRITE_CALENDAR", "declare"))),
    (r"requestRemindersPermissionsAsync", None, (REM_FULL, REM), ()),
    (r"requestPermissionsAsync|usePermissions|getAssetsAsync", "expo-media-library", (PHOTOS,), ()),
    (r"saveToLibraryAsync", "expo-media-library", (PHOTOS_ADD, PHOTOS), ()),
    (r"authenticateAsync", "expo-local-authentication", (FACE_ID,), ()),
    (r"requestTrackingPermissionsAsync|useTrackingPermissions", None, (TRACKING,), ()),
    (r"\bPedometer\b|\bDeviceMotion\b", "expo-sensors", (MOTION,), ()),
]

# module -> plugin option -> Info.plist keys it writes
EXPO_OPTIONS = {
    "expo-image-picker": {"photosPermission": (PHOTOS,), "cameraPermission": (CAMERA,), "microphonePermission": (MIC,)},
    "expo-camera": {"cameraPermission": (CAMERA,), "microphonePermission": (MIC,)},
    "expo-location": {
        "locationWhenInUsePermission": (LOC_WHEN,),
        "locationAlwaysAndWhenInUsePermission": (LOC_ALWAYS,),
        "locationAlwaysPermission": (LOC_ALWAYS_OLD,),
        "motionUsagePermission": (MOTION,),
    },
    "expo-contacts": {"contactsPermission": (CONTACTS,)},
    "expo-calendar": {
        "calendarPermission": (CAL, CAL_FULL),
        "remindersPermission": (REM, REM_FULL),
        "writeOnlyCalendarPermission": (CAL_WRITE,),
    },
    "expo-media-library": {"photosPermission": (PHOTOS,), "savePhotosPermission": (PHOTOS_ADD,)},
    "expo-audio": {"microphonePermission": (MIC,)},
    "expo-local-authentication": {"faceIDPermission": (FACE_ID,)},
    "expo-tracking-transparency": {"userTrackingPermission": (TRACKING,)},
    "expo-sensors": {"motionPermission": (MOTION,)},
}

# (module, plugin option, Android permission that option=false leaves out)
EXPO_ANDROID_OFF = [
    ("expo-image-picker", "cameraPermission", "CAMERA"),
    ("expo-image-picker", "microphonePermission", "RECORD_AUDIO"),
    ("expo-camera", "recordAudioAndroid", "RECORD_AUDIO"),
    ("expo-audio", "recordAudioAndroid", "RECORD_AUDIO"),
]

ANDROID_API = r"Manifest\.permission\.([A-Z0-9_]+)|[\"']android\.permission\.([A-Z0-9_]+)[\"']"

DANGEROUS = set(
    "ACCEPT_HANDOVER ACCESS_BACKGROUND_LOCATION ACCESS_COARSE_LOCATION ACCESS_FINE_LOCATION "
    "ACCESS_LOCAL_NETWORK ACCESS_MEDIA_LOCATION ACTIVITY_RECOGNITION ADD_VOICEMAIL "
    "ANSWER_PHONE_CALLS BLUETOOTH_ADVERTISE BLUETOOTH_CONNECT BLUETOOTH_SCAN BODY_SENSORS "
    "BODY_SENSORS_BACKGROUND CALL_PHONE CAMERA GET_ACCOUNTS NEARBY_WIFI_DEVICES POST_NOTIFICATIONS "
    "PROCESS_OUTGOING_CALLS RANGING READ_CALENDAR READ_CALL_LOG READ_CONTACTS READ_EXTERNAL_STORAGE "
    "READ_MEDIA_AUDIO READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_VISUAL_USER_SELECTED "
    "READ_PHONE_NUMBERS READ_PHONE_STATE READ_SMS RECEIVE_MMS RECEIVE_SMS RECEIVE_WAP_PUSH "
    "RECORD_AUDIO SEND_SMS USE_SIP UWB_RANGING WRITE_CALENDAR WRITE_CALL_LOG WRITE_CONTACTS "
    "WRITE_EXTERNAL_STORAGE".split()
)

DENSITY = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
PLACEHOLDER = re.compile(r"%\w+%|\{\{|<%|\$\{|\$[A-Z_]")
ANDROID_NS = "{http://schemas.android.com/apk/res/android}"
TOOLS_NS = "{http://schemas.android.com/tools}"



class UsageError(Exception):
    pass


class Unknown(Exception):
    pass


class Fail(Exception):
    def __init__(self, reason, fix):
        Exception.__init__(self, reason)
        self.reason = reason
        self.fix = fix


# Rendering ---------------------------------------------------------------


def clean(text):
    return "".join(c for c in str(text) if unicodedata.category(c) not in UNSAFE_CATEGORIES)


def show(value):
    """Render a project-derived value: no control characters, bounded, quoted, cannot break out."""
    text = clean(value)
    if len(text) > SHOW_LIMIT:
        text = text[:SHOW_LIMIT] + "...[truncated]"
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def show_list(values):
    return ", ".join(show(v) for v in values) or "none"


# Files -------------------------------------------------------------------


def _rel(path):
    root = PROJECT["path"]
    if root and (path == root or path.startswith(root + os.sep)):
        return os.path.relpath(path, root)
    return os.path.basename(path)


def _inside(path, root):
    real = os.path.realpath(path)
    return real == root or real.startswith(root + os.sep)


def contain(path):
    """Decide before any existence check, so a missing outside path reads the same as a present one."""
    if not _inside(path, PROJECT["real"]):
        raise Unknown("%s points outside the project" % show(_rel(path)))


def read_bytes(path, limit=MAX_READ_BYTES, contained=True, prefix=False):
    """Every read: regular file only, inside the project unless the operator named it, never over limit bytes."""
    label = show(_rel(path))
    if READS["left"] <= 0:
        raise Unknown("%s was not read: the %d MB per-run read limit is used up" % (label, MAX_RUN_READ_MB))
    if contained:
        contain(path)
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NONBLOCK", 0))
    except OSError as e:
        raise Unknown("%s could not be read (%s)" % (label, type(e).__name__))
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise Unknown("%s is not a regular file" % label)
        parts = []
        size = 0
        while size <= limit:
            part = os.read(fd, min(1024 * 1024, limit + 1 - size))
            if not part:
                break
            parts.append(part)
            size += len(part)
    except OSError as e:
        raise Unknown("%s could not be read (%s)" % (label, type(e).__name__))
    finally:
        os.close(fd)
    data = b"".join(parts)
    READS["left"] -= len(data) + 4096
    if len(data) > limit:
        if prefix:
            return data[:limit]
        raise Unknown("%s is larger than the %d MB read limit" % (label, limit // (1024 * 1024)))
    return data


def read_text(path):
    data = read_bytes(path)
    try:
        return data.decode("utf-8-sig")
    except ValueError:
        raise Unknown("%s is not UTF-8 text" % show(_rel(path)))


def load_json(path):
    text = read_text(path)
    try:
        return json.loads(text)
    except (ValueError, RecursionError):
        raise Unknown("%s is not valid JSON" % show(_rel(path)))


def read_json_quietly(path):
    """For framework detection: anything unreadable counts as absent."""
    try:
        return load_json(path)
    except Unknown:
        return None


def parse_xml(data, label):
    if b"<!ENTITY" in data.replace(b"\x00", b""):
        raise Unknown("%s declares XML entities, which are not read" % label)
    try:
        return ET.fromstring(data)
    except (ET.ParseError, ValueError):
        raise Unknown("%s is not well-formed XML" % label)


def read_xml(path):
    return parse_xml(read_bytes(path), show(_rel(path)))


# An unclosed literal runs to the end of its line or of the input, so a match never fails and rescans.
COMMENT_OR_STRING = re.compile(
    r"""("(?:\\.|[^"\\\n])*(?:"|(?=\n)|\\?\Z)|'(?:\\.|[^'\\\n])*(?:'|(?=\n)|\\?\Z)|`(?:\\.|[^`\\])*(?:`|\\?\Z))"""
    r"""|(?<!\\)/\*|(?<!\\)//[^\n]*""",
    re.S,
)


def strip_comments(text):
    """Linear time. A mistake here only moves a row to raw-only, which is UNKNOWN, so it can never produce a PASS."""
    parts = []
    pos = 0
    while True:
        m = COMMENT_OR_STRING.search(text, pos)
        if not m:
            parts.append(text[pos:])
            return "".join(parts)
        parts.append(text[pos:m.start()])
        pos = m.end()
        parts.append(m.group(1) or " ")
        if m.group() == "/*":
            end = text.find("*/", pos)
            if end < 0:
                return "".join(parts)
            pos = end + 2


def image_info(path):
    """Return (width, height, has_alpha) from a PNG or WebP header; has_alpha is None for WebP."""
    label = show(_rel(path))
    data = read_bytes(path, limit=IMAGE_PREFIX_BYTES, prefix=True)
    try:
        if data[:8] == b"\x89PNG\r\n\x1a\n":
            return _png_info(data)
        if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            return _webp_info(data)
    except (ValueError, struct.error, IndexError):
        raise Unknown("%s has a damaged image header" % label)
    raise Unknown("%s is not a readable PNG or WebP" % label)


def _png_info(data):
    if data[12:16] != b"IHDR":
        raise ValueError("no IHDR")
    width, height = struct.unpack(">II", data[16:24])
    colour = data[25]
    if width == 0 or height == 0 or colour not in (0, 2, 3, 4, 6):
        raise ValueError("bad IHDR")
    transparent = False
    pos = 8
    while True:
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        chunk = data[pos + 4:pos + 8]
        if chunk == b"IDAT":
            return width, height, colour in (4, 6) or transparent
        if pos + 12 + length > len(data):
            raise ValueError("truncated")
        if chunk == b"tRNS":
            transparent = True
        pos += 12 + length


def _webp_info(data):
    kind = data[12:16]
    if kind == b"VP8 ":
        if data[23:26] != b"\x9d\x01\x2a":
            raise ValueError("no VP8 start code")
        width, height = struct.unpack("<HH", data[26:30])
        return width & 0x3FFF, height & 0x3FFF, None
    if kind == b"VP8L":
        if data[20] != 0x2F:
            raise ValueError("no VP8L signature")
        bits = struct.unpack("<I", data[21:25])[0]
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1, None
    if kind == b"VP8X":
        if len(data) < 30:
            raise ValueError("truncated")
        width = int.from_bytes(data[24:27], "little") + 1
        height = int.from_bytes(data[27:30], "little") + 1
        return width, height, None
    raise ValueError("unknown WebP chunk")


def verdict(fails, unknowns, evidence):
    """fails: [(reason, fix)]. Every gap goes on the one line."""
    if fails:
        reasons = dict.fromkeys(reason for reason, _ in fails)
        fixes = dict.fromkeys(fix for _, fix in fails)
        raise Fail("; ".join(reasons), "; ".join(fixes))
    if unknowns:
        raise Unknown("; ".join(dict.fromkeys(unknowns)))
    return evidence


# Shared rules ------------------------------------------------------------


def valid_name(value, source, fix):
    if not isinstance(value, str) or not value.strip():
        raise Fail("the app name is empty in %s" % source, fix)
    return "%s from %s" % (show(value.strip()), source)


def _valid_id(value, pattern, what, rule, source, fix):
    if not isinstance(value, str) or not value:
        raise Fail("no %s in %s" % (what, source), fix)
    if not re.fullmatch(pattern, value):
        raise Fail("%s %s %s" % (what, show(value), rule), fix)
    return "%s from %s" % (show(value), source)


def valid_bundle_id(value, source, fix):
    return _valid_id(value, r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*", "bundle id",
                     "must be letters, digits, hyphens, and periods, with no empty segment", source, fix)


def valid_package(value, source, fix):
    return _valid_id(value, r"[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+", "application id",
                     "needs two or more segments, each starting with a letter, using only letters, digits, and underscores", source, fix)


def _skip_dir(name, current, root):
    """build and dist are output only at the scan root; build also beside a Gradle file. A src/build folder is source."""
    if name in ("build", "dist"):
        return current == root or (name == "build" and any(os.path.lexists(os.path.join(current, g)) for g in GRADLE_FILES))
    return name in SKIP_DIRS


def _not_scanned(path, root):
    current = root
    for part in os.path.relpath(path, root).split(os.sep):
        if _skip_dir(part, current, root):
            return True
        current = os.path.join(current, part)
    return False


def scan_code(root, extensions, skipped):
    """Yield (relative path, comment-free text, raw text); a file that cannot be read goes in skipped."""
    def unreadable(error):
        skipped.append("%s could not be read (%s)" % (show(_rel(error.filename)), type(error).__name__))

    scan_real = os.path.realpath(root)
    for current, dirs, files in os.walk(root, onerror=unreadable):
        dirs[:] = sorted(d for d in dirs if not _skip_dir(d, current, root))
        for name in dirs:
            path = os.path.join(current, name)
            if os.path.islink(path) and not _inside(path, PROJECT["real"]):
                skipped.append("%s points outside the project" % show(_rel(path)))
            elif os.path.islink(path) and (not _inside(path, scan_real) or _not_scanned(os.path.realpath(path), scan_real)):
                skipped.append("%s points at a folder that is not scanned" % show(_rel(path)))
        for name in sorted(files):
            if not name.endswith(extensions):
                continue
            path = os.path.join(current, name)
            try:
                data = read_bytes(path, limit=MAX_SCAN_BYTES)
            except Unknown as e:
                skipped.append(str(e))
                continue
            try:
                raw = data.decode("utf-8")
            except ValueError:
                skipped.append("%s is not UTF-8 text" % show(_rel(path)))
                continue
            if "\0" in raw:
                skipped.append("%s holds a NUL byte" % show(_rel(path)))
                continue
            yield _rel(path), strip_comments(raw), raw


def _row_hits(row, text):
    module = row[1]
    return (not module or module in text) and re.search(row[0], text)


def detect(root, extensions, table, skipped):
    """Return (row, file, certain) per table row found. A row seen only in raw text is not certain; code in any file wins."""
    found = {}
    for rel, stripped, raw in scan_code(root, extensions, skipped):
        for index, row in enumerate(table):
            if index in found and found[index][2]:
                continue
            if _row_hits(row, stripped):
                found[index] = (row, rel, True)
            elif index not in found and _row_hits(row, raw):
                found[index] = (row, rel, False)
    return [found[index] for index in sorted(found)]


def detect_android_native(root, skipped):
    """Return (permission, "declare", file, certain). Same rule as detect."""
    found = {}
    for rel, stripped, raw in scan_code(root, (".kt", ".java"), skipped):
        code = set(a or b for a, b in re.findall(ANDROID_API, stripped))
        for perm in code:
            if perm not in found or not found[perm][1]:
                found[perm] = (rel, True)
        for perm in set(a or b for a, b in re.findall(ANDROID_API, raw)) - code:
            found.setdefault(perm, (rel, False))
    return [(perm, "declare", rel, certain) for perm, (rel, certain) in sorted(found.items())]


def _code_gap(need, rel, certain, maybe, reason, fix, fails, unknowns):
    if not certain:
        unknowns.append("%s mentions an API that needs %s, but only in what reads as a comment; confirm it is not code"
                        % (show(rel), show(need)))
    elif maybe:
        unknowns.append("%s uses an API that needs %s, and %s" % (show(rel), show(need), maybe))
    else:
        fails.append(("%s uses an API that needs %s%s" % (show(rel), show(need), reason), fix))


def _scan_verdict(fails, unknowns, skipped, declared, needed):
    unknowns += ["%s, so permission APIs in it are unknown" % reason for reason in skipped]
    return verdict(fails, unknowns, "%s; needed by code: %s; %s" % (
        declared, show_list(sorted(set(needed))) if needed else "none detected", PERMISSION_SCOPE))


def check_strings(strings, unresolved, required, fix_for, skipped, maybe):
    """strings: key -> text. required: [(keys, file, certain)]. fix_for(key) -> (reason, fix)."""
    fails = [("%s is declared but empty" % show(key), fix_for(key)[1]) for key in sorted(strings) if not strings[key].strip()]
    unknowns = []
    for keys, rel, certain in required:
        if not any(k in strings or k in unresolved for k in keys):
            reason, fix = fix_for(keys[0])
            _code_gap(keys[0], rel, certain, maybe, "; " + reason, fix, fails, unknowns)
    unknowns += ["%s holds a build variable that cannot be resolved here" % show(k) for k in sorted(unresolved)]
    return _scan_verdict(fails, unknowns, skipped, "declared: %s" % show_list(sorted(strings)),
                         [keys[0] for keys, _, certain in required if certain])


def check_android_permissions(declared, blocked, required, fix, skipped, maybe):
    """required: [(permission, how, file, certain)]."""
    fails = []
    unknowns = []
    for perm, how, rel, certain in required:
        if perm in blocked:
            _code_gap(perm, rel, certain, None, ", which the project removes", fix(perm), fails, unknowns)
        elif how == "declare" and perm not in declared:
            _code_gap(perm, rel, certain, maybe, ", which is not declared", fix(perm), fails, unknowns)
    dangerous = sorted(p for p in declared if p in DANGEROUS)
    return _scan_verdict(fails, unknowns, skipped, "declared dangerous: %s" % show_list(dangerous),
                         [r[0] for r in required if r[3]])


# Resolved inputs ---------------------------------------------------------


def _resolved_file(path):
    """Classify one operator file by its content: (kind, data)."""
    label = show(path)
    try:
        data = read_bytes(path, contained=False)
        if data.lstrip(b"\xef\xbb\xbf \t\r\n").startswith(b"<"):
            root = parse_xml(data, label)
            if root.tag != "manifest":
                raise Unknown("root element is not manifest")
            if not root.get("package"):
                raise UsageError("--resolved %s is not a built manifest: it has no package attribute" % label)
            return "android", root
        parsed = json.loads(data.decode("utf-8-sig"))
    except (Unknown, ValueError, RecursionError) as e:
        raise UsageError("--resolved %s could not be read (%s)" % (label, clean(e) or type(e).__name__))
    if isinstance(parsed, dict) and isinstance(parsed.get("expo"), dict):
        return "expo", parsed["expo"]
    if isinstance(parsed, dict) and isinstance(parsed.get("slug"), str):
        return "expo", parsed
    if parsed and isinstance(parsed, list) and all(isinstance(e, dict) and isinstance(e.get("buildSettings"), dict) for e in parsed):
        return "xcode", parsed
    raise UsageError("--resolved %s is not Xcode settings, an Expo config, or an Android manifest" % label)


def load_resolved(paths):
    resolved = {}
    for path in paths:
        kind, data = _resolved_file(path)
        if kind in resolved:
            raise UsageError("--resolved was given two %s files" % kind)
        resolved[kind] = data
    return resolved


def xcode_settings(entries, framework):
    """Return the settings of the one application target, only for a Release device resolve of this checkout."""
    if entries is None:
        first = "`flutter build ios --release --no-codesign --config-only`, then " if framework == "flutter" else ""
        raise Unknown("no resolved Xcode settings; run %s`xcodebuild -showBuildSettings -json -configuration Release -sdk iphoneos` "
                      "with -project or -workspace and -scheme, save the output outside the project, and pass --resolved <file>" % first)
    apps = [e["buildSettings"] for e in entries if e["buildSettings"].get("PRODUCT_TYPE") == APP_PRODUCT_TYPE]
    if len(apps) != 1:
        raise Unknown("the resolved Xcode settings hold %d application targets, not one; pick one with -scheme" % len(apps))
    settings = dict((k, v) for k, v in apps[0].items() if isinstance(v, str))
    if settings.get("CONFIGURATION") != "Release" or settings.get("PLATFORM_NAME") != "iphoneos":
        raise Unknown("the resolved Xcode settings are not for Release on iphoneos, so they are not the release truth")
    root = settings.get("SRCROOT")
    if not root or not os.path.isabs(root) or not _inside(root, PROJECT["real"]):
        raise Unknown("SRCROOT in the resolved Xcode settings is not inside this project; resolve from this checkout")
    return settings


# Apple native ------------------------------------------------------------


class Apple:
    FIX_ICON = "add a 1024x1024 PNG with no alpha channel to the app icon set in the asset catalog"

    def __init__(self, settings):
        self.settings = settings
        self.root = settings["SRCROOT"]
        self.generated = settings.get("GENERATE_INFOPLIST_FILE") == "YES"

    def expand(self, value):
        for _ in range(8):
            m = re.search(r"\$\(([^)$]*)\)|\$\{([^}$]*)\}", value)
            if not m:
                if "$" in value:
                    raise Unknown("%s does not resolve" % show(value))
                return value
            var = m.group(1) if m.group(1) is not None else m.group(2)
            if var not in self.settings:
                raise Unknown("%s holds %s, which the resolved settings do not define" % (show(value), show("$(%s)" % var)))
            value = value[:m.start()] + self.settings[var] + value[m.end():]
        raise Unknown("%s does not resolve" % show(value))

    def plist(self):
        rel = self.settings.get("INFOPLIST_FILE")
        if not rel:
            return {}
        path = os.path.join(self.root, self.expand(rel))
        data = read_bytes(path)
        try:
            parsed = plistlib.loads(data)
        except Exception as e:
            raise Unknown("%s could not be read as a plist (%s)" % (show(_rel(path)), type(e).__name__))
        if not isinstance(parsed, dict):
            raise Unknown("%s is not a plist dictionary" % show(_rel(path)))
        return parsed

    def app_name(self):
        plist = self.plist()
        fix = "set the Display Name of the app target in Xcode, which writes CFBundleDisplayName"
        generated = self.settings.get("INFOPLIST_KEY_CFBundleDisplayName") if self.generated else None
        for source, value in (("CFBundleDisplayName", plist.get("CFBundleDisplayName")),
                              ("INFOPLIST_KEY_CFBundleDisplayName", generated),
                              ("CFBundleName", plist.get("CFBundleName")),
                              ("PRODUCT_NAME", self.settings.get("PRODUCT_NAME"))):
            if value is not None:
                return valid_name(self.expand(value) if isinstance(value, str) else "", source, fix)
        raise Fail("no app name in the resolved settings or Info.plist", fix)

    def bundle_id(self):
        fix = "set a reverse-DNS Bundle Identifier on the app target in Xcode (letters, digits, hyphens, periods)"
        value = self.settings.get("PRODUCT_BUNDLE_IDENTIFIER")
        source = "PRODUCT_BUNDLE_IDENTIFIER"
        if value is None:
            value = self.plist().get("CFBundleIdentifier")
            source = "CFBundleIdentifier"
        if value is None:
            raise Fail("no bundle id in the resolved settings or Info.plist", fix)
        return valid_bundle_id(self.expand(value) if isinstance(value, str) else "", source, fix)

    def _icon_set(self):
        name = self.settings.get("ASSETCATALOG_COMPILER_APPICON_NAME")
        if name is None:
            raise Fail("no ASSETCATALOG_COMPILER_APPICON_NAME in the resolved settings", Apple.FIX_ICON)
        name = self.expand(name)
        if "/" in name or ".." in name:
            raise Unknown("ASSETCATALOG_COMPILER_APPICON_NAME %s is not a plain icon set name" % show(name))
        sets = []
        for current, dirs, _ in os.walk(self.root):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            if name + ".icon" in dirs:
                raise Unknown("%s is an Icon Composer file; Xcode renders its sizes and alpha at build time, "
                              "so check the archived app" % show(name + ".icon"))
            in_catalog = any(part.endswith(".xcassets") for part in os.path.relpath(current, self.root).split(os.sep))
            if name + ".appiconset" in dirs and in_catalog:
                sets.append(os.path.join(current, name + ".appiconset"))
        if not sets:
            raise Fail("no %s under %s" % (show(name + ".appiconset"), show(_rel(self.root))), Apple.FIX_ICON)
        if len(sets) > 1:
            raise Unknown("more than one %s" % show(name + ".appiconset"))
        contents = load_json(os.path.join(sets[0], "Contents.json"))
        images = contents.get("images") if isinstance(contents, dict) else None
        if not isinstance(images, list):
            raise Unknown("%s has no images list" % show(_rel(os.path.join(sets[0], "Contents.json"))))
        return sets[0], [i for i in images if isinstance(i, dict) and _ios_icon_entry(i)]

    def icon_sizes(self):
        folder, images = self._icon_set()
        if len(images) > MAX_DECLARED_ICONS:
            raise Unknown("Contents.json lists %d icons, over the %d this script checks" % (len(images), MAX_DECLARED_ICONS))
        fails = []
        unknowns = []
        marketing = None
        checked = 0
        for image in images:
            is_marketing = _is_marketing(image)
            if is_marketing and not image.get("appearances"):
                marketing = image
            filename = image.get("filename")
            if not filename:
                continue
            path = os.path.join(folder, str(filename))
            try:
                contain(path)
                if not os.path.lexists(path):
                    fails.append(("%s is listed in Contents.json but missing" % show(filename), Apple.FIX_ICON))
                    continue
                width, height, _ = image_info(path)
            except Unknown as e:
                unknowns.append(str(e))
                continue
            checked += 1
            want = (1024, 1024) if is_marketing else _icon_pixels(image)
            if want and (width, height) != want:
                fails.append(("%s is %dx%d, expected %dx%d" % (show(filename), width, height, want[0], want[1]),
                              "export the icon at %dx%d" % want))
        if marketing is None or not marketing.get("filename"):
            fails.insert(0, ("no 1024x1024 App Store icon in the app icon set", Apple.FIX_ICON))
        wells = [i for i in images if i.get("idiom") in ("iphone", "ipad")]
        if wells and not any(i.get("filename") for i in wells):
            unknowns.append("the set lists device sizes but fills none of them; no rule found says the App Store icon alone is enough")
        return verdict(fails, unknowns, "%s: 1024x1024 App Store icon present, %d icon files sized correctly" % (
            show(os.path.basename(folder)), checked))

    def icon_alpha(self):
        folder, images = self._icon_set()
        marketing = [i for i in images if _is_marketing(i) and not i.get("appearances") and i.get("filename")]
        if not marketing:
            raise Unknown("no App Store icon file to read; see icon-sizes")
        filename = str(marketing[0]["filename"])
        if _has_alpha(os.path.join(folder, filename)):
            raise Unknown("%s has an alpha channel or transparency; no current Apple document states a rule for this, "
                          "so confirm by validating the archive in Xcode" % show(filename))
        return "%s has no alpha channel or tRNS chunk" % show(filename)

    def strings(self):
        values = {}
        if self.generated:
            for key, value in self.settings.items():
                m = re.fullmatch(r"INFOPLIST_KEY_(NS\w+UsageDescription)", key)
                if m:
                    values[m.group(1)] = value
        for key, value in self.plist().items():
            if isinstance(key, str) and re.fullmatch(r"NS\w+UsageDescription", key):
                values[key] = value if isinstance(value, str) else ""
        strings = {}
        unresolved = set()
        for key, value in values.items():
            try:
                strings[key] = self.expand(value)
            except Unknown:
                unresolved.add(key)
        return strings, unresolved

    def fix_for(self, key):
        return "no string for it", "add %s with a specific reason to Info.plist" % show(key)


def _ios_icon_entry(image):
    return image.get("idiom") in ("iphone", "ipad", "ios-marketing") or (
        image.get("idiom") == "universal" and image.get("platform") == "ios")


def _is_marketing(image):
    return image.get("idiom") == "ios-marketing" or (
        image.get("idiom") == "universal" and image.get("platform") == "ios" and image.get("size") == "1024x1024")


def _icon_pixels(image):
    size = re.fullmatch(r"([\d.]+)x([\d.]+)", str(image.get("size", "")))
    scale = re.fullmatch(r"(\d+)x", str(image.get("scale", "1x")))
    if not size or not scale:
        return None
    return int(float(size.group(1)) * int(scale.group(1))), int(float(size.group(2)) * int(scale.group(1)))


def _has_alpha(path):
    _, _, alpha = image_info(path)
    if alpha is None:
        raise Unknown("%s is not a PNG, so its alpha cannot be read" % show(_rel(path)))
    return alpha


# Android native ----------------------------------------------------------


class AndroidNative:
    def __init__(self, root, built):
        self.root = root
        self.built = built
        self.module = os.path.join(root, "app") if os.path.isdir(os.path.join(root, "app")) else root
        self.main = os.path.join(self.module, "src", "main")
        self._manifest = None
        self.debug = built is not None and self._built_attr("debuggable") not in (None, "false")

    def manifest(self):
        path = os.path.join(self.main, "AndroidManifest.xml")
        if not os.path.lexists(path):
            raise Unknown("%s is missing; a Gradle source set can relocate it" % show(_rel(path)))
        if self._manifest is None:
            self._manifest = read_xml(path)
        return self._manifest

    def _built_attr(self, attr):
        application = self.built.find("application")
        return application.get(ANDROID_NS + attr) if application is not None else None

    def _source_attr(self, attr, fix):
        """A value src/main lacks can come from another manifest, so only a built manifest confirms it is missing."""
        if self.built is not None and self._built_attr(attr) is None:
            self._no_debug()
            raise Fail("android:%s is missing on <application> in the built manifest" % attr, fix)
        node = self.manifest().find("application")
        value = node.get(ANDROID_NS + attr) if node is not None else None
        if value is None:
            raise Unknown("android:%s is missing from src/main, and a library or build variant manifest can supply it; "
                          "pass a built manifest with --resolved <file> to confirm" % attr)
        return value

    def _no_debug(self):
        if self.debug:
            raise Unknown("the resolved manifest is from a debuggable build, which is not the release truth; use a release build")

    def maybe(self):
        return None if self.built is not None else "no built manifest shows it, and a library can supply it"

    def app_name(self):
        fix = 'set android:label on <application>, usually "@string/app_name" in res/values/strings.xml'
        if self.built is not None:
            built = self._built_attr("label")
            if built is not None and not built.startswith("@") and "${" not in built:
                self._no_debug()
                return valid_name(built, "the built manifest (android:label)", fix)
        label = self._source_attr("label", fix)
        if label.startswith("@string/"):
            return self._string_name(label, fix)
        if "${" in label or label.startswith("@"):
            raise Unknown("android:label %s is a placeholder or a reference this script does not follow" % show(label))
        return valid_name(label, "android:label", fix)

    def _string_name(self, label, fix):
        name = label[len("@string/"):]
        folder = os.path.join(self.main, "res", "values")
        for file in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
            path = os.path.join(folder, file)
            for node in read_xml(path).findall("string") if file.endswith(".xml") else []:
                if node.get("name") == name:
                    return valid_name("".join(node.itertext()), "%s (%s)" % (show(_rel(path)), show(name)), fix)
        raise Unknown("%s is not in res/values; a Gradle resValue or a flavor can supply it" % show(label))

    def package(self):
        if self.built is None:
            raise Unknown("the application id comes from Gradle, which this script does not read; build a release from the "
                          "current commit, read its manifest with apkanalyzer or bundletool, and pass --resolved <file>")
        self._no_debug()
        fix = 'set applicationId in the app module\'s build.gradle to your own reverse-DNS id, e.g. "com.yourname.app"'
        return valid_package(self.built.get("package"), "the built manifest", fix)

    def _check_layer(self, ref, base_dp, fails, unknowns, fix):
        """Return how many files were judged."""
        m = re.fullmatch(r"@(mipmap|drawable)/(\w+)", ref or "")
        if not m:
            unknowns.append("icon reference %s is not a @mipmap or @drawable file" % show(ref))
            return 0
        res = os.path.join(self.main, "res")
        files = []
        for folder in sorted(os.listdir(res)) if os.path.isdir(res) else []:
            if folder == m.group(1) or folder.startswith(m.group(1) + "-"):
                for ext in (".png", ".webp", ".xml", ".jpg", ".jpeg"):
                    if os.path.lexists(os.path.join(res, folder, m.group(2) + ext)):
                        files.append((folder, os.path.join(res, folder, m.group(2) + ext)))
        if not files:
            fails.append(("%s has no file under res/" % show(ref), fix))
        count = 0
        for folder, path in files:
            label = show(os.path.join(folder, os.path.basename(path)))
            try:
                if path.endswith(".xml"):
                    count += self._check_xml_drawable(read_xml(path), label, base_dp, fails, unknowns, fix)
                    continue
                width, height, _ = image_info(path)
            except Unknown as e:
                unknowns.append(str(e))
                continue
            density = re.search(r"-(mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)\b", folder)
            if not density:
                unknowns.append("%s has no density qualifier, so its size cannot be judged" % label)
                continue
            want = int(base_dp * DENSITY[density.group(1)])
            count += 1
            if (width, height) != (want, want):
                fails.append(("%s is %dx%d, expected %dx%d" % (label, width, height, want, want),
                              "export it at %dx%d (%d dp at %s)" % (want, want, base_dp, density.group(1))))
        return count

    def _check_xml_drawable(self, node, label, base_dp, fails, unknowns, fix):
        if node.tag == "adaptive-icon":
            for tag in ("foreground", "background"):
                if node.find(tag) is None:
                    unknowns.append("%s has no <%s>, and no source says the build tools reject that" % (label, tag))
            count = 0
            for tag in ("foreground", "background", "monochrome"):
                layer = node.find(tag)
                ref = layer.get(ANDROID_NS + "drawable") if layer is not None else None
                if layer is None:
                    continue
                if ref is None and len(layer):
                    unknowns.append("<%s> in %s is an inline drawable, whose size cannot be judged here" % (tag, label))
                elif ref is None:
                    fails.append(("<%s> in %s has no drawable" % (tag, label), fix))
                elif tag != "background" or not ref.startswith(("@color/", "@android:color/", "#")):
                    count += self._check_layer(ref, 108, fails, unknowns, fix)
            return count
        if node.tag == "vector" and base_dp == 108:
            for attr in ("width", "height"):
                value = node.get(ANDROID_NS + attr)
                if value != "108dp":
                    fails.append(("%s has android:%s %s, expected 108dp" % (label, attr, show(value)),
                                  "size all adaptive layers to 108x108 dp"))
            return 1
        unknowns.append("%s is a %s drawable, whose size cannot be judged here" % (label, show(node.tag)))
        return 0

    def icon_sizes(self):
        fix = 'set android:icon="@mipmap/ic_launcher" on <application> and add the icon with Image Asset Studio'
        ref = self._source_attr("icon", fix)
        fails = []
        unknowns = []
        count = self._check_layer(ref, 48, fails, unknowns, fix)
        return verdict(fails, unknowns, "%s: %d file(s) checked" % (show(ref), count))

    def declared(self):
        declared = set()
        removed = set()
        self._no_debug()
        manifest = self.built if self.built is not None else self.manifest()
        for tag in ("uses-permission", "uses-permission-sdk-23"):
            for node in manifest.findall(tag):
                name = (node.get(ANDROID_NS + "name") or "").replace("android.permission.", "")
                if node.get(TOOLS_NS + "node") == "remove":
                    removed.add(name)
                else:
                    declared.add(name)
        return declared, removed

    def fix_permission(self, perm):
        return "add <uses-permission> for %s to AndroidManifest.xml" % show("android.permission." + perm)


# Expo config -------------------------------------------------------------


class ExpoConfig:
    def __init__(self, project, config):
        self.project = project
        self.config = config
        self.why = None
        self.disabled = set()
        if config is not None:
            return
        for name in ("app.config.js", "app.config.ts"):
            if os.path.lexists(os.path.join(project, name)):
                self.why = "%s is dynamic; run `npx expo config --json`, save the output, and pass it with --resolved <file>" % name
                return
        path = os.path.join(project, "app.config.json" if os.path.lexists(os.path.join(project, "app.config.json")) else "app.json")
        try:
            data = load_json(path) if os.path.lexists(path) else {}
            if not isinstance(data, dict):
                raise Unknown("%s is not a JSON object" % show(_rel(path)))
            self.config = data["expo"] if isinstance(data.get("expo"), dict) else data
        except Unknown as e:
            self.why = str(e)

    def cfg(self):
        if self.why:
            raise Unknown(self.why)
        return self.config

    def section(self, name):
        value = self.cfg().get(name)
        return value if isinstance(value, dict) else {}

    def plugins(self):
        plugins = {}
        items = self.cfg().get("plugins")
        for item in items if isinstance(items, list) else []:
            if isinstance(item, str):
                plugins.setdefault(item, {})
            elif isinstance(item, list) and item and isinstance(item[0], str):
                plugins[item[0]] = item[1] if len(item) > 1 and isinstance(item[1], dict) else {}
        return plugins

    def maybe(self):
        other = [name for name in self.plugins() if name not in EXPO_OPTIONS]
        if other:
            return "the config plugin %s can set it" % show(other[0])
        items = self.cfg().get("plugins")
        if isinstance(items, list) and any(not isinstance(i, (str, list)) for i in items):
            return "a config plugin entry that is not a name can set it"
        return None

    def _no_local_plugin(self):
        local = [name for name in self.plugins() if name.startswith((".", "/"))]
        if local:
            raise Unknown("the local config plugin %s can rewrite this; run `npx expo prebuild` and check the native project" % show(local[0]))

    def _name(self):
        """Expo's own default is exp.name ?? the package.json name."""
        self._no_local_plugin()
        name = self.cfg().get("name")
        if name is not None:
            return name, "the Expo config (name)"
        path = os.path.join(self.project, "package.json")
        data = load_json(path) if os.path.lexists(path) else None
        name = data.get("name") if isinstance(data, dict) else None
        if isinstance(name, str):
            return name, "package.json name, Expo's default when the config sets none"
        raise Unknown("no name in the Expo config or package.json, so Expo uses the folder name; set expo.name")

    def image_path(self, value, what):
        """Return an absolute path for a config image, or raise for remote and missing files."""
        if not isinstance(value, str) or re.match(r"https?://", value):
            raise Unknown("%s is a remote URL or not a path (%s), so its size cannot be read" % (what, show(value)))
        path = os.path.normpath(os.path.join(self.project, value))
        contain(path)
        if not os.path.exists(path):
            raise Fail("%s points at %s, which is missing" % (what, show(value)), "add the file or fix the path in the app config")
        return path

    def _image_sizes(self, layers, fails, unknowns):
        """Yield (what, value, width, height) for each layer with a readable header; the rest go on the lists."""
        for what, value in layers:
            if not value:
                continue
            try:
                width, height, _ = image_info(self.image_path(value, what))
            except Fail as e:
                fails.append((e.reason, e.fix))
            except Unknown as e:
                unknowns.append(str(e))
            else:
                yield what, value, width, height

    def app_name(self):
        name, source = self._name()
        return valid_name(name, source, "set expo.name in the app config")

    def web_name(self):
        self._no_local_plugin()
        fix = "set expo.name or expo.web.name in the app config"
        if self.section("web").get("name"):
            return valid_name(self.section("web")["name"], "the Expo config (web.name)", fix)
        name, source = self._name()
        return valid_name(name, source, fix)

    def bundle_id(self):
        self._no_local_plugin()
        value = self.section("ios").get("bundleIdentifier")
        return valid_bundle_id(value, "ios.bundleIdentifier", "set ios.bundleIdentifier in the app config to a reverse-DNS id")

    def package(self):
        self._no_local_plugin()
        value = self.section("android").get("package")
        return valid_package(value, "android.package", "set android.package in the app config to your own reverse-DNS id")

    def _ios_icons(self):
        icon = self.section("ios").get("icon")
        if isinstance(icon, dict) or (isinstance(icon, str) and icon.endswith(".icon")):
            raise Unknown("ios.icon is an Icon Composer file or a set of appearance variants; check the built app")
        return "ios.icon" if icon else "icon", icon or self.cfg().get("icon")

    def icon_sizes_ios(self):
        what, value = self._ios_icons()
        fix = "set icon in the app config to a 1024x1024 PNG"
        if not value:
            raise Fail("no icon in the app config", fix)
        width, height, _ = image_info(self.image_path(value, what))
        if (width, height) != (1024, 1024):
            raise Fail("%s %s is %dx%d, expected 1024x1024" % (what, show(value), width, height), fix)
        return "%s is 1024x1024" % show(value)

    def icon_alpha_ios(self):
        what, value = self._ios_icons()
        if not value:
            raise Unknown("no icon in the app config; see icon-sizes")
        try:
            path = self.image_path(value, what)
        except Fail:
            raise Unknown("%s is missing; see icon-sizes" % show(value))
        if _has_alpha(path):
            raise Fail("%s has an alpha channel or transparency; Expo's docs say the icon has no transparent pixels" % show(value),
                       "flatten %s onto your intended background and re-export without alpha; "
                       "otherwise Expo's prebuild fills transparency with white" % show(value))
        return "%s has no alpha channel or tRNS chunk" % show(value)

    def icon_sizes_android(self):
        android = self.section("android")
        adaptive = android.get("adaptiveIcon") if isinstance(android.get("adaptiveIcon"), dict) else {}
        layers = []
        if adaptive.get("foregroundImage"):
            layers = [("android.adaptiveIcon." + k, adaptive.get(k)) for k in ("foregroundImage", "backgroundImage", "monochromeImage")]
        if android.get("icon") or (not layers and self.cfg().get("icon")):
            layers.append(("android.icon", android.get("icon") or self.cfg().get("icon")))
        if not layers:
            raise Fail("no icon in the app config", "set android.adaptiveIcon.foregroundImage to a PNG of at least 512x512")
        fails = []
        unknowns = []
        sizes = {}
        done = []
        for what, value, width, height in self._image_sizes(layers, fails, unknowns):
            sizes[what] = (width, height)
            done.append("%s %dx%d" % (show(value), width, height))
            if width != height or (width < 512 and not what.endswith("monochromeImage")):
                fails.append(("%s %s is %dx%d; use a square of at least 512x512" % (what, show(value), width, height),
                              "export a square PNG of at least 512x512"))
        back = sizes.get("android.adaptiveIcon.backgroundImage")
        fore = sizes.get("android.adaptiveIcon.foregroundImage")
        if back and fore and back != fore:
            fails.append(("the adaptive background image is not the same size as the foreground image",
                          "export both layers at the same dimensions"))
        return verdict(fails, unknowns, ", ".join(done))

    def web_icon(self):
        favicon = self.section("web").get("favicon")
        if not favicon:
            raise Fail("no web.favicon in the app config", "set web.favicon in the app config")
        check_image_file(self.image_path(favicon, "web.favicon"))
        return "web.favicon %s exists" % show(favicon)

    def strings(self):
        info = self.section("ios").get("infoPlist")
        strings = {}
        for key, value in (info.items() if isinstance(info, dict) else []):
            if re.fullmatch(r"NS\w+UsageDescription", key):
                strings[key] = value if isinstance(value, str) else ""
        for module, options in self.plugins().items():
            for option, keys in EXPO_OPTIONS.get(module, {}).items():
                for key in keys if option in options else ():
                    if options[option] is False:
                        strings.pop(key, None)
                        self.disabled.add(key)
                    elif isinstance(options[option], str):
                        strings[key] = options[option]
                        self.disabled.discard(key)
        return strings, set()

    def fix_for(self, key):
        reason = "without a string Expo writes a generic default that its docs say to tailor"
        if key in self.disabled:
            reason = "a plugin option of false removes it"
        return reason, "set a specific reason in the module's plugin option, or in %s" % show("ios.infoPlist." + key)

    def declared(self):
        android = self.section("android")
        declared = set(_short_perms(android.get("permissions")))
        blocked = set(_short_perms(android.get("blockedPermissions")))
        plugins = self.plugins()
        for module, option, perm in EXPO_ANDROID_OFF:
            if plugins.get(module, {}).get(option) is False:
                blocked.add(perm)
        if plugins.get("expo-location", {}).get("isAndroidBackgroundLocationEnabled") is True:
            declared.add("ACCESS_BACKGROUND_LOCATION")
        return declared, blocked

    def fix_permission(self, perm):
        return ("add %s to android.permissions and remove any plugin option or blockedPermissions entry that excludes it"
                % show("android.permission." + perm))


def check_image_file(path):
    """For a web icon with no size to read: an image extension and at least one byte."""
    if not path.lower().endswith(WEB_ICON_EXTENSIONS):
        raise Unknown("%s does not have an image file extension" % show(_rel(path)))
    if not read_bytes(path, limit=IMAGE_PREFIX_BYTES, prefix=True):
        raise Unknown("%s is empty" % show(_rel(path)))


def _short_perms(value):
    return [p.replace("android.permission.", "") for p in value if isinstance(p, str)] if isinstance(value, list) else []


# Web ---------------------------------------------------------------------


class HeadReader(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.title = None
        self.in_title = False
        self.head_over = False
        self.base = False
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag in ("body", "svg"):
            self.head_over = True
        if self.head_over:
            return
        self.base = self.base or tag == "base"
        if tag == "title" and self.title is None:
            self.in_title = True
            self.title = ""
        elif tag == "link":
            self.links.append(dict(attrs))

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
        elif tag == "head":
            self.head_over = True

    def handle_data(self, data):
        if self.in_title:
            self.title += data


class Web:
    def __init__(self, project, framework, expo=None):
        self.project = project
        self.framework = framework
        self.expo = expo
        self.base = os.path.join(project, "web") if framework == "flutter" else project
        self.configured_in_code = framework in ("vite", "nextjs")
        self._head = None
        self._head_read = False
        self.app_dir = os.path.join(project, "app")
        if not os.path.isdir(self.app_dir) and os.path.isdir(os.path.join(project, "src", "app")):
            self.app_dir = os.path.join(project, "src", "app")

    def head(self):
        if not self._head_read:
            path = os.path.join(self.base, "index.html")
            if self.framework != "nextjs" and os.path.lexists(path):
                self._head = HeadReader()
                self._head.feed(read_text(path))
            self._head_read = True
        return self._head

    def manifest(self):
        """Return (path, data) for the manifest the build uses, or (None, None). Malformed raises Unknown."""
        if self.framework == "nextjs":
            candidates = [os.path.join(self.app_dir, name) for name in ("manifest.json", "manifest.webmanifest")]
        else:
            head = self.head()
            links = [link["href"] for link in (head.links if head else [])
                     if "manifest" in (link.get("rel") or "").lower().split() and link.get("href")]
            candidates = [found for found in (self._find(href, self.base) for href in links if not self._base_relative(href)) if found]
        for path in candidates:
            if os.path.lexists(path):
                data = load_json(path)
                if not isinstance(data, dict):
                    raise Unknown("%s is not a JSON object" % show(_rel(path)))
                return path, data
        return None, None

    def _base_relative(self, ref):
        """<base> is not resolved, so a relative reference beside one has no known target."""
        head = self.head()
        return head and head.base and not re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:|/", ref)

    def _next_code_manifest(self):
        """A manifest.ts or manifest.js generates the manifest at build time, whatever else exists."""
        for name in ("manifest.ts", "manifest.js"):
            path = os.path.join(self.app_dir, name)
            if self.framework == "nextjs" and os.path.lexists(path):
                return "%s generates the web manifest at build time, so it is not read" % show(_rel(path))
        return None

    def _find(self, ref, base):
        ref = ref.split("?")[0].split("#")[0]
        rel = ref.lstrip("/")
        roots = [os.path.join(self.base, "public"), self.base] if ref.startswith("/") else [base, os.path.join(self.base, "public"), self.base]
        paths = [os.path.normpath(os.path.join(root, rel)) for root in roots]
        inside = [path for path in paths if _inside(path, PROJECT["real"])]
        for path in inside:
            if os.path.lexists(path):
                return path
        if len(inside) < len(paths):
            raise Unknown("%s points outside the project" % show(ref))
        return None

    def app_name(self):
        if self.expo:
            return self.expo.web_name()
        fix = "set <title> in index.html or name in the web manifest"
        code_manifest = self._next_code_manifest()
        if code_manifest:
            raise Unknown(code_manifest)
        head = self.head()
        if head and head.base and head.title is None:
            raise Unknown("index.html has a <base> and no <title>; <base> is not resolved")
        path, data = (None, None) if head and head.base else self.manifest()
        if data is not None:
            name = data.get("name") or data.get("short_name")
            if name is not None:
                return valid_name(name, show(_rel(path)), fix)
        if head and head.title is not None:
            if PLACEHOLDER.search(head.title):
                raise Unknown("<title> holds a build placeholder (%s)" % show(head.title))
            if self.configured_in_code and not head.title.strip():
                raise Unknown("<title> is empty, no linked web manifest names the app, and a JS or TS config may set it")
            return valid_name(head.title, "index.html <title>", fix)
        if self.configured_in_code:
            raise Unknown("no name in a web manifest or <title>, and a JS or TS config may set it")
        raise Fail("no name in a web manifest or <title>", fix)

    def icon_sizes(self):
        if self.expo:
            return self.expo.web_icon()
        fix = 'add an icon file and declare it with <link rel="icon"> or in the web manifest'
        fails = []
        unknowns = []
        declared = []
        code_manifest = self._next_code_manifest()
        if code_manifest:
            unknowns.append(code_manifest)
        path, data = self.manifest()
        if data is not None:
            icons = data.get("icons", [])
            for icon in icons if isinstance(icons, list) else []:
                if isinstance(icon, dict) and icon.get("src"):
                    declared.append((str(icon["src"]), icon.get("sizes"), os.path.dirname(path), "manifest"))
        head = self.head()
        for link in head.links if head else []:
            rel = (link.get("rel") or "").lower().split()
            if link.get("href") and self._base_relative(link["href"]) and {"icon", "apple-touch-icon", "manifest"} & set(rel):
                unknowns.append("%s is relative beside a <base>, which is not resolved" % show(link["href"]))
            elif link.get("href") and ("icon" in rel or "apple-touch-icon" in rel):
                declared.append((link["href"], link.get("sizes"), self.base, "index.html"))
        if self.framework == "nextjs":
            self._next_icons(declared, unknowns)
        if len(declared) > MAX_DECLARED_ICONS:
            raise Unknown("the project declares %d icons, over the %d this script checks" % (len(declared), MAX_DECLARED_ICONS))
        for ref, sizes, base, source in declared:
            self._check_declared(ref, sizes, base, source, fails, unknowns, fix)
        if not declared and not unknowns:
            if self.configured_in_code:
                raise Unknown("no icon declared in a web manifest, index.html, or app/, and a JS or TS config may set one")
            fails.append(("no icon declared in a web manifest or index.html", fix))
        return verdict(fails, unknowns, "%d declared icon(s) exist with matching sizes" % len(declared))

    def _next_icons(self, declared, unknowns):
        for name in sorted(os.listdir(self.app_dir)) if os.path.isdir(self.app_dir) else []:
            stem, ext = os.path.splitext(name)
            if re.fullmatch(r"(favicon|icon\d*|apple-icon\d*)", stem):
                if ext in (".ts", ".tsx", ".js", ".jsx"):
                    unknowns.append("%s generates its icon at runtime" % show("app/" + name))
                else:
                    declared.append((name, None, self.app_dir, "app/"))

    def _check_declared(self, ref, sizes, base, source, fails, unknowns, fix):
        if re.match(r"(https?:)?//|data:", ref) or PLACEHOLDER.search(ref):
            unknowns.append("icon %s in %s is remote, inline, or a build placeholder, so it is not checked" % (show(ref), source))
            return
        try:
            path = self._find(ref, base)
            if path is None:
                fails.append(("%s declares %s, which is missing" % (source, show(ref)), fix))
                return
            if not path.lower().endswith((".png", ".webp")):
                check_image_file(path)
                return
            width, height, _ = image_info(path)
        except Unknown as e:
            unknowns.append(str(e))
            return
        if isinstance(sizes, str) and sizes.strip().lower() != "any":
            if "%dx%d" % (width, height) not in sizes.lower().split():
                fails.append(("%s is %dx%d but %s declares %s" % (show(ref), width, height, source, show(sizes)),
                              "export the file at the declared size or correct the declaration"))


# State -------------------------------------------------------------------


def _state_scalar(value):
    if value.startswith(('"', "'")):
        m = re.fullmatch(r"""(?:"([^"\\]*)"|'([^']*)')(?:\s+#.*)?""", value)
        if not m:
            raise Unknown(".app-creators/state.md holds a quoted value that is not a simple string")
        return m.group(1) or m.group(2) or ""
    value = re.split(r"(?:^|\s)#", value, maxsplit=1)[0].strip()
    return "" if value in ("~", "null", "Null", "NULL") else value


def _state_value(lines, keys):
    """Walk block-form keys. An absent key or an empty map is an empty value; any other flow map or block scalar is Unknown."""
    depth = 0
    parent = -1
    child = None
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent <= parent:
            return ""
        child = indent if child is None else child
        key, colon, rest = stripped.partition(":")
        if indent != child or not colon or (rest and not rest[0].isspace()) or key.strip().strip("\"'") != keys[depth]:
            continue
        value = rest.strip()
        if re.fullmatch(r"\{\s*\}(?:\s+#.*)?", value):
            return ""
        if value[:1] in ("{", "|", ">"):
            raise Unknown(".app-creators/state.md has a flow map or block scalar on this path, which is not read")
        scalar = _state_scalar(value)
        if depth == len(keys) - 1:
            return scalar
        if scalar:
            return ""
        depth += 1
        parent = indent
        child = None
    return ""


def privacy_url(project):
    path = os.path.join(project, ".app-creators", "state.md")
    label = ".app-creators/state.md"
    if not os.path.lexists(path):
        raise Unknown("%s is missing; run app-creators first" % label)
    lines = read_text(path).splitlines()
    if not lines or lines[0].strip() != "---":
        raise Unknown("%s has no frontmatter" % label)
    for end, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            return _state_value(lines[1:end], ("provided", "publish-readiness", "privacy_policy_url"))
    raise Unknown("%s has no closing frontmatter line" % label)


def check_privacy(project, platform, collects):
    value = privacy_url(project)
    fix = "publish a privacy policy page and set provided.publish-readiness.privacy_policy_url in .app-creators/state.md"
    if value:
        try:
            parts = urlsplit(value)
            good = parts.scheme in ("http", "https") and bool(parts.hostname) and not re.search(r"\s", value) and clean(value) == value
        except ValueError:
            good = False
        if not good:
            raise Fail("privacy_policy_url %s is not an http(s) URL" % show(value), fix)
        return show(value)
    if platform != "web":
        store = "App Store Connect" if platform == "ios" else "Google Play"
        raise Fail("no privacy policy URL; %s requires one for every app" % store, fix)
    if collects == "yes":
        raise Fail("no privacy policy URL, and the confirmed inventory lists collected data", fix)
    if collects == "no":
        return "no privacy policy URL; the confirmed inventory lists no collected data"
    raise Unknown("no privacy policy URL; pass --collects-data yes or no from the confirmed inventory")


# Framework detection and routes ------------------------------------------


def _package_deps(project):
    data = read_json_quietly(os.path.join(project, "package.json"))
    deps = {}
    for key in ("devDependencies", "dependencies"):
        section = data.get(key) if isinstance(data, dict) else None
        deps.update(section if isinstance(section, dict) else {})
    return deps


def _is_flutter(project):
    path = os.path.join(project, "pubspec.yaml")
    if not os.path.lexists(path):
        return False
    try:
        return "flutter" in read_text(path)
    except Unknown:
        return True


def _is_android_app(project):
    for folder in (project, os.path.join(project, "app")):
        if os.path.lexists(os.path.join(folder, "src", "main", "AndroidManifest.xml")):
            if any(os.path.lexists(os.path.join(folder, name)) for name in GRADLE_FILES):
                return True
    return False


def detect_framework(project):
    deps = _package_deps(project)
    has = lambda name: os.path.exists(os.path.join(project, name))
    configs = [read_json_quietly(os.path.join(project, name)) for name in ("app.json", "app.config.json")]
    if "expo" in deps or any(isinstance(data, dict) and "expo" in data for data in configs):
        return "expo"
    if _is_flutter(project):
        return "flutter"
    if any(e.endswith((".xcodeproj", ".xcworkspace")) and os.path.isdir(os.path.join(project, e)) for e in os.listdir(project)):
        return "xcode"
    if _is_android_app(project):
        return "kotlin"
    if any(has("next.config." + e) for e in ("js", "mjs", "ts")) or "next" in deps:
        return "nextjs"
    if any(has("vite.config." + e) for e in ("js", "ts", "mjs", "mts")) or "vite" in deps:
        return "vite"
    if has("index.html"):
        return "static"
    if has("Package.swift"):
        return "xcode"
    if any(has(os.path.join(folder, name)) for folder in ("", "app") for name in GRADLE_FILES):
        return "kotlin"
    return "unknown"


def expo_platforms(project, expo):
    config = expo.config if expo.config is not None else {}
    platforms = config.get("platforms")
    if isinstance(platforms, list):
        return set(p for p in platforms if isinstance(p, str))
    return {"ios", "android", "web"} if "react-dom" in _package_deps(project) else {"ios", "android"}


def check_route(project, framework, platform, expo):
    only = {"kotlin": "android", "xcode": "ios", "vite": "web", "nextjs": "web", "static": "web"}.get(framework)
    if only and only != platform:
        raise UsageError("%s has no %s route; it goes to publish-%s" % (framework, platform, only))
    if framework == "flutter" and not os.path.isdir(os.path.join(project, platform)):
        raise UsageError("this flutter project has no %s/ directory, so it has no %s route" % (platform, platform))
    if framework == "expo" and platform not in expo_platforms(project, expo):
        raise UsageError("this expo project does not carry %s, so it has no %s route" % (platform, platform))


def native_wins(project, folder):
    """A real native project wins for Expo, unless ignored: Expo Build then runs Prebuild."""
    root = os.path.join(project, folder)
    if not os.path.isdir(root):
        return False
    if folder == "ios":
        real = any(d.endswith(".xcodeproj") for d in os.listdir(root))
    else:
        real = any(os.path.lexists(os.path.join(root, "app", name)) for name in GRADLE_FILES)
    if not real:
        return False
    name = ".easignore" if os.path.lexists(os.path.join(project, ".easignore")) else ".gitignore"
    path = os.path.join(project, name)
    if not os.path.lexists(path):
        return True
    forms = {folder, folder + "/", folder + "/*", folder + "/**"}
    lines = [line.strip() for line in read_text(path).splitlines()]
    if any(line.startswith("!") and re.search(r"(?<![\w.-])%s(?![\w.-])" % folder, line) for line in lines):
        raise Unknown("%s has a negated line naming %s/, which this script does not interpret, so it cannot tell "
                      "whether the native folder or the app config decides" % (name, folder))
    return not any(line.lstrip("/") in forms for line in lines)


# Runner ------------------------------------------------------------------


def run(cid, fn):
    try:
        print("PASS %s: %s" % (cid, _one_line(fn())))
        return False
    except Fail as e:
        print("FAIL %s: %s; fix: %s" % (cid, _one_line(e.reason), _one_line(e.fix)))
        return True
    except Unknown as e:
        print("UNKNOWN %s: %s" % (cid, _one_line(str(e))))
    except Exception as e:
        print("UNKNOWN %s: a project file could not be read (%s)" % (cid, type(e).__name__))
    return False


def _one_line(text):
    text = "".join(" " if c in "\t\r\n" else c for c in str(text) if c in "\t\r\n" or unicodedata.category(c) not in UNSAFE_CATEGORIES)
    text = re.sub(r"\s+", " ", text).strip()
    return text if len(text) <= MAX_LINE else text[:MAX_LINE] + "...[truncated]"


def _route_unknown(cids, reason):
    def fn():
        raise Unknown(reason)
    return [(cid, fn) for cid in cids]


def ios_checks(project, framework, expo, resolved):
    try:
        if framework == "expo" and not native_wins(project, "ios"):
            source = expo
            name, ident, sizes, alpha = expo.app_name, expo.bundle_id, expo.icon_sizes_ios, expo.icon_alpha_ios
        else:
            source = Apple(xcode_settings(resolved.get("xcode"), framework))
            name, ident, sizes, alpha = source.app_name, source.bundle_id, source.icon_sizes, source.icon_alpha
    except Unknown as e:
        return _route_unknown(("app-name", "bundle-id", "icon-sizes", "icon-alpha", "permission-strings"), str(e))

    def strings():
        values, unresolved = source.strings()
        skipped = []
        return check_strings(values, unresolved, _ios_required(project, framework, skipped), source.fix_for, skipped,
                             expo.maybe() if source is expo else None)

    return [("app-name", name), ("bundle-id", ident), ("icon-sizes", sizes), ("icon-alpha", alpha), ("permission-strings", strings)]


def _ios_required(project, framework, skipped):
    if framework == "expo":
        found = detect(project, EXPO_EXTENSIONS, EXPO_APIS, skipped)
    else:
        apis, extensions = (APPLE_APIS, (".swift", ".m", ".mm")) if framework == "xcode" else (DART_APIS, (".dart",))
        found = detect(project, extensions, [(p, None, keys, ()) for p, keys in apis], skipped)
    return [(row[2], rel, certain) for row, rel, certain in found]


def android_checks(project, framework, expo, resolved):
    try:
        if framework == "expo" and not native_wins(project, "android"):
            source = expo
            name, ident, sizes = expo.app_name, expo.package, expo.icon_sizes_android
        else:
            source = AndroidNative(project if framework == "kotlin" else os.path.join(project, "android"), resolved.get("android"))
            name, ident, sizes = source.app_name, source.package, source.icon_sizes
    except Unknown as e:
        return _route_unknown(("app-name", "package", "icon-sizes", "permissions-declared"), str(e))

    def permissions():
        declared, blocked = source.declared()
        skipped = []
        if framework == "expo":
            found = detect(project, EXPO_EXTENSIONS, EXPO_APIS, skipped)
            required = [(perm, how if source is expo else "declare", rel, certain) for row, rel, certain in found for perm, how in row[3]]
        else:
            required = detect_android_native(source.root, skipped)
        return check_android_permissions(declared, blocked, required, source.fix_permission, skipped, source.maybe())

    return [("app-name", name), ("package", ident), ("icon-sizes", sizes), ("permissions-declared", permissions)]


def web_checks(project, framework, expo, resolved):
    web = Web(project, framework, expo if framework == "expo" else None)
    return [("app-name", web.app_name), ("icon-sizes", web.icon_sizes)]


def _out_of_time(signum, frame):
    """Backstop. Checks not reached print nothing, so no PASS stands for undone work."""
    try:
        sys.stdout.flush()
    except (RuntimeError, ValueError, OSError):
        pass
    os.write(2, b"error: the %d-second run limit passed; checks not printed above have no result\n" % RUN_LIMIT_SECONDS)
    os._exit(2)


def main(argv):
    if hasattr(signal, "SIGALRM"):
        signal.signal(signal.SIGALRM, _out_of_time)
        signal.setitimer(signal.ITIMER_REAL, RUN_LIMIT_SECONDS)
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(errors="backslashreplace")
    parser = argparse.ArgumentParser(prog="check-readiness.py", allow_abbrev=False)
    parser.add_argument("project")
    parser.add_argument("--platform", required=True, choices=["ios", "android", "web"])
    parser.add_argument("--resolved", action="append", default=[])
    parser.add_argument("--collects-data", choices=["yes", "no"])
    args = parser.parse_args(argv)
    project = os.path.abspath(args.project)
    PROJECT["path"] = project
    PROJECT["real"] = os.path.realpath(project)
    try:
        if not os.path.isdir(project):
            raise UsageError("project directory not found: %s" % show(args.project))
        resolved = load_resolved(args.resolved)
        framework = detect_framework(project)
        if framework == "unknown":
            raise UsageError("no supported framework found in %s; expected Expo, Flutter, Xcode, Kotlin, Next.js, Vite, "
                             "or a static site" % show(args.project))
        expo = ExpoConfig(project, resolved.get("expo")) if framework == "expo" else None
        check_route(project, framework, args.platform, expo)
        table = {"ios": ios_checks, "android": android_checks, "web": web_checks}[args.platform]
        checks = table(project, framework, expo, resolved)
    except UsageError as e:
        print("error: %s" % _one_line(e), file=sys.stderr)
        return 2
    except OSError as e:
        print("error: %s could not be read (%s)" % (show(args.project), type(e).__name__), file=sys.stderr)
        return 2
    failed = False
    for cid, fn in checks:
        failed = run(cid, fn) or failed
    failed = run("privacy-policy-url", lambda: check_privacy(project, args.platform, args.collects_data)) or failed
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
