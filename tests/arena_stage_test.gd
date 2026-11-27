extends Node
## Stages (ArenaCatalog / Arena.create): the factory, and the beach bar's and
## the Great Wall's layouts against the play circle and the camera at every
## arena size: nothing stands inside the rope, nothing tall where the camera
## can go, the sea stays clear of the sand's props, the wall stands on its
## ridge. Plus each build itself and a real match on it.
## Run as a scene:  godot --headless res://tests/arena_stage_test.tscn

## Footprints around a spot: chairs around a table, an umbrella's canopy.
const TABLE_REACH := 1.5
const UMBRELLA_REACH := BeachArena.UMBRELLA_RADIUS
const MATCH_FRAMES := 30
## Great Wall: the walkway's steepest climb per step, and how far off its
## ridge the wall may stand.
const MAX_WALK_SLOPE := 0.9
const RIDGE_TOLERANCE := 0.5

var _fails := 0


func _ready() -> void:
	_test_catalog()
	_test_layout(Tuning.match_rules.arena_radius)
	var biggest := Tuning.match_rules.arena_radius \
			+ Tuning.coop.arena_radius_per_extra_fighter * (Tuning.coop.field_cap - 2)
	_test_layout(biggest)
	_test_great_wall_layout(Tuning.match_rules.arena_radius)
	_test_great_wall_layout(biggest)
	await _test_build()
	await _test_great_wall_build()
	await _test_match_scene(ArenaCatalog.BEACH_BAR, BeachArena)
	await _test_match_scene(ArenaCatalog.GREAT_WALL, GreatWallArena)
	print("ARENA_STAGE %s (%d failures)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func check(cond: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		_fails += 1


func _test_catalog() -> void:
	var stone := Arena.create(ArenaCatalog.DEFAULT)
	var beach := Arena.create(ArenaCatalog.BEACH_BAR)
	var wall := Arena.create(ArenaCatalog.GREAT_WALL)
	var unknown := Arena.create(&"from_a_newer_build")
	check(stone.get_script() == Arena, "default id builds the stone ring")
	check(beach is BeachArena, "beach_bar id builds the beach")
	check(wall is GreatWallArena, "great_wall id builds the Great Wall")
	check(unknown.get_script() == Arena, "an unknown id falls back to the default")
	stone.free()
	beach.free()
	wall.free()
	unknown.free()
	for id in ArenaCatalog.IDS:
		check(ArenaCatalog.NAMES.has(id), "%s has a display name" % id)


func _test_layout(r: float) -> void:
	var b := Tuning.arena_beach
	var cam := r + Tuning.camera.radius_margin
	var tables := BeachArena.table_spots(r)
	var umbrellas := BeachArena.umbrella_spots(r)
	check(tables.size() >= 8, "r=%.1f: %d tables" % [r, tables.size()])
	check(umbrellas.size() >= 8, "r=%.1f: %d umbrellas" % [r, umbrellas.size()])
	var inside := 0
	for t in tables:
		if t.length() - TABLE_REACH <= r:
			inside += 1
		if t.y >= 0.0:
			inside += 1
	check(inside == 0, "r=%.1f: tables on the bar's side, outside the rope" % r)
	var bar_clear := true
	for t in tables:
		if -t.y + TABLE_REACH > -BeachArena.bar_z(r):
			bar_clear = false
	check(bar_clear, "r=%.1f: tables between the rope and the bar" % r)
	var tall_clear := true
	var dry := true
	for u in umbrellas:
		if u.length() - UMBRELLA_REACH <= cam:
			tall_clear = false
		if u.y <= 0.0 or u.y + UMBRELLA_REACH >= BeachArena.shore_z(u.x, r) - b.swash_reach:
			dry = false
	check(tall_clear, "r=%.1f: umbrellas beyond the camera's limit (%.1f m)" % [r, cam])
	check(dry, "r=%.1f: umbrellas stay on dry sand" % r)
	check(-BeachArena.bar_z(r) - BeachArena.AWNING_DEPTH > cam, "r=%.1f: the bar and its awning are beyond the camera's limit" % r)
	check(BeachArena.shore_z(0.0, r) - b.swash_reach > cam, "r=%.1f: the water is beyond the camera's limit" % r)
	check(BeachArena.shore_z(200.0, r) < BeachArena.shore_z(0.0, r)
			and BeachArena.shore_z(-200.0, r) > BeachArena.shore_z(0.0, r), "r=%.1f: the bay curves" % r)


func _test_build() -> void:
	var arena := Arena.create(ArenaCatalog.BEACH_BAR)
	arena.radius = Tuning.match_rules.arena_radius
	add_child(arena)
	await get_tree().process_frame
	var props := arena.get_node("Props")
	for node_name: String in ["Tables", "Chairs", "Umbrellas", "Palms", "Towers", "Bar", "Rope"]:
		check(props.has_node(node_name), "stage has its %s" % node_name)
	check(arena.has_node("FloorBody"), "stage has the floor collider")
	check(arena.has_node("Sun") and arena.has_node("WorldEnvironment"), "stage has its light and sky")
	var chairs := props.get_node("Chairs") as MultiMeshInstance3D
	check(chairs.multimesh.instance_count > BeachArena.table_spots(arena.radius).size(), "tables have chairs")
	var texts: Array[String] = []
	for c in props.get_children():
		if c is Label3D:
			texts.append(c.text)
	check(Tuning.arena_beach.brand_a_name in texts and Tuning.arena_beach.brand_b_name in texts, "both brands are shown")
	check(texts.size() < 32, "wordmarks stay few enough to be cheap (%d)" % texts.size())
	arena.queue_free()


## A whole match scene on a stage: config -> Arena.create -> running.
func _test_match_scene(id: StringName, stage: Script) -> void:
	var cfg := MatchScene.build_default_config()
	cfg.arena_id = id
	for p in cfg.players:
		p.input_kind = PlayerSlotConfig.InputKind.CPU
	Game.current_config = cfg
	var scene := MatchScene.new()
	add_child(scene)
	for i in MATCH_FRAMES:
		await get_tree().process_frame
	check(scene.arena.get_script() == stage, "a match with the %s id plays on that stage" % id)
	check(is_equal_approx(scene.arena.radius, scene.director.arena_radius), "stage and sim agree on the radius")
	check(scene.director.fighters.size() == cfg.players.size(), "the match runs with its fighters")
	Game.current_config = null
	scene.free()


func _test_great_wall_layout(r: float) -> void:
	var g := Tuning.arena_great_wall
	var cam := r + Tuning.camera.radius_margin
	var th := GreatWallArena.terrace_half(r)
	check(th > cam, "r=%.1f: the parapets and the gate tower's face are beyond the camera's limit (%.1f m)" % [r, cam])
	var low := GreatWallArena.low_prop_spots(r)
	check(low.size() >= 8, "r=%.1f: %d low prop spots" % [r, low.size()])
	var low_ok := true
	for p in low:
		if p.length() - GreatWallArena.LOW_PROP_REACH <= r + 0.3 or absf(p.x) + GreatWallArena.LOW_PROP_REACH >= th \
				or absf(p.y) + GreatWallArena.LOW_PROP_REACH >= th:
			low_ok = false
	check(low_ok, "r=%.1f: low props between the cord and the parapets" % r)
	var tall := GreatWallArena.banner_spots(r)
	check(tall.size() >= 8, "r=%.1f: %d banners" % [r, tall.size()])
	var openings_clear := true
	for p in tall:
		if p.y < -th * 0.9 and absf(p.x) < g.gate_width * 0.5:
			openings_clear = false
		if absf(p.x) > th * 0.9 and absf(p.y) < g.walkway_width * 0.5:
			openings_clear = false
	check(openings_clear, "r=%.1f: no banner in the wall's openings" % r)
	tall.append_array(GreatWallArena.lantern_spots(r))
	var tall_ok := true
	for p in tall:
		if p.length() <= cam or maxf(absf(p.x), absf(p.y)) >= th:
			tall_ok = false
	check(tall_ok, "r=%.1f: banners and lanterns beyond the camera's limit, on the terrace" % r)

	var under := true
	var reach := GreatWallArena.terrace_outer(r) + 10.0
	for i in 11:
		for k in 11:
			var x := -reach + reach * 2.0 * i / 10.0
			var z := -reach + reach * 2.0 * k / 10.0
			if GreatWallArena.ground_height(x, z, r) > -2.0:
				under = false
	check(under, "r=%.1f: the ground stays below the terrace around it" % r)

	for side: float in [1.0, -1.0]:
		var path := GreatWallArena.wall_path(side, r)
		check(is_zero_approx(path[0].y) and is_equal_approx(absf(path[0].x), GreatWallArena.terrace_outer(r)),
				"r=%.1f side %+d: the wall leaves the terrace level with it" % [r, side])
		var steepest := 0.0
		var off_ridge := 0.0
		var trench := -INF
		var climbs := 0.0
		for i in path.size():
			var p := path[i]
			off_ridge = maxf(off_ridge, absf(GreatWallArena.ground_height(p.x, p.z, r) - (p.y - g.terrace_height)))
			climbs = maxf(climbs, p.y)
			# Across the wall, the ground falls away from it on both sides.
			for across: float in [-1.0, 1.0]:
				for off: float in [15.0, 30.0, 60.0]:
					trench = maxf(trench, GreatWallArena.ground_height(p.x, p.z + across * off, r) - p.y)
			if i > 0:
				var d := p - path[i - 1]
				steepest = maxf(steepest, absf(d.y) / Vector2(d.x, d.z).length())
		check(steepest <= MAX_WALK_SLOPE, "r=%.1f side %+d: walkway slope at most %.2f (%.2f)" % [r, side, MAX_WALK_SLOPE, steepest])
		check(off_ridge <= RIDGE_TOLERANCE, "r=%.1f side %+d: the wall stands on its ridge (%.2f m off)" % [r, side, off_ridge])
		check(trench < 0.0, "r=%.1f side %+d: the wall keeps to its crest, the ground below it (%.1f m)" % [r, side, trench])
		check(climbs > g.ridge_rise * 0.5, "r=%.1f side %+d: the wall climbs the ridge (%.0f m)" % [r, side, climbs])
		var end := path[path.size() - 1]
		check(Vector2(end.x, end.z).length() < Tuning.camera.far, "r=%.1f side %+d: the wall ends inside the far plane" % [r, side])


func _test_great_wall_build() -> void:
	var arena := Arena.create(ArenaCatalog.GREAT_WALL)
	arena.radius = Tuning.match_rules.arena_radius
	add_child(arena)
	await get_tree().process_frame
	var props := arena.get_node("Props")
	for node_name: String in ["Posts", "Cord", "Bastion", "GateTower", "Pavilion", "WallEast", "WallWest",
			"WatchtowersEast", "WatchtowersWest", "Banners", "BannerPoles", "Lanterns", "Trees"]:
		check(props.has_node(node_name), "Great Wall has its %s" % node_name)
	for node_name: String in ["Terrace", "Terrain", "Mist", "FloorBody", "Sun", "WorldEnvironment"]:
		check(arena.has_node(node_name), "Great Wall has its %s" % node_name)
	var trees := props.get_node("Trees") as MultiMeshInstance3D
	var conifers := props.get_node("Conifers") as MultiMeshInstance3D
	var tree_total := trees.multimesh.instance_count + conifers.multimesh.instance_count
	check(tree_total > Tuning.arena_great_wall.tree_count / 2, "the slopes are wooded (%d trees)" % tree_total)
	# The drawn terrain (coarser than ground_height) meets the wall's body:
	# below the walkway, above the foot of the wall.
	var g := Tuning.arena_great_wall
	var wall := arena as GreatWallArena
	var worst_high := -INF
	var worst_low := -INF
	for side: float in [1.0, -1.0]:
		for p in GreatWallArena.wall_path(side, arena.radius):
			var h := wall._mesh_height(p.x, p.z)
			worst_high = maxf(worst_high, h - p.y)
			worst_low = maxf(worst_low, (p.y - g.terrace_height - g.wall_footing) - h)
	check(worst_high < -1.0, "the drawn terrain stays under the walkway (%.1f m)" % worst_high)
	check(worst_low < 0.0, "the wall's foot is buried in the drawn terrain (%.1f m)" % worst_low)
	check(props.get_child_count() < 40, "few nodes: repeated props are batched (%d)" % props.get_child_count())
	arena.queue_free()
