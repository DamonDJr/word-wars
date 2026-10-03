"""What the realistic board scenes in this folder share.

The toon boards (`toonkit.py`) are drawn live: every object goes to the game
and is shaded there. A realistic scene cannot be. The light shafts, the
murk, the soft shadows and the stone's grain are path-traced effects the
phone's renderer cannot afford, so these scenes are rendered once here, in
Cycles, and shipped as pictures. The camera never moves, so a picture of the
scene and the scene are the same thing to the player.

What moves is added back in the game over the picture (see
`scripts/board3d.gd`): fish, jellyfish, light, bubbles. For those to pass
behind a column and in front of the statue, the render also writes the
scene's depth, which the game's shaders test against.

Layout is by screen position, as in `toonkit.py`: `place(sx, sy, d)` is
(sx, sy) on the 9:16 frame, -1..1 edge to edge, `d` metres in front of the
camera. The game pins the frame's width, so a taller phone sees more above
and below (to about sy = +-1.2). On a phone the board covers the middle half
of the width from sy = +0.8 to -0.3 and the keyboard everything below
sy = -0.3, so what matters is at the sides and in the top half.

The plate is rendered past the frame on every side: `OVER_X` for the shake
margin the game draws the backdrop with, `OVER_Y` for the tallest phones.
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[2]
TAU = math.tau
ASPECT = 1080.0 / 1920.0
OVER_X = 1.18
OVER_Y = 1.27

SCENE = None
CAMERA = None
CAM_M = Matrix()
TX = 1.0
TY = 1.0
MATS = {}


# ------------------------------------------------------------------ helpers

def srgb(hexcol):
    """sRGB hex to linear RGBA, which is what node colours want."""
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (lin[0], lin[1], lin[2], 1.0)


def setup():
    """Empty the file and set Cycles up on the GPU if there is one."""
    global SCENE, MATS
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("HIP", "CUDA", "OPTIX", "ONEAPI"):
        try:
            prefs.compute_device_type = kind
        except TypeError:
            continue
        prefs.get_devices()
        gpus = [d for d in prefs.devices if d.type != 'CPU']
        if gpus:
            for d in prefs.devices:
                d.use = d.type != 'CPU'
            sc.cycles.device = 'GPU'
            break
    sc.cycles.use_denoising = True
    sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    sc.cycles.max_bounces = 8
    sc.cycles.volume_bounces = 2
    sc.cycles.transparent_max_bounces = 16
    # Standard rather than AgX: the sea's blue is meant to be saturated, and
    # AgX walks every bright blue toward white.
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.exposure = -0.6
    sc.render.film_transparent = False
    # Surface relief is real geometry, diced at render time to about a pixel
    # wherever the camera sees it and coarser off screen (see `detail`).
    sc.cycles.dicing_rate = 1.0
    sc.cycles.offscreen_dicing_scale = 6.0
    sc.cycles.max_subdivisions = 12
    SCENE = sc
    MATS = {}
    return sc


def camera(vfov=60.0, pitch=0.0, loc=(0.0, 0.0, 0.0), yaw=0.0, clip_end=600.0):
    """The camera, fixed, and the frame `place()` works in.

    `vfov` is the 9:16 frame's vertical field of view; the camera itself is
    widened by `OVER_X`/`OVER_Y` so the render covers the margins. `pitch` is
    degrees above level, `yaw` degrees to the right of straight down +Y.
    """
    global CAMERA, CAM_M, TX, TY
    TY = math.tan(math.radians(vfov) * 0.5)
    TX = TY * ASPECT
    data = bpy.data.cameras.new("Camera")
    data.sensor_fit = 'HORIZONTAL'
    data.angle_x = 2.0 * math.atan(TX * OVER_X)
    data.clip_start = 0.2
    data.clip_end = clip_end
    cam = bpy.data.objects.new("Camera", data)
    SCENE.collection.objects.link(cam)
    SCENE.camera = cam
    rot = Euler((math.radians(90.0 + pitch), 0.0, -math.radians(yaw)))
    cam.rotation_euler = rot
    cam.location = Vector(loc)
    CAMERA = cam
    CAM_M = Matrix.Translation(Vector(loc)) @ rot.to_matrix().to_4x4()
    return cam


def plate_size(width):
    """Pixel size of a plate `width` wide: the frame's shape stretched by
    the two margins."""
    return width, int(round(width * (TY * OVER_Y) / (TX * OVER_X) / 2.0) * 2)


def place(sx, sy, d):
    return CAM_M @ Vector((sx * d * TX, sy * d * TY, -d))


def screen(p):
    """The inverse of `place`: world point -> (sx, sy, d)."""
    v = CAM_M.inverted() @ Vector(p)
    d = -v.z
    return v.x / (d * TX), v.y / (d * TY), d


def ground(sx, sy, z=0.0):
    """Where the ray through (sx, sy) meets the plane at height `z`."""
    o = CAM_M.translation
    ray = place(sx, sy, 1.0) - o
    if abs(ray.z) < 1e-6:
        return None
    t = (z - o.z) / ray.z
    return o + ray * t if t > 0 else None


def link(obj, coll=None):
    (coll or SCENE.collection).objects.link(obj)
    return obj


def collection(name):
    c = bpy.data.collections.new(name)
    SCENE.collection.children.link(c)
    return c


def mesh_object(name, bm, mat=None, coll=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
    o = bpy.data.objects.new(name, me)
    if mat is not None:
        me.materials.append(mat)
    return link(o, coll)


def apply_modifiers(obj):
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def boolean(obj, cutter, op='DIFFERENCE', keep=False):
    m = obj.modifiers.new("bool", 'BOOLEAN')
    m.operation = op
    m.solver = 'EXACT'
    # Cutters are built from overlapping pieces (an arch is a box and a
    # cylinder), which the exact solver only handles when told to.
    m.use_self = True
    m.use_hole_tolerant = True
    m.object = cutter
    apply_modifiers(obj)
    if not keep:
        bpy.data.objects.remove(cutter, do_unlink=True)


def join(objs, name):
    # Joining keeps only the active object's modifiers, and applies them to
    # everything, so each part's own go in first.
    for o in objs:
        if o.modifiers:
            apply_modifiers(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def lathe(bm, profile, seg, xform=Matrix(), radial=None, cap_top=True, cap_bottom=True):
    """Revolve `profile` [(r, z), ...] round Z. `radial(theta)` scales r,
    which is how flutes get cut into a shaft."""
    rings = []
    for r, z in profile:
        ring = []
        for i in range(seg):
            a = TAU * i / seg
            k = radial(a) if radial else 1.0
            ring.append(bm.verts.new(xform @ Vector((r * k * math.cos(a), r * k * math.sin(a), z))))
        rings.append(ring)
    for ra, rb in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if cap_bottom and profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    return rings


def organic(obj):
    """Mark `obj` as something grown or worn round (rock, coral, a body), to
    be subdivided smooth when it is diced; anything else is diced flat so a
    column's plinth and a wall's corners keep their edges."""
    obj["organic"] = True
    return obj


def detail(obj, px=1.0):
    """Let the renderer dice `obj` to about `px` pixels and displace it by its
    material's height. The modifier has to be last, so this goes on after
    every join and boolean."""
    mods = obj.modifiers
    last = mods[-1] if len(mods) else None
    if last is not None and last.type == 'SUBSURF':
        sub = last
    else:
        sub = mods.new("detail", 'SUBSURF')
        sub.levels = 0
        sub.subdivision_type = 'CATMULL_CLARK' if obj.get("organic") else 'SIMPLE'
    sub.use_adaptive_subdivision = True
    sub.adaptive_space = 'PIXEL'
    sub.adaptive_pixel_size = px
    return sub


def detail_all(px=1.0, skip=()):
    """`detail` on everything `organic` whose material has relief. Only those:
    what is built is cut with booleans into long slivers and great many-sided
    faces, and the renderer dices a face once per corner, so a ruin diced to
    the pixel costs gigabytes. Its masonry is a bump instead."""
    n = 0
    for o in SCENE.objects:
        if o.type != 'MESH' or o in skip or o.name in skip or not o.get("organic"):
            continue
        if any(s.material is not None and s.material.displacement_method != 'BUMP' for s in o.material_slots):
            detail(o, px)
            n += 1
    print("[detail] %d objects diced at render time" % n)


def noise_displace(obj, strength, size, seed=0, kind='VORONOI', levels=2, mid=0.5):
    """Subdivide and push the surface along its normals by a procedural
    texture: how a box becomes a weathered block and a ball a boulder."""
    if levels:
        sub = obj.modifiers.new("sub", 'SUBSURF')
        sub.levels = levels
        sub.render_levels = levels
    tex = bpy.data.textures.new(obj.name + "_disp", kind)
    if kind == 'VORONOI':
        tex.noise_scale = size
        tex.distance_metric = 'DISTANCE'
    else:
        tex.noise_scale = size
    d = obj.modifiers.new("disp", 'DISPLACE')
    d.texture = tex
    d.strength = strength
    d.mid_level = mid
    d.texture_coords = 'GLOBAL' if seed == 0 else 'OBJECT'
    return d


# ---------------------------------------------------------------- materials
#
# Every material is a Principled BSDF fed by procedural textures, so nothing
# has to be painted or downloaded and every surface still has grain at any
# distance.

def _nodes(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return m, nt, out


def _noise(nt, scale, detail=6.0, rough=0.6, coord=None):
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    if coord is not None:
        nt.links.new(coord, n.inputs["Vector"])
    return n


def _ramp(nt, fac, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    el = r.color_ramp.elements
    el[0].position, el[0].color = stops[0][0], stops[0][1]
    el[1].position, el[1].color = stops[-1][0], stops[-1][1]
    for p, c in stops[1:-1]:
        e = el.new(p)
        e.color = c
    nt.links.new(fac, r.inputs["Fac"])
    return r


def _mix(nt, fac, a, b, blend='MIX'):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = 'RGBA'
    m.blend_type = blend
    if isinstance(fac, float):
        m.inputs[0].default_value = fac
    else:
        nt.links.new(fac, m.inputs[0])
    for sock, v in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(v, tuple):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return m.outputs[2]


def _math(nt, op, a, b=None, c=None, clamp=False):
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = op
    m.use_clamp = clamp
    for sock, v in zip(m.inputs, (a, b, c)):
        if v is None:
            continue
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            nt.links.new(v, sock)
    return m.outputs[0]


def _up_mask(nt, lo=0.35, hi=0.8):
    """1 on faces that point up, 0 on walls and undersides."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = lo
    mr.inputs["From Max"].default_value = hi
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    return mr.outputs["Result"]


def _pos(nt):
    """World position. Textures are read in metres, so a stretched or scaled
    object (a crag is a ball scaled 30 m tall) is not stretched grain."""
    return nt.nodes.new("ShaderNodeNewGeometry").outputs["Position"]


def _band(nt, x, lo, hi):
    """0 below `lo`, 1 above `hi`, smooth between."""
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.interpolation_type = 'SMOOTHSTEP'
    mr.inputs["From Min"].default_value = lo
    mr.inputs["From Max"].default_value = hi
    nt.links.new(x, mr.inputs["Value"])
    return mr.outputs["Result"]


def _scaled(nt, co, s):
    """`co` scaled per axis by `s` (x, y, z): streaks are noise squeezed
    along one axis."""
    v = nt.nodes.new("ShaderNodeVectorMath")
    v.operation = 'MULTIPLY'
    nt.links.new(co, v.inputs[0])
    v.inputs[1].default_value = s
    return v.outputs[0]


def _sum(nt, terms, base=0.0):
    """base + sum(w * x) over [(x, w)]: a height field built from parts."""
    acc = base
    for x, w in terms:
        acc = _math(nt, 'MULTIPLY_ADD', x, w, acc)
    return acc


def _displace(m, nt, out, height, scale, mid=0.5):
    """Feed `height` (0..1, `mid` is the surface) to the material's
    displacement, `scale` metres from 0 to 1, in world space so a scaled
    object is displaced in metres too. Displacement only, no bump on top:
    `detail` dices to the pixel, so a bump would add nothing a pixel can
    show, and it costs three evaluations of the height at every hit."""
    d = nt.nodes.new("ShaderNodeDisplacement")
    d.space = 'WORLD'
    d.inputs["Midlevel"].default_value = mid
    d.inputs["Scale"].default_value = scale
    nt.links.new(height, d.inputs["Height"])
    nt.links.new(d.outputs[0], out.inputs["Displacement"])
    m.displacement_method = 'DISPLACEMENT'
    return d


def _bricks(nt, size):
    """Masonry courses on any wall: a brick pattern laid on whichever pair of
    axes the face is most nearly flat to, so walls running either way and
    round towers all get level courses. Returns (mortar 0..1, per-block 0..1)."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    nsep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], nsep.inputs[0])

    def brick(a, b):
        cv = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(a, cv.inputs[0])
        nt.links.new(b, cv.inputs[1])
        br = nt.nodes.new("ShaderNodeTexBrick")
        br.inputs["Scale"].default_value = 1.0 / size
        br.inputs["Mortar Size"].default_value = 0.035
        br.inputs["Mortar Smooth"].default_value = 0.4
        br.inputs["Brick Width"].default_value = 1.6
        br.inputs["Row Height"].default_value = 0.55
        br.inputs["Color1"].default_value = (0.0, 0.0, 0.0, 1.0)
        br.inputs["Color2"].default_value = (1.0, 1.0, 1.0, 1.0)
        br.offset_frequency = 2
        br.squash = 1.0
        nt.links.new(cv.outputs[0], br.inputs["Vector"])
        return br
    bx = brick(sep.outputs["Y"], sep.outputs["Z"])     # faces looking along X
    by = brick(sep.outputs["X"], sep.outputs["Z"])     # faces looking along Y
    pick = _math(nt, 'GREATER_THAN', _math(nt, 'ABSOLUTE', nsep.outputs["X"]),
                 _math(nt, 'ABSOLUTE', nsep.outputs["Y"]))
    mortar = _mix(nt, pick, by.outputs["Fac"], bx.outputs["Fac"])
    block = _mix(nt, pick, by.outputs["Color"], bx.outputs["Color"])
    return mortar, block


def _warp(nt, co, scale, amount):
    """`co` pushed about by a noise of `scale`, `amount` metres: what makes
    cell edges wander like cracks instead of tiling like paving."""
    n = _noise(nt, scale, 3.0, 0.5, co)
    v = nt.nodes.new("ShaderNodeVectorMath")
    v.operation = 'MULTIPLY_ADD'
    nt.links.new(n.outputs["Color"], v.inputs[0])
    v.inputs[1].default_value = (amount, amount, amount)
    nt.links.new(co, v.inputs[2])
    return v.outputs[0]


def _voronoi(nt, co, scale, feature='F1', rand=1.0):
    v = nt.nodes.new("ShaderNodeTexVoronoi")
    v.feature = feature
    v.inputs["Scale"].default_value = scale
    v.inputs["Randomness"].default_value = rand
    nt.links.new(co, v.inputs["Vector"])
    return v


def stone(name, base="#8a8f96", dark="#3c444c", moss="#3f5a2a", moss_amount=0.5,
          scale=1.0, relief=0.3, rough=0.85, crevice="#141a20", algae="#2c4a4a", blocks=0.0,
          tone="#7a6c5c", coralline=0.0, sponges=0.0, silt=0.4, pits=0.5, cracks=1.0, dice=True,
          streaks=0.0):
    """Weathered stone under the sea, measured in metres: `scale` is how
    fine the grain is (about that many features a metre at the finest
    useful size), `relief` how far the surface is displaced at most.

    Shape: lumps, wandering cracks and the pits the sea wears into stone,
    and a crust over what faces up. `blocks` > 0 lays it in masonry courses
    of about that many metres instead: joints sunk in, the arrises chipped
    and now and then a block gone.

    Colour: grain between `dark` and `base`, drifting toward `tone` and
    `algae` over metres, grime in every hollow, moss or silt on what faces
    the surface, and in patches the pink crust of coralline algae
    (`coralline`) and the orange, yellow and red of encrusting sponges
    (`sponges`), raised a little off the stone, and dark stains run down
    its faces (`streaks`).

    `dice=False` keeps the relief as a bump (for masonry; see `detail_all`)."""
    m, nt, out = _nodes(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    co = _pos(nt)
    s = scale
    lumps = _noise(nt, s * 0.3, 3.0, 0.5, co).outputs["Fac"]
    grain = _noise(nt, s * 3.0, 5.0, 0.62, co).outputs["Fac"]
    fine = _noise(nt, s * 16.0, 3.0, 0.6, co).outputs["Fac"]
    big = _noise(nt, s * 0.1, 3.0, 0.5, co).outputs["Fac"]
    patch = _noise(nt, s * 0.6, 3.0, 0.55, co).outputs["Fac"]
    up = _up_mask(nt, 0.3, 0.75)

    # Pits, gathered in patches rather than evenly spread.
    pv = _voronoi(nt, co, s * 2.2)
    pit = _math(nt, 'MULTIPLY', _math(nt, 'SUBTRACT', 1.0, _band(nt, pv.outputs["Distance"], 0.06, 0.28)),
                _band(nt, patch, 0.45, 0.6))
    pit = _math(nt, 'MULTIPLY', pit, pits)

    if blocks:
        mortar, block = _bricks(nt, blocks)
        chip = _noise(nt, s * 1.5, 5.0, 0.6, co).outputs["Fac"]
        # How far into a joint: the joint itself, widened where the noise
        # says the edge has broken away.
        edge = _band(nt, _math(nt, 'MULTIPLY_ADD', chip, 0.9, _math(nt, 'SUBTRACT', mortar, 0.45)), 0.0, 0.35)
        bv = _math(nt, 'ADD', block, 0.0)        # colour -> value
        gone = _band(nt, bv, 0.9, 0.92)
        h = _sum(nt, [(bv, 0.12), (edge, -0.45), (grain, 0.3), (fine, 0.1), (gone, -0.45), (pit, -0.12),
                      (lumps, 0.2)], 0.38)
        lines = edge
    else:
        wco = _warp(nt, co, s * 0.8, 0.35 / s)
        c1 = _voronoi(nt, wco, s * 0.45, 'DISTANCE_TO_EDGE')
        c2 = _voronoi(nt, wco, s * 1.6, 'DISTANCE_TO_EDGE')
        crack = _math(nt, 'SUBTRACT', 1.0, _band(nt, c1.outputs["Distance"], 0.0, 0.05))
        crack2 = _math(nt, 'MULTIPLY', _math(nt, 'SUBTRACT', 1.0, _band(nt, c2.outputs["Distance"], 0.0, 0.035)),
                       _band(nt, patch, 0.4, 0.55))
        crack = _math(nt, 'MULTIPLY', crack, cracks)
        crack2 = _math(nt, 'MULTIPLY', crack2, cracks)
        # Facets: the cell's own distance from its edge lifts its middle, so
        # the stone breaks into blocky planes between the cracks.
        facet = _band(nt, c1.outputs["Distance"], 0.0, 0.35)
        h = _sum(nt, [(lumps, 1.1), (facet, 0.22), (grain, 0.5), (fine, 0.16), (crack, -0.28),
                      (crack2, -0.1), (pit, -0.2)], -0.25)
        lines = _math(nt, 'MAXIMUM', crack, _math(nt, 'MULTIPLY', crack2, 0.7))

    # Colour.
    col = _ramp(nt, grain, [(0.3, srgb(dark)), (0.7, srgb(base))]).outputs["Color"]
    col = _mix(nt, _band(nt, big, 0.35, 0.65), col, _mix(nt, 0.6, col, srgb(tone)))
    if blocks:
        var = _math(nt, 'MULTIPLY_ADD', bv, 0.5, 0.75)
        col = _mix(nt, 1.0, col, _mix(nt, var, (0, 0, 0, 1), (1.0, 1.0, 1.0, 1.0)), 'MULTIPLY')
    col = _mix(nt, _math(nt, 'MULTIPLY', patch, 0.45), col, srgb(algae))
    if streaks:
        # Dark runs down the face, the way water stains a wall that stood
        # in it long enough: noise squeezed tall and thin.
        st = _noise(nt, 1.0, 3.0, 0.6, _scaled(nt, co, (s * 3.0, s * 3.0, s * 0.18))).outputs["Fac"]
        col = _mix(nt, _math(nt, 'MULTIPLY', _band(nt, st, 0.52, 0.66), streaks), col,
                   _mix(nt, 0.55, srgb(algae), srgb(crevice)))
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 4
    ao.inputs["Distance"].default_value = 1.0
    shade = _band(nt, ao.outputs["AO"], 0.0, 0.85)
    col = _mix(nt, shade, srgb(crevice), col)
    col = _mix(nt, _math(nt, 'MULTIPLY', lines, 0.85), col, srgb(crevice))
    col = _mix(nt, _math(nt, 'MULTIPLY', pit, 0.8), col, srgb(crevice))
    rgh = _math(nt, 'ADD', rough, 0.0)

    # Coralline crust: pink, speckled, in patches, a little raised.
    if coralline:
        cn = _noise(nt, s * 0.5, 4.0, 0.6, _warp(nt, co, s * 2.0, 0.1 / s)).outputs["Fac"]
        cm = _math(nt, 'MULTIPLY', _band(nt, cn, 0.56, 0.6), coralline, clamp=True)
        ccol = _mix(nt, _band(nt, fine, 0.45, 0.6), srgb("#7a3e5e"), srgb("#c0809a"))
        col = _mix(nt, cm, col, ccol)
        h = _sum(nt, [(cm, 0.08), (_math(nt, 'MULTIPLY', cm, fine), 0.06)], h)
        rgh = _mix(nt, cm, rgh, (0.6, 0.6, 0.6, 1.0))

    # Encrusting sponges: a few cells, raised and full of pores.
    if sponges:
        sv = _voronoi(nt, _warp(nt, co, s * 1.2, 0.15 / s), s * 0.7)
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(sv.outputs["Color"], sep.inputs[0])
        pick = _band(nt, sep.outputs["Red"], 1.0 - 0.18 * sponges, 1.0 - 0.18 * sponges + 0.01)
        sm = _math(nt, 'MULTIPLY', pick, _math(nt, 'SUBTRACT', 1.0, _band(nt, sv.outputs["Distance"], 0.25, 0.4)))
        scol = _ramp(nt, sep.outputs["Green"], [(0.0, srgb("#c0581c")), (0.35, srgb("#c89a22")),
                                                (0.65, srgb("#a8281e")), (1.0, srgb("#6a3484"))]).outputs["Color"]
        pores = _voronoi(nt, co, s * 18.0)
        pore = _math(nt, 'SUBTRACT', 1.0, _band(nt, pores.outputs["Distance"], 0.1, 0.3))
        scol = _mix(nt, _math(nt, 'MULTIPLY', pore, 0.6), scol, srgb("#2a140c"))
        col = _mix(nt, sm, col, scol)
        h = _sum(nt, [(sm, 0.14), (_math(nt, 'MULTIPLY', sm, pore), -0.05)], h)
        rgh = _mix(nt, sm, rgh, (0.95, 0.95, 0.95, 1.0))

    # Silt on the flattest tops, moss and turf on what faces up.
    nz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(nt.nodes.new("ShaderNodeNewGeometry").outputs["Normal"], nz.inputs[0])
    sl = _math(nt, 'MULTIPLY', _band(nt, nz.outputs["Z"], 0.8, 0.95), _band(nt, big, 0.3, 0.5))
    sl = _math(nt, 'MULTIPLY', sl, silt)
    col = _mix(nt, sl, col, _mix(nt, fine, srgb("#8c8a76"), srgb("#b4b29c")))
    mn = _noise(nt, s * 1.2, 3.0, 0.7, co).outputs["Fac"]
    mm = _math(nt, 'MULTIPLY', up, _band(nt, mn, 0.42, 0.6))
    mm = _math(nt, 'MULTIPLY', mm, 1.6 * moss_amount, clamp=True)
    mcol = _mix(nt, fine, srgb("#1e3214"), srgb(moss))
    col = _mix(nt, mm, col, mcol)
    h = _sum(nt, [(mm, 0.06), (_math(nt, 'MULTIPLY', mm, fine), 0.08)], h)
    rgh = _mix(nt, _math(nt, 'MAXIMUM', mm, sl), rgh, (1.0, 1.0, 1.0, 1.0))
    nt.links.new(mm, bsdf.inputs["Sheen Weight"])
    bsdf.inputs["Sheen Tint"].default_value = srgb(moss)

    nt.links.new(col, bsdf.inputs["Base Color"])
    nt.links.new(rgh, bsdf.inputs["Roughness"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    _displace(m, nt, out, h, relief)
    if not dice:
        m.displacement_method = 'BUMP'
    MATS[name] = m
    return m


def metal(name, base="#c9a24a", patina="#3f8f84", patina_amount=0.5, rough=0.35,
          scale=1.5, dirt="#1c2622", moss="#3a5a2a", moss_amount=0.0, wear=0.0,
          streaks=0.0, crust=0.0, relief=0.0, dark="#4a3018"):
    """Bronze or gold that has lain in the sea: verdigris in every hollow
    and in streaks run down from the tops (`streaks`), bright metal worn
    through on the edges (`wear`), a pale crust with pink coralline and
    corrosion pits on whatever faces the surface (`crust`), moss on top of
    that (`moss_amount`). `scale` is features a metre; `relief` metres of
    real displacement for the crust and pits."""
    m, nt, out = _nodes(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    co = _pos(nt)
    n = _noise(nt, scale, 5.0, 0.65, co).outputs["Fac"]
    fine = _noise(nt, scale * 12.0, 3.0, 0.6, co).outputs["Fac"]
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 4
    ao.inputs["Distance"].default_value = 0.35
    cav = _math(nt, 'SUBTRACT', 1.0, ao.outputs["AO"])
    pm = _sum(nt, [(cav, 2.5), (n, patina_amount)], -0.45)
    if streaks:
        st = _noise(nt, 1.0, 6.0, 0.6, _scaled(nt, co, (scale * 5.0, scale * 5.0, scale * 0.3))).outputs["Fac"]
        pm = _sum(nt, [(_band(nt, st, 0.5, 0.64), streaks)], pm)
    pm = _math(nt, 'MULTIPLY', pm, 2.0, clamp=True)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    edge = None
    if wear:
        edge = _math(nt, 'MULTIPLY', _math(nt, 'SUBTRACT', geo.outputs["Pointiness"], 0.5), 6.0 * wear,
                     clamp=True)
        pm = _math(nt, 'SUBTRACT', pm, edge, clamp=True)
    mcol = _mix(nt, _band(nt, n, 0.35, 0.6), srgb(dark), srgb(base))
    if edge is not None:
        mcol = _mix(nt, edge, mcol, srgb(base))
    pcol = _ramp(nt, fine, [(0.3, srgb("#1f5048")), (0.55, srgb(patina)), (0.8, srgb("#86ccb4"))]).outputs["Color"]
    color = _mix(nt, pm, mcol, pcol)
    color = _mix(nt, _math(nt, 'MULTIPLY', cav, 1.5, clamp=True), color, srgb(dirt))
    pv = _voronoi(nt, co, scale * 25.0)
    pit = _math(nt, 'MULTIPLY', _math(nt, 'SUBTRACT', 1.0, _band(nt, pv.outputs["Distance"], 0.05, 0.25)), pm)
    color = _mix(nt, _math(nt, 'MULTIPLY', pit, 0.6), color, srgb(dirt))
    h = _sum(nt, [(n, 0.15), (pit, -0.15), (_math(nt, 'MULTIPLY', pm, fine), 0.12)], 0.42)
    solid = pm
    if crust:
        cn = _noise(nt, scale * 1.4, 6.0, 0.6, co).outputs["Fac"]
        cm = _math(nt, 'MULTIPLY', _up_mask(nt, 0.35, 0.8), _band(nt, cn, 0.4, 0.55))
        cm = _math(nt, 'MULTIPLY', cm, crust, clamp=True)
        speck = _voronoi(nt, co, scale * 6.0)
        pink = _math(nt, 'MULTIPLY', _band(nt, fine, 0.5, 0.6),
                     _math(nt, 'SUBTRACT', 1.0, _band(nt, speck.outputs["Distance"], 0.2, 0.45)))
        ccol = _mix(nt, pink, _mix(nt, fine, srgb("#6c7466"), srgb("#a8ae9c")), srgb("#b06a84"))
        color = _mix(nt, cm, color, ccol)
        h = _sum(nt, [(cm, 0.35), (_math(nt, 'MULTIPLY', cm, fine), 0.35)], h)
        solid = _math(nt, 'MAXIMUM', solid, cm)
    if moss_amount:
        mn = _noise(nt, scale * 2.0, 6.0, 0.7, co).outputs["Fac"]
        mm = _math(nt, 'MULTIPLY', _up_mask(nt, 0.45, 0.85), _band(nt, mn, 0.45, 0.62))
        mm = _math(nt, 'MULTIPLY', mm, 1.6 * moss_amount, clamp=True)
        color = _mix(nt, mm, color, _mix(nt, fine, srgb("#1e3214"), srgb(moss)))
        h = _sum(nt, [(mm, 0.2)], h)
        solid = _math(nt, 'MAXIMUM', solid, mm)
    nt.links.new(color, bsdf.inputs["Base Color"])
    nt.links.new(_math(nt, 'SUBTRACT', 1.0, solid), bsdf.inputs["Metallic"])
    nt.links.new(_math(nt, 'MULTIPLY_ADD', solid, 0.55, rough), bsdf.inputs["Roughness"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    if relief:
        _displace(m, nt, out, h, relief)
    else:
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = 0.3
        nt.links.new(h, b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    MATS[name] = m
    return m


def emissive(name, color="#ffb060", strength=8.0, base=None):
    m, nt, out = _nodes(name)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = srgb(color)
    e.inputs["Strength"].default_value = strength
    nt.links.new(e.outputs[0], out.inputs["Surface"])
    MATS[name] = m
    return m


def plain(name, color="#808080", rough=0.6, sss=0.0, sss_radius=(1.0, 0.4, 0.2),
          metallic=0.0, transmission=0.0, alpha=1.0, coat=0.0, sheen=0.0,
          bump_scale=0.0, bump=0.3, emit=None, emit_strength=0.0):
    m, nt, out = _nodes(name)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if sss:
        bsdf.inputs["Subsurface Weight"].default_value = sss
        bsdf.inputs["Subsurface Radius"].default_value = sss_radius
    if transmission:
        bsdf.inputs["Transmission Weight"].default_value = transmission
    if coat:
        bsdf.inputs["Coat Weight"].default_value = coat
    if sheen:
        bsdf.inputs["Sheen Weight"].default_value = sheen
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    if emit:
        bsdf.inputs["Emission Color"].default_value = srgb(emit)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    if bump_scale:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        n = _noise(nt, bump_scale, 6.0, 0.6, tc.outputs["Object"])
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        nt.links.new(n.outputs["Fac"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
    MATS[name] = m
    return m


# -------------------------------------------------------------------- water

def water(top_z, floor_z, density=0.012, scatter="#3fa6d8", absorb="#2f8fd0", anisotropy=0.55,
          top="#6fd6ff", horizon="#06305c", bottom="#010814", sky_strength=1.0, extent=700.0):
    """The sea: a homogeneous volume in a box whose lid is the surface, and a
    world that is bright overhead and black below.

    A box rather than a world volume, because a volume that fills all of
    space swallows the sun: its light would have to cross infinite water to
    arrive. In the box it travels unattenuated to the surface and only then
    starts to fade, as it should. Cycles samples homogeneous volumes exactly,
    without stepping, so the box costs little.
    """
    w = bpy.data.worlds.new("Sea")
    SCENE.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    r = _ramp(nt, _math(nt, 'MULTIPLY_ADD', sep.outputs["Z"], 0.5, 0.5),
              [(0.0, srgb(bottom)), (0.48, srgb(horizon)), (0.75, srgb(top)), (1.0, srgb(top))])
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = sky_strength
    nt.links.new(r.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs[0], out.inputs["Surface"])

    m, mnt, mout = _nodes("Water")
    vol = mnt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = srgb(scatter)
    vol.inputs["Density"].default_value = density
    vol.inputs["Anisotropy"].default_value = anisotropy
    vol.inputs["Absorption Color"].default_value = srgb(absorb)
    mnt.links.new(vol.outputs[0], mout.inputs["Volume"])
    bm = bmesh.new()
    h = top_z - floor_z
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0.0, extent * 0.5, floor_z + h * 0.5))
                          @ Matrix.Diagonal((extent * 2.0, extent * 1.6, h, 1.0)))
    box = mesh_object("Water", bm, m, smooth=False)
    box.display_type = 'BOUNDS'
    MATS["Water"] = m
    return box


def light(kind, name, loc, energy, color="#ffffff", size=0.5, rot=None, coll=None):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = srgb(color)[:3]
    if kind in ('POINT', 'SPOT'):
        data.shadow_soft_size = size
    elif kind == 'AREA':
        data.size = size
    elif kind == 'SUN':
        data.angle = math.radians(size)
    o = bpy.data.objects.new(name, data)
    o.location = loc
    if rot is not None:
        o.rotation_euler = rot
    return link(o, coll)


def aim(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


# ------------------------------------------------------------------- render

def render(path, width, samples=256, preview=False, crop=None):
    """Render the plate to `path` at `width` pixels across, or only the
    `crop` (u0, v0, u1, v1 of the plate, 0,0 top left) of it, for looking
    closely at one corner without paying for the rest."""
    w, h = plate_size(width)
    SCENE.render.resolution_x = w
    SCENE.render.resolution_y = h
    SCENE.render.resolution_percentage = 100
    SCENE.render.use_border = SCENE.render.use_crop_to_border = crop is not None
    if crop:
        u0, v0, u1, v1 = crop
        SCENE.render.border_min_x, SCENE.render.border_max_x = u0, u1
        SCENE.render.border_min_y, SCENE.render.border_max_y = 1.0 - v1, 1.0 - v0
    SCENE.cycles.samples = samples
    SCENE.cycles.adaptive_threshold = 0.02 if preview else 0.008
    SCENE.render.image_settings.file_format = 'PNG'
    SCENE.render.image_settings.color_mode = 'RGB'
    SCENE.render.filepath = str(path)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print("[render] %dx%d %d samples -> %s" % (w, h, samples, path))


# ------------------------------------------------------------- game assets
#
# What the game needs from the render, written to one folder:
#
#   plate.png   the scene without the things that move in place
#   <layer>.png each thing that sways (the merman, the kelp), cut out of a
#               render with it in, cropped to where it is
#   depth.exr   camera depth in metres at half size, 0 where there is nothing,
#               so live things can go behind the stone
#   plate.json  the frame (TX, TY, the margins) and where each layer sits,
#               which the game reads rather than keeping its own copy

def _visible(objs):
    keep = set(objs)
    for o in SCENE.objects:
        o.hide_render = o not in keep and o.type in ('MESH', 'CURVE', 'LIGHT') and o.type != 'LIGHT'
    for o in SCENE.objects:
        if o.type == 'LIGHT':
            o.hide_render = False


def _uv(p):
    """World point -> plate UV (0,0 top left)."""
    sx, sy, d = screen(p)
    return (sx / OVER_X + 1.0) * 0.5, (1.0 - sy / OVER_Y) * 0.5, d


def _bbox_uv(objs, margin=0.02):
    dg = bpy.context.evaluated_depsgraph_get()
    us, vs = [], []
    for o in objs:
        if o.type != 'MESH':
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        mw = o.matrix_world
        for v in me.vertices:
            u, vv, d = _uv(mw @ v.co)
            if d > 0:
                us.append(u)
                vs.append(vv)
        ev.to_mesh_clear()
    return (max(0.0, min(us) - margin), max(0.0, min(vs) - margin),
            min(1.0, max(us) + margin), min(1.0, max(vs) + margin))


def _render(path, width, samples, border=None, transparent=False, fmt='PNG', half=False):
    w, h = plate_size(width)
    r = SCENE.render
    r.resolution_x, r.resolution_y = w, h
    r.resolution_percentage = 50 if half else 100
    r.film_transparent = transparent
    r.use_border = border is not None
    r.use_crop_to_border = border is not None
    if border:
        u0, v0, u1, v1 = border
        r.border_min_x, r.border_max_x = u0, u1
        r.border_min_y, r.border_max_y = 1.0 - v1, 1.0 - v0
    SCENE.cycles.samples = samples
    s = r.image_settings
    s.file_format = fmt
    if fmt == 'PNG':
        s.color_mode = 'RGBA' if transparent else 'RGB'
        s.color_depth = '8'
    else:
        # RGB although only one channel is read: Godot's EXR importer refuses
        # a single-channel file, and a depth that fails to load quietly
        # turns every creature's occlusion off.
        s.color_mode = 'RGB'
        s.color_depth = '16'
        s.exr_codec = 'ZIP'
    r.filepath = str(path)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)


def _override(mat_fn):
    vl = bpy.context.view_layer
    vl.material_override = mat_fn() if mat_fn else None


def _flat_material(name, strength_node):
    m, nt, out = _nodes(name)
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (1, 1, 1, 1)
    strength_node(nt, e)
    nt.links.new(e.outputs[0], out.inputs["Surface"])
    return m


def bake(out_dir, width, samples, layers, hidden=()):
    """Render everything the game needs into `out_dir`. `layers` is
    {name: [objects]}: each is left out of the plate and cut out on its own.
    `hidden` are helpers no picture should show (the water box is handled)."""
    import json
    import numpy as np
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    everything = [o for o in SCENE.objects if o.type in ('MESH', 'CURVE') and o not in hidden]
    movers = {o for objs in layers.values() for o in objs}
    water = [o for o in SCENE.objects if o.name in ("Water",)]
    meta = {"tx": TX, "ty": TY, "over": [OVER_X, OVER_Y], "size": list(plate_size(width)), "layers": {}}

    # The plate.
    _visible([o for o in everything if o not in movers])
    _render(out_dir / "plate.png", width, samples)

    # Each layer: its pixels from a render with it in, its alpha from a
    # render of it alone.
    for name, objs in layers.items():
        rect = _bbox_uv(objs)
        _visible([o for o in everything if o not in movers or o in objs])
        _render(out_dir / (name + "_rgb.png"), width, samples, border=rect)
        _visible(objs)
        _override(lambda: _flat_material("Mask", lambda nt, e: None))
        world = SCENE.world
        SCENE.world = None
        _render(out_dir / (name + "_a.png"), width, 24, border=rect, transparent=True)
        SCENE.world = world
        _override(None)
        rgb = bpy.data.images.load(str(out_dir / (name + "_rgb.png")))
        a = bpy.data.images.load(str(out_dir / (name + "_a.png")))
        px = np.empty(rgb.size[0] * rgb.size[1] * 4, dtype=np.float32)
        rgb.pixels.foreach_get(px)
        pa = np.empty(a.size[0] * a.size[1] * 4, dtype=np.float32)
        a.pixels.foreach_get(pa)
        px = px.reshape(-1, 4)
        px[:, 3] = pa.reshape(-1, 4)[:, 3]
        img = bpy.data.images.new(name, rgb.size[0], rgb.size[1], alpha=True)
        img.colorspace_settings.name = 'sRGB'
        img.pixels.foreach_set(px.ravel())
        img.filepath_raw = str(out_dir / (name + ".png"))
        img.file_format = 'PNG'
        img.save()
        for im in (rgb, a, img):
            bpy.data.images.remove(im)
        (out_dir / (name + "_rgb.png")).unlink()
        (out_dir / (name + "_a.png")).unlink()
        meta["layers"][name] = {"file": name + ".png", "rect": list(rect)}

    bake_depth(out_dir, width, [o for o in everything if o not in movers and o not in water])
    meta["depth"] = "depth.exr"

    for o in SCENE.objects:
        o.hide_render = o in hidden
    with open(out_dir / "plate.json", "w") as f:
        json.dump(meta, f, indent=1)
    print("[bake] %s: plate, %s, depth" % (out_dir, ", ".join(layers)))


def bake_depth(out_dir, width, objs):
    """Depth alone: every surface in `objs` emits its own distance from the
    camera plane, and the render is saved raw, so the EXR holds metres. One
    sample and a needle-thin filter, so no pixel is an average of a near
    surface and a far one."""
    _visible(objs)

    def depth_strength(nt, e):
        cd = nt.nodes.new("ShaderNodeCameraData")
        nt.links.new(cd.outputs["View Z Depth"], e.inputs["Strength"])
    _override(lambda: _flat_material("Depth", depth_strength))
    view = (SCENE.view_settings.view_transform, SCENE.view_settings.look, SCENE.view_settings.exposure)
    world = SCENE.world
    SCENE.world = None
    SCENE.view_settings.view_transform = 'Raw'
    SCENE.view_settings.look = 'None'
    SCENE.view_settings.exposure = 0.0
    filt = SCENE.cycles.filter_width
    SCENE.cycles.filter_width = 0.01
    denoise = SCENE.cycles.use_denoising
    SCENE.cycles.use_denoising = False
    _render(Path(out_dir) / "depth.exr", width, 1, fmt='OPEN_EXR', half=True)
    SCENE.cycles.use_denoising = denoise
    SCENE.cycles.filter_width = filt
    SCENE.world = world
    SCENE.view_settings.view_transform, SCENE.view_settings.look, SCENE.view_settings.exposure = view
    _override(None)
