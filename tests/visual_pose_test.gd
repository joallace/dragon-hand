extends Node
## Headless test for FighterVisual's static poses: grounded poses must rest on
## the floor (y = 0) instead of floating above or sinking into it.
##   godot --headless res://tests/visual_pose_test.tscn

## Max gap (m) allowed between a grounded pose's lowest point and the floor.
const GROUND_TOLERANCE := 0.03
## Max gap (m) between a lying body's torso/limbs and the floor (they touch it).
const LYING_PART_TOLERANCE := 0.05
## Get-up poses whose lowest point must touch the floor.
const GROUNDED: Array[StringName] = [&"knockdown", &"wakeup"]
## Standing poses (feet planted) whose lowest point must stay within
## FOOT_TOLERANCE of the floor (no sinking, no floating). Attack key poses
## are checked by tests/move_tracks_test.
const STANDING: Array[StringName] = [
	&"guard", &"guard_high", &"guard_low", &"counter_guard", &"recoil",
	&"throw_hold", &"throw_toss", &"taunt", &"dash_start", &"dash_stop",
	&"charge_end", &"duck", &"duck_curl", &"duck_wide", &"getup_kick", &"getup_kick_windup",
	&"sway_l_dip", &"sway_r_dip", &"backflip_load", &"backflip_land", &"charge_gather",
	&"hitstun", &"hitstun_body", &"hitstun_low",
]
const FOOT_TOLERANCE := 0.12
## Highest point (m) a duck pose may reach: the original single duck pose's
## (the primitive rig's head can't get under FighterTuning.duck_height).
const DUCK_MAX_TOP := 1.25
## Static attack poses that must have a "<pose>_windup" for their startup
## (the get-up strike's track keys them).
const NEEDS_WINDUP: Array[StringName] = [&"getup_kick"]
const MOVES_DIR := "res://data/moves/"

var _ok := true
var _visual: FighterVisual


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: ", what)


func _ready() -> void:
	_visual = FighterVisual.new()
	add_child(_visual)
	for id in GROUNDED:
		_apply(id)
		var low := _lowest(_visual._body)
		print("%s lowest point y = %.3f" % [id, low])
		_check(absf(low) <= GROUND_TOLERANCE, "%s rests on the floor (lowest y %.3f)" % [id, low])
	# Lying down, the torso, legs and arms lie on the floor, not just one limb.
	_apply(&"knockdown")
	for j in [&"torso", &"hip_l", &"hip_r", &"sh_l", &"sh_r"]:
		var low := _lowest(_visual._joints[j], j != &"torso")
		if j == &"torso":  # the body: waist and chest bones, not the limbs on them
			low = minf(low, _lowest(_visual._joints[&"chest"], false))
		_check(low >= -GROUND_TOLERANCE and low <= LYING_PART_TOLERANCE,
			"knockdown %s on the floor (lowest y %.3f)" % [j, low])
	# Getting up, the planted foot and the kneeling leg both touch the floor.
	_apply(&"wakeup")
	for j in [&"kn_l", &"kn_r"]:
		var low := _lowest(_visual._joints[j])
		_check(absf(low) <= GROUND_TOLERANCE, "wakeup %s on the floor (lowest y %.3f)" % [j, low])
	# Get-up strike: spinning on both hands planted on the floor.
	for id in [&"getup_kick", &"getup_kick_windup"]:
		_apply(id)
		for j in [&"el_l", &"el_r"]:
			var low := _lowest(_visual._joints[j])
			print("%s %s lowest point y = %.3f" % [id, j, low])
			_check(absf(low) <= FOOT_TOLERANCE, "%s %s hand on the floor (lowest y %.3f)" % [id, j, low])
	_test_states_resolve()
	_test_move_poses()
	_test_duck_variants()
	for id in STANDING:
		_apply(id)
		var low := _lowest(_visual._body)
		print("%s lowest point y = %.3f" % [id, low])
		_check(absf(low) <= FOOT_TOLERANCE, "%s feet on the floor (lowest y %.3f)" % [id, low])
	print("VISUAL POSE TEST %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)


## Every pose Fighter.current_pose() can report outside ATTACK maps to a
## defined pose (no silent fallback to idle).
func _test_states_resolve() -> void:
	var ids: Array[StringName] = [&"knockdown", &"launched"]
	ids.append_array(Fighter.GUARD_POSE_NAMES)
	for d in Fighter.DODGE_NAMES:
		if d != &"none":
			ids.append(d)
	for st in Fighter.STATE_NAMES:
		if st not in [&"attack", &"dodge", &"ko", &"walk", &"throw"]:
			ids.append(st)
	for id in ids:
		_check(FighterVisual.POSES.has(FighterVisual.pose_id_for(id, id, 0, Tuning.fighter)),
			"state pose %s defined" % id)
	_check(FighterVisual.pose_id_for(&"walk", &"walk", 0, Tuning.fighter) == &"idle", "walk -> idle")
	# The thrower holds through the break window, then tosses.
	var hold := FighterVisual.pose_id_for(&"throw", &"throw", 0, Tuning.fighter)
	var toss := FighterVisual.pose_id_for(&"throw", &"throw", Tuning.fighter.throw_break_frames, Tuning.fighter)
	_check(hold == &"throw_hold" and toss == &"throw_toss", "throw state hold -> toss (%s, %s)" % [hold, toss])
	_check(FighterVisual.POSES.has(hold) and FighterVisual.POSES.has(toss), "throw hold/toss poses defined")


## Every move's pose (a static pose or a MoveTracks track; and the new
## moves' windups) is defined.
func _test_move_poses() -> void:
	for file in DirAccess.get_files_at(MOVES_DIR):
		if file.get_extension() != "tres":
			continue
		var m := load(MOVES_DIR + file) as MoveData
		if m == null or m.pose == &"":
			continue
		_check(FighterVisual.POSES.has(m.pose) or MoveTracks.has_track(m.pose),
			"move %s pose %s defined (pose or track)" % [m.id, m.pose])
	for id in NEEDS_WINDUP:
		_check(FighterVisual.POSES.has(id), "pose %s defined" % id)
		_check(FighterVisual.POSES.has(StringName(String(id) + "_windup")), "pose %s_windup defined" % id)


## One duck pose per Fighter duck variant, none taller than the original
## duck, rising once the duck can chain.
func _test_duck_variants() -> void:
	var t := Tuning.fighter
	_check(FighterVisual.DUCK_POSES.size() == Fighter.DUCK_VARIANTS, "one duck pose per variant")
	for v in Fighter.DUCK_VARIANTS:
		var id := FighterVisual.pose_id_for(&"duck", &"dodge", 0, t, v)
		_check(id == FighterVisual.DUCK_POSES[v] and FighterVisual.POSES.has(id), "duck variant %d -> %s" % [v, id])
		_apply(id)
		var top := _highest(_visual._body)
		print("%s highest point y = %.3f" % [id, top])
		_check(top <= DUCK_MAX_TOP, "%s crouches low (top y %.3f)" % [id, top])
	_check(FighterVisual.pose_id_for(&"duck", &"dodge", t.duck_chain_from_frame + 1, t, 1) == &"idle",
		"duck rises after its chain frame")
	_check(FighterVisual.pose_id_for(&"sway_l", &"dodge", 0, t, 1) == &"sway_l", "sways keep their pose")


## Exact highest world-space y of every primitive mesh under `node`.
func _highest(node: Node) -> float:
	if _visual._skeleton != null:
		var high_m := -INF
		for p in FighterModel.posed_points(_visual._skeleton, _model_bones(node, true)):
			high_m = maxf(high_m, p.y)
		return high_m
	var high := -INF
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = (mi as MeshInstance3D).global_transform
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m is CapsuleMesh:
			var half := (m as CapsuleMesh).height * 0.5 - (m as CapsuleMesh).radius
			high = maxf(high, maxf((t * Vector3(0, half, 0)).y, (t * Vector3(0, -half, 0)).y) + (m as CapsuleMesh).radius)
		elif m is SphereMesh:
			high = maxf(high, t.origin.y + (m as SphereMesh).radius)
		elif m is BoxMesh:
			var h := (m as BoxMesh).size * 0.5
			for i in 8:
				high = maxf(high, (t * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)).y)
	return high


## Snap the visual straight to a named pose (no blending).
func _apply(id: StringName) -> void:
	_visual.snap_to_pose(FighterVisual.POSES[id])


## Skeleton bone indices of `node`'s joint (and the joints under it when
## `deep`); `node` = the body = every bone.
func _model_bones(node: Node, deep: bool) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in _visual._rig.size():
		var n := _visual._rig[i]
		if n == node or (deep and node.is_ancestor_of(n)):
			out.append(i)
	return out


## Exact lowest world-space y of every primitive mesh under `node` (only its
## own meshes, not child joints', when `deep` is false).
func _lowest(node: Node, deep := true) -> float:
	if _visual._skeleton != null:
		var low_m := INF
		for p in FighterModel.posed_points(_visual._skeleton, _model_bones(node, deep)):
			low_m = minf(low_m, p.y)
		return low_m
	var low := INF
	for mi in node.find_children("*", "MeshInstance3D", deep, false):
		var t: Transform3D = (mi as MeshInstance3D).global_transform
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m is CapsuleMesh:
			var half := (m as CapsuleMesh).height * 0.5 - (m as CapsuleMesh).radius
			var a := t * Vector3(0, half, 0)
			var b := t * Vector3(0, -half, 0)
			low = minf(low, minf(a.y, b.y) - (m as CapsuleMesh).radius)
		elif m is SphereMesh:
			low = minf(low, t.origin.y - (m as SphereMesh).radius)
		elif m is BoxMesh:
			var h := (m as BoxMesh).size * 0.5
			for i in 8:
				var c := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
				low = minf(low, (t * c).y)
	return low
