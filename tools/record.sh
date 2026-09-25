#!/usr/bin/env bash
# Record a self-playing Godot scene at 1080x1920, with the game's own audio.
#
#     tools/record.sh --script tools/adreel.gd  --seed 11 --seconds 16 --out build/ads/raw/take-11
#     tools/record.sh --script tools/trailer.gd --seed 11 --out build/trailer/raw/take
#
# Produces <out>.mp4 and <out>.beats — the marker log the cut is driven from.
# Anything after `--` is passed through to the Godot script untouched.
#
# ## Why this script has to exist
#
# Godot's movie writer takes its output size from `display/window/size/viewport_*`
# in project.godot, read once at startup. Not from `--resolution`, which sizes
# the window the writer ignores; not from anything settable at runtime. So the
# only way to record at a size that is not the project's is to edit the project
# file, record, and put it back — and the put-it-back has to survive the record
# crashing, or the next person to open the editor finds the game is 1080x1920
# now and has no idea why. Hence the trap.
#
# ## Why AVI and then ffmpeg
#
# The movie writer only writes uncompressed AVI (hundreds of MB a minute here).
# That is a working format, not a deliverable, so it is transcoded and deleted.
set -euo pipefail
cd "$(dirname "$0")/.."

SCRIPT=tools/adreel.gd
OUT=build/ads/raw/take
W=1080
H=1920
PASS=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	--script) SCRIPT="$2"; shift 2 ;;
	--out) OUT="$2"; shift 2 ;;
	--size) W="${2%x*}"; H="${2#*x}"; shift 2 ;;
	# Everything the recorder does not itself need is the scene's business.
	# `--seed` and `--seconds` mean different things to different scenes, and
	# this wrapper has no opinion about either.
	--) shift; PASS+=("$@"); break ;;
	*) PASS+=("$1"); shift ;;
	esac
done

mkdir -p "$(dirname "$OUT")"

# One at a time, because two of these cannot coexist.
#
# Both instances edit the same project.godot and both restore it on the way out,
# so a second run started while the first is going will hand the recorder a
# viewport the wrong size, or restore the file out from under it mid-take. That
# is not theoretical: two overlapping batches produced a set of takes where the
# seed in the log did not match the seed in the footage, one file was a truncated
# 3MB, and the beat sheets belonged to different runs than the videos beside
# them. None of it announced itself as a failure — every command exited 0.
#
# `flock -n` with no waiting, because the honest answer to "the recorder is
# already running" is to say so rather than to queue up behind it silently.
LOCK="${TMPDIR:-/tmp}/adreel.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
	echo "another tools/record.sh is already recording — wait for it to finish." >&2
	echo "(they share project.godot, so they cannot run at the same time)" >&2
	exit 1
fi

AVI="$(mktemp -u "${TMPDIR:-/tmp}/adreel-XXXXXX.avi")"

# The restore has to be exact, so it is a copy of the real file rather than a
# sed that tries to reverse itself. A backup outside the repo, because a stray
# project.godot.bak inside it is the kind of thing that gets committed.
BACKUP="$(mktemp -u "${TMPDIR:-/tmp}/project-godot-XXXXXX.bak")"
cp project.godot "$BACKUP"
restore() {
	cp "$BACKUP" project.godot
	rm -f "$BACKUP" "$AVI"
}
trap restore EXIT

sed -i \
	-e "s/^window\/size\/viewport_width=.*/window\/size\/viewport_width=$W/" \
	-e "s/^window\/size\/viewport_height=.*/window\/size\/viewport_height=$H/" \
	project.godot

echo "==> recording $SCRIPT at ${W}x${H}"
# `--fixed-fps 30` decouples the recording from how slowly it renders: the
# result is correctly timed however long the wall clock took. Godot's own
# chatter is filtered to the reel's lines; the beats are teed to the cut sheet.
godot --fixed-fps 30 --write-movie "$AVI" --script "$SCRIPT" -- \
	--size "${W}x${H}" "${PASS[@]}" 2>&1 \
	| grep -E '^\[(reel|beat|scene|emote)\]' | tee "$OUT.beats"

if [[ ! -s "$AVI" ]]; then
	echo "  FAILED — no footage written. Rerun without the grep to see why." >&2
	exit 1
fi

echo "==> transcoding"
# CRF 16 because this is a master that gets re-encoded by the cut and again by
# whichever platform it is posted to. Generational loss is the thing to spend
# bitrate on here, not file size.
#
# The colour flags are not decoration. Godot writes the AVI as full-range RGB,
# and left to itself ffmpeg lands on `yuvj420p` tagged `pc` range with a
# `bt470bg` matrix and no primaries — which is full-range video wearing a 1970s
# PAL label. Players and platform transcoders that assume bt709 limited then
# stretch the levels, and the game is drawn almost entirely in near-blacks, so
# the failure shows up exactly where this footage lives: crushed shadows and a
# board that has lost its grid. Converting to bt709 limited here and tagging it
# means every stage after this one agrees about what the numbers mean.
# Audio is stated rather than left to ffmpeg's defaults, because one consumer of
# this file has a specification: an App Preview wants stereo AAC at 256kbps, and
# "whatever ffmpeg picked" is not a thing that can be checked before an upload is
# rejected. Harmless everywhere else — the ad reel and the trailer are both
# stereo game audio and neither cares what the bitrate is, so there is one
# setting rather than a flag nobody would remember to pass.
ffmpeg -y -loglevel error -i "$AVI" \
	-vf "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p" \
	-c:v libx264 -preset slow -crf 16 -r 30 \
	-colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
	-c:a aac -b:a 256k -ac 2 \
	"$OUT.mp4"

echo "==> $OUT.mp4  ($(du -h "$OUT.mp4" | cut -f1))"
