"""Builds the low-poly fighter model (rigid segments) and exports it as glTF.

Run headless (Blender 4.2+ / 5.x):
    blender --background --factory-startup --python tools/blender/build_fighter.py -- \
        [out=assets/models/fighter_brawler.glb] [preview=<dir>]

One mesh object per FighterVisual joint, named after it (torso, head, sh_l,
el_l, hip_l, kn_l, ...), its origin on the joint pivot and parented like the
visual's rig, so the game can rebuild the pose rig from the file and merge
the parts into one rigidly skinned mesh (every vertex follows one bone).
Extra parts: `pelvis` (on the hips, no rotation of its own) and `belly`
(unit sphere, scaled per character by CharacterDef.belly_radius).

Colours are palette slots, not textures: every vertex's UV.x is the slot
centre ((slot + 0.5) / PALETTE_SIZE). The game's toon shader looks the slot
up in a per-fighter colour array, so team colours are a shader parameter.
Materials are exported only so a viewer (and `preview=`) shows colours.

Coordinates below are Godot's (x right, y up, forward = -z, metres),
converted to Blender's z-up on vertex creation; the glTF exporter's +Y up
conversion turns them back exactly.

Proportions: chunky heroic (big chest, fists and boots, small head).
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# --- palette slots (keep in sync with presentation/fighter/fighter_model.gd) ---
PALETTE_SIZE = 8
PRIMARY, PRIMARY_DARK, SKIN, CLOTH, TRIM, HAIR, GOLD, SOLE = range(8)
# Preview colours only (the game assigns its own per fighter).
PREVIEW = {
    PRIMARY: (0.80, 0.40, 0.20), PRIMARY_DARK: (0.42, 0.18, 0.08), SKIN: (0.93, 0.74, 0.58),
    CLOTH: (0.16, 0.17, 0.24), TRIM: (0.95, 0.93, 0.86), HAIR: (0.07, 0.06, 0.08),
    GOLD: (0.95, 0.72, 0.20), SOLE: (0.22, 0.20, 0.20),
}

# --- joint layout: name -> (parent, pivot relative to the parent) ----------------
# Mirrors FighterVisual's rig (pelvis 0.95 m up, shoulders, elbows, hips, knees).
SHOULDER = (0.29, 0.58, 0.0)
JOINTS = {
    "pelvis": (None, (0.0, 0.95, 0.0)),
    "torso": ("pelvis", (0.0, 0.0, 0.0)),
    "head": ("torso", (0.0, 0.68, 0.0)),
    "belly": ("torso", (0.0, 0.0, 0.0)),
}
for _side, _sfx in ((-1.0, "_l"), (1.0, "_r")):
    JOINTS["sh" + _sfx] = ("torso", (SHOULDER[0] * _side, SHOULDER[1], 0.0))
    JOINTS["el" + _sfx] = ("sh" + _sfx, (0.0, -0.32, 0.0))
    JOINTS["hip" + _sfx] = ("pelvis", (0.12 * _side, 0.0, 0.0))
    JOINTS["kn" + _sfx] = ("hip" + _sfx, (0.0, -0.46, 0.0))


def gd(v):
    """Godot (x, y, z) -> Blender (x, -z, y)."""
    return Vector((v[0], -v[2], v[1]))


class Part:
    """Accumulates primitives for one joint's mesh."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _finish(self, verts, faces, slot, smooth):
        bv = [self.bm.verts.new(gd(p)) for p in verts]
        for f in faces:
            face = self.bm.faces.new([bv[i] for i in f])
            face.smooth = smooth
            face.material_index = slot
            for loop in face.loops:
                loop[self.uv].uv = ((slot + 0.5) / PALETTE_SIZE, 0.5)

    def frustum(self, y0, y1, bottom, top, slot, offset=(0.0, 0.0, 0.0), smooth=False):
        """Tapered box from y0 to y1; bottom/top = (width, depth)."""
        ox, oy, oz = offset
        verts = []
        for y, (w, d) in ((y0, bottom), (y1, top)):
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                verts.append((ox + sx * w / 2, oy + y, oz + sz * d / 2))
        faces = [(0, 1, 2, 3)[::-1], (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self._finish(verts, faces, slot, smooth)

    def box(self, center, size, slot, smooth=False):
        cx, cy, cz = center
        w, h, d = size
        self.frustum(-h / 2, h / 2, (w, d), (w, d), slot, (cx, cy, cz), smooth)

    def prism(self, p0, p1, r0, r1, slot, sides=6, smooth=True, cap=True, squash=1.0, twist=0.0):
        """Tapered n-gon prism from p0 (radius r0) to p1 (radius r1).
        squash scales the cross-section depth (z of the local frame)."""
        a, b = Vector(p0), Vector(p1)
        axis = (b - a).normalized()
        ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(ref).normalized()
        v = axis.cross(u).normalized()
        verts = []
        for c, r in ((a, r0), (b, r1)):
            for i in range(sides):
                t = math.tau * i / sides + twist
                p = c + (u * math.cos(t) + v * math.sin(t) * squash) * r
                verts.append(tuple(p))
        faces = []
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((i, j, sides + j, sides + i))
        if cap:
            faces.append(tuple(range(sides))[::-1])
            faces.append(tuple(range(sides, 2 * sides)))
        # Winding: make faces point away from the axis.
        self._finish(verts, faces, slot, smooth)

    def cone(self, base, tip, r, slot, sides=4):
        a, b = Vector(base), Vector(tip)
        axis = (b - a).normalized()
        ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
        u = axis.cross(ref).normalized()
        v = axis.cross(u).normalized()
        verts = [tuple(a + (u * math.cos(math.tau * i / sides) + v * math.sin(math.tau * i / sides)) * r)
                 for i in range(sides)]
        verts.append(tuple(b))
        faces = [(i, (i + 1) % sides, sides) for i in range(sides)]
        faces.append(tuple(range(sides))[::-1])
        self._finish(verts, faces, slot, False)

    def blob(self, center, radii, slot, subdiv=1, smooth=True):
        """Low-poly ellipsoid (icosphere)."""
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
        verts = [(center[0] + v.co.x * radii[0], center[1] + v.co.y * radii[1],
                  center[2] + v.co.z * radii[2]) for v in tmp.verts]
        faces = [tuple(v.index for v in f.verts) for f in tmp.faces]
        tmp.free()
        self._finish(verts, faces, slot, smooth)

    def to_object(self, materials):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in materials:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


# --- the Brawler -------------------------------------------------------------------

def build_parts():
    parts = {name: Part(name) for name in JOINTS}

    p = parts["pelvis"]
    p.frustum(-0.12, 0.06, (0.34, 0.24), (0.38, 0.25), CLOTH)       # hips
    p.frustum(0.03, 0.11, (0.40, 0.27), (0.40, 0.27), PRIMARY_DARK)  # belt
    p.box((0.0, 0.07, -0.14), (0.09, 0.07, 0.03), GOLD)               # buckle
    p.frustum(-0.02, 0.10, (0.12, 0.02), (0.14, 0.02), PRIMARY_DARK, (0.0, -0.08, -0.13))  # belt tail

    t = parts["torso"]
    t.prism((0, 0.08, 0), (0, 0.34, 0), 0.17, 0.21, SKIN, sides=8, squash=0.8)  # waist
    t.frustum(0.30, 0.66, (0.40, 0.31), (0.66, 0.40), PRIMARY, (0.0, 0.0, 0.015))  # chest (V)
    t.frustum(0.26, 0.31, (0.38, 0.27), (0.42, 0.29), PRIMARY_DARK)   # vest hem
    t.frustum(0.38, 0.62, (0.10, 0.01), (0.20, 0.01), SKIN, (0.0, 0.0, -0.181))  # open collar V
    t.prism((0, 0.62, 0.0), (0, 0.74, 0.0), 0.085, 0.075, SKIN, sides=6)  # neck
    for side in (-1.0, 1.0):
        t.blob((0.33 * side, 0.62, 0.0), (0.14, 0.12, 0.15), PRIMARY_DARK)  # shoulder pads
        t.box((0.33 * side, 0.70, 0.0), (0.06, 0.03, 0.16), TRIM)            # pad stripe

    h = parts["head"]
    h.blob((0.0, 0.13, 0.0), (0.115, 0.13, 0.125), SKIN)               # skull
    h.frustum(0.0, 0.11, (0.13, 0.15), (0.18, 0.19), SKIN, (0.0, 0.0, -0.02))  # square jaw
    h.prism((0, 0.15, 0), (0, 0.19, 0), 0.128, 0.128, TRIM, sides=8)  # headband
    h.box((0.0, 0.12, -0.12), (0.12, 0.022, 0.02), HAIR)               # brow line (eyes)
    h.blob((0.0, 0.20, 0.02), (0.125, 0.085, 0.13), HAIR)              # hair cap
    for x, z, tx, ty, tz in ((0.0, -0.05, 0.0, 0.30, -0.07), (-0.07, 0.0, -0.15, 0.30, 0.04),
                             (0.07, 0.0, 0.15, 0.30, 0.04), (0.0, 0.06, 0.0, 0.29, 0.18),
                             (-0.06, 0.07, -0.14, 0.25, 0.15), (0.06, 0.07, 0.14, 0.25, 0.15)):
        h.cone((x, 0.22, z), (tx, ty, tz), 0.06, HAIR)                 # spikes
    for side in (-1.0, 1.0):
        h.box((0.07 * side, 0.205, 0.10), (0.03, 0.02, 0.12), TRIM)    # headband tails
        h.box((0.07 * side, 0.15, 0.17), (0.025, 0.09, 0.02), TRIM)

    b = parts["belly"]
    b.blob((0.0, 0.0, 0.0), (1.0, 1.0, 1.0), PRIMARY, subdiv=1)

    for side, sfx in ((-1.0, "_l"), (1.0, "_r")):
        a = parts["sh" + sfx]
        a.blob((0.02 * side, -0.04, 0.0), (0.11, 0.11, 0.11), SKIN)    # deltoid
        a.prism((0.01 * side, -0.06, 0), (0, -0.30, 0), 0.095, 0.075, SKIN, sides=7)  # bicep
        f = parts["el" + sfx]
        f.prism((0, 0.0, 0), (0, -0.22, 0), 0.08, 0.105, SKIN, sides=7)  # forearm (Popeye-ish)
        f.prism((0, -0.18, 0), (0, -0.26, 0), 0.112, 0.112, TRIM, sides=7)  # wrist wrap
        f.frustum(-0.41, -0.25, (0.19, 0.17), (0.22, 0.19), PRIMARY_DARK)  # big fist
        f.box((0.0, -0.30, -0.095), (0.22, 0.06, 0.03), TRIM)            # knuckle band
        f.box((-0.115 * side, -0.31, -0.02), (0.05, 0.10, 0.08), PRIMARY_DARK)  # thumb
        th = parts["hip" + sfx]
        th.prism((0, 0.04, 0), (0, -0.44, 0), 0.125, 0.10, CLOTH, sides=7)  # baggy thigh
        sh = parts["kn" + sfx]
        sh.prism((0, 0.0, 0), (0, -0.30, 0), 0.10, 0.12, CLOTH, sides=7)  # flared pant leg
        sh.prism((0, -0.26, 0), (0, -0.42, 0), 0.11, 0.10, PRIMARY, sides=7)  # boot shaft
        sh.frustum(-0.47, -0.35, (0.20, 0.30), (0.17, 0.22), PRIMARY, (0.0, 0.0, -0.05))  # boot
        sh.box((0.0, -0.475, -0.055), (0.21, 0.035, 0.31), SOLE)        # sole (floor at -0.49)
        sh.box((0.0, -0.32, -0.105), (0.13, 0.03, 0.02), TRIM)         # boot strap
    return parts


def make_materials():
    mats = []
    for slot in range(PALETTE_SIZE):
        m = bpy.data.materials.new("slot_%d" % slot)
        c = PREVIEW[slot]
        m.diffuse_color = (c[0], c[1], c[2], 1.0)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf is not None:
            bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
            bsdf.inputs["Roughness"].default_value = 0.8
        mats.append(m)
    return mats


def assemble(parts, mats):
    objs = {name: part.to_object(mats) for name, part in parts.items()}
    for name, (parent, pivot) in JOINTS.items():
        ob = objs[name]
        if parent is not None:
            ob.parent = objs[parent]
        ob.location = gd(pivot)
    bpy.context.view_layer.update()
    return objs


def render_preview(out_dir):
    """Workbench turnaround (front, 3/4, side, back) for review."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 420
    scene.render.resolution_y = 620
    scene.render.film_transparent = False
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.3
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    os.makedirs(out_dir, exist_ok=True)
    belly = bpy.data.objects.get("belly")
    if belly is not None:
        belly.hide_render = True  # unit sphere; the game scales it per character
    target = gd((0.0, 1.0, 0.0))
    for label, yaw in (("front", 0.0), ("three_quarter", 35.0), ("side", 90.0), ("back", 180.0)):
        r = math.radians(yaw)
        # Godot forward is -z: the front view looks from -z toward +z.
        pos = gd((5.0 * math.sin(r), 1.15, -5.0 * math.cos(r)))
        cam.location = pos
        direction = target - pos
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, "fighter_%s.png" % label)
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = dict(a.split("=", 1) for a in argv if "=" in a)
    out = args.get("out", "assets/models/fighter_brawler.glb")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    assemble(build_parts(), mats)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(out), export_format="GLB", export_yup=True,
                              export_apply=False, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT")
    print("BUILD_FIGHTER wrote", out)
    if "preview" in args:
        render_preview(args["preview"])
        print("BUILD_FIGHTER preview in", args["preview"])


main()
