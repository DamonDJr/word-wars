#!/usr/bin/env python3
"""The App Store icon: BloqBot, hyped, with the wordmark's tiles flying.

    tools/appicon_art.py              writes appicon-1024.png
    tools/appicon_art.py --preview    and a sheet of it at home-screen sizes

The old icon was the wordmark's tiles alone, flat on navy: correct, and the
least fun thing in a game whose mascot punches the air when you win. So the
character is the icon now, in his own hype pose, drawn by hand like every
BloqBot frame in the game, over a burst in the tiers' warm colours, with the
title's own W tiles thrown out of the shot. Nothing here is generated art:
BloqBot is the hand-drawn frame, and the rest is the wordmark's tile drawn the
way `splash_art.py` and `_draw_wordmark` draw it.

Apple's rules, which the output keeps: 1024x1024, square corners (iOS masks
them), and no alpha channel at all — a transparent pixel anywhere is a
rejected upload.
"""

import base64
import io
import math
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
# The SVG it renders from carries BloqBot inside it as base64, so it is a build
# product, not a source: it is written where builds go and not kept.
SRC = ROOT / "build" / "icon"
FONTS = [ROOT / "fonts" / "BarlowCondensed-Black.ttf"]
BOT = ROOT / "baseEmotes" / "BloqBot" / "BloqBotHype" / "BloqBotHype_013.png"

SIZE = 1024
INK = "#0b1020"
BLUE = "#48bfe3"
RED = "#f94144"

# The burst's centre, roughly behind BloqBot's head, so the rays come out of
# him rather than out of the middle of the canvas.
CX, CY = 600, 440


def shade(hex_, k):
    """Darken (k < 0) or lighten (k > 0) like Godot's Color.darkened/lightened."""
    h = hex_.lstrip("#")
    c = [int(h[i:i + 2], 16) for i in (0, 2, 4)]
    if k < 0:
        c = [round(v * (1 + k)) for v in c]
    else:
        c = [round(v + (255 - v) * k) for v in c]
    return "#" + "".join(f"{v:02x}" for v in c)


def backdrop():
    """A warm burst: lit in the middle, deeper at the edges, with rays."""
    out = [
        '<defs>'
        f'<radialGradient id="glow" cx="{CX}" cy="{CY}" r="820" gradientUnits="userSpaceOnUse">'
        '<stop offset="0" stop-color="#ffe680"/>'
        '<stop offset="0.45" stop-color="#ffc533"/>'
        '<stop offset="1" stop-color="#f28a12"/>'
        '</radialGradient>'
        f'<radialGradient id="rayfade" cx="{CX}" cy="{CY}" r="760" gradientUnits="userSpaceOnUse">'
        '<stop offset="0.15" stop-color="#fff6cc" stop-opacity="0.55"/>'
        '<stop offset="1" stop-color="#fff6cc" stop-opacity="0.05"/>'
        '</radialGradient>'
        '</defs>',
        f'<rect width="{SIZE}" height="{SIZE}" fill="url(#glow)"/>',
    ]
    rays = 14
    far = 1600
    for i in range(rays):
        a0 = (i / rays) * math.tau + 0.12
        a1 = a0 + math.tau / rays * 0.5
        pts = [(CX, CY), (CX + math.cos(a0) * far, CY + math.sin(a0) * far),
               (CX + math.cos(a1) * far, CY + math.sin(a1) * far)]
        out.append('<polygon points="' + " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
                   + '" fill="url(#rayfade)"/>')
    return "".join(out)


def tile(cx, cy, size, letter, col, tilt):
    """The wordmark's tile — a lit face over a darker base, rimmed, with its
    letter — and an ink line round the lot, so it holds its shape at 60px."""
    r = size * 0.16
    half = size / 2
    ink = max(6.0, size * 0.035)
    lift = size * 0.10
    return (f'<g transform="translate({cx:.1f} {cy:.1f}) rotate({tilt})">'
            f'<rect x="{-half - ink:.1f}" y="{-half - ink:.1f}" width="{size + ink * 2:.1f}" '
            f'height="{size + lift + ink * 2:.1f}" rx="{r + ink:.1f}" fill="{INK}"/>'
            f'<rect x="{-half:.1f}" y="{-half + lift:.1f}" width="{size:.1f}" '
            f'height="{size:.1f}" rx="{r:.1f}" fill="{shade(col, -0.45)}"/>'
            f'<rect x="{-half:.1f}" y="{-half:.1f}" width="{size:.1f}" height="{size:.1f}" '
            f'rx="{r:.1f}" fill="{col}"/>'
            f'<rect x="{-half + size * 0.08:.1f}" y="{-half + size * 0.07:.1f}" '
            f'width="{size * 0.84:.1f}" height="{size * 0.12:.1f}" rx="{size * 0.06:.1f}" '
            f'fill="#ffffff" fill-opacity="0.35"/>'
            f'<text x="0" y="{size * 0.30:.1f}" text-anchor="middle" '
            f'font-family="Barlow Condensed" font-weight="900" '
            f'font-size="{size * 0.86:.1f}" fill="{INK}">{letter}</text></g>')


def streaks(cx, cy, size, ang, n=3):
    """Speed lines trailing a tile, pointing back the way it came."""
    out = []
    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx
    for k in range(n):
        off = (k - (n - 1) / 2) * size * 0.30
        start = size * 0.62 + (k % 2) * size * 0.08
        length = size * (0.55 if k % 2 == 0 else 0.38)
        x0, y0 = cx + dx * start + px * off, cy + dy * start + py * off
        x1, y1 = x0 + dx * length, y0 + dy * length
        out.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" '
                   f'stroke="#fffbe6" stroke-width="{size * 0.055:.1f}" '
                   f'stroke-linecap="round" stroke-opacity="0.9"/>')
    return "".join(out)


def sparkle(x, y, s, col="#ffffff"):
    """BloqBot's own hype star: four points, pinched."""
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        r = s if i % 2 == 0 else s * 0.28
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
    return ('<polygon points="' + " ".join(f"{a:.1f},{b:.1f}" for a, b in pts)
            + f'" fill="{col}" stroke="{INK}" stroke-width="{max(3.0, s * 0.12):.1f}" '
            'stroke-linejoin="round"/>')


def bot_png(scale):
    """BloqBot's frame with a sticker outline: his silhouette grown in ink
    behind him, so he reads as one shape against the burst at any size."""
    art = Image.open(BOT).convert("RGBA")
    # The frame carries a big pale star behind his head, drawn white at about
    # sixty percent. It is the only light, half-transparent thing in it — he
    # is opaque, and his edges are ink — so it lifts out cleanly, and the icon
    # has its own stars.
    px = art.load()
    for y in range(art.height):
        for x in range(art.width):
            r, g, b, a = px[x, y]
            if 0 < a < 250 and min(r, g, b) > 190:
                px[x, y] = (0, 0, 0, 0)
    w, h = art.size
    art = art.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
    pad = 40
    canvas = Image.new("RGBA", (art.width + pad * 2, art.height + pad * 2), (0, 0, 0, 0))
    alpha = Image.new("L", canvas.size, 0)
    alpha.paste(art.getchannel("A"), (pad, pad))
    grown = alpha.filter(ImageFilter.MaxFilter(23)).filter(ImageFilter.GaussianBlur(1.2))
    grown = grown.point(lambda v: 255 if v > 90 else 0)
    outline = Image.new("RGBA", canvas.size, (11, 16, 32, 255))
    outline.putalpha(grown)
    canvas.alpha_composite(outline)
    canvas.alpha_composite(art, (pad, pad))
    buf = io.BytesIO()
    canvas.save(buf, "PNG")
    return canvas.size, pad, base64.b64encode(buf.getvalue()).decode()


def icon_svg():
    body = [backdrop()]
    scale = 1.9
    (bw, bh), pad, data = bot_png(scale)
    # Placed by eye from the frame: his head on the burst, a little right of
    # centre and as big as the square allows, because his face is what has to
    # survive at sixty pixels; his legs run off the bottom, where they say
    # nothing anyway. The tiles he has just thrown are up and away on the left.
    bx = 655 - bw * 0.56
    by = 1080 - bh * 0.93
    # The speed lines run back toward him, so they go behind him: drawn over
    # him they read as scratches across his face.
    body.append(streaks(205, 505, 225, math.radians(35)))
    body.append(streaks(315, 215, 250, math.radians(55)))
    body.append(f'<image x="{bx:.1f}" y="{by:.1f}" width="{bw}" height="{bh}" '
                f'href="data:image/png;base64,{data}"/>')
    body.append(tile(205, 505, 225, "W", RED, 12))
    body.append(tile(315, 215, 250, "W", BLUE, -10))
    body.append(sparkle(915, 150, 46))
    body.append(sparkle(590, 80, 26))
    body.append(sparkle(120, 760, 30))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'xmlns:xlink="http://www.w3.org/1999/xlink" width="{SIZE}" height="{SIZE}" '
            f'viewBox="0 0 {SIZE} {SIZE}">{"".join(body)}</svg>\n')


def render(svg_path, png_path):
    cmd = ["resvg", "--width", str(SIZE), "--height", str(SIZE)]
    for f in FONTS:
        cmd += ["--use-font-file", str(f)]
    subprocess.run(cmd + [str(svg_path), str(png_path)], check=True)
    # No alpha channel, which is what Apple checks for, not just no
    # transparent pixels.
    Image.open(png_path).convert("RGB").save(png_path)


def preview(png_path, out):
    """The icon as a home screen shows it: masked, at the sizes it is seen."""
    icon = Image.open(png_path).convert("RGBA")
    sizes = [512, 180, 120, 87, 60]
    sheet = Image.new("RGB", (sum(sizes) + 40 * (len(sizes) + 1), 512 + 80), (28, 30, 44))
    x = 40
    for s in sizes:
        small = icon.resize((s, s), Image.LANCZOS)
        mask = Image.new("L", (s * 4, s * 4), 0)
        from PIL import ImageDraw
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, s * 4 - 1, s * 4 - 1), radius=s * 4 * 0.2237,
                                               fill=255)
        mask = mask.resize((s, s), Image.LANCZOS)
        sheet.paste(small, (x, 40 + (512 - s) // 2), mask)
        x += s + 40
    sheet.save(out)


def main():
    SRC.mkdir(parents=True, exist_ok=True)
    src = SRC / "appicon.svg"
    src.write_text(icon_svg())
    out = ROOT / "appicon-1024.png"
    render(src, out)
    print(f"[appicon_art] {out.name}  {SIZE}x{SIZE}, no alpha")
    if "--preview" in sys.argv:
        prev = ROOT / "build" / "appicon-preview.png"
        prev.parent.mkdir(exist_ok=True)
        preview(out, prev)
        print(f"[appicon_art] {prev}")


if __name__ == "__main__":
    main()
