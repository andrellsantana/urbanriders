extends RefCounted
## Fábrica (com cache) de materiais Cel Shading com contorno de quadrinho.

const TOON: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE: Shader = preload("res://shaders/outline.gdshader")

enum Outline { NONE, SMOOTH, BOX }

static var _cache: Dictionary = {}


## SMOOTH: expande pela normal (cilindros, esferas). BOX: expande pelos cantos (caixas centradas).
static func make(color: Color, outline: Outline = Outline.SMOOTH, width: float = 0.02) -> ShaderMaterial:
	var key := "%s|%d|%.3f" % [color.to_html(), outline, width]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", color)
	if outline != Outline.NONE:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", width)
		o.set_shader_parameter("box_mode", outline == Outline.BOX)
		mat.next_pass = o
	_cache[key] = mat
	return mat
