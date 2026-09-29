"""Cars and buses for the 3D boards, each body one smooth surface.

A body is lofted: a cross-section is swept from the rear bumper to the front
one, taking its height from a side profile (bumper, trunk, rear window, roof,
windshield, hood) and lifting its lower edge over each wheel, so the arches
are part of the same surface as everything else. The windows are faces of
that surface given a second material, not panes stuck on. One level of
subdivision rounds it all off. Wheels sit in the arches, lamps are sunk
halfway into the body, and nothing floats or reads as a separate block.

Local axes of a vehicle: +X forward, +Y to its left, +Z up, origin on the
ground between the axles. `drive()` moves one along a lane and turns its
wheels by the distance covered.

Materials: "Paint" (colour from vertex colour, so one material serves every
car), "Glass", "Tire", "Hub", "Headlight", "Taillight", plus "Glow" quads for
the halos (see `glow_quads`).
"""

import math
import random

import bmesh
from mathutils import Euler, Matrix, Vector

import toonkit as tk
from toonkit import TAU

SEDAN = {
    "L": 4.6, "W": 0.9, "clear": 0.28, "belt": 1.0, "roof_w": 0.66,
    "glass_top": None,
    # (fraction of length from the rear, height of the top line)
    "profile": [(0.0, 0.6), (0.025, 0.86), (0.09, 0.97), (0.23, 1.01), (0.37, 1.42),
                (0.45, 1.46), (0.6, 1.45), (0.745, 1.06), (0.9, 0.95), (0.975, 0.84),
                (1.0, 0.6)],
    "cabin": (0.22, 0.76), "roof": (0.36, 0.61), "pillar": 0.53,
    "wheels": (0.2, 0.79), "wheel_r": 0.34,
}
HATCH = dict(SEDAN, L=4.1, profile=[(0.0, 0.62), (0.03, 0.95), (0.08, 1.35), (0.14, 1.44),
                                    (0.55, 1.45), (0.7, 1.05), (0.88, 0.94), (0.97, 0.83),
                                    (1.0, 0.6)],
             cabin=(0.06, 0.71), roof=(0.13, 0.56), pillar=0.42, wheels=(0.17, 0.8))
BUS = {
    "L": 11.4, "W": 1.27, "clear": 0.36, "belt": 1.28, "roof_w": 1.2,
    "glass_top": 2.62,
    "profile": [(0.0, 0.55), (0.006, 2.95), (0.02, 3.12), (0.975, 3.12), (0.992, 2.96),
                (1.0, 0.6)],
    "cabin": (0.03, 0.965), "roof": (0.025, 0.985), "pillar": None,
    "wheels": (0.2, 0.84), "wheel_r": 0.5,
}


def _profile_fn(points):
    curve = tk.catmull([Vector(p) for p in points], per=12)

    def top(xf):
        for a, b in zip(curve, curve[1:]):
            if a.x <= xf <= b.x and b.x > a.x:
                t = (xf - a.x) / (b.x - a.x)
                return a.y + (b.y - a.y) * t
        return curve[-1].y if xf > 0.5 else curve[0].y
    return top


def _section(zb, zt, W, belt, roof_w, cabin, glass_top):
    """Right half of a cross-section, bottom centre to top centre: ten
    points. Stations with no cabin collapse the greenhouse points onto a
    rounded hood edge, so every station has the same count."""
    zbelt = min(belt, zt - 0.03)
    gw = W * 0.93 * (1.0 - cabin) + roof_w * cabin
    gt = zt - 0.08 if glass_top is None else min(glass_top, zt - 0.08)
    gt = max(gt, zbelt + 0.04)
    return [
        (0.0, zb),
        (W * 0.86, zb),
        (W, zb + 0.08),
        (W, 0.5 * (zb + zbelt)),
        (W * 0.985, zbelt - 0.015),
        (W * 0.955, zbelt + 0.025),
        (gw + (W - gw) * 0.25 + 0.03, gt),
        (gw + 0.035, zt - 0.045),
        (gw - 0.03, zt),
        (0.0, zt),
    ]


def body(name, spec, rgb, parent=None, seed=0, glass="Glass"):
    """A vehicle's body: the lofted shell with its windows, as one mesh."""
    L, W = spec["L"], spec["W"]
    top = _profile_fn(spec["profile"])
    c0, c1 = spec["cabin"]
    r0, r1 = spec["roof"]
    wr = spec["wheel_r"]
    bm, col = tk.new_bm()
    N = 56 if L < 6 else 70
    rings, stations = [], []
    for i in range(N + 1):
        xf = i / N
        x = (xf - 0.5) * L
        zt = top(xf)
        zb = spec["clear"]
        for wf in spec["wheels"]:
            dx = (xf - wf) * L
            r = wr + 0.07
            if abs(dx) < r:
                zb = max(zb, wr + math.sqrt(r * r - dx * dx) * 0.92)
        cabin = tk.smooth(c0 - 0.04, c0 + 0.02, xf) * (1.0 - tk.smooth(c1 - 0.02, c1 + 0.04, xf))
        # Round the ends: pull the section in over the last few centimetres.
        end = min(xf, 1.0 - xf) * L
        pinch = math.sqrt(max(0.0, 1.0 - (1.0 - min(end / 0.12, 1.0)) ** 2)) * 0.12 + 0.88
        half = _section(zb, zt, W * pinch, spec["belt"], spec["roof_w"] * pinch, cabin,
                        spec["glass_top"])
        pts = half + [(-y, z) for y, z in reversed(half[1:-1])]
        ring = []
        for y, z in pts:
            v = bm.verts.new((x, y, z))
            v[col] = rgb + (1.0,)
            ring.append(v)
        rings.append(ring)
        stations.append((xf, zt, cabin))
    faces = []
    for i in range(N):
        a, b = rings[i], rings[i + 1]
        xf = 0.5 * (stations[i][0] + stations[i + 1][0])
        zt = 0.5 * (stations[i][1] + stations[i + 1][1])
        cab = min(stations[i][2], stations[i + 1][2])
        m = len(a)
        for j in range(m):
            f = bm.faces.new((a[j], a[(j + 1) % m], b[(j + 1) % m], b[j]))
            seg = j if j < 9 else 17 - j
            pane = False
            if cab > 0.5:
                if seg == 5 or seg == 6:
                    pane = True
                    if spec["pillar"] is not None and abs(xf - spec["pillar"]) < 0.018:
                        pane = False
                if seg in (7, 8) and not (r0 <= xf <= r1):
                    pane = True
            f.material_index = 1 if pane else 0
            faces.append(f)
    # Caps.
    for ring, xf in ((rings[0], 0.0), (rings[-1], 1.0)):
        cz = sum(v.co.z for v in ring) / len(ring)
        c = bm.verts.new(((xf - 0.5) * L + (0.03 if xf < 0.5 else -0.03), 0.0, cz))
        c[col] = rgb + (1.0,)
        m = len(ring)
        for j in range(m):
            f = bm.faces.new((c, ring[(j + 1) % m], ring[j]))
            f.material_index = 0
    o = tk.bm_object(name, bm, ["Paint", glass], parent)
    sub = o.modifiers.new("round", 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 1
    return o


def wheels(name, spec, parent):
    """Four wheels in the arches, each its own object so it can turn."""
    L, W, r = spec["L"], spec["W"], spec["wheel_r"]
    out = []
    for wf in spec["wheels"]:
        for side in (1, -1):
            bm, col = tk.new_bm()
            w = 0.24 if L < 6 else 0.3
            prof = [(0.0, -w / 2), (r * 0.8, -w / 2), (r * 0.97, -w / 2 + 0.03), (r, 0.0),
                    (r * 0.97, w / 2 - 0.03), (r * 0.8, w / 2), (0.0, w / 2)]
            # Axle along Y.
            tk.lathe(bm, col, prof, 18, Matrix.Rotation(math.pi / 2, 4, 'X'),
                     color=lambda t: (1.0, 1.0, 1.0))
            o = tk.bm_object("%s_wheel%d%s" % (name, int(wf * 10), "L" if side > 0 else "R"),
                             bm, "Tire", parent,
                             loc=((wf - 0.5) * L, side * (W - 0.13), r))
            hb, hc = tk.new_bm()
            tk.lathe(hb, hc, [(0.0, 0.0), (r * 0.55, 0.0), (r * 0.5, 0.02), (0.0, 0.04)], 12,
                     Matrix.Translation((0, side * w / 2, 0))
                     @ Matrix.Rotation(-side * math.pi / 2, 4, 'X'))
            tk.bm_object(o.name + "_hub", hb, "Hub", o)
            out.append(o)
    return out


def lamps(name, spec, parent, head=True, tail=True, glows=True):
    """Head and tail lamps sunk into the body, and their halos."""
    L, W = spec["L"], spec["W"]
    top = _profile_fn(spec["profile"])
    big = L > 6
    for kind, xf, mat in (("head", 0.992, "Headlight"), ("tail", 0.008, "Taillight")):
        if (kind == "head" and not head) or (kind == "tail" and not tail):
            continue
        bm, col = tk.new_bm()
        z = 0.72 if not big else 0.75
        x = (xf - 0.5) * L
        for side in (1, -1):
            y = side * (W - (0.22 if not big else 0.3))
            tk.puff(bm, col, Vector((x, y, z)), 0.11 if not big else 0.14, 2, 0.55)
        tk.bm_object("%s_%slamps" % (name, kind), bm, mat, parent)
        if glows:
            gb = glow_quads([(Vector((x + (0.12 if kind == "head" else -0.12), side * (W - 0.22), z)),
                              (1.0, 0.93, 0.75) if kind == "head" else (1.0, 0.15, 0.1),
                              1.1 if kind == "head" else 0.6) for side in (1, -1)])
            tk.bm_object("%s_%sglow" % (name, kind), gb, "Glow", parent, recalc=False)


def glow_quads(items):
    """Billboard halos. `items` is [(centre, rgb, size)].

    Each quad is built flat in the local XZ plane, `size` across, with UV
    marking the corner and UV2.x carrying the size, so the glow shader can
    find the centre from any corner and turn the quad to face the camera.
    (Four corners on one point would be simpler, and Godot's importer
    throws degenerate faces away.)"""
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("Color")
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    for c, rgb, size in items:
        c = Vector(c)
        vs = [bm.verts.new(c + Vector(((u - 0.5) * size, 0.0, (w - 0.5) * size)))
              for u, w in ((0, 0), (1, 0), (1, 1), (0, 1))]
        for v in vs:
            v[col] = tuple(rgb) + (1.0,)
        f = bm.faces.new(vs)
        for loop, (u, w) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = (u, w)
            loop[uv2].uv = (size, 0.0)
    return bm


def vehicle(name, spec, rgb, taxi=False, sign=None, seed=0, glass="Glass"):
    """A whole vehicle under one empty; returns (root, wheels)."""
    root = tk.empty(name)
    body(name + "_body", spec, rgb, root, seed, glass)
    ws = wheels(name, spec, root)
    lamps(name, spec, root)
    if taxi:
        bm, col = tk.new_bm()
        top = _profile_fn(spec["profile"])(0.5)
        tk.lathe(bm, col, [(0.0, 0.0), (0.2, 0.0), (0.2, 0.16), (0.0, 0.2)], 4,
                 Matrix.Translation((0.0, 0.0, top - 0.01)) @ Matrix.Rotation(math.pi / 4, 4, 'Z')
                 @ Matrix.Diagonal((1.4, 0.55, 1.0, 1.0)))
        tk.bm_object(name + "_sign", bm, "TaxiSign", root)
    if sign:
        sign(root)
    return root, ws


def drive(root, wheel_objs, spec, lane_x, heading, y_of_t, step=1, far=None):
    """Key a vehicle along the lane x = `lane_x`. `heading` +1 drives toward
    +Y, -1 toward the camera. `y_of_t(t)` gives its y at loop phase t, or
    None while it is off the road (it is then shrunk to nothing, so the jump
    back to the start happens unseen). Past `far - 16` it shrinks toward
    nothing at `far`, so it comes out of the haze rather than popping in."""
    yaw = math.pi / 2 if heading > 0 else -math.pi / 2
    r = spec["wheel_r"]
    last_y = None
    spin = 0.0
    for f in range(0, tk.FRAMES + 1, step):
        t = f / tk.FRAMES
        y = y_of_t(t)
        vis = 1.0
        if y is None:
            y = last_y if last_y is not None else 0.0
            vis = 0.0
        if last_y is not None and vis > 0:
            spin += abs(y - last_y) / r
        last_y = y
        root.location = (lane_x, y, 0.0)
        root.rotation_euler = Euler((0, 0, yaw))
        if far is not None:
            vis *= tk.clamp((far - y) / 16.0)
        # Never quite zero: Godot cannot make a rotation out of a zero-scale
        # basis and says so every frame.
        vis = max(vis, 0.001)
        root.scale = (vis, vis, vis)
        root.keyframe_insert("location", frame=f)
        root.keyframe_insert("rotation_euler", frame=f)
        root.keyframe_insert("scale", frame=f)
        for w in wheel_objs:
            w.rotation_euler = Euler((0, spin, 0))
            w.keyframe_insert("rotation_euler", frame=f)
