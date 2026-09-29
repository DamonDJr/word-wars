"""Volcano: the Volcano board rebuilt as a 3D scene.

    LD_LIBRARY_PATH=/usr/lib blender --background --factory-startup \
        --python tools/blender/volcano.py

Writes boards/3d/volcano.glb (what the game loads for Volcano) and
build/boards3d/volcano.blend (to open and adjust by hand).

The scene, from back to front: a smoky red sky with ash banks drifting across
the top; a ring of far ridges; the volcano, erupting, with three lava flows
running down channels in its sides; a field of cracked basalt plates with lava
showing through every crack, and a lava river winding out of the volcano's
foot toward the camera; and tall rock spires either side, framing the board.

What moves, all on the 20 second loop: the eruption (a burst that pulses, lava
bombs arcing out of the crater, a smoke plume rolling up and away to the
right), the ash banks, and the camera's drift. The lava itself (the river, the
cracks, the flows, the crater) is shader work in Godot, and the painted
board's rising embers are kept and drawn over the top.

Rock is lit by the lava, not the sky: vertex alpha on the plates and the cone
is a glow mask, 0 where the rock meets lava, and the toon shader pulls those
faces toward orange. That is what makes the cracks read as hot rather than as
lines.

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
from toonkit import (TAU, bm_object, cloud, empty, ground, keyframes,  # noqa: E402
                     lathe, mix, n3, new_bm, place, puff, ribbon, smooth)

# Lit colour per material, as sRGB. Shadows, ink and glow are in board3d.gd.
PALETTE = {
    "Basalt": "#46251f",
    "Cone": "#4e2923",
    "Spire": "#4c2820",
    "Ridge": "#3e1a18",
    "Smoke": "#c05a36",
    "Ash": "#a8442a",
    "Lava": "#ff9a2a",
    "LavaFlow": "#ff9a2a",
    "CraterLava": "#ffc040",
    "Burst": "#ffd45a",
    "Bomb": "#ffa93a",
}

CAM_H = 6.0

tk.setup(PALETTE)
tk.camera(vfov=56.0, pitch=-8.0, loc=(0.0, 0.0, CAM_H), sway=(0.35, 0.08),
          turn=(0.2, 0.5), clip_end=700.0)


# ------------------------------------------------------------------ volcano

# The peak sits high in the frame, just under the clock, a touch right of
# centre; the base runs off both edges at the horizon.
PEAK = place(0.04, 0.93, 100.0)
VC = Vector((PEAK.x, PEAK.y, 0.0))
H = PEAK.z
RB = 40.0
RC = 6.0

# The three flows, as (angle at the rim, meander, width at top, at the foot).
# Angle -90 degrees faces the camera.
FLOWS = [
    (math.radians(-90 - 24), 0.10, 1.6, 3.6),
    (math.radians(-90 + 18), 0.08, 1.4, 3.2),
    (math.radians(-90 + 58), 0.12, 1.2, 2.8),
    (math.radians(-90 - 62), 0.14, 0.8, 1.9),
    (math.radians(-90 - 2), 0.18, 0.7, 1.6),
]

# The channels stop short of the rim, or they notch it and the dark inside of
# the crater shows through as a hole.
def carve(t):
    return 1.1 * (1.0 - smooth(0.88, 0.97, t))


def cone_r0(t):
    """Radius of the smooth cone at height fraction t (0 foot, 1 rim)."""
    return RC + (RB - RC) * (1.0 - t) ** 1.3


def flow_theta(k, t):
    th0, amp, _, _ = FLOWS[k]
    return th0 + amp * math.sin(t * 6.0 + k * 1.7) * (1.0 - 0.5 * t)


def flow_width(k, t):
    _, _, wt, wb = FLOWS[k]
    return wb + (wt - wb) * t


def channel(th, t):
    """0..1, how far inside a lava channel this point of the cone is."""
    r = cone_r0(t)
    best = 0.0
    for k in range(len(FLOWS)):
        d = math.atan2(math.sin(th - flow_theta(k, t)), math.cos(th - flow_theta(k, t))) * r
        w = flow_width(k, t)
        best = max(best, math.exp(-(d / (0.75 * w)) ** 2))
    return best


def glow_near_flow(th, t):
    r = cone_r0(t)
    best = 0.0
    for k in range(len(FLOWS)):
        d = math.atan2(math.sin(th - flow_theta(k, t)), math.cos(th - flow_theta(k, t))) * r
        w = flow_width(k, t)
        best = max(best, math.exp(-(d / (1.1 * w)) ** 2))
    return best


def cone_r(th, t, rough=True):
    r = cone_r0(t)
    if not rough:
        return r
    c, s = math.cos(th), math.sin(th)
    ch = channel(th, t)
    ridge = 0.08 * math.sin(th * 11.0 + 2.2 * t + 0.7) * (1.0 - 0.6 * t)
    lump = 0.1 * n3(c * 2.2 + 4.0, s * 2.2, t * 3.5) + 0.04 * n3(c * 6 + 1.0, s * 6, t * 9)
    return r * (1.0 + (ridge + lump) * (1.0 - ch)) - carve(t) * ch


def volcano():
    bm, col = new_bm()
    NT = 140
    NR = 44
    rings = []
    rough = {}
    for j in range(NR + 1):
        t = j / NR
        z = H * t
        ring = []
        for i in range(NT):
            th = TAU * i / NT
            r0 = cone_r(th, t, rough=False)
            r = cone_r(th, t)
            v = bm.verts.new((VC.x + r0 * math.cos(th), VC.y + r0 * math.sin(th), z))
            rough[v] = Vector((VC.x + r * math.cos(th), VC.y + r * math.sin(th), z))
            band = 1.0 if int(t * 7.0 + 0.8 * n3(math.cos(th) * 3, math.sin(th) * 3, t * 4)) % 2 == 0 else 0.9
            dark = 0.8 + 0.2 * t
            g = max(glow_near_flow(th, t), smooth(0.9, 1.0, t) * 0.6)
            v[col] = (band * dark, band * dark * 0.97, band * dark * 1.02, 1.0 - 0.9 * g)
            ring.append(v)
        rings.append(ring)
    # The crater: a raised lip, walls going in and down, a floor.
    for rf, dz, a in ((0.95, 0.9, 0.5), (0.8, -1.4, 0.15), (0.6, -2.6, 0.05)):
        ring = []
        for i in range(NT):
            th = TAU * i / NT
            r = RC * rf
            p = Vector((VC.x + r * math.cos(th), VC.y + r * math.sin(th), H + dz))
            v = bm.verts.new(p)
            rough[v] = p
            v[col] = (0.8, 0.78, 0.82, a)
            ring.append(v)
        rings.append(ring)
    c = bm.verts.new((VC.x, VC.y, H - 2.7))
    rough[c] = c.co.copy()
    c[col] = (0.8, 0.8, 0.8, 0.0)
    rings.append([c])
    tk.bridge_rings(bm, rings)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    smooth_n = [v.normal.copy() for v in bm.verts]
    for v, p in rough.items():
        v.co = p
    bm.normal_update()
    normals = [(0.45 * n + 0.55 * v.normal).normalized()
               for v, n in zip(bm.verts, smooth_n)]
    bm_object("volcano", bm, "Cone", recalc=False, normals=normals)

    # The flows, lying in their channels.
    for k in range(len(FLOWS)):
        path, widths, ups = [], [], []
        N = 60
        for n in range(N + 1):
            t = 0.975 - 0.975 * n / N
            th = flow_theta(k, t)
            r = cone_r0(t) - carve(t) + 0.45
            path.append(Vector((VC.x + r * math.cos(th), VC.y + r * math.sin(th), H * t)))
            widths.append(flow_width(k, t) * 1.25)
            # The cone's own surface normal, so the ribbon lies flat on it.
            dr = (cone_r0(max(t - 0.01, 0.0)) - cone_r0(min(t + 0.01, 1.0))) / (0.02 * H)
            ups.append(Vector((math.cos(th), math.sin(th), dr)).normalized())
        bmr = ribbon(path, widths, v_scale=flow_width(k, 0.5), up=lambda n, ups=ups: ups[n])
        bm_object("flow_%d" % k, bmr, "LavaFlow", recalc=False)

    # The pool in the crater.
    bm, col = new_bm()
    lathe(bm, col, [(0.0, -0.05), (RC * 0.84, 0.0), (0.0, 0.05)], 40,
          Matrix.Translation((VC.x, VC.y, H - 1.0)))
    bm_object("crater_lava", bm, "CraterLava")
    return Vector((VC.x, VC.y, H - 0.5))


# --------------------------------------------------------------- eruption

def burst(crater):
    """Spikes of lava thrown up out of the crater, pulsing."""
    rnd = random.Random(31)
    bm, col = new_bm()
    n = 11
    for k in range(n):
        a = TAU * k / n + rnd.uniform(-0.2, 0.2)
        tilt = math.radians(rnd.uniform(10, 48))
        L = rnd.uniform(5.0, 11.0)
        r = rnd.uniform(0.7, 1.2)
        xf = (Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(tilt, 4, 'X'))
        lathe(bm, col, [(0.0, -0.5), (r, 0.0), (r * 0.75, L * 0.35), (r * 0.4, L * 0.7), (0.0, L)],
              8, xf)
    puff(bm, col, Vector((0, 0, 0.6)), 3.4, 2, 0.6)
    o = bm_object("burst", bm, "Burst", loc=crater)

    def f(t):
        beat = max(0.0, math.sin(TAU * 8 * t)) ** 2
        swell = 0.78 + 0.3 * beat + 0.06 * math.sin(TAU * 3 * t)
        return None, Euler((0, 0, TAU * t)), (swell, swell, 0.7 + 0.45 * beat)
    keyframes(o, f, step=1)


def bombs(crater, count=9):
    """Blobs of lava lobbed out of the crater, a few flights each per loop."""
    rnd = random.Random(47)
    g = 17.0
    for i in range(count):
        bm, col = new_bm()
        puff(bm, col, Vector((0, 0, 0)), rnd.uniform(0.7, 1.1), 2, 0.9)
        o = bm_object("bomb_%d" % i, bm, "Bomb", loc=crater)
        flights = []
        nf = rnd.choice([2, 3])
        for k in range(nf):
            v0 = rnd.uniform(12.0, 19.0)
            dur = 2.0 * v0 / g * 1.12
            start = (k + rnd.uniform(0.05, 0.7)) * (tk.LOOP / nf)
            start = min(start, tk.LOOP - dur - 0.1)
            a = rnd.uniform(0, TAU)
            vh = rnd.uniform(3.0, 7.5)
            flights.append((start, dur, a, vh, v0))

        def f(t, flights=flights):
            T = t * tk.LOOP
            for start, dur, a, vh, v0 in flights:
                if start <= T <= start + dur:
                    u = T - start
                    p = crater + Vector((math.cos(a) * vh * u, math.sin(a) * vh * u * 0.7,
                                         v0 * u - 0.5 * g * u * u))
                    s = smooth(0.0, 0.08, u) * (1.0 - smooth(dur - 0.12, dur, u))
                    return p, None, (s, s, s)
            return crater, None, (0.0, 0.0, 0.0)
        keyframes(o, f, step=1)


def plume(crater, count=12, cycles=2):
    """The smoke column: puffs born in the crater that grow, climb and drift
    right on the wind, and dissolve (by shrinking) near the top of the frame."""
    rnd = random.Random(59)
    for i in range(count):
        bm, col = new_bm()
        for k in range(6):
            c = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.3, 0.4)))
            puff(bm, col, c, rnd.uniform(0.55, 0.9), 2)
        for v in bm.verts:
            up = tk.clamp(v.co.z * 0.6 + 0.5)
            v[col] = (0.85 + 0.15 * up, 0.85 + 0.15 * up, 0.9 + 0.1 * up, 1.0)
        o = bm_object("smoke_%d" % i, bm, "Smoke", loc=crater)
        phase = i / count
        wob = rnd.uniform(0, TAU)
        spin = rnd.choice([-1, 1]) * rnd.uniform(0.5, 1.5)

        def f(t, phase=phase, wob=wob, spin=spin):
            u = (t * cycles + phase) % 1.0
            rise = 46.0 * u
            drift = Vector((24.0, 8.0, 0.0)) * (u ** 1.5)
            sway = Vector((1.5 * math.sin(TAU * (2 * u) + wob), 0, 0))
            s = (1.6 + 11.0 * u ** 0.8) * smooth(0.0, 0.08, u) * (1.0 - smooth(0.8, 1.0, u))
            return (crater + Vector((0, 4.0, 9.0 + rise)) + drift + sway,
                    Euler((0, 0, spin * u * 2.0)), (s, s, s * 0.85))
        keyframes(o, f, step=1)


# ------------------------------------------------------------------ ground

# The river, from the volcano's foot to under the keyboard. (x, y) on the
# ground; widths grow toward the camera.
RIVER = [(VC.x + 0.5, VC.y - RB + 2), (VC.x - 3.0, 52.0), (3.5, 42.0), (-3.0, 33.0),
         (4.5, 25.0), (-1.0, 17.0), (-4.0, 9.0), (-1.0, 0.0), (1.0, -8.0)]


def catmull(points, per=10):
    out = []
    pts = [points[0]] + points + [points[-1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (Vector(pts[i + j]) for j in (-1, 0, 1, 2))
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(Vector(points[-1]))
    return out


RIVER_PTS = catmull(RIVER)


def river_width(y):
    return 2.2 + max(0.0, 60.0 - y) * 0.045


def river_dist(x, y):
    p = Vector((x, y))
    best = 1e9
    for a, b in zip(RIVER_PTS, RIVER_PTS[1:]):
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
        best = min(best, (a + ab * t - p).length)
    return best


def plates(name, S, y0, y1, seed, gap0, gap_k):
    """Hexagonal slabs of basalt on jittered corners, so neighbours share
    every crack. Glow mask 0 at the foot of each slab, 1 on top."""
    rnd = random.Random(seed)
    bm, col = new_bm()
    dx = S
    dy = S * 0.8660254
    R = S / math.sqrt(3.0)
    jit = 0.3 * S

    def corner(x, y):
        return Vector((x + jit * n3(x * 0.61 + seed, y * 0.61, 1.3),
                       y + jit * n3(x * 0.61 - seed, y * 0.61, 7.9)))

    j = int(y0 / dy) - 1
    count = 0
    while j * dy < y1 + dy:
        y = j * dy
        half = y * tk.TX * 1.35 + 8.0
        i0 = int(-half / dx) - 1
        for i in range(i0, -i0 + 1):
            x = i * dx + (j % 2) * dx * 0.5
            if y < y0 or y > y1 or abs(x) > half:
                continue
            if (Vector((x, y)) - VC.xy).length < RB * 0.93:
                continue
            if river_dist(x, y) < river_width(y) * 0.5 + S * 0.25:
                continue
            if rnd.random() < 0.04:
                continue        # a pool
            cs = []
            for k in range(6):
                a = math.radians(30 + 60 * k)
                cx, cy = x + R * math.cos(a), y + R * math.sin(a)
                cs.append(corner(round(cx, 3), round(cy, 3)))
            ctr = sum(cs, Vector((0, 0))) / 6.0
            gap = gap0 + gap_k * y
            cs = [c + (ctr - c).normalized() * gap for c in cs]
            h = rnd.uniform(0.22, 0.46) * S / 2.3
            tx, ty = rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04)
            tint = rnd.uniform(0.78, 1.0)

            def zat(p, lift):
                return lift + tx * (p.x - ctr.x) + ty * (p.y - ctr.y)

            bot = [bm.verts.new((c.x, c.y, -0.3)) for c in cs]
            sh = [bm.verts.new((c.x, c.y, zat(c, h - 0.1 * S / 2.3))) for c in cs]
            ins = [c + (ctr - c) * 0.16 for c in cs]
            top = [bm.verts.new((c.x, c.y, zat(c, h))) for c in ins]
            mid = bm.verts.new((ctr.x, ctr.y, zat(ctr, h + 0.05 * S / 2.3)))
            for v in bot:
                v[col] = (tint * 0.8, tint * 0.8, tint * 0.8, 0.0)
            for v in sh:
                v[col] = (tint * 0.9, tint * 0.9, tint * 0.9, 0.55)
            for v in top:
                v[col] = (tint, tint, tint, 1.0)
            mid[col] = (tint, tint, tint, 1.0)
            for k in range(6):
                k2 = (k + 1) % 6
                bm.faces.new((bot[k], bot[k2], sh[k2], sh[k]))
                bm.faces.new((sh[k], sh[k2], top[k2], top[k]))
                bm.faces.new((mid, top[k], top[k2]))
            count += 1
        j += 1
    bm_object(name, bm, "Basalt", recalc=False)
    return count


def lava_plane():
    bm, col = new_bm()
    vs = [bm.verts.new(p) for p in ((-160, -20, 0), (160, -20, 0), (160, 320, 0), (-160, 320, 0))]
    bm.faces.new(vs)
    bm_object("lava", bm, "Lava", recalc=False)


# ------------------------------------------------------------------ spires

def spire(bm, col, base, height, radius, seed, lean=0.12):
    """A jagged column of rock, shaded as its un-roughened self."""
    rnd = random.Random(seed)
    seg = 9
    N = 12
    lv = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.5, 0.5), 0)) * lean * height
    rings, rough = [], {}
    rot = rnd.uniform(0, TAU)
    for k in range(N):
        t = k / (N - 1)
        if k == N - 1:
            p = base + Vector((0, 0, height)) + lv
            v = bm.verts.new(p)
            rough[v] = p
            v[col] = (1.0, 1.0, 1.0, 1.0)
            rings.append([v])
            break
        r0 = radius * (1.0 - t) ** 0.7
        ledge = 1.0 - 0.12 * ((t * 4.0 + rnd.uniform(0, 0.3)) % 1.0)
        ring = []
        for i in range(seg):
            a = rot + TAU * i / seg
            c, s = math.cos(a), math.sin(a)
            r = r0 * ledge * (1.0 + 0.22 * n3(c * 1.4 + seed, s * 1.4, t * 3.0))
            off = lv * t * t + Vector((0, 0, height * t))
            v = bm.verts.new(base + off + Vector((r0 * c, r0 * s, 0)))
            rough[v] = base + off + Vector((r * c, r * s, 0))
            shade = (0.8 + 0.2 * t) * (1.0 if int(t * 5 + 0.5 * n3(c, s, t)) % 2 == 0 else 0.9)
            v[col] = (shade, shade, shade, 1.0 - 0.8 * (1.0 - smooth(0.0, 0.2, t)))
            ring.append(v)
        rings.append(ring)
    return rings, rough


def spires(name, specs):
    bm, col = new_bm()
    rough = {}
    for base, height, radius, seed in specs:
        rings, rgh = spire(bm, col, base, height, radius, seed)
        tk.bridge_rings(bm, rings)
        rough.update(rgh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    smooth_n = [v.normal.copy() for v in bm.verts]
    for v, p in rough.items():
        v.co = p
    bm.normal_update()
    normals = [(0.6 * n + 0.4 * v.normal).normalized() for v, n in zip(bm.verts, smooth_n)]
    bm_object(name, bm, "Spire", recalc=False, normals=normals)


def cluster(sx, sy, height, seed, n=3, spread=None):
    """A main spire at screen point (sx, sy) on the ground and smaller ones
    around it."""
    rnd = random.Random(seed)
    base = ground(sx, sy)
    base.z = -0.5
    spread = spread or height * 0.35
    out = [(base, height, height * 0.2, seed)]
    for k in range(n - 1):
        off = Vector((rnd.uniform(-1, 1) * spread, rnd.uniform(-0.3, 1.0) * spread, 0))
        out.append((base + off, height * rnd.uniform(0.45, 0.75),
                    height * rnd.uniform(0.14, 0.2), seed * 7 + k))
    return out


def ridges():
    rnd = random.Random(71)
    bm, col = new_bm()
    for k in range(14):
        side = -1 if k % 2 == 0 else 1
        x = side * rnd.uniform(35, 170)
        y = rnd.uniform(150, 280)
        h = rnd.uniform(14, 38)
        r = h * rnd.uniform(1.1, 1.8)
        prof = [(r, -1.0), (r * 0.7, h * 0.3), (r * 0.35, h * 0.72), (r * 0.12, h * 0.95), (0.0, h)]
        verts = lathe(bm, col, prof, 12, Matrix.Translation((x, y, 0)))
        for v in verts:
            v.co.x += 2.5 * n3(v.co.x * 0.1, v.co.y * 0.1, 3.3) * (v.co.z / h)
    bm_object("ridges", bm, "Ridge")


def ash_banks():
    """Heavy smoke across the top of the sky, lit from below."""
    specs = [(-0.7, 1.08, 150, (40, 12, 12), 14, 801), (0.55, 1.15, 170, (46, 12, 13), 14, 802),
             (0.0, 1.3, 190, (60, 14, 14), 16, 803), (-0.95, 0.75, 170, (30, 10, 10), 12, 804),
             (1.0, 0.78, 160, (28, 10, 10), 12, 805)]
    for sx, sy, d, size, n, seed in specs:
        cloud("ash_%d" % seed, sx, sy, d, size, n, seed, drift=0.5, subdiv=2,
              mat="Ash", under=(1.0, 1.0, 1.0), flat=False)


# ------------------------------------------------------------------- scene

def build():
    crater = volcano()
    burst(crater)
    bombs(crater)
    plume(crater)
    lava_plane()
    near = plates("plates_near", 2.3, 2.0, 72.0, 11, 0.13, 0.0035)
    far = plates("plates_far", 4.4, 72.0, 175.0, 12, 0.3, 0.0015)
    print("[volcano] %d near plates, %d far" % (near, far))
    # Ground distance climbs fast toward the horizon (sy = +0.26): sy -0.22
    # is 23 m out, 0.0 is 43 m, 0.08 is 60 m, which is the volcano's foot.
    spires("spires_left", cluster(-0.86, -0.22, 13.0, 3) + cluster(-0.62, 0.0, 8.0, 5, n=2))
    spires("spires_right", cluster(0.86, -0.08, 14.0, 7) + cluster(0.64, 0.03, 9.0, 9, n=2))
    spires("spires_far", cluster(-0.3, 0.07, 5.0, 13, n=2) + cluster(0.36, 0.08, 5.5, 17, n=2))
    ridges()
    ash_banks()


build()
tk.export("volcano")
