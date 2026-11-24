shader_type spatial;
// Fighter body: flat palette colours (slot = UV.x * PALETTE_SIZE, see
// FighterModel), 2-tone light step, rim on silhouettes, glow via emission.
// Works on every renderer (Compatibility included). Uniforms set by
// FighterModel / FighterVisual from Tuning.vfx.
render_mode specular_disabled, ambient_light_disabled;

const int PALETTE_SIZE = 8;
uniform vec4 palette[PALETTE_SIZE] : source_color;
uniform float threshold = 0.15;
uniform float softness = 0.03;
uniform float shade_floor = 0.35;
uniform float rim_strength = 0.35;
uniform float rim_power = 3.0;
uniform vec3 glow_color : source_color = vec3(1.0);
uniform float glow_energy = 0.0;

void fragment() {
	int slot = clamp(int(UV.x * float(PALETTE_SIZE)), 0, PALETTE_SIZE - 1);
	ALBEDO = palette[slot].rgb;
	ROUGHNESS = 1.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power) * rim_strength;
	EMISSION = ALBEDO * rim + glow_color * glow_energy;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(threshold - softness, threshold + softness, ndl);
	if (LIGHT_IS_DIRECTIONAL) {
		// ATTENUATION is the shadow term here: shadowed = shade.
		lit *= step(0.5, ATTENUATION);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shade_floor, 1.0, lit);
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
	}
}
