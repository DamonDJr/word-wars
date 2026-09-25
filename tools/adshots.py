#!/usr/bin/env python3
"""TikTok image ads, composed over frames of a real self-played match.

    tools/adshots.py                    # every hook, every placement
    tools/adshots.py --hook hits-back   # just one

Writes build/ads/images/<hook>-<placement>.png.

## What these are for

TikTok's feed is video, so these are not feed ads. They are what Ads Manager
asks for once a campaign exists: the Pangle and Global App Bundle placements
that serve a still, and the cover frame a video ad is browsed by. Those want
three shapes, so every hook is rendered in all three rather than one being
picked now and the other two being needed at three in the morning.

The hooks are the download angle, not the A-to-E hook test — `hits-back` is the
same line variant F opens on, because an image and a video running in the same
campaign should look like the same campaign.

## The frames are frames, not mockups

Every image is built on a real frame lifted out of `build/ads/raw/take-h31.mp4`,
which is the human-paced take variant F is cut from. Same reasoning as the video
tools: a still that shows a board the build cannot produce is the one kind of ad
that is actually dishonest, and a composite of hand-placed blocks would be
exactly that. The script pulls its own frames with ffmpeg so the timestamps in
`ADS` are the record of which moment each one is.

It also means the boards here are boards a person at 36wpm actually reached. See
`docs/social-ads.md` on why that matters more for an install ad than it looks.

## Two layouts, because one does not fit three shapes

`full` is the frame itself, edge to edge, scrimmed top and bottom so type has
somewhere to sit. It only works at 9:16 — which is the take's own shape — and it
is the one that looks native rather than like an ad.

`device` puts the whole phone on the game's own menu furniture, because the
square and landscape slots cannot show a 9:16 frame at any useful size without
either cropping the board off or shrinking it to a stripe. Losing the shape of
the phone is worse: these run beside an install button and the shape is half of
what says what is being installed.

## On the third copy of `ground` and `decor`

`caption-shots.py` and `challenge-banners.py` each carry their own, sized to
their own canvas. This is the third, and the only difference here is that it
takes the canvas as an argument instead of reading a module global — which is
what the other two would need to become if anybody ever wants one of these.
Shared as an argument rather than factored into a fourth file, because three
callers is not yet a library and the two existing ones are working.
"""

import argparse
import os
import random
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

TAKE = "build/ads/raw/take-h31.mp4"
OUT = "build/ads/images"
WORK = "build/ads/images/.frames"

# The same family the video ads are set in. Files rather than family names,
# because PIL resolves neither — and `Inter.ttc` is a collection whose Black
# face needs an index nobody would remember, so the CTA uses Barlow too.
HOOK_F = "fonts/BarlowCondensed-ExtraBold.ttf"
NAME_F = "fonts/BarlowCondensed-ExtraBold.ttf"
BODY_B = "fonts/BarlowSemiCondensed-Bold.ttf"
BODY_R = "fonts/BarlowSemiCondensed-Medium.ttf"

# Straight out of the game: THEMES/midnight, the boot splash, and TIER_COLORS.
BG_TOP, BG_BOT = (1, 6, 26), (20, 26, 54)
TIERS = ["#5390d9", "#48bfe3", "#64dfdf", "#f9c74f", "#f8961e", "#f94144"]
INK, MUTE = (230, 236, 255), (125, 136, 173)
CYAN = "#7bdff2"   # PLAYER_ACCENT
GOLD = "#ffd166"
PINK = "#ff8fa3"   # AI_ACCENT

# Placement -> canvas and layout.
#
# 1080x1920 rather than the 720x1280 minimum, and 1080 square rather than 640,
# because every one of these is downscaled by somebody else's pipeline and
# handing it more to work with costs nothing here.
# `4x5` and the bump to 1200 square are Google's asks rather than TikTok's.
# Google App campaigns want 1200x1500 portrait, 1200x1200 square and 1200x628
# landscape; TikTok wanted 1080 square and did not want 4:5 at all. Rendering
# the superset costs one more pass and means one folder answers both networks,
# which is worth more than the two files it saves to keep them separate.
PLACEMENTS = {
    "9x16": ((1080, 1920), "full"),
    "4x5": ((1200, 1500), "full"),
    "1x1": ((1200, 1200), "device"),
    "16x9": ((1200, 628), "device"),
}

# The ads. Each is a moment in the take, an accent, a headline and the line
# under it.
#
# `at` is a timestamp in `TAKE`, and every one of them was chosen by looking at
# it. 11.25 is a detonation caught mid-burst with "13 incoming" on the rival's
# chip, which is the only single frame in the take that shows both halves of the
# game at once — what a word does to your board and what it does to theirs.
ADS = [
    ("hits-back", 11.25, CYAN,
     ["WORD GAME", "THAT HITS BACK"],
     "The letters you leave behind become their next problem."),
    ("endings", 4.73, GOLD,
     ["YOUR ENDINGS", "BECOME THEIR", "BEGINNINGS"],
     "Clear your board by filling theirs. One word does both."),
    ("incoming", 19.90, PINK,
     ["EVERY WORD", "LANDS ON", "THEIR BOARD"],
     "They have to answer what you leave them. So do you."),
]

CTA_NAME = "WORD WARS"
CTA_SUB = "Free on the App Store"


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def ground(size, accent):
    """Vertical gradient plus a bloom behind where the phone will sit."""
    w, h = size
    im = Image.new("RGB", size, BG_TOP)
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(
            int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)))
    glow = Image.new("RGB", size, (0, 0, 0))
    g = ImageDraw.Draw(glow)
    cx, cy = int(w * 0.72), int(h * 0.52)
    for i in range(9):
        f = i / 8.0
        r = int(max(w, h) * (0.14 + f * 0.46))
        v = int(30 * (1.0 - f))
        g.ellipse([cx - r, cy - r, cx + r, cy + r],
                  fill=tuple(int(c * v / 255) for c in accent))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    return Image.fromarray(np.clip(
        np.asarray(im, dtype=int) + np.asarray(glow, dtype=int),
        0, 255).astype("uint8"))


def decor(im, seed):
    """The drifting blocks behind every menu. Low contrast on purpose."""
    w, h = im.size
    rnd = random.Random(seed)
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for _ in range(18):
        s = rnd.randint(50, 190)
        x, y = rnd.randint(-60, w), rnd.randint(-60, h)
        col = hx(rnd.choice(TIERS))
        a = rnd.randint(8, 20)
        tile = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(tile).rounded_rectangle(
            [0, 0, s, s], radius=int(s * 0.18), fill=col + (a,))
        lay.alpha_composite(tile.rotate(rnd.randint(-28, 28), expand=True), (x, y))
    return Image.alpha_composite(im.convert("RGBA"), lay).convert("RGB")


def rounded(shot, radius):
    """Round the frame's corners so it reads as a phone and not a crop."""
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, shot.size[0] - 1, shot.size[1] - 1], radius=radius, fill=255)
    out = shot.convert("RGBA")
    out.putalpha(mask)
    return out


def scrim(im, top_stop=0.52, bot_start=0.58, strength=0.86, top_hold=0.0):
    """Darken the top and bottom bands, leaving the middle alone.

    Built as a vertical alpha ramp rather than two pasted gradients, because the
    two have to meet in the middle without a seam and a seam across a near-black
    picture is the kind of thing that only shows up after it is posted.

    `top_hold` is a plateau at full strength before the ramp begins, and it is
    there because a pure ramp is the wrong shape for this job. Decaying from the
    top edge, the scrim has already given back two thirds of its strength by the
    time it reaches the bottom of the headline — so the first render had score
    pops reading clearly through the sub-line. Text needs a *flat* floor under it
    and a fade only past where it ends.
    """
    h = im.size[1]
    ramp = np.zeros(h, dtype=float)
    for y in range(h):
        t = y / (h - 1)
        if t < top_hold:
            ramp[y] = 1.0
        elif t < top_stop:
            ramp[y] = (1.0 - (t - top_hold) / (top_stop - top_hold)) ** 1.4
        elif t > bot_start:
            ramp[y] = ((t - bot_start) / (1.0 - bot_start)) ** 1.6
    a = (ramp * strength)[:, None, None]
    arr = np.asarray(im.convert("RGB"), dtype=float)
    return Image.fromarray(np.clip(arr * (1.0 - a), 0, 255).astype("uint8"))


def fit(draw, text, path, width, start, floor=20):
    """Largest size at which `text` fits `width`. Headlines are set to the box."""
    size = start
    while size > floor:
        f = ImageFont.truetype(path, size)
        if draw.textlength(text, font=f) <= width:
            return f
        size -= 2
    return ImageFont.truetype(path, floor)


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if draw.textlength(trial, font=font) <= width and line:
            line = trial
        elif not line:
            line = word
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def grab(take, at):
    """One frame of the take, as a PIL image.

    `-ss` before `-i` so ffmpeg seeks rather than decodes up to the timestamp;
    the take is 40-odd seconds and this is called once per hook.
    """
    os.makedirs(WORK, exist_ok=True)
    path = os.path.join(WORK, "f%.2f.png" % at)
    if not os.path.exists(path):
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "%.3f" % at,
                        "-i", take, "-frames:v", "1", path], check=True)
    return Image.open(path).convert("RGB")


def cta(im, x, y, accent, scale=1.0, align="left"):
    """The name, the offer, and a rule over the top of them.

    One block wherever it is put, so the three placements cannot drift into
    disagreeing about what the call to action says.
    """
    d = ImageDraw.Draw(im)
    f_name = ImageFont.truetype(NAME_F, int(62 * scale))
    f_sub = ImageFont.truetype(BODY_B, int(30 * scale))
    rule_w = int(96 * scale)
    nx = x
    if align == "center":
        nx = x - d.textlength(CTA_NAME, font=f_name) / 2
        d.line([(x - rule_w // 2, y), (x + rule_w // 2, y)], fill=accent, width=3)
    else:
        d.line([(x, y), (x + rule_w, y)], fill=accent, width=3)
    d.text((nx, y + int(20 * scale)), CTA_NAME, font=f_name, fill=INK)
    sx = x - d.textlength(CTA_SUB, font=f_sub) / 2 if align == "center" else x
    d.text((sx, y + int(96 * scale)), CTA_SUB, font=f_sub, fill=accent)


def headline(d, head, box, avail_h, accent, x, y):
    """Set the headline to the box, and return where it ends.

    Sized against the height it is allowed as well as the width, which is the
    part the first pass got wrong. Fitting on width alone gives the same size to
    a two-line hook and a three-line one, and the three-line one then walks down
    the picture into whatever was under it — in `endings` that was the call to
    action, which it overprinted.
    """
    start = min(int(box * 0.30), int(avail_h / (len(head) + 0.9)))
    f = None
    for line in head:
        cand = fit(d, line, HOOK_F, box, start)
        if f is None or cand.size < f.size:
            f = cand
    # One size for the whole block. Fitting each line on its own would set the
    # short line bigger than the long one, which reads as a mistake rather than
    # as emphasis.
    for i, line in enumerate(head):
        d.text((x, y), line, font=f, fill=INK if i == 0 else hx(accent))
        y += int(f.size * 0.92)
    return y


def layout_full(size, frame, accent, head, sub):
    """9:16 — the frame itself, edge to edge.

    The type is placed against the bands this game reliably leaves empty rather
    than against fractions of the canvas: the well above the stack takes the
    headline, and the gap between the board and the keyboard takes the call to
    action. The first pass used round numbers instead and put the headline over
    the HUD, the sub-line through the score pops, and WORD WARS across the F, G
    and H keys.
    """
    w, h = size
    # The plateau runs to just past where the sub-line ends, so everything the
    # type sits on is flat black rather than a gradient the score pops show
    # through.
    im = scrim(frame.resize(size, Image.LANCZOS), top_hold=0.37,
               top_stop=0.49, bot_start=0.66, strength=0.965).convert("RGB")
    d = ImageDraw.Draw(im)
    margin = int(w * 0.075)
    box = w - margin * 2

    # Under the HUD, and finished before the stack starts.
    top = int(h * 0.135)
    y = headline(d, head, box, int(h * 0.26), accent, margin, top)

    f_sub = ImageFont.truetype(BODY_R, int(w * 0.036))
    y += int(h * 0.012)
    for line in wrap(d, sub, f_sub, box):
        d.text((margin, y), line, font=f_sub, fill=MUTE)
        y += int(f_sub.size * 1.32)

    # Above the chain bar, not on it.
    #
    # 0.635 put the rule and the name straight through the game's own progress
    # bar, which draws a solid horizontal line across the middle of that gap —
    # so WORD WARS came out looking struck through. The clear band is the one
    # between the bottom of the stack and the top of that bar.
    cta(im, w // 2, int(h * 0.582), hx(accent), scale=w / 1080, align="center")
    return im


def layout_device(size, frame, accent, head, sub):
    """1:1 and 1.91:1 — the phone on the game's own furniture, type beside it.

    The phone is hung off the bottom edge rather than fitted inside the canvas.
    At 628 tall a whole 9:16 screen is 353px wide and the board inside it is a
    stripe nobody can read; letting the keyboard run off the bottom buys the
    board about 60% more height, and the keyboard is the part of the picture
    that was carrying the least.
    """
    w, h = size
    im = decor(ground(size, hx(accent)), int(sum(ord(c) for c in head[0])))

    # The phone, sized off the canvas *width* rather than its height.
    #
    # Height was the first attempt and it only happened to work at 1.91:1. On the
    # square canvas the same multiplier produced a phone 814px wide on a 1080px
    # picture, which left the type a 105px column — a headline set smaller than
    # its own sub-line, wrapped one word per line, running off the bottom. Width
    # is what the text column is actually competing for, so width is what sizes
    # this.
    pw = int(w * 0.42)
    ph = int(pw * 1920 / 1080)
    px, py = int(w - pw - w * 0.055), int(h * 0.10)
    shot = frame.resize((pw, ph), Image.LANCZOS)

    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [px - 6, py + 14, px + pw + 6, py + ph], radius=30, fill=(0, 0, 0, 165))
    im = Image.alpha_composite(
        im.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(26)))
    im.alpha_composite(rounded(shot, 30), (px, py))
    ImageDraw.Draw(im).rounded_rectangle(
        [px, py, px + pw, py + ph], radius=30, outline=hx(accent) + (120,), width=3)
    im = im.convert("RGB")

    d = ImageDraw.Draw(im)
    margin = int(w * 0.055)
    box = px - margin - int(w * 0.04)
    scale = box / 520.0

    # The block flows: headline, then sub under it, then the call to action under
    # that — rather than each being pinned to its own fraction of the height.
    # Pinned, a three-line hook simply lands on whatever was below it.
    y = int(h * 0.12)
    y = headline(d, head, box, int(h * 0.42), accent, margin, y)

    f_sub = ImageFont.truetype(BODY_R, max(18, int(box * 0.072)))
    y += int(h * 0.025)
    for line in wrap(d, sub, f_sub, box):
        d.text((margin, y), line, font=f_sub, fill=MUTE)
        y += int(f_sub.size * 1.30)

    # Below the sub, or pushed up if the sub ran long — whichever keeps the whole
    # block on the canvas.
    cta_y = min(y + int(h * 0.075), h - int(150 * scale))
    cta(im, margin, cta_y, hx(accent), scale=scale)
    return im


LAYOUTS = {"full": layout_full, "device": layout_device}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hook", default=None, help="just one of %s"
                    % ", ".join(a[0] for a in ADS))
    ap.add_argument("--take", default=TAKE)
    ap.add_argument("--out-dir", default=OUT)
    args = ap.parse_args()

    if not os.path.exists(args.take):
        sys.exit("no footage at %s — record it with:\n"
                 "    tools/adreel.sh --seed 31 --seconds 22 --human "
                 "--out build/ads/raw/take-h31" % args.take)
    os.makedirs(args.out_dir, exist_ok=True)

    wanted = [a for a in ADS if args.hook in (None, a[0])]
    if not wanted:
        sys.exit("no hook %r — expected one of %s"
                 % (args.hook, ", ".join(a[0] for a in ADS)))

    print("[images]")
    for name, at, accent, head, sub in wanted:
        frame = grab(args.take, at)
        for slot, (size, kind) in PLACEMENTS.items():
            im = LAYOUTS[kind](size, frame, accent, head, sub)
            dest = os.path.join(args.out_dir, "%s-%s.png" % (name, slot))
            im.save(dest)
            print("  %s  %dx%d  (frame @ %.2fs)" % (dest, size[0], size[1], at))


if __name__ == "__main__":
    main()
