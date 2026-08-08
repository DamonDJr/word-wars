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

echo "==> Linux"
godot --headless --export-release "Linux" "$OUT/linux/WordWars.x86_64" >/dev/null
echo "==> Windows"
godot --headless --export-release "Windows Desktop" "$OUT/windows/WordWars.exe" >/dev/null

# The word lists are plain .txt, not imported resources, so they only make it
# into a build via the preset's include_filter. That is easy to break and gives
# no error — the game just starts with an empty dictionary and rejects every
# word. So prove the lists are in there rather than assuming.
echo "==> Verifying the dictionary shipped"
chmod +x "$OUT/linux/WordWars.x86_64"
if ! "$OUT/linux/WordWars.x86_64" --headless --quit-after 120 2>&1 | grep -q "WordBank: 3"; then
	echo "FAILED: the build starts with no dictionary." >&2
	echo "        Check include_filter in export_presets.cfg." >&2
	exit 1
fi

cp packaging/README-linux.txt "$OUT/linux/README.txt"
cp packaging/README-windows.txt "$OUT/windows/README.txt"

( cd "$OUT" && zip -q -j WordWars-linux-x86_64.zip linux/WordWars.x86_64 linux/README.txt )
( cd "$OUT" && zip -q -j WordWars-windows-x86_64.zip windows/WordWars.exe windows/README.txt )

echo "==> Done"
ls -lh "$OUT"/*.zip
