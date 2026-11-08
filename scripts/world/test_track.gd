extends Node3D
## Pista de testes de Red City (geometria provisória, gerada por código).
## Avenida com prédios, postes, slalom de cones, rampa, piso molhado, grama e praça de manobras.

const Toon := preload("res://scripts/core/toon_materials.gd")

const ASPHALT := Color(0.13, 0.1, 0.13)
const SPAWN := Vector3(0.0, 0.0, 0.0)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1985
	_build_ground()
	_build_avenue()
	_build_buildings()
	_build_poles_and_trees()
	_build_slalom()
	_build_ramp()
	_build_surface_zones()
	_build_plaza()
	_build_landmarks()


# ----------------------------------------------------------------- utilidades

func _static_box(size: Vector3, pos: Vector3, color: Color, outline: bool = true,
		rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Toon.make(color, Toon.Outline.BOX if outline else Toon.Outline.NONE, 0.06)
	body.add_child(mi)
	add_child(body)
	return body


func _static_cylinder(r: float, h: float, pos: Vector3, color: Color, collide: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if collide else Node3D.new()
	root.position = pos + Vector3(0, h * 0.5, 0)
	if collide:
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = h
		shape.shape = cyl
		root.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = Toon.make(color, Toon.Outline.SMOOTH, 0.04)
	root.add_child(mi)
	add_child(root)
	return root


func _flat(size: Vector2, pos: Vector3, color: Color, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = Toon.make(color, Toon.Outline.NONE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ------------------------------------------------------------------- cenário

func _build_ground() -> void:
	_static_box(Vector3(260, 1, 280), Vector3(0, -0.5, -95), ASPHALT, false)
	# Gramados laterais (visual) e calçadas.
	_flat(Vector2(60, 150), Vector3(-42, 0.01, -55), Color(0.2, 0.14, 0.08))
	_flat(Vector2(60, 150), Vector3(42, 0.01, -55), Color(0.2, 0.14, 0.08))
	_flat(Vector2(4, 150), Vector3(-10, 0.015, -55), Color(0.38, 0.3, 0.28))
	_flat(Vector2(4, 150), Vector3(10, 0.015, -55), Color(0.38, 0.3, 0.28))


func _build_avenue() -> void:
	var z := 8.0
	while z > -128.0:
		_flat(Vector2(0.25, 3.0), Vector3(0, 0.02, z), Color(0.9, 0.82, 0.55))
		z -= 7.0
	# Linha de largada.
	for i in 8:
		_flat(Vector2(1.0, 1.0), Vector3(-7.0 + i * 2.0, 0.025, -3.0), Color.WHITE)
		_flat(Vector2(1.0, 1.0), Vector3(-6.0 + i * 2.0, 0.025, -4.0), Color.WHITE)


func _build_buildings() -> void:
	var palette := [Color(0.3, 0.25, 0.28), Color(0.36, 0.22, 0.18), Color(0.24, 0.2, 0.26),
			Color(0.4, 0.32, 0.28), Color(0.2, 0.17, 0.2)]
	for side: float in [-1.0, 1.0]:
		var z := -6.0
		while z > -125.0:
			var depth := _rng.randf_range(8.0, 14.0)
			var h := _rng.randf_range(5.0, 14.0)
			var w := _rng.randf_range(8.0, 12.0)
			var col: Color = palette[_rng.randi() % palette.size()]
			var b := _static_box(Vector3(w, h, depth), Vector3(side * (17.0 + w * 0.5), h * 0.5, z - depth * 0.5), col)
			_add_windows(b, Vector3(w, h, depth), side)
			z -= depth + _rng.randf_range(2.0, 6.0)


func _add_windows(building: Node3D, size: Vector3, side: float) -> void:
	var lit := Toon.make(Color(1.0, 0.75, 0.35), Toon.Outline.NONE)
	var dark := Toon.make(Color(0.12, 0.08, 0.12), Toon.Outline.NONE)
	var face_x := -side * (size.x * 0.5 + 0.02)
	var y := 2.0
	while y < size.y - 1.0:
		var z := -size.z * 0.5 + 1.5
		while z < size.z * 0.5 - 1.0:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.2, 1.4)
			mi.mesh = q
			mi.material_override = lit if _rng.randf() < 0.35 else dark
			mi.position = Vector3(face_x, y - size.y * 0.5, z)
			mi.rotation.y = -side * PI / 2.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			building.add_child(mi)
			z += 2.6
		y += 3.0


func _build_poles_and_trees() -> void:
	var z := -12.0
	while z > -125.0:
		for side: float in [-1.0, 1.0]:
			_static_cylinder(0.14, 8.0, Vector3(side * 11.0, 0, z), Color(0.3, 0.18, 0.1))
			var arm := _static_box(Vector3(1.6, 0.12, 0.12), Vector3(side * 11.0, 7.4, z), Color(0.3, 0.18, 0.1))
			arm.get_child(0).queue_free()
		z -= 25.0
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * _rng.randf_range(30.0, 55.0), 0, _rng.randf_range(-10.0, -125.0))
		_tree(pos)


func _tree(pos: Vector3) -> void:
	_static_cylinder(0.3, 3.5, pos, Color(0.25, 0.14, 0.08))
	var leaves := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 2.4
	s.height = 4.0
	s.radial_segments = 10
	s.rings = 6
	leaves.mesh = s
	var tones := [Color(0.6, 0.18, 0.06), Color(0.7, 0.35, 0.08), Color(0.35, 0.12, 0.08)]
	leaves.material_override = Toon.make(tones[_rng.randi() % tones.size()], Toon.Outline.SMOOTH, 0.06)
	leaves.position = pos + Vector3(0, 4.6, 0)
	add_child(leaves)


func _build_slalom() -> void:
	for i in 6:
		var x := 2.2 if i % 2 == 0 else -2.2
		_static_cylinder(0.22, 0.75, Vector3(x, 0, -20.0 - i * 5.0), Color(1.0, 0.45, 0.05))


func _build_ramp() -> void:
	var ang := deg_to_rad(8.0)
	var half := 5.0
	var rise := half * 2.0 * sin(ang)
	var run := half * 2.0 * cos(ang)
	var col := Color(0.45, 0.38, 0.36)
	# subida → plataforma → descida, à direita da avenida
	_static_box(Vector3(5, 0.4, half * 2.0), Vector3(4.5, rise * 0.5 - 0.2 * cos(ang), -62.0 - run * 0.5), col, true, Vector3(ang, 0, 0))
	_static_box(Vector3(5, rise, 6), Vector3(4.5, rise * 0.5, -62.0 - run - 3.0), col)
	_static_box(Vector3(5, 0.4, half * 2.0), Vector3(4.5, rise * 0.5 - 0.2 * cos(ang), -62.0 - run - 6.0 - run * 0.5), col, true, Vector3(-ang, 0, 0))


func _zone(rect: Rect2, grip: float, zone_name: String, color: Color) -> void:
	var area := Area3D.new()
	area.position = Vector3(rect.get_center().x, 0.5, rect.get_center().y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x, 1.0, rect.size.y)
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b.has_method("enter_surface"):
			b.enter_surface(grip, zone_name))
	area.body_exited.connect(func(b: Node3D) -> void:
		if b.has_method("exit_surface"):
			b.exit_surface(zone_name))
	add_child(area)
	_flat(rect.size, Vector3(rect.get_center().x, 0.02, rect.get_center().y), color)


func _build_surface_zones() -> void:
	_zone(Rect2(-10, -118, 10, 26), 0.45, "asfalto molhado", Color(0.16, 0.14, 0.24))
	_zone(Rect2(0.5, -118, 9.5, 26), 0.6, "grama", Color(0.16, 0.2, 0.07))
	# poças decorativas na zona molhada
	for i in 5:
		_flat(Vector2(_rng.randf_range(1.5, 3.0), _rng.randf_range(1.0, 2.5)),
				Vector3(_rng.randf_range(-9, -1), 0.03, _rng.randf_range(-116, -94)), Color(0.55, 0.15, 0.12))


func _build_plaza() -> void:
	var wall := Color(0.4, 0.3, 0.32)
	_static_box(Vector3(2, 3, 260), Vector3(-70, 1.5, -95), wall)
	_static_box(Vector3(2, 3, 260), Vector3(70, 1.5, -95), wall)
	_static_box(Vector3(142, 3, 2), Vector3(0, 1.5, 34), wall)
	_static_box(Vector3(142, 3, 2), Vector3(0, 1.5, -224), wall)
	# alguns obstáculos na praça
	for i in 6:
		_static_box(Vector3(1.2, 1.0, 1.2), Vector3(_rng.randf_range(-40, 40), 0.5, _rng.randf_range(-180, -210)),
				Color(0.5, 0.25, 0.15))


func _build_landmarks() -> void:
	# Placa de boas-vindas.
	_static_cylinder(0.08, 2.0, Vector3(13, 0, -2.5), Color(0.3, 0.18, 0.1))
	_static_cylinder(0.08, 2.0, Vector3(15.6, 0, -2.5), Color(0.3, 0.18, 0.1))
	var sign_box := _static_box(Vector3(3.2, 1.6, 0.15), Vector3(14.3, 2.6, -2.5), Color(0.18, 0.22, 0.18))
	var label := Label3D.new()
	label.text = "BEM-VINDO A\nRED CITY"
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 10
	label.modulate = Color(0.95, 0.92, 0.85)
	label.position = Vector3(0, 0, 0.09)
	sign_box.add_child(label)
	# Caixa d'água de Red City ao fundo.
	var base := Vector3(-35, 0, -195)
	for corner: Vector2 in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
		_static_cylinder(0.3, 16.0, base + Vector3(corner.x, 0, corner.y), Color(0.45, 0.42, 0.45))
	var tank := _static_cylinder(6.0, 7.0, base + Vector3(0, 16, 0), Color(0.75, 0.72, 0.72), false)
	var tl := Label3D.new()
	tl.text = "RED CITY"
	tl.font_size = 160
	tl.pixel_size = 0.012
	tl.outline_size = 16
	tl.modulate = Color(0.15, 0.05, 0.05)
	tl.position = Vector3(0, 0.3, 6.05)
	tank.add_child(tl)
