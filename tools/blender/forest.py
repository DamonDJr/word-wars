"""Forest: the Forest board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/forest.py

Writes boards/3d/forest.glb (what the game loads for Forest) and
build/boards3d/forest.blend.

A river valley in summer: the river winds toward the camera out of a pool
under a waterfall, between grassy banks that rise into pine-covered hills,
with mountains in the haze behind. A big broadleaf tree leans in from the
left and fills the top corner, the way the painting frames it.

What moves: the waterfalls and the river (shader), mist rolling off the pool,
every tree in the wind (shader), clouds and a flock crossing, shafts of sun
through the big tree; and the painted board's falling leaves still drift
over the top.

Trees, waterfalls and birds come from sky_islands.py, which doubles as a box
of parts. The framing rules and the contract with the game are in
`toonkit.py`.
"""

import math
import random
import sys
from pathlib import Path

from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toonkit as tk  # noqa: E402
import sky_islands as si  # noqa: E402
from toonkit import (TAU, bm_object, cloud, keyframes, lathe, n3, new_bm, puff,  # noqa: E402
                     smooth)

PALETTE = dict(si.PALETTE)
PALETTE.update({
    "Ground": "#ffffff",
    "Stone": "#a9a39a",
    "Mountain": "#7f9cc0",
    "River": "#4fb8c8",
    "Mist": "#ffffff",
    "Shaft": "#fff2c4",
})

tk.setup(PALETTE)
tk.camera(vfov=60.0, pitch=-6.0, loc=(0.0, 0.0, 4.5), sway=(0.2, 0.06), turn=(0.15, 0.4))

FALL_Y = 104.0


def river_x(y):
    return 2.6 * math.sin(y / 21.0 + 0.4) + 1.4 * math.sin(y / 9.0) * smooth(10, 40, y)


def river_w(y):
    return 7.5 - 2.5 * smooth(0, 95, y)


def ground_z(x, y):
    dx = abs(x - river_x(y)) - river_w(y) * 0.5
    if dx < 0:
        return -0.7
    z = 0.2 + 1.1 * (1.0 - math.exp(-dx / 1.6))
    # The valley opens out near the camera and closes in toward the falls.
    z += 0.005 * dx * dx * (0.4 + 0.6 * smooth(0, 90, y))
    z += 0.8 * n3(x / 7.0, y / 7.0, 1.3) * smooth(0, 4, dx)
    # The cliff the falls come over, and the wooded top beyond it.
    z += 18.0 * smooth(FALL_Y - 8, FALL_Y, y) * (1.0 - 0.5 * smooth(40, 70, abs(x)))
    return z


def ground_col(x, y, z):
    dx = abs(x - river_x(y)) - river_w(y) * 0.5
    e = 0.6
    slope = abs(ground_z(x + e, y) - ground_z(x - e, y)) + abs(ground_z(x, y + e) - ground_z(x, y - e))
    grass = tk.mix((0.46, 0.75, 0.27), (0.62, 0.82, 0.3), 0.5 + 0.5 * n3(x / 5.0, y / 5.0, 7.7))
    sand = (0.85, 0.79, 0.6)
    stone = (0.5, 0.52, 0.46)
    c = tk.mix(sand, grass, smooth(0.2, 1.8, dx))
    c = tk.mix(c, stone, smooth(0.9, 1.8, slope))
    return c + (1.0,)


def terrain():
    tk.terrain("valley", "Ground", -60, 60, -6, 150, 90, 96, ground_z, ground_col, ypow=1.45)


def river():
    bm, col = new_bm()
    rows = []
    N = 60
    for j in range(N + 1):
        y = -8 + (FALL_Y - 4 + 8) * (j / N) ** 1.2
        xc, w = river_x(y), river_w(y) + 1.2
        rows.append([bm.verts.new((xc + w * (u - 0.5), y, 0.0)) for u in (0.0, 0.5, 1.0)])
    for a, b in zip(rows, rows[1:]):
        for k in range(2):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))
    bm_object("river", bm, "River", recalc=False)


def falls():
    xc = river_x(FALL_Y - 6)
    top = ground_z(xc, FALL_Y + 1) - 0.4
    d = Vector((0, -1, 0))
    for name, x, w, h in (("falls_main", xc, 6.0, top), ("falls_left", xc - 13.0, 2.2, top - 4.0)):
        path = []
        M = 26
        p0 = Vector((x, FALL_Y - 7.2, h))
        for k in range(M + 1):
            s = k / M
            path.append(p0 + d * (1.6 * (1.0 - math.exp(-6.0 * s))) + Vector((0, 0, -h * s ** 1.15)))
        bmr = tk.ribbon(path, [w * (1.0 + 0.35 * k / M) for k in range(M + 1)],
                        bulge=0.3, v_scale=w * 0.6, fade=True, normal_hint=d)
        bm_object(name, bmr, "Water", recalc=False)
    # Spray at the foot, rolling and breathing.
    rnd = random.Random(5)
    for i in range(7):
        c = Vector((xc + rnd.uniform(-4.5, 4.5), FALL_Y - 9.5 + rnd.uniform(-1.5, 1.0), 0.6))
        bm, col = new_bm()
        for k in range(4):
            puff(bm, col, Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.4, 0.4), rnd.uniform(0, 0.6))),
                 rnd.uniform(0.9, 1.5), 2, 0.8, (0.92, 0.96, 1.0))
        o = bm_object("mist_%d" % i, bm, "Mist", loc=c)
        ph = rnd.uniform(0, TAU)
        k2 = rnd.choice([2, 3])

        def f(t, c=c, ph=ph, k2=k2):
            b = 0.5 + 0.5 * math.sin(TAU * k2 * t + ph)
            return c + Vector((0, 0, 0.6 * b)), None, (1.0 + 0.25 * b,) * 3
        keyframes(o, f, step=2)


def big_tree():
    """The broadleaf leaning in from the left edge, its crown over the top
    corner of the frame."""
    rnd = random.Random(11)
    bt, ct = new_bm()
    bl, cl = new_bm()
    base = Vector((-10.5, 15.0, ground_z(-10.5, 15.0) - 0.3))
    lean = lambda t: Vector((2.4 * t * t, 0.6 * t, 0))
    lathe(bt, ct, [(0.75, 0.0), (0.6, 2.0), (0.45, 5.0), (0.35, 7.5), (0.2, 9.5), (0.0, 10.0)], 10,
          Matrix.Translation(base), offset=lean, color=lambda t: (0.85 + 0.15 * t,) * 3)
    # Two boughs reaching right.
    for zb, ang, L in ((5.5, 0.35, 5.0), (7.2, 0.15, 4.2)):
        root = base + lean(zb / 10.0) + Vector((0, 0, zb))
        xf = Matrix.Translation(root) @ Matrix.Rotation(-math.pi / 2 + ang, 4, 'Y')
        lathe(bt, ct, [(0.28, 0.0), (0.2, L * 0.6), (0.0, L)], 7, xf)
    # In the top left corner only: at this distance the frame is just over
    # five metres either side of centre.
    crown = [(Vector((-8.5, 16.0, 12.0)), 2.8), (Vector((-6.0, 16.5, 11.2)), 2.3),
             (Vector((-4.6, 15.5, 12.6)), 1.9), (Vector((-9.5, 18.0, 13.2)), 2.6),
             (Vector((-7.0, 18.5, 13.6)), 2.4), (Vector((-10.0, 14.0, 10.4)), 2.4),
             (Vector((-7.5, 14.0, 14.0)), 2.2)]
    for c, r in crown:
        for k in range(4):
            off = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.6))) * r * 0.5
            tint = (rnd.uniform(0.85, 1.0), rnd.uniform(0.92, 1.03), rnd.uniform(0.8, 0.95))
            puff(bl, cl, c + off, r * rnd.uniform(0.55, 0.8), 2, 0.8, tint, 0.3)
    tk.stamp_sway(bt, ct, 0, base.z)
    tk.stamp_sway(bl, cl, 0, base.z)
    bm_object("bigtree_trunk", bt, "Trunk")
    bm_object("bigtree_leaves", bl, "Leaves")


def woods():
    rnd = random.Random(23)
    bt, ct = new_bm()
    bl, cl = new_bm()
    bp, cp = new_bm()
    # Pines up the valley sides and along the top of the cliff: a wall of
    # them at the sides of the frame, thinning toward the middle.
    for i in range(200):
        y = rnd.uniform(20, 170)
        side = rnd.choice([-1, 1])
        x = side * rnd.uniform(8.0, 60.0)
        dx = abs(x - river_x(y)) - river_w(y) * 0.5
        if dx < 3.5 or (FALL_Y - 12 < y < FALL_Y + 2 and abs(x - river_x(y)) < 12):
            continue
        z = ground_z(x, y) - 0.2
        s = rnd.uniform(3.5, 6.5) * (1.0 + 0.25 * smooth(15, 40, abs(x)))
        n0, n1 = len(bt.verts), len(bp.verts)
        si.tree_pine(bt, ct, bp, cp, Vector((x, y, z)), s, rnd)
        tk.stamp_sway(bt, ct, n0, z)
        tk.stamp_sway(bp, cp, n1, z)
    # Broadleaves nearer the water.
    for i in range(26):
        y = rnd.uniform(12, 90)
        side = rnd.choice([-1, 1])
        x = river_x(y) + side * (river_w(y) * 0.5 + rnd.uniform(3.0, 9.0))
        if abs(x) < 6 and y < 25:
            continue
        z = ground_z(x, y) - 0.2
        n0, n1 = len(bt.verts), len(bl.verts)
        si.tree_round(bt, ct, bl, cl, Vector((x, y, z)), rnd.uniform(2.6, 4.2), rnd)
        tk.stamp_sway(bt, ct, n0, z)
        tk.stamp_sway(bl, cl, n1, z)
    # Bushes and flowers along the banks.
    bb, cb = new_bm()
    bf, cf = new_bm()
    hues = [(1.0, 0.72, 0.86), (1.0, 1.0, 1.0), (1.0, 0.88, 0.4), (0.8, 0.72, 1.0)]
    for i in range(70):
        y = rnd.uniform(8, 80)
        side = rnd.choice([-1, 1])
        x = river_x(y) + side * (river_w(y) * 0.5 + rnd.uniform(1.0, 6.0))
        z = ground_z(x, y)
        n0 = len(bb.verts)
        if rnd.random() < 0.55:
            for k in range(3):
                q = Vector((x + rnd.uniform(-0.6, 0.6), y + rnd.uniform(-0.6, 0.6), z + 0.3))
                puff(bb, cb, q, rnd.uniform(0.45, 0.75), 2, 0.8,
                     (rnd.uniform(0.8, 0.95), 1.0, rnd.uniform(0.75, 0.9)), 0.25)
        else:
            for k in range(5):
                q = Vector((x + rnd.uniform(-1, 1), y + rnd.uniform(-1, 1), z + 0.12))
                puff(bf, cf, q, 0.12, 1, 1.0, rnd.choice(hues))
        tk.stamp_sway(bb, cb, n0, z)
    bm_object("trunks", bt, "Trunk")
    bm_object("leaves", bl, "Leaves")
    bm_object("pines", bp, "Pine")
    bm_object("bushes", bb, "Leaves")
    bm_object("flowers", bf, "Flower")


def stones():
    rnd = random.Random(31)
    bm, col = new_bm()
    for i in range(46):
        y = rnd.uniform(6, 95)
        side = rnd.choice([-1, 1])
        x = river_x(y) + side * (river_w(y) * 0.5 + rnd.uniform(-1.2, 1.5))
        s = rnd.uniform(0.5, 1.6) * (1.0 + y / 80.0)
        tint = rnd.uniform(0.85, 1.0)
        tk.rock(bm, col, (x, y, max(ground_z(x, y), -0.2) + s * 0.25), s, i * 1.7, 0.7,
                2, (tint, tint * 1.02, tint))
    bm_object("stones", bm, "Stone")


def mountains():
    rnd = random.Random(41)
    bm, col = new_bm()
    for k in range(12):
        x = rnd.uniform(-220, 220)
        y = rnd.uniform(240, 420)
        h = rnd.uniform(50, 120)
        r = h * rnd.uniform(1.2, 1.8)
        prof = [(r, -2.0), (r * 0.72, h * 0.3), (r * 0.38, h * 0.7), (r * 0.12, h * 0.94), (0.0, h)]
        verts = lathe(bm, col, prof, 14, Matrix.Translation((x, y, 0)))
        for v in verts:
            v.co.x += 5.0 * n3(v.co.x * 0.05, v.co.y * 0.05, 3.3) * (v.co.z / h)
            snow = smooth(0.72, 0.8, v.co.z / h)
            c = tk.mix((0.85, 0.9, 1.0), (1.25, 1.25, 1.25), snow)
            v[col] = tuple(min(1.0, q) for q in c) + (1.0,)
    bm_object("mountains", bm, "Mountain")


def shafts():
    items = []
    rnd = random.Random(51)
    for i in range(5):
        a = Vector((-7.0 + i * 1.8 + rnd.uniform(-0.5, 0.5), 15.0 + i * 2.5, 11.0))
        b = a + Vector((6.5 + rnd.uniform(0, 2), 3.0, -11.0))
        items.append((a, b, rnd.uniform(1.0, 1.8), (1.0, 0.93, 0.72), rnd.random()))
    bm_object("sun_shafts", tk.ray_quads(items), "Shaft", recalc=False)


def build():
    terrain()
    river()
    falls()
    big_tree()
    woods()
    stones()
    mountains()
    shafts()
    for i, (sx, sy, d, size, n, seed) in enumerate([
            (-0.6, 0.95, 160, (26, 9, 8), 14, 701), (0.55, 1.1, 190, (30, 10, 9), 14, 702),
            (0.9, 0.75, 170, (20, 8, 7), 12, 703), (-0.1, 1.25, 220, (34, 10, 9), 14, 704)]):
        cloud("cloud_%d" % i, sx, sy, d, size, n, seed, drift=0.5, subdiv=2)
    si.flock("flock", 0.62, 40, 5, 61, start=0.2, span=0.55)


build()
tk.export("forest")
