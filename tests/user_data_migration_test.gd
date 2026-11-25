extends Node
## The rename to Dragon Hand moved Godot's user data folder; UserDataMigration
## copies the old "God Hand Tenkaichi" folder's files over once.
##   godot --headless res://tests/user_data_migration_test.tscn

const ROOT := "user://migration_test"

var _ok := true


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: ", what)


func _ready() -> void:
	var root := ProjectSettings.globalize_path(ROOT)
	_rm(root)
	var old_dir := root.path_join("old")
	var new_dir := root.path_join("new")
	_write(old_dir.path_join("controls.cfg"), "old controls")
	_write(old_dir.path_join("online.cfg"), "old online")
	_write(old_dir.path_join("replays/last_1.ghr"), "replay")
	_write(old_dir.path_join("logs/godot.log"), "old log")
	# The new folder already holds this boot's log and one file of its own.
	_write(new_dir.path_join("logs/godot.log"), "new log")
	_write(new_dir.path_join("online.cfg"), "new online")

	var copied := UserDataMigration.migrate(old_dir, new_dir)
	_check(copied == 2, "copies the two missing files (got %d)" % copied)
	_check(_read(new_dir.path_join("controls.cfg")) == "old controls", "controls.cfg carried over")
	_check(_read(new_dir.path_join("replays/last_1.ghr")) == "replay", "replays carried over")
	_check(_read(new_dir.path_join("online.cfg")) == "new online", "an existing new file is kept")
	_check(_read(new_dir.path_join("logs/godot.log")) == "new log", "logs are not copied")
	_check(FileAccess.file_exists(old_dir.path_join("controls.cfg")), "old folder left in place")

	# Once only: the marker stops a second copy even after files are deleted.
	DirAccess.remove_absolute(new_dir.path_join("controls.cfg"))
	_check(UserDataMigration.migrate(old_dir, new_dir) == 0, "second run copies nothing")
	_check(not FileAccess.file_exists(new_dir.path_join("controls.cfg")), "deleted file stays deleted")

	# No old folder: nothing to do, no error.
	_check(UserDataMigration.migrate(root.path_join("missing"), root.path_join("fresh")) == 0,
			"missing old folder is a no-op")
	_check(UserDataMigration.legacy_dir("/a/app_userdata/Dragon Hand") == "/a/app_userdata/God Hand Tenkaichi",
			"legacy folder is the sibling with the old name")

	_rm(root)
	print("USER DATA MIGRATION TEST %s" % ("PASS" if _ok else "FAIL"))
	get_tree().quit(0 if _ok else 1)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _rm(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.include_hidden = true  # the migration marker is a dot file
	for f in da.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for d in da.get_directories():
		_rm(dir.path_join(d))
	DirAccess.remove_absolute(dir)
