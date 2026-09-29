"""Nexus: the Nexus board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/nexus.py

Writes boards/3d/nexus.glb (what the game loads for Nexus) and
build/boards3d/nexus.blend.

A ruined plaza at the edge of the sky: worn stone slabs with gold rune
circles set into them, a colonnade of broken pillars wearing gold rings, and
past the edge, a sea of sunset cloud with floating islands and their
waterfalls. Above it all hangs a great ring, a portal, with a beam of light
through it and crystal shards turning round it; two planets in the dusk.

What moves: the ring turns and its shards orbit, the runes breathe, the
islands bob and their falls pour, the clouds drift, the beam shimmers.

Islands come from sky_islands.py. The framing rules and the contract with
the game are in `toonkit.py`.
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
from toonkit import TAU, bm_object, cloud, empty, keyframes, lathe, n3, new_bm, place, puff  # noqa: E402

PALETTE = dict(si.PALETTE)
PALETTE.update({
    "Tile": "#c9b8a4",
    "Pillar": "#d2c2ac",
    "Rune": "#ffcf5a",
    "Gold": "#ffc14a",
    "Portal": "#fff0b0",
    "Crystal": "#9fe8ff",
    "Planet": "#ffffff",
    "Beam": "#fff2c8",
    "Glow": "#ffffff",
    "Cloud": "#ffe2c8",
    "Ivy": "#7cc85a",
})

tk.setup(PALETTE)
tk.camera(vfov=64.0, pitch=5.0, loc=(0.0, 0.0, 3.0), sway=(0.18, 0.05), turn=(0.12, 0.35),
          clip_end=1600.0)

EDGE_Y = 42.0
RUNES_Y = 20.0


def box(bm, col, x0, x1, y0, y1, z0, z1, rgb=(1, 1, 1)):
    v = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                  (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for q in v:
        q[col] = tuple(rgb) + (1.0,)
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([v[i] for i in f])
    return v


def plaza():
    """Slabs, each its own slightly worn block, a few missing and a few
    lifted, so the floor reads as old."""
    rnd = random.Random(3)
    bm, col = new_bm()
    S = 2.0
    for j in range(-2, int(EDGE_Y / S)):
        for i in range(-11, 11):
            x0, y0 = i * S + 0.06, j * S + 0.06
            if rnd.random() < 0.05:
                continue
            h = rnd.uniform(-0.05, 0.08) + (0.2 if rnd.random() < 0.04 else 0.0)
            k = rnd.uniform(0.78, 1.0)
            box(bm, col, x0, x0 + S - 0.12, y0, y0 + S - 0.12, -0.3, h, (k, k * 0.98, k * 0.95))
    # The edge: a broken balustrade, gaps in it.
    for i in range(-12, 12):
        if rnd.random() < 0.3:
            continue
        x0 = i * 1.8
        box(bm, col, x0, x0 + 1.5, EDGE_Y - 0.6, EDGE_Y, 0.0, rnd.uniform(0.6, 1.1), (0.9, 0.88, 0.85))
    bm_object("plaza", bm, "Tile")


def runes():
    """Gold circles set into the floor, dashed and ticked, breathing."""
    bm, col = new_bm()
    c = Vector((0.0, RUNES_Y, 0.1))
    rnd = random.Random(7)
    for r, w, dash in ((3.2, 0.14, 0), (5.4, 0.2, 18), (7.6, 0.14, 0), (8.4, 0.08, 36)):
        segs = 96
        for i in range(segs):
            if dash and (i * dash // segs) % 2 == 1:
                continue
            a0, a1 = TAU * i / segs, TAU * (i + 1) / segs
            p = [c + Vector((rr * math.cos(a), rr * math.sin(a), 0.0))
                 for rr, a in ((r - w, a0), (r + w, a0), (r + w, a1), (r - w, a1))]
            vs = [bm.verts.new(q) for q in p]
            for v in vs:
                v[col] = (1.0, 1.0, 1.0, rnd.random() * 0.2)
            bm.faces.new(vs)
    # Ticks between the second and third rings, and a star in the middle.
    for i in range(24):
        a = TAU * i / 24
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0)) * 0.08
        p0, p1 = c + d * 5.8, c + d * (7.2 if i % 3 == 0 else 6.6)
        vs = [bm.verts.new(q) for q in (p0 - s, p0 + s, p1 + s, p1 - s)]
        for v in vs:
            v[col] = (1.0, 1.0, 1.0, 0.5)
        bm.faces.new(vs)
    for i in range(8):
        a = TAU * i / 8
        d = Vector((math.cos(a), math.sin(a), 0))
        s = Vector((-d.y, d.x, 0)) * 0.35
        vs = [bm.verts.new(q) for q in (c + s, c + d * 2.6, c - s)]
        for v in vs:
            v[col] = (1.0, 1.0, 1.0, 0.8)
        bm.faces.new(vs)
    bm_object("runes", bm, "Rune", recalc=False)


def torus(bm, col, centre, axis, R, r, seg=48, tube=8, rgb=(1, 1, 1)):
    """A ring of radius R and thickness r, about `axis`."""
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix()
    rings = []
    for i in range(seg):
        a = TAU * i / seg
        ring = []
        for k in range(tube):
            b = TAU * k / tube
            p = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a),
                        r * math.sin(b)))
            v = bm.verts.new(centre + rot @ p)
            v[col] = tuple(rgb) + (1.0,)
            ring.append(v)
        rings.append(ring)
    for i in range(seg):
        a, b = rings[i], rings[(i + 1) % seg]
        for k in range(tube):
            bm.faces.new((a[k], a[(k + 1) % tube], b[(k + 1) % tube], b[k]))


def colonnade():
    rnd = random.Random(11)
    bp, cp = new_bm()
    bg, cg = new_bm()
    bl, cl = new_bm()
    # Receding either side, each where the frame's edge strip is at its depth.
    for y, h, broken in ((15.0, 17.0, False), (24.0, 12.0, True), (33.0, 15.0, False),
                         (44.0, 9.0, True)):
        for side in (-1, 1):
            x = side * 0.82 * tk.half_width(y)
            hh = h * rnd.uniform(0.85, 1.1)
            lathe(bp, cp, [(0.0, -0.3), (1.2, -0.3), (1.2, 0.6), (0.95, 0.9), (0.85, hh * 0.5),
                           (0.8, hh - 0.9), (1.1, hh - 0.6), (1.1, hh), (0.0, hh + 0.05)], 12,
                  Matrix.Translation((x, y, 0.0)),
                  color=lambda t: (0.85 + 0.15 * t,) * 3)
            if broken:
                # A snapped-off drum lying at the foot.
                xf = Matrix.Translation((x + side * 1.6, y - 1.2, 0.8)) @ Matrix.Rotation(math.pi / 2, 4, 'X')
                lathe(bp, cp, [(0.0, -1.2), (0.85, -1.2), (0.85, 1.2), (0.0, 1.2)], 12, xf)
            torus(bg, cg, Vector((x, y, hh * 0.62)), Vector((0, 0, 1)), 1.05, 0.14)
            # Ivy climbing it.
            for k in range(rnd.randint(4, 7)):
                a = rnd.uniform(0, TAU)
                z = rnd.uniform(0.5, hh * 0.9)
                puff(bl, cl, Vector((x + 0.9 * math.cos(a), y + 0.9 * math.sin(a), z)),
                     rnd.uniform(0.35, 0.6), 2, 0.8,
                     (rnd.uniform(0.8, 1.0), 1.0, rnd.uniform(0.8, 0.95)), 0.25)
    bm_object("pillars", bp, "Pillar")
    bm_object("pillar_rings", bg, "Gold")
    bm_object("ivy", bl, "Ivy")


def portal():
    centre = place(0.0, 0.98, 260.0)
    axis = (tk.CAM_M.translation - centre).normalized()
    root = empty("portal", centre)
    R = 62.0
    bm, col = new_bm()
    torus(bm, col, Vector((0, 0, 0)), axis, R, 4.5, 72, 10)
    # Blocks set round the ring like the painting's, every eighth of a turn.
    rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix()
    for i in range(8):
        a = TAU * i / 8
        p = rot @ Vector((R * math.cos(a), R * math.sin(a), 0))
        tk.puff(bm, col, p, 8.0, 1, 1.0)
    bm_object("portal_ring", bm, "Gold", root)
    bm, col = new_bm()
    torus(bm, col, Vector((0, 0, 0)), axis, R - 5.5, 1.2, 72, 6)
    bm_object("portal_inner", bm, "Portal", root)
    bm_object("portal_glow", vh.glow_quads([(Vector((0, 0, 0)) + axis * 3, (1.0, 0.85, 0.55), R * 3.4)]),
              "Glow", root, recalc=False)

    # Converted to angles against the last frame's, or somewhere past a half
    # turn they flip sign and the ring spins round the long way between keys.
    last = [Euler((0.0, 0.0, 0.0))]

    def f(t):
        e = Matrix.Rotation(TAU * t, 3, axis).to_euler('XYZ', last[0])
        last[0] = e
        return None, e, None
    keyframes(root, f, step=2)

    # The beam, down through the ring and on down to the clouds.
    top = centre + Vector((0, 0, 260))
    bot = centre + Vector((0, 0, -220))
    bm_object("beam", tk.ray_quads([(top, bot, 10.0, (1.0, 0.92, 0.7), 0.3),
                                    (centre + Vector((0, 0, 40)), bot, 26.0, (1.0, 0.85, 0.6), 0.7)]),
              "Beam", recalc=False)

    # Shards, turning round the ring.
    rnd = random.Random(19)
    for i in range(10):
        bm, col = new_bm()
        s = rnd.uniform(2.0, 4.5)
        lathe(bm, col, [(0.0, -s * 1.4), (s * 0.55, 0.0), (0.0, s * 1.4)], 4)
        o = bm_object("shard_%d" % i, bm, "Crystal")
        rr = R * rnd.uniform(1.15, 1.45)
        ph = TAU * i / 10 + rnd.uniform(-0.2, 0.2)
        k = rnd.choice([1, 1, 2])
        bob = rnd.uniform(3, 8)
        e1 = Vector((1, 0, 0)).cross(axis).normalized()
        e2 = axis.cross(e1).normalized()

        def f2(t, rr=rr, ph=ph, k=k, bob=bob, e1=e1, e2=e2):
            a = -TAU * k * t + ph
            p = centre + (e1 * math.cos(a) + e2 * math.sin(a)) * rr + axis * bob * math.sin(TAU * 2 * t + ph)
            return p, Euler((0.3, TAU * 2 * t + ph, 0.0)), None
        keyframes(o, f2, step=2)


def planets():
    for sx, sy, d, r, rgb, band in ((0.62, 1.12, 700.0, 70.0, (0.62, 0.66, 0.95), (0.8, 0.84, 1.0)),
                                    (0.86, 0.9, 800.0, 26.0, (0.95, 0.72, 0.9), (1.0, 0.9, 0.95))):
        bm, col = new_bm()
        c = place(sx, sy, d)
        vs = puff(bm, col, c, r, 3)
        for v in vs:
            z = (v.co.z - c.z) / r
            k = 0.5 + 0.5 * math.sin(z * 9.0 + 2.0 * tk.n3(v.co.x / r, v.co.y / r, 1.0))
            v[col] = tk.mix(rgb, band, k) + (1.0,)
        bm_object("planet_%d" % int(r), bm, "Planet")


def skyfield():
    """The sea of cloud below the edge, and the islands over it."""
    specs = [(-0.9, -0.05, 90, (30, 10, 8), 16, 301), (0.85, 0.0, 110, (34, 10, 8), 16, 302),
             (0.0, 0.08, 180, (60, 16, 12), 18, 303), (-0.5, 0.15, 260, (70, 18, 14), 16, 304),
             (0.55, 0.18, 300, (80, 18, 14), 16, 305), (-1.05, 0.35, 150, (22, 8, 7), 12, 306),
             (1.1, 0.4, 170, (24, 8, 7), 12, 307), (0.0, -0.12, 70, (40, 12, 8), 16, 308)]
    for i, (sx, sy, d, size, n, seed) in enumerate(specs):
        cloud("sea_%d" % i, sx, sy, d, size, n, seed, drift=0.4, subdiv=2)
    # Low, just over the cloud sea, so they are seen from the side and not
    # from underneath; and clear of the pillars.
    si.island("isle_a", -0.55, 0.3, 80, 7.0, 1.6, 11, trees=("round", "round"), waterfall=0.5,
              bushes=3)
    si.island("isle_b", 0.6, 0.38, 100, 8.0, 1.7, 23, trees=("round", "pine"), waterfall=-0.5,
              bushes=2)
    si.island("isle_c", -0.2, 0.62, 170, 7.0, 1.6, 37, trees=("round",), waterfall=0.3)
    si.island("isle_d", 0.3, 0.2, 200, 6.0, 1.6, 41, trees=("pine", "round"), waterfall=-0.4)
    si.island("isle_e", -0.62, 0.85, 140, 5.0, 1.8, 53, trees=("round",), bob=0.8)
    si.island("isle_f", 0.55, 0.95, 160, 5.5, 1.7, 67, trees=("round",), waterfall=0.6, bob=0.8)


def build():
    plaza()
    runes()
    colonnade()
    portal()
    planets()
    skyfield()


build()
tk.export("nexus")
