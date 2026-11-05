#!/usr/bin/env bash
# Every marketing still, then the caption cards built from them.
#
#     tools/shots.sh              phone stills -> build/shots, then the cards
#     tools/shots.sh --ipad       the tablet layout, split and full keyboards
#     tools/shots.sh --appstore   both submission sets, at Apple's sizes
#     tools/shots.sh --duo        the iPhone Duo's four submission sets, at Apple's sizes
#     tools/shots.sh --duo-poses  the partly folded poses, for the press kit
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
--duo)
	# The iPhone Duo is its own device class in App Store Connect, with an outer
	# display and an inner one, each in both orientations: 1398x2034 and
	# 2007x2853, and their landscapes. A phone with a hinge is never locked (see
	# `_apply_orientation_policy` in game.gd), so all four are poses a player is
	# actually in, and all four are here.
	#
	# Each size is its own folder under build/shots/appstore-duo/, numbered in
	# the order the listing should show them: the match first, since a glass
	# this size is what is being sold. The two inner sets each carry the folded
	# poses, at the inner display's own size, because they are the two things
	# only a Duo does: held tall like a laptop the board stands and the keys lie
	# on the table, and held wide like a book each player has a page.
	#
	# `pose:shot` pairs; a shot can carry its own flags after a comma.
	DUO_OUT=build/shots/appstore-duo
	rm -rf "$DUO_OUT"
	duo_set() {
		local dir="$DUO_OUT/$1"
		shift
		mkdir -p "$dir"
		local n=1
		for ps in "$@"; do
			local pose="${ps%%:*}" spec="${ps#*:}"
			local shot="${spec%%,*}" flags=""
			[[ "$spec" == *,* ]] && flags="${spec#*,}"
			echo "--- $shot $flags ($pose) ---"
			# shellcheck disable=SC2086
			shoot "$shot" --pose "$pose" $flags
			cp "build/shots/duo/$pose/$shot.png" \
				"$dir/$(printf '%02d' "$n")-$pose-$shot.png"
			n=$((n + 1))
		done
	}
	duo_set inner-landscape-2853x2007 \
		inner-landscape:solo inner-landscape-book:versus inner-landscape:survival \
		inner-landscape-book:title inner-landscape:daily inner-landscape:boards
	duo_set inner-portrait-2007x2853 \
		inner-portrait:solo inner-portrait-laptop:solo inner-portrait:survival \
		inner-portrait:boards inner-portrait:daily inner-portrait:mastery
	duo_set outer-portrait-1398x2034 \
		outer-portrait:solo outer-portrait:daily outer-portrait:survival \
		outer-portrait:versus outer-portrait:boards outer-portrait:title
	duo_set outer-landscape-2034x1398 \
		outer-landscape:solo outer-landscape:survival outer-landscape:versus \
		outer-landscape:daily
	echo
	# Every file the size its folder says, and no alpha channel, which App Store
	# Connect refuses outright.
	bad=0
	for f in "$DUO_OUT"/*/*.png; do
		want="${f%/*}"
		want="${want##*-}"
		# `%A` is the alpha flag: False is what Apple wants.
		got="$(magick identify -format '%wx%h %A' "$f")"
		case "$got" in
		"$want False" | "$want Undefined") ;;
		*) echo "  WRONG: $f is $got, wants $want without alpha" >&2; bad=1 ;;
		esac
	done
	[ "$bad" = 0 ] || exit 1
	echo "==> $DUO_OUT/<pose>-<size>/ — one folder per App Store Connect slot,"
	echo "    numbered in listing order. Sizes and channels are checked above."
	;;
--duo-poses)
	# The partly folded poses: the layout the game uses when the system reports
	# the crease. For the press kit and the docs — not for the listing, which
	# should show what every player sees first.
	for pose in inner-portrait-laptop inner-landscape-book; do
		for s in solo versus; do
			echo "--- $s ($pose) ---"
			shoot "$s" --pose "$pose"
		done
	done
	;;
*)
	echo "usage: tools/shots.sh [--ipad|--appstore|--duo|--duo-poses]" >&2
	exit 2
	;;
esac
