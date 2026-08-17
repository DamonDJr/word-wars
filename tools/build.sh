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

# The scoreboard reads six numbers off every board in the match, and only two of
# them were ever on the wire. Against a CPU it looked perfect — a CPU is
# simulated here, so its state is the real one — and against a person four
# columns read zero. Nothing but a finished networked match could show it.
echo "==> Net state check"
NET=$("$(command -v godot)" --headless --script tools/nettest.gd 2>&1 || true)
if ! grep -q "net state behaves" <<<"$NET"; then
	echo "FAILED: the network state is dropping something the scoreboard shows." >&2
	grep -E "FAILED" <<<"$NET" >&2 || true
	echo "        Run: godot --headless --script tools/nettest.gd" >&2
	exit 1
fi

# You could win a match and finish second on points, because the two hardest
# things in the game paid nothing. These bonuses are what tie the scoreboard back
# to the result, and focus fire is invisible by construction — the only symptom
# is that blocks get bigger, which is indistinguishable from a chain tier.
echo "==> Scoring check"
SCORE=$("$(command -v godot)" --headless --script tools/scoretest.gd 2>&1 || true)
if ! grep -q "scoring behaves" <<<"$SCORE"; then
	echo "FAILED: the scoring or the focus rule is not behaving." >&2
	grep -E "FAILED" <<<"$SCORE" >&2 || true
	echo "        Run: godot --headless --script tools/scoretest.gd" >&2
	exit 1
fi

# A premium cosmetic that any amount of playing can reach is a sale given away,
# and one that a purchase fails to deliver is worse. Every other unlock here is
# a pure function of the record, and that formula gets re-tuned — so the check
# is that a maxed-out career still cannot reach the paid entries.
echo "==> Shop check"
SHOP=$("$(command -v godot)" --headless --script tools/shoptest.gd 2>&1 || true)
if ! grep -q "shop behaves" <<<"$SHOP"; then
	echo "FAILED: the premium pack is not behaving." >&2
	grep -E "FAILED" <<<"$SHOP" >&2 || true
	echo "        Run: godot --headless --script tools/shoptest.gd" >&2
	exit 1
fi

# The daily makes two promises that both fail quietly: the same board for
# everyone, and one run a day. A daily that deals different boards still looks
# like a working daily — it just is not a contest — and a second attempt at a
# board you have already seen is not a score anyone can compare.
echo "==> Daily check"
DAILY=$("$(command -v godot)" --headless --script tools/dailytest.gd 2>&1 || true)
if ! grep -q "daily behaves" <<<"$DAILY"; then
	echo "FAILED: the daily board is not behaving." >&2
	grep -E "FAILED" <<<"$DAILY" >&2 || true
	echo "        Run: godot --headless --script tools/dailytest.gd" >&2
	exit 1
fi

# Haptics fail silently by construction: there is no taptic engine on this
# machine, so a call naming an event that does not exist does exactly what a
# correct one does here — nothing. Nobody would find out until a phone did.
echo "==> Haptics check"
HAPTIC=$("$(command -v godot)" --headless --script tools/haptictest.gd 2>&1 || true)
if ! grep -q "haptics behave" <<<"$HAPTIC"; then
	echo "FAILED: the haptics are not behaving." >&2
	grep -E "FAILED|unknown:" <<<"$HAPTIC" >&2 || true
	echo "        Run: godot --headless --script tools/haptictest.gd" >&2
	exit 1
fi

# Q was untypeable on every desktop build for several releases, because `match`
# does not fall through and the arm that owned Q only did anything while paused.
# Any shortcut added to the play phase can do the same to its letter, and the
# phone build cannot see it — the drawn keyboard never goes near that code.
echo "==> Keys check"
KEYS=$("$(command -v godot)" --headless --script tools/keystest.gd 2>&1 || true)
if ! grep -q "keys behave" <<<"$KEYS"; then
	echo "FAILED: a letter cannot be typed." >&2
	grep -E "FAILED|swallowed" <<<"$KEYS" >&2 || true
	echo "        Run: godot --headless --script tools/keystest.gd" >&2
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

# iOS is not built here — Godot emits an Xcode project and a Mac compiles it, so
# the shippable artifact comes out of .github/workflows/ios.yml. But the export
# step itself is just file writing, so it runs fine on Linux, and running it is
# the only way to find out on this machine that the preset is still valid. The
# thing worth catching is the dictionary: the word lists are plain .txt and
# reach the game only through include_filter, and losing them produces an app
# that starts cleanly and rejects every word. Ten seconds here beats finding it
# after a runner build and an install.
echo "==> iOS preset check"
# The directory has to exist first — the iOS exporter writes a tree of files
# beside the path it is given rather than creating it, and silently does nothing
# if it is not there.
mkdir -p "$OUT/ios-check"
godot --headless --export-release "iOS" "$PWD/$OUT/ios-check/WordWars.ipa" >/dev/null 2>&1 || true
if [ ! -f "$OUT/ios-check/WordWars.pck" ]; then
	echo "FAILED: the iOS export produced no pck." >&2
	echo "        Run: godot --headless --export-release iOS build/ios/WordWars.ipa" >&2
	exit 1
fi
for f in data/words.txt data/common.txt; do
	if ! grep -aq "$f" "$OUT/ios-check/WordWars.pck"; then
		echo "FAILED: $f is not in the iOS build." >&2
		echo "        Check include_filter in the iOS preset." >&2
		exit 1
	fi
done
# Half a gigabyte of xcframeworks that nothing downstream wants.
rm -rf "$OUT/ios-check"

cp packaging/README-linux.txt "$OUT/linux/README.txt"
cp packaging/README-windows.txt "$OUT/windows/README.txt"

# Everything the exporter wrote, not a hand-written list of it.
#
# This used to name the executable and the readme, which was true for as long as
# a build was one file. EOS arrives as a GDExtension, so a Linux export is now
# three files and a Windows one is four — and the two that were being dropped
# are the shared libraries the extension loads at startup. The game still ran
# perfectly from the export directory, so nothing here noticed; it only died for
# people who installed from the zip, with "Can't open dynamic library" followed
# by every EOS script failing to parse and the lobby refusing to accept a
# keystroke. Naming files by hand is what made that possible, so stop doing it.
( cd "$OUT/linux" && zip -q -r ../WordWars-linux-x86_64.zip . )
( cd "$OUT/windows" && zip -q -r ../WordWars-windows-x86_64.zip . )

# And prove it, rather than trusting the glob. A missing file here is invisible
# until somebody installs the thing.
for pair in "linux:WordWars-linux-x86_64.zip" "windows:WordWars-windows-x86_64.zip"; do
	dir="${pair%%:*}"
	zipf="${pair##*:}"
	if ! diff <(cd "$OUT/$dir" && find . -type f | sed 's|^\./||' | sort) \
			<(unzip -Z1 "$OUT/$zipf" | sort) >/dev/null; then
		echo "FAILED: $zipf does not match what the $dir export produced:" >&2
		diff <(cd "$OUT/$dir" && find . -type f | sed 's|^\./||' | sort) \
			<(unzip -Z1 "$OUT/$zipf" | sort) >&2 || true
		exit 1
	fi
done

# The one check that would have caught this: unpack the shipped zip somewhere
# with nothing else in it and boot that, which is exactly what the launcher does
# to somebody's machine. Booting the export directory proves nothing, because
# the export directory has the files the zip is missing.
echo "==> Booting the shipped zip"
rm -rf "$OUT/ziptest"
mkdir -p "$OUT/ziptest"
unzip -q "$OUT/WordWars-linux-x86_64.zip" -d "$OUT/ziptest"
chmod +x "$OUT/ziptest/WordWars.x86_64"
ZIPBOOT=$(cd "$OUT/ziptest" && ./WordWars.x86_64 --headless --quit-after 120 2>&1 || true)
if grep -qE "Can't open dynamic library|GDExtension dynamic library not found" <<<"$ZIPBOOT"; then
	echo "FAILED: the shipped zip is missing a native library." >&2
	grep -E "Can't open dynamic library|not found" <<<"$ZIPBOOT" | head -3 >&2
	exit 1
fi
if ! grep -q "WordBank: 3" <<<"$ZIPBOOT"; then
	echo "FAILED: the shipped zip does not start cleanly." >&2
	grep -E "ERROR|SCRIPT ERROR" <<<"$ZIPBOOT" | head -5 >&2
	exit 1
fi
rm -rf "$OUT/ziptest"

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
