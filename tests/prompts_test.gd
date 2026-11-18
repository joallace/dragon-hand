extends Node
## Headless test of the button prompts: PromptGlyphs tables (styles, keys,
## pad brand detection), the Prompts autoload (last device used, settings
## overrides, template formatting), PromptLabel redraws, the preferences'
## save/load in controls.cfg, the Controls page rows and the lobby (shared
## footer follows the last device, a player's card keeps their own).
## Leaves user://controls.cfg and the preferences as it found them.

const XBOX_A := 0x21D3
const XBOX_B := 0x21D2
const PS_CROSS := 0x21E3
const PS_L2 := 0x21B2
const KEY_J_CAP := 0xFF2A
## Pad ids no real controller has: Prompts treats them as Xbox pads, so a
## pad plugged into the machine can't change the expected glyphs.
const PAD_A := 90
const PAD_B := 91
const ENTER_CAP := 0x242E
const ESC_CAP := 0x242F

var _fails := 0
var _cfg_existed := false
var _cfg_bytes := PackedByteArray()


func _ready() -> void:
	_backup_cfg()
	# Default bindings and preferences, whatever the user saved.
	for s in Bindings.SLOT_COUNT:
		Bindings.reset_defaults(s)
	Bindings.set_prompt_prefs(Bindings.PromptDevice.AUTO, Bindings.PadStyle.AUTO)
	_test_glyph_tables()
	await _test_device_tracking()
	_test_overrides()
	_test_format()
	await _test_prompt_label()
	_test_prefs_saved()
	await _test_controls_rows()
	await _test_lobby()
	_restore_cfg()
	print("PROMPTS %s (%d failures)" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func check(cond: bool, what: String) -> void:
	print("%s: %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func send(e: InputEvent) -> void:
	Input.parse_input_event(e)
	await frames(2)


func pad_press(device: int, button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = true
	return e


func key_press(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e


func stick(device: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = JOY_AXIS_LEFT_X
	e.axis_value = value
	return e


func _has(bb: String, cp: int) -> bool:
	return bb.contains(String.chr(cp))


# --- Tests -----------------------------------------------------------------------

func _test_glyph_tables() -> void:
	var S := PromptGlyphs.Style
	var a := {"t": "btn", "i": JOY_BUTTON_A}
	check(PromptGlyphs.glyph(a, S.XBOX)["cp"] == XBOX_A, "Xbox: bottom face button is A")
	check(PromptGlyphs.glyph(a, S.PLAYSTATION)["cp"] == PS_CROSS, "PlayStation: bottom face button is the cross")
	check(PromptGlyphs.glyph(a, S.NINTENDO)["cp"] == XBOX_B,
			"Nintendo: bottom face button reads B (positional buttons)")
	check(PromptGlyphs.glyph({"t": "axis", "i": JOY_AXIS_TRIGGER_LEFT, "s": 1}, S.PLAYSTATION)["cp"] == PS_L2,
			"PlayStation: left trigger is L2")
	check(PromptGlyphs.glyph(a, S.XBOX)["face"] == 0 and PromptGlyphs.glyph(
			{"t": "btn", "i": JOY_BUTTON_START}, S.XBOX)["face"] == -1, "face buttons carry their colour slot")
	check(PromptGlyphs.key_codepoint(KEY_J) == KEY_J_CAP and PromptGlyphs.key_codepoint(KEY_ENTER) == ENTER_CAP
			and PromptGlyphs.key_codepoint(KEY_F5) == 0x2464 and PromptGlyphs.key_codepoint(KEY_COMMA) == 0xFF0C,
			"keys: letters, named keys, F-keys and punctuation have keycaps")
	check(PromptGlyphs.font().has_char(PromptGlyphs.key_codepoint(KEY_Z)), "the font draws the Z keycap")
	var kp := PromptGlyphs.glyph({"t": "key", "i": KEY_KP_1}, S.KEYBOARD)
	check(not kp.has("cp") and PromptGlyphs.key_name(kp["text"]) == "Num 1",
			"a numpad key has no glyph: text keycap 'Num 1'")
	check(PromptGlyphs.glyph({}, S.XBOX) == {"text": "—"}, "unbound: a dash")
	check(PromptGlyphs.detect_style("Xbox Wireless Controller") == S.XBOX
			and PromptGlyphs.detect_style("PS5 Controller") == S.PLAYSTATION
			and PromptGlyphs.detect_style("Wireless Controller", 0x054C) == S.PLAYSTATION
			and PromptGlyphs.detect_style("Nintendo Switch Pro Controller") == S.NINTENDO
			and PromptGlyphs.detect_style("Generic USB Joystick") == S.XBOX,
			"pad style from vendor id / name, Xbox otherwise")
	var u := UiTheme.tuning()
	check(PromptGlyphs.color_of({"cp": XBOX_A, "face": 0}, S.XBOX, u) == u.prompt_xbox_face_colors[0]
			and PromptGlyphs.color_of({"cp": 0x2198, "face": -1}, S.XBOX, u) == u.prompt_pad_color
			and PromptGlyphs.color_of({"cp": XBOX_B, "face": 0}, S.NINTENDO, u) == u.prompt_pad_color,
			"colours: brand face colours, neutral elsewhere and for Nintendo")
	var bb := PromptGlyphs.bbcode({"cp": XBOX_A, "face": 0}, S.XBOX, 30, u)
	check(bb.contains("[color=#%s]" % u.prompt_xbox_face_colors[0].to_html()) and bb.contains("[font_size=30]")
			and bb.contains(PromptGlyphs.FONT_PATH) and bb.contains("[outline_size=0]")
			and bb.contains("[%s " % PromptGlyphs.PBG_TAG),
			"pad glyph BBCode: tinted, sized, in Promptfont, no outline, wrapped for its badge")
	var B := PromptGlyphs.Badge
	check(PromptGlyphs.badge_of(XBOX_A, S.XBOX) == B.CIRCLE
			and PromptGlyphs.badge_of(PS_CROSS, S.PLAYSTATION) == B.CIRCLE
			and PromptGlyphs.badge_of(0x2198, S.XBOX) == B.ROUNDED_RECT
			and PromptGlyphs.badge_of(PS_L2, S.PLAYSTATION) == B.ROUNDED_RECT
			and PromptGlyphs.badge_of(0x2208, S.PLAYSTATION) == B.PILL
			and PromptGlyphs.badge_of(0x21BE, S.XBOX) == B.PILL
			and PromptGlyphs.badge_of(KEY_J_CAP, S.KEYBOARD) == B.NONE,
			"badge shapes: circles, pills and rounded rects on pads; none on keyboard")
	var key_bb := PromptGlyphs.bbcode({"cp": KEY_J_CAP, "face": -1}, S.KEYBOARD, 30, u)
	check(key_bb.contains("[outline_size=%d]" % roundi(30 * u.prompt_key_outline_scale))
			and key_bb.contains("[outline_color=#%s]" % u.color_outline.to_html())
			and not key_bb.contains("[%s " % PromptGlyphs.PBG_TAG),
			"keyboard glyph BBCode: dark outline, no gamepad badge")
	var num_bb := PromptGlyphs.bbcode({"text": "Kp 1"}, S.KEYBOARD, 30, u)
	check(num_bb.contains("Num 1") and num_bb.contains("[%s b=%d " % [PromptGlyphs.PBG_TAG, B.KEYCAP_TEXT]),
			"text keycap BBCode: wrapped for a bordered keycap backdrop")
	var m_a := PromptGlyphs.ink_metrics(XBOX_A)
	var ink_a: Rect2 = m_a["rect"]
	check(ink_a.size.x > 0.74 and ink_a.size.x < 0.77 and absf(ink_a.size.x - ink_a.size.y) < 0.01,
			"ink_metrics samples the outer button circle (~0.756 em), not just the inner cutout")
	var round_ok := true
	for cp: int in [XBOX_B, PS_CROSS, 0x21E2, 0x21E1, 0x21FB, 0x21FE]:
		var mc := PromptGlyphs.ink_metrics(cp)
		round_ok = round_ok and absf(float(mc["radius"]) - float(m_a["radius"])) < 0.01 \
			and (mc["rect"] as Rect2).get_center().distance_to(ink_a.get_center()) < 0.01
	check(round_ok, "every round face/system button shares one badge center and radius")
	var spec_a := PromptGlyphs.badge_spec(B.CIRCLE, XBOX_A, Vector2(40, 30), 30, u)
	var rect_a: Rect2 = spec_a["rect"]
	var rim_a: int = spec_a["border_width"]
	var ink_px := Rect2(Vector2(40, 30) + ink_a.position * 30.0, ink_a.size * 30.0)
	var charcoal_ring := (ink_px.position.x - rect_a.position.x) - float(rim_a)
	check(is_equal_approx(rect_a.size.x, rect_a.size.y)
			and rect_a.get_center().distance_to(ink_px.get_center()) < 0.05
			and charcoal_ring > 3.0 and spec_a["bg"] == u.prompt_pad_badge_color
			and spec_a["border"] == u.prompt_pad_rim_color and rim_a >= 1,
			"circle badge: centered charcoal disc (> 3 px outside ink) + thin black rim")
	var m_lt := PromptGlyphs.ink_metrics(0x2196)
	var spec_lt := PromptGlyphs.badge_spec(B.ROUNDED_RECT, 0x2196, Vector2.ZERO, 30, u)
	var lt_px := Rect2((m_lt["rect"] as Rect2).position * 30.0, (m_lt["rect"] as Rect2).size * 30.0)
	check((spec_lt["rect"] as Rect2).encloses(lt_px.grow(3.0)),
			"trigger badge encloses the full trigger glyph by > 3 px on all sides")
	var spec_lb := PromptGlyphs.badge_spec(B.ROUNDED_RECT, 0x2198, Vector2.ZERO, 30, u)
	check((spec_lb["rect"] as Rect2).size.x > (spec_lb["rect"] as Rect2).size.y,
			"shoulder badge: wide rounded rectangle")


func _test_device_tracking() -> void:
	var fired := [0]
	var count := func() -> void: fired[0] += 1
	Prompts.changed.connect(count)
	await send(key_press(KEY_A))
	check(Prompts.kind() == Bindings.Kind.KEYBOARD, "a key press: keyboard legends")
	fired[0] = 0
	await send(pad_press(PAD_A, JOY_BUTTON_A))
	check(Prompts.kind() == Bindings.Kind.PAD and Prompts.last_pad == PAD_A and fired[0] == 1,
			"a pad button: pad legends, `changed` once")
	await send(key_press(KEY_A))
	await send(stick(PAD_A, 0.2))
	check(Prompts.kind() == Bindings.Kind.KEYBOARD, "a stick inside the threshold (drift) doesn't switch")
	await send(stick(PAD_A, 0.9))
	check(Prompts.kind() == Bindings.Kind.PAD, "a stick pushed past the threshold switches to the pad")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	await send(click)
	check(Prompts.kind() == Bindings.Kind.PAD, "the mouse doesn't switch")
	fired[0] = 0
	await send(pad_press(PAD_B, JOY_BUTTON_B))
	check(Prompts.last_pad == PAD_B and fired[0] == 0, "another pad of the same style: no redraw")
	Prompts.changed.disconnect(count)


func _test_overrides() -> void:
	Prompts.note_event(pad_press(PAD_A, JOY_BUTTON_A))
	Bindings.set_prompt_prefs(Bindings.PromptDevice.KEYBOARD, Bindings.PadStyle.AUTO)
	check(Prompts.kind() == Bindings.Kind.KEYBOARD, "Prompts: Keyboard pins the legends to the keyboard")
	Bindings.set_prompt_prefs(Bindings.PromptDevice.PAD, Bindings.PadStyle.PLAYSTATION)
	Prompts.note_event(key_press(KEY_A))
	check(Prompts.kind() == Bindings.Kind.PAD and Prompts.style_for() == PromptGlyphs.Style.PLAYSTATION,
			"Prompts: Gamepad + PlayStation style hold through key presses")
	check(_has(Prompts.format("{accept}", 20), PS_CROSS), "the forced style draws PlayStation glyphs")
	var fired := [0]
	var count := func() -> void: fired[0] += 1
	Prompts.changed.connect(count)
	Prompts.note_event(pad_press(PAD_A, JOY_BUTTON_A))
	Prompts.note_event(key_press(KEY_A))
	check(fired[0] == 0, "pinned: switching devices doesn't redraw")
	Prompts.changed.disconnect(count)
	Bindings.set_prompt_prefs(Bindings.PromptDevice.AUTO, Bindings.PadStyle.AUTO)
	check(Prompts.kind() == Bindings.Kind.KEYBOARD, "back to Auto: the last device used again")


func _test_format() -> void:
	var K := Bindings.Kind
	var key_bb := Prompts.format("{accept} select  {back} back", 20, K.KEYBOARD)
	check(_has(key_bb, ENTER_CAP) and _has(key_bb, ESC_CAP) and key_bb.contains(" select  "),
			"keyboard: Enter / Esc keycaps around the words")
	var pad_bb := Prompts.format("{accept} select", 20, K.PAD)
	check(_has(pad_bb, XBOX_A) and not _has(pad_bb, ENTER_CAP), "pad: the A button")
	check(_has(Prompts.format("{@LIGHT}", 20, K.KEYBOARD, -1, 0), KEY_J_CAP), "{@LIGHT}: P1's keyboard key (J)")
	check(Prompts.format("{@LIGHT}", 20, K.KEYBOARD, -1, 1).contains("Num 1"),
			"{@LIGHT} for profile 2: its numpad key, as a text keycap")
	check(_has(Prompts.format("{pad:back}", 20, K.KEYBOARD), XBOX_B), "{pad:...} is the pad side on the keyboard")
	check(_has(Prompts.format("{seat}", 20, K.KEYBOARD), 0xFF29), "{seat} on the keyboard: P1's HEAVY key (I)")
	var lit := Prompts.format("a [b] {nope} %d", 20, K.PAD)
	check(lit.begins_with("a [lb]b] {nope} %d"), "literal text escaped, unknown tokens kept (got %s)" % lit)
	check(Prompts.format("{accept}", 20, K.PAD).contains("[font_size=%d]" % roundi(20 * UiTheme.tuning().prompt_glyph_scale)),
			"glyphs scaled from the text size")


func _test_prompt_label() -> void:
	var u := UiTheme.tuning()
	Prompts.note_event(key_press(KEY_A))
	var l := MenuHelpers.prompt("{@LIGHT} light", &"HintPrompt", HORIZONTAL_ALIGNMENT_CENTER, "")
	add_child(l)
	await frames(2)
	check(_has(l.text, KEY_J_CAP) and l.get_parsed_text().ends_with(" light"),
			"PromptLabel draws on entering the tree")
	check(l.badge_specs().is_empty() and not l.clip_contents,
			"keyboard glyph has no gamepad badge and PromptLabel doesn't clip outer rims")
	Prompts.note_event(pad_press(PAD_A, JOY_BUTTON_A))
	await frames(2)
	check(_has(l.text, 0x21D0), "redrawn for the pad (LIGHT = X)")
	check(l.badge_specs().size() == 1 and l.badge_specs()[0]["bg"] == u.prompt_pad_badge_color
			and not l.is_processing_internal(),
			"pad glyph draws one charcoal badge and doesn't tick per frame while idle")
	var old := Bindings.get_binding(0, Bindings.Kind.PAD, "LIGHT")
	Bindings.set_binding(0, Bindings.Kind.PAD, "LIGHT", {"t": "btn", "i": JOY_BUTTON_Y})
	check(_has(l.text, 0x21D1), "redrawn after a rebind (LIGHT = Y)")
	Bindings.set_binding(0, Bindings.Kind.PAD, "LIGHT", old)
	l.key_template = "keys only"
	Prompts.note_event(key_press(KEY_A))
	await frames(2)
	check(l.get_parsed_text() == "keys only" and l.badge_specs().is_empty(),
			"key_template replaces the template on the keyboard and clears badges")
	l.key_template = ""
	l.slot = 1
	l.refresh()
	await frames(2)
	check(l.badge_specs().size() == 1 and l.badge_specs()[0]["bg"] == u.prompt_key_color
			and int(l.badge_specs()[0]["border_width"]) == u.prompt_keycap_border_width,
			"text keycap ('Num 1') draws one bordered keycap backdrop")
	l.slot = 0
	l.kind = Bindings.Kind.PAD
	l.refresh()
	await frames(2)
	check(_has(l.text, 0x21D0) and l.badge_specs().size() == 1, "a fixed kind ignores the shared device")
	var saved_bg := u.prompt_pad_badge_color
	u.prompt_pad_badge_color = Color(0.25, 0.26, 0.30)
	l.refresh()
	await frames(2)
	check(l.badge_specs()[0]["bg"] == u.prompt_pad_badge_color,
			"refresh() redraws backdrop when badge tuning changes without text changing")
	u.prompt_pad_badge_color = saved_bg
	l.visible = false
	l.template = "{accept} go"
	check(not l.is_processing_internal() and l.badge_specs().is_empty(),
			"a hidden PromptLabel never leaves internal processing on or stale badges behind")
	l.queue_free()
	await frames(1)


func _test_prefs_saved() -> void:
	Bindings.set_prompt_prefs(Bindings.PromptDevice.PAD, Bindings.PadStyle.NINTENDO)
	Bindings.save_to_disk()
	Bindings.set_prompt_prefs(Bindings.PromptDevice.AUTO, Bindings.PadStyle.AUTO)
	Bindings.load_from_disk()
	check(Bindings.prompt_device == Bindings.PromptDevice.PAD and Bindings.pad_style == Bindings.PadStyle.NINTENDO,
			"prompt preferences round-trip through controls.cfg")
	Bindings.reset_defaults(0)
	check(Bindings.pad_style == Bindings.PadStyle.NINTENDO, "reset to defaults keeps the prompt preferences")
	Bindings.set_prompt_prefs(Bindings.PromptDevice.AUTO, Bindings.PadStyle.AUTO)


func _test_controls_rows() -> void:
	var cs := (load(ControlsScreen.SCENE_PATH) as PackedScene).instantiate() as ControlsScreen
	cs.embedded = true
	add_child(cs)
	await frames(2)
	cs._prompt_sel.cycle(1)  # Auto -> Keyboard
	cs._style_sel.cycle(1)  # Auto -> Xbox
	cs._style_sel.cycle(1)  # -> PlayStation
	check(Bindings.prompt_device == Bindings.PromptDevice.KEYBOARD
			and Bindings.pad_style == Bindings.PadStyle.PLAYSTATION, "Controls page rows set the prompt preferences")
	var light: PromptLabel = cs._row_values["LIGHT"]
	check(_has(light.text, 0x21E0), "binding values are glyphs in the chosen pad style (LIGHT = square)")
	cs.queue_free()
	Bindings.set_prompt_prefs(Bindings.PromptDevice.AUTO, Bindings.PadStyle.AUTO)
	await frames(2)


func _test_lobby() -> void:
	Lobby.pending_mode = MatchConfig.Mode.LOCAL_VERSUS
	var j := (load(Game.SCENE_LOBBY) as PackedScene).instantiate() as Lobby
	j.auto_start = false
	add_child(j)
	await frames(3)
	await send(key_press(KEY_ENTER))
	check(j.slots[0].device_kind == Bindings.Kind.KEYBOARD, "keyboard joins P1")
	var hint: PromptLabel = j._ui[0]["hint"]
	var footer := j._hint_label
	check(_has(hint.text, KEY_J_CAP) and _has(footer.text, ENTER_CAP),
			"keyboard: card shows P1's keys, footer the shared keys")
	await send(pad_press(PAD_A, JOY_BUTTON_START))
	check(j.slots[1].device_kind == Bindings.Kind.PAD, "a pad joins P2")
	var empty: PromptLabel = j._ui[2]["state"]
	check(_has(empty.text, ENTER_CAP) and _has(empty.text, 0x21FB), "an empty card names both join buttons")
	check(_has(footer.text, XBOX_A) and not _has(footer.text, ENTER_CAP), "footer switched to the pad")
	check(_has(hint.text, KEY_J_CAP) and not _has(hint.text, XBOX_A),
			"P1's card keeps the keyboard glyphs while the pad is on screen")
	check(_has((j._ui[1]["hint"] as PromptLabel).text, XBOX_A), "P2's card shows pad glyphs")
	j.queue_free()
	await frames(2)


func _backup_cfg() -> void:
	_cfg_existed = FileAccess.file_exists(Bindings.SAVE_PATH)
	if _cfg_existed:
		_cfg_bytes = FileAccess.get_file_as_bytes(Bindings.SAVE_PATH)


func _restore_cfg() -> void:
	if _cfg_existed:
		var f := FileAccess.open(Bindings.SAVE_PATH, FileAccess.WRITE)
		f.store_buffer(_cfg_bytes)
		f.close()
	elif FileAccess.file_exists(Bindings.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Bindings.SAVE_PATH))
	for s in Bindings.SLOT_COUNT:
		Bindings.reset_defaults(s)
	Bindings.set_prompt_prefs(Bindings.PromptDevice.AUTO, Bindings.PadStyle.AUTO)
	Bindings.load_from_disk()
