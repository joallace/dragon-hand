extends Node
## Pose authoring helper (headless). Numbers for FighterVisual.POSES and
## MoveTracks.KEY_POSES, so poses can be written against the rig instead of
## by eye (docs/animation_roadmap.md).
##
## report (default): every pose's lowest point (vs idle's: feet planted when
## equal), head position, and the contact error of MoveTracks.CONTACTS.
##   godot --headless res://tools/pose_fit.tscn -- [mode=report] [only=<pose>]
## fit: searches two angles of a limb's upper joint and its lower joint's bend
## so the fist/foot reaches a move's hitbox center, from a key pose.
##   godot --headless res://tools/pose_fit.tscn -- mode=fit pose=hook_hit
##       joint=sh_r move=brawler_hook [axes=xz|yz|xy] [fixed=<deg>]
##       [a=lo,hi] [b=lo,hi] [bend=lo,hi] [prefer=<deg>]
## `axes`: the two components of the upper joint searched (the third stays
## at the pose's value, or `fixed`); `prefer`: bend the search leans toward.
## The visual space is fighter space with z flipped (forward = -Z).

const STEP_COARSE := 4.0
const STEP_FINE := 1.0
## Score weight per degree of bend away from `prefer` (m per deg).
const BEND_WEIGHT := 0.0015

var _v: FighterVisual


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	_v = FighterVisual.new()
	add_child(_v)
	if args.get("mode", "report") == "fit":
		_fit(args)
	else:
		_report(args.get("only", ""))
	get_tree().quit()


func _apply(pose: Dictionary) -> void:
	var idle: Dictionary = FighterVisual.POSES[&"idle"]
	for j in FighterVisual.JOINTS:
		(_v._joints[j] as Node3D).rotation_degrees = pose.get(j, idle[j])
	_v._body.position = pose.get(&"root", idle[&"root"])
	if _v._skeleton != null:
		FighterModel.sync_pose(_v._skeleton, _v._rig)


func _effector(j: StringName) -> Vector3:
	var off := MoveTracks.FIST_OFFSET if String(j).begins_with("el") else MoveTracks.FOOT_OFFSET
	return (_v._joints[j] as Node3D).global_transform * off


func _lowest() -> float:
	if _v._skeleton == null:
		return minf(_effector(&"kn_l").y, _effector(&"kn_r").y)
	var all := PackedInt32Array()
	for i in _v._rig.size():
		all.append(i)
	var lo := INF
	for p in FighterModel.posed_points(_v._skeleton, all):
		lo = minf(lo, p.y)
	return lo


static func _target(move_id: String) -> Vector3:
	var m := load("res://data/moves/%s.tres" % move_id) as MoveData
	return Vector3(m.hitbox_offset.x, m.hitbox_offset.y, -m.hitbox_offset.z)


func _report(only: String) -> void:
	_apply(FighterVisual.POSES[&"idle"])
	var ref := _lowest()
	print("POSE_FIT idle lowest %.3f" % ref)
	var all := {}
	for id in FighterVisual.POSES:
		all[id] = FighterVisual.POSES[id]
	for id in MoveTracks.KEY_POSES:
		all[id] = MoveTracks.KEY_POSES[id]
	for id: StringName in all:
		if only != "" and String(id) != only:
			continue
		_apply(all[id])
		var head := (_v._joints[&"head"] as Node3D).global_transform * Vector3(0, 0.15, 0)
		var line := "POSE_FIT %-20s floor %+.3f  head (%.2f, %.2f, %.2f)" % [id, _lowest() - ref, head.x, head.y, head.z]
		if MoveTracks.CONTACTS.has(id):
			var c: Array = MoveTracks.CONTACTS[id]
			line += "  contact %s %.3f m" % [c[0], _effector(c[0]).distance_to(_target(c[1]))]
		print(line)


func _range(s: String, fallback: Vector2) -> Vector2:
	if s == "":
		return fallback
	var p := s.split(",")
	return Vector2(float(p[0]), float(p[1]))


func _fit(args: Dictionary) -> void:
	var pose_id := StringName(args.get("pose", ""))
	var src: Dictionary = MoveTracks.KEY_POSES.get(pose_id, FighterVisual.POSES.get(pose_id, {}))
	var upper := StringName(args.get("joint", "sh_r"))
	var lower := StringName(String(upper).replace("sh_", "el_").replace("hip_", "kn_"))
	var target := _target(args.get("move", ""))
	var axes: String = args.get("axes", "xz")
	var ia := "xyz".find(axes[0])
	var ib := "xyz".find(axes[1])
	var idle: Dictionary = FighterVisual.POSES[&"idle"]
	var base: Vector3 = src.get(upper, idle[upper])
	if args.has("fixed"):
		base["xyz".find("xyz".replace(axes[0], "").replace(axes[1], ""))] = float(args["fixed"])
	var ra := _range(args.get("a", ""), Vector2(-90, 180))
	var rb := _range(args.get("b", ""), Vector2(-90, 90))
	var is_leg := String(lower).begins_with("kn")
	var rl := _range(args.get("bend", ""), Vector2(-150, 0) if is_leg else Vector2(0, 150))
	var prefer := float(args.get("prefer", "0"))
	var p := src.duplicate()
	var best := INF
	var bu := base
	var bl := 0.0
	var step := STEP_COARSE
	for pass_i in 2:
		var a := ra.x
		while a <= ra.y:
			var b := rb.x
			while b <= rb.y:
				var l := rl.x
				while l <= rl.y:
					var u := base
					u[ia] = a
					u[ib] = b
					p[upper] = u
					p[lower] = Vector3(l, 0, 0)
					_apply(p)
					var s := _effector(lower).distance_to(target) + BEND_WEIGHT * absf(l - prefer)
					if s < best:
						best = s
						bu = u
						bl = l
					l += step
				b += step
			a += step
		ra = Vector2(bu[ia] - STEP_COARSE, bu[ia] + STEP_COARSE)
		rb = Vector2(bu[ib] - STEP_COARSE, bu[ib] + STEP_COARSE)
		rl = Vector2(bl - STEP_COARSE, bl + STEP_COARSE)
		step = STEP_FINE
	p[upper] = bu
	p[lower] = Vector3(bl, 0, 0)
	_apply(p)
	print("POSE_FIT %s: &\"%s\": Vector3(%d, %d, %d), &\"%s\": Vector3(%d, 0, 0)  -> %.3f m off %s" % [
		pose_id, upper, bu.x, bu.y, bu.z, lower, bl, _effector(lower).distance_to(target), target])
