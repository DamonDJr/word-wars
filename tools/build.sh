#!/usr/bin/env bash
# Builds shippable Windows and Linux binaries and zips them for sending.
#
#   tools/build.sh
#
# Needs Godot 4.7 on PATH with export templates installed (Editor > Manage
# Export Templates). Each platform comes out as one self-contained executable.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build
rm -rf "$OUT"
mkdir -p "$OUT/linux" "$OUT/windows"

# Power words fire on situations that are hard to reach by playing — three
# identically stamped blocks, or a board one row from the ceiling — so they are
# exactly the rules most likely to rot unnoticed. Gate the build on them.
#
# Captured to a variable rather than piped into `grep -q`: this script runs under
# `pipefail`, and grep exiting the moment it matches sends godot a SIGPIPE, which
# would fail the pipeline on success.
echo "==> Rules check"
RULES=$("$(command -v godot)" --headless --script tools/powertest.gd 2>&1 || true)
if ! grep -q "all power words behave" <<<"$RULES"; then
	echo "FAILED: the power words are not behaving." >&2
	grep -E "FAILED" <<<"$RULES" >&2 || true
	echo "        Run: godot --headless --script tools/powertest.gd" >&2
	exit 1
fi

# The profile is somebody's entire history with the game. A bug that loses it is
# a different order of mistake from a block landing in the wrong column, so the
# save round-trip is checked before anything ships.
echo "==> Mastery check"
MASTERY=$("$(command -v godot)" --headless --script tools/masterytest.gd 2>&1 || true)
if ! grep -q "mastery holds up" <<<"$MASTERY"; then
	echo "FAILED: the mastery record is not behaving." >&2
	grep -E "FAILED" <<<"$MASTERY" >&2 || true
	echo "        Run: godot --headless --script tools/masterytest.gd" >&2
	exit 1
fi

# Two ways for a filter to be wrong, and the second is the one that would be
# noticed: refusing to print `classic` in a game about the letters inside words.
echo "==> Censor check"
CENSOR=$("$(command -v godot)" --headless --script tools/censortest.gd 2>&1 || true)
if ! grep -q "censor behaves" <<<"$CENSOR"; then
	echo "FAILED: the profanity filter is not behaving." >&2
	grep -E "FAILED" <<<"$CENSOR" >&2 || true
	echo "        Run: godot --headless --script tools/censortest.gd" >&2
	exit 1
fi

# Six kinds, six rules, and each rule has exactly one way of being wrong.
echo "==> Block check"
BLOCKS=$("$(command -v godot)" --headless --script tools/blocktest.gd 2>&1 || true)
if ! grep -q "blocks behave" <<<"$BLOCKS"; then
	echo "FAILED: the special block kinds are not behaving." >&2
	grep -E "FAILED" <<<"$BLOCKS" >&2 || true
	echo "        Run: godot --headless --script tools/blocktest.gd" >&2
	exit 1
fi

# Practice makes two promises — you cannot lose it and it cannot be farmed —
# and both are easy to break later with a mode flag missed in one branch.
echo "==> Practice check"
PRACTICE=$("$(command -v godot)" --headless --script tools/practicetest.gd 2>&1 || true)
if ! grep -q "practice behaves" <<<"$PRACTICE"; then
	echo "FAILED: the tutorial or training mode is not behaving." >&2
	grep -E "FAILED" <<<"$PRACTICE" >&2 || true
	echo "        Run: godot --headless --script tools/practicetest.gd" >&2
	exit 1
fi

echo "==> Linux"
godot --headless --export-release "Linux" "$OUT/linux/WordWars.x86_64" >/dev/null
echo "==> Windows"
godot --headless --export-release "Windows Desktop" "$OUT/windows/WordWars.exe" >/dev/null

# Every asset check below reads the same boot, so boot once.
echo "==> Verifying the assets shipped"
chmod +x "$OUT/linux/WordWars.x86_64"
BOOT=$("$OUT/linux/WordWars.x86_64" --headless --quit-after 120 2>&1 || true)

# The word lists are plain .txt, not imported resources, so they only make it
# into a build via the preset's include_filter. That is easy to break and gives
# no error — the game just starts with an empty dictionary and rejects every
# word. So prove the lists are in there rather than assuming.
if ! grep -q "WordBank: 3" <<<"$BOOT"; then
	echo "FAILED: the build starts with no dictionary." >&2
	echo "        Check include_filter in export_presets.cfg." >&2
	exit 1
fi

# Music, art and fonts are imported, so unlike the word lists they ship on their
# own — but the game is written to carry on without them rather than crash,
# which is exactly what makes a missing one easy to miss. Each says so on boot.
if grep -qE "Music: missing track|splash art missing|title font missing" <<<"$BOOT"; then
	echo "FAILED: an imported asset did not make it into the build:" >&2
	grep -E "Music: missing track|splash art missing|title font missing" <<<"$BOOT" >&2
	exit 1
fi

# macOS. Exported straight from here — unlike iOS, Godot ships a finished
# universal binary for this platform rather than an Xcode project, so no Mac and
# no Xcode are involved in making it.
echo "==> macOS"
mkdir -p "$OUT/macos"
godot --headless --export-release "macOS" "$PWD/$OUT/macos/WordWars.zip" >/dev/null

# The dictionary check has to be done differently here. There is no booting a
# Mach-O binary on Linux, and macOS keeps the pck beside the executable rather
# than inside it — so the pck is opened directly and the word lists looked for by
# name. Without this the app would start with an empty dictionary and reject
# every word, exactly as on every other platform, with nothing to catch it.
if ! unzip -p "$OUT/macos/WordWars.zip" "*.pck" 2>/dev/null | grep -aq "data/words.txt"; then
	echo "FAILED: the macOS build has no dictionary." >&2
	echo "        Check include_filter in the macOS preset." >&2
	exit 1
fi

cp packaging/README-linux.txt "$OUT/linux/README.txt"
cp packaging/README-windows.txt "$OUT/windows/README.txt"

( cd "$OUT" && zip -q -j WordWars-linux-x86_64.zip linux/WordWars.x86_64 linux/README.txt )
( cd "$OUT" && zip -q -j WordWars-windows-x86_64.zip windows/WordWars.exe windows/README.txt )

# The macOS zip already contains the .app, so the readme is added to it rather
# than a second archive being wrapped around the first.
cp packaging/README-macos.txt "$OUT/macos/README.txt"
( cd "$OUT/macos" && zip -q WordWars.zip README.txt && rm README.txt )
mv "$OUT/macos/WordWars.zip" "$OUT/WordWars-macos-universal.zip"

# The launcher is a separate project on purpose: nothing can overwrite a running
# executable on Windows, so the updater must not be the thing being updated.
echo "==> Launcher"
mkdir -p "$OUT/launcher"
godot --headless --path launcher --export-release "Linux" "$PWD/$OUT/launcher/WordWarsLauncher.x86_64" >/dev/null
godot --headless --path launcher --export-release "Windows Desktop" "$PWD/$OUT/launcher/WordWarsLauncher.exe" >/dev/null
cp packaging/README-launcher.txt "$OUT/launcher/README.txt"
( cd "$OUT" && zip -q -j WordWarsLauncher-linux-x86_64.zip launcher/WordWarsLauncher.x86_64 launcher/README.txt )
( cd "$OUT" && zip -q -j WordWarsLauncher-windows-x86_64.zip launcher/WordWarsLauncher.exe launcher/README.txt )

echo "==> Done"
ls -lh "$OUT"/*.zip
