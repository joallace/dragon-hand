class_name MoveTracks
extends RefCounted
## Keyframed attack animation (presentation only): per move pose, a list of
## keys on the move's own timeline, so the same track fits any MoveData
## using that pose (string hit, rush hit, charge strike) at its frame data.
##
## Timeline `u`: 0..1 = startup, 1..2 = active, 2..3 = recovery, each phase
## scaled to its frame count (MoveTracks.timeline_u). A key is
## [u, pose, ease]: `pose` names KEY_POSES or FighterVisual.POSES, `ease` is
## the curve INTO that key from the previous one (Godot's ease(): >1 slow
## start/fast end, <1 fast start/slow end, <0 in-out). Before the first key
## the first pose holds; after the last, the last.
##
## Authoring rules (anticipation -> snap -> overshoot -> hold -> settle):
## - the strike arrives at u = 1.0 (first active frame) with EASE_IN, so the
##   limb accelerates into contact instead of decelerating into it;
## - "*_hit" poses put the fist/foot on the move's hitbox center (checked by
##   tests/move_tracks_test against data/moves; CONTACTS);
## - the opposite hand comes back to guard, the head stays on the target
##   (counter-rotates the torso twist), the back leg drives the hip.
## Joint conventions as FighterVisual: torso/head +X tilt BACK, limbs +X
## swing forward, torso +Y turns the chest left (right shoulder forward).
## A shoulder raised sideways (|Z| ~ 90) hinges its elbow horizontally
## (hooks); with the arm forward (X ~ 90) the elbow bends upward.

const EASE_IN := 2.6
const EASE_OUT := 0.4
const EASE_IN_OUT := -2.0
const LINEAR := 1.0

const KEY_POSES := {
	# --- jab: lead (left) straight --------------------------------------------
	&"jab_load": {&"torso": Vector3(-4, -6, 0), &"head": Vector3(-2, 10, 0),
		&"sh_l": Vector3(40, 0, -5), &"el_l": Vector3(120, 0, 0),
		&"sh_r": Vector3(45, 0, -10), &"el_r": Vector3(120, 0, 0),
		&"hip_l": Vector3(18, 0, -5), &"kn_l": Vector3(-28, 0, 0),
		&"hip_r": Vector3(-14, 0, 5), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.052, 0.0)},
	&"jab_hit": {&"torso": Vector3(-10, -30, 0), &"head": Vector3(6, 26, 0),
		&"sh_l": Vector3(95, 0, -25), &"el_l": Vector3(5, 0, 0),
		&"sh_r": Vector3(55, 0, -8), &"el_r": Vector3(125, 0, 0),
		&"hip_l": Vector3(24, 0, -5), &"kn_l": Vector3(-26, 0, 0),
		&"hip_r": Vector3(-20, 0, 5), &"kn_r": Vector3(-8, 0, 0), &"root": Vector3(0, -0.05, -0.07)},
	&"jab_over": {&"torso": Vector3(-12, -36, 0), &"head": Vector3(7, 30, 0),
		&"sh_l": Vector3(97, 0, -28), &"el_l": Vector3(0, 0, 0),
		&"sh_r": Vector3(55, 0, -8), &"el_r": Vector3(125, 0, 0),
		&"hip_l": Vector3(24, 0, -5), &"kn_l": Vector3(-26, 0, 0),
		&"hip_r": Vector3(-20, 0, 5), &"kn_r": Vector3(-8, 0, 0), &"root": Vector3(0, -0.05, -0.09)},
	&"jab_back": {&"torso": Vector3(-8, -18, 0), &"head": Vector3(3, 18, 0),
		&"sh_l": Vector3(70, 0, -10), &"el_l": Vector3(95, 0, 0),
		&"sh_r": Vector3(50, 0, -8), &"el_r": Vector3(122, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-24, 0, 0),
		&"hip_r": Vector3(-16, 0, 5), &"kn_r": Vector3(-12, 0, 0), &"root": Vector3(0, -0.05, -0.04)},
	# --- jab2: rear (right) cross, hip and back heel turn through -------------
	&"jab2_load": {&"torso": Vector3(-4, -12, 0), &"head": Vector3(-2, 12, 0),
		&"sh_r": Vector3(35, 0, 10), &"el_r": Vector3(125, 0, 0),
		&"sh_l": Vector3(60, 0, -15), &"el_l": Vector3(110, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-14, 0, 5), &"kn_r": Vector3(-22, 0, 0), &"root": Vector3(0, -0.056, 0.02)},
	&"jab2_hit": {&"torso": Vector3(-10, 32, 0), &"head": Vector3(6, -28, 0),
		&"sh_r": Vector3(97, 0, 28), &"el_r": Vector3(5, 0, 0),
		&"sh_l": Vector3(55, 0, 8), &"el_l": Vector3(125, 0, 0),
		&"hip_l": Vector3(28, 0, -5), &"kn_l": Vector3(-32, 0, 0),
		&"hip_r": Vector3(-14, 20, 5), &"kn_r": Vector3(-18, 0, 0), &"root": Vector3(0, -0.05, -0.05)},
	&"jab2_over": {&"torso": Vector3(-12, 40, 0), &"head": Vector3(7, -34, 0),
		&"sh_r": Vector3(99, 0, 32), &"el_r": Vector3(0, 0, 0),
		&"sh_l": Vector3(55, 0, 8), &"el_l": Vector3(125, 0, 0),
		&"hip_l": Vector3(28, 0, -5), &"kn_l": Vector3(-32, 0, 0),
		&"hip_r": Vector3(-14, 25, 5), &"kn_r": Vector3(-18, 0, 0), &"root": Vector3(0, -0.05, -0.07)},
	&"jab2_back": {&"torso": Vector3(-8, 15, 0), &"head": Vector3(3, -12, 0),
		&"sh_r": Vector3(70, 0, 10), &"el_r": Vector3(95, 0, 0),
		&"sh_l": Vector3(50, 0, 0), &"el_l": Vector3(122, 0, 0),
		&"hip_l": Vector3(22, 0, -5), &"kn_l": Vector3(-26, 0, 0),
		&"hip_r": Vector3(-14, 10, 5), &"kn_r": Vector3(-14, 0, 0), &"root": Vector3(0, -0.05, -0.03)},
	# --- hook: right, elbow out level, whole body turns through ---------------
	&"hook_load": {&"torso": Vector3(-6, -25, 0), &"head": Vector3(0, 20, 0),
		&"sh_r": Vector3(0, -20, 80), &"el_r": Vector3(100, 0, 0),
		&"sh_l": Vector3(55, 0, 0), &"el_l": Vector3(120, 0, 0),
		&"hip_l": Vector3(22, 0, -5), &"kn_l": Vector3(-34, 0, 0),
		&"hip_r": Vector3(-12, 0, 5), &"kn_r": Vector3(-28, 0, 0), &"root": Vector3(0, -0.062, 0.02)},
	&"hook_hit": {&"torso": Vector3(-8, 45, 0), &"head": Vector3(6, -36, 0),
		&"sh_r": Vector3(6, 22, 85), &"el_r": Vector3(60, 0, 0),
		&"sh_l": Vector3(55, 0, 8), &"el_l": Vector3(125, 0, 0),
		&"hip_l": Vector3(26, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-12, 25, 5), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.05, -0.06)},
	&"hook_over": {&"torso": Vector3(-9, 56, 0), &"head": Vector3(7, -42, 0),
		&"sh_r": Vector3(6, 28, 85), &"el_r": Vector3(56, 0, 0),
		&"sh_l": Vector3(55, 0, 8), &"el_l": Vector3(125, 0, 0),
		&"hip_l": Vector3(26, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-12, 30, 5), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.05, -0.07)},
	&"hook_back": {&"torso": Vector3(-8, 18, 0), &"head": Vector3(3, -12, 0),
		&"sh_r": Vector3(50, 0, 20), &"el_r": Vector3(110, 0, 0),
		&"sh_l": Vector3(50, 0, 0), &"el_l": Vector3(122, 0, 0),
		&"hip_l": Vector3(22, 0, -5), &"kn_l": Vector3(-26, 0, 0),
		&"hip_r": Vector3(-14, 10, 5), &"kn_r": Vector3(-14, 0, 0), &"root": Vector3(0, -0.05, -0.03)},
	# --- kick: right front kick, chambered knee, leaning back for balance -----
	&"kick_load": {&"torso": Vector3(10, -8, 0), &"head": Vector3(-8, 8, 0),
		&"sh_l": Vector3(35, 0, -30), &"el_l": Vector3(80, 0, 0),
		&"sh_r": Vector3(10, 0, 25), &"el_r": Vector3(70, 0, 0),
		&"hip_r": Vector3(100, 0, 0), &"kn_r": Vector3(-120, 0, 0),
		&"hip_l": Vector3(-4, 0, -4), &"kn_l": Vector3(-18, 0, 0), &"root": Vector3(0, -0.03, 0.0)},
	&"kick_hit": {&"torso": Vector3(14, -8, 0), &"head": Vector3(-12, 8, 0),
		&"sh_l": Vector3(35, 0, -30), &"el_l": Vector3(70, 0, 0),
		&"sh_r": Vector3(-15, 0, 25), &"el_r": Vector3(60, 0, 0),
		&"hip_r": Vector3(93, 0, -1), &"kn_r": Vector3(-5, 0, 0),
		&"hip_l": Vector3(-6, 0, -4), &"kn_l": Vector3(-14, 0, 0), &"root": Vector3(0, -0.02, -0.05)},
	&"kick_over": {&"torso": Vector3(18, -10, 0), &"head": Vector3(-15, 10, 0),
		&"sh_l": Vector3(40, 0, -35), &"el_l": Vector3(65, 0, 0),
		&"sh_r": Vector3(-20, 0, 30), &"el_r": Vector3(55, 0, 0),
		&"hip_r": Vector3(97, 0, -1), &"kn_r": Vector3(0, 0, 0),
		&"hip_l": Vector3(-6, 0, -4), &"kn_l": Vector3(-14, 0, 0), &"root": Vector3(0, -0.02, -0.06)},
	&"kick_back": {&"torso": Vector3(8, -8, 0), &"head": Vector3(-6, 8, 0),
		&"sh_l": Vector3(40, 0, -20), &"el_l": Vector3(95, 0, 0),
		&"sh_r": Vector3(25, 0, 15), &"el_r": Vector3(100, 0, 0),
		&"hip_r": Vector3(85, 0, 0), &"kn_r": Vector3(-105, 0, 0),
		&"hip_l": Vector3(-4, 0, -4), &"kn_l": Vector3(-18, 0, 0), &"root": Vector3(0, -0.03, -0.02)},
	# --- heavy: rear power punch to the body, lead hand measures, deep lunge ---
	&"heavy_load": {&"torso": Vector3(-2, -40, 0), &"head": Vector3(0, 30, 0),
		&"sh_r": Vector3(-25, 0, 25), &"el_r": Vector3(120, 0, 0),
		&"sh_l": Vector3(70, 0, -10), &"el_l": Vector3(60, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-35, 0, 0),
		&"hip_r": Vector3(-5, 0, 5), &"kn_r": Vector3(-40, 0, 0), &"root": Vector3(0, -0.062, 0.06)},
	&"heavy_hit": {&"torso": Vector3(-16, 40, 0), &"head": Vector3(10, -32, 0),
		&"sh_r": Vector3(41, 0, 42), &"el_r": Vector3(64, 0, 0),
		&"sh_l": Vector3(30, 0, -15), &"el_l": Vector3(115, 0, 0),
		&"hip_l": Vector3(48, 0, -5), &"kn_l": Vector3(-55, 0, 0),
		&"hip_r": Vector3(-35, 20, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.13, -0.08)},
	&"heavy_over": {&"torso": Vector3(-20, 50, 0), &"head": Vector3(12, -38, 0),
		&"sh_r": Vector3(44, 0, 40), &"el_r": Vector3(58, 0, 0),
		&"sh_l": Vector3(25, 0, -15), &"el_l": Vector3(118, 0, 0),
		&"hip_l": Vector3(50, 0, -5), &"kn_l": Vector3(-58, 0, 0),
		&"hip_r": Vector3(-37, 24, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.14, -0.1)},
	&"heavy_back": {&"torso": Vector3(-8, 15, 0), &"head": Vector3(4, -12, 0),
		&"sh_r": Vector3(45, 0, 20), &"el_r": Vector3(100, 0, 0),
		&"sh_l": Vector3(50, 0, -10), &"el_l": Vector3(115, 0, 0),
		&"hip_l": Vector3(30, 0, -5), &"kn_l": Vector3(-40, 0, 0),
		&"hip_r": Vector3(-20, 8, 5), &"kn_r": Vector3(-15, 0, 0), &"root": Vector3(0, -0.068, -0.03)},
}

## Move pose -> keys [u, pose, ease].
const TRACKS := {
	&"jab": [
		[0.0, &"jab_load", LINEAR], [0.5, &"jab_load", LINEAR],
		[1.0, &"jab_hit", EASE_IN], [1.4, &"jab_over", EASE_OUT], [2.0, &"jab_hit", EASE_IN_OUT],
		[2.35, &"jab_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"jab2": [
		[0.0, &"jab2_load", LINEAR], [0.5, &"jab2_load", LINEAR],
		[1.0, &"jab2_hit", EASE_IN], [1.4, &"jab2_over", EASE_OUT], [2.0, &"jab2_hit", EASE_IN_OUT],
		[2.35, &"jab2_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"hook": [
		[0.0, &"hook_load", LINEAR], [0.55, &"hook_load", LINEAR],
		[1.0, &"hook_hit", EASE_IN], [1.4, &"hook_over", EASE_OUT], [2.0, &"hook_over", LINEAR],
		[2.4, &"hook_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"kick": [
		[0.0, &"kick_load", LINEAR], [0.6, &"kick_load", LINEAR],
		[1.0, &"kick_hit", EASE_IN], [1.35, &"kick_over", EASE_OUT], [2.0, &"kick_hit", EASE_IN_OUT],
		[2.35, &"kick_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"heavy": [
		[0.0, &"heavy_load", LINEAR], [0.7, &"heavy_load", LINEAR],
		[1.0, &"heavy_hit", EASE_IN], [1.3, &"heavy_over", EASE_OUT], [2.0, &"heavy_hit", EASE_IN_OUT],
		[2.3, &"heavy_hit", LINEAR], [2.6, &"heavy_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
}

## Contact poses -> [striking joint, the move whose hitbox it must reach].
## The fist sits FIST_OFFSET below its elbow joint, the foot FOOT_OFFSET
## below its knee joint (the rig's segment lengths).
const CONTACTS := {
	&"jab_hit": [&"el_l", &"brawler_jab1"],
	&"jab2_hit": [&"el_r", &"brawler_jab2"],
	&"hook_hit": [&"el_r", &"brawler_hook"],
	&"kick_hit": [&"kn_r", &"brawler_kick"],
	&"heavy_hit": [&"el_r", &"brawler_finisher_1"],
}
const FIST_OFFSET := Vector3(0, -0.30, 0)
const FOOT_OFFSET := Vector3(0, -0.46, -0.06)


static func has_track(pose: StringName) -> bool:
	return TRACKS.has(pose)


## Timeline position of `frame` (may be fractional) in `m`: 0..1 startup,
## 1..2 active, 2..3 recovery. Phases with no frames are skipped.
static func timeline_u(m: MoveData, frame: float) -> float:
	var phases := [m.startup, m.active, m.recovery]
	var u := 0.0
	var f := frame
	for n: int in phases:
		if n <= 0:
			u += 1.0
			continue
		if f < n:
			return u + maxf(f, 0.0) / n
		f -= n
		u += 1.0
	return 3.0


static func pose_of(id: StringName) -> Dictionary:
	return KEY_POSES[id] if KEY_POSES.has(id) else FighterVisual.POSES[id]


## The pose dictionary (every FighterVisual joint + root) of track `pose`
## at timeline `u`; missing joints come from `base`.
static func sample(pose: StringName, u: float, base: Dictionary) -> Dictionary:
	var keys: Array = TRACKS[pose]
	var i := 0
	while i < keys.size() and float(keys[i][0]) <= u:
		i += 1
	if i == 0:
		return _full(pose_of(keys[0][1]), base)
	if i >= keys.size():
		return _full(pose_of(keys[-1][1]), base)
	var a: Array = keys[i - 1]
	var b: Array = keys[i]
	var s := (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
	var k := ease(clampf(s, 0.0, 1.0), float(b[2]))
	var pa := pose_of(a[1])
	var pb := pose_of(b[1])
	var out := {}
	for j: StringName in base:
		out[j] = (pa.get(j, base[j]) as Vector3).lerp(pb.get(j, base[j]), k)
	return out


static func _full(p: Dictionary, base: Dictionary) -> Dictionary:
	var out := {}
	for j: StringName in base:
		out[j] = p.get(j, base[j])
	return out
