#!/usr/bin/env bash
# Every marketing still, then the caption cards built from them.
#
#     tools/shots.sh              phone stills -> build/shots, then the cards
#     tools/shots.sh --ipad       the tablet layout, split and full keyboards
#     tools/shots.sh --appstore   both submission sets, at Apple's sizes
#
# Output lands in build/shots (raw stills), build/shots/cards (1080x1920
# captioned, for posts) and build/shots/appstore (what App Store Connect takes).
# All three are gitignored along with the rest of build/.
#
# ## The three sets are three different jobs
#
# The stills are for looking at a layout. The cards are for posting — 1080x1920
# is the shape every social surface wants and none of the App Store slots are,
# and they carry caption furniture that a store screenshot may not.
#
# `--appstore` is the only one that produces something submittable: 1320x2868
# for the 6.9-inch iPhone and 2064x2752 for the 13-inch iPad, which are the two
# sizes Apple asks for and scales the rest of the listing from. Neither of the
# other two sets is any of those sizes, which is worth knowing before an upload
# is rejected for it. No caption pass runs over them, deliberately.
#
# One process per shot rather than one process for all of them. Each shot pokes
# at autoload state — Profile for the mastery numbers, Boards for the injected
# leaderboard, WordBank's seed for the daily — and a fresh process is the only
# cheap way to be sure none of that leaks into the next frame. The cost is
# reloading the 350k-word dictionary each time, which is about half a second.
#
# Needs a real display: --headless renders these blank. See tools/shots.gd.
set -euo pipefail
cd "$(dirname "$0")/.."

SHOTS=(title solo daily survival boards mastery)
MODE="${1:-plain}"

# shot + flags -> one still, with the godot chatter filtered down to our line.
shoot() {
	godot --script tools/shots.gd -- "$@" 2>&1 | grep -E '^\[shots\]' || {
		echo "  FAILED — rerun without the grep to see why: $*" >&2
		exit 1
	}
}

case "$MODE" in
plain)
	for s in "${SHOTS[@]}"; do
		echo "--- $s ---"
		shoot "$s"
	done
	python3 tools/caption-shots.py
	;;
--ipad)
	# Both halves of the keyboard setting. The split is what a tablet gets by
	# default and the full board is the other one, which only exists on
	# hardware nobody in the room owns and so ships unlooked-at otherwise.
	for s in "${SHOTS[@]}"; do
		echo "--- $s (ipad) ---"
		shoot "$s" --ipad
		shoot "$s" --ipad --fullkeys
	done
	;;
--appstore)
	# The phone set is required, and the tablet set becomes required the moment
	# the listing claims iPad — which this one now does.
	for s in "${SHOTS[@]}"; do
		echo "--- $s (app store) ---"
		shoot "$s" --appstore
		shoot "$s" --ipad --appstore
	done
	echo
	echo "==> build/shots/appstore — upload the plain files as iPhone 6.9\","
	echo "    the -ipad files as iPad 13\". Sizes are checked above."
	;;
*)
	echo "usage: tools/shots.sh [--ipad|--appstore]" >&2
	exit 2
	;;
esac
