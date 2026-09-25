#!/usr/bin/env bash
# Every Duo pose, rendered and then composed into comparison sheets.
#
#     tools/duoshots.sh            # renders + both sheets, into build/duo/
#     tools/duoshots.sh --probe    # the geometry table instead, to stdout
#
# The sheets are the point. Looking at one pose at a time proves nothing: the
# renders are all roughly a thousand design units across, so a 5.4-inch cover
# screen and a 10.9-inch iPad arrive on screen the same size and the entire
# question — is this big enough to play on — is invisible. So each pose is
# scaled to its true physical size at a common PPI before they are put side by
# side. A pixel on a sheet is 1/150th of an inch of real glass, everywhere.
#
# Do not add --headless. The dummy renderer saves blank images; see duoshots.gd.
set -euo pipefail
cd "$(dirname "$0")/.."

POSES=(iphone cover-phone cover-tablet open-phone open-tablet open-land ipad)
OUT=build/duo
# Sheet pixels per inch of real glass. 150 keeps the tallest sheet (the iPad, at
# 8.9 inches) under 1400px while leaving the keyboard legible.
SHEET_PPI=150

# Physical size of each panel, in inches: panel pixels over panel density.
# Kept in step with tools/duo_poses.gd by hand — there are seven numbers here
# and a GDScript-to-shell bridge is not worth writing for seven numbers.
declare -A INCHES=(
	[iphone]="2.563x5.557"      # 1179x2556 @ 460ppi
	[cover-phone]="3.039x4.422" # 1398x2034 @ 460ppi
	[cover-tablet]="3.039x4.422"
	[open-phone]="4.367x6.209"  # 1878x2670 @ 430ppi
	[open-tablet]="4.367x6.209"
	[open-land]="6.209x4.367"   # 2670x1878, the same panel turned over
	[ipad]="6.212x8.939"        # 1640x2360 @ 264ppi
)

declare -A LABEL=(
	[iphone]="iPhone 15 · 6.1in\nphone layout"
	[cover-phone]="Duo FOLDED · 5.4in\nphone layout"
	[cover-tablet]="Duo FOLDED · 5.4in\ntablet layout"
	[open-phone]="Duo OPEN · 7.6in\nphone layout"
	[open-tablet]="Duo OPEN · 7.6in\ntablet layout"
	[open-land]="Duo OPEN · 7.6in\nlandscape"
	[ipad]="iPad Air · 10.9in\ntablet layout"
)

if [[ "${1:-}" == "--probe" ]]; then
	printf '%-13s %-10s %8s  %-12s %8s  %-12s %8s %9s\n' \
		pose units 1u_in board_in cell_in key_in kbd_in above_in
	for p in "${POSES[@]}"; do
		DISPLAY="${DISPLAY:-:1}" godot --script tools/duoprobe.gd -- "$p" 2>/dev/null \
			| grep '^\[probe\]' | sed 's/^\[probe\] //' \
			| awk -F'|' '{printf "%-13s %-10s %8.5f  %5.2fx%-6.2f %8.3f  %5.2fx%-6.2f %8.2f %9.2f\n",
				$1,$2,$3,$4,$5,$6,$7,$8,$9,$10}'
	done
	exit 0
fi

mkdir -p "$OUT"
if [[ "${1:-}" != "--sheets-only" ]]; then
for p in "${POSES[@]}"; do
	DISPLAY="${DISPLAY:-:1}" godot --script tools/duoshots.gd -- "$p" 2>/dev/null \
		| grep '^\[duo\]' || { echo "render failed: $p" >&2; exit 1; }
done
fi

# Scale one render to true physical size and caption it.
plate() {
	local pose="$1" dims w h
	dims="${INCHES[$pose]}"
	# awk rather than bc: bc is not installed everywhere and awk is.
	w=$(awk -v v="${dims%x*}" -v p="$SHEET_PPI" 'BEGIN{printf "%.0f", v*p}')
	h=$(awk -v v="${dims#*x}" -v p="$SHEET_PPI" 'BEGIN{printf "%.0f", v*p}')
	# `-extent` was here and cropped the caption off every plate: it grows the
	# canvas from the gravity edge, so a south gravity pushed the two label lines
	# out of the bottom. A plain border does the same spacing job and cannot cut
	# anything.
	magick "$OUT/$pose.png" -resize "${w}x${h}!" \
		-bordercolor '#2a3550' -border 2 \
		-background '#0b1020' -fill '#cfd8f0' -pointsize 22 \
		-gravity center label:"$(printf "${LABEL[$pose]}")" -append \
		-bordercolor '#0b1020' -border 14 \
		"$OUT/.plate-$pose.png"
}

# Sheet one: the cover-screen question. An iPhone 15 for reference and the same
# folded Duo under both layouts — which is the decision, and nothing else.
for p in iphone cover-phone cover-tablet; do plate "$p"; done
magick "$OUT/.plate-iphone.png" "$OUT/.plate-cover-phone.png" \
	"$OUT/.plate-cover-tablet.png" \
	-background '#0b1020' -gravity south +append \
	-bordercolor '#0b1020' -border 20 "$OUT/sheet-cover.png"

# Sheet two: every pose the device has, plus an iPad for the far end of the
# range. The one that shows how much ground a single layout has to cover.
for p in cover-tablet open-tablet open-land ipad; do plate "$p"; done
magick "$OUT/.plate-cover-tablet.png" "$OUT/.plate-open-tablet.png" \
	"$OUT/.plate-open-land.png" "$OUT/.plate-ipad.png" \
	-background '#0b1020' -gravity south +append \
	-bordercolor '#0b1020' -border 20 "$OUT/sheet-poses.png"

rm -f "$OUT"/.plate-*.png
echo "[duo] $OUT/sheet-cover.png"
echo "[duo] $OUT/sheet-poses.png"
