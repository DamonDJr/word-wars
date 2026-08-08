#!/usr/bin/env bash
# Builds shippable Windows and Linux binaries and zips them for sending.
#
#   tools/build.sh
#
# Needs Godot 4.7 on PATH with export templates installed (Editor > Manage
# Export Templates). Each build is a single self-contained executable.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=build
rm -rf "$OUT"
mkdir -p "$OUT/linux" "$OUT/windows"

echo "==> Linux"
godot --headless --export-release "Linux" "$OUT/linux/WordWars.x86_64" >/dev/null
echo "==> Windows"
godot --headless --export-release "Windows Desktop" "$OUT/windows/WordWars.exe" >/dev/null

# The word lists are plain .txt, not imported resources, so they only make it in
# via the preset's include_filter. Prove they did rather than assume it.
echo "==> Verifying the dictionary shipped"
chmod +x "$OUT/linux/WordWars.x86_64"
if ! "$OUT/linux/WordWars.x86_64" --headless --quit-after 120 2>&1 | grep -q "WordBank: 3"; then
  echo "FAILED: the build starts with no dictionary — check include_filter in export_presets.cfg" >&2
  exit 1
fi

cp "$OUT/linux/README.txt" "$OUT/linux/README.txt" 2>/dev/null || true
( cd "$OUT" && zip -q -j WordWars-linux-x86_64.zip linux/WordWars.x86_64 linux/README.txt 2>/dev/null || zip -q -j WordWars-linux-x86_64.zip linux/WordWars.x86_64 )
( cd "$OUT" && zip -q -j WordWars-windows-x86_64.zip windows/WordWars.exe windows/README.txt 2>/dev/null || zip -q -j WordWars-windows-x86_64.zip windows/WordWars.exe )

ls -lh "$OUT"/*.zip
