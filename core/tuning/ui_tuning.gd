class_name UiTuning
extends Resource
## Menu look & feel (data/tuning/ui.tres when present). Read by UiTheme and the
## menu screens in scenes/menus/. Change colors/sizes/timeouts here.

@export_group("Palette")
@export var color_orange: Color = Color(1.0, 0.55, 0.08)
@export var color_orange_light: Color = Color(1.0, 0.78, 0.25)
@export var color_blue: Color = Color(0.10, 0.32, 0.85)
@export var color_blue_dark: Color = Color(0.04, 0.09, 0.28)
@export var color_panel: Color = Color(0.03, 0.06, 0.18, 0.88)
@export var color_text: Color = Color(1.0, 0.98, 0.92)
@export var color_text_dim: Color = Color(0.70, 0.75, 0.90)
@export var color_outline: Color = Color(0.05, 0.02, 0.0)
@export var color_focus: Color = Color(1.0, 0.92, 0.2)
@export var color_disabled: Color = Color(0.35, 0.38, 0.48)
@export var color_ready: Color = Color(0.35, 1.0, 0.4)

@export_group("Sizes")
@export var font_title: int = 64
@export var font_header: int = 38
@export var font_button: int = 28
@export var font_body: int = 22
@export var font_hint: int = 18
@export var outline_title: int = 16
@export var outline_text: int = 8
@export var font_embolden: float = 0.6
@export var button_min_size: Vector2 = Vector2(460, 52)
@export var corner_radius: int = 6
@export var border_width: int = 4
@export var focus_border_width: int = 6
## Horizontal skew of button/panel boxes (fighting-game slant).
@export var box_skew: float = 0.18
@export var list_separation: int = 10

@export_group("Button prompts")
## Glyph size relative to the text around it (Promptfont glyphs are 1 em).
@export var prompt_glyph_scale: float = 1.3
## A stick pushed past this switches the legends to the gamepad (Prompts).
@export var prompt_pad_axis_threshold: float = 0.5
## Keyboard keycaps, and the text keycap of keys without a glyph.
@export var prompt_key_color: Color = Color(1.0, 0.98, 0.92)
@export var prompt_keycap_text_color: Color = Color(0.05, 0.02, 0.0)
## Text keycap size relative to a glyph.
@export var prompt_keycap_text_scale: float = 0.6
## Pad buttons without a brand colour (shoulders, triggers, sticks, d-pad).
@export var prompt_pad_color: Color = Color(1.0, 0.98, 0.92)
## Face buttons per style, ordered bottom, right, left, top (Xbox A, B, X,
## Y). An empty array draws that style's face buttons in prompt_pad_color.
@export var prompt_xbox_face_colors: PackedColorArray = PackedColorArray([
	Color(0.38, 0.78, 0.25), Color(0.93, 0.25, 0.22), Color(0.2, 0.52, 0.95), Color(1.0, 0.78, 0.1)])
@export var prompt_playstation_face_colors: PackedColorArray = PackedColorArray([
	Color(0.49, 0.7, 0.95), Color(1.0, 0.4, 0.4), Color(0.9, 0.6, 0.79), Color(0.25, 0.89, 0.63)])
@export var prompt_nintendo_face_colors: PackedColorArray = PackedColorArray()

@export_group("Feel")
## Scale punch on button press.
@export var press_punch_scale: float = 0.92
@export var press_punch_time: float = 0.12
@export var title_pulse_speed: float = 1.6
@export var background_speed: float = 0.25

@export_group("Controls screen")
## Seconds before an unanswered "Press a button..." prompt cancels.
@export var rebind_timeout_seconds: float = 5.0
## Minimum seconds after entering listening before input is accepted
## (plus the confirm press must have been released).
@export var rebind_arm_delay: float = 0.15

@export_group("Layout")
## Vertical gap between the main menu's title, subtitle, buttons and hint.
@export var main_menu_separation: int = 10
## How-to-play overlay: space kept free around the panel (x: sides, y: top/bottom).
@export var how_to_margin: Vector2 = Vector2(48, 20)
## How-to-play grid gaps (x: between columns, y: between rows).
@export var how_to_grid_separation: Vector2i = Vector2i(40, 6)
## Pixels scrolled per ui_up / ui_down press (held keys repeat).
@export var how_to_scroll_step: float = 64.0
## Right-stick scroll speed (pixels per second at full deflection).
@export var how_to_stick_scroll_speed: float = 900.0
## Right-stick deflection below which the how-to-play list doesn't scroll.
@export var how_to_stick_deadzone: float = 0.3

@export_group("Join screen")
## Space kept free around the join screen (x: sides, y: top/bottom).
@export var join_margin: Vector2 = Vector2(24, 12)
## Gap between the mode tabs, the room bar, the cards, the rules line, the
## status and the hint lines.
@export var join_root_separation: int = 4
## Gap between the slot cards (and between the room bar's items).
@export var join_column_separation: int = 16
## Game mode tabs (LB / RB) at the top of the lobby, and the gap between them.
@export var join_tab_font: int = 34
@export var join_tab_separation: int = 28
## Player panel: "CHOOSE!" / "READY!" state line and the fighter name.
@export var join_state_font: int = 30
@export var join_character_font: int = 26
## Rows of a card under the fighter name (colour, team, CPU level) and the
## rules summary line.
@export var join_row_font: int = 20
## Opacity of a card nobody sits in.
@export var join_empty_card_alpha: float = 0.6
## "PRESS START" prompt of an empty card: lowest opacity and pulse speed.
@export var join_blink_min_alpha: float = 0.55
@export var join_blink_speed: float = 3.0
## Seconds a notice stays in the room bar (copied, port in use...).
@export var join_notice_seconds: float = 4.0
## Match options overlay: panel width, rule row font and gap, and the width
## of a row's "<" / ">" buttons (mouse / touch).
@export var join_options_width: float = 620.0
@export var join_options_row_font: int = 22
@export var join_row_separation: int = 2
@export var join_options_arrow_width: float = 56.0
## Border width of the P1/P2-coloured player panels.
@export var join_panel_border: int = 6
## More than two cards: they share the row with these smaller fonts and a
## thinner inner padding.
@export var join_compact_header_font: int = 24
@export var join_compact_state_font: int = 22
@export var join_compact_character_font: int = 20
@export var join_compact_panel_margin: int = 6
## Seconds between "all ready" and the match starting (cancel by un-readying).
@export var join_start_delay: float = 1.0
## Stick deflection that counts as a menu direction on the join screen.
@export var stick_nav_threshold: float = 0.6

@export_group("Results screen")
## Vertical gap between the headline, tally and button list (versus).
@export var results_separation: int = 30
## Tighter gap used by the co-op layout (headline, team line, table, buttons).
@export var results_coop_separation: int = 8
## Headline scale pulse: amplitude (fraction of size) and speed (rad/s).
@export var results_pulse_amount: float = 0.04
@export var results_pulse_speed: float = 4.0
## Versus headline when the winning team has 2+ fighters (their tags joined
## by Tuning.hud.text_team_join): "P1 & P3 WIN!".
@export var results_text_team_winner: String = "%s WIN!"
## Co-op stats table: min width of the row-label column / each player column,
## gaps between cells, and the tallest it may get before it scrolls.
@export var results_label_col_width: int = 230
@export var results_player_col_width: int = 190
@export var results_table_h_gap: int = 18
@export var results_table_v_gap: int = 0
@export var results_table_max_height: int = 260
## Inner padding of the stats panel.
@export var results_panel_padding: int = 10
## Online co-op: the Retry / Lobby / Save replay / Leave buttons go in a grid
## this many columns wide (under the stats table).
@export var results_online_coop_button_columns: int = 2

@export_group("Online screens")
## Settings and join-online screens: gap between the title, rows and footer.
@export var online_separation: int = 14
## Width of the text fields (profile name, port, address).
@export var online_field_width: int = 420
## Label column width on the settings screen's text-field rows.
@export var online_label_width: int = 220
## Recent hosts list: tallest it gets before it scrolls, row height, and the
## size of each row's delete ("x") button.
@export var online_recent_max_height: int = 260
@export var online_recent_row_height: int = 46
@export var online_delete_button_size: Vector2 = Vector2(56, 46)
## Status / error line colours.
@export var color_error: Color = Color(1.0, 0.4, 0.35)
@export var color_ok: Color = Color(0.35, 1.0, 0.4)
## Web, online: a tab hidden (or unfocused) at least this long shows the
## "keep this tab in front" warning when the player comes back, for
## background_tab_warning_seconds (any key / click dismisses it).
@export var background_tab_min_hidden_seconds: float = 1.0
@export var background_tab_warning_seconds: float = 8.0
## Its distance from the top of the screen.
@export var background_tab_warning_margin: int = 24

@export_group("Settings screen")
## Gap between the title, tab bar, page and footer; outer margin (x, y).
@export var settings_separation: int = 8
@export var settings_margin: Vector2 = Vector2(80, 16)
## Tab bar: gap between tabs, tab font size.
@export var settings_tab_separation: int = 28
@export var settings_tab_font: int = 30
## Width of the option rows on the Graphics / Audio / Online pages.
@export var settings_row_width: int = 640
## Number steppers: held repeats before the fast step kicks in.
@export var stepper_fast_after_repeats: int = 6
## Host port stepper: fast (held) step.
@export var port_step_fast: int = 100
## Confirm prompts (reset, keep display settings): panel padding and width.
@export var confirm_padding: int = 28
@export var confirm_width: int = 620
