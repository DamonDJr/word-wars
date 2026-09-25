#!/usr/bin/env python3
"""App Store screenshots: a headline over each rendered screen.

    tools/store-shots.sh          # renders the screens, then runs this
    python3 tools/store-shots.py  # just the compositing, from existing renders

Reads the raw renders `tools/shots.gd --appstore --board X` writes into
build/shots/appstore and composes the upload set into build/shots/store:

    iphone/01-launch.png ...   1320 x 2868  (iPhone 6.9")
    ipad/01-launch.png ...     2064 x 2752  (iPad 13")

Both RGB with no alpha channel, which App Store Connect rejects on sight.

## Why captions now, when the old set had none

The old set was the game's own frames, full-bleed. That is honest and it is a
poor first impression: on the store page the first two or three screenshots are
most of what a visitor sees, at thumbnail size, and a raw game frame at
thumbnail size is a grid of small letters. A headline says what the game is in
the time somebody spends deciding whether to look closer.

The screen underneath is still exactly what the game draws — rendered by
shots.gd, nothing painted in here but the frame around it.

## Premium boards are labelled

App Review Guideline 2.3.2: screenshots must make clear when something featured
needs an additional purchase. Every shot on a Premium-pack board carries a gold
PREMIUM BOARD tag naming it, and the cosmetics shot says the pack outright. The
free screens are deliberately on free boards (Midnight, and Ember, a level
reward), so the set shows what everybody gets as well as what can be bought.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

SRC = "build/shots/appstore"
OUT = "build/shots/store"
HEAD = "fonts/BarlowCondensed-Black.ttf"
TAGF = "fonts/BarlowSemiCondensed-Bold.ttf"

INK = (230, 236, 255)
GOLD = (255, 209, 102)
DEEP = (11, 16, 32)

# Paid boards. Anything filmed on one of these is tagged.
PREMIUM = {"forest", "volcano", "ocean", "space", "cyber", "clouds", "desert", "aurora"}

# (render, board, file name, line one, line two, accent, backdrop top, bottom, tag)
# Line one is white and line two is in the accent, so each card reads as a
# statement and its payoff. `tag` overrides the automatic premium tag.
SHOTS = [
    ("solo", "volcano", "01-launch", "TYPE WORDS.", "LAUNCH THEM.",
     (255, 140, 66), (40, 8, 4), (18, 4, 2), None),
    ("solo", "space", "02-rule", "YOUR WORD'S LAST LETTERS", "HIT THEIR BOARD.",
     (199, 125, 255), (22, 10, 50), (8, 4, 28), None),
    ("versus", "clouds", "03-friends", "PLAY YOUR FRIENDS.", "SEND A LINK. YOU'RE IN.",
     (79, 195, 247), (18, 40, 70), (8, 18, 36), None),
    ("daily", "midnight", "04-daily", "ONE BOARD A DAY.", "THE SAME FOR EVERYONE.",
     (100, 223, 223), (14, 20, 44), (4, 8, 22), None),
    ("survival", "ember", "05-survival", "NO CLOCK.", "HOW LONG CAN YOU LAST?",
     (249, 65, 68), (40, 14, 12), (16, 6, 6), None),
    ("cosmetics", "aurora", "06-boards", "PICK YOUR BATTLEFIELD.", "8 ANIMATED BOARDS.",
     (94, 234, 212), (6, 30, 42), (2, 12, 20), "IN THE PREMIUM PACK"),
    ("boards", "midnight", "07-leaderboard", "CLIMB THE DAILY BOARD.", "BEAT THE WORLD.",
     (255, 209, 102), (14, 20, 44), (4, 8, 22), None),
]

DEVICES = {
    # name: (canvas, suffix on the render, headline band height, sizes)
    "iphone": ((1320, 2868), "", 640, 118, 44),
    "ipad": ((2064, 2752), "-ipad", 560, 132, 48),
}


def gradient(size, top, bottom):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        f = y / (h - 1)
        col.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * f) for i in range(3)))
    return col.resize((w, h))


def glow(canvas, centre, radius, colour, strength):
    """A soft pool of the accent behind the screen, so each card has its own
    light rather than all seven sitting on the same flat dark."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = centre
    d.ellipse((x - radius, y - radius, x + radius, y + radius),
              fill=colour + (int(255 * strength),))
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.45))
    canvas.alpha_composite(layer)


def fit_font(path, text, size, max_w):
    while size > 20:
        f = ImageFont.truetype(path, size)
        if f.getlength(text) <= max_w:
            return f
        size -= 2
    return ImageFont.truetype(path, size)


def centred(draw, y, text, font, fill, width):
    w = font.getlength(text)
    draw.text(((width - w) / 2, y), text, font=font, fill=fill)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1),
                                           radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def compose(device, spec):
    (cw, ch), suffix, band, head_size, tag_size = DEVICES[device]
    render, board, name, one, two, accent, top, bottom, tag = spec
    src = os.path.join(SRC, "%s-%s%s.png" % (render, board, suffix))
    if not os.path.exists(src):
        raise SystemExit("missing %s — run tools/store-shots.sh" % src)

    canvas = gradient((cw, ch), top, bottom).convert("RGBA")
    glow(canvas, (cw // 2, band + (ch - band) // 2), int(cw * 0.55), accent, 0.22)
    d = ImageDraw.Draw(canvas)

    # The headline.
    margin = int(cw * 0.07)
    f1 = fit_font(HEAD, one, head_size, cw - margin * 2)
    f2 = fit_font(HEAD, two, head_size, cw - margin * 2)
    y = int(band * 0.20)
    centred(d, y, one, f1, INK, cw)
    centred(d, y + int(head_size * 1.02), two, f2, accent, cw)

    # The premium tag, as a pill under the headline.
    label = tag
    if label is None and board in PREMIUM:
        label = "PREMIUM BOARD  ·  %s" % board.upper()
    if label:
        tf = ImageFont.truetype(TAGF, tag_size)
        tw = tf.getlength(label)
        py = y + int(head_size * 2.18)
        pad_x, pad_y = int(tag_size * 0.8), int(tag_size * 0.38)
        box = (cw / 2 - tw / 2 - pad_x, py, cw / 2 + tw / 2 + pad_x, py + tag_size + pad_y * 2)
        d.rounded_rectangle(box, radius=(box[3] - box[1]) / 2, fill=(20, 16, 6, 230),
                            outline=GOLD, width=3)
        d.text((cw / 2 - tw / 2, py + pad_y - tag_size * 0.12), label, font=tf, fill=GOLD)

    # The screen, framed, under the band.
    shot = Image.open(src).convert("RGB")
    room_h = ch - band - int(ch * 0.035)
    room_w = cw - margin * 2
    scale = min(room_h / shot.height, room_w / shot.width)
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    radius = int(sw * 0.06)
    sx, sy = (cw - sw) // 2, band

    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((sx, sy + 18, sx + sw, sy + sh + 18),
                                             radius=radius, fill=(0, 0, 0, 150))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    canvas.alpha_composite(rounded(shot, radius), (sx, sy))
    ImageDraw.Draw(canvas).rounded_rectangle((sx, sy, sx + sw - 1, sy + sh - 1),
                                             radius=radius, outline=accent + (200,), width=4)

    dest = os.path.join(OUT, device)
    os.makedirs(dest, exist_ok=True)
    path = os.path.join(dest, name + ".png")
    # RGB, no alpha: App Store Connect refuses a screenshot for having the
    # channel at all, whether or not anything in it is transparent.
    canvas.convert("RGB").save(path, optimize=True)
    return path


def main():
    for device in DEVICES:
        for spec in SHOTS:
            path = compose(device, spec)
            im = Image.open(path)
            print("  %s  %dx%d  %s" % (path, im.width, im.height, im.mode))


if __name__ == "__main__":
    main()
