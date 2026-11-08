// Céu vermelho tempestuoso de Red City (nuvens animadas + relâmpagos raros).
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.22, 0.02, 0.04);
uniform vec3 horizon_color : source_color = vec3(0.95, 0.22, 0.08);
uniform vec3 cloud_dark : source_color = vec3(0.12, 0.01, 0.03);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.35, 0.18);
uniform vec3 ground_color : source_color = vec3(0.18, 0.04, 0.05);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.45));
	if (AT_CUBEMAP_PASS) {
		COLOR = d.y < 0.0 ? ground_color : col;
	} else if (d.y < 0.0) {
		COLOR = mix(horizon_color * 0.6, ground_color, clamp(-d.y * 4.0, 0.0, 1.0));
	} else {
		vec2 uv = d.xz / (d.y + 0.12) * 0.9;
		float t = TIME * 0.015;
		float c = fbm(uv + vec2(t, t * 0.6));
		float c2 = fbm(uv * 2.2 - vec2(t * 1.7, 0.0));
		float clouds = smoothstep(0.38, 0.78, c * 0.7 + c2 * 0.4);
		float fade = smoothstep(0.0, 0.18, d.y);
		vec3 cloud_col = mix(cloud_lit, cloud_dark, smoothstep(0.45, 0.9, c2));
		col = mix(col, cloud_col, clouds * fade * 0.85);
		// relâmpago raro
		float slot = floor(TIME * 1.5);
		float flash = step(0.97, hash(vec2(slot, 7.0))) * (1.0 - fract(TIME * 1.5));
		col += vec3(1.0, 0.55, 0.45) * flash * clouds * 0.6;
		COLOR = col;
	}
}
