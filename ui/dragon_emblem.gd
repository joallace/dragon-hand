class_name DragonEmblem
extends Control
## The Dragon Hand emblem ("Coiled Fist"): a gold fist with a jade dragon
## coiled up the forearm, roaring over the knuckles, on a lacquer disc framed
## by a gold ring and a slowly turning dashed jade ring.
## The art is ART_PATH (shipped as-is through a "keep" import), rasterized at
## the control's on-screen size with the tuned palette swapped in (art_svg);
## the disc and rings are drawn here so the dashed ring can turn. icon.svg is
## the same art over a static frame (tests/emblem_test keeps them in sync;
## tools/render_boot_splash.gd renders it to the boot splash).
## Presentation only.

const ART_PATH := "res://assets/ui/dragon_emblem.svg"
## Side of the art's viewBox; the frame below is laid out in the same units.
const DESIGN := 100.0
const RING_DASHES := 28
## UiTuning colours the art may use. The SVG is authored in their script
## defaults; art_svg() maps each default to the tuned value.
const PALETTE: Array[StringName] = [
	&"color_outline", &"color_jade", &"color_jade_dark", &"color_gold",
	&"color_gold_light", &"color_ember", &"color_text",
]

## Dashed ring turn speed (radians per second); 0 = still.
var spin := 0.15

var _angle := 0.0
var _svg := ""
var _art: ImageTexture
var _art_px := 0
## The art failed to load or parse: don't retry every redraw.
var _failed := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	# Window size / UI scale change the on-screen size without a resize.
	get_viewport().size_changed.connect(queue_redraw)
	Settings.video_applied.connect(queue_redraw)


func _process(delta: float) -> void:
	if spin != 0.0 and is_visible_in_tree():
		_angle = fposmod(_angle + spin * delta, TAU)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var u := UiTheme.tuning()
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var k := side / DESIGN
	var origin := (size - Vector2(side, side)) * 0.5
	var c := Vector2(DESIGN, DESIGN) * 0.5
	draw_set_transform(origin, 0.0, Vector2(k, k))
	draw_circle(c, 47.5, Color(u.color_lacquer, 0.85))
	draw_arc(c, 46.0, 0.0, TAU, 96, u.color_gold, 2.5, true)
	var step := TAU / RING_DASHES
	for i in RING_DASHES:
		var a := _angle + i * step
		draw_arc(c, 39.0, a, a + step * 0.55, 6, u.color_jade, 1.2, true)
	draw_set_transform(Vector2.ZERO)
	var tex := art_texture(ceili(side * get_screen_transform().get_scale().x))
	if tex != null:
		draw_texture_rect(tex, Rect2(origin, Vector2(side, side)), false)


## The art rasterized at px x px (cached until the size changes); null if the
## SVG is missing or fails to parse.
func art_texture(px: int) -> ImageTexture:
	px = maxi(px, 1)
	if _art != null and _art_px == px:
		return _art
	if _failed:
		return null
	if _svg.is_empty():
		_svg = art_svg(UiTheme.tuning())
	var img := rasterize(_svg, px)
	if img == null:
		_failed = true
		push_error("DragonEmblem: cannot rasterize %s" % ART_PATH)
		return null
	_art = ImageTexture.create_from_image(img)
	_art_px = px
	return _art


## The art's SVG source with its default palette replaced by u's colours
## (one pass, so a tuned colour equal to another default isn't remapped).
static func art_svg(u: UiTuning) -> String:
	var src := FileAccess.get_file_as_string(ART_PATH)
	if src.is_empty():
		push_error("DragonEmblem: cannot read %s" % ART_PATH)
		return ""
	var defaults := UiTuning.new()
	var swap := {}
	for prop in PALETTE:
		var key := (defaults.get(prop) as Color).to_html(false)
		if not swap.has(key):
			swap[key] = (u.get(prop) as Color).to_html(false)
	var re := RegEx.create_from_string("#([0-9a-fA-F]{6})\\b")
	var out := ""
	var at := 0
	for m in re.search_all(src):
		var hex := m.get_string(1).to_lower()
		out += src.substr(at, m.get_start(1) - at) + str(swap.get(hex, hex))
		at = m.get_end(1)
	return out + src.substr(at)


## svg (DESIGN units square) rendered to a px x px image, or null.
static func rasterize(svg: String, px: int) -> Image:
	if svg.is_empty():
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg, px / DESIGN) != OK:
		return null
	if img.get_width() != px or img.get_height() != px:
		img.resize(px, px, Image.INTERPOLATE_BILINEAR)
	return img
