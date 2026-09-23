#!/usr/bin/env bash
# Install Godot's Android build template into res://android/build and wire EOS
# into it. Safe to run again: every edit is guarded by a marker.
#
# android/ is gitignored — it is Godot's template plus three small edits, and
# committing a generated Gradle project means reviewing Godot's diff on every
# engine upgrade. This script is the part worth keeping.
#
# Also: invite links (an intent filter, and GodotApp holding the link for the
# game to take) — see the section at the end.
#
# Why EOS needs a custom build at all, when every other plugin here does not:
# the other plugins are Godot Android plugins and inject themselves. EOSG is a
# GDExtension, and Epic's Android SDK also has a Java half that must be
# initialised from the activity *before* the native library is used. Skip that
# and the game boots fine and dies the first time anything touches EOS.
#
#   1. build.gradle  — Epic's .aar and the androidx libraries it links against
#      plus core library desugaring, which the .aar's metadata requires
#   2. build.gradle  — eos_login_protocol_scheme, which the .aar's manifest
#                      references; the build fails at resource linking without it
#   3. GodotApp.java — load libEOSSDK and call EOSSDK.init(this) in onCreate
#
# Steps are from addons/epic-online-services-godot/README.md, "Exporting for
# Android".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
VERSION="$("$GODOT" --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?\.[a-z]+' | head -1)"
TEMPLATES="${HOME}/.local/share/godot/export_templates/${VERSION}"
SOURCE="${TEMPLATES}/android_source.zip"
BUILD="${ROOT}/android/build"
AAR="${ROOT}/addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar"

[[ -f "${SOURCE}" ]] || { echo "error: no ${SOURCE} — install the ${VERSION} export templates" >&2; exit 1; }
[[ -f "${AAR}" ]] || { echo "error: no EOS Android binaries — run tools/fetch-eos.sh" >&2; exit 1; }

# The installed version is what Godot compares against before every export; a
# mismatch makes it refuse to build rather than silently use a stale template.
if [[ "$(cat "${ROOT}/android/.build_version" 2>/dev/null)" != "${VERSION}" ]]; then
  echo "Installing the ${VERSION} Android build template"
  rm -rf "${BUILD}"
  mkdir -p "${BUILD}"
  unzip -q "${SOURCE}" -d "${BUILD}"
  echo -n "${VERSION}" > "${ROOT}/android/.build_version"
  # Keeps the editor from importing a Gradle project as game resources.
  touch "${BUILD}/.gdignore"
fi

CLIENT_ID="$(grep -oP 'const CLIENT_ID := "\K[^"]+' "${ROOT}/scripts/eos_config.gd")"
[[ -n "${CLIENT_ID}" ]] || { echo "error: CLIENT_ID is empty in scripts/eos_config.gd" >&2; exit 1; }

GRADLE="${BUILD}/build.gradle"
if ! grep -q "EOS SDK dependencies" "${GRADLE}"; then
  echo "Adding the EOS SDK to build.gradle"
  python3 - "${GRADLE}" "${CLIENT_ID,,}" <<'PY'
import sys, re
path, client = sys.argv[1], sys.argv[2]
s = open(path).read()

deps = '''
    // EOS SDK dependencies — tools/android-template.sh
    implementation 'androidx.appcompat:appcompat:1.5.1'
    implementation 'androidx.constraintlayout:constraintlayout:2.1.4'
    implementation 'androidx.security:security-crypto:1.0.0'
    implementation 'androidx.browser:browser:1.4.0'
    implementation 'androidx.webkit:webkit:1.7.0'
    implementation files('../../addons/epic-online-services-godot/bin/android/eossdk-StaticSTDC-release.aar')
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
'''
anchor = re.search(r'\n(\s*implementation "androidx\.documentfile:[^\n]*)\n', s)
assert anchor, "build.gradle: androidx.documentfile line not found — template changed"
s = s[:anchor.end()] + deps + s[anchor.end():]

# The .aar's metadata demands it and the build stops at checkAarMetadata
# without it: Epic's Java uses java.time and friends below the API level
# that ships them.
old = "        targetCompatibility versions.javaVersion\n"
assert s.count(old) == 1, "build.gradle: compileOptions not found — template changed"
s = s.replace(old, old + "        coreLibraryDesugaringEnabled true\n")

scheme = '''
        // EOS: referenced by the SDK's manifest — tools/android-template.sh
        resValue("string", "eos_login_protocol_scheme", "eos.%s")
''' % client
anchor = re.search(r"\n\s*missingDimensionStrategy 'products', 'template'\n", s)
assert anchor, "build.gradle: missingDimensionStrategy line not found — template changed"
s = s[:anchor.end()] + scheme + s[anchor.end():]
open(path, "w").write(s)
PY
fi

APP="${BUILD}/src/main/java/com/godot/game/GodotApp.java"
if ! grep -q "EOSSDK.init" "${APP}"; then
  echo "Initialising EOS in GodotApp.java"
  python3 - "${APP}" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read()

def once(old, new):
    global s
    assert s.count(old) == 1, "GodotApp.java: %r not found exactly once — template changed" % old
    s = s.replace(old, new)

once("import org.godotengine.godot.GodotActivity;\n",
     "import org.godotengine.godot.GodotActivity;\n\nimport com.epicgames.mobile.eossdk.EOSSDK;\n")
# Loaded before anything else in the class, so the GDExtension finds it
# already resident when it resolves its EOS symbols.
once("\tstatic {\n",
     "\tstatic {\n\t\t// EOS — tools/android-template.sh\n\t\tSystem.loadLibrary(\"EOSSDK\");\n\n")
# Before super.onCreate: that is where Godot starts, and the extension may
# touch EOS as soon as the autoloads run.
once("\t\tsuper.onCreate(savedInstanceState);\n",
     "\t\tEOSSDK.init(this);\n\t\tsuper.onCreate(savedInstanceState);\n")
open(path, "w").write(s)
PY
fi

# ---------------------------------------------------------------- invite links
#
# An invite is a link to https://damondjr.github.io/word-wars/j/?c=CODE. With the
# game installed, Android should open the game rather than the page — that is
# the https filter, verified against /.well-known/assetlinks.json on the domain.
# The wordwars:// scheme is the page's own "open the game" button, which works
# whether or not verification has happened yet.
MANIFEST="${BUILD}/src/main/AndroidManifest.xml"
if ! grep -q 'android:scheme="wordwars"' "${MANIFEST}"; then
  echo "Adding invite links to AndroidManifest.xml"
  python3 - "${MANIFEST}" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read()
alias = '''
        <!-- Invite links — tools/android-template.sh

             An alias of its own rather than filters on GodotAppLauncher: at
             export Godot writes src/<variant>/AndroidManifest.xml, which marks
             the launcher alias and the activity tools:node="mergeOnlyAttributes"
             — and that drops every child element from this file, filters and
             all, without a warning. Godot never mentions this alias, so it
             merges whole. It targets the same activity, so the link still
             arrives in GodotApp (getIntent / onNewIntent). -->
        <activity-alias
            android:name=".GodotAppLinks"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="damondjr.github.io"
                    android:pathPrefix="/word-wars/j" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="wordwars" android:host="join" />
            </intent-filter>
        </activity-alias>
'''
anchor = "    </application>\n"
assert s.count(anchor) == 1, "AndroidManifest.xml: </application> not found — template changed"
s = s.replace(anchor, alias + anchor)
open(path, "w").write(s)
PY
fi

if ! grep -q "takeLink" "${APP}"; then
  echo "Capturing invite links in GodotApp.java"
  python3 - "${APP}" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read()

def once(old, new):
    global s
    assert s.count(old) == 1, "GodotApp.java: %r not found exactly once — template changed" % old
    s = s.replace(old, new)

once("import android.os.Bundle;\n", "import android.content.Intent;\nimport android.os.Bundle;\n")
# Held in a static and taken by the game — MultiplayerManager asks for it with
# JavaClassWrapper on launch and on every resume. A cold start and a link that
# arrives while the game is already open (onNewIntent) end up in the same place.
once("public class GodotApp extends GodotActivity {\n",
     '''public class GodotApp extends GodotActivity {
	// Invite links — tools/android-template.sh
	private static String pendingLink = null;

	public static String takeLink() {
		String link = pendingLink;
		pendingLink = null;
		return link == null ? "" : link;
	}

	private static void captureLink(Intent intent) {
		if (intent != null && Intent.ACTION_VIEW.equals(intent.getAction()) && intent.getData() != null) {
			pendingLink = intent.getData().toString();
		}
	}

	@Override
	public void onNewIntent(Intent intent) {
		super.onNewIntent(intent);
		captureLink(intent);
	}

''')
once("\t\tEOSSDK.init(this);\n", "\t\tEOSSDK.init(this);\n\t\tcaptureLink(getIntent());\n")
open(path, "w").write(s)
PY
fi

echo "Android build template ready at android/build"
