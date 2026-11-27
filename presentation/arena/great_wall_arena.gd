class_name GreatWallArena
extends Arena
## An autumn dawn on the Great Wall: a wide bastion terrace where the wall
## crosses a mountain ridge. Visual only, like every Arena: the play area is
## the cord circle of `radius` inlaid in the paving, and everything else
## stands outside it, so the fighters never meet a prop. Looking at -Z: the
## gate tower with its pavilion. Looking at +Z: the valley, a sea of mist and
## the rising sun. Along +X and -X the wall leaves the terrace and snakes
## away over the ridge, watchtower after watchtower.
## Reads Tuning.arena_great_wall (data/tuning/arena_great_wall.tres). Brick
## work shares one material (BRICK_SHADER), painted parts PropMesh's;
## repeated props are MultiMeshes of one PropMesh each.

const TERRACE_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 stone_light : source_color;
uniform vec4 stone_dark : source_color;
uniform vec4 moss : source_color;
uniform vec4 inlay : source_color;
uniform vec4 inlay_red : source_color;
uniform float radius = 18.0;
varying vec3 world_pos;

//NOISE
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz;
	float near = 1.0 - smoothstep(20.0, 60.0, length(world_pos - CAMERA_POSITION_WORLD));
	// Flagstones in running bond.
	vec2 size = vec2(1.2, 0.8);
	vec2 q = p / size;
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float tone = fbm(p * 0.12);
	vec3 c = mix(stone_light.rgb, stone_dark.rgb, clamp(hash(cell) * 0.6 + tone * 0.6 - 0.2, 0.0, 1.0));
	float e = min(min(f.x, 1.0 - f.x) * size.x, min(f.y, 1.0 - f.y) * size.y);
	float joint = 1.0 - smoothstep(0.015, 0.05, e);
	float mossy = smoothstep(0.58, 0.8, fbm(p * 0.3 + 4.0));
	c = mix(c, stone_dark.rgb * 0.7, joint * near);
	c = mix(c, moss.rgb, max(joint * 0.5 * mossy, mossy * 0.3));
	// Worn smooth inside the ring.
	float r = length(p);
	c *= 1.0 + (1.0 - smoothstep(radius - 2.0, radius, r)) * 0.06;
	// The inlay: the ring at the boundary, an octagon, the centre circles.
	float band = 1.0 - smoothstep(0.28, 0.34, abs(r - (radius - 0.4)));
	float red = 1.0 - smoothstep(0.05, 0.1, abs(r - (radius - 0.4)));
	float oct = max(max(abs(p.x), abs(p.y)), (abs(p.x) + abs(p.y)) * 0.7071);
	float octl = 1.0 - smoothstep(0.1, 0.16, abs(oct - radius * 0.55));
	float hub = 1.0 - smoothstep(0.1, 0.15, abs(r - 3.0));
	float hub_red = 1.0 - smoothstep(0.04, 0.08, abs(r - 2.6));
	c = mix(c, inlay.rgb, max(band, max(hub, octl) * 0.6));
	c = mix(c, inlay_red.rgb, max(red, hub_red));
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

## Brick courses on vertical faces, by world position; vertex colour times
## the instance colour is the paint.
const BRICK_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 mortar : source_color;
varying vec3 world_pos;
varying vec3 world_n;

//NOISE
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));  // vertex colours are sRGB, as on PropMesh.material()
	float side = 1.0 - abs(world_n.y);
	vec2 t = normalize(vec2(-world_n.z, world_n.x) + vec2(0.0001));
	float across = dot(world_pos.xz, t);
	float row = floor(world_pos.y / 0.42);
	float bx = across / 0.9 + mod(row, 2.0) * 0.5;
	float fy = fract(world_pos.y / 0.42);
	float fx = fract(bx);
	float joint = max(1.0 - smoothstep(0.0, 0.1, min(fy, 1.0 - fy)), 1.0 - smoothstep(0.0, 0.05, min(fx, 1.0 - fx)));
	float near = 1.0 - smoothstep(25.0, 80.0, length(world_pos - CAMERA_POSITION_WORLD));
	float n = hash(vec2(floor(bx), row));
	vec3 c = paint * (0.92 + 0.16 * n * near);
	c = mix(c, mortar.rgb, joint * near * side * 0.55);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""

## Banners: the cloth sways, more toward its free edge (local +x).
const FLAG_SHADER := """
shader_type spatial;
render_mode cull_disabled;
void vertex() {
	float phase = MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.23;
	VERTEX.z += sin(TIME * 1.9 + VERTEX.x * 2.2 + VERTEX.y * 0.6 + phase) * 0.16 * VERTEX.x;
}
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.95;
}
"""

const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 mist : source_color;
uniform float fade_from = 380.0;
uniform float fade_to = 470.0;
varying vec3 world_pos;

//NOISE
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_pos.xz * 0.012 + vec2(TIME * 0.006, TIME * 0.003);
	float n = fbm(p) * 0.7 + fbm(p * 2.7 - TIME * 0.004) * 0.3;
	float edge = 1.0 - smoothstep(fade_from, fade_to, length(world_pos.xz));
	ALBEDO = mist.rgb;
	ALPHA = mist.a * smoothstep(0.28, 0.7, n) * edge;
}
"""

## Footprint radius of a low prop (jar cluster, brick stack).
## A knocked-over jar lies up to its offset plus its height from the spot.
const LOW_PROP_REACH := 1.4
const JAR_HEIGHT := 0.62
const FLAG_SIZE := Vector2(1.3, 2.8)
const LANTERN_HEIGHT := 2.3
const CORD_POINTS_PER_POST := 5
const CORD_SAG := 0.08
const CORD_RADIUS := 0.03
const DOOR_SIZE := Vector2(3.4, 3.8)
## How far inside the camera's far plane the far ranges' mist fades out.
const FAR_MARGIN := 30.0

var _props: Node3D
var _prop_mat: StandardMaterial3D
var _brick_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## Terrain heights at the grid's vertices, (terrain_cells + 1)^2, row by row.
var _heights := PackedFloat32Array()

static var _noise: FastNoiseLite
static var _noise_key := Vector2(-1.0, -1.0)


func look() -> ArenaTuning:
	return Tuning.arena_great_wall


func _make_sky_material() -> Material:
	var g := Tuning.arena_great_wall
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BeachArena.SKY_SHADER.replace("//NOISE", PropArena.NOISE_GLSL)
	mat.shader = sh
	mat.set_shader_parameter("top", g.sky_top_color)
	mat.set_shader_parameter("horizon", g.sky_horizon_color)
	mat.set_shader_parameter("cloud_lit", g.cloud_lit)
	mat.set_shader_parameter("cloud_shade", g.cloud_shade)
	mat.set_shader_parameter("sun_glow", g.sun_glow)
	mat.set_shader_parameter("cover", g.cloud_cover)
	mat.set_shader_parameter("cloud_scale", g.cloud_scale)
	return mat


func _build_environment() -> void:
	super()
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	var scale := Tuning.arena_great_wall.compatibility_light_scale
	_sun.light_energy *= scale
	var env: Environment = (get_node("WorldEnvironment") as WorldEnvironment).environment
	env.ambient_light_energy *= scale


# --- layout (no nodes, so tests can check it against the play circle) ---------

## Inner face of the terrace's parapet, on every side.
static func terrace_half(play_radius: float) -> float:
	return play_radius + Tuning.arena_great_wall.terrace_margin


## Outer face of the terrace (its parapet's and its body's).
static func terrace_outer(play_radius: float) -> float:
	return terrace_half(play_radius) + Tuning.arena_great_wall.parapet_thickness


## Distance along X from the terrace's outer face (0 on the terrace).
static func _out(x: float, play_radius: float) -> float:
	return maxf(absf(x) - terrace_outer(play_radius), 0.0)


## The wall's centre line: its z at x. 0 on the terrace.
static func ridge_z(x: float, play_radius: float) -> float:
	var g := Tuning.arena_great_wall
	var s := _out(x, play_radius)
	var phase := 0.0 if x >= 0.0 else 2.4
	var wander := sin(s * TAU / g.meander_wavelength + phase) - sin(phase)
	return g.meander_amplitude * smoothstep(0.0, g.ridge_ramp, s) * wander


## Height of the ridge's crest (the ground the wall stands on) at x.
static func ridge_y(x: float, play_radius: float) -> float:
	var g := Tuning.arena_great_wall
	var s := _out(x, play_radius)
	var wavelength := g.ridge_wavelength * (1.0 if x >= 0.0 else 0.82)
	var peaks := 0.5 - 0.5 * cos(s * TAU / wavelength)
	var swell := 0.75 + 0.25 * sin(s * 0.011 + (0.0 if x >= 0.0 else 1.7))
	return -g.terrace_height + g.ridge_rise * smoothstep(0.0, g.ridge_ramp, s) * peaks * swell


## Height of the wall's walkway at x: level with the terrace where it leaves it.
static func walk_y(x: float, play_radius: float) -> float:
	return ridge_y(x, play_radius) + Tuning.arena_great_wall.terrace_height


## Horizontal distance from (x, z) to the wall's centre line, measured
## across it.
static func ridge_distance(x: float, z: float, play_radius: float) -> float:
	var slope := ridge_z(x + 0.5, play_radius) - ridge_z(x - 0.5, play_radius)
	return absf(z - ridge_z(x, play_radius)) / sqrt(1.0 + slope * slope)


## Half width of the ridge's flat crest at x: a plateau around the terrace,
## a narrow crest under the wall further out.
static func ridge_crest(x: float, play_radius: float) -> float:
	var g := Tuning.arena_great_wall
	var wide := terrace_outer(play_radius) + 4.0
	return lerpf(wide, g.ridge_top, smoothstep(0.0, g.ridge_ramp, _out(x, play_radius)))


## The ground's height at (x, z): the ridge's crest, falling off into
## valleys with rolling hills, rising into far ranges toward the horizon.
static func ground_height(x: float, z: float, play_radius: float) -> float:
	var g := Tuning.arena_great_wall
	var off := maxf(ridge_distance(x, z, play_radius) - ridge_crest(x, play_radius), 0.0)
	var k := off / g.ridge_width
	var fall := 1.0 - exp(-k * k)
	var n := _terrain_noise()
	var h := ridge_y(x, play_radius) - g.valley_depth * fall
	h += g.hill_amplitude * fall * n.get_noise_2d(x, z)
	# Far ranges only well away from the wall, so it keeps to its crest.
	var far := smoothstep(g.far_start, g.far_end, Vector2(x, z).length()) * smoothstep(1.0, 2.5, k)
	h += g.far_amplitude * far * (0.55 + 0.45 * n.get_noise_2d(z * 1.7 + 900.0, x * 1.7))
	return h


## The wall leaving the terrace on side +1 (+X) or -1 (-X): walkway centre
## points, from the terrace's outer face outward.
static func wall_path(side: float, play_radius: float) -> PackedVector3Array:
	var g := Tuning.arena_great_wall
	var out := PackedVector3Array()
	var start := terrace_outer(play_radius)
	var steps := int(g.wall_length / g.wall_step)
	for i in steps + 1:
		var x := side * (start + i * g.wall_step)
		out.append(Vector3(x, walk_y(x, play_radius), ridge_z(x, play_radius)))
	return out


## Low prop spots (x, z): rings around the play circle, inside the camera's
## reach, so nothing on them may stand taller than a jar.
static func low_prop_spots(play_radius: float) -> PackedVector2Array:
	var g := Tuning.arena_great_wall
	var out := PackedVector2Array()
	for row in g.prop_row_gaps.size():
		var r := play_radius + g.prop_row_gaps[row]
		var count := maxi(int(TAU * r / g.prop_spacing), 1)
		for i in count:
			var a := TAU * (i + 0.5 * (row % 2)) / count
			out.append(Vector2(cos(a), sin(a)) * r)
	return out


## Banner pole spots (x, z) along the inside of the parapets, clear of the
## wall's two openings and of the gate tower.
static func banner_spots(play_radius: float) -> PackedVector2Array:
	var g := Tuning.arena_great_wall
	var at := terrace_half(play_radius) - 0.8
	var count := int(at * 2.0 / g.banner_spacing)
	var out := PackedVector2Array()
	for i in count + 1:
		var u := -at + at * 2.0 * i / maxf(count, 1)
		for spot: Vector2 in [Vector2(u, at), Vector2(u, -at), Vector2(at, u), Vector2(-at, u)]:
			if absf(spot.x) >= at - 0.01 and absf(spot.y) >= at - 0.01:
				continue  # the corners hold the lanterns
			if absf(spot.x) >= at - 0.01 and absf(spot.y) < g.walkway_width * 0.5 + 1.5:
				continue  # the wall's openings on +X and -X
			if spot.y < 0.0 and absf(spot.y) >= at - 0.01 and absf(spot.x) < g.gate_width * 0.5 + 1.0:
				continue  # the gate tower's face
			if not out.has(spot):
				out.append(spot)
	return out


## Stone lanterns in the terrace's four corners.
static func lantern_spots(play_radius: float) -> PackedVector2Array:
	var at := terrace_half(play_radius) - 1.4
	return PackedVector2Array([Vector2(at, at), Vector2(-at, at), Vector2(at, -at), Vector2(-at, -at)])


static func _terrain_noise() -> FastNoiseLite:
	var g := Tuning.arena_great_wall
	var key := Vector2(g.scenery_seed, g.hill_scale)
	if _noise == null or _noise_key != key:
		_noise = FastNoiseLite.new()
		_noise.seed = g.scenery_seed
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = g.hill_scale
		_noise.fractal_octaves = 3
		_noise_key = key
	return _noise


# --- stage ----------------------------------------------------------------------

func _build_ground() -> void:
	var g := Tuning.arena_great_wall
	_rng.seed = g.scenery_seed
	_prop_mat = PropMesh.material()
	_brick_mat = ShaderMaterial.new()
	var brick := Shader.new()
	brick.code = BRICK_SHADER.replace("//NOISE", PropArena.NOISE_GLSL)
	_brick_mat.shader = brick
	_brick_mat.set_shader_parameter("mortar", g.mortar_color)
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)

	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TERRACE_SHADER.replace("//NOISE", PropArena.NOISE_GLSL)
	mat.shader = sh
	mat.set_shader_parameter("stone_light", g.paving_light)
	mat.set_shader_parameter("stone_dark", g.paving_dark)
	mat.set_shader_parameter("moss", g.moss_color)
	mat.set_shader_parameter("inlay", g.inlay_color)
	mat.set_shader_parameter("inlay_red", g.inlay_red)
	mat.set_shader_parameter("radius", radius)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * terrace_outer(radius) * 2.0
	plane.material = mat
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Terrace"
	floor_mi.mesh = plane
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mi)
	_build_floor_body()
	_build_terrain()
	_build_mist()


## The play boundary: a red cord on short stone posts, in place of the
## energy wall.
func _build_ring() -> void:
	var g := Tuning.arena_great_wall
	var post := PropMesh.new()
	post.block(Vector3(0.0, g.post_height * 0.5, 0.0), Vector3(0.2, g.post_height, 0.2), g.paving_dark)
	post.block(Vector3(0.0, g.post_height + 0.04, 0.0), Vector3(0.28, 0.08, 0.28), g.paving_light)
	var posts: Array = []
	var ring_at := radius + 0.15
	var count := maxi(int(TAU * ring_at / g.post_spacing), 3)
	for i in count:
		var a := TAU * i / count
		posts.append([Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0.0, sin(a)) * ring_at), Color.WHITE])
	_batch("Posts", post.commit(), posts)

	var cord := PropMesh.new()
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cord_y := g.post_height - 0.06
	for i in count * CORD_POINTS_PER_POST + 1:
		var t := float(i) / CORD_POINTS_PER_POST
		var a := TAU * t / count
		var u := 2.0 * fmod(t, 1.0) - 1.0
		points.append(Vector3(cos(a) * ring_at, cord_y - CORD_SAG * (1.0 - u * u), sin(a) * ring_at))
		radii.append(CORD_RADIUS)
	cord.tube(points, radii, 5, g.cord_color)
	_add_static("Cord", cord.commit())


func _build_scenery() -> void:
	_rng.seed = look().scenery_seed
	_build_bastion()
	_build_gate_tower()
	_build_wall(1.0)
	_build_wall(-1.0)
	_build_low_props()
	_build_banners()
	_build_trees()


func _build_terrain() -> void:
	var g := Tuning.arena_great_wall
	var n := g.terrain_cells
	var size := g.terrain_size
	var cell := size / n
	var half := size * 0.5
	_heights.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			_heights[j * (n + 1) + i] = ground_height(-half + i * cell, -half + j * cell, radius)
	var m := PropMesh.new()
	var hidden := terrace_half(radius) - cell
	var far_reach := Tuning.camera.far
	for j in n:
		for i in n:
			var x0 := -half + i * cell
			var z0 := -half + j * cell
			if maxf(absf(x0 + cell * 0.5), absf(z0 + cell * 0.5)) < hidden:
				continue  # under the terrace
			if Vector2(x0 + cell * 0.5, z0 + cell * 0.5).length() > far_reach + cell:
				continue  # past the far plane
			var p00 := Vector3(x0, _heights[j * (n + 1) + i], z0)
			var p10 := Vector3(x0 + cell, _heights[j * (n + 1) + i + 1], z0)
			var p01 := Vector3(x0, _heights[(j + 1) * (n + 1) + i], z0 + cell)
			var p11 := Vector3(x0 + cell, _heights[(j + 1) * (n + 1) + i + 1], z0 + cell)
			_ground_tri(m, p00, p10, p11)
			_ground_tri(m, p00, p11, p01)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = m.commit()
	mi.material_override = _prop_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## One terrain triangle, facing up, coloured by its slope and place: rock on
## steep faces and high crests, autumn grass elsewhere, hazed far away.
func _ground_tri(m: PropMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	var g := Tuning.arena_great_wall
	var normal := (b - a).cross(c - a)
	if normal.y < 0.0:
		var t := b
		b = c
		c = t
		normal = -normal
	var up := normal.normalized().y
	var mid := (a + b + c) / 3.0
	var tone := _rng.randf()
	var color := g.grass_color.lerp(g.slope_color, clampf(tone * 0.7 + (1.0 - up) * 1.5, 0.0, 1.0))
	color = color.lerp(look().rock_color, (1.0 - smoothstep(0.68, 0.82, up)) * 0.85)
	color = color.lerp(look().rock_color, smoothstep(30.0, 70.0, mid.y) * 0.6)
	color = color.lerp(g.far_color, smoothstep(g.far_start, g.far_end, Vector2(mid.x, mid.z).length()) * 0.45)
	m.tri(a, b, c, color)


## The terrain mesh's own height at (x, z) (its triangles, not ground_height),
## so trees stand on what is drawn.
func _mesh_height(x: float, z: float) -> float:
	var g := Tuning.arena_great_wall
	var n := g.terrain_cells
	var cell := g.terrain_size / n
	var gx := clampf((x + g.terrain_size * 0.5) / cell, 0.0, n - 0.001)
	var gz := clampf((z + g.terrain_size * 0.5) / cell, 0.0, n - 0.001)
	var i := int(gx)
	var j := int(gz)
	var fx := gx - i
	var fz := gz - j
	var h00 := _heights[j * (n + 1) + i]
	var h10 := _heights[j * (n + 1) + i + 1]
	var h01 := _heights[(j + 1) * (n + 1) + i]
	var h11 := _heights[(j + 1) * (n + 1) + i + 1]
	if fx >= fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz


func _build_mist() -> void:
	var g := Tuning.arena_great_wall
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MIST_SHADER.replace("//NOISE", PropArena.NOISE_GLSL)
	mat.shader = sh
	mat.set_shader_parameter("mist", g.mist_color)
	mat.set_shader_parameter("fade_to", Tuning.camera.far - FAR_MARGIN)
	mat.set_shader_parameter("fade_from", Tuning.camera.far - FAR_MARGIN * 4.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * g.terrain_size
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "Mist"
	mi.mesh = plane
	mi.position.y = g.mist_height
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## The terrace's body down to the ridge, and its battlemented parapet.
func _build_bastion() -> void:
	var g := Tuning.arena_great_wall
	var th := terrace_half(radius)
	var to := terrace_outer(radius)
	var bottom := 0.0
	for i in 9:
		var u := -to + to * 2.0 * i / 8.0
		for spot: Vector2 in [Vector2(u, to), Vector2(u, -to), Vector2(to, u), Vector2(-to, u)]:
			bottom = minf(bottom, ground_height(spot.x, spot.y, radius))
	bottom -= g.wall_footing
	var m := PropMesh.new()
	var corners := [Vector3(-to, 0.0, -to), Vector3(to, 0.0, -to), Vector3(to, 0.0, to), Vector3(-to, 0.0, to)]
	for k in 4:
		var a: Vector3 = corners[k]
		var b: Vector3 = corners[(k + 1) % 4]
		var outward := ((a + b) * 0.5).normalized()
		_face(m, a + Vector3.UP * bottom, b + Vector3.UP * bottom, b, a, g.brick_color, outward)
		# A plinth course a little proud, halfway down.
		var band_y := bottom * 0.35
		var proud := outward * 0.25
		_face(m, a + proud + Vector3.UP * (band_y - 0.4), b + proud + Vector3.UP * (band_y - 0.4),
				b + proud + Vector3.UP * band_y, a + proud + Vector3.UP * band_y, g.brick_dark, outward)
	# Parapets: (from, to) along each side, and which side.
	var hw := g.walkway_width * 0.5
	var mid := th + g.parapet_thickness * 0.5
	var runs: Array = [
		[Vector3(0.0, 0.0, mid), Vector3.RIGHT, -to, to],                       # +Z
		[Vector3(0.0, 0.0, -mid), Vector3.RIGHT, -to, -g.gate_width * 0.5],     # -Z, left of the gate
		[Vector3(0.0, 0.0, -mid), Vector3.RIGHT, g.gate_width * 0.5, to],       # -Z, right of the gate
		[Vector3(mid, 0.0, 0.0), Vector3.BACK, -th, -hw],                       # +X, either side of the wall
		[Vector3(mid, 0.0, 0.0), Vector3.BACK, hw, th],
		[Vector3(-mid, 0.0, 0.0), Vector3.BACK, -th, -hw],                      # -X
		[Vector3(-mid, 0.0, 0.0), Vector3.BACK, hw, th],
	]
	for run: Array in runs:
		var base: Vector3 = run[0]
		var along: Vector3 = run[1]
		var u0: float = run[2]
		var u1: float = run[3]
		_parapet(m, base + along * u0, base + along * u1, 0.0)
	_add_brick("Bastion", m.commit())


## A straight parapet with merlons from `a` to `b` (centre line), standing
## on floor height y.
func _parapet(m: PropMesh, a: Vector3, b: Vector3, y: float) -> void:
	var g := Tuning.arena_great_wall
	var along := b - a
	var length := along.length()
	if length < 0.1:
		return
	var dir := along / length
	var right := Vector3(-dir.z, 0.0, dir.x)
	var basis := Basis(right, Vector3.UP, -dir)
	var centre := (a + b) * 0.5 + Vector3.UP * (y + g.parapet_height * 0.5)
	m.box(Transform3D(basis, centre), Vector3(g.parapet_thickness, g.parapet_height, length), g.brick_color)
	var count := maxi(int(length / g.merlon_spacing), 1)
	for i in count:
		var at := a + dir * (length * (i + 0.5) / count) + Vector3.UP * (y + g.parapet_height + g.merlon_height * 0.5)
		m.box(Transform3D(basis, at), Vector3(g.parapet_thickness, g.merlon_height, g.merlon_width), g.brick_color)


## The gate tower on the -Z side: a brick storey with an arched gate, its
## own battlements, and a red pavilion with a double-eaved roof on top.
func _build_gate_tower() -> void:
	var g := Tuning.arena_great_wall
	var th := terrace_half(radius)
	var hx := g.gate_width * 0.5
	var z_face := -th
	var z_back := -th - g.gate_depth
	var zc := (z_face + z_back) * 0.5
	var hz := g.gate_depth * 0.5
	var top := g.gate_base_height
	var bottom := minf(ground_height(-hx, z_back, radius), ground_height(hx, z_back, radius)) - g.wall_footing
	var brick := PropMesh.new()
	brick.block(Vector3(0.0, (top + bottom) * 0.5, zc), Vector3(g.gate_width, top - bottom, g.gate_depth), g.brick_color)
	brick.block(Vector3(0.0, top + 0.12, zc), Vector3(g.gate_width + 0.3, 0.24, g.gate_depth + 0.3), g.brick_dark)
	var y := top + 0.24
	var pt := g.parapet_thickness
	_parapet(brick, Vector3(-hx, 0.0, z_face - pt * 0.5), Vector3(hx, 0.0, z_face - pt * 0.5), y)
	_parapet(brick, Vector3(-hx, 0.0, z_back + pt * 0.5), Vector3(hx, 0.0, z_back + pt * 0.5), y)
	for sx: float in [-1.0, 1.0]:
		_parapet(brick, Vector3(sx * (hx - pt * 0.5), 0.0, z_back + pt), Vector3(sx * (hx - pt * 0.5), 0.0, z_face - pt), y)
	_add_brick("GateTower", brick.commit())

	var m := PropMesh.new()
	var dark := Color(0.06, 0.05, 0.05)
	var stone := g.paving_light
	var front := z_face + 0.03
	# The gate: a dark arched opening in a stone frame, a plaque above it.
	var door_w := DOOR_SIZE.x
	var door_h := DOOR_SIZE.y
	m.block(Vector3(0.0, door_h * 0.5 + 0.5, front + 0.02), Vector3(door_w + 1.0, door_h + 1.0, 0.06), stone)
	m.block(Vector3(0.0, door_h * 0.5 - 0.4, front + 0.06), Vector3(door_w, door_h - 0.8, 0.04), dark)
	_arch(m, Vector3(0.0, door_h - 0.8, front + 0.061), door_w * 0.5, dark)
	_arch(m, Vector3(0.0, door_h - 0.8, front + 0.03), door_w * 0.5 + 0.5, stone)
	m.block(Vector3(0.0, door_h + 1.3, front + 0.08), Vector3(2.6, 0.9, 0.1), g.gold_color)
	m.block(Vector3(0.0, door_h + 1.3, front + 0.1), Vector3(2.3, 0.7, 0.1), g.lacquer_red)
	# Arrow slits either side.
	for sx: float in [-1.0, 1.0]:
		for row in 2:
			var at := Vector3(sx * (hx - 2.6), 1.8 + row * 2.4, front + 0.04)
			m.block(at, Vector3(0.5, 1.1, 0.04), dark)
			_arch(m, at + Vector3(0.0, 0.55, 0.001), 0.25, dark)

	# The pavilion.
	var py := y
	var px := hx - 2.2
	var pz := hz - 1.8
	var ph := g.pavilion_height
	m.block(Vector3(0.0, py + 0.15, zc), Vector3(px * 2.0 + 0.8, 0.3, pz * 2.0 + 0.8), stone)
	m.block(Vector3(0.0, py + 0.3 + ph * 0.45, zc), Vector3(px * 2.0 - 1.0, ph * 0.9, pz * 2.0 - 1.0), g.lacquer_red)
	var cols_x := 6
	for i in cols_x:
		var x := -px + px * 2.0 * i / (cols_x - 1)
		for sz: float in [-1.0, 1.0]:
			m.rod(Vector3(x, py + 0.3, zc + sz * pz), Vector3(x, py + 0.3 + ph, zc + sz * pz), 0.26, 0.24, 8, g.lacquer_red)
	for sx: float in [-1.0, 1.0]:
		m.rod(Vector3(sx * px, py + 0.3, zc), Vector3(sx * px, py + 0.3 + ph, zc), 0.26, 0.24, 8, g.lacquer_red)
	# Lattice windows on the front, between the columns.
	for i in cols_x - 1:
		var x := -px + px * 2.0 * (i + 0.5) / (cols_x - 1)
		var wz := zc + pz - 0.48
		m.block(Vector3(x, py + 0.3 + ph * 0.5, wz), Vector3(1.5, ph * 0.5, 0.06), g.gold_color)
		m.block(Vector3(x, py + 0.3 + ph * 0.5, wz + 0.02), Vector3(1.3, ph * 0.42, 0.06), dark)
	# Painted beams, then the lower eave.
	var beam_y := py + 0.3 + ph
	m.block(Vector3(0.0, beam_y - 0.25, zc), Vector3(px * 2.0 + 0.7, 0.5, pz * 2.0 + 0.7), g.roof_trim)
	m.block(Vector3(0.0, beam_y - 0.3, zc), Vector3(px * 2.0 + 0.75, 0.12, pz * 2.0 + 0.75), g.gold_color)
	var e := g.roof_eave
	_hip_roof(m, Vector3(0.0, beam_y, zc), px + e, pz + e, g.roof_height * 0.38, 0.55, g.roof_tile, g.roof_trim)
	# Upper storey and its roof.
	var ux := px * 0.62
	var uz := pz * 0.62
	var uh := 2.2
	var uy := beam_y + g.roof_height * 0.25
	m.block(Vector3(0.0, uy + uh * 0.5, zc), Vector3(ux * 2.0, uh, uz * 2.0), g.lacquer_red)
	for i in 3:
		var x := -ux + ux * 2.0 * (i + 0.5) / 3.0
		m.block(Vector3(x, uy + uh * 0.5, zc + uz + 0.02), Vector3(1.2, uh * 0.55, 0.06), dark)
	m.block(Vector3(0.0, uy + uh - 0.2, zc), Vector3(ux * 2.0 + 0.4, 0.4, uz * 2.0 + 0.4), g.roof_trim)
	_hip_roof(m, Vector3(0.0, uy + uh, zc), ux + e, uz + e, g.roof_height, 0.75, g.roof_tile, g.roof_trim)
	var crest := uy + uh + g.roof_height
	for sx: float in [-1.0, 1.0]:
		var at := Vector3(sx * maxf(ux - uz, 0.0) + sx * 0.3, crest, zc)
		m.rod(at, at + Vector3.UP * 0.9, 0.22, 0.05, 6, g.gold_color)
	_add_static("Pavilion", m.commit())


## A half disc standing on `base` (its diameter), facing +Z.
static func _arch(m: PropMesh, base: Vector3, r: float, color: Color) -> void:
	var parts := 10
	for i in parts:
		var a0 := PI * i / parts
		var a1 := PI * (i + 1) / parts
		var p0 := base + Vector3(cos(a0), sin(a0), 0.0) * r
		var p1 := base + Vector3(cos(a1), sin(a1), 0.0) * r
		_tri_facing(m, base, p0, p1, color, Vector3.BACK)


## A hipped roof whose slopes sag between eave and ridge and whose corners
## lift: the curve of a Chinese roof in two bands per slope. `base` is the
## middle of the eave line; the ridge runs along X.
static func _hip_roof(m: PropMesh, base: Vector3, hx: float, hz: float, height: float, curl: float,
		color: Color, under: Color) -> void:
	var rx := maxf(hx - hz, 0.3)
	var top := base.y + height
	var sides: Array = [
		[Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(-rx, 0, 0), Vector3(rx, 0, 0), Vector3.FORWARD],
		[Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(rx, 0, 0), Vector3(rx, 0, 0), Vector3.RIGHT],
		[Vector3(hx, 0, hz), Vector3(-hx, 0, hz), Vector3(rx, 0, 0), Vector3(-rx, 0, 0), Vector3.BACK],
		[Vector3(-hx, 0, hz), Vector3(-hx, 0, -hz), Vector3(-rx, 0, 0), Vector3(-rx, 0, 0), Vector3.LEFT],
	]
	# Across each slope: corner, near the corner, middle, ... The eave lifts
	# only toward the corners.
	var across: Array[float] = [0.0, 0.2, 0.5, 0.8, 1.0]
	for k in sides.size():
		var s: Array = sides[k]
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var ra: Vector3 = s[2]
		var rb: Vector3 = s[3]
		var outward: Vector3 = s[4] + Vector3.UP
		var eave: Array[Vector3] = []
		var midrow: Array[Vector3] = []
		var ridge: Array[Vector3] = []
		for t in across:
			var edge := absf(2.0 * t - 1.0)
			var lift := curl * edge * edge * edge
			var e := a.lerp(b, t) + Vector3.UP * lift
			var r := ra.lerp(rb, t) + Vector3.UP * height
			var p := e.lerp(r, 0.5)
			p.y = height * 0.28 + lift * 0.4
			eave.append(e)
			midrow.append(p)
			ridge.append(r)
		var shade := color.darkened(0.06 * k)
		for i in across.size() - 1:
			_face(m, base + eave[i], base + eave[i + 1], base + midrow[i + 1], base + midrow[i], shade, outward)
			_face(m, base + midrow[i], base + midrow[i + 1], base + ridge[i + 1], base + ridge[i], shade, outward)
			# Eave edge trim, seen from below and from the side.
			_face(m, base + eave[i] + Vector3.DOWN * 0.18, base + eave[i + 1] + Vector3.DOWN * 0.18,
					base + eave[i + 1], base + eave[i], under, s[4])
	_face(m, base + Vector3(-hx, -0.1, -hz), base + Vector3(hx, -0.1, -hz),
			base + Vector3(hx, -0.1, hz), base + Vector3(-hx, -0.1, hz), under, Vector3.DOWN)
	m.block(Vector3(base.x, top + 0.12, base.z), Vector3(rx * 2.0 + 0.5, 0.3, 0.4), color.darkened(0.3))


## One branch of the wall (side +1: +X), its body down past the ridge, the
## walkway, parapets with merlons on both sides, and its watchtowers.
func _build_wall(side: float) -> void:
	var g := Tuning.arena_great_wall
	var path := wall_path(side, radius)
	var hw := g.walkway_width * 0.5
	var ow := hw + g.parapet_thickness
	var ph := g.parapet_height
	var depth := g.terrace_height + g.wall_footing
	var rights: Array[Vector3] = []
	for i in path.size():
		var t := path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]
		t.y = 0.0
		t = t.normalized()
		rights.append(Vector3(-t.z, 0.0, t.x) * side)
	var m := PropMesh.new()
	for i in path.size() - 1:
		var p0 := path[i]
		var p1 := path[i + 1]
		var r0 := rights[i]
		var r1 := rights[i + 1]
		var up := Vector3.UP
		var stone := g.walkway_color.darkened(0.05 * (i % 2))
		_face(m, p0 - r0 * hw, p1 - r1 * hw, p1 + r1 * hw, p0 + r0 * hw, stone, up)
		for s: float in [-1.0, 1.0]:
			var out_dir := r0 * s
			# Inner face of the parapet, its top, then the outer face down
			# past the ridge.
			_face(m, p0 + r0 * s * hw, p1 + r1 * s * hw, p1 + r1 * s * hw + up * ph, p0 + r0 * s * hw + up * ph, g.brick_color, -out_dir)
			_face(m, p0 + r0 * s * hw + up * ph, p1 + r1 * s * hw + up * ph, p1 + r1 * s * ow + up * ph, p0 + r0 * s * ow + up * ph, g.brick_color, up)
			_face(m, p0 + r0 * s * ow - up * depth, p1 + r1 * s * ow - up * depth, p1 + r1 * s * ow + up * ph, p0 + r0 * s * ow + up * ph, g.brick_color, out_dir)
			# Merlons.
			var seg := p1 - p0
			var count := maxi(int(Vector2(seg.x, seg.z).length() / g.merlon_spacing), 1)
			var dir := Vector3(seg.x, 0.0, seg.z).normalized()
			var basis := Basis(Vector3(-dir.z, 0.0, dir.x), Vector3.UP, -dir)
			for k in count:
				var f := (k + 0.5) / count
				var at := p0.lerp(p1, f) + r0.lerp(r1, f) * s * (hw + g.parapet_thickness * 0.5) + up * (ph + g.merlon_height * 0.5)
				m.box(Transform3D(basis, at), Vector3(g.parapet_thickness, g.merlon_height, g.merlon_width), g.brick_color)
	# Close the far end.
	var last := path.size() - 1
	var end_out := (path[last] - path[last - 1]).normalized()
	var re := rights[last]
	_face(m, path[last] - re * ow - Vector3.UP * depth, path[last] + re * ow - Vector3.UP * depth,
			path[last] + re * ow + Vector3.UP * ph, path[last] - re * ow + Vector3.UP * ph, g.brick_dark, end_out)
	_add_brick("WallEast" if side > 0.0 else "WallWest", m.commit())

	var tower := _watchtower_mesh()
	var towers: Array = []
	var along := g.watchtower_first
	while along < g.wall_length - g.wall_step:
		var i := int(along / g.wall_step)
		var t := path[i + 1] - path[i]
		var yaw := atan2(t.x, t.z)
		towers.append([Transform3D(Basis(Vector3.UP, yaw), path[i]), Color.WHITE.darkened(_rng.randf_range(0.0, 0.12))])
		along += g.watchtower_spacing * _rng.randf_range(0.8, 1.2)
	_batch("WatchtowersEast" if side > 0.0 else "WatchtowersWest", tower, towers, _brick_mat)


## A watchtower astride the walkway (local +Z along the wall), origin at the
## walkway's level.
func _watchtower_mesh() -> ArrayMesh:
	var g := Tuning.arena_great_wall
	var s := g.watchtower_size
	var depth := g.terrace_height + g.wall_footing
	var m := PropMesh.new()
	m.block(Vector3(0.0, (s.y - depth) * 0.5, 0.0), Vector3(s.x, s.y + depth, s.z), g.brick_color)
	m.block(Vector3(0.0, s.y + 0.1, 0.0), Vector3(s.x + 0.3, 0.2, s.z + 0.3), g.brick_dark)
	var hx := s.x * 0.5 - g.parapet_thickness * 0.5
	var hz := s.z * 0.5 - g.parapet_thickness * 0.5
	_parapet(m, Vector3(-hx, 0.0, hz), Vector3(hx, 0.0, hz), s.y + 0.2)
	_parapet(m, Vector3(hx, 0.0, -hz), Vector3(-hx, 0.0, -hz), s.y + 0.2)
	_parapet(m, Vector3(hx, 0.0, hz - 0.7), Vector3(hx, 0.0, -hz + 0.7), s.y + 0.2)
	_parapet(m, Vector3(-hx, 0.0, -hz + 0.7), Vector3(-hx, 0.0, hz - 0.7), s.y + 0.2)
	var dark := Color(0.08, 0.07, 0.07)
	# Arched windows on the long sides, the walkway's doors on the ends.
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			var at := Vector3(sx * (s.x * 0.5 + 0.02), s.y * 0.45, (k - 1) * s.z * 0.28)
			m.block(at, Vector3(0.04, 1.4, 0.8), dark)
	for sz: float in [-1.0, 1.0]:
		m.block(Vector3(0.0, 1.1, sz * (s.z * 0.5 + 0.02)), Vector3(1.8, 2.2, 0.04), dark)
	return m.commit()


## Wine jars and stacked bricks in the rings around the cord: low enough for
## the camera to pass over.
func _build_low_props() -> void:
	var g := Tuning.arena_great_wall
	var jars: Array = []
	var bricks: Array = []
	for spot in low_prop_spots(radius):
		if _rng.randf() < g.prop_skip_chance:
			continue
		var pos := Vector3(spot.x, 0.0, spot.y)
		if _rng.randf() < 0.6:
			for n in _rng.randi_range(1, 3):
				var off := Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5))
				var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + off)
				if _rng.randf() < 0.15:  # knocked over in the fight
					xf.basis = xf.basis * Basis(Vector3.RIGHT, PI * 0.5)
					xf.origin.y += 0.25
				jars.append([xf, Color.WHITE])
		else:
			bricks.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos), Color.WHITE.darkened(_rng.randf_range(0.0, 0.15))])
	_batch("Jars", _jar_mesh(), jars)
	_batch("BrickStacks", _brick_stack_mesh(), bricks)

	var lanterns: Array = []
	for spot in lantern_spots(radius):
		lanterns.append([Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(spot.x, 0.0, spot.y)), Color.WHITE])
	_batch("Lanterns", _lantern_mesh(), lanterns)


func _build_banners() -> void:
	var g := Tuning.arena_great_wall
	var pole := PropMesh.new()
	pole.rod(Vector3.ZERO, Vector3.UP * g.banner_height, 0.07, 0.05, 6, Color(0.25, 0.16, 0.1))
	pole.rod(Vector3.UP * g.banner_height, Vector3.UP * (g.banner_height + 0.45), 0.1, 0.0, 6, g.gold_color)
	pole.block(Vector3(FLAG_SIZE.x * 0.5, g.banner_height - 0.1, 0.0), Vector3(FLAG_SIZE.x + 0.15, 0.06, 0.06), Color(0.25, 0.16, 0.1))
	var flag := PropMesh.new()
	var top := g.banner_height - 0.15
	var parts := 4
	for i in parts:
		var x0 := FLAG_SIZE.x * i / parts
		var x1 := FLAG_SIZE.x * (i + 1) / parts
		flag.two_sided_quad(Vector3(x0, top - FLAG_SIZE.y, 0.0), Vector3(x1, top - FLAG_SIZE.y, 0.0),
				Vector3(x1, top, 0.0), Vector3(x0, top, 0.0), Color.WHITE)
	var poles: Array = []
	var flags: Array = []
	var spots := banner_spots(radius)
	for i in spots.size():
		var at := Vector3(spots[i].x, 0.0, spots[i].y)
		# The cloth's face toward the middle of the terrace.
		var xf := Transform3D(Basis(Vector3.UP, atan2(-at.x, -at.z)), at)
		poles.append([xf, Color.WHITE])
		flags.append([xf, g.banner_colors[i % g.banner_colors.size()]])
	_batch("BannerPoles", pole.commit(), poles)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FLAG_SHADER
	mat.shader = sh
	_batch("Banners", flag.commit(), flags, mat)


func _build_trees() -> void:
	var g := Tuning.arena_great_wall
	var conifers: Array = []
	var broadleaves: Array = []
	var half := g.terrain_size * 0.5 - 20.0
	var near := terrace_outer(radius) + 18.0
	var reach := minf(half, Tuning.camera.far - FAR_MARGIN)
	var attempts := 0
	while conifers.size() + broadleaves.size() < g.tree_count and attempts < g.tree_count * 6:
		attempts += 1
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		var dist := Vector2(x, z).length()
		if dist < near or dist > reach:
			continue
		if ridge_distance(x, z, radius) < ridge_crest(x, radius) + g.tree_wall_clear:
			continue
		var y := _mesh_height(x, z)
		if y > 40.0 or y < g.mist_height - 25.0:
			continue  # bare crests; nothing to see under the mist
		var slope := Vector2(_mesh_height(x + 2.0, z) - y, _mesh_height(x, z + 2.0) - y).length() / 2.0
		if slope > 1.1:
			continue
		var h := _rng.randf_range(g.tree_min_height, g.tree_max_height)
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(h, h, h) * Vector3(_rng.randf_range(0.85, 1.15), 1.0, 1.0)),
				Vector3(x, y - 0.3, z))
		var color: Color = g.tree_colors[_rng.randi() % g.tree_colors.size()]
		if _rng.randf() < g.conifer_share:
			conifers.append([xf, g.tree_colors[g.tree_colors.size() - 1 - (_rng.randi() % 2)]])
		else:
			broadleaves.append([xf, color])
	_batch("Conifers", _conifer_mesh(), conifers)
	_batch("Trees", _broadleaf_mesh(), broadleaves)


# --- helpers ------------------------------------------------------------------

## A quad facing `outward`, whatever order its corners come in.
static func _face(m: PropMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	if (b - a).cross(d - a).dot(outward) >= 0.0:
		m.quad(a, b, c, d, color)
	else:
		m.quad(d, c, b, a, color)


static func _tri_facing(m: PropMesh, a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) >= 0.0:
		m.tri(a, b, c, color)
	else:
		m.tri(a, c, b, color)


func _add_static(node_name: String, mesh: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _prop_mat
	_props.add_child(mi)


func _add_brick(node_name: String, mesh: ArrayMesh) -> void:
	_add_static(node_name, mesh)
	(_props.get_child(-1) as MeshInstance3D).material_override = _brick_mat


## items: [Transform3D, Color] pairs. `mat` null = the prop material.
func _batch(node_name: String, mesh: Mesh, items: Array, mat: Material = null) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.name = node_name
	mi.multimesh = mm
	mi.material_override = mat if mat != null else _prop_mat
	_props.add_child(mi)


# --- prop meshes (local origin on the ground) --------------------------------

## A glazed wine jar with a red cloth over its mouth.
static func _jar_mesh() -> ArrayMesh:
	var g := Tuning.arena_great_wall
	var m := PropMesh.new()
	var h := JAR_HEIGHT
	m.tube(PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.UP * h * 0.18, Vector3.UP * h * 0.5,
			Vector3.UP * h * 0.8, Vector3.UP * h * 0.9, Vector3.UP * h]),
			PackedFloat32Array([0.0, 0.15, 0.24, 0.27, 0.2, 0.12, 0.12]), 9, g.jar_color)
	m.rod(Vector3.UP * (h - 0.04), Vector3.UP * (h + 0.06), 0.16, 0.08, 9, g.lacquer_red)
	return m.commit()


## Spare wall bricks, three courses.
static func _brick_stack_mesh() -> ArrayMesh:
	var g := Tuning.arena_great_wall
	var m := PropMesh.new()
	var size := Vector3(0.4, 0.1, 0.2)
	for row in 3:
		for i in 3 - row:
			for k in 2:
				var c := g.brick_color if (i + k + row) % 2 == 0 else g.brick_dark
				if row % 2 == 0:
					m.block(Vector3((i - 1.0 + row * 0.5) * 0.42, size.y * (row + 0.5), (k - 0.5) * 0.42), size, c)
				else:
					m.block(Vector3((k - 0.5) * 0.42, size.y * (row + 0.5), (i - 1.0 + row * 0.5) * 0.42 * 0.5), Vector3(size.z, size.y, size.x), c)
	return m.commit()


## A stone lantern: plinth, shaft, the open light box, a little roof.
static func _lantern_mesh() -> ArrayMesh:
	var g := Tuning.arena_great_wall
	var m := PropMesh.new()
	var stone := g.paving_dark
	var h := LANTERN_HEIGHT
	m.block(Vector3(0.0, 0.15, 0.0), Vector3(0.8, 0.3, 0.8), stone)
	m.rod(Vector3.UP * 0.3, Vector3.UP * h * 0.55, 0.16, 0.14, 8, stone)
	m.block(Vector3(0.0, h * 0.58, 0.0), Vector3(0.7, 0.12, 0.7), stone)
	m.block(Vector3(0.0, h * 0.7, 0.0), Vector3(0.44, 0.4, 0.44), g.gold_color.lightened(0.3))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.block(Vector3(sx * 0.24, h * 0.7, sz * 0.24), Vector3(0.1, 0.42, 0.1), stone)
	m.rod(Vector3.UP * h * 0.8, Vector3.UP * h * 0.97, 0.62, 0.05, 4, stone)
	m.rod(Vector3.UP * h * 0.95, Vector3.UP * h, 0.08, 0.0, 6, stone)
	return m.commit()


## An evergreen, 1 m tall (scaled per instance), crown tinted.
static func _conifer_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	m.rod(Vector3.ZERO, Vector3.UP * 0.3, 0.05, 0.04, 5, Color(0.45, 0.38, 0.32))
	m.rod(Vector3.UP * 0.18, Vector3.UP * 0.7, 0.3, 0.0, 7, Color.WHITE)
	m.rod(Vector3.UP * 0.45, Vector3.UP * 1.0, 0.22, 0.0, 7, Color.WHITE.darkened(0.1))
	return m.commit()


## A broadleaf tree in autumn colours, 1 m tall (scaled per instance).
static func _broadleaf_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	m.rod(Vector3.ZERO, Vector3.UP * 0.45, 0.05, 0.035, 5, Color(0.45, 0.38, 0.32))
	m.tube(PackedVector3Array([Vector3.UP * 0.3, Vector3.UP * 0.3, Vector3.UP * 0.42, Vector3.UP * 0.66,
			Vector3.UP * 0.9, Vector3.UP * 1.0]),
			PackedFloat32Array([0.0, 0.16, 0.34, 0.38, 0.24, 0.0]), 7, Color.WHITE)
	return m.commit()
