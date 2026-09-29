"""Desert: the Desert board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/desert.py

Writes boards/3d/desert.glb (what the game loads for Desert) and
build/boards3d/desert.blend.

Sundown in canyon country: sand in low dunes and a dry wash winding off
toward the horizon, sandstone buttes and spires in layered bands either side,
saguaros and prickly pear, and the sun sitting on the horizon under an
orange sky.

What moves: a tumbleweed bouncing across, vultures circling, clouds drifting,
the camera's drift; and the painted board's heat haze still shimmers over
the top.

The framing rules and the contract with the game are in `toonkit.py`.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toonkit as tk  # noqa: E402
import sky_islands as si  # noqa: E402
import vehicles as vh  # noqa: E402
from toonkit import (TAU, bm_object, cloud, crossing, empty, keyframes, lathe, n3,  # noqa: E402
                     new_bm, place, puff, smooth)

PALETTE = {
    "Sand": "#ffffff",
    "Mesa": "#ffffff",
    "Cactus": "#6aa84f",
    "Brush": "#8a8a4a",
    "Sun": "#ffe08a",
    "Glow": "#ffffff",
    "Cloud": "#ffd2a8",
    "Twig": "#a07a4a",
    "Bird": "#2a1a24",
    "Pebble": "#c07a5a",
}

tk.setup(PALETTE)
tk.camera(vfov=60.0, pitch=-3.0, loc=(0.0, 0.0, 4.5), sway=(0.2, 0.05), turn=(0.12, 0.35),
          clip_end=1600.0)


def wash_x(y):
    return 3.0 * math.sin(y / 26.0) + 5.0 * math.sin(y / 61.0 + 1.0)


def ground_z(x, y):
    dunes = 1.4 * n3(x / 22.0, y / 22.0, 1.0) + 0.6 * n3(x / 9.0, y / 9.0, 4.0)
    # Ripples across the dunes, the wind's own texture.
    dunes += 0.08 * math.sin((x * 0.4 + y * 0.9) * 1.3 + n3(x / 6, y / 6, 2.0) * 3.0)
    dx = abs(x - wash_x(y))
    wash = -1.1 * math.exp(-(dx / 4.5) ** 2)
    return dunes + wash + 0.004 * max(0.0, abs(x) - 20.0) ** 2


def ground_col(x, y, z):
    k = 0.5 + 0.5 * n3(x / 12.0, y / 12.0, 9.0)
    c = tk.mix((0.93, 0.62, 0.36), (0.98, 0.74, 0.46), k)
    dx = abs(x - wash_x(y))
    c = tk.mix((0.8, 0.5, 0.32), c, smooth(1.0, 5.0, dx))
    return c + (1.0,)


def terrain():
    tk.terrain("sand", "Sand", -140, 140, -6, 420, 90, 100, ground_z, ground_col, ypow=1.7)


def formation(bm, col, base, radius, height, seed, flat=True, spire=False):
    """A butte, a mesa or a spire: stacked bands of sandstone, each a little
    set in or out from the last, with a flat cap (or a point, for a spire)."""
    rnd = random.Random(seed)
    seg = 14
    bands = max(5, int(height / 3.5))
    rings = []
    rot = rnd.uniform(0, TAU)
    shape = [1.0 + 0.25 * n3(math.cos(TAU * i / seg) * 1.3 + seed, math.sin(TAU * i / seg) * 1.3, 0.5)
             for i in range(seg)]
    band_col = [(0.86, 0.42, 0.26), (0.95, 0.56, 0.32), (0.78, 0.36, 0.24), (0.98, 0.64, 0.38)]
    for b in range(bands + 1):
        t = b / bands
        if spire:
            r = radius * (1.0 - t) ** 0.7 + radius * 0.06
        else:
            r = radius * (1.0 - 0.18 * t) * (1.0 + (0.08 if b % 2 else -0.04) * rnd.random())
        z = height * t
        c = band_col[b % 4]
        ring = []
        for i in range(seg):
            a = rot + TAU * i / seg
            rr = r * shape[i]
            v = bm.verts.new(base + Vector((rr * math.cos(a), rr * math.sin(a), z)))
            v[col] = c + (1.0,)
            ring.append(v)
        rings.append(ring)
    cap = bm.verts.new(base + Vector((0, 0, height + (radius * 0.4 if spire else 0.2))))
    cap[col] = band_col[3] + (1.0,)
    rings.append([cap])
    tk.bridge_rings(bm, rings)


def rocks():
    rnd = random.Random(3)
    bm, col = new_bm()
    # The big butte on the left, spires on the right, the painting's framing.
    formation(bm, col, Vector((-24.0, 60.0, -1.0)), 11.0, 40.0, 11)
    formation(bm, col, Vector((-14.0, 38.0, -1.0)), 4.0, 22.0, 12, spire=True)
    formation(bm, col, Vector((18.0, 46.0, -1.0)), 5.5, 34.0, 13, spire=True)
    formation(bm, col, Vector((26.0, 70.0, -1.0)), 8.0, 46.0, 14, spire=True)
    formation(bm, col, Vector((13.0, 28.0, -1.0)), 3.0, 14.0, 15, spire=True)
    # Buttes in the middle distance, so the land steps back in layers.
    formation(bm, col, Vector((-34.0, 120.0, -1.5)), 16.0, 34.0, 16)
    formation(bm, col, Vector((40.0, 140.0, -1.5)), 14.0, 30.0, 17)
    formation(bm, col, Vector((-8.0, 175.0, -1.5)), 9.0, 24.0, 18, spire=True)
    # Mesas along the horizon.
    for i in range(14):
        x = rnd.uniform(-260, 260)
        y = rnd.uniform(220, 400)
        formation(bm, col, Vector((x, y, -2.0)), rnd.uniform(18, 40), rnd.uniform(18, 45),
                  30 + i, spire=rnd.random() < 0.25)
    bm_object("rocks", bm, "Mesa")
    # Boulders in the foreground.
    bm, col = new_bm()
    for i in range(30):
        y = rnd.uniform(10, 90)
        x = rnd.choice([-1, 1]) * rnd.uniform(5, 30)
        s = rnd.uniform(0.6, 2.2)
        tk.rock(bm, col, (x, y, ground_z(x, y) + s * 0.2), s, i * 2.3, 0.65, 2,
                (1.0, rnd.uniform(0.9, 1.0), rnd.uniform(0.85, 1.0)))
    bm_object("boulders", bm, "Pebble")


def saguaro(bm, col, base, s, rnd):
    lathe(bm, col, [(0.0, -0.3 * s), (0.2 * s, -0.3 * s), (0.22 * s, 2.5 * s), (0.2 * s, 3.4 * s),
                    (0.12 * s, 3.62 * s), (0.0, 3.7 * s)], 10, Matrix.Translation(base),
          color=lambda t: (0.9 + 0.1 * t, 1.0, 0.9))
    for k in range(rnd.randint(1, 3)):
        side = rnd.choice([-1, 1])
        a = rnd.uniform(0, TAU)
        zb = rnd.uniform(1.2, 2.2) * s
        out = Vector((math.cos(a), math.sin(a), 0))
        elbow = base + Vector((0, 0, zb)) + out * 0.55 * s
        # Out, then up: two short lathes meeting at the elbow.
        xf = Matrix.Translation(base + Vector((0, 0, zb))) @ \
            Vector((0, 0, 1)).rotation_difference(out).to_matrix().to_4x4()
        lathe(bm, col, [(0.14 * s, 0.0), (0.14 * s, 0.55 * s), (0.0, 0.62 * s)], 8, xf)
        up = rnd.uniform(0.7, 1.3) * s
        lathe(bm, col, [(0.0, -0.1 * s), (0.14 * s, -0.05 * s), (0.14 * s, up), (0.0, up + 0.1 * s)],
              8, Matrix.Translation(elbow))


def plants():
    rnd = random.Random(17)
    bm, col = new_bm()
    spots = [(-7.5, 16.0, 2.2), (8.5, 19.0, 2.5), (-11.0, 26.0, 2.8), (6.0, 34.0, 1.8),
             (-4.0, 44.0, 1.6), (10.0, 58.0, 2.0), (-16.0, 80.0, 2.4), (3.0, 90.0, 1.6)]
    for i in range(20):
        spots.append((rnd.choice([-1, 1]) * rnd.uniform(8, 60), rnd.uniform(30, 200),
                      rnd.uniform(1.4, 2.4)))
    for x, y, s in spots:
        saguaro(bm, col, Vector((x, y, ground_z(x, y) - 0.2)), s, rnd)
    # Prickly pear: paddles in a clump.
    for i in range(22):
        x = rnd.choice([-1, 1]) * rnd.uniform(4, 25)
        y = rnd.uniform(9, 70)
        c = Vector((x, y, ground_z(x, y)))
        for k in range(rnd.randint(3, 6)):
            off = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.4, 0.4), rnd.uniform(0.3, 1.0)))
            vs = puff(bm, col, c + off, rnd.uniform(0.35, 0.5), 2, 1.0, (0.85, 1.0, 0.8))
            ang = rnd.uniform(-0.6, 0.6)
            for v in vs:
                d = v.co - (c + off)
                d = Matrix.Rotation(ang, 3, 'Z') @ Vector((d.x, d.y * 0.25, d.z * 1.25))
                v.co = c + off + d
    bm_object("cacti", bm, "Cactus")
    bb, cb = new_bm()
    for i in range(60):
        x = rnd.choice([-1, 1]) * rnd.uniform(3, 40)
        y = rnd.uniform(8, 120)
        for k in range(3):
            puff(bb, cb, Vector((x + rnd.uniform(-0.5, 0.5), y + rnd.uniform(-0.5, 0.5),
                                 ground_z(x, y) + 0.2)), rnd.uniform(0.3, 0.55), 1, 0.7,
                 (rnd.uniform(0.8, 1.0), rnd.uniform(0.8, 1.0), 0.8), 0.3)
    bm_object("brush", bb, "Brush")


def sun():
    pos = place(0.18, 0.2, 1100.0)
    to_cam = (tk.CAM_M.translation - pos).normalized()
    rot = to_cam.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    bm, col = new_bm()
    R = 70.0
    c = bm.verts.new(pos)
    c[col] = (1, 1, 1, 1)
    ring = []
    for i in range(48):
        a = TAU * i / 48
        v = bm.verts.new(pos + rot @ Vector((R * math.cos(a), R * math.sin(a), 0)))
        v[col] = (1, 1, 1, 1)
        ring.append(v)
    tk.bridge_rings(bm, [[c], ring])
    bm_object("sun", bm, "Sun", recalc=False)
    bm_object("sun_glow", vh.glow_quads([(pos + to_cam * 5.0, (1.0, 0.72, 0.35), R * 9.0)]),
              "Glow", recalc=False)


def tumbleweed():
    bm, col = new_bm()
    vs = puff(bm, col, Vector((0, 0, 0)), 0.55, 1, 1.0)
    for v in vs:
        v.co *= 1.0 + 0.15 * n3(v.co.x * 5, v.co.y * 5, v.co.z * 5)
    rnd = random.Random(9)
    for k in range(10):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))).normalized()
        xf = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        lathe(bm, col, [(0.03, 0.2), (0.02, 0.72), (0.0, 0.78)], 4, xf)
    o = bm_object("tumbleweed", bm, "Twig")
    r = 0.6
    y = 24.0

    def f(t):
        u, vis = crossing(t, 0.3, 0.45)
        x = -16.0 + 32.0 * u
        z = ground_z(x, y) + r + 0.9 * abs(math.sin(u * math.pi * 6.0))
        s = max(vis, 0.001)
        return Vector((x, y, z)), Euler((0.0, 32.0 * u / r, 0.0)), (s, s, s)
    keyframes(o, f, step=1)


def vultures():
    """Three birds wheeling on a thermal, gliding more than flapping."""
    rnd = random.Random(21)
    centre = place(0.35, 0.72, 90.0)
    for i in range(3):
        root = empty("vulture_%d" % i, centre)
        R = rnd.uniform(9.0, 16.0)
        ph = TAU * i / 3.0
        dz = rnd.uniform(-4, 4)

        def f(t, R=R, ph=ph, dz=dz):
            a = TAU * t * 2.0 + ph
            p = centre + Vector((R * math.cos(a), R * 0.5 * math.sin(a), dz + 1.5 * math.sin(a * 0.5)))
            # Facing along the circle, banked into it.
            return p, Euler((math.radians(-25), 0.0, a + math.pi)), None
        keyframes(root, f, step=2)
        s = 2.4
        bm, col = new_bm()
        lathe(bm, col, [(0.0, -0.25), (0.06, -0.12), (0.07, 0.05), (0.04, 0.2), (0.0, 0.28)], 8,
              Matrix.Rotation(math.pi / 2, 4, 'Y') @ Matrix.Diagonal((s, s, s, 1)))
        bm_object(root.name + "_body", bm, "Bird", root)
        for side in (1, -1):
            wb = bmesh.new()
            vs = [wb.verts.new(Vector(p) * s) for p in
                  ((0.08, 0.0, 0.0), (-0.08, 0.0, 0.0), (-0.12, 0.3 * side, 0.02),
                   (-0.05, 0.55 * side, 0.05), (0.06, 0.28 * side, 0.02))]
            wb.faces.new(vs if side > 0 else list(reversed(vs)))
            wing = bm_object("%s_wing%s" % (root.name, "L" if side > 0 else "R"), wb, "Bird",
                             root, recalc=False, smooth=False)
            wph = rnd.uniform(0, TAU)

            def fw(t, side=side, wph=wph):
                # Mostly held out, with a few slow beats now and then.
                beat = math.sin(TAU * 24 * t + wph) * max(0.0, math.sin(TAU * 3 * t + wph)) ** 6
                return None, Euler((-side * (math.radians(6) + math.radians(30) * beat), 0, 0)), None
            keyframes(wing, fw, step=1)


def build():
    terrain()
    rocks()
    plants()
    sun()
    tumbleweed()
    vultures()
    for i, (sx, sy, d, size, n, seed) in enumerate([
            (-0.6, 0.85, 240, (40, 10, 8), 12, 801), (0.5, 1.05, 280, (46, 12, 9), 14, 802),
            (0.95, 0.6, 260, (30, 9, 7), 10, 803), (-0.2, 1.25, 320, (50, 12, 10), 14, 804),
            (-0.95, 0.45, 300, (34, 9, 7), 10, 805)]):
        cloud("cloud_%d" % i, sx, sy, d, size, n, seed, drift=0.5, subdiv=2,
              under=(0.85, 0.6, 0.75), flat=True)


build()
tk.export("desert")
