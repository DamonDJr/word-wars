"""Space: the Space board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/space.py

Writes boards/3d/space.glb (what the game loads for Space) and
build/boards3d/space.blend.

Out in an asteroid field: a violet nebula across the sky with a bright core
(the sky shader draws it, and the stars), a great banded planet low on the
right with a ring round it and a moon going round it, smaller worlds high
up, and rocks everywhere, near and far.

What moves: every asteroid tumbles on its own axis, some drift across the
field; the moon orbits; the planet's storms turn with it; a comet crosses
once a loop; the stars twinkle and the nebula churns, slowly.

The planet turns a third of a revolution a loop and carries three storms a
third of the way round from each other, so the loop comes round with the
same face. Its bands go round with latitude, so they look the same at any
turn. The framing rules and the contract with the game are in `toonkit.py`.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toonkit as tk  # noqa: E402
import vehicles as vh  # noqa: E402
from toonkit import TAU, bm_object, crossing, empty, keyframes, lathe, n3, new_bm, place, puff  # noqa: E402

PALETTE = {
    "Planet": "#ffffff",
    "Ring": "#ffffff",
    "Moon": "#d8d2ea",
    "Asteroid": "#8a7a9a",
    "Comet": "#e8f6ff",
    "Tail": "#bfe8ff",
    "Glow": "#ffffff",
}

tk.setup(PALETTE)
tk.camera(vfov=60.0, pitch=0.0, loc=(0.0, 0.0, 0.0), sway=(0.35, 0.2), turn=(0.4, 0.8),
          clip_end=3000.0)


def spin_keys(o, axis, turns, phase=0.0, step=2, loc_fn=None):
    """Key `o` turning `turns` times a loop about `axis`, the angles taken
    against the last frame's so they never jump a whole turn between keys."""
    last = [Euler((0.0, 0.0, 0.0))]
    axis = Vector(axis).normalized()

    def f(t):
        e = Matrix.Rotation(TAU * turns * t + phase, 3, axis).to_euler('XYZ', last[0])
        last[0] = e
        return (loc_fn(t) if loc_fn else None), e, None
    keyframes(o, f, step=step)


def planet():
    centre = place(0.92, -0.3, 240.0)
    root = empty("planet", centre)
    R = 58.0
    tilt = Matrix.Rotation(math.radians(24), 3, 'Y') @ Matrix.Rotation(math.radians(-12), 3, 'X')
    axis = tilt @ Vector((0, 0, 1))
    bm, col = new_bm()
    vs = puff(bm, col, Vector((0, 0, 0)), R, 5)
    band_a, band_b, band_c = (0.58, 0.42, 0.9), (0.82, 0.62, 1.0), (0.42, 0.32, 0.78)
    storms = [Vector((math.cos(TAU * k / 3), math.sin(TAU * k / 3), 0.25 - 0.25 * k)).normalized()
              for k in range(3)]
    for v in vs:
        d = v.co.normalized()
        lat = d.z
        w = lat * 7.0 + 0.6 * n3(lat * 3.0, 0.0, 1.7)
        k = 0.5 + 0.5 * math.sin(w)
        c = tk.mix(band_a, band_b, k)
        c = tk.mix(c, band_c, max(0.0, math.sin(w * 2.3 + 1.0)) ** 4)
        for sd in storms:
            g = max(0.0, d.dot(sd))
            c = tk.mix(c, (0.98, 0.78, 0.95), g ** 60)
        v[col] = c + (1.0,)
        v.co = tilt @ v.co
    body = bm_object("planet_body", bm, "Planet", root)
    spin_keys(body, axis, 1.0 / 3.0, step=4)
    # The ring: a flat band, bands of its own.
    bm, col = new_bm()
    rings = []
    for f, c in ((1.3, (0.8, 0.7, 0.95)), (1.42, (0.95, 0.85, 1.0)), (1.5, (0.7, 0.6, 0.9)),
                 (1.62, (0.9, 0.8, 1.0)), (1.72, (0.65, 0.55, 0.85))):
        ring = []
        for i in range(96):
            a = TAU * i / 96
            v = bm.verts.new(tilt @ Vector((R * f * math.cos(a), R * f * math.sin(a), 0)))
            v[col] = c + (1.0,)
            ring.append(v)
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(96):
            bm.faces.new((a[i], a[(i + 1) % 96], b[(i + 1) % 96], b[i]))
    bm_object("planet_ring", bm, "Ring", root, recalc=False)
    # A moon on a tilted orbit round it.
    bm, col = new_bm()
    craters(bm, col, Vector((0, 0, 0)), 9.0, 5)
    moon = bm_object("planet_moon", bm, "Moon", root)
    e1 = tilt @ Vector((1, 0, 0))
    e2 = tilt @ Vector((0, 1, 0))

    def loc(t):
        a = TAU * t + 0.8
        return (e1 * math.cos(a) + e2 * math.sin(a)) * R * 2.4 + axis * 12.0 * math.sin(a)
    spin_keys(moon, (0.2, 0.3, 1.0), 1.0, step=2, loc_fn=loc)


def craters(bm, col, centre, r, seed, rgb=(1, 1, 1)):
    """A cratered ball: dimples pressed in, their floors a shade darker."""
    rnd = random.Random(seed)
    vs = puff(bm, col, centre, r, 3)
    pits = [(Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized(),
             rnd.uniform(0.18, 0.4)) for _ in range(9)]
    for v in vs:
        d = (v.co - centre).normalized()
        dent = 0.0
        for p, s in pits:
            x = math.acos(max(-1.0, min(1.0, d.dot(p)))) / s
            if x < 1.0:
                dent = max(dent, 1.0 - x * x)
        k = 1.0 - 0.08 * dent + 0.05 * n3(d.x * 3 + seed, d.y * 3, d.z * 3)
        v.co = centre + d * r * k
        m = 1.0 - 0.28 * dent
        v[col] = (rgb[0] * m, rgb[1] * m, rgb[2] * m, 1.0)
    return vs


def worlds():
    for sx, sy, d, r, rgb, seed in ((0.55, 1.05, 420.0, 26.0, (0.9, 0.85, 1.0), 3),
                                    (0.82, 0.78, 380.0, 12.0, (0.8, 0.9, 1.0), 4),
                                    (-0.7, 0.2, 520.0, 16.0, (1.0, 0.82, 0.9), 6)):
        bm, col = new_bm()
        craters(bm, col, place(sx, sy, d), r, seed, rgb)
        bm_object("world_%d" % seed, bm, "Moon")


def asteroid(bm, col, r, seed):
    rnd = random.Random(seed)
    vs = craters(bm, col, Vector((0, 0, 0)), r, seed)
    stretch = Vector((rnd.uniform(0.8, 1.3), rnd.uniform(0.7, 1.1), rnd.uniform(0.6, 0.95)))
    for v in vs:
        v.co = Vector((v.co.x * stretch.x, v.co.y * stretch.y, v.co.z * stretch.z))
        v.co *= 1.0 + 0.18 * n3(v.co.x / r * 1.5 + seed, v.co.y / r * 1.5, v.co.z / r * 1.5)


def field():
    rnd = random.Random(11)
    n = 0
    # Placed by screen position: thick at the sides and top, thin in the
    # middle where the board is, near ones big and far ones small.
    for i in range(38):
        sx = rnd.choice([-1, 1]) * rnd.uniform(0.35, 1.15)
        sy = rnd.uniform(-0.4, 1.25)
        d = rnd.uniform(30, 320)
        r = rnd.uniform(0.012, 0.035) * d * (1.0 if abs(sx) > 0.6 else 0.6)
        bm, col = new_bm()
        asteroid(bm, col, r, 100 + i)
        home = place(sx, sy, d)
        o = bm_object("rock_%d" % i, bm, "Asteroid", loc=home)
        axis = (rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))
        turns = rnd.choice([1, 1, 2]) * rnd.choice([-1, 1])
        bob = r * 0.4
        ph = rnd.uniform(0, TAU)
        spin_keys(o, axis, turns, rnd.uniform(0, TAU), step=2,
                  loc_fn=lambda t, home=home, bob=bob, ph=ph:
                  home + Vector((bob * math.sin(TAU * t + ph), 0, bob * math.cos(TAU * t + ph))))
        n += 1
    # A few drifting right across the field, near.
    for i in range(4):
        bm, col = new_bm()
        r = rnd.uniform(1.2, 2.4)
        asteroid(bm, col, r, 300 + i)
        o = bm_object("drifter_%d" % i, bm, "Asteroid")
        sy = rnd.uniform(-0.2, 1.0)
        d = rnd.uniform(25, 45)
        row = place(0.0, sy, d)
        half = tk.half_width(d) * 1.3
        start = i / 4.0
        axis = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 1)).normalized()
        last = [Euler((0.0, 0.0, 0.0))]

        def f(t, row=row, half=half, start=start, axis=axis, last=last, direction=rnd.choice([-1, 1])):
            u, vis = crossing(t, start, 0.95)
            s = max(vis, 0.001)
            e = Matrix.Rotation(TAU * 2 * t, 3, axis).to_euler('XYZ', last[0])
            last[0] = e
            return row + Vector((direction * (-half + 2 * half * u), 0, 0)), e, (s, s, s)
        keyframes(o, f, step=1)


def comet():
    root = empty("comet", (0, 0, 0))
    bm, col = new_bm()
    puff(bm, col, Vector((0, 0, 0)), 1.6, 2)
    bm_object("comet_head", bm, "Comet", root)
    bm_object("comet_glow", vh.glow_quads([(Vector((0, 0, 0)), (0.7, 0.9, 1.0), 16.0)]), "Glow",
              root, recalc=False)
    a = place(-1.3, 1.1, 260.0)
    b = place(0.4, 0.55, 260.0)
    tail_dir = (a - b).normalized()
    bm_object("comet_tail", tk.ray_quads([(Vector((0, 0, 0)), tail_dir * 70.0, 5.0, (0.7, 0.9, 1.0), 0.2)]),
              "Tail", root, recalc=False)

    def f(t):
        u = (t - 0.2) / 0.5
        if 0.0 <= u <= 1.0:
            return a + (b - a) * u, None, (1.0, 1.0, 1.0)
        return a, None, (0.001, 0.001, 0.001)
    keyframes(root, f, step=2)


def build():
    planet()
    worlds()
    field()
    comet()


build()
tk.export("space")
