class_name PromptLabel
extends RichTextLabel
## A label whose text has button prompts in it: a template such as
## "{accept} select     {back} back" (tokens: Prompts autoload), drawn with
## coloured Promptfont glyphs and redrawn whenever the device on screen, the
## prompt settings or the bindings change.
##
## By default it follows the shared legend device (Prompts.kind()). A
## per-player legend sets `kind` / `device` / `slot` to that player's.
## Theme types: "PromptText" (body), "HintPrompt", "HeaderPrompt" (UiTheme),
## mirroring the Label ones; set_color() replaces the text colour.

## Template for a pad, and for the keyboard ("" = the same template).
## Setting either redraws the label.
var template := "":
	set(v):
		if v != template:
			template = v
			refresh()
var key_template := "":
	set(v):
		if v != key_template:
			key_template = v
			refresh()
## Whose glyphs: a Bindings.Kind, or -1 to follow Prompts.kind().
var kind := -1
## Pad device id for the pad style (-1: the last pad used).
var device := -1
## Bindings profile read by {@ACTION} tokens.
var slot := 0

var _fx := _PromptBgEffect.new()
var _backdrop := _Backdrop.new()


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	clip_contents = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"PromptText"
	install_effect(_fx)
	_backdrop.show_behind_parent = true
	add_child(_backdrop, false, Node.INTERNAL_MODE_FRONT)


func _enter_tree() -> void:
	Prompts.changed.connect(refresh)
	Bindings.changed.connect(_on_bindings_changed)
	refresh()


func _exit_tree() -> void:
	Prompts.changed.disconnect(refresh)
	Bindings.changed.disconnect(_on_bindings_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		refresh()
	elif what == NOTIFICATION_DRAW:
		_sync_backdrop()
		set_process_internal(false)


## Set what to show (and whose glyphs; see the vars).
func set_prompt(pad_template: String, keyboard_template := "", kind_ := -1, device_ := -1, slot_ := 0) -> void:
	var whose_changed := kind_ != kind or device_ != device or slot_ != slot
	kind = kind_
	device = device_
	slot = slot_
	key_template = keyboard_template
	template = pad_template
	if whose_changed:
		refresh()


func set_color(c: Color) -> void:
	add_theme_color_override("default_color", c)


## The device kind this label shows now.
func shown_kind() -> int:
	return kind if kind >= 0 else Prompts.kind()


func refresh() -> void:
	if not is_inside_tree():
		return
	var k := shown_kind()
	var t := key_template if k == Bindings.Kind.KEYBOARD and key_template != "" else template
	var bb := Prompts.format(t, get_theme_font_size(&"normal_font_size"), k, device, slot)
	var has_pbg := bb.contains("[%s " % PromptGlyphs.PBG_TAG)
	if bb != text:
		_fx.spans.clear()
		text = bb
		set_process_internal(false)
		if not is_visible_in_tree() or not has_pbg:
			_backdrop.set_specs([])
	elif is_visible_in_tree() and has_pbg:
		queue_redraw()


## The backdrop specs drawn behind this label's glyphs on its last draw pass.
func badge_specs() -> Array[Dictionary]:
	return _backdrop.specs


func _sync_backdrop() -> void:
	var u := UiTheme.tuning()
	var next: Array[Dictionary] = []
	for span_key: Variant in _fx.spans:
		var sp: Dictionary = _fx.spans[span_key]
		var b := int(sp["b"]) as PromptGlyphs.Badge
		var spec: Dictionary
		if b == PromptGlyphs.Badge.KEYCAP_TEXT:
			spec = PromptGlyphs.keycap_text_spec(sp["rect"], int(sp["s"]), u)
		else:
			spec = PromptGlyphs.badge_spec(b, int(sp["c"]), sp["pos"], int(sp["s"]), u)
		if not spec.is_empty():
			next.append(spec)
	_fx.spans.clear()
	_backdrop.set_specs(next)


func _on_bindings_changed(_slot: int) -> void:
	refresh()


## Records the drawn baseline origin of each `[pbg]` span during
## RichTextLabel's draw pass (deduplicated across outline / fill passes by tag
## start index). PromptLabel turns internal processing off right after setting
## text / drawing so static and hidden labels never tick per frame.
class _PromptBgEffect extends RichTextEffect:
	var bbcode := PromptGlyphs.PBG_TAG
	var spans: Dictionary = {}

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var tag_key: int = fx.range.x - fx.relative_index
		var b: int = int(fx.env.get("b", PromptGlyphs.Badge.NONE))
		var s: int = int(fx.env.get("s", 0))
		var pos := fx.transform.origin
		if b == PromptGlyphs.Badge.KEYCAP_TEXT:
			if not fx.font.is_valid():
				return true
			var ts := TextServerManager.get_primary_interface()
			var adv_x := ts.font_get_glyph_advance(fx.font, s, fx.glyph_index).x
			var asc := ts.font_get_ascent(fx.font, s)
			var dsc := ts.font_get_descent(fx.font, s)
			var line_key := Vector2i(tag_key, roundi(pos.y))
			if spans.has(line_key):
				var cur: Rect2 = spans[line_key]["rect"]
				spans[line_key]["rect"] = cur.expand(Vector2(pos.x, pos.y - asc)).expand(Vector2(pos.x + adv_x, pos.y + dsc))
			else:
				spans[line_key] = {"b": b, "s": s, "rect": Rect2(pos.x, pos.y - asc, adv_x, asc + dsc)}
		elif not spans.has(tag_key):
			spans[tag_key] = {"b": b, "c": int(fx.env.get("c", 0)), "s": s, "pos": pos}
		return true


## Draws geometric gamepad badges and text-keycap boxes behind PromptLabel.
class _Backdrop extends Node2D:
	var _styles: Dictionary = {}
	var specs: Array[Dictionary] = []

	func _style_box(s: Dictionary) -> StyleBoxFlat:
		var key := [s["bg"], s["border"], s["border_width"], s["corner"]]
		if _styles.has(key):
			return _styles[key]
		var sb := StyleBoxFlat.new()
		sb.bg_color = s["bg"]
		sb.border_color = s["border"]
		sb.set_border_width_all(int(s["border_width"]))
		sb.set_corner_radius_all(int(s["corner"]))
		sb.anti_aliasing = true
		_styles[key] = sb
		return sb

	func set_specs(next: Array[Dictionary]) -> void:
		if specs == next:
			return
		specs = next
		queue_redraw()

	func _draw() -> void:
		for s in specs:
			draw_style_box(_style_box(s), s["rect"])
