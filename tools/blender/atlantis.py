"""Atlantis: a sunken city, as a realistic board.

    LD_LIBRARY_PATH=/usr/lib blender --background --python tools/blender/atlantis.py \
        -- [--preview | --still | --live] [--width N] [--samples N] [--out PATH]
        [--crop U0,V0,U1,V1]

Writes what the game loads: boards/3d/atlantis/ (the rendered plate, the
layers that move in place, the depth and plate.json) and boards/3d/atlantis.glb
(the camera and everything that swims). Saves build/boards3d/atlantis.blend.

`--preview` renders a small, quick still for checking the layout, `--still`
a full-size one, and neither writes game files. `--live` rewrites only the
glTF, for when only the creatures have changed.

Looking up out of a chasm at the drowned city. On the left a colossal bronze
statue of the sea king stands on a cliff with his trident, jellyfish drifting
past him; in the middle, columns climb out of the deep and a great ring hangs
over the city, lit from its core; on the right a domed hall still glows from
inside, behind tiers of arches. Light comes down from the surface in shafts.
In front: rock, coral, a giant clam holding a pearl, and a merman swimming up
toward the statue.

How this is built, and what the game adds over it, is in `realkit.py`.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import realkit as rk  # noqa: E402
import reefkit as rf  # noqa: E402
import sealife as sl  # noqa: E402
from realkit import TAU  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = "--preview" in ARGS


def arg(name, default):
    return type(default)(ARGS[ARGS.index(name) + 1]) if name in ARGS else default


rk.setup()
CAM = rk.camera(vfov=62.0, pitch=9.0, loc=(0.0, 0.0, 6.0), clip_end=900.0)

SURFACE = 95.0      # the sea's surface, metres above the camera's ledge
FLOOR = -28.0       # the bottom of the chasm

# ---------------------------------------------------------------- materials

M = {
    "rock": rk.stone("Rock", base="#727c80", dark="#2a3238", moss="#4a6a2e", moss_amount=0.55,
                     scale=1.0, relief=0.45, algae="#2c4c50", tone="#7c6a58", coralline=0.7, sponges=0.6),
    "cliff": rk.stone("Cliff", base="#626c72", dark="#20282e", moss="#3f6030", moss_amount=0.65,
                      scale=0.7, relief=0.8, algae="#28484c", tone="#6e6254", coralline=0.5, sponges=0.4),
    "marble": rk.stone("Marble", base="#c8c4b8", dark="#7c8086", moss="#56723a", moss_amount=0.45,
                       scale=1.4, relief=0.08, rough=0.6, algae="#3a5c5c", tone="#b0a490", cracks=0.45,
                       pits=0.7, coralline=0.2, sponges=0.15, dice=False, streaks=0.6),
    "sandstone": rk.stone("Sandstone", base="#a89a84", dark="#5c584e", moss="#4c6a34",
                          moss_amount=0.55, scale=1.2, relief=0.16, algae="#3a5656", blocks=0.9,
                          tone="#8e7a62", coralline=0.25, sponges=0.2, dice=False, streaks=0.8),
    "sand": rk.stone("Sand", base="#9aa29c", dark="#6a7470", moss="#556a3a", moss_amount=0.15,
                     scale=2.0, relief=0.06, rough=0.95, cracks=0.0, pits=0.2, silt=0.0),
    # Old bronze: dark, green with verdigris over most of it and crusted on
    # top, the warm metal showing only where it stands proud.
    "bronze": rk.metal("Bronze", base="#a8803e", dark="#3e2814", patina="#3a8a7c", patina_amount=0.85,
                       rough=0.42, moss_amount=0.35, wear=0.8, streaks=0.7, crust=1.0, relief=0.06, scale=1.2),
    "gold": rk.metal("Gold", base="#e2b04a", patina="#4a8a70", patina_amount=0.2, rough=0.25,
                     streaks=0.15, crust=0.3, scale=1.5, dark="#8a6420"),
    # The same bronze on what is built (domes, the ring), as a bump.
    "dome": rk.metal("DomeBronze", base="#b8904c", patina="#3a8a7c", patina_amount=0.6, rough=0.38,
                     moss_amount=0.35, wear=0.8, streaks=0.55, crust=0.75, scale=1.2),
    "window": rk.emissive("Window", "#ff9a3c", 2.2),
    "core": rk.emissive("Core", "#7fe8ff", 30.0),
}


# ------------------------------------------------------------------ helpers

def rock(name, center, size, seed, mat=None, squash=(1.0, 1.0, 1.0), detail=0.35,
         rot=(0.0, 0.0, 0.0), coll=None):
    """A boulder or a cliff: a ball pushed about by two noises. The noises are
    read in world space, so no two rocks share a shape."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    o = rk.mesh_object(name, bm, mat or M["rock"], coll)
    o.location = center
    o.scale = (size * squash[0], size * squash[1], size * squash[2])
    o.rotation_euler = (rot[0] + rng.uniform(-0.3, 0.3), rot[1] + rng.uniform(-0.3, 0.3),
                        rot[2] + rng.uniform(0, TAU))
    big = bpy.data.textures.new(name + "_big", 'CLOUDS')
    big.noise_scale = size * 0.7
    big.noise_depth = 2
    d1 = o.modifiers.new("big", 'DISPLACE')
    d1.texture = big
    d1.strength = 0.6
    d1.texture_coords = 'GLOBAL'
    sub = o.modifiers.new("sub", 'SUBSURF')
    sub.levels = sub.render_levels = 2
    vor = bpy.data.textures.new(name + "_vor", 'VORONOI')
    vor.noise_scale = detail * max(1.0, size * 0.25)
    vor.distance_metric = 'DISTANCE'
    d2 = o.modifiers.new("chips", 'DISPLACE')
    d2.texture = vor
    d2.strength = min(0.18, 0.5 / size)
    d2.texture_coords = 'GLOBAL'
    return rk.organic(o)


def column(name, base, height, radius, mat=None, flutes=20, broken=0.0, seed=0, lean=0.0,
           coll=None):
    """A fluted column with a base and a capital. `broken` is how much of the
    top is gone, as a fraction; a broken one has no capital and a jagged top."""
    rng = random.Random(seed)
    bm = bmesh.new()
    shaft_h = height * (1.0 - broken)
    # Base: plinth and torus.
    rk.lathe(bm, [(radius * 1.45, 0.0), (radius * 1.45, radius * 0.35), (radius * 1.3, radius * 0.4),
                  (radius * 1.32, radius * 0.55), (radius * 1.18, radius * 0.7), (radius * 1.05, radius * 0.75)], 32)
    # Shaft with entasis, fluted.
    prof = []
    n = 14
    top = shaft_h - (0.0 if broken else radius * 1.1)
    for i in range(n + 1):
        t = i / n
        r = radius * (1.0 - 0.12 * t + 0.03 * math.sin(math.pi * t))
        prof.append((r, radius * 0.75 + (top - radius * 0.75) * t))
    rk.lathe(bm, prof, flutes * 4,
             radial=lambda a: 1.0 - 0.045 * (1.0 - abs(math.cos(flutes * a * 0.5))) ** 0.5)
    if not broken:
        rk.lathe(bm, [(radius * 0.88, top), (radius * 1.0, top + radius * 0.15),
                      (radius * 1.25, top + radius * 0.5), (radius * 1.35, top + radius * 0.55)], 32)
        # Abacus.
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, top + radius * 0.8))
                              @ Matrix.Diagonal((radius * 2.9, radius * 2.9, radius * 0.5, 1.0)))
    o = rk.mesh_object(name, bm, mat or M["marble"], coll, smooth=True)
    if broken:
        # A jagged break: knock the top off with a noisy cutter.
        cut = rock(name + "_cut", (0.0, 0.0, shaft_h + radius * 1.6), radius * 2.2, seed + 7,
                   squash=(1.4, 1.4, 1.0))
        rk.apply_modifiers(cut)
        o.location = (0, 0, 0)
        rk.boolean(o, cut)
    o.location = base
    o.rotation_euler = (rng.uniform(-lean, lean), rng.uniform(-lean, lean), rng.uniform(0, TAU))
    return o


def arch_wall(name, origin, length, height, thick, bays, levels=1, mat=None, yaw=0.0,
              broken=0.0, seed=0, coll=None):
    """A wall pierced by round arches, `bays` across and `levels` high, like
    an aqueduct. Built as a block with arch-shaped holes cut through it."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, height * 0.5))
                          @ Matrix.Diagonal((length, thick, height, 1.0)))
    o = rk.mesh_object(name, bm, mat or M["sandstone"], coll, smooth=False)
    bay = length / bays
    lh = height / levels
    cutters = []
    for lv in range(levels):
        for b in range(bays):
            w = bay * 0.62
            x = -length * 0.5 + bay * (b + 0.5)
            z0 = lv * lh + lh * 0.08
            spring = z0 + lh * 0.82 - w * 0.5
            cb = bmesh.new()
            bmesh.ops.create_cube(cb, size=1.0, matrix=Matrix.Translation((x, 0, (z0 + spring) * 0.5))
                                  @ Matrix.Diagonal((w, thick * 3, spring - z0, 1.0)))
            bmesh.ops.create_cone(cb, cap_ends=True, segments=24, radius1=w * 0.5, radius2=w * 0.5,
                                  depth=thick * 3,
                                  matrix=Matrix.Translation((x, 0, spring)) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
            c = rk.mesh_object(name + "_c", cb, None, coll, smooth=False)
            cutters.append(c)
    cut = rk.join(cutters, name + "_cuts")
    rk.boolean(o, cut)
    # Cornices along each level.
    for lv in range(1, levels + 1):
        cb = bmesh.new()
        bmesh.ops.create_cube(cb, size=1.0, matrix=Matrix.Translation((0, 0, lv * lh - lh * 0.03))
                              @ Matrix.Diagonal((length * 1.01, thick * 1.25, lh * 0.06, 1.0)))
        c = rk.mesh_object(name + "_cornice", cb, mat or M["sandstone"], coll, smooth=False)
        o = rk.join([o, c], name)
    if broken:
        cut = rock(name + "_brk", (length * 0.5, 0, height), height * broken, seed + 3,
                   squash=(1.6, 2.0, 1.0))
        rk.apply_modifiers(cut)
        rk.boolean(o, cut)
    o.location = origin
    o.rotation_euler = (0, 0, yaw)
    return o


def domed_hall(name, center, radius, drum_h, mat=None, coll=None):
    """A round hall: a drum of tall arched windows lit from inside, a ribbed
    dome and a lantern."""
    cx, cy, cz = center
    parts = []
    # The drum.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=radius, radius2=radius,
                          depth=drum_h, matrix=Matrix.Translation((0, 0, drum_h * 0.5)))
    drum = rk.mesh_object(name + "_drum", bm, mat or M["marble"], coll, smooth=False)
    cutters = []
    nwin = 12
    for i in range(nwin):
        a = TAU * (i + 0.5) / nwin
        w = TAU * radius / nwin * 0.42
        h = drum_h * 0.62
        cb = bmesh.new()
        m = (Matrix.Rotation(a, 4, 'Z') @ Matrix.Translation((radius, 0, drum_h * 0.18)))
        bmesh.ops.create_cube(cb, size=1.0, matrix=m @ Matrix.Translation((0, 0, h * 0.5 - w * 0.25))
                              @ Matrix.Diagonal((radius * 0.5, w, h - w * 0.5, 1.0)))
        bmesh.ops.create_cone(cb, cap_ends=True, segments=16, radius1=w * 0.5, radius2=w * 0.5,
                              depth=radius * 0.5,
                              matrix=m @ Matrix.Translation((0, 0, h - w * 0.5)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
        cutters.append(rk.mesh_object(name + "_wc", cb, None, coll, smooth=False))
    rk.boolean(drum, rk.join(cutters, name + "_wcs"))
    parts.append(drum)
    # The lit room inside: a slightly smaller cylinder that glows.
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=radius * 0.8, radius2=radius * 0.8,
                          depth=drum_h * 0.95, matrix=Matrix.Translation((0, 0, drum_h * 0.5)))
    parts.append(rk.mesh_object(name + "_glow", bm, M["window"], coll))
    # Pilasters between the windows and cornices.
    for i in range(nwin):
        a = TAU * i / nwin
        cb = bmesh.new()
        bmesh.ops.create_cube(cb, size=1.0, matrix=Matrix.Rotation(a, 4, 'Z')
                              @ Matrix.Translation((radius + 0.15, 0, drum_h * 0.5))
                              @ Matrix.Diagonal((0.5, radius * 0.12, drum_h, 1.0)))
        parts.append(rk.mesh_object(name + "_pil", cb, mat or M["marble"], coll, smooth=False))
    bm = bmesh.new()
    rk.lathe(bm, [(radius * 1.02, drum_h - 0.4), (radius * 1.12, drum_h - 0.1), (radius * 1.12, drum_h + 0.4),
                  (radius * 0.98, drum_h + 0.6)], 48)
    rk.lathe(bm, [(radius * 1.1, 0.0), (radius * 1.1, 0.8), (radius * 1.02, 1.0)], 48)
    parts.append(rk.mesh_object(name + "_cornice", bm, mat or M["marble"], coll))
    # The dome, slightly pointed, with ribs.
    bm = bmesh.new()
    prof = []
    for i in range(17):
        t = i / 16
        a = t * math.pi * 0.5
        prof.append((radius * math.cos(a) * 0.98, drum_h + 0.6 + radius * 1.05 * math.sin(a)))
    prof[-1] = (0.0, prof[-1][1])
    rk.lathe(bm, prof, 64, cap_top=False, cap_bottom=False)
    parts.append(rk.mesh_object(name + "_dome", bm, M["dome"], coll))
    for i in range(16):
        a = TAU * i / 16
        rb = bmesh.new()
        pts = []
        for j in range(13):
            t = j / 12
            aa = t * math.pi * 0.5 * 0.96
            pts.append(Vector((radius * math.cos(aa) * 1.0, 0, drum_h + 0.6 + radius * 1.06 * math.sin(aa))))
        prev = None
        for j, p in enumerate(pts):
            ring = []
            for k in range(4):
                off = Vector(((k in (1, 2)) * 0.35, (k in (2, 3)) * 0.35 - 0.175, 0))
                ring.append(rb.verts.new(Matrix.Rotation(a, 4, 'Z') @ (p + off)))
            if prev:
                for k in range(4):
                    rb.faces.new((prev[k], prev[(k + 1) % 4], ring[(k + 1) % 4], ring[k]))
            prev = ring
        parts.append(rk.mesh_object(name + "_rib", rb, M["marble"], coll, smooth=False))
    # Lantern.
    bm = bmesh.new()
    lz = drum_h + 0.6 + radius * 1.05
    rk.lathe(bm, [(radius * 0.2, lz - 0.3), (radius * 0.2, lz + radius * 0.35), (radius * 0.24, lz + radius * 0.4),
                  (radius * 0.16, lz + radius * 0.55), (0.0, lz + radius * 0.75)], 24)
    parts.append(rk.mesh_object(name + "_lantern", bm, M["marble"], coll))
    hall = rk.join(parts, name)
    hall.location = center
    rk.light('POINT', name + "_lamp", (cx, cy, cz + drum_h * 0.5), 6000.0 * (radius / 8.0) ** 2,
             "#ffa04a", size=2.0, coll=coll)
    return hall


def ring_gate(name, center, radius, facing, coll=None):
    """The great ring: a broad stone hoop banded in bronze, spokes, and a
    glowing core."""
    parts = []
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=96, radius1=radius, radius2=radius, depth=radius * 0.18)
    bmesh.ops.create_cone(bm, cap_ends=False, segments=96, radius1=radius * 0.82, radius2=radius * 0.82,
                          depth=radius * 0.18)
    o = rk.mesh_object(name + "_band", bm, M["marble"], coll)
    s = o.modifiers.new("solid", 'SOLIDIFY')
    s.thickness = radius * 0.06
    parts.append(o)
    # The hoop itself as a torus.
    bm = bmesh.new()
    seg, sides = 96, 16
    rings = []
    for i in range(seg):
        a = TAU * i / seg
        ring = []
        for j in range(sides):
            b = TAU * j / sides
            r = radius * 0.91 + radius * 0.1 * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), radius * 0.13 * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        for j in range(sides):
            bm.faces.new((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % sides],
                          rings[i][(j + 1) % sides]))
    parts.append(rk.mesh_object(name + "_hoop", bm, M["dome"], coll))
    for i in range(8):
        a = TAU * i / 8
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Rotation(a, 4, 'Z')
                              @ Matrix.Translation((radius * 0.52, 0, 0))
                              @ Matrix.Diagonal((radius * 0.64, radius * 0.05, radius * 0.06, 1.0)))
        parts.append(rk.mesh_object(name + "_spoke", bm, M["dome"], coll, smooth=False))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=radius * 0.16)
    parts.append(rk.mesh_object(name + "_core", bm, M["core"], coll))
    # A second, inner hoop, and glowing marks round the band between them.
    bm = bmesh.new()
    seg, sides = 72, 10
    rings = []
    for i in range(seg):
        a = TAU * i / seg
        ring = []
        for j in range(sides):
            b = TAU * j / sides
            r = radius * 0.62 + radius * 0.04 * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), radius * 0.05 * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        for j in range(sides):
            bm.faces.new((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % sides],
                          rings[i][(j + 1) % sides]))
    parts.append(rk.mesh_object(name + "_inner", bm, M["dome"], coll))
    bm = bmesh.new()
    for i in range(24):
        a = TAU * i / 24
        bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Rotation(a, 4, 'Z')
                              @ Matrix.Translation((radius * 0.74, 0, radius * 0.02))
                              @ Matrix.Diagonal((radius * 0.07, radius * 0.025, radius * 0.06, 1.0)))
    parts.append(rk.mesh_object(name + "_runes", bm, M["core"], coll, smooth=False))
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=48, radius1=radius * 0.3, radius2=radius * 0.3,
                          depth=radius * 0.1)
    o = rk.mesh_object(name + "_collar", bm, M["gold"], coll)
    s = o.modifiers.new("solid", 'SOLIDIFY')
    s.thickness = radius * 0.05
    parts.append(o)
    g = rk.join(parts, name)
    g.location = center
    # Stand the ring on edge, facing `facing`.
    d = (Vector(facing) - Vector(center)).normalized()
    g.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    rk.light('POINT', name + "_glow", center, 25000.0, "#7fe8ff", size=radius * 0.15, coll=coll)
    return g


# ------------------------------------------------------------------ the sea

rk.water(SURFACE, FLOOR - 80.0, density=0.0105, scatter="#62c8f2", absorb="#56b4f0", anisotropy=0.72,
         top="#9fe6ff", horizon="#0a4486", bottom="#010814", sky_strength=1.0)

# The sun is high behind the city and shines toward the camera, so the shafts
# come down at us and fan out from above the top of the frame.
sun = rk.light('SUN', "Sun", (0, 0, SURFACE + 10), 38.0, "#eafcff", size=0.6)
rk.aim(sun, (sun.location.x - 0.06, sun.location.y - 0.42, sun.location.z - 1.0))

# The surface lets the light through in patches: that is what makes shafts.
# The camera never sees it; the sky's bright top stands in for it.
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=600.0)
surf = rk.mesh_object("Surface", bm, None, smooth=False)
surf.location = (0, 160, SURFACE + 1.0)
surf.visible_camera = False
mat, nt, out = rk._nodes("Surface")
tc = nt.nodes.new("ShaderNodeTexCoord")
mapping = nt.nodes.new("ShaderNodeMapping")
mapping.inputs["Scale"].default_value = (0.05, 0.05, 0.05)
nt.links.new(tc.outputs["Object"], mapping.inputs["Vector"])
vor = nt.nodes.new("ShaderNodeTexVoronoi")
vor.feature = 'SMOOTH_F1'
vor.inputs["Smoothness"].default_value = 0.8
nt.links.new(mapping.outputs[0], vor.inputs["Vector"])
holes = rk._ramp(nt, vor.outputs["Distance"], [(0.3, (1, 1, 1, 1)), (0.4, (0, 0, 0, 1))])
tr = nt.nodes.new("ShaderNodeBsdfTransparent")
dark = nt.nodes.new("ShaderNodeBsdfDiffuse")
dark.inputs["Color"].default_value = (0, 0, 0, 1)
mix = nt.nodes.new("ShaderNodeMixShader")
nt.links.new(holes.outputs["Color"], mix.inputs[0])
nt.links.new(dark.outputs[0], mix.inputs[1])
nt.links.new(tr.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], out.inputs["Surface"])
surf.data.materials.append(mat)

# ---------------------------------------------------------------- the deep

bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=60, y_segments=60, size=400.0)
floor = rk.mesh_object("Floor", bm, M["sand"], smooth=True)
floor.location = (0, 150, FLOOR)
rk.noise_displace(floor, 6.0, 25.0, kind='CLOUDS', levels=0)


def crag(name, top, radius, height, seed, mat=None, lean=(0.0, 0.0), squash=0.9):
    """A rock pillar whose top sits at `top`: a tall column of stone broken
    into blocks and ledges, for cliffs and outcrops."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    o = rk.mesh_object(name, bm, mat or M["cliff"])
    o.scale = (radius, radius * squash, height * 0.5)
    o.location = (top[0], top[1], top[2] - height * 0.5)
    o.rotation_euler = (lean[0], lean[1], rng.uniform(0, TAU))
    big = bpy.data.textures.new(name + "_big", 'CLOUDS')
    big.noise_scale = radius * 1.1
    big.noise_depth = 2
    d = o.modifiers.new("big", 'DISPLACE')
    d.texture, d.strength, d.texture_coords = big, 0.32, 'GLOBAL'
    sub = o.modifiers.new("sub", 'SUBSURF')
    sub.levels = sub.render_levels = 1
    # Blocks: Voronoi cells pushed out, so the rock breaks into facets.
    vor = bpy.data.textures.new(name + "_blocks", 'VORONOI')
    vor.noise_scale = radius * 0.45
    vor.distance_metric = 'DISTANCE_SQUARED'
    d = o.modifiers.new("blocks", 'DISPLACE')
    d.texture, d.strength, d.texture_coords = vor, -0.12, 'GLOBAL'
    # Strata: thin horizontal bands, the way sedimentary rock weathers.
    band = bpy.data.textures.new(name + "_strata", 'WOOD')
    band.wood_type = 'BANDNOISE'
    band.noise_scale = 0.6
    band.turbulence = 4.0
    d = o.modifiers.new("strata", 'DISPLACE')
    d.texture, d.strength, d.texture_coords = band, 0.02, 'GLOBAL'
    d.direction = 'NORMAL'
    return rk.organic(o)


def round_tower(name, base, radius, height, levels, seed, broken=0.25, lit_level=-1, mat=None):
    """A round tower with an arched window to each side on every storey and
    string courses between them, its top broken off."""
    rng = random.Random(seed)
    bm = bmesh.new()
    rk.lathe(bm, [(radius * 1.15, 0.0), (radius * 1.15, radius * 0.6), (radius, radius * 0.7),
                  (radius * 0.92, height)], 40)
    o = rk.mesh_object(name, bm, mat or M["sandstone"], smooth=False)
    lh = height / levels
    cutters = []
    for lv in range(levels):
        for k in range(4):
            a = TAU * k / 4 + lv * 0.4 + rng.uniform(-0.1, 0.1)
            w = radius * 0.5
            h = lh * 0.55
            z0 = lv * lh + lh * 0.2
            m = Matrix.Rotation(a, 4, 'Z') @ Matrix.Translation((radius, 0, 0))
            cb = bmesh.new()
            bmesh.ops.create_cube(cb, size=1.0, matrix=m @ Matrix.Translation((0, 0, z0 + (h - w * 0.5) * 0.5))
                                  @ Matrix.Diagonal((radius * 0.9, w, h - w * 0.5, 1.0)))
            bmesh.ops.create_cone(cb, cap_ends=True, segments=16, radius1=w * 0.5, radius2=w * 0.5,
                                  depth=radius * 0.9, matrix=m @ Matrix.Translation((0, 0, z0 + h - w * 0.5))
                                  @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
            cutters.append(rk.mesh_object(name + "_w", cb, None, smooth=False))
    rk.boolean(o, rk.join(cutters, name + "_ws"))
    cut = rock(name + "_brk", (radius * 0.6, 0, height * (1.0 - broken * 0.5)), radius * 1.8, seed + 1,
               squash=(1.2, 1.2, broken * height / radius))
    rk.apply_modifiers(cut)
    rk.boolean(o, cut)
    parts = [o]
    for lv in range(1, levels):
        if lv * lh > height * (1.0 - broken):
            break
        bm = bmesh.new()
        r = radius * (1.0 - 0.08 * lv / levels)
        rk.lathe(bm, [(r * 0.96, lv * lh - 0.3), (r * 1.06, lv * lh - 0.15), (r * 1.06, lv * lh + 0.2),
                      (r * 0.96, lv * lh + 0.3)], 40)
        parts.append(rk.mesh_object(name + "_course", bm, mat or M["sandstone"]))
    if lit_level >= 0:
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=24, radius1=radius * 0.75, radius2=radius * 0.75,
                              depth=lh * 0.7, matrix=Matrix.Translation((0, 0, lit_level * lh + lh * 0.5)))
        parts.append(rk.mesh_object(name + "_room", bm, M["window"]))
    o = rk.join(parts, name)
    o.location = base
    o.rotation_euler = (0, 0, rng.uniform(0, TAU))
    return o


# ------------------------------------------------------------- rock masses

# The statue's cliff: crags from the deep up to a ledge at his feet.
STATUE_H = 14.0
STATUE_AT = rk.place(-0.56, -0.06, 27.0)
crag("CliffMain", (STATUE_AT.x - 0.3, STATUE_AT.y + 0.8, STATUE_AT.z - 0.3), 4.2, STATUE_AT.z - FLOOR, 10)
crag("CliffB", (STATUE_AT.x - 8.0, STATUE_AT.y + 6.0, STATUE_AT.z - 2.0), 6.5, STATUE_AT.z - FLOOR, 11)
crag("CliffC", (STATUE_AT.x + 4.0, STATUE_AT.y + 3.0, STATUE_AT.z - 7.0), 3.4, 30.0, 12, lean=(0.0, 0.12))
crag("CliffD", (STATUE_AT.x - 3.5, STATUE_AT.y - 5.0, STATUE_AT.z - 8.0), 4.0, 30.0, 13)
crag("CliffE", (STATUE_AT.x - 14.0, STATUE_AT.y + 2.0, STATUE_AT.z + 6.0), 6.0, 50.0, 14)

# Foreground left: the ledge the clam sits on, running off the bottom.
LEDGE = rk.place(-0.6, -0.98, 8.5)
crag("Ledge0", (LEDGE.x, LEDGE.y, LEDGE.z - 0.3), 2.6, 14.0, 40, M["rock"], squash=1.1)
crag("Ledge1", (LEDGE.x - 2.8, LEDGE.y + 2.5, LEDGE.z + 1.4), 2.2, 16.0, 41, M["rock"])
crag("Ledge2", (LEDGE.x - 2.2, LEDGE.y + 6.5, LEDGE.z + 5.0), 2.6, 22.0, 42, M["rock"])

# Foreground right: coral rock in the corner.
CORNER = rk.place(0.88, -1.06, 8.0)
crag("Corner0", (CORNER.x, CORNER.y, CORNER.z - 0.3), 1.9, 12.0, 60, M["rock"], squash=1.1)
crag("Corner1", (CORNER.x + 1.9, CORNER.y + 2.2, CORNER.z + 1.8), 1.9, 14.0, 61, M["rock"])

# Right edge: a ruined tower, dark against the light, one storey still lit.
TOWER = rk.place(1.16, 0.0, 26.0)
crag("TowerRock", (TOWER.x + 0.5, TOWER.y + 0.5, TOWER.z - 12.0), 4.0, 30.0, 70)
round_tower("Tower", (TOWER.x, TOWER.y, TOWER.z - 12.5), 2.7, 48.0, 6, 71, broken=0.15, lit_level=3)
rk.light('POINT', "TowerLamp", (TOWER.x, TOWER.y, TOWER.z - 12.5 + 48.0 / 6 * 3.5), 1800.0, "#ffa04a", size=1.0)

# --------------------------------------------------------------- the city

HALL = rk.place(0.62, 0.16, 78.0)
city_base = HALL.z - 3.0
for i, (dx, dy, r) in enumerate([(0, 0, 13), (-16, 4, 10), (12, 10, 12), (-6, 16, 12)]):
    crag("Terrace%d" % i, (HALL.x + dx, HALL.y + dy, city_base - 0.5), r, city_base - FLOOR + 10, 80 + i)
domed_hall("Hall", (HALL.x, HALL.y, city_base), 9.0, 12.0)
arch_wall("Arcade0", (HALL.x - 9.0, HALL.y - 14.0, city_base - 14.0), 28.0, 22.0, 2.5, 6, levels=2,
          yaw=math.radians(-8), broken=0.3, seed=11)
arch_wall("Arcade1", (HALL.x + 8.0, HALL.y - 10.0, city_base - 20.0), 20.0, 18.0, 2.5, 4, levels=2,
          yaw=math.radians(15), seed=12)
arch_wall("Arcade2", (HALL.x - 24.0, HALL.y + 2.0, city_base - 8.0), 18.0, 14.0, 2.2, 4, levels=1,
          yaw=math.radians(-20), broken=0.4, seed=13)
SMALL = rk.place(0.45, -0.18, 58.0)
crag("SmallRock", (SMALL.x, SMALL.y, SMALL.z - 0.5), 6.0, SMALL.z - FLOOR, 90)
domed_hall("SmallHall", (SMALL.x, SMALL.y, SMALL.z), 4.0, 5.5)
round_tower("CityTower", rk.place(0.85, 0.0, 70.0) + Vector((0, 0, -20)), 3.0, 52.0, 7, 95, broken=0.1,
            lit_level=5)

# Columns climbing out of the chasm, middle of the frame.
for i, (sx, d, h, r, b) in enumerate([
        (-0.08, 40.0, 50.0, 1.4, 0.0), (0.1, 48.0, 46.0, 1.4, 0.25), (0.24, 44.0, 40.0, 1.3, 0.4),
        (-0.2, 62.0, 60.0, 1.8, 0.15), (0.02, 76.0, 66.0, 2.0, 0.3), (0.3, 96.0, 74.0, 2.0, 0.0),
        (-0.3, 110.0, 64.0, 2.2, 0.35), (0.12, 120.0, 80.0, 2.4, 0.1)]):
    p = rk.place(sx, 0.0, d)
    column("Column%d" % i, (p.x, p.y, FLOOR - 2.0), h, r, broken=b, seed=100 + i, lean=0.03)

# A bridge of arches across the chasm, between the statue's cliff and the
# city, its middle span fallen.
BRIDGE = rk.place(0.0, -0.08, 52.0)
arch_wall("BridgeL", (BRIDGE.x - 13.0, BRIDGE.y + 2.0, FLOOR - 2.0), 22.0, BRIDGE.z - FLOOR + 2.0, 3.0, 4,
          levels=3, yaw=math.radians(-12), broken=0.12, seed=170)
arch_wall("BridgeR", (BRIDGE.x + 12.0, BRIDGE.y - 2.0, FLOOR - 2.0), 18.0, BRIDGE.z - FLOOR - 1.0, 3.0, 3,
          levels=3, yaw=math.radians(-12), broken=0.25, seed=171)
for i, (dx, dy, dz, s_) in enumerate([(-1.0, 1.0, -12.0, 2.2), (2.5, -1.0, -16.0, 1.8), (0.5, 3.0, -20.0, 2.6)]):
    rock("Rubble%d" % i, (BRIDGE.x + dx, BRIDGE.y + dy, BRIDGE.z + dz), s_, 175 + i, M["sandstone"],
         squash=(1.6, 1.0, 0.7), detail=0.5)
# More columns and walls at mid-depths, so the chasm is a city and not a hole.
for i, (sx, d, h, r, b) in enumerate([(-0.32, 58.0, 44.0, 1.5, 0.3), (0.38, 66.0, 50.0, 1.6, 0.2),
                                      (-0.12, 92.0, 70.0, 2.0, 0.4), (0.48, 104.0, 76.0, 2.2, 0.15),
                                      (-0.45, 125.0, 72.0, 2.4, 0.0)]):
    p = rk.place(sx, 0.0, d)
    column("MidColumn%d" % i, (p.x, p.y, FLOOR - 2.0), h, r, broken=b, seed=180 + i, lean=0.04)
arch_wall("MidWall0", rk.place(-0.15, 0.0, 88.0) + Vector((0, 0, -20)), 30.0, 36.0, 3.5, 5, levels=3,
          yaw=math.radians(10), broken=0.35, seed=190)
arch_wall("MidWall1", rk.place(0.2, 0.0, 115.0) + Vector((0, 0, -26)), 36.0, 44.0, 4.0, 6, levels=3,
          yaw=math.radians(-6), broken=0.2, seed=191)

# The ring over the city, on a tower of its own.
RING = rk.place(0.28, 0.86, 82.0)
ring_gate("Ring", RING, 8.5, CAM.location)
column("RingTower", (RING.x, RING.y + 1.5, FLOOR), RING.z - FLOOR - 9.0, 2.6, seed=140)

# A broken temple front high on the left, behind the statue.
TEMPLE = rk.place(-0.55, 1.08, 80.0)
for i in range(4):
    column("TempleCol%d" % i, (TEMPLE.x - 9 + i * 6.0, TEMPLE.y, TEMPLE.z - 22.0), 20.0, 1.2,
           broken=(0.0, 0.0, 0.3, 0.5)[i], seed=150 + i)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((16, 3.5, 3.0, 1)))
lintel = rk.mesh_object("TempleLintel", bm, M["marble"], smooth=False)
lintel.location = (TEMPLE.x - 4.0, TEMPLE.y, TEMPLE.z - 0.5)
lintel.rotation_euler = (0, math.radians(-6), 0)
crag("TempleRock", (TEMPLE.x, TEMPLE.y + 2, TEMPLE.z - 22.5), 15.0, 40.0, 160, squash=0.7)

# Far away: towers and columns going into the murk.
rng = random.Random(7)
for i in range(16):
    d = rng.uniform(140, 260)
    sx = rng.uniform(-1.4, 1.4)
    p = rk.place(sx, 0.0, d)
    if rng.random() < 0.6:
        column("Far%d" % i, (p.x, p.y, FLOOR - 4), rng.uniform(50, 120), rng.uniform(2.0, 4.0),
               broken=rng.choice([0.0, 0.2, 0.4]), seed=200 + i)
    else:
        arch_wall("FarWall%d" % i, (p.x, p.y, FLOOR - 4), rng.uniform(20, 40), rng.uniform(40, 70), 4.0,
                  rng.randint(2, 4), levels=rng.randint(2, 3), yaw=rng.uniform(-0.5, 0.5),
                  broken=rng.uniform(0.0, 0.4), seed=220 + i)

# --------------------------------------------------------------- figures

def mpfb():
    import addon_utils
    addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
    from bl_ext.user_default.mpfb.services.humanservice import HumanService
    from bl_ext.user_default.mpfb.services.targetservice import TargetService
    return HumanService, TargetService


def human(macro, mat):
    """An MPFB body with its rig, the shape keys baked and the helper
    geometry gone."""
    HumanService, TargetService = mpfb()
    body = HumanService.create_human(macro_detail_dict=macro, scale=0.1)
    rig = HumanService.add_builtin_rig(body, "game_engine")
    TargetService.bake_targets(body)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier="Hide helpers")
    body.data.materials.clear()
    body.data.materials.append(mat)
    for p in body.data.polygons:
        p.use_smooth = True
    return body, rig


def point_bone(rig, name, direction):
    """Turn a pose bone so it points along `direction`, given in the rig's own
    frame (x his left, -y his front, z up), keeping its head where it is."""
    bpy.context.view_layer.update()
    pb = rig.pose.bones[name]
    mw = rig.matrix_world
    head = mw @ pb.head
    cur = (mw @ pb.tail) - head
    want = mw.to_3x3() @ Vector(direction)
    q = cur.normalized().rotation_difference(want.normalized())
    new = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ (mw @ pb.matrix)
    pb.matrix = mw.inverted() @ new
    bpy.context.view_layer.update()


def bone_head(rig, name):
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[name].head


def bone_tail(rig, name):
    bpy.context.view_layer.update()
    return rig.matrix_world @ rig.pose.bones[name].tail


def face_point(body, head_a, head_b, fwd):
    """The tip of the nose, near enough: of the posed body's vertices close
    round the head, the one furthest forward. Close round the head, because
    a hand held up beside it is at the same height and further out."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    mw = body.matrix_world
    axis = (head_b - head_a)
    hl = axis.length
    axis.normalize()
    best, best_d = None, -1e9
    for v in me.vertices:
        p = mw @ v.co
        t = (p - head_a).dot(axis)
        if not (0.2 * hl < t < 0.7 * hl):
            continue
        off = (p - head_a) - axis * t
        if off.length > hl * 0.9:
            continue
        if off.dot(fwd) > best_d:
            best, best_d = p, off.dot(fwd)
    ev.to_mesh_clear()
    return best


def lump(name, center, size, mat, seed, squash=(1, 1, 1), curls=0.0, rot=(0, 0, 0)):
    """A displaced ball: a beard, a head of hair, a cushion of moss."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    o = rk.mesh_object(name, bm, mat)
    o.location = center
    o.scale = (size * squash[0], size * squash[1], size * squash[2])
    o.rotation_euler = rot
    if curls:
        t = bpy.data.textures.new(name + "_curls", 'STUCCI')
        t.noise_scale = curls
        t.stucci_type = 'WALL_OUT'
        d = o.modifiers.new("curls", 'DISPLACE')
        d.texture, d.strength, d.texture_coords = t, 0.18, 'OBJECT'
    return rk.organic(o)


def robe(name, top_center, bottom_z, r_top, r_bottom, mat, seed, facing=0.0):
    """Drapery from the waist to the rock: a skirt in deep pleats that open
    toward the hem, a rolled belt over the waist, and a hem that spreads over
    the stone it stands on."""
    rng = random.Random(seed)
    bm = bmesh.new()
    seg, n = 160, 40
    h = top_center.z - bottom_z
    pleats = [(rng.uniform(0, TAU), rng.uniform(0.7, 1.3)) for _ in range(26)]
    rings = []
    for i in range(n + 1):
        t = i / n
        z = top_center.z - h * t
        r = r_top + (r_bottom - r_top) * (t ** 1.5)
        ring = []
        for j in range(seg):
            a = TAU * j / seg
            # Pleats: ridges with sharp valleys, deeper and broader lower down,
            # each starting at its own height, as cloth that hangs from a belt.
            fold = 0.0
            for k, (ph, depth) in enumerate(pleats):
                start = 0.08 + 0.4 * ((k * 0.37) % 1.0)
                open_ = max(0.0, (t - start) / (1.0 - start))
                fold += depth * open_ * (1.0 - abs(math.sin(0.5 * (13 * a + ph + k * 0.9)))) ** 3 * 0.07
            fold -= 0.035 * t
            roll = 0.1 * math.exp(-((t - 0.035) / 0.025) ** 2)
            hem = 0.18 * max(0.0, (t - 0.9) / 0.1) ** 2 * (0.7 + 0.3 * math.sin(5 * a + 1.3))
            rr = r * (1.0 + fold + roll + hem)
            zz = z - (0.4 * hem * r if t > 0.9 else 0.0)
            ring.append(bm.verts.new((top_center.x + rr * math.cos(a + facing),
                                      top_center.y + rr * math.sin(a + facing), zz)))
        rings.append(ring)
    for ra, rb in zip(rings, rings[1:]):
        for j in range(seg):
            bm.faces.new((ra[j], ra[(j + 1) % seg], rb[(j + 1) % seg], rb[j]))
    o = rk.mesh_object(name, bm, mat)
    sub = o.modifiers.new("sub", 'SUBSURF')
    sub.levels = sub.render_levels = 1
    return rk.organic(o)


def crown(name, center, radius, mat, up=(0, 0, 1)):
    bm = bmesh.new()
    rk.lathe(bm, [(radius, -radius * 0.15), (radius * 1.05, 0.0), (radius * 1.05, radius * 0.25),
                  (radius * 1.12, radius * 0.32)], 48, cap_top=False, cap_bottom=False)
    for k in range(9):
        a = TAU * k / 9
        tall = radius * (0.85 if k % 2 == 0 else 0.55)
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=radius * 0.16, radius2=0.0, depth=tall,
                              matrix=Matrix.Translation((radius * 1.05 * math.cos(a), radius * 1.05 * math.sin(a),
                                                         radius * 0.3 + tall * 0.5))
                              @ Matrix.Rotation(0.18, 4, Vector((-math.sin(a), math.cos(a), 0))))
    o = rk.mesh_object(name, bm, mat)
    s = o.modifiers.new("solid", 'SOLIDIFY')
    s.thickness = radius * 0.06
    o.location = center
    o.rotation_euler = Vector(up).to_track_quat('Z', 'Y').to_euler()
    return o


def trident(grip, length):
    """A gold trident stood upright through `grip`."""
    parts = []
    bottom = grip.z - length * 0.42
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.16, radius2=0.14, depth=length,
                          matrix=Matrix.Translation((0, 0, length * 0.5)))
    # Bands down the shaft.
    for z in (0.62, 0.66, 0.9):
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.22, radius2=0.22, depth=0.25,
                              matrix=Matrix.Translation((0, 0, length * z)))
    parts.append(rk.mesh_object("TridentShaft", bm, M["gold"]))
    top = length
    for x in (-1.0, 0.0, 1.0):
        bm = bmesh.new()
        tine = 3.0 if x == 0 else 2.4
        bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.13, radius2=0.01, depth=tine,
                              matrix=Matrix.Translation((x * 0.95, 0, top + 0.7 + tine * 0.5)))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.18, radius2=0.0, depth=0.8,
                              matrix=Matrix.Translation((x * 0.95 + 0.17, 0, top + 0.7 + tine * 0.62))
                              @ Matrix.Rotation(math.radians(200), 4, 'Y'))
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.18, radius2=0.0, depth=0.8,
                              matrix=Matrix.Translation((x * 0.95 - 0.17, 0, top + 0.7 + tine * 0.62))
                              @ Matrix.Rotation(math.radians(160), 4, 'Y'))
        parts.append(rk.mesh_object("Tine", bm, M["gold"]))
    bm = bmesh.new()
    # The crosspiece curves up at the ends, like a crescent.
    prev = None
    for j in range(13):
        t = j / 12 * 2 - 1
        c = Vector((t * 1.05, 0, top + 0.45 + 0.35 * t * t))
        ring = [bm.verts.new(c + Vector((0, math.cos(TAU * k / 8) * 0.14, math.sin(TAU * k / 8) * 0.2)))
                for k in range(8)]
        if prev:
            for k in range(8):
                bm.faces.new((prev[k], prev[(k + 1) % 8], ring[(k + 1) % 8], ring[k]))
        prev = ring
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.32, radius2=0.18, depth=0.9,
                          matrix=Matrix.Translation((0, 0, top)))
    parts.append(rk.mesh_object("TridentHead", bm, M["gold"]))
    t = rk.join(parts, "Trident")
    t.location = (grip.x, grip.y, bottom)
    return t


def statue():
    """The sea king: an MPFB body, heroic, in weathered bronze, robed from the
    waist, crowned and bearded, holding his trident up in his left hand."""
    body, rig = human({"gender": 1.0, "age": 0.65, "muscle": 1.0, "weight": 0.62, "proportions": 1.0,
                       "height": 0.8, "cupsize": 0.5, "firmness": 0.5,
                       "race": {"asian": 0.15, "caucasian": 0.6, "african": 0.25}}, M["bronze"])
    k = STATUE_H / body.dimensions.z
    rk.organic(body)
    sub = body.modifiers.new("sub", 'SUBSURF')
    sub.levels = sub.render_levels = 1
    rig.scale = (k, k, k)
    rig.location = STATUE_AT
    yaw = math.radians(18)
    rig.rotation_euler = (0, 0, yaw)
    # His right arm (our left) hangs a little back; his left is out to the
    # side with the forearm up, gripping the trident.
    point_bone(rig, "upperarm_r", (-0.28, 0.12, -1.0))
    point_bone(rig, "lowerarm_r", (-0.12, 0.3, -1.0))
    point_bone(rig, "upperarm_l", (1.0, -0.3, -0.18))
    point_bone(rig, "lowerarm_l", (0.15, -0.25, 1.0))
    point_bone(rig, "hand_l", (0.05, -0.2, 1.0))
    point_bone(rig, "neck_01", (0.06, -0.12, 1.0))
    point_bone(rig, "head", (0.15, -0.28, 1.0))
    point_bone(rig, "thigh_l", (0.12, -0.05, -1.0))
    point_bone(rig, "thigh_r", (-0.08, 0.1, -1.0))
    hips = bone_head(rig, "pelvis")
    robe("Robe", hips + Vector((0, 0, 0.12 * k)), STATUE_AT.z - 1.5, 0.19 * k, 0.36 * k, M["bronze"], 300, yaw)
    head_a, head_b = bone_head(rig, "head"), bone_tail(rig, "head")
    up = (head_b - head_a).normalized()
    face = face_point(body, head_a, head_b, Matrix.Rotation(yaw, 3, 'Z') @ Vector((0, -1, 0)))
    fwd = face - head_a.lerp(head_b, 0.45)
    fwd = (fwd - up * fwd.dot(up)).normalized()
    hl = (head_b - head_a).length
    crown("Crown", head_b - up * hl * 0.18 - fwd * 0.01 * k, 0.12 * k, M["gold"], up)
    lump("Hair", head_b - up * hl * 0.3 - fwd * 0.03 * k, 0.118 * k, M["bronze"], 301,
         squash=(1.0, 1.05, 0.85), curls=0.06 * k)
    lump("Beard", face - up * 0.075 * k - fwd * 0.03 * k, 0.07 * k, M["bronze"], 302,
         squash=(1.05, 0.8, 1.3), curls=0.045 * k)
    trident(bone_head(rig, "hand_l"), STATUE_H * 1.35)
    # A gold edge from behind, the light off the city catching his outline;
    # a warm key from his left so his face and chest read, and a cool fill
    # from the water on his right.
    rim = rk.light('AREA', "StatueRim", STATUE_AT + Vector((5.0, 9.0, 12.0)), 6000.0, "#ffd08a", size=5.0)
    rk.aim(rim, STATUE_AT + Vector((0, 0, STATUE_H * 0.55)))
    key = rk.light('AREA', "StatueKey", STATUE_AT + Vector((9.0, -9.0, 14.0)), 2800.0, "#ffd9a0", size=6.0)
    rk.aim(key, STATUE_AT + Vector((0, 0, STATUE_H * 0.6)))
    fill = rk.light('AREA', "StatueFill", STATUE_AT + Vector((-8.0, -12.0, 6.0)), 1500.0, "#9fe0ff", size=8.0)
    rk.aim(fill, STATUE_AT + Vector((0, 0, STATUE_H * 0.5)))
    return body, rig


statue()


def tail_mesh(name, path, radii, fin_width, mat, fin_mat):
    """The merman's tail: a loft along `path` with UVs (u round, v along) for
    the scales, ending in a two-lobed fin."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    sides = 24
    rings = []
    prev_n = None
    frames = []
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if prev_n is None:
            n = t.cross(Vector((0, 0, 1))).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n)
        frames.append((t, n, b))
        ring = []
        for k in range(sides + 1):
            a = TAU * k / sides
            # Wider side to side than front to back.
            ring.append(bm.verts.new(p + (n * math.cos(a) * 1.15 + b * math.sin(a) * 0.9) * radii[i]))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            f = bm.faces.new((rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]))
            for lp, (u, v) in zip(f.loops, ((k / sides, i), ((k + 1) / sides, i), ((k + 1) / sides, i + 1),
                                            (k / sides, i + 1))):
                lp[uv].uv = (u, v / (len(rings) - 1))
    o = rk.mesh_object(name, bm, mat)
    # The fin: a broad, thin membrane, two lobes with a notch between.
    t, n, b = frames[-1]
    root = path[-1]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    nu, nv = 24, 14
    grid = []
    for i in range(nu + 1):
        u = i / nu * 2.0 - 1.0
        row = []
        for j in range(nv + 1):
            v = j / nv
            lobe = 1.0 - 0.32 * math.exp(-(u / 0.22) ** 2)          # the notch in the middle
            reach = fin_width * (0.25 + 0.85 * lobe * (0.4 + 0.6 * abs(u) ** 0.7)) * v
            spread = fin_width * 0.6 * u * (0.25 + v * 0.9)
            wave = 0.05 * fin_width * math.sin(u * 6.0 + v * 3.0)
            row.append(bm.verts.new(root + t * reach + n * spread + b * wave))
        grid.append(row)
    for i in range(nu):
        for j in range(nv):
            f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
            for lp, (uu, vv) in zip(f.loops, ((i / nu, j / nv), ((i + 1) / nu, j / nv),
                                              ((i + 1) / nu, (j + 1) / nv), (i / nu, (j + 1) / nv))):
                lp[uv].uv = (uu, vv)
    fin = rk.mesh_object(name + "Fin", bm, fin_mat)
    s = fin.modifiers.new("solid", 'SOLIDIFY')
    s.thickness = 0.01
    return o, fin


def scale_material(name="Scales"):
    """Fish scales: overlapping cells in the tail's UVs, blue-green with a
    film's sheen, darker down the spine."""
    m, nt, out = rk._nodes(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (22.0, 40.0, 1.0)
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 1.0
    vor.inputs["Randomness"].default_value = 0.15
    nt.links.new(mp.outputs[0], vor.inputs["Vector"])
    edge = rk._ramp(nt, vor.outputs["Distance"], [(0.0, (1, 1, 1, 1)), (0.48, (0.25, 0.25, 0.25, 1))])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["UV"], sep.inputs[0])
    along = rk._ramp(nt, sep.outputs["Y"], [(0.0, rk.srgb("#1a3a6a")), (0.6, rk.srgb("#1f7a9a")),
                                            (1.0, rk.srgb("#3ab0b0"))])
    col = rk._mix(nt, 0.55, along.outputs["Color"], edge.outputs["Color"], 'MULTIPLY')
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.55
    bsdf.inputs["Roughness"].default_value = 0.3
    bsdf.inputs["Thin Film Thickness"].default_value = 380.0
    bsdf.inputs["Thin Film IOR"].default_value = 1.5
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = 0.5
    nt.links.new(edge.outputs["Color"], b.inputs["Height"])
    nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    rk.MATS[name] = m
    return m


def fin_material(name="Fin"):
    """A fin: translucent membrane with darker rays fanning along it."""
    m, nt, out = rk._nodes(name)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["UV"], sep.inputs[0])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'X'
    wave.inputs["Scale"].default_value = 18.0
    nt.links.new(tc.outputs["UV"], wave.inputs["Vector"])
    rays = rk._ramp(nt, wave.outputs["Fac"], [(0.0, rk.srgb("#1c5a86")), (0.5, rk.srgb("#5ad2e8"))])
    tip = rk._ramp(nt, sep.outputs["Y"], [(0.0, (1, 1, 1, 1)), (1.0, rk.srgb("#9ff0ff"))])
    col = rk._mix(nt, 1.0, rays.outputs["Color"], tip.outputs["Color"], 'MULTIPLY')
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Transmission Weight"].default_value = 0.6
    nt.links.new(rk._math(nt, 'MULTIPLY_ADD', sep.outputs["Y"], -0.35, 0.9), bsdf.inputs["Alpha"])
    tl = nt.nodes.new("ShaderNodeBsdfTranslucent")
    nt.links.new(col, tl.inputs["Color"])
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.4
    nt.links.new(bsdf.outputs[0], mix.inputs[1])
    nt.links.new(tl.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    rk.MATS[name] = m
    return m


MERMAN_HEAD = rk.place(0.2, -0.02, 4.9)
MERMAN_PARTS = []
MERMAN_ANCHORS = {}


def merman():
    """Seen from behind, swimming up toward the statue: right arm reaching,
    left arm out, the tail trailing down to the right into a broad fin."""
    skin = rk.plain("Skin", "#6a412c", rough=0.42, sss=0.12, sss_radius=(1.0, 0.35, 0.2), coat=0.25,
                    bump_scale=60.0, bump=0.08)
    body, rig = human({"gender": 1.0, "age": 0.42, "muscle": 0.95, "weight": 0.5, "proportions": 0.95,
                       "height": 0.85, "cupsize": 0.5, "firmness": 0.5,
                       "race": {"asian": 0.05, "caucasian": 0.25, "african": 0.7}}, skin)
    # No legs: drop everything below the hips that is not a hand.
    hip_z = (rig.matrix_world @ rig.data.bones["thigh_l"].head_local).z
    bm = bmesh.new()
    bm.from_mesh(body.data)
    gone = [v for v in bm.verts if v.co.z < hip_z - 0.04 and abs(v.co.x) < 0.3]
    bmesh.ops.delete(bm, geom=gone, context='VERTS')
    bm.to_mesh(body.data)
    bm.free()
    point_bone(rig, "spine_02", (0.0, -0.1, 1.0))
    # His left arm (our left, as he faces away) reaches up toward the statue;
    # his right is out and down, steering.
    point_bone(rig, "upperarm_l", (0.12, -0.3, 1.0))
    point_bone(rig, "lowerarm_l", (0.02, -0.4, 1.0))
    point_bone(rig, "hand_l", (0.0, -0.45, 1.0))
    point_bone(rig, "upperarm_r", (-0.85, 0.15, -0.8))
    point_bone(rig, "lowerarm_r", (-0.6, -0.1, -0.9))
    point_bone(rig, "head", (0.12, -0.5, 1.0))
    # Facing away, pitched forward into a climb and rolled toward the statue.
    rig.rotation_euler = (0, 0, 0)
    rig.matrix_world = (Matrix.Rotation(math.radians(-6), 4, 'Z') @ Matrix.Rotation(math.radians(-20), 4, 'Y')
                        @ Matrix.Rotation(math.radians(-30), 4, 'X') @ Matrix.Rotation(math.pi, 4, 'Z'))
    bpy.context.view_layer.update()
    head = bone_head(rig, "head")
    rig.location = rig.location + (MERMAN_HEAD - head)
    bpy.context.view_layer.update()
    # Tail from the hips, down the line of the body and curling out to the
    # right toward us.
    pelvis = bone_head(rig, "pelvis")
    up = (bone_head(rig, "spine_03") - pelvis).normalized()
    right = Vector((1, 0, 0))
    back = up.cross(right).normalized()
    path, radii = [], []
    for i in range(17):
        t = i / 16
        p = (pelvis + up * 0.12 - up * 1.25 * t + right * 0.35 * t ** 1.8 + back * 0.45 * t ** 2
             + right * 0.06 * math.sin(t * math.pi * 2.0))
        path.append(p)
        # Full through the hips and thigh, then a long taper to the fin.
        radii.append(0.19 * (1.0 - 0.8 * t ** 1.6) + 0.014)
    tail, fin = tail_mesh("Tail", path, radii, 1.1, scale_material(), fin_material())
    # A belt of shells and beads over the seam.
    bm = bmesh.new()
    seg = 28
    for k in range(seg):
        a = TAU * k / seg
        n0 = right * math.cos(a) * 1.18 + back * math.sin(a) * 0.95
        c = pelvis + up * 0.1 + n0 * 0.165
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.028 + 0.012 * (k % 3 == 0),
                                   matrix=Matrix.Translation(c))
    belt = rk.mesh_object("Belt", bm, M["gold"])
    # Bands on his arms.
    for side in ("l", "r"):
        a, b2 = bone_head(rig, "upperarm_" + side), bone_tail(rig, "upperarm_" + side)
        c = a.lerp(b2, 0.55)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=0.055, radius2=0.052, depth=0.05)
        o = rk.mesh_object("Armband_" + side, bm, M["gold"])
        o.location = c
        o.rotation_euler = (b2 - a).to_track_quat('Z', 'Y').to_euler()
        s = o.modifiers.new("solid", 'SOLIDIFY')
        s.thickness = 0.012
    a, b2 = bone_head(rig, "head"), bone_tail(rig, "head")
    hair = rk.plain("Hair", "#1a120e", rough=0.6, bump_scale=120.0, bump=0.3)
    lump("MerHair", b2 - (b2 - a) * 0.38, 0.115, hair, 401, squash=(1.0, 1.1, 0.95), curls=0.035)
    body.name = "Merman"
    MERMAN_PARTS.extend([body, tail, fin, belt, bpy.data.objects["Armband_l"], bpy.data.objects["Armband_r"],
                         bpy.data.objects["MerHair"]])
    MERMAN_ANCHORS.update({"hip": pelvis.copy(), "fin": path[-1].copy(), "mid": path[8].copy(),
                           "shoulder": bone_head(rig, "upperarm_l"), "hand": bone_tail(rig, "hand_l")})
    # Light on his back from the shafts overhead, and a warm edge from the
    # hall's windows on the far side.
    key = rk.light('AREA', "MerKey", MERMAN_HEAD + Vector((-0.5, -2.5, 4.0)), 500.0, "#dff6ff", size=3.0)
    rk.aim(key, MERMAN_HEAD + Vector((0.3, 0.2, -0.8)))
    rim = rk.light('AREA', "MerRim", MERMAN_HEAD + Vector((2.0, 3.0, 0.5)), 250.0, "#ffc890", size=2.0)
    rk.aim(rim, MERMAN_HEAD + Vector((0.3, 0.0, -0.8)))
    return body, rig


merman()

# ------------------------------------------------------------------ the reef

REEF = rf.materials()
KELP = rf.leaf_material(color="#62702a", back="#a8a848", dark="#3a3e14")
SHELL = rf.shell_material()
WEED = rf.leaf_material("Weed", color="#4a5426", back="#7a7c34", dark="#262a10")
PEARL = rk.plain("Pearl", "#fff4ec", rough=0.15, emit="#fff0dc", emit_strength=10.0)

ledge_top = LEDGE + Vector((0.4, 0.4, -0.15))
rf.scallop("Clam", ledge_top + Vector((0, 0, 0.1)), 1.15, 500, SHELL, open_deg=68, yaw=math.radians(180))
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=0.17)
pearl = rk.mesh_object("Pearl", bm, PEARL)
pearl.location = ledge_top + Vector((0.05, -0.5, -0.02))
rk.light('POINT', "PearlGlow", pearl.location + Vector((0, -0.25, 0.25)), 160.0, "#ffe8d0", size=0.15)

PINK, RED, ORANGE, PURPLE, MAGENTA, YELLOW = ((0.9, 0.25, 0.4), (0.8, 0.12, 0.1), (0.95, 0.45, 0.12),
                                            (0.45, 0.15, 0.7), (0.85, 0.15, 0.6), (0.9, 0.75, 0.2))
GREEN, OCHRE, BLUE = (0.45, 0.7, 0.3), (0.62, 0.48, 0.24), (0.3, 0.55, 0.85)


def coral(kind, name, p, size, rgb, seed):
    """One named piece of the reef, `size` metres across or so."""
    rng = random.Random(seed)
    if kind == "stag":
        return rf.staghorn(name, p, size, rgb, seed, REEF["stony"])
    if kind == "fan":
        return rf.sea_fan(name, p, size, rgb, seed, REEF, facing=math.radians(rng.uniform(-30, 30)))
    if kind == "brain":
        return rf.brain_coral(name, p, size, rgb, seed, REEF["brain"])
    if kind == "anemone":
        return rf.anemone(name, p, size * 0.6, rgb, seed, REEF["soft"], tip_rgb=rng.choice((PINK, YELLOW, None)))
    if kind == "zoa":
        return rf.zoanthids(name, p, size * 0.8, rgb, seed, REEF["soft"], count=70, center_rgb=GREEN)
    return rf.grow(kind, name, p, size, rgb, seed, REEF)


reef = [
    # The ledge in front, left, round the clam.
    ("stag", rk.place(-0.82, -0.82, 8.0), 1.4, PINK), ("anemone", rk.place(-0.35, -1.05, 7.4), 0.9, GREEN),
    ("fan", rk.place(-0.95, -0.55, 9.5), 2.2, PURPLE), ("brain", rk.place(-0.28, -1.22, 7.2), 0.6, ORANGE),
    ("zoa", rk.place(-0.7, -1.18, 7.2), 0.9, MAGENTA), ("dusters", rk.place(-0.98, -0.95, 8.0), 0.8, YELLOW),
    ("urchins", rk.place(-0.5, -1.12, 7.3), 0.7, PURPLE), ("table", rk.place(-1.05, -0.72, 9.0), 1.0, OCHRE),
    # The rock in the right-hand corner.
    ("stag", rk.place(0.8, -0.95, 7.8), 1.2, MAGENTA), ("fan", rk.place(0.98, -0.75, 8.6), 1.8, RED),
    ("brain", rk.place(0.95, -1.15, 7.6), 0.6, PURPLE), ("anemone", rk.place(0.75, -1.15, 7.5), 0.7, PINK),
    ("tubes", rk.place(1.05, -1.0, 8.2), 0.9, BLUE), ("dusters", rk.place(0.68, -1.05, 7.6), 0.6, RED),
    # Down the statue's cliff.
    ("stag", rk.place(-0.42, -0.18, 26.0), 2.5, ORANGE), ("fan", rk.place(-0.7, -0.15, 27.0), 3.5, PURPLE),
    ("stag", rk.place(-0.78, -0.3, 22.0), 2.2, PINK), ("anemone", rk.place(-0.5, -0.22, 25.0), 2.0, MAGENTA),
    ("brain", rk.place(-0.66, -0.2, 28.0), 1.6, ORANGE), ("stag", rk.place(-0.9, -0.3, 30.0), 3.0, RED),
    ("zoa", rk.place(-0.82, -0.42, 24.0), 2.2, YELLOW), ("fan", rk.place(-0.35, -0.35, 23.0), 2.6, MAGENTA),
    ("table", rk.place(-0.6, -0.55, 20.0), 2.0, OCHRE), ("soft", rk.place(-0.98, -0.12, 30.0), 2.4, PINK),
    ("barrel", rk.place(-0.55, -0.4, 24.0), 1.6, ORANGE), ("whips", rk.place(-0.3, -0.28, 24.5), 2.4, YELLOW),
    # Out on the right, under the tower.
    ("stag", rk.place(0.62, -0.42, 52.0), 3.0, PINK), ("fan", rk.place(0.74, -0.38, 56.0), 4.0, PURPLE),
    # Grown up round the statue's feet over the centuries.
    ("brain", STATUE_AT + Vector((2.2, -1.5, -0.6)), 1.0, ORANGE), ("anemone", STATUE_AT + Vector((-2.0, -1.8, -0.5)), 1.4, YELLOW),
    ("stag", STATUE_AT + Vector((2.6, -0.6, -0.8)), 1.8, RED), ("fan", STATUE_AT + Vector((-2.8, -0.2, -0.5)), 2.4, MAGENTA),
    ("zoa", STATUE_AT + Vector((0.8, -2.4, -0.7)), 1.2, PINK), ("dusters", STATUE_AT + Vector((-1.2, -2.6, -0.6)), 1.4, RED),
    ("tubes", STATUE_AT + Vector((3.0, 0.8, -0.6)), 1.6, PURPLE),
]
for i, (kind, p, size, col) in enumerate(reef):
    coral(kind, "Coral%d" % i, p, size, col, 600 + i)

# A reef grown over every rock the camera can see the top of, and over the
# tops of the ruins.
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
rocks = [o for o in meshes if o.name.startswith(("Cliff", "Ledge", "Corner", "TowerRock", "Terrace", "SmallRock"))]
ruins = [o for o in meshes if o.name.startswith(("Arcade", "Hall", "SmallHall", "Tower", "CityTower", "Column",
                                                 "MidColumn", "Bridge", "MidWall", "Temple", "Rubble", "RingTower"))]
bpy.context.view_layer.update()
rf.scatter("ReefStatue", rocks, STATUE_AT + Vector((0, -2.0, 0)), 9.0, 44, 21, REEF, scale=1.6)
rf.scatter("ReefLedge", rocks, LEDGE + Vector((-1.0, 2.0, 0)), 5.0, 40, 22, REEF, scale=0.7)
rf.scatter("ReefCorner", rocks, CORNER + Vector((1.0, 1.0, 0)), 3.5, 26, 23, REEF, scale=0.6)
rf.scatter("ReefTower", rocks, TOWER + Vector((0, 0, -10.0)), 5.0, 18, 24, REEF, scale=1.2)
rf.scatter("ReefCity", rocks, HALL + Vector((-6.0, -8.0, 0)), 18.0, 36, 25, REEF, scale=3.0)
rf.scatter("ReefRuins", ruins, rk.place(0.2, 0.2, 70.0), 45.0, 60, 26, REEF, scale=2.4, up_only=0.6)


def statue_growth():
    """Centuries on the sea floor: barnacles crowded on him wherever the
    current brings food (the hem, the folds, the tops of his arms and
    shoulders), a few corals and sponges grown on him, and weed hanging
    from his arm and trident."""
    parts = [o for o in bpy.data.objects if o.name in ("Human", "Robe", "Crown", "Hair", "Beard")]
    face_z = bpy.data.objects["Beard"].location.z
    spots = rf.surface_points(parts, 120, 31,
                              lambda p, n: (n.z > 0.25 or p.z < STATUE_AT.z + 2.5) and p.z < face_z - 0.4)
    rf.barnacles("StatueBarnacles", [(p, n, random.Random(i).randint(3, 14)) for i, (p, n) in enumerate(spots)],
                 32, REEF["stony"], size=0.07)
    tops = rf.surface_points(parts, 14, 33, lambda p, n: n.z > 0.75 and p.z < face_z - 0.6)
    for i, (p, n) in enumerate(tops):
        kind = ("zoanthids", "tubes", "anemone", "barrel", "dusters", "zoanthids", "brain")[i % 7]
        o = rf.grow(kind, "StatueGrowth%d" % i, p - n * 0.05, random.Random(i).uniform(0.35, 0.6),
                    rf.PALETTE[(i * 5) % len(rf.PALETTE)], 340 + i, REEF)
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = n.to_track_quat('Z', 'Y')
    trident = bpy.data.objects["Trident"]
    under = rf.surface_points([trident, bpy.data.objects["Human"]], 40, 35,
                              lambda p, n: n.z < -0.35 and p.z > STATUE_AT.z + STATUE_H * 0.5)
    rf.strands("StatueWeed", [p for p, n in under], 36, WEED, length=(0.5, 2.2), width=0.05)


statue_growth()

# Weed hanging off the ruins' cornices and broken edges.
eaves = rf.surface_points([o for o in ruins if o.name.startswith(("Arcade", "MidWall", "Bridge", "Tower"))
                           and o.name != "TowerRock"], 90, 37,
                          lambda p, n: n.z < -0.8)
rf.strands("RuinWeed", [p for p, n in eaves], 38, WEED, length=(0.8, 3.0), width=0.09)

KELP_PARTS = []
for i, (sx, sy, d, h) in enumerate([(-1.0, -0.72, 9.0, 4.2), (-1.12, -0.5, 11.0, 5.4), (-0.86, -0.66, 10.5, 3.6)]):
    # Leaning out of the frame, so it frames the statue's cliff instead of
    # covering it.
    KELP_PARTS.append(rf.kelp("Kelp%d" % i, rk.place(sx, sy, d), h, 700 + i, KELP, blades=4, lean=(-0.2, 0.1)))

# ------------------------------------------------------------------- render

# The sand is too big to dice and mostly hidden; it keeps its relief as bump.
rk.detail_all(skip=("Floor",))

blend = rk.ROOT / "build" / "boards3d" / "atlantis.blend"
rk.SCENE.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
if PREVIEW or "--still" in ARGS:
    out = Path(arg("--out", str(rk.ROOT / "build" / "boards3d" / "atlantis" / "plate.png")))
    crop = tuple(float(x) for x in arg("--crop", "").split(",")) if "--crop" in ARGS else None
    rk.render(out, arg("--width", 360 if PREVIEW else 1280), arg("--samples", 48 if PREVIEW else 512),
              preview=PREVIEW, crop=crop)
    raise SystemExit

ASSETS = rk.ROOT / "boards" / "3d" / "atlantis"
if "--live" not in ARGS:
    # `--live` skips this, the slow part, when only what swims has changed.
    rk.bake(ASSETS, arg("--width", 1280), arg("--samples", 512),
            {"merman": MERMAN_PARTS, "kelp": KELP_PARTS})

    # Where the merman bends, in plate UV, for the game's warp of his layer.
    import json
    meta = json.loads((ASSETS / "plate.json").read_text())
    meta["layers"]["merman"]["anchors"] = {k: list(rk._uv(v)[:2]) for k, v in MERMAN_ANCHORS.items()}
    (ASSETS / "plate.json").write_text(json.dumps(meta, indent=1))

# ------------------------------------------------------------------- live

# The game's camera: the frame's own field of view, not the plate's wider
# one, because the game widens it itself for the margins.
gcam_data = bpy.data.cameras.new("GameCamera")
gcam_data.sensor_fit = 'VERTICAL'
gcam_data.angle_y = math.radians(62.0)
gcam_data.clip_start = 0.2
gcam_data.clip_end = 900.0
gcam = bpy.data.objects.new("GameCamera", gcam_data)
gcam.matrix_world = CAM.matrix_world.copy()
rk.link(gcam)
rk.SCENE.render.resolution_x, rk.SCENE.render.resolution_y = 1080, 1920
rk.SCENE.render.resolution_percentage = 100


def tag(name):
    return rk.plain(name, "#ffffff")


live = [gcam]
FISH, YELLOW_FISH, JELLY, WHALE, MANTA, RAY = (tag("Fish"), tag("FishGold"), tag("Jelly"), tag("Whale"),
                                               tag("Manta"), tag("Ray"))

# A big school of silver fish wheeling round past the statue, through the
# gap behind his trident and back round in front of the cliff.
sa = sl.school("SchoolA", 120, 0.85, 2.6, 801, FISH, rgb=(0.78, 0.84, 0.9))
sl.orbit(sa, rk.place(-0.3, 0.42, 34.0), (9.0, 6.0), tilt=0.25, turns=1)
# A second, further off, over the city.
sb = sl.school("SchoolB", 80, 1.1, 3.4, 802, FISH, rgb=(0.6, 0.7, 0.8), shape=(1.2, 0.6, 0.5))
sl.orbit(sb, rk.place(0.45, 0.55, 70.0), (16.0, 9.0), tilt=-0.15, phase=0.4, turns=1)
# A few yellow reef fish near the merman and the coral, slower.
sc = sl.school("SchoolC", 12, 0.3, 0.8, 803, YELLOW_FISH, rgb=(1.0, 0.82, 0.2))
sl.orbit(sc, rk.place(0.62, -0.45, 9.0), (1.6, 1.0), tilt=0.4, phase=0.2, turns=2, wobble=0.3)
live += [sa, sb, sc]

# Jellyfish down the left side, beside the statue, as in the picture.
# Clear of the statue's face and chest, which they would otherwise veil.
for i, (sx, sy, d, size) in enumerate([(-0.88, 0.55, 18.0, 0.7), (-0.95, 0.2, 12.0, 0.55),
                                       (-0.78, 0.92, 24.0, 0.9), (-0.88, -0.12, 9.0, 0.4),
                                       (-1.02, 0.78, 15.0, 0.5), (-0.45, 1.05, 34.0, 1.1),
                                       (-1.05, 0.35, 26.0, 0.75)]):
    j = sl.jellyfish("Jelly%d" % i, size, 900 + i, JELLY)
    sl.drift(j, rk.place(sx, sy, d), rise=size * 1.2, sway=size * 0.8, phase=i * 0.21)
    live.append(j)

# The whale, high on the right, swimming slowly across over the city.
w = sl.whale("Whale", 26.0, WHALE)
sl.crossing(w, rk.place(1.9, 0.85, 115.0), rk.place(-1.9, 1.0, 125.0), 0.05, 0.85, bob=1.5)
live.append(w)
# A manta gliding low across the chasm, the other way.
m = sl.manta("Manta", 4.5, MANTA)
sl.crossing(m, rk.place(-1.8, -0.35, 45.0), rk.place(1.8, -0.2, 40.0), 0.4, 0.55, bob=0.8)
live.append(m)

# Light shafts that shimmer over the rendered ones.
sun_dir = (sun.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
shafts = []
rng = random.Random(42)
for i in range(9):
    # Far enough back, and short enough, that no shaft comes down in front of
    # the statue and washes him out.
    top = rk.place(rng.uniform(-0.9, 1.1), 1.35, rng.uniform(70, 120))
    shafts.append((top, top + sun_dir * rng.uniform(30, 50), rng.uniform(3.0, 7.0), (0.75, 0.95, 1.0),
                   rng.random()))
live.append(sl.rays("Shafts", shafts, RAY))

# Bubbles: from the clam, and from a crack in the statue's cliff.
live.append(sl.marker("Bubbles_Clam", pearl.location + Vector((0, 0, 0.1))))
live.append(sl.marker("Bubbles_Cliff", rk.place(-0.42, -0.35, 22.0)))
live.append(sl.marker("Bubbles_Corner", rk.place(0.82, -0.9, 8.0)))

sl.export(rk.ROOT / "boards" / "3d" / "atlantis.glb", live)
