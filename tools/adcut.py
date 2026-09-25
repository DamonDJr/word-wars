#!/usr/bin/env python3
"""Cut a social ad out of a take recorded by tools/adreel.sh.

    tools/adcut.py A --take build/ads/raw/take-11 --out build/ads/A.mp4
    tools/adcut.py all

Five variants, one per hook being tested. They deliberately do not share a look:
the point of running five is to find out which *register* works, so A is an
esports broadcast, B is a clean explainer, C is a challenge card, D is a
falling-apart meme and E is a plain text post with no effects at all. If they
were all cut the same way the test would only be measuring the words.

## Why the typography is ASS and the effects are ffmpeg filters

libass is a real motion-graphics renderer that happens to be aimed at subtitles.
It does per-glyph transforms, easing, blur, outlines, letter-spacing, vector
shapes and clipping wipes, all keyframed, all resolution-independent. Every
caption, bar, arrow, flash and end card in here is one ASS event, which is
enormously easier to write and re-time than the equivalent chain of `drawtext`
and `overlay`. The ffmpeg filters do only what ASS cannot: move the *camera*
(shake, punch), grade, and split the colour channels.

## Cuts land on the beat sheet, not on round numbers

`adreel.sh` writes one `[beat]` line per word fired, with the moment the first
key went down, the moment it fired, and the chain the hit landed on. That is a
cut sheet, so captions can be timed to the frame a block actually detonates
rather than to a guess. `pick_window` uses the same data to choose which stretch
of the take to use at all: the reel's board runs dry in its second half — the
picker takes the longest word on offer and clears faster than the ramp refills —
so the last ten seconds of a take are mostly waiting. Choosing by beat density
finds the part worth posting without anybody watching the take.
"""

import argparse
import os
import shutil
import subprocess
import sys

# The game's own palette, from scripts/game.gd. Ads that invent their own
# colours stop looking like the thing they are advertising, and the cyan/pink
# opposition is the game's whole visual argument — it is you against them.
CYAN = "#7bdff2"    # PLAYER_ACCENT
PINK = "#ff8fa3"    # AI_ACCENT
GOLD = "#ffd166"    # scores, big hits
PURPLE = "#c77dff"
INK = "#e6ecff"
DEEP = "#0b1020"    # bg_top
RED = "#f94144"     # SURVIVAL_ACCENT
WHITE = "#ffffff"

FPS = 30
W, H = 1080, 1920

# Where the ad is allowed to put things.
#
# Two different constraints happen to point the same way. The platforms draw
# their own furniture over the video — caption, handle and music ticker across
# the bottom, the like/comment/share rail up the right — and anything of ours
# underneath it is simply not read. Separately, the game draws its clock and
# score along the very top, and those are worth keeping visible in an ad about
# a score.
#
# So: nothing below VOID_BOTTOM, nothing right of SAFE_RIGHT, and the camera is
# never allowed to zoom far enough to crop the HUD.
SAFE_RIGHT = 940
SAFE_LEFT = 56
# The empty upper half of the playfield. Blocks stack from the floor and the
# reel never lets the board get more than about half full, so this band is the
# one place a caption can sit over the game without covering any of it.
VOID_TOP, VOID_BOTTOM = 330, 700
# The gap between the bottom of the board and the top of the keyboard, which the
# game only uses for the word being typed.
BAND_Y = 1200


def ass_c(hex_colour, alpha=0):
    """#rrggbb -> &Haabbggrr, for the colour fields of a style line.

    ASS is BGR with an inverted alpha — 00 is opaque — and both of those are
    easy to get backwards in a way that produces a plausible wrong colour rather
    than an obvious error, so the conversion lives in one place.
    """
    h = hex_colour.lstrip("#")
    return "&H%02X%s%s%s" % (alpha, h[4:6], h[2:4], h[0:2])


def c_in(hex_colour):
    """#rrggbb -> &Hbbggrr&, for an inline \\c override.

    A separate function from `ass_c` because the two contexts want different
    spellings: a style field is `&Haabbggrr` with the alpha and no terminator,
    an inline override is `&Hbbggrr&` with a trailing ampersand and no alpha.
    libass will often accept the wrong one, which is precisely why mixing them
    is worth avoiding — it fails on some builds and not others.
    """
    h = hex_colour.lstrip("#")
    return "&H%s%s%s&" % (h[4:6], h[2:4], h[0:2])


def ts(seconds):
    """Seconds -> 0:00:00.00, which is the only time format ASS accepts."""
    seconds = max(0.0, seconds)
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = seconds % 60
    return "%d:%02d:%05.2f" % (h, m, s)


def rect(x, y, w, h):
    """An ASS vector rectangle, for bars and full-screen flashes. Used with
    \\an7 so the drawing's origin is the position given rather than its centre."""
    return "m %d %d l %d %d l %d %d l %d %d" % (x, y, x + w, y, x + w, y + h, x, y + h)


class Beat:
    __slots__ = ("start", "fire", "word", "chain", "length")

    def __init__(self, start, fire, word, chain, length):
        self.start = start
        self.fire = fire
        self.word = word
        self.chain = chain
        self.length = length

    def shifted(self, by):
        return Beat(self.start - by, self.fire - by, self.word, self.chain, self.length)


def load_beats(path):
    beats = []
    with open(path) as fh:
        for line in fh:
            if not line.startswith("[beat]"):
                continue
            _, start, fire, word, chain, length = line.split()
            beats.append(Beat(float(start), float(fire), word, int(chain), int(length)))
    if not beats:
        sys.exit("no beats in %s — was the take recorded?" % path)
    return beats


def pick_window(beats, length, avoid=()):
    """The most eventful `length` seconds of the take.

    Scored on how many words are fired and how high the chains climb, minus a
    heavy penalty for the longest silence inside the window — a stretch with one
    huge hit and three seconds of nothing either side is worse footage than a
    steady patter, and only the gap term expresses that.

    Windows are only ever started on a beat's first keystroke, so the ad opens
    on somebody beginning to type rather than halfway through a word.
    """
    best, best_score = beats[0].start, None
    for anchor in beats:
        w0, w1 = anchor.start, anchor.start + length
        inside = [b for b in beats if b.start >= w0 and b.fire <= w1]
        if len(inside) < 3:
            continue
        if any(b.word in avoid for b in inside):
            continue
        edges = [w0] + [b.fire for b in inside] + [w1]
        max_gap = max(edges[i + 1] - edges[i] for i in range(len(edges) - 1))
        score = 3.0 * len(inside) + sum(b.chain for b in inside) * 0.6 - 9.0 * max_gap
        if best_score is None or score > best_score:
            best, best_score = w0, score
    return best


def shake(beats, amp=20.0, decay=13.0, span=0.30, gain=1.0):
    """Camera kick on every fire, sized by the chain it landed on.

    A decaying sine rather than random jitter: an impact is one impulse that
    rings down, and noise reads as a fault in the encode. `between` keeps each
    term switched off outside its own window, so the expression cost does not
    grow with the length of the clip the way a sum of live sines would.
    """
    xs, ys = [], []
    for b in beats:
        t0 = b.fire
        weight = min(1.0, (b.chain + 3) / 9.0) * gain
        a = amp * weight
        xs.append("%.1f*sin((t-%.3f)*86)*exp(-max(t-%.3f,0)*%.1f)*between(t,%.3f,%.3f)"
                  % (a, t0, t0, decay, t0, t0 + span))
        ys.append("%.1f*cos((t-%.3f)*74)*exp(-max(t-%.3f,0)*%.1f)*between(t,%.3f,%.3f)"
                  % (a * 0.72, t0, t0, decay, t0, t0 + span))
    return ("+".join(xs) or "0"), ("+".join(ys) or "0")


def camera(beats, pad=1.045, **kw):
    """Scale up, then crop a shaking window back down to frame size.

    The headroom is why the scale comes first: a crop that shakes without it
    would run off the edge of the picture and show black slivers on the hardest
    hits.

    `pad` is kept small — 4.5% gives ±24px horizontally and ±43px vertically,
    which is more than the shake ever uses. The first cut ran at 10% because
    more headroom seemed strictly better, and it is not: the pad is a permanent
    zoom as well as a shake budget, and at 10% it cropped the clock and score off
    the top of the frame and the FIRE button off the bottom. An ad for a game
    should not be missing the game's own scoreboard.
    """
    sx, sy = shake(beats, **kw)
    return ("scale=%d:%d:flags=bicubic,crop=%d:%d:x='(iw-ow)/2+(%s)':y='(ih-oh)/2+(%s)'"
            % (int(W * pad) // 2 * 2, int(H * pad) // 2 * 2, W, H, sx, sy))


def chroma_ramp(t0, t1, peak=12, steps=18):
    """A colour-channel split that widens from nothing to `peak` over a stretch.

    Stepped through `sendcmd` rather than written as an expression because
    `rgbashift`'s shifts are declared as ints: they carry the runtime-settable
    flag, so a command can change them mid-clip, but they will not parse an
    expression in `t` the way `crop`'s coordinates will. Eighteen steps over
    eight seconds is a change every 0.45s, which at this magnitude is well under
    what reads as a step.

    Intervals are separated with `;` and each carries a single command. The
    alternative — one interval with comma-separated commands — needs the commas
    escaped past both the filtergraph parser and sendcmd's own, and gets
    misparsed as a target named `0.5` when that is fractionally wrong.
    """
    cmds = []
    for i in range(steps + 1):
        f = i / float(steps)
        at = t0 + (t1 - t0) * f
        h = int(round(peak * f))
        v = int(round(peak * 0.45 * f))
        cmds += ["%.2f rgbashift rh %d" % (at, -h),
                 "%.2f rgbashift bh %d" % (at, h),
                 "%.2f rgbashift rv %d" % (at, v),
                 "%.2f rgbashift bv %d" % (at, -v)]
    # Snap back to clean for the end card, which is the whole point of the joke.
    cmds += ["%.2f rgbashift rh 0" % t1, "%.2f rgbashift bh 0" % t1,
             "%.2f rgbashift rv 0" % t1, "%.2f rgbashift bv 0" % t1]
    return "sendcmd=c='%s',rgbashift" % ";".join(cmds)


HEADER = """[Script Info]
ScriptType: v4.00+
PlayResX: %d
PlayResY: %d
WrapStyle: 2
ScaledBorderAndShadow: yes
YCbCr Matrix: TV.709

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
%s

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
%s
"""


def style(name, font, size, colour, outline_col=DEEP, outline=0, shadow=0,
          bold=0, align=5, spacing=0, scale_x=100):
    return ("Style: %s,%s,%d,%s,%s,%s,&H00000000,%d,0,0,0,%d,100,%.1f,0,1,%.1f,%.1f,%d,30,30,30,1"
            % (name, font, size, ass_c(colour), ass_c(WHITE), ass_c(outline_col),
               bold, scale_x, spacing, outline, shadow, align))


def ev(start, end, style_name, text, layer=5):
    return "Dialogue: %d,%s,%s,%s,,0,0,0,,%s" % (layer, ts(start), ts(end), style_name, text)


def alpha_of(opacity):
    """Opacity 0..1 -> an ASS alpha byte.

    ASS alpha runs backwards — `&H00&` is fully opaque and `&HFF&` is invisible —
    which is the single easiest thing in this format to get wrong, because the
    mistake still renders. The first cut asked for a "subtle" flash at `&H20&`
    and got a frame that was 87% solid gold; every shot in variant C came out
    the colour of a mustard field. Taking opacity and converting here means the
    call sites read in the direction a person thinks in.
    """
    return max(0, min(255, int(round((1.0 - opacity) * 255))))


def flash(t0, colour=WHITE, opacity=0.22, hold=0.05, fall=0.16, layer=1):
    """A full-frame colour wash that decays. Sits under the type on layer 1."""
    return ("Dialogue: %d,%s,%s,FX,,0,0,0,,{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\c%s"
            "\\alpha&H%02X&\\t(%d,%d,\\alpha&HFF&)}%s"
            % (layer, ts(t0), ts(t0 + hold + fall), c_in(colour), alpha_of(opacity),
               int(hold * 1000), int((hold + fall) * 1000), rect(0, 0, W, H)))


def dim(t0, t1, opacity=0.72, fade=0.35, layer=2):
    """Darken the picture under an end card, so type has something to sit on."""
    return ("Dialogue: %d,%s,%s,FX,,0,0,0,,{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\c&H000000&"
            "\\alpha&HFF&\\t(0,%d,\\alpha&H%02X&)}%s"
            % (layer, ts(t0), ts(t1), int(fade * 1000), alpha_of(opacity),
               rect(0, 0, W, H)))


# --------------------------------------------------------------------------
# The five cuts.
#
# Each returns (styles, events, video filter chain, duration). The gameplay is
# already trimmed and shifted to t=0 before these are called, so every time in
# here is a time in the finished ad.
# --------------------------------------------------------------------------

def variant_a(beats, dur, opts):
    """A — "PvP WORD TETRIS". Esports broadcast.

    Condensed caps, hard slams, a flash on every big chain.

    The words called out on each fire are shown one at a time in the middle of
    the board's empty upper half, not stacked down the right-hand margin the way
    a real kill feed would be. Two reasons, and the second is the one that
    settled it: the margin either side of the board is only about 300px wide, so
    a thirteen-letter word set in it has to drop to a size nobody reads on a
    phone — and the right-hand strip is where the platforms put the like and
    share rail, so half of each word would be under a button anyway.
    """
    end = dur - 2.3
    styles = [
        style("Hook", "Barlow Condensed ExtraBold", 168, WHITE, outline=0, align=5),
        style("HookHit", "Barlow Condensed ExtraBold", 196, CYAN, outline=0, align=5),
        style("Feed", "Barlow Condensed ExtraBold", 92, INK, outline=0, align=5, spacing=1),
        style("Chain", "Barlow Semi Condensed Bold", 46, GOLD, outline=0, align=5, spacing=4),
        style("End", "Barlow Condensed ExtraBold", 150, WHITE, outline=0, align=5),
        style("Sub", "Barlow Semi Condensed Bold", 52, CYAN, outline=0, align=5, spacing=2),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    e = []

    # A red wedge that wipes off, so frame one is not simply gameplay. \clip is
    # animated rather than the shape, which keeps the edge hard.
    e.append("Dialogue: 3,%s,%s,FX,,0,0,0,,{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\c%s\\alpha&H%02X&"
             "\\clip(0,0,1080,1920)\\t(0,520,\\clip(0,1920,1080,1920))}%s"
             % (ts(0), ts(0.62), c_in(RED), alpha_of(0.34), rect(0, 0, W, H)))
    e.append(flash(0.0, WHITE, opacity=0.42, hold=0.02, fall=0.20))

    # Hook. Two lines, the second one bigger and cyan, both slamming in from
    # oversize with the blur coming off as they land.
    e.append(ev(0.05, 2.35, "Hook",
                r"{\pos(540,%d)\fscx150\fscy150\blur14\alpha&H40&"
                r"\t(0,190,\fscx100\fscy100\blur0\alpha&H00&)}PvP WORD" % VOID_TOP))
    e.append(ev(0.22, 2.35, "HookHit",
                r"{\pos(540,%d)\fscx60\fscy170\blur18\alpha&H60&"
                r"\t(0,230,0.6,\fscx100\fscy100\blur0\alpha&H00&)"
                r"\t(230,340,\fscx104\fscy96)\t(340,430,\fscx100\fscy100)}TETRIS"
                % (VOID_TOP + 170)))
    e.append(ev(0.05, 2.35, "FX",
                r"{\an7\pos(%d,%d)\p1\bord0\shad0\c" % (SAFE_LEFT + 64, VOID_TOP + 250)
                + c_in(CYAN) +
                r"\alpha&H10&\clip(%d,%d,%d,%d)\t(120,420,\clip(%d,%d,%d,%d))}"
                % (SAFE_LEFT + 64, VOID_TOP + 250, SAFE_LEFT + 64, VOID_TOP + 262,
                   SAFE_LEFT + 64, VOID_TOP + 250, SAFE_RIGHT, VOID_TOP + 262)
                + rect(0, 0, SAFE_RIGHT - SAFE_LEFT - 64, 12)))

    # One word per fire, dead centre of the empty upper board, punched in and
    # gone before the next one. Chains of six or more get the gold treatment and
    # a badge, which is the game's own language for a big hit.
    for b in beats:
        if b.fire < 2.4 or b.fire > end - 0.2:
            continue
        hot = b.chain >= 6
        col = GOLD if hot else INK
        e.append(ev(b.fire - 0.02, min(b.fire + 0.56, end), "Feed",
                    (r"{\pos(540,%d)\c%s\fscx128\fscy128\blur9\alpha&H60&"
                     r"\t(0,110,\fscx100\fscy100\blur0\alpha&H00&)"
                     r"\t(380,560,\alpha&HFF&)}%s")
                    % (VOID_TOP + 120, c_in(col), b.word.upper())))
        if hot:
            e.append(ev(b.fire + 0.04, min(b.fire + 0.56, end), "Chain",
                        (r"{\pos(540,%d)\alpha&HFF&\t(0,120,\alpha&H00&)"
                         r"\t(380,560,\alpha&HFF&)}CHAIN x%d")
                        % (VOID_TOP + 210, b.chain)))
            e.append(flash(b.fire, GOLD, opacity=0.20, hold=0.02, fall=0.18))

    e.append(dim(end, dur))
    e.append(ev(end + 0.08, dur, "End",
                r"{\pos(540,860)\fscx130\fscy130\blur10\alpha&H50&"
                r"\t(0,200,\fscx100\fscy100\blur0\alpha&H00&)}WORD WARS"))
    e.append(ev(end + 0.30, dur, "Sub",
                r"{\pos(540,1000)\alpha&HFF&\t(0,220,\alpha&H00&)}FREE ON THE APP STORE"))

    vf = (camera(beats, amp=22.0, gain=1.0) +
          ",eq=contrast=1.16:saturation=1.30:gamma=0.97,vignette=a=PI/4.5")
    return styles, e, vf, dur


def variant_b(beats, dur, opts):
    """B — "Your words attack your opponent". Clean explainer.

    The only one of the five that has to teach something, so it is the only one
    with no shake worth the name: the reader is being asked to follow a rule,
    and a moving frame makes that harder. The mechanic is shown with the
    README's own example, because FRIENDSHIP -> SHIP is the clearest sentence
    anybody has written about this game.
    """
    end = dur - 2.3
    styles = [
        style("Big", "Barlow Condensed Black", 128, WHITE, outline=0, align=5),
        style("Hit", "Barlow Condensed Black", 146, CYAN, outline=0, align=5),
        # 62, not 74. At 74 the longest rule line measured 995px wide, which puts
        # its last word past SAFE_RIGHT and under the share button — and over the
        # game's own SENT rail, so it covered the very thing the sentence is
        # about. The copy below was cut down to match.
        style("Rule", "Barlow Condensed Black", 62, WHITE, outline=0, align=5),
        style("RuleSm", "Barlow Semi Condensed Medium", 46, INK, outline=0, align=5, bold=-1),
        style("Chip", "Barlow Condensed Black", 66, DEEP, outline=0, align=5, spacing=2),
        style("End", "Barlow Condensed Black", 132, WHITE, outline=0, align=5),
        style("Sub", "Barlow Semi Condensed Medium", 52, CYAN, outline=0, align=5, bold=-1, spacing=1),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    e = []

    # Kinetic hook: three phrases swapping in one place, each pushing the last
    # out. Scale and blur only — no rotation, nothing thrown around.
    def swap(t0, t1, st, text, y=VOID_TOP + 110):
        return ev(t0, t1, st,
                  (r"{\pos(540,%d)\fscy120\fscx120\blur12\alpha&H30&"
                   r"\t(0,170,\fscx100\fscy100\blur0\alpha&H00&)"
                   r"\t(%d,%d,\alpha&HFF&\blur8)}%s")
                  % (y, int((t1 - t0) * 1000) - 160, int((t1 - t0) * 1000), text))

    e.append(swap(0.05, 1.05, "Big", "YOUR WORDS"))
    e.append(swap(1.05, 2.05, "Hit", "ATTACK"))
    e.append(swap(2.05, 3.15, "Big", "YOUR OPPONENT"))

    # The rule, spelled out over the middle of the clip. Two lines, the second
    # arriving a beat after the first so it reads as consequence rather than a
    # block of text.
    e.append(ev(3.35, 6.5, "Rule",
                r"{\pos(540,470)\alpha&HFF&\t(0,200,\alpha&H00&)}You type {\c"
                + c_in(CYAN) + r"}FRIENDSHIP"))
    e.append(ev(3.95, 6.5, "Rule",
                r"{\pos(540,566)\alpha&HFF&\t(0,200,\alpha&H00&)}They get {\c"
                + c_in(PINK) + r"}SHIP"))
    e.append(ev(4.75, 6.5, "RuleSm",
                r"{\pos(540,678)\alpha&HFF&\t(0,240,\alpha&H00&)}"
                r"now they need a word\Nthat {\c" + c_in(GOLD) + r"}starts{\c"
                + c_in(INK) + r"} with it"))

    # An arrow from the player's board up to the rival's chip, drawn once on a
    # real beat so the geometry matches what is happening underneath.
    arrow_at = next((b.fire for b in beats if b.fire > 6.6), 6.8)
    # Coordinates are all positive and the drawing is placed by its top-left with
    # \an7, so the arrow spans x 496-584 — centred on 540 — and y 300-510. A
    # drawing with negative coordinates is placed by its bounding box instead,
    # which silently shifts it off centre by half its own width.
    e.append("Dialogue: 4,%s,%s,FX,,0,0,0,,{\\an7\\pos(496,300)\\p1\\bord0\\shad0\\c%s"
             "\\alpha&HFF&\\t(0,180,\\alpha&H20&)\\t(600,900,\\alpha&HFF&)}"
             "m 44 0 l 88 70 l 58 70 l 58 210 l 30 210 l 30 70 l 0 70"
             % (ts(arrow_at - 0.25), ts(arrow_at + 0.9), c_in(GOLD)))
    e.append(ev(arrow_at - 0.2, arrow_at + 0.9, "Chip",
                r"{\pos(540,1200)\c" + c_in(INK) +
                r"\alpha&HFF&\t(0,180,\alpha&H00&)\t(600,900,\alpha&HFF&)}"
                r"every word lands on their board"))

    e.append(dim(end, dur))
    e.append(ev(end + 0.08, dur, "End",
                r"{\pos(540,860)\fscx118\fscy118\blur8\alpha&H50&"
                r"\t(0,220,\fscx100\fscy100\blur0\alpha&H00&)}WORD WARS"))
    e.append(ev(end + 0.32, dur, "Sub",
                r"{\pos(540,990)\alpha&HFF&\t(0,240,\alpha&H00&)}Free on the App Store"))

    vf = (camera(beats, amp=8.0, gain=0.5, pad=1.05) +
          ",eq=contrast=1.06:saturation=1.12:brightness=0.015")
    return styles, e, vf, dur


def variant_c(beats, dur, opts):
    """C — "Can you beat my score?". Challenge card.

    Monospace, because the whole register is a scoreboard. The number on the end
    card is the game's own final score, read off the last frame and passed in
    with --score; nothing here invents one. If it is not supplied the card falls
    back to pointing at the score the HUD is already drawing, which is true
    whatever the run did.
    """
    end = dur - 2.6
    styles = [
        style("Mono", "JetBrainsMono Nerd Font", 96, GOLD, outline=0, align=5, bold=-1, spacing=2),
        style("MonoSm", "JetBrainsMono Nerd Font", 46, INK, outline=0, align=5, bold=-1, spacing=1),
        style("Num", "JetBrainsMono Nerd Font", 210, GOLD, outline=0, align=5, bold=-1),
        style("End", "JetBrainsMono Nerd Font", 88, WHITE, outline=0, align=5, bold=-1, spacing=3),
        # 36, not 40: at 40 a thirteen-letter word runs 360px from the left
        # margin and laps onto the board, which starts at x 310.
        style("Tick", "JetBrainsMono Nerd Font", 36, CYAN, outline=0, align=4, bold=-1),
        style("FX", "JetBrainsMono Nerd Font", 40, WHITE),
    ]
    e = []

    e.append(ev(0.05, 2.4, "Mono",
                r"{\pos(540,%d)\alpha&HFF&\fsp30\t(0,260,\alpha&H00&\fsp2)}CAN YOU BEAT"
                % (VOID_TOP + 60)))
    e.append(ev(0.45, 2.4, "Mono",
                r"{\pos(540,%d)\c" % (VOID_TOP + 190) + c_in(WHITE) +
                r"\alpha&HFF&\fsp30\t(0,260,\alpha&H00&\fsp2)}MY SCORE?"))
    e.append("Dialogue: 4,%s,%s,FX,,0,0,0,,{\\an7\\pos(150,%d)\\p1\\bord0\\shad0\\c%s"
             "\\alpha&H20&\\clip(150,%d,150,%d)\\t(0,380,\\clip(150,%d,930,%d))}%s"
             % (ts(0.55), ts(2.4), VOID_TOP + 250, c_in(GOLD),
                VOID_TOP + 250, VOID_TOP + 260, VOID_TOP + 250, VOID_TOP + 260,
                rect(0, 0, 780, 10)))

    # A running log down the left margin — every word banked, terminal style.
    for i, b in enumerate(beats):
        if b.fire < 2.5 or b.fire > end - 0.2:
            continue
        y = 520 + (i % 6) * 74
        e.append(ev(b.fire, min(b.fire + 1.4, end), "Tick",
                    (r"{\pos(46,%d)\alpha&HFF&\t(0,110,\alpha&H00&)"
                     r"\t(1100,1400,\alpha&HFF&)\c%s}+ %s")
                    % (y, c_in(GOLD if b.chain >= 6 else CYAN), b.word.lower())))
        if b.chain >= 6:
            e.append(flash(b.fire, GOLD, opacity=0.20, hold=0.02, fall=0.14))

    e.append(dim(end, dur, opacity=0.78, fade=0.25))
    score = opts.get("score")
    if score:
        e.append(ev(end + 0.05, dur, "MonoSm", r"{\pos(540,700)\alpha&HFF&\t(0,200,\alpha&H00&)}MY SCORE"))
        e.append(ev(end + 0.15, dur, "Num",
                    (r"{\pos(540,880)\fscx135\fscy135\blur12\alpha&H60&"
                     r"\t(0,200,\fscx100\fscy100\blur0\alpha&H00&)}%s") % score))
    else:
        e.append(ev(end + 0.05, dur, "MonoSm",
                    r"{\pos(540,760)\alpha&HFF&\t(0,200,\alpha&H00&)}THAT NUMBER UP THERE"))
    e.append(ev(end + 0.55, dur, "End",
                r"{\pos(540,1080)\alpha&HFF&\t(0,240,\alpha&H00&)}YOUR TURN."))
    e.append(ev(end + 0.85, dur, "MonoSm",
                r"{\pos(540,1200)\c" + c_in(CYAN) +
                r"\alpha&HFF&\t(0,240,\alpha&H00&)}WORD WARS  //  FREE ON iOS"))

    # The picture freezes when the end card arrives.
    #
    # Not for style — for consistency. The card quotes a number, the game's own
    # HUD is drawing that number at the top of the same frame, and if the match
    # keeps running underneath then the two disagree for the whole card: the
    # first pass said 26,297 over a HUD that still read 23,546 and was climbing.
    # Freezing on the last live frame makes the quoted score the score on
    # screen, which is the only version of this card that survives being paused.
    #
    # The shake is fed only the beats before the freeze, since a frozen frame
    # that jolts reads as a dropped frame rather than an impact. Audio is left
    # running — the room does not have to go silent for the picture to stop.
    live = [b for b in beats if b.fire < end]
    vf = ("trim=0:%.3f,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=%.3f,"
          % (end, dur - end)
          + camera(live, amp=14.0, gain=0.75)
          + ",eq=contrast=1.14:saturation=1.05:gamma=0.96,vignette=a=PI/4")
    return styles, e, vf, dur


def variant_d(beats, dur, opts):
    """D — "This got out of hand". The picture falls apart.

    Set in the game's own display face; the chroma split, grain and shake do
    the breaking, so the letters themselves stay the brand.

    The structure is the joke: it opens quiet and lowercase, degrades for eight
    seconds, then stops dead and the end card is completely composed. Chroma
    split, grain and shake all ramp on `t` rather than stepping per beat, so the
    escalation is felt before it is noticed.
    """
    cut = dur - 2.2
    styles = [
        style("Calm", "Barlow Semi Condensed Medium", 68, INK, outline=0, align=5, bold=-1),
        style("Glitch", "Barlow Condensed Black", 150, PINK, outline=0, align=5),
        style("Word", "Barlow Condensed Black", 76, CYAN, outline=0, align=5),
        style("End", "Barlow Condensed Black", 128, WHITE, outline=0, align=5),
        style("Sub", "Barlow Semi Condensed Medium", 50, INK, outline=0, align=5, bold=-1),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    e = []

    # Both lines inside the board's empty upper half. At 660/800 they sat on top
    # of the blocks, which is the one thing a gameplay ad cannot cover.
    e.append(ev(0.1, 1.5, "Calm",
                r"{\pos(540,%d)\alpha&HFF&\t(0,260,\alpha&H00&)}this got" % (VOID_TOP + 70)))
    e.append(ev(1.05, 3.0, "Glitch",
                r"{\pos(540,%d)\fscx40\fscy160\blur20\alpha&H70&"
                r"\t(0,180,\fscx100\fscy100\blur0\alpha&H00&)"
                r"\t(180,300,\frz2)\t(300,420,\frz-2)\t(420,520,\frz0)}OUT OF HAND"
                % (VOID_TOP + 190)))
    e.append(flash(1.05, PINK, opacity=0.30, hold=0.02, fall=0.22))

    # Words thrown on at increasing angles as it comes apart.
    for i, b in enumerate(beats):
        if b.fire < 3.1 or b.fire > cut - 0.2:
            continue
        chaos = min(1.0, (b.fire - 3.0) / max(cut - 3.0, 0.1))
        rot = (7.0 if i % 2 else -7.0) * chaos
        # Kept to ±60 so a thirteen-letter word set at 76px still lands inside
        # SAFE_RIGHT once it has been thrown off centre.
        x = 540 + (60 if i % 3 == 0 else -50 if i % 3 == 1 else 8) * chaos
        y = 470 + (i % 4) * 60
        e.append(ev(b.fire, min(b.fire + 0.62, cut), "Word",
                    (r"{\pos(%d,%d)\frz%.1f\fscx%d\fscy%d\blur%.1f\alpha&H30&"
                     r"\t(0,90,\alpha&H00&)\t(380,620,\alpha&HFF&)}%s")
                    % (x, y, rot, 100 + int(18 * chaos), 100 + int(18 * chaos),
                       2.0 * chaos, b.word.upper())))
        if b.chain >= 5:
            e.append(flash(b.fire, WHITE, opacity=0.22, hold=0.01, fall=0.12))

    # Everything stops. A hard black hold, then the end card arrives sober.
    e.append("Dialogue: 2,%s,%s,FX,,0,0,0,,{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\c&H000000&"
             "\\alpha&H10&}%s" % (ts(cut), ts(dur), rect(0, 0, W, H)))
    e.append(ev(cut + 0.25, dur, "End", r"{\pos(540,880)\alpha&HFF&\t(0,260,\alpha&H00&)}WORD WARS"))
    e.append(ev(cut + 0.55, dur, "Sub",
                r"{\pos(540,1000)\c" + c_in(CYAN) +
                r"\alpha&HFF&\t(0,260,\alpha&H00&)}it's a spelling game. allegedly."))

    # `brightness` is doing real work here rather than taste. The game is drawn
    # almost entirely in near-blacks, and contrast above 1 pivots around mid grey
    # — so on this picture it darkens far more than it brightens, and the first
    # pass came out with an unreadable keyboard and a board you had to hunt for.
    # The lift puts it back where the other four sit.
    vf = (camera(beats, amp=30.0, gain=1.25, pad=1.09) +
          "," + chroma_ramp(3.0, cut, peak=10) +
          ",noise=alls=9:allf=t+u" +
          ",eq=contrast=1.18:saturation=1.35:brightness=0.10,vignette=a=PI/3.8")
    return styles, e, vf, dur


def variant_e(beats, dur, opts):
    """E — "I made a game for people who are annoyingly good at spelling".

    The control. No shake, no flashes, no grade to speak of — a plain caption
    box of the kind the platforms put on a post themselves, over footage left
    alone. It is in the test because a founder saying a true sentence over
    unedited gameplay routinely beats a produced ad, and if it wins here that is
    worth knowing before any more effort goes into the other four.
    """
    end = dur - 2.4
    styles = [
        style("Post", "Barlow Semi Condensed Medium", 62, WHITE, outline=0, align=8, bold=-1),
        style("Note", "Barlow Semi Condensed Medium", 54, WHITE, outline=0, align=5, bold=-1),
        style("End", "Barlow Condensed Black", 104, WHITE, outline=0, align=5),
        style("Sub", "Barlow Semi Condensed Medium", 46, INK, outline=0, align=5, bold=-1),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    e = []

    # The caption slab, sized to the lines it actually holds.
    #
    # Three lines rather than two. Set over two, the first line runs to about
    # 900px — wider than the slab has room for once it is padded, so it either
    # touched both edges or had to drop to a size that stops looking like a
    # caption somebody typed. Three shorter lines is also simply how this gets
    # written on the platform it is imitating.
    e.append("Dialogue: 3,%s,%s,FX,,0,0,0,,{\\an7\\pos(58,296)\\p1\\bord0\\shad0\\c&H000000&"
             "\\alpha&H4A&}%s" % (ts(0.0), ts(5.4), rect(0, 0, 964, 246)))
    e.append(ev(0.0, 5.4, "Post",
                r"{\pos(540,326)}i made a game for people\Nwho are {\c"
                + c_in(CYAN) + r"}annoyingly good\Nat spelling"))

    # Text centred on the slab, not 30px above it: the slab runs 296-428 and
    # \an5 centres on the position given, so this has to be the slab's middle.
    e.append("Dialogue: 3,%s,%s,FX,,0,0,0,,{\\an7\\pos(140,296)\\p1\\bord0\\shad0\\c&H000000&"
             "\\alpha&H4A&}%s" % (ts(5.6), ts(end), rect(0, 0, 800, 132)))
    e.append(ev(5.6, end, "Note",
                r"{\pos(540,362)\alpha&HFF&\t(0,220,\alpha&H00&)}"
                r"your words become their problem"))

    e.append(dim(end, dur, opacity=0.75, fade=0.3))
    e.append(ev(end + 0.1, dur, "End",
                r"{\pos(540,880)\alpha&HFF&\t(0,240,\alpha&H00&)}Word Wars"))
    e.append(ev(end + 0.35, dur, "Sub",
                r"{\pos(540,990)\c" + c_in(CYAN) +
                r"\alpha&HFF&\t(0,240,\alpha&H00&)}free on the App Store"))

    # Nothing at all. This was briefly a 3% scale-and-crop meant to read as a
    # slow push, which it cannot: a constant zoom is not a move, it is just a
    # crop, and all it did was throw away the edges of the frame and resample
    # every pixel for no visible result. The control variant is more useful if
    # it is actually a control.
    vf = "null"
    return styles, e, vf, dur


# builder, runtime, filename slug, and which take it is cut from.
#
# One take per variant. Five ads cut from one recording show the same board
# playing the same words five times, which is fine while each is watched alone
# and looks like a bug the moment two of them appear in the same feed — and
# putting all five in front of the same audience is the entire point of running
# a variant test. Seeds are cheap; footage that cannot be told apart is not.
def variant_f(beats, dur, opts):
    """F — the download ad. Not a hook test.

    A to E exist to find out which *register* works and are deliberately five
    different treatments of the same footage. F is the other job: it assumes the
    question has been asked and just tries to convert. That makes it the only cut
    in here with a shape rather than an angle — category, mechanic, payoff, call
    to action, in that order, because that is the order somebody decides in.

    ## Three things it does differently, all of them for installs

    **It says what the game is inside two seconds.** "WORD GAME" is a dull first
    line and it is deliberate: install intent needs a category before it needs a
    personality. A viewer who has not worked out what they are looking at by the
    second second is not going to, and D's approach — vibe first, explanation
    never — is a watch-rate strategy rather than an install one.

    **The CTA gets 3.3 seconds, not 2.3.** The other four end cards are a sign-off
    on a test; this one is the ask. Two seconds is enough to read a name and not
    enough to decide to act on it, and the end of the video is where the platform
    puts its own Download button — so the card is holding attention for a control
    that lives outside the frame.

    **It is cut from human-paced footage.** `tools/adreel.sh --human`, and this is
    the part that matters most. The machine picker types 55wpm and takes the
    longest word on the board every turn, which reads to a stranger as a game
    they would be bad at. An ad whose job is a download cannot afford that: the
    viewer is being asked to picture themselves playing, and they will not
    picture themselves doing something that looks impossible. Human footage is
    slower, the board stays fuller, and the offer it makes is one the install
    actually keeps.
    """
    # Longer tail than the other four. See the docstring.
    end = dur - 3.3
    styles = [
        style("Hook", "Barlow Condensed ExtraBold", 172, WHITE, outline=0, align=5),
        style("HookHit", "Barlow Condensed ExtraBold", 172, CYAN, outline=0, align=5),
        style("Rule", "Barlow Condensed Black", 72, WHITE, outline=0, align=5),
        style("RuleHit", "Barlow Condensed Black", 72, PINK, outline=0, align=5),
        style("Chain", "Barlow Condensed ExtraBold", 118, GOLD, outline=0, align=5, spacing=2),
        style("End", "Barlow Condensed Black", 142, WHITE, outline=0, align=5),
        style("Sub", "Barlow Condensed Black", 58, CYAN, outline=0, align=5, spacing=1),
        style("Tag", "Barlow Semi Condensed Medium", 44, INK, outline=0, align=5, bold=-1),
        style("FX", "Barlow Semi Condensed Medium", 40, WHITE),
    ]
    e = []

    # Frame one is not plain gameplay, but it is not A's red wedge either — a
    # single cyan sweep off the top, because the register here is confident
    # rather than loud and a scroll-stopper that promises chaos mis-sells a game
    # whose actual pleasure is being good at it.
    e.append("Dialogue: 3,%s,%s,FX,,0,0,0,,{\\an7\\pos(0,0)\\p1\\bord0\\shad0\\c%s\\alpha&H%02X&"
             "\\clip(0,0,1080,1920)\\t(0,420,\\clip(0,0,1080,0))}%s"
             % (ts(0), ts(0.5), c_in(CYAN), alpha_of(0.30), rect(0, 0, W, H)))

    # The category, then the turn. Both lines stay up together — they are one
    # sentence and the second half is the half that sells, so it is not allowed
    # to arrive after the first has gone.
    e.append(ev(0.05, 2.30, "Hook",
                r"{\pos(540,%d)\fscx140\fscy140\blur12\alpha&H40&"
                r"\t(0,180,\fscx100\fscy100\blur0\alpha&H00&)"
                r"\t(2050,2300,\alpha&HFF&)}WORD GAME" % VOID_TOP))
    e.append(ev(0.40, 2.30, "HookHit",
                r"{\pos(540,%d)\fscx70\fscy150\blur16\alpha&H60&"
                r"\t(0,220,\fscx100\fscy100\blur0\alpha&H00&)"
                r"\t(220,330,\fscx103\fscy97)\t(330,420,\fscx100\fscy100)"
                r"\t(1650,1900,\alpha&HFF&)}THAT HITS BACK" % (VOID_TOP + 168)))

    # The mechanic, in one sentence with a turn in it, hung on a real fire so the
    # words land while the SENT rail underneath them is actually filling.
    #
    # `next` with a default rather than an index: a window is chosen for beat
    # density, not for having a beat at a particular second, and an ad that
    # crashes because the footage was quiet at 2.7s would be a cutter that only
    # works on the take it was written against.
    rule_at = next((b.fire for b in beats if b.fire > 2.75), 3.0)
    e.append(ev(rule_at - 0.15, rule_at + 3.1, "Rule",
                r"{\pos(540,%d)\alpha&HFF&\t(0,200,\alpha&H00&)"
                r"\t(2700,3100,\alpha&HFF&)}ONE WORD CLEARS YOURS" % (VOID_TOP + 60)))
    e.append(ev(rule_at + 0.55, rule_at + 3.1, "RuleHit",
                r"{\pos(540,%d)\alpha&HFF&\t(0,200,\alpha&H00&)"
                r"\t(2150,2550,\alpha&HFF&)}AND FILLS THEIRS" % (VOID_TOP + 150)))
    e.append(ev(rule_at + 1.15, rule_at + 3.1, "Tag",
                r"{\pos(540,%d)\alpha&HFF&\t(0,240,\alpha&H00&)"
                r"\t(1550,1950,\alpha&HFF&)}the letters you leave behind"
                r"\Nbecome their next problem" % (VOID_TOP + 250)))

    # The payoff. One callout on the best hit left in the window, because a
    # single gold moment reads as a highlight and four of them read as a screen
    # that is always shouting.
    #
    # The fallback is not defensive padding — it is the difference between an ad
    # with a payoff and one without. Human footage fires a word about every 2.7
    # seconds, so the gap between the rule clearing and the end card starting
    # holds two beats at best and sometimes one; the first cut of this variant
    # found its best hit 0.29s past the cutoff, dropped the callout entirely, and
    # produced a perfectly clean video with no high point in it. Nothing in the
    # output said so.
    rule_end = rule_at + 3.15
    late = [b for b in beats if rule_end < b.fire < end - 0.25]
    if not late:
        late = [b for b in beats if 2.4 < b.fire < end - 0.25]
    if late:
        top = max(late, key=lambda b: b.chain)
        e.append(ev(top.fire - 0.02, min(top.fire + 1.15, end), "Chain",
                    (r"{\pos(540,%d)\fscx124\fscy124\blur10\alpha&H60&"
                     r"\t(0,130,\fscx100\fscy100\blur0\alpha&H00&)"
                     r"\t(850,1150,\alpha&HFF&)}CHAIN x%d")
                    % (VOID_TOP + 90, top.chain)))
        e.append(ev(top.fire + 0.16, min(top.fire + 1.15, end), "Tag",
                    (r"{\pos(540,%d)\alpha&HFF&\t(0,180,\alpha&H00&)"
                     r"\t(800,1100,\alpha&HFF&)}keep firing and it keeps climbing")
                    % (VOID_TOP + 190)))
        e.append(flash(top.fire, GOLD, opacity=0.18, hold=0.02, fall=0.20))

    # The ask.
    e.append(dim(end, dur, opacity=0.80))
    e.append(ev(end + 0.10, dur, "End",
                r"{\pos(540,840)\fscx124\fscy124\blur9\alpha&H50&"
                r"\t(0,210,\fscx100\fscy100\blur0\alpha&H00&)}WORD WARS"))
    e.append(ev(end + 0.34, dur, "Sub",
                r"{\pos(540,968)\alpha&HFF&\t(0,230,\alpha&H00&)}FREE ON THE APP STORE"))
    # Two true things rather than one snappy one.
    #
    # This line read "one match takes 75 seconds" until it was checked against
    # the source. `DAILY_SECONDS` is 75, but that is the *daily*, and what is on
    # screen behind this card is a versus match — which runs until somebody is
    # out of lives and has no fixed length at all. A timing claim measured off a
    # mode the ad never shows is the kind of thing nobody would catch until an
    # install did, so it names both modes and times only the one that is timed.
    e.append(ev(end + 0.62, dur, "Tag",
                r"{\pos(540,1060)\alpha&HFF&\t(0,260,\alpha&H00&)}"
                r"75-second daily  \h·\h  or play someone live"))

    # Lighter than A and heavier than B. The hits should land, but this cut is
    # asking to be trusted and a frame that will not sit still undercuts that.
    vf = (camera(beats, amp=13.0, gain=0.7, pad=1.05) +
          ",eq=contrast=1.10:saturation=1.20:brightness=0.012")
    return styles, e, vf, dur


VARIANTS = {
    "A": (variant_a, 11.0, "pvp-word-tetris", "take-11"),
    "B": (variant_b, 11.5, "words-attack", "take-23"),
    "C": (variant_c, 10.5, "beat-my-score", "take-47"),
    "D": (variant_d, 10.5, "out-of-hand", "take-5"),
    "E": (variant_e, 11.5, "annoyingly-good", "take-71"),
    # The odd one out, and the default take says so: F is the only variant cut
    # from `--human` footage, and pointing it at one of the machine takes would
    # silently undo the thing it exists to do. See `variant_f`.
    # 14.5s rather than the 11-ish the hook tests run at, and the extra is not
    # padding either. Human footage fires about every 2.7 seconds, so the four
    # movements — hook, rule, payoff, ask — need roughly four beats to hang on,
    # and at 13.0 the payoff had nowhere to land between the rule clearing and
    # the end card starting. Still inside the 9-15s band these platforms reward.
    "F": (variant_f, 14.5, "download", "take-h31"),
}


def build(letter, take, out, opts):
    fn, dur, slug, _ = VARIANTS[letter]
    beats = load_beats(take + ".beats")

    # The gameplay the ad actually uses. Everything after the end card starts is
    # still gameplay underneath, so the window has to cover the whole runtime.
    w0 = pick_window(beats, dur, avoid=opts.get("avoid", ()))
    local = [b.shifted(w0) for b in beats if b.fire >= w0 and b.fire <= w0 + dur]

    styles, events, vf, dur = fn(local, dur, opts)
    ass_path = os.path.join(os.path.dirname(out), ".%s.ass" % slug)
    with open(ass_path, "w") as fh:
        fh.write(HEADER % (W, H, "\n".join(styles), "\n".join(events)))

    # The subtitles filter goes last so the type is never shaken, split or
    # graded with the picture — captions that wobble with the camera read as a
    # mistake rather than an effect.
    #
    # Then bt709 limited range, tagged, because that is what every social
    # uploader assumes it is being handed. `out_range` is set without `in_range`
    # on purpose: scale reads the incoming range off the stream, so this both
    # fixes the older full-range takes and stays a no-op on takes recorded since
    # adreel.sh started tagging them correctly. Pinning `in_range=full` would
    # have quietly compressed the new ones a second time.
    chain = ("%s,subtitles=%s:fontsdir=fonts,"
             "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p"
             % (vf, ass_path))
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-ss", "%.3f" % w0, "-t", "%.3f" % dur, "-i", take + ".mp4",
        "-filter_complex", "[0:v]%s[v];[0:a]atrim=0:%.3f,asetpts=PTS-STARTPTS,"
                           "loudnorm=I=-14:TP=-1.5:LRA=11[a]" % (chain, dur),
        "-map", "[v]", "-map", "[a]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "19", "-pix_fmt", "yuv420p",
        "-profile:v", "high", "-level", "4.0", "-r", str(FPS),
        "-colorspace", "bt709", "-color_primaries", "bt709",
        "-color_trc", "bt709", "-color_range", "tv",
        "-c:a", "aac", "-b:a", "160k", "-ar", "48000",
        "-movflags", "+faststart",
        out,
    ]
    print("--- %s (%s)  window %.2fs  %d beats" % (letter, slug, w0, len(local)))
    subprocess.run(cmd, check=True)
    print("    %s" % out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("variant", help="A-F, or 'all'")
    ap.add_argument("--take", default=None,
                    help="override the take this variant is cut from")
    ap.add_argument("--raw-dir", default="build/ads/raw")
    ap.add_argument("--out-dir", default="build/ads")
    ap.add_argument("--score", default=None, help="C only: the real final score, read off the take")
    ap.add_argument("--avoid", default="",
                    help="comma-separated words whose window this cut should skip. "
                         "The recorder already refuses profanity and an editorial "
                         "list (see NOT_IN_AN_AD in tools/adreel.gd); this is for "
                         "the rarer case of a word that is fine in general and "
                         "wrong beside this particular hook, where re-recording "
                         "the whole take would be a heavy way to move six seconds.")
    args = ap.parse_args()

    if not shutil.which("ffmpeg"):
        sys.exit("ffmpeg not on PATH")
    os.makedirs(args.out_dir, exist_ok=True)
    opts = {"score": args.score,
            "avoid": tuple(w.strip().lower() for w in args.avoid.split(",") if w.strip())}

    letters = sorted(VARIANTS) if args.variant == "all" else [args.variant.upper()]
    for letter in letters:
        if letter not in VARIANTS:
            sys.exit("no variant %r — expected one of %s or 'all'"
                     % (letter, ", ".join(sorted(VARIANTS))))
        slug, default_take = VARIANTS[letter][2], VARIANTS[letter][3]
        take = args.take or os.path.join(args.raw_dir, default_take)
        if not os.path.exists(take + ".mp4"):
            sys.exit("no footage at %s.mp4 — record it with:\n"
                     "    tools/adreel.sh --seed N --seconds 20 --out %s" % (take, take))
        build(letter, take, os.path.join(args.out_dir, "%s-%s.mp4" % (letter, slug)), opts)


if __name__ == "__main__":
    main()
