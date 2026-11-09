extends RefCounted
## Modelos provisórios (primitivas + Cel Shading) de carros, pedestres e do cão.

const Toon := preload("res://scripts/core/toon_materials.gd")
const MeshBatcher := preload("res://scripts/world/mesh_batcher.gd")


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	mi.material_override = Toon.make(color, Toon.Outline.BOX, 0.025)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	mi.mesh = m
	mi.position = pos
	mi.rotation = rot
	mi.material_override = Toon.make(color, Toon.Outline.SMOOTH, 0.02)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	mi.mesh = m
	mi.position = pos
	mi.material_override = Toon.make(color, Toon.Outline.NONE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Carro dos anos 80 (frente = -Z local), com faróis acesos. Uma única malha (desempenho).
static func car(color: Color) -> Node3D:
	var root := Node3D.new()
	var b := MeshBatcher.new()
	b.cell_size = 1.0e6
	b.outline_width = 0.03
	b.add_box(Vector3(0, 0.65, 0), Vector3(1.9, 0.7, 4.6), color)
	b.add_box(Vector3(0, 1.3, 0.25), Vector3(1.75, 0.6, 2.4), color.darkened(0.08))
	b.add_box(Vector3(0, 0.5, -2.32), Vector3(1.95, 0.18, 0.12), Color(0.75, 0.75, 0.75))
	b.add_panel(Vector3(0, 1.33, -0.96), 1.6, 0.45, Vector3.FORWARD, Color(0.1, 0.08, 0.12), MeshBatcher.Layer.FLAT)
	for s: float in [-1.0, 1.0]:
		for z: float in [-1.5, 1.4]:
			var t := Transform3D(Basis(Vector3.BACK, -s * PI / 2), Vector3(s * 0.71, 0.36, z))
			b.add_cylinder(t, 0.36, 0.28, Color(0.06, 0.06, 0.06), 8)
		b.add_panel(Vector3(s * 0.65, 0.72, -2.33), 0.32, 0.2, Vector3.FORWARD, Color(1.0, 0.95, 0.7), MeshBatcher.Layer.GLOW)
		b.add_panel(Vector3(s * 0.7, 0.72, 2.31), 0.3, 0.16, Vector3.BACK, Color(0.9, 0.1, 0.08), MeshBatcher.Layer.GLOW)
	b.build(root)
	return root


## Pedestre. Pernas em pivôs "PernaE"/"PernaD" para animar a caminhada.
static func person(shirt: Color, pants: Color, skin: Color, hair: Color, tall: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * tall
	for s: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "PernaE" if s < 0 else "PernaD"
		pivot.position = Vector3(s * 0.1, 0.85, 0)
		root.add_child(pivot)
		_cyl(pivot, 0.07, 0.8, Vector3(0, -0.4, 0), pants)
		_box(pivot, Vector3(0.12, 0.08, 0.24), Vector3(0, -0.82, -0.05), Color(0.2, 0.15, 0.1))
	_cyl(root, 0.17, 0.62, Vector3(0, 1.17, 0), shirt)
	for s: float in [-1.0, 1.0]:
		_cyl(root, 0.055, 0.58, Vector3(s * 0.23, 1.15, 0), shirt, Vector3(0, 0, s * 0.12))
	_sphere(root, 0.13, Vector3(0, 1.62, 0), skin)
	_sphere(root, 0.135, Vector3(0, 1.68, 0.03), hair)
	return root


## Cão vira-lata caramelo. Pernas em pivôs "Pata0..3", rabo em "Rabo".
static func dog() -> Node3D:
	var root := Node3D.new()
	var fur := Color(0.72, 0.45, 0.2)
	_box(root, Vector3(0.32, 0.3, 0.75), Vector3(0, 0.55, 0), fur)
	var head := _box(root, Vector3(0.26, 0.26, 0.3), Vector3(0, 0.78, -0.45), fur)
	_box(head, Vector3(0.14, 0.12, 0.16), Vector3(0, -0.04, -0.2), fur.darkened(0.15))
	_sphere(head, 0.03, Vector3(0, -0.01, -0.29), Color(0.05, 0.05, 0.05))
	for s: float in [-1.0, 1.0]:
		_box(head, Vector3(0.07, 0.12, 0.05), Vector3(s * 0.1, 0.15, 0.04), fur.darkened(0.3))
	var k := 0
	for z: float in [-0.28, 0.28]:
		for s: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.name = "Pata%d" % k
			pivot.position = Vector3(s * 0.11, 0.45, z)
			root.add_child(pivot)
			_box(pivot, Vector3(0.08, 0.42, 0.08), Vector3(0, -0.21, 0), fur.darkened(0.1))
			k += 1
	var tail := Node3D.new()
	tail.name = "Rabo"
	tail.position = Vector3(0, 0.66, 0.37)
	root.add_child(tail)
	var t := _box(tail, Vector3(0.05, 0.05, 0.3), Vector3(0, 0.08, 0.13), fur)
	t.rotation.x = -0.6
	return root
