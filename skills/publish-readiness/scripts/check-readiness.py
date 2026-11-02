#!/usr/bin/env python3
# Static publish-readiness checks. Rules and sources: references/checks.md.
# usage: python3 -I check-readiness.py <project> --platform ios|android|web
#          [--expo-config <file>] [--collects-data yes|no]
# Prints PASS, FAIL, or UNKNOWN per check. Exit 0 when nothing fails, 1 on a
# failure, 2 on a usage or environment error. No network; writes nothing.
import argparse
import json
import os
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from urllib.parse import urlsplit

SKIP_DIRS = {"node_modules", ".git", "build", "Pods", ".dart_tool", "dist", ".expo", ".gradle"}
MAX_SCAN_BYTES = 2 * 1024 * 1024

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
    (r"pickVideo\([^)]*ImageSource\.camera", (MIC,)),
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


# Files -------------------------------------------------------------------


def read_text(path, label=None):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8-sig")
    except (OSError, ValueError) as e:
        raise Unknown("%s could not be read (%s)" % (label or os.path.basename(path), type(e).__name__))


def load_json(path, label=None):
    text = read_text(path, label)
    try:
        return json.loads(text)
    except ValueError:
        raise Unknown("%s is not valid JSON" % (label or os.path.basename(path)))


COMMENT_OR_STRING = re.compile(r"""("(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')|/\*.*?\*/|//[^\n]*""", re.S)


def strip_comments(text):
    return COMMENT_OR_STRING.sub(lambda m: m.group(1) or " ", text)


def image_info(path, label=None):
    """Return (width, height, has_alpha) from a PNG or WebP header; has_alpha is None for WebP."""
    label = label or os.path.basename(path)
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        raise Unknown("%s could not be read (%s)" % (label, type(e).__name__))
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
        if pos + 12 + length > len(data):
            raise ValueError("truncated")
        if chunk == b"tRNS":
            transparent = True
        if chunk == b"IDAT":
            return width, height, colour in (4, 6) or transparent
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
    if fails:
        raise Fail(fails[0][0], fails[0][1])
    if unknowns:
        raise Unknown(unknowns[0])
    return evidence


# Shared rules ------------------------------------------------------------


def valid_name(value, source, fix):
    if not isinstance(value, str) or not value.strip():
        raise Fail("the app name is empty in %s" % source, fix)
    return '"%s" from %s' % (value.strip(), source)


def valid_bundle_id(value, source, fix):
    if not isinstance(value, str) or not value:
        raise Fail("no bundle id in %s" % source, fix)
    if not re.fullmatch(r"[A-Za-z0-9.-]+", value):
        raise Fail('bundle id "%s" has characters other than letters, digits, hyphens, and periods' % value, fix)
    return "%s from %s" % (value, source)


def valid_package(value, source, fix):
    if not isinstance(value, str) or not value:
        raise Fail("no application id in %s" % source, fix)
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+", value):
        raise Fail('application id "%s" needs two or more segments, each starting with a letter, '
                   "using only letters, digits, and underscores" % value, fix)
    if value == "com.example" or value.startswith("com.example."):
        raise Fail('application id "%s" is under com.example, which Google Play refuses as restricted' % value, fix)
    return "%s from %s" % (value, source)


def scan_code(root, extensions):
    """Yield (relative path, comment-free text) for each source file under root."""
    for current, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(files):
            if not name.endswith(extensions):
                continue
            path = os.path.join(current, name)
            try:
                if os.path.getsize(path) > MAX_SCAN_BYTES:
                    continue
                with open(path, "rb") as f:
                    text = f.read().decode("utf-8", "replace")
            except OSError:
                continue
            yield os.path.relpath(path, root), strip_comments(text)


def detect_keys(root, extensions, table):
    """Return [(keys, file)] for every table row found in code."""
    found = []
    seen = set()
    for rel, text in scan_code(root, extensions):
        for pattern, keys in table:
            if keys not in seen and re.search(pattern, text):
                seen.add(keys)
                found.append((keys, rel))
    return found


def detect_expo(root):
    """Return [(iOS keys, Android permissions, file)] for every Expo API found in code."""
    found = []
    seen = set()
    for rel, text in scan_code(root, (".ts", ".tsx", ".js", ".jsx")):
        for index, (pattern, module, keys, perms) in enumerate(EXPO_APIS):
            if index in seen or (module and module not in text):
                continue
            if re.search(pattern, text):
                seen.add(index)
                found.append((keys, perms, rel))
    return found


def check_strings(strings, unresolved, required, fix_for):
    """strings: key -> text. required: [(keys, file)]. fix_for(key) -> (reason, fix)."""
    fails = []
    for key in sorted(strings):
        if not strings[key].strip():
            fails.append(("%s is declared but empty" % key, fix_for(key)[1]))
    for keys, rel in required:
        if not any(strings.get(k, "").strip() for k in keys) and not any(k in unresolved for k in keys):
            reason, fix = fix_for(keys[0])
            fails.append(("%s uses an API that needs %s; %s" % (rel, keys[0], reason), fix))
    unknowns = ["%s holds a build variable that cannot be resolved here" % k for k in sorted(unresolved)]
    needed = sorted(set(k[0] for k, _ in required))
    return verdict(fails, unknowns, "declared: %s; needed by code: %s" % (
        ", ".join(sorted(strings)) or "none", ", ".join(needed) or "none detected"))


def check_android_permissions(declared, blocked, required, fix):
    """required: [(permission, how, file)]."""
    fails = []
    for perm, how, rel in required:
        if perm in blocked:
            fails.append(("%s uses an API that needs %s, which the project removes" % (rel, perm), fix(perm)))
        elif how == "declare" and perm not in declared:
            fails.append(("%s uses an API that needs %s, which is not declared" % (rel, perm), fix(perm)))
    dangerous = sorted(p for p in declared if p in DANGEROUS)
    return verdict(fails, [], "declared dangerous: %s; needed by code: %s" % (
        ", ".join(dangerous) or "none", ", ".join(sorted(set(r[0] for r in required))) or "none detected"))


# Apple native ------------------------------------------------------------


class Apple:
    FIX_ICON = "add a 1024x1024 opaque PNG to the app icon set in the asset catalog"

    def __init__(self, project, root):
        self.project = project
        self.root = root
        self.label = os.path.relpath(root, project)
        self.label = "" if self.label == "." else self.label + "/"
        self.settings = None
        self.xcconfig = False
        self.target = ""
        self.error = None
        try:
            self._load()
        except Unknown as e:
            self.error = str(e)

    def _project_file(self):
        projects = [d for d in os.listdir(self.root) if d.endswith(".xcodeproj")]
        if not projects:
            for sub in sorted(os.listdir(self.root)):
                path = os.path.join(self.root, sub)
                if sub not in SKIP_DIRS and os.path.isdir(path) and not sub.endswith((".xcodeproj", ".xcworkspace")):
                    projects += [os.path.join(sub, d) for d in os.listdir(path) if d.endswith(".xcodeproj")]
        if not projects:
            raise Unknown("no .xcodeproj under %s; open the project in Xcode or generate one" % (self.label or "the project root"))
        if len(projects) > 1:
            raise Unknown("more than one .xcodeproj: %s" % ", ".join(sorted(projects)))
        return os.path.join(self.root, projects[0], "project.pbxproj")

    def _load(self):
        path = self._project_file()
        text = read_text(path, "project.pbxproj")
        objects = {}
        for m in re.finditer(r"^\s*([0-9A-Fa-f]{24})(?: /\*.*?\*/)? = \{", text, re.M):
            block = _pbx_block(text, m.end() - 1)
            if _isa(block):
                objects[m.group(1)] = block
        targets = [b for b in objects.values() if _isa(b) == "PBXNativeTarget"
                   and 'productType = "com.apple.product-type.application"' in b]
        if not targets:
            raise Unknown("project.pbxproj shows no application target")
        if len(targets) > 1:
            raise Unknown("project.pbxproj has %d application targets; choose one by hand" % len(targets))
        name = re.search(r"\bname = (.*?);", targets[0])
        self.target = _pbx_value(name.group(1)) if name else ""
        settings = {}
        projects = [b for b in objects.values() if _isa(b) == "PBXProject"]
        if projects:
            settings.update(self._release(objects, projects[0], required=False))
        settings.update(self._release(objects, targets[0], required=True))
        settings["TARGET_NAME"] = self.target
        settings.setdefault("PROJECT_DIR", self.root)
        settings.setdefault("SRCROOT", self.root)
        settings.setdefault("inherited", "")
        self.settings = settings

    def _release(self, objects, owner, required):
        ref = re.search(r"buildConfigurationList = ([0-9A-Fa-f]{24})", owner)
        config_list = objects.get(ref.group(1)) if ref else None
        ids = re.search(r"buildConfigurations = \((.*?)\)", config_list or "", re.S)
        for cid in re.findall(r"([0-9A-Fa-f]{24})(?: /\*.*?\*/)?,", ids.group(1)) if ids else []:
            block = objects.get(cid, "")
            if re.search(r"\bname = \"?Release\"?;", block):
                if "baseConfigurationReference" in block:
                    self.xcconfig = True
                return _pbx_settings(block)
        if required:
            raise Unknown("project.pbxproj has no Release configuration for the app target")
        return {}

    def _need(self):
        if self.error:
            raise Unknown(self.error)

    def resolve(self, value):
        for _ in range(8):
            m = re.search(r"\$\(([^)]*)\)|\$\{([^}]*)\}", value)
            if not m:
                return value
            var = m.group(1) if m.group(1) is not None else m.group(2)
            if var not in self.settings:
                raise Unknown('"%s" holds $(%s), which the Release settings do not define' % (value, var))
            value = value[:m.start()] + self.settings[var] + value[m.end():]
        raise Unknown('"%s" does not resolve' % value)

    def plist(self):
        rel = self.settings.get("INFOPLIST_FILE")
        if rel is None:
            return {}
        rel = self.resolve(rel)
        path = os.path.join(self.root, rel)
        try:
            with open(path, "rb") as f:
                data = plistlib.load(f)
        except Exception as e:
            raise Unknown("%s%s could not be read as a plist (%s)" % (self.label, rel, type(e).__name__))
        if not isinstance(data, dict):
            raise Unknown("%s%s is not a plist dictionary" % (self.label, rel))
        return data

    def missing(self, what, fix):
        if self.xcconfig:
            raise Unknown("%s not in project.pbxproj; an .xcconfig file may set it" % what)
        raise Fail("no %s in project.pbxproj or Info.plist" % what, fix)

    def app_name(self):
        self._need()
        plist = self.plist()
        fix = "set the Display Name of the app target in Xcode, which writes CFBundleDisplayName"
        for source, value in (
            ("CFBundleDisplayName", plist.get("CFBundleDisplayName")),
            ("INFOPLIST_KEY_CFBundleDisplayName", self.settings.get("INFOPLIST_KEY_CFBundleDisplayName")),
            ("CFBundleName", plist.get("CFBundleName")),
            ("PRODUCT_NAME", self.settings.get("PRODUCT_NAME")),
        ):
            if value is not None:
                return valid_name(self.resolve(value) if isinstance(value, str) else "", source, fix)
        return self.missing("app name", fix)

    def bundle_id(self):
        self._need()
        fix = "set a reverse-DNS Bundle Identifier on the app target in Xcode (letters, digits, hyphens, periods)"
        value = self.settings.get("PRODUCT_BUNDLE_IDENTIFIER")
        source = "PRODUCT_BUNDLE_IDENTIFIER"
        if value is None:
            value = self.plist().get("CFBundleIdentifier")
            source = "CFBundleIdentifier"
        if value is None:
            return self.missing("bundle id", fix)
        return valid_bundle_id(self.resolve(value) if isinstance(value, str) else "", source, fix)

    def _icon_set(self):
        self._need()
        name = self.settings.get("ASSETCATALOG_COMPILER_APPICON_NAME")
        if name is None:
            return self.missing("ASSETCATALOG_COMPILER_APPICON_NAME", Apple.FIX_ICON)
        name = self.resolve(name)
        sets = []
        for current, dirs, _ in os.walk(self.root):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            if name + ".icon" in dirs:
                raise Unknown("%s.icon is an Icon Composer file; Xcode renders its sizes and alpha at build time, "
                              "so check the archived app" % name)
            if name + ".appiconset" in dirs:
                sets.append(os.path.join(current, name + ".appiconset"))
        if not sets:
            raise Fail("no %s.appiconset under %s" % (name, self.label or "the project root"), Apple.FIX_ICON)
        if len(sets) > 1:
            raise Unknown("more than one %s.appiconset" % name)
        contents = load_json(os.path.join(sets[0], "Contents.json"), "%s.appiconset/Contents.json" % name)
        images = contents.get("images") if isinstance(contents, dict) else None
        if not isinstance(images, list):
            raise Unknown("%s.appiconset/Contents.json has no images list" % name)
        return sets[0], [i for i in images if isinstance(i, dict) and _ios_icon_entry(i)]

    def icon_sizes(self):
        folder, images = self._icon_set()
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
            path = os.path.join(folder, filename)
            if not os.path.isfile(path):
                fails.append(("%s is listed in Contents.json but missing" % filename, Apple.FIX_ICON))
                continue
            want = _icon_pixels(image)
            try:
                width, height, _ = image_info(path)
            except Unknown as e:
                unknowns.append(str(e))
                continue
            checked += 1
            if want and (width, height) != want:
                fails.append(("%s is %dx%d, expected %dx%d" % (filename, width, height, want[0], want[1]),
                              "export the icon at %dx%d" % want))
        if marketing is None or not marketing.get("filename"):
            fails.insert(0, ("no 1024x1024 App Store icon in the app icon set", Apple.FIX_ICON))
        return verdict(fails, unknowns, "%s: 1024x1024 App Store icon present, %d icon files sized correctly" % (
            os.path.basename(folder), checked))

    def icon_alpha(self):
        folder, images = self._icon_set()
        marketing = [i for i in images if _is_marketing(i) and not i.get("appearances") and i.get("filename")]
        if not marketing:
            raise Unknown("no App Store icon file to read; see icon-sizes")
        filename = marketing[0]["filename"]
        path = os.path.join(folder, filename)
        if not os.path.isfile(path):
            raise Unknown("%s is missing; see icon-sizes" % filename)
        return _alpha_verdict(path, filename, "flatten %s onto an opaque background and re-export without alpha" % filename)

    def strings(self):
        self._need()
        plist = self.plist()
        values = {}
        for key, value in self.settings.items():
            m = re.fullmatch(r"INFOPLIST_KEY_(NS\w+UsageDescription)", key)
            if m:
                values[m.group(1)] = value
        for key, value in plist.items():
            if re.fullmatch(r"NS\w+UsageDescription", key):
                values[key] = value if isinstance(value, str) else ""
        strings = {}
        unresolved = set()
        for key, value in values.items():
            try:
                strings[key] = self.resolve(value)
            except Unknown:
                unresolved.add(key)
        return strings, unresolved

    def fix_for(self, key):
        return "no string for it", "add %s with a specific reason to Info.plist" % key


def _pbx_block(text, start):
    depth = 0
    quoted = False
    i = start
    while i < len(text):
        c = text[i]
        if quoted:
            if c == "\\":
                i += 1
            elif c == '"':
                quoted = False
        elif c == '"':
            quoted = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    raise Unknown("project.pbxproj has unbalanced braces")


def _isa(block):
    m = re.search(r"\bisa = (\w+);", block)
    return m.group(1) if m else ""


def _pbx_value(raw):
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"':
        return re.sub(r"\\(.)", lambda m: "\n" if m.group(1) == "n" else m.group(1), raw[1:-1])
    return raw


def _pbx_settings(block):
    start = block.find("buildSettings = {")
    if start < 0:
        return {}
    settings = {}
    for line in _pbx_block(block, start + len("buildSettings = ")).split("\n"):
        m = re.match(r'^\s*("[^"]+"|[\w.\[\]=*-]+)\s*=\s*(.*);\s*$', line)
        if m and not m.group(2).startswith("("):
            settings[_pbx_value(m.group(1))] = _pbx_value(m.group(2))
    return settings


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


def _alpha_verdict(path, label, fix):
    _, _, alpha = image_info(path, label)
    if alpha is None:
        raise Unknown("%s is not a PNG, so its alpha cannot be read" % label)
    if alpha:
        raise Fail("%s has an alpha channel or transparency, which the App Store icon cannot have" % label, fix)
    return "%s has no alpha channel or tRNS chunk" % label


# Android native ----------------------------------------------------------


class AndroidNative:
    def __init__(self, project, root):
        self.project = project
        self.root = root
        self.module = os.path.join(root, "app") if os.path.isdir(os.path.join(root, "app")) else root
        self.main = os.path.join(self.module, "src", "main")
        self.label = os.path.relpath(self.main, project)
        self._manifest = None

    def _xml(self, path, label):
        try:
            return ET.parse(path).getroot()
        except ET.ParseError:
            raise Unknown("%s is not well-formed XML" % label)
        except OSError as e:
            raise Unknown("%s could not be read (%s)" % (label, type(e).__name__))

    def manifest(self):
        path = os.path.join(self.main, "AndroidManifest.xml")
        label = os.path.join(self.label, "AndroidManifest.xml")
        if not os.path.isfile(path):
            raise Fail("%s is missing" % label, "restore AndroidManifest.xml in the app module")
        if self._manifest is None:
            self._manifest = self._xml(path, label)
        return self._manifest

    def application(self):
        node = self.manifest().find("application")
        if node is None:
            raise Fail("AndroidManifest.xml has no <application>", "restore the <application> element")
        return node

    def app_name(self):
        fix = 'set android:label on <application>, usually "@string/app_name" in res/values/strings.xml'
        label = self.application().get(ANDROID_NS + "label")
        if label is None:
            raise Fail("android:label is missing on <application>", fix)
        if "${" in label:
            raise Unknown('android:label "%s" comes from a Gradle placeholder' % label)
        if label.startswith("@string/"):
            name = label[len("@string/"):]
            path = os.path.join(self.main, "res", "values", "strings.xml")
            if not os.path.isfile(path):
                raise Fail("%s points at res/values/strings.xml, which is missing" % label, fix)
            for node in self._xml(path, "res/values/strings.xml").findall("string"):
                if node.get("name") == name:
                    return valid_name("".join(node.itertext()), "res/values/strings.xml (%s)" % name, fix)
            raise Fail("%s is not in res/values/strings.xml" % label, fix)
        if label.startswith("@"):
            raise Unknown('android:label "%s" is a reference this script does not follow' % label)
        return valid_name(label, "android:label", fix)

    def package(self):
        fix = 'set applicationId in the app module\'s build.gradle to your own reverse-DNS id, e.g. "com.yourname.app"'
        path = None
        for name in ("build.gradle.kts", "build.gradle"):
            if os.path.isfile(os.path.join(self.module, name)):
                path = os.path.join(self.module, name)
                break
        if path is None:
            raise Fail("no build.gradle in the app module", fix)
        label = os.path.relpath(path, self.project)
        text = strip_comments(read_text(path, label))
        if text.count("{") != text.count("}"):
            raise Unknown("%s has unbalanced braces" % label)
        values = set()
        for rest in re.findall(r"\bapplicationId\b(.*)", text):
            m = re.match(r"""\s*=?\s*["']([^"'$]*)["']\s*$""", rest)
            if not m:
                raise Unknown("applicationId in %s is not a literal" % label)
            values.add(m.group(1))
        if len(values) > 1:
            raise Unknown("%s sets more than one applicationId" % label)
        return valid_package(values.pop() if values else "", label, fix)

    def _drawables(self, ref):
        m = re.fullmatch(r"@(mipmap|drawable)/(\w+)", ref or "")
        if not m:
            return None
        res = os.path.join(self.main, "res")
        found = []
        if os.path.isdir(res):
            for folder in sorted(os.listdir(res)):
                if folder == m.group(1) or folder.startswith(m.group(1) + "-"):
                    for ext in (".png", ".webp", ".xml", ".jpg", ".jpeg"):
                        path = os.path.join(res, folder, m.group(2) + ext)
                        if os.path.isfile(path):
                            found.append((folder, path))
        return found

    def _check_layer(self, ref, base_dp, fails, unknowns, fix):
        files = self._drawables(ref)
        if files is None:
            unknowns.append('icon reference "%s" is not a @mipmap or @drawable file' % ref)
            return 0
        if not files:
            fails.append(("%s has no file under res/" % ref, fix))
            return 0
        count = 0
        for folder, path in files:
            label = os.path.join(folder, os.path.basename(path))
            if path.endswith(".xml"):
                self._check_xml_drawable(path, label, base_dp, fails, unknowns, fix)
                count += 1
                continue
            try:
                width, height, _ = image_info(path, label)
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

    def _check_xml_drawable(self, path, label, base_dp, fails, unknowns, fix):
        try:
            node = self._xml(path, label)
        except Unknown as e:
            unknowns.append(str(e))
            return
        if node.tag == "adaptive-icon":
            foreground = node.find("foreground")
            if foreground is None:
                fails.append(("%s has no <foreground>" % label, fix))
                return
            for layer in (foreground, node.find("background"), node.find("monochrome")):
                if layer is None:
                    continue
                ref = layer.get(ANDROID_NS + "drawable")
                if ref is None:
                    for child in layer:
                        ref = child.get(ANDROID_NS + "drawable") or ref
                if ref is None:
                    if len(layer) == 0:
                        fails.append(("<%s> in %s has no drawable" % (layer.tag, label), fix))
                    continue
                if not ref.startswith("@color/"):
                    self._check_layer(ref, 108, fails, unknowns, fix)
        elif node.tag == "vector" and base_dp == 108:
            for attr in ("width", "height"):
                value = node.get(ANDROID_NS + attr)
                if value != "108dp":
                    fails.append(("%s has android:%s %s, expected 108dp" % (label, attr, value), "size all adaptive layers to 108x108 dp"))

    def icon_sizes(self):
        fix = 'set android:icon="@mipmap/ic_launcher" on <application> and add the icon with Image Asset Studio'
        ref = self.application().get(ANDROID_NS + "icon")
        if ref is None:
            raise Fail("android:icon is missing on <application>", fix)
        fails = []
        unknowns = []
        count = self._check_layer(ref, 48, fails, unknowns, fix)
        return verdict(fails, unknowns, "%s: %d file(s) checked" % (ref, count))

    def declared(self):
        declared = set()
        removed = set()
        for tag in ("uses-permission", "uses-permission-sdk-23"):
            for node in self.manifest().findall(tag):
                name = (node.get(ANDROID_NS + "name") or "").replace("android.permission.", "")
                if node.get(TOOLS_NS + "node") == "remove":
                    removed.add(name)
                else:
                    declared.add(name)
        return declared, removed

    def fix_permission(self, perm):
        return 'add <uses-permission android:name="android.permission.%s" /> to AndroidManifest.xml' % perm


def detect_android_native(root):
    found = {}
    for rel, text in scan_code(root, (".kt", ".java")):
        for a, b in re.findall(ANDROID_API, text):
            found.setdefault(a or b, rel)
    return [(perm, "declare", rel) for perm, rel in sorted(found.items())]


# Expo config -------------------------------------------------------------


class ExpoConfig:
    def __init__(self, project, config_path):
        self.project = project
        self.config = None
        self.why = None
        self.disabled = set()
        if config_path:
            self.config = load_expo_flag(config_path)
            return
        for name in ("app.config.js", "app.config.ts"):
            if os.path.isfile(os.path.join(project, name)):
                self.why = ("%s is dynamic; run `npx expo config --json`, save the output, and pass it with "
                            "--expo-config <file>" % name)
                return
        for name in ("app.json", "app.config.json"):
            path = os.path.join(project, name)
            if os.path.isfile(path):
                try:
                    data = load_json(path, name)
                except Unknown as e:
                    self.why = str(e)
                    return
                if not isinstance(data, dict):
                    self.why = "%s is not a JSON object" % name
                    return
                inner = data.get("expo")
                self.config = inner if isinstance(inner, dict) else data
                return
        self.config = {}

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
                options = item[1] if len(item) > 1 and isinstance(item[1], dict) else {}
                plugins[item[0]] = options
        return plugins

    def image_path(self, value, what):
        """Return an absolute path for a config image, or raise for remote and missing files."""
        if re.match(r"https?://", value):
            raise Unknown("%s is a remote URL (%s), so its size cannot be read" % (what, value))
        path = os.path.normpath(os.path.join(self.project, value))
        if not os.path.exists(path):
            raise Fail("%s points at %s, which is missing" % (what, value), "add the file or fix the path in the app config")
        return path

    def app_name(self):
        name = self.cfg().get("name")
        return valid_name(name if name is not None else "", "the Expo config (name)", "set expo.name in the app config")

    def web_name(self):
        name = self.section("web").get("name") or self.cfg().get("name")
        return valid_name(name if name is not None else "", "the Expo config", "set expo.name or expo.web.name in the app config")

    def bundle_id(self):
        value = self.section("ios").get("bundleIdentifier")
        return valid_bundle_id(value, "ios.bundleIdentifier", "set ios.bundleIdentifier in the app config to a reverse-DNS id")

    def package(self):
        value = self.section("android").get("package")
        return valid_package(value, "android.package", "set android.package in the app config to your own reverse-DNS id")

    def _ios_icons(self):
        icon = self.section("ios").get("icon")
        top = self.cfg().get("icon")
        if isinstance(icon, str) and icon.endswith(".icon"):
            raise Unknown("ios.icon is an Icon Composer file (%s); its sizes and alpha are rendered at build time, "
                          "so check the build" % icon)
        if isinstance(icon, dict):
            return [("ios.icon.light", icon.get("light") or top), ("ios.icon.dark", icon.get("dark")), ("ios.icon.tinted", icon.get("tinted"))]
        return [("ios.icon" if icon else "icon", icon or top)]

    def icon_sizes_ios(self):
        icons = self._ios_icons()
        fix = "set icon in the app config to a 1024x1024 PNG"
        if not icons[0][1]:
            raise Fail("no icon in the app config", fix)
        fails = []
        unknowns = []
        done = []
        for what, value in icons:
            if not value:
                continue
            try:
                path = self.image_path(value, what)
                width, height, _ = image_info(path, value)
            except Fail as e:
                fails.append((e.reason, e.fix))
                continue
            except Unknown as e:
                unknowns.append(str(e))
                continue
            if (width, height) != (1024, 1024):
                fails.append(("%s %s is %dx%d, expected 1024x1024" % (what, value, width, height), fix))
            done.append(value)
        return verdict(fails, unknowns, "%s is 1024x1024" % ", ".join(done))

    def icon_alpha_ios(self):
        what, value = self._ios_icons()[0]
        if not value:
            raise Unknown("no icon in the app config; see icon-sizes")
        try:
            path = self.image_path(value, what)
        except Fail:
            raise Unknown("%s is missing; see icon-sizes" % value)
        return _alpha_verdict(path, value, "flatten %s onto your intended background and re-export without alpha; "
                                           "otherwise Expo's prebuild fills transparency with white" % value)

    def icon_sizes_android(self):
        android = self.section("android")
        adaptive = android.get("adaptiveIcon") if isinstance(android.get("adaptiveIcon"), dict) else {}
        foreground = adaptive.get("foregroundImage")
        fails = []
        unknowns = []
        sizes = {}
        layers = []
        if foreground:
            layers = [("android.adaptiveIcon." + k, adaptive.get(k)) for k in ("foregroundImage", "backgroundImage", "monochromeImage")]
        fallback = android.get("icon") or self.cfg().get("icon")
        if fallback and not foreground:
            layers = [("android.icon" if android.get("icon") else "icon", fallback)]
        elif android.get("icon"):
            layers.append(("android.icon", android.get("icon")))
        if not layers:
            raise Fail("no icon in the app config", "set android.adaptiveIcon.foregroundImage to a PNG of at least 512x512")
        done = []
        for what, value in layers:
            if not value:
                continue
            try:
                width, height, _ = image_info(self.image_path(value, what), value)
            except Fail as e:
                fails.append((e.reason, e.fix))
                continue
            except Unknown as e:
                unknowns.append(str(e))
                continue
            sizes[what] = (width, height)
            done.append("%s %dx%d" % (value, width, height))
            if width != height or (width < 512 and not what.endswith("monochromeImage")):
                fails.append(("%s %s is %dx%d; use a square of at least 512x512" % (what, value, width, height),
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
        self.image_path(favicon, "web.favicon")
        return "web.favicon %s exists" % favicon

    def strings(self):
        info = self.section("ios").get("infoPlist")
        strings = {}
        for key, value in (info.items() if isinstance(info, dict) else []):
            if re.fullmatch(r"NS\w+UsageDescription", key):
                strings[key] = value if isinstance(value, str) else ""
        for module, options in self.plugins().items():
            for option, keys in EXPO_OPTIONS.get(module, {}).items():
                if option not in options:
                    continue
                for key in keys:
                    if options[option] is False:
                        strings.pop(key, None)
                        self.disabled.add(key)
                    elif isinstance(options[option], str):
                        strings[key] = options[option]
                        self.disabled.discard(key)
        return strings, set()

    def fix_for(self, key):
        hint = "ios.infoPlist.%s" % key
        for module, options in EXPO_OPTIONS.items():
            for option, keys in options.items():
                if key in keys:
                    hint = "the %s option of the %s plugin, or %s" % (option, module, hint)
                    return self._reason(key), "set a specific reason in %s" % hint
        return self._reason(key), "set a specific reason in %s" % hint

    def _reason(self, key):
        if key in self.disabled:
            return "a plugin option of false removes it"
        return "without a string Expo writes a generic default that its docs say to tailor"

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
        return ('add "android.permission.%s" to android.permissions and remove any plugin option or '
                "blockedPermissions entry that excludes it" % perm)


def _short_perms(value):
    return [p.replace("android.permission.", "") for p in value if isinstance(p, str)] if isinstance(value, list) else []


def load_expo_flag(path):
    try:
        with open(path, "rb") as f:
            data = json.loads(f.read().decode("utf-8-sig"))
    except (OSError, ValueError) as e:
        raise UsageError("--expo-config %s could not be read as JSON (%s)" % (path, type(e).__name__))
    if not isinstance(data, dict):
        raise UsageError("--expo-config %s is not a JSON object" % path)
    return data["expo"] if isinstance(data.get("expo"), dict) else data


# Web ---------------------------------------------------------------------


class HeadReader(HTMLParser):
    def __init__(self):
        HTMLParser.__init__(self, convert_charrefs=True)
        self.title = None
        self.in_title = False
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "title" and self.title is None:
            self.in_title = True
            self.title = ""
        elif tag == "link":
            self.links.append(dict(attrs))

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


class Web:
    def __init__(self, project, framework, expo=None):
        self.project = project
        self.framework = framework
        self.expo = expo
        self.base = os.path.join(project, "web") if framework == "flutter" else project
        self.app_dir = os.path.join(project, "app")
        if not os.path.isdir(self.app_dir) and os.path.isdir(os.path.join(project, "src", "app")):
            self.app_dir = os.path.join(project, "src", "app")

    def head(self):
        for rel in (("index.html",), ("public", "index.html")):
            path = os.path.join(self.base, *rel)
            if os.path.isfile(path):
                reader = HeadReader()
                reader.feed(read_text(path, "index.html"))
                return reader
        return None

    def manifest(self):
        """Return (path, data) for a manifest file, or (None, None). Malformed raises Unknown."""
        head = self.head()
        candidates = []
        for link in head.links if head else []:
            if "manifest" in (link.get("rel") or "").lower().split() and link.get("href"):
                found = self._find(link["href"], self.base)
                if found:
                    candidates.append(found)
        for folder in (os.path.join(self.base, "public"), self.base, self.app_dir):
            for name in ("manifest.webmanifest", "manifest.json", "site.webmanifest"):
                candidates.append(os.path.join(folder, name))
        for path in candidates:
            if os.path.isfile(path):
                data = load_json(path, os.path.relpath(path, self.project))
                if not isinstance(data, dict):
                    raise Unknown("%s is not a JSON object" % os.path.relpath(path, self.project))
                return path, data
        return None, None

    def _find(self, ref, base):
        ref = ref.split("?")[0].split("#")[0]
        rel = ref.lstrip("/")
        roots = [os.path.join(self.base, "public"), self.base] if ref.startswith("/") else [base, os.path.join(self.base, "public"), self.base]
        for root in roots:
            path = os.path.normpath(os.path.join(root, rel))
            if os.path.isfile(path):
                return path
        return None

    def _layout(self):
        for ext in ("tsx", "jsx", "ts", "js"):
            path = os.path.join(self.app_dir, "layout." + ext)
            if os.path.isfile(path):
                return read_text(path, "layout." + ext)
        return None

    def app_name(self):
        if self.expo:
            return self.expo.web_name()
        fix = "set <title> in index.html or name in the web manifest"
        path, data = self.manifest()
        if data is not None:
            name = data.get("name") or data.get("short_name")
            if name is not None:
                return valid_name(name, os.path.relpath(path, self.project), fix)
        head = self.head()
        if head and head.title is not None:
            if PLACEHOLDER.search(head.title):
                raise Unknown('<title>%s</title> holds a build placeholder' % head.title)
            return valid_name(head.title, "index.html <title>", fix)
        if self.framework == "nextjs":
            return self._next_name()
        if self.framework == "vite" and self._vite_inline_manifest():
            raise Unknown("the only name is inside the inline manifest in vite.config; add <title> to index.html")
        raise Fail("no name in a web manifest or <title>", fix)

    def _next_name(self):
        fix = "set metadata.title in the root layout, or name in app/manifest.json"
        for ext in ("ts", "js"):
            if os.path.isfile(os.path.join(self.app_dir, "manifest." + ext)):
                raise Unknown("app/manifest.%s builds the name at runtime" % ext)
        layout = self._layout()
        if layout is None:
            if os.path.isdir(os.path.join(self.project, "pages")) or os.path.isdir(os.path.join(self.project, "src", "pages")):
                raise Unknown("the pages router sets the title at runtime")
            raise Fail("no root layout or manifest name", fix)
        layout = strip_comments(layout)
        if "generateMetadata" in layout:
            raise Unknown("generateMetadata builds the title at runtime")
        m = re.search(r"\bmetadata\b.*?\btitle:\s*(?:\{[^}]*?\bdefault:\s*)?([\"'`])(.*?)\1", layout, re.S)
        if m and "${" not in m.group(2):
            return valid_name(m.group(2), "metadata.title in the root layout", fix)
        if re.search(r"\bmetadata\b", layout):
            raise Unknown("metadata.title in the root layout is not a literal")
        raise Fail("the root layout sets no metadata.title", fix)

    def _vite_inline_manifest(self):
        for ext in ("ts", "js", "mjs", "mts"):
            path = os.path.join(self.project, "vite.config." + ext)
            if os.path.isfile(path) and "manifest" in read_text(path, "vite.config." + ext):
                return True
        return False

    def icon_sizes(self):
        if self.expo:
            return self.expo.web_icon()
        fix = 'add an icon file and declare it with <link rel="icon"> or in the web manifest'
        fails = []
        unknowns = []
        declared = []
        path, data = self.manifest()
        if data is not None:
            icons = data.get("icons", [])
            for icon in icons if isinstance(icons, list) else []:
                if isinstance(icon, dict) and icon.get("src"):
                    declared.append((icon["src"], icon.get("sizes"), os.path.dirname(path), "manifest"))
        head = self.head()
        for link in head.links if head else []:
            rel = (link.get("rel") or "").lower().split()
            if link.get("href") and ("icon" in rel or "apple-touch-icon" in rel):
                declared.append((link["href"], link.get("sizes"), self.base, "index.html"))
        if self.framework == "nextjs":
            for name in sorted(os.listdir(self.app_dir)) if os.path.isdir(self.app_dir) else []:
                stem, ext = os.path.splitext(name)
                if re.fullmatch(r"(favicon|icon\d*|apple-icon\d*)", stem):
                    if ext in (".ts", ".tsx", ".js", ".jsx"):
                        unknowns.append("app/%s generates its icon at runtime" % name)
                    else:
                        declared.append((name, None, self.app_dir, "app/"))
            layout = self._layout()
            if not declared and not unknowns and layout and re.search(r"\bicons:", layout):
                unknowns.append("metadata.icons in the root layout is read at runtime")
        for ref, sizes, base, source in declared:
            self._check_declared(ref, sizes, base, source, fails, unknowns, fix)
        if not declared and not unknowns:
            fails.append(("no icon declared in a web manifest, index.html, or app/", fix))
        return verdict(fails, unknowns, "%d declared icon(s) exist with matching sizes" % len(declared))

    def _check_declared(self, ref, sizes, base, source, fails, unknowns, fix):
        if re.match(r"(https?:)?//", ref):
            unknowns.append("icon %s is remote" % ref)
            return
        if ref.startswith("data:"):
            return
        if PLACEHOLDER.search(ref):
            unknowns.append("icon %s holds a build placeholder" % ref)
            return
        path = self._find(ref, base)
        if path is None:
            fails.append(("%s declares %s, which is missing" % (source, ref), fix))
            return
        if not path.endswith((".png", ".webp")):
            return
        try:
            width, height, _ = image_info(path, ref)
        except Unknown as e:
            unknowns.append(str(e))
            return
        if isinstance(sizes, str) and sizes.strip().lower() != "any":
            listed = sizes.lower().split()
            if "%dx%d" % (width, height) not in listed:
                fails.append(("%s is %dx%d but %s declares %s" % (ref, width, height, source, sizes),
                              "export the file at the declared size or correct the declaration"))


# State -------------------------------------------------------------------


def parse_scalar(raw):
    raw = raw.strip()
    if raw[:1] == '"':
        m = re.match(r'"((?:[^"\\]|\\.)*)"', raw)
        if not m:
            raise Unknown("unterminated quote in .app-creators/state.md")
        return re.sub(r"\\(.)", r"\1", m.group(1))
    if raw[:1] == "'":
        m = re.match(r"'((?:[^']|'')*)'", raw)
        if not m:
            raise Unknown("unterminated quote in .app-creators/state.md")
        return m.group(1).replace("''", "'")
    if raw[:1] in ("|", ">"):
        raise Unknown(".app-creators/state.md uses a block scalar for this value")
    value = re.split(r"(?:^|\s)#", raw, maxsplit=1)[0].strip()
    return "" if value in ("~", "null", "Null", "NULL") else value


def parse_flow(text):
    """Parse a one-level or nested YAML flow map into dicts of strings."""
    value, end = _flow_map(text, 0)
    rest = text[end:].strip()
    if rest and not rest.startswith("#"):
        raise ValueError("text after flow map")
    return value


def _flow_map(text, i):
    if text[i] != "{":
        raise ValueError("expected {")
    i += 1
    result = {}
    while True:
        i = _skip_space(text, i)
        if text[i] == "}":
            return result, i + 1
        key, i = _flow_token(text, i, ":")
        i = _skip_space(text, i)
        if text[i] != ":":
            raise ValueError("expected :")
        i = _skip_space(text, i + 1)
        if text[i] == "{":
            value, i = _flow_map(text, i)
        else:
            value, i = _flow_token(text, i, ",}")
        result[key] = value
        i = _skip_space(text, i)
        if text[i] == ",":
            i += 1
        elif text[i] != "}":
            raise ValueError("expected , or }")


def _flow_token(text, i, stops):
    if text[i] in "\"'":
        quote = text[i]
        end = i + 1
        while True:
            if text[end] == "\\" and quote == '"':
                end += 2
            elif text[end] == quote:
                if quote == "'" and text[end + 1:end + 2] == "'":
                    end += 2
                else:
                    break
            else:
                end += 1
        return parse_scalar(text[i:end + 1]), end + 1
    end = i
    while text[end] not in stops:
        if ":" in stops and text[end] in ",}":
            raise ValueError("bare token")
        end += 1
    return parse_scalar(text[i:end]), end


def _skip_space(text, i):
    while text[i] in " \t\n":
        i += 1
    return i


def privacy_url(project):
    path = os.path.join(project, ".app-creators", "state.md")
    label = ".app-creators/state.md"
    if not os.path.isfile(path):
        raise Unknown("%s is missing; run app-creators first" % label)
    lines = read_text(path, label).splitlines()
    if not lines or lines[0].strip() != "---":
        raise Unknown("%s has no frontmatter" % label)
    try:
        end = next(i for i, line in enumerate(lines[1:], 1) if line.strip() == "---")
    except StopIteration:
        raise Unknown("%s has no closing frontmatter line" % label)
    body = lines[1:end]
    try:
        return _lookup(body, ["provided", "publish-readiness", "privacy_policy_url"])
    except (ValueError, IndexError):
        raise Unknown("%s has a flow map that cannot be read" % label)


def _lookup(lines, path):
    """Walk an indentation-based YAML block along path; missing keys give an empty string."""
    indent = 0
    i = 0
    for depth, want in enumerate(path):
        hit = None
        while i < len(lines):
            line = lines[i]
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                i += 1
                continue
            this = len(line) - len(line.lstrip(" "))
            if this < indent:
                return ""
            m = re.match(r"""\s*(?:"([^"]+)"|'([^']+)'|([^\s:#][^:#]*?))\s*:(?:\s+(.*)|\s*)$""", line)
            if this == indent and m and (m.group(1) or m.group(2) or m.group(3)) == want:
                hit = m.group(4) or ""
                i += 1
                break
            i += 1
        if hit is None:
            return ""
        hit = hit.strip()
        if hit.startswith("{"):
            text = hit
            while text.count("{") > text.count("}") and i < len(lines):
                text += " " + lines[i].strip()
                i += 1
            value = parse_flow(text)
            for key in path[depth + 1:]:
                value = value.get(key, "") if isinstance(value, dict) else ""
            return value if isinstance(value, str) else ""
        if depth == len(path) - 1:
            return parse_scalar(hit)
        if parse_scalar(hit):
            return ""
        indent = _next_indent(lines, i, indent)
        if indent is None:
            return ""
    return ""


def _next_indent(lines, i, parent):
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped and not stripped.startswith("#"):
            this = len(lines[i]) - len(lines[i].lstrip(" "))
            return this if this > parent else None
        i += 1
    return None


def check_privacy(project, platform, collects):
    value = privacy_url(project)
    fix = "publish a privacy policy page and set provided.publish-readiness.privacy_policy_url in .app-creators/state.md"
    if value:
        try:
            parts = urlsplit(value)
            good = parts.scheme in ("http", "https") and bool(parts.hostname) and not re.search(r"\s", value)
        except ValueError:
            good = False
        if not good:
            raise Fail('privacy_policy_url "%s" is not an http(s) URL' % value, fix)
        return value
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
    try:
        with open(os.path.join(project, "package.json"), "rb") as f:
            data = json.loads(f.read().decode("utf-8-sig"))
    except (OSError, ValueError):
        return {}, {}
    if not isinstance(data, dict):
        return {}, {}
    deps = data.get("dependencies")
    dev = data.get("devDependencies")
    return (deps if isinstance(deps, dict) else {}), (dev if isinstance(dev, dict) else {})


def _json_has_expo(path):
    try:
        with open(path, "rb") as f:
            data = json.loads(f.read().decode("utf-8-sig"))
    except (OSError, ValueError):
        return False
    return isinstance(data, dict) and "expo" in data


def _is_flutter(project):
    try:
        text = read_text(os.path.join(project, "pubspec.yaml"))
    except Unknown:
        return False
    in_deps = False
    for line in text.splitlines():
        if re.match(r"dependencies\s*:", line):
            in_deps = True
        elif line[:1].strip() and not line.startswith("#"):
            in_deps = False
        elif in_deps and re.match(r"\s+flutter\s*:", line):
            return True
    return False


def _is_android_app(project):
    catalog = ""
    try:
        catalog = read_text(os.path.join(project, "gradle", "libs.versions.toml"))
    except Unknown:
        pass
    for folder in (project, os.path.join(project, "app")):
        for name in ("build.gradle", "build.gradle.kts"):
            path = os.path.join(folder, name)
            if not os.path.isfile(path):
                continue
            try:
                text = read_text(path)
            except Unknown:
                continue
            if "com.android.application" in text:
                return True
            for alias in re.findall(r"alias\(\s*libs\.plugins\.([\w.]+)\s*\)", text):
                pattern = alias.replace(".", "[-_.]") + r"\s*=.*com\.android\.application"
                if re.search(pattern, catalog):
                    return True
    return False


def detect_framework(project):
    deps, dev = _package_deps(project)
    has = lambda name: os.path.exists(os.path.join(project, name))
    if _json_has_expo(os.path.join(project, "app.json")) or _json_has_expo(os.path.join(project, "app.config.json")) or "expo" in deps:
        return "expo"
    if _is_flutter(project):
        return "flutter"
    entries = os.listdir(project)
    if any(e.endswith((".xcodeproj", ".xcworkspace")) and os.path.isdir(os.path.join(project, e)) for e in entries):
        return "xcode"
    if has("Package.swift"):
        try:
            if "executableTarget" in read_text(os.path.join(project, "Package.swift")):
                return "xcode"
        except Unknown:
            pass
    if _is_android_app(project):
        return "kotlin"
    if any(has("next.config." + e) for e in ("js", "mjs", "ts")) or "next" in deps:
        return "nextjs"
    if any(has("vite.config." + e) for e in ("js", "ts", "mjs", "mts")) or "vite" in deps or "vite" in dev:
        return "vite"
    if has("index.html"):
        return "static"
    return "unknown"


def expo_platforms(project, expo):
    config = expo.config if expo.config is not None else {}
    platforms = config.get("platforms")
    if isinstance(platforms, list):
        return set(platforms)
    deps, _ = _package_deps(project)
    return {"ios", "android", "web"} if "react-dom" in deps else {"ios", "android"}


def check_route(project, framework, platform, expo):
    if platform == "ios":
        if framework == "kotlin":
            raise UsageError("kotlin has no ios route; a Kotlin Android project goes to publish-android")
        if framework in ("vite", "nextjs", "static"):
            raise UsageError("%s has no ios route; a web project goes to publish-web" % framework)
    if platform == "android":
        if framework == "xcode":
            raise UsageError("xcode has no android route; an Xcode project goes to publish-ios")
        if framework in ("vite", "nextjs", "static"):
            raise UsageError("%s has no android route; a web project goes to publish-web" % framework)
    if platform == "web" and framework in ("kotlin", "xcode"):
        raise UsageError("%s has no web route" % framework)
    if framework == "flutter" and not os.path.isdir(os.path.join(project, platform)):
        raise UsageError("this flutter project has no %s/ directory, so it has no %s route" % (platform, platform))
    if framework == "expo" and platform not in expo_platforms(project, expo):
        raise UsageError("this expo project does not carry %s, so it has no %s route" % (platform, platform))


def native_wins(project, folder):
    """A native folder wins for Expo, unless ignored: EAS then builds it fresh with Prebuild."""
    if not os.path.isdir(os.path.join(project, folder)):
        return False
    for name in (".gitignore", ".easignore"):
        try:
            lines = read_text(os.path.join(project, name)).splitlines()
        except Unknown:
            continue
        if any(line.strip().strip("/") == folder for line in lines):
            return False
    return True


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
    return re.sub(r"\s+", " ", str(text)).strip()


def ios_checks(project, framework, expo):
    if framework == "expo" and not native_wins(project, "ios"):
        source = expo
        name, ident, sizes, alpha = expo.app_name, expo.bundle_id, expo.icon_sizes_ios, expo.icon_alpha_ios
    else:
        root = project if framework == "xcode" else os.path.join(project, "ios")
        source = Apple(project, root)
        name, ident, sizes, alpha = source.app_name, source.bundle_id, source.icon_sizes, source.icon_alpha

    def strings():
        values, unresolved = source.strings()
        return check_strings(values, unresolved, _ios_required(project, framework), source.fix_for)

    return [("app-name", name), ("bundle-id", ident), ("icon-sizes", sizes), ("icon-alpha", alpha), ("permission-strings", strings)]


def _ios_required(project, framework):
    if framework == "xcode":
        return detect_keys(project, (".swift", ".m", ".mm"), APPLE_APIS)
    if framework == "flutter":
        return detect_keys(project, (".dart",), DART_APIS)
    return [(keys, rel) for keys, _, rel in detect_expo(project)]


def android_checks(project, framework, expo):
    if framework == "expo" and not native_wins(project, "android"):
        source = expo
        name, ident, sizes = expo.app_name, expo.package, expo.icon_sizes_android
    else:
        root = project if framework == "kotlin" else os.path.join(project, "android")
        source = AndroidNative(project, root)
        name, ident, sizes = source.app_name, source.package, source.icon_sizes

    def permissions():
        declared, blocked = source.declared()
        if framework == "expo":
            required = [(perm, how, rel) for _, perms, rel in detect_expo(project) for perm, how in perms]
        else:
            required = detect_android_native(project)
        return check_android_permissions(declared, blocked, required, source.fix_permission)

    return [("app-name", name), ("package", ident), ("icon-sizes", sizes), ("permissions-declared", permissions)]


def web_checks(project, framework, expo):
    web = Web(project, framework, expo if framework == "expo" else None)
    return [("app-name", web.app_name), ("icon-sizes", web.icon_sizes)]


def main(argv):
    parser = argparse.ArgumentParser(prog="check-readiness.py")
    parser.add_argument("project")
    parser.add_argument("--platform", required=True, choices=["ios", "android", "web"])
    parser.add_argument("--expo-config")
    parser.add_argument("--collects-data", choices=["yes", "no"])
    args = parser.parse_args(argv)
    project = os.path.abspath(args.project)
    try:
        if not os.path.isdir(project):
            raise UsageError("project directory not found: %s" % args.project)
        framework = detect_framework(project)
        if framework == "unknown":
            raise UsageError("no supported framework found in %s; expected Expo, Flutter, Xcode, Kotlin, Next.js, Vite, "
                             "or a static site" % args.project)
        expo = ExpoConfig(project, args.expo_config) if framework == "expo" else None
        check_route(project, framework, args.platform, expo)
    except UsageError as e:
        print("error: %s" % e, file=sys.stderr)
        return 2
    except OSError as e:
        print("error: %s could not be read (%s)" % (args.project, type(e).__name__), file=sys.stderr)
        return 2
    table = {"ios": ios_checks, "android": android_checks, "web": web_checks}[args.platform]
    failed = False
    try:
        checks = table(project, framework, expo)
    except OSError as e:
        print("error: %s could not be read (%s)" % (args.project, type(e).__name__), file=sys.stderr)
        return 2
    for cid, fn in checks:
        failed = run(cid, fn) or failed
    failed = run("privacy-policy-url", lambda: check_privacy(project, args.platform, args.collects_data)) or failed
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
