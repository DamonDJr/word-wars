#!/usr/bin/env bash
# Every Duo pose, rendered and then composed into one comparison sheet.
#
#     tools/duoshots.sh            # renders + the sheet, into build/duo/
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

POSES=(iphone outer-portrait inner-portrait inner-landscape inner-portrait-laptop inner-landscape-book ipad)
OUT=build/duo
# Sheet pixels per inch of real glass. 110 keeps the iPad (8.9 inches tall) under
# a thousand pixels while leaving the keyboard legible.
SHEET_PPI=110

# Physical size of each panel, in inches: render pixels over density. Kept in
# step with tools/duo_poses.gd by hand — there are seven numbers here and a
# GDScript-to-shell bridge is not worth writing for seven numbers.
declare -A INCHES=(
	[iphone]="2.563x5.557"                # 1179x2556 @ 460ppi
	[outer-portrait]="3.039x4.422"        # 1398x2034 @ 460ppi
	[inner-portrait]="4.373x6.216"        # 2007x2853 @ 459ppi
	[inner-landscape]="6.216x4.373"       # the same panel turned over
	[inner-portrait-laptop]="4.373x6.216"
	[inner-landscape-book]="6.216x4.373"
	[ipad]="6.212x8.939"                  # 1640x2360 @ 264ppi
)

declare -A LABEL=(
	[iphone]="iPhone 15 · 6.1in\nupright"
	[outer-portrait]="Duo CLOSED · 5.4in\nouter display"
	[inner-portrait]="Duo OPEN · 7.6in\nheld tall"
	[inner-landscape]="Duo OPEN · 7.6in\nheld wide"
	[inner-portrait-laptop]="Duo as a laptop\nheld tall, partly folded"
	[inner-landscape-book]="Duo as a book\nheld wide, partly folded"
	[ipad]="iPad Air · 10.9in\nupright"
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
		-background '#0b1020' -fill '#cfd8f0' -pointsize 17 \
		-gravity center label:"$(printf "${LABEL[$pose]}")" -append \
		-bordercolor '#0b1020' -border 14 \
		"$OUT/.plate-$pose.png"
}

# One sheet, at true physical size: the tall poses in a row and the wide ones
# under it. Each pose is scaled so a pixel is 1/110th of an inch of real glass,
# everywhere — which is the only way "is this big enough to play on" can be seen,
# because every render is roughly a thousand design units across.
for p in "${POSES[@]}"; do plate "$p"; done
magick "$OUT/.plate-iphone.png" "$OUT/.plate-outer-portrait.png" \
	"$OUT/.plate-inner-portrait.png" "$OUT/.plate-inner-portrait-laptop.png" \
	"$OUT/.plate-ipad.png" \
	-background '#0b1020' -gravity south +append "$OUT/.row-tall.png"
magick "$OUT/.plate-inner-landscape.png" "$OUT/.plate-inner-landscape-book.png" \
	-background '#0b1020' -gravity north +append "$OUT/.row-wide.png"
magick "$OUT/.row-tall.png" "$OUT/.row-wide.png" \
	-background '#0b1020' -gravity west -append \
	-bordercolor '#0b1020' -border 20 "$OUT/sheet-poses.png"

rm -f "$OUT"/.plate-*.png "$OUT"/.row-*.png
echo "[duo] $OUT/sheet-poses.png"
