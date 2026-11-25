class_name UserDataMigration
extends RefCounted
## The game was "God Hand Tenkaichi" before it became "Dragon Hand", and
## Godot names the user data folder (user://: controls.cfg, online.cfg,
## video/audio settings, replays/) after the project. On the first boot under
## the new name, copy the old folder's files across, once (a marker file
## records it), never overwriting a file the new folder already has and never
## deleting the old folder. Run by Settings before any user file is read.

## Former project names, newest first; the first folder found is used.
const LEGACY_NAMES: PackedStringArray = ["God Hand Tenkaichi"]
## Written into the new folder once the copy was attempted.
const MARKER := ".migrated_from_legacy"
## Engine-written folders not worth carrying over.
const SKIP_DIRS: PackedStringArray = ["logs", "shader_cache", "vulkan"]


## Migrates into this run's user folder. No-op on web (user:// is the
## browser's storage, not a named folder) and headless (tests and tools: a
## dev run must not spend the one-time copy before a player's first launch).
static func run() -> int:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return 0
	var new_dir := OS.get_user_data_dir()
	for i in LEGACY_NAMES.size():
		if DirAccess.dir_exists_absolute(legacy_dir(new_dir, i)):
			return migrate(legacy_dir(new_dir, i), new_dir)
	return 0


## The user folder the game had under its old name: the sibling of `new_dir`.
static func legacy_dir(new_dir: String, index: int = 0) -> String:
	return new_dir.get_base_dir().path_join(LEGACY_NAMES[index])


## Copies files under `old_dir` missing from `new_dir`; returns how many.
static func migrate(old_dir: String, new_dir: String) -> int:
	if old_dir == new_dir or not DirAccess.dir_exists_absolute(old_dir):
		return 0
	if FileAccess.file_exists(new_dir.path_join(MARKER)):
		return 0
	DirAccess.make_dir_recursive_absolute(new_dir)
	var failed: Array[String] = []
	var copied := _copy_tree(old_dir, new_dir, true, failed)
	if not failed.is_empty():
		# No marker: the next boot retries the files still missing.
		push_warning("Dragon Hand: could not carry over %s" % [failed])
		return copied
	var f := FileAccess.open(new_dir.path_join(MARKER), FileAccess.WRITE)
	if f != null:
		f.store_line(old_dir)
	if copied > 0:
		print("Dragon Hand: carried %d file(s) over from %s" % [copied, old_dir])
	return copied


static func _copy_tree(from: String, to: String, top: bool, failed: Array[String]) -> int:
	var n := 0
	for name in DirAccess.get_files_at(from):
		var dest := to.path_join(name)
		if FileAccess.file_exists(dest):
			continue
		DirAccess.make_dir_recursive_absolute(to)
		if DirAccess.copy_absolute(from.path_join(name), dest) == OK:
			n += 1
		else:
			failed.append(from.path_join(name))
	var dir := DirAccess.open(from)
	for d in DirAccess.get_directories_at(from):
		# Linked folders are skipped (a link back up would recurse forever).
		if (top and d in SKIP_DIRS) or (dir != null and dir.is_link(d)):
			continue
		n += _copy_tree(from.path_join(d), to.path_join(d), false, failed)
	return n
