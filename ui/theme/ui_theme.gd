class_name UiTheme
extends RefCounted
## The Jade Lacquer Theme (Dragon Hand), built in code from Tuning.ui:
## LacquerBox plates and cards, Dela Gothic One titles, Saira body text.
## Use: `control.theme = UiTheme.get_theme()` on a screen root.
## Type variations: "TitleLabel", "HeaderLabel", "HintLabel", "PanelBox",
## "RowButton"; for PromptLabel (a RichTextLabel) "PromptText", "HintPrompt"
## and "HeaderPrompt", which look like Label, "HintLabel" and "HeaderLabel".

static var _cached: Theme


static func get_theme() -> Theme:
	if _cached == null:
		_cached = build()
	return _cached


## Drop the cache (e.g. after editing Tuning.ui at runtime).
static func invalidate() -> void:
	_cached = null
	_fonts.clear()


static func tuning() -> UiTuning:
	var t: UiTuning = Tuning.ui if Tuning.get("ui") != null else null
	return t if t != null else UiTuning.new()


static func build() -> Theme:
	var u := tuning()
	var th := Theme.new()
	th.default_font = body_font()
	th.default_font_size = u.font_body

	# --- Button ---------------------------------------------------------------
	# Pointed lacquer plates: idle = raised panel, hover = dark jade, focus =
	# jade with a gold rim and glow (drawn over the state box, under the text).
	th.set_stylebox("normal", "Button", button_box(u.color_panel_raised, Color(u.color_gold, 0.35), u))
	th.set_stylebox("hover", "Button", button_box(u.color_jade_dark, u.color_gold, u))
	var pressed := button_box(u.color_gold, u.color_gold_light, u)
	pressed.content_margin_top += 3
	pressed.content_margin_bottom -= 3
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", button_box(Color(u.color_panel_raised, 0.5), Color(u.color_disabled, 0.5), u))
	var focus := button_box(u.color_jade, u.color_gold, u)
	focus.glow_color = Color(u.color_jade, u.focus_glow_alpha)
	focus.glow_size = u.focus_glow_size
	th.set_stylebox("focus", "Button", focus)
	th.set_font("font", "Button", button_font())
	th.set_font_size("font_size", "Button", u.font_button)
	th.set_constant("outline_size", "Button", 0)
	th.set_color("font_outline_color", "Button", u.color_outline)
	th.set_color("font_color", "Button", u.color_text)
	th.set_color("font_hover_color", "Button", u.color_gold_light)
	th.set_color("font_focus_color", "Button", u.color_text_on_jade)
	th.set_color("font_pressed_color", "Button", u.color_text_on_jade)
	th.set_color("font_hover_pressed_color", "Button", u.color_text_on_jade)
	th.set_color("font_disabled_color", "Button", u.color_disabled)

	# "RowButton": square-ended full-width list rows (controls screen).
	th.set_type_variation("RowButton", "Button")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var rb := (th.get_stylebox(st, "Button") as LacquerBox).duplicate() as LacquerBox
		rb.point = 0.0
		rb.corner_cut = u.corner_radius
		rb.glow_size = 0.0
		th.set_stylebox(st, "RowButton", rb)

	# --- Labels -----------------------------------------------------------------
	th.set_color("font_color", "Label", u.color_text)
	th.set_color("font_outline_color", "Label", u.color_outline)
	th.set_constant("outline_size", "Label", u.outline_text)
	th.set_font_size("font_size", "Label", u.font_body)

	# Title: bone display type on a jade drop shadow.
	th.set_type_variation("TitleLabel", "Label")
	th.set_font("font", "TitleLabel", title_font())
	th.set_font_size("font_size", "TitleLabel", u.font_title)
	th.set_constant("outline_size", "TitleLabel", 0)
	th.set_color("font_color", "TitleLabel", u.color_text)
	th.set_color("font_shadow_color", "TitleLabel", u.color_jade)
	th.set_constant("shadow_offset_x", "TitleLabel", 0)
	th.set_constant("shadow_offset_y", "TitleLabel", u.title_shadow_offset)
	th.set_constant("shadow_outline_size", "TitleLabel", 0)

	th.set_type_variation("HeaderLabel", "Label")
	th.set_font("font", "HeaderLabel", display_font())
	th.set_font_size("font_size", "HeaderLabel", u.font_header)
	th.set_constant("outline_size", "HeaderLabel", u.outline_text)
	th.set_color("font_color", "HeaderLabel", u.color_gold)

	th.set_type_variation("HintLabel", "Label")
	th.set_font_size("font_size", "HintLabel", u.font_hint)
	th.set_color("font_color", "HintLabel", u.color_text_dim)
	th.set_constant("outline_size", "HintLabel", maxi(u.outline_text - 2, 2))

	# --- Prompt labels (RichTextLabel twins of the labels above) ---------------
	for v: Array in [[&"PromptText", u.font_body, u.color_text, u.outline_text],
			[&"HintPrompt", u.font_hint, u.color_text_dim, maxi(u.outline_text - 2, 2)],
			[&"HeaderPrompt", u.font_header, u.color_gold, u.outline_text]]:
		th.set_type_variation(v[0], "RichTextLabel")
		th.set_font_size("normal_font_size", v[0], v[1])
		th.set_color("default_color", v[0], v[2])
		th.set_constant("outline_size", v[0], v[3])
		th.set_color("font_outline_color", v[0], u.color_outline)
	th.set_font("normal_font", "HeaderPrompt", display_font())

	# --- Panels -----------------------------------------------------------------
	# Lacquer card, gold frame and inner line; PanelBox frames in jade.
	var panel := panel_box(u.color_gold, u)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_type_variation("PanelBox", "PanelContainer")
	th.set_stylebox("panel", "PanelBox", panel_box(u.color_jade, u))
	th.set_stylebox("panel", "Panel", panel)

	# --- Text fields ----------------------------------------------------------------
	var field := panel_box(Color(u.color_gold, 0.35), u)
	field.bg_color = u.color_lacquer
	field.inner_line_color = Color.TRANSPARENT
	field.content_margin_left = 14
	field.content_margin_right = 14
	field.content_margin_top = 6
	field.content_margin_bottom = 6
	th.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate() as LacquerBox
	field_focus.border_color = u.color_jade
	th.set_stylebox("focus", "LineEdit", field_focus)
	var field_off := field.duplicate() as LacquerBox
	field_off.border_color = Color(u.color_disabled, 0.5)
	th.set_stylebox("read_only", "LineEdit", field_off)
	th.set_color("font_color", "LineEdit", u.color_text)
	th.set_color("font_placeholder_color", "LineEdit", Color(u.color_text_dim, 0.7))
	th.set_color("caret_color", "LineEdit", u.color_gold)
	th.set_color("selection_color", "LineEdit", Color(u.color_jade, 0.45))
	th.set_color("font_selected_color", "LineEdit", u.color_text)

	# --- Containers / scroll ------------------------------------------------------
	th.set_constant("separation", "VBoxContainer", u.list_separation)
	th.set_constant("separation", "HBoxContainer", u.list_separation)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = u.color_gold
	grabber.set_corner_radius_all(4)
	th.set_stylebox("grabber", "VScrollBar", grabber)
	th.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	th.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(u.color_lacquer, 0.7)
	track.content_margin_left = 3
	track.content_margin_right = 3
	th.set_stylebox("scroll", "VScrollBar", track)
	return th


## A pointed button plate.
static func button_box(bg: Color, border: Color, u: UiTuning) -> LacquerBox:
	var b := LacquerBox.new()
	b.bg_color = bg
	b.border_color = border
	b.border_width = u.border_width
	b.point = u.button_point
	b.content_margin_left = 28 + u.button_point
	b.content_margin_right = 28 + u.button_point
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b


## A lacquer card framed in `border` with a faint gold inner line.
static func panel_box(border: Color, u: UiTuning) -> LacquerBox:
	var b := LacquerBox.new()
	b.bg_color = u.color_panel
	b.border_color = border
	b.border_width = u.border_width
	b.corner_cut = u.corner_radius
	b.inner_line_color = Color(u.color_gold, u.panel_inner_line_alpha)
	b.inner_line_inset = u.panel_inner_line_inset
	b.set_content_margin_all(20)
	return b


# --- Fonts ---------------------------------------------------------------------
static var _fonts := {}


## `path` wrapped with the engine's default font as fallback: the bundled
## fonts are Latin only (display subset), online names may be any script.
static func _font_file(path: String) -> Font:
	var f: Font = load(path) as Font if ResourceLoader.exists(path) else null
	if f == null:
		return ThemeDB.fallback_font
	var v := FontVariation.new()
	v.base_font = f
	v.fallbacks = [ThemeDB.fallback_font]
	return v


## Dela Gothic One: titles, headers, HUD names / timer / banners.
static func display_font() -> Font:
	if not _fonts.has(&"display"):
		_fonts[&"display"] = _font_file(tuning().font_display_path)
	return _fonts[&"display"]


## Saira Semi Condensed SemiBold: body text.
static func body_font() -> Font:
	if not _fonts.has(&"body"):
		_fonts[&"body"] = _font_file(tuning().font_body_path)
	return _fonts[&"body"]


## Saira Bold, letter-spaced: buttons and tabs.
static func button_font() -> Font:
	if not _fonts.has(&"button"):
		var v := FontVariation.new()
		v.base_font = _font_file(tuning().font_bold_path)
		v.spacing_glyph = tuning().font_button_spacing
		_fonts[&"button"] = v
	return _fonts[&"button"]


## The display font, letter-spaced for the title.
static func title_font() -> Font:
	if not _fonts.has(&"title"):
		var v := FontVariation.new()
		v.base_font = display_font()
		v.spacing_glyph = tuning().font_title_spacing
		v.spacing_top = tuning().font_title_trim_top
		v.spacing_bottom = tuning().font_title_trim_bottom
		_fonts[&"title"] = v
	return _fonts[&"title"]
