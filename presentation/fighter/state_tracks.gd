class_name StateTracks
extends RefCounted
## Keyframed non-attack states (presentation only): like MoveTracks, but on
## the state's own frame count. A track is keyed by the fighter's
## current_pose() (dodge kinds) or state name, runs over `frames` state
## frames (a FighterTuning property name, or an int), and its keys are
## [t, pose, ease] with t = 0..1 of that length (MoveTracks.sample, so
## the same ease conventions; poses from FighterVisual.POSES / KEY_POSES).
## Past t = 1 the last key holds (loops like the charge stay on it).
## States without a track use FighterVisual.pose_id_for as before.

const E_IN := MoveTracks.EASE_IN
const E_OUT := MoveTracks.EASE_OUT
const E_IN_OUT := MoveTracks.EASE_IN_OUT
const LIN := MoveTracks.LINEAR

const TRACKS := {
	# Sways: drop under the blow fast, ride it, rise back into stance.
	&"sway_l": {"frames": &"sway_total_frames", "keys": [
		[0.0, &"sway_l_dip", E_OUT], [0.3, &"sway_l_dip", LIN], [0.6, &"sway_l", E_IN_OUT],
		[0.8, &"sway_l", LIN], [1.0, &"idle", E_IN_OUT],
	]},
	&"sway_r": {"frames": &"sway_total_frames", "keys": [
		[0.0, &"sway_r_dip", E_OUT], [0.3, &"sway_r_dip", LIN], [0.6, &"sway_r", E_IN_OUT],
		[0.8, &"sway_r", LIN], [1.0, &"idle", E_IN_OUT],
	]},
	# Backflip: crouch and push off, tuck through the (procedural) spin, land
	# in a crouch, stand.
	&"backflip": {"frames": &"backflip_total_frames", "keys": [
		[0.0, &"backflip_load", E_OUT], [0.08, &"backflip_load", LIN], [0.2, &"backflip", E_IN],
		[0.62, &"backflip", LIN], [0.76, &"backflip_land", E_OUT], [0.88, &"backflip_land", LIN],
		[1.0, &"idle", E_IN_OUT],
	]},
	# Ki charge: gather in over the wind-up, then burst into the power-up.
	&"charge": {"frames": &"charge_windup_frames", "keys": [
		[0.0, &"charge_gather", E_OUT], [0.6, &"charge_gather", LIN], [1.0, &"charge", E_IN],
	]},
}


## The track key for a fighter's current state, or &"" when it has none.
## Only a grounded dodge plays a dodge track: an air tech also reports the
## backflip pose, but starts in the air and lasts until it lands.
static func key_for(state_name: StringName, pose: StringName,
		dodge_kind: Fighter.DodgeKind = Fighter.DodgeKind.DODGE) -> StringName:
	if state_name == &"dodge":
		return pose if dodge_kind == Fighter.DodgeKind.DODGE and TRACKS.has(pose) else &""
	if state_name != &"dodge" and TRACKS.has(state_name):
		return state_name
	return &""


## Length in frames of `key`'s track for `tuning`.
static func frames_of(key: StringName, tuning: FighterTuning) -> int:
	var f: Variant = TRACKS[key]["frames"]
	if f is int:
		return maxi(f, 1)
	return maxi(int(tuning.get(f)) if tuning != null else 1, 1)


## Pose dictionary of `key` at state frame `frame` (fractional ok).
static func sample(key: StringName, frame: float, tuning: FighterTuning, base: Dictionary) -> Dictionary:
	var t := clampf(frame / frames_of(key, tuning), 0.0, 1.0)
	return MoveTracks.sample_keys(TRACKS[key]["keys"], t, base)
