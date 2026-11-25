class_name DragonEmblem
extends Control
## The Dragon Hand emblem: a gold open hand inside a jade dragon coiling
## around it, framed by a gold ring and a slowly turning dashed jade ring.
## Drawn from a 100x100 design (the paths below, SVG syntax: absolute M/L/C/Z)
## scaled into the control's square. Presentation only.

const DRAGON := "M50 8 C72 12 88 30 88 50 C88 70 70 88 50 88 C38 88 28 82 22 74 C34 80 50 78 60 68 C70 58 70 40 58 30"
const DRAGON_HEAD := "M58 30 L66 22 L64 32 L72 30"
const HAND := "M38 74 L40 56 C36 54 34 50 35 45 L37 38 C38 35 42 35 43 38 L44 30 C44 27 49 27 49 30 L50 40 L52 31 C53 28 57 29 57 32 L56 46 C58 44 63 44 63 48 C63 51 59 55 55 60 L52 74 Z"
const RING_DASHES := 28

## Dashed ring turn speed (radians per second); 0 = still.
var spin := 0.15

var _dragon: PackedVector2Array
var _head: PackedVector2Array
var _hand: PackedVector2Array
var _angle := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dragon = svg_path(DRAGON)
	_head = svg_path(DRAGON_HEAD)
	_hand = svg_path(HAND)


func _process(delta: float) -> void:
	if spin != 0.0 and is_visible_in_tree():
		_angle = fposmod(_angle + spin * delta, TAU)
		queue_redraw()


func _draw() -> void:
	var u := UiTheme.tuning()
	var side := minf(size.x, size.y)
	var k := side / 100.0
	var origin := (size - Vector2(side, side)) * 0.5
	draw_set_transform(origin, 0.0, Vector2(k, k))
	draw_circle(Vector2(50, 50), 47.5, Color(u.color_lacquer, 0.85))
	draw_arc(Vector2(50, 50), 46.0, 0.0, TAU, 96, u.color_gold, 2.5, true)
	var step := TAU / RING_DASHES
	for i in RING_DASHES:
		var a := _angle + i * step
		draw_arc(Vector2(50, 50), 39.0, a, a + step * 0.55, 6, u.color_jade, 1.2, true)
	draw_polyline(_dragon, u.color_outline, 7.5, true)
	draw_polyline(_dragon, u.color_jade, 5.0, true)
	draw_polyline(_head, u.color_jade, 3.0, true)
	var closed := _hand.duplicate()
	closed.append(_hand[0])
	draw_polyline(closed, u.color_outline, 3.0, true)
	draw_colored_polygon(_hand, u.color_gold)
	draw_polyline(closed, u.color_gold, 1.0, true)
	draw_set_transform(Vector2.ZERO)


## Points of an SVG path using absolute M, L, C and Z (cubics flattened).
static func svg_path(d: String) -> PackedVector2Array:
	for c in ["M", "L", "C", "Z", ","]:
		d = d.replace(c, " %s " % c if c != "," else " ")
	var tokens := d.split(" ", false)
	var out := PackedVector2Array()
	var i := 0
	var cmd := ""
	var pen := Vector2.ZERO
	while i < tokens.size():
		var tok := tokens[i]
		if tok in ["M", "L", "C", "Z"]:
			cmd = tok
			i += 1
			continue
		match cmd:
			"M", "L":
				pen = Vector2(float(tokens[i]), float(tokens[i + 1]))
				out.append(pen)
				i += 2
			"C":
				var c1 := Vector2(float(tokens[i]), float(tokens[i + 1]))
				var c2 := Vector2(float(tokens[i + 2]), float(tokens[i + 3]))
				var end := Vector2(float(tokens[i + 4]), float(tokens[i + 5]))
				var curve := Curve2D.new()
				curve.add_point(pen, Vector2.ZERO, c1 - pen)
				curve.add_point(end, c2 - end, Vector2.ZERO)
				var pts := curve.tessellate(4, 3.0)
				for j in range(1, pts.size()):
					out.append(pts[j])
				pen = end
				i += 6
			_:
				i += 1
	return out
