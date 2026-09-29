"""Aurora: the Aurora board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/aurora.py

Writes boards/3d/aurora.glb (what the game loads for Aurora) and
build/boards3d/aurora.blend.

A winter night: a still lake between snow banks and pine woods, snowy peaks
behind, and the northern lights hung across the sky above them. A cabin on
the left shore has a lit window and smoke going up from its chimney.

What moves: the aurora's curtains, folding and swaying (shader), the lake
mirroring all of it (the reflection camera, as on the city's wet road), snow
falling (the game's snow sheets), the stars, the chimney smoke, and now and
then a shooting star.

The framing rules and the contract with the game are in `toonkit.py`.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toonkit as tk  # noqa: E402
import vehicles as vh  # noqa: E402
from toonkit import TAU, bm_object, keyframes, lathe, n3, new_bm, puff, smooth  # noqa: E402

PALETTE = {
    "Snow": "#eef4ff",
    "Lake": "#0c2040",
    "SnowPine": "#ffffff",
    "Trunk": "#4a3a3c",
    "Peak": "#ffffff",
    "Aurora": "#40ff90",
    "Cabin": "#6a4a3e",
    "Roof": "#eef4ff",
    "Window": "#ffc870",
    "Smoke": "#c8d2e8",
    "Meteor": "#e8f4ff",
    "Glow": "#ffffff",
}

tk.setup(PALETTE)
tk.camera(vfov=62.0, pitch=1.0, loc=(0.0, 0.0, 3.2), sway=(0.18, 0.05), turn=(0.12, 0.35))


def shore(y):
    """Half the lake's width at `y`, and its centre."""
    # Narrow near the camera, so the woods on both shores are in the frame
    # beside the board; opening out toward the mountains.
    return 6.5 + 2.5 * math.sin(y / 34.0 + 0.8) + 0.07 * y, 1.8 * math.sin(y / 47.0)


def ground_z(x, y):
    half, c = shore(y)
    dx = abs(x - c) - half
    if dx < 0:
        return -0.5
    z = 0.25 + 0.9 * (1.0 - math.exp(-dx / 2.2)) + 0.0045 * dx * dx
    z += 0.6 * n3(x / 9.0, y / 9.0, 2.1) * smooth(0, 6, dx)
    return z


def terrain():
    def col(x, y, z):
        k = 0.92 + 0.08 * n3(x / 4.0, y / 4.0, 5.5)
        return (k, k, min(1.0, k * 1.03), 1.0)
    tk.terrain("banks", "Snow", -90, 90, -8, 230, 90, 90, ground_z, col, ypow=1.5)
    bm, c = new_bm()
    vs = [bm.verts.new(p) for p in ((-90, -8, 0), (90, -8, 0), (90, 420, 0), (-90, 420, 0))]
    bm.faces.new(vs)
    bm_object("lake", bm, "Lake", recalc=False)


def snow_pine(bm, col, base, s, rnd):
    """A spruce with snow lying on each tier: the tops of the tiers white,
    their undersides dark."""
    lathe(bm, col, [(0.1 * s, -0.1 * s), (0.08 * s, 0.3 * s), (0.0, 0.35 * s)], 6,
          Matrix.Translation(base), color=lambda t: (0.28, 0.2, 0.2))
    green = (0.2, 0.42, 0.36)
    tiers = 4
    for k in range(tiers):
        f = k / tiers
        zb = (0.22 + f * 0.72) * s
        r = (0.55 - f * 0.34) * s
        hgt = (0.5 - f * 0.1) * s
        prof = [(0.0, zb + 0.06 * s), (r * 0.95, zb - 0.02 * s), (r, zb + 0.03 * s),
                (r * 0.6, zb + hgt * 0.32), (r * 0.25, zb + hgt * 0.72), (0.0, zb + hgt)]
        cols = [green, green, (0.8, 0.86, 0.95), (1.0, 1.0, 1.0), (1.0, 1.0, 1.0), (1.0, 1.0, 1.0)]
        verts = lathe(bm, col, prof, 9, Matrix.Translation(base),
                      color=lambda t, cols=cols: cols[min(int(round(t * 5)), 5)])
        # Snow lies lumpy, not in a perfect cone.
        for v in verts:
            if v.co.z > base.z + zb + 0.05 * s:
                v.co.x += 0.04 * s * n3(v.co.x * 3, v.co.y * 3, v.co.z)
                v.co.y += 0.04 * s * n3(v.co.y * 3, v.co.z * 3, v.co.x)


def woods():
    rnd = random.Random(7)
    bm, col = new_bm()
    # Fewer than the eye would guess: the lake shows every one twice.
    for i in range(210):
        y = rnd.uniform(12, 230)
        side = rnd.choice([-1, 1])
        half, c = shore(y)
        x = c + side * (half + 2.0 + rnd.uniform(0.0, 1.0) ** 1.8 * 60.0)
        if abs(x) > 88:
            continue
        s = rnd.uniform(4.5, 9.0) * (1.0 + 0.3 * smooth(40, 150, y))
        snow_pine(bm, col, Vector((x, y, ground_z(x, y) - 0.3)), s, rnd)
    # And a few tall ones near the camera, one either side, so the frame has
    # trees climbing its edges and not only along the horizon.
    for x, y, s in ((-9.5, 17.0, 13.0), (-12.5, 23.0, 11.0), (10.0, 19.0, 12.5),
                    (13.5, 26.0, 10.5), (-8.0, 30.0, 9.0), (9.0, 33.0, 8.5)):
        snow_pine(bm, col, Vector((x, y, ground_z(x, y) - 0.3)), s, rnd)
    bm_object("pines", bm, "SnowPine")


def peaks():
    rnd = random.Random(19)
    bm, col = new_bm()
    for k in range(18):
        x = rnd.uniform(-320, 320)
        y = rnd.uniform(380, 620)
        # Low enough that the lights have the sky above them.
        h = rnd.uniform(55, 110) * (1.0 - 0.3 * min(abs(x) / 320.0, 1.0))
        r = h * rnd.uniform(0.75, 1.05)
        prof = [(r, -2.0), (r * 0.62, h * 0.25), (r * 0.34, h * 0.55), (r * 0.12, h * 0.85), (0.0, h)]
        verts = lathe(bm, col, prof, 16, Matrix.Translation((x, y, 0)))
        for v in verts:
            u = max(0.0, v.co.z) / h
            v.co.x += 9.0 * n3(v.co.x * 0.04, v.co.y * 0.04, 3.3) * u
            v.co.y += 6.0 * n3(v.co.y * 0.05, v.co.x * 0.05, 1.1) * u
            # Snow on the upper slopes, dark rock showing on the ridges below.
            ridge = 0.5 + 0.5 * n3(v.co.x * 0.08, v.co.y * 0.08, v.co.z * 0.08)
            snow = smooth(0.25, 0.45, u + 0.25 * ridge)
            c = tk.mix((0.3, 0.33, 0.45), (0.95, 0.97, 1.0), snow)
            v[col] = c + (1.0,)
    bm_object("peaks", bm, "Peak")


def aurora():
    """Curtains: tall ribbons hung high and far off, each following a slow
    curve across the sky."""
    rnd = random.Random(29)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    specs = [(420.0, 95.0, 190.0, 0.0), (520.0, 120.0, 230.0, 1.7), (360.0, 150.0, 150.0, 3.1)]
    for y0, z0, H, ph in specs:
        N = 60
        pts = []
        for k in range(N + 1):
            u = k / N
            x = -520 + 1040 * u
            y = y0 + 90.0 * math.sin(u * 5.0 + ph) + 40.0 * math.sin(u * 11.0 + ph * 2.0)
            z = z0 + 25.0 * math.sin(u * 3.0 + ph)
            pts.append(Vector((x, y, z)))
        length = 0.0
        rows = []
        for k, p in enumerate(pts):
            if k:
                length += (p - pts[k - 1]).length
            rows.append((bm.verts.new(p), bm.verts.new(p + Vector((0, 0, H))), length, k / N))
        for a, b in zip(rows, rows[1:]):
            f = bm.faces.new((a[0], b[0], b[1], a[1]))
            for loop in f.loops:
                row = a if loop.vert in (a[0], a[1]) else b
                top = loop.vert is row[1]
                loop[uv].uv = (row[2], 0.0)
                loop[uv2].uv = (1.0 if top else 0.0, row[3])
    bm_object("aurora", bm, "Aurora", recalc=False)


def cabin():
    """A log cabin on the left shore, its window lit, smoke from the stack."""
    half, c = shore(62.0)
    x = c - half - 4.5
    y = 62.0
    z = ground_z(x, y) - 0.2
    bm, col = new_bm()
    w, d, h = 5.0, 4.0, 2.8
    v = [bm.verts.new((x + px, y + py, z + pz)) for px, py, pz in
         ((-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (-w / 2, d / 2, 0),
          (-w / 2, -d / 2, h), (w / 2, -d / 2, h), (w / 2, d / 2, h), (-w / 2, d / 2, h))]
    for q in v:
        q[col] = (1, 1, 1, 1)
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([v[i] for i in f])
    bm_object("cabin", bm, "Cabin")
    # A snowy roof, overhanging.
    bm, col = new_bm()
    o = 0.5
    r = [bm.verts.new((x + px, y + py, z + pz)) for px, py, pz in
         ((-w / 2 - o, -d / 2 - o, h - 0.1), (w / 2 + o, -d / 2 - o, h - 0.1),
          (w / 2 + o, d / 2 + o, h - 0.1), (-w / 2 - o, d / 2 + o, h - 0.1),
          (-w / 2 - o, 0, h + 2.0), (w / 2 + o, 0, h + 2.0))]
    for q in r:
        q[col] = (1, 1, 1, 1)
    for f in ((0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)):
        bm.faces.new([r[i] for i in f])
    bm_object("roof", bm, "Roof")
    bm, col = new_bm()
    for px in (-1.2, 1.2):
        vs = [bm.verts.new((x + px + a, y - d / 2 - 0.05, z + b)) for a, b in
              ((-0.45, 0.9), (0.45, 0.9), (0.45, 1.8), (-0.45, 1.8))]
        bm.faces.new(vs)
    bm_object("cabin_windows", bm, "Window", recalc=False)
    stack = Vector((x + 1.4, y + 0.6, z + h + 1.6))
    bm, col = new_bm()
    lathe(bm, col, [(0.0, -1.5), (0.3, -1.5), (0.3, 0.3), (0.0, 0.3)], 6, Matrix.Translation(stack))
    bm_object("chimney", bm, "Cabin")
    glow = vh.glow_quads([(Vector((x, y - d / 2 - 0.3, z + 1.35)), (1.0, 0.75, 0.4), 4.5)])
    bm_object("cabin_glow", glow, "Glow", recalc=False)
    rnd = random.Random(37)
    for i in range(7):
        bm, col = new_bm()
        for k in range(3):
            puff(bm, col, Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(-0.2, 0.3))),
                 rnd.uniform(0.35, 0.5), 2)
        o = bm_object("smoke_%d" % i, bm, "Smoke", loc=stack)
        phase = i / 7

        def f(t, phase=phase, i=i):
            u = (t * 2 + phase) % 1.0
            s = (0.5 + 2.2 * u) * smooth(0.0, 0.08, u) * (1.0 - smooth(0.75, 1.0, u))
            s = max(s, 0.001)
            return (stack + Vector((1.8 * u ** 1.4, 0.5 * u, 0.3 + 7.0 * u))
                    + Vector((0.25 * math.sin(TAU * 2 * u + i), 0, 0)), None, (s, s, s))
        keyframes(o, f, step=2)


def meteor():
    """A shooting star, once a loop, high over the peaks."""
    bm, col = new_bm()
    lathe(bm, col, [(0.0, -9.0), (0.25, -1.0), (0.45, 0.0), (0.0, 0.4)], 6,
          Matrix.Rotation(math.pi / 2, 4, 'Y'))
    o = bm_object("meteor", bm, "Meteor")
    a = tk.place(-0.7, 1.05, 300.0)
    b = tk.place(0.2, 0.8, 300.0)
    dirv = (b - a).normalized()
    yaw = math.atan2(dirv.y, dirv.x)
    pitch = -math.asin(dirv.z)

    def f(t):
        u = (t - 0.55) / 0.05
        if 0.0 <= u <= 1.0:
            s = math.sin(u * math.pi)
            return a + (b - a) * u, (0.0, pitch, yaw), (1.0, s, s)
        return a, (0.0, pitch, yaw), (0.001, 0.001, 0.001)
    keyframes(o, f, step=1)


def build():
    terrain()
    woods()
    peaks()
    aurora()
    cabin()
    meteor()


build()
tk.export("aurora")
