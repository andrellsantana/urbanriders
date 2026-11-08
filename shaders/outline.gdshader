// Contorno de quadrinho por casca invertida (inverted hull).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.06, 0.02, 0.03, 1.0);
uniform float width = 0.02;
uniform bool box_mode = false;

void vertex() {
	if (box_mode) {
		VERTEX += sign(VERTEX) * width;
	} else {
		VERTEX += NORMAL * width;
	}
}

void fragment() {
	ALBEDO = color.rgb;
}
