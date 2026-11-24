class_name FighterModel
extends RefCounted
## Low-poly fighter body: the rigid-segment model from
## tools/blender/build_fighter.py, merged into ONE rigidly skinned mesh (every
## vertex follows exactly one bone) so a fighter is one draw call (+ one for
## its outline), cheap on phones and the web build.
##
## The model file holds one mesh node per rig joint, named after it, with its
## geometry relative to the joint pivot. The bones are the caller's rig
## (FighterVisual's joint nodes): bone rests come from the rig, so the pivots
## live in one place and the code-driven poses keep working; the caller copies
## its joint transforms into the skeleton every frame (sync_pose).
##
## Colours: every vertex's UV.x selects a palette slot (Slot); the toon
## shader reads the slot's colour from a per-fighter array, so team colours
## are a shader parameter, not a texture or a material per part.
##
## Presentation only: never read by the sim.

## Keep in sync with tools/blender/build_fighter.py.
enum Slot { PRIMARY, PRIMARY_DARK, SKIN, CLOTH, TRIM, HAIR, GOLD, SOLE }
const PALETTE_SIZE := 8
## Model parts that don't follow a bone of their own name.
const PART_BONES := {&"belly": &"torso"}

const TOON_SHADER := preload("res://presentation/fighter/toon.gdshader")
const OUTLINE_SHADER := preload("res://presentation/fighter/toon_outline.gdshader")

## path -> { part name -> Array[Dictionary] of surface arrays } (or {} if unloadable)
static var _parts_cache: Dictionary = {}
## cache key -> ArrayMesh
static var _mesh_cache: Dictionary = {}
static var _outline_mat: ShaderMaterial


## True when the model at `path` exists and has parts.
static func available(path: String) -> bool:
	return not path.is_empty() and not _parts(path).is_empty()


## A Skeleton3D mirroring `bones` (ordered parents first; each one's parent
## is the previous Node3D in its ancestry that is also in `bones`, else
## none) with the merged mesh skinned to it as a child MeshInstance3D named
## "Body". `extra_parts` maps a part name to a Transform3D applied to it in
## its bone's space before merging (e.g. the belly's size); parts missing
## from it whose name isn't a bone are skipped, so `extra_parts` also turns
## optional parts on. Returns null if the model can't be loaded.
static func create(path: String, bones: Array[Node3D], extra_parts: Dictionary,
		material: Material) -> Skeleton3D:
	var parts := _parts(path)
	if parts.is_empty():
		return null
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	var index := {}
	for n in bones:
		var i := skel.add_bone(n.name)
		index[n] = i
		var p := n.get_parent()
		while p != null and not index.has(p):
			p = p.get_parent()
		if p != null:
			skel.set_bone_parent(i, index[p])
		skel.set_bone_rest(i, n.transform)
		skel.set_bone_pose(i, n.transform)
	var key := "%s|%s|%s" % [path, _bones_key(skel), var_to_str(extra_parts)]
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		mesh = _merge(parts, skel, extra_parts)
		_mesh_cache[key] = mesh
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh
	mi.material_override = material
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = skel.create_skin_from_rest_transforms()
	return skel


## Copy the rig's joint transforms into the skeleton (same order as create's bones).
static func sync_pose(skel: Skeleton3D, bones: Array[Node3D]) -> void:
	for i in bones.size():
		var n := bones[i]
		skel.set_bone_pose_position(i, n.position)
		skel.set_bone_pose_rotation(i, n.quaternion)


## A toon material for one fighter (its own palette and glow), outlined.
static func make_material(primary: Color) -> ShaderMaterial:
	var v := Tuning.vfx
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter(&"palette", palette_for(primary))
	m.set_shader_parameter(&"threshold", v.toon_threshold)
	m.set_shader_parameter(&"softness", v.toon_softness)
	m.set_shader_parameter(&"shade_floor", v.toon_shade_floor)
	m.set_shader_parameter(&"rim_strength", v.toon_rim_strength)
	m.set_shader_parameter(&"rim_power", v.toon_rim_power)
	if v.outline_width > 0.0:
		m.next_pass = outline_material()
	return m


## The outline pass shared by every fighter.
static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE_SHADER
		_outline_mat.set_shader_parameter(&"outline_color", Tuning.vfx.outline_color)
		_outline_mat.set_shader_parameter(&"width", Tuning.vfx.outline_width)
	return _outline_mat


static func palette_for(primary: Color) -> PackedColorArray:
	var v := Tuning.vfx
	var p := PackedColorArray()
	p.resize(PALETTE_SIZE)
	p[Slot.PRIMARY] = primary
	p[Slot.PRIMARY_DARK] = primary.darkened(v.primary_dark_amount)
	p[Slot.SKIN] = v.skin_color
	p[Slot.CLOTH] = v.cloth_color
	p[Slot.TRIM] = v.trim_color
	p[Slot.HAIR] = v.hair_color
	p[Slot.GOLD] = v.gold_color
	p[Slot.SOLE] = v.sole_color
	return p


static func set_glow(m: ShaderMaterial, color: Color, energy: float) -> void:
	m.set_shader_parameter(&"glow_color", color)
	m.set_shader_parameter(&"glow_energy", energy)


# --- loading / merging ---------------------------------------------------------

static func _parts(path: String) -> Dictionary:
	if _parts_cache.has(path):
		return _parts_cache[path]
	var parts := {}
	if not path.is_empty() and ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			var root := scene.instantiate()
			for node in root.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.mesh == null:
					continue
				var surfaces: Array[Array] = []
				for s in mi.mesh.get_surface_count():
					surfaces.append(mi.mesh.surface_get_arrays(s))
				parts[StringName(mi.name)] = surfaces
			root.free()
	_parts_cache[path] = parts
	return parts


static func _bones_key(skel: Skeleton3D) -> String:
	var s := ""
	for i in skel.get_bone_count():
		s += "%s@%s;" % [skel.get_bone_name(i), skel.get_bone_global_rest(i).origin]
	return s


static func _merge(parts: Dictionary, skel: Skeleton3D, extra_parts: Dictionary) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	for part: StringName in parts:
		var bone_name: StringName = PART_BONES.get(part, part)
		var bone := skel.find_bone(bone_name)
		var is_extra := PART_BONES.has(part)
		if bone < 0 or (is_extra and not extra_parts.has(part)):
			continue
		var local: Transform3D = extra_parts.get(part, Transform3D.IDENTITY)
		var xf := skel.get_bone_global_rest(bone) * local
		var nb := xf.basis.inverse().transposed()
		for arrays: Array in parts[part]:
			var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var pu: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var pi: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var base := verts.size()
			for k in pv.size():
				verts.append(xf * pv[k])
				normals.append((nb * pn[k]).normalized() if k < pn.size() else Vector3.UP)
				uvs.append(pu[k] if k < pu.size() else Vector2.ZERO)
				bone_ids.append_array([bone, 0, 0, 0])
				weights.append_array([1.0, 0.0, 0.0, 0.0])
			if pi.is_empty():
				for k in pv.size():
					indices.append(base + k)
			else:
				for k in pi:
					indices.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bone_ids
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## World-space positions of the body's vertices in the skeleton's current
## pose (CPU skinning; tests and tools, not per frame). `bones` limits it to
## vertices of those bone indices (empty = all).
static func posed_points(skel: Skeleton3D, bones: PackedInt32Array = PackedInt32Array()) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mi := skel.get_node_or_null(^"Body") as MeshInstance3D
	if mi == null or mi.mesh == null:
		return out
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var skin_xf: Array[Transform3D] = []
	for i in skel.get_bone_count():
		skin_xf.append(skel.global_transform * skel.get_bone_global_pose(i) * skel.get_bone_global_rest(i).affine_inverse())
	for k in verts.size():
		var b := ids[k * 4]
		if bones.is_empty() or b in bones:
			out.append(skin_xf[b] * verts[k])
	return out
