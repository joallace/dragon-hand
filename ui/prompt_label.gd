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


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_OFF
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"PromptText"


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
	if bb != text:
		text = bb


func _on_bindings_changed(_slot: int) -> void:
	refresh()
