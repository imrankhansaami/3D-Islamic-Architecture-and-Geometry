shader_type spatial;
// Water surface for the courtyard fountain.
// Vertex displacement produces gentle concentric ripples; the fragment stage
// adds a subtle normal perturbation for reflections. Kept intentionally simple
// so it runs on both Forward+ and the Compatibility renderer.

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.07, 0.30, 0.34, 0.88);
uniform vec4 deep_color : source_color = vec4(0.03, 0.13, 0.19, 0.92);
uniform float wave_strength : hint_range(0.0, 0.2) = 0.035;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.0;
uniform float wave_scale : hint_range(0.5, 6.0) = 2.2;

void vertex() {
	float t = TIME * wave_speed;
	// Two superposed radial waves from the fountain centre (local origin).
	float r = length(VERTEX.xz);
	VERTEX.y += sin(r * wave_scale * 3.0 - t * 1.7) * wave_strength;
	VERTEX.y += cos(VERTEX.x * wave_scale * 2.1 + t * 1.1) * wave_strength * 0.5;
}

void fragment() {
	float t = TIME * wave_speed;
	float ripple = sin(VERTEX.x * wave_scale * 4.0 + t * 1.6)
		* cos(VERTEX.z * wave_scale * 3.6 + t * 1.3);
	float depth_mix = clamp(length(VERTEX.xz) * 0.22, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, water_color.rgb, depth_mix) * (0.92 + 0.08 * ripple);
	ALPHA = mix(deep_color.a, water_color.a, depth_mix);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.8;
	NORMAL = normalize(NORMAL + vec3(ripple * 0.03, 0.0, ripple * 0.03));
}
