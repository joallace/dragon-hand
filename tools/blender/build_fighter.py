"""Builds the low-poly fighter model (rigid segments) and exports it as glTF.

Run headless (Blender 4.2+ / 5.x):
    blender --background --factory-startup --python tools/blender/build_fighter.py -- \
        [char=brawler|bulk|sprite] [out=assets/models/fighter_<char>.glb] [preview=<dir>]

One body per `char` (BUILDERS), all on the same rig and palette slots; a
character picks its file with CharacterDef.model_path (empty = the Brawler).

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
The game scales every model by CharacterDef.body_scale, so a body made for
a wide character (Bulk) is written narrower where it should not widen
(head, fists, feet): see BULK_SCALE. A small one (Sprite) draws them
a little larger: SPRITE_GROW.
"""

import math
import os
import re
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
# Mirrors FighterVisual's rig (pelvis 0.95 m up; waist "torso" + "chest";
# shoulders, elbows, wrists; hips, knees, ankles: CHEST_AT, HEAD_AT,
# SHOULDER_AT, WRIST_AT, ANKLE_AT there).
CHEST = (0.0, 0.30, 0.0)
SHOULDER = (0.29, 0.28, 0.0)
WRIST = (0.0, -0.22, 0.0)
ANKLE = (0.0, -0.42, 0.0)
JOINTS = {
    "pelvis": (None, (0.0, 0.95, 0.0)),
    "torso": ("pelvis", (0.0, 0.0, 0.0)),
    "chest": ("torso", CHEST),
    "head": ("chest", (0.0, 0.38, 0.0)),
    "belly": ("torso", (0.0, 0.0, 0.0)),
}
for _side, _sfx in ((-1.0, "_l"), (1.0, "_r")):
    JOINTS["sh" + _sfx] = ("chest", (SHOULDER[0] * _side, SHOULDER[1], 0.0))
    JOINTS["el" + _sfx] = ("sh" + _sfx, (0.0, -0.32, 0.0))
    JOINTS["wr" + _sfx] = ("el" + _sfx, WRIST)
    JOINTS["hip" + _sfx] = ("pelvis", (0.12 * _side, 0.0, 0.0))
    JOINTS["kn" + _sfx] = ("hip" + _sfx, (0.0, -0.46, 0.0))
    JOINTS["an" + _sfx] = ("kn" + _sfx, ANKLE)


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

def build_brawler():
    parts = {name: Part(name) for name in JOINTS}

    p = parts["pelvis"]
    p.frustum(-0.12, 0.06, (0.34, 0.24), (0.38, 0.25), CLOTH)       # hips
    p.frustum(0.03, 0.11, (0.40, 0.27), (0.40, 0.27), PRIMARY_DARK)  # belt
    p.box((0.0, 0.07, -0.14), (0.09, 0.07, 0.03), GOLD)               # buckle
    p.frustum(-0.02, 0.10, (0.12, 0.02), (0.14, 0.02), PRIMARY_DARK, (0.0, -0.08, -0.13))  # belt tail

    t = parts["torso"]
    t.prism((0, 0.08, 0), (0, 0.34, 0), 0.17, 0.21, SKIN, sides=8, squash=0.8)  # waist
    t.frustum(0.26, 0.31, (0.38, 0.27), (0.42, 0.29), PRIMARY_DARK)   # vest hem

    c = parts["chest"]  # coordinates from the chest pivot (CHEST above the waist)
    c.frustum(0.0, 0.36, (0.40, 0.31), (0.66, 0.40), PRIMARY, (0.0, 0.0, 0.015))  # chest (V)
    c.frustum(0.08, 0.32, (0.10, 0.01), (0.20, 0.01), SKIN, (0.0, 0.0, -0.181))  # open collar V
    c.prism((0, 0.32, 0.0), (0, 0.44, 0.0), 0.085, 0.075, SKIN, sides=6)  # neck
    for side in (-1.0, 1.0):
        c.blob((0.33 * side, 0.32, 0.0), (0.14, 0.12, 0.15), PRIMARY_DARK)  # shoulder pads
        c.box((0.33 * side, 0.40, 0.0), (0.06, 0.03, 0.16), TRIM)            # pad stripe

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
        w = parts["wr" + sfx]  # from the wrist pivot (WRIST below the elbow)
        w.frustum(-0.19, -0.03, (0.19, 0.17), (0.22, 0.19), PRIMARY_DARK)  # big fist
        w.box((0.0, -0.08, -0.095), (0.22, 0.06, 0.03), TRIM)            # knuckle band
        w.box((-0.115 * side, -0.09, -0.02), (0.05, 0.10, 0.08), PRIMARY_DARK)  # thumb
        th = parts["hip" + sfx]
        th.prism((0, 0.04, 0), (0, -0.44, 0), 0.125, 0.10, CLOTH, sides=7)  # baggy thigh
        sh = parts["kn" + sfx]
        sh.prism((0, 0.0, 0), (0, -0.30, 0), 0.10, 0.12, CLOTH, sides=7)  # flared pant leg
        sh.prism((0, -0.26, 0), (0, -0.42, 0), 0.11, 0.10, PRIMARY, sides=7)  # boot shaft
        ft = parts["an" + sfx]  # from the ankle pivot (ANKLE below the knee)
        ft.frustum(-0.05, 0.07, (0.20, 0.30), (0.17, 0.22), PRIMARY, (0.0, 0.0, -0.05))  # boot
        ft.box((0.0, -0.055, -0.055), (0.21, 0.035, 0.31), SOLE)        # sole (floor at -0.07)
        sh.box((0.0, -0.32, -0.105), (0.13, 0.03, 0.02), TRIM)         # boot strap
    return parts


# --- Bulk ---------------------------------------------------------------------------
# Fat bruiser: shaved head with a topknot, full beard, sleeveless open vest
# over a bare chest and a gut that hangs over a wide sash, heavy arms in
# wrist wraps, baggy pants wrapped from the shin down, flat heavy boots.
# The gut is part of the waist, so there is no unit belly part. Same pivots
# and floor line as the Brawler (soles at -0.0725 under the ankle), so poses
# and floor checks hold.

def body_scale_of(char):
    """CharacterDef.body_scale from data/characters/<char>.tres (written by
    tools/generate_moves.gd), so the model follows a retuned profile."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "characters",
                        char + ".tres")
    with open(path) as f:
        m = re.search(r"^body_scale = Vector3\(([^)]*)\)", f.read(), re.M)
    if m is None:
        sys.exit("BUILD_FIGHTER no body_scale in %s" % path)
    return tuple(float(v) for v in m.group(1).split(","))


# Bulk's body_scale: parts that should keep a normal size are divided by it
# (x, z) before export. Rerun this script after changing it.
BULK_SCALE = body_scale_of("bulk")
KX, KZ = 1.0 / BULK_SCALE[0], 1.0 / BULK_SCALE[2]


def _n(w, d):
    """(width, depth) undone by Bulk's body_scale."""
    return (w * KX, d * KZ)


def build_bulk():
    parts = {name: Part(name) for name in JOINTS if name != "belly"}

    p = parts["pelvis"]
    p.frustum(-0.13, 0.05, (0.36, 0.25), (0.40, 0.26), CLOTH)        # hips
    p.frustum(0.00, 0.12, (0.42, 0.28), (0.41, 0.27), PRIMARY_DARK)  # wide sash
    p.blob((0.07, 0.05, -0.145), (0.05, 0.045, 0.03), GOLD)           # sash knot
    p.frustum(-0.20, 0.03, (0.05, 0.015), (0.06, 0.015), PRIMARY_DARK, (0.05, 0.0, -0.15))  # sash tails
    p.frustum(-0.16, 0.03, (0.045, 0.015), (0.05, 0.015), PRIMARY_DARK, (0.10, 0.0, -0.145))

    t = parts["torso"]
    t.prism((0, 0.04, 0.02), (0, 0.32, 0.02), 0.18, 0.20, SKIN, sides=8, squash=0.75)  # waist / back
    t.blob((0.0, 0.17, -0.07), (0.215, 0.24, 0.20), SKIN, subdiv=2)                      # the gut
    t.blob((0.0, 0.12, -0.262), (0.012, 0.016, 0.01), HAIR, smooth=False)              # navel
    for side in (-1.0, 1.0):  # vest flaps falling open over the gut's sides
        t.frustum(0.10, 0.33, (0.08, 0.30), (0.09, 0.32), PRIMARY, (0.19 * side, 0.0, 0.0))

    c = parts["chest"]  # from the chest pivot (CHEST above the waist)
    c.frustum(0.0, 0.36, (0.42, 0.30), (0.62, 0.38), PRIMARY, (0.0, 0.0, 0.02))   # vest
    c.frustum(-0.02, 0.33, (0.24, 0.02), (0.22, 0.02), SKIN, (0.0, 0.0, -0.155))   # open front
    for side in (-1.0, 1.0):
        c.blob((0.095 * side, 0.20, -0.13), (0.11, 0.09, 0.07), SKIN, subdiv=2)    # pecs
        c.frustum(-0.02, 0.33, (0.035, 0.02), (0.04, 0.02), PRIMARY_DARK,
                  (0.135 * side, 0.0, -0.165))                                   # vest edge
        c.blob((0.27 * side, 0.33, 0.0), (0.12, 0.09, 0.13), PRIMARY_DARK)         # vest shoulder
        c.blob((0.12 * side, 0.37, 0.02), (0.10, 0.06, 0.09), SKIN)                # traps
    c.prism((0, 0.30, 0.01), (0, 0.42, 0.01), 0.10, 0.09, SKIN, sides=7)          # thick neck

    h = parts["head"]  # a bit over the Brawler's size once widened by body_scale
    h.blob((0.0, 0.13, 0.0), (0.13 * KX, 0.14, 0.14 * KZ), SKIN, subdiv=2)        # shaved skull
    h.frustum(-0.02, 0.11, _n(0.20, 0.19), _n(0.25, 0.23), SKIN, (0.0, 0.0, -0.015))  # heavy jaw
    h.blob((0.0, 0.01, -0.07 * KZ), (0.135 * KX, 0.09, 0.10 * KZ), HAIR)          # full beard
    h.blob((0.0, -0.06, -0.10 * KZ), (0.07 * KX, 0.06, 0.06 * KZ), HAIR)          # beard point
    h.box((0.0, 0.085, -0.15 * KZ), (0.15 * KX, 0.025, 0.035 * KZ), HAIR)          # moustache
    h.box((0.0, 0.15, -0.14 * KZ), (0.17 * KX, 0.03, 0.03 * KZ), HAIR)             # brow ridge
    h.blob((0.0, 0.29, 0.05 * KZ), (0.04 * KX, 0.045, 0.04 * KZ), HAIR)           # topknot
    h.prism((0, 0.255, 0.05 * KZ), (0, 0.27, 0.05 * KZ), 0.034 * KX, 0.034 * KX, TRIM, sides=6)  # knot tie
    for side in (-1.0, 1.0):
        h.blob((0.13 * KX * side, 0.12, 0.0), (0.025 * KX, 0.04, 0.03 * KZ), SKIN)  # ears

    for side, sfx in ((-1.0, "_l"), (1.0, "_r")):
        a = parts["sh" + sfx]
        a.blob((0.02 * side, -0.04, 0.0), (0.10, 0.11, 0.10), SKIN)               # deltoid
        a.prism((0.01 * side, -0.06, 0), (0, -0.30, 0), 0.088, 0.072, SKIN, sides=7)  # upper arm
        f = parts["el" + sfx]
        f.prism((0, 0.0, 0), (0, -0.20, 0), 0.072, 0.085, SKIN, sides=7)           # forearm
        f.prism((0, -0.13, 0), (0, -0.25, 0), 0.092, 0.09, TRIM, sides=7)           # wrist wrap
        w = parts["wr" + sfx]  # from the wrist pivot
        w.frustum(-0.18, -0.03, _n(0.22, 0.21), _n(0.25, 0.23), PRIMARY_DARK)       # meaty fist
        w.box((0.0, -0.08, -0.115 * KZ), (0.25 * KX, 0.06, 0.03 * KZ), TRIM)         # knuckle wrap
        w.box((-0.13 * KX * side, -0.09, -0.02 * KZ), (0.06 * KX, 0.10, 0.09 * KZ), PRIMARY_DARK)  # thumb
        th = parts["hip" + sfx]
        th.prism((0, 0.04, 0), (0, -0.44, 0), 0.13, 0.105, CLOTH, sides=7)          # thick thigh
        sh = parts["kn" + sfx]
        sh.prism((0, 0.0, 0), (0, -0.22, 0), 0.105, 0.11, CLOTH, sides=7)           # baggy pant leg
        sh.prism((0, -0.20, 0), (0, -0.41, 0), 0.085, 0.075, TRIM, sides=7)          # shin wraps
        for y in (-0.25, -0.31, -0.37):
            sh.prism((0, y, 0), (0, y - 0.02, 0), 0.089, 0.087, PRIMARY_DARK, sides=7)  # wrap bands
        ft = parts["an" + sfx]  # from the ankle pivot
        ft.frustum(-0.055, 0.06, _n(0.27, 0.38), _n(0.22, 0.28), PRIMARY, (0.0, 0.0, -0.035))  # flat boot
        ft.box((0.0, -0.055, -0.035), (0.28 * KX, 0.035, 0.39 * KZ), SOLE)           # sole (floor at -0.0725)
    return parts


# --- Sprite -------------------------------------------------------------------------
# Small, lean speedster: swept-back hair with a long ponytail, goggles pushed
# up on the forehead, a scarf whose tails stream behind, a cropped sleeveless
# top over a bare midriff, arm guards and wrapped hands, shorts over bare
# thighs, shin bindings and light running shoes with a speed stripe. Same
# pivots and floor line as the Brawler (soles at -0.0725 under the ankle).
# The game shrinks it by body_scale (~0.8), so the head, hands and feet are
# drawn a little larger here (SPRITE_GROW) to keep it readable on screen:
# a big head on a small body also reads as young and quick.

SPRITE_SCALE = body_scale_of("sprite")
# Head / hands / feet grow by this much of what body_scale takes away.
SPRITE_GROW = 0.5
SG = 1.0 + (1.0 / SPRITE_SCALE[0] - 1.0) * SPRITE_GROW


def build_sprite():
    parts = {name: Part(name) for name in JOINTS if name != "belly"}

    p = parts["pelvis"]
    p.frustum(-0.13, 0.05, (0.31, 0.21), (0.33, 0.22), CLOTH)        # shorts seat
    p.frustum(0.02, 0.09, (0.35, 0.24), (0.35, 0.24), PRIMARY_DARK)  # waistband
    p.box((0.0, 0.055, -0.125), (0.05, 0.035, 0.02), GOLD)            # cord knot
    for side in (-1.0, 1.0):
        p.box((0.025 * side, 0.0, -0.125), (0.012, 0.09, 0.012), TRIM)  # cord ends

    t = parts["torso"]
    t.prism((0, 0.06, 0), (0, 0.33, 0), 0.145, 0.175, SKIN, sides=8, squash=0.75)  # lean midriff
    for y in (0.14, 0.21):  # abs
        t.box((0.0, y, -0.112), (0.10, 0.012, 0.012), PRIMARY_DARK)
    t.frustum(0.25, 0.32, (0.34, 0.25), (0.37, 0.26), PRIMARY)       # crop top hem

    c = parts["chest"]  # from the chest pivot (CHEST above the waist)
    c.frustum(0.0, 0.34, (0.36, 0.26), (0.52, 0.31), PRIMARY, (0.0, 0.0, 0.01))  # crop top
    c.frustum(0.02, 0.30, (0.035, 0.02), (0.035, 0.02), TRIM, (0.0, 0.0, -0.135))  # zip stripe
    c.frustum(0.0, 0.045, (0.37, 0.27), (0.385, 0.275), PRIMARY_DARK, (0.0, 0.0, 0.01))  # top's lower band
    c.blob((-0.27, 0.32, 0.0), (0.10, 0.07, 0.11), PRIMARY_DARK)            # one shoulder guard
    c.prism((0, 0.30, 0.0), (0, 0.42, 0.0), 0.07, 0.065, SKIN, sides=6)     # neck
    c.prism((0, 0.30, 0.0), (0, 0.39, 0.0), 0.115, 0.105, PRIMARY_DARK, sides=8)  # scarf wrap
    c.blob((0.04, 0.33, -0.10), (0.04, 0.035, 0.03), PRIMARY_DARK)          # scarf knot
    # Scarf tails falling down the back, kept close to it so the body still
    # lies flat on its back (character_model_test).
    c.prism((0.03, 0.35, 0.10), (0.07, 0.15, 0.175), 0.05, 0.042, PRIMARY_DARK, sides=4, squash=0.3)
    c.prism((0.07, 0.15, 0.175), (0.12, -0.02, 0.185), 0.042, 0.022, PRIMARY_DARK, sides=4, squash=0.3)
    c.prism((-0.02, 0.34, 0.10), (-0.05, 0.08, 0.18), 0.045, 0.025, PRIMARY_DARK, sides=4, squash=0.3)

    h = parts["head"]  # drawn SG larger: the body_scale shrink brings it back down
    k = SG
    h.blob((0.0, 0.13 * k, 0.0), (0.11 * k, 0.125 * k, 0.12 * k), SKIN, subdiv=2)  # skull
    h.frustum(0.0, 0.10 * k, (0.09 * k, 0.11 * k), (0.16 * k, 0.17 * k), SKIN,
              (0.0, 0.0, -0.025 * k))                                           # pointed chin
    h.box((0.0, 0.115 * k, -0.118 * k), (0.11 * k, 0.026 * k, 0.02 * k), HAIR)  # eyes
    for side in (-1.0, 1.0):
        h.blob((0.11 * k * side, 0.12 * k, 0.0), (0.02 * k, 0.035 * k, 0.025 * k), SKIN)  # ears
    h.blob((0.0, 0.19 * k, 0.025 * k), (0.12 * k, 0.09 * k, 0.13 * k), HAIR)   # hair cap
    h.prism((0, 0.16 * k, 0), (0, 0.19 * k, 0), 0.121 * k, 0.121 * k, CLOTH, sides=8)  # goggle strap
    for side in (-1.0, 1.0):
        h.prism((0.045 * k * side, 0.20 * k, -0.105 * k), (0.045 * k * side, 0.20 * k, -0.135 * k),
                0.034 * k, 0.03 * k, GOLD, sides=6, smooth=False)               # goggle lenses
    h.cone((0.0, 0.25 * k, -0.07 * k), (0.02 * k, 0.17 * k, -0.17 * k), 0.05 * k, HAIR)  # bangs
    # Hair swept back by the wind of its own speed.
    for x, y, z, tx, ty, tz in ((0.0, 0.25, -0.02, 0.0, 0.31, 0.16), (-0.07, 0.22, 0.0, -0.13, 0.27, 0.17),
                                (0.07, 0.22, 0.0, 0.13, 0.27, 0.17), (-0.05, 0.16, 0.06, -0.12, 0.15, 0.17),
                                (0.05, 0.16, 0.06, 0.12, 0.15, 0.17)):
        h.cone((x * k, y * k, z * k), (tx * k, ty * k, tz * k), 0.055 * k, HAIR)
    # Ponytail: tied high at the back, falls close to the neck (it may not
    # stick out past the hair, or the head sinks into the floor lying down).
    h.prism((0, 0.21 * k, 0.10 * k), (0, 0.19 * k, 0.125 * k), 0.035 * k, 0.035 * k, TRIM, sides=6)  # tie
    h.prism((0, 0.19 * k, 0.12 * k), (0, 0.04 * k, 0.135 * k), 0.042 * k, 0.032 * k, HAIR, sides=5)
    h.cone((0, 0.04 * k, 0.135 * k), (0, -0.11 * k, 0.14 * k), 0.032 * k, HAIR, sides=5)

    for side, sfx in ((-1.0, "_l"), (1.0, "_r")):
        a = parts["sh" + sfx]
        a.blob((0.015 * side, -0.035, 0.0), (0.085, 0.09, 0.085), SKIN)          # deltoid
        a.prism((0.01 * side, -0.05, 0), (0, -0.30, 0), 0.08, 0.066, SKIN, sides=7)  # lean upper arm
        f = parts["el" + sfx]
        f.prism((0, 0.0, 0), (0, -0.08, 0), 0.06, 0.065, SKIN, sides=7)          # forearm
        f.prism((0, -0.05, 0), (0, -0.21, 0), 0.075, 0.088, PRIMARY_DARK, sides=7)  # arm guard
        f.box((0.0, -0.13, -0.085), (0.03, 0.12, 0.02), GOLD)                    # guard stripe
        w = parts["wr" + sfx]  # from the wrist pivot (WRIST below the elbow)
        w.frustum(-0.17 * SG, -0.03, (0.15 * SG, 0.15 * SG), (0.17 * SG, 0.16 * SG), TRIM)  # wrapped fist
        w.box((0.0, -0.08 * SG, -0.085 * SG), (0.175 * SG, 0.05 * SG, 0.025 * SG), PRIMARY_DARK)  # knuckle wrap
        w.box((-0.09 * SG * side, -0.085 * SG, -0.02), (0.045 * SG, 0.09 * SG, 0.07 * SG), TRIM)  # thumb
        th = parts["hip" + sfx]
        th.prism((0, 0.04, 0), (0, -0.22, 0), 0.122, 0.115, CLOTH, sides=7)       # shorts leg
        th.prism((0, -0.20, 0), (0, -0.23, 0), 0.119, 0.119, PRIMARY_DARK, sides=7)  # shorts hem
        th.prism((0, -0.18, 0), (0, -0.44, 0), 0.098, 0.08, SKIN, sides=7)         # bare thigh
        sh = parts["kn" + sfx]
        sh.prism((0, 0.02, 0), (0, -0.14, 0), 0.078, 0.076, SKIN, sides=7)         # knee
        sh.prism((0, -0.12, 0), (0, -0.30, 0), 0.08, 0.07, TRIM, sides=7)         # shin bindings
        for y in (-0.16, -0.22):
            sh.prism((0, y, 0), (0, y - 0.02, 0), 0.082, 0.079, PRIMARY_DARK, sides=7)  # binding cords
        sh.prism((0, -0.28, 0), (0, -0.42, 0), 0.08, 0.088, PRIMARY, sides=7)      # shoe collar
        ft = parts["an" + sfx]  # from the ankle pivot (ANKLE below the knee)
        fl = 0.28 * SG  # shoe length, toe ahead of the ankle
        ft.frustum(-0.05, 0.06, (0.15 * SG, fl - 0.01), (0.12 * SG, fl * 0.7), PRIMARY,
                   (0.0, 0.0, -0.05))                                            # running shoe
        ft.box((0.0, -0.055, -0.055), (0.16 * SG, 0.035, fl + 0.01), SOLE)       # sole (floor at -0.0725)
        ft.box((0.0, -0.025, -0.05 - fl / 2 + 0.03), (0.13 * SG, 0.05, 0.05), TRIM)  # toe cap
        for s in (-1.0, 1.0):  # speed stripe on both sides of the shoe
            ft.box((0.074 * SG * s, -0.01, -0.06), (0.012, 0.025, fl * 0.55), GOLD)
    return parts


BUILDERS = {"brawler": build_brawler, "bulk": build_bulk, "sprite": build_sprite}
# body_scale applied to `preview=` renders only (the game applies its own).
PREVIEW_SCALE = {"bulk": BULK_SCALE, "sprite": SPRITE_SCALE}


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
        ob = objs.get(name)
        if ob is None:  # optional part this body doesn't have (belly)
            continue
        if parent is not None:
            ob.parent = objs[parent]
        ob.location = gd(pivot)
    bpy.context.view_layer.update()
    return objs


def render_preview(out_dir, char):
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
    if char in PREVIEW_SCALE:  # scale about the floor, like the game's body node
        root = bpy.data.objects.new("preview_root", None)
        scene.collection.objects.link(root)
        bpy.data.objects["pelvis"].parent = root
        sx, sy, sz = PREVIEW_SCALE[char]
        root.scale = (sx, sz, sy)  # Godot (x, y, z) scale in Blender axes
    target = gd((0.0, 1.0, 0.0))
    for label, yaw in (("front", 0.0), ("three_quarter", 35.0), ("side", 90.0), ("back", 180.0)):
        r = math.radians(yaw)
        # Godot forward is -z: the front view looks from -z toward +z.
        pos = gd((5.0 * math.sin(r), 1.15, -5.0 * math.cos(r)))
        cam.location = pos
        direction = target - pos
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, "%s_%s.png" % (char, label))
        bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = dict(a.split("=", 1) for a in argv if "=" in a)
    char = args.get("char", "brawler")
    if char not in BUILDERS:
        sys.exit("BUILD_FIGHTER unknown char=%s (have %s)" % (char, ", ".join(BUILDERS)))
    out = args.get("out", "assets/models/fighter_%s.glb" % char)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = make_materials()
    assemble(BUILDERS[char](), mats)
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(out), export_format="GLB", export_yup=True,
                              export_apply=False, export_texcoords=True, export_normals=True,
                              export_materials="EXPORT")
    print("BUILD_FIGHTER wrote", out)
    if "preview" in args:
        render_preview(args["preview"], char)
        print("BUILD_FIGHTER preview in", args["preview"])


main()
