// Sem iluminação, cor por vértice (janelas acesas, luzes de varanda).
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float energy = 1.0;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * energy;
}
