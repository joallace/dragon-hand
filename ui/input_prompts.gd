extends Node
## Autoload "Prompts": which device the button legends show, and the BBCode
## for a legend template. Presentation only: the sim never reads it.
##
## Shared legends (menu footers, tab bars, How to Play) follow the last
## device anyone used: a key press switches them to the keyboard, a pad
## button or a stick pushed past Tuning.ui.prompt_pad_axis_threshold to that
## pad (mouse input never switches). Settings > Controls can pin them
## (Bindings.prompt_device) and force a pad style (Bindings.pad_style);
## otherwise each pad's style comes from its vendor / name (PromptGlyphs).
## A per-player legend (a lobby card) passes its own kind and device.
##
## Templates are plain text with tokens (PromptLabel renders them):
##   {accept}        a shared prompt word (PromptGlyphs.UI_TOKENS)
##   {@LIGHT}        the binding of a Bindings action for the profile `slot`
##   {pad:back}      always the pad side ({key:...} the keyboard side)
## e.g. "{accept} select     {back} back".

signal changed

const _TOKEN_PATTERN := "\\{(?:(pad|key):)?(@?[A-Za-z_]+)\\}"

## Last device kind used (Bindings.Kind) and the last pad's device id.
var last_kind: int = Bindings.Kind.KEYBOARD
var last_pad: int = -1

var _token_re := RegEx.create_from_string(_TOKEN_PATTERN)
## device id -> PromptGlyphs.Style, while that pad stays connected.
var _detected: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# window_input fires before any node's _input, so screens that swallow
	# events still switch the legends.
	get_tree().root.window_input.connect(note_event)
	Bindings.prompts_changed.connect(changed.emit)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		last_kind = Bindings.Kind.PAD
		last_pad = pads[0]


## Follow `e` if it says which device the player is on.
func note_event(e: InputEvent) -> void:
	var kind := -1
	var device := last_pad
	if e is InputEventKey and e.pressed:
		kind = Bindings.Kind.KEYBOARD
	elif e is InputEventJoypadButton and e.pressed:
		kind = Bindings.Kind.PAD
		device = e.device
	elif e is InputEventJoypadMotion and absf(e.axis_value) >= UiTheme.tuning().prompt_pad_axis_threshold:
		kind = Bindings.Kind.PAD
		device = e.device
	if kind < 0 or (kind == last_kind and device == last_pad):
		return
	# Redraw only when the shared legends' style changes (not while pinned,
	# nor between two pads of one style).
	var before := style_for()
	last_kind = kind
	last_pad = device
	if style_for() != before:
		changed.emit()


## The device kind the shared legends show.
func kind() -> int:
	match Bindings.prompt_device:
		Bindings.PromptDevice.KEYBOARD:
			return Bindings.Kind.KEYBOARD
		Bindings.PromptDevice.PAD:
			return Bindings.Kind.PAD
	return last_kind


## Glyph style for pad `device` (-1: the last pad used).
func pad_style(device: int = -1) -> PromptGlyphs.Style:
	match Bindings.pad_style:
		Bindings.PadStyle.XBOX:
			return PromptGlyphs.Style.XBOX
		Bindings.PadStyle.PLAYSTATION:
			return PromptGlyphs.Style.PLAYSTATION
		Bindings.PadStyle.NINTENDO:
			return PromptGlyphs.Style.NINTENDO
	var d := device if device >= 0 else last_pad
	if d < 0:
		return PromptGlyphs.Style.XBOX
	if not d in Input.get_connected_joypads():
		return PromptGlyphs.Style.XBOX  # a synthetic device (tests, replays)
	if not _detected.has(d):
		var info := Input.get_joy_info(d)
		_detected[d] = PromptGlyphs.detect_style(Input.get_joy_name(d), str(info.get("vendor_id", "0")).to_int())
	return _detected[d]


## Style for a device kind (-1: the shared one) and pad device.
func style_for(kind_: int = -1, device: int = -1) -> PromptGlyphs.Style:
	var k := kind_ if kind_ >= 0 else kind()
	return PromptGlyphs.Style.KEYBOARD if k == Bindings.Kind.KEYBOARD else pad_style(device)


## BBCode for `template` with glyphs `font_size` px tall text around them.
## `kind_` / `device`: whose glyphs (-1: the shared legend's); `slot`: the
## Bindings profile for {@ACTION} tokens.
func format(template: String, font_size: int, kind_: int = -1, device: int = -1, slot: int = 0) -> String:
	var k := kind_ if kind_ >= 0 else kind()
	var size := roundi(font_size * UiTheme.tuning().prompt_glyph_scale)
	var out := ""
	var at := 0
	for m in _token_re.search_all(template):
		out += PromptGlyphs.escape(template.substr(at, m.get_start() - at))
		var side := m.get_string(1)
		var tk := k
		if side == "pad":
			tk = Bindings.Kind.PAD
		elif side == "key":
			tk = Bindings.Kind.KEYBOARD
		out += _token(m.get_string(2), tk, device, slot, size)
		at = m.get_end()
	return out + PromptGlyphs.escape(template.substr(at))


func _token(name: String, kind_: int, device: int, slot: int, size: int) -> String:
	var spec: Variant
	if name.begins_with("@"):
		spec = name
	elif PromptGlyphs.UI_TOKENS.has(name):
		spec = PromptGlyphs.UI_TOKENS[name][0 if kind_ == Bindings.Kind.PAD else 1]
	else:
		return PromptGlyphs.escape("{%s}" % name)
	if spec is String:
		spec = Bindings.get_binding(slot, kind_, (spec as String).substr(1))
	var style := style_for(kind_, device)
	var u := UiTheme.tuning()
	if spec is Array:
		var parts := ""
		for b: Dictionary in spec:
			parts += PromptGlyphs.bbcode(PromptGlyphs.glyph(b, style), style, size, u)
		return parts
	return PromptGlyphs.bbcode(PromptGlyphs.glyph(spec, style), style, size, u)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_detected.erase(device)
	if connected or device != last_pad:
		return
	# The pad on screen left: show another one's glyphs, or the keyboard's.
	var pads := Input.get_connected_joypads()
	last_pad = pads[0] if not pads.is_empty() else -1
	if pads.is_empty():
		last_kind = Bindings.Kind.KEYBOARD
	changed.emit()
