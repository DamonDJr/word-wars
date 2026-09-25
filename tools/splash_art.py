#!/usr/bin/env python3
"""The launch splashes, from the same tile logo the title screen draws.

    tools/splash_art.py

Writes packaging/splash/*.svg and renders splashScreen.png (landscape, the
engine boot splash) and iosSplashScreen.png (portrait, the iOS launch
storyboard). Both keep the sizes the export presets were set up with.

The logo here has to match `_draw_wordmark` in game.gd, because the splash
fades straight into the title screen: same tiles, same colours, same tilts.
If one changes, change the other.
"""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "packaging" / "splash"
FONTS = [ROOT / "fonts" / "BarlowCondensed-Black.ttf",
         ROOT / "fonts" / "BarlowSemiCondensed-Medium.ttf"]

MATTE = "#01061a"          # project.godot boot_splash/bg_color
BLUE = "#48bfe3"
RED = "#f94144"
INK = "#0b1020"
TIER = ["#5390d9", "#48bfe3", "#64dfdf", "#f9c74f", "#f8961e", "#f94144"]
TILT = [-4.0, 2.5, -1.5, 3.5, -3.0, 1.5, -2.5, 4.0]
DROP = [2.0, -3.0, 1.0, -1.0, -2.0, 3.0, 0.0, -3.0]


def shade(hex_, k):
    """Darken (k < 0) or lighten (k > 0) like Godot's Color.darkened/lightened."""
    h = hex_.lstrip("#")
    c = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if k < 0:
        c = [round(v * (1 + k)) for v in c]
    else:
        c = [round(v + (255 - v) * k) for v in c]
    return "#" + "".join(f"{v:02x}" for v in c)


def tile(cx, cy, size, letter, col, tilt, text_size=None):
    r = size * 0.14
    half = size / 2
    ts = text_size or size * 0.86
    return (f'<g transform="translate({cx:.1f} {cy:.1f}) rotate({tilt})">'
            f'<rect x="{-half:.1f}" y="{-half + size * 0.09:.1f}" width="{size:.1f}" '
            f'height="{size:.1f}" rx="{r:.1f}" fill="{shade(col, -0.62)}"/>'
            f'<rect x="{-half:.1f}" y="{-half:.1f}" width="{size:.1f}" height="{size:.1f}" '
            f'rx="{r:.1f}" fill="{col}" stroke="{shade(col, 0.3)}" '
            f'stroke-width="{max(1.5, size * 0.035):.1f}"/>'
            f'<text x="0" y="{ts * 0.36:.1f}" text-anchor="middle" '
            f'font-family="Barlow Condensed" font-weight="900" '
            f'font-size="{ts:.1f}" fill="{INK}">{letter}</text></g>')


def word_row(cx, cy, size, word, col, offset):
    gap = size * 0.12
    total = size * len(word) + gap * (len(word) - 1)
    x = cx - total / 2 + size / 2
    out = []
    for i, ch in enumerate(word):
        k = offset + i
        out.append(tile(x, cy + DROP[k] * size / 58, size, ch, col, TILT[k]))
        x += size + gap
    return "".join(out)


def backdrop(w, h, cell):
    """The playfield's ruling, very faint, and a few loose blocks carrying
    real stamps, so the first frame is already the game's world."""
    out = [f'<rect width="{w}" height="{h}" fill="{MATTE}"/>']
    x = cell / 2
    while x < w:
        out.append(f'<line x1="{x:.1f}" y1="0" x2="{x:.1f}" y2="{h}" '
                   f'stroke="#ffffff" stroke-opacity="0.03" stroke-width="1.5"/>')
        x += cell
    y = cell / 2
    while y < h:
        out.append(f'<line x1="0" y1="{y:.1f}" x2="{w}" y2="{y:.1f}" '
                   f'stroke="#ffffff" stroke-opacity="0.03" stroke-width="1.5"/>')
        y += cell
    return "".join(out)


def loose_block(x, y, cw, ch, stamp, tier, alpha, tilt=0):
    col = TIER[tier]
    return (f'<g opacity="{alpha}" transform="translate({x} {y}) rotate({tilt})">'
            f'<rect x="{-cw / 2}" y="{-ch / 2}" width="{cw}" height="{ch}" rx="10" '
            f'fill="{col}" fill-opacity="0.16" stroke="{col}" stroke-width="3"/>'
            f'<text x="0" y="{ch * 0.16:.1f}" text-anchor="middle" '
            f'font-family="Barlow Condensed" font-weight="900" '
            f'font-size="{min(ch, cw / max(1, len(stamp)) * 1.6) * 0.5:.1f}" '
            f'fill="{col}">{stamp}</text></g>')


def tagline(cx, y, size):
    return (f'<text x="{cx}" y="{y}" text-anchor="middle" font-family="Barlow Semi Condensed" '
            f'font-weight="500" font-size="{size}" fill="#8d99bd">'
            f'Your endings become their beginnings.</text>')


def landscape():
    w, h = 1536, 1024
    body = [backdrop(w, h, 64)]
    for x, y, cw, ch, s, t, a, r in ((190, 210, 150, 64, "SHIP", 2, 0.5, -6),
                                     (1320, 190, 128, 64, "ING", 5, 0.45, 5),
                                     (150, 820, 128, 128, "MENT", 3, 0.35, 4),
                                     (1380, 800, 200, 128, "TION", 1, 0.35, -4),
                                     (430, 880, 64, 64, "AL", 0, 0.25, 8),
                                     (1110, 900, 64, 64, "ER", 4, 0.25, -8)):
        body.append(loose_block(x, y, cw, ch, s, t, a, r))
    size = 118
    row_w = size * 8 + size * 0.12 * 6 + size * 0.45
    left = w / 2 - row_w / 2
    body.append(word_row(left + (size * 4 + size * 0.36) / 2, 470, size, "WORD", BLUE, 0))
    body.append(word_row(w - left - (size * 4 + size * 0.36) / 2, 470, size, "WARS", RED, 4))
    body.append(tagline(w / 2, 640, 40))
    return w, h, body


def portrait():
    w, h = 853, 1844
    body = [backdrop(w, h, 71)]
    for x, y, cw, ch, s, t, a, r in ((170, 300, 142, 71, "SHIP", 2, 0.5, -6),
                                     (690, 380, 142, 71, "ING", 5, 0.45, 5),
                                     (160, 1420, 142, 142, "MENT", 3, 0.35, 4),
                                     (680, 1500, 213, 142, "TION", 1, 0.35, -4),
                                     (720, 1290, 71, 71, "AL", 0, 0.25, -8)):
        body.append(loose_block(x, y, cw, ch, s, t, a, r))
    size = 150
    body.append(word_row(w / 2, 790, size, "WORD", BLUE, 0))
    body.append(word_row(w / 2, 790 + size * 1.32, size, "WARS", RED, 4))
    body.append(tagline(w / 2, 1150, 40))
    return w, h, body


def main():
    SRC.mkdir(parents=True, exist_ok=True)
    # Sources for resvg, not textures: keep Godot from importing them.
    (SRC / ".gdignore").touch()
    for name, out, build in (("landscape", "splashScreen.png", landscape),
                             ("portrait", "iosSplashScreen.png", portrait)):
        w, h, body = build()
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
               f'viewBox="0 0 {w} {h}">{"".join(body)}</svg>\n')
        src = SRC / f"{name}.svg"
        src.write_text(svg)
        cmd = ["resvg", "--width", str(w), "--height", str(h)]
        for f in FONTS:
            cmd += ["--use-font-file", str(f)]
        subprocess.run(cmd + [str(src), str(ROOT / out)], check=True)
        print(f"[splash_art] {out}  {w}x{h}")


if __name__ == "__main__":
    main()
