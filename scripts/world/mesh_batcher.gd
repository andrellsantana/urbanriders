extends RefCounted
## Agrupa milhares de primitivas em poucas malhas por célula do mapa (desempenho).
## Cor por vértice + direção de contorno pré-calculada em CUSTOM0 (contorno uniforme em metros).

const Toon := preload("res://scripts/core/toon_materials.gd")

enum Layer { SOLID, FLAT, GLOW }

var cell_size: float = 130.0
var outline_width: float = 0.05
var visibility_end: float = 340.0
var primitive_count: int = 0

var _tools: Dictionary = {} ## Vector3i(cx, cz, layer) -> SurfaceTool


func _st(pos: Vector3, layer: Layer) -> SurfaceTool:
	var key := Vector3i(floori(pos.x / cell_size), floori(pos.z / cell_size), layer)
	if not _tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_custom_format(0, SurfaceTool.CUSTOM_RGB_FLOAT)
		_tools[key] = st
	return _tools[key]


# ------------------------------------------------------------- núcleo convexo

## Deslocamento do contorno num vértice: o·n = 1 para cada face adjacente.
static func outline_offset(normals: Array[Vector3]) -> Vector3:
	var uniq: Array[Vector3] = []
	for n in normals:
		var dup := false
		for u in uniq:
			if u.dot(n) > 0.999:
				dup = true
				break
		if not dup:
			uniq.append(n)
	var o := Vector3.ZERO
	match uniq.size():
		0:
			return Vector3.ZERO
		1:
			o = uniq[0]
		2:
			o = (uniq[0] + uniq[1]) / maxf(1.0 + uniq[0].dot(uniq[1]), 0.2)
		3:
			var m := Basis(uniq[0], uniq[1], uniq[2]).transposed()
			if absf(m.determinant()) > 0.05:
				o = m.inverse() * Vector3.ONE
			else:
				o = (uniq[0] + uniq[1] + uniq[2]).normalized()
		_:
			var avg := Vector3.ZERO
			for u in uniq:
				avg += u
			avg = avg.normalized()
			var d := 0.0
			for u in uniq:
				d += avg.dot(u)
			o = avg / maxf(d / uniq.size(), 0.3)
	return o.limit_length(3.0)


## Poliedro convexo em coordenadas locais; faces = listas de índices (qualquer ordem de giro).
func add_convex(xform: Transform3D, verts: PackedVector3Array, faces: Array, color: Color,
		layer: Layer = Layer.SOLID) -> void:
	primitive_count += 1
	var st := _st(xform.origin, layer)
	var wv := PackedVector3Array()
	var center := Vector3.ZERO
	for v in verts:
		var w := xform * v
		wv.append(w)
		center += w
	center /= float(verts.size())
	var face_normals: Array[Vector3] = []
	var vert_normals: Array = []
	vert_normals.resize(verts.size())
	for i in verts.size():
		vert_normals[i] = [] as Array[Vector3]
	for f: PackedInt32Array in faces:
		var a := wv[f[0]]
		var n := (wv[f[1]] - a).cross(wv[f[2]] - a)
		if n.length() < 1e-8 and f.size() > 3:
			n = (wv[f[2]] - a).cross(wv[f[3]] - a)
		n = n.normalized()
		var fc := Vector3.ZERO
		for idx in f:
			fc += wv[idx]
		fc /= float(f.size())
		if n.dot(fc - center) < 0.0:
			n = -n
		face_normals.append(n)
		for idx in f:
			(vert_normals[idx] as Array[Vector3]).append(n)
	var offsets := PackedVector3Array()
	for i in verts.size():
		offsets.append(outline_offset(vert_normals[i]))
	for fi in faces.size():
		var f: PackedInt32Array = faces[fi]
		var n := face_normals[fi]
		for k in range(1, f.size() - 1):
			_emit_tri(st, wv, offsets, [f[0], f[k], f[k + 1]], n, color)


func _emit_tri(st: SurfaceTool, wv: PackedVector3Array, offsets: PackedVector3Array, tri: Array,
		n: Vector3, color: Color) -> void:
	var a: int = tri[0]
	var b: int = tri[1]
	var c: int = tri[2]
	# Godot: face frontal em sentido horário → produto vetorial aponta para dentro.
	if (wv[b] - wv[a]).cross(wv[c] - wv[a]).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for idx in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		var o := offsets[idx]
		st.set_custom(0, Color(o.x, o.y, o.z))
		st.add_vertex(wv[idx])


# ----------------------------------------------------------------- primitivas

const BOX_FACES := [
	[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]


## Caixa centrada em `center`, girada em Y.
func add_box(center: Vector3, size: Vector3, color: Color, rot_y: float = 0.0,
		layer: Layer = Layer.SOLID) -> void:
	var h := size * 0.5
	var v := PackedVector3Array()
	for i in 8:
		v.append(Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	add_convex(Transform3D(Basis(Vector3.UP, rot_y), center), v, _faces(BOX_FACES), color, layer)


## Telhado de duas águas; cumeeira ao longo do X local. base_center = centro da base.
func add_roof(base_center: Vector3, w: float, d: float, h: float, color: Color, rot_y: float = 0.0) -> void:
	var v := PackedVector3Array([
		Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2),
		Vector3(-w / 2, h, 0), Vector3(w / 2, h, 0)])
	var faces := _faces([[0, 1, 2, 3], [0, 1, 5, 4], [3, 2, 5, 4], [0, 4, 3], [1, 2, 5]])
	add_convex(Transform3D(Basis(Vector3.UP, rot_y), base_center), v, faces, color)


## Cilindro com eixo Y local do transform; origem = centro da base.
func add_cylinder(xform: Transform3D, r: float, h: float, color: Color, segs: int = 8) -> void:
	var v := PackedVector3Array()
	for ring in 2:
		for i in segs:
			var a := TAU * i / segs
			v.append(Vector3(cos(a) * r, h * ring, sin(a) * r))
	var faces: Array = []
	var bottom := PackedInt32Array()
	var top := PackedInt32Array()
	for i in segs:
		var j := (i + 1) % segs
		faces.append(PackedInt32Array([i, j, segs + j, segs + i]))
		bottom.append(i)
		top.append(segs + i)
	faces.append(bottom)
	faces.append(top)
	add_convex(xform, v, faces, color)


func add_cylinder_y(base: Vector3, r: float, h: float, color: Color, segs: int = 8) -> void:
	add_cylinder(Transform3D(Basis.IDENTITY, base), r, h, color, segs)


## Esfera low-poly (folhagem, arbustos).
func add_blob(center: Vector3, radius: Vector3, color: Color, segs: int = 7, rings: int = 4) -> void:
	var v := PackedVector3Array()
	v.append(Vector3(0, -radius.y, 0))
	for r in range(1, rings):
		var phi := PI * r / rings
		for i in segs:
			var a := TAU * i / segs + (0.5 * TAU / segs if r % 2 == 0 else 0.0)
			v.append(Vector3(sin(phi) * cos(a) * radius.x, -cos(phi) * radius.y, sin(phi) * sin(a) * radius.z))
	v.append(Vector3(0, radius.y, 0))
	var top_i := v.size() - 1
	var faces: Array = []
	for i in segs:
		faces.append(PackedInt32Array([0, 1 + i, 1 + (i + 1) % segs]))
	for r in range(rings - 2):
		var b0 := 1 + r * segs
		var b1 := b0 + segs
		for i in segs:
			var j := (i + 1) % segs
			faces.append(PackedInt32Array([b0 + i, b0 + j, b1 + i]))
			faces.append(PackedInt32Array([b0 + j, b1 + j, b1 + i]))
	var last := 1 + (rings - 2) * segs
	for i in segs:
		faces.append(PackedInt32Array([top_i, last + i, last + (i + 1) % segs]))
	add_convex(Transform3D(Basis.IDENTITY, center), v, faces, color)


## Retângulo plano horizontal (ruas, calçadas, gramados). Sem contorno.
func add_flat(center: Vector3, size: Vector2, color: Color, rot_y: float = 0.0,
		layer: Layer = Layer.FLAT) -> void:
	var b := Basis(Vector3.UP, rot_y)
	var hx := b * Vector3(size.x * 0.5, 0, 0)
	var hz := b * Vector3(0, 0, size.y * 0.5)
	add_quad(PackedVector3Array([center - hx - hz, center + hx - hz, center + hx + hz, center - hx + hz]),
			Vector3.UP, color, layer)


## Painel vertical (janelas) voltado para `normal`.
func add_panel(center: Vector3, w: float, h: float, normal: Vector3, color: Color, layer: Layer) -> void:
	var right := Vector3.UP.cross(normal).normalized() * (w * 0.5)
	var up := Vector3.UP * (h * 0.5)
	add_quad(PackedVector3Array([center - right - up, center + right - up, center + right + up, center - right + up]),
			normal, color, layer)


func add_quad(p: PackedVector3Array, normal: Vector3, color: Color, layer: Layer) -> void:
	primitive_count += 1
	var st := _st((p[0] + p[2]) * 0.5, layer)
	var zero := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	_emit_tri(st, p, zero, [0, 1, 2], normal, color)
	_emit_tri(st, p, zero, [0, 2, 3], normal, color)


static func _faces(list: Array) -> Array:
	var out: Array = []
	for f: Array in list:
		out.append(PackedInt32Array(f))
	return out


# ------------------------------------------------------------------- montagem

## Cria os MeshInstance3D (um por célula e camada) dentro de `parent`.
func build(parent: Node3D) -> int:
	var solid_mat := Toon.make(Color.WHITE, Toon.Outline.CUSTOM, outline_width, true)
	var flat_mat := Toon.make(Color.WHITE, Toon.Outline.NONE, 0.0, true)
	var glow_mat := Toon.unlit_vertex_color()
	var count := 0
	for key: Vector3i in _tools:
		var st: SurfaceTool = _tools[key]
		var mesh := st.commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		match key.z:
			Layer.SOLID:
				mi.material_override = solid_mat
			Layer.FLAT:
				mi.material_override = flat_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_:
				mi.material_override = glow_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if key.z != Layer.FLAT:
			mi.visibility_range_end = visibility_end
		parent.add_child(mi)
		count += 1
	_tools.clear()
	return count
