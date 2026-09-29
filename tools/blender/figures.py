"""People for the 3D boards: one smooth, skinned body each, and a walk.

A body starts as a stick skeleton (joints and the sticks between them) that
Blender's Skin modifier wraps in a hull and Subdivision Surface rounds off.
The result is a single continuous mesh: hips flow into legs and shoulders
into arms, with no seams and nothing that reads as stacked blocks.

It is then rigged by hand. Bones run along the same sticks, and every vertex
is weighted by its distance to them, but only between the nearest bone and
that bone's own parent and children, so a swinging arm never drags the ribs
along with it and the two legs never pull on each other.

Every bone is rolled so its local X axis points to the character's right,
which makes every swing a rotation about X with one sign convention:

    thigh, shin, upper arm, forearm   +X swings the far end forward
    hips, spine, chest, head          +X leans back
    foot                              +X lifts the toe
    twist                             about the bone's own Y

The walk is keyed on the bones at a whole number of strides per loop, and the
stride length is derived from the swing, so feet travel with the ground
rather than skating over it.
"""

import math
import random

import bpy
from mathutils import Euler, Matrix, Vector

import toonkit as tk
from toonkit import TAU

# name: (position, (radius across, radius front to back)), for a 1.75 m adult
# facing +Y with +X to their right.
JOINTS = {
    "pelvis": ((0.0, 0.0, 0.95), (0.165, 0.125)),
    "spine": ((0.0, 0.005, 1.12), (0.16, 0.125)),
    "chest": ((0.0, 0.0, 1.31), (0.2, 0.135)),
    "neck": ((0.0, 0.0, 1.47), (0.06, 0.06)),
    "head": ((0.0, 0.015, 1.585), (0.104, 0.114)),
    "crown": ((0.0, 0.0, 1.69), (0.08, 0.084)),
}
for side, sx in (("L", -1.0), ("R", 1.0)):
    JOINTS.update({
        "shoulder." + side: ((0.2 * sx, 0.0, 1.39), (0.065, 0.065)),
        "elbow." + side: ((0.235 * sx, -0.005, 1.12), (0.054, 0.054)),
        "wrist." + side: ((0.245 * sx, 0.02, 0.9), (0.04, 0.036)),
        "hand." + side: ((0.245 * sx, 0.03, 0.82), (0.038, 0.028)),
        "hip." + side: ((0.098 * sx, 0.0, 0.9), (0.092, 0.092)),
        "knee." + side: ((0.1 * sx, 0.015, 0.5), (0.064, 0.064)),
        "ankle." + side: ((0.1 * sx, -0.01, 0.09), (0.05, 0.05)),
        "toe." + side: ((0.1 * sx, 0.12, 0.045), (0.048, 0.036)),
    })

EDGES = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck"),
         ("neck", "head"), ("head", "crown")]
for s in ("L", "R"):
    EDGES += [("chest", "shoulder." + s), ("shoulder." + s, "elbow." + s),
              ("elbow." + s, "wrist." + s), ("wrist." + s, "hand." + s),
              ("pelvis", "hip." + s), ("hip." + s, "knee." + s),
              ("knee." + s, "ankle." + s), ("ankle." + s, "toe." + s)]

# (bone, head joint, tail joint, parent, roll: which way its local Z faces)
BONES = [
    ("hips", "pelvis", "spine", None, "back"),
    ("spine", "spine", "chest", "hips", "back"),
    ("chest", "chest", "neck", "spine", "back"),
    ("head", "neck", "crown", "chest", "back"),
]
for s in ("L", "R"):
    BONES += [
        ("upper_arm." + s, "shoulder." + s, "elbow." + s, "chest", "front"),
        ("forearm." + s, "elbow." + s, "hand." + s, "upper_arm." + s, "front"),
        ("thigh." + s, "hip." + s, "knee." + s, "hips", "front"),
        ("shin." + s, "knee." + s, "ankle." + s, "thigh." + s, "front"),
        ("foot." + s, "ankle." + s, "toe." + s, "shin." + s, "up"),
    ]
PARENT = {b[0]: b[3] for b in BONES}
CHILDREN = {b[0]: [c[0] for c in BONES if c[3] == b[0]] for b in BONES}

REGION = {"hips": "legs", "spine": "coat", "chest": "coat", "head": "head"}
for s in ("L", "R"):
    REGION.update({"upper_arm." + s: "coat", "forearm." + s: "coat",
                   "thigh." + s: "legs", "shin." + s: "legs", "foot." + s: "shoes"})

SKIN_TONES = [(0.93, 0.76, 0.62), (0.78, 0.57, 0.42), (0.55, 0.38, 0.27),
              (0.36, 0.24, 0.17), (0.98, 0.84, 0.72)]
HAIR = [(0.05, 0.04, 0.035), (0.16, 0.09, 0.05), (0.3, 0.18, 0.08), (0.62, 0.48, 0.25),
        (0.08, 0.06, 0.06)]


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (a + ab * t - p).length


def body(name, height=1.75, build=1.0, coat=(0.2, 0.22, 0.3), legs=(0.1, 0.1, 0.13),
         skin=None, hood=False, shoes=(0.06, 0.06, 0.07), seed=0):
    """One person: returns the armature object (the mesh rides on it).

    `build` thickens the torso and arms (a heavy coat, a big frame); `hood`
    paints the head in the coat's colour and rounds it out.
    """
    rnd = random.Random(seed)
    k = height / 1.75
    skin = skin or rnd.choice(SKIN_TONES)
    hair = rnd.choice(HAIR)
    joints = {}
    for n, (p, r) in JOINTS.items():
        rx, ry = r
        if n in ("spine", "chest", "pelvis") or n.startswith(("shoulder", "elbow")):
            rx, ry = rx * build, ry * (0.5 + 0.5 * build)
        if hood and n in ("head", "crown"):
            rx, ry = rx * 1.18, ry * 1.2
        joints[n] = (Vector(p) * k, (rx * k, ry * k))

    # The skeleton, skinned and smoothed, baked to a plain mesh.
    names = list(joints)
    me = bpy.data.meshes.new(name + "_sticks")
    me.from_pydata([joints[n][0] for n in names],
                   [(names.index(a), names.index(b)) for a, b in EDGES], [])
    sticks = bpy.data.objects.new(name + "_sticks", me)
    tk.SCENE.collection.objects.link(sticks)
    skin_mod = sticks.modifiers.new("skin", 'SKIN')
    skin_mod.branch_smoothing = 0.6
    skin_mod.use_smooth_shade = True
    if len(me.skin_vertices) == 0:
        me.skin_vertices.new()
    sv = me.skin_vertices[0].data
    for i, n in enumerate(names):
        sv[i].radius = joints[n][1]
        sv[i].use_root = n == "pelvis"
    sub = sticks.modifiers.new("smooth", 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 1
    dg = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(sticks.evaluated_get(dg))
    mesh.name = name + "_body"
    bpy.data.objects.remove(sticks, do_unlink=True)
    bpy.data.meshes.remove(me)

    # The rig.
    arm_data = bpy.data.armatures.new(name + "_rig")
    rig = bpy.data.objects.new(name, arm_data)
    tk.SCENE.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    facing = {"back": Vector((0, -1, 0)), "front": Vector((0, 1, 0)), "up": Vector((0, 0, 1))}
    for bname, hj, tj, parent, roll in BONES:
        eb = arm_data.edit_bones.new(bname)
        eb.head = joints[hj][0]
        eb.tail = joints[tj][0]
        eb.align_roll(facing[roll])
        if parent:
            eb.parent = arm_data.edit_bones[parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.select_set(False)
    segs = {b[0]: (joints[b[1]][0], joints[b[2]][0]) for b in BONES}

    # Weights: nearest bone, blended only with its parent and children.
    obj = bpy.data.objects.new(name + "_body", mesh)
    tk.SCENE.collection.objects.link(obj)
    groups = {b[0]: obj.vertex_groups.new(name=b[0]) for b in BONES}
    region_rgb = {"coat": coat, "legs": legs, "shoes": shoes,
                  "head": coat if hood else skin}
    col = mesh.color_attributes.new("Color", 'FLOAT_COLOR', 'POINT')
    for v in mesh.vertices:
        d = {b: _seg_dist(v.co, a, c) for b, (a, c) in segs.items()}
        near = min(d, key=d.get)
        cand = [near] + CHILDREN[near] + ([PARENT[near]] if PARENT[near] else [])
        w = {b: 1.0 / (d[b] ** 5 + 1e-7) for b in cand}
        tot = sum(w.values())
        for b, x in w.items():
            if x / tot > 0.02:
                groups[b].add([v.index], x / tot, 'REPLACE')
        rgb = region_rgb[REGION[near]]
        # Hands and the face are skin whatever the region says.
        if near.startswith("forearm") and v.co.z < 0.9 * k:
            rgb = skin
        if near == "head" and hood and v.co.y > 0.05 * k and 1.52 * k < v.co.z < 1.68 * k:
            rgb = skin
        # Hair: the crown and the back of the head.
        if near == "head" and not hood and (v.co.z > 1.63 * k or
                                            (v.co.y < -0.02 * k and v.co.z > 1.53 * k)):
            rgb = hair
        col.data[v.index].color = rgb + (1.0,)
    mesh.color_attributes.active_color = col
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(tk.material("Person"))
    obj.parent = rig
    mod = obj.modifiers.new("rig", 'ARMATURE')
    mod.object = rig
    for pb in rig.pose.bones:
        pb.rotation_mode = 'XYZ'
    rig["height_k"] = k
    return rig


def umbrella(rig, rgb, seed=0):
    """An umbrella in the right hand. Call with the rig already in its
    holding pose; the canopy is fixed to the forearm from then on."""
    rnd = random.Random(seed)
    k = rig["height_k"]
    bm, col = tk.new_bm()
    ribs = 8
    R = 0.52 * k
    rings = []
    top = bm.verts.new((0, 0, 0.26 * k))
    top[col] = rgb + (1.0,)
    rings.append([top])
    for f, dz in ((0.45, 0.2), (0.8, 0.09), (1.0, 0.0)):
        ring = []
        for i in range(ribs * 3):
            a = TAU * i / (ribs * 3)
            # The cloth sags between ribs, which is what makes it an umbrella
            # and not a lampshade.
            sag = 0.0 if i % 3 == 0 else 0.035 * k * f
            v = bm.verts.new((R * f * math.cos(a), R * f * math.sin(a), dz * k - sag))
            v[col] = rgb + (1.0,)
            ring.append(v)
        rings.append(ring)
    under = bm.verts.new((0, 0, 0.12 * k))
    under[col] = tuple(c * 0.6 for c in rgb) + (1.0,)
    rings.append([under])
    tk.bridge_rings(bm, rings)
    tk.lathe(bm, col, [(0.012, -0.72 * k), (0.012, 0.26 * k)], 6,
             color=lambda t: (0.12, 0.12, 0.14))
    canopy = tk.bm_object(rig.name + "_umbrella", bm, "Umbrella")
    bpy.context.view_layer.update()
    pb = rig.pose.bones["forearm.R"]
    hand = rig.matrix_world @ pb.tail
    canopy.parent = rig
    canopy.parent_type = 'BONE'
    canopy.parent_bone = "forearm.R"
    canopy.matrix_world = Matrix.Translation(hand + Vector((0, 0.02, 0.72 * k)))
    return canopy


# ------------------------------------------------------------------ poses

def _r(deg):
    return math.radians(deg)


def walk_pose(p, hold_right=False, sway=1.0):
    """Bone rotations (degrees about X, twist about Y) at walk phase `p`."""
    pose = {}
    for s, off in (("L", 0.0), ("R", math.pi)):
        q = p + off
        thigh = 24.0 * math.sin(q) + 3.0
        bend = 6.0 + 42.0 * max(0.0, math.cos(q + 0.8)) ** 2
        pose["thigh." + s] = (thigh, 0.0)
        pose["shin." + s] = (-bend, 0.0)
        pose["foot." + s] = (bend - thigh + 6.0 * max(0.0, math.cos(q)), 0.0)
        swing = -16.0 * math.sin(q) * sway
        pose["upper_arm." + s] = (swing, 0.0)
        pose["forearm." + s] = (12.0 + 10.0 * max(0.0, -math.sin(q)), 0.0)
    if hold_right:
        pose["upper_arm.R"] = (28.0, 0.0)
        pose["forearm.R"] = (78.0, 0.0)
    pose["hips"] = (0.0, 5.0 * math.sin(p))
    pose["spine"] = (-2.0, -2.0 * math.sin(p))
    pose["chest"] = (-3.0, -5.0 * math.sin(p))
    pose["head"] = (2.0, 3.0 * math.sin(p))
    return pose


def idle_pose(t, seed, hold_right=False):
    """Standing: breathing, a slow weight shift, and a look around now and
    then. `t` is the loop phase 0..1, and every motion repeats inside it."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, TAU) for _ in range(4)]
    breathe = math.sin(TAU * 5 * t + ph[0])
    shift = math.sin(TAU * t + ph[1])
    # The head turns in steps: hold, turn, hold.
    look = math.sin(TAU * 2 * t + ph[2])
    look = math.copysign(abs(look) ** 0.35, look)
    pose = {
        "hips": (0.0, 3.0 * shift),
        "spine": (-1.0 + 0.8 * breathe, 0.0),
        "chest": (-1.5 + 1.2 * breathe, -2.0 * shift),
        "head": (1.0, 22.0 * look),
    }
    for s, sg in (("L", 1.0), ("R", -1.0)):
        pose["thigh." + s] = (2.0 + 2.0 * shift * sg, 0.0)
        pose["shin." + s] = (-3.0 - 3.0 * max(0.0, shift * sg), 0.0)
        pose["foot." + s] = (1.0, 0.0)
        pose["upper_arm." + s] = (3.0 + 1.0 * breathe, 0.0)
        pose["forearm." + s] = (10.0, 0.0)
    if hold_right:
        pose["upper_arm.R"] = (28.0, 0.0)
        pose["forearm.R"] = (78.0, 0.0)
    return pose


def apply_pose(rig, pose, frame=None):
    for bname, (x, tw) in pose.items():
        pb = rig.pose.bones[bname]
        pb.rotation_euler = Euler((_r(x), _r(tw), 0.0))
        if frame is not None:
            pb.keyframe_insert("rotation_euler", frame=frame)


# ----------------------------------------------------------------- motion

# Two steps, each about 2 * leg * sin(swing), at 1.75 m.
STRIDE = 4.0 * 0.85 * math.sin(math.radians(24.0))


def walker(rig, route, start, cycles=18, hold_right=False, step=2):
    """Walk `route` (a list of (x, y) on the ground) starting at loop phase
    `start`, and wait at one end or the other for the rest of the loop.

    Speed follows from the stride and `cycles` (strides per loop), so the
    feet keep pace with the ground. A route should begin and end somewhere
    the camera cannot see (inside a doorway, off the side of the frame),
    because that is where the figure appears and vanishes.
    """
    k = rig["height_k"]
    # A point may carry a height too, (x, y, z), for a walk up or down stairs.
    pts = [Vector((p[0], p[1], p[2] if len(p) > 2 else 0.0)) for p in route]
    lens = [(b - a).length for a, b in zip(pts, pts[1:])]
    total = sum(lens)
    # Quicken the pace, if need be, until the route fits in the loop with a
    # moment to spare; past 23 strides a loop it is a march, not a walk.
    need = math.ceil(total / (0.92 * tk.LOOP) * tk.LOOP / (STRIDE * k))
    cycles = max(cycles, need)
    if cycles > 23:
        raise ValueError("%s: a %.1f m route does not fit in the loop" % (rig.name, total))
    period = tk.LOOP / cycles
    speed = STRIDE * k / period
    dur = total / speed

    def at(dist):
        dist = max(0.0, min(total, dist))
        for a, b, L in zip(pts, pts[1:], lens):
            if dist <= L:
                return a + (b - a) * (dist / L), (b - a).normalized()
            dist -= L
        return pts[-1], (pts[-1] - pts[-2]).normalized()

    def yaw_of(d):
        # Heading from the flat part of the direction, so stairs do not tip
        # the figure forward.
        return math.atan2(-d.x, d.y) if (d.x or d.y) else 0.0

    last_yaw = None
    for f in range(0, tk.FRAMES + 1, step):
        T = f / tk.FPS
        u = (T - start * tk.LOOP) % tk.LOOP
        p = TAU * T / period
        active = u <= dur
        pos, d = at(u * speed if active else (0.0 if u > dur + (tk.LOOP - dur) / 2 else total))
        # Turn smoothly through corners: look half a metre ahead.
        _, d2 = at(u * speed + 0.5)
        dd = (d + d2).normalized() if (d + d2).length > 1e-6 else d
        bob = 0.022 * k * math.cos(2.0 * p)
        rig.location = pos + Vector((0, 0, bob))
        # Unwrapped, or a turn across +-180 degrees spins the figure round
        # the long way between two keys.
        yaw = yaw_of(dd)
        if last_yaw is not None:
            yaw = last_yaw + math.atan2(math.sin(yaw - last_yaw), math.cos(yaw - last_yaw))
        last_yaw = yaw
        rig.rotation_euler = Euler((0, 0, yaw))
        # Hidden by where they stand, never by shrinking: a skinned mesh
        # whose rig is scaled to nothing comes out of Godot's skinning as
        # triangles the size of the sky.
        rig.keyframe_insert("location", frame=f)
        rig.keyframe_insert("rotation_euler", frame=f)
        apply_pose(rig, walk_pose(p, hold_right), frame=f)


def stander(rig, pos, yaw, seed, hold_right=False, step=2):
    rig.location = Vector(pos)
    rig.rotation_euler = Euler((0, 0, yaw))
    for f in range(0, tk.FRAMES + 1, step):
        apply_pose(rig, idle_pose(f / tk.FRAMES, seed, hold_right), frame=f)
