class_name PoseSprings
extends RefCounted
## Damped springs over a pose: one Vector3 (degrees, or meters for the root
## offset) per channel chases its target. Overshoot and settle come from the
## damping ratio, so a snap into a pose carries momentum instead of easing
## to a dead stop, and velocity kicks (hit reactions) ride on top.
## Presentation only (FighterVisual); frame-rate independent by substepping.

var _x: Dictionary = {}  # StringName -> Vector3 value
var _v: Dictionary = {}  # StringName -> Vector3 velocity (per second)


## Start `channel` at rest at `value`.
func reset(channel: StringName, value: Vector3) -> void:
	_x[channel] = value
	_v[channel] = Vector3.ZERO


func value(channel: StringName) -> Vector3:
	return _x[channel]


func velocity(channel: StringName) -> Vector3:
	return _v[channel]


## Adds to `channel`'s velocity (an impulse; units per second).
func kick(channel: StringName, dv: Vector3) -> void:
	_v[channel] = (_v[channel] as Vector3) + dv


## Advances every channel `dt` seconds toward `targets` (channel -> Vector3;
## channels missing from it keep their target from `fallback`), with the
## spring at `hz` and damping ratio `zeta`. Semi-implicit Euler in steps of at
## most `max_step`; past `max_steps` the channels snap (a long stall).
func step(targets: Dictionary, fallback: Dictionary, dt: float, hz: float, zeta: float,
		max_step: float, max_steps: int) -> void:
	if dt <= 0.0:
		return
	var w := TAU * hz
	# Semi-implicit Euler is stable while (h w)^2 + 4 zeta h w < 4: cap the
	# step at 0.5 / w too, so a stiffer tuning can't blow up.
	var n := ceili(dt / minf(max_step, 0.5 / maxf(w, 0.001)))
	if n > max_steps:
		for c in _x:
			_x[c] = targets[c] if targets.has(c) else fallback[c]
			_v[c] = Vector3.ZERO
		return
	var h := dt / n
	var k := w * w
	var d := 2.0 * zeta * w
	for c in _x:
		# (not targets.get(c, fallback[c]): the default is evaluated eagerly)
		var target: Vector3 = targets[c] if targets.has(c) else fallback[c]
		var x: Vector3 = _x[c]
		var v: Vector3 = _v[c]
		for i in n:
			v += (k * (target - x) - d * v) * h
			x += v * h
		_x[c] = x
		_v[c] = v
