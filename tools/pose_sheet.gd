extends Node
## Renders MoveTracks tracks as pose strips (PNG, one cell per timeline
## sample) so a track can be checked by eye while tuning it. The track's
## raw target poses, without the springs. Needs a real window (no --headless):
##   godot res://tools/pose_sheet.tscn --resolution 320x240 -- out=<dir> [only=jab] [view=side|front34]
## `poses=guard,duck,...` instead draws those static poses in one strip;
## `char=bulk` draws that character's body (model, colour, body_scale).
## Cells: u = 0 (load) .. 1 (contact, first active frame) .. 2 (recovery) .. 3.

const US: Array[float] = [0.0, 0.5, 0.8, 1.0, 1.35, 2.0, 2.35, 2.7, 3.0]
const CELL := Vector2i(200, 260)
const VIEWS := {
	"side": Vector3(3.6, 1.1, -0.35),
	"front34": Vector3(2.2, 1.6, -3.0),
}
const LOOK_AT := Vector3(0, 0.95, -0.35)
const BACKGROUND := Color(0.75, 0.8, 0.85)
const FLOOR_COLOR := Color(0.45, 0.5, 0.45)
const FLOOR_SIZE := 6.0
const CAMERA_FOV := 40.0

var _vp: SubViewport
var _cam: Camera3D
var _visual: FighterVisual


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var out: String = args.get("out", "user://pose_sheet")
	DirAccess.make_dir_recursive_absolute(out)
	var char_id := StringName(args.get("char", ""))
	if char_id != &"" and char_id not in CharacterRegistry.ids():
		printerr("pose_sheet: unknown char=%s (have %s)" % [char_id, CharacterRegistry.ids()])
		get_tree().quit(1)
		return
	_build_stage(char_id)
	await get_tree().process_frame
	for view: String in VIEWS:
		if args.has("view") and args["view"] != view:
			continue
		if args.has("poses"):
			await _static_strip(args["poses"].split(","), view, out)
			continue
		for pose: StringName in MoveTracks.TRACKS:
			if args.has("only") and StringName(args["only"]) != pose:
				continue
			_cam.position = VIEWS[view]
			_cam.look_at(LOOK_AT)
			var strip := Image.create(CELL.x * US.size(), CELL.y, false, Image.FORMAT_RGBA8)
			for i in US.size():
				_apply(MoveTracks.sample(pose, US[i], FighterVisual.POSES[&"idle"]))
				strip.blit_rect(await _shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
			var path := "%s/%s_%s.png" % [out, pose, view]
			strip.save_png(path)
			print("POSE_SHEET ", ProjectSettings.globalize_path(path))
	get_tree().quit()


## One strip of named static poses (FighterVisual.POSES / MoveTracks.KEY_POSES).
func _static_strip(names: PackedStringArray, view: String, out: String) -> void:
	_cam.position = VIEWS[view]
	_cam.look_at(LOOK_AT)
	var strip := Image.create(CELL.x * names.size(), CELL.y, false, Image.FORMAT_RGBA8)
	for i in names.size():
		_apply(MoveTracks.pose_of(StringName(names[i])))
		strip.blit_rect(await _shot(), Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
	var path := "%s/poses_%s.png" % [out, view]
	strip.save_png(path)
	print("POSE_SHEET ", ProjectSettings.globalize_path(path))


func _build_stage(char_id: StringName) -> void:
	_vp = SubViewport.new()
	_vp.size = CELL
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BACKGROUND
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	_vp.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = FLOOR_COLOR
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = floor_mat
	_vp.add_child(floor_node)
	_cam = Camera3D.new()
	_cam.fov = CAMERA_FOV
	_vp.add_child(_cam)
	_visual = FighterVisual.new()  # no Fighter parent: posed by hand below
	if char_id != &"":
		_visual.preview_def = CharacterRegistry.load_def(char_id)
	_vp.add_child(_visual)


func _apply(pose: Dictionary) -> void:
	_visual.snap_to_pose(pose)


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var im := _vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im
