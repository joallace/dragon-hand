class_name AnimatedBackground
extends ColorRect
## Cheap full-screen animated backdrop: black lacquer covered in drifting
## dragon scales, a slow jade glint sweeping across them, gold-rimmed vignette
## (single canvas shader, no textures).

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 col_bg : source_color = vec4(0.043, 0.078, 0.071, 1.0);
uniform vec4 col_scale : source_color = vec4(0.184, 0.749, 0.561, 1.0);
uniform vec4 col_gold : source_color = vec4(0.914, 0.725, 0.286, 1.0);
uniform float speed = 0.25;
uniform float aspect = 1.777;
uniform float scale_count = 22.0;
uniform float rim_alpha = 0.22;

void fragment() {
	vec2 uv = UV * vec2(aspect, 1.0);
	float t = TIME * speed;
	// Fish-scale tiling: rows offset by half a cell, each cell an arc open
	// downward (the scale above overlaps the one below).
	vec2 g = (uv + vec2(t * 0.08, -t * 0.05)) * vec2(scale_count, scale_count * 1.6);
	float row = floor(g.y);
	g.x += mod(row, 2.0) * 0.5;
	vec2 cell = fract(g) - vec2(0.5, 0.0);
	float d = length(cell * vec2(1.0, 1.6));
	float rim = smoothstep(0.08, 0.0, abs(d - 0.5));
	float body = smoothstep(0.5, 0.2, d);
	// Diagonal glint band crossing the screen.
	float band = uv.x * 0.7 + UV.y * 0.6 - fract(t * 0.15) * 3.0 + 0.6;
	float glint = exp(-band * band * 18.0);
	vec2 c = (UV - vec2(0.5, 0.42)) * vec2(aspect, 1.0);
	float r = length(c);
	float vis = smoothstep(1.15, 0.15, r);
	vec3 col = col_bg.rgb;
	col += col_scale.rgb * (rim * rim_alpha + body * 0.03) * (0.35 + 0.65 * vis);
	col += col_scale.rgb * rim * glint * 0.5 * vis;
	col += col_gold.rgb * exp(-r * 3.2) * 0.07;
	col *= 1.0 - smoothstep(0.55, 1.25, r) * 0.7;
	COLOR = vec4(col, 1.0);
}
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var u := UiTheme.tuning()
	var sh := Shader.new()
	sh.code = SHADER_CODE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col_bg", u.color_lacquer)
	m.set_shader_parameter("col_scale", u.color_jade)
	m.set_shader_parameter("col_gold", u.color_gold)
	m.set_shader_parameter("scale_count", u.background_scale_count)
	m.set_shader_parameter("rim_alpha", u.background_rim_alpha)
	m.set_shader_parameter("speed", u.background_speed)
	material = m
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	if size.y > 0.0:
		(material as ShaderMaterial).set_shader_parameter("aspect", size.x / size.y)
