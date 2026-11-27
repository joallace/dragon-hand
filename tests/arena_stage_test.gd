extends Node
## Stages (ArenaCatalog / Arena.create): the factory, and the beach bar's and
## Times Square's layouts against the play circle and the camera at every
## arena size: nothing stands inside the rope / barricades, nothing tall where
## the camera can go, the sea stays clear of the sand's props, the plaza's
## props stay on the plaza. Plus each build and a real match on each.
## Run as a scene:  godot --headless res://tests/arena_stage_test.tscn

## Footprints around a spot: chairs around a table, an umbrella's canopy.
const TABLE_REACH := 1.5
const UMBRELLA_REACH := BeachArena.UMBRELLA_RADIUS
const MATCH_FRAMES := 30

var _fails := 0


func _ready() -> void:
	_test_catalog()
	_test_layout(Tuning.match_rules.arena_radius)
	var biggest := Tuning.match_rules.arena_radius \
			+ Tuning.coop.arena_radius_per_extra_fighter * (Tuning.coop.field_cap - 2)
	_test_layout(biggest)
	_test_times_square_layout(Tuning.match_rules.arena_radius)
	_test_times_square_layout(biggest)
	await _test_build()
	await _test_times_square_build()
	for id: StringName in [ArenaCatalog.BEACH_BAR, ArenaCatalog.TIMES_SQUARE]:
		await _test_match_scene(id)
	print("ARENA_STAGE %s (%d failures)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func check(cond: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		_fails += 1


func _test_catalog() -> void:
	var stone := Arena.create(ArenaCatalog.DEFAULT)
	var beach := Arena.create(ArenaCatalog.BEACH_BAR)
	var square := Arena.create(ArenaCatalog.TIMES_SQUARE)
	var unknown := Arena.create(&"from_a_newer_build")
	check(stone.get_script() == Arena, "default id builds the stone ring")
	check(beach is BeachArena, "beach_bar id builds the beach")
	check(square is TimesSquareArena, "times_square id builds Times Square")
	check(unknown.get_script() == Arena, "an unknown id falls back to the default")
	square.free()
	stone.free()
	beach.free()
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


func _test_times_square_layout(r: float) -> void:
	var t := Tuning.arena_times_square
	var cam := r + Tuning.camera.radius_margin
	var tables := TimesSquareArena.table_spots(r)
	check(tables.size() >= 10, "square r=%.1f: %d café tables" % [r, tables.size()])
	var outside := true
	var on_plaza := true
	var planter_x := TimesSquareArena.curb_x(r) - TimesSquareArena.PLANTER_INSET - TimesSquareArena.PLANTER_SIZE.x
	for p in tables:
		if p.length() - TimesSquareArena.TABLE_REACH <= r:
			outside = false
		if absf(p.x) + TimesSquareArena.TABLE_REACH > planter_x \
				or absf(p.y) + TimesSquareArena.TABLE_REACH > TimesSquareArena.cross_z(r):
			on_plaza = false
		if p.y + TimesSquareArena.TABLE_REACH > TimesSquareArena.steps_z(r) and absf(p.x) < t.steps_width * 0.5 + TimesSquareArena.TABLE_REACH:
			on_plaza = false
	check(outside, "square r=%.1f: tables outside the barricades" % r)
	check(on_plaza, "square r=%.1f: tables on the plaza, clear of planters, steps and cross streets" % r)
	# Tall things: lamps and signals on the curbs, the steps, carts, traffic.
	check(TimesSquareArena.curb_x(r) - 0.5 > cam, "square r=%.1f: the curbs (lamps, signals, traffic) are beyond the camera's limit (%.1f m)" % [r, cam])
	var lamps_clear := true
	var lamps_off_streets := true
	for l in TimesSquareArena.lamp_spots(r):
		if Vector2(l.x, l.y).length() <= cam:
			lamps_clear = false
		if TimesSquareArena.in_cross_street(l.y, r, 1.0):
			lamps_off_streets = false
	check(lamps_clear, "square r=%.1f: lamp posts beyond the camera's limit" % r)
	check(lamps_off_streets, "square r=%.1f: no lamp post stands in a cross street" % r)
	check(planter_x > cam, "square r=%.1f: planters (taller than a table) beyond the camera's limit" % r)
	check(TimesSquareArena.steps_z(r) > cam, "square r=%.1f: the red steps are beyond the camera's limit" % r)
	var steps_end := TimesSquareArena.steps_z(r) + t.steps_depth + TimesSquareArena.BOOTH_DEPTH
	check(steps_end < TimesSquareArena.cross_z(r) and t.steps_width * 0.5 < TimesSquareArena.curb_x(r),
			"square r=%.1f: the steps and their booth fit on the plaza" % r)
	var carts_ok := true
	for c in TimesSquareArena.cart_spots(r):
		if c.length() - 1.5 <= cam or absf(c.y) + 1.5 > TimesSquareArena.cross_z(r):
			carts_ok = false
	check(carts_ok, "square r=%.1f: food carts beyond the camera's limit, on the plaza" % r)
	check(-TimesSquareArena.tower_z(r) > TimesSquareArena.cross_z(r) + t.cross_width,
			"square r=%.1f: the tower stands past the -Z cross street" % r)
	check(t.tower_size.x * 0.5 < TimesSquareArena.curb_x(r), "square r=%.1f: the tower stays off the avenues" % r)


func _test_times_square_build() -> void:
	var arena := Arena.create(ArenaCatalog.TIMES_SQUARE)
	arena.radius = Tuning.match_rules.arena_radius
	add_child(arena)
	await get_tree().process_frame
	var props := arena.get_node("Props")
	for node_name: String in ["Barricades", "Tables", "Chairs", "Planters", "Steps", "StepsGlow", "Lamps", "Cars",
			"TaxiSigns", "Buildings", "Screens", "Ball"]:
		check(props.has_node(node_name), "square has its %s" % node_name)
	check(arena.has_node("FloorBody"), "square has the floor collider")
	check(arena.has_node("Sun") and arena.has_node("WorldEnvironment"), "square has its light and sky")
	var screens := props.get_node("Screens") as MultiMeshInstance3D
	check(screens.multimesh.instance_count >= 30, "the square is covered in screens (%d)" % screens.multimesh.instance_count)
	# Every barricade outside the play circle.
	var r := arena.radius
	var square := arena as TimesSquareArena
	var ring: Array = square.placements["Barricades"]
	var ring_ok := true
	for xf: Transform3D in ring:
		if Vector2(xf.origin.x, xf.origin.z).length() <= r:
			ring_ok = false
	check(ring_ok and ring.size() > 20, "%d barricades ring the play circle" % ring.size())
	# Every car off the plaza (on an avenue or a cross street).
	var cars: Array = square.placements["Cars"] + square.placements["Buses"]
	var cam := r + Tuning.camera.radius_margin
	var cars_ok := true
	for xf: Transform3D in cars:
		var o := xf.origin
		if Vector2(o.x, o.z).length() - TimesSquareArena.CAR_SIZE.z * 0.5 <= cam:
			cars_ok = false
		if absf(o.x) < TimesSquareArena.curb_x(r) and not TimesSquareArena.in_cross_street(o.z, r):
			cars_ok = false
	check(cars_ok and cars.size() > 40, "%d cars and buses, all in the streets beyond the camera" % cars.size())
	var texts: Array[String] = []
	for c in props.get_children():
		if c is Label3D:
			texts.append(c.text)
	check(texts.size() > 0 and texts.size() <= Tuning.arena_times_square.max_wordmarks,
			"a few wordmarks on the screens (%d)" % texts.size())
	var fictional := true
	for text in texts:
		if text not in Tuning.arena_times_square.brands:
			fictional = false
	check(fictional, "wordmarks come from the tuning's fictional brands")
	arena.queue_free()


## A whole match scene on a stage: config -> Arena.create -> running.
func _test_match_scene(id: StringName) -> void:
	var cfg := MatchScene.build_default_config()
	cfg.arena_id = id
	for p in cfg.players:
		p.input_kind = PlayerSlotConfig.InputKind.CPU
	Game.current_config = cfg
	var scene := MatchScene.new()
	add_child(scene)
	for i in MATCH_FRAMES:
		await get_tree().process_frame
	var expected: Script = BeachArena if id == ArenaCatalog.BEACH_BAR else TimesSquareArena
	check(scene.arena.get_script() == expected,
			"a match with the %s id plays on that stage" % id)
	check(is_equal_approx(scene.arena.radius, scene.director.arena_radius), "stage and sim agree on the radius")
	check(scene.director.fighters.size() == cfg.players.size(), "the match runs with its fighters")
	Game.current_config = null
	scene.free()
