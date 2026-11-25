extends Control
## Main menu (project main scene). Built in code; see ui/menu_helpers.gd.
## "Join online" needs an online transport and "Quit" a closable window
## (Quit is absent on web, PlatformCaps). A web invite link's room code
## (Net.boot_join_code) opens the join screen joining it.

const TITLE := "DRAGON HAND"
const TAGLINE := "FORGE THE HAND  ·  WAKE THE DRAGON"

var _title: Label
var _emblem: DragonEmblem
var _list: VBoxContainer
var _how_to: HowToPlayPanel
## Net.pending_message shown once ("Host left the session", ...).
var _message: Label


func _ready() -> void:
	# Safety: arriving here always means no room is open.
	Net.leave()
	MenuHelpers.setup_screen(self)
	add_child(AnimatedBackground.new())

	var u := UiTheme.tuning()
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", u.main_menu_separation)
	_emblem = DragonEmblem.new()
	_emblem.custom_minimum_size = Vector2.ONE * u.main_menu_emblem_size
	_emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_emblem)
	_title = MenuHelpers.title(TITLE)
	col.add_child(_title)
	col.add_child(MenuHelpers.ruled_label(TAGLINE))
	col.add_child(MenuHelpers.spacer(u.main_menu_title_gap))

	var buttons: Array = [MenuHelpers.button("Play", _on_play)]
	if Net.online_available():
		buttons.append(MenuHelpers.button("Join online", _on_join_online))
	buttons.append(MenuHelpers.button("How to Play", _on_how_to_play))
	buttons.append(MenuHelpers.button("Settings", _on_settings))
	if PlatformCaps.can_quit():
		buttons.append(MenuHelpers.button("Quit", _on_quit))
	_list = MenuHelpers.vlist(buttons)
	_list.name = "Buttons"
	col.add_child(_list)
	_message = MenuHelpers.label(Net.pending_message, &"HintLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_message.add_theme_color_override("font_color", u.color_ember)
	_message.visible = not Net.pending_message.is_empty()
	Net.pending_message = ""
	col.add_child(_message)
	col.add_child(MenuHelpers.prompt("{accept} select     {back} back"))
	add_child(MenuHelpers.centered(col))
	MenuHelpers.focus_first(_list)
	# Web invite link (?room=CODE at boot): straight into joining that room.
	if not Net.boot_join_code.is_empty() and Net.online_available():
		JoinOnlineScreen.pending_code = Net.boot_join_code
		Net.boot_join_code = ""
		_on_join_online.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _how_to != null:
		return
	# Nothing focused (e.g. mouse click on background) -> re-grab focus.
	if get_viewport().gui_get_focus_owner() == null and (
			event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")
			or event.is_action_pressed("ui_accept")):
		MenuHelpers.focus_first(_list)
		get_viewport().set_input_as_handled()


func _on_play() -> void:
	Game.goto(Game.SCENE_LOBBY)


func _on_join_online() -> void:
	Game.goto(Game.SCENE_JOIN_ONLINE)


func _on_settings() -> void:
	Game.goto(Game.SCENE_SETTINGS)


func _on_how_to_play() -> void:
	_how_to = HowToPlayPanel.new()
	_how_to.closed.connect(func() -> void:
		_how_to = null
		MenuHelpers.focus_first(_list))
	add_child(_how_to)


func _on_quit() -> void:
	get_tree().quit()
