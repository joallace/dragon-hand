class_name HudTimerDisc
extends Control
## Lacquer disc with a gold ring, drawn behind the round timer.


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var t := Tuning.hud
	var c := size * 0.5
	var r := t.timer_disc_radius
	draw_circle(c, r + t.timer_disc_ring_width, t.outline_color)
	draw_circle(c, r, t.bar_bg_color)
	draw_arc(c, r, 0.0, TAU, 64, t.bar_border_color, t.timer_disc_ring_width, true)
