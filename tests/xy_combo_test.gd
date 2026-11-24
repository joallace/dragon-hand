extends Node
## BT3 X / Y combos (LIGHT = rush, HEAVY = finisher / blast) and when the
## victim falls (BT3 reactions + God Hand floaty juggles). Run as a scene:
##   godot --headless res://tests/xy_combo_test.tscn

const B := InputFrame.Btn
const FWD := Vector2(0, 1)
const BACK := Vector2(0, -1)

var _failures := 0
var _events: Array = []  # [slot, kind, data]


func _ready() -> void:
	var tests: Array[Callable] = [
		_test_five_hit_string, _test_finisher_by_position, _test_tapped_finishers_stagger,
		_test_full_string_finisher_falls, _test_ender_pushes_back, _test_neutral_heavy,
		_test_upper_hook_juggle, _test_floaty_fall, _test_juggle_cap, _test_sweep,
		_test_hold_y_charges_finisher, _test_tap_y_doesnt_wait, _test_smash_knockdown_ratio,
		_test_charged_ki_blast, _test_charged_ki_blast_needs_ki, _test_follow_up_after_finisher,
		_test_save_load_hold_gate, _test_determinism, _test_held_blast_fires_once, _test_juggle_slam_stays_down,
		_test_weak_charge_keeps_loop_key, _test_air_blast_hangs_while_held,
	]
	for t in tests:
		t.call()
	print("XY COMBO TESTS: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


# --- harness ------------------------------------------------------------------

func _check(cond: bool, label: String) -> bool:
	print("%s %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1
	return cond


func _new_match(distance: float = 1.4) -> MatchDirector:
	for c in get_children():
		c.queue_free()
	_events.clear()
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
		var pos := Vector3(0, 0, distance * 0.5 if i == 0 else -distance * 0.5)
		d.fighters[i].reset_for_round(Transform3D(Basis.looking_at(-pos.normalized()), pos))
		d.fighters[i].event.connect(func(kind: StringName, data: Dictionary) -> void:
			_events.append([i, kind, data]))
		(d.sources[i] as ScriptedInput).start_tick = d.tick + 1
	return d


func _src(d: MatchDirector, slot: int) -> ScriptedInput:
	return d.sources[slot] as ScriptedInput


func _run(d: MatchDirector, n: int) -> void:
	for i in n:
		d.step()


func _run_until(d: MatchDirector, cond: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		d.step()
	return cond.call()


func _count(kind: StringName, slot: int = -1) -> int:
	var n := 0
	for e: Array in _events:
		if e[1] == kind and (slot < 0 or e[0] == slot):
			n += 1
	return n


func _last(kind: StringName) -> Dictionary:
	for i in range(_events.size() - 1, -1, -1):
		if _events[i][1] == kind:
			return _events[i][2]
	return {}


func _move_id(f: Fighter) -> StringName:
	return f.current_move().id if f.current_move() else &""


## Plays a string like a player confirming each hit: presses step 0 at once,
## then each next step the tick after the victim takes (or blocks) the
## previous hit. `steps` = [[btn, stick: Vector2], ...]. Runs `ticks` ticks
## and returns the moves slot 0 started, in order.
func _play(d: MatchDirector, steps: Array, ticks: int) -> Array[StringName]:
	var s := _src(d, 0)
	var seen: Array[StringName] = []
	var serial := -1
	var next := 0
	var hits := _count(&"hit", 1)
	for i in ticks:
		if next < steps.size() and (next == 0 or _count(&"hit", 1) > hits):
			hits = _count(&"hit", 1)
			var st: Array = steps[next]
			s.stick_at_tick(d.tick + 1, d.tick + 2, st[1]).press_at_tick(d.tick + 1, st[0])
			next += 1
		d.step()
		var f := d.fighters[0]
		if f.current_move_serial() != serial and f.current_state_name() == &"attack":
			serial = f.current_move_serial()
			seen.append(_move_id(f))
	return seen


## `n` X presses, then (unless `y` is false) Y with `stick`, as _play steps.
func _xy(n: int, y: bool = true, stick := Vector2.ZERO) -> Array:
	var steps := []
	for i in n:
		steps.append([B.LIGHT, Vector2.ZERO])
	if y:
		steps.append([B.HEAVY, stick])
	return steps


## Ticks until slot 1 takes its first hit (0 = before any step).
func _ticks_to_first_hit(d: MatchDirector, max_ticks: int) -> int:
	for i in max_ticks:
		if _count(&"hit", 1) > 0:
			return i
		d.step()
	return max_ticks


# --- tests --------------------------------------------------------------------

func _test_five_hit_string() -> void:
	var d := _new_match()
	var moves := _play(d, _xy(6, false), 120)
	var want: Array[StringName] = d.fighters[0].def.light_string
	_check(moves.slice(0, 5) == want, "X x5 = jab, jab, hook, kick, ender (%s)" % [moves])
	_check(_count(&"hit", 1) == 5 and _count(&"knockdown", 1) == 0, "all five land, nobody falls (%d hits)" % _count(&"hit", 1))


func _test_finisher_by_position() -> void:
	var ids := [&"brawler_finisher_1", &"brawler_finisher_2", &"brawler_finisher_3", &"brawler_finisher_4",
		&"brawler_finisher"]
	for n in 5:
		var d := _new_match()
		var moves := _play(d, _xy(n + 1), 120)
		_check(moves.size() == n + 2 and moves[n + 1] == ids[n], "%d X then Y = %s (%s)" % [n + 1, ids[n], moves])
	# Stick forward / back pick the upper hook / sweep at any position.
	for c: Array in [[FWD, &"brawler_upper_hook"], [BACK, &"brawler_sweep"]]:
		for n: int in [1, 3, 5]:
			var d := _new_match()
			var moves := _play(d, _xy(n, true, c[0]), 120)
			_check(moves.size() == n + 1 and moves[n] == c[1], "%d X then %s+Y = %s (%s)" % [n, c[0], c[1], moves])


func _test_tapped_finishers_stagger() -> void:
	for n in 4:
		var d := _new_match()
		_play(d, _xy(n + 1), 60 + n * 16)
		var p2 := d.fighters[1]
		_check(_count(&"hit", 1) == n + 2 and _count(&"stagger", 1) == 1 and _count(&"knockdown", 1) == 0,
			"finisher after %d X staggers, no fall (%s)" % [n + 1, p2.current_state_name()])


func _test_full_string_finisher_falls() -> void:
	var d := _new_match()
	_play(d, _xy(5), 140)
	_check(_count(&"knockdown", 1) == 1 and _count(&"hit", 1) == 6, "X x5 then Y blows the victim away (%d hits)" % _count(&"hit", 1))


func _test_ender_pushes_back() -> void:
	var d := _new_match()
	var p2 := d.fighters[1]
	var steps := _xy(5, false)
	var before := [0.0]
	var s := _src(d, 0)
	var next := 0
	var hits := 0
	for i in 140:
		if next < steps.size() and (next == 0 or _count(&"hit", 1) > hits):
			hits = _count(&"hit", 1)
			s.press_at_tick(d.tick + 1, B.LIGHT)
			next += 1
		if _count(&"hit", 1) == 4 and before[0] == 0.0:
			before[0] = p2.global_position.z
		d.step()
		if _count(&"hit", 1) == 5:
			break
	_run(d, 20)
	var moved := absf(p2.global_position.z - before[0])
	_check(_count(&"hit", 1) == 5 and p2.current_state_name() == &"guard_break" and _count(&"knockdown", 1) == 0,
		"the ender staggers (%s)" % p2.current_state_name())
	_check(moved > 0.5, "the ender pushes back (%.2f m)" % moved)


func _test_neutral_heavy() -> void:
	var d := _new_match()
	_src(d, 0).press(0, B.HEAVY)
	_run(d, 40)
	_check(_count(&"hit", 1) == 1 and _count(&"stagger", 1) == 1 and _count(&"knockdown", 1) == 0,
		"neutral Y close = body blow: heavy stagger, no fall")
	d = _new_match()
	_src(d, 0).stick(0, 1, FWD).press(0, B.HEAVY)
	_check(_run_until(d, func() -> bool: return d.fighters[1].global_position.y > 1.0, 60), "neutral fwd+Y = upper hook launches")


func _test_upper_hook_juggle() -> void:
	var d := _new_match()
	var p2 := d.fighters[1]
	var s := _src(d, 0)
	s.stick(0, 1, FWD).press(0, B.HEAVY)
	_run_until(d, func() -> bool: return _count(&"knockdown", 1) == 1, 40)
	var at := d.tick
	for i in 3:
		s.press_at_tick(at + 4 + i * 9, B.LIGHT)
	var hits_before := _count(&"hit", 1)
	_run(d, 40)
	var juggled := _count(&"hit", 1) - hits_before
	_check(juggled >= 2, "X juggles the launched victim (%d juggle hits)" % juggled)
	_check(p2.current_state_name() == &"knockdown", "juggle keeps them in the knockdown")


func _test_floaty_fall() -> void:
	var d := _new_match()
	var p2 := d.fighters[1]
	_src(d, 0).stick(0, 1, FWD).press(0, B.HEAVY)
	_run_until(d, func() -> bool: return _count(&"knockdown", 1) == 1, 40)
	var up := 0
	var down := 0
	for i in 120:
		var vy := p2._vel.y
		d.step()
		if not p2.is_airborne():
			break
		if p2._vel.y < vy:
			if vy > 0.0:
				up += 1
			else:
				down += 1
	var t := p2.tuning
	_check(t.knockdown_fall_gravity < t.gravity and down > up, "launch falls slower than it rises (up %d f, down %d f)" % [up, down])


func _test_juggle_cap() -> void:
	var d := _new_match()
	var p2 := d.fighters[1]
	p2._enter(Fighter.State.KNOCKDOWN)
	p2._land_frame = -1
	p2.global_position.y = 1.0
	p2._vel = Vector3(0, 1.0, 0)
	_src(d, 0).press(0, B.LIGHT)
	_run_until(d, func() -> bool: return _count(&"hit", 1) == 1, 30)
	_check(p2._vel.y >= p2.tuning.juggle_pop_velocity - 0.5, "a juggle hit pops the victim up (%.2f m/s)" % p2._vel.y)
	var horiz := Vector2(p2._vel.x, p2._vel.z).length()
	_check(horiz < 1.0, "juggle hits barely push (%.2f m/s)" % horiz)


func _test_sweep() -> void:
	var d := _new_match()
	_src(d, 0).stick(0, 1, BACK).press(0, B.HEAVY)
	_check(_run_until(d, func() -> bool: return _count(&"knockdown", 1) == 1, 40), "back+Y sweep trips")


func _test_hold_y_charges_finisher() -> void:
	# Held through: the finisher waits for the hold, becomes the charged one.
	var d := _new_match()
	var p1 := d.fighters[0]
	var m: MoveData = p1.def.move(&"brawler_finisher_1_charged")
	var hold := p1.tuning.charge_hold_frames + m.charge_frame + m.charge_max_frames
	_src(d, 0).press(0, B.LIGHT).press(8, B.HEAVY, hold)
	_run_until(d, func() -> bool: return _count(&"charge_start", 0) == 1, 40)
	_check(_move_id(p1) == &"brawler_finisher_1_charged" and _count(&"hit", 1) == 1,
		"held Y after a jab charges the finisher before it hits")
	_check(_run_until(d, func() -> bool: return _count(&"knockdown", 1) == 1, 120), "full charged finisher blows away")
	# Released early (< 30%): hits like the tapped one, no fall.
	d = _new_match()
	p1 = d.fighters[0]
	_src(d, 0).press(0, B.LIGHT).press(8, B.HEAVY, p1.tuning.charge_hold_frames + m.charge_frame + 2)
	_run_until(d, func() -> bool: return _count(&"hit", 1) == 2, 80)
	var ratio: float = _last(&"charge_release").get("ratio", -1.0)
	_check(ratio >= 0.0 and ratio < m.charge_knockdown_ratio and _count(&"knockdown", 1) == 0 and _count(&"stagger", 1) == 1,
		"charged finisher under 30%% staggers, no fall (%.2f)" % ratio)


func _test_tap_y_doesnt_wait() -> void:
	var d := _new_match()
	var p1 := d.fighters[0]
	_src(d, 0).press(0, B.HEAVY)
	var frames := _ticks_to_first_hit(d, 40)
	var m := p1.def.move(p1.def.heavy)
	_check(frames <= m.startup + 3 and _count(&"charge_start", 0) == 0, "tapped Y hits on its startup (%d f)" % frames)
	# A finisher held past its startup but under charge_hold_frames waits for
	# the release, then fires as tapped.
	d = _new_match()
	p1 = d.fighters[0]
	var fin := p1.def.move(&"brawler_finisher_1")
	var held := p1.tuning.charge_hold_frames - 1
	_check(held > fin.startup, "test setup: the finisher hits before the charge threshold")
	_src(d, 0).press(0, B.HEAVY, held)
	d.step()
	p1._start_move(fin)  # HEAVY held 1 frame when the finisher starts
	var waited := 0
	while _count(&"hit", 1) < 1 and waited < 60:
		d.step()
		waited += 1
	_check(waited > fin.startup and _count(&"charge_start", 0) == 0 and _count(&"hit", 1) == 1,
		"held Y waits for the release, then fires the tapped finisher (%d f > %d)" % [waited, fin.startup])


func _test_smash_knockdown_ratio() -> void:
	for full: bool in [false, true]:
		var d := _new_match()
		var p1 := d.fighters[0]
		var m := p1.def.move(&"brawler_charge_punch")
		var hold := p1.tuning.charge_hold_frames + m.charge_frame + (m.charge_max_frames if full else 2)
		_src(d, 0).press(0, B.LIGHT, hold)
		_run_until(d, func() -> bool: return _count(&"hit", 1) >= 2, 120)
		var fell := _count(&"knockdown", 1) == 1
		if full:
			_check(fell, "full smash blows away")
		else:
			_check(not fell, "smash under 30 pct doesn't knock down (ratio %.2f)" % _last(&"charge_release").get("ratio", -1.0))


func _test_charged_ki_blast() -> void:
	var d := _new_match(8.0)
	var p1 := d.fighters[0]
	p1.ki = p1.ki_max()
	var shot: MoveData = p1.def.move(&"brawler_ki_blast_charged")
	_src(d, 0).press(0, B.HEAVY, p1.tuning.charge_hold_frames + shot.charge_frame + 10)
	_run_until(d, func() -> bool: return _count(&"charge_start", 0) == 1, 30)
	_check(_move_id(p1) == shot.id, "held Y far away = charged ki blast")
	var spent := p1.ki_max() - p1.ki
	_check(is_equal_approx(spent, p1.tuning.ki_blast_cost + p1.tuning.ki_blast_charge_extra_cost),
		"charged blast costs the extra ki (%.1f)" % spent)
	_check(_run_until(d, func() -> bool: return _count(&"knockdown", 1) == 1, 120), "charged ki blast knocks down")
	# Tapped: plain blast.
	d = _new_match(8.0)
	p1 = d.fighters[0]
	_src(d, 0).press(0, B.HEAVY)
	_run(d, 3)
	_check(_move_id(p1) == p1.def.ki_blast, "tapped Y far away = ki blast")


func _test_charged_ki_blast_needs_ki() -> void:
	var d := _new_match(8.0)
	var p1 := d.fighters[0]
	p1.ki = p1.tuning.ki_blast_cost + 1.0
	_src(d, 0).press(0, B.HEAVY, 40)
	_run_until(d, func() -> bool: return _count(&"ki_blast", 0) == 1, 60)
	_check(_count(&"ki_blast", 0) == 1 and _count(&"charge_start", 0) == 0, "without the extra ki a held blast fires plain")


func _test_follow_up_after_finisher() -> void:
	# X Y (stagger) then X on hit: a new string; then fwd+Y launches.
	var d := _new_match()
	var moves := _play(d, [[B.LIGHT, Vector2.ZERO], [B.HEAVY, Vector2.ZERO], [B.LIGHT, Vector2.ZERO],
		[B.HEAVY, FWD]], 120)
	_check(moves.slice(0, 4) == [&"brawler_jab1", &"brawler_finisher_1", &"brawler_jab1", &"brawler_upper_hook"],
		"finisher -> new string -> upper hook (%s)" % [moves])
	_check(_count(&"hit", 1) == 4 and _count(&"knockdown", 1) == 1, "the follow-ups land (%d hits)" % _count(&"hit", 1))


func _test_save_load_hold_gate() -> void:
	var d := _new_match()
	var p1 := d.fighters[0]
	_src(d, 0).press(0, B.LIGHT).press(8, B.HEAVY, 60)
	_run(d, 8 + 10)  # finisher waiting at its gate, HEAVY still held
	var s := d.save_state()
	_check(StateHash.of(d) == StateHash.of_state(s), "save/load: snapshot hash")
	_run(d, 80)
	var want := StateHash.of(d)
	d.load_state(s)
	_check(StateHash.of(d) == StateHash.of_state(s), "save/load round trip at the hold gate")
	_check(p1._move_btn == B.HEAVY, "the starting button is restored")
	_run(d, 80)
	_check(StateHash.of(d) == want, "resim from the hold gate matches")


func _test_determinism() -> void:
	var run := func() -> int:
		var d := _new_match()
		_play(d, _xy(3, true, FWD) + _xy(4, false) + [[B.HEAVY, Vector2.ZERO]], 200)
		return StateHash.of(d)
	_check(run.call() == run.call(), "X/Y juggle sequence is deterministic")


## Review fix: a held blast that can't pay for the charge fires once, quietly,
## even if ki comes back while the button is still held.
func _test_held_blast_fires_once() -> void:
	var d := _new_match(8.0)
	var p1 := d.fighters[0]
	p1.ki = p1.tuning.ki_blast_cost + 1.0
	_src(d, 0).press(0, B.HEAVY, 40)
	_run_until(d, func() -> bool: return _count(&"ki_blast", 0) == 1, 30)
	p1.ki = p1.ki_max()  # e.g. ki gained from the blast's hit
	_run(d, 30)
	_check(_count(&"ki_blast", 0) == 1 and _count(&"charge_start", 0) == 0, "held blast after spawning never re-fires")
	_check(_count(&"not_enough_ki", 0) == 0, "no not_enough_ki spam while held")


## Review fix: the juggle pop doesn't turn a downward slam into a lift.
func _test_juggle_slam_stays_down() -> void:
	var d := _new_match()
	var p1 := d.fighters[0]
	var p2 := d.fighters[1]
	p2._enter(Fighter.State.KNOCKDOWN)
	p2._land_frame = -1
	p2.global_position.y = 1.0
	p2._vel = Vector3(0, 1.0, 0)
	var hb := Hitbox.new()
	hb.source = p1
	hb.attacker = p1
	hb.move = p1.def.move(&"brawler_smash_down")
	hb.forward = Vector3(0, 0, -1)
	hb.right = Vector3(-1, 0, 0)
	hb.hit_id = 99 * 256
	p2.receive_hit(hb)
	_check(p2._vel.y < 0.0, "a slam on an airborne victim still drives down (%.2f m/s)" % p2._vel.y)


## Review fix: a charged finisher released under 30% carries the tapped
## finisher's anti-loop key, so repeating it pushes out.
func _test_weak_charge_keeps_loop_key() -> void:
	var d := _new_match()
	var p1 := d.fighters[0]
	var m: MoveData = p1.def.move(&"brawler_finisher_1_charged")
	_check(m.loop_group_weak == p1.def.move(&"brawler_finisher_1").loop_group, "weak charge key = the tapped finisher's")
	p1._start_move(m)
	p1._charge = 1
	var hbs := p1.get_active_hitboxes()
	while hbs.is_empty() and p1._state_frame < m.total():
		p1._state_frame += 1
		hbs = p1.get_active_hitboxes()
	_check(not hbs.is_empty() and not hbs[0].knockdown_ok and hbs[0].loop_group == m.loop_group_weak,
		"weak charged hit: no knockdown, tapped key (%s)" % (hbs[0].loop_group if not hbs.is_empty() else &"none"))


## Review fix: a held blast in the air hangs while it waits and charges.
func _test_air_blast_hangs_while_held() -> void:
	var d := _new_match(8.0)
	var p1 := d.fighters[0]
	p1.ki = p1.ki_max()
	_src(d, 0).press(0, B.JUMP).press(12, B.HEAVY, 40)
	_run_until(d, func() -> bool: return _count(&"charge_start", 0) == 1, 40)
	var y := p1.global_position.y
	_run(d, 10)
	_check(p1.is_airborne() and absf(p1.global_position.y - y) < 0.01,
		"held air blast hangs while charging (y %.2f -> %.2f)" % [y, p1.global_position.y])
