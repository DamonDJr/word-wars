#!/usr/bin/env python3
"""Cut the trailer from a take recorded by tools/trailer.sh.

    tools/trailercut.py
    tools/trailercut.py --take build/trailer/raw/take --out build/trailer/word-wars-trailer.mp4

## The timeline is not cut

The take is used end to end, in the order it was recorded, with only its head
and tail trimmed. That is a deliberate choice and it is about sound.

`trailer.gd` films twelve scenes in one continuous pass, so the recording
carries one continuous audio track — the music, the keystrokes and the impacts
all running in real time. The moment the picture is cut, that track is cut with
it, and every join needs a crossfade to hide a jump that would not have existed
if nothing had been cut. Eleven joins is eleven chances to hear the edit.

There is nothing to gain by paying that. The scenes already change completely —
title, board, argument, defeat, victory, leaderboard — so the variety a trailer
normally buys with cutting is variety this footage has anyway. What the cut adds
is typography, grading and light, laid over an unbroken take.

The consequence to know about: scene timings are fixed by the recording. To
change how long a movement runs, change the hold in `trailer.gd` and record
again. That is slower than dragging a clip, and it is the trade for an edit with
no seams in it.

## Everything on screen is the game's

The captions explain; they never assert anything the picture is not doing. The
emotes are the game's own emote bubbles, the defeat and victory screens are the
ones `_end_match` builds, and the leaderboard is the real screen drawn over
injected rows. See the header of `tools/trailer.gd` for what is staged and what
is not.
"""

import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from adcut import (  # noqa: E402
    CYAN, PINK, GOLD, INK, DEEP, RED, WHITE,
    W, H, FPS, HEADER, SAFE_LEFT, SAFE_RIGHT, VOID_TOP,
    c_in, ts, rect, style, ev, flash, dim, alpha_of, shake,
)


def load_markers(path):
    """The recording's own log, split into the three kinds of marker it writes."""
    scenes, beats, emotes = {}, [], []
    with open(path) as fh:
        for line in fh:
            bits = line.split()
            if not bits:
                continue
            if bits[0] == "[scene]":
                scenes[bits[1]] = (float(bits[2]), float(bits[3]))
            elif bits[0] == "[beat]":
                beats.append((float(bits[1]), bits[2], int(bits[3])))
            elif bits[0] == "[emote]":
                emotes.append((float(bits[1]), bits[2], bits[3]))
    if not scenes:
        sys.exit("no [scene] markers in %s — was the take recorded with trailer.gd?" % path)
    return scenes, beats, emotes


def card(t0, t1, st, text, y, rise=26, hold_in=0.34):
    """A caption that lifts into place and leaves without being noticed.

    Rising rather than punching. The ads punch because they are fighting for
    three seconds of attention in a feed; a trailer already has the viewer, and
    type that slams on every line reads as an advert rather than as a trailer.
    """
    dur_ms = int((t1 - t0) * 1000)
    return ev(t0, t1, st,
              (r"{\move(540,%d,540,%d,0,%d)\alpha&HFF&\blur6"
               r"\t(0,%d,\alpha&H00&\blur0)\t(%d,%d,\alpha&HFF&)}%s")
              % (y + rise, y, int(hold_in * 1000), int(hold_in * 1000),
                 dur_ms - 300, dur_ms, text))


def build(take, out, opts):
    scenes, beats, emotes = load_markers(take + ".beats")

    # Trim the very top and tail. The first frames are the title screen still
    # settling after the layout is forced, and the last are dead air after the
    # end card has said everything it is going to say.
    head = 0.35
    tail = scenes["endcard"][1] - 0.15
    dur = tail - head

    def at(name, edge=0):
        """A scene boundary, shifted into the finished trailer's own timeline."""
        return scenes[name][edge] - head

    styles = [
        style("Wordmark", "Barlow Condensed Black", 128, WHITE, outline=0, align=5),
        style("Big", "Barlow Condensed ExtraBold", 104, WHITE, outline=0, align=5),
        style("Hit", "Barlow Condensed ExtraBold", 112, CYAN, outline=0, align=5),
        style("Say", "Barlow Semi Condensed Medium", 58, INK, outline=0, align=5, bold=-1),
        style("SayHot", "Barlow Condensed Black", 62, GOLD, outline=0, align=5),
        style("Small", "Barlow Semi Condensed Medium", 46, INK, outline=0, align=5, bold=-1),
        style("End", "Barlow Condensed ExtraBold", 132, WHITE, outline=0, align=5),
        style("Sub", "Barlow Semi Condensed Medium", 52, CYAN, outline=0, align=5, bold=-1),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    e = []

    # --- the rule -------------------------------------------------------
    #
    # Three lines across the scene, arriving in the order the mechanic happens
    # in. This is the only place in the trailer where the viewer is being taught
    # something, so it gets the most screen time per word of anything here.
    r0, r1 = at("rule"), at("rule", 1)
    e.append(card(r0 + 0.25, r0 + 2.3, "Say", "the word you type", VOID_TOP + 40))
    e.append(card(r0 + 1.15, r0 + 3.4, "Hit",
                  r"ITS LAST LETTERS", VOID_TOP + 130))
    e.append(card(r0 + 2.5, r1 - 0.1, "Say",
                  r"land on their board", VOID_TOP + 250))

    # --- the rally ------------------------------------------------------
    y0, y1 = at("rally"), at("rally", 1)
    e.append(card(y0 + 0.5, y0 + 4.2, "SayHot",
                  r"your endings become their beginnings", VOID_TOP + 60))
    e.append(card(y0 + 5.0, y1 - 0.3, "Say",
                  r"and they have to answer every one", VOID_TOP + 60))

    # --- the argument ---------------------------------------------------
    #
    # One line, early, and then out of the way. The emotes are the joke and a
    # caption sitting on top of them is a caption explaining a joke.
    m0 = at("emotes")
    e.append(card(m0 + 0.3, m0 + 3.0, "Say", r"talk is part of it", VOID_TOP + 40))

    # --- chaos ----------------------------------------------------------
    c0, c1 = at("chaos"), at("chaos", 1)
    e.append(card(c0 + 0.4, c0 + 4.0, "Big", r"KEEP YOUR RHYTHM", VOID_TOP + 60))
    e.append(card(c0 + 4.4, c1 - 0.2, "Say",
                  r"nine words in a row is a 4x3 slab", VOID_TOP + 170))

    # --- danger ---------------------------------------------------------
    d0, d1 = at("danger"), at("danger", 1)
    e.append(card(d0 + 0.3, d1 - 0.1, "Big", r"BREAK IT AND", VOID_TOP + 40))
    e.append(card(d0 + 0.9, d1 - 0.1, "Hit", r"START FROM NOTHING", VOID_TOP + 150))

    # --- defeat ---------------------------------------------------------
    #
    # Nothing over it. The screen already says who won, and a trailer that
    # captions its own losing screen is arguing with the picture.
    f0, f1 = at("defeat"), at("defeat", 1)
    e.append(flash(f0, RED, opacity=0.30, hold=0.03, fall=0.35))
    e.append(card(f1 - 1.5, f1 - 0.05, "Small", r"you will lose some", VOID_TOP + 470))

    # --- the comeback ---------------------------------------------------
    k0 = at("comeback")
    e.append(card(k0 + 0.5, k0 + 3.6, "Big", r"SO WIN THE NEXT ONE", VOID_TOP + 60))

    # A flash on every genuinely large chain in the comeback, so the run reads
    # as building rather than as more of the same.
    for t0, word, chain in beats:
        local = t0 - head
        if k0 <= local <= at("comeback", 1) and chain >= 7:
            e.append(flash(local, GOLD, opacity=0.20, hold=0.02, fall=0.20))

    # --- victory --------------------------------------------------------
    v0 = at("victory")
    e.append(flash(v0, WHITE, opacity=0.34, hold=0.03, fall=0.30))

    # --- the boards -----------------------------------------------------
    b0, b1 = at("boards"), at("boards", 1)
    e.append(card(b0 + 0.4, b1 - 0.2, "Say", r"a new board every day", VOID_TOP + 40))
    s0, s1 = at("mastery"), at("mastery", 1)
    e.append(card(s0 + 0.3, s1 - 0.2, "Say", r"and a long way up it", VOID_TOP + 40))

    # --- end card -------------------------------------------------------
    n0 = at("endcard")
    # Nearly black, not merely dark. The scene underneath is the title screen,
    # which draws the game's own wordmark across the top — so at 0.80 the end
    # card showed WORD WARS twice, once faintly at the top and once large in the
    # middle, which reads as a mistake rather than as emphasis.
    e.append(dim(n0 + 0.15, dur, opacity=0.93, fade=0.4))
    e.append(ev(n0 + 0.45, dur, "Wordmark",
                r"{\pos(540,840)\fscx118\fscy118\blur10\alpha&H50&"
                r"\t(0,260,\fscx100\fscy100\blur0\alpha&H00&)}WORD WARS"))
    e.append(ev(n0 + 0.85, dur, "Sub",
                r"{\pos(540,980)\alpha&HFF&\t(0,280,\alpha&H00&)}"
                r"free on the App Store"))
    # iOS only. This line read "iPhone · iPad · Windows · Linux" until the
    # desktop builds turned out not to be finished — a trailer is the worst
    # place to name a platform somebody cannot actually download from.
    e.append(ev(n0 + 1.15, dur, "Small",
                r"{\pos(540,1070)\c" + c_in(PINK) +
                r"\alpha&HFF&\t(0,280,\alpha&H00&)}iPhone  ·  iPad"))

    ass_path = os.path.join(os.path.dirname(out) or ".", ".trailer.ass")
    with open(ass_path, "w") as fh:
        fh.write(HEADER % (W, H, "\n".join(styles), "\n".join(e)))

    # Camera shake only on the play scenes. The title, leaderboard and mastery
    # screens are menus, and a menu that shakes looks like a fault rather than
    # like impact.
    play_beats = [b for b in beats
                  if any(scenes[s][0] <= b[0] <= scenes[s][1]
                         for s in ("rule", "rally", "emotes", "chaos", "danger", "comeback"))]

    class B:  # `shake` wants .fire and .chain; the trailer's beats are tuples.
        def __init__(self, t, chain):
            self.fire, self.chain = t, chain

    sx, sy = shake([B(t - head, c) for t, _, c in play_beats], amp=16.0, gain=0.8)
    pad = 1.045

    # The camera is switched on only where it shakes.
    #
    # Shake needs headroom, headroom means scaling the frame up 4.5% and cropping
    # back, and a non-integer upscale resamples every pixel in the picture. On
    # gameplay that is invisible — the frame is moving anyway. On a menu it is
    # not: the title screen holds still, its row subtitles are one-pixel type,
    # and the game draws an animated grain over everything. Resampled, that grain
    # stops being texture and starts crawling, and the whole screen reads as
    # soft and unstable. It was reported as the menu "glitching and scrolling",
    # which is exactly what per-pixel crawl on static type looks like.
    #
    # So the graded frame is split: one branch untouched, one shaken, and an
    # `overlay` with a timeline `enable` chooses between them. The menus — title,
    # leaderboard, mastery, end card — come through at native resolution and stay
    # sharp, and nothing is resampled that does not need to be.
    windows = "+".join(
        "between(t,%.3f,%.3f)" % (at(a), at(b, 1))
        for a, b in (("rule", "danger"), ("comeback", "comeback")))

    # Grade first, so both branches match. Measured rather than eyeballed: the
    # first pass ran contrast 1.10 over a PI/4.5 vignette and dropped the average
    # luma of a busy frame from 44 to 28 — a third of the picture's light, on a
    # game drawn almost entirely in near-blacks, where there was none spare.
    # Contrast above 1 pivots on mid grey and so darkens far more than it lifts
    # here, and a vignette that reads as gentle on a 16:9 frame is not gentle
    # over 1920 vertical pixels. These land back at 44.7 with a little snap left.
    vf = (
        "[0:v]eq=contrast=1.05:saturation=1.20:brightness=0.055,vignette=a=PI/7,"
        "split[clean][fx];"
        "[fx]scale=%d:%d:flags=bicubic,"
        "crop=%d:%d:x='(iw-ow)/2+(%s)':y='(ih-oh)/2+(%s)'[shaken];"
        "[clean][shaken]overlay=0:0:enable='%s'[cam];"
        "[cam]subtitles=%s:fontsdir=fonts,"
        "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p[v]"
        % (int(W * pad) // 2 * 2, int(H * pad) // 2 * 2, W, H, sx, sy,
           windows, ass_path))

    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-ss", "%.3f" % head, "-t", "%.3f" % dur, "-i", take + ".mp4",
        "-filter_complex",
        "%s;[0:a]atrim=0:%.3f,asetpts=PTS-STARTPTS,"
        "afade=t=in:st=0:d=0.4,afade=t=out:st=%.3f:d=0.7,"
        "loudnorm=I=-14:TP=-1.5:LRA=11[a]" % (vf, dur, dur - 0.7),
        "-map", "[v]", "-map", "[a]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
        "-profile:v", "high", "-level", "4.0", "-r", str(FPS),
        "-colorspace", "bt709", "-color_primaries", "bt709",
        "-color_trc", "bt709", "-color_range", "tv",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart",
        out,
    ]
    print("--- trailer  %.2fs  %d scenes  %d beats" % (dur, len(scenes), len(beats)))
    subprocess.run(cmd, check=True)
    print("    %s" % out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--take", default="build/trailer/raw/take")
    ap.add_argument("--out", default="build/trailer/word-wars-trailer.mp4")
    args = ap.parse_args()
    if not os.path.exists(args.take + ".mp4"):
        sys.exit("no footage at %s.mp4 — record it with tools/trailer.sh" % args.take)
    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    build(args.take, args.out, {})


if __name__ == "__main__":
    main()
