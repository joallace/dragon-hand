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
	_test_all_moves_tracked()
	_test_state_tracks()
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
	_visual.snap_to_pose(pose)


static func _effector(joints: Dictionary, j: StringName) -> Vector3:
	return MoveTracks.effector(joints, j)


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
		if m.pose != &"":  # projectile shots: posed by the move that spawns them
			_check(MoveTracks.has_track(m.pose), "%s's pose %s has a track" % [m.id, m.pose])
		_apply(MoveTracks.KEY_POSES[id])
		var d := _effector(_visual._joints, c[0]).distance_to(_hitbox_local(m))
		_check(d <= CONTACT_TOLERANCE, "%s: %s on %s's hitbox (%.3f m off)" % [id, c[0], m.id, d])
		# As played: every track keying this pose on its first active frame,
		# sampled there (what the visual shows, not the raw key).
		for track: StringName in MoveTracks.TRACKS:
			for k: Array in MoveTracks.TRACKS[track]:
				if k[1] != id or not is_equal_approx(float(k[0]), 1.0):
					continue
				_apply(MoveTracks.sample(track, 1.0, FighterVisual.POSES[&"idle"]))
				var dp := _effector(_visual._joints, c[0]).distance_to(_hitbox_local(m))
				_check(dp <= CONTACT_TOLERANCE, "track %s as played reaches %s's hitbox (%.3f m off)"
					% [track, m.id, dp])


func _test_feet() -> void:
	_apply(FighterVisual.POSES[&"idle"])
	var ref := _lowest()
	for id: StringName in MoveTracks.KEY_POSES:
		if _airborne(id):
			continue
		_apply(MoveTracks.KEY_POSES[id])
		var low := _lowest()
		_check(absf(low - ref) <= FLOOR_TOLERANCE, "%s feet planted (lowest %.3f, idle %.3f)" % [id, low, ref])


## Key pose of an airborne track ("<track>_<key>").
static func _airborne(id: StringName) -> bool:
	for t in MoveTracks.AIRBORNE:
		if String(id).begins_with(String(t) + "_"):
			return true
	return false


## State tracks: keys ordered in 0..1 on defined poses, a real tuning length,
## and the right key per state.
func _test_state_tracks() -> void:
	for key: StringName in StateTracks.TRACKS:
		var tr: Dictionary = StateTracks.TRACKS[key]
		var f: Variant = tr["frames"]
		_check(f is int or f in Tuning.fighter, "state track %s: length %s exists" % [key, f])
		var prev := -1.0
		var ok := true
		for k: Array in tr["keys"]:
			ok = ok and float(k[0]) >= prev and float(k[0]) <= 1.0
			ok = ok and (MoveTracks.KEY_POSES.has(k[1]) or FighterVisual.POSES.has(k[1]))
			prev = float(k[0])
		_check(ok, "state track %s: keys ordered in 0..1, poses defined" % key)
		var s := StateTracks.sample(key, 1e6, Tuning.fighter, FighterVisual.POSES[&"idle"])
		_check(s.size() == FighterVisual.rest_pose().size(), "state track %s holds a full pose past its end" % key)
	_check(StateTracks.key_for(&"dodge", &"sway_l") == &"sway_l", "a sway dodge plays its track")
	_check(StateTracks.key_for(&"dodge", &"duck") == &"", "ducks keep their variant poses")
	_check(StateTracks.key_for(&"dodge", &"backflip", Fighter.DodgeKind.AIR_TECH) == &"",
		"an air tech keeps the static backflip tuck")
	_check(StateTracks.key_for(&"charge", &"charge") == &"charge", "the ki charge plays its track")
	_check(StateTracks.key_for(&"idle", &"idle") == &"", "idle has no state track")


## Every attack pose any move uses has a track (no static fallbacks left).
func _test_all_moves_tracked() -> void:
	for file in DirAccess.get_files_at(MOVES_DIR):
		if file.get_extension() != "tres":
			continue
		var m := load(MOVES_DIR + file) as MoveData
		if m != null and m.pose != &"":
			_check(MoveTracks.has_track(m.pose), "move %s pose %s has a track" % [m.id, m.pose])


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
		if pose in MoveTracks.NO_CONTACT:
			_check(contact_at < 0.0, "track %s: listed without contact, has none" % pose)
		else:
			_check(is_equal_approx(contact_at, 1.0), "track %s: contact pose on the first active frame" % pose)
		_check(keys[-1][1] == &"idle", "track %s ends in idle" % pose)
		var s := MoveTracks.sample(pose, 1.0, FighterVisual.POSES[&"idle"])
		_check(s.size() == FighterVisual.rest_pose().size(), "track %s samples a full pose" % pose)


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
	v2._hit_zone = FighterVisual.HitZone.LOW  # the jab must set it
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
	_check(v2._hit_zone == FighterVisual.HitZone.HEAD, "a jab lands in the head zone (%d)" % v2._hit_zone)
	# A kick's hit point (hitbox at 1.0 m) is a body blow, a sweep's a low hit.
	var kick := load(MOVES_DIR + "brawler_kick.tres") as MoveData
	var sweep := load(MOVES_DIR + "brawler_sweep.tres") as MoveData
	v2._hit_reaction(p2.global_transform * Vector3(0, kick.hitbox_offset.y, 0), false, false)
	_check(v2._hit_zone == FighterVisual.HitZone.BODY, "a kick lands in the body zone (%d)" % v2._hit_zone)
	v2._hit_reaction(p2.global_transform * Vector3(0, sweep.hitbox_offset.y, 0), false, false)
	_check(v2._hit_zone == FighterVisual.HitZone.LOW, "a sweep lands in the low zone (%d)" % v2._hit_zone)
	_check(FighterVisual.pose_id_for(&"hitstun", &"hitstun", 0, Tuning.fighter) == &"hitstun"
		and FighterVisual.HITSTUN_POSES.size() == FighterVisual.HitZone.size(), "one hitstun pose per zone")
	_check(finite, "spring values stay finite")
	d.queue_free()


func _visual_of(f: Fighter) -> FighterVisual:
	var found := f.find_children("*", "FighterVisual", true, false)
	return found[0] as FighterVisual if not found.is_empty() else null
