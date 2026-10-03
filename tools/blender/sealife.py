"""The live half of a realistic sea board: what swims over the plate.

Each creature is a mesh exported to the game in a glTF with the camera; the
game shades it to sit in the render (see `boards/3d/creature.gdshader` and
friends) and hides it behind the plate's stone using the plate's depth.

Travel is keyed here on the loop, as in the toon boards. The motion of a
body (a tail beating, a bell pulsing, wings flapping) is done in the game's
vertex shaders from what each vertex carries:

  UV.x      0 at the nose (or the bell's crown) to 1 at the tail tip
  UV.y      -1..1 across the body, for wings
  COLOR.a   a per-animal seed, so a school does not beat in step
"""

import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

import realkit as rk
from realkit import TAU

FPS = 24
LOOP = 30.0
FRAMES = int(FPS * LOOP)


def keyframes(obj, fn, step=2):
    """Key `fn(t)` -> (loc, rot) over the loop, t running 0..1. Linear keys:
    the curves are dense samples, and Bezier between them overshoots."""
    bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
    obj.rotation_mode = 'QUATERNION'
    for f in range(0, FRAMES + 1, step):
        loc, rot = fn(f / FRAMES)
        if loc is not None:
            obj.location = loc
            obj.keyframe_insert("location", frame=f)
        if rot is not None:
            obj.rotation_quaternion = rot
            obj.keyframe_insert("rotation_quaternion", frame=f)


def facing(direction, up=Vector((0, 0, 1))):
    """A rotation that points a creature's nose (local +X) along `direction`."""
    d = Vector(direction).normalized()
    return d.to_track_quat('X', 'Z')


def _layers(bm):
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    col = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
    return uv, col


def _stamp(bm, faces, length, seed, rgb=(1, 1, 1), half_width=1.0):
    """Write UV.x (nose to tail), UV.y (across) and the seed onto `faces`
    from the vertices' local positions (nose at +x * length / 2)."""
    uv, col = _layers(bm)
    for f in faces:
        for lp in f.loops:
            p = lp.vert.co
            lp[uv].uv = (0.5 - p.x / length, p.y / half_width)
            lp[col] = (rgb[0], rgb[1], rgb[2], seed)


def body(bm, length, profile, sides=8, xform=Matrix(), flat=1.0):
    """A body of revolution along X: `profile` is [(t, r)] with t from 0 at
    the nose to 1 at the tail and r as a fraction of the length. `flat`
    squashes it side to side."""
    rings = []
    for t, r in profile:
        x = length * (0.5 - t)
        r *= length
        ring = []
        for k in range(sides):
            a = TAU * k / sides
            ring.append(bm.verts.new(xform @ Vector((x, r * flat * math.cos(a), r * math.sin(a)))))
        rings.append(ring)
    faces = []
    nose = bm.verts.new(xform @ Vector((length * 0.5 + 0.0001, 0, 0)))
    for k in range(sides):
        faces.append(bm.faces.new((nose, rings[0][(k + 1) % sides], rings[0][k])))
    for ra, rb in zip(rings, rings[1:]):
        for k in range(sides):
            faces.append(bm.faces.new((ra[k], ra[(k + 1) % sides], rb[(k + 1) % sides], rb[k])))
    return faces


def fin(bm, pts, xform=Matrix()):
    """A flat fin through `pts`, a fan from the first point."""
    vs = [bm.verts.new(xform @ Vector(p)) for p in pts]
    faces = []
    for a, b in zip(vs[1:], vs[2:]):
        faces.append(bm.faces.new((vs[0], a, b)))
    return faces


# --------------------------------------------------------------------- fish

def fish_into(bm, length, seed, rgb, xform):
    """One small fish: a spindle body, a forked tail, a dorsal fin."""
    faces = body(bm, length, [(0.05, 0.05), (0.2, 0.11), (0.45, 0.12), (0.7, 0.07), (0.88, 0.025)],
                 sides=6, xform=xform, flat=0.45)
    faces += fin(bm, [(-0.36, 0, 0), (-0.55, 0, 0.13), (-0.5, 0, 0), (-0.55, 0, -0.13)], xform=xform @
                 Matrix.Diagonal((length, length, length, 1)))
    faces += fin(bm, [(0.05, 0, 0.1), (-0.05, 0, 0.19), (-0.15, 0, 0.1)], xform=xform @
                 Matrix.Diagonal((length, length, length, 1)))
    # UVs from the fish's own frame, before it was placed in the school.
    uv, col = _layers(bm)
    inv = xform.inverted()
    for f in faces:
        for lp in f.loops:
            p = inv @ lp.vert.co
            lp[uv].uv = (0.5 - p.x / length, p.y / length)
            lp[col] = (rgb[0], rgb[1], rgb[2], seed)
    return faces


def school(name, count, length, spread, seed, mat, rgb=(0.8, 0.85, 0.9), shape=(1.0, 0.5, 0.6)):
    """A school: `count` fish in a loose ellipsoid round the object's
    origin, all facing +X, each with its own seed. The school travels as one
    object; each fish's beat and wander are in the shader."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for i in range(count):
        p = Vector((rng.gauss(0, spread * shape[0]), rng.gauss(0, spread * shape[1]),
                    rng.gauss(0, spread * shape[2])))
        s = length * rng.uniform(0.8, 1.2)
        rot = Matrix.Rotation(rng.uniform(-0.15, 0.15), 4, 'Z') @ Matrix.Rotation(rng.uniform(-0.1, 0.1), 4, 'Y')
        tint = tuple(c * rng.uniform(0.85, 1.1) for c in rgb)
        fish_into(bm, s, rng.random(), tint, Matrix.Translation(p) @ rot)
    return rk.mesh_object(name, bm, mat, smooth=False)


def orbit(obj, center, radii, tilt=0.0, phase=0.0, turns=1, wobble=0.0):
    """Swim round a closed loop `turns` times per loop, nose along the path."""
    c = Vector(center)

    def at(t):
        a = TAU * (t * turns + phase)
        p = Vector((radii[0] * math.cos(a), radii[1] * math.sin(a), 0.0))
        p.z = p.y * math.sin(tilt) + wobble * math.sin(2 * a)
        return c + p

    def fn(t):
        p = at(t)
        ahead = at(t + 0.002)
        return p, facing(ahead - p)
    keyframes(obj, fn)


# ---------------------------------------------------------------- jellyfish
#
# What `boards/3d/jelly.gdshader` reads from each vertex. glTF flips V on the
# way into Godot, so every V here is written as 1 - v and arrives as v.
#
#   UV.x    how far along its part: crown (0) to margin (1) on the bell, root
#           (0) to tip (1) on a tentacle or an arm
#   UV.y    which part: 0 the bell's outside, 1 a tentacle, 2 an oral arm,
#           3 the bell's inside
#   UV2.x   a random number per tentacle or arm, so none move in step
#   UV2.y   the bell's radius in metres, for motions measured by it
#   COLOR.r across an oral arm: 0 its spine, 1 its frilled edge
#   COLOR.a the jelly's seed

BELL, TENTACLE, ARM, INSIDE = 0, 1, 2, 3


def _jelly_loop(lp, uv, uv2, col, along, part, rnd, size, seed, across=0.0):
    lp[uv].uv = (along, 1.0 - part)
    lp[uv2].uv = (rnd, 1.0 - size)
    lp[col] = (across, 0.0, 0.0, seed)


def jellyfish(name, size, seed, mat, arms=4, tentacles=28):
    """A jellyfish, `size` the bell's radius: a hollow bell, thick at the
    crown and thin at its scalloped margin, its inside a second surface the
    shader can see through the first; a fringe of fine tentacles trailing
    from the margin in slow curls; and long frilled oral arms twisting down
    from the middle, the way a sea nettle's do."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UVMap2")
    col = bm.loops.layers.color.new("Col")
    s = rng.random()
    R = size
    H = R * rng.uniform(0.75, 0.95)
    seg, nr = 48, 14
    lappets = 16
    phi_max = math.radians(rng.uniform(92, 100))

    def bell(t, a, inside):
        """A point on the bell, t from crown (0) to margin (1)."""
        phi = t * phi_max
        notch = math.exp(-((((a * lappets / TAU) % 1.0) - 0.5) / 0.12) ** 2)
        rr = R * math.sin(phi) * (1.0 + 0.08 * t ** 3) * (1.0 + 0.015 * math.cos(lappets * a) * t)
        z = H * math.cos(phi) + R * 0.06 * notch * t ** 6
        if inside:
            # The jelly is thick at the crown and thin at the margin.
            th = R * (0.28 * (1.0 - t) ** 1.6 + 0.015)
            rr -= th * math.sin(phi)
            z -= th * math.cos(phi) * (H / R)
        return Vector((rr * math.cos(a), rr * math.sin(a), z))

    surfaces = []
    for inside in (False, True):
        top = bm.verts.new(bell(0.0, 0.0, inside))
        rings = [[bm.verts.new(bell(i / nr, TAU * k / seg, inside)) for k in range(seg)] for i in range(1, nr + 1)]
        part = INSIDE if inside else BELL
        for k in range(seg):
            q = (top, rings[0][k], rings[0][(k + 1) % seg])
            f = bm.faces.new(tuple(reversed(q)) if inside else q)
            for lp in f.loops:
                _jelly_loop(lp, uv, uv2, col, 0.0 if lp.vert is top else 1.0 / nr, part, 0.0, R, s)
        for i in range(nr - 1):
            for k in range(seg):
                q = (rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % seg], rings[i][(k + 1) % seg])
                f = bm.faces.new(tuple(reversed(q)) if inside else q)
                for lp in f.loops:
                    j = (i + 1) if lp.vert in (rings[i + 1][k], rings[i + 1][(k + 1) % seg]) else i
                    _jelly_loop(lp, uv, uv2, col, (j + 1) / nr, part, 0.0, R, s)
        surfaces.append(rings[-1])
    # The margin, closing the gap between the two surfaces.
    for k in range(seg):
        f = bm.faces.new((surfaces[0][k], surfaces[1][k], surfaces[1][(k + 1) % seg], surfaces[0][(k + 1) % seg]))
        for lp in f.loops:
            _jelly_loop(lp, uv, uv2, col, 1.0, BELL, 0.0, R, s)

    # Tentacles: fine three-sided threads from the margin, hanging in slow
    # curls, each its own length.
    for k in range(tentacles):
        a = TAU * (k + 0.5) / tentacles + rng.uniform(-0.04, 0.04)
        rnd = rng.random()
        root = bell(0.985, a, True)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        length = R * rng.uniform(3.0, 6.0)
        n = 26
        curl = rng.uniform(1.5, 3.5)
        ph = rng.uniform(0, TAU)
        pts = []
        for i in range(n + 1):
            t = i / n
            wob = R * 0.18 * t ** 1.3
            pts.append(root + Vector((0, 0, -length * t)) - out * R * 0.12 * math.sin(t * math.pi)
                       + Vector((math.cos(ph + t * curl * TAU), math.sin(ph + t * curl * TAU), 0)) * wob)
        rings = []
        for i, p in enumerate(pts):
            t = i / n
            d = (pts[min(i + 1, n)] - pts[max(i - 1, 0)]).normalized()
            e1 = d.cross(Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))).normalized()
            e2 = d.cross(e1)
            r = R * (0.014 * (1.0 - t) + 0.004)
            rings.append([bm.verts.new(p + (e1 * math.cos(TAU * j / 3) + e2 * math.sin(TAU * j / 3)) * r)
                          for j in range(3)])
        for i in range(n):
            for j in range(3):
                f = bm.faces.new((rings[i][j], rings[i][(j + 1) % 3], rings[i + 1][(j + 1) % 3], rings[i + 1][j]))
                for lp in f.loops:
                    t = (i + (1 if lp.vert in rings[i + 1] else 0)) / n
                    _jelly_loop(lp, uv, uv2, col, t, TENTACLE, rnd, R, s)

    # Oral arms: frilled curtains twisting down together from the middle of
    # the bell. Each is a strip whose inner edge is its spine and whose outer
    # edge, much longer, ruffles back and forth.
    crown = bell(0.0, 0.0, True)
    twist = rng.uniform(0.8, 1.6) * rng.choice((-1, 1))
    for k in range(arms):
        a0 = TAU * k / arms + rng.uniform(-0.2, 0.2)
        rnd = rng.random()
        length = R * rng.uniform(2.6, 4.2)
        n = 72
        rows = []
        for i in range(n + 1):
            t = i / n
            a = a0 + twist * t
            out = Vector((math.cos(a), math.sin(a), 0.0))
            tang = Vector((-math.sin(a), math.cos(a), 0.0))
            spine = crown + Vector((0, 0, -R * 0.05 - length * t)) + out * R * (0.04 + 0.1 * t)
            # Narrow where it leaves the mouth, a broad curtain a little way
            # down, tapering to a ribbon at the end.
            w = R * (0.05 + 0.3 * min(1.0, t / 0.22) ** 0.7 * (1.0 - t) ** 0.8)
            row = []
            for j, u in enumerate((0.0, 0.35, 0.7, 1.0)):
                ph = t * 52.0 + rnd * TAU
                ruffle = R * (0.11 * math.sin(ph) + 0.04 * math.sin(ph * 2.3 + 1.0)) * u ** 2 * (1.0 - 0.4 * t)
                row.append(bm.verts.new(spine + out * w * u + tang * ruffle))
            rows.append(row)
        for i in range(n):
            for j in range(3):
                f = bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
                for lp in f.loops:
                    ii = i + (1 if lp.vert in rows[i + 1] else 0)
                    jj = rows[ii].index(lp.vert)
                    _jelly_loop(lp, uv, uv2, col, ii / n, ARM, rnd, R, s, across=(0.0, 0.35, 0.7, 1.0)[jj])
    return rk.mesh_object(name, bm, mat, smooth=True)


def drift(obj, base, rise=1.0, sway=0.6, phase=0.0):
    """Hang near `base`, rising and sinking and drifting a little, upright."""
    b = Vector(base)

    def fn(t):
        a = TAU * (t + phase)
        p = b + Vector((sway * math.sin(a), sway * 0.5 * math.cos(2 * a), rise * math.sin(2 * a)))
        tilt = 0.12 * math.sin(a + 1.0)
        q = Matrix.Rotation(tilt, 3, 'X').to_quaternion()
        return p, q
    keyframes(obj, fn, step=4)


# ----------------------------------------------------------- whale and ray

def whale(name, length, mat):
    """A humpback, nose along +X: long pectoral fins, broad flukes."""
    bm = bmesh.new()
    faces = body(bm, length, [(0.03, 0.06), (0.12, 0.12), (0.3, 0.14), (0.5, 0.12), (0.7, 0.08),
                              (0.85, 0.04), (0.95, 0.02)], sides=12, flat=0.85)
    L = length
    faces += fin(bm, [(0.18 * L, 0.06 * L, -0.06 * L), (0.05 * L, 0.42 * L, -0.12 * L),
                      (0.0, 0.40 * L, -0.11 * L), (0.1 * L, 0.06 * L, -0.07 * L)])
    faces += fin(bm, [(0.18 * L, -0.06 * L, -0.06 * L), (0.1 * L, -0.06 * L, -0.07 * L),
                      (0.0, -0.40 * L, -0.11 * L), (0.05 * L, -0.42 * L, -0.12 * L)])
    faces += fin(bm, [(-0.45 * L, 0, 0), (-0.5 * L, 0.2 * L, 0.01 * L), (-0.58 * L, 0.22 * L, 0.0),
                      (-0.52 * L, 0, 0), (-0.58 * L, -0.22 * L, 0.0), (-0.5 * L, -0.2 * L, 0.01 * L)])
    _stamp(bm, bm.faces, length, 0.3, half_width=0.45 * L)
    return rk.mesh_object(name, bm, mat, smooth=True)


def manta(name, span, mat):
    """A manta ray, nose along +X: a diamond of wing, a short whip of tail,
    and the two horn-like fins at the front."""
    bm = bmesh.new()
    nx, ny = 10, 16
    grid = []
    for i in range(nx + 1):
        u = i / nx
        row = []
        for j in range(ny + 1):
            v = j / ny * 2 - 1
            # Diamond outline swept back at the tips.
            half = span * 0.5 * (math.sin(math.pi * min(1.0, u * 1.25)) ** 0.8)
            y = v * half
            x = span * (0.25 - 0.55 * u) - abs(v) ** 1.6 * span * 0.22
            z = span * 0.05 * (1 - v * v) * math.sin(math.pi * u)
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    faces = []
    for i in range(nx):
        for j in range(ny):
            faces.append(bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])))
    tail = [bm.verts.new((-span * 0.3 - span * 0.6 * t, 0, 0)) for t in (0, 1)]
    w = span * 0.015
    a, b, c, d = (bm.verts.new((tail[0].co.x, -w, 0)), bm.verts.new((tail[0].co.x, w, 0)),
                  bm.verts.new((tail[1].co.x, w * 0.2, 0)), bm.verts.new((tail[1].co.x, -w * 0.2, 0)))
    faces.append(bm.faces.new((a, b, c, d)))
    bm.verts.remove(tail[0])
    bm.verts.remove(tail[1])
    _stamp(bm, bm.faces, span, 0.6, half_width=span * 0.5)
    return rk.mesh_object(name, bm, mat, smooth=True)


def crossing(obj, start, end, enter, span, bob=0.0):
    """Cross from `start` to `end` once per loop, entering at loop phase
    `enter` and taking `span` of it; parked beyond `end` the rest of the time,
    and back to `start` in the one frame where the loop wraps."""
    s, e = Vector(start), Vector(end)
    q = facing(e - s)

    def fn(t):
        p = (t - enter) % 1.0
        u = min(1.0, p / span)
        pos = s.lerp(e, u) + Vector((0, 0, bob * math.sin(TAU * u * 2)))
        if p / span > 1.0:
            pos = e + (e - s).normalized() * 40.0
        return pos, q
    keyframes(obj, fn)


def export(path, keep):
    """Write the creatures and the game's camera to `path`, and nothing else."""
    bpy.ops.object.select_all(action='DESELECT')
    for o in keep:
        o.select_set(True)
    sc = bpy.context.scene
    sc.frame_start, sc.frame_end = 0, FRAMES
    sc.render.fps = FPS
    sc.frame_set(0)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
        export_cameras=True, export_vertex_color='ACTIVE', export_animations=True,
        export_animation_mode='SCENE', export_anim_scene_split_object=False, export_frame_range=True,
        export_force_sampling=True, export_optimize_animation_size=True)
    print("[sealife] %d objects -> %s" % (len(keep), path))


def rays(name, items, mat):
    """Shafts of light as long quads facing the camera: `items` is
    [(top, bottom, width, rgb, seed)]. UV.x runs across, UV2.x along from the
    top (0) to the bottom (1), as `boards/3d/ray.gdshader` reads them."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UVMap2")
    col = bm.loops.layers.color.new("Col")
    cam = rk.CAM_M.translation
    for top, bottom, width, rgb, seed in items:
        top, bottom = Vector(top), Vector(bottom)
        along = (bottom - top).normalized()
        mid = (top + bottom) * 0.5
        side = along.cross(cam - mid).normalized()
        w0, w1 = width * 0.6, width
        vs = [bm.verts.new(top - side * w0), bm.verts.new(top + side * w0),
              bm.verts.new(bottom + side * w1), bm.verts.new(bottom - side * w1)]
        f = bm.faces.new(vs)
        for lp, (u, a) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            lp[uv].uv = (u, 0.0)
            lp[uv2].uv = (a, 0.0)
            lp[col] = (rgb[0], rgb[1], rgb[2], seed)
    return rk.mesh_object(name, bm, mat, smooth=False)


def marker(name, loc):
    """An empty the game looks for by name (bubble vents and the like)."""
    o = bpy.data.objects.new(name, None)
    o.location = loc
    return rk.link(o)
