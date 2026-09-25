#!/usr/bin/env bash
# Landscape and square cuts of the install ad, for Google App campaigns.
#
#     tools/adwide.sh
#
# Writes build/ads/F-download-16x9.mp4 (1920x1080) and
# build/ads/F-download-1x1.mp4 (1080x1080) from the vertical F-download.mp4.
#
# ## Why this is a re-frame and not a crop
#
# F is 1080x1920 and every caption in it was positioned against that frame.
# Cropping a 16:9 window out of it keeps about a third of the picture and none
# of the type — the board would survive and the headline, the score and the
# keyboard would all be outside the frame.
#
# So the vertical clip is kept whole and placed on a wider canvas, with the
# headline set beside it. That is the same answer `adshots.py` reached for the
# square and landscape stills, for the same reason, and it means the still and
# the video in one campaign look like one campaign.
#
# The copy beside the clip is deliberately not the clip's own caption. The first
# pass set "the letters you leave behind become their next problem" on the left
# while the video was saying the same sentence in the middle, which reads as a
# duplicated layer rather than as emphasis. The panel makes a different claim —
# that it is real-time — and lets the video make its own.
#
# The alternative — recording a landscape take — is a worse idea than it sounds:
# the game's landscape layout is a different composition, so it would be an ad
# for a screen most players will never see. This shows the phone, because the
# phone is the product.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=build/ads/F-download.mp4
[[ -f "$SRC" ]] || { echo "no $SRC — run tools/adcut.py F first" >&2; exit 1; }

HEAVY=fonts/BarlowCondensed-ExtraBold.ttf
LIGHT=fonts/BarlowSemiCondensed-Bold.ttf

# The game's own palette, as ffmpeg wants it.
VOID=0x0b1020
INK=0xe6ecff
CYAN=0x7bdff2
DIM=0x7787b5

# One encode per shape. `-shortest` is not used: both outputs are exactly as
# long as the source, and the colour flags match everything else the repo ships
# so a platform transcoder is not handed an untagged file to guess about.
frame () {
  local out=$1 w=$2 h=$3 vh=$4 vx=$5 tx=$6 h1y=$7 h2y=$8 suby=$9 ctay=${10} fs=${11} subfs=${12}
  local vw=$(( vh * 1080 / 1920 / 2 * 2 ))
  ffmpeg -y -loglevel error \
    -f lavfi -i "color=c=$VOID:s=${w}x${h}:r=30" \
    -i "$SRC" \
    -filter_complex "
      [0:v]drawbox=x=0:y=0:w=${w}:h=${h}:color=${VOID}:t=fill,
           geq=r='r(X,Y)+18*exp(-((X-${w})^2+(Y)^2)/${w}00)':g='g(X,Y)':b='b(X,Y)'[bg];
      [1:v]scale=${vw}:${vh},
           pad=${vw}+8:${vh}+8:4:4:color=0x26305c[dev];
      [bg][dev]overlay=x=${vx}:y=(H-h)/2:shortest=1[c];
      [c]drawtext=fontfile=${HEAVY}:text='WORD GAME':x=${tx}:y=${h1y}:fontsize=${fs}:fontcolor=${INK},
         drawtext=fontfile=${HEAVY}:text='THAT HITS BACK':x=${tx}:y=${h2y}:fontsize=${fs}:fontcolor=${CYAN},
         drawtext=fontfile=${LIGHT}:text='Not turn-based. You both':x=${tx}:y=${suby}:fontsize=${subfs}:fontcolor=${DIM},
         drawtext=fontfile=${LIGHT}:text='type at once.':x=${tx}:y=${suby}+$((subfs+10)):fontsize=${subfs}:fontcolor=${DIM},
         drawtext=fontfile=${HEAVY}:text='Free on the App Store':x=${tx}:y=${ctay}:fontsize=${subfs}+6:fontcolor=${CYAN},
         format=yuv420p[v]" \
    -map "[v]" -map "1:a" \
    -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p -profile:v high -level 4.0 -r 30 \
    -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
    -c:a aac -b:a 160k -ar 48000 -movflags +faststart \
    "$out"
  echo "    $out  $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$out")  $(du -h "$out" | cut -f1)"
}

echo "==> re-framing $SRC"
# The inset must fit: a 9:16 clip `vh` tall is `vh*1080/1920` wide, plus the 8px
# border, and `vx` plus that has to land inside `w`. The square was first laid
# out at vx=600 with a 528-wide clip on a 1080 canvas, which put 56px of the
# phone — and the whole right-hand column of the keyboard — outside the frame.
#      out                              w    h    vh   vx    tx   h1y  h2y  suby ctay fs  subfs
frame build/ads/F-download-16x9.mp4   1920 1080  980 1180   110  330  430  570  700  86  34
frame build/ads/F-download-1x1.mp4    1080 1080  900  546    52  300  376  486  620  58  24
