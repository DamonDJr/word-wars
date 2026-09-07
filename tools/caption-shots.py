"""Caption cards for the stills that tools/shots.gd renders.

    godot --script tools/shots.gd -- daily        # and the rest
    python3 tools/caption-shots.py

Reads build/shots/*.png and writes build/shots/cards/*.png — 1080x1920, which is
the shape every social surface wants and none of the App Store slots are. These
are for posts, not for App Store Connect: that wants 1320x2868 for the 6.9-inch
iPhone and 2064x2752 for the 13-inch iPad, with no caption furniture around the
screenshot and no alpha channel on it.

Those are what `tools/shots.sh --appstore` produces, and this script
deliberately does not run over them.

The furniture is the game's own: the same background gradient, the same drifting
low-contrast blocks and the same tier palette as tools/challenge-banners.py,
because a caption card in a different visual language than the screenshot inside
it reads as a stock template somebody dropped the game into.

Each caption is a label and a line. The label says which screen this is, since a
scrolling reader does not yet know there are modes; the line is the one sentence
that screen is worth. Anything longer gets skimmed past — these are read at
thumbnail size on a phone, next to somebody's thumb.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np
import os
import random

W, H = 1080, 1920
SRC = "build/shots"
OUT = "build/shots/cards"

SANS_B = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
SANS = "/usr/share/fonts/TTF/DejaVuSans.ttf"

# Straight out of the game: THEMES/midnight, the boot splash, and TIER_COLORS.
BG_TOP, BG_BOT = (1, 6, 26), (20, 26, 54)
TIERS = ["#5390d9", "#48bfe3", "#64dfdf", "#f9c74f", "#f8961e", "#f94144"]
INK, MUTE = (230, 236, 255), (125, 136, 173)

# The still, the accent it is captioned in, the label, and the line.
#
# The lines are deliberately not feature lists. "Leaderboards, achievements and
# challenges" describes the release; "what the next place up costs you" is the
# thing somebody might actually want.
CARDS = [
    ("title", "#64dfdf", "WORD WARS",
     "Your endings become their beginnings."),
    ("solo", "#48bfe3", "HOW IT WORKS",
     "The last letters of your word land on their board — "
     "and they have to answer them."),
    ("daily", "#f9c74f", "THE DAILY",
     "Sixty seconds. One run. The same board for everyone."),
    ("survival", "#f94144", "SURVIVAL",
     "No clock, no opponent. Just how long you can hold the line."),
    ("boards", "#5390d9", "LEADERBOARDS",
     "Where you stand — and what the next place up would cost you."),
    ("mastery", "#f8961e", "MASTERY",
     "Seventeen achievements, and a title you can wear."),
]


def hx(c):
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def ground(accent):
    """Vertical gradient plus a bloom behind where the screenshot will sit."""
    im = Image.new("RGB", (W, H), BG_TOP)
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(
            int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)))
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    g = ImageDraw.Draw(glow)
    cx, cy = W // 2, int(H * 0.58)
    for i in range(9):
        f = i / 8.0
        r = int(W * (0.16 + f * 0.52))
        v = int(30 * (1.0 - f))
        g.ellipse([cx - r, cy - r, cx + r, cy + r],
                  fill=tuple(int(c * v / 255) for c in accent))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    return Image.fromarray(np.clip(
        np.asarray(im, dtype=int) + np.asarray(glow, dtype=int),
        0, 255).astype("uint8"))


def decor(im, seed):
    """The drifting blocks behind every menu. Low contrast on purpose."""
    rnd = random.Random(seed)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for _ in range(18):
        s = rnd.randint(50, 190)
        x, y = rnd.randint(-60, W), rnd.randint(-60, H)
        col = hx(rnd.choice(TIERS))
        a = rnd.randint(8, 20)
        tile = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(tile).rounded_rectangle(
            [0, 0, s, s], radius=int(s * 0.18), fill=col + (a,))
        lay.alpha_composite(tile.rotate(rnd.randint(-28, 28), expand=True), (x, y))
    return Image.alpha_composite(im.convert("RGBA"), lay).convert("RGB")


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


def rounded(shot, radius):
    """Round the screenshot's corners so it reads as a phone and not a crop."""
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, shot.size[0] - 1, shot.size[1] - 1], radius=radius, fill=255)
    out = shot.convert("RGBA")
    out.putalpha(mask)
    return out


def card(name, accent_hex, label, line):
    accent = hx(accent_hex)
    src = os.path.join(SRC, f"{name}.png")
    if not os.path.exists(src):
        print(f"  skip {name} — {src} not rendered yet")
        return
    shot = Image.open(src).convert("RGB")

    im = decor(ground(accent), sum(ord(c) for c in name))
    d = ImageDraw.Draw(im)

    f_label = ImageFont.truetype(SANS_B, 34)
    f_line = ImageFont.truetype(SANS_B, 52)

    # Label, letter-spaced by hand — PIL has no tracking, and a label this short
    # looks cramped without it.
    x = 84
    spaced = "  ".join(label)
    d.text((x, 96), spaced, font=f_label, fill=accent)

    lines = wrap(d, line, f_line, W - 168)
    y = 158
    for t in lines:
        d.text((x, y), t, font=f_line, fill=INK)
        y += 68

    # The screenshot, sized to whatever the caption left rather than to a fixed
    # number — a two-line caption and a three-line one must not push it off the
    # bottom edge or leave a gap under it.
    top = max(y + 46, 360)
    avail_h = H - top - 70
    scale = min(avail_h / shot.height, (W - 300) / shot.width)
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    sx = (W - sw) // 2

    # A soft drop shadow, so the still sits on the card rather than in it.
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [sx, top + 10, sx + sw, top + sh + 10], radius=28, fill=(0, 0, 0, 150))
    im = Image.alpha_composite(
        im.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(22)))

    im.alpha_composite(rounded(shot, 26), (sx, top))
    ImageDraw.Draw(im).rounded_rectangle(
        [sx, top, sx + sw, top + sh], radius=26, outline=accent + (110,), width=3)

    os.makedirs(OUT, exist_ok=True)
    dest = os.path.join(OUT, f"{name}.png")
    im.convert("RGB").save(dest)
    print(f"  {dest}  {W}x{H}")


if __name__ == "__main__":
    print("[cards]")
    for spec in CARDS:
        card(*spec)
