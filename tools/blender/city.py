"""City: a rainy night street, the Cyber board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/city.py

Writes boards/3d/city.glb (what the game loads for Cyber) and
build/boards3d/city.blend (to open and adjust by hand).

The camera stands on the left pavement at eye height, looking down a
four-lane street at a skyline under a full moon, as in the painting the
board was drawn from. Towers line both sides, their windows lit
warm and cold (and a few switching on and off, in the shader); shopfronts
and neon signs along the ground floors; street lamps throwing cones of light
into the rain; trees on the pavements; a bus stop.

What moves, all on the 20 second loop:

- Traffic: a bus that pulls in at the stop, waits and pulls away; a taxi and
  five other cars in both directions, wheels turning by the distance driven.
  They come out of the haze at the far end and leave behind the camera.
- People: ten walkers with a proper walk (see figures.py), coming out of lit
  doorways and going into others, or walking in from beside the frame; some
  under umbrellas. Four more stand at the stop and under an awning, shifting
  their weight and looking about.
- Blinking lights on the tall towers' roofs; the camera's slow drift.

The rain, the wet road with everything reflected in it, the window changes,
the neon buzz and the light in the lamps' cones are the game's job
(`scripts/board3d.gd` and the shaders in `boards/3d/`).

Walkers only exist on the pavement between two hidden points, because the
loop is 20 seconds and nobody walks the length of a street in that: a
doorway (they step out of, or into, a wall with a lit door on it) or the side
of the frame near the camera. Each crossing is timed to fit in the loop.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import toonkit as tk  # noqa: E402
import figures as fg  # noqa: E402
import vehicles as vh  # noqa: E402
from toonkit import TAU, bm_object, empty, lathe, new_bm, place, puff  # noqa: E402

PALETTE = {
    "Road": "#141a30", "Sidewalk": "#222844", "Curb": "#39415f",
    "Building": "#161c3a",
    "Neon": "#ffffff", "NeonEdge": "#ffffff", "Door": "#ffd58a", "Ad": "#ffffff",
    "LampPost": "#262b44", "LampBulb": "#f4f8ff", "Glow": "#ffffff", "Pool": "#ffffff",
    "LightCone": "#ffffff", "Blink": "#ff2a2a", "Moon": "#eef4ff",
    "Leaves": "#2b5a44", "Trunk": "#3a2c30",
    "Shelter": "#2a3150", "ShelterGlass": "#2c4a7a",
    "Paint": "#ffffff", "Glass": "#3a5078", "Tire": "#15161c", "Hub": "#8c94a6",
    "Headlight": "#fff6dc", "Taillight": "#ff2626", "TaxiSign": "#fff2b8",
    "BusGlass": "#a8d8ff", "BusSign": "#ffb428",
    "Person": "#ffffff", "Umbrella": "#ffffff",
}

tk.setup(PALETTE)
# Two framings. The game's stands on the left pavement at eye height,
# looking down the street and turned a little toward it. With
# `-- --overhead` the camera is over the middle of the street instead (the
# first framing, kept to compare); that writes city__overhead.glb, which the
# game would read with city's settings.
SIDEWALK = "--overhead" not in sys.argv
if SIDEWALK:
    CAM = tk.camera(vfov=68.0, pitch=4.0, yaw=8.0, loc=(-7.4, 0.0, 2.2), sway=(0.1, 0.04),
                    turn=(0.1, 0.25), clip_end=1500.0)
else:
    CAM = tk.camera(vfov=68.0, pitch=-10.0, loc=(0.0, 0.0, 4.2), sway=(0.16, 0.05),
                    turn=(0.12, 0.3), clip_end=1500.0)

ROAD = 6.0          # half the carriageway
WALK = 9.5          # the facades
CURB = 0.15
CROSS = [(100.0, 114.0), (262.0, 274.0)]
NEON = [(1.0, 0.22, 0.38), (1.0, 0.35, 0.82), (0.2, 0.9, 1.0), (1.0, 0.8, 0.22),
        (0.62, 0.36, 1.0), (0.3, 0.55, 1.0), (1.0, 0.45, 0.15)]
EDGE = [(0.2, 0.5, 1.0), (0.25, 0.7, 1.0), (0.3, 0.45, 1.0), (0.9, 0.3, 1.0)]


def in_cross(y, pad=0.0):
    return any(a - pad <= y <= b + pad for a, b in CROSS)


# ------------------------------------------------------------------ ground

def quad(bm, corners, col=None, rgba=(1, 1, 1, 1)):
    vs = [bm.verts.new(c) for c in corners]
    if col is not None:
        for v in vs:
            v[col] = rgba
    return bm.faces.new(vs)


def ground():
    bm, col = new_bm()
    quad(bm, [(-ROAD, -30, 0), (ROAD, -30, 0), (ROAD, 1600, 0), (-ROAD, 1600, 0)])
    for a, b in CROSS:
        quad(bm, [(-400, a, 0), (-ROAD, a, 0), (-ROAD, b, 0), (-400, b, 0)])
        quad(bm, [(ROAD, a, 0), (400, a, 0), (400, b, 0), (ROAD, b, 0)])
    bm_object("road", bm, "Road", recalc=False)

    bm, col = new_bm()
    cb, cc = new_bm()
    edges = [-30.0]
    for a, b in CROSS:
        edges += [a, b]
    edges.append(1600.0)
    for y0, y1 in zip(edges[0::2], edges[1::2]):
        for s in (-1, 1):
            xi, xo = s * ROAD, s * (WALK + 40)
            x0, x1 = min(xi, xo), max(xi, xo)
            quad(bm, [(x0, y0, CURB), (x1, y0, CURB), (x1, y1, CURB), (x0, y1, CURB)])
            # The kerb: the face toward the road, and the two at crossings.
            if s < 0:
                quad(cb, [(xi, y0, 0), (xi, y1, 0), (xi, y1, CURB), (xi, y0, CURB)])
            else:
                quad(cb, [(xi, y1, 0), (xi, y0, 0), (xi, y0, CURB), (xi, y1, CURB)])
            if y0 > -30:
                quad(cb, [(x1, y0, 0), (x0, y0, 0), (x0, y0, CURB), (x1, y0, CURB)])
            if y1 < 1600:
                quad(cb, [(x0, y1, 0), (x1, y1, 0), (x1, y1, CURB), (x0, y1, CURB)])
    bm_object("sidewalk", bm, "Sidewalk", recalc=False)
    bm_object("curb", cb, "Curb", recalc=False)


# --------------------------------------------------------------- buildings

class Blocks:
    """Every building face in one mesh, one draw call.

    Per face: UV is metres (across the face, and height above the street);
    UV2 is (lit fraction, seed); vertex colour is (window width, how cold
    the light is, shopfront, wall brightness). The building shader draws
    the windows from those."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.verts.layers.float_color.new("Color")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.uv2 = self.bm.loops.layers.uv.new("UV2")

    def face(self, corners, uvs, rgba, p2):
        vs = [self.bm.verts.new(c) for c in corners]
        for v in vs:
            v[self.col] = rgba
        f = self.bm.faces.new(vs)
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
            loop[self.uv2].uv = p2

    def box(self, x0, x1, y0, y1, z0, z1, colw, cool, lit, seed, bright, shop_face=None):
        p2 = (lit, seed)
        dy, dx = y1 - y0, x1 - x0

        def rgba(face):
            return (colw, cool, 1.0 if face == shop_face and z0 <= 0.01 else 0.0, bright)
        self.face([(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
                  [(0, z0), (dy, z0), (dy, z1), (0, z1)], rgba("+x"), p2)
        self.face([(x0, y1, z0), (x0, y0, z0), (x0, y0, z1), (x0, y1, z1)],
                  [(0, z0), (dy, z0), (dy, z1), (0, z1)], rgba("-x"), p2)
        self.face([(x1, y1, z0), (x0, y1, z0), (x0, y1, z1), (x1, y1, z1)],
                  [(0, z0), (dx, z0), (dx, z1), (0, z1)], rgba("+y"), p2)
        self.face([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)],
                  [(0, z0), (dx, z0), (dx, z1), (0, z1)], rgba("-y"), p2)
        self.face([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)],
                  [(0, -1), (1, -1), (1, -1), (0, -1)], rgba("top"), p2)


class Extras:
    """The small emissive and dark bits that ride on buildings, collected
    per material so each is one mesh."""

    def __init__(self):
        self.parts = {}

    def bm(self, mat):
        if mat not in self.parts:
            self.parts[mat] = new_bm()
        return self.parts[mat]

    def box(self, mat, x0, x1, y0, y1, z0, z1, rgba=(1, 1, 1, 1)):
        bm, col = self.bm(mat)
        v = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                      (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
        for q in v:
            q[col] = rgba
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            bm.faces.new([v[i] for i in f])

    def finish(self):
        for mat, (bm, col) in self.parts.items():
            bm_object("extras_" + mat.lower(), bm, mat)


def height_for(y, rnd):
    # Low enough down the street that the sky opens up over it, as in the
    # painting; the tall ones are saved for the skyline at the end.
    if y < 100:
        return rnd.uniform(13, 30)
    if y < 262:
        return rnd.uniform(18, 46) if rnd.random() > 0.15 else rnd.uniform(46, 64)
    return rnd.uniform(26, 70) if rnd.random() > 0.2 else rnd.uniform(70, 100)


def street_side(B, X, side, rnd):
    """One side of the street: an unbroken row of buildings but for the
    cross streets, so every walker's doorway lands on a wall."""
    y = -30.0
    facade = side * WALK
    street_face = "+x" if side < 0 else "-x"
    shops = []
    while y < 560:
        if in_cross(y):
            y = next(b for a, b in CROSS if a <= y <= b) + 0.01
            continue
        w = rnd.uniform(12, 28)
        y1 = y + w
        for a, b in CROSS:
            if y < a < y1:
                y1 = a
        depth = rnd.uniform(16, 32)
        h = height_for(y, rnd)
        x0, x1 = sorted((facade, side * (WALK + depth)))
        cool = 1.0 if rnd.random() < 0.22 else rnd.uniform(0.0, 0.25)
        lit = rnd.uniform(0.25, 0.6)
        seed = rnd.random()
        colw = rnd.random()
        bright = rnd.uniform(0.75, 1.0)
        B.box(x0, x1, y, y1, 0.0, h, colw, cool, lit, seed, bright, street_face)
        # Setbacks on the taller ones.
        if h > 28 and rnd.random() < 0.5:
            inset = rnd.uniform(2.0, 4.0)
            h2 = h + rnd.uniform(6, 26)
            xa, xb = sorted((facade + side * inset, side * (WALK + depth - inset)))
            B.box(xa, xb, y + inset, y1 - inset, h, h2, colw, cool, lit, rnd.random(), bright)
            top = h2
        else:
            top = h
        # Neon up the edges of some towers.
        if top > 40 and rnd.random() < 0.4:
            ec = rnd.choice(EDGE) + (rnd.random(),)
            ex = facade + side * 0.05
            for ye in (y + 0.1, y1 - 0.35):
                X.box("NeonEdge", min(ex, ex + side * 0.25), max(ex, ex + side * 0.25),
                      ye, ye + 0.25, 6.0, h, ec)
            for zb in range(12, int(h) - 2, rnd.choice([9, 12, 15])):
                X.box("NeonEdge", min(ex, ex + side * 0.2), max(ex, ex + side * 0.2),
                      y + 0.1, y1 - 0.1, zb, zb + 0.22, ec)
        if top > 70:
            for ye in (y + 1.0, y1 - 1.0):
                bm, col = X.bm("Blink")
                vs = puff(bm, col, Vector((side * (WALK + depth * 0.5), ye, top + 0.4)), 0.45, 1)
                ph = rnd.random()
                for v in vs:
                    v[col] = (1.0, 1.0, 1.0, ph)
        # Signs over the shopfronts, and blade signs off the wall.
        if y < 330:
            shops.append((y, y1))
            c = rnd.choice(NEON) + (rnd.random(),)
            sw = min(y1 - y - 2.0, rnd.uniform(4.0, 9.0))
            yc = rnd.uniform(y + 1 + sw / 2, y1 - 1 - sw / 2) if y1 - y - 2 > sw else (y + y1) / 2
            X.box("Neon", min(facade, facade - side * 0.22), max(facade, facade - side * 0.22),
                  yc - sw / 2, yc + sw / 2, 3.55, 4.25, c)
            if rnd.random() < 0.55:
                c = rnd.choice(NEON) + (rnd.random(),)
                yb = rnd.uniform(y + 1.0, y1 - 1.0)
                zb = rnd.uniform(4.8, 6.5)
                X.box("Neon", min(facade - side * 0.15, facade - side * 1.1),
                      max(facade - side * 0.15, facade - side * 1.1),
                      yb - 0.1, yb + 0.1, zb, zb + rnd.uniform(2.2, 4.0), c)
        y = y1 + rnd.uniform(0.0, 0.3)
    return shops


def skyline(B, X, rnd):
    """The towers at the end of the street, and the ones down the cross
    streets."""
    for i in range(46):
        x = rnd.uniform(-1, 1)
        x = math.copysign(abs(x) ** 1.4, x) * 260
        y = rnd.uniform(560, 1100)
        w = rnd.uniform(18, 48)
        d = rnd.uniform(18, 48)
        near_axis = 1.0 - min(abs(x) / 200.0, 1.0)
        h = rnd.uniform(80, 200) + near_axis * rnd.uniform(0, 140)
        cool = 1.0 if rnd.random() < 0.35 else rnd.uniform(0.0, 0.3)
        B.box(x - w / 2, x + w / 2, y, y + d, 0, h, rnd.random(), cool, rnd.uniform(0.2, 0.55),
              rnd.random(), rnd.uniform(0.7, 1.0))
        if rnd.random() < 0.45:
            ec = rnd.choice(EDGE) + (rnd.random(),)
            for xe in (x - w / 2 - 0.1, x + w / 2 - 0.5):
                X.box("NeonEdge", xe, xe + 0.6, y - 0.2, y + 0.4, 10, h, ec)
        if rnd.random() < 0.4:
            sh = rnd.uniform(20, 60)
            X.box("LampPost", x - 0.6, x + 0.6, y + d / 2 - 0.6, y + d / 2 + 0.6, h, h + sh)
            bm, col = X.bm("Blink")
            vs = puff(bm, col, Vector((x, y + d / 2, h + sh + 0.8)), 1.1, 1)
            ph = rnd.random()
            for v in vs:
                v[col] = (1.0, 1.0, 1.0, ph)
    for a, b in CROSS:
        for s in (-1, 1):
            x = s * rnd.uniform(70, 110)
            B.box(min(x, x + s * 30), max(x, x + s * 30), a - 6, b + 6, 0,
                  rnd.uniform(40, 90), rnd.random(), rnd.uniform(0, 0.3), 0.4,
                  rnd.random(), 0.8)


def doors(X, spots):
    """Lit doorways where walkers come and go."""
    for side, y in spots:
        f = side * WALK - side * 0.06
        X.box("Door", min(f, f - side * 0.04), max(f, f - side * 0.04),
              y - 0.65, y + 0.65, CURB, 2.45, (1, 1, 1, 1))
        # A little awning over it, so it reads as a door and not a light.
        X.box("LampPost", min(f, f - side * 0.8), max(f, f - side * 0.8),
              y - 0.9, y + 0.9, 2.6, 2.72)


# ---------------------------------------------------------- street furniture

LAMP_COOL = (0.8, 0.9, 1.0)
LAMP_WARM = (1.0, 0.78, 0.48)


def streetlamps():
    posts, pc = new_bm()
    bulbs, bc = new_bm()
    cones, cc = new_bm()
    glows = []
    pools = []
    for side in (-1, 1):
        for i in range(18):
            y = 8.0 + i * 26.0 + (13.0 if side > 0 else 0.0)
            if in_cross(y, 3.0):
                continue
            x = side * (ROAD + 0.55)
            if SIDEWALK and side < 0:
                # On the building side of the pavement the camera stands on,
                # so a post rises at the left edge of the frame.
                y += 1.0
                x = -(WALK - 0.5)
            hx = x - side * 1.9
            rgb = LAMP_WARM if i % 3 == 2 else LAMP_COOL
            lathe(posts, pc, [(0.12, CURB), (0.1, 1.0), (0.075, 7.6), (0.0, 7.7)], 8,
                  Matrix.Translation((x, y, 0)))
            # The arm, out over the road.
            lathe(posts, pc, [(0.0, 0.0), (0.05, 0.0), (0.05, 1.95), (0.0, 1.95)], 6,
                  Matrix.Translation((x, y, 7.45)) @ Matrix.Rotation(-side * math.pi / 2, 4, 'Y'))
            lathe(posts, pc, [(0.0, -0.08), (0.32, -0.04), (0.36, 0.02), (0.2, 0.12), (0.0, 0.14)],
                  10, Matrix.Translation((hx, y, 7.36)) @ Matrix.Diagonal((1.3, 0.8, 1.0, 1.0)))
            vs = puff(bulbs, bc, Vector((hx, y, 7.3)), 0.3, 2, 0.25)
            for v in vs:
                v[bc] = rgb + (1.0,)
            vs = lathe(cones, cc, [(3.3, 0.02), (0.28, 7.25)], 20,
                       Matrix.Translation((hx, y, 0)))
            for v in vs:
                v[cc] = rgb + (1.0,)
            glows.append((Vector((hx, y, 7.15)), rgb, 3.4))
            pools.append((Vector((hx, y, 0.03)), rgb, 7.5))
    bm_object("lamp_posts", posts, "LampPost")
    bm_object("lamp_bulbs", bulbs, "LampBulb")
    # Open cones: no caps, so no normal fixing.
    bm_object("lamp_cones", cones, "LightCone", recalc=False)
    bm_object("lamp_glows", vh.glow_quads(glows), "Glow", recalc=False)
    # Pools lie flat on the road: built in XY, not XZ.
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("Color")
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    for c, rgb, size in pools:
        vs = [bm.verts.new(c + Vector(((u - 0.5) * size, (w - 0.5) * size * 1.3, 0)))
              for u, w in ((0, 0), (1, 0), (1, 1), (0, 1))]
        for v in vs:
            v[col] = rgb + (1.0,)
        f = bm.faces.new(vs)
        for loop, (u, w) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = (u, w)
            loop[uv2].uv = (size, 0.0)
    bm_object("lamp_pools", bm, "Pool", recalc=False)


def trees(rnd):
    tb, tc = new_bm()
    lb, lc = new_bm()
    for side in (-1, 1):
        for i in range(16):
            y = 21.0 + i * 26.0 + (13.0 if side > 0 else 0.0)
            if in_cross(y, 4.0) or 40.0 < y < 56.0 and side < 0:
                continue
            # Standing on that pavement, the near trees would be in the way.
            if SIDEWALK and side < 0 and y < 60.0:
                continue
            x = side * 8.1
            s = rnd.uniform(0.85, 1.15)
            lathe(tb, tc, [(0.16 * s, CURB), (0.12 * s, 1.5 * s), (0.09 * s, 2.9 * s), (0.0, 3.1 * s)],
                  7, Matrix.Translation((x, y, 0)))
            tint = (rnd.uniform(0.8, 1.0), rnd.uniform(0.9, 1.05), rnd.uniform(0.8, 1.0))
            for k in range(rnd.randint(6, 8)):
                a = rnd.uniform(0, TAU)
                rr = rnd.uniform(0.0, 0.9) * s
                c = Vector((x + rr * math.cos(a) * 0.8, y + rr * math.sin(a), rnd.uniform(3.3, 4.6) * s))
                puff(lb, lc, c, rnd.uniform(0.8, 1.2) * s, 2, 0.85,
                     tuple(min(1.0, t * rnd.uniform(0.9, 1.05)) for t in tint), 0.3)
    bm_object("tree_trunks", tb, "Trunk")
    bm_object("tree_leaves", lb, "Leaves")


def bus_stop(X, y0=44.0, y1=50.5):
    x_back, x_front = -9.15, -7.7
    for yy in (y0, y1):
        for xx in (x_back, x_front):
            X.box("Shelter", xx - 0.05, xx + 0.05, yy - 0.05, yy + 0.05, CURB, 2.7)
    X.box("Shelter", x_back - 0.15, x_front + 0.25, y0 - 0.2, y1 + 0.2, 2.7, 2.82)
    X.box("ShelterGlass", x_back - 0.02, x_back + 0.02, y0, y1, 0.4, 2.55)
    X.box("Shelter", x_back + 0.1, x_back + 0.5, y0 + 0.6, y1 - 0.6, 0.55, 0.62)
    # The advert panel at the end, lit.
    X.box("Ad", x_back, x_front, y1 - 0.05, y1 + 0.05, 0.5, 2.4, (0.55, 0.45, 1.0, 1.0))


def moon():
    pos = place(0.35, 1.06, 900.0)
    to_cam = (tk.CAM_M.translation - pos).normalized()
    rot = to_cam.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    bm, col = new_bm()
    R = 34.0
    rings = []
    c = bm.verts.new(pos)
    c[col] = (1, 1, 1, 1)
    rings.append([c])
    for f in (0.35, 0.7, 1.0):
        ring = []
        for i in range(40):
            a = TAU * i / 40
            p = pos + rot @ Vector((R * f * math.cos(a), R * f * math.sin(a), 0))
            v = bm.verts.new(p)
            k = 0.86 + 0.14 * (0.5 + 0.5 * tk.n3(math.cos(a) * 2 * f, math.sin(a) * 2 * f, 3.1))
            v[col] = (k, k, min(1.0, k * 1.03), 1.0)
            ring.append(v)
        rings.append(ring)
    tk.bridge_rings(bm, rings)
    bm_object("moon", bm, "Moon", recalc=False)
    bm_object("moon_glow", vh.glow_quads([(pos + to_cam * 2.0, (0.5, 0.62, 0.95), R * 5.0)]),
              "Glow", recalc=False)


# ----------------------------------------------------------------- traffic

def lin(start, span, y0, y1):
    def f(t):
        u = ((t - start) % 1.0) / span
        return None if u > 1.0 else y0 + (y1 - y0) * u
    return f


def bus_timeline(t):
    """In from the haze, easing to a stop at the shelter, a wait, and away."""
    T = t * tk.LOOP
    stop = 53.0
    if T < 11.0:
        u = T / 11.0
        return stop + 110.0 * (1.0 - u) ** 1.5
    if T < 14.5:
        return stop
    tau = T - 14.5
    return stop - 0.5 * 3.4 * tau * tau


def bus_sign(root):
    L = vh.BUS["L"]
    X = L / 2
    bm, col = new_bm()
    quad(bm, [(X + 0.02, -1.05, 1.35), (X + 0.02, 1.05, 1.35), (X + 0.02, 1.05, 2.6),
              (X + 0.02, -1.05, 2.6)])
    bm_object("bus_windshield", bm, "Glass", root, recalc=False)
    bm, col = new_bm()
    quad(bm, [(X + 0.03, -0.95, 2.66), (X + 0.03, 0.95, 2.66), (X + 0.03, 0.95, 2.98),
              (X + 0.03, -0.95, 2.98)])
    bm_object("bus_signboard", bm, "LampPost", root, recalc=False)
    cu = bpy.data.curves.new("bus_text", 'FONT')
    cu.body = "56 DOWNTOWN"
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.size = 0.2
    txt = bpy.data.objects.new("bus_text", cu)
    tk.SCENE.collection.objects.link(txt)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(txt.evaluated_get(dg))
    bpy.data.objects.remove(txt, do_unlink=True)
    # Text is laid in XY reading along +X; stand it on the bus's front
    # (+X), reading along +Y as seen by someone facing the bus.
    m = Matrix(((0, 0, 1, X + 0.045), (1, 0, 0, 0), (0, 1, 0, 2.82), (0, 0, 0, 1)))
    me.transform(m)
    me.materials.append(tk.material("BusSign"))
    o = bpy.data.objects.new("bus_text", me)
    tk.SCENE.collection.objects.link(o)
    o.parent = root


def traffic():
    # Toward the camera on the left, away on the right.
    bus, bw = vh.vehicle("bus", vh.BUS, (0.14, 0.34, 0.95), sign=bus_sign, glass="BusGlass")
    vh.drive(bus, bw, vh.BUS, -4.5, -1, bus_timeline, far=165.0)
    cars = [
        ("taxi", vh.SEDAN, (1.0, 0.76, 0.06), True, -1.5, -1, lin(0.0, 0.88, 205, -14), 207),
        ("car_red", vh.HATCH, (0.62, 0.05, 0.08), False, -1.5, -1, lin(0.5, 0.88, 205, -14), 207),
        ("car_white", vh.SEDAN, (0.82, 0.84, 0.88), False, 1.5, 1, lin(0.15, 0.9, -14, 205), 207),
        ("car_black", vh.SEDAN, (0.07, 0.07, 0.09), False, 1.5, 1, lin(0.65, 0.9, -14, 205), 207),
        ("car_blue", vh.HATCH, (0.14, 0.24, 0.55), False, 4.5, 1, lin(0.35, 0.95, -14, 185), 187),
        ("car_grey", vh.SEDAN, (0.26, 0.28, 0.32), False, 4.5, 1, lin(0.85, 0.95, -14, 185), 187),
    ]
    for name, spec, rgb, taxi, lane, heading, fn, far in cars:
        root, ws = vh.vehicle(name, spec, rgb, taxi=taxi)
        vh.drive(root, ws, spec, lane, heading, fn, far=far)


# ------------------------------------------------------------------ people

COATS = [(0.1, 0.12, 0.2), (0.15, 0.15, 0.17), (0.6, 0.1, 0.14), (0.55, 0.4, 0.1),
         (0.1, 0.35, 0.4), (0.3, 0.15, 0.4), (0.35, 0.22, 0.12), (0.3, 0.36, 0.46),
         (0.05, 0.05, 0.06), (0.45, 0.47, 0.5)]
LEGS = [(0.08, 0.08, 0.1), (0.12, 0.13, 0.2), (0.2, 0.18, 0.15), (0.05, 0.05, 0.06)]
UMBRELLAS = [(0.06, 0.06, 0.08), (0.55, 0.08, 0.12), (0.12, 0.2, 0.5), (0.9, 0.75, 0.2)]

L_IN, R_IN = -(WALK + 1.2), WALK + 1.2

# (name, route, start phase, strides per loop, hood, umbrella)
WALKERS = [
    ("walk_l1", [(-7.5, 11.0), (-7.5, 30.0), (L_IN, 30.0)], 0.0, 18, False, False),
    ("walk_l2", [(L_IN, 36.0), (-8.5, 36.0), (-8.5, 11.0)], 0.35, 17, False, False),
    ("walk_l3", [(L_IN, 60.0), (-8.0, 60.0), (-8.0, 77.0), (L_IN, 77.0)], 0.15, 18, True, False),
    ("walk_l4", [(L_IN, 92.0), (-7.6, 92.0), (-7.6, 80.0), (L_IN, 80.0)], 0.6, 16, False, True),
    ("walk_l5", [(-8.2, 11.0), (-8.2, 27.0), (L_IN, 27.0)], 0.62, 19, True, False),
    ("walk_r1", [(R_IN, 34.0), (8.4, 34.0), (8.4, 11.0)], 0.1, 18, False, False),
    ("walk_r2", [(7.5, 11.0), (7.5, 27.0), (R_IN, 27.0)], 0.5, 16, False, True),
    ("walk_r3", [(R_IN, 58.0), (8.0, 58.0), (8.0, 75.0), (R_IN, 75.0)], 0.75, 18, False, False),
    ("walk_r4", [(R_IN, 97.0), (7.8, 97.0), (7.8, 82.0), (R_IN, 82.0)], 0.3, 18, False, True),
    ("walk_r5", [(R_IN, 31.0), (7.6, 31.0), (7.6, 11.0)], 0.82, 19, True, False),
]
if SIDEWALK:
    # The near ends of the left pavement's walks are behind the camera now:
    # they come past it, close, the way the hooded figure does in the painting.
    WALKERS[0] = ("walk_l1", [(-8.2, -4.0), (-8.2, 16.0), (L_IN, 16.0)], 0.0, 18, False, False)
    WALKERS[1] = ("walk_l2", [(L_IN, 18.0), (-9.0, 18.0), (-9.0, -4.0)], 0.35, 17, False, False)
    WALKERS[4] = ("walk_l5", [(-6.6, -4.0), (-6.6, 15.0), (L_IN, 15.0)], 0.62, 19, True, False)

# (name, position, facing yaw, umbrella)
STANDERS = [
    ("wait_1", (-8.0, 45.2), -math.pi / 2, False),
    ("wait_2", (-8.6, 47.6), math.pi * 0.85, True),
    ("wait_3", (-7.9, 49.6), -0.3, False),
    ("wait_4", (8.9, 44.0), math.pi / 2, False),
]


def door_spots():
    spots = []
    for _, route, *_ in WALKERS:
        for x, y in (route[0], route[-1]):
            if abs(x) > WALK:
                spots.append((1 if x > 0 else -1, y))
    return spots


def people(rnd):
    for i, (name, route, start, cycles, hood, umb) in enumerate(WALKERS):
        rig = fg.body(name, height=rnd.uniform(1.62, 1.86), build=rnd.uniform(1.0, 1.25),
                      coat=rnd.choice(COATS), legs=rnd.choice(LEGS), hood=hood, seed=100 + i)
        if umb:
            fg.apply_pose(rig, fg.walk_pose(0.0, hold_right=True))
            bpy.context.view_layer.update()
            fg.umbrella(rig, rnd.choice(UMBRELLAS), seed=i)
        fg.walker(rig, route, start, cycles=cycles, hold_right=umb)
    for i, (name, (x, y), yaw, umb) in enumerate(STANDERS):
        rig = fg.body(name, height=rnd.uniform(1.62, 1.86), build=rnd.uniform(1.0, 1.25),
                      coat=rnd.choice(COATS), legs=rnd.choice(LEGS), seed=200 + i)
        rig.location = (x, y, CURB)
        rig.rotation_euler = Euler((0, 0, yaw))
        if umb:
            fg.apply_pose(rig, fg.idle_pose(0.0, 200 + i, hold_right=True))
            bpy.context.view_layer.update()
            fg.umbrella(rig, rnd.choice(UMBRELLAS), seed=50 + i)
        fg.stander(rig, (x, y, CURB), yaw, 200 + i, hold_right=umb)


# ------------------------------------------------------------------- scene

def build():
    rnd = random.Random(20260929)
    ground()
    B = Blocks()
    X = Extras()
    spots = door_spots()
    street_side(B, X, -1, rnd)
    street_side(B, X, 1, rnd)
    skyline(B, X, rnd)
    doors(X, spots)
    bus_stop(X)
    bm_object("buildings", B.bm, "Building", recalc=False)
    X.finish()
    streetlamps()
    trees(rnd)
    moon()
    traffic()
    people(rnd)


build()
tk.export("city" if SIDEWALK else "city__overhead")
