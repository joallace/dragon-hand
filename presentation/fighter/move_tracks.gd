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
	# --- finisher: lunging overhand right (string ender, counter, rush finish) ---
	&"finisher_load": {&"torso": Vector3(-10, -45, 0), &"head": Vector3(0, 35, 0),
		&"sh_l": Vector3(60, 0, -15), &"el_l": Vector3(80, 0, 0), &"sh_r": Vector3(-30, 0, 20),
		&"el_r": Vector3(115, 0, 0), &"hip_l": Vector3(30, 0, -5), &"kn_l": Vector3(-50, 0, 0),
		&"hip_r": Vector3(-5, 0, 5), &"kn_r": Vector3(-45, 0, 0), &"root": Vector3(0, -0.088, 0.06)},
	&"finisher_hit": {&"torso": Vector3(-14, 38, 0), &"head": Vector3(10, -30, 0),
		&"sh_l": Vector3(25, 0, -20), &"el_l": Vector3(115, 0, 0), &"sh_r": Vector3(92, 0, 24),
		&"el_r": Vector3(5, 0, 0), &"hip_l": Vector3(50, 0, -5), &"kn_l": Vector3(-60, 0, 0),
		&"hip_r": Vector3(-40, 20, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.176, -0.04)},
	&"finisher_over": {&"torso": Vector3(-18, 48, 0), &"head": Vector3(12, -38, 0),
		&"sh_l": Vector3(25, 0, -20), &"el_l": Vector3(115, 0, 0), &"sh_r": Vector3(92, 0, 24),
		&"el_r": Vector3(5, 0, 0), &"hip_l": Vector3(50, 0, -5), &"kn_l": Vector3(-60, 0, 0),
		&"hip_r": Vector3(-40, 20, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.176, -0.06)},
	&"finisher_back": {&"torso": Vector3(-10, 15, 0), &"head": Vector3(5, -10, 0),
		&"sh_l": Vector3(45, 0, -10), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(50, 0, 15),
		&"el_r": Vector3(100, 0, 0), &"hip_l": Vector3(30, 0, -5), &"kn_l": Vector3(-40, 0, 0),
		&"hip_r": Vector3(-20, 8, 5), &"kn_r": Vector3(-15, 0, 0), &"root": Vector3(0, -0.068, -0.05)},
	# --- kick_mid: roundhouse; leg raised sideways so the knee hinges level ---
	&"kick_mid_load": {&"torso": Vector3(10, -15, -12), &"head": Vector3(-8, 12, 10),
		&"sh_l": Vector3(50, 0, -20), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(20, 0, 30),
		&"el_r": Vector3(90, 0, 0), &"hip_l": Vector3(-4, -25, -4), &"kn_l": Vector3(-18, 0, 0),
		&"hip_r": Vector3(0, 30, 85), &"kn_r": Vector3(-120, 0, 0), &"root": Vector3(0, -0.03, 0.0)},
	&"kick_mid_hit": {&"torso": Vector3(18, 30, -20), &"head": Vector3(-14, -25, 15),
		&"sh_l": Vector3(60, 0, -15), &"el_l": Vector3(120, 0, 0), &"sh_r": Vector3(-25, 0, 35),
		&"el_r": Vector3(40, 0, 0), &"hip_l": Vector3(-6, -35, -4), &"kn_l": Vector3(-12, 0, 0),
		&"hip_r": Vector3(-34, 106, 90), &"kn_r": Vector3(-43, 0, 0), &"root": Vector3(0, -0.02, -0.04)},
	&"kick_mid_over": {&"torso": Vector3(20, 40, -22), &"head": Vector3(-15, -32, 16),
		&"sh_l": Vector3(60, 0, -15), &"el_l": Vector3(120, 0, 0), &"sh_r": Vector3(-25, 0, 35),
		&"el_r": Vector3(40, 0, 0), &"hip_l": Vector3(-6, -35, -4), &"kn_l": Vector3(-12, 0, 0),
		&"hip_r": Vector3(-34, 106, 90), &"kn_r": Vector3(-43, 0, 0), &"root": Vector3(0, -0.02, -0.04)},
	&"kick_mid_back": {&"torso": Vector3(10, 10, -10), &"head": Vector3(-6, -5, 8),
		&"sh_l": Vector3(50, 0, -15), &"el_l": Vector3(115, 0, 0), &"sh_r": Vector3(25, 0, 20),
		&"el_r": Vector3(100, 0, 0), &"hip_l": Vector3(-4, -15, -4), &"kn_l": Vector3(-18, 0, 0),
		&"hip_r": Vector3(0, 40, 80), &"kn_r": Vector3(-115, 0, 0), &"root": Vector3(0, -0.03, -0.02)},
	# --- charge_kick: spinning back kick (the whole body turns on `spin`) ---
	&"charge_kick_load": {&"spin": Vector3(0, -100, 0), &"torso": Vector3(-15, 0, 0),
		&"head": Vector3(5, 70, 0), &"sh_l": Vector3(40, 0, -30), &"el_l": Vector3(100, 0, 0),
		&"sh_r": Vector3(40, 0, 30), &"el_r": Vector3(100, 0, 0), &"hip_l": Vector3(10, 0, -4),
		&"kn_l": Vector3(-30, 0, 0), &"hip_r": Vector3(70, 0, 0), &"kn_r": Vector3(-125, 0, 0),
		&"root": Vector3(0, -0.037, 0.0)},
	&"charge_kick_hit": {&"spin": Vector3(0, -180, 0), &"torso": Vector3(-35, 0, 0),
		&"head": Vector3(20, 60, 0), &"sh_l": Vector3(20, 0, -30), &"el_l": Vector3(90, 0, 0),
		&"sh_r": Vector3(40, 0, 40), &"el_r": Vector3(90, 0, 0), &"hip_l": Vector3(-10, 0, -4),
		&"kn_l": Vector3(-15, 0, 0), &"hip_r": Vector3(-106, 0, -13), &"kn_r": Vector3(-5, 0, 0),
		&"root": Vector3(0, -0.05, 0.0)},
	&"charge_kick_over": {&"spin": Vector3(0, -180, 0), &"torso": Vector3(-40, 0, 0),
		&"head": Vector3(20, 60, 0), &"sh_l": Vector3(20, 0, -30), &"el_l": Vector3(90, 0, 0),
		&"sh_r": Vector3(40, 0, 40), &"el_r": Vector3(90, 0, 0), &"hip_l": Vector3(-10, 0, -4),
		&"kn_l": Vector3(-15, 0, 0), &"hip_r": Vector3(-106, 0, -13), &"kn_r": Vector3(-5, 0, 0),
		&"root": Vector3(0, -0.05, 0.0)},
	&"charge_kick_back": {&"spin": Vector3(0, -90, 0), &"torso": Vector3(-10, 0, 0),
		&"head": Vector3(5, 50, 0), &"sh_l": Vector3(40, 0, -20), &"el_l": Vector3(105, 0, 0),
		&"sh_r": Vector3(40, 0, 20), &"el_r": Vector3(105, 0, 0), &"hip_l": Vector3(5, 0, -4),
		&"kn_l": Vector3(-25, 0, 0), &"hip_r": Vector3(60, 0, 0), &"kn_r": Vector3(-110, 0, 0),
		&"root": Vector3(0, -0.032, 0.0)},
	# --- smash_right: wide back-fist out to the right ---
	&"smash_right_load": {&"torso": Vector3(-6, 40, 0), &"head": Vector3(4, -30, 0),
		&"sh_l": Vector3(55, 0, 0), &"el_l": Vector3(115, 0, 0), &"sh_r": Vector3(80, 0, -40),
		&"el_r": Vector3(125, 0, 0), &"kn_l": Vector3(-30, 0, 0), &"kn_r": Vector3(-30, 0, 0),
		&"root": Vector3(0, -0.05, 0.0)},
	&"smash_right_hit": {&"torso": Vector3(-10, 12, 0), &"head": Vector3(6, -8, 0),
		&"sh_l": Vector3(40, 0, -20), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(85, 0, 11),
		&"el_r": Vector3(10, 0, 0), &"hip_l": Vector3(-10, 0, -5), &"kn_l": Vector3(-10, 0, 0),
		&"hip_r": Vector3(20, 0, 15), &"kn_r": Vector3(-25, 0, 0), &"root": Vector3(0, -0.05, -0.03)},
	&"smash_right_over": {&"torso": Vector3(-11, -6, 0), &"head": Vector3(7, 6, 0),
		&"sh_l": Vector3(40, 0, -20), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(85, 0, 55),
		&"el_r": Vector3(15, 0, 0), &"hip_l": Vector3(-10, 0, -5), &"kn_l": Vector3(-10, 0, 0),
		&"hip_r": Vector3(20, 0, 15), &"kn_r": Vector3(-25, 0, 0), &"root": Vector3(0, -0.05, -0.03)},
	&"smash_right_back": {&"torso": Vector3(-6, -15, 0), &"head": Vector3(4, 12, 0),
		&"sh_l": Vector3(45, 0, -10), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(55, 0, 20),
		&"el_r": Vector3(100, 0, 0), &"hip_l": Vector3(-8, 0, -5), &"kn_l": Vector3(-15, 0, 0),
		&"hip_r": Vector3(10, 0, 10), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.033, -0.02)},
	# --- smash_left: mirror of smash_right ---
	&"smash_left_load": {&"torso": Vector3(-6, -40, 0), &"head": Vector3(4, 30, 0),
		&"sh_l": Vector3(80, 0, 40), &"el_l": Vector3(125, 0, 0), &"sh_r": Vector3(55, 0, 0),
		&"el_r": Vector3(115, 0, 0), &"kn_l": Vector3(-30, 0, 0), &"kn_r": Vector3(-30, 0, 0),
		&"root": Vector3(0, -0.05, 0.0)},
	&"smash_left_hit": {&"torso": Vector3(-10, -12, 0), &"head": Vector3(6, 8, 0),
		&"sh_l": Vector3(85, 0, -11), &"el_l": Vector3(10, 0, 0), &"sh_r": Vector3(40, 0, 20),
		&"el_r": Vector3(110, 0, 0), &"hip_l": Vector3(20, 0, -15), &"kn_l": Vector3(-25, 0, 0),
		&"hip_r": Vector3(-10, 0, 5), &"kn_r": Vector3(-10, 0, 0), &"root": Vector3(0, -0.05, -0.03)},
	&"smash_left_over": {&"torso": Vector3(-11, 6, 0), &"head": Vector3(7, -6, 0),
		&"sh_l": Vector3(85, 0, -55), &"el_l": Vector3(15, 0, 0), &"sh_r": Vector3(40, 0, 20),
		&"el_r": Vector3(110, 0, 0), &"hip_l": Vector3(20, 0, -15), &"kn_l": Vector3(-25, 0, 0),
		&"hip_r": Vector3(-10, 0, 5), &"kn_r": Vector3(-10, 0, 0), &"root": Vector3(0, -0.05, -0.03)},
	&"smash_left_back": {&"torso": Vector3(-6, 15, 0), &"head": Vector3(4, -12, 0),
		&"sh_l": Vector3(55, 0, -20), &"el_l": Vector3(100, 0, 0), &"sh_r": Vector3(45, 0, 10),
		&"el_r": Vector3(110, 0, 0), &"hip_l": Vector3(10, 0, -10), &"kn_l": Vector3(-20, 0, 0),
		&"hip_r": Vector3(-8, 0, 5), &"kn_r": Vector3(-15, 0, 0), &"root": Vector3(0, -0.033, -0.02)},
	# --- hammer: two-fisted overhead, rising onto the toes first ---
	&"hammer_load": {&"torso": Vector3(18, 0, 0), &"head": Vector3(-12, 0, 0), &"sh_l": Vector3(185, 0, 10),
		&"el_l": Vector3(30, 0, 0), &"sh_r": Vector3(185, 0, -10), &"el_r": Vector3(30, 0, 0),
		&"hip_l": Vector3(5, 0, -5), &"kn_l": Vector3(-8, 0, 0), &"hip_r": Vector3(-5, 0, 5),
		&"kn_r": Vector3(-8, 0, 0), &"root": Vector3(0, -0.039, 0.03)},
	&"hammer_hit": {&"torso": Vector3(-40, 0, 0), &"head": Vector3(30, 0, 0), &"sh_l": Vector3(90, 0, 25),
		&"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(90, 0, -25), &"el_r": Vector3(60, 0, 0),
		&"hip_l": Vector3(45, 0, -5), &"kn_l": Vector3(-50, 0, 0), &"hip_r": Vector3(-25, 0, 5),
		&"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.12, -0.06)},
	&"hammer_over": {&"torso": Vector3(-46, 0, 0), &"head": Vector3(30, 0, 0), &"sh_l": Vector3(45, 0, 15),
		&"el_l": Vector3(25, 0, 0), &"sh_r": Vector3(45, 0, -15), &"el_r": Vector3(25, 0, 0),
		&"hip_l": Vector3(45, 0, -5), &"kn_l": Vector3(-50, 0, 0), &"hip_r": Vector3(-25, 0, 5),
		&"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.111, -0.07)},
	&"hammer_back": {&"torso": Vector3(-15, 0, 0), &"head": Vector3(10, 0, 0), &"sh_l": Vector3(50, 0, -10),
		&"el_l": Vector3(100, 0, 0), &"sh_r": Vector3(50, 0, 10), &"el_r": Vector3(100, 0, 0),
		&"hip_l": Vector3(30, 0, -5), &"kn_l": Vector3(-35, 0, 0), &"hip_r": Vector3(-15, 0, 5),
		&"kn_r": Vector3(-18, 0, 0), &"root": Vector3(0, -0.052, -0.03)},
	# --- uppercut: from a deep crouch, rising through it ---
	&"uppercut_load": {&"torso": Vector3(-22, -30, 0), &"head": Vector3(15, 25, 0),
		&"sh_l": Vector3(60, 0, -10), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(5, 0, 10),
		&"el_r": Vector3(115, 0, 0), &"hip_l": Vector3(40, 0, -5), &"kn_l": Vector3(-60, 0, 0),
		&"hip_r": Vector3(15, 0, 5), &"kn_r": Vector3(-55, 0, 0), &"root": Vector3(0, -0.067, 0.02)},
	&"uppercut_hit": {&"torso": Vector3(-4, 20, 0), &"head": Vector3(2, -18, 0), &"sh_l": Vector3(30, 0, -25),
		&"el_l": Vector3(100, 0, 0), &"sh_r": Vector3(93, 0, 6), &"el_r": Vector3(33, 0, 0),
		&"hip_l": Vector3(10, 0, -5), &"kn_l": Vector3(-10, 0, 0), &"hip_r": Vector3(-15, 15, 5),
		&"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.045, -0.1)},
	&"uppercut_over": {&"torso": Vector3(2, 28, 0), &"head": Vector3(-2, -24, 0),
		&"sh_l": Vector3(30, 0, -25), &"el_l": Vector3(100, 0, 0), &"sh_r": Vector3(150, 0, 10),
		&"el_r": Vector3(50, 0, 0), &"hip_l": Vector3(10, 0, -5), &"kn_l": Vector3(-10, 0, 0),
		&"hip_r": Vector3(-15, 15, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.045, -0.1)},
	&"uppercut_back": {&"torso": Vector3(-4, 10, 0), &"head": Vector3(4, -8, 0), &"sh_l": Vector3(45, 0, -10),
		&"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(80, 0, 15), &"el_r": Vector3(110, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-25, 0, 0), &"hip_r": Vector3(-12, 5, 5),
		&"kn_r": Vector3(-15, 0, 0), &"root": Vector3(0, -0.04, -0.03)},
	# --- kick_low: crouching sweep, lead hand down for balance ---
	&"kick_low_load": {&"torso": Vector3(-35, 15, 0), &"head": Vector3(30, -10, 0),
		&"sh_l": Vector3(60, 0, -20), &"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(50, 0, 20),
		&"el_r": Vector3(90, 0, 0), &"hip_l": Vector3(100, 0, -5), &"kn_l": Vector3(-130, 0, 0),
		&"hip_r": Vector3(95, 0, 10), &"kn_r": Vector3(-130, 0, 0), &"root": Vector3(0, -0.544, 0.0)},
	&"kick_low_hit": {&"torso": Vector3(-30, -20, 0), &"head": Vector3(25, 15, 0),
		&"sh_l": Vector3(70, 0, -25), &"el_l": Vector3(10, 0, 0), &"sh_r": Vector3(40, 0, 35),
		&"el_r": Vector3(80, 0, 0), &"hip_l": Vector3(100, 0, -5), &"kn_l": Vector3(-135, 0, 0),
		&"hip_r": Vector3(85, 0, -1), &"kn_r": Vector3(0, 0, 0), &"root": Vector3(0, -0.584, -0.03)},
	&"kick_low_over": {&"torso": Vector3(-30, -28, 0), &"head": Vector3(25, 20, 0),
		&"sh_l": Vector3(70, 0, -25), &"el_l": Vector3(10, 0, 0), &"sh_r": Vector3(40, 0, 35),
		&"el_r": Vector3(80, 0, 0), &"hip_l": Vector3(100, 0, -5), &"kn_l": Vector3(-135, 0, 0),
		&"hip_r": Vector3(85, 0, -1), &"kn_r": Vector3(0, 0, 0), &"root": Vector3(0, -0.584, -0.03)},
	&"kick_low_back": {&"torso": Vector3(-25, 0, 0), &"head": Vector3(20, 0, 0), &"sh_l": Vector3(60, 0, -20),
		&"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(50, 0, 20), &"el_r": Vector3(90, 0, 0),
		&"hip_l": Vector3(100, 0, -5), &"kn_l": Vector3(-130, 0, 0), &"hip_r": Vector3(95, 0, 10),
		&"kn_r": Vector3(-130, 0, 0), &"root": Vector3(0, -0.544, 0.0)},
	# --- dash_punch: running lunge punch (also the rush) ---
	&"dash_punch_load": {&"torso": Vector3(-25, -25, 0), &"head": Vector3(18, 20, 0),
		&"sh_l": Vector3(60, 0, -10), &"el_l": Vector3(100, 0, 0), &"sh_r": Vector3(-30, 0, 20),
		&"el_r": Vector3(100, 0, 0), &"hip_l": Vector3(45, 0, -5), &"kn_l": Vector3(-60, 0, 0),
		&"hip_r": Vector3(-25, 0, 5), &"kn_r": Vector3(-40, 0, 0), &"root": Vector3(0, -0.17, 0.0)},
	&"dash_punch_hit": {&"torso": Vector3(-22, 30, 0), &"head": Vector3(16, -26, 0),
		&"sh_l": Vector3(-20, 0, -20), &"el_l": Vector3(80, 0, 0), &"sh_r": Vector3(113, 0, 15),
		&"el_r": Vector3(5, 0, 0), &"hip_l": Vector3(50, 0, -5), &"kn_l": Vector3(-55, 0, 0),
		&"hip_r": Vector3(-45, 15, 5), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.221, -0.02)},
	&"dash_punch_over": {&"torso": Vector3(-25, 37, 0), &"head": Vector3(18, -31, 0),
		&"sh_l": Vector3(-20, 0, -20), &"el_l": Vector3(80, 0, 0), &"sh_r": Vector3(113, 0, 15),
		&"el_r": Vector3(5, 0, 0), &"hip_l": Vector3(50, 0, -5), &"kn_l": Vector3(-55, 0, 0),
		&"hip_r": Vector3(-45, 15, 5), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.221, -0.02)},
	&"dash_punch_back": {&"torso": Vector3(-15, 10, 0), &"head": Vector3(10, -8, 0),
		&"sh_l": Vector3(40, 0, -10), &"el_l": Vector3(105, 0, 0), &"sh_r": Vector3(55, 0, 15),
		&"el_r": Vector3(100, 0, 0), &"hip_l": Vector3(30, 0, -5), &"kn_l": Vector3(-35, 0, 0),
		&"hip_r": Vector3(-20, 5, 5), &"kn_r": Vector3(-20, 0, 0), &"root": Vector3(0, -0.08, -0.05)},
	# --- belly_bump: gut thrust, arms flung back (Bulk) ---
	&"belly_bump_load": {&"torso": Vector3(-25, 0, 0), &"head": Vector3(20, 0, 0),
		&"sh_l": Vector3(20, 0, -35), &"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(20, 0, 35),
		&"el_r": Vector3(60, 0, 0), &"hip_l": Vector3(25, 0, -5), &"kn_l": Vector3(-40, 0, 0),
		&"hip_r": Vector3(10, 0, 5), &"kn_r": Vector3(-40, 0, 0), &"root": Vector3(0, -0.039, 0.04)},
	&"belly_bump_hit": {&"torso": Vector3(25, 0, 0), &"head": Vector3(-15, 0, 0),
		&"sh_l": Vector3(-30, 0, -50), &"el_l": Vector3(20, 0, 0), &"sh_r": Vector3(-30, 0, 50),
		&"el_r": Vector3(20, 0, 0), &"hip_l": Vector3(35, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-25, 0, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.076, -0.12)},
	&"belly_bump_over": {&"torso": Vector3(30, 0, 0), &"head": Vector3(-15, 0, 0),
		&"sh_l": Vector3(-30, 0, -50), &"el_l": Vector3(20, 0, 0), &"sh_r": Vector3(-30, 0, 50),
		&"el_r": Vector3(20, 0, 0), &"hip_l": Vector3(35, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-25, 0, 5), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, -0.076, -0.14)},
	&"belly_bump_back": {&"torso": Vector3(5, 0, 0), &"head": Vector3(0, 0, 0), &"sh_l": Vector3(30, 0, -30),
		&"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(30, 0, 30), &"el_r": Vector3(60, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-25, 0, 0), &"hip_r": Vector3(-10, 0, 5),
		&"kn_r": Vector3(-10, 0, 0), &"root": Vector3(0, -0.036, -0.04)},
	# --- throw: two-handed grab ---
	&"throw_load": {&"torso": Vector3(-8, 0, 0), &"head": Vector3(5, 0, 0), &"sh_l": Vector3(50, 0, -45),
		&"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(50, 0, 45), &"el_r": Vector3(60, 0, 0),
		&"kn_l": Vector3(-30, 0, 0), &"kn_r": Vector3(-30, 0, 0), &"root": Vector3(0, -0.05, 0.0)},
	&"throw_hit": {&"torso": Vector3(-20, 0, 0), &"head": Vector3(14, 0, 0), &"sh_l": Vector3(66, 0, 28),
		&"el_l": Vector3(14, 0, 0), &"sh_r": Vector3(66, 0, -28), &"el_r": Vector3(14, 0, 0),
		&"hip_l": Vector3(35, 0, -5), &"kn_l": Vector3(-40, 0, 0), &"hip_r": Vector3(-25, 0, 5),
		&"kn_r": Vector3(-10, 0, 0), &"root": Vector3(0, -0.07, -0.06)},
	&"throw_back": {&"torso": Vector3(-5, 0, 0), &"head": Vector3(4, 0, 0), &"sh_l": Vector3(40, 0, -15),
		&"el_l": Vector3(90, 0, 0), &"sh_r": Vector3(40, 0, 15), &"el_r": Vector3(90, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-25, 0, 0), &"hip_r": Vector3(-12, 0, 5),
		&"kn_r": Vector3(-12, 0, 0), &"root": Vector3(0, -0.05, -0.02)},
	# --- jump_kick: airborne, tucked, one leg shot down-forward ---
	&"jump_kick_load": {&"torso": Vector3(5, 0, 0), &"head": Vector3(-4, 0, 0), &"sh_l": Vector3(40, 0, -30),
		&"el_l": Vector3(90, 0, 0), &"sh_r": Vector3(40, 0, 30), &"el_r": Vector3(90, 0, 0),
		&"hip_l": Vector3(90, 0, -5), &"kn_l": Vector3(-120, 0, 0), &"hip_r": Vector3(95, 0, 5),
		&"kn_r": Vector3(-125, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	&"jump_kick_hit": {&"torso": Vector3(15, 0, 0), &"head": Vector3(-10, 0, 0), &"sh_l": Vector3(20, 0, -45),
		&"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(-20, 0, 40), &"el_r": Vector3(60, 0, 0),
		&"hip_l": Vector3(80, 0, -5), &"kn_l": Vector3(-120, 0, 0), &"hip_r": Vector3(71, 0, -1),
		&"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	&"jump_kick_over": {&"torso": Vector3(18, 0, 0), &"head": Vector3(-12, 0, 0),
		&"sh_l": Vector3(20, 0, -45), &"el_l": Vector3(60, 0, 0), &"sh_r": Vector3(-20, 0, 40),
		&"el_r": Vector3(60, 0, 0), &"hip_l": Vector3(80, 0, -5), &"kn_l": Vector3(-120, 0, 0),
		&"hip_r": Vector3(71, 0, -1), &"kn_r": Vector3(-5, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	&"jump_kick_back": {&"torso": Vector3(5, 0, 0), &"head": Vector3(-4, 0, 0), &"sh_l": Vector3(40, 0, -30),
		&"el_l": Vector3(90, 0, 0), &"sh_r": Vector3(40, 0, 30), &"el_r": Vector3(90, 0, 0),
		&"hip_l": Vector3(90, 0, -5), &"kn_l": Vector3(-120, 0, 0), &"hip_r": Vector3(95, 0, 5),
		&"kn_r": Vector3(-125, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	# --- dive_kick: tucked, then a leg stabbed down-forward, leaning back ---
	&"dive_kick_load": {&"torso": Vector3(-10, 0, 0), &"head": Vector3(8, 0, 0), &"sh_l": Vector3(30, 0, -30),
		&"el_l": Vector3(90, 0, 0), &"sh_r": Vector3(30, 0, 30), &"el_r": Vector3(90, 0, 0),
		&"hip_l": Vector3(95, 0, -5), &"kn_l": Vector3(-125, 0, 0), &"hip_r": Vector3(100, 0, 5),
		&"kn_r": Vector3(-130, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	&"dive_kick_hit": {&"torso": Vector3(20, 0, 0), &"head": Vector3(-12, 0, 0),
		&"sh_l": Vector3(-20, 0, -45), &"el_l": Vector3(30, 0, 0), &"sh_r": Vector3(-20, 0, 45),
		&"el_r": Vector3(30, 0, 0), &"hip_l": Vector3(85, 0, -5), &"kn_l": Vector3(-115, 0, 0),
		&"hip_r": Vector3(52, 0, -1), &"kn_r": Vector3(1, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	&"dive_kick_over": {&"torso": Vector3(24, 0, 0), &"head": Vector3(-12, 0, 0),
		&"sh_l": Vector3(-20, 0, -45), &"el_l": Vector3(30, 0, 0), &"sh_r": Vector3(-20, 0, 45),
		&"el_r": Vector3(30, 0, 0), &"hip_l": Vector3(85, 0, -5), &"kn_l": Vector3(-115, 0, 0),
		&"hip_r": Vector3(52, 0, -1), &"kn_r": Vector3(1, 0, 0), &"root": Vector3(0, 0.0, 0.0)},
	&"dive_kick_back": {&"torso": Vector3(-10, 0, 0), &"head": Vector3(8, 0, 0), &"sh_l": Vector3(40, 0, -25),
		&"el_l": Vector3(80, 0, 0), &"sh_r": Vector3(40, 0, 25), &"el_r": Vector3(80, 0, 0),
		&"hip_l": Vector3(60, 0, -5), &"kn_l": Vector3(-80, 0, 0), &"hip_r": Vector3(50, 0, 5),
		&"kn_r": Vector3(-70, 0, 0), &"root": Vector3(0, -0.2, 0.0)},
	# --- duck_kick: stays in the crouch, sweeps a leg out along the floor ---
	&"duck_kick_load": {&"torso": Vector3(-40, 15, 0), &"head": Vector3(30, -10, 0),
		&"sh_l": Vector3(60, 0, -20), &"el_l": Vector3(80, 0, 0), &"sh_r": Vector3(60, 0, 20),
		&"el_r": Vector3(80, 0, 0), &"hip_l": Vector3(110, 0, -5), &"kn_l": Vector3(-140, 0, 0),
		&"hip_r": Vector3(105, 0, 5), &"kn_r": Vector3(-145, 0, 0), &"root": Vector3(0, -0.634, 0.0)},
	&"duck_kick_hit": {&"torso": Vector3(-35, -20, 0), &"head": Vector3(28, 15, 0),
		&"sh_l": Vector3(70, 0, -25), &"el_l": Vector3(10, 0, 0), &"sh_r": Vector3(45, 0, 30),
		&"el_r": Vector3(80, 0, 0), &"hip_l": Vector3(110, 0, -5), &"kn_l": Vector3(-140, 0, 0),
		&"hip_r": Vector3(88, 0, -1), &"kn_r": Vector3(-3, 0, 0), &"root": Vector3(0, -0.652, -0.03)},
	&"duck_kick_over": {&"torso": Vector3(-35, -28, 0), &"head": Vector3(28, 20, 0),
		&"sh_l": Vector3(70, 0, -25), &"el_l": Vector3(10, 0, 0), &"sh_r": Vector3(45, 0, 30),
		&"el_r": Vector3(80, 0, 0), &"hip_l": Vector3(110, 0, -5), &"kn_l": Vector3(-140, 0, 0),
		&"hip_r": Vector3(88, 0, -1), &"kn_r": Vector3(-3, 0, 0), &"root": Vector3(0, -0.652, -0.03)},
	&"duck_kick_back": {&"torso": Vector3(-40, 15, 0), &"head": Vector3(30, -10, 0),
		&"sh_l": Vector3(60, 0, -20), &"el_l": Vector3(80, 0, 0), &"sh_r": Vector3(60, 0, 20),
		&"el_r": Vector3(80, 0, 0), &"hip_l": Vector3(110, 0, -5), &"kn_l": Vector3(-140, 0, 0),
		&"hip_r": Vector3(105, 0, 5), &"kn_r": Vector3(-145, 0, 0), &"root": Vector3(0, -0.634, 0.0)},
	# --- ki_blast: hand drawn to the hip, palm thrust at the spawn point ---
	&"ki_blast_load": {&"torso": Vector3(-6, -35, 0), &"head": Vector3(4, 30, 0),
		&"sh_l": Vector3(60, 0, -15), &"el_l": Vector3(100, 0, 0), &"sh_r": Vector3(-25, 0, 20),
		&"el_r": Vector3(110, 0, 0), &"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-10, 0, 5), &"kn_r": Vector3(-25, 0, 0), &"root": Vector3(0, -0.047, 0.02)},
	&"ki_blast_back": {&"torso": Vector3(-8, 10, 0), &"head": Vector3(5, -8, 0), &"sh_l": Vector3(45, 0, -10),
		&"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(60, 0, 15), &"el_r": Vector3(90, 0, 0),
		&"hip_l": Vector3(20, 0, -5), &"kn_l": Vector3(-25, 0, 0), &"hip_r": Vector3(-14, 5, 5),
		&"kn_r": Vector3(-14, 0, 0), &"root": Vector3(0, -0.05, -0.02)},
	&"ki_blast_shot": {&"torso": Vector3(-10, 30, 0), &"head": Vector3(8, -25, 0),
		&"sh_l": Vector3(40, 0, -20), &"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(82, 0, 29),
		&"el_r": Vector3(5, 0, 0), &"hip_l": Vector3(25, 0, -5), &"kn_l": Vector3(-30, 0, 0),
		&"hip_r": Vector3(-20, 10, 5), &"kn_r": Vector3(-8, 0, 0), &"root": Vector3(0, -0.05, -0.04)},
	# --- beam: hands cupped at the hip, then both palms out, held ---
	&"beam_load": {&"torso": Vector3(-4, 60, 0), &"head": Vector3(4, -50, 0), &"sh_l": Vector3(40, 0, 40),
		&"el_l": Vector3(110, 0, 0), &"sh_r": Vector3(-30, 0, 20), &"el_r": Vector3(100, 0, 0),
		&"hip_l": Vector3(5, 0, -20), &"kn_l": Vector3(-30, 0, 0), &"hip_r": Vector3(5, 0, 20),
		&"kn_r": Vector3(-30, 0, 0), &"root": Vector3(0, -0.06, 0.0)},
	&"beam_shot": {&"torso": Vector3(-8, 0, 0), &"head": Vector3(6, 0, 0), &"sh_l": Vector3(86, 0, 29),
		&"el_l": Vector3(10, 0, 0), &"sh_r": Vector3(86, 0, -29), &"el_r": Vector3(10, 0, 0),
		&"hip_l": Vector3(5, 0, -20), &"kn_l": Vector3(-25, 0, 0), &"hip_r": Vector3(5, 0, 20),
		&"kn_r": Vector3(-25, 0, 0), &"root": Vector3(0, -0.061, 0.0)},
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
	&"finisher": [
		[0.0, &"finisher_load", LINEAR], [0.6, &"finisher_load", LINEAR],
		[1.0, &"finisher_hit", EASE_IN], [1.3, &"finisher_over", EASE_OUT], [2.0, &"finisher_hit", EASE_IN_OUT],
		[2.3, &"finisher_hit", LINEAR], [2.6, &"finisher_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"kick_mid": [
		[0.0, &"kick_mid_load", LINEAR], [0.6, &"kick_mid_load", LINEAR],
		[1.0, &"kick_mid_hit", EASE_IN], [1.35, &"kick_mid_over", EASE_OUT], [2.0, &"kick_mid_over", LINEAR],
		[2.4, &"kick_mid_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	# Turns its back over the startup, kicks out behind, turns back to face.
	&"charge_kick": [
		[0.0, &"charge_kick_load", EASE_OUT], [0.7, &"charge_kick_load", LINEAR],
		[1.0, &"charge_kick_hit", EASE_IN], [1.3, &"charge_kick_over", EASE_OUT], [2.0, &"charge_kick_hit", EASE_IN_OUT],
		[2.4, &"charge_kick_back", EASE_IN_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"smash_right": [
		[0.0, &"smash_right_load", LINEAR], [0.7, &"smash_right_load", LINEAR],
		[1.0, &"smash_right_hit", EASE_IN], [1.35, &"smash_right_over", EASE_OUT],
		[2.0, &"smash_right_over", LINEAR], [2.4, &"smash_right_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"smash_left": [
		[0.0, &"smash_left_load", LINEAR], [0.7, &"smash_left_load", LINEAR],
		[1.0, &"smash_left_hit", EASE_IN], [1.35, &"smash_left_over", EASE_OUT],
		[2.0, &"smash_left_over", LINEAR], [2.4, &"smash_left_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"hammer": [
		[0.0, &"hammer_load", EASE_OUT], [0.7, &"hammer_load", LINEAR],
		[1.0, &"hammer_hit", EASE_IN], [1.3, &"hammer_over", EASE_OUT], [2.0, &"hammer_over", LINEAR],
		[2.3, &"hammer_over", LINEAR], [2.6, &"hammer_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"uppercut": [
		[0.0, &"uppercut_load", EASE_OUT], [0.65, &"uppercut_load", LINEAR],
		[1.0, &"uppercut_hit", EASE_IN], [1.35, &"uppercut_over", EASE_OUT], [2.0, &"uppercut_over", LINEAR],
		[2.4, &"uppercut_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"kick_low": [
		[0.0, &"kick_low_load", EASE_OUT], [0.6, &"kick_low_load", LINEAR],
		[1.0, &"kick_low_hit", EASE_IN], [1.4, &"kick_low_over", EASE_OUT], [2.0, &"kick_low_over", LINEAR],
		[2.4, &"kick_low_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"dash_punch": [
		[0.0, &"dash_punch_load", LINEAR], [0.55, &"dash_punch_load", LINEAR],
		[1.0, &"dash_punch_hit", EASE_IN], [1.4, &"dash_punch_over", EASE_OUT], [2.0, &"dash_punch_hit", EASE_IN_OUT],
		[2.4, &"dash_punch_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"belly_bump": [
		[0.0, &"belly_bump_load", EASE_OUT], [0.6, &"belly_bump_load", LINEAR],
		[1.0, &"belly_bump_hit", EASE_IN], [1.35, &"belly_bump_over", EASE_OUT], [2.0, &"belly_bump_hit", EASE_IN_OUT],
		[2.4, &"belly_bump_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	# A connected grab leaves the attack for the THROW state (throw_hold/toss);
	# this plays out a whiff.
	&"throw": [
		[0.0, &"throw_load", LINEAR], [0.5, &"throw_load", LINEAR],
		[1.0, &"throw_hit", EASE_IN], [2.0, &"throw_hit", LINEAR],
		[2.4, &"throw_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"jump_kick": [
		[0.0, &"jump_kick_load", EASE_OUT], [0.5, &"jump_kick_load", LINEAR],
		[1.0, &"jump_kick_hit", EASE_IN], [1.3, &"jump_kick_over", EASE_OUT], [2.0, &"jump_kick_hit", LINEAR],
		[2.5, &"jump_kick_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"dive_kick": [
		[0.0, &"dive_kick_load", EASE_OUT], [0.6, &"dive_kick_load", LINEAR],
		[1.0, &"dive_kick_hit", EASE_IN], [1.3, &"dive_kick_over", EASE_OUT], [2.0, &"dive_kick_hit", LINEAR],
		[2.3, &"dive_kick_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	&"duck_kick": [
		[0.0, &"duck_kick_load", EASE_OUT], [0.5, &"duck_kick_load", LINEAR],
		[1.0, &"duck_kick_hit", EASE_IN], [1.4, &"duck_kick_over", EASE_OUT], [2.0, &"duck_kick_over", LINEAR],
		[2.4, &"duck_kick_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	# The full turn over the active frames is procedural (FighterVisual).
	&"getup_kick": [
		[0.0, &"getup_kick_windup", EASE_OUT], [0.6, &"getup_kick_windup", LINEAR],
		[1.0, &"getup_kick", EASE_IN], [2.0, &"getup_kick", LINEAR],
		[2.5, &"wakeup", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	# No active frames: the shot spawns as startup ends (u jumps 1 -> 2).
	&"ki_blast": [
		[0.0, &"ki_blast_load", EASE_OUT], [0.65, &"ki_blast_load", LINEAR],
		[1.0, &"ki_blast_shot", EASE_IN], [2.0, &"ki_blast_shot", LINEAR],
		[2.45, &"ki_blast_back", EASE_OUT], [3.0, &"idle", EASE_IN_OUT],
	],
	# Palms held out while the beam streams (most of the long recovery).
	&"beam": [
		[0.0, &"beam_load", EASE_OUT], [0.75, &"beam_load", LINEAR],
		[1.0, &"beam_shot", EASE_IN], [2.0, &"beam_shot", LINEAR], [2.85, &"beam_shot", LINEAR],
		[3.0, &"idle", EASE_IN_OUT],
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
	&"finisher_hit": [&"el_r", &"brawler_ender"],
	&"kick_mid_hit": [&"kn_r", &"brawler_kick_mid"],
	&"charge_kick_hit": [&"kn_r", &"brawler_charge_kick"],
	&"smash_right_hit": [&"el_r", &"brawler_smash_right"],
	&"smash_left_hit": [&"el_l", &"brawler_smash_left"],
	&"hammer_hit": [&"el_r", &"brawler_finisher_4"],
	&"uppercut_hit": [&"el_r", &"brawler_upper_hook"],
	&"kick_low_hit": [&"kn_r", &"brawler_sweep"],
	&"dash_punch_hit": [&"el_r", &"brawler_dash_punch"],
	&"throw_hit": [&"el_r", &"brawler_throw"],
	&"jump_kick_hit": [&"kn_r", &"brawler_jump_kick"],
	&"dive_kick_hit": [&"kn_r", &"brawler_dive_kick"],
	&"duck_kick_hit": [&"kn_r", &"brawler_duck_kick"],
	# Projectiles: the palm on the shot's spawn point.
	&"ki_blast_shot": [&"el_r", &"brawler_ki_blast_shot"],
	&"beam_shot": [&"el_r", &"brawler_beam_shot"],
}
## Tracks with no limb contact (the belly hits; the get-up kick's hitbox is a
## ring around the body).
const NO_CONTACT: Array[StringName] = [&"belly_bump", &"getup_kick"]
## Tracks played in the air: their key poses aren't held to the floor.
const AIRBORNE: Array[StringName] = [&"jump_kick", &"dive_kick"]
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
