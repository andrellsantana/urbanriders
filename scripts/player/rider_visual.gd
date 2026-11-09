extends Node3D
## Modelo PROVISÓRIO (primitivas) do Andrew-Mike Starr na BMX vermelha.
## Animações procedurais: pedalada com IK das pernas, rodas, guidão, inclinação e queda.

const Toon := preload("res://scripts/core/toon_materials.gd")
const Characters := preload("res://scripts/core/characters.gd")

const WHEEL_R := 0.26
const GEAR_RATIO := 2.75 ## coroa/catraca (44/16)
const CRANK_LEN := 0.16
const BB := Vector3(0.0, 0.3, 0.05) ## movimento central
const THIGH := 0.42
const SHIN := 0.43
const HIP_Y := 0.86
const HIP_Z := 0.3

## Aparência (ver characters.gd). Definir antes de entrar na árvore.
var look: Dictionary = {}
var lean_root: Node3D
var rider: Node3D
var rear_wheel: Node3D
var front_wheel: Node3D
var fork_pivot: Node3D
var crank: Node3D
var crank_angle: float = 0.0

var _wheel_angle: float = 0.0
var _legs: Array[Dictionary] = []
var _crashing: bool = false
var _crash_t: float = 0.0
var _crash_side: float = 1.0

var _red: Material
var _chrome: Material
var _black: Material
var _navy: Material
var _white: Material
var _jeans: Material
var _skin: Material
var _hair: Material
var _bag: Material
var _shirt: Material


func _ready() -> void:
	if look.is_empty():
		look = Characters.look(Characters.ANDREW)
	_red = Toon.make(look["frame"])
	_chrome = Toon.make(Color(0.7, 0.68, 0.7))
	_black = Toon.make(Color(0.07, 0.06, 0.07))
	_navy = Toon.make(look["jacket"])
	_white = Toon.make(look["stripe"] if look["stripe"] != null else Color.WHITE)
	_jeans = Toon.make(look["pants"])
	_skin = Toon.make(look["skin"])
	_hair = Toon.make(look["hair"])
	_bag = Toon.make(Color(0.4, 0.24, 0.1), Toon.Outline.BOX, 0.015)
	_shirt = Toon.make(look["shirt"])
	scale = Vector3.ONE * float(look["scale"])
	lean_root = Node3D.new()
	lean_root.name = "LeanRoot"
	add_child(lean_root)
	_build_bike()
	_build_rider()
	update_pose(0.0, 0.0, 0.0, false, 0.0, 0.0)


# ---------------------------------------------------------------- construção

func _mesh(mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sphere(r: float, mat: Material, parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return _mesh(m, mat, parent, pos)


func _box(size: Vector3, mat: Material, parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, mat, parent, pos)


func _tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 1.0
	m.radial_segments = 10
	m.rings = 1
	var mi := _mesh(m, mat, parent)
	place_tube(mi, a, b)
	return mi


## Posiciona um cilindro de altura 1 entre os pontos a e b.
static func place_tube(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return
	var y := d / l
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)


func _wheel(z: float, parent: Node3D, offset: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0, WHEEL_R, z) - offset
	parent.add_child(pivot)
	var tire := TorusMesh.new()
	tire.inner_radius = WHEEL_R - 0.045
	tire.outer_radius = WHEEL_R
	tire.rings = 20
	tire.ring_segments = 8
	var t := _mesh(tire, _black, pivot)
	t.rotation = Vector3(0.0, 0.0, PI / 2.0)
	var rim := TorusMesh.new()
	rim.inner_radius = WHEEL_R - 0.06
	rim.outer_radius = WHEEL_R - 0.04
	rim.rings = 20
	rim.ring_segments = 6
	var rm := _mesh(rim, _chrome, pivot)
	rm.rotation = Vector3(0.0, 0.0, PI / 2.0)
	for i in 3:
		var ang := i * PI / 3.0
		var dir := Vector3(0.0, cos(ang), sin(ang)) * (WHEEL_R - 0.05)
		_tube(pivot, -dir, dir, 0.006, _chrome)
	_tube(pivot, Vector3(-0.05, 0, 0), Vector3(0.05, 0, 0), 0.025, _chrome)
	return pivot


func _build_bike() -> void:
	var bike := Node3D.new()
	bike.name = "Bike"
	lean_root.add_child(bike)
	var rear_axle := Vector3(0.0, WHEEL_R, 0.52)
	var seat_top := Vector3(0.0, 0.72, 0.3)
	var head_top := Vector3(0.0, 0.78, -0.36)
	var head_bottom := Vector3(0.0, 0.6, -0.4)
	_tube(bike, BB, seat_top, 0.024, _red)
	_tube(bike, seat_top, head_top, 0.024, _red)
	_tube(bike, BB, head_bottom, 0.028, _red)
	_tube(bike, head_bottom, head_top, 0.03, _red)
	for side: float in [-0.06, 0.06]:
		_tube(bike, rear_axle + Vector3(side, 0, 0), BB + Vector3(side * 0.5, 0, 0), 0.016, _red)
		_tube(bike, rear_axle + Vector3(side, 0, 0), seat_top + Vector3(side * 0.3, 0, 0), 0.014, _red)
	_tube(bike, seat_top, seat_top + Vector3(0, 0.06, 0.02), 0.015, _chrome)
	_box(Vector3(0.13, 0.05, 0.26), _black, bike, Vector3(0.0, 0.8, 0.33))
	rear_wheel = _wheel(0.52, bike, Vector3.ZERO)

	# Garfo + roda dianteira + guidão giram juntos.
	fork_pivot = Node3D.new()
	fork_pivot.position = head_top
	bike.add_child(fork_pivot)
	var front_axle := Vector3(0.0, WHEEL_R, -0.52) - head_top
	for side: float in [-0.06, 0.06]:
		_tube(fork_pivot, Vector3(side, -0.16, -0.03), front_axle + Vector3(side, 0, 0), 0.016, _chrome)
	_tube(fork_pivot, Vector3.ZERO, Vector3(0, 0.14, 0.03), 0.02, _chrome)
	_tube(fork_pivot, Vector3(-0.28, 0.18, -0.05), Vector3(0.28, 0.18, -0.05), 0.016, _chrome)
	_tube(fork_pivot, Vector3(-0.12, 0.14, 0.02), Vector3(-0.2, 0.18, -0.05), 0.014, _chrome)
	_tube(fork_pivot, Vector3(0.12, 0.14, 0.02), Vector3(0.2, 0.18, -0.05), 0.014, _chrome)
	_tube(fork_pivot, Vector3(-0.32, 0.18, -0.05), Vector3(-0.22, 0.18, -0.05), 0.022, _black)
	_tube(fork_pivot, Vector3(0.22, 0.18, -0.05), Vector3(0.32, 0.18, -0.05), 0.022, _black)
	front_wheel = _wheel(0.0, fork_pivot, Vector3.ZERO)
	front_wheel.position = front_axle

	# Pedivela: braço direito em -Z local, esquerdo em +Z local.
	crank = Node3D.new()
	crank.position = BB
	bike.add_child(crank)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.09
	ring.bottom_radius = 0.09
	ring.height = 0.012
	ring.radial_segments = 16
	var rmi := _mesh(ring, _chrome, crank, Vector3(0.07, 0, 0))
	rmi.rotation = Vector3(0, 0, PI / 2.0)
	_tube(crank, Vector3(0.09, 0, 0), Vector3(0.09, 0, -CRANK_LEN), 0.014, _chrome)
	_tube(crank, Vector3(-0.09, 0, 0), Vector3(-0.09, 0, CRANK_LEN), 0.014, _chrome)
	_box(Vector3(0.08, 0.02, 0.06), _black, crank, Vector3(0.14, 0, -CRANK_LEN))
	_box(Vector3(0.08, 0.02, 0.06), _black, crank, Vector3(-0.14, 0, CRANK_LEN))


func _build_rider() -> void:
	rider = Node3D.new()
	rider.name = "Ciclista"
	lean_root.add_child(rider)
	var hip := Vector3(0.0, HIP_Y, HIP_Z)
	var shoulder := Vector3(0.0, 1.28, -0.06)
	var torso_dir := (shoulder - hip).normalized()
	var back_n := Vector3(0.0, -torso_dir.z, torso_dir.y)
	if back_n.z < 0.0:
		back_n = -back_n
	# Tronco: jaqueta azul-marinho com listras brancas, gola vermelha.
	var torso := _tube(rider, hip, shoulder, 0.15, _navy)
	torso.scale.x *= 1.15
	_tube(rider, hip + Vector3(0, -0.04, 0.02), hip + Vector3(0, 0.08, 0), 0.155, _jeans)
	_tube(rider, shoulder - torso_dir * 0.02, shoulder + torso_dir * 0.06, 0.07, _shirt)
	# Mochila marrom (só Andrew-Mike).
	var mid := (hip + shoulder) * 0.5 + torso_dir * 0.04
	if look["backpack"]:
		var bag := _box(Vector3(0.3, 0.34, 0.13), _bag, rider, mid + back_n * 0.17)
		bag.rotation.x = -atan2(-torso_dir.z, torso_dir.y)
		var flap := _box(Vector3(0.31, 0.12, 0.14), Toon.make(Color(0.32, 0.19, 0.08), Toon.Outline.BOX, 0.01), rider,
				mid + back_n * 0.18 + torso_dir * 0.14)
		flap.rotation.x = bag.rotation.x
	# Braços com listra branca até as manoplas.
	for side: float in [-1.0, 1.0]:
		var s := shoulder + Vector3(0.17 * side, -0.03, 0.0)
		var grip := Vector3(0.27 * side, 0.96, -0.41)
		var elbow := (s + grip) * 0.5 + Vector3(0.06 * side, 0.03, 0.04)
		_tube(rider, s, elbow, 0.055, _navy)
		_tube(rider, elbow, grip, 0.05, _navy)
		if look["stripe"] != null:
			_tube(rider, s + Vector3(0.045 * side, 0.01, 0), elbow + Vector3(0.045 * side, 0.01, 0), 0.016, _white)
			_tube(rider, elbow + Vector3(0.04 * side, 0.01, 0), grip + Vector3(0.035 * side, 0.03, 0.04), 0.014, _white)
		_sphere(0.045, _skin, rider, grip)
	# Cabeça e cabelo castanho ondulado.
	var head := Vector3(0.0, 1.47, -0.13)
	_tube(rider, shoulder, head, 0.05, _skin)
	_sphere(0.13, _skin, rider, head)
	_build_hair(head)
	_sphere(0.03, _skin, rider, head + Vector3(0.13, 0.0, 0.0))
	_sphere(0.03, _skin, rider, head + Vector3(-0.13, 0.0, 0.0))
	# Pernas (jeans com barra dobrada) e tênis brancos.
	for side: float in [1.0, -1.0]:
		var leg := {
			"side": side,
			"thigh": _tube(rider, Vector3.ZERO, Vector3.UP, 0.075, _jeans),
			"shin": _tube(rider, Vector3.ZERO, Vector3.UP, 0.065, Toon.make(look["shins"])),
			"cuff": _tube(rider, Vector3.ZERO, Vector3.UP, 0.072, Toon.make(look["cuff"])),
			"shoe": _box(Vector3(0.1, 0.08, 0.22), Toon.make(look["shoes"], Toon.Outline.BOX, 0.012), rider, Vector3.ZERO),
		}
		_legs.append(leg)


func _build_hair(head: Vector3) -> void:
	var accent := Toon.make(look["accent"])
	match String(look["hair_style"]):
		"pigtails":
			var cap := _sphere(0.142, _hair, rider, head + Vector3(0, 0.03, 0.025))
			cap.scale = Vector3(1.05, 0.95, 1.05)
			for s: float in [-1.0, 1.0]:
				_sphere(0.035, accent, rider, head + Vector3(s * 0.15, 0.0, 0.06))
				var tail := _sphere(0.06, _hair, rider, head + Vector3(s * 0.19, -0.1, 0.08))
				tail.scale = Vector3(0.8, 1.7, 0.8)
		"spiky":
			var cap := _sphere(0.138, _hair, rider, head + Vector3(0, 0.03, 0.02))
			cap.scale = Vector3(1.02, 0.9, 1.02)
			for i in 9:
				var a := i * TAU / 9.0
				var spike := _sphere(0.045, _hair, rider, head + Vector3(cos(a) * 0.08, 0.13, 0.03 + sin(a) * 0.08))
				spike.scale = Vector3(0.7, 1.6, 0.7)
		"puff":
			var cap := _sphere(0.138, _hair, rider, head + Vector3(0, 0.02, 0.02))
			cap.scale = Vector3(1.03, 0.92, 1.03)
			var puff := _sphere(0.13, _hair, rider, head + Vector3(0, 0.17, 0.03))
			puff.scale = Vector3(1.2, 0.95, 1.2)
			var band := _tube(rider, head + Vector3(-0.14, 0.06, -0.02), head + Vector3(0.14, 0.06, -0.02), 0.03, accent)
			band.scale.z *= 1.0
		_:
			var hair := _sphere(0.145, _hair, rider, head + Vector3(0, 0.035, 0.03))
			hair.scale = Vector3(1.08, 0.95, 1.05)
			for i in 8:
				var a := i * TAU / 8.0
				_sphere(0.06, _hair, rider, head + Vector3(cos(a) * 0.13, 0.07 + sin(i * 1.7) * 0.03, 0.04 + sin(a) * 0.1))


# ------------------------------------------------------------------ animação

## Posição do pedal (no espaço do lean_root). side 1 = direito.
func pedal_position(side: float) -> Vector3:
	var s := CRANK_LEN * sin(crank_angle)
	var c := CRANK_LEN * cos(crank_angle)
	if side > 0.0:
		return BB + Vector3(0.14, s, -c)
	return BB + Vector3(-0.14, -s, c)


## IK de dois ossos no plano sagital; joelho aponta para frente.
static func solve_knee(hip: Vector3, foot: Vector3, l1: float, l2: float) -> Vector3:
	var d := foot - hip
	var dist := clampf(d.length(), 0.05, l1 + l2 - 0.001)
	var dir := d.normalized()
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var perp := Vector3(0.0, -dir.z, dir.y).normalized()
	if perp.z > 0.0:
		perp = -perp
	return hip + (dir * cos_a + perp * sin_a) * l1


func update_pose(speed: float, lean: float, steer: float, pedaling: bool, boost: float, dt: float) -> void:
	if lean_root == null:
		return
	var wheel_rate := speed / WHEEL_R
	_wheel_angle = wrapf(_wheel_angle - wheel_rate * dt, -TAU, TAU)
	rear_wheel.rotation.x = _wheel_angle
	front_wheel.rotation.x = _wheel_angle
	if pedaling and not _crashing:
		crank_angle = wrapf(crank_angle - maxf(wheel_rate, 4.0) / GEAR_RATIO * dt, -TAU, TAU)
	crank.rotation.x = crank_angle
	fork_pivot.rotation.y = steer * 0.35

	for leg: Dictionary in _legs:
		var side: float = leg["side"]
		var hip := Vector3(0.1 * side, HIP_Y, HIP_Z)
		var foot := pedal_position(side) + Vector3(0.0, 0.06, 0.0)
		var knee := solve_knee(hip, foot, THIGH, SHIN)
		place_tube(leg["thigh"], hip, knee)
		place_tube(leg["shin"], knee, foot)
		var ankle_dir := (foot - knee).normalized()
		place_tube(leg["cuff"], foot - ankle_dir * 0.1, foot - ankle_dir * 0.03)
		var shoe: MeshInstance3D = leg["shoe"]
		shoe.position = foot + Vector3(0.0, 0.0, -0.04)

	# Turbo: o garoto balança o corpo de um lado ao outro.
	rider.rotation.z = sin(crank_angle) * 0.07 * boost

	if _crashing:
		_crash_t += dt
		var k := clampf(_crash_t / 0.45, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		lean_root.rotation.z = lerpf(lean_root.rotation.z, _crash_side * 1.45, k)
		lean_root.position.y = -0.05 * k
		rider.position = Vector3(0.15 * _crash_side * k, -0.1 * k, -0.25 * k)
	else:
		lean_root.rotation.z = lean


func start_crash(current_lean: float) -> void:
	_crashing = true
	_crash_t = 0.0
	_crash_side = 1.0 if current_lean >= 0.0 else -1.0
	if absf(current_lean) < 0.05:
		_crash_side = 1.0 if randf() < 0.5 else -1.0


func end_crash() -> void:
	_crashing = false
	lean_root.rotation.z = 0.0
	lean_root.position = Vector3.ZERO
	rider.position = Vector3.ZERO
