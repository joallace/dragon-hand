extends Node
## Headless test for per-character body models (CharacterDef.model_path):
## every roster character's visual loads its own model (or the shared one),
## covers the whole rig like the Brawler's, and stands / lies / crouches on
## the floor at its own body_scale, the checks visual_pose_test runs on the
## default body.
##   godot --headless res://tests/character_model_test.tscn

## Floor tolerances (m, before body_scale.y): visual_pose_test's.
const GROUND_TOLERANCE := 0.03
const FOOT_TOLERANCE := 0.12
const GROUNDED: Array[StringName] = [&"knockdown", &"wakeup"]
const STANDING: Array[StringName] = [
	&"idle", &"guard", &"guard_high", &"guard_low", &"counter_guard", &"recoil",
	&"throw_hold", &"throw_toss", &"taunt", &"dash_start", &"dash_stop",
	&"charge_end", &"getup_kick", &"sway_l_dip", &"sway_r_dip", &"backflip_load",
	&"backflip_land", &"charge_gather", &"hitstun", &"hitstun_body", &"hitstun_low",
]
## Highest point (m, before body_scale.y) a crouch may reach: the default
## body's bound (visual_pose_test DUCK_MAX_TOP).
const DUCK_MAX_TOP := 1.25

var _ok := true


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: ", what)


func _ready() -> void:
	var shared := _make(CharacterRegistry.load_def(&"brawler"))
	var shared_bones := _bones_with_parts(shared)
	shared.queue_free()
	_check(not shared_bones.is_empty(), "shared model has parts")
	var own := 0
	for id in CharacterRegistry.ids():
		var d := CharacterRegistry.load_def(id)
		var v := _make(d)
		var path := FighterVisual.model_path_for(d)
		print("%s model %s" % [id, path])
		if not d.model_path.is_empty():
			own += 1
			_check(path == d.model_path, "%s wears its own model %s" % [id, d.model_path])
		_check(v._skeleton != null, "%s body is a model, not primitives" % id)
		if v._skeleton == null:
			v.queue_free()
			continue
		_check(_bones_with_parts(v) == shared_bones, "%s model covers the same joints as the shared one" % id)
		_test_floor(id, d, v)
		v.queue_free()
	_check(own > 0, "at least one character has its own model")
	# A missing model file falls back to the shared body, not primitives.
	var broken := CharacterDef.new()
	broken.model_path = "res://assets/models/does_not_exist.glb"
	_check(FighterVisual.model_path_for(broken) == Tuning.vfx.fighter_model_path,
		"missing model falls back to the shared one")
	print("CHARACTER MODEL TEST %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)


func _test_floor(id: StringName, d: CharacterDef, v: FighterVisual) -> void:
	for pose in GROUNDED:
		_apply(v, pose)
		var low := _lowest(v)
		_check(absf(low) <= GROUND_TOLERANCE * d.body_scale.y, "%s %s rests on the floor (lowest y %.3f)" % [id, pose, low])
	for pose in STANDING:
		_apply(v, pose)
		var low := _lowest(v)
		_check(absf(low) <= FOOT_TOLERANCE * d.body_scale.y, "%s %s feet on the floor (lowest y %.3f)" % [id, pose, low])
	var max_top := DUCK_MAX_TOP * d.body_scale.y
	for pose in FighterVisual.DUCK_POSES:
		_apply(v, pose)
		var top := _highest(v)
		print("%s %s top y = %.3f (max %.3f)" % [id, pose, top, max_top])
		_check(top <= max_top, "%s %s crouches low (top %.3f)" % [id, pose, top])


func _make(d: CharacterDef) -> FighterVisual:
	var v := FighterVisual.new()
	v.preview_def = d
	add_child(v)
	return v


func _apply(v: FighterVisual, id: StringName) -> void:
	v.snap_to_pose(FighterVisual.POSES[id])


## Names of the bones that carry vertices.
func _bones_with_parts(v: FighterVisual) -> Array[StringName]:
	var out: Array[StringName] = []
	if v._skeleton == null:
		return out
	for i in v._rig.size():
		if not FighterModel.posed_points(v._skeleton, PackedInt32Array([i])).is_empty():
			out.append(v._rig[i].name)
	out.sort()
	return out


func _lowest(v: FighterVisual) -> float:
	var low := INF
	for p in FighterModel.posed_points(v._skeleton):
		low = minf(low, p.y)
	return low


func _highest(v: FighterVisual) -> float:
	var high := -INF
	for p in FighterModel.posed_points(v._skeleton):
		high = maxf(high, p.y)
	return high
