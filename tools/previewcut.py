#!/usr/bin/env python3
"""Cut the App Store preview from a take recorded with `trailer.sh --preview`.

    tools/trailer.sh --seed 11 --size 886x1920 --out build/trailer/raw/preview --preview
    tools/previewcut.py

Apple's iPhone preview is 886x1920, 15-30 seconds, 30fps, H.264 with stereo
AAC. It autoplays **muted** in the first slot of the listing, so everything the
viewer needs to follow it is on screen as type; the game's own music and sound
ride underneath for anybody who taps it.

Like `trailercut.py`, the take is used whole — the board changing at each scene
boundary is the cut, so there are no joins in the audio. What this adds is the
captions, a white flash on each board change, a gold one on each big hit, the
camera kick on every word fired, and the grade.

## Why captions carry an outline here and not in the trailer

The trailer was filmed on the default navy board, where bare white type reads
fine. Every preview scene is on a painted board — lava, a lit sky, a neon city —
and bare type over those disappears. So these styles are outlined and shadowed
in the game's own near-black.

## Frame width

`adcut` is written against 1080x1920. The preview is 886 wide, so the width is
read from the take and every position here is worked out from it rather than
from the constant.
"""

import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from adcut import (  # noqa: E402
    CYAN, GOLD, INK, DEEP, RED, WHITE, FPS, HEADER, VOID_TOP,
    c_in, ts, style, ev, alpha_of, shake,
)
from trailercut import load_markers  # noqa: E402

## Which board each scene is filmed on — must match `PREVIEW_BOARDS` in
## tools/trailer.gd, since the tag names the board the viewer is looking at.
PREVIEW_BOARDS = {"hook": "volcano", "rule": "space", "rally": "clouds",
                  "danger": "cyber", "win": "forest"}

APPLE_MAX = 30.0
APPLE_MIN = 15.0


def frame_size(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "json", path],
        check=True, capture_output=True, text=True).stdout
    s = json.loads(out)["streams"][0]
    return int(s["width"]), int(s["height"])


def card(t0, t1, st, text, cx, y, rise=22, hold_in=0.26):
    """A caption that lifts in quickly and fades out. Quicker than the
    trailer's: a muted preview is read in glances, not watched."""
    dur_ms = int((t1 - t0) * 1000)
    return ev(t0, t1, st,
              (r"{\move(%d,%d,%d,%d,0,%d)\alpha&HFF&"
               r"\t(0,%d,\alpha&H00&)\t(%d,%d,\alpha&HFF&)}%s")
              % (cx, y + rise, cx, y, int(hold_in * 1000), int(hold_in * 1000),
                 dur_ms - 240, dur_ms, text))


def wash(t0, w, h, colour=WHITE, opacity=0.3, hold=0.03, fall=0.28):
    return ("Dialogue: 1,%s,%s,FX,,0,0,0,,{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\c%s"
            "\\alpha&H%02X&\\t(%d,%d,\\alpha&HFF&)}m 0 0 l %d 0 %d %d 0 %d"
            % (ts(t0), ts(t0 + hold + fall), c_in(colour), alpha_of(opacity),
               int(hold * 1000), int((hold + fall) * 1000), w, w, h, h))


def build(take, out):
    scenes, beats, _emotes = load_markers(take + ".beats")
    need = ["hook", "rule", "rally", "danger", "win"]
    missing = [n for n in need if n not in scenes]
    if missing:
        sys.exit("take has no %s scene — record it with trailer.sh --preview" % ", ".join(missing))

    w, h = frame_size(take + ".mp4")
    cx = w // 2
    head = 0.25
    tail = scenes["win"][1] - 0.1
    dur = tail - head
    if not APPLE_MIN <= dur <= APPLE_MAX:
        sys.exit("preview would be %.1fs; Apple takes %d-%ds" % (dur, APPLE_MIN, APPLE_MAX))

    def at(name, edge=0):
        return scenes[name][edge] - head

    # Outlined in the game's own near-black; see the module note.
    styles = [
        style("Big", "Barlow Condensed ExtraBold", 108, WHITE,
              outline_col=DEEP, outline=6, shadow=3, align=5),
        style("Hit", "Barlow Condensed ExtraBold", 116, CYAN,
              outline_col=DEEP, outline=6, shadow=3, align=5),
        style("Hot", "Barlow Condensed ExtraBold", 116, GOLD,
              outline_col=DEEP, outline=6, shadow=3, align=5),
        style("Red", "Barlow Condensed ExtraBold", 112, RED,
              outline_col=DEEP, outline=6, shadow=3, align=5),
        style("Say", "Barlow Condensed Black", 60, INK,
              outline_col=DEEP, outline=5, shadow=2, align=5),
        style("Tag", "Barlow Condensed Black", 30, GOLD,
              outline_col=DEEP, outline=4, shadow=1, align=9),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    # The phone's playfield is tall and its upper half stays empty; an iPad
    # frame is squarer, the board shorter, and the stack reaches higher up the
    # screen — so at the phone's positions the rule scene's third line landed
    # on the blocks. On a tablet-shaped frame the captions move up into the
    # board's empty top instead.
    tablet = h / w < 1.6
    top = 230 if tablet else VOID_TOP
    y1 = top + 10
    y2 = top + (105 if tablet else 130)
    e = []

    # hook — the first second has to earn the next twenty-five.
    a, b = at("hook"), at("hook", 1)
    e.append(card(max(0.0, a + 0.05), b, "Big", "TYPE WORDS.", cx, y1))
    e.append(card(a + 0.55, b, "Hot", "LAUNCH THEM.", cx, y2))

    # rule — the one thing a stranger has to understand.
    a, b = at("rule"), at("rule", 1)
    e.append(wash(a, w, h))
    e.append(card(a + 0.2, a + 2.4, "Say", "the word you type", cx, y1 + 20))
    e.append(card(a + 0.8, b, "Hit", "ITS LAST LETTERS", cx, y2))
    e.append(card(a + 2.3, b, "Say", "hit their board", cx, y2 + (90 if tablet else 110)))

    # rally — the game at speed, and the person on the other end.
    a, b = at("rally"), at("rally", 1)
    e.append(wash(a, w, h))
    e.append(card(a + 0.2, a + 3.2, "Big", "THEY ANSWER.", cx, y1))
    e.append(card(a + 3.6, b - 0.1, "Hit", "YOU ANSWER BACK.", cx, y1))

    # danger
    a, b = at("danger"), at("danger", 1)
    e.append(wash(a, w, h, colour=RED, opacity=0.28))
    e.append(card(a + 0.25, b, "Red", "DON'T HIT THE TOP.", cx, y1))

    # win — the answer, then the screen that says so, left clean.
    a, b = at("win"), at("win", 1)
    e.append(wash(a, w, h))
    e.append(card(a + 0.25, a + 3.0, "Hot", "BREAK THEM.", cx, y1))
    over = a + 3.2
    e.append(wash(over, w, h, opacity=0.36, fall=0.35))

    # Every scene is on a board from the Premium pack, and App Review Guideline
    # 2.3.2 requires a preview to say when what it features costs extra. So
    # each painted scene carries a tag naming its board as premium — in the
    # top-right corner beside the clock, which is empty in every scene, small
    # enough not to fight the captions, present for
    # the whole scene so nobody can miss it by blinking.
    for name, board in PREVIEW_BOARDS.items():
        if name not in scenes:
            continue
        a, b = at(name), at(name, 1)
        if name == "win":
            b = over
        e.append(ev(max(0.0, a), b, "Tag",
                    r"{\an9\pos(%d,%d)}%s  ·  PREMIUM BOARD" % (w - 24, 34, board.upper())))

    # A gold flash on every genuinely big hit, anywhere before the summary.
    for t0, _word, chain in beats:
        local = t0 - head
        if 0.0 <= local < over and chain >= 6:
            e.append(wash(local, w, h, colour=GOLD, opacity=0.16, hold=0.02, fall=0.18))

    ass = os.path.join(os.path.dirname(out) or ".", ".preview.ass")
    with open(ass, "w") as fh:
        fh.write(HEADER % (w, h, "\n".join(styles), "\n".join(e)))

    # The camera kick, on the play only — the summary holds still.
    class B:
        def __init__(self, t, chain):
            self.fire, self.chain = t, chain
    play = [B(t - head, c) for t, _, c in beats if 0.0 <= t - head < over]
    sx, sy = shake(play, amp=12.0, gain=0.8)
    pad = 1.035
    vf = (
        "[0:v]eq=contrast=1.05:saturation=1.22:brightness=0.05,vignette=a=PI/7,"
        "split[clean][fx];"
        "[fx]scale=%d:%d:flags=bicubic,"
        "crop=%d:%d:x='(iw-ow)/2+(%s)':y='(ih-oh)/2+(%s)'[shaken];"
        "[clean][shaken]overlay=0:0:enable='between(t,0,%.3f)'[cam];"
        "[cam]subtitles=%s:fontsdir=fonts,"
        "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p[v]"
        % (int(w * pad) // 2 * 2, int(h * pad) // 2 * 2, w, h, sx, sy, over, ass))

    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-ss", "%.3f" % head, "-t", "%.3f" % dur, "-i", take + ".mp4",
        "-filter_complex",
        "%s;[0:a]atrim=0:%.3f,asetpts=PTS-STARTPTS,"
        "afade=t=in:st=0:d=0.25,afade=t=out:st=%.3f:d=0.6,"
        "loudnorm=I=-14:TP=-1.5:LRA=11[a]" % (vf, dur, dur - 0.6),
        "-map", "[v]", "-map", "[a]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
        "-profile:v", "high", "-level", "4.0", "-r", str(FPS),
        "-colorspace", "bt709", "-color_primaries", "bt709",
        "-color_trc", "bt709", "-color_range", "tv",
        "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
        "-movflags", "+faststart",
        out,
    ]
    print("--- preview  %dx%d  %.2fs  %d beats" % (w, h, dur, len(beats)))
    subprocess.run(cmd, check=True)
    print("    %s" % out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--take", default="build/trailer/raw/preview")
    ap.add_argument("--out", default="build/trailer/word-wars-preview.mp4")
    args = ap.parse_args()
    if not os.path.exists(args.take + ".mp4"):
        sys.exit("no footage at %s.mp4 — record it with tools/trailer.sh --preview" % args.take)
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    build(args.take, args.out)


if __name__ == "__main__":
    main()
