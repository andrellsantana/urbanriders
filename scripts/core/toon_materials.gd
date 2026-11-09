extends RefCounted
## Fábrica (com cache) de materiais Cel Shading com contorno de quadrinho.

const TOON: Shader = preload("res://shaders/toon.gdshader")
const OUTLINE: Shader = preload("res://shaders/outline.gdshader")
const UNLIT_VC: Shader = preload("res://shaders/unlit_vc.gdshader")

enum Outline { NONE, SMOOTH, BOX, CUSTOM }

static var _cache: Dictionary = {}


## SMOOTH: expande pela normal (cilindros, esferas). BOX: caixas centradas.
## CUSTOM: direção em CUSTOM0 (malhas agrupadas pelo MeshBatcher).
static func make(color: Color, outline: Outline = Outline.SMOOTH, width: float = 0.02,
		vertex_color: bool = false) -> ShaderMaterial:
	var key := "%s|%d|%.3f|%s" % [color.to_html(), outline, width, vertex_color]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = TOON
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("use_vertex_color", vertex_color)
	if outline != Outline.NONE:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("width", width)
		o.set_shader_parameter("mode", outline - 1)
		mat.next_pass = o
	_cache[key] = mat
	return mat


static func unlit_vertex_color() -> ShaderMaterial:
	if _cache.has("unlit_vc"):
		return _cache["unlit_vc"]
	var mat := ShaderMaterial.new()
	mat.shader = UNLIT_VC
	_cache["unlit_vc"] = mat
	return mat
