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

const FONT_PATH := "res://assets/fonts/promptfont/promptfont.ttf"

## Face button -> index into the style's face colours (bottom, right, left, top).
const FACE_INDEX := {JOY_BUTTON_A: 0, JOY_BUTTON_B: 1, JOY_BUTTON_X: 2, JOY_BUTTON_Y: 3}

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


## BBCode drawing one glyph at `size` px (the font's own glyph, tinted, or a
## text keycap). No outline: the label's would fill the glyph's cutouts.
static func bbcode(g: Dictionary, style: Style, size: int, u: UiTuning) -> String:
	if g.has("cp"):
		return "[outline_size=0][font=%s][font_size=%d][color=#%s]%s[/color][/font_size][/font][/outline_size]" % [
			FONT_PATH, size, color_of(g, style, u).to_html(), String.chr(g["cp"])]
	var text := escape(str(g.get("text", "")))
	if style == Style.KEYBOARD and text != "—":
		return "[outline_size=0][font_size=%d][bgcolor=#%s][color=#%s] %s [/color][/bgcolor][/font_size][/outline_size]" % [
			roundi(size * u.prompt_keycap_text_scale), u.prompt_key_color.to_html(),
			u.prompt_keycap_text_color.to_html(), key_name(text)]
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
