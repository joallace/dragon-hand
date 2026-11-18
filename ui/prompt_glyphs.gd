class_name PromptGlyphs
extends RefCounted
## Button prompt glyphs: which Promptfont character draws a binding (a pad
## button, trigger or key) in a given style, and the BBCode that draws it in
## a RichTextLabel (PromptLabel). The Prompts autoload picks the style and
## device; this file is the static tables and nothing else.
##
## Font: Promptfont v1.10 by Yukari Hafner (assets/fonts/promptfont/,
## SIL Open Font License 1.1, see LICENSE.txt there). Each glyph is a filled
## shape with its label cut out, one em wide, so it takes a [color] tint.
##
## Pad buttons are positional (JOY_BUTTON_A = the bottom face button), so the
## Nintendo style labels the bottom one "B" and the right one "A".
## Keys without a glyph (numpad, media keys...) are drawn as a text keycap.

enum Style { KEYBOARD, XBOX, PLAYSTATION, NINTENDO }
## Backdrop shape drawn behind a prompt by PromptLabel (gamepad badges and
## multi-character text keycaps; Promptfont keycaps use a font outline).
enum Badge { NONE, CIRCLE, PILL, ROUNDED_RECT, KEYCAP_TEXT }

const FONT_PATH := "res://assets/fonts/promptfont/promptfont.ttf"
const PBG_TAG := "pbg"
const _FULL_CORNER := 9999
const _METRIC_SIZE := 256
const _FALLBACK_INK_RECT := Rect2(0.1, -0.69, 0.8, 0.8)
const _FALLBACK_INK_RADIUS := 0.4

## Face button -> index into the style's face colours (bottom, right, left, top).
const FACE_INDEX := {JOY_BUTTON_A: 0, JOY_BUTTON_B: 1, JOY_BUTTON_X: 2, JOY_BUTTON_Y: 3}

## Non-circular gamepad glyphs: capsule pills and rounded-rect shoulders /
## triggers / touchpad. Every other gamepad glyph sits on a circular badge.
const _PILL_CPS: Array[int] = [0x2208, 0x2206, 0x21F9, 0x21BE, 0x21BF]
const _ROUNDED_RECT_CPS: Array[int] = [
	0x2198, 0x2199, 0x21B0, 0x21B1, 0x219C, 0x219D,
	0x2196, 0x2197, 0x21B2, 0x21B3, 0x219A, 0x219B,
	0x2207,
]

static var _ink_cache: Dictionary = {}

const _XBOX_BUTTONS := {
	JOY_BUTTON_A: 0x21D3, JOY_BUTTON_B: 0x21D2, JOY_BUTTON_X: 0x21D0, JOY_BUTTON_Y: 0x21D1,
	JOY_BUTTON_LEFT_SHOULDER: 0x2198, JOY_BUTTON_RIGHT_SHOULDER: 0x2199,
	JOY_BUTTON_START: 0x21FB, JOY_BUTTON_BACK: 0x21FA, JOY_BUTTON_GUIDE: 0x21F9,
	JOY_BUTTON_LEFT_STICK: 0x21BA, JOY_BUTTON_RIGHT_STICK: 0x21BB,
	JOY_BUTTON_DPAD_UP: 0x227B, JOY_BUTTON_DPAD_DOWN: 0x227D,
	JOY_BUTTON_DPAD_LEFT: 0x227A, JOY_BUTTON_DPAD_RIGHT: 0x227C,
}
const _PLAYSTATION_BUTTONS := {
	JOY_BUTTON_A: 0x21E3, JOY_BUTTON_B: 0x21E2, JOY_BUTTON_X: 0x21E0, JOY_BUTTON_Y: 0x21E1,
	JOY_BUTTON_LEFT_SHOULDER: 0x21B0, JOY_BUTTON_RIGHT_SHOULDER: 0x21B1,
	JOY_BUTTON_START: 0x2208, JOY_BUTTON_BACK: 0x2206, JOY_BUTTON_GUIDE: 0x21F9,
	JOY_BUTTON_LEFT_STICK: 0x21BA, JOY_BUTTON_RIGHT_STICK: 0x21BB,
	JOY_BUTTON_DPAD_UP: 0x219F, JOY_BUTTON_DPAD_DOWN: 0x21A1,
	JOY_BUTTON_DPAD_LEFT: 0x219E, JOY_BUTTON_DPAD_RIGHT: 0x21A0,
	JOY_BUTTON_TOUCHPAD: 0x2207,
}
const _NINTENDO_BUTTONS := {
	JOY_BUTTON_A: 0x21D2, JOY_BUTTON_B: 0x21D3, JOY_BUTTON_X: 0x21D1, JOY_BUTTON_Y: 0x21D0,
	JOY_BUTTON_LEFT_SHOULDER: 0x219C, JOY_BUTTON_RIGHT_SHOULDER: 0x219D,
	JOY_BUTTON_START: 0x21FE, JOY_BUTTON_BACK: 0x21FD, JOY_BUTTON_GUIDE: 0x21F9,
	JOY_BUTTON_LEFT_STICK: 0x21BA, JOY_BUTTON_RIGHT_STICK: 0x21BB,
	JOY_BUTTON_DPAD_UP: 0x219F, JOY_BUTTON_DPAD_DOWN: 0x21A1,
	JOY_BUTTON_DPAD_LEFT: 0x219E, JOY_BUTTON_DPAD_RIGHT: 0x21A0,
}
## Triggers per style: [left, right].
const _TRIGGERS := {
	Style.XBOX: [0x2196, 0x2197],
	Style.PLAYSTATION: [0x21B2, 0x21B3],
	Style.NINTENDO: [0x219A, 0x219B],
}
## Shapes that aren't one binding: [Xbox, others].
const _SHAPES := {
	"lstick": [0x21CB, 0x21CB], "rstick": [0x21CC, 0x21CC],
	"lstick_up": [0x21BE, 0x21BE], "rstick_up": [0x21BF, 0x21BF],
	"dpad": [0x2284, 0x21CE],
	"dpad_up_down": [0x227F, 0x21A3], "dpad_left_right": [0x227E, 0x21A2],
}
const _NAMED_KEYS := {
	KEY_ENTER: 0x242E, KEY_KP_ENTER: 0x242E, KEY_ESCAPE: 0x242F, KEY_TAB: 0x242B,
	KEY_SPACE: 0x243A, KEY_BACKSPACE: 0x242D, KEY_SHIFT: 0x2429, KEY_CTRL: 0x2427,
	KEY_ALT: 0x2428, KEY_META: 0x242A, KEY_CAPSLOCK: 0x242C, KEY_INSERT: 0x2434,
	KEY_DELETE: 0x2437, KEY_HOME: 0x2435, KEY_END: 0x2438, KEY_PAGEUP: 0x2436,
	KEY_PAGEDOWN: 0x2439, KEY_PRINT: 0x2430, KEY_SCROLLLOCK: 0x2431, KEY_PAUSE: 0x2432,
	KEY_NUMLOCK: 0x2433, KEY_LEFT: 0x23F4, KEY_RIGHT: 0x23F5, KEY_UP: 0x23F6, KEY_DOWN: 0x23F7,
}
## Printable keys (Godot keycodes = their ASCII code) map onto the font's
## fullwidth keycaps: U+FEE0 + code (U+FF01 is "!").
const _PRINTABLE_FIRST := 0x21
const _PRINTABLE_LAST := 0x7E
const _PRINTABLE_BASE := 0xFEE0
const _F1_GLYPH := 0x2460
const _NUMPAD_WORDS := {"Add": "+", "Subtract": "-", "Multiply": "*", "Divide": "/", "Period": "."}
const _F_KEYS := 12

## Prompt words shared by every screen ({name} in a template): [pad, key].
## Each side is a binding Dictionary (as in Bindings), a list of them drawn
## side by side, a "shape" (_SHAPES), or "@ACTION" for the player's binding.
const UI_TOKENS := {
	"accept": [{"t": "btn", "i": JOY_BUTTON_A}, {"t": "key", "i": KEY_ENTER}],
	"back": [{"t": "btn", "i": JOY_BUTTON_B}, {"t": "key", "i": KEY_ESCAPE}],
	"start": [{"t": "btn", "i": JOY_BUTTON_START}, {"t": "key", "i": KEY_ENTER}],
	"options": [{"t": "btn", "i": JOY_BUTTON_Y}, {"t": "key", "i": KEY_TAB}],
	"seat": [{"t": "btn", "i": JOY_BUTTON_X}, "@HEAVY"],
	"forget": [{"t": "btn", "i": JOY_BUTTON_X}, {"t": "key", "i": KEY_DELETE}],
	"tab_prev": [{"t": "btn", "i": JOY_BUTTON_LEFT_SHOULDER}, {"t": "key", "i": KEY_Q}],
	"tab_next": [{"t": "btn", "i": JOY_BUTTON_RIGHT_SHOULDER}, {"t": "key", "i": KEY_E}],
	"up_down": [{"t": "shape", "i": "dpad_up_down"}, [{"t": "key", "i": KEY_UP}, {"t": "key", "i": KEY_DOWN}]],
	"left_right": [{"t": "shape", "i": "dpad_left_right"},
		[{"t": "key", "i": KEY_LEFT}, {"t": "key", "i": KEY_RIGHT}]],
	"lstick": [{"t": "shape", "i": "lstick"}, {}],
	"rstick": [{"t": "shape", "i": "rstick"}, {}],
	"lstick_up": [{"t": "shape", "i": "lstick_up"}, {}],
	"rstick_up": [{"t": "shape", "i": "rstick_up"}, {}],
	"dpad": [{"t": "shape", "i": "dpad"}, {}],
}

## Sony and Nintendo USB vendor ids (Input.get_joy_info "vendor_id").
const _VENDOR_SONY := 0x054C
const _VENDOR_NINTENDO := 0x057E
const _PLAYSTATION_NAMES: Array[String] = ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]
const _NINTENDO_NAMES: Array[String] = ["nintendo", "switch", "joy-con", "joycon", "pro controller"]

## The glyph font (ResourceLoader caches it).
static func font() -> FontFile:
	return load(FONT_PATH)


## The pad style for a controller, from its USB vendor (when the platform
## reports it) or its name; Xbox when neither says otherwise.
static func detect_style(joy_name: String, vendor_id: int = 0) -> Style:
	if vendor_id == _VENDOR_SONY:
		return Style.PLAYSTATION
	if vendor_id == _VENDOR_NINTENDO:
		return Style.NINTENDO
	var n := joy_name.to_lower()
	for w in _PLAYSTATION_NAMES:
		if n.contains(w):
			return Style.PLAYSTATION
	for w in _NINTENDO_NAMES:
		if n.contains(w):
			return Style.NINTENDO
	return Style.XBOX


## The glyph for a binding: {"cp": codepoint, "face": 0..3 or -1} or, for a
## key without one, {"text": label}. Unbound ({}) -> {"text": "—"}.
static func glyph(b: Dictionary, style: Style) -> Dictionary:
	match b.get("t", ""):
		"key":
			var cp := key_codepoint(b["i"])
			return {"cp": cp, "face": -1} if cp > 0 else {"text": OS.get_keycode_string(b["i"])}
		"btn":
			var table: Dictionary = _NINTENDO_BUTTONS if style == Style.NINTENDO \
				else (_PLAYSTATION_BUTTONS if style == Style.PLAYSTATION else _XBOX_BUTTONS)
			if table.has(b["i"]):
				return {"cp": table[b["i"]], "face": FACE_INDEX.get(b["i"], -1)}
			return {"text": "Button %d" % b["i"]}
		"axis":
			var pair: Array = _TRIGGERS.get(style, _TRIGGERS[Style.XBOX])
			match b["i"]:
				JOY_AXIS_TRIGGER_LEFT:
					return {"cp": pair[0], "face": -1}
				JOY_AXIS_TRIGGER_RIGHT:
					return {"cp": pair[1], "face": -1}
			return {"text": "Axis %d" % b["i"]}
		"shape":
			var cps: Array = _SHAPES.get(b["i"], [])
			if cps.is_empty():
				return {"text": str(b["i"])}
			return {"cp": cps[0] if style == Style.XBOX else cps[1], "face": -1}
	return {"text": "—"}


## The font's keycap for `keycode`, or 0 when it has none.
static func key_codepoint(keycode: int) -> int:
	if _NAMED_KEYS.has(keycode):
		return _NAMED_KEYS[keycode]
	if keycode >= KEY_F1 and keycode < KEY_F1 + _F_KEYS:
		return _F1_GLYPH + keycode - KEY_F1
	if keycode >= _PRINTABLE_FIRST and keycode <= _PRINTABLE_LAST:
		var cp := _PRINTABLE_BASE + (String.chr(keycode).to_upper().unicode_at(0))
		if font() != null and font().has_char(cp):
			return cp
	return 0


## The tint for a glyph in `style`.
static func color_of(g: Dictionary, style: Style, u: UiTuning) -> Color:
	if style == Style.KEYBOARD:
		return u.prompt_key_color
	var face: int = g.get("face", -1)
	var colors: PackedColorArray = u.prompt_nintendo_face_colors if style == Style.NINTENDO \
		else (u.prompt_playstation_face_colors if style == Style.PLAYSTATION else u.prompt_xbox_face_colors)
	if face >= 0 and face < colors.size():
		return colors[face]
	return u.prompt_pad_color


## Geometric badge shape for `cp` in `style` (gamepad glyphs only).
static func badge_of(cp: int, style: Style) -> Badge:
	if style == Style.KEYBOARD or cp <= 0:
		return Badge.NONE
	if cp in _ROUNDED_RECT_CPS:
		return Badge.ROUNDED_RECT
	if cp in _PILL_CPS:
		return Badge.PILL
	return Badge.CIRCLE


## Cached ink bounds {"rect": Rect2, "radius": float} in 1-em units relative to
## the glyph's baseline origin, sampled along every contour's true curves once
## per session (TrueType circles have only off-curve conic control points whose
## midpoints lie on the curve).
static func ink_metrics(cp: int) -> Dictionary:
	if _ink_cache.has(cp):
		return _ink_cache[cp]
	var f := font()
	var rids := f.get_rids() if f != null else []
	if rids.is_empty():
		return {"rect": _FALLBACK_INK_RECT, "radius": _FALLBACK_INK_RADIUS}
	var ts := TextServerManager.get_primary_interface()
	var gi := ts.font_get_glyph_index(rids[0], _METRIC_SIZE, cp, 0)
	var data := ts.font_get_glyph_contours(rids[0], _METRIC_SIZE, gi)
	var pts: PackedVector3Array = data.get("points", PackedVector3Array())
	var ends: PackedInt32Array = data.get("contours", PackedInt32Array())
	var sampled: Array[Vector2] = []
	var start := 0
	for end_idx in ends:
		_sample_contour(pts, start, end_idx, sampled)
		start = end_idx + 1
	if sampled.is_empty():
		return {"rect": _FALLBACK_INK_RECT, "radius": _FALLBACK_INK_RADIUS}
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in sampled:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var center := 0.5 * (min_p + max_p)
	var max_r := 0.0
	for p in sampled:
		max_r = maxf(max_r, p.distance_to(center))
	var inv := 1.0 / float(_METRIC_SIZE)
	var out := {"rect": Rect2(min_p * inv, (max_p - min_p) * inv), "radius": max_r * inv}
	_ink_cache[cp] = out
	return out


static func _sample_contour(pts: PackedVector3Array, start: int, end_idx: int, out: Array[Vector2]) -> void:
	var count := end_idx - start + 1
	if count <= 0 or end_idx >= pts.size():
		return
	var first_on := -1
	for k in count:
		if int(pts[start + k].z) == TextServer.CONTOUR_CURVE_TAG_ON:
			first_on = k
			break
	if first_on < 0:
		for k in count:
			var ip := start + posmod(k - 1, count)
			var ic := start + k
			var inx := start + ((k + 1) % count)
			var prev := Vector2(pts[ip].x, pts[ip].y)
			var ctrl := Vector2(pts[ic].x, pts[ic].y)
			var nxt := Vector2(pts[inx].x, pts[inx].y)
			_sample_quad(0.5 * (prev + ctrl), ctrl, 0.5 * (ctrl + nxt), out)
		return
	var ring_pts: Array[Vector2] = []
	var ring_tags := PackedInt32Array()
	for step in count:
		var idx := start + ((first_on + step) % count)
		var nxt := start + ((first_on + step + 1) % count)
		var cur_v := Vector2(pts[idx].x, pts[idx].y)
		var cur_t := int(pts[idx].z)
		ring_pts.append(cur_v)
		ring_tags.append(cur_t)
		if cur_t == TextServer.CONTOUR_CURVE_TAG_OFF_CONIC and int(pts[nxt].z) == TextServer.CONTOUR_CURVE_TAG_OFF_CONIC:
			ring_pts.append(0.5 * (cur_v + Vector2(pts[nxt].x, pts[nxt].y)))
			ring_tags.append(TextServer.CONTOUR_CURVE_TAG_ON)
	ring_pts.append(ring_pts[0])
	ring_tags.append(TextServer.CONTOUR_CURVE_TAG_ON)
	var i := 0
	var last := ring_pts.size() - 1
	while i < last:
		var p0 := ring_pts[i]
		if ring_tags[i + 1] == TextServer.CONTOUR_CURVE_TAG_ON:
			out.append(p0)
			i += 1
		elif ring_tags[i + 1] == TextServer.CONTOUR_CURVE_TAG_OFF_CONIC and i + 2 <= last:
			_sample_quad(p0, ring_pts[i + 1], ring_pts[i + 2], out)
			i += 2
		elif ring_tags[i + 1] == TextServer.CONTOUR_CURVE_TAG_OFF_CUBIC and i + 3 <= last:
			_sample_cubic(p0, ring_pts[i + 1], ring_pts[i + 2], ring_pts[i + 3], out)
			i += 3
		else:
			out.append(p0)
			i += 1


static func _sample_quad(p0: Vector2, c: Vector2, p1: Vector2, out: Array[Vector2]) -> void:
	for t: float in [0.0, 0.25, 0.5, 0.75]:
		var u := 1.0 - t
		out.append(u * u * p0 + 2.0 * u * t * c + t * t * p1)


static func _sample_cubic(p0: Vector2, c1: Vector2, c2: Vector2, p1: Vector2, out: Array[Vector2]) -> void:
	for t: float in [0.0, 0.25, 0.5, 0.75]:
		var u := 1.0 - t
		out.append(u * u * u * p0 + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * p1)


## StyleBox draw spec {"rect", "bg", "border", "border_width", "corner"} for a
## gamepad badge around `cp` drawn at baseline `origin` and `size` px.
static func badge_spec(badge: Badge, cp: int, origin: Vector2, size: int, u: UiTuning) -> Dictionary:
	var m := ink_metrics(cp)
	var ink_rect := Rect2(origin + (m["rect"] as Rect2).position * size, (m["rect"] as Rect2).size * size)
	var pad := size * u.prompt_pad_badge_padding
	var rim := maxi(roundi(size * u.prompt_pad_rim_scale), 1) if u.prompt_pad_rim_scale > 0.0 else 0
	var inner_rect: Rect2
	var corner: int
	match badge:
		Badge.CIRCLE:
			var r := float(m["radius"]) * size + pad
			inner_rect = Rect2(ink_rect.get_center() - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
			corner = _FULL_CORNER
		Badge.PILL:
			inner_rect = ink_rect.grow(pad)
			corner = _FULL_CORNER
		Badge.ROUNDED_RECT:
			inner_rect = ink_rect.grow(pad)
			var short_side := minf(ink_rect.size.x, ink_rect.size.y)
			corner = maxi(roundi(short_side * u.prompt_pad_corner_ratio + pad) + rim, 1)
		_:
			return {}
	return {
		"rect": inner_rect.grow(rim),
		"bg": u.prompt_pad_badge_color,
		"border": u.prompt_pad_rim_color,
		"border_width": rim,
		"corner": corner,
	}


## StyleBox draw spec for a multi-character text keycap ("Num 1") spanning
## `span_rect` at `cap_size` px.
static func keycap_text_spec(span_rect: Rect2, cap_size: int, u: UiTuning) -> Dictionary:
	var border_w := maxi(u.prompt_keycap_border_width, 0)
	var pad_x := cap_size * u.prompt_keycap_h_padding
	var inner := span_rect.grow_individual(pad_x, 0.0, pad_x, 0.0)
	return {
		"rect": inner.grow(border_w),
		"bg": u.prompt_key_color,
		"border": u.color_outline,
		"border_width": border_w,
		"corner": maxi(u.prompt_keycap_corner_radius + border_w, 0),
	}


## BBCode drawing one glyph at `size` px: gamepad glyphs sit on a geometric
## badge (PromptLabel draws `[pbg]`) with `[outline_size=0]`; keyboard keycaps
## get a dark outline; keys without a glyph draw as a bordered text keycap.
static func bbcode(g: Dictionary, style: Style, size: int, u: UiTuning) -> String:
	if g.has("cp"):
		var cp: int = g["cp"]
		var inner := "[font=%s][font_size=%d][color=#%s]%s[/color][/font_size][/font]" % [
			FONT_PATH, size, color_of(g, style, u).to_html(), String.chr(cp)]
		if style == Style.KEYBOARD:
			var out_sz := maxi(roundi(size * u.prompt_key_outline_scale), 1) if u.prompt_key_outline_scale > 0.0 else 0
			if out_sz > 0:
				return "[outline_size=%d][outline_color=#%s]%s[/outline_color][/outline_size]" % [
					out_sz, u.color_outline.to_html(), inner]
			return "[outline_size=0]%s[/outline_size]" % inner
		var no_outline := "[outline_size=0]%s[/outline_size]" % inner
		var badge := badge_of(cp, style)
		if badge != Badge.NONE and u.prompt_pad_badge_color.a > 0.0:
			return "[%s b=%d c=%d s=%d]%s[/%s]" % [PBG_TAG, badge, cp, size, no_outline, PBG_TAG]
		return no_outline
	var text := escape(str(g.get("text", "")))
	if style == Style.KEYBOARD and text != "—":
		var cap_size := roundi(size * u.prompt_keycap_text_scale)
		var cap := "[outline_size=0][font_size=%d][color=#%s] %s [/color][/font_size][/outline_size]" % [
			cap_size, u.prompt_keycap_text_color.to_html(), key_name(text)]
		return "[%s b=%d s=%d]%s[/%s]" % [PBG_TAG, Badge.KEYCAP_TEXT, cap_size, cap, PBG_TAG]
	return text


## A short keycap name for a key Godot calls `godot_name` ("Kp 1" -> "Num 1").
static func key_name(godot_name: String) -> String:
	if not godot_name.begins_with("Kp "):
		return godot_name
	var rest := godot_name.substr(3)
	return "Num " + str(_NUMPAD_WORDS.get(rest, rest))


## Literal text made safe for BBCode.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")
