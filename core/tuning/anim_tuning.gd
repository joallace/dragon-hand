class_name AnimTuning
extends Resource
## Fighter body animation feel (presentation only, never read by the sim).
## Edit data/tuning/anim.tres. Spring frequencies in Hz, damping as a ratio
## (1 = critically damped, no overshoot; lower = overshoot and settle),
## angles in degrees, impulses in degrees/second, offsets in meters.

@export_group("Joint springs")
## Every joint chases its target pose with a damped spring (FighterVisual):
## state changes, stance, reactions.
@export var spring_hz: float = 7.5
@export var spring_damping: float = 0.65
## Attack active frames without a track, dodges: snappier, more overshoot.
@export var strike_spring_hz: float = 16.0
@export var strike_spring_damping: float = 0.5
## Following a keyframed move track (MoveTracks): stiff so the keys land on
## their frames; the overshoot is authored in the keys.
@export var track_spring_hz: float = 24.0
@export var track_spring_damping: float = 0.8
## Lying down, getting up, ducking: no overshoot through the floor.
@export var grounded_spring_damping: float = 1.0
## Spring integration step cap (s) and step count cap per rendered frame
## (past it the pose snaps to its target).
@export var max_substep: float = 1.0 / 240.0
@export var max_substeps: int = 24

@export_group("Idle")
## Breathing: chest rises/falls, shoulders lift, body bobs.
@export var breath_hz: float = 0.45
@export var breath_deg: float = 2.0
@export var breath_bob: float = 0.008
## Slow side-to-side weight shift.
@export var weight_shift_hz: float = 0.21
@export var weight_shift_deg: float = 2.5

@export_group("Walk")
## Arms swing against the legs, the chest counter-twists, the body bobs
## twice per stride.
@export var walk_arm_swing_deg: float = 16.0
@export var walk_torso_twist_deg: float = 6.0
@export var walk_bob: float = 0.025

@export_group("Follow-through")
## The head trails the torso: seconds of torso angular velocity it lags by.
@export var head_lag: float = 0.03
@export var head_lag_max_deg: float = 15.0

@export_group("Hit reactions")
## Unblocked hit taken: the torso and head snap back, arms fling out, the
## chest twists away from the side hit (spring velocity kicks).
@export var hit_torso_impulse: float = 520.0
@export var hit_head_impulse: float = 760.0
@export var hit_arm_impulse: float = 420.0
@export var hit_twist_impulse: float = 380.0
@export var hit_heavy_scale: float = 1.6
## Blocked hit: the same kick, scaled down (guard rocked).
@export var hit_blocked_scale: float = 0.35
## Where the hit landed, from the hit point's height above the victim's
## feet (m, at body scale 1): above head height the head snaps back
## (hitstun), below low height a knee buckles (hitstun_low), between = a
## body blow folding the chest over (hitstun_body).
@export var hit_head_height: float = 1.4
@export var hit_low_height: float = 0.75
## Torso kick per zone, times hit_torso_impulse (negative = folds forward).
@export var hit_body_torso_scale: float = -0.8
@export var hit_low_torso_scale: float = 0.3
## A knocked-down fighter bouncing off the floor: the body and limbs flop.
@export var bounce_torso_impulse: float = 600.0
@export var bounce_limb_impulse: float = 700.0
