// Cel Shading barato: 3 faixas de luz + brilho de borda (rim).
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float rim_strength = 0.25;

void fragment() {
	vec3 vc = use_vertex_color ? pow(COLOR.rgb, vec3(2.2)) : vec3(1.0);
	ALBEDO = albedo.rgb * vc;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = mix(0.0, 0.45, step(0.04, ndl));
	band = mix(band, 1.0, smoothstep(0.42, 0.48, ndl));
	float rim = smoothstep(0.62, 0.68, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0)) * step(0.04, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * (band + rim * rim_strength);
}
