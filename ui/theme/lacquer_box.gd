@tool
class_name LacquerBox
extends StyleBox
## The Jade Lacquer box: a flat fill with a border, optionally pointed ends
## (`point` px deep, buttons), a thin inner line (panels) and an outer glow
## (focus). Built by UiTheme from Tuning.ui; presentation only.

@export var bg_color := Color.BLACK:
	set(v):
		bg_color = v
		emit_changed()
@export var border_color := Color.WHITE:
	set(v):
		border_color = v
		emit_changed()
@export var border_width := 2.0:
	set(v):
		border_width = v
		emit_changed()
## Depth of the left/right points; 0 = a rectangle.
@export var point := 0.0:
	set(v):
		point = v
		emit_changed()
## Corner cut of a rectangle (px); ignored when pointed.
@export var corner_cut := 0.0:
	set(v):
		corner_cut = v
		emit_changed()
@export var inner_line_color := Color.TRANSPARENT:
	set(v):
		inner_line_color = v
		emit_changed()
@export var inner_line_inset := 6.0:
	set(v):
		inner_line_inset = v
		emit_changed()
@export var glow_color := Color.TRANSPARENT:
	set(v):
		glow_color = v
		emit_changed()
@export var glow_size := 0.0:
	set(v):
		glow_size = v
		emit_changed()
## Grows the drawn shape past the control's rect (like StyleBoxFlat's).
@export var expand := Vector2.ZERO:
	set(v):
		expand = v
		emit_changed()

const GLOW_STEPS := 4


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(expand.x, expand.y, expand.x, expand.y)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var r := _get_draw_rect(rect)
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	var rs := RenderingServer
	if glow_size > 0.0 and glow_color.a > 0.0:
		for i in GLOW_STEPS:
			var k := float(GLOW_STEPS - i) / GLOW_STEPS
			var g := Color(glow_color, glow_color.a * (1.0 - k) * 0.6)
			_fill(to_canvas_item, shape(r.grow(glow_size * k), point + glow_size * k * 0.5, corner_cut), g)
	var outer := shape(r, point, corner_cut)
	# Too small for the frame (the insets would cross): a plain fill.
	var frame := 2.0 * (border_width + maxf(inner_line_inset, 0.0) + corner_cut)
	if r.size.x <= frame or r.size.y <= frame:
		_fill(to_canvas_item, outer, bg_color if bg_color.a > 0.0 else border_color)
		return
	if border_width > 0.0 and border_color.a > 0.0:
		var inner := inset(outer, border_width)
		_fill(to_canvas_item, inner, bg_color)
		# The border is a ring (one quad per edge), so a translucent fill
		# never shows the border colour through it.
		for i in outer.size():
			var j := (i + 1) % outer.size()
			_fill(to_canvas_item, PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), border_color)
		_line(to_canvas_item, outer, border_color)
	else:
		_fill(to_canvas_item, outer, bg_color)
		_line(to_canvas_item, outer, bg_color)
	if inner_line_color.a > 0.0 and inner_line_inset > 0.0:
		var line := inset(outer, inner_line_inset)
		if line.size() >= 3:
			var closed := line.duplicate()
			closed.append(line[0])
			rs.canvas_item_add_polyline(to_canvas_item, closed, PackedColorArray([inner_line_color]), 1.0, true)


## The outline of `r`: a hexagon with `p`-deep side points, else a rectangle
## with `cut` corners.
static func shape(r: Rect2, p: float, cut: float = 0.0) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var ym := (y0 + y1) * 0.5
	p = minf(p, r.size.x * 0.25)
	if p > 0.0:
		return PackedVector2Array([Vector2(x0 + p, y0), Vector2(x1 - p, y0), Vector2(x1, ym),
				Vector2(x1 - p, y1), Vector2(x0 + p, y1), Vector2(x0, ym)])
	cut = minf(cut, minf(r.size.x, r.size.y) * 0.5)
	if cut > 0.0:
		return PackedVector2Array([Vector2(x0 + cut, y0), Vector2(x1 - cut, y0), Vector2(x1, y0 + cut),
				Vector2(x1, y1 - cut), Vector2(x1 - cut, y1), Vector2(x0 + cut, y1),
				Vector2(x0, y1 - cut), Vector2(x0, y0 + cut)])
	return PackedVector2Array([r.position, Vector2(x1, y0), r.end, Vector2(x0, y1)])


## Convex polygon `pts` moved `d` px inwards, vertex for vertex (each new
## vertex is where its two offset edges meet).
static func inset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	var sgn := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var e1 := (b - a).normalized()
		var e2 := (c - b).normalized()
		# Inward normals (y down: a positive area runs clockwise on screen).
		var n1 := Vector2(-e1.y, e1.x) * sgn
		var n2 := Vector2(-e2.y, e2.x) * sgn
		var hit: Variant = Geometry2D.line_intersects_line(a + n1 * d, e1, b + n2 * d, e2)
		out[i] = hit if hit != null else b + n1 * d
	return out


static func _fill(ci: RID, pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3 and c.a > 0.0:
		RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([c]))


## Antialiased edge over a filled shape (polygons have hard edges).
static func _line(ci: RID, pts: PackedVector2Array, c: Color) -> void:
	if pts.size() >= 3 and c.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, closed, PackedColorArray([c]), 1.0, true)
