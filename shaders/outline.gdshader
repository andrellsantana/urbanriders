// Contorno de quadrinho por casca invertida (inverted hull).
// mode 0: expande pela normal | 1: caixa centrada (sign) | 2: direção pré-calculada em CUSTOM0 (malhas agrupadas)
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.06, 0.02, 0.03, 1.0);
uniform float width = 0.02;
uniform int mode = 0;

void vertex() {
	if (mode == 1) {
		VERTEX += sign(VERTEX) * width;
	} else if (mode == 2) {
		VERTEX += CUSTOM0.xyz * width;
	} else {
		VERTEX += NORMAL * width;
	}
}

void fragment() {
	ALBEDO = color.rgb;
}
