class_name Lobby
extends Control
## Unified lobby (SPEC_ONLINE.md §10.2), local and online: the game mode on
## tabs at the top, one card per slot, and the match rules on their own
## options screen. The data and rules live in a LobbyModel (`model`); this
## screen maps devices to commands and draws it.
##
## Input is read per *device* in _input (event.device), not through global
## ui_* actions, so two pads never steer the same card.
##
## Any device, joined or not (the lobby's owner: anyone offline, the host
## online):
##   LB / RB (Q / E, PageUp / PageDown): game mode, the tabs at the top.
##   Y (TAB): the options screen (`open_options`): the mode's rules, one per
##     row (up/down row, left/right value), then the room actions (open an
##     online room, by room code where PlatformCaps.room_codes() and / or by
##     direct IP; copy what to share; close / leave the room). While it is
##     open every device steers it and nobody can ready up (opening it
##     un-readies this machine's players); guests see the host's rules
##     read-only. B / Y closes it.
## Gamepad (unjoined): START or A joins the next free slot. B with nobody
##   joined -> main menu (leaving the room online).
## Gamepad (joined): the cursor stays in the player's own card: D-pad / left
##   stick up-down picks fighter / colour / team, left-right changes it;
##   A/START = ready; B = un-ready, then leave.
##   X (`cycle_seat`, the lobby's owner): the cursor hops to the next card
##   with seat rows (LobbyModel.seat_rows): an empty slot ("+ CPU": A or
##   left/right seats a CPU), a CPU (remove it, fighter, level, team), online
##   a player's team, in co-op the CPU ally's place. X again = next card,
##   after the last one (or B) back to the player's own card.
## Keyboard: ENTER joins a keyboard player into the next free slot; that
##   player's number on this machine picks the Bindings keyboard layout
##   (first = A/WASD, second = B/arrows+numpad). Joined keyboard players
##   navigate with their layout's MOVE keys, ready with their LIGHT or JUMP key
##   (or ENTER once all slots are filled), hop to other seats with their HEAVY
##   key and back out with their PAUSE key (or ESC). While only one keyboard
##   player is joined, arrow keys also navigate.
## Mouse / touch: the tabs, the Options button, the options rows ("<" / ">"
##   and the action buttons) and the room bar's buttons; a tap on an empty
##   card seats a CPU there (again: removes it).
##
## Room bar: "Local", or hosting by code "Opening room…", then "Room code:
##   XXXXXX", and any signaling problem; LAN / UPnP details only for direct
##   IP. Without online play (Net.online_available() false) the room bar and
##   the room actions are gone.
##
## Local: `model` is this screen's own; the tabs switch Versus / Co-op (see
##   LobbyModel; CPUs are seated in empty versus slots). The match starts
##   after UiTheme join_start_delay seconds of everyone ready.
## Online: `model` is Net.room.model. The host applies commands directly; a
##   guest's commands go to the host (OnlineRoom.request) and the screen
##   redraws on every state broadcast. The host's countdown
##   (Tuning.net.lobby_countdown_frames) starts the match on every peer.
## More than two slots (team versus, co-op) use compact cards. In co-op the
##   CPU ally is shown in the last empty slot (model.ally_place()).
## Couch + online: every local device joins its own slot (up to
##   Tuning.net.max_local_players_online), each sending its own request.

## Emitted with the finished config right before a local match starts.
signal match_requested(config: MatchConfig)

const Cmd := LobbyModel.Cmd
const Row := LobbyModel.Row
const SlotType := LobbyModel.SlotType
const SlotState := LobbyModel.SlotState
## Screen commands next to LobbyModel.Cmd (never sent to the model).
const CMD_SEAT := 100
const CMD_OPTIONS := 101
const CMD_MODE_PREV := 102
const CMD_MODE_NEXT := 103
## Every rule row, in the order the options screen lists them.
const RULE_ROWS: Array[int] = [
	Row.LOCK_TEAMS, Row.ROUNDS, Row.COOP_STRUCTURE, Row.ENEMY_COUNT, Row.WAVES, Row.ENEMY_LEVEL,
	Row.ENEMY_ROSTER, Row.ALLY, Row.ALLY_LEVEL, Row.ALLY_CHARACTER, Row.FRIENDLY_FIRE, Row.TIMER, Row.STAGE]
## Action items of the options screen (after the rule rows; negative, so an
## item is either a Row or one of these).
const ACT_COPY := -1
const ACT_ROOM := -2
const ACT_DIRECT := -3
const ACT_DONE := -4
const ACTIONS: Array[int] = [ACT_COPY, ACT_ROOM, ACT_DIRECT, ACT_DONE]

## Set before Game.goto(Game.SCENE_LOBBY) to choose the local mode.
static var pending_mode: MatchConfig.Mode = MatchConfig.Mode.LOCAL_VERSUS

var model: LobbyModel
## Tests set this false to inspect match_requested without changing scene.
var auto_start: bool = true
## The cards' slot list (model.slots).
var slots: Array[LobbyModel.Slot]:
	get:
		return model.slots

var _local_model: LobbyModel
var _countdown := 0.0
var _started := false
var _stick_dir: Dictionary = {}  # device -> Vector2i
var _blink := 0.0
## Text shown in the room bar for UiTuning.join_notice_seconds (port in use,
## copied...).
var _notice := "":
	set(v):
		_notice = v
		_notice_left = UiTheme.tuning().join_notice_seconds
var _notice_left := 0.0
## Local players editing another seat: their slot -> {"target": slot, "row": Row}.
var _focus: Dictionary = {}
var _options_open := false
## The options screen's cursor: a Row or an ACT_* (see option_items).
var _options_item: int = ACT_DONE

# UI refs
var _ui: Array[Dictionary] = []
var _tab_bar: HBoxContainer
var _tab_buttons: Array[Button] = []
var _tab_modes: Array[MatchConfig.Mode] = []
var _panel_row: HBoxContainer
var _rules_label: Label
var _status_label: PromptLabel
var _hint_label: PromptLabel
var _room_label: Label
var _room_button: Button
var _copy_button: Button
var _direct_button: Button
var _options: Control
var _options_header: Label
var _options_hint: PromptLabel
var _options_scroll: ScrollContainer
## Rule Row -> its Label on the options screen.
var _row_labels: Dictionary = {}
## Rule Row / ACT_* -> the options screen control of that item.
var _option_controls: Dictionary = {}


func _ready() -> void:
	MenuHelpers.setup_screen(self)
	_local_model = LobbyModel.new(pending_mode)
	_local_model.restore()
	model = Net.room.model if Net.room != null else _local_model
	_build_ui()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	Net.room_code_changed.connect(_on_room_code_changed)
	Net.signaling_problem.connect(_on_signaling_problem)
	_watch_room()
	_refresh()


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if Net.room_code_changed.is_connected(_on_room_code_changed):
		Net.room_code_changed.disconnect(_on_room_code_changed)
	if Net.signaling_problem.is_connected(_on_signaling_problem):
		Net.signaling_problem.disconnect(_on_signaling_problem)


func is_online() -> bool:
	return Net.room != null


func is_coop() -> bool:
	return model.is_coop()


## This machine runs the lobby: its players change the mode, the rules and
## the other seats (anyone offline, the host online).
func can_manage() -> bool:
	return not is_online() or Net.is_host()


func cpu_slot() -> int:
	return model.cpu_slot()


func all_ready() -> bool:
	return model.all_ready()


func nobody_joined() -> bool:
	return model.nobody_joined()


func build_config() -> MatchConfig:
	return model.build_config(randi())


## The slot drawn as the CPU ally (co-op with the ally on; empty when every
## slot has a player).
func ally_slots() -> Array[int]:
	var out: Array[int] = []
	if model.coop_ally and model.ally_place() >= 0:
		out.append(model.ally_place())
	return out


# --- Room ------------------------------------------------------------------------

func _watch_room() -> void:
	if Net.room == null:
		return
	if not Net.room.changed.is_connected(_on_room_changed):
		Net.room.changed.connect(_on_room_changed)


func _on_room_changed() -> void:
	if Net.room == null:
		return
	if Net.room.phase != OnlineRoom.Phase.LOBBY:
		_started = true
	_refresh()


func _on_room_code_changed(_code: String) -> void:
	_refresh()


func _on_signaling_problem(_text: String) -> void:
	_refresh()


## Both ways to open a room exist here (desktop with room codes): by room
## code and by direct IP.
static func two_room_kinds() -> bool:
	return Net.room_codes_ready() and PlatformCaps.direct_ip()


## The room button / options item: open a room (local; by room code where
## available, else direct IP), close it (host) or leave it (guest).
func room_action() -> void:
	if not Net.online_available():
		return
	if not is_online():
		open_online()
	elif Net.is_host():
		close_room()
	else:
		_back_to_menu()


## Host a room (room code unless `direct` or there are no room codes; the
## code arrives later); the first local player keeps their slot and pick.
func open_online(direct: bool = false) -> Error:
	direct = direct or not Net.room_codes_ready()
	var err := Net.host() if direct else Net.host_room()
	if err != OK:
		_notice = "Port %d is in use" % Net.settings.host_port() if direct and err == ERR_CANT_CREATE \
			else "Could not open the room (%s)" % error_string(err)
		Sfx.play(&"ui_back")
		_refresh()
		return err
	var keep: LobbyModel.Slot = null
	for s in _local_model.slots:
		if s.type == SlotType.HUMAN and s.state != SlotState.EMPTY \
				and (keep == null or s.join_order < keep.join_order):
			keep = s
	model = Net.room.model
	model.carry_rules_from(_local_model)
	_watch_room()
	if keep != null:
		Net.room.join_local(keep.device_kind, keep.device_id)
		var mine := Net.room.my_slots()
		if not mine.is_empty():
			model.slots[mine[0]].char_index = keep.char_index
			model.slots[mine[0]].color_index = keep.color_index
	Net.room.publish()
	_notice = ""
	_focus.clear()
	Sfx.play(&"ui_confirm")
	_rebuild_panels()
	_refresh()
	return OK


## Host: close the room and go back to the local lobby.
func close_room() -> void:
	Net.leave()
	model = _local_model
	for s in model.slots:
		if s.state == SlotState.READY and s.type == SlotType.HUMAN:
			s.state = SlotState.JOINED
	_started = false
	_focus.clear()
	Sfx.play(&"ui_back")
	_rebuild_panels()
	_refresh()


## Host: copy what guests need. Room code: the code (desktop) or the invite
## link (web, Net.invite_text). Direct IP: the best address. Call from an
## input handler (browsers allow clipboard writes only in a user gesture).
func copy_address() -> void:
	if Net.is_host() and Net.backend == PlatformCaps.NetBackend.WEBRTC:
		var invite := Net.invite_text()
		if invite.is_empty():
			return
		WebPage.copy_text(invite)
		_notice = "Copied the invite link" if invite != Net.room_code else "Copied %s" % invite
		_refresh()
		return
	var a := _host_addresses()
	if a.is_empty():
		return
	WebPage.copy_text(a[0])
	_notice = "Copied %s" % a[0]
	_refresh()


## "ip:port" strings worth sharing: the UPnP public address first (direct
## IP rooms only).
func _host_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	if not Net.is_host() or Net.backend == PlatformCaps.NetBackend.WEBRTC:
		return out
	var port := Net.settings.host_port()
	if Net.upnp.status == UpnpHelper.Status.MAPPED and Net.upnp.external_ip != "":
		out.append(_with_port(Net.upnp.external_ip, port))
	for a in UpnpHelper.local_addresses():
		out.append(_with_port(a, port))
	return out


static func _with_port(ip: String, port: int) -> String:
	return ("[%s]:%d" if ip.contains(":") else "%s:%d") % [ip, port]


# --- Mode, rules, seats -------------------------------------------------------------

## LB / RB: the next game mode (the lobby's owner).
func cycle_mode(dir: int) -> void:
	if model.modes().size() < 2:
		return
	if not can_manage():
		_notice = "The host picks the game"
		Sfx.play(&"ui_back")
		_refresh()
		return
	change_rule(Row.MODE, dir)


## A tab: switch to mode `m` (not one with fewer places than joined players).
func select_mode(m: MatchConfig.Mode) -> void:
	var ms := model.modes()
	if not can_manage() or not m in ms or m == model.mode:
		return
	if not change_rule(Row.MODE, ms.find(m) - ms.find(model.mode)):
		_notice = "Too many players for %s" % LobbyModel.mode_name(m)
		_refresh()


## Change a shared rule (LobbyModel.change_rule; the lobby's owner). Returns
## whether anything changed.
func change_rule(row: int, dir: int) -> bool:
	return _owner_change({"op": OnlineRoom.OP_RULE, "row": row, "dir": dir},
			func() -> bool: return model.change_rule(row, dir))


## Change a seat row of slot `idx` (LobbyModel.change_seat; the lobby's owner).
func change_seat(idx: int, row: int, dir: int) -> bool:
	return _owner_change({"op": OnlineRoom.OP_SEAT, "slot": idx, "row": row, "dir": dir},
			func() -> bool: return model.change_seat(idx, row, dir))


## Apply an owner's change: `local` offline, the room request `req` online
## (the host applies its own at once). A refused change sounds like one.
func _owner_change(req: Dictionary, local: Callable) -> bool:
	if not can_manage():
		return false
	var ok := false
	if is_online():
		var before := model.to_dict()
		Net.room.request(req)
		ok = model.to_dict() != before
	else:
		ok = local.call()
	if ok:
		_countdown = UiTheme.tuning().join_start_delay
	Sfx.play(&"ui_move" if ok else &"ui_back")
	_refresh()
	return ok


## Seats the player in slot `idx` can edit, in slot order.
func seat_targets_for(idx: int) -> Array[int]:
	var out: Array[int] = []
	if can_manage():
		for t in model.seat_targets():
			if t != idx:
				out.append(t)
	return out


## The seat the player in slot `idx` is editing, or -1 (their own card).
func focus_of(idx: int) -> int:
	return _focus[idx]["target"] if _focus.has(idx) else -1


## X: this player's cursor hops to the next seat they can edit, and from the
## last one back to their own card.
func cycle_seat(idx: int) -> void:
	if slots[idx].state != SlotState.JOINED:
		return
	var next := -1
	for t in seat_targets_for(idx):
		if t > focus_of(idx):
			next = t
			break
	if next < 0 and not _focus.has(idx):
		Sfx.play(&"ui_back")
		return
	if next < 0:
		_focus.erase(idx)
	else:
		_focus[idx] = {"target": next, "row": model.seat_rows(next)[0]}
	Sfx.play(&"ui_move")
	_refresh()


## A command of a player whose cursor is on another seat.
func _seat_command(idx: int, cmd: int) -> void:
	var f: Dictionary = _focus[idx]
	var target: int = f["target"]
	var rows := model.seat_rows(target)
	match cmd:
		Cmd.UP, Cmd.DOWN:
			f["row"] = rows[posmod(rows.find(f["row"]) + (1 if cmd == Cmd.DOWN else -1), rows.size())]
			Sfx.play(&"ui_move")
		Cmd.LEFT:
			change_seat(target, f["row"], -1)
		Cmd.RIGHT:
			change_seat(target, f["row"], 1)
		Cmd.CONFIRM:
			# A on "+ CPU" seats it; anywhere else the player is done here.
			if _seat_off(target, f["row"]):
				change_seat(target, f["row"], 1)
			else:
				_focus.erase(idx)
				Sfx.play(&"ui_confirm")
		Cmd.BACK:
			_focus.erase(idx)
			Sfx.play(&"ui_back")


## `row` of slot `idx` is a switch that is off (no CPU / no ally there yet).
func _seat_off(idx: int, row: int) -> bool:
	return (row == Row.SEAT_TYPE and slots[idx].type != SlotType.CPU) or (row == Row.ALLY and not model.coop_ally)


## Seat cursors whose player left / readied, or whose seat lost its rows.
func _validate_focus() -> void:
	var mine := local_slots()
	for idx: int in _focus.keys():
		var f: Dictionary = _focus[idx]
		var rows := model.seat_rows(f["target"]) if can_manage() else ([] as Array[int])
		if not idx in mine or slots[idx].state != SlotState.JOINED or rows.is_empty() or f["target"] == idx:
			_focus.erase(idx)
		elif not f["row"] in rows:
			f["row"] = rows[0]


## A tap on a card: seat a CPU in an empty slot / take it out (the co-op
## ally in its place).
func _on_card_gui_input(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _started or _options_open or idx >= slots.size():
		return
	var rows := model.seat_rows(idx) if can_manage() else ([] as Array[int])
	for r: int in [Row.SEAT_TYPE, Row.ALLY]:
		if r in rows:
			change_seat(idx, r, 1)
			_punch_panel(idx)
			return


# --- Options screen -------------------------------------------------------------------

## What the options screen lists, top to bottom: the mode's rule rows, then
## the room actions this machine has, then Done.
func option_items() -> Array[int]:
	var items: Array[int] = []
	items.append_array(model.rule_rows())
	if Net.online_available():
		if not is_online():
			items.append(ACT_ROOM)
			if two_room_kinds():
				items.append(ACT_DIRECT)
		else:
			if _can_copy():
				items.append(ACT_COPY)
			items.append(ACT_ROOM)
	items.append(ACT_DONE)
	return items


func options_open() -> bool:
	return _options_open


## Y / TAB: open the options screen. This machine's ready players are
## un-readied, so the match can't start under it.
func open_options() -> void:
	if _options_open or _started:
		return
	_options_open = true
	_options_item = option_items()[0]
	_focus.clear()
	for i in local_slots():
		if slots[i].state == SlotState.READY:
			_apply_cmd(i, Cmd.BACK)
	Sfx.play(&"ui_confirm")
	_refresh()


func close_options() -> void:
	if not _options_open:
		return
	_options_open = false
	Sfx.play(&"ui_back")
	_refresh()


func toggle_options() -> void:
	if _options_open:
		close_options()
	else:
		open_options()


func _options_command(cmd: int) -> void:
	var items := option_items()
	var at := maxi(items.find(_options_item), 0)
	match cmd:
		Cmd.UP, Cmd.DOWN:
			_options_item = items[posmod(at + (1 if cmd == Cmd.DOWN else -1), items.size())]
			Sfx.play(&"ui_move")
			_refresh()
		Cmd.LEFT:
			_option_step(items[at], -1)
		Cmd.RIGHT:
			_option_step(items[at], 1)
		Cmd.CONFIRM:
			_option_activate(items[at])
		Cmd.BACK, CMD_OPTIONS:
			close_options()


## Left / right on an item (a rule row; the "<" / ">" buttons).
func _option_step(item: int, dir: int) -> void:
	if item < 0:
		return
	_options_item = item
	if can_manage():
		change_rule(item, dir)
	else:
		Sfx.play(&"ui_back")
		_refresh()


## A / click on an item: a rule row steps forward, an action runs.
func _option_activate(item: int) -> void:
	if item >= 0:
		_option_step(item, 1)
		return
	_options_item = item
	match item:
		ACT_DONE:
			close_options()
		ACT_COPY:
			copy_address()
		ACT_ROOM:
			# Back to the cards: the room bar there shows the code, or why not.
			_options_open = false
			room_action()
			_refresh()
		ACT_DIRECT:
			_options_open = false
			open_online(true)
			_refresh()


func _can_copy() -> bool:
	return Net.is_host() and (Net.backend != PlatformCaps.NetBackend.WEBRTC or not Net.room_code.is_empty())


# --- Input ---------------------------------------------------------------------

const _PAD_CMDS := {
	JOY_BUTTON_A: Cmd.CONFIRM, JOY_BUTTON_START: Cmd.CONFIRM,
	JOY_BUTTON_B: Cmd.BACK, JOY_BUTTON_BACK: Cmd.BACK,
	JOY_BUTTON_DPAD_UP: Cmd.UP, JOY_BUTTON_DPAD_DOWN: Cmd.DOWN,
	JOY_BUTTON_DPAD_LEFT: Cmd.LEFT, JOY_BUTTON_DPAD_RIGHT: Cmd.RIGHT,
	JOY_BUTTON_X: CMD_SEAT, JOY_BUTTON_Y: CMD_OPTIONS,
	JOY_BUTTON_LEFT_SHOULDER: CMD_MODE_PREV, JOY_BUTTON_RIGHT_SHOULDER: CMD_MODE_NEXT,
}

## Keys of a joined keyboard player's layout (Bindings action -> command).
const _KEY_LAYOUT_CMDS := {
	"MOVE_FORWARD": Cmd.UP, "MOVE_BACK": Cmd.DOWN,
	"MOVE_LEFT": Cmd.LEFT, "MOVE_RIGHT": Cmd.RIGHT,
	"LIGHT": Cmd.CONFIRM, "JUMP": Cmd.CONFIRM, "PAUSE": Cmd.BACK, "HEAVY": CMD_SEAT,
}

## Keys that mean the same for everyone (screen commands and the options screen).
const _KEY_CMDS := {
	KEY_TAB: CMD_OPTIONS, KEY_Q: CMD_MODE_PREV, KEY_PAGEUP: CMD_MODE_PREV,
	KEY_E: CMD_MODE_NEXT, KEY_PAGEDOWN: CMD_MODE_NEXT,
	KEY_UP: Cmd.UP, KEY_DOWN: Cmd.DOWN, KEY_LEFT: Cmd.LEFT, KEY_RIGHT: Cmd.RIGHT,
	KEY_ENTER: Cmd.CONFIRM, KEY_KP_ENTER: Cmd.CONFIRM, KEY_SPACE: Cmd.CONFIRM,
	KEY_ESCAPE: Cmd.BACK, KEY_BACKSPACE: Cmd.BACK,
}


func _input(event: InputEvent) -> void:
	if _started:
		return
	if event is InputEventJoypadButton:
		if event.pressed and _PAD_CMDS.has(event.button_index):
			_pad_command(event.device, _PAD_CMDS[event.button_index])
	elif event is InputEventJoypadMotion:
		_on_pad_motion(event)
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			_on_key(event)
	else:
		return
	get_viewport().set_input_as_handled()


## Commands that don't belong to a slot: the mode tabs, and everything
## while the options screen is open. Returns true when `cmd` was one.
func _screen_command(cmd: int) -> bool:
	match cmd:
		CMD_MODE_PREV:
			cycle_mode(-1)
			return true
		CMD_MODE_NEXT:
			cycle_mode(1)
			return true
	if _options_open:
		_options_command(cmd)
		return true
	if cmd == CMD_OPTIONS:
		open_options()
		return true
	return false


func _pad_command(device: int, cmd: int) -> void:
	if _screen_command(cmd):
		return
	var idx := slot_for_device(Bindings.Kind.PAD, device)
	if idx >= 0:
		_command(idx, cmd)
	elif cmd == Cmd.CONFIRM:
		join(Bindings.Kind.PAD, device)
	elif cmd == Cmd.BACK and local_slots().is_empty():
		_back_to_menu()


func _on_pad_motion(e: InputEventJoypadMotion) -> void:
	if e.axis != JOY_AXIS_LEFT_X and e.axis != JOY_AXIS_LEFT_Y:
		return
	var th := UiTheme.tuning().stick_nav_threshold
	var v := Vector2(Input.get_joy_axis(e.device, JOY_AXIS_LEFT_X), Input.get_joy_axis(e.device, JOY_AXIS_LEFT_Y))
	if e.axis == JOY_AXIS_LEFT_X:
		v.x = e.axis_value
	else:
		v.y = e.axis_value
	var dir := Vector2i.ZERO
	if absf(v.x) >= th and absf(v.x) >= absf(v.y):
		dir.x = signi(roundi(signf(v.x)))
	elif absf(v.y) >= th:
		dir.y = signi(roundi(signf(v.y)))
	var prev: Vector2i = _stick_dir.get(e.device, Vector2i.ZERO)
	if dir == prev:
		return
	_stick_dir[e.device] = dir
	if dir.x < 0:
		_pad_command(e.device, Cmd.LEFT)
	elif dir.x > 0:
		_pad_command(e.device, Cmd.RIGHT)
	elif dir.y < 0:
		_pad_command(e.device, Cmd.UP)
	elif dir.y > 0:
		_pad_command(e.device, Cmd.DOWN)


func _on_key(e: InputEventKey) -> void:
	var b := Bindings.binding_from_event(e, Bindings.Kind.KEYBOARD)
	if b.is_empty():
		return
	var code: int = b["i"]
	var kb := keyboard_slots()
	if _options_open:
		# Everyone steers the options: the shared keys, then any layout's.
		var cmd: int = _KEY_CMDS.get(code, -1)
		for profile in Bindings.SLOT_COUNT:
			for action: String in _KEY_LAYOUT_CMDS:
				if cmd < 0 and Bindings.get_binding(profile, Bindings.Kind.KEYBOARD, action) == b:
					cmd = _KEY_LAYOUT_CMDS[action]
		if cmd >= 0 and cmd != CMD_SEAT:
			_screen_command(cmd)
		return
	# 1) Per-layout keys of each joined keyboard player.
	for idx in kb:
		for action: String in _KEY_LAYOUT_CMDS:
			if Bindings.get_binding(binding_slot(idx), Bindings.Kind.KEYBOARD, action) == b:
				_command(idx, _KEY_LAYOUT_CMDS[action])
				return
	# 2) Shared keys.
	var shared: int = _KEY_CMDS.get(code, -1)
	if shared < 0 or _screen_command(shared):
		return
	match shared:
		Cmd.CONFIRM:
			if _can_join_more() and kb.size() < Bindings.SLOT_COUNT:
				join(Bindings.Kind.KEYBOARD, -1)
			else:
				for idx in kb:
					if slots[idx].state == SlotState.JOINED:
						_command(idx, Cmd.CONFIRM)
						return
		Cmd.BACK:
			if not kb.is_empty():
				var last := kb[0]
				for idx in kb:
					if slots[idx].join_order > slots[last].join_order:
						last = idx
				_command(last, Cmd.BACK)
			elif local_slots().is_empty():
				_back_to_menu()
		_:  # arrows
			if kb.size() == 1:
				_command(kb[0], shared)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		var idx := slot_for_device(Bindings.Kind.PAD, device)
		if idx >= 0:
			leave(idx)
	_stick_dir.erase(device)
	_refresh()


# --- Slot logic ----------------------------------------------------------------

## Slot of a joined pad on this machine (-1: none; the keyboard may own
## several slots, so it always gets -1).
func slot_for_device(kind: int, device: int) -> int:
	if kind == Bindings.Kind.KEYBOARD:
		return -1
	if is_online():
		return Net.room.slot_of_device(kind, device)
	for i in slots.size():
		var s := slots[i]
		if s.type == SlotType.HUMAN and s.state != SlotState.EMPTY \
				and s.device_kind == kind and s.device_id == device:
			return i
	return -1


## Joined slots played on this machine.
func local_slots() -> Array[int]:
	if is_online():
		var out: Array[int] = []
		for slot: int in Net.room.local_devices:
			if slot in Net.room.my_slots():
				out.append(slot)
		out.sort()
		return out
	var all: Array[int] = []
	for i in slots.size():
		if slots[i].type == SlotType.HUMAN and slots[i].state != SlotState.EMPTY:
			all.append(i)
	return all


func keyboard_slots() -> Array[int]:
	var out: Array[int] = []
	for i in local_slots():
		if _device_kind(i) == Bindings.Kind.KEYBOARD:
			out.append(i)
	return out


## Keyboard layout / bindings profile of a local slot, as the match will
## use it (MatchConfig.binding_profile): keyboard players by their order on
## this machine, pads by player number (a guest in slot 2 uses layout A).
func binding_slot(idx: int) -> int:
	var mine := local_slots()
	var at := mine.find(idx)
	if at < 0:
		return 0
	return Bindings.profile_for(mine.map(func(i: int) -> int: return _device_kind(i)), at)


func _device_kind(idx: int) -> int:
	if is_online():
		var d: Array = Net.room.local_devices.get(idx, [Bindings.Kind.PAD, -1])
		return d[0]
	return slots[idx].device_kind


func _device_id(idx: int) -> int:
	if is_online():
		var d: Array = Net.room.local_devices.get(idx, [Bindings.Kind.PAD, -1])
		return d[1]
	return slots[idx].device_id


func first_free_slot() -> int:
	return model.first_free_slot()


func _can_join_more() -> bool:
	if model.first_free_slot() < 0:
		return false
	return not is_online() or local_slots().size() < Tuning.net.max_local_players_online


## Claim the next free HUMAN slot for a device. Returns the slot (online: -1,
## the host answers with the next state) or -1.
func join(kind: int, device: int) -> int:
	if kind == Bindings.Kind.PAD and (slot_for_device(kind, device) >= 0
			or (is_online() and Net.room.is_pending(kind, device))):
		return -1
	if not _can_join_more() or (kind == Bindings.Kind.KEYBOARD and keyboard_slots().size() >= Bindings.SLOT_COUNT):
		return -1
	Sfx.play(&"ui_confirm")
	if is_online():
		Net.room.join_local(kind, device)
		var mine := slot_for_device(kind, device) if kind == Bindings.Kind.PAD else _last(local_slots())
		_punch_panel(mine)
		_refresh()
		return mine
	var idx := model.join(kind, device)
	_punch_panel(idx)
	_refresh()
	return idx


static func _last(a: Array[int]) -> int:
	return a[-1] if not a.is_empty() else -1


func leave(idx: int) -> void:
	if is_online():
		if slots[idx].state == SlotState.READY:
			_send(idx, Cmd.BACK)
		_send(idx, Cmd.BACK)
	else:
		model.leave(idx)
	Sfx.play(&"ui_back")
	_refresh()


func _command(idx: int, cmd: int) -> void:
	if idx < 0 or idx >= slots.size():
		return
	if cmd == CMD_SEAT:
		cycle_seat(idx)
		return
	if cmd >= CMD_SEAT:
		return
	if _focus.has(idx):
		_seat_command(idx, cmd)
	else:
		_play_for(_apply_cmd(idx, cmd), idx)
	_refresh()


## Apply a LobbyModel.Cmd to a slot of this machine (online: ask the host).
## Returns what it did (online: what it should do).
func _apply_cmd(idx: int, cmd: int) -> StringName:
	if not is_online():
		return model.command(idx, cmd)
	var ev := _predict(idx, cmd)
	_send(idx, cmd)
	return ev


func _send(idx: int, cmd: int) -> void:
	Net.room.request({"op": OnlineRoom.OP_CMD, "slot": idx, "cmd": cmd})


## Online: the event a command will cause (for instant feedback sounds).
func _predict(idx: int, cmd: int) -> StringName:
	var s := slots[idx]
	if s.state == SlotState.READY:
		return LobbyModel.EV_UNREADY if cmd == Cmd.BACK else LobbyModel.EV_NONE
	match cmd:
		Cmd.CONFIRM:
			return LobbyModel.EV_READY
		Cmd.BACK:
			return LobbyModel.EV_LEAVE
	return LobbyModel.EV_MOVE


func _play_for(ev: StringName, idx: int) -> void:
	match ev:
		LobbyModel.EV_MOVE:
			Sfx.play(&"ui_move")
		LobbyModel.EV_READY:
			_punch_panel(idx)
			Sfx.play(&"ui_confirm")
		LobbyModel.EV_UNREADY, LobbyModel.EV_LEAVE:
			Sfx.play(&"ui_back")


func _process(delta: float) -> void:
	_blink += delta
	if _started:
		return
	if not is_online():
		if all_ready() and not _options_open:
			_countdown -= delta
			if _countdown <= 0.0:
				_start()
				return
		else:
			_countdown = UiTheme.tuning().join_start_delay
	if _notice != "":
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice = ""
			_refresh_room()
	_refresh_status()
	var u := UiTheme.tuning()
	for i in mini(_ui.size(), slots.size()):
		var prompt := slots[i].state == SlotState.EMPTY and not i in ally_slots()
		(_ui[i]["state"] as Control).modulate.a = \
			lerpf(u.join_blink_min_alpha, 1.0, absf(sin(_blink * u.join_blink_speed))) if prompt else 1.0


func _start() -> void:
	_started = true
	model.remember()
	var cfg := build_config()
	match_requested.emit(cfg)
	if auto_start:
		Game.start_match(cfg)


func _back_to_menu() -> void:
	Sfx.play(&"ui_back")
	_started = true
	if is_online():
		Net.leave()
	else:
		model.remember()
	Game.goto(Game.SCENE_MAIN_MENU)


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	add_child(AnimatedBackground.new())
	var u := UiTheme.tuning()
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = u.join_margin.x
	root.offset_right = -u.join_margin.x
	root.offset_top = u.join_margin.y
	root.offset_bottom = -u.join_margin.y
	root.add_theme_constant_override("separation", u.join_root_separation)
	add_child(root)

	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.add_theme_constant_override("separation", u.join_tab_separation)
	root.add_child(_tab_bar)
	root.add_child(_build_room_bar())
	# One card per slot, sharing the width (no minimum widths: long values
	# are cut with an ellipsis, never pushed off-screen).
	_panel_row = HBoxContainer.new()
	_panel_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_row.add_theme_constant_override("separation", u.join_column_separation)
	root.add_child(_panel_row)
	_rebuild_panels()

	# The rules at a glance, and the way to their screen.
	var rules := HBoxContainer.new()
	rules.alignment = BoxContainer.ALIGNMENT_CENTER
	rules.add_theme_constant_override("separation", u.join_column_separation)
	_rules_label = _fit_label("", &"", u.join_row_font)
	_rules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules.add_child(_rules_label)
	rules.add_child(MenuHelpers.prompt("{options}", &"PromptText"))
	var options := MenuHelpers.button("Options", toggle_options)
	options.focus_mode = Control.FOCUS_NONE
	options.custom_minimum_size.x = 0
	rules.add_child(options)
	root.add_child(rules)

	_status_label = MenuHelpers.prompt("", &"HeaderPrompt")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)
	_hint_label = MenuHelpers.prompt("")
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint_label)
	_build_options()


## Top bar: room status and its buttons (mouse / touch; pads and keys open
## rooms from the options screen).
func _build_room_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", UiTheme.tuning().join_column_separation)
	_room_label = _fit_label("", &"HintLabel")
	_room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_room_label)
	# Text-wide buttons, so the address keeps the room.
	_copy_button = MenuHelpers.button("Copy", copy_address)
	_copy_button.focus_mode = Control.FOCUS_NONE
	_copy_button.custom_minimum_size.x = 0
	bar.add_child(_copy_button)
	_room_button = MenuHelpers.button("Open online", room_action)
	_room_button.focus_mode = Control.FOCUS_NONE
	_room_button.custom_minimum_size.x = 0
	_room_button.visible = Net.online_available()
	bar.add_child(_room_button)
	# Desktop with room codes: the room button opens a room-code room, this
	# one a direct-IP room (local only).
	_direct_button = MenuHelpers.button("Direct IP", func() -> void: open_online(true))
	_direct_button.focus_mode = Control.FOCUS_NONE
	_direct_button.custom_minimum_size.x = 0
	_direct_button.visible = false
	bar.add_child(_direct_button)
	return bar


## The mode tabs: one flat button per model.modes(), LB / RB glyphs around them.
func _rebuild_tabs() -> void:
	for c in _tab_bar.get_children():
		_tab_bar.remove_child(c)
		c.queue_free()
	_tab_buttons.clear()
	_tab_modes = model.modes().duplicate()
	var u := UiTheme.tuning()
	_tab_bar.add_child(MenuHelpers.prompt("{tab_prev}", &"PromptText"))
	for m in _tab_modes:
		var b := Button.new()
		b.text = LobbyModel.mode_name(m).to_upper()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", u.join_tab_font)
		b.pressed.connect(select_mode.bind(m))
		_tab_bar.add_child(b)
		_tab_buttons.append(b)
	_tab_bar.add_child(MenuHelpers.prompt("{tab_next}", &"PromptText"))


func _refresh_tabs() -> void:
	if _tab_modes != model.modes():
		_rebuild_tabs()
	var u := UiTheme.tuning()
	var mine := can_manage()
	for i in _tab_buttons.size():
		var b := _tab_buttons[i]
		var on := _tab_modes[i] == model.mode
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, u.color_focus if on else u.color_text_dim)
		b.mouse_filter = Control.MOUSE_FILTER_STOP if mine else Control.MOUSE_FILTER_IGNORE
	# LB / RB only mean something to whoever picks the mode.
	(_tab_bar.get_child(0) as Control).visible = mine
	(_tab_bar.get_child(_tab_bar.get_child_count() - 1) as Control).visible = mine


## (Re)build one card per slot, side by side (compact from three slots up).
func _rebuild_panels() -> void:
	if _panel_row == null:
		return
	for c in _panel_row.get_children():
		_panel_row.remove_child(c)
		c.queue_free()
	_ui.clear()
	for i in slots.size():
		var ui := _build_card(i, slots.size() > 2)
		_ui.append(ui)
		_panel_row.add_child(ui["panel"])


## Single-line label that shrinks with an ellipsis instead of widening its panel.
static func _fit_label(text: String, variation: StringName = &"", font_size := 0) -> Label:
	var l := MenuHelpers.label(text, variation, HORIZONTAL_ALIGNMENT_CENTER)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l


## A slot's card, top to bottom: who (header, device), the seat switch of an
## empty slot, the fighter, a CPU's level, the colour, the team, the state
## and a hint. _refresh_card shows the lines the slot has.
func _build_card(i: int, compact: bool) -> Dictionary:
	var u := UiTheme.tuning()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := (UiTheme.get_theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.set_border_width_all(u.join_panel_border)
	if compact:
		sb.set_content_margin_all(u.join_compact_panel_margin)
	panel.add_theme_stylebox_override("panel", sb)
	panel.gui_input.connect(_on_card_gui_input.bind(i))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var header := _fit_label("", &"HeaderLabel", u.join_compact_header_font if compact else 0)
	var device := _fit_label("", &"HintLabel")
	var seat := _fit_label("", &"", u.join_row_font)
	var character := _fit_label("", &"", u.join_compact_character_font if compact else u.join_character_font)
	var level := _fit_label("", &"", u.join_row_font)
	var swatch := _fit_label("", &"", u.join_row_font)
	var team := _fit_label("", &"", u.join_row_font)
	var state := MenuHelpers.prompt("", &"HeaderPrompt")
	state.add_theme_font_size_override(&"normal_font_size", u.join_compact_state_font if compact else u.join_state_font)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The player's own glyphs (kind / device / profile: _refresh_card).
	var hint := MenuHelpers.prompt("")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l: Control in [header, device, seat, character, level, swatch, team, state, hint]:
		col.add_child(l)
	return {"panel": panel, "header": header, "device": device, "seat": seat, "character": character,
		"level": level, "swatch": swatch, "team": team, "state": state, "hint": hint, "style": sb,
		"color": Color.WHITE, "compact": compact}


## The options screen: a dimmed overlay with a row per rule ("<" name: value
## ">") and a button per action, in a list that scrolls when it has to.
func _build_options() -> void:
	var u := UiTheme.tuning()
	_options = Control.new()
	_options.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	add_child(_options)
	var dim := ColorRect.new()
	dim.color = Tuning.hud.pause_dim_color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options.add_child(dim)
	var panel := PanelContainer.new()
	# Opaque, so the cards behind don't read through the rows.
	var box := (UiTheme.get_theme().get_stylebox("panel", "PanelBox") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.bg_color.a = 1.0
	panel.add_theme_stylebox_override("panel", box)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -u.join_options_width * 0.5
	panel.offset_right = u.join_options_width * 0.5
	panel.offset_top = u.join_margin.y
	panel.offset_bottom = -u.join_margin.y
	_options.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	_options_header = _fit_label("", &"HeaderLabel")
	outer.add_child(_options_header)
	_options_scroll = ScrollContainer.new()
	_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_options_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", u.join_row_separation)
	_options_scroll.add_child(col)
	for r in RULE_ROWS:
		var row := HBoxContainer.new()
		row.add_child(_arrow_button("<", r, -1))
		var l := _fit_label("", &"", u.join_options_row_font)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(_arrow_button(">", r, 1))
		col.add_child(row)
		_row_labels[r] = l
		_option_controls[r] = row
	for a in ACTIONS:
		var b := Button.new()
		b.theme_type_variation = &"RowButton"
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", u.join_options_row_font)
		b.pressed.connect(_option_activate.bind(a))
		col.add_child(b)
		_option_controls[a] = b
	_options_hint = MenuHelpers.prompt("")
	_options_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_options_hint)


func _arrow_button(text: String, row: int, dir: int) -> Button:
	var u := UiTheme.tuning()
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = u.join_options_arrow_width
	b.add_theme_font_size_override("font_size", u.join_options_row_font)
	b.pressed.connect(_option_step.bind(row, dir))
	return b


func _refresh() -> void:
	if _panel_row == null:
		return
	if _ui.size() != slots.size():
		_rebuild_panels()
	_validate_focus()
	_refresh_tabs()
	var colors := model.resolved_colors()
	var ally := ally_slots()
	for i in slots.size():
		_ui[i]["color"] = Tuning.colors.color(model.ally_color() if i in ally else colors[i])
	for i in slots.size():
		_refresh_card(i)
	_refresh_rules()
	_refresh_options()
	_refresh_room()
	_refresh_status()
	_refresh_hint()


## Draw slot `i`'s card: a player, a CPU, the co-op ally, or an empty seat.
func _refresh_card(i: int) -> void:
	var u := UiTheme.tuning()
	var s := slots[i]
	var ui := _ui[i]
	var ids := MenuHelpers.character_ids()
	var mine := i in local_slots()
	var is_ally := i in ally_slots()
	var is_cpu := s.type == SlotType.CPU
	var empty := s.state == SlotState.EMPTY and not is_ally
	var joined_human := s.type == SlotType.HUMAN and s.state != SlotState.EMPTY
	var color: Color = ui["color"]
	(ui["style"] as StyleBoxFlat).border_color = color
	(ui["panel"] as Control).modulate.a = u.join_empty_card_alpha if empty else 1.0

	var header: Label = ui["header"]
	header.add_theme_color_override("font_color", color)
	if is_ally:
		header.text = "CPU ALLY"
	elif is_cpu:
		header.text = "CPU"
	elif is_online() and s.display_name != "":
		header.text = s.display_name.to_upper()
	else:
		header.text = "PLAYER %d" % (i + 1)

	var device: Label = ui["device"]
	if not joined_human:
		device.text = ""
	elif mine or not is_online():
		device.text = MenuHelpers.device_label(_device_kind(i), _device_id(i), binding_slot(i))
	else:
		device.text = _online_label(s.owner_peer)
	device.visible = device.text != ""

	# The switch of an empty seat ("+ CPU"), or of a seated CPU / the ally
	# while someone's cursor is on it.
	var seat: Label = ui["seat"]
	var seat_rows := model.seat_rows(i) if can_manage() else ([] as Array[int])
	var seat_row := Row.SEAT_TYPE if Row.SEAT_TYPE in seat_rows else (Row.ALLY if Row.ALLY in seat_rows else -1)
	var seat_cursor := _row_cursor(i, -1, seat_row)
	seat.visible = seat_row >= 0 and (empty or not seat_cursor.is_empty())
	if seat_row == Row.ALLY:
		_set_row(seat, ("CPU ally" if model.coop_ally else "No ally") if not seat_cursor.is_empty() else "+ CPU ally",
				seat_cursor, u.color_text_dim)
	else:
		_set_row(seat, ("CPU" if is_cpu else "Open") if not seat_cursor.is_empty() else "+ CPU",
				seat_cursor, u.color_text_dim)

	var character: Label = ui["character"]
	character.visible = not empty
	var char_index := model.coop_ally_char if is_ally else s.char_index
	_set_row(character, MenuHelpers.character_name(ids[clampi(char_index, 0, ids.size() - 1)]),
			_row_cursor(i, Row.CHARACTER, Row.ALLY_CHARACTER if is_ally else Row.CPU_CHARACTER), u.color_text)

	var level: Label = ui["level"]
	level.visible = is_ally or is_cpu
	var level_cursor := _row_cursor(i, -1, Row.ALLY_LEVEL if is_ally else Row.CPU_LEVEL)
	var cpu_level := model.coop_ally_level if is_ally else s.cpu_level
	_set_row(level, Tuning.cpu.level_name(cpu_level), level_cursor, u.color_text_dim)

	var swatch: Label = ui["swatch"]
	swatch.visible = joined_human
	_set_row(swatch, Tuning.colors.color_name(model.resolved_colors()[i]), _row_cursor(i, Row.COLOR, -1), color)

	var team: Label = ui["team"]
	team.visible = model.team_mode() and not empty
	_set_row(team, LobbyModel.team_name(s.team), _row_cursor(i, Row.TEAM, Row.SEAT_TEAM), u.color_text_dim)

	var state: PromptLabel = ui["state"]
	var hint: PromptLabel = ui["hint"]
	# Narrow (compact) cards break their two-part lines; wide ones have the room.
	var br := "\n" if ui["compact"] else "  -  "
	var gap := "\n" if ui["compact"] else " "
	var tip := ""
	if is_ally or is_cpu or s.state == SlotState.READY:
		state.template = "READY!"
		state.set_color(u.color_ready)
		if mine and not is_cpu:
			tip = "%s cancel" % _key_pair("back", i, "PAUSE")
		elif not level_cursor.is_empty():
			tip = Tuning.cpu.level_blurb(cpu_level)
	elif s.state == SlotState.EMPTY:
		# Both join buttons: whoever wants in may be on the other device.
		state.template = "PRESS {pad:start} / {key:start}" if _can_join_more() \
			else "WAITING FOR%sA PLAYER..." % gap
		state.set_color(u.color_text)
	elif _focus.has(i):
		state.template = "AT SEAT %d" % (focus_of(i) + 1)
		state.set_color(color)
		tip = "%s next seat%s%s back" % [_key_pair("seat", i, "HEAVY"), br, _key_pair("back", i, "PAUSE")]
	else:
		state.template = "CHOOSE!"
		state.set_color(color)
		if mine:
			tip = "%s ready" % _key_pair("accept", i, "LIGHT")
			if not seat_targets_for(i).is_empty():
				tip += "%s%s %s" % [br, _key_pair("seat", i, "HEAVY"), _seats_word()]
	# The card's player's own glyphs, whatever device the screen shows.
	hint.set_prompt(tip, "", _device_kind(i) if mine else -1, _device_id(i) if mine else -1, binding_slot(i))
	hint.visible = tip != ""


## The cursor on one of slot `i`'s lines: its player's own (`own_row`, a
## rows_for row) or a local player's seat cursor (`seat_row`). Returns the
## colour to draw it in, as [Color], or [] for no cursor.
func _row_cursor(i: int, own_row: int, seat_row: int) -> Array:
	var s := slots[i]
	if own_row >= 0 and s.type == SlotType.HUMAN and s.state == SlotState.JOINED and s.cursor == own_row \
			and not _focus.has(i):
		return [_ui[i]["color"]]
	if seat_row >= 0:
		for p: int in _focus:
			if _focus[p]["target"] == i and _focus[p]["row"] == seat_row:
				return [_ui[p]["color"]]
	return []


## A card line: "<  value  >" in the cursor's colour, or the plain value.
static func _set_row(label: Label, text: String, cursor: Array, plain: Color) -> void:
	label.text = text if cursor.is_empty() else "<  %s  >" % text
	label.add_theme_color_override("font_color", plain if cursor.is_empty() else cursor[0])


## What X does for the players of this mode.
func _seats_word() -> String:
	if is_coop():
		return "CPU ally"
	return "CPUs and teams" if is_online() and model.team_mode() else ("CPUs" if model.team_mode() else "CPU")


## The prompt token for what a lobby command is on slot `i`'s device: the
## shared pad button `pad_token` for a pad player, the key bound to `action`
## in a keyboard player's layout.
func _key_pair(pad_token: String, i: int, action: String) -> String:
	if _device_kind(i) != Bindings.Kind.KEYBOARD:
		return "{%s}" % pad_token
	return "{@%s}" % action


## The rules in one line, under the cards.
func _refresh_rules() -> void:
	var parts: PackedStringArray = []
	var time: int = model.time_options[model.time_index]
	if is_coop():
		if model.coop_structure != CoopConfig.Structure.WAVES:
			parts.append("Brawl: %d enemies" % model.coop_enemy_count)
		elif model.coop_endless():
			parts.append("Endless waves from %d" % model.coop_enemy_count)
		else:
			parts.append("%d waves of %d" % [model.coop_waves, model.coop_enemy_count])
		parts.append(Tuning.cpu.level_name(model.coop_enemy_level))
		if model.friendly_fire:
			parts.append("Friendly fire")
		if time > 0:
			parts.append("%d s" % time)
		if model.coop_ally and model.ally_place() < 0:
			parts.append("+ CPU ally")  # every card has a player
	else:
		parts.append("First to %d" % model.rounds_to_win)
		parts.append("Timer %s" % MenuHelpers.round_time_label(time))
	parts.append(ArenaCatalog.display_name(ArenaCatalog.IDS[model.stage_index]))
	_rules_label.text = "  -  ".join(parts)


## Name and value of a rule row.
func _rule_text(r: int) -> Array:
	var ids := MenuHelpers.character_ids()
	var waves := model.coop_structure == CoopConfig.Structure.WAVES
	match r:
		Row.LOCK_TEAMS:
			return ["Lock teams", "On" if model.lock_teams else "Off"]
		Row.ROUNDS:
			return ["Rounds to win", str(model.rounds_to_win)]
		Row.TIMER:
			return ["Time limit" if is_coop() else "Timer", MenuHelpers.round_time_label(model.time_options[model.time_index])]
		Row.STAGE:
			return ["Stage", ArenaCatalog.display_name(ArenaCatalog.IDS[model.stage_index])]
		Row.COOP_STRUCTURE:
			return ["Run", "Waves" if waves else "Brawl"]
		Row.ENEMY_COUNT:
			return [("First wave" if model.coop_endless() else "Enemies per wave") if waves else "Enemies",
					str(model.coop_enemy_count)]
		Row.WAVES:
			return ["Waves", "Endless" if model.coop_endless() else str(model.coop_waves)]
		Row.ENEMY_LEVEL:
			return ["Enemy level", Tuning.cpu.level_name(model.coop_enemy_level)]
		Row.ENEMY_ROSTER:
			return ["Enemy roster", "Random" if model.coop_roster == 0
					else MenuHelpers.character_name(ids[clampi(model.coop_roster - 1, 0, ids.size() - 1)])]
		Row.ALLY:
			return ["Ally", "CPU" if model.coop_ally else "None"]
		Row.ALLY_LEVEL:
			return ["Ally level", Tuning.cpu.level_name(model.coop_ally_level)]
		Row.ALLY_CHARACTER:
			return ["Ally fighter", MenuHelpers.character_name(ids[clampi(model.coop_ally_char, 0, ids.size() - 1)])]
		Row.FRIENDLY_FIRE:
			return ["Friendly fire", "On" if model.friendly_fire else "Off"]
	return ["", ""]


func _action_text(a: int) -> String:
	match a:
		ACT_COPY:
			return "Copy the invite link" if Net.invite_text() != Net.room_code else \
				("Copy the room code" if Net.backend == PlatformCaps.NetBackend.WEBRTC else "Copy the address")
		ACT_ROOM:
			if not is_online():
				return "Open an online room (room code)" if two_room_kinds() else "Open an online room"
			return "Close the room" if Net.is_host() else "Leave the room"
		ACT_DIRECT:
			return "Open an online room (direct IP)"
	return "Done"


func _refresh_options() -> void:
	_options.visible = _options_open
	if not _options_open:
		return
	var u := UiTheme.tuning()
	var items := option_items()
	if not _options_item in items:
		_options_item = items[0]
	var mine := can_manage()
	for item: int in _option_controls:
		var c: Control = _option_controls[item]
		var on := item == _options_item
		c.visible = item in items
		if item >= 0:
			var t := _rule_text(item)
			var l: Label = _row_labels[item]
			l.text = "%s:  %s" % [t[0], t[1]]
			l.add_theme_color_override("font_color", u.color_focus if on else (u.color_text if mine else u.color_text_dim))
			for arrow: int in [0, 2]:
				(c.get_child(arrow) as Button).modulate.a = 1.0 if mine else 0.0
				(c.get_child(arrow) as Button).disabled = not mine
		else:
			(c as Button).text = _action_text(item)
			for col in ["font_color", "font_hover_color"]:
				c.add_theme_color_override(col, u.color_focus if on else u.color_text)
	_options_header.text = ("CO-OP RUN" if is_coop() else "MATCH RULES") + ("" if mine else "  (THE HOST'S)")
	_options_hint.template = "{up_down} row     {left_right} change     {accept} select     {back} back" if mine \
		else "The host sets the rules     {back} back"
	(func() -> void:
		if _options_open and _option_controls.has(_options_item):
			_options_scroll.ensure_control_visible(_option_controls[_options_item])).call_deferred()


func _refresh_hint() -> void:
	# Shared keys only: a keyboard player's own layout keys are on their card.
	var owner_keys := can_manage()
	_hint_label.template = "{start} join     {accept} ready     {back} back%s     {options} options" \
			% ("     {tab_prev}/{tab_next} game     {seat} seats" if owner_keys else "")
	_hint_label.key_template = "{accept} join     {back} back%s     {options} options" \
			% ("     {tab_prev}/{tab_next} game" if owner_keys else "")


func _online_label(peer: int) -> String:
	var ms := Net.room.ping_ms(peer) if Net.room != null else -1.0
	return "Online  -  %d ms" % roundi(ms) if ms >= 0.0 else "Online"


func _refresh_room() -> void:
	if _room_label == null:
		return
	var by_code := Net.backend == PlatformCaps.NetBackend.WEBRTC
	_copy_button.visible = _can_copy()
	_copy_button.text = "Copy link" if by_code and Net.invite_text() != Net.room_code else "Copy"
	_direct_button.visible = not is_online() and two_room_kinds()
	var parts: PackedStringArray = []
	if not is_online():
		parts.append("Local")
		_room_button.text = "Room code" if two_room_kinds() else "Open online"
	elif Net.is_host() and by_code:
		parts.append("Hosting")
		parts.append("Room code: %s" % Net.room_code if not Net.room_code.is_empty()
				else ("Opening room…" if Net.signaling_error_text.is_empty() else "No room code"))
		if not Net.signaling_error_text.is_empty():
			parts.append(Net.signaling_error_text)
		_room_button.text = "Close room"
	elif Net.is_host():
		var port := Net.settings.host_port()
		var lan := UpnpHelper.local_addresses()
		parts.append("Hosting")
		if not lan.is_empty():
			parts.append(_with_port(lan[0], port))
		match Net.upnp.status:
			UpnpHelper.Status.MAPPED:
				parts.append("Public %s (UPnP)" % _with_port(Net.upnp.external_ip, port))
			UpnpHelper.Status.WORKING:
				parts.append("UPnP...")
			UpnpHelper.Status.FAILED:
				parts.append("UPnP failed - forward UDP %d or use LAN/VPN" % port)
		_room_button.text = "Close room"
	else:
		var host := Net.session.peer_name(Transport.HOST_PEER)
		parts.append("Connected to %s" % host)
		var ms := Net.room.ping_ms(Transport.HOST_PEER)
		if ms >= 0.0:
			parts.append("%d ms" % roundi(ms))
		_room_button.text = "Leave"
	if _notice != "":
		parts.append(_notice)
	_room_label.text = "  -  ".join(parts)


func _refresh_status() -> void:
	if _status_label == null:
		return
	# {seat} on the keyboard: the first local keyboard player's layout key.
	var kb := keyboard_slots()
	var profile := binding_slot(kb[0]) if not kb.is_empty() else 0
	if _status_label.slot != profile:
		_status_label.slot = profile
		_status_label.refresh()
	if is_online():
		_refresh_room()
	if _started:
		_status_label.template = "FIGHT!"
	elif is_online() and Net.room.countdown != OnlineRoom.NO_COUNTDOWN:
		_status_label.template = "GET READY... %d" % Net.room.countdown_seconds()
	elif not is_online() and all_ready() and not _options_open:
		_status_label.template = "GET READY... %d" % ceili(maxf(_countdown, 0.0))
	elif local_slots().is_empty():
		_status_label.template = "{back} leave the room" if is_online() else "{back} back to menu"
	elif is_online() and is_coop():
		_status_label.template = _coop_online_status()
	elif model.team_mode() and not model.teams_ok():
		_status_label.template = ("Waiting for an opponent to join (or seat a CPU with {seat})..." if Net.is_host()
				else "Waiting for an opponent to join...") if is_online() \
			else "Needs two fighters on two teams ({seat} seats a CPU)"
	elif is_online():
		var waiting := local_slots().all(func(i: int) -> bool: return slots[i].state == SlotState.READY)
		_status_label.template = "Waiting for everyone to ready up..." if waiting else ""
	else:
		_status_label.template = ""


## Online co-op starts once every joined player is ready, however many joined.
func _coop_online_status() -> String:
	var waiting := local_slots().all(func(i: int) -> bool: return slots[i].state == SlotState.READY)
	var text := "Waiting for everyone to ready up..." if waiting else "Ready up to start the run"
	if model.first_free_slot() >= 0:
		text += "  -  more players can still join"
	return text


func _punch_panel(idx: int) -> void:
	if idx >= 0 and idx < _ui.size():
		MenuHelpers.punch(_ui[idx]["panel"])
