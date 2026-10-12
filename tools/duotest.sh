#!/usr/bin/env bash
# Every Duo pose, and every way of changing between them, as assertions.
#
#     tools/duotest.sh
#
# One process per pose because `start_match` is not built to be called many
# times into one tree — see `duotest.gd`. Needs no display: it lays out, it does
# not render.
set -uo pipefail
cd "$(dirname "$0")/.."

run() {
	local out
	out=$(godot --headless --script tools/duotest.gd -- "$@" 2>&1 | grep -E "^---|(ok|FAILED)( +\[.*\])?$|SCRIPT ERROR|Parse Error" || true)
	echo "$out"
	grep -q "FAILURES\|SCRIPT ERROR\|Parse Error" <<<"$out" && return 1
	return 0
}

bad=0
run classify || bad=1
# Every pose a player can be in, each one first.
for p in outer-portrait inner-portrait inner-landscape inner-portrait-laptop inner-landscape-book iphone ipad ipad-landscape ipad-window-wide; do
	run "$p" || bad=1
done
# And the changes between them: opening, closing, turning, partly folding.
for pair in \
	"outer-portrait inner-portrait" \
	"inner-portrait outer-portrait" \
	"inner-portrait inner-landscape" \
	"inner-landscape outer-portrait" \
	"inner-portrait inner-portrait-laptop" \
	"inner-landscape inner-landscape-book"; do
	set -- $pair
	run "$1" --then "$2" || bad=1
done
[ "$bad" = 0 ] && echo "=== duo poses behave ===" || { echo "=== FAILURES ===" >&2; exit 1; }
