#!/usr/bin/env bash
# The App Store screenshot set, captioned: render every screen, then compose.
#
#     tools/store-shots.sh
#
# Renders each screen at Apple's sizes, on the board it is shown on, with
# tools/shots.gd, then tools/store-shots.py puts the headline and the frame
# around it. The upload set lands in build/shots/store/{iphone,ipad}.
#
# Keep the list below in step with SHOTS in tools/store-shots.py — the render
# and the board name have to match the file the compositor looks for.
set -euo pipefail
cd "$(dirname "$0")/.."

RENDERS=(
	"solo volcano"
	"solo space"
	"versus clouds"
	"daily midnight"
	"survival ember"
	"cosmetics aurora"
	"boards midnight"
)

for spec in "${RENDERS[@]}"; do
	read -r shot board <<<"$spec"
	for device in "" "--ipad"; do
		echo "--- $shot on $board ${device:-(iphone)} ---"
		godot --script tools/shots.gd -- "$shot" --board "$board" --appstore $device 2>&1 \
			| grep -E '^\[shots\] res' || {
			echo "  FAILED — rerun without the grep to see why" >&2
			exit 1
		}
	done
done

python3 tools/store-shots.py
echo
echo "==> build/shots/store/iphone — upload as iPhone 6.9\""
echo "    build/shots/store/ipad   — upload as iPad 13\""
