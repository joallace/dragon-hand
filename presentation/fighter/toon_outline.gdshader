shader_type spatial;
// Inverted-hull outline (next_pass of the toon material): back faces pushed
// out along the normal, flat colour.
render_mode unshaded, cull_front, shadows_disabled;

uniform vec3 outline_color : source_color = vec3(0.05, 0.04, 0.08);
uniform float width = 0.014;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color;
}
