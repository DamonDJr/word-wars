"""Subway: an underground platform, as a 3D board.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/subway.py

Writes boards/3d/subway.glb (what the game loads for Subway) and
build/boards3d/subway.blend.

Late at night on the platform: the train standing at the left in its red
"12" livery, tail lights on; a tiled wall with red stripes and the line's
number across the track; a dark vault overhead with a line of fluorescent
tubes running off into the distance; and on the right, the yellow tactile
strip along the edge, steel pillars, benches, a bin, hanging signs and the
way up to the street. The floor is wet and reflects all of it.

What moves, on the 20 second loop: the train pulls out and away into the
dark, the next one comes in past the camera and brakes to a stop where the
last one stood; commuters wait and fidget; one comes down the stairs and one
goes up; a tube flickers; signals glow down the tunnel.

The train leaves by accelerating into the tunnel until the fog has it, and
arrives from behind the camera, so the loop joins: at the jump between the
two it is out of sight at both ends and shrunk to nothing for the frame
between, as the city's traffic is.

The framing rules and the contract with the game are in `toonkit.py`.
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
from toonkit import TAU, bm_object, empty, keyframes, lathe, new_bm, puff, smooth  # noqa: E402

PALETTE = {
    "Floor": "#ffffff", "Tactile": "#f0c030", "Edge": "#3a3e4a", "Ballast": "#2a2a30",
    "Rail": "#9aa0b0", "Tiles": "#ffffff", "TilesDark": "#ffffff", "Vault": "#1a2032",
    "Fixture": "#2c3242", "Tube": "#d4e8ff", "TubeFlicker": "#d4e8ff", "Glow": "#ffffff",
    "Pillar": "#3c4660", "Steel": "#707c96", "TrainGlass": "#b4c8e6", "TailLight": "#ff2a2a",
    "Sign": "#ff3030", "SignPanel": "#141820", "SignText": "#f4f6fa", "SignRed": "#d8141c",
    "Bench": "#3a4252", "Bin": "#7a8294", "Signal": "#ffffff", "Stairs": "#3a4050",
    "Person": "#ffffff",
}

tk.setup(PALETTE)
CAM = tk.camera(vfov=64.0, pitch=3.0, yaw=-7.0, loc=(1.8, 0.0, 1.7), sway=(0.06, 0.03),
                turn=(0.08, 0.2), clip_end=700.0)

WALL_L = -5.2       # the tiled wall across the track
EDGE = 0.0          # the platform edge
WALL_R = 8.0        # the wall behind the pillars
BED = -1.2          # the track bed
SPRING = 4.0        # where the vault springs from the walls
APEX = 6.3
Y0, Y_PLAT, Y_END = -14.0, 160.0, 460.0
STAIR = (20.0, 24.0)
TRAIN_X = -2.0
REAR0 = 14.0        # where the train's rear stands at the platform
CAR_L, CAR_GAP, CARS = 16.0, 0.7, 5
HW = 1.55           # half the train's width


def quad(bm, col, pts, rgb=(1, 1, 1), uvs=None, uv=None):
    vs = [bm.verts.new(p) for p in pts]
    for v in vs:
        v[col] = tuple(rgb) + (1.0,)
    f = bm.faces.new(vs)
    if uvs is not None:
        for loop, u in zip(f.loops, uvs):
            loop[uv].uv = u
    return f


def box(bm, col, x0, x1, y0, y1, z0, z1, rgb=(1, 1, 1)):
    v = [bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                  (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for q in v:
        q[col] = tuple(rgb) + (1.0,)
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([v[i] for i in f])


def text_mesh(name, body, size, xform, mat, parent=None):
    cu = bpy.data.curves.new(name + "_curve", 'FONT')
    cu.body = body
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.size = size
    cu.extrude = 0.01
    ob = bpy.data.objects.new(name + "_tmp", cu)
    tk.SCENE.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob, do_unlink=True)
    me.transform(xform)
    me.materials.append(tk.material(mat))
    o = bpy.data.objects.new(name, me)
    tk.SCENE.collection.objects.link(o)
    o.parent = parent
    return o


# Text lies in XY facing +Z. These stand it on a wall facing +X (the tiled
# wall, read from the platform) or facing -Y (toward the camera).
FACE_X = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
FACE_NEG_Y = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


# ---------------------------------------------------------------- station

def station():
    # The wet floor and the yellow strip along its edge.
    bm, col = new_bm()
    quad(bm, col, [(1.0, Y0, 0), (WALL_R, Y0, 0), (WALL_R, Y_PLAT, 0), (1.0, Y_PLAT, 0)])
    bm_object("floor", bm, "Floor", recalc=False)
    bm, col = new_bm()
    quad(bm, col, [(EDGE, Y0, 0.004), (1.0, Y0, 0.004), (1.0, Y_PLAT, 0.004), (EDGE, Y_PLAT, 0.004)])
    bm_object("tactile", bm, "Tactile", recalc=False)
    # The edge's face down to the track, the track bed, rails and sleepers.
    bm, col = new_bm()
    quad(bm, col, [(EDGE, Y_PLAT, BED), (EDGE, Y0, BED), (EDGE, Y0, 0.0), (EDGE, Y_PLAT, 0.0)])
    for y in range(int(Y0), int(Y_PLAT + 60)):
        if y % 1 == 0:
            box(bm, col, TRAIN_X - 1.3, TRAIN_X + 1.3, y + 0.1, y + 0.4, BED, BED + 0.1, (0.8, 0.8, 0.85))
    bm_object("track_edge", bm, "Edge", recalc=False)
    bm, col = new_bm()
    quad(bm, col, [(WALL_L, Y0, BED), (EDGE, Y0, BED), (EDGE, Y_END, BED), (WALL_L, Y_END, BED)])
    bm_object("ballast", bm, "Ballast", recalc=False)
    bm, col = new_bm()
    for x in (TRAIN_X - 0.72, TRAIN_X + 0.72):
        box(bm, col, x - 0.05, x + 0.05, Y0, Y_END, BED + 0.1, BED + 0.26)
    bm_object("rails", bm, "Rail")

    # The tiled walls, UV in metres (along, up).
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("Color")
    uv = bm.loops.layers.uv.new("UVMap")
    quad(bm, col, [(WALL_L, Y_PLAT, BED), (WALL_L, Y0, BED), (WALL_L, Y0, SPRING), (WALL_L, Y_PLAT, SPRING)],
         uvs=[(Y_PLAT, BED), (Y0, BED), (Y0, SPRING), (Y_PLAT, SPRING)], uv=uv)
    bm_object("wall_left", bm, "Tiles", recalc=False)
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("Color")
    uv = bm.loops.layers.uv.new("UVMap")
    for ya, yb in ((Y0, STAIR[0]), (STAIR[1], Y_PLAT)):
        quad(bm, col, [(WALL_R, ya, 0.0), (WALL_R, yb, 0.0), (WALL_R, yb, SPRING), (WALL_R, ya, SPRING)],
             uvs=[(ya, 0.0), (yb, 0.0), (yb, SPRING), (ya, SPRING)], uv=uv)
    # Over the stair opening.
    quad(bm, col, [(WALL_R, STAIR[0], 2.8), (WALL_R, STAIR[1], 2.8), (WALL_R, STAIR[1], SPRING),
                   (WALL_R, STAIR[0], SPRING)], uvs=[(STAIR[0], 2.8), (STAIR[1], 2.8),
                                                     (STAIR[1], SPRING), (STAIR[0], SPRING)], uv=uv)
    # The end of the platform, and the stairwell's sides.
    quad(bm, col, [(EDGE, Y_PLAT, 0.0), (WALL_R, Y_PLAT, 0.0), (WALL_R, Y_PLAT, SPRING), (EDGE, Y_PLAT, SPRING)],
         uvs=[(0, 0), (8, 0), (8, SPRING), (0, SPRING)], uv=uv)
    for y in STAIR:
        s = 1 if y == STAIR[0] else -1
        pts = [(WALL_R, y, 0.0), (WALL_R + 8, y, 0.0), (WALL_R + 8, y, 7.0), (WALL_R, y, 7.0)]
        quad(bm, col, pts if s > 0 else list(reversed(pts)),
             uvs=[(0, 0), (8, 0), (8, 7), (0, 7)] if s > 0 else [(0, 7), (8, 7), (8, 0), (0, 0)], uv=uv)
    bm_object("wall_right", bm, "TilesDark", recalc=False)

    # The stairs up to the street, and the corridor's ceiling.
    bm, col = new_bm()
    for k in range(16):
        x0 = WALL_R + 1.5 + k * 0.32
        box(bm, col, x0, x0 + 0.32, STAIR[0], STAIR[1], -0.1, (k + 1) * 0.18)
    box(bm, col, WALL_R, WALL_R + 8, STAIR[0], STAIR[1], 2.8, 3.0)
    bm_object("stairs", bm, "Stairs")

    # The vault, the whole length, and the tunnel beyond the platform.
    bm, col = new_bm()
    rows = []
    N = 18
    for j, y in enumerate(range(int(Y0), int(Y_END) + 1, 3)):
        cx, a, b = (WALL_L + WALL_R) / 2, (WALL_R - WALL_L) / 2, APEX - SPRING
        rib = 0.78 if j % 2 else 1.0
        row = []
        for i in range(N + 1):
            th = math.pi * (1 - i / N)
            v = bm.verts.new((cx + a * math.cos(th), y, SPRING + b * math.sin(th)))
            v[col] = (rib, rib, rib, 1.0)
            row.append(v)
        rows.append(row)
    for ra, rb in zip(rows, rows[1:]):
        for i in range(N):
            bm.faces.new((ra[i], rb[i], rb[i + 1], ra[i + 1]))
    # Beyond the platform the walls come down to the track.
    for x, s in ((WALL_L, 1), (EDGE + 0.3, -1)):
        pts = [(x, Y_PLAT, BED), (x, Y_END, BED), (x, Y_END, SPRING), (x, Y_PLAT, SPRING)]
        vs = [bm.verts.new(p) for p in (pts if s > 0 else list(reversed(pts)))]
        for v in vs:
            v[col] = (0.6, 0.6, 0.6, 1.0)
        bm.faces.new(vs)
    bm_object("vault", bm, "Vault", recalc=False)

    # The far wall of the tunnel where it ends, in the dark.
    bm, col = new_bm()
    quad(bm, col, [(WALL_L, Y_END, BED), (WALL_R, Y_END, BED), (WALL_R, Y_END, APEX), (WALL_L, Y_END, APEX)])
    bm_object("tunnel_end", bm, "Vault", recalc=False)


def fittings():
    rnd = random.Random(5)
    # Pillars down the platform.
    bm, col = new_bm()
    for k in range(18):
        y = 6.0 + k * 9.0
        if STAIR[0] - 2 < y < STAIR[1] + 2:
            continue
        box(bm, col, 5.3, 6.0, y, y + 0.7, 0.0, 6.6)
    bm_object("pillars", bm, "Pillar")

    # The line of tubes down the ceiling, a housing and a tube each, hung on
    # rods; and the halos round the near ones.
    fx, ft, ff = new_bm(), new_bm(), new_bm()
    glows = []
    flick_at = 31.0
    y = -6.0
    while y < Y_PLAT:
        box(fx[0], fx[1], 2.05, 2.45, y, y + 2.2, 5.45, 5.6)
        box(fx[0], fx[1], 2.22, 2.28, y + 0.5, y + 0.56, 5.6, 6.3)
        target = ff if abs(y - flick_at) < 1.3 else ft
        box(target[0], target[1], 2.12, 2.38, y + 0.05, y + 2.15, 5.39, 5.45, (1, 1, 1))
        if y < 70:
            glows.append((Vector((2.25, y + 1.1, 5.3)), (0.72, 0.84, 1.0), 2.6))
        y += 2.5
    bm_object("fixtures", fx[0], "Fixture")
    bm_object("tubes", ft[0], "Tube")
    bm_object("tube_flicker", ff[0], "TubeFlicker")
    bm_object("tube_glows", vh.glow_quads(glows), "Glow", recalc=False)

    # Hanging signs with an arrow, facing the camera.
    bp, cp = new_bm()
    ba, ca = new_bm()
    for y in (18.0, 44.0, 80.0):
        box(bp, cp, 3.2, 5.2, y, y + 0.08, 4.5, 5.1)
        for x in (3.5, 4.9):
            box(bp, cp, x - 0.03, x + 0.03, y, y + 0.06, 5.1, 6.0)
        # The arrow: a shaft and a head, on the camera side of the panel.
        yy = y - 0.01
        quad(ba, ca, [(4.12, yy, 4.6), (4.28, yy, 4.6), (4.28, yy, 4.88), (4.12, yy, 4.88)])
        quad(ba, ca, [(3.98, yy, 4.86), (4.42, yy, 4.86), (4.2, yy, 5.02)])
    bm_object("sign_panels", bp, "SignPanel")
    bm_object("sign_arrows", ba, "SignText", recalc=False)

    # The line's number on the tiled wall, a red bar under it.
    bp, cp = new_bm()
    br, cr = new_bm()
    for y in (24.0, 62.0, 100.0, 138.0):
        box(bp, cp, WALL_L, WALL_L + 0.06, y - 0.9, y + 0.9, 1.4, 3.4)
        box(br, cr, WALL_L, WALL_L + 0.08, y - 0.6, y + 0.6, 1.65, 1.8)
        text_mesh("line_%d" % int(y), "12", 1.0,
                  Matrix.Translation((WALL_L + 0.08, y, 2.55)) @ FACE_X, "SignText")
    bm_object("wall_signs", bp, "SignPanel")
    bm_object("wall_sign_bars", br, "SignRed")

    # Benches and a bin.
    bb, cb = new_bm()
    for y in (30.0, 66.0, 102.0):
        box(bb, cb, 6.6, 7.5, y, y + 3.0, 0.45, 0.55)
        box(bb, cb, 7.4, 7.55, y, y + 3.0, 0.55, 1.1)
        for yy in (y + 0.2, y + 2.7):
            box(bb, cb, 6.7, 6.8, yy, yy + 0.1, 0.0, 0.45)
            box(bb, cb, 7.3, 7.4, yy, yy + 0.1, 0.0, 0.45)
    bm_object("benches", bb, "Bench")
    bb, cb = new_bm()
    for y in (15.0, 52.0):
        lathe(bb, cb, [(0.0, 0.0), (0.3, 0.0), (0.3, 0.95), (0.33, 1.0), (0.0, 1.02)], 14,
              Matrix.Translation((6.9, y, 0.0)))
    bm_object("bins", bb, "Bin")

    # Signals down the tunnel.
    bs, cs = new_bm()
    sg = []
    for y, rgb in ((210.0, (1.0, 0.15, 0.1)), (270.0, (0.2, 1.0, 0.45)), (340.0, (1.0, 0.15, 0.1)),
                   (420.0, (1.0, 0.75, 0.2))):
        puff(bs, cs, Vector((EDGE + 0.15, y, 2.2)), 0.16, 2, 1.0, rgb)
        sg.append((Vector((EDGE + 0.05, y, 2.2)), rgb, 3.0))
    bm_object("signals", bs, "Signal")
    bm_object("signal_glows", vh.glow_quads(sg), "Glow", recalc=False)


# ------------------------------------------------------------------ train

def car(parent, y0, rear):
    """One car, rear at y0: a steel body with a red stripe below the windows,
    the windows a lit band broken by piers. The rear car carries the face."""
    bm, col = new_bm()
    steel, red = (0.62, 0.65, 0.72), (1.0, 0.1, 0.12)
    sec = [((0.0, -0.95), steel), ((HW - 0.08, -0.95), steel), ((HW, -0.87), steel),
           ((HW, 0.25), steel), ((HW, 0.26), red), ((HW, 0.52), red), ((HW, 0.53), steel),
           ((HW, 0.95), steel), ((HW, 1.95), steel), ((HW, 2.3), steel),
           ((HW - 0.2, 2.62), steel), ((HW - 0.55, 2.76), steel), ((0.0, 2.8), steel)]
    ring_pts = sec + [((-w, z), c) for (w, z), c in reversed(sec[1:-1])]
    nsec = len(sec)
    stations = set(round(y0 + i * 0.4, 3) for i in range(int(CAR_L / 0.4) + 1))
    wins = []
    x = 1.2
    while x + 1.4 < CAR_L - 1.0:
        wins.append((y0 + x, y0 + x + 1.4))
        stations.add(round(y0 + x, 3))
        stations.add(round(y0 + x + 1.4, 3))
        x += 2.1
    stations = sorted(stations)
    rings = []
    for y in stations:
        ring = []
        for (w, z), c in ring_pts:
            v = bm.verts.new((TRAIN_X + w, y, z))
            v[col] = c + (1.0,)
            ring.append(v)
        rings.append(ring)
    m = len(ring_pts)
    for i in range(len(stations) - 1):
        ym = 0.5 * (stations[i] + stations[i + 1])
        lit = any(a <= ym <= b for a, b in wins)
        for j in range(m):
            f = bm.faces.new((rings[i][j], rings[i + 1][j], rings[i + 1][(j + 1) % m], rings[i][(j + 1) % m]))
            seg = j if j < nsec - 1 else m - 1 - j
            f.material_index = 1 if (lit and seg == 7) else 0
    for ring, y in ((rings[0], stations[0]), (rings[-1], stations[-1])):
        c = bm.verts.new((TRAIN_X, y, 0.9))
        c[col] = steel + (1.0,)
        for j in range(m):
            f = bm.faces.new((c, ring[(j + 1) % m], ring[j]))
            f.material_index = 0
    body = bm_object("car_%d" % int(y0), bm, ["Steel", "TrainGlass"], parent)
    if not rear:
        return body

    # The rear face: a door with a window, two side windows, the tail
    # lights low down, the number in a red ring at the top, a coupler.
    yf = y0 - 0.02
    bg, cg = new_bm()
    for x0, x1, z0, z1 in ((TRAIN_X - 0.36, TRAIN_X + 0.36, 0.95, 2.0),
                           (TRAIN_X - 1.28, TRAIN_X - 0.72, 1.0, 1.95),
                           (TRAIN_X + 0.72, TRAIN_X + 1.28, 1.0, 1.95)):
        quad(bg, cg, [(x0, yf, z0), (x1, yf, z0), (x1, yf, z1), (x0, yf, z1)])
    bm_object("train_windows", bg, "TrainGlass", parent, recalc=False)
    bd, cd = new_bm()
    box(bd, cd, TRAIN_X - 0.48, TRAIN_X + 0.48, yf - 0.03, yf, -0.6, 2.15, (0.5, 0.52, 0.58))
    box(bd, cd, TRAIN_X - 0.22, TRAIN_X + 0.22, yf - 0.5, yf, -0.7, -0.35, (0.3, 0.3, 0.34))
    bm_object("train_door", bd, "Steel", parent)
    bl, cl = new_bm()
    for x in (TRAIN_X - 1.0, TRAIN_X + 1.0):
        puff(bl, cl, Vector((x, yf - 0.02, 0.3)), 0.15, 2, 1.0)
    bm_object("train_tail", bl, "TailLight", parent)
    bm_object("train_tail_glow", vh.glow_quads([(Vector((x, yf - 0.15, 0.3)), (1.0, 0.12, 0.08), 2.4)
                                                for x in (TRAIN_X - 1.0, TRAIN_X + 1.0)]),
              "Glow", parent, recalc=False)
    br, cr = new_bm()
    seg = 40
    for i in range(seg):
        a0, a1 = TAU * i / seg, TAU * (i + 1) / seg
        pts = [(TRAIN_X + r * math.cos(a), yf - 0.01, 2.36 + r * math.sin(a))
               for r, a in ((0.27, a0), (0.33, a0), (0.33, a1), (0.27, a1))]
        quad(br, cr, list(reversed(pts)))
    bm_object("train_ring", br, "Sign", parent, recalc=False)
    text_mesh("train_number", "12", 0.3, Matrix.Translation((TRAIN_X, yf - 0.02, 2.35)) @ FACE_NEG_Y,
              "Sign", parent)
    return body


def train():
    root = empty("train", (0, 0, 0))
    for k in range(CARS):
        y0 = REAR0 + k * (CAR_L + CAR_GAP)
        car(root, y0, k == 0)
        if k:
            bm, col = new_bm()
            box(bm, col, TRAIN_X - 1.1, TRAIN_X + 1.1, y0 - CAR_GAP, y0, -0.6, 2.4, (0.2, 0.2, 0.24))
            bm_object("gangway_%d" % k, bm, "Bench", root)

    length = CARS * (CAR_L + CAR_GAP)

    def rear_at(T):
        if T < 4.0:
            return REAR0
        if T < 11.0:
            u = (T - 4.0) / 7.0
            return REAR0 + 280.0 * u * u
        if T < 11.5:
            return REAR0 + 280.0
        back = -length - 6.0
        if T < 12.0:
            return back
        if T < 19.0:
            u = (T - 12.0) / 7.0
            return back + (REAR0 - back) * (1.0 - (1.0 - u) ** 2)
        return REAR0

    def f(t):
        T = t * tk.LOOP
        s = 0.001 if 11.3 <= T <= 11.7 else 1.0
        return Vector((0.0, rear_at(T) - REAR0, 0.0)), None, (s, s, s)
    keyframes(root, f, step=1)


# ----------------------------------------------------------------- people

def people():
    rnd = random.Random(41)
    coats = [(0.12, 0.14, 0.22), (0.5, 0.12, 0.14), (0.2, 0.3, 0.42), (0.35, 0.28, 0.2),
             (0.08, 0.08, 0.09), (0.4, 0.42, 0.46)]
    legs = [(0.08, 0.08, 0.1), (0.14, 0.16, 0.24), (0.06, 0.06, 0.07)]
    standers = [("wait_1", (4.0, 26.5), math.pi / 2, False),
                ("wait_2", (3.1, 38.0), math.pi / 2 + 0.35, True),
                ("wait_3", (6.4, 33.0), math.pi / 2 - 0.2, False)]
    for i, (name, (x, y), yaw, phone) in enumerate(standers):
        rig = fg.body(name, height=rnd.uniform(1.62, 1.86), build=rnd.uniform(1.0, 1.25),
                      coat=rnd.choice(coats), legs=rnd.choice(legs), hood=(i == 2), seed=300 + i)
        fg.stander(rig, (x, y, 0.0), yaw, 300 + i, hold_right=phone)
    # One up the stairs, one down them: they vanish into and come out of the
    # stairwell, which the camera cannot see into past its first metre.
    walks = [("walk_up", [(5.0, 3.0), (5.0, 19.0), (7.6, 22.0), (9.5, 22.0), (11.5, 22.0, 1.1)], 0.1),
             ("walk_down", [(11.5, 22.5, 1.1), (9.5, 22.5), (7.4, 22.5), (4.2, 18.0), (4.2, 3.0)], 0.55)]
    for i, (name, route, start) in enumerate(walks):
        rig = fg.body(name, height=rnd.uniform(1.65, 1.85), build=rnd.uniform(1.0, 1.2),
                      coat=rnd.choice(coats), legs=rnd.choice(legs), seed=320 + i)
        fg.walker(rig, route, start, cycles=18)


def build():
    station()
    fittings()
    train()
    people()


build()
tk.export("subway")
