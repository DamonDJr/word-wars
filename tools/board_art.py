#!/usr/bin/env python3
"""A vector set of the nine board backdrops, as placeholders or a starting point.

    tools/board_art.py            # all nine, into build/board_art/
    tools/board_art.py volcano    # just one

Not what ships. The boards in boards/*.png are the Premium art; this writes
to build/board_art/ and never touches them. To try one in the game, copy its
PNG over the matching file in boards/.

Every shape is placed here, in code, from a fixed seed: flat fills, three to
five depth layers per scene, tall shapes at the left and right edges framing
an open middle, because on a phone the board covers the middle third and the
keyboard the bottom third.
"""

import math
import os
import random
import subprocess
import sys
from pathlib import Path

W, H = 900, 1600
ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("BOARD_ART_OUT", ROOT / "build" / "board_art"))
SRC = OUT / "src"


# --------------------------------------------------------------- primitives

def f(v):
    return f"{v:.1f}".rstrip("0").rstrip(".")


def pts(points):
    return " ".join(f"{f(x)},{f(y)}" for x, y in points)


def poly(points, fill, opacity=1.0, extra=""):
    op = f' opacity="{opacity:.3f}"' if opacity < 1.0 else ""
    return f'<polygon points="{pts(points)}" fill="{fill}"{op}{extra}/>'


def rect(x, y, w, h, fill, opacity=1.0, rx=0):
    op = f' opacity="{opacity:.3f}"' if opacity < 1.0 else ""
    r = f' rx="{f(rx)}"' if rx else ""
    return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}"{r} fill="{fill}"{op}/>'


def circle(x, y, r, fill, opacity=1.0, extra=""):
    op = f' opacity="{opacity:.3f}"' if opacity < 1.0 else ""
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{fill}"{op}{extra}/>'


def ring(x, y, r, stroke, width, opacity=1.0, dash=""):
    op = f' opacity="{opacity:.3f}"' if opacity < 1.0 else ""
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="none" '
            f'stroke="{stroke}" stroke-width="{f(width)}"{d}{op}/>')


def path(d, fill, opacity=1.0, extra=""):
    op = f' opacity="{opacity:.3f}"' if opacity < 1.0 else ""
    return f'<path d="{d}" fill="{fill}"{op}{extra}/>'


def line(x1, y1, x2, y2, stroke, width, opacity=1.0, cap="round"):
    op = f' opacity="{opacity:.3f}"' if opacity < 1.0 else ""
    return (f'<line x1="{f(x1)}" y1="{f(y1)}" x2="{f(x2)}" y2="{f(y2)}" '
            f'stroke="{stroke}" stroke-width="{f(width)}" stroke-linecap="{cap}"{op}/>')


def vgrad(gid, stops):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">{s}</linearGradient>'


def rgrad(gid, stops, cx=0.5, cy=0.5, r=0.5):
    s = "".join(
        f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
    return f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">{s}</radialGradient>'


def mix(a, b, t):
    """Blend two #rrggbb colours. Used for atmospheric depth: every layer
    further back is pulled toward the sky by a fixed step."""
    a = a.lstrip("#")
    b = b.lstrip("#")
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(ca, cb))


def svg(body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}"><defs>{defs}</defs>{body}</svg>\n')


# -------------------------------------------------------------- landforms

def ridge(rng, base, amp, steps, x0=-20, x1=W + 20, jag=0.5, bottom=H + 20):
    """A skyline: a line across the scene with a random walk on it, closed off
    at the bottom. `jag` near 1 is a sawtooth range; near 0 is rolling."""
    out = []
    n = steps
    y = base
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        drift = rng.uniform(-amp, amp) * (0.4 + jag)
        y = base + (y - base) * (1.0 - jag * 0.5) + drift
        y = max(base - amp * 1.6, min(base + amp * 1.2, y))
        out.append((x, y))
    return out + [(x1, bottom), (x0, bottom)]


def smooth_band(fn, x0=-20, x1=W + 20, steps=90, bottom=H + 20):
    """A skyline from a function of x — for dunes, swells and hills."""
    out = [(x0 + (x1 - x0) * i / steps, fn(x0 + (x1 - x0) * i / steps))
           for i in range(steps + 1)]
    return out + [(x1, bottom), (x0, bottom)]


def pine(x, base, h, w, fill, tiers=4, trunk=None):
    """A fir in stacked tiers. Each tier overhangs the one above, which is what
    reads as a conifer at any size rather than as a triangle."""
    parts = []
    if trunk:
        parts.append(rect(x - w * 0.06, base - h * 0.14, w * 0.12, h * 0.16, trunk))
    top = base - h
    for t in range(tiers):
        f0 = t / tiers
        f1 = (t + 1) / tiers
        y0 = top + h * 0.86 * f0 * 0.92
        y1 = top + h * 0.86 * f1 + h * 0.04
        half = w * 0.5 * (0.35 + 0.65 * f1)
        parts.append(poly([(x, y0), (x + half, y1), (x + half * 0.35, y1 - h * 0.03),
                           (x - half * 0.35, y1 - h * 0.03), (x - half, y1)], fill))
    return "".join(parts)


def tree_row(rng, base_fn, count, hmin, hmax, fill, x0=-40, x1=W + 40, gap=None):
    out = []
    xs = sorted(rng.uniform(x0, x1) for _ in range(count))
    for x in xs:
        h = rng.uniform(hmin, hmax)
        out.append(pine(x, base_fn(x) + 6, h, h * rng.uniform(0.34, 0.44), fill,
                        tiers=rng.choice((3, 4, 4, 5))))
    return "".join(out)


def cloud(cx, cy, s, fill, rng, lobes=6, flat=True):
    """A cumulus as a heap of discs on a flat base, drawn as one group."""
    parts = []
    for i in range(lobes):
        u = i / (lobes - 1) - 0.5
        r = s * (0.55 - abs(u) * 0.5) * rng.uniform(0.85, 1.15)
        parts.append(circle(cx + u * s * 1.7, cy - r * 0.45, r, fill))
    if flat:
        parts.append(rect(cx - s * 0.95, cy - s * 0.05, s * 1.9, s * 0.22, fill,
                          rx=s * 0.11))
    return "".join(parts)


def stars(rng, n, x0, y0, x1, y1, fill, rmin=0.8, rmax=2.2, amin=0.35, amax=1.0):
    out = []
    for _ in range(n):
        r = rmin + (rmax - rmin) * rng.random() ** 3
        out.append(circle(rng.uniform(x0, x1), rng.uniform(y0, y1), r, fill,
                          rng.uniform(amin, amax)))
    return "".join(out)


def sparkle(x, y, s, fill, opacity=1.0):
    """A four-point star, for the handful of bright ones."""
    k = s * 0.18
    return poly([(x, y - s), (x + k, y - k), (x + s, y), (x + k, y + k), (x, y + s),
                 (x - k, y + k), (x - s, y), (x - k, y - k)], fill, opacity)


# ------------------------------------------------------------------ scenes

def forest():
    rng = random.Random(11)
    sky = "#123024"
    haze = "#b9d7a5"
    defs = vgrad("sky", [(0, "#0a1f18"), (0.35, "#1c4432"), (0.62, "#5c8a5e"),
                         (0.78, "#a9c98f"), (1, "#d7e6b0")])
    b = [rect(0, 0, W, H, "url(#sky)")]
    # A low sun through morning haze: a flat disc and two rings of light.
    b.append(circle(560, 930, 200, "#e9f2c4", 0.10))
    b.append(circle(560, 930, 130, "#eef5cf", 0.16))
    b.append(circle(560, 930, 74, "#f7fadf"))

    layers = [
        # base, amplitude, count, height range, fill
        (1000, 14, 70, (60, 120), mix("#3c6b4c", haze, 0.55)),
        (1060, 18, 52, (110, 190), mix("#2f5b40", haze, 0.30)),
        (1130, 22, 36, (180, 290), "#224733"),
        (1220, 26, 22, (280, 420), "#163424"),
    ]
    for i, (base, amp, count, (hmin, hmax), fill) in enumerate(layers):
        phase = rng.uniform(0, 6)
        fn = (lambda x, base=base, amp=amp, phase=phase:
              base + math.sin(x / 140 + phase) * amp + math.sin(x / 57) * amp * 0.3)
        b.append(poly(smooth_band(fn), fill))
        b.append(tree_row(rng, fn, count, hmin, hmax, fill))
        # A band of mist sitting on each ridge, which is what separates the
        # layers without outlining them.
        b.append(rect(0, base - 40, W, 70, haze, 0.10 - i * 0.015))

    # The near trees stand at the edges and frame the board.
    near = "#0b1f15"
    for x, h in ((-30, 1250), (70, 980), (830, 1180), (930, 1320), (150, 700),
                 (760, 760)):
        b.append(pine(x, 1400, h, h * 0.36, near, tiers=7, trunk=near))
    # The floor, and ferns along it.
    b.append(poly(smooth_band(lambda x: 1330 + math.sin(x / 90) * 14), near))
    for _ in range(46):
        x = rng.uniform(-10, W + 10)
        y = 1340 + rng.uniform(-10, 60)
        s = rng.uniform(26, 60)
        for k in range(5):
            a = math.radians(-150 + k * 30 + rng.uniform(-8, 8))
            b.append(line(x, y, x + math.cos(a) * s, y + math.sin(a) * s * 0.9,
                          "#123122", 5))
    return svg("".join(b), defs)


def volcano():
    rng = random.Random(23)
    defs = vgrad("sky", [(0, "#140404"), (0.4, "#3a0d07"), (0.66, "#7a220b"),
                         (0.8, "#b23d10"), (1, "#3a0d07")])
    defs += rgrad("glow", [(0, "#ff7a2a", 0.55), (0.5, "#ff5a1a", 0.18),
                           (1, "#ff4500", 0)])
    b = [rect(0, 0, W, H, "url(#sky)")]
    b.append(stars(rng, 60, 0, 0, W, 600, "#ffcfae", 0.6, 1.6, 0.15, 0.5))

    # The plume first, so the mountain stands in front of it.
    cx, cy = 600, 760
    # The plume: billows heaped along a column that leans with the wind, each
    # one a little lighter than the one below it as it cools and spreads.
    plume = []
    for i in range(16):
        t = i / 15
        x = cx + t * 210 + math.sin(t * 4.0) * 40
        y = cy - 60 - t * 700
        s_ = 70 + t * 150
        col = mix("#2c0c08", "#56201a", t * 0.6)
        for k in range(5):
            a = math.tau * k / 5 + i
            plume.append(circle(x + math.cos(a) * s_ * 0.45,
                                y + math.sin(a) * s_ * 0.3, s_ * rng.uniform(0.45, 0.62),
                                col))
    b.append("".join(plume))
    b.append(circle(cx, cy - 10, 260, "url(#glow)"))

    far = mix("#3a110a", "#b23d10", 0.35)
    b.append(poly(ridge(rng, 1000, 36, 26, jag=0.8), far))
    # The cone.
    b.append(poly([(150, 1150), (cx - 70, cy), (cx - 38, cy + 8), (cx + 38, cy + 6),
                   (cx + 76, cy), (1060, 1150)], "#2a0b07"))
    # Its lit flank, facing the lava below.
    b.append(poly([(cx + 76, cy), (1060, 1150), (880, 1150), (cx + 30, cy + 40)],
                  "#3b120a"))
    # Lava running down it: smooth rivulets, a dark crust edge and a hot core.
    for d in (f"M{cx - 24},{cy + 6} C{cx - 40},{cy + 90} {cx - 10},{cy + 150} "
              f"{cx - 60},{cy + 230} S{cx - 60},{cy + 340} {cx - 110},{cy + 400}",
              f"M{cx + 26},{cy + 6} C{cx + 50},{cy + 80} {cx + 30},{cy + 140} "
              f"{cx + 80},{cy + 220} S{cx + 120},{cy + 330} {cx + 170},{cy + 400}",
              f"M{cx + 4},{cy + 8} C{cx + 10},{cy + 70} {cx - 4},{cy + 120} "
              f"{cx + 12},{cy + 190}"):
        for wdt, col in ((20, "#7a1e08"), (11, "#e2480f"), (4, "#ffc15a")):
            b.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{wdt}" '
                     f'stroke-linecap="round"/>')
    b.append(poly([(cx - 70, cy), (cx - 38, cy + 8), (cx + 38, cy + 6), (cx + 76, cy),
                   (cx + 40, cy - 8), (cx - 40, cy - 8)], "#ffb347"))

    mid = "#1f0805"
    b.append(poly(ridge(rng, 1150, 40, 30, jag=0.9), mid))
    # Basalt columns at both edges: hexagonal tops catching the lava light.
    for side in (0, 1):
        x = -20 if side == 0 else W + 20
        tops = [560, 760, 640, 900, 820, 1040] if side == 0 else [620, 820, 700, 980, 880]
        for top in tops:
            cw = rng.uniform(48, 70)
            top += rng.uniform(-30, 30)
            if side:
                x -= cw
            b.append(rect(x, top, cw, H - top, "#140504"))
            b.append(poly([(x, top), (x + cw * 0.25, top - 14), (x + cw * 0.75, top - 14),
                           (x + cw, top), (x + cw * 0.75, top + 12),
                           (x + cw * 0.25, top + 12)], "#4a170b"))
            b.append(line(x + cw * 0.25, top - 14, x + cw * 0.75, top - 14,
                          "#ff7a2a", 2, 0.7))
            # Seams where the column fractured.
            for _ in range(2):
                sy = rng.uniform(top + 60, H)
                b.append(line(x + 4, sy, x + cw - 4, sy + rng.uniform(-6, 6),
                              "#2a0b07", 3))
            if not side:
                x += cw
    # The river of lava across the floor, crusted.
    river = smooth_band(lambda x: 1300 + math.sin(x / 120) * 30)
    b.append(poly(river, "#1a0604"))
    b.append(path("M-20,1360 C200,1300 300,1420 480,1370 S760,1300 920,1350 "
                  "L920,1420 C760,1380 640,1470 460,1440 S160,1390 -20,1440 Z",
                  "#e0460f"))
    b.append(path("M-20,1385 C200,1330 300,1440 480,1395 S760,1325 920,1375",
                  "none", extra=' stroke="#ffc15a" stroke-width="5"'))
    for _ in range(18):
        x = rng.uniform(0, W)
        y = 1380 + math.sin(x / 120) * 20 + rng.uniform(-10, 30)
        s = rng.uniform(10, 26)
        b.append(poly([(x - s, y), (x - s * 0.3, y - s * 0.5), (x + s, y - s * 0.2),
                       (x + s * 0.4, y + s * 0.4)], "#3a0f07", 0.9))
    return svg("".join(b), defs)


def ocean():
    rng = random.Random(37)
    defs = vgrad("sea", [(0, "#3ba7c9"), (0.12, "#1b7fa8"), (0.4, "#0c4d73"),
                         (0.75, "#062a45"), (1, "#031627")])
    b = [rect(0, 0, W, H, "url(#sea)")]
    # The surface seen from below: a bright wavering band.
    b.append(path("M0,0 L900,0 L900,70 " + " ".join(
        f"Q{f(900 - i * 75 - 37)},{f(90 if i % 2 else 50)} {f(900 - (i + 1) * 75)},70"
        for i in range(12)) + " Z", "#7fd3ea", 0.55))
    # Shafts of light, fanned from a point above the surface.
    for i in range(9):
        x = 60 + i * 100 + rng.uniform(-30, 30)
        w0 = rng.uniform(20, 60)
        b.append(poly([(x, 60), (x + w0, 60), (x + w0 * 3 + 160, 1200),
                       (x + 120, 1200)], "#bdf0ff", rng.uniform(0.03, 0.07)))

    # Far rock shelves.
    for base, fill in ((820, "#0d4a6b"), (980, "#0a3b58")):
        b.append(poly(ridge(rng, base, 60, 14, jag=0.3), fill, 0.9))

    # A school of fish in the open water, all heading one way.
    for _ in range(26):
        x = rng.uniform(480, 860)
        y = rng.uniform(420, 700)
        s = rng.uniform(7, 13)
        b.append(path(f"M{f(x)},{f(y)} q{f(s)},{f(-s * 0.55)} {f(s * 2)},0 "
                      f"q{f(-s)},{f(s * 0.55)} {f(-s * 2)},0 Z "
                      f"M{f(x + s * 2)},{f(y)} l{f(s * 0.8)},{f(-s * 0.45)} "
                      f"l0,{f(s * 0.9)} Z", "#9bdcef", 0.55))

    # Rock towers at both edges, with coral on their ledges.
    def tower(x0, x1, top, fill):
        pts_ = [(x0, H + 10)]
        y = H
        steps = 12
        for i in range(steps + 1):
            t = i / steps
            y = top + (H - top) * (1 - t) ** 1.4
            xx = x1 + (x0 - x1) * (1 - t) ** 0.8 + rng.uniform(-18, 18)
            pts_.append((xx, y))
        pts_.append((x0, top - 20))
        return poly(pts_, fill)

    b.append(poly([(-20, 560), (60, 520), (140, 600), (210, 780), (250, 1000),
                   (230, 1200), (300, 1600), (-20, 1600)], "#083450"))
    b.append(poly([(920, 620), (840, 600), (760, 700), (700, 900), (690, 1100),
                   (620, 1600), (920, 1600)], "#083450"))
    b.append(poly([(-20, 800), (40, 790), (120, 880), (170, 1080), (150, 1300),
                   (200, 1600), (-20, 1600)], "#052339"))
    b.append(poly([(920, 860), (860, 850), (790, 960), (770, 1150), (720, 1600),
                   (920, 1600)], "#052339"))

    def coral(x, y, s, fill, depth=4, ang=-90):
        out = []

        def br(x, y, a, l, d):
            x2 = x + math.cos(math.radians(a)) * l
            y2 = y + math.sin(math.radians(a)) * l
            out.append(line(x, y, x2, y2, fill, max(2.5, d * 2.6)))
            if d == 0:
                out.append(circle(x2, y2, 4.5, fill))
                return
            for da in (-28, 24):
                br(x2, y2, a + da + rng.uniform(-10, 10), l * 0.72, d - 1)
        br(x, y, ang, s, depth)
        return "".join(out)

    for x, y, s, c in ((70, 800, 46, "#c05a78"), (150, 620, 30, "#a24d6d"),
                       (820, 880, 50, "#d9745a"), (740, 720, 30, "#b25e52"),
                       (40, 1080, 60, "#e0708c"), (860, 1150, 58, "#f08c5a")):
        b.append(coral(x, y, s, c))
    # Kelp, rising from the floor at the edges and bending with the swell.
    for x0 in (20, 55, 100, 790, 830, 870):
        top = rng.uniform(700, 900)
        d = [f"M{f(x0)},{H}"]
        for k in range(8):
            t = (k + 1) / 8
            y = H - (H - top) * t
            d.append(f"Q{f(x0 + (40 if k % 2 else -40))},{f(y + (H - top) / 16)} "
                     f"{f(x0 + math.sin(t * 3) * 14)},{f(y)}")
        b.append(f'<path d="{" ".join(d)}" fill="none" stroke="#1f7a5c" '
                  f'stroke-width="12" stroke-linecap="round" opacity="0.9"/>')
    # The sand, with ripples.
    b.append(poly(smooth_band(lambda x: 1360 + math.sin(x / 110) * 18), "#0b3a50"))
    for i in range(7):
        y = 1400 + i * 28
        b.append(path(f"M-10,{y} " + " ".join(
            f"q30,-10 60,0" for _ in range(17)), "none",
            extra=' stroke="#11506b" stroke-width="3" opacity="0.7"'))
    return svg("".join(b), defs)


def space():
    rng = random.Random(41)
    defs = vgrad("sky", [(0, "#06031a"), (0.5, "#130833"), (1, "#1f0d45")])
    defs += ('<clipPath id="planet"><circle cx="40" cy="1420" r="560"/></clipPath>')
    b = [rect(0, 0, W, H, "url(#sky)")]
    # Two faint dust lanes crossing the field, flat ellipses at low alpha.
    for cx, cy, rx, ry, rot, col in ((520, 520, 520, 110, -28, "#7a3fd4"),
                                     (380, 700, 460, 70, -24, "#c14fd6")):
        b.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" '
                 f'transform="rotate({rot} {cx} {cy})" fill="{col}" opacity="0.08"/>')
    b.append(stars(rng, 320, 0, 0, W, H, "#efe6ff", 0.7, 2.4, 0.25, 0.95))
    # A constellation, charted: points joined by thin lines.
    cons = [(110, 300), (170, 230), (250, 260), (300, 180), (380, 210), (250, 340)]
    for (x1, y1), (x2, y2) in zip(cons, cons[1:4] + [cons[4]]):
        b.append(line(x1, y1, x2, y2, "#b9a6ff", 1.5, 0.45))
    b.append(line(250, 260, 250, 340, "#b9a6ff", 1.5, 0.45))
    for x, y in cons:
        b.append(circle(x, y, 3.2, "#f3edff"))
    for x, y, s in ((760, 180, 14), (640, 420, 9), (120, 620, 10), (820, 560, 8)):
        b.append(sparkle(x, y, s, "#ffffff", 0.9))

    # A small moon at the upper right.
    b.append(circle(760, 330, 64, "#cbb8f0"))
    b.append(path("M760,266 A64,64 0 0 1 760,394 A44,64 0 0 0 760,266 Z",
                  "#7e63b8"))
    for x, y, r in ((740, 300, 10), (778, 350, 7), (735, 360, 5)):
        b.append(circle(x, y, r, "#a893d8"))

    # The planet, banded, rising out of the lower left.
    band_cols = ["#6b3fb5", "#8a55cf", "#5a2f9c", "#a06bdc", "#7446bf", "#4e2a8a"]
    bands = []
    y = 860
    i = 0
    while y < 2000:
        h = rng.uniform(40, 110)
        bands.append(f'<path d="M-600,{f(y)} Q40,{f(y - 90)} 700,{f(y)} L700,{f(y + h)} '
                     f'Q40,{f(y + h - 90)} -600,{f(y + h)} Z" fill="{band_cols[i % 6]}"/>')
        y += h
        i += 1
    b.append(f'<g clip-path="url(#planet)">{"".join(bands)}'
             # The night side: a crescent of shadow on the right-hand limb.
             # The night side: a thick ring centred up and left of the planet
             # only lands on its far limb, which makes the crescent.
             f'<circle cx="-90" cy="1500" r="720" fill="none" stroke="#12062a" '
             f'stroke-width="300" opacity="0.55"/></g>')
    # Its rings, tilted, passing in front of the body at the bottom.
    for r, wdt, col, a in ((700, 10, "#d7c2ff", 0.55), (760, 4, "#efe4ff", 0.4),
                           (820, 16, "#9c7ae0", 0.35)):
        b.append(f'<ellipse cx="40" cy="1420" rx="{r}" ry="{r * 0.2}" '
                 f'transform="rotate(-18 40 1420)" fill="none" stroke="{col}" '
                 f'stroke-width="{wdt}" opacity="{a}"/>')
    # Orbits, as a star chart would draw them, round the sun we cannot see.
    for r in (1000, 1180, 1420):
        b.append(ring(1100, -200, r, "#a88cff", 1.2, 0.18, "3 9"))
    return svg("".join(b), defs)


def cyber():
    rng = random.Random(53)
    defs = vgrad("sky", [(0, "#05051a"), (0.45, "#150a38"), (0.66, "#3a0f5a"),
                         (0.72, "#5a1470"), (1, "#0a0620")])
    b = [rect(0, 0, W, H, "url(#sky)")]
    b.append(stars(rng, 40, 0, 0, W, 500, "#c8d6ff", 0.6, 1.4, 0.15, 0.5))

    neon = ["#22e8ff", "#ff2fd0", "#ffd166", "#7df5ff"]

    def building(x, w, top, fill, lit, win=(10, 14), gap=(8, 10), sign=False):
        out = [rect(x, top, w, H - top, fill)]
        # Windows on a grid, a quarter of them lit.
        wx, wy = win
        gx, gy = gap
        cols = int((w - gx) // (wx + gx))
        rows = int((1150 - top) // (wy + gy))
        ox = x + (w - cols * (wx + gx) + gx) / 2
        for r in range(max(0, rows)):
            for c in range(cols):
                if rng.random() < lit:
                    col = rng.choice(neon[:3] + ["#ffe8b0", "#ffe8b0"])
                    out.append(rect(ox + c * (wx + gx), top + 16 + r * (wy + gy), wx, wy,
                                    col, rng.uniform(0.35, 0.8)))
        if sign:
            sx = x + (w * 0.15 if rng.random() < 0.5 else w * 0.6)
            sh = rng.uniform(140, 260)
            sy = top + rng.uniform(40, 160)
            col = rng.choice(neon[:2])
            out.append(rect(sx - 6, sy - 6, 34, sh + 12, col, 0.18, rx=6))
            out.append(rect(sx, sy, 22, sh, "#0b0726", rx=4))
            out.append(f'<rect x="{f(sx)}" y="{f(sy)}" width="22" height="{f(sh)}" '
                       f'rx="4" fill="none" stroke="{col}" stroke-width="3"/>')
            # Glyph bars rather than letters: a sign nobody can misread.
            k = sy + 14
            while k < sy + sh - 18:
                bh = rng.choice((8, 14, 20))
                out.append(rect(sx + 6, k, 10, bh, col, 0.85, rx=2))
                k += bh + 8
        # A mast and a warning light on the roof.
        if rng.random() < 0.5:
            mx = x + w * rng.uniform(0.3, 0.7)
            out.append(line(mx, top, mx, top - rng.uniform(40, 90), fill, 4))
        return "".join(out)

    # Far skyline, hazed into the sky.
    x = -20
    while x < W:
        w = rng.uniform(40, 90)
        top = rng.uniform(820, 980)
        b.append(building(x, w, top, "#2a1250", 0.12, (5, 7), (6, 7)))
        x += w + rng.uniform(0, 6)
    # A spire in the middle distance.
    b.append(poly([(450, 520), (470, 760), (430, 760)], "#1c0c3e"))
    b.append(rect(420, 760, 60, 500, "#1c0c3e"))
    b.append(circle(450, 520, 6, "#ff2fd0"))
    # Middle skyline.
    x = -30
    while x < W:
        w = rng.uniform(70, 130)
        top = rng.uniform(760, 900)
        b.append(building(x, w, top, "#170a36", 0.2, (7, 10), (7, 9)))
        x += w + rng.uniform(4, 20)
    # An elevated line crossing the city.
    b.append(rect(-10, 1055, W + 20, 20, "#0e0628"))
    b.append(line(-10, 1055, W + 10, 1055, "#22e8ff", 2, 0.6))
    for px in range(20, W, 140):
        b.append(rect(px, 1075, 16, 120, "#0e0628"))
    # Near towers at the edges carry the signs.
    b.append(building(-40, 250, 380, "#0c0622", 0.22, (12, 16), (9, 12), sign=True))
    b.append(building(650, 290, 300, "#0c0622", 0.22, (12, 16), (9, 12), sign=True))
    b.append(building(170, 90, 700, "#10072c", 0.18, (9, 12), (8, 10)))
    b.append(building(600, 70, 640, "#10072c", 0.18, (9, 12), (8, 10)))

    # Wet street in perspective.
    b.append(rect(0, 1190, W, H - 1190, "#090420"))
    vx, vy = 450, 1060
    for i in range(-10, 11):
        x2 = 450 + i * 150
        b.append(line(vx + (x2 - vx) * 0.12, 1190, x2, H, "#ff2fd0", 2, 0.22))
    y = 1190
    step = 10
    while y < H:
        b.append(line(0, y, W, y, "#22e8ff", 1.5, 0.18))
        step *= 1.35
        y += step
    # Reflections of the signs in the wet road.
    for x, col in ((60, "#22e8ff"), (170, "#ff2fd0"), (720, "#ff2fd0"),
                   (820, "#22e8ff")):
        b.append(rect(x, 1200, 16, 320, col, 0.12, rx=8))
    return svg("".join(b), defs)


def clouds():
    rng = random.Random(61)
    defs = vgrad("sky", [(0, "#2a78c6"), (0.35, "#4f9ee0"), (0.7, "#9fd0f3"),
                         (1, "#e6f4fd")])
    b = [rect(0, 0, W, H, "url(#sky)")]
    b.append(circle(720, 250, 180, "#fffbe6", 0.12))
    b.append(circle(720, 250, 110, "#fffbe6", 0.22))
    b.append(circle(720, 250, 62, "#fffdf3"))

    # Banks of cloud, back to front, heaviest at the edges.
    banks = [
        (1000, "#cfe6f8", 16, (70, 130)),
        (1120, "#e2f0fb", 12, (100, 170)),
        (1260, "#f2f8fe", 9, (130, 220)),
    ]
    for base, fill, n, (smin, smax) in banks:
        b.append(rect(-20, base, W + 40, H - base, fill))
        for i in range(n):
            x = -60 + (W + 120) * i / (n - 1) + rng.uniform(-30, 30)
            s = rng.uniform(smin, smax)
            b.append(cloud(x, base + 10, s, fill, rng))
    # Towers of cumulus up both sides, shaded underneath.
    for side, xs in ((0, (40, 150)), (1, (860, 750))):
        for j, x in enumerate(xs):
            for k in range(4):
                y = 1000 - k * 170 - j * 60
                s = 170 - k * 26 - j * 20
                b.append(cloud(x + (k * 16 if side == 0 else -k * 16), y + 40, s,
                               "#c4dcf1", rng))
                b.append(cloud(x + (k * 16 if side == 0 else -k * 16), y, s,
                               "#ffffff", rng))
    # A small, flat cloud crossing the open sky.
    b.append(cloud(420, 520, 70, "#ffffff", rng, lobes=5))
    b.append(cloud(560, 700, 46, "#f4faff", rng, lobes=4))
    # Birds.
    for _ in range(7):
        x = rng.uniform(300, 640)
        y = rng.uniform(300, 460)
        s = rng.uniform(7, 12)
        b.append(path(f"M{f(x - s)},{f(y)} q{f(s * 0.5)},{f(-s * 0.6)} {f(s)},0 "
                      f"q{f(s * 0.5)},{f(-s * 0.6)} {f(s)},0", "none",
                      extra=' stroke="#1e4f80" stroke-width="2.4" opacity="0.7" '
                            'stroke-linecap="round"'))
    return svg("".join(b), defs)


def desert():
    rng = random.Random(71)
    b = []
    # A banded sunset sky, the way a printed poster would do it.
    bands = ["#2a0f24", "#4a1628", "#76222a", "#a8392b", "#d25e2d", "#ec8a3b",
             "#f6b25a"]
    y = 0
    for i, col in enumerate(bands):
        h = 120 + i * 22
        b.append(rect(0, y, W, h + 2, col))
        y += h
    b.append(rect(0, y, W, H - y, bands[-1]))
    # The sun, low and large.
    b.append(circle(450, 1000, 230, "#ffd98a", 0.18))
    b.append(circle(450, 1000, 160, "#ffe3a3"))

    # Mesas, far to near. Flat tops and scree skirts.
    def mesa(x0, x1, top, base, fill, cap):
        w = x1 - x0
        return (poly([(x0 - w * 0.18, base), (x0, top + 30), (x0 + w * 0.06, top),
                       (x1 - w * 0.06, top), (x1, top + 36), (x1 + w * 0.22, base)], fill)
                + rect(x0 + w * 0.06, top, w * 0.88, 8, cap))

    far = mix("#9a3a24", "#f6b25a", 0.35)
    b.append(poly(ridge(rng, 1090, 10, 20, jag=0.2), far))
    b.append(mesa(80, 260, 930, 1100, far, mix(far, "#ffd98a", 0.3)))
    b.append(mesa(640, 780, 960, 1100, far, mix(far, "#ffd98a", 0.3)))
    midc = "#7a2c1e"
    b.append(mesa(-60, 170, 760, 1180, midc, "#b5472b"))
    b.append(mesa(720, 960, 700, 1180, midc, "#b5472b"))
    # Strata lines across the near mesas.
    for y in (840, 900, 980, 1060):
        b.append(line(-40, y, 170 + (y - 760) * 0.2, y, "#6a2419", 4, 0.8))
        b.append(line(740 - (y - 700) * 0.1, y, 920, y, "#6a2419", 4, 0.8))
    # Dunes in the foreground, each with a lit face and a shadow face.
    for base, amp, per, lit, shade in ((1180, 30, 200, "#c7652e", "#9a4523"),
                                       (1260, 40, 260, "#a64d25", "#7c3419"),
                                       (1360, 46, 300, "#7d3419", "#5a2211")):
        ph = rng.uniform(0, 6)
        fn = (lambda x, base=base, amp=amp, per=per, ph=ph:
              base + math.sin(x / per * math.pi + ph) * amp)
        b.append(poly(smooth_band(fn), lit))
        # The shadow side: the same crest shifted down and clipped by eye.
        fn2 = (lambda x, fn=fn, per=per: fn(x) + 18 + 22 * max(0.0, math.cos(x / per * math.pi)))
        b.append(poly(smooth_band(fn2), shade, 0.8))
    # Saguaro at the edges.

    def saguaro(x, base, h, fill):
        w = h * 0.12
        out = [rect(x - w / 2, base - h, w, h, fill, rx=w / 2)]
        for side, at, arm in ((-1, 0.55, 0.3), (1, 0.4, 0.38)):
            ay = base - h * at
            ax = x + side * w * 1.6
            out.append(rect(min(x, ax) - (0 if side > 0 else 0), ay - w * 0.5,
                            abs(ax - x) + w * 0.5, w, fill, rx=w / 2))
            out.append(rect(ax - w / 2, ay - h * arm, w, h * arm, fill, rx=w / 2))
        return "".join(out)

    b.append(saguaro(90, 1330, 330, "#3a1409"))
    b.append(saguaro(820, 1300, 260, "#3a1409"))
    b.append(saguaro(200, 1270, 120, "#5a2211"))
    for _ in range(14):
        x = rng.choice((rng.uniform(0, 250), rng.uniform(650, 900)))
        y = rng.uniform(1300, 1460)
        s = rng.uniform(10, 22)
        b.append(poly([(x - s, y), (x - s * 0.3, y - s * 0.7), (x + s * 0.5, y - s * 0.6),
                       (x + s, y)], "#4a1a0c"))
    return svg("".join(b), "")


def aurora():
    rng = random.Random(83)
    defs = vgrad("sky", [(0, "#020914"), (0.45, "#05203a"), (0.7, "#0b3a52"),
                         (1, "#0a2a3f")])
    defs += ('<linearGradient id="veil" x1="0" y1="0" x2="0" y2="1">'
             '<stop offset="0" stop-color="#6affd8" stop-opacity="0"/>'
             '<stop offset="0.7" stop-color="#3ff0c4" stop-opacity="0.35"/>'
             '<stop offset="1" stop-color="#2ee6c0" stop-opacity="0"/></linearGradient>')
    b = [rect(0, 0, W, H, "url(#sky)")]
    b.append(stars(rng, 220, 0, 0, W, 1000, "#e6fbff", 0.6, 2.0, 0.2, 0.9))
    # A still curtain of aurora: narrow vertical strips hung along a curve,
    # each one a gradient that fades out at both ends.
    def curve(t, k):
        return (420 + math.sin(t * 5.2) * 90 + math.sin(t * 13) * 20
                - k * (26 + math.sin(t * 7 + 1) * 10 + math.sin(t * 17) * 4))

    steps = 80
    for k, (col, a) in enumerate((("#2ee6c0", 0.30), ("#3ff0c4", 0.24),
                                  ("#5cf5cf", 0.19), ("#79f7d8", 0.15),
                                  ("#8ff5e0", 0.11), ("#a8f0ff", 0.08),
                                  ("#b89cff", 0.06), ("#c79cff", 0.04))):
        top = [(-40 + 980 * i / steps, curve(i / steps, k + 1)) for i in range(steps + 1)]
        bot = [(-40 + 980 * i / steps, curve(i / steps, k) + (18 if k == 0 else 0))
               for i in range(steps, -1, -1)]
        b.append(poly(top + bot, col, a))
    # Mountains: each peak split into a lit face and a shadow face.
    def peak(x, top, half, base, lit, shade, snow):
        out = [poly([(x - half, base), (x, top), (x + half, base)], shade)]
        out.append(poly([(x - half, base), (x, top), (x + half * 0.1, base)], lit))
        s = (base - top) * 0.28
        out.append(poly([(x, top), (x - half * s / (base - top), top + s),
                         (x - half * 0.12, top + s * 0.8), (x + half * 0.05, top + s * 1.1),
                         (x + half * s / (base - top), top + s)], snow))
        return "".join(out)

    for x, top, half, base, k in ((120, 700, 330, 1150, 0.55), (560, 760, 300, 1150, 0.55),
                                  (860, 640, 280, 1150, 0.55),
                                  (-20, 820, 300, 1180, 0.25), (380, 880, 260, 1180, 0.25),
                                  (760, 820, 300, 1180, 0.25)):
        sky = "#0b3a52"
        b.append(peak(x, top, half, base, mix("#3e6a86", sky, k), mix("#1c3c54", sky, k),
                      mix("#dff4ff", sky, k * 0.8)))
    # The frozen lake, with the range upside down in it, faintly.
    b.append(rect(0, 1150, W, 200, "#06243a"))
    for x, top, half in ((120, 700, 330), (560, 760, 300), (860, 640, 280)):
        b.append(poly([(x - half, 1150), (x, 1150 + (1150 - top) * 0.45),
                       (x + half, 1150)], "#0d3450", 0.8))
    for i in range(10):
        y = 1170 + i * 17
        x = rng.uniform(100, 700)
        b.append(line(x, y, x + rng.uniform(60, 200), y, "#9ff7e2", 2, 0.18))
    # Snowbank and firs in front.
    b.append(poly(smooth_band(lambda x: 1330 + math.sin(x / 130) * 20), "#c9e2ee"))
    b.append(poly(smooth_band(lambda x: 1360 + math.sin(x / 100 + 1) * 16), "#8fb6c9"))
    for x, h in ((-10, 700), (70, 520), (130, 360), (800, 560), (880, 760),
                 (740, 380)):
        b.append(pine(x, 1400, h, h * 0.34, "#031019", tiers=6))
    return svg("".join(b), defs)


def nexus():
    rng = random.Random(97)
    gold = "#ffc850"
    defs = vgrad("sky", [(0, "#07061a"), (0.5, "#1a1236"), (0.8, "#2c1e48"),
                         (1, "#120c24")])
    defs += rgrad("halo", [(0, "#ffd77a", 0.35), (0.4, "#c9973f", 0.12),
                           (1, "#c9973f", 0)])
    b = [rect(0, 0, W, H, "url(#sky)")]
    b.append(stars(rng, 120, 0, 0, W, 900, "#fff3d6", 0.6, 1.8, 0.2, 0.7))
    cx, cy = 450, 720
    b.append(circle(cx, cy, 520, "url(#halo)"))
    # The seal: rings, a tick ring, and two squares turned against each other.
    for r, wdt, a, dash in ((430, 2, 0.5, ""), (400, 1.2, 0.35, "2 10"),
                            (350, 3, 0.55, ""), (250, 1.5, 0.4, ""),
                            (180, 1.2, 0.3, "6 6")):
        b.append(ring(cx, cy, r, gold, wdt, a, dash))
    for i in range(48):
        a = math.tau * i / 48
        r0 = 350 if i % 4 else 332
        b.append(line(cx + math.cos(a) * r0, cy + math.sin(a) * r0,
                      cx + math.cos(a) * 372, cy + math.sin(a) * 372, gold,
                      2 if i % 4 else 3, 0.5))
    for rot in (0, 45):
        pts_ = [(cx + math.cos(math.radians(rot + 90 * k)) * 350,
                 cy + math.sin(math.radians(rot + 90 * k)) * 350) for k in range(4)]
        b.append(f'<polygon points="{pts(pts_)}" fill="none" stroke="{gold}" '
                 f'stroke-width="1.6" opacity="0.4"/>')
        for x, y in pts_:
            b.append(circle(x, y, 9, "#1a1236"))
            b.append(ring(x, y, 9, gold, 2, 0.8))
    # Stones hanging in the air round the seal.
    for _ in range(14):
        x = rng.choice((rng.uniform(20, 230), rng.uniform(670, 880)))
        y = rng.uniform(300, 1050)
        s = rng.uniform(12, 34)
        pts_ = [(x + math.cos(a) * s * rng.uniform(0.7, 1.1),
                 y + math.sin(a) * s * rng.uniform(0.5, 0.9))
                for a in [math.tau * k / 6 + rng.uniform(-0.3, 0.3) for k in range(6)]]
        b.append(poly(pts_, "#2e2350"))
        b.append(line(pts_[4][0], pts_[4][1], pts_[5][0], pts_[5][1], gold, 2, 0.6))
    # Two pillars at the edges with gold bands.
    for x0 in (-10, 760):
        b.append(rect(x0, 380, 150, H - 380, "#1b1433"))
        b.append(rect(x0 - 16, 350, 182, 40, "#241a42"))
        b.append(rect(x0 - 16, 350, 182, 4, gold, 0.7))
        for y in range(520, 1300, 190):
            b.append(rect(x0, y, 150, 6, gold, 0.35))
            b.append(circle(x0 + 75, y + 60, 14, "none",
                            extra=f' stroke="{gold}" stroke-width="2" opacity="0.4"'))
    # A floor of flagstones in perspective.
    b.append(rect(0, 1180, W, H - 1180, "#120c24"))
    for i in range(-8, 9):
        b.append(line(cx + i * 20, 1180, cx + i * 170, H, gold, 1.5, 0.2))
    y, step = 1180, 14
    while y < H:
        b.append(line(0, y, W, y, gold, 1.2, 0.18))
        step *= 1.3
        y += step
    return svg("".join(b), defs)


SCENES = {
    "forest": forest, "volcano": volcano, "ocean": ocean, "space": space,
    "cyber": cyber, "clouds": clouds, "desert": desert, "aurora": aurora,
    "nexus": nexus,
}


def main():
    names = sys.argv[1:] or list(SCENES)
    SRC.mkdir(parents=True, exist_ok=True)
    # Previews, not game assets: keep Godot from importing them.
    (OUT / ".gdignore").touch()
    for name in names:
        src = SRC / f"{name}.svg"
        src.write_text(SCENES[name]())
        png = OUT / f"{name}.png"
        subprocess.run(["resvg", "--width", str(W), "--height", str(H), str(src),
                        str(png)], check=True)
        print(f"[board_art] {png}")


if __name__ == "__main__":
    main()
