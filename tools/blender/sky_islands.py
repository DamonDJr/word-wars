"""Sky Islands: the Clouds board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/sky_islands.py

Writes two files:

    boards/3d/sky_islands.glb          what the game loads for Clouds
    build/boards3d/sky_islands.blend   the same scene, to open and push around

`LD_LIBRARY_PATH` is there because OpenVINO's ld.so.conf entry puts its own,
older libtbb ahead of the system one, and Blender dies on a missing symbol
without it.

The cartoon look is not in here. Blender supplies shapes, a base colour per
material, vertex colours for the variation inside a material, and the motion;
`scripts/board3d.gd` swaps every material for a toon shader by name when the
scene loads. So the Blender viewport shows flat plastic, and the game shows
the board. Recolour a material here and the toon shading follows it.

Everything that moves is keyframed on one 20 second loop, and every motion
repeats a whole number of times inside it, so the loop has no seam. The
things that cross the screen (the flock, the high puffs) jump back while they
are out of frame, and shrink to nothing for the two frames either side of the
jump so the interpolated frame between can never be seen. Waterfalls and the
wind in the trees are shader work in Godot, not keyframes.

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
from toonkit import (TAU, bm_object, bridge_rings, clamp, cloud, crossing,  # noqa: E402
                     crossing_cloud, empty, keyframes, lathe, mix, mul, n3,
                     new_bm, place, puff, ribbon)

VFOV = 56.0
PITCH = 4.0

# Lit colour per material, as sRGB. The toon shader's shadow and outline
# colours for each live in `board3d.gd`, next to the shader that uses them.
PALETTE = {
    "Grass": "#9ed85a",
    "Rock": "#e3ab78",
    "Leaves": "#80d052",
    "Pine": "#4fb46e",
    "Trunk": "#a46d46",
    "Cloud": "#ffffff",
    "Foam": "#ffffff",
    "Pebble": "#cdc6dc",
    "Flower": "#ffffff",
    "Bird": "#34476f",
    "Water": "#7fd6f5",
    "Stream": "#7fd6f5",
}

tk.setup(PALETTE)
tk.camera(vfov=VFOV, pitch=PITCH)


# ------------------------------------------------------------------ islands

def island_shape(R, seed):
    h = 0.12 * R

    def rim(th):
        c, s = math.cos(th), math.sin(th)
        return R * (1.0 + 0.11 * n3(c * 1.2 + seed * 1.7, s * 1.2 - seed, 0.5)
                    + 0.035 * math.sin(3.0 * th + seed))

    def top(rho, th):
        x, y = rho * math.cos(th), rho * math.sin(th)
        bump = 0.07 * R * n3(x * 2.4 + seed * 3.1, y * 2.4 - seed, 2.3)
        return h * (1.0 - rho ** 2.4) + bump * (1.0 - rho ** 4)

    return rim, top


def grass_cap(name, R, rim, top, seed, parent):
    bm, col = new_bm()
    NT = 84
    kd = 9 + seed % 5

    def drip(th):
        s = max(0.0, math.sin(th * kd + seed * 2.3)) ** 3
        m = 0.55 + 0.45 * (0.5 + 0.5 * n3(math.cos(th) * 3 + seed,
                                          math.sin(th) * 3, 4.2))
        return s * m

    # (rho, z, shade) for each ring, top to bottom.
    specs = [
        lambda th: (0.25, top(0.25, th), 1.0),
        lambda th: (0.50, top(0.50, th), 1.0),
        lambda th: (0.72, top(0.72, th), 0.98),
        lambda th: (0.88, top(0.88, th), 0.96),
        lambda th: (0.97, top(0.97, th) - 0.012 * R, 0.93),
        lambda th: (1.02, -0.03 * R, 0.86),
        lambda th: (1.035, -0.085 * R, 0.8),
        lambda th: (1.02 - 0.04 * drip(th), -0.13 * R - 0.28 * R * drip(th), 0.72),
        lambda th: (0.93, -0.15 * R - 0.12 * R * drip(th), 0.66),
        lambda th: (0.78, -0.13 * R, 0.66),
    ]

    def patch(x, y):
        k = 0.5 + 0.5 * n3(x * 1.3 / R + seed, y * 1.3 / R, 7.7)
        return mix((0.86, 0.97, 0.9), (1.0, 1.0, 0.8), clamp(k * 1.4 - 0.2))

    c_top = bm.verts.new((0, 0, top(0.0, 0.0)))
    c_top[col] = patch(0, 0) + (1.0,)
    rings = [[c_top]]
    for spec in specs:
        ring = []
        for i in range(NT):
            th = TAU * i / NT
            rho, z, shade = spec(th)
            r = rho * rim(th)
            x, y = r * math.cos(th), r * math.sin(th)
            v = bm.verts.new((x, y, z))
            rgb = mul(patch(x, y), (shade, shade, shade))
            v[col] = rgb + (1.0,)
            ring.append(v)
        rings.append(ring)
    c_bot = bm.verts.new((0, 0, -0.12 * R))
    c_bot[col] = (0.66, 0.66, 0.66, 1.0)
    rings.append([c_bot])
    bridge_rings(bm, rings)
    return bm_object(name, bm, "Grass", parent)


def rock_body(name, R, depth, rim, seed, parent, rnd):
    """The rock under the grass: a lumpy, ledged cone with spikes under it.

    Shaded with the normals of the same cone *before* the lumps go on (plus a
    quarter of the real ones). A toon terminator drawn across every lump
    breaks the rock into camouflage blotches; drawn across the underlying
    cone it is one clean shadow down one side, and the lumps still show in
    the silhouette and the ink.
    """
    bm, col = new_bm()
    NT = 60
    NR = 20
    lean = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0)) * 0.18 * R
    z0 = -0.05 * R

    def rock_col(t, th):
        if t < 0.06:
            return (0.7, 0.52, 0.46)
        band = int(t * 6.0 + 0.6 * n3(math.cos(th) * 2 + seed, math.sin(th) * 2, t * 3))
        light = 1.0 if band % 2 == 0 else 0.88
        dark = 1.0 - 0.38 * t ** 1.3
        tint = mix((1.0, 1.0, 1.0), (0.74, 0.7, 0.92), t ** 1.4)
        return mul(tint, (light * dark,) * 3)

    top_c = bm.verts.new((0, 0, -0.02 * R))
    top_c[col] = (0.7, 0.52, 0.46, 1.0)
    rings = [[top_c]]
    rough = {}
    for j in range(NR):
        t = j / NR
        ring = []
        for i in range(NT):
            th = TAU * i / NT
            c, s = math.cos(th), math.sin(th)
            taper = (1.0 - t) ** 0.85
            ledge = 1.0 - 0.07 * ((t * 5.0 + 0.35 * n3(c + seed, s, t)) % 1.0)
            lump = 1.0 + 0.2 * n3(c * 1.5 + seed, s * 1.5, t * 2.2 + seed * 0.7)
            ridge = 1.0 + 0.05 * math.sin(th * 8.0 + seed + t * 3.0)
            r0 = 0.95 * rim(th) * taper
            p0 = Vector((r0 * c, r0 * s, z0 - depth * t)) + lean * t * t
            r = r0 * ledge * lump * ridge
            p = Vector((r * c, r * s, z0 - depth * t)) + lean * t * t
            v = bm.verts.new(p0)
            rough[v] = p
            v[col] = rock_col(t, th) + (1.0,)
            ring.append(v)
        rings.append(ring)
    tip = bm.verts.new(Vector((0, 0, z0 - depth * 1.02)) + lean)
    tip[col] = rock_col(1.0, 0.0) + (1.0,)
    rings.append([tip])
    bridge_rings(bm, rings)

    # Two or three smaller spikes hanging off the underside, so it reads as
    # rock torn out of the ground rather than as a cone.
    for k in range(rnd.randint(2, 3)):
        a = rnd.uniform(0, TAU)
        rr = rnd.uniform(0.3, 0.5) * R
        zt = z0 - depth * rnd.uniform(0.25, 0.4)
        L = depth * rnd.uniform(0.35, 0.55)
        w = rnd.uniform(0.18, 0.26) * R
        xf = Matrix.Translation((rr * math.cos(a), rr * math.sin(a), zt))
        prof = [(0.0, -L), (0.35 * w, -0.7 * L), (0.75 * w, -0.35 * L),
                (w, 0.0), (0.0, 0.15 * w)]
        lathe(bm, col, prof, 12, xf,
              color=lambda t: mul(rock_col(0.9 - 0.5 * t, a), (1, 1, 1)))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    smooth = [v.normal.copy() for v in bm.verts]
    for v, p in rough.items():
        v.co = p
    bm.normal_update()
    normals = [(0.75 * n + 0.25 * v.normal).normalized()
               for v, n in zip(bm.verts, smooth)]
    return bm_object(name, bm, "Rock", parent, recalc=False, normals=normals)


def tree_round(bt, ct, bl, cl, base, s, rnd):
    lean = Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), 0)) * s
    prof = [(0.11 * s, -0.12 * s), (0.1 * s, 0.25 * s), (0.08 * s, 0.6 * s),
            (0.06 * s, 1.0 * s), (0.0, 1.05 * s)]
    lathe(bt, ct, prof, 7, Matrix.Translation(base),
          offset=lambda t: lean * t * t,
          color=lambda t: (0.85 + 0.15 * t,) * 3)
    top = base + lean + Vector((0, 0, 1.0 * s))
    tint = (rnd.uniform(0.9, 1.0), rnd.uniform(0.95, 1.0), rnd.uniform(0.85, 1.0))
    puff(bl, cl, top + Vector((0, 0, 0.12 * s)), 0.46 * s, 2, 0.72, tint, 0.2)
    n = rnd.randint(5, 7)
    a0 = rnd.uniform(0, TAU)
    for i in range(n):
        a = a0 + TAU * i / n + rnd.uniform(-0.2, 0.2)
        p = top + Vector((0.42 * s * math.cos(a), 0.42 * s * math.sin(a),
                          rnd.uniform(-0.06, 0.08) * s))
        k = rnd.uniform(0.9, 1.0)
        puff(bl, cl, p, rnd.uniform(0.28, 0.36) * s, 2, 0.72, mul(tint, (k, k, k)), 0.25)
    for i in range(2):
        a = rnd.uniform(0, TAU)
        p = top + Vector((0.16 * s * math.cos(a), 0.16 * s * math.sin(a), 0.3 * s))
        puff(bl, cl, p, 0.26 * s, 2, 0.72, tint, 0.15)


def tree_pine(bt, ct, bp, cp, base, s, rnd):
    prof = [(0.08 * s, -0.12 * s), (0.07 * s, 0.35 * s), (0.0, 0.4 * s)]
    lathe(bt, ct, prof, 6, Matrix.Translation(base),
          color=lambda t: (0.85,) * 3)
    tint = (rnd.uniform(0.9, 1.0), 1.0, rnd.uniform(0.9, 1.0))
    for zb, r, h in ((0.25, 0.5, 0.72), (0.62, 0.4, 0.6), (0.95, 0.29, 0.55)):
        zb, r, h = zb * s, r * s, h * s
        prof = [(0.0, zb + 0.08 * s), (r * 0.92, zb - 0.02 * s), (r, zb + 0.03 * s),
                (r * 0.45, zb + h * 0.5), (0.0, zb + h)]
        lathe(bp, cp, prof, 12, Matrix.Translation(base),
              color=lambda t, tint=tint: mul(tint, (0.78 + 0.22 * t,) * 3))


def water(name, R, rim, top, th0, depth, parent):
    """A stream across the top and the fall off the edge, as two ribbons.

    UV.x runs across the ribbon and UV.y along it in units of the fall's
    width, so the shader's streaks are the same size on every island. UV2.x
    runs 0..1 down the fall, for the fade at the bottom.
    """
    w0 = 0.2 * R

    # The stream: from a spring inside the grass out to the lip.
    th_s = th0 + 0.8
    path = []
    N = 16
    for k in range(N + 1):
        u = k / N
        rho = 0.18 + 0.82 * u
        th = th_s + (th0 - th_s) * (u ** 0.7)
        r = rho * rim(th)
        z = top(min(rho, 0.97), th) + 0.03 * R
        if rho > 0.97:
            z = min(z, 0.0)
        path.append(Vector((r * math.cos(th), r * math.sin(th), z)))
    stream = ribbon(path, [w0 * (0.55 + 0.35 * (k / N)) for k in range(N + 1)],
                    bulge=0.0, v_scale=w0, fade=False)
    bm_object(name + "_stream", stream, "Stream", parent, recalc=False)

    # The fall: over the lip, out a little, then straight down past the tip.
    d = Vector((math.cos(th0), math.sin(th0), 0))
    p0 = Vector((rim(th0) * 1.0 * d.x, rim(th0) * 1.0 * d.y, 0.0))
    M = 30
    Lf = depth * 2.8
    path = []
    for k in range(M + 1):
        s = k / M
        out = 0.42 * R * (1.0 - math.exp(-7.0 * s))
        z = 0.02 * R - Lf * s ** 1.2
        path.append(p0 + d * out + Vector((0, 0, z)))
    fall = ribbon(path, [w0 * (1.0 + 0.9 * (k / M)) for k in range(M + 1)],
                  bulge=0.05 * R, v_scale=w0, fade=True, normal_hint=d)
    bm_object(name + "_fall", fall, "Water", parent, recalc=False)
    return p0


def island(name, sx, sy, d, R, depth_k, seed, trees=(), waterfall=None,
           flowers=0, bushes=0, bob=1.0):
    rnd = random.Random(seed)
    pos = place(sx, sy, d)
    root = empty(name, pos)
    rim, top = island_shape(R, seed)
    depth = R * depth_k
    grass_cap(name + "_grass", R, rim, top, seed, root)
    rock_body(name + "_rock", R, depth, rim, seed, root, rnd)

    # Which way is the camera, in the island's own frame. Waterfalls go a
    # little either side of it, so they are seen three-quarter on.
    to_cam = -pos
    th_cam = math.atan2(to_cam.y, to_cam.x)
    keep_clear = []
    if waterfall is not None:
        th0 = th_cam + waterfall
        lip = water(name + "_water", R, rim, top, th0, depth, root)
        keep_clear.append(th0 + 0.4)
        bf, cf = new_bm()
        for k in range(5):
            a = rnd.uniform(-0.5, 0.5)
            p = lip + Vector((math.cos(th0 + math.pi / 2), math.sin(th0 + math.pi / 2), 0)) \
                * a * 0.2 * R + Vector((0, 0, rnd.uniform(0.0, 0.04) * R))
            puff(bf, cf, p, rnd.uniform(0.05, 0.08) * R, 1, 0.8, (1, 1, 1))
        bm_object(name + "_foam", bf, "Foam", root)

    def spot(rmin, rmax):
        for _ in range(40):
            th = rnd.uniform(0, TAU)
            rho = rnd.uniform(rmin, rmax)
            if all(abs(math.atan2(math.sin(th - k), math.cos(th - k))) > 0.55
                   for k in keep_clear):
                break
        r = rho * rim(th)
        return Vector((r * math.cos(th), r * math.sin(th), top(rho, th) - 0.03 * R))

    if trees:
        bt, ct = new_bm()
        bl, cl = new_bm()
        bp, cp = new_bm()
        used = []
        for kind in trees:
            for _ in range(30):
                p = spot(0.0, 0.62)
                if all((p - q).length > 0.55 * R for q in used):
                    break
            used.append(p)
            s = R * rnd.uniform(0.42, 0.55)
            if kind == "pine":
                tree_pine(bt, ct, bp, cp, p, s * 1.1, rnd)
            else:
                tree_round(bt, ct, bl, cl, p, s, rnd)
        bm_object(name + "_trunks", bt, "Trunk", root)
        if len(bl.verts):
            bm_object(name + "_leaves", bl, "Leaves", root)
        else:
            bl.free()
        if len(bp.verts):
            bm_object(name + "_pines", bp, "Pine", root)
        else:
            bp.free()

    if bushes:
        bb, cb = new_bm()
        for _ in range(bushes):
            p = spot(0.7, 0.9)
            tint = (rnd.uniform(0.85, 0.95), 1.0, rnd.uniform(0.8, 0.95))
            for k in range(3):
                q = p + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0.4)) * 0.07 * R
                puff(bb, cb, q, rnd.uniform(0.08, 0.12) * R, 2, 0.8, tint, 0.25)
        bm_object(name + "_bushes", bb, "Leaves", root)

    if flowers:
        bfl, cfl = new_bm()
        hues = [(1.0, 0.72, 0.86), (1.0, 1.0, 1.0), (1.0, 0.9, 0.45), (0.8, 0.75, 1.0)]
        for _ in range(flowers):
            p = spot(0.2, 0.9) + Vector((0, 0, 0.035 * R))
            puff(bfl, cfl, p, 0.035 * R, 1, 1.0, rnd.choice(hues))
        bm_object(name + "_flowers", bfl, "Flower", root)

    # Bob, tilt and turn, each a whole number of times per loop.
    k = rnd.choice([1, 2, 2, 3])
    amp = 0.09 * R * bob
    tilt = math.radians(1.6) * bob
    yaw = math.radians(3.5) * bob
    ph = [rnd.uniform(0, TAU) for _ in range(4)]

    def f(t):
        loc = pos + Vector((0, 0, amp * math.sin(TAU * k * t + ph[0])))
        rot = Euler((tilt * math.sin(TAU * k * t + ph[1]),
                     tilt * math.cos(TAU * k * t + ph[2]),
                     yaw * math.sin(TAU * t + ph[3])))
        return loc, rot, None
    keyframes(root, f, step=2)
    return root


def pebbles(name, sx, sy, d, spread, count, seed, size):
    """Loose rocks hanging in the air beside an island, bobbing on their own."""
    rnd = random.Random(seed)
    for i in range(count):
        pos = place(sx, sy, d) + Vector((rnd.uniform(-1, 1) * spread,
                                         rnd.uniform(-1, 1) * spread * 0.5,
                                         rnd.uniform(-1, 1) * spread * 0.6))
        bm, col = new_bm()
        r = size * rnd.uniform(0.6, 1.2)
        verts = puff(bm, col, Vector((0, 0, 0)), r, 1, 0.8, (1, 1, 1))
        for v in verts:
            v.co *= 1.0 + 0.25 * n3(v.co.x * 3 / r + i, v.co.y * 3 / r, seed)
            v.co.z -= max(0.0, -v.co.z) * 0.6   # a pointed underside
            v[col] = (1.0, 1.0, 1.0, 1.0) if v.co.z > -0.2 * r else (0.75, 0.72, 0.88, 1.0)
        o = bm_object("%s_%d" % (name, i), bm, "Pebble", None, pos)
        k = rnd.choice([1, 2, 3])
        amp = spread * 0.12
        ph = rnd.uniform(0, TAU)
        spin = rnd.choice([-1, 1])
        base = Euler((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0))

        def f(t, pos=pos, k=k, amp=amp, ph=ph, spin=spin, base=base):
            return (pos + Vector((0, 0, amp * math.sin(TAU * k * t + ph))),
                    Euler((base.x, base.y, spin * TAU * t)), None)
        keyframes(o, f, step=2)


# -------------------------------------------------------------------- birds

def flock(name, sy, d, count, seed, start, span):
    rnd = random.Random(seed)
    root = empty(name, place(0.0, sy, d))
    half = tk.half_width(d) * 1.3
    base = place(0.0, sy, d)

    def f(t):
        u, vis = crossing(t, start, span)
        x = -half + 2 * half * u
        z = 0.5 * math.sin(u * math.pi * 2.0)
        return base + Vector((x, 0, z)), None, (vis, vis, vis)
    keyframes(root, f, step=1)

    for i in range(count):
        off = Vector((-i * 0.55 + rnd.uniform(-0.15, 0.15),
                      rnd.uniform(-0.8, 0.8),
                      (i % 2) * 0.35 - i * 0.12 + rnd.uniform(-0.1, 0.1)))
        s = rnd.uniform(0.85, 1.1)
        bird = empty("%s_bird%d" % (name, i), off, root)
        # Banked toward the camera so the wings open up rather than edge-on.
        bird.rotation_euler = Euler((math.radians(-28), 0, 0))
        bm, col = new_bm()
        lathe(bm, col, [(0.0, -0.2), (0.05, -0.12), (0.06, 0.0), (0.04, 0.12), (0.0, 0.2)],
              8, Matrix.Rotation(math.pi / 2, 4, 'Y') @ Matrix.Diagonal((s, s, s, 1)))
        bm_object(bird.name + "_body", bm, "Bird", bird)
        ph = rnd.uniform(0, TAU)
        flaps = rnd.choice([44, 48, 52])     # beats per loop, about 2.4 a second
        for side in (1, -1):
            bm = bmesh.new()
            vs = [bm.verts.new(Vector(p) * s) for p in
                  ((0.07, 0.0, 0.0), (-0.07, 0.0, 0.0), (-0.1, 0.22 * side, 0.03),
                   (-0.02, 0.4 * side, 0.0), (0.06, 0.2 * side, 0.02))]
            bm.faces.new(vs if side > 0 else list(reversed(vs)))
            wing = bm_object("%s_wing%s" % (bird.name, "L" if side > 0 else "R"),
                             bm, "Bird", bird, recalc=False, smooth=False)

            def fw(t, side=side, ph=ph, flaps=flaps):
                a = math.radians(38) * math.sin(TAU * flaps * t + ph) + math.radians(8)
                return None, Euler((-side * a, 0, 0)), None
            keyframes(wing, fw, step=1)


# -------------------------------------------------------------------- scene

def build():
    # Islands: (name, sx, sy, d, R, depth_k, seed, trees, waterfall, flowers, bushes)
    island("isle_left", -1.02, 0.36, 16, 2.2, 1.55, 11,
           trees=("round", "round"), waterfall=0.55, flowers=12, bushes=3)
    island("isle_right", 0.8, 0.44, 24, 1.6, 1.7, 23,
           trees=("round", "pine"), waterfall=-0.6, flowers=10, bushes=2)
    island("isle_topright", 0.5, 0.95, 27, 1.5, 1.8, 37,
           trees=("round",), flowers=5, bushes=1)
    island("isle_topleft", -0.58, 0.8, 30, 1.9, 1.6, 41,
           trees=("pine", "pine", "round"), waterfall=0.7, bushes=2)
    island("isle_centre", 0.1, 0.36, 48, 2.6, 1.6, 53,
           trees=("round", "round"), waterfall=-0.45, bushes=2, bob=0.8)
    island("isle_lowright", 0.8, -0.1, 16, 1.25, 1.5, 67,
           trees=("round",), waterfall=0.6, flowers=8, bushes=2)
    island("isle_lowleft", -0.78, -0.2, 15, 1.15, 1.5, 71,
           trees=("pine",), flowers=6, bushes=2)
    island("isle_far1", -0.28, 0.6, 78, 2.8, 1.5, 83, trees=("round",), bob=0.6)
    island("isle_far2", 0.42, 0.1, 92, 3.2, 1.4, 97, waterfall=0.3, bob=0.6)
    island("isle_top", -0.1, 1.1, 40, 1.4, 1.7, 101, trees=("round",), bushes=1)

    pebbles("pebble_left", -0.62, 0.1, 15, 0.9, 3, 5, 0.16)
    pebbles("pebble_right", 0.74, 0.2, 20, 0.9, 3, 6, 0.18)
    pebbles("pebble_top", 0.2, 0.9, 26, 1.4, 2, 7, 0.2)

    # The cloud sea, low in the frame where the keyboard is.
    cloud("sea_1", -0.6, -0.5, 14, (3.4, 1.4, 1.35), 16, 201)
    cloud("sea_2", 0.55, -0.6, 13, (3.6, 1.4, 1.4), 16, 202)
    cloud("sea_3", 0.0, -0.36, 22, (4.6, 2.0, 1.8), 18, 203)
    cloud("sea_4", -0.95, -0.16, 24, (3.4, 1.8, 1.7), 14, 204)
    cloud("sea_5", 0.98, -0.04, 26, (3.0, 1.5, 1.5), 14, 205)
    cloud("sea_6", 0.3, -0.12, 38, (6.0, 2.5, 2.2), 18, 206)
    cloud("sea_7", -0.45, 0.0, 56, (8.0, 3.0, 3.0), 18, 207)
    cloud("sea_8", 0.55, 0.08, 72, (10.0, 3.0, 3.2), 16, 208)
    cloud("sea_9", -0.2, -0.85, 11, (3.0, 1.2, 1.2), 14, 209)

    # Banks at the sides, the way the painting frames its islands.
    cloud("bank_left", -1.08, 0.46, 21, (2.0, 1.5, 1.6), 12, 301)
    cloud("bank_right", 1.14, 0.12, 19, (2.0, 1.4, 1.5), 12, 302)
    cloud("bank_upright", 1.02, 0.82, 26, (2.2, 1.6, 1.7), 12, 303)
    cloud("bank_upleft", -1.05, 1.02, 30, (2.4, 1.6, 1.6), 12, 304)

    # Wisps caught under the islands.
    cloud("wisp_left", -0.8, 0.06, 16.5, (1.4, 0.8, 0.55), 8, 401)
    cloud("wisp_right", 0.82, 0.3, 24.5, (1.3, 0.8, 0.5), 8, 402)
    cloud("wisp_centre", 0.02, 0.2, 47, (2.2, 1.0, 0.9), 9, 403)

    # High puffs that cross the sky, and a flock.
    crossing_cloud("puff_a", 1.02, 45, (1.6, 0.8, 0.8), 8, 501, start=0.0, span=1.0)
    crossing_cloud("puff_b", 0.72, 60, (2.0, 0.9, 0.9), 9, 502, start=0.45, span=1.0,
                   direction=-1)
    crossing_cloud("puff_c", 1.2, 38, (1.3, 0.7, 0.7), 7, 503, start=0.7, span=1.0)
    flock("flock", 0.58, 16, 4, 601, start=0.1, span=0.6)


build()
tk.export("sky_islands")
