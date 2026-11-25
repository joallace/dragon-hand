extends Node
## Headless test for the Dragon Hand emblem (DragonEmblem):
## - the art SVG ships as-is ("keep" import) and parses;
## - it only uses palette colours, and art_svg() swaps them for tuned ones;
## - icon.svg embeds the art's <g> verbatim (one design, two files);
## - rasterize() gives a square image of the asked size with visible pixels;
## - the control rasterizes and caches its art at its menu size.
##   godot --headless res://tests/emblem_test.tscn

var _ok := true


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: ", what)


func _ready() -> void:
	_test_art_ships()
	_test_palette()
	_test_icon_in_sync()
	_test_rasterize()
	await _test_control()
	print("PASS" if _ok else "FAIL")
	get_tree().quit(0 if _ok else 1)


func _test_art_ships() -> void:
	var cfg := ConfigFile.new()
	_check(cfg.load(DragonEmblem.ART_PATH + ".import") == OK, "art has an .import file")
	_check(cfg.get_value("remap", "importer", "") == "keep",
		"art is imported as 'keep' so exports ship the raw SVG")
	_check(not FileAccess.get_file_as_string(DragonEmblem.ART_PATH).is_empty(), "art is readable")


func _hexes(svg: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in RegEx.create_from_string("#([0-9a-fA-F]{6})\\b").search_all(svg):
		out.append(m.get_string(1).to_lower())
	return out


func _test_palette() -> void:
	var defaults := UiTuning.new()
	var allowed := {}
	for prop in DragonEmblem.PALETTE:
		allowed[(defaults.get(prop) as Color).to_html(false)] = prop
	var src := FileAccess.get_file_as_string(DragonEmblem.ART_PATH)
	for hex in _hexes(src):
		_check(allowed.has(hex), "art colour #%s is a UiTuning palette default" % hex)
	# Defaults in -> the same SVG out.
	_check(DragonEmblem.art_svg(defaults) == src, "default palette leaves the art unchanged")
	# Retuned jade -> no default jade left, the new one in its place.
	var tuned := UiTuning.new()
	tuned.color_jade = Color("123456")
	var swapped := DragonEmblem.art_svg(tuned)
	_check(not swapped.contains("#" + defaults.color_jade.to_html(false)), "tuned jade replaces the default")
	_check(swapped.contains("#123456"), "tuned jade is in the recoloured art")
	_check(swapped.contains("#" + defaults.color_gold.to_html(false)), "untouched colours stay")


func _test_icon_in_sync() -> void:
	var re := RegEx.create_from_string("(?s)<g .*</g>")
	var art := re.search(FileAccess.get_file_as_string(DragonEmblem.ART_PATH))
	var icon := FileAccess.get_file_as_string("res://icon.svg")
	_check(art != null and icon.contains(art.get_string()), "icon.svg embeds the emblem art verbatim")


func _test_rasterize() -> void:
	var svg := DragonEmblem.art_svg(UiTheme.tuning())
	for px: int in [16, 124, 300]:
		var img := DragonEmblem.rasterize(svg, px)
		_check(img != null, "rasterize %d px" % px)
		if img == null:
			continue
		_check(img.get_width() == px and img.get_height() == px, "rasterized %d px is square" % px)
		var opaque := 0
		var step := maxi(1, px / 16)
		for y in range(0, px, step):
			for x in range(0, px, step):
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		_check(opaque > 0, "rasterized %d px has visible art" % px)
	_check(DragonEmblem.rasterize("", 32) == null, "empty SVG -> null")


func _test_control() -> void:
	var e := DragonEmblem.new()
	e.custom_minimum_size = Vector2.ONE * UiTheme.tuning().main_menu_emblem_size
	e.size = e.custom_minimum_size
	add_child(e)
	await get_tree().process_frame
	await get_tree().process_frame
	# _draw rasterized at its screen size (headless: scale 1) on its own.
	_check(e._art != null and e._art_px == ceili(e.size.x * e.get_screen_transform().get_scale().x),
		"control rasterizes its art at its on-screen size when drawn")
	var tex := e.art_texture(124)
	_check(tex != null and tex.get_width() == 124, "art_texture gives the asked size")
	_check(e.art_texture(124) == tex, "same size reuses the cached texture")
	var half := e.art_texture(62)
	_check(half != null and half.get_width() == 62, "a resize re-rasterizes")
	e.queue_free()
