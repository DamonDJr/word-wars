"""Ocean: the Ocean board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/ocean.py

Writes boards/3d/ocean.glb (what the game loads for Ocean) and
build/boards3d/ocean.blend.

Down in a reef canyon, looking up toward the light: a sandy floor running
away between walls of rock grown over with coral, kelp standing up out of the
sand, and the sunlit surface far above.

What moves: jellyfish pulsing as they hang and drift, a school of fish
wheeling round, a whale passing far off, bubbles going up from the floor,
the kelp swaying, shafts of light from the surface shimmering; and the
painted board's caustics still ripple over the top.

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
import vehicles as vh  # noqa: E402
from toonkit import (TAU, bm_object, crossing, empty, keyframes, lathe, n3, new_bm,  # noqa: E402
                     place, puff, smooth)

PALETTE = {
    "Sand": "#c4e2e8",
    "Reef": "#3f7fa0",
    "Coral": "#ffffff",
    "Kelp": "#6aa84a",
    "Jelly": "#ffb8f0",
    "Glow": "#ffffff",
    "Fish": "#ffffff",
    "Whale": "#1e3a66",
    "Bubble": "#dff8ff",
    "Shaft": "#c8f4ff",
}

tk.setup(PALETTE)
tk.camera(vfov=64.0, pitch=9.0, loc=(0.0, 0.0, 4.0), sway=(0.25, 0.1), turn=(0.2, 0.5))

CORAL_HUES = [(1.0, 0.45, 0.62), (1.0, 0.62, 0.35), (0.72, 0.45, 1.0), (1.0, 0.85, 0.35),
              (0.4, 0.9, 0.85), (1.0, 0.35, 0.45)]


def path_x(y):
    return 2.0 * math.sin(y / 23.0)


def floor_z(x, y):
    dx = abs(x - path_x(y))
    z = 0.5 * n3(x / 8.0, y / 8.0, 1.0) + 0.06 * math.sin(x * 1.2 + y * 0.8 + n3(x / 4, y / 4, 3.0) * 2.0)
    return z + 0.012 * max(0.0, dx - 3.0) ** 2


def terrain():
    def col(x, y, z):
        k = 0.88 + 0.12 * n3(x / 3.0, y / 3.0, 5.0)
        return (k, k * 0.97, k * 0.88, 1.0)
    tk.terrain("seabed", "Sand", -70, 70, -6, 200, 80, 90, floor_z, col, ypow=1.5)


def reef_column(bm, col, base, height, radius, seed):
    """A craggy column of reef rock, lumpier than any land rock, shaded as
    its un-roughened self."""
    rnd = random.Random(seed)
    seg = 12
    N = 10
    rings = []
    rough = {}
    lean = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.5), 0)) * 0.1 * height
    for k in range(N):
        t = k / (N - 1)
        r0 = radius * (1.0 - 0.45 * t) * (1.0 + 0.25 * math.sin(t * 7.0 + seed))
        ring = []
        for i in range(seg):
            a = TAU * i / seg
            c, s = math.cos(a), math.sin(a)
            r = r0 * (1.0 + 0.35 * n3(c * 1.4 + seed, s * 1.4, t * 3.0))
            off = lean * t * t + Vector((0, 0, height * t))
            v = bm.verts.new(base + off + Vector((r0 * c, r0 * s, 0)))
            rough[v] = base + off + Vector((r * c, r * s, 0))
            k2 = 0.8 + 0.2 * t
            v[col] = (k2, k2, k2, 1.0)
            ring.append(v)
        rings.append(ring)
    top = bm.verts.new(base + lean + Vector((0, 0, height + radius * 0.3)))
    rough[top] = top.co.copy()
    top[col] = (1, 1, 1, 1)
    rings.append([top])
    return rings, rough


def reef():
    rnd = random.Random(3)
    bm, col = new_bm()
    rough = {}
    cols = []
    # Columns in the strips beside the board, sized to the strip at their
    # depth so near and far ones sit in the frame alike; a second, taller
    # row behind makes them a wall.
    for side in (-1, 1):
        for row, (k0, k1, hk) in enumerate(((0.8, 0.9, 1.0), (1.05, 1.3, 1.5))):
            y = 16.0 + row * 6.0
            while y < 170:
                hw = tk.half_width(y)
                r = rnd.uniform(0.09, 0.14) * hw * (1.4 if row else 1.0)
                x = side * (rnd.uniform(k0, k1) * hw + r * 0.5)
                h = rnd.uniform(6, 14) * (1.0 + y / 70.0) * hk
                rings, rg = reef_column(bm, col, Vector((x, y, floor_z(x, y) - 0.5)), h, r,
                                        int(y * 3 + side + row * 1000))
                tk.bridge_rings(bm, rings)
                rough.update(rg)
                cols.append((x, y, h, r))
                y += rnd.uniform(4.0, 9.0) * (1.0 + y / 80.0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    smooth_n = [v.normal.copy() for v in bm.verts]
    for v, p in rough.items():
        v.co = p
    bm.normal_update()
    normals = [(0.6 * n + 0.4 * v.normal).normalized() for v, n in zip(bm.verts, smooth_n)]
    bm_object("reef", bm, "Reef", recalc=False, normals=normals)
    return cols


def coral(cols):
    rnd = random.Random(7)
    bm, col = new_bm()

    def branchy(base, s, hue):
        """Branching coral: a stub that forks, and forks again."""
        tips = [(base, Vector((0, 0, 1)), s, 0)]
        while tips:
            p, d, L, depth = tips.pop()
            xf = Matrix.Translation(p) @ Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
            r = 0.12 * L
            lathe(bm, col, [(r, 0.0), (r * 0.75, L), (0.0, L + r)], 6, xf,
                  color=lambda t: tuple(min(1.0, c * (0.8 + 0.3 * t)) for c in hue))
            if depth < 2:
                for k in range(rnd.randint(2, 3)):
                    nd = (d + Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), 0.3))).normalized()
                    tips.append((p + d * L * 0.9, nd, L * 0.7, depth + 1))

    def fan(base, s, hue):
        vs = puff(bm, col, base + Vector((0, 0, s * 0.6)), s * 0.6, 2, 1.0, hue)
        a = rnd.uniform(0, math.pi)
        for v in vs:
            d = v.co - base
            d = Matrix.Rotation(a, 3, 'Z') @ Vector((d.x, d.y * 0.12, d.z))
            v.co = base + d

    # Along the foot of the reef, and up its sides.
    for x, y, h, r in cols:
        for k in range(rnd.randint(4, 7)):
            a = rnd.uniform(0, TAU)
            z = rnd.uniform(0.0, h * 0.8)
            p = Vector((x + r * 1.1 * math.cos(a), y + r * 1.1 * math.sin(a), floor_z(x, y) + z))
            hue = rnd.choice(CORAL_HUES)
            kind = rnd.random()
            if kind < 0.45:
                branchy(p, rnd.uniform(0.5, 1.1), hue)
            elif kind < 0.7:
                fan(p, rnd.uniform(0.8, 1.6), hue)
            else:
                puff(bm, col, p, rnd.uniform(0.5, 1.0), 2, 0.75, hue, 0.3)
    # And scattered on the floor near the camera.
    for i in range(90):
        y = rnd.uniform(6, 80)
        x = path_x(y) + rnd.choice([-1, 1]) * rnd.uniform(2.5, 0.75 * tk.half_width(y) + 3.0)
        p = Vector((x, y, floor_z(x, y) - 0.1))
        hue = rnd.choice(CORAL_HUES)
        if rnd.random() < 0.5:
            branchy(p, rnd.uniform(0.4, 0.8), hue)
        else:
            puff(bm, col, p, rnd.uniform(0.35, 0.7), 2, 0.7, hue, 0.3)
    bm_object("coral", bm, "Coral")


def kelp():
    rnd = random.Random(11)
    bm, col = new_bm()
    for i in range(46):
        y = rnd.uniform(6, 90)
        x = path_x(y) + rnd.choice([-1, 1]) * rnd.uniform(3.0, 10.0)
        base = Vector((x, y, floor_z(x, y) - 0.2))
        n0 = len(bm.verts)
        H = rnd.uniform(3.0, 8.0)
        ph = rnd.uniform(0, TAU)
        lathe(bm, col, [(0.1, 0.0), (0.08, H * 0.5), (0.05, H), (0.0, H + 0.1)], 5,
              Matrix.Translation(base), offset=lambda t, ph=ph: Vector((0.5 * math.sin(t * 5 + ph), 0, 0)),
              color=lambda t: (0.8 + 0.2 * t, 1.0, 0.8))
        # Long thin blades up the stalk, alternating sides.
        for k in range(int(H / 0.6)):
            z = 0.5 + k * 0.6
            a = (k % 2) * math.pi + rnd.uniform(-0.5, 0.5)
            p = base + Vector((0.5 * math.sin(z / H * 5 + ph), 0, z))
            c = p + Vector((math.cos(a), math.sin(a), 0.4)) * 0.28
            vs = puff(bm, col, c, 0.24, 2, 1.0, (0.85, 1.0, 0.75))
            rot = Matrix.Rotation(a, 3, 'Z')
            for v in vs:
                d = rot.inverted() @ (v.co - c)
                v.co = c + rot @ Vector((d.x * 1.2, d.y * 0.15, d.z * 2.4))
        tk.stamp_sway(bm, col, n0, base.z)
    bm_object("kelp", bm, "Kelp")


def jellies():
    rnd = random.Random(19)
    spots = [(-0.62, 0.62, 18.0), (0.7, 0.4, 22.0), (0.35, 0.95, 28.0), (-0.3, 1.1, 34.0),
             (0.9, 0.85, 30.0), (-0.85, 0.25, 26.0), (0.1, 0.55, 40.0)]
    for i, (sx, sy, d) in enumerate(spots):
        home = place(sx, sy, d)
        root = empty("jelly_%d" % i, home)
        s = rnd.uniform(0.7, 1.2)
        bm, col = new_bm()
        # The bell: a dome, open underneath, with a frilled rim.
        verts = lathe(bm, col, [(0.0, 0.9 * s), (0.55 * s, 0.75 * s), (0.85 * s, 0.35 * s),
                                (0.9 * s, 0.05 * s), (0.7 * s, 0.0)], 16)
        for v in verts:
            if v.co.z < 0.1 * s:
                a = math.atan2(v.co.y, v.co.x)
                v.co.z -= 0.06 * s * (0.5 + 0.5 * math.sin(a * 8))
        # Tentacles trailing below.
        for k in range(7):
            a = TAU * k / 7
            L = rnd.uniform(1.4, 2.4) * s
            lathe(bm, col, [(0.03 * s, 0.0), (0.02 * s, -L), (0.0, -L - 0.05)], 4,
                  Matrix.Translation((0.5 * s * math.cos(a), 0.5 * s * math.sin(a), 0.05 * s)),
                  offset=lambda t, a=a: Vector((0.25 * math.sin(t * 6 + a), 0.2 * math.cos(t * 5 + a), 0)))
        bm_object(root.name + "_body", bm, "Jelly", root, recalc=False)
        bm_object(root.name + "_glow", vh.glow_quads([(Vector((0, 0, 0.4 * s)), (1.0, 0.55, 0.9), 4.0 * s)]),
                  "Glow", root, recalc=False)
        ph = rnd.uniform(0, TAU)
        beats = rnd.choice([10, 12, 14])
        drift = rnd.uniform(0.6, 1.4)

        def f(t, home=home, ph=ph, beats=beats, drift=drift):
            b = math.sin(TAU * beats * t + ph)
            pulse = max(0.0, b) ** 2
            p = home + Vector((drift * math.sin(TAU * t + ph), 0.4 * math.cos(TAU * t + ph),
                               1.2 * math.sin(TAU * 2 * t + ph) + 0.25 * pulse))
            return p, Euler((0.12 * math.sin(TAU * t + ph), 0.1 * math.cos(TAU * t), 0)), \
                (1.0 - 0.14 * pulse, 1.0 - 0.14 * pulse, 1.0 + 0.12 * pulse)
        keyframes(root, f, step=1)


def fish():
    """A school wheeling on an ellipse, each fish a little off the line."""
    rnd = random.Random(23)
    centre = place(0.1, 0.35, 32.0)
    for i in range(22):
        bm, col = new_bm()
        s = rnd.uniform(0.4, 0.6)
        hue = rnd.choice([(1.0, 0.85, 0.3), (0.4, 0.8, 1.0), (1.0, 0.55, 0.3)])
        lathe(bm, col, [(0.0, -0.5 * s), (0.18 * s, -0.2 * s), (0.2 * s, 0.1 * s), (0.0, 0.5 * s)], 8,
              Matrix.Rotation(math.pi / 2, 4, 'Y') @ Matrix.Diagonal((1.0, 0.6, 1.0, 1.0)),
              color=lambda t: hue)
        tail = [bm.verts.new(Vector(p) * s) for p in ((-0.45, 0, 0), (-0.8, 0, 0.25), (-0.8, 0, -0.25))]
        for v in tail:
            v[col] = hue + (1.0,)
        bm.faces.new(tail)
        o = bm_object("fish_%d" % i, bm, "Fish")
        off = Vector((rnd.uniform(-1.5, 1.5), rnd.uniform(-1.5, 1.5), rnd.uniform(-1.0, 1.0)))
        ph = i * 0.035
        wig = rnd.uniform(0, TAU)
        last = [None]

        def f(t, off=off, ph=ph, wig=wig, last=last):
            a = TAU * (t + ph)
            p = centre + Vector((9.0 * math.cos(a), 4.0 * math.sin(a), 1.5 * math.sin(2 * a))) + off
            yaw = a + math.pi / 2 + 0.12 * math.sin(TAU * 40 * t + wig)
            if last[0] is not None:
                yaw = last[0] + math.atan2(math.sin(yaw - last[0]), math.cos(yaw - last[0]))
            last[0] = yaw
            return p, Euler((0, 0, yaw)), None
        keyframes(o, f, step=1)


def whale():
    bm, col = new_bm()
    lathe(bm, col, [(0.0, -9.0), (1.0, -7.0), (2.2, -3.0), (2.4, 1.0), (1.8, 5.0), (0.6, 8.0), (0.0, 9.0)],
          14, Matrix.Rotation(math.pi / 2, 4, 'Y') @ Matrix.Diagonal((1.0, 0.8, 1.0, 1.0)))
    for side in (1, -1):
        vs = [bm.verts.new(p) for p in ((-8.5, 0, 0), (-11.5, 3.2 * side, 0.4), (-10.5, 0.4 * side, 0))]
        bm.faces.new(vs if side > 0 else list(reversed(vs)))
        vs = [bm.verts.new(p) for p in ((2.0, 1.6 * side, -1.0), (-1.5, 5.0 * side, -1.8), (-1.0, 1.8 * side, -1.2))]
        bm.faces.new(vs if side > 0 else list(reversed(vs)))
    o = bm_object("whale", bm, "Whale", recalc=False)
    row = place(0.0, 0.62, 150.0)
    half = tk.half_width(150.0) * 1.4

    def f(t):
        u, vis = crossing(t, 0.05, 0.9)
        s = max(vis, 0.001)
        return row + Vector((-half + 2 * half * u, 0, 3.0 * math.sin(u * TAU))), \
            Euler((0, 0.08 * math.sin(u * TAU * 3), 0)), (s, s, s)
    keyframes(o, f, step=2)


def bubbles():
    rnd = random.Random(29)
    vents = [(-5.0, 14.0), (6.0, 20.0), (-3.0, 34.0), (4.0, 46.0)]
    for vi, (x, y) in enumerate(vents):
        base = Vector((x, y, floor_z(x, y)))
        for k in range(8):
            bm, col = new_bm()
            r = rnd.uniform(0.08, 0.18)
            puff(bm, col, Vector((0, 0, 0)), r, 1)
            o = bm_object("bubble_%d_%d" % (vi, k), bm, "Bubble", loc=base)
            ph = k / 8.0
            wob = rnd.uniform(0, TAU)

            def f(t, base=base, ph=ph, wob=wob):
                u = (t * 5 + ph) % 1.0
                s = smooth(0.0, 0.05, u) * (1.0 - smooth(0.9, 1.0, u))
                s = max(s, 0.001)
                return base + Vector((0.3 * math.sin(TAU * 3 * u + wob), 0, 14.0 * u)), None, (s, s, s)
            keyframes(o, f, step=1)


def shafts():
    rnd = random.Random(31)
    items = []
    for i in range(9):
        top = place(rnd.uniform(-0.8, 0.8), 1.3, rnd.uniform(40, 90))
        top.z = 45.0
        bot = Vector((top.x + rnd.uniform(-6, 6) + 8.0, top.y + rnd.uniform(-5, 5), 0.0))
        items.append((top, bot, rnd.uniform(3.0, 6.5), (0.75, 0.95, 1.0), rnd.random()))
    bm_object("light_shafts", tk.ray_quads(items), "Shaft", recalc=False)


def build():
    terrain()
    cols = reef()
    coral(cols)
    kelp()
    jellies()
    fish()
    whale()
    bubbles()
    shafts()


build()
tk.export("ocean")
