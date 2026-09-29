"""What the 3D board scenes in this folder share.

Not run on its own: `sky_islands.py` and `volcano.py` import it, call
`setup()` with their palette and `camera()` with their framing, build, and
finish with `export()`.

The contract with the game (`scripts/board3d.gd`) lives here:

- Materials are named, and the game swaps each for a toon shader *by name*.
  Blender's base colour is the lit tone; the shadow, ink and extras are in
  `board3d.gd`'s per-scene table.
- Vertex colour RGB multiplies the lit and shadow tones. Vertex colour alpha
  is a glow mask (1 = none, 0 = full), for rock that sits next to lava.
- Ribbons (water, lava flows) carry UV.x across, UV.y along in units of the
  ribbon's width, and UV2.x 0..1 along, for fades. glTF flips V on the way
  out, so in Godot UV.y *decreases* along the ribbon.
- Everything that moves is keyed on one loop of `LOOP` seconds, every motion
  a whole number of times inside it, and the scene exports as one animation.

Layout is by screen position: `place(sx, sy, d)` is (sx, sy) on the 9:16
frame, -1..1 edge to edge, `d` units in front of the camera. The game pins the
camera's width, so a taller phone sees more above and below (to about
sy = +-1.2) and never less at the sides. On a phone the board covers the
middle half of the width from sy = +0.8 to -0.3 and the keyboard everything
below sy = -0.3, so what matters is at the sides and in the top half.
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[2]
TAU = math.tau
FPS = 24
LOOP = 20.0
FRAMES = int(FPS * LOOP)
ASPECT = 1080.0 / 1920.0

SCENE = None
PALETTE = {}
MATS = {}
CAMERA = None
CAM_M = Matrix()
TX = 1.0
TY = 1.0


# ------------------------------------------------------------------ helpers

def srgb(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
                 for x in c)


def clamp(x, a=0.0, b=1.0):
    return a if x < a else b if x > b else x


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mul(a, b):
    return tuple(x * y for x, y in zip(a, b))


def n3(x, y, z):
    return noise.noise(Vector((x, y, z)))


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def setup(palette):
    """Empty the scene and set the loop. `palette` is {material: sRGB hex}."""
    global SCENE, PALETTE, MATS
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras,
                 bpy.data.lights, bpy.data.actions, bpy.data.armatures,
                 bpy.data.curves):
        for block in list(coll):
            coll.remove(block)
    sc = bpy.context.scene
    sc.render.fps = FPS
    sc.frame_start = 0
    sc.frame_end = FRAMES
    sc.render.resolution_x = 1080
    sc.render.resolution_y = 1920
    # Linear keys: the curves are dense samples of sines, and a Bezier
    # between two samples either side of a jump would overshoot across the
    # frame.
    bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
    SCENE = sc
    PALETTE = dict(palette)
    MATS = {}
    return sc


def material(name):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    col = srgb(PALETTE[name]) + (1.0,)
    bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'),
                None)
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = col
        bsdf.inputs["Roughness"].default_value = 1.0
    m.diffuse_color = col
    MATS[name] = m
    return m


def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    o.empty_display_size = 0.5
    SCENE.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o


def new_bm():
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("Color")
    return bm, col


def bm_object(name, bm, mat_name, parent=None, loc=(0, 0, 0), smooth=True,
              recalc=True, normals=None):
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    if normals is not None:
        me.normals_split_custom_set_from_vertices(normals)
    # A list of materials pairs with each face's material_index.
    for name_ in (mat_name if isinstance(mat_name, (list, tuple)) else [mat_name]):
        me.materials.append(material(name_))
    attr = me.color_attributes.get("Color")
    if attr is not None:
        me.color_attributes.active_color = attr
        try:
            me.color_attributes.render_color_index = \
                me.color_attributes.active_color_index
        except Exception:
            pass
    o = bpy.data.objects.new(name, me)
    SCENE.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o


def lathe(bm, col, profile, seg, xform=Matrix(), offset=None, color=None):
    """Spin a (radius, z) profile, bottom to top. A zero radius is a pole.

    `offset(t)` shifts each ring sideways (t runs 0..1 up the profile), which
    is how a trunk leans; `color(t)` paints each ring.
    """
    rings = []
    n = len(profile)
    for k, (r, z) in enumerate(profile):
        t = k / max(1, n - 1)
        off = offset(t) if offset else Vector((0, 0, 0))
        rgb = color(t) if color else (1.0, 1.0, 1.0)
        if r <= 1e-6:
            v = bm.verts.new(xform @ (Vector((0, 0, z)) + off))
            v[col] = rgb + (1.0,)
            rings.append([v])
            continue
        ring = []
        for i in range(seg):
            a = TAU * i / seg
            v = bm.verts.new(xform @ (Vector((r * math.cos(a),
                                              r * math.sin(a), z)) + off))
            v[col] = rgb + (1.0,)
            ring.append(v)
        rings.append(ring)
    bridge_rings(bm, rings)
    return [v for ring in rings for v in ring]


def bridge_rings(bm, rings):
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1 and len(b) == 1:
            continue
        if len(a) == 1:
            m = len(b)
            for i in range(m):
                bm.faces.new((a[0], b[(i + 1) % m], b[i]))
        elif len(b) == 1:
            m = len(a)
            for i in range(m):
                bm.faces.new((a[i], a[(i + 1) % m], b[0]))
        else:
            m = len(a)
            for i in range(m):
                bm.faces.new((a[i], a[(i + 1) % m], b[(i + 1) % m], b[i]))


def puff(bm, col, center, radius, subdiv=2, squash=1.0, rgb=(1, 1, 1),
         ao=0.0):
    xf = Matrix.Translation(center) @ Matrix.Diagonal((radius, radius,
                                                       radius * squash, 1.0))
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0,
                                     matrix=xf)
    for v in ret["verts"]:
        up = clamp((v.co.z - center.z) / (radius * squash) * 0.5 + 0.5)
        k = 1.0 - ao + ao * up
        v[col] = (rgb[0] * k, rgb[1] * k, rgb[2] * k, 1.0)
    return ret["verts"]


def keyframes(obj, fn, step=2):
    """Key `fn(t)` -> (loc, rot, scale) over the loop, t running 0..1.

    Any of the three may be None to leave that channel unkeyed.
    """
    for f in range(0, FRAMES + 1, step):
        loc, rot, scl = fn(f / FRAMES)
        if loc is not None:
            obj.location = loc
            obj.keyframe_insert("location", frame=f)
        if rot is not None:
            obj.rotation_euler = rot
            obj.keyframe_insert("rotation_euler", frame=f)
        if scl is not None:
            obj.scale = scl
            obj.keyframe_insert("scale", frame=f)


def crossing(t, start, span):
    """0..1 progress of something that crosses the frame once per loop.

    It enters at loop phase `start`, takes `span` of the loop to cross, and
    waits out of frame for the rest. Returns (progress, visible_scale).
    """
    p = (t - start) % 1.0
    u = p / span
    if u > 1.0:
        return 1.0 + (u - 1.0) * span * 0.2, 0.0   # parked past the far edge
    # Zero scale for the first and last sliver, where the jump happens.
    edge = 2.5 / (FRAMES * span)
    s = 0.0 if (u < edge or u > 1.0 - edge) else 1.0
    return u, s


# ------------------------------------------------------------------- camera

def camera(vfov=56.0, pitch=0.0, loc=(0.0, 0.0, 0.0), sway=(0.28, 0.14),
           turn=(0.35, 0.8), clip_end=400.0, yaw=0.0):
    """The camera, its slow drift, and the frame `place()` works in.

    `pitch` is degrees above level, `yaw` degrees to the right of straight
    down +Y. The drift is small on purpose: near
    things should slide over far ones, and the backdrop should feel alive
    without the phone seeming to sway.
    """
    global CAMERA, CAM_M, TX, TY
    data = bpy.data.cameras.new("Camera")
    data.sensor_fit = 'VERTICAL'
    data.angle_y = math.radians(vfov)
    data.clip_start = 0.3
    data.clip_end = clip_end
    cam = bpy.data.objects.new("Camera", data)
    SCENE.collection.objects.link(cam)
    SCENE.camera = cam
    base_rot = Euler((math.radians(90.0 + pitch), 0.0, -math.radians(yaw)))
    cam.rotation_euler = base_rot
    base = Vector(loc)
    cam.location = base

    def f(t):
        p = base + Vector((sway[0] * math.sin(TAU * t), 0.0,
                           sway[1] * math.sin(TAU * 2 * t + 1.0)))
        rot = Euler((base_rot.x + math.radians(turn[0]) * math.sin(TAU * t + 2.1),
                     0.0,
                     base_rot.z + math.radians(turn[1]) * math.sin(TAU * t + 0.6)))
        return p, rot, None
    keyframes(cam, f, step=2)
    CAMERA = cam
    CAM_M = Matrix.Translation(base) @ base_rot.to_matrix().to_4x4()
    TY = math.tan(math.radians(vfov) * 0.5)
    TX = TY * ASPECT
    return cam


def place(sx, sy, d):
    return CAM_M @ Vector((sx * d * TX, sy * d * TY, -d))


def half_width(d):
    """Half the frame's width, in world units, `d` in front of the camera."""
    return d * TX


def ground(sx, sy, z=0.0):
    """Where the ray through (sx, sy) meets the plane at height `z`."""
    o = CAM_M.translation
    ray = place(sx, sy, 1.0) - o
    if ray.z >= -1e-6:
        return None
    return o + ray * ((z - o.z) / ray.z)


# ---------------------------------------------------------------- ribbons

def ribbon(path, widths, bulge=0.0, v_scale=1.0, fade=False, normal_hint=None,
           up=Vector((0, 0, 1))):
    """A strip along `path`, three vertices across, `bulge` pushing the middle
    out along the face normal. See the module notes for its UVs."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    rows = []
    uvs = {}
    length = 0.0
    n = len(path)
    for k, p in enumerate(path):
        if k > 0:
            length += (p - path[k - 1]).length
        tan = (path[min(k + 1, n - 1)] - path[max(k - 1, 0)]).normalized()
        u_ = up(k) if callable(up) else up
        across = tan.cross(u_)
        if across.length < 1e-4 and normal_hint is not None:
            across = normal_hint.cross(u_)
        if across.length < 1e-4:
            across = Vector((1, 0, 0))
        across.normalize()
        face = across.cross(tan).normalized()
        if normal_hint is not None and face.dot(normal_hint) < 0:
            face = -face
        row = []
        for j, u in enumerate((0.0, 0.5, 1.0)):
            off = across * (u - 0.5) * widths[k]
            if j == 1:
                off += face * bulge
            v = bm.verts.new(p + off)
            uvs[v] = ((u, length / v_scale), (k / (n - 1) if fade else 0.0, 0.0))
            row.append(v)
        rows.append(row)
    for a, b in zip(rows, rows[1:]):
        for j in range(2):
            f = bm.faces.new((a[j], a[j + 1], b[j + 1], b[j]))
            for loop in f.loops:
                loop[uv].uv, loop[uv2].uv = uvs[loop.vert]
    return bm


# ----------------------------------------------------------------- clouds

def cloud(name, sx, sy, d, size, n, seed, drift=0.35, subdiv=None,
          mat="Cloud", under=(0.82, 0.86, 1.0), flat=True, pos=None):
    """A cumulus: overlapping spheres, biggest in the middle, flat underneath
    unless `flat` is off. `under` tints the underside through vertex colour."""
    rnd = random.Random(seed)
    wx, wy, wz = size
    if subdiv is None:
        subdiv = 3 if d < 45 else 2
    bm, col = new_bm()
    for i in range(n):
        u = rnd.uniform(-1, 1)
        taper = 1.0 - 0.55 * abs(u) ** 1.5
        r = wz * rnd.uniform(0.55, 1.0) * taper
        c = Vector((u * wx, rnd.uniform(-1, 1) * wy,
                    r * rnd.uniform(0.0, 0.55) * taper))
        puff(bm, col, c, r, subdiv)
    floor = -0.12 * wz
    for v in bm.verts:
        if flat and v.co.z < floor:
            v.co.z = floor + (v.co.z - floor) * 0.15
        t = clamp((v.co.z - floor) / (wz * 1.3))
        v[col] = mix(under, (1.0, 1.0, 1.0), t ** 0.6) + (1.0,)
    if pos is None:
        pos = place(sx, sy, d)
    o = bm_object(name, bm, mat, None, pos)
    if drift > 0:
        amp = drift * wx * 0.25
        ph = rnd.uniform(0, TAU)
        ph2 = rnd.uniform(0, TAU)
        k = rnd.choice([1, 1, 2])

        def f(t):
            return (pos + Vector((amp * math.sin(TAU * t + ph), 0,
                                  amp * 0.2 * math.sin(TAU * k * t + ph2))),
                    None,
                    (1.0, 1.0, 1.0 + 0.03 * math.sin(TAU * k * t + ph2)))
        keyframes(o, f, step=4)
    return o


def crossing_cloud(name, sy, d, size, n, seed, start, span, direction=1,
                   **kw):
    o = cloud(name, 0.0, sy, d, size, n, seed, drift=0.0, **kw)
    half = half_width(d) * 1.25 + size[0] * 1.2
    row = place(0.0, sy, d)

    def f(t):
        u, vis = crossing(t, start, span)
        x = (-half + 2 * half * u) * direction
        return row + Vector((x, 0, 0)), None, (vis, vis, vis)
    keyframes(o, f, step=1)
    return o


def catmull(points, per=10):
    """A Catmull-Rom curve through `points` (2D or 3D), `per` samples a span."""
    out = []
    pts = [points[0]] + list(points) + [points[-1]]
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = (Vector(pts[i + j]) for j in (-1, 0, 1, 2))
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t
                              + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(Vector(points[-1]))
    return out


# ----------------------------------------------------------------- ground

def terrain(name, mat, x0, x1, y0, y1, nx, ny, height, color=None, ypow=1.0,
            parent=None):
    """A heightfield over x0..x1, y0..y1: `height(x, y)` in metres, and
    `color(x, y, z)` an RGBA per vertex. `ypow` over 1 packs the rows toward
    y0, which is the camera's end, where the detail is seen."""
    bm, col = new_bm()
    rows = []
    for j in range(ny + 1):
        y = y0 + (y1 - y0) * (j / ny) ** ypow
        row = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            z = height(x, y)
            v = bm.verts.new((x, y, z))
            v[col] = color(x, y, z) if color else (1.0, 1.0, 1.0, 1.0)
            row.append(v)
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    return bm_object(name, bm, mat, parent, recalc=False)


def stamp_sway(bm, col, first, base_z, top=20.0):
    """Mark the vertices from index `first` on as one tree standing at
    `base_z`: vertex alpha becomes 1 - height above its foot / `top`, which
    is what the toon shader's `sway_alpha` sways by. Call after building each
    tree into a mesh that holds many."""
    bm.verts.ensure_lookup_table()
    for v in bm.verts[first:]:
        c = v[col]
        v[col] = (c[0], c[1], c[2], 1.0 - clamp((v.co.z - base_z) / top))


def rock(bm, col, center, size, seed, squash=0.75, subdiv=2, rgb=(1, 1, 1), under=0.7):
    """A lumpy boulder with a flattened foot, darker underneath."""
    verts = puff(bm, col, Vector(center), size, subdiv, squash)
    for v in verts:
        d = v.co - Vector(center)
        k = 1.0 + 0.22 * n3(d.x * 2.2 / size + seed, d.y * 2.2 / size, d.z * 2.2 / size)
        v.co = Vector(center) + d * k
        if v.co.z < center[2] - size * squash * 0.35:
            v.co.z = center[2] - size * squash * 0.35
        up = clamp((v.co.z - center[2]) / (size * squash) * 0.5 + 0.5)
        m = under + (1.0 - under) * up
        v[col] = (rgb[0] * m, rgb[1] * m, rgb[2] * m, 1.0)
    return verts


def ray_quads(items):
    """Shafts of light, as quads facing the camera's axis. `items` is
    [(start, end, width, rgb, seed)]; UV.x runs across, UV2.x along from the
    start. See boards/3d/ray.gdshader."""
    bm = bmesh.new()
    col = bm.verts.layers.float_color.new("Color")
    uv = bm.loops.layers.uv.new("UVMap")
    uv2 = bm.loops.layers.uv.new("UV2")
    view = (CAM_M.to_3x3() @ Vector((0, 0, -1))).normalized()
    for start, end, width, rgb, seed in items:
        a, b = Vector(start), Vector(end)
        across = (b - a).cross(view).normalized() * width * 0.5
        vs = [bm.verts.new(p) for p in (a - across, a + across, b + across * 1.8, b - across * 1.8)]
        for v in vs:
            v[col] = tuple(rgb) + (seed,)
        f = bm.faces.new(vs)
        for loop, (u, w) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = (u, 0.0)
            loop[uv2].uv = (w, 0.0)
    return bm


# ----------------------------------------------------------------- export

def export(name):
    """Save the .blend under build/ and the .glb the game loads."""
    glb = ROOT / "boards" / "3d" / (name + ".glb")
    blend = ROOT / "build" / "boards3d" / (name + ".blend")
    glb.parent.mkdir(parents=True, exist_ok=True)
    blend.parent.mkdir(parents=True, exist_ok=True)
    SCENE.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.ops.export_scene.gltf(
        filepath=str(glb),
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_cameras=True,
        export_vertex_color='ACTIVE',
        export_animations=True,
        export_animation_mode='SCENE',
        export_anim_scene_split_object=False,
        export_frame_range=True,
        export_force_sampling=True,
        export_optimize_animation_size=True,
    )
    tris = 0
    for o in SCENE.objects:
        if o.type == 'MESH':
            o.data.calc_loop_triangles()
            tris += len(o.data.loop_triangles)
    print("[%s] %d objects, %d triangles -> %s"
          % (name, len(SCENE.objects), tris, glb))
