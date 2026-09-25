#!/usr/bin/env bash
# Assemble everything a newsletter or a reviewer asks for, into build/presskit.
#
#     tools/presskit.sh
#
# Gathers what the other tools already produce rather than producing anything of
# its own — the screenshots come from tools/shots.sh, the trailer from
# tools/trailer.sh and tools/trailercut.py, the vertical cuts from
# tools/adcut.py. The one thing built here is the GIF, because nothing else
# needs one.
#
# Missing pieces are reported and skipped rather than fatal, so this can be run
# early to see what is still outstanding.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=build/presskit
TRAILER=build/trailer/word-wars-trailer.mp4

rm -rf "$OUT"
mkdir -p "$OUT/screenshots" "$OUT/social"

missing=()
have() { [[ -f "$1" ]] || { missing+=("$2"); return 1; }; }

# --- the trailer ----------------------------------------------------------
if have "$TRAILER" "trailer — run tools/trailer.sh then tools/trailercut.py"; then
	cp "$TRAILER" "$OUT/word-wars-trailer.mp4"

	# The GIF, which is the asset most newsletters actually embed: a lot of mail
	# templates cannot autoplay video, so a submission that arrives with a loop
	# already made is measurably less work for whoever is deciding to run it.
	#
	# Two passes for a shared palette. A per-frame palette on a picture this
	# dark bands the background into visible steps, and the game is drawn almost
	# entirely in near-blacks. `bayer` dithering rather than the default because
	# it compresses far better on flat areas — same reason, opposite direction.
	echo "==> building the GIF"
	GIF_FROM=$(python3 - <<'PY'
# Start the loop at the rally, not at the title screen: a GIF that opens on a
# menu spends its first second saying nothing, and it will be seen in a mail
# client at about 300px wide where a menu is unreadable anyway.
import sys
scenes = {}
for line in open("build/trailer/raw/take.beats"):
    b = line.split()
    if b and b[0] == "[scene]":
        scenes[b[1]] = (float(b[2]), float(b[3]))
print("%.2f" % scenes.get("rally", (8.0, 0))[0])
PY
	)
	# Every number here is fighting file size, and the first pass at 15fps/480px
	# came back 13MB — past what most mail clients will inline and well past the
	# 5MB a submission should be. The game's screen grain is what does it: fine
	# per-pixel noise defeats GIF's run-length compression completely, so a
	# sigma-0.4 blur that is invisible at this size is worth more than any
	# palette tuning. With that in, 10fps at 380px on 80 colours lands at 3.6MB
	# and still reads as motion.
	ffmpeg -y -loglevel error -ss "$GIF_FROM" -t 5 -i "$TRAILER" \
		-vf "fps=10,scale=380:-1:flags=lanczos,gblur=sigma=0.4,split[a][b];[a]palettegen=max_colors=80[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
		-loop 0 "$OUT/word-wars.gif"
	echo "    $OUT/word-wars.gif ($(du -h "$OUT/word-wars.gif" | cut -f1))"
fi

# --- screenshots ----------------------------------------------------------
if compgen -G "build/shots/*.png" >/dev/null; then
	cp build/shots/*.png "$OUT/screenshots/" 2>/dev/null || true
	echo "==> screenshots: $(ls "$OUT/screenshots" | wc -l) files"
else
	missing+=("screenshots — run tools/shots.sh and tools/shots.sh --ipad")
fi

# --- the vertical cuts ----------------------------------------------------
if compgen -G "build/ads/[A-E]-*.mp4" >/dev/null; then
	cp build/ads/[A-E]-*.mp4 "$OUT/social/"
	echo "==> social: $(ls "$OUT/social" | wc -l) clips"
else
	missing+=("social clips — run tools/adcut.py all")
fi

# --- icon -----------------------------------------------------------------
if have appicon-1024.png "app icon"; then
	cp appicon-1024.png "$OUT/icon-1024.png"
fi

# --- the written kit ------------------------------------------------------
cp docs/presskit/README.md "$OUT/PRESSKIT.md"
cp docs/presskit/submissions.md "$OUT/SUBMISSIONS.md"

echo
echo "==> $OUT"
du -sh "$OUT"
if ((${#missing[@]})); then
	echo
	echo "still missing:"
	printf '  - %s\n' "${missing[@]}"
fi
