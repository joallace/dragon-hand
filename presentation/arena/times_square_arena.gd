class_name TimesSquareArena
extends PropArena
## Times Square at night: the fight is in the pedestrian plaza at the middle
## of the bowtie, inside a ring of police barricades. Visual only, like every
## Arena: everything stands outside the play circle of `radius`, and anything
## taller than a café table beyond the camera's limit. The avenues run along Z
## on both sides, jammed with taxis; the facades are covered in screens.
## Looking at +Z: café tables, the glowing red steps, a cross street. Looking
## at -Z: food carts, a cross street, the screen-clad tower with the ball.
## Reads Tuning.arena_times_square (data/tuning/arena_times_square.tres).
## Brands on the screens are fictional (TimesSquareArenaTuning.brands).

const STREET_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 paver_light : source_color;
uniform vec4 paver_dark : source_color;
uniform vec4 asphalt : source_color;
uniform vec4 lane_paint : source_color;
uniform vec4 curb : source_color;
uniform vec4 sidewalk : source_color;
uniform float radius = 18.0;
uniform float curb_x = 27.0;
uniform float road_width = 11.0;
uniform float lane_count = 3.0;
uniform float sidewalk_width = 5.0;
uniform float cross_near = 39.0;
uniform float cross_width = 10.0;
varying vec3 world_pos;

//NOISE
float band(float v, float lo, float hi) {
	return step(lo, v) * step(v, hi);
}
void fragment() {
	vec2 p = world_pos.xz;
	float view_dist = length(world_pos - CAMERA_POSITION_WORLD);
	float near_detail = 1.0 - smoothstep(25.0, 70.0, view_dist);
	float ax = abs(p.x);
	float rx = ax - curb_x;  // 0..road_width on an avenue
	float cz = abs(p.y) - cross_near;  // 0..cross_width on a cross street
	float on_avenue = band(rx, 0.0, road_width);
	float on_cross = band(cz, 0.0, cross_width);
	float on_road = max(on_avenue, on_cross);
	float tone = fbm(p * 0.21);

	// Plaza: staggered dark pavers with silver discs set in them.
	vec2 tp = p / vec2(1.2, 0.6);
	tp.x += mod(floor(tp.y), 2.0) * 0.5;
	vec2 cell = floor(tp);
	vec2 f = fract(tp);
	vec3 c = mix(paver_light.rgb, paver_dark.rgb, hash(cell) * 0.6 + tone * 0.4);
	float grout = 1.0 - smoothstep(0.02, 0.06, min(min(f.x, 1.0 - f.x) * 1.2, min(f.y, 1.0 - f.y) * 0.6));
	c = mix(c, paver_dark.rgb * 0.5, grout * near_detail);
	vec2 dc = floor(p / 2.6);
	vec2 dp = (dc + vec2(hash(dc), hash(dc + 7.1)) * 0.8 + 0.1) * 2.6;
	float disc = 1.0 - smoothstep(0.05, 0.07, length(p - dp));
	c = mix(c, vec3(0.55, 0.57, 0.6), disc * near_detail);
	float rough = mix(0.8, 0.25, disc);
	float scuff = (1.0 - smoothstep(radius - 1.5, radius + 0.5, length(p))) * smoothstep(0.4, 0.7, fbm(p * 0.6));
	c *= 1.0 - scuff * 0.15;

	// Sidewalks: square concrete slabs.
	float on_walk = band(rx, road_width, road_width + sidewalk_width + 400.0) * (1.0 - on_cross);
	vec2 sf = fract(p / 1.5);
	vec3 walk = sidewalk.rgb * (0.9 + 0.2 * hash(floor(p / 1.5)));
	walk = mix(walk, walk * 0.6, (1.0 - smoothstep(0.01, 0.03, min(min(sf.x, 1.0 - sf.x), min(sf.y, 1.0 - sf.y)))) * near_detail);
	c = mix(c, walk, on_walk);

	// Asphalt, patched, with puddles that catch the screens.
	vec3 road = asphalt.rgb * (0.8 + 0.4 * tone);
	float puddle = smoothstep(0.58, 0.64, fbm(p * 0.09 + 3.0));
	road = mix(road, asphalt.rgb * 0.55, puddle);
	float lane_w = road_width / lane_count;
	float lane_line = 1.0 - smoothstep(0.06, 0.1, abs(mod(rx + lane_w * 0.5, lane_w) - lane_w * 0.5));
	lane_line *= band(rx, 0.5, road_width - 0.5) * step(0.5, fract(p.y / 6.0)) * (1.0 - on_cross);
	road = mix(road, lane_paint.rgb, lane_line);
	// Zebras: across the avenues at the cross streets' edges, across the
	// cross streets at the curbs.
	float zebra_a = on_avenue * (band(cz, 0.6, 3.6) + band(cz, cross_width - 3.6, cross_width - 0.6));
	zebra_a *= step(0.5, fract(p.x / 1.2));
	float zebra_c = on_cross * (band(rx, -3.6, -0.6) + band(rx, road_width + 0.6, road_width + 3.6));
	zebra_c *= step(0.5, fract(p.y / 1.2));
	road = mix(road, lane_paint.rgb, clamp(zebra_a + zebra_c, 0.0, 1.0) * (0.8 + 0.2 * tone));
	c = mix(c, road, on_road);
	rough = mix(rough, mix(0.75, 0.06, puddle), on_road);

	// Curbs where a road meets a walk.
	float curb_line = (band(rx, -0.3, 0.0) + band(rx, road_width, road_width + 0.3)) * (1.0 - on_cross)
			+ (band(cz, -0.3, 0.0) + band(cz, cross_width, cross_width + 0.3)) * (1.0 - on_avenue);
	c = mix(c, curb.rgb, clamp(curb_line, 0.0, 1.0));
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
}
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
"""

const SKY_SHADER := """
shader_type sky;
uniform vec3 top : source_color;
uniform vec3 horizon : source_color;
uniform vec3 city_glow : source_color;
uniform vec3 cloud_lit : source_color;
uniform float cover = 0.5;
uniform float cloud_scale = 2.2;

//NOISE
void sky() {
	vec3 d = EYEDIR;
	float h = max(d.y, 0.0);
	vec3 c = mix(horizon, top, 1.0 - exp(-h * 6.0));
	c += city_glow * exp(-h * 14.0) * 0.6;
	if (d.y > 0.005) {
		// Static on purpose: TIME here would redraw the radiance every frame.
		vec2 uv = d.xz / (d.y + 0.2) * cloud_scale;
		float mask = smoothstep(cover, cover + 0.25, fbm(uv)) * smoothstep(0.01, 0.12, d.y);
		c = mix(c, cloud_lit * (0.55 + 0.45 * exp(-h * 3.0)), mask * 0.85);
		// The few stars that make it through the glow.
		float star = step(0.9988, hash(floor(d.xz / (d.y + 0.05) * 90.0)));
		c += vec3(0.6) * star * (1.0 - mask) * smoothstep(0.25, 0.6, d.y);
	} else {
		c = horizon * 0.5;
	}
	COLOR = c;
}
"""

## Night facades: lit and dark windows, shop fronts at street level. Instance
## colour = wall paint.
const BUILDING_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec4 window_lit : source_color;
uniform vec4 storefront : source_color;
uniform float storefront_height = 4.5;
uniform float energy = 3.0;
varying vec3 world_pos;
varying vec3 world_n;
varying vec2 seed;

//NOISE
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	seed = MODEL_MATRIX[3].xz;
}
void fragment() {
	vec3 paint = pow(COLOR.rgb, vec3(2.2));  // instance colours are sRGB, as on PropMesh.material()
	float side = 1.0 - abs(world_n.y);
	float across = abs(world_n.x) > 0.5 ? world_pos.z : world_pos.x;
	vec2 cell = vec2(floor(across / 3.2), floor(world_pos.y / 3.6));
	vec2 f = vec2(fract(across / 3.2), fract(world_pos.y / 3.6));
	float pane = step(0.28, f.x) * step(f.x, 0.72) * step(0.3, f.y) * step(f.y, 0.8);
	float lit = step(0.66, hash(cell + seed * 0.37)) * pane;
	float shop = step(0.4, world_pos.y) * step(world_pos.y, storefront_height) * pane;
	vec3 glass = vec3(0.02, 0.025, 0.04);
	ALBEDO = mix(paint, glass, pane * side);
	ROUGHNESS = mix(0.85, 0.2, pane);
	vec3 glow = window_lit.rgb * lit * (0.35 + 0.65 * hash(cell + 3.1));
	glow = world_pos.y < storefront_height ? storefront.rgb * shop : glow;
	EMISSION = glow * side * energy * 0.2;
}
"""

## LED screens: a quad per screen, the picture made up from INSTANCE_CUSTOM =
## (pattern, seed, width m, height m) and the instance colour.
const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform float energy = 2.2;
varying vec4 custom;

//NOISE
vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}
void vertex() {
	custom = INSTANCE_CUSTOM;
}
void fragment() {
	int pattern = int(custom.x + 0.5);
	float seed = custom.y;
	vec2 size = max(custom.zw, vec2(0.5));
	vec2 m = UV * size;  // metres from the top-left corner
	vec2 q = vec2(UV.x * size.x / size.y, UV.y);
	float t = TIME + seed * 37.0;
	vec3 a = pow(COLOR.rgb, vec3(2.2));
	vec3 b = hue(fract(seed * 3.7 + 0.5)) * 0.9 + 0.05;
	vec3 c;
	if (pattern == 0) {  // pulsing rings
		vec2 at = vec2(size.x / size.y * (0.25 + 0.5 * hash(vec2(seed, 1.0))), 0.5);
		float ring = step(0.5, fract(length(q - at) * 2.5 - t * 0.5));
		c = mix(a, b, ring * 0.8);
	} else if (pattern == 1) {  // scrolling stripes
		c = mix(a, a * 0.15, step(0.5, fract((q.x + q.y) * 1.6 - t * 0.35)));
	} else if (pattern == 2) {  // "video": blocks that change twice a second
		vec2 cell = floor(q * 7.0);
		float n = hash(cell + floor(t * 2.0) * 1.7);
		c = mix(a * 0.12, mix(a, b, n), smoothstep(0.3, 0.5, n * 0.6 + noise(q * 2.0 + t * 0.3) * 0.6));
	} else if (pattern == 3) {  // ticker: fake text crawling left
		vec2 px = floor(vec2((m.x + t * 3.0) / 0.22, UV.y * 7.0));
		float glyph = step(0.5, hash(px + floor(px.x / 6.0) * 13.0)) * step(1.0, mod(px.x, 6.0));
		glyph *= step(1.0, px.y) * step(px.y, 5.0);
		c = mix(vec3(0.01), a, glyph);
	} else if (pattern == 4) {  // two colours wiping across
		float phase = fract(t / 5.0);
		c = mix(a, b, step(UV.x, phase));
		c = mix(c, vec3(0.9), (1.0 - smoothstep(0.32, 0.34, length(q - vec2(size.x / size.y * 0.5, 0.5)))) * 0.3);
	} else {  // gradient with a slow swell
		c = mix(a, b, clamp(UV.y + 0.25 * sin(q.x * 3.0 + t * 0.7), 0.0, 1.0));
	}
	// Every few seconds the ad cuts to black and back.
	c *= 0.25 + 0.75 * smoothstep(0.0, 0.08, fract(t / 9.0));
	// LEDs up close, frame at the edge.
	vec2 led = fract(m / 0.12);
	float aa = clamp(1.0 - max(fwidth(m.x), fwidth(m.y)) / 0.12, 0.0, 1.0);
	c *= mix(1.0, 0.6 + 0.4 * step(0.25, min(led.x, led.y)), aa);
	float edge = min(min(m.x, size.x - m.x), min(m.y, size.y - m.y));
	c = mix(vec3(0.015), c * energy, step(0.22, edge));
	ALBEDO = c;
}
"""

## Unshaded vertex colour x instance colour, brightened: lamps, headlights,
## cab signs, the red steps' risers.
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform float energy = 3.0;
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energy;
}
"""

## The ball: facets twinkling through the hues.
const BALL_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec4 base : source_color;
uniform float energy = 3.0;

//NOISE
void fragment() {
	vec2 facet = floor(UV * vec2(28.0, 14.0));
	float n = hash(facet);
	float sparkle = 0.55 + 0.45 * sin(TIME * (1.5 + n * 3.0) + n * 40.0);
	vec3 tint = mix(base.rgb, vec3(0.5 + 0.5 * sin(n * 6.3 + TIME), 0.5 + 0.5 * sin(n * 6.3 + TIME + 2.1), 0.5 + 0.5 * sin(n * 6.3 + TIME + 4.2)), 0.35);
	ALBEDO = tint * sparkle * energy;
}
"""

const CHAIR_SEAT_HEIGHT := 0.45
const TABLE_HEIGHT := 0.74
const TABLE_TOP_RADIUS := 0.36
## Distance from a table's centre to its chairs' seats.
const CHAIR_RING := 0.62
## Footprint around a table spot: chairs pulled out.
const TABLE_REACH := 1.3
## Planters stand this far inside the plaza curbs.
const PLANTER_INSET := 0.8
const PLANTER_SIZE := Vector3(1.0, 0.75, 2.2)
const LAMP_HEIGHT := 7.5
const LAMP_ARM := 2.4
const SIGNAL_HEIGHT := 4.6
const FACADE_DEPTH := 30.0
const CAR_SIZE := Vector3(1.9, 1.5, 4.8)
const BUS_LENGTH := 12.0
const BOOTH_DEPTH := 2.4
const CART_SIZE := Vector3(1.9, 1.0, 1.0)
const MAST_HEIGHT := 14.0
const WORDMARK_OUTLINE := 14
## Buildings side by side closing each end of the canyon.
const CANYON_END_BUILDINGS := 4
## How far inside the camera's far plane the last building stands.
const FAR_MARGIN := 40.0
## How many tries each skyline tower gets to land outside the streets.
const SKYLINE_TRIES := 8

enum Pattern { RINGS, STRIPES, VIDEO, TICKER, WIPE, GRADIENT }
## Patterns a wordmark reads well on.
const WORDMARK_PATTERNS: Array[int] = [Pattern.RINGS, Pattern.WIPE, Pattern.GRADIENT, Pattern.STRIPES]

var _glow_mat: ShaderMaterial
## [Transform3D, Color, Color custom] per screen.
var _screens: Array = []
## [Transform3D, Color] per building box.
var _buildings: Array = []


func look() -> ArenaTuning:
	return Tuning.arena_times_square


func _make_sky_material() -> Material:
	var t := Tuning.arena_times_square
	var mat := _shader_material(SKY_SHADER)
	mat.set_shader_parameter("top", t.sky_top_color)
	mat.set_shader_parameter("horizon", t.sky_horizon_color)
	mat.set_shader_parameter("city_glow", t.city_glow)
	mat.set_shader_parameter("cloud_lit", t.cloud_lit)
	mat.set_shader_parameter("cover", t.cloud_cover)
	mat.set_shader_parameter("cloud_scale", t.cloud_scale)
	return mat


func _build_environment() -> void:
	super()
	var t := Tuning.arena_times_square
	_sun.light_color = t.key_light_color
	var env: Environment = (get_node("WorldEnvironment") as WorldEnvironment).environment
	# The night sky is too dark to light anything: the city's glow does.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = t.ambient_color
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_sun.light_energy *= t.compatibility_light_scale
		env.ambient_light_energy *= t.compatibility_light_scale
		return
	for side: float in [-1.0, 1.0]:
		var spill := OmniLight3D.new()
		spill.name = "ScreenSpill"
		spill.light_color = t.spill_color_right if side > 0.0 else t.spill_color_left
		spill.light_energy = t.spill_energy
		spill.omni_range = t.spill_range
		spill.omni_attenuation = 0.6
		spill.position = Vector3(side * (curb_x(radius) + t.road_width * 0.5), t.spill_height, 0.0)
		add_child(spill)


# --- layout (no nodes, so tests can check it against the play circle) ---------

## The curb between the plaza and the avenue (both sides, mirrored).
static func curb_x(play_radius: float) -> float:
	return play_radius + Tuning.arena_times_square.plaza_margin


## The building faces along the avenues.
static func facade_x(play_radius: float) -> float:
	var t := Tuning.arena_times_square
	return curb_x(play_radius) + t.road_width + t.sidewalk_width


## Near side of the cross streets (at +Z and -Z, mirrored).
static func cross_z(play_radius: float) -> float:
	return play_radius + Tuning.arena_times_square.cross_gap


## The red steps' lowest tread (they rise toward +Z).
static func steps_z(play_radius: float) -> float:
	return play_radius + Tuning.arena_times_square.steps_gap


## The tower's face toward the plaza (it stands at -Z).
static func tower_z(play_radius: float) -> float:
	return -(play_radius + Tuning.arena_times_square.tower_gap)


static func in_cross_street(z: float, play_radius: float, margin := 0.0) -> bool:
	var near := absf(z) - cross_z(play_radius)
	return near > -margin and near < Tuning.arena_times_square.cross_width + margin


## Café tables (x, z): rings around the play circle, kept on the plaza, off
## the red steps and the cross streets, clear of the planters.
static func table_spots(play_radius: float) -> PackedVector2Array:
	var t := Tuning.arena_times_square
	var out := PackedVector2Array()
	var max_x := curb_x(play_radius) - PLANTER_INSET - PLANTER_SIZE.x - TABLE_REACH
	for row in t.table_row_gaps.size():
		var r := play_radius + t.table_row_gaps[row]
		var count := int(TAU * r / t.table_spacing)
		var offset := 0.5 if row % 2 == 1 else 0.0
		for i in count:
			var a := TAU * (i + offset) / count
			var at := Vector2(cos(a), sin(a)) * r
			if absf(at.x) > max_x:
				continue
			if at.y + TABLE_REACH > steps_z(play_radius) and absf(at.x) < t.steps_width * 0.5 + TABLE_REACH:
				continue
			if absf(at.y) + TABLE_REACH > cross_z(play_radius):
				continue
			out.append(at)
	return out


## Food carts (x, z), at the -Z end of the plaza.
static func cart_spots(play_radius: float) -> PackedVector2Array:
	var z := -(play_radius + Tuning.arena_times_square.cross_gap * 0.7)
	return PackedVector2Array([Vector2(-6.0, z), Vector2(5.5, z - 2.5), Vector2(0.0, z + 1.5)])


## Lamp posts (x, z, arm direction): both curbs of both avenues.
static func lamp_spots(play_radius: float) -> Array[Vector3]:
	var t := Tuning.arena_times_square
	var out: Array[Vector3] = []
	var inner := curb_x(play_radius) - 0.45
	var outer := curb_x(play_radius) + t.road_width + 0.45
	var count := int(t.traffic_span / t.lamp_spacing)
	for side: float in [-1.0, 1.0]:
		for i in range(-count, count + 1):
			var z := (i + 0.5) * t.lamp_spacing
			if not in_cross_street(z, play_radius, 1.0):
				out.append(Vector3(side * inner, z, side))
			var z_outer := z + t.lamp_spacing * 0.5
			if not in_cross_street(z_outer, play_radius, 1.0):
				out.append(Vector3(side * outer, z_outer, -side))
	return out


# --- stage ----------------------------------------------------------------------

func _build_ground() -> void:
	var t := Tuning.arena_times_square
	var mat := _shader_material(STREET_SHADER)
	for key: String in ["paver_light", "paver_dark", "asphalt", "lane_paint", "road_width", "sidewalk_width",
			"cross_width"]:
		mat.set_shader_parameter(key, t.get(key))
	mat.set_shader_parameter("curb", t.curb_color)
	mat.set_shader_parameter("sidewalk", t.sidewalk_color)
	mat.set_shader_parameter("lane_count", float(t.lane_count))
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("curb_x", curb_x(radius))
	mat.set_shader_parameter("cross_near", cross_z(radius))

	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * t.outer_ground_size
	plane.material = mat
	var ground := MeshInstance3D.new()
	ground.name = "Street"
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_build_floor_body()


## The play boundary: blue police barricades end to end.
func _build_ring() -> void:
	var t := Tuning.arena_times_square
	_glow_mat = _shader_material(GLOW_SHADER)
	_glow_mat.set_shader_parameter("energy", t.light_energy)
	var ring_at := radius + 0.35
	var count := maxi(int(TAU * ring_at / (t.barricade_length + 0.2)), 3)
	var items: Array = []
	for i in count:
		var a := TAU * i / count
		var basis := Basis(Vector3.UP, -(a + PI * 0.5) + _rng.randf_range(-0.04, 0.04))
		items.append([Transform3D(basis, Vector3(cos(a), 0.0, sin(a)) * ring_at), Color.WHITE])
	_batch("Barricades", _barricade_mesh(), items)


func _build_scenery() -> void:
	_build_plaza()
	_build_steps()
	_build_street_furniture()
	_build_traffic()
	_build_facades()
	_build_tower()
	_build_skyline()
	_build_screens()
	var bmat := _shader_material(BUILDING_SHADER)
	var t := Tuning.arena_times_square
	bmat.set_shader_parameter("window_lit", t.window_lit)
	bmat.set_shader_parameter("storefront", t.storefront_color)
	bmat.set_shader_parameter("storefront_height", t.storefront_height)
	bmat.set_shader_parameter("energy", t.light_energy)
	var box := BoxMesh.new()
	box.material = bmat
	_batch("Buildings", box, _buildings, false)


func _build_plaza() -> void:
	var t := Tuning.arena_times_square
	var tables: Array = []
	var chairs: Array = []
	for spot in table_spots(radius):
		if _rng.randf() < t.table_skip_chance:
			continue
		var pos := Vector3(spot.x, 0.0, spot.y)
		var yaw := _rng.randf() * TAU
		tables.append([Transform3D(Basis(Vector3.UP, yaw), pos), t.table_color])
		for seat in _rng.randi_range(2, 4):
			if _rng.randf() < t.chair_missing_chance:
				continue
			var a := yaw + TAU * seat / 4.0
			var seat_pos := pos + Vector3(sin(a), 0.0, cos(a)) * (CHAIR_RING + _rng.randf_range(0.0, 0.35))
			var basis := Basis(Vector3.UP, a + PI + _rng.randf_range(-0.4, 0.4))
			if _rng.randf() < t.chair_toppled_chance:
				basis = basis * Basis(Vector3.RIGHT, -PI * 0.5)
				seat_pos += Vector3(sin(a), 0.0, cos(a)) * 0.5 + Vector3.UP * 0.2
			chairs.append([Transform3D(basis, seat_pos), t.table_color])
	_batch("Tables", _table_mesh(), tables)
	_batch("Chairs", _chair_mesh(), chairs)

	# Planters along both curbs, the length of the plaza.
	var planters: Array = []
	var x := curb_x(radius) - PLANTER_INSET - PLANTER_SIZE.x * 0.5
	var count := int(t.traffic_span / t.planter_spacing)
	for side: float in [-1.0, 1.0]:
		for i in range(-count, count + 1):
			var z := i * t.planter_spacing + side * t.planter_spacing * 0.25
			if in_cross_street(z, radius, PLANTER_SIZE.z):
				continue
			planters.append([Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.03, 0.03)), Vector3(side * x, 0.0, z)), Color.WHITE])
	_batch("Planters", _planter_mesh(), planters)

	var carts: Array = []
	var cart_tops: Array = []
	for spot in cart_spots(radius):
		var xf := Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.4, 0.4)), Vector3(spot.x, 0.0, spot.y))
		carts.append([xf, Color.WHITE])
		cart_tops.append([xf, Color.WHITE])
	_batch("Carts", _cart_mesh(), carts)
	_glow_batch("CartLights", _cart_glow_mesh(), cart_tops)


## Red steps rising toward +Z, lit from inside, with a ticket booth beneath
## their top.
func _build_steps() -> void:
	var t := Tuning.arena_times_square
	var z0 := steps_z(radius)
	var w := t.steps_width
	var n := maxi(t.steps_count, 1)
	var rise := t.steps_height / n
	var run := t.steps_depth / n
	var m := PropMesh.new()
	var glass := t.steps_glow.darkened(0.55)
	var glow := PropMesh.new()
	for i in n:
		var y := rise * (i + 1)
		var zs := z0 + run * i
		var depth := t.steps_depth - run * i
		m.block(Vector3(0.0, y * 0.5, zs + depth * 0.5), Vector3(w, y, depth), glass)
		# The riser shines, the tread's nose catches it.
		glow.quad(Vector3(w * 0.5, y - rise, zs - 0.01), Vector3(-w * 0.5, y - rise, zs - 0.01),
				Vector3(-w * 0.5, y, zs - 0.01), Vector3(w * 0.5, y, zs - 0.01), t.steps_glow)
		glow.block(Vector3(0.0, y + 0.01, zs + 0.06), Vector3(w, 0.02, 0.12), t.steps_glow.lightened(0.4))
	# Glass rails along the sides, and the booth behind.
	for sx: float in [-1.0, 1.0]:
		m.block(Vector3(sx * (w * 0.5 + 0.05), t.steps_height * 0.5 + 0.5, z0 + t.steps_depth * 0.5),
				Vector3(0.08, t.steps_height + 1.0, t.steps_depth), t.steel_color)
	var booth_z := z0 + t.steps_depth + BOOTH_DEPTH * 0.5
	m.block(Vector3(0.0, t.steps_height * 0.5, booth_z), Vector3(w * 0.8, t.steps_height, BOOTH_DEPTH), t.steel_color)
	_add_static("Steps", m.commit())
	_add_static("StepsGlow", glow.commit(), _glow_mat)


func _build_street_furniture() -> void:
	var t := Tuning.arena_times_square
	var lamps: Array = []
	for spot in lamp_spots(radius):
		# The arm leans out over the road.
		var basis := Basis.IDENTITY if spot.z > 0.0 else Basis(Vector3.UP, PI)
		lamps.append([Transform3D(basis, Vector3(spot.x, 0.0, spot.y)), Color.WHITE])
	_batch("Lamps", _lamp_mesh(), lamps)
	_glow_batch("LampHeads", _lamp_glow_mesh(), lamps)

	# Signals at the corners of both cross streets.
	var signals: Array = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for edge: float in [-0.6, t.cross_width + 0.6]:
				for x: float in [curb_x(radius) - 0.4, curb_x(radius) + t.road_width + 0.4]:
					signals.append([Transform3D(Basis.IDENTITY, Vector3(sx * x, 0.0, sz * (cross_z(radius) + edge))),
							Color.WHITE])
	_batch("Signals", _signal_mesh(), signals)
	_glow_batch("SignalLights", _signal_glow_mesh(), signals)


## The jam on both avenues (everyone heading -Z) and along the cross streets.
func _build_traffic() -> void:
	var t := Tuning.arena_times_square
	var cars: Array = []
	var buses: Array = []
	var taxi_signs: Array = []
	var lights: Array = []
	var bus_lights: Array = []
	var lane_w := t.road_width / t.lane_count
	var south := Basis(Vector3.UP, PI)
	for side: float in [-1.0, 1.0]:
		for lane in t.lane_count:
			var x := side * (curb_x(radius) + lane_w * (lane + 0.5))
			# Rear end of the next vehicle.
			var back := -t.traffic_span + _rng.randf_range(0.0, t.car_spacing)
			while back < t.traffic_span:
				var bus := _rng.randf() < t.bus_chance
				var length := BUS_LENGTH if bus else CAR_SIZE.z
				var z := back + length * 0.5
				var gap := _rng.randf() < t.car_gap_chance
				if not gap and not in_cross_street(z, radius, length * 0.5 + 1.0):
					var xf := Transform3D(south * Basis(Vector3.UP, _rng.randf_range(-0.04, 0.04)),
							Vector3(x + _rng.randf_range(-0.25, 0.25), 0.0, z))
					if bus:
						buses.append([xf, t.bus_color])
						bus_lights.append([xf, Color.WHITE])
					else:
						var taxi := _rng.randf() < t.taxi_share
						var color := t.taxi_color if taxi else t.car_colors[_rng.randi() % t.car_colors.size()]
						cars.append([xf, color])
						lights.append([xf, Color.WHITE])
						if taxi:
							taxi_signs.append([xf, Color.WHITE])
				back += length + t.car_spacing - CAR_SIZE.z + _rng.randf_range(-0.6, 0.8)
	# Cross streets, heading +X / -X by side of the street, out past the
	# facades and between the plaza's two halves.
	for sz: float in [-1.0, 1.0]:
		for half: float in [0.25, 0.75]:
			var z := sz * (cross_z(radius) + t.cross_width * half)
			var heading := Basis(Vector3.UP, PI * 0.5 if half < 0.5 else -PI * 0.5)
			var x := -t.traffic_span
			while x < t.traffic_span:
				var ax := absf(x)
				var clear_of_avenue := ax < curb_x(radius) - CAR_SIZE.z or ax > facade_x(radius) + 2.0
				if clear_of_avenue and _rng.randf() > t.car_gap_chance:
					var xf := Transform3D(heading, Vector3(x, 0.0, z))
					var taxi := _rng.randf() < t.taxi_share
					cars.append([xf, t.taxi_color if taxi else t.car_colors[_rng.randi() % t.car_colors.size()]])
					lights.append([xf, Color.WHITE])
					if taxi:
						taxi_signs.append([xf, Color.WHITE])
				x += t.car_spacing + _rng.randf_range(0.0, 2.0)
	_batch("Cars", _car_mesh(), cars)
	_batch("Buses", _bus_mesh(), buses)
	_glow_batch("CarLights", _car_glow_mesh(CAR_SIZE.z), lights)
	_glow_batch("BusLights", _car_glow_mesh(BUS_LENGTH), bus_lights)
	_glow_batch("TaxiSigns", _taxi_sign_mesh(), taxi_signs)


## The canyon: buildings shoulder to shoulder along both avenues, screens on
## the faces toward the plaza.
func _build_facades() -> void:
	var t := Tuning.arena_times_square
	var fx := facade_x(radius)
	for side: float in [-1.0, 1.0]:
		var z := -t.facade_span
		while z < t.facade_span:
			var w := _rng.randf_range(t.facade_min_width, t.facade_max_width)
			# Leave the cross streets open: stop short of one, resume past it.
			var skip := false
			for street_start: float in [-cross_z(radius) - t.cross_width, cross_z(radius)]:
				if z >= street_start - 0.01 and z < street_start + t.cross_width:
					z = street_start + t.cross_width
					skip = true
				elif z < street_start and z + w > street_start:
					w = street_start - z
			# The canyon's end buildings take over at facade_span.
			w = minf(w, t.facade_span - z)
			if skip:
				continue
			# Too thin a remainder: leave the gap rather than a sliver.
			if w < t.facade_min_width * 0.5:
				z += w
				continue
			var closeness := 1.0 - clampf(absf(z + w * 0.5) / t.facade_span, 0.0, 1.0)
			var h := lerpf(t.facade_min_height, t.facade_max_height, _rng.randf() * (0.4 + 0.6 * closeness))
			var center := Vector3(side * (fx + FACADE_DEPTH * 0.5), h * 0.5, z + w * 0.5)
			_add_building(center, Vector3(FACADE_DEPTH, h, w))
			# Screens, stacked up the face toward the street.
			var face := Basis(Vector3.UP, -PI * 0.5 if side > 0.0 else PI * 0.5)
			var y := t.screen_base
			for _s in _rng.randi_range(1, t.screens_per_building):
				var sh := _rng.randf_range(t.screen_min_height, t.screen_max_height)
				if y + sh > h - 4.0:
					break
				var sw := w * _rng.randf_range(0.6, 0.94)
				var sz := z + w * 0.5 + _rng.randf_range(-1.0, 1.0) * (w - sw) * 0.5
				_add_screen(face, Vector3(side * (fx - 0.12), y + sh * 0.5, sz), Vector2(sw, sh))
				y += sh + _rng.randf_range(0.8, 4.0)
			z += w
	# Close the canyon at both ends.
	var span := fx * 2.0 + FACADE_DEPTH * 2.0
	var w := span / CANYON_END_BUILDINGS
	for sz: float in [-1.0, 1.0]:
		for i in CANYON_END_BUILDINGS:
			var h := _rng.randf_range(t.facade_min_height, t.facade_max_height)
			var depth := FACADE_DEPTH * _rng.randf_range(0.8, 1.2)
			_add_building(Vector3(-span * 0.5 + w * (i + 0.5), h * 0.5, sz * (t.facade_span + depth * 0.5)),
					Vector3(w, h, depth))


## The narrow tower at the bowtie's -Z end: screens up its lower floors, a
## ticker band, the ball on its mast.
func _build_tower() -> void:
	var t := Tuning.arena_times_square
	var s := t.tower_size
	var face_z := tower_z(radius)
	_add_building(Vector3(0.0, s.y * 0.5, face_z - s.z * 0.5), s)
	var y := 4.0
	var heights: Array[float] = [9.0, 14.0, 11.0, 16.0, 10.0]
	for i in heights.size():
		var h := heights[i]
		_add_screen(Basis.IDENTITY, Vector3(0.0, y + h * 0.5, face_z + 0.12), Vector2(s.x * 0.92, h))
		for sx: float in [-1.0, 1.0]:
			var side := Basis(Vector3.UP, sx * PI * 0.5)
			_add_screen(side, Vector3(sx * (s.x * 0.5 + 0.12), y + h * 0.5, face_z - s.z * 0.5), Vector2(s.z * 0.9, h))
		y += h + 0.8
		if i == 0:
			_add_screen(Basis.IDENTITY, Vector3(0.0, y + 0.9, face_z + 0.12), Vector2(s.x, 1.8), Pattern.TICKER)
			y += 2.6
	var mast := PropMesh.new()
	mast.rod(Vector3(0.0, s.y, face_z - s.z * 0.5), Vector3(0.0, s.y + MAST_HEIGHT, face_z - s.z * 0.5), 0.35, 0.2, 8,
			t.steel_color)
	_add_static("Mast", mast.commit())
	var ball := SphereMesh.new()
	ball.radius = t.ball_radius
	ball.height = t.ball_radius * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	var bmat := _shader_material(BALL_SHADER)
	bmat.set_shader_parameter("base", t.ball_color)
	bmat.set_shader_parameter("energy", t.light_energy)
	var bm := _add_static("Ball", ball, bmat)
	bm.position = Vector3(0.0, s.y + MAST_HEIGHT + t.ball_radius * 0.6, face_z - s.z * 0.5)
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Skyscrapers behind the facades, kept off the cross streets so they read as
## streets, taller further out.
func _build_skyline() -> void:
	var t := Tuning.arena_times_square
	var start := facade_x(radius) + FACADE_DEPTH + 4.0
	var limit := minf(Tuning.camera.far, t.outer_ground_size * 0.5) - FAR_MARGIN
	for i in t.tower_count:
		for _attempt in SKYLINE_TRIES:
			var out := _rng.randf()
			out *= out
			var size := Vector3(_rng.randf_range(16.0, 34.0), 0.0, _rng.randf_range(16.0, 34.0))
			var x := (-1.0 if i % 2 == 0 else 1.0) * (start + size.x * 0.5 + out * t.skyline_depth)
			var z := _rng.randf_range(-t.facade_span, t.facade_span)
			if in_cross_street(z, radius, size.z * 0.5 + 2.0):
				continue
			var at := Vector2(x, z).limit_length(limit)
			if absf(at.x) < start + size.x * 0.5:
				continue
			size.y = lerpf(t.skyline_min_height, t.skyline_max_height, sqrt(out)) * _rng.randf_range(0.6, 1.1)
			_add_building(Vector3(at.x, size.y * 0.5, at.y), size)
			break


func _glow_batch(node_name: String, mesh: Mesh, items: Array) -> void:
	var mi := _batch(node_name, mesh, items, false)
	if mi != null:
		mi.material_override = _glow_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_building(center: Vector3, size: Vector3) -> void:
	var t := Tuning.arena_times_square
	var color: Color = t.facade_colors[_rng.randi() % t.facade_colors.size()]
	_buildings.append([Transform3D(Basis.from_scale(size), center), color])


func _add_screen(face: Basis, center: Vector3, size: Vector2, pattern := -1) -> void:
	var t := Tuning.arena_times_square
	if pattern < 0:
		pattern = _rng.randi() % Pattern.size()
		# A crawl only reads on a strip.
		if pattern == Pattern.TICKER and size.x < size.y * 3.0:
			pattern = Pattern.VIDEO
	var color: Color = t.screen_colors[_rng.randi() % t.screen_colors.size()]
	var custom := Color(pattern, _rng.randf(), size.x, size.y)
	_screens.append([Transform3D(face * Basis.from_scale(Vector3(size.x, size.y, 1.0)), center), color, custom])


## One MultiMesh for every screen; the nearest ones carry a wordmark.
func _build_screens() -> void:
	var t := Tuning.arena_times_square
	var quad := QuadMesh.new()
	var mat := _shader_material(SCREEN_SHADER)
	mat.set_shader_parameter("energy", t.screen_energy)
	quad.material = mat
	var mi := _batch("Screens", quad, _screens, false)
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var order: Array = _screens.duplicate()
	order.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as Transform3D).origin.length() < (b[0] as Transform3D).origin.length())
	var font := UiTheme.display_font()
	var marks := 0
	for s: Array in order:
		if marks >= t.max_wordmarks or t.brands.is_empty():
			break
		var custom: Color = s[2]
		if int(custom.r) not in WORDMARK_PATTERNS:
			continue
		var xf: Transform3D = s[0]
		var size := Vector2(custom.b, custom.a)
		var text := t.brands[marks % t.brands.size()]
		var font_size := 96
		# Roughly: a glyph is 0.7 em wide on this font, a line 1.2 em tall.
		var pixel := minf(size.x * 0.8 / (text.length() * font_size * 0.7), size.y * 0.45 / (font_size * 1.2))
		var face := xf.basis.orthonormalized()
		var l := _add_text(text, Transform3D(face, xf.origin + face.z * 0.06), t.wordmark_color, pixel, font_size, font)
		l.shaded = false
		l.outline_size = WORDMARK_OUTLINE
		l.outline_modulate = t.wordmark_outline
		marks += 1


# --- prop meshes (local origin on the ground) --------------------------------

## A blue police barricade along X: a striped rail on two A-frame legs.
static func _barricade_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	var l := t.barricade_length
	var h := t.barricade_height
	var blue := t.barricade_color
	m.block(Vector3(0.0, h - 0.11, 0.0), Vector3(l, 0.22, 0.04), blue)
	for i in 5:
		m.block(Vector3(-l * 0.4 + l * 0.2 * i, h - 0.11, 0.025), Vector3(l * 0.08, 0.1, 0.01), t.barricade_stripe)
	m.block(Vector3(0.0, h * 0.45, 0.0), Vector3(l * 0.92, 0.1, 0.03), blue)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (l * 0.5 - 0.18)
		for sz: float in [-1.0, 1.0]:
			m.rod(Vector3(x, h, 0.0), Vector3(x, 0.0, sz * 0.32), 0.03, 0.03, 5, blue.darkened(0.2))
	return m.commit()


## A round bistro table, tinted by the instance colour.
static func _table_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	var c := Color.WHITE
	m.rod(Vector3(0.0, TABLE_HEIGHT - 0.03, 0.0), Vector3(0.0, TABLE_HEIGHT, 0.0), TABLE_TOP_RADIUS, TABLE_TOP_RADIUS, 14, c)
	m.rod(Vector3.ZERO, Vector3(0.0, TABLE_HEIGHT, 0.0), 0.035, 0.035, 6, c)
	m.rod(Vector3.ZERO, Vector3(0.0, 0.03, 0.0), 0.24, 0.22, 10, c.darkened(0.3))
	return m.commit()


## A metal bistro chair facing +z, tinted by the instance colour.
static func _chair_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	var c := Color.WHITE
	var y := CHAIR_SEAT_HEIGHT
	m.block(Vector3(0.0, y, 0.0), Vector3(0.42, 0.03, 0.42), c)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.rod(Vector3(sx * 0.18, y, sz * 0.18), Vector3(sx * 0.21, 0.0, sz * 0.21), 0.016, 0.016, 5, c)
	var back := Basis(Vector3.RIGHT, -0.15)
	var pivot := Vector3(0.0, y, -0.2)
	for sx: float in [-1.0, 1.0]:
		m.box(Transform3D(back, pivot + back * Vector3(sx * 0.19, 0.22, 0.0)), Vector3(0.025, 0.44, 0.025), c)
	for i in 3:
		m.box(Transform3D(back, pivot + back * Vector3(0.0, 0.16 + 0.13 * i, 0.0)), Vector3(0.4, 0.05, 0.015), c)
	return m.commit()


## A concrete planter of clipped shrubs, long along Z.
static func _planter_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	var s := PLANTER_SIZE
	m.block(Vector3(0.0, s.y * 0.5, 0.0), s, t.planter_color)
	m.block(Vector3(0.0, s.y + 0.02, 0.0), s + Vector3(0.08, 0.04, 0.08), t.planter_color.lightened(0.15))
	for i in 3:
		var z := (i - 1.0) * s.z * 0.3
		m.block(Vector3(0.0, s.y + 0.22, z), Vector3(s.x * 0.8, 0.4, s.z * 0.28), t.shrub_color.lightened(0.06 * i))
	return m.commit()


## A street food cart under a striped umbrella.
static func _cart_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	var s := CART_SIZE
	var steel := t.curb_color.lightened(0.2)
	m.block(Vector3(0.0, 0.35 + s.y * 0.5, 0.0), s, steel)
	m.block(Vector3(0.0, 0.35 + s.y * 0.5, s.z * 0.5 + 0.01), Vector3(s.x * 0.9, s.y * 0.5, 0.02), t.barricade_color)
	for sx: float in [-1.0, 1.0]:
		m.rod(Vector3(sx * s.x * 0.35, 0.35, -s.z * 0.5), Vector3(sx * s.x * 0.35, 0.35, s.z * 0.5), 0.33, 0.33, 10,
				Color(0.08, 0.08, 0.08))
	var top := Vector3(0.0, 2.6, 0.0)
	m.rod(Vector3(0.0, 0.35 + s.y, 0.0), top, 0.025, 0.025, 6, steel)
	var panels := 8
	for i in panels:
		var a0 := TAU * i / panels
		var a1 := TAU * (i + 1) / panels
		var p0 := Vector3(cos(a0) * 1.3, 2.15, sin(a0) * 1.3)
		var p1 := Vector3(cos(a1) * 1.3, 2.15, sin(a1) * 1.3)
		var c := t.taxi_color if i % 2 == 0 else t.barricade_color
		m.tri(top, p1, p0, c)
		m.tri(top, p0, p1, c.darkened(0.3))
	return m.commit()


## The cart's lit menu board and steam-table glow.
static func _cart_glow_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	m.block(Vector3(0.0, 0.35 + CART_SIZE.y + 0.25, -CART_SIZE.z * 0.3), Vector3(CART_SIZE.x * 0.7, 0.4, 0.04), t.lamp_color)
	return m.commit()


## A lamp post with its arm out over +X.
static func _lamp_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	var steel := t.steel_color
	m.rod(Vector3.ZERO, Vector3(0.0, 0.5, 0.0), 0.16, 0.13, 8, steel)
	m.rod(Vector3(0.0, 0.5, 0.0), Vector3(0.0, LAMP_HEIGHT, 0.0), 0.09, 0.07, 7, steel)
	m.tube(PackedVector3Array([Vector3(0.0, LAMP_HEIGHT - 0.4, 0.0), Vector3(0.0, LAMP_HEIGHT, 0.0),
			Vector3(LAMP_ARM * 0.5, LAMP_HEIGHT + 0.3, 0.0), Vector3(LAMP_ARM, LAMP_HEIGHT + 0.2, 0.0)]),
			PackedFloat32Array([0.06, 0.06, 0.05, 0.05]), 6, steel)
	m.block(Vector3(LAMP_ARM, LAMP_HEIGHT + 0.12, 0.0), Vector3(0.7, 0.16, 0.32), steel)
	return m.commit()


static func _lamp_glow_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	var y := LAMP_HEIGHT + 0.035
	var hx := 0.3
	var hz := 0.13
	# Facing down.
	m.quad(Vector3(LAMP_ARM - hx, y, -hz), Vector3(LAMP_ARM + hx, y, -hz), Vector3(LAMP_ARM + hx, y, hz),
			Vector3(LAMP_ARM - hx, y, hz), t.lamp_color)
	return m.commit()


## A traffic signal on a post, heads facing both ways along Z.
static func _signal_mesh() -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	m.rod(Vector3.ZERO, Vector3(0.0, SIGNAL_HEIGHT, 0.0), 0.08, 0.07, 7, t.steel_color)
	m.block(Vector3(0.0, SIGNAL_HEIGHT - 0.5, 0.0), Vector3(0.36, 1.05, 0.3), Color(0.12, 0.12, 0.1))
	return m.commit()


## The signal's lamps: red lit, amber and green dim, both faces; and the
## walk sign.
static func _signal_glow_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	var colors: Array[Color] = [Color(1.0, 0.1, 0.05), Color(0.25, 0.15, 0.02), Color(0.02, 0.2, 0.08)]
	for i in 3:
		var y := SIGNAL_HEIGHT - 0.18 - 0.32 * i
		for sz: float in [-1.0, 1.0]:
			m.box(Transform3D(Basis(Vector3.UP, 0.0 if sz > 0.0 else PI), Vector3(0.0, y, sz * 0.16)),
					Vector3(0.2, 0.2, 0.01), colors[i])
	m.block(Vector3(0.0, 2.6, 0.0), Vector3(0.3, 0.3, 0.32), Color(1.0, 0.45, 0.1))
	return m.commit()


## A sedan facing +Z, tinted by the instance colour (taxi yellow or paint).
static func _car_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	var s := CAR_SIZE
	var c := Color.WHITE
	var dark := Color(0.06, 0.06, 0.07)
	var glass := Color(0.12, 0.14, 0.17)
	m.block(Vector3(0.0, 0.55, 0.0), Vector3(s.x, 0.6, s.z), c)
	m.block(Vector3(0.0, 1.12, -0.2), Vector3(s.x * 0.86, 0.55, s.z * 0.5), glass)
	m.block(Vector3(0.0, 1.41, -0.2), Vector3(s.x * 0.84, 0.05, s.z * 0.46), c)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			m.rod(Vector3(sx * s.x * 0.5 - sx * 0.12, 0.33, sz * s.z * 0.32), Vector3(sx * s.x * 0.5 + sx * 0.02, 0.33, sz * s.z * 0.32),
					0.33, 0.33, 10, dark)
	m.block(Vector3(0.0, 0.3, s.z * 0.5 + 0.03), Vector3(s.x, 0.16, 0.08), dark)
	m.block(Vector3(0.0, 0.3, -s.z * 0.5 - 0.03), Vector3(s.x, 0.16, 0.08), dark)
	return m.commit()


## A city bus facing +Z, tinted by the instance colour.
static func _bus_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	var l := BUS_LENGTH
	var c := Color.WHITE
	m.block(Vector3(0.0, 1.75, 0.0), Vector3(2.55, 2.9, l), c)
	m.block(Vector3(0.0, 0.45, 0.0), Vector3(2.5, 0.5, l * 0.98), Color(0.85, 0.85, 0.85))
	var glass := Color(0.1, 0.12, 0.16)
	for sx: float in [-1.0, 1.0]:
		m.block(Vector3(sx * 1.28, 2.1, -0.4), Vector3(0.02, 1.0, l * 0.8), glass)
		for sz: float in [-1.0, 1.0]:
			m.rod(Vector3(sx * 1.15, 0.5, sz * l * 0.32), Vector3(sx * 1.3, 0.5, sz * l * 0.32), 0.5, 0.5, 10,
					Color(0.06, 0.06, 0.07))
	m.block(Vector3(0.0, 2.0, l * 0.5 + 0.01), Vector3(2.3, 1.4, 0.02), glass)
	return m.commit()


## Headlights at +Z, tail lights at -Z, for a vehicle `length` long.
static func _car_glow_mesh(length: float) -> ArrayMesh:
	var t := Tuning.arena_times_square
	var m := PropMesh.new()
	var half := length * 0.5 + 0.02
	for sx: float in [-1.0, 1.0]:
		m.block(Vector3(sx * 0.68, 0.68, half), Vector3(0.32, 0.14, 0.02), t.headlight_color)
		m.block(Vector3(sx * 0.72, 0.72, -half), Vector3(0.26, 0.14, 0.02), t.taillight_color)
	return m.commit()


## The lit sign on a cab's roof.
static func _taxi_sign_mesh() -> ArrayMesh:
	var m := PropMesh.new()
	m.block(Vector3(0.0, 1.55, -0.2), Vector3(0.9, 0.24, 0.3), Color(1.0, 0.95, 0.75))
	return m.commit()
