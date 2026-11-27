class_name PropArena
extends Arena
## Base of the stages dressed with PropMesh props (BeachArena,
## TimesSquareArena): a "Props" node holding them, the one prop material,
## a seeded RNG for the layout, and the helpers that keep a stage cheap on the
## web build: repeated props are MultiMeshes of one mesh each, one-off props a
## single MeshInstance, wordmarks the only per-prop nodes.

## Value noise and fbm for stage shaders: put "//NOISE" in the code and
## replace it with this.
const NOISE_GLSL := """
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.15;
}
"""

var _props: Node3D
var _prop_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
## Batch name -> Array of the Transform3Ds put in it, for tests: the headless
## renderer doesn't keep MultiMesh transforms.
var placements: Dictionary = {}


func _ready() -> void:
	_prop_mat = PropMesh.material()
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)
	_rng.seed = look().scenery_seed
	super()


static func _shader_material(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code.replace("//NOISE", NOISE_GLSL)
	mat.shader = sh
	return mat


func _add_text(text: String, xf: Transform3D, color: Color, pixel: float, size: int, font: Font = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.transform = xf
	l.pixel_size = pixel
	l.font_size = size
	if font != null:
		l.font = font
	l.outline_size = 0
	l.modulate = color
	l.shaded = true
	l.double_sided = false
	l.no_depth_test = false
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_props.add_child(l)
	return l


## `material` null = the prop material.
func _add_static(node_name: String, mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material if material != null else _prop_mat
	_props.add_child(mi)
	return mi


## items: [Transform3D, Color] pairs, or [Transform3D, Color, Color] with
## the instance's custom data. `use_prop_material` = false keeps the mesh's
## own one.
func _batch(node_name: String, mesh: Mesh, items: Array, use_prop_material := true) -> MultiMeshInstance3D:
	if items.is_empty():
		return null
	var placed: Array = placements.get(node_name, [])
	for item: Array in items:
		placed.append(item[0])
	placements[node_name] = placed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = (items[0] as Array).size() > 2
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, items[i][2])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	if use_prop_material:
		mi.material_override = _prop_mat
	_props.add_child(mi)
	return mi
