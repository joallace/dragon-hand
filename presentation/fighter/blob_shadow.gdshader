shader_type spatial;
// Soft round shadow decal under a fighter (a quad on the floor): cheap
// stand-in for real-time shadows, readable on every renderer.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity = 0.45;
// 0 = full opacity .. 1 = gone (height, co-op KO fade).
uniform float fade = 0.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = opacity * (1.0 - fade) * (1.0 - smoothstep(0.55, 1.0, d));
}
