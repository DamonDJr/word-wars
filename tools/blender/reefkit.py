"""Reef life for the realistic boards: coral, sponges, anemones, kelp, a clam.

Every builder takes a seed, so a scene asks for "a pink staghorn here" and
gets a different one each time without anyone modelling it. Shapes are made
from tubes and lathed profiles in bmesh. Colour is the vertex colour, so one
material serves a whole reef of different corals, and its alpha marks the
growing tips, which the materials pale. The texture a coral is known by (the
cups of its polyps, a brain coral's grooves, a sponge's pores) is a bump in its
material, so it catches the light instead of being painted on.
"""

import math
import random

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector, noise

import realkit as rk
from realkit import TAU

GOLDEN = math.pi * (3.0 - math.sqrt(5.0))


# ---------------------------------------------------------------- materials

def _attr(nt):
    a = nt.nodes.new("ShaderNodeVertexColor")
    a.layer_name = "Col"
    return a


def coral_material(name="Coral", pattern="polyps", scale=60.0, relief=0.008, rough=0.6, sss=0.0):
    """Coloured by vertex colour, the tips (vertex alpha) paled.

    `pattern` is the relief: "polyps" the little cups stony corals are
    covered in, `scale` of them a metre; "brain" the meandering ridges of a
    brain coral; "sponge" a lumpy surface full of pores; "soft" almost
    smooth, for anemones and soft corals, which are lit through (`sss`)."""
    m, nt, out = rk._nodes(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    a = _attr(nt)
    co = rk._pos(nt)
    base = a.outputs["Color"]
    tip = a.outputs["Alpha"]
    # New growth has no algae living in it yet, so the tips are pale.
    col = rk._mix(nt, rk._math(nt, 'MULTIPLY', tip, 0.7), base, rk._mix(nt, 0.3, (0.95, 0.93, 0.88, 1.0), base))
    n = rk._noise(nt, scale * 0.15, 3.0, 0.6, co).outputs["Fac"]
    dark = rk._mix(nt, 0.75, col, (0.02, 0.02, 0.03, 1.0))
    if pattern == "polyps":
        v = rk._voronoi(nt, co, scale)
        d = v.outputs["Distance"]
        rim = rk._math(nt, 'MULTIPLY', rk._band(nt, d, 0.12, 0.28),
                       rk._math(nt, 'SUBTRACT', 1.0, rk._band(nt, d, 0.32, 0.55)))
        pit = rk._math(nt, 'SUBTRACT', 1.0, rk._band(nt, d, 0.0, 0.17))
        h = rk._sum(nt, [(rim, 0.35), (pit, -0.45), (n, 0.3)], 0.45)
        col = rk._mix(nt, rk._math(nt, 'MULTIPLY', pit, 0.7), col, dark)
    elif pattern == "brain":
        # Bands bent by a strong distortion wander like a maze but keep one
        # width, as a brain coral's ridges do.
        wv = nt.nodes.new("ShaderNodeTexWave")
        wv.wave_type = 'BANDS'
        wv.inputs["Scale"].default_value = scale * 0.06
        wv.inputs["Distortion"].default_value = 14.0
        wv.inputs["Detail"].default_value = 2.0
        wv.inputs["Detail Scale"].default_value = 1.5
        nt.links.new(co, wv.inputs["Vector"])
        ridge = rk._band(nt, wv.outputs["Fac"], 0.25, 0.6)
        h = rk._sum(nt, [(ridge, 0.7), (n, 0.25)], 0.0)
        groove = rk._mix(nt, 0.55, col, (0.06, 0.14, 0.07, 1.0))
        col = rk._mix(nt, ridge, groove, col)
    elif pattern == "sponge":
        v = rk._voronoi(nt, co, scale)
        pore = rk._math(nt, 'SUBTRACT', 1.0, rk._band(nt, v.outputs["Distance"], 0.08, 0.3))
        lumps = rk._noise(nt, scale * 0.12, 4.0, 0.55, co).outputs["Fac"]
        h = rk._sum(nt, [(lumps, 0.6), (pore, -0.4), (n, 0.2)], 0.2)
        col = rk._mix(nt, rk._math(nt, 'MULTIPLY', pore, 0.8), col, dark)
    else:
        h = rk._sum(nt, [(n, 0.5)], 0.25)
    # A little light and dark over each colony, so no two are flat paint.
    blot = rk._noise(nt, scale * 0.04, 2.0, 0.5, co).outputs["Fac"]
    col = rk._mix(nt, rk._band(nt, blot, 0.3, 0.7), rk._mix(nt, 0.3, col, (0, 0, 0, 1)), col)
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    if sss:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Scale"].default_value = 0.02
        nt.links.new(base, bsdf.inputs["Subsurface Radius"])
    # Bump rather than displacement: a reef is hundreds of small things, and
    # dicing every one to the pixel costs more memory than the whole city.
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Distance"].default_value = relief
    b.inputs["Strength"].default_value = 1.0
    nt.links.new(h, b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    rk.MATS[name] = m
    return m


def net_material(name="FanNet", scale=16.0):
    """A sea fan's lace: the vertex colour along a net of cell edges, two
    sizes of mesh over each other, and clear water between. The net is laid
    in the fan's own box (`scale` cells across it whatever its size) and in
    its plane, so a big fan far off and a small one close by read alike."""
    m, nt, out = rk._nodes(name)
    a = _attr(nt)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    flat = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["X"], flat.inputs["X"])
    nt.links.new(sep.outputs["Z"], flat.inputs["Y"])
    w = rk._warp(nt, flat.outputs[0], scale * 0.3, 0.25 / scale)
    v1 = rk._voronoi(nt, w, scale, 'DISTANCE_TO_EDGE')
    v2 = rk._voronoi(nt, w, scale * 2.2, 'DISTANCE_TO_EDGE')
    net = rk._math(nt, 'MAXIMUM', rk._math(nt, 'SUBTRACT', 1.0, rk._band(nt, v1.outputs["Distance"], 0.05, 0.1)),
                   rk._math(nt, 'SUBTRACT', 1.0, rk._band(nt, v2.outputs["Distance"], 0.04, 0.09)))
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(a.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(net, mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(bsdf.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    rk.MATS[name] = m
    return m


def leaf_material(name="Kelp", color="#8fae3a", back="#d8e86a", dark="#4a6a1c"):
    """Kelp and sea grass: waxy in front, lit through from behind, mottled,
    and darker where the vertex colour says (stems, floats)."""
    m, nt, out = rk._nodes(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    a = _attr(nt)
    n = rk._noise(nt, 3.0, 4.0, 0.5, tc.outputs["UV"])
    spots = rk._noise(nt, 40.0, 3.0, 0.6, rk._pos(nt))
    cr = rk._ramp(nt, n.outputs["Fac"], [(0.3, rk.srgb(dark)), (0.7, rk.srgb(color))]).outputs["Color"]
    cr = rk._mix(nt, rk._band(nt, spots.outputs["Fac"], 0.55, 0.7), cr, rk._mix(nt, 0.5, cr, (0, 0, 0, 1)))
    cr = rk._mix(nt, 1.0, cr, a.outputs["Color"], 'MULTIPLY')
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(cr, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.4
    tl = nt.nodes.new("ShaderNodeBsdfTranslucent")
    nt.links.new(rk._mix(nt, 1.0, rk.srgb(back), a.outputs["Color"], 'MULTIPLY'), tl.inputs["Color"])
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.45
    nt.links.new(bsdf.outputs[0], mix.inputs[1])
    nt.links.new(tl.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    rk.MATS[name] = m
    return m


def shell_material(name="Shell"):
    """Outside ridged and mottled, inside nacre: pale, with a film's colours
    sliding over it. Inside is the back of the faces (see `scallop`)."""
    m, nt, out = rk._nodes(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    inside = geo.outputs["Backfacing"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    co = tc.outputs["Object"]
    n = rk._noise(nt, 6.0, 4.0, 0.6, co)
    # Growth rings round the hinge, and the crust and pits of an old shell.
    rings = nt.nodes.new("ShaderNodeTexWave")
    rings.wave_type = 'RINGS'
    rings.inputs["Scale"].default_value = 9.0
    rings.inputs["Distortion"].default_value = 2.0
    rings.inputs["Detail"].default_value = 2.0
    nt.links.new(co, rings.inputs["Vector"])
    pits = rk._voronoi(nt, co, 40.0)
    pit = rk._math(nt, 'SUBTRACT', 1.0, rk._band(nt, pits.outputs["Distance"], 0.05, 0.25))
    outside = rk._ramp(nt, n.outputs["Fac"], [(0.35, rk.srgb("#6a3a44")), (0.65, rk.srgb("#d0907a"))]).outputs["Color"]
    outside = rk._mix(nt, rk._math(nt, 'MULTIPLY', rings.outputs["Fac"], 0.35), outside, rk.srgb("#3a2228"))
    outside = rk._mix(nt, rk._math(nt, 'MULTIPLY', pit, 0.5), outside, rk.srgb("#2a1a1c"))
    col = rk._mix(nt, inside, outside, rk.srgb("#f4e8f2"))
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.01
    h = rk._sum(nt, [(rings.outputs["Fac"], 0.4), (pit, -0.5), (n.outputs["Fac"], 0.5)])
    nt.links.new(rk._math(nt, 'MULTIPLY', h, rk._math(nt, 'SUBTRACT', 1.0, inside)), bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(col, bsdf.inputs["Base Color"])
    nt.links.new(rk._math(nt, 'MULTIPLY_ADD', inside, -0.45, 0.6), bsdf.inputs["Roughness"])
    nt.links.new(rk._math(nt, 'MULTIPLY', inside, 480.0), bsdf.inputs["Thin Film Thickness"])
    bsdf.inputs["Thin Film IOR"].default_value = 1.45
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    rk.MATS[name] = m
    return m


def materials():
    """One of each material a reef needs, by the name builders and `scatter`
    know them by."""
    return {
        "stony": coral_material("Coral", "polyps"),
        "brain": coral_material("Brain", "brain", scale=60.0, relief=0.02),
        "sponge": coral_material("Sponge", "sponge", scale=35.0, relief=0.014, rough=0.9),
        "soft": coral_material("Soft", "soft", scale=40.0, relief=0.002, rough=0.45, sss=0.2),
        "net": net_material(),
        "grass": leaf_material("Grass", color="#6a8a34", back="#a8c860"),
    }


# ------------------------------------------------------------------ helpers

def _color_layer(bm):
    return bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")


def _paint(bm, col, faces, rgb, tip=0.0):
    c = (rgb[0], rgb[1], rgb[2], tip)
    for f in faces:
        for lp in f.loops:
            lp[col] = c


def tube(bm, col, pts, radii, rgb, sides=8, tip=(0.0, 0.0), cap=True):
    """A tube through `pts` with a radius at each point, capped at the far end
    with a round tip. `rgb` is a colour or a function of how far along
    (0..1) it is, for bands; `tip` the tip mark at the start and the end."""
    rings = []
    prev_n = None
    faces = []
    last = len(pts) - 1
    for i, p in enumerate(pts):
        if i == 0:
            t = (pts[1] - pts[0]).normalized()
        elif i == last:
            t = (pts[-1] - pts[-2]).normalized()
        else:
            t = (pts[i + 1] - pts[i - 1]).normalized()
        if prev_n is None:
            a = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(a).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        ring = [bm.verts.new(p + (n * math.cos(TAU * k / sides) + b * math.sin(TAU * k / sides)) * radii[i])
                for k in range(sides)]
        rings.append(ring)

    def paint(f, ts):
        for lp, u in zip(f.loops, ts):
            c = rgb(u) if callable(rgb) else rgb
            lp[col] = (c[0], c[1], c[2], tip[0] + (tip[1] - tip[0]) * u)
    for i, (ra, rb) in enumerate(zip(rings, rings[1:])):
        u0, u1 = i / last, (i + 1) / last
        for k in range(sides):
            f = bm.faces.new((ra[k], ra[(k + 1) % sides], rb[(k + 1) % sides], rb[k]))
            paint(f, (u0, u0, u1, u1))
            faces.append(f)
    if cap:
        end = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1])
        for k in range(sides):
            f = bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], end))
            paint(f, (1.0, 1.0, 1.0))
            faces.append(f)
    return faces


def _jitter(rgb, rng, amount=0.12):
    return tuple(max(0.0, min(1.0, c * (1.0 + rng.uniform(-amount, amount)))) for c in rgb)


def _shade(rgb, k):
    return tuple(max(0.0, min(1.0, c * k)) for c in rgb)


def _finish(name, bm, mat, base, coll=None, rot=None):
    o = rk.mesh_object(name, bm, mat, coll)
    o.location = base
    if rot is not None:
        o.rotation_euler = rot
    return rk.organic(o)


def _wobble(bm, amount, freq, seed):
    """Push every vertex about a little by a noise: nothing grown is a
    perfect lathe."""
    off = Vector((seed * 7.31 % 100, seed * 3.17 % 100, seed * 5.13 % 100))
    for v in bm.verts:
        v.co += noise.noise_vector(v.co * freq + off) * amount


# ------------------------------------------------------------------- corals

def staghorn(name, base, size, rgb, seed, mat, depth=4, spread=0.6, coll=None):
    """Branching coral: each branch splits in two or three, barely thinning,
    turning upward, the growing tips pale, like staghorn or a red tree
    coral."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)

    def grow(p, d, length, radius, level):
        pts = [p]
        rad = [radius]
        n = 6
        dd = d.copy()
        for i in range(1, n + 1):
            dd = (dd + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.15))).normalized()
            pts.append(pts[-1] + dd * (length / n))
            rad.append(radius * (1.0 - 0.15 * i / n))
        end = level >= depth
        tube(bm, col, pts, rad, _jitter(rgb, rng), sides=8 if level < 2 else 6,
             tip=(0.15, 1.0) if end else (0.0, 0.15))
        if end:
            return
        for _ in range(rng.choice((2, 2, 3))):
            nd = (dd + Vector((rng.uniform(-spread, spread), rng.uniform(-spread, spread),
                               rng.uniform(0.0, 0.4)))).normalized()
            grow(pts[-1], nd, length * rng.uniform(0.6, 0.8), rad[-1] * 0.92, level + 1)

    for _ in range(rng.randint(2, 4)):
        d = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 1.0)).normalized()
        grow(Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0.0)) * size, d,
             size * 0.3, size * 0.05, 0)
    return _finish(name, bm, mat, base, coll, (0, 0, rng.uniform(0, TAU)))


def table_coral(name, base, size, rgb, seed, mat, coll=None):
    """A table coral: a stout foot and a broad, thin, lobed plate, its top
    bristling with short upright branchlets, the rim pale where it grows."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    dark = _shade(rgb, 0.6)
    tube(bm, col, [Vector((0, 0, 0)), Vector((0.02, 0, size * 0.16)), Vector((0, 0.02, size * 0.3))],
         [size * 0.12, size * 0.08, size * 0.14], dark, sides=12, cap=False)
    seg, nr = 72, 9
    off = rng.uniform(0, 100)
    lobes = [rng.uniform(0.0, 0.18) for _ in range(7)]

    def edge(a):
        r = 1.0 + 0.12 * noise.noise(Vector((math.cos(a) * 1.5 + off, math.sin(a) * 1.5, 0)))
        return size * r * (1.0 + sum(lb * math.cos((k + 2) * a + k) for k, lb in enumerate(lobes)) * 0.3)

    def surf(j, a, top):
        rho = j / nr
        r = edge(a) * rho
        z = size * (0.3 + 0.12 * rho * rho + 0.03 * math.sin(3 * a) * rho)
        if not top:
            z -= size * (0.07 - 0.04 * rho)
        return Vector((r * math.cos(a), r * math.sin(a), z))
    grids = []
    for top in (True, False):
        c = bm.verts.new(surf(0, 0, top))
        rings = [[bm.verts.new(surf(j, TAU * k / seg, top)) for k in range(seg)] for j in range(1, nr + 1)]
        for k in range(seg):
            q = (c, rings[0][k], rings[0][(k + 1) % seg])
            f = bm.faces.new(q if top else tuple(reversed(q)))
            _paint(bm, col, [f], rgb if top else dark)
        for j in range(nr - 1):
            for k in range(seg):
                q = (rings[j][k], rings[j + 1][k], rings[j + 1][(k + 1) % seg], rings[j][(k + 1) % seg])
                f = bm.faces.new(q if top else tuple(reversed(q)))
                _paint(bm, col, [f], rgb if top else dark, 0.6 * (j / nr) ** 3)
        grids.append(rings[-1])
    for k in range(seg):
        f = bm.faces.new((grids[0][k], grids[1][k], grids[1][(k + 1) % seg], grids[0][(k + 1) % seg]))
        _paint(bm, col, [f], rgb, 1.0)
    # Branchlets: short pale-tipped stubs all over the top.
    for _ in range(int(160 * size + 60)):
        a = rng.uniform(0, TAU)
        rho = math.sqrt(rng.uniform(0.02, 0.92))
        p = surf(rho * nr, a, True) * 1.0
        p.z -= size * 0.01
        h = size * rng.uniform(0.03, 0.07)
        lean = Vector((math.cos(a), math.sin(a), 0)) * rho * 0.5
        d = (Vector((0, 0, 1)) + lean).normalized()
        tube(bm, col, [p, p + d * h * 0.5, p + d * h], [size * 0.016, size * 0.014, size * 0.012],
             rgb, sides=5, tip=(0.2, 1.0))
    return _finish(name, bm, mat, base, coll, (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), rng.uniform(0, TAU)))


def sea_fan(name, base, size, rgb, seed, mats, facing=0.0, coll=None):
    """A gorgonian: a lace of branches in one gently waved plane, facing the
    current. The branches are tubes; the fine net between them is a sheet
    whose material lets the water through its holes."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)

    def wave(p):
        return Vector((p.x, p.y + size * 0.07 * math.sin(p.x / size * 3.0 + seed) * (p.z / size), p.z))

    def grow(p, ang, length, radius, level):
        pts = [p]
        rad = [radius]
        a = ang
        for i in range(1, 5):
            a += rng.uniform(-0.18, 0.18)
            pts.append(pts[-1] + Vector((math.sin(a), 0.0, math.cos(a))) * (length / 4))
            rad.append(radius * (1.0 - 0.2 * i / 4))
        tube(bm, col, [wave(q) for q in pts], rad, _jitter(rgb, rng, 0.08), sides=5,
             tip=(0.0, 0.5) if level >= 5 else (0.0, 0.0))
        if level >= 6:
            return
        grow(pts[-1], a - rng.uniform(0.2, 0.55), length * 0.78, rad[-1] * 0.82, level + 1)
        grow(pts[-1], a + rng.uniform(0.2, 0.55), length * 0.78, rad[-1] * 0.82, level + 1)

    grow(Vector((0, 0, 0)), 0.0, size * 0.22, size * 0.025, 0)
    # The net: a fan-shaped sheet from just above the foot to the branch tips.
    span, nr, seg = math.radians(72), 8, 28
    reach = [size * rng.uniform(0.72, 0.86) for _ in range(seg + 1)]
    rows = []
    for j in range(nr + 1):
        rho = 0.08 + 0.92 * j / nr
        rows.append([bm.verts.new(wave(Vector((math.sin(-span + 2 * span * k / seg) * reach[k] * rho, 0.0,
                                                  math.cos(-span + 2 * span * k / seg) * reach[k] * rho))))
                     for k in range(seg + 1)])
    net = []
    for j in range(nr):
        for k in range(seg):
            f = bm.faces.new((rows[j][k], rows[j][k + 1], rows[j + 1][k + 1], rows[j + 1][k]))
            f.material_index = 1
            net.append(f)
    _paint(bm, col, net, _shade(rgb, 0.85))
    o = _finish(name, bm, mats["stony"], base, coll, (rng.uniform(-0.15, 0.15), 0, facing))
    o.data.materials.append(mats["net"])
    return o


def brain_coral(name, base, size, rgb, seed, mat, coll=None):
    """A boulder coral, lumpy, its grooves in its material."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    col = _color_layer(bm)
    off = Vector((rng.uniform(0, 100), rng.uniform(0, 100), rng.uniform(0, 100)))
    for v in bm.verts:
        p = v.co.copy()
        if p.z < -0.2:
            p.z = -0.2 - (p.z + 0.2) * 0.2
        v.co = p * (1.0 + 0.1 * noise.noise(p * 1.5 + off) + 0.04 * noise.noise(p * 4.0 + off))
    _paint(bm, col, bm.faces, _jitter(rgb, rng))
    o = _finish(name, bm, mat, base, coll)
    o.scale = (size, size * rng.uniform(0.8, 1.1), size * rng.uniform(0.6, 0.8))
    return o


def anemone(name, base, size, rgb, seed, mat, tip_rgb=None, coll=None):
    """A sea anemone: a stout column, a disc, and a mop of tentacles curling
    out and up from it, each fattening to a bulb just before its tip, the
    way a bubble-tip anemone's do."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    column = _shade(rgb, 0.55)
    tip_rgb = tip_rgb or tuple(min(1.0, c * 0.5 + 0.5) for c in rgb)
    faces = []
    rings = rk.lathe(bm, [(size * 0.2, -size * 0.05), (size * 0.21, size * 0.1), (size * 0.26, size * 0.2),
                          (size * 0.3, size * 0.24), (size * 0.18, size * 0.27), (0.0, size * 0.26)], 24)
    _paint(bm, col, bm.faces, column)
    n = rng.randint(60, 90)
    for i in range(n):
        a = GOLDEN * i + rng.uniform(-0.1, 0.1)
        r0 = size * 0.29 * math.sqrt((i + 0.5) / n)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        root = Vector((r0 * math.cos(a), r0 * math.sin(a), size * 0.25))
        length = size * rng.uniform(0.35, 0.55)
        splay = 0.35 + 1.6 * r0 / size
        d = (out * splay + Vector((0, 0, 1))).normalized()
        curl = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.0)) * 0.25
        pts = [root]
        for k in range(1, 8):
            d = (d + out * 0.12 + curl - Vector((0, 0, 0.06 * k * splay))).normalized()
            pts.append(pts[-1] + d * length / 7)
        rr = size * rng.uniform(0.026, 0.034)
        radii = [rr, rr * 0.92, rr * 0.86, rr * 0.82, rr * 0.86, rr * 1.15, rr * 1.2, rr * 0.7]
        tube(bm, col, pts, radii, lambda u: tip_rgb if u > 0.72 else rgb, sides=6, tip=(0.0, 0.6))
    return _finish(name, bm, mat, base, coll, (0, 0, rng.uniform(0, TAU)))


def zoanthids(name, base, size, rgb, seed, mat, count=60, center_rgb=None, coll=None):
    """A carpet of zoanthid polyps: short stalks crowded together, each
    opening to a flat disc whose middle is another colour."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    center_rgb = center_rgb or (0.35, 0.8, 0.3)
    for i in range(count):
        a = GOLDEN * i
        r = size * math.sqrt((i + 0.5) / count) + rng.uniform(-0.02, 0.02) * size
        p = Vector((r * math.cos(a), r * math.sin(a), -size * 0.02))
        h = size * rng.uniform(0.04, 0.09)
        d = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 1.0)).normalized()
        rr = size * rng.uniform(0.04, 0.055)
        top = p + d * h
        tube(bm, col, [p, p + d * h * 0.5, top], [rr * 0.8, rr * 0.75, rr * 0.85], _shade(rgb, 0.6),
             sides=8, cap=False)
        # The disc: a fan of the stalk's last ring out to a wider rim.
        n = d
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(t)
        c = bm.verts.new(top + n * rr * 0.1)
        rim = [bm.verts.new(top + (t * math.cos(TAU * k / 10) + b * math.sin(TAU * k / 10)) * rr * 1.45)
               for k in range(10)]
        for k in range(10):
            f = bm.faces.new((c, rim[k], rim[(k + 1) % 10]))
            for lp in f.loops:
                cc = center_rgb if lp.vert is c else rgb
                lp[col] = (cc[0], cc[1], cc[2], 0.0)
    return _finish(name, bm, mat, base, coll)


def anemones(name, base, size, rgb, seed, mat, count=40, coll=None):
    """A patch of zoanthids, kept under the old name."""
    return zoanthids(name, base, size, rgb, seed, mat, count=count, coll=coll)


# ------------------------------------------------------------------ sponges

def barrel_sponge(name, base, size, rgb, seed, mat, coll=None):
    """A barrel sponge: a thick-walled vase with deep, uneven ridges up its
    sides and a ragged lip."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    ridges = rng.randint(9, 14)
    tall = rng.uniform(0.9, 1.3)
    ph = rng.uniform(0, TAU)
    prof = [(0.25, 0.0), (0.38, 0.12), (0.47, 0.35), (0.5, 0.6), (0.48, 0.85), (0.45, 1.0)]

    def radial(a):
        r = abs(math.sin(ridges * 0.5 * a + ph + 0.4 * math.sin(3 * a)))
        return 1.0 + 0.1 * r ** 0.5
    rk.lathe(bm, [(r * size, z * size * tall) for r, z in prof], 96, radial=radial, cap_top=False)
    _wobble(bm, size * 0.035, 3.0 / size, seed)
    _paint(bm, col, bm.faces, _jitter(rgb, rng))
    o = _finish(name, bm, mat, base, coll)
    s = o.modifiers.new("wall", 'SOLIDIFY')
    s.thickness = size * 0.09
    s.offset = -1.0
    return o


def tube_sponges(name, base, size, rgb, seed, mat, coll=None):
    """A cluster of tube sponges: tall open tubes, thick-lipped and a little
    crooked, leaning out from one root."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    for _ in range(rng.randint(3, 6)):
        d = Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 1.0)).normalized()
        h = size * rng.uniform(0.6, 1.0)
        r = size * rng.uniform(0.07, 0.11)
        m = Matrix.Translation(Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0)) * size) \
            @ d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
        rk.lathe(bm, [(r * 0.8, 0.0), (r, h * 0.3), (r * 1.05, h * 0.7), (r * 1.15, h)], 24, xform=m,
                 cap_top=False)
    _wobble(bm, size * 0.02, 4.0 / size, seed)
    _paint(bm, col, bm.faces, _jitter(rgb, rng))
    o = _finish(name, bm, mat, base, coll)
    s = o.modifiers.new("wall", 'SOLIDIFY')
    s.thickness = size * 0.025
    s.offset = -1.0
    return o


# ------------------------------------------------------------ other animals

def feather_dusters(name, base, size, rgb, seed, mat, count=None, coll=None):
    """Feather-duster worms: leathery tubes, each opening into a funnel of
    banded feathery arms."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    for w in range(count or rng.randint(3, 7)):
        root = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.0)) * size * 0.18
        axis = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 1.0)).normalized()
        h = size * rng.uniform(0.25, 0.5)
        stalk = [root + axis * h * t + Vector((0.03 * math.sin(t * 4 + w), 0, 0)) * size for t in (0, 0.33, 0.66, 1)]
        tube(bm, col, stalk, [size * 0.022] * 4, (0.32, 0.24, 0.17), sides=8, cap=False)
        top = stalk[-1]
        t = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.95 else Vector((1, 0, 0))).normalized()
        b = axis.cross(t)
        band = _jitter(rgb, rng, 0.1)
        arms = rng.randint(22, 32)
        open_ = math.radians(rng.uniform(32, 48))
        for k in range(arms):
            a = TAU * k / arms
            out = t * math.cos(a) + b * math.sin(a)
            d = (axis * math.cos(open_) + out * math.sin(open_)).normalized()
            L = size * rng.uniform(0.18, 0.24)
            pts = [top + out * size * 0.012]
            for i in range(1, 6):
                d = (d + out * 0.08).normalized()
                pts.append(pts[-1] + d * L / 5)
            tube(bm, col, pts, [size * 0.007, size * 0.006, size * 0.006, size * 0.005, size * 0.004, size * 0.003],
                 lambda u: band if int(u * 7) % 2 == 0 else (0.9, 0.88, 0.82), sides=4, tip=(0.0, 0.5))
    return _finish(name, bm, mat, base, coll)


def urchins(name, base, size, seed, mat, count=None, rgb=(0.12, 0.04, 0.1), coll=None):
    """Long-spined sea urchins huddled together: a dark round body bristling
    with needles, paler toward their points."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    for u in range(count or rng.randint(3, 7)):
        c = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), 0.0)) * size * 0.4
        r = size * rng.uniform(0.07, 0.1)
        c.z = r * 0.55
        body = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r,
                                          matrix=Matrix.Translation(c) @ Matrix.Diagonal((1, 1, 0.75, 1)))
        _paint(bm, col, {f for v in body["verts"] for f in v.link_faces}, rgb)
        for k in range(rng.randint(90, 140)):
            z = rng.uniform(-0.2, 1.0)
            a = rng.uniform(0, TAU)
            d = Vector((math.sqrt(1 - z * z) * math.cos(a), math.sqrt(1 - z * z) * math.sin(a), z))
            L = r * rng.uniform(1.6, 3.0)
            p0 = c + Vector((d.x, d.y, d.z * 0.75)) * r * 0.95
            tube(bm, col, [p0, p0 + d * L * 0.5, p0 + d * L], [r * 0.05, r * 0.03, r * 0.008],
                 _shade(rgb, 1.3), sides=4, tip=(0.0, 0.8))
    return _finish(name, bm, mat, base, coll)


def starfish(name, base, size, rgb, seed, mat, coll=None):
    """A sea star lying on the rock: five tapering arms, each curled a little
    its own way, domed along the middle."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    seg, nr = 100, 6
    bends = [rng.uniform(-0.25, 0.25) for _ in range(5)]

    def outline(a):
        k = (0.5 + 0.5 * math.cos(5 * a)) ** 1.8
        return size * (0.2 + 0.8 * k)

    def pt(j, a, top):
        rho = j / nr
        arm = int(round(a / (TAU / 5))) % 5
        aa = a + bends[arm] * rho * rho
        r = outline(a) * rho
        z = (size * 0.1 * (1.0 - rho ** 2) * (0.4 + 0.6 * (0.5 + 0.5 * math.cos(5 * a)))) if top else 0.0
        return Vector((r * math.cos(aa), r * math.sin(aa), z + 0.005 * size))
    rims = []
    for top in (True, False):
        c = bm.verts.new(pt(0, 0, top))
        rings = [[bm.verts.new(pt(j, TAU * k / seg, top)) for k in range(seg)] for j in range(1, nr + 1)]
        for k in range(seg):
            q = (c, rings[0][k], rings[0][(k + 1) % seg])
            bm.faces.new(q if top else tuple(reversed(q)))
        for j in range(nr - 1):
            for k in range(seg):
                q = (rings[j][k], rings[j + 1][k], rings[j + 1][(k + 1) % seg], rings[j][(k + 1) % seg])
                bm.faces.new(q if top else tuple(reversed(q)))
        rims.append(rings[-1])
    for k in range(seg):
        bm.faces.new((rims[0][k], rims[1][k], rims[1][(k + 1) % seg], rims[0][(k + 1) % seg]))
    _paint(bm, col, bm.faces, _jitter(rgb, rng))
    return _finish(name, bm, mat, base, coll, (0, 0, rng.uniform(0, TAU)))


def sea_whips(name, base, size, rgb, seed, mat, coll=None):
    """Sea whips: a few long, thin, springy rods from one holdfast, now and
    then forked."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    for _ in range(rng.randint(4, 9)):
        d = Vector((rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), 1.0)).normalized()
        L = size * rng.uniform(0.6, 1.2)
        bend = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0))
        pts = [Vector((0, 0, 0))]
        for i in range(1, 9):
            d = (d + bend * 0.08).normalized()
            pts.append(pts[-1] + d * L / 8)
        tube(bm, col, pts, [size * 0.018 * (1.0 - 0.6 * i / 8) for i in range(9)], _jitter(rgb, rng),
             sides=6, tip=(0.0, 0.8))
    return _finish(name, bm, mat, base, coll)


def soft_tree(name, base, size, rgb, seed, mat, coll=None):
    """A soft tree coral: a pale, glassy trunk branching a few times, every
    twig ending in a tight bunch of brightly coloured polyps."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    trunk = (0.85, 0.78, 0.76)

    def grow(p, d, length, radius, level):
        pts = [p]
        for i in range(1, 4):
            d = (d + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0.1))).normalized()
            pts.append(pts[-1] + d * length / 3)
        tube(bm, col, pts, [radius, radius * 0.9, radius * 0.8, radius * 0.7], trunk, sides=7)
        if level >= 3:
            for _ in range(rng.randint(6, 12)):
                q = pts[-1] + Vector((rng.gauss(0, 1), rng.gauss(0, 1), abs(rng.gauss(0, 1)))) * size * 0.05
                s = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=size * rng.uniform(0.025, 0.04),
                                               matrix=Matrix.Translation(q))
                _paint(bm, col, {f for v in s["verts"] for f in v.link_faces}, _jitter(rgb, rng, 0.15), 0.3)
            return
        for _ in range(rng.choice((2, 3, 3))):
            nd = (d + Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0.2))).normalized()
            grow(pts[-1], nd, length * 0.7, radius * 0.7, level + 1)

    grow(Vector((0, 0, 0)), Vector((0, 0, 1)), size * 0.35, size * 0.07, 0)
    return _finish(name, bm, mat, base, coll)


def barnacles(name, spots, seed, mat, size=0.05, coll=None):
    """Barnacles crowded round each of `spots` [(point, normal, count)]:
    little chalky cones of plates, open at the top."""
    rng = random.Random(seed)
    bm = bmesh.new()
    col = _color_layer(bm)
    for p, n, k in spots:
        n = Vector(n).normalized()
        t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
        b = n.cross(t)
        for _ in range(k):
            r = size * rng.uniform(0.35, 1.0)
            off = (t * rng.gauss(0, 1) + b * rng.gauss(0, 1)) * size * 1.4
            m = Matrix.Translation(Vector(p) + off - n * r * 0.2) @ n.to_track_quat('Z', 'Y').to_matrix().to_4x4() \
                @ Matrix.Rotation(rng.uniform(0, TAU), 4, 'Z')
            h = r * rng.uniform(0.7, 1.1)
            before = set(bm.faces)
            rk.lathe(bm, [(r, 0.0), (r * 0.92, h * 0.35), (r * 0.55, h * 0.95), (r * 0.42, h), (r * 0.3, h * 0.82),
                          (0.0, h * 0.75)], 12, xform=m, radial=lambda a: 1.0 + 0.1 * abs(math.cos(3 * a)),
                     cap_top=False)
            shade = rng.uniform(0.6, 0.95)
            _paint(bm, col, set(bm.faces) - before, (0.8 * shade, 0.77 * shade, 0.7 * shade))
    o = rk.mesh_object(name, bm, mat, coll)
    return rk.organic(o)


# --------------------------------------------------------------------- kelp

def kelp(name, base, height, seed, mat, blades=5, lean=(0.0, 0.0), coll=None):
    """A clump of giant kelp: `blades` stems rising from one holdfast, each
    hung with wrinkled blades, every blade on a little gas float. UV.y runs
    0 at a blade's root to 1 at its tip."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = _color_layer(bm)
    stem_rgb = (0.45, 0.4, 0.22)
    for s in range(blades):
        a0 = rng.uniform(0, TAU)
        h = height * rng.uniform(0.6, 1.0)
        bend = Vector((lean[0] + rng.uniform(-0.25, 0.25), lean[1] + rng.uniform(-0.25, 0.25), 0.0))
        root = Vector((math.cos(a0), math.sin(a0), 0.0)) * height * 0.03
        n = 20
        stem = [root + Vector((0, 0, h * i / n)) + bend * h * (i / n) ** 2
                + Vector((math.sin(i * 0.5 + s), math.cos(i * 0.4 + s), 0)) * height * 0.012 for i in range(n + 1)]
        faces = tube(bm, col, stem, [height * 0.006] * (n + 1), stem_rgb, sides=5)
        for f in faces:
            for lp in f.loops:
                lp[uv].uv = (0.5, 0.0)
        side = rng.uniform(0, TAU)
        for i in range(2, n + 1):
            p = stem[i]
            side += math.pi * rng.uniform(0.8, 1.2)
            along = (stem[min(i + 1, n)] - stem[i - 1]).normalized()
            out = Vector((math.cos(side), math.sin(side), 0.0))
            out = (out - along * out.dot(along)).normalized()
            float_p = p + out * height * 0.012
            fl = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=height * 0.007,
                                            matrix=Matrix.Translation(float_p) @ Matrix.Diagonal((1, 1, 1.6, 1)))
            _paint(bm, col, {f for v in fl["verts"] for f in v.link_faces}, (0.55, 0.5, 0.25))
            # The blade: long, wrinkled across and ruffled at the edges, and
            # turned more or less toward the camera (down -Y), as a blade
            # streaming in the current shows its face more often than its edge.
            top = i / n
            L = height * rng.uniform(0.17, 0.27) * (1.0 - 0.4 * top)
            W = L * rng.uniform(0.11, 0.15)
            # Close along the stem, streaming up with it, so a stem and its
            # blades read as one long frond rather than a branch of leaves;
            # the current takes them all a little to -X.
            bd = (out * 0.38 + along * 0.92 + Vector((-0.12, 0, 0))).normalized()
            wide = bd.cross(Vector((0, 1, 0))) + Vector((rng.uniform(-0.4, 0.4), 0, rng.uniform(-0.4, 0.4)))
            wide = (wide - bd * wide.dot(bd)).normalized()
            twist = rng.uniform(-0.4, 0.4)
            rows = 18
            prev = None
            for r in range(rows + 1):
                v = r / rows
                sweep = Vector((-L * 0.18 * v * v, 0, 0)) + out * L * 0.12 * math.sin(v * math.pi)
                c = float_p + bd * L * v + sweep
                q = Quaternion(bd, twist * v)
                wv = q @ wide
                nv = q @ bd.cross(wide)
                # Lance-shaped: widest a quarter of the way out, a long
                # taper to the tip.
                w = W * (min(1.0, (v + 0.06) / 0.28) * (1.0 - max(0.0, v - 0.25) / 0.75) ** 0.9) ** 0.8
                row = []
                for j, u in enumerate((-1.0, -0.5, 0.0, 0.5, 1.0)):
                    corr = 0.14 * W * math.sin(v * 44.0 + u * 2.0 + s) * (0.3 + abs(u))
                    ruffle = 0.3 * W * math.sin(v * 70.0 + s * 3) * abs(u) ** 3
                    row.append(bm.verts.new(c + wv * w * u + nv * (corr + ruffle)))
                if prev:
                    for j in range(4):
                        f = bm.faces.new((prev[j], prev[j + 1], row[j + 1], row[j]))
                        for lp, (uu, vv) in zip(f.loops, ((j / 4, (r - 1) / rows), ((j + 1) / 4, (r - 1) / rows),
                                                          ((j + 1) / 4, v), (j / 4, v))):
                            lp[uv].uv = (uu, vv)
                            lp[col] = (1.0, 1.0, 1.0, 0.0)
                prev = row
    o = rk.mesh_object(name, bm, mat, coll)
    o.location = base
    return o


def sea_grass(name, base, size, seed, mat, count=50, coll=None):
    """A tuft of sea grass: thin blades from one patch, each bending over
    its own way and twisting as it goes."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = _color_layer(bm)
    for _ in range(count):
        a = rng.uniform(0, TAU)
        r = size * 0.3 * math.sqrt(rng.random())
        root = Vector((r * math.cos(a), r * math.sin(a), 0.0))
        h = size * rng.uniform(0.5, 1.0)
        bend = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.0))
        twist = rng.uniform(-2.0, 2.0)
        prev = None
        n = 9
        for i in range(n + 1):
            t = i / n
            c = root + Vector((0, 0, h * t * (1.0 - 0.3 * t * bend.length))) + bend * h * t * t
            side = Quaternion((0, 0, 1), a + twist * t) @ Vector((size * 0.014 * (1.0 - 0.8 * t), 0, 0))
            pair = (bm.verts.new(c - side), bm.verts.new(c + side))
            if prev:
                f = bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
                for lp, v in zip(f.loops, ((0, t - 1 / n), (1, t - 1 / n), (1, t), (0, t))):
                    lp[uv].uv = v
                    lp[col] = (1.0, 1.0, 1.0, 0.0)
            prev = pair
    o = rk.mesh_object(name, bm, mat, coll)
    o.location = base
    return o


def strands(name, anchors, seed, mat, length=(0.4, 1.4), width=0.03, coll=None):
    """Weed hanging from ledges and arms: a ribbon dropping from each of
    `anchors`, tapering, turning and drifting a little off the vertical."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    col = _color_layer(bm)
    for p in anchors:
        L = rng.uniform(*length)
        drift = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))
        twist = rng.uniform(0, TAU)
        prev = None
        n = 10
        for i in range(n + 1):
            t = i / n
            c = Vector(p) + Vector((0, 0, -L * t)) + drift * L * t * t \
                + Vector((math.sin(t * 7 + twist), 0, 0)) * L * 0.03
            side = Quaternion((0, 0, 1), twist + t * 2.5) @ Vector((width * (1.0 - 0.6 * t), 0, 0))
            pair = (bm.verts.new(c - side), bm.verts.new(c + side))
            if prev:
                f = bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
                for lp, v in zip(f.loops, ((0, t - 1 / n), (1, t - 1 / n), (1, t), (0, t))):
                    lp[uv].uv = v
                    lp[col] = (0.7, 0.66, 0.5, 0.0)
            prev = pair
    return rk.mesh_object(name, bm, mat, coll)


# --------------------------------------------------------------------- clam

def scallop(name, base, size, seed, mat, open_deg=55.0, yaw=0.0, coll=None):
    """A giant scallop, open: two ribbed fans hinged at the back, the lower
    one cupped on the rock, the upper tipped up. Single-sided, with every
    normal pointing out of the shell, so the material can tell the nacre
    inside by its back faces."""
    bm = bmesh.new()
    ribs = 18
    nu, nv = 18, ribs * 6

    def half(upper):
        verts = []
        for i in range(nu + 1):
            u = i / nu
            row = []
            for j in range(nv + 1):
                v = j / nv * 2.0 - 1.0
                a = v * math.radians(72)
                r = size * (0.08 + 0.92 * u)
                rib = 0.035 * size * u * (0.5 + 0.5 * math.cos(v * ribs * math.pi))
                # Growth lines: fine ridges round the shell, the way it grew.
                rib += 0.006 * size * u * math.sin(u * 90.0)
                cup = 0.22 * size * (1.0 - u ** 2) * math.cos(a * 0.9) * u ** 0.4
                z = (cup + rib) if upper else -(cup + rib)
                row.append(bm.verts.new((r * math.sin(a), r * math.cos(a), z)))
            verts.append(row)
        faces = []
        for i in range(nu):
            for j in range(nv):
                q = (verts[i][j], verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1])
                faces.append(bm.faces.new(q if upper else tuple(reversed(q))))
        return verts, faces

    half(False)
    uv, _ = half(True)
    rot = Matrix.Rotation(math.radians(open_deg), 4, 'X')
    for row in uv:
        for v in row:
            v.co = rot @ v.co
    o = rk.mesh_object(name, bm, mat, coll)
    o.location = base
    o.rotation_euler = (0, 0, yaw)
    return o


# ------------------------------------------------------------------ scatter

PALETTE = [(0.9, 0.25, 0.4), (0.8, 0.12, 0.1), (0.95, 0.45, 0.12), (0.45, 0.15, 0.7), (0.85, 0.15, 0.6),
           (0.9, 0.75, 0.2), (0.95, 0.55, 0.45), (0.3, 0.6, 0.75),
           # The browns, ochres and olives most of a real reef is.
           (0.55, 0.38, 0.2), (0.62, 0.52, 0.3), (0.4, 0.45, 0.22), (0.7, 0.6, 0.5)]

# What grows where `scatter` drops it, and how often.
KINDS = [("stag", 13), ("table", 6), ("fan", 9), ("brain", 9), ("anemone", 9), ("zoanthids", 9),
         ("barrel", 7), ("tubes", 8), ("dusters", 7), ("urchins", 5), ("star", 3), ("whips", 6), ("soft", 6),
         ("grass", 8)]


def grow(kind, nm, loc, s, rgb, seed, mats):
    """One thing of `kind`, `s` big, at `loc`."""
    rng = random.Random(seed)
    if kind == "stag":
        return staghorn(nm, loc, s * 1.2, rgb, seed, mats["stony"], depth=3)
    if kind == "table":
        return table_coral(nm, loc, s * 0.9, rgb, seed, mats["stony"])
    if kind == "fan":
        return sea_fan(nm, loc, s * 1.6, rgb, seed, mats, facing=rng.uniform(-0.5, 0.5))
    if kind == "brain":
        return brain_coral(nm, loc, s * 0.45, rgb, seed, mats["brain"])
    if kind == "anemone":
        return anemone(nm, loc, s * 0.8, rgb, seed, mats["soft"])
    if kind == "zoanthids":
        return zoanthids(nm, loc, s * 0.6, rgb, seed, mats["soft"], count=50,
                         center_rgb=rng.choice(PALETTE))
    if kind == "barrel":
        return barrel_sponge(nm, loc, s * 0.7, rng.choice(((0.75, 0.38, 0.15), (0.55, 0.3, 0.2), (0.6, 0.25, 0.5))),
                             seed, mats["sponge"])
    if kind == "tubes":
        return tube_sponges(nm, loc, s * 0.9, rgb, seed, mats["sponge"])
    if kind == "dusters":
        return feather_dusters(nm, loc, s * 1.0, rgb, seed, mats["soft"])
    if kind == "urchins":
        return urchins(nm, loc, s * 1.2, seed, mats["stony"])
    if kind == "star":
        return starfish(nm, loc, s * 0.35, rng.choice(((0.9, 0.35, 0.1), (0.8, 0.15, 0.15), (0.25, 0.4, 0.85))),
                        seed, mats["stony"])
    if kind == "whips":
        return sea_whips(nm, loc, s * 1.3, rgb, seed, mats["stony"])
    if kind == "soft":
        return soft_tree(nm, loc, s * 0.9, rgb, seed, mats["soft"])
    return sea_grass(nm, loc, s * 1.2, seed, mats["grass"])


def _pick(rng, kinds):
    total = sum(w for _, w in kinds)
    x = rng.uniform(0, total)
    for k, w in kinds:
        x -= w
        if x <= 0:
            return k
    return kinds[-1][0]


def scatter(name, targets, center, radius, count, seed, mats, scale=1.0, up_only=0.4, kinds=None):
    """Grow a reef on `targets`: drop rays from above within `radius` of
    `center`, and where one lands on an upward-facing part of a target, put
    something there that grows on rock, sized by `scale`."""
    rng = random.Random(seed)
    scene = bpy.context.scene
    dg = bpy.context.evaluated_depsgraph_get()
    keep = set(targets)
    made = []
    c = Vector(center)
    kinds = kinds or KINDS
    for i in range(count * 3):
        if len(made) >= count:
            break
        a = rng.uniform(0, TAU)
        r = radius * math.sqrt(rng.random())
        origin = c + Vector((r * math.cos(a), r * math.sin(a), radius + 30.0))
        hit, loc, nor, _, obj, _ = scene.ray_cast(dg, origin, Vector((0, 0, -1)))
        if not hit or obj not in keep or nor.z < up_only:
            continue
        kind = _pick(rng, kinds)
        s = scale * rng.uniform(0.6, 1.4)
        o = grow(kind, "%s%d" % (name, len(made)), loc - nor * 0.05 * s, s, rng.choice(PALETTE),
                 seed * 100 + i, mats)
        o.rotation_mode = 'QUATERNION'
        if kind in ("fan", "whips", "grass", "soft"):
            # These stand up whatever they grow on, and fans turn their lace
            # to the current, which here is toward the camera.
            o.rotation_quaternion = Quaternion((0, 0, 1), rng.uniform(-0.5, 0.5))
        else:
            o.rotation_quaternion = nor.to_track_quat('Z', 'Y') @ Quaternion((0, 0, 1), rng.uniform(0, TAU))
        made.append(o)
    return made


def surface_points(objs, count, seed, accept=None):
    """`count` points spread evenly by area over `objs` as the renderer will
    see them (modifiers applied), each with its normal, in world space.
    `accept(point, normal)` filters them (more are drawn to make up)."""
    rng = np.random.default_rng(seed)
    dg = bpy.context.evaluated_depsgraph_get()
    tris, norms = [], []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        co = np.empty(len(me.vertices) * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        mw = np.array(o.matrix_world)
        co = co @ mw[:3, :3].T + mw[:3, 3]
        idx = np.empty(len(me.loop_triangles) * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("vertices", idx)
        t = co[idx.reshape(-1, 3)]
        tris.append(t)
        ev.to_mesh_clear()
    t = np.concatenate(tris)
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    area = np.linalg.norm(n, axis=1)
    n = n / np.maximum(area, 1e-12)[:, None]
    p = area / area.sum()
    out = []
    tries = 0
    while len(out) < count and tries < 20:
        tries += 1
        pick = rng.choice(len(t), size=count * 2, p=p)
        r1, r2 = rng.random(len(pick)), rng.random(len(pick))
        s = np.sqrt(r1)
        pts = t[pick, 0] * (1 - s)[:, None] + t[pick, 1] * (s * (1 - r2))[:, None] + t[pick, 2] * (s * r2)[:, None]
        for q, nn in zip(pts, n[pick]):
            q, nn = Vector(q), Vector(nn)
            if accept is None or accept(q, nn):
                out.append((q, nn))
                if len(out) >= count:
                    break
    return out
