extends Node
## Keyframed move tracks (MoveTracks), pose springs (PoseSprings) and their
## use by FighterVisual. Visual only, so what this checks is geometry and
## timing, not feel:
## - every contact pose puts its fist/foot on its move's hitbox center;
## - every key pose keeps the feet planted like the idle stance;
## - tracks are well formed and land the contact pose on the first active
##   frame; the timeline maps frames to phases;
## - springs converge, overshoot only when underdamped, and don't depend on
##   the frame rate;
## - in a real match the rendered jab fist reaches the hitbox while it is
##   live, and a hit taken kicks the victim back.
##   godot --headless res://tests/move_tracks_test.tscn

const B := InputFrame.Btn
## Max distance (m) between a contact pose's fist/foot and the hitbox center
## (hitbox radii are 0.45-0.55).
const CONTACT_TOLERANCE := 0.1
## Max difference (m) between a key pose's lowest point and idle's.
const FLOOR_TOLERANCE := 0.03
## Live match: the fist must come this close to the hitbox center during the
## active frames (springs + one tick of clock lag).
const LIVE_TOLERANCE := 0.2
const MOVES_DIR := "res://data/moves/"

var _failures := 0
var _visual: FighterVisual


func _ready() -> void:
	_visual = FighterVisual.new()
	add_child(_visual)
	_test_contacts()
	_test_feet()
	_test_track_shape()
	_test_timeline()
	_test_springs()
	_visual.queue_free()
	_test_live_jab()
	print("MOVE TRACKS TESTS: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(cond: bool, label: String) -> bool:
	print("%s %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1
	return cond


func _apply(pose: Dictionary) -> void:
	var idle: Dictionary = FighterVisual.POSES[&"idle"]
	for j in FighterVisual.JOINTS:
		(_visual._joints[j] as Node3D).rotation_degrees = pose.get(j, idle[j])
	_visual._body.position = pose.get(&"root", idle[&"root"])
	if _visual._skeleton != null:
		FighterModel.sync_pose(_visual._skeleton, _visual._rig)


static func _effector(joints: Dictionary, j: StringName) -> Vector3:
	var off := MoveTracks.FIST_OFFSET if String(j).begins_with("el") else MoveTracks.FOOT_OFFSET
	return (joints[j] as Node3D).global_transform * off


## Hitbox center in the visual's space (fighter space +z = visual -Z).
static func _hitbox_local(m: MoveData) -> Vector3:
	return Vector3(m.hitbox_offset.x, m.hitbox_offset.y, -m.hitbox_offset.z)


func _lowest() -> float:
	if _visual._skeleton == null:
		var low := INF
		for j in [&"kn_l", &"kn_r"]:
			low = minf(low, _effector(_visual._joints, j).y)
		return low
	var all := PackedInt32Array()
	for i in _visual._rig.size():
		all.append(i)
	var lo := INF
	for p in FighterModel.posed_points(_visual._skeleton, all):
		lo = minf(lo, p.y)
	return lo


func _test_contacts() -> void:
	for id: StringName in MoveTracks.CONTACTS:
		var c: Array = MoveTracks.CONTACTS[id]
		var m := load(MOVES_DIR + String(c[1]) + ".tres") as MoveData
		if not _check(m != null, "contact move %s exists" % c[1]):
			continue
		_check(MoveTracks.has_track(m.pose), "%s's pose %s has a track" % [m.id, m.pose])
		_apply(MoveTracks.KEY_POSES[id])
		var d := _effector(_visual._joints, c[0]).distance_to(_hitbox_local(m))
		_check(d <= CONTACT_TOLERANCE, "%s: %s on %s's hitbox (%.3f m off)" % [id, c[0], m.id, d])


func _test_feet() -> void:
	_apply(FighterVisual.POSES[&"idle"])
	var ref := _lowest()
	for id: StringName in MoveTracks.KEY_POSES:
		_apply(MoveTracks.KEY_POSES[id])
		var low := _lowest()
		_check(absf(low - ref) <= FLOOR_TOLERANCE, "%s feet planted (lowest %.3f, idle %.3f)" % [id, low, ref])


func _test_track_shape() -> void:
	for pose: StringName in MoveTracks.TRACKS:
		var keys: Array = MoveTracks.TRACKS[pose]
		var prev := -1.0
		var ok := true
		var contact_at := -1.0
		for k: Array in keys:
			var u := float(k[0])
			ok = ok and u >= prev and u >= 0.0 and u <= 3.0
			ok = ok and (MoveTracks.KEY_POSES.has(k[1]) or FighterVisual.POSES.has(k[1]))
			if MoveTracks.CONTACTS.has(k[1]) and contact_at < 0.0:
				contact_at = u
			prev = u
		_check(ok, "track %s: keys ordered in 0..3, poses defined" % pose)
		_check(is_equal_approx(contact_at, 1.0), "track %s: contact pose on the first active frame" % pose)
		_check(keys[-1][1] == &"idle", "track %s ends in idle" % pose)
		var s := MoveTracks.sample(pose, 1.0, FighterVisual.POSES[&"idle"])
		_check(s.size() == FighterVisual.POSES[&"idle"].size(), "track %s samples a full pose" % pose)


func _test_timeline() -> void:
	var m := MoveData.new()
	m.startup = 5
	m.active = 3
	m.recovery = 12
	_check(is_equal_approx(MoveTracks.timeline_u(m, 0), 0.0), "frame 0 -> u 0")
	_check(is_equal_approx(MoveTracks.timeline_u(m, 2.5), 0.5), "mid startup -> u 0.5")
	_check(is_equal_approx(MoveTracks.timeline_u(m, 5), 1.0), "first active frame -> u 1")
	_check(is_equal_approx(MoveTracks.timeline_u(m, 8), 2.0), "first recovery frame -> u 2")
	_check(is_equal_approx(MoveTracks.timeline_u(m, 14), 2.5), "mid recovery -> u 2.5")
	_check(is_equal_approx(MoveTracks.timeline_u(m, 40), 3.0), "past the end -> u 3")
	m.active = 0
	_check(is_equal_approx(MoveTracks.timeline_u(m, 5), 2.0), "no active frames: skipped")


func _spring_run(dt: float, seconds: float, zeta: float) -> Array:
	var sp := PoseSprings.new()
	sp.reset(&"a", Vector3.ZERO)
	var target := {&"a": Vector3(100, 0, 0)}
	var peak := 0.0
	var t := 0.0
	while t < seconds - 0.00001:
		sp.step(target, target, dt, 8.0, zeta, 1.0 / 240.0, 24)
		peak = maxf(peak, sp.value(&"a").x)
		t += dt
	return [sp.value(&"a").x, peak]


func _test_springs() -> void:
	var under := _spring_run(1.0 / 60.0, 1.0, 0.5)
	_check(absf(under[0] - 100.0) < 1.0, "underdamped spring settles on target (%.2f)" % under[0])
	_check(under[1] > 105.0, "underdamped spring overshoots (peak %.1f)" % under[1])
	var crit := _spring_run(1.0 / 60.0, 1.0, 1.0)
	_check(crit[1] <= 100.01, "critically damped spring never overshoots (peak %.2f)" % crit[1])
	var slow := _spring_run(1.0 / 30.0, 0.2, 0.5)
	var fast := _spring_run(1.0 / 144.0, 0.2, 0.5)
	_check(absf(slow[0] - fast[0]) < 2.0, "springs independent of frame rate (30 fps %.1f vs 144 fps %.1f)"
		% [slow[0], fast[0]])
	var stiff := PoseSprings.new()
	stiff.reset(&"a", Vector3.ZERO)
	for i in 60:
		stiff.step({&"a": Vector3(100, 0, 0)}, {}, 1.0 / 60.0, 120.0, 0.3, 1.0 / 240.0, 200)
	_check(stiff.value(&"a").is_finite() and absf(stiff.value(&"a").x - 100.0) < 1.0,
		"a very stiff spring stays stable (%s)" % stiff.value(&"a"))
	var sp := PoseSprings.new()
	sp.reset(&"a", Vector3.ZERO)
	sp.step({&"a": Vector3(50, 0, 0)}, {}, 1.0, 8.0, 0.5, 1.0 / 240.0, 24)
	_check(sp.value(&"a") == Vector3(50, 0, 0), "a long stall snaps to the target")


## Real match: P1 jabs P2; render the visual once per tick.
func _test_live_jab() -> void:
	var cfg := MatchConfig.from_defaults()
	cfg.round_time_seconds = 0
	for i in 2:
		var p := PlayerSlotConfig.new()
		p.slot = i
		p.input_kind = PlayerSlotConfig.InputKind.CPU
		cfg.players.append(p)
	var d := MatchDirector.new()
	d.auto_step = false
	add_child(d)
	d.setup(cfg)
	for i in 2:
		d.sources[i] = ScriptedInput.new()
	while d.phase != MatchDirector.Phase.FIGHT:
		d.step()
	for i in 2:
		var pos := Vector3(0, 0, 0.7 if i == 0 else -0.7)
		d.fighters[i].reset_for_round(Transform3D(Basis.looking_at(-pos.normalized()), pos))
		(d.sources[i] as ScriptedInput).start_tick = d.tick + 1
	var p1 := d.fighters[0]
	var p2 := d.fighters[1]
	var v1 := _visual_of(p1)
	var v2 := _visual_of(p2)
	if not _check(v1 != null and v2 != null, "fighters have visuals"):
		return
	var hit := [false]
	p2.event.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"hit" and data.get("slot", -1) == p2.slot:
			hit[0] = true)
	(d.sources[0] as ScriptedInput).press(0, B.LIGHT)
	var best := INF
	var move: MoveData = null
	var kicked := false
	var finite := true
	for t in 40:
		d.step()
		for v in [v1, v2]:
			v.record()  # no _physics_process when stepping by hand
			v._process(1.0 / 60.0)
		if hit[0] and not kicked:
			kicked = v2._springs.velocity(&"torso").x > 0.0
		for j in FighterVisual.JOINTS:
			finite = finite and v1._springs.value(j).is_finite() and v2._springs.value(j).is_finite()
		var m := p1.current_move()
		if m == null:
			continue
		move = m
		if p1.attack_phase() != 1:
			continue
		var fist := _effector(v1._joints, &"el_l")
		var local := v1.global_transform.affine_inverse() * fist
		best = minf(best, local.distance_to(_hitbox_local(m)))
	_check(move != null and move.pose == &"jab", "P1 threw the jab (%s)" % (move.id if move else "none"))
	_check(best <= LIVE_TOLERANCE, "rendered jab fist reaches the live hitbox (%.3f m)" % best)
	_check(hit[0] and kicked, "the hit kicks the victim's torso back")
	_check(finite, "spring values stay finite")
	d.queue_free()


func _visual_of(f: Fighter) -> FighterVisual:
	var found := f.find_children("*", "FighterVisual", true, false)
	return found[0] as FighterVisual if not found.is_empty() else null
