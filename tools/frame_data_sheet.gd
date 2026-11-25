extends Node
## Prints the frame-data sheet of every character (or one), from MoveData and
## each character's tuning (tools/frame_data.gd explains the columns):
##   godot --headless res://tools/frame_data_sheet.tscn -- [char=brawler] [format=md|csv] [out=<file>]
## Guard letters per pose (mid / high / low): P plain, K ki guard, O push-off,
## S push-stop, U unblockable.

const FrameData := preload("res://tools/frame_data.gd")
const DEFAULTS := {"char": "all", "format": "md", "out": ""}


func _ready() -> void:
	var args := DEFAULTS.duplicate()
	for pair in ToolArgs.pairs():
		var kv := pair.split("=", true, 1)
		if kv.size() == 2 and args.has(kv[0]):
			args[kv[0]] = kv[1]
		else:
			push_error("frame_data_sheet: unknown argument %s" % pair)
			get_tree().quit(2)
			return
	var ids: Array[StringName] = CharacterRegistry.ids()
	if args["char"] != "all":
		ids = [StringName(args["char"])]
	var text := ""
	if args["format"] == "md":
		text = "Guard m/h/l: P plain, K ki guard, O push-off, S push-stop, U unblockable.\n\n"
	for i in ids.size():
		var def := CharacterRegistry.load_def(ids[i])
		var rows := FrameData.rows(def, Tuning.fighter)
		if args["format"] == "csv":
			text += FrameData.to_csv(String(ids[i]), rows, i == 0)
		else:
			text += FrameData.to_markdown(CharacterRegistry.display_name(ids[i]), rows) + "\n"
	if args["out"] != "":
		var f := FileAccess.open(args["out"], FileAccess.WRITE)
		if f == null:
			push_error("frame_data_sheet: can't write %s" % args["out"])
			get_tree().quit(1)
			return
		f.store_string(text)
		print("frame_data_sheet: wrote %s" % args["out"])
	else:
		print(text)
	get_tree().quit(0)
