extends Node3D
## Elementos do circuito: aceleradores (setas no chão), rampas, obstáculos e faixas de pedestres.
## Posições definidas por (distância no laço, desvio lateral). Sempre há passagem livre ao lado.

const Circuit := preload("res://scripts/race/circuit.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const Toon := preload("res://scripts/core/toon_materials.gd")
const MeshBatcher := preload("res://scripts/world/mesh_batcher.gd")
const Layer := MeshBatcher.Layer

## Aceleradores: (distância, lateral).
const PADS: Array[Vector2] = [Vector2(60, -1.5), Vector2(330, 1.5), Vector2(600, 0.0), Vector2(820, -1.5),
	Vector2(1080, 1.5), Vector2(1335, 0.0)]
## Rampas: (distância, lateral).
const RAMPS: Array[Vector2] = [Vector2(200, 1.2), Vector2(680, -1.2), Vector2(955, 0.0), Vector2(1400, 1.0)]
## Obstáculos: (distância, lateral, tipo).
const OBSTACLES: Array[Array] = [[120.0, -1.6, "cavalete"], [465.0, 1.4, "cones"], [640.0, 0.2, "lixeira"],
	[790.0, 1.8, "cacamba"], [1200.0, -1.5, "cavalete"]]
## Faixas de pedestres (distâncias).
const CROSSINGS: Array[float] = [150.0, 560.0, 1050.0, 1290.0]

const PAD_SIZE := Vector2(2.2, 3.2)
const RAMP_SIZE := Vector3(2.6, 0.5, 2.6) ## largura, altura, comprimento

var circuit: Circuit
var riders: Array[BikeController] = []
## Para a IA: {"pos", "radius", "kind"} (obstáculos fixos) e atrativos (aceleradores e rampas).
var obstacles: Array[Dictionary] = []
var attractors: Array[Dictionary] = []
var crossing_points: Array[Dictionary] = []
var _pad_cooldown: Dictionary = {}
var batcher := MeshBatcher.new() ## todo o visual fixo vira poucas malhas (desempenho)


func setup(c: Circuit) -> void:
	circuit = c
	for p in PADS:
		_build_pad(p.x, p.y)
	for r in RAMPS:
		_build_ramp(r.x, r.y)
	for o in OBSTACLES:
		_build_obstacle(float(o[0]), float(o[1]), String(o[2]))
	for d in CROSSINGS:
		_build_crossing(d)
	batcher.build(self)


func _frame(distance: float, lateral: float) -> Dictionary:
	var s := circuit.sample(distance)
	var dir: Vector3 = s["dir"]
	var right := dir.cross(Vector3.UP)
	return {"pos": (s["pos"] as Vector3) + right * lateral, "dir": dir, "right": right,
		"rot": atan2(dir.x, dir.z)}


func _mat_unlit(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


# --------------------------------------------------------------- aceleradores

func _build_pad(distance: float, lateral: float) -> void:
	var f := _frame(distance, lateral)
	var rot: float = f["rot"]
	var bs := Basis(Vector3.UP, rot)
	var c: Vector3 = (f["pos"] as Vector3) + Vector3(0, 0.045, 0)
	batcher.add_flat(c, PAD_SIZE, Color(0.2, 0.06, 0.3), rot, Layer.GLOW)
	# Três setas (chevrons) apontando no sentido da corrida.
	for k in 3:
		for sd: float in [-1.0, 1.0]:
			batcher.add_flat(c + bs * Vector3(sd * 0.38, 0.005, 1.0 - k * 0.95 - 0.25), Vector2(0.95, 0.22),
					Color(1.0, 0.85, 0.2), rot - sd * 0.6, Layer.GLOW)
	attractors.append({"pos": f["pos"], "distance": distance, "lateral": lateral, "kind": "pad"})


# --------------------------------------------------------------------- rampas

func _build_ramp(distance: float, lateral: float) -> void:
	var f := _frame(distance, lateral)
	var ang := atan2(RAMP_SIZE.y, RAMP_SIZE.z)
	var slope_len := sqrt(RAMP_SIZE.y * RAMP_SIZE.y + RAMP_SIZE.z * RAMP_SIZE.z)
	var body := StaticBody3D.new()
	add_child(body)
	var rot := Basis(Vector3.UP, float(f["rot"])) * Basis(Vector3.RIGHT, -ang) # sobe no sentido da corrida
	var center: Vector3 = (f["pos"] as Vector3) + Vector3(0, RAMP_SIZE.y * 0.5 - 0.06, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RAMP_SIZE.x, 0.12, slope_len)
	shape.shape = box
	shape.transform = Transform3D(rot, center)
	body.add_child(shape)
	batcher.add_box_xform(shape.transform, box.size, Color(0.75, 0.42, 0.15))
	# Apoios sob a parte alta (só visual) e faixas amarelas na borda.
	var dir: Vector3 = f["dir"]
	var top: Vector3 = (f["pos"] as Vector3) + dir * (RAMP_SIZE.z * 0.5 - 0.15)
	batcher.add_box(top + Vector3(0, (RAMP_SIZE.y - 0.05) * 0.5, 0), Vector3(RAMP_SIZE.x * 0.95, RAMP_SIZE.y - 0.05, 0.12),
			Color(0.4, 0.25, 0.12), f["rot"])
	attractors.append({"pos": f["pos"], "distance": distance, "lateral": lateral, "kind": "ramp"})


# ---------------------------------------------------------------- obstáculos

func _build_obstacle(distance: float, lateral: float, kind: String) -> void:
	var f := _frame(distance, lateral)
	var p: Vector3 = f["pos"]
	var rot: float = f["rot"]
	var body := StaticBody3D.new()
	add_child(body)
	var radius := 1.0
	match kind:
		"cavalete":
			radius = 1.4
			var bs := Basis(Vector3.UP, rot)
			for k in 5:
				var col := Color(1.0, 0.45, 0.05) if k % 2 == 0 else Color(0.92, 0.9, 0.85)
				_vis_box(body, Vector3(0.5, 0.28, 0.06), p + bs * Vector3(-1.0 + k * 0.5, 0.9, 0), rot, col)
			for s: float in [-1.0, 1.0]:
				_vis_box(body, Vector3(0.08, 1.0, 0.5), p + bs * Vector3(s * 1.15, 0.5, 0), rot, Color(0.3, 0.2, 0.12))
			_col_box(body, Vector3(2.6, 1.1, 0.5), p + Vector3(0, 0.55, 0), rot)
		"cones":
			radius = 1.2
			for k in 5:
				var a := k * TAU / 5.0
				var cp := p + Vector3(cos(a), 0, sin(a)) * 0.75
				_vis_cyl(body, 0.2, 0.7, cp, Color(1.0, 0.45, 0.05))
				_col_cyl(body, 0.22, 0.7, cp)
		"lixeira":
			radius = 0.7
			_vis_cyl(body, 0.4, 1.0, p, Color(0.42, 0.44, 0.45))
			_vis_cyl(body, 0.44, 0.1, p + Vector3(0, 1.0, 0), Color(0.3, 0.32, 0.33))
			_col_cyl(body, 0.42, 1.1, p)
		"cacamba":
			radius = 1.4
			_vis_box(body, Vector3(1.9, 1.3, 3.0), p + Vector3(0, 0.65, 0), rot, Color(0.2, 0.35, 0.25))
			_col_box(body, Vector3(1.9, 1.3, 3.0), p + Vector3(0, 0.65, 0), rot)
	obstacles.append({"pos": p, "radius": radius, "kind": kind, "distance": distance, "lateral": lateral})


func _vis_box(_parent: Node3D, size: Vector3, pos: Vector3, rot: float, color: Color) -> void:
	batcher.add_box(pos, size, color, rot)


func _vis_cyl(_parent: Node3D, r: float, h: float, base: Vector3, color: Color) -> void:
	batcher.add_cylinder_y(base, r, h, color, 8)


func _col_box(body: StaticBody3D, size: Vector3, center: Vector3, rot: float) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, rot), center)
	body.add_child(cs)


func _col_cyl(body: StaticBody3D, r: float, h: float, base: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = base + Vector3(0, h * 0.5, 0)
	body.add_child(cs)


# --------------------------------------------------------- faixas de pedestres

func _build_crossing(distance: float) -> void:
	var f := _frame(distance, 0.0)
	var right: Vector3 = f["right"]
	for k in 8:
		batcher.add_flat((f["pos"] as Vector3) + right * (-4.9 + k * 1.4) + Vector3(0, 0.042, 0), Vector2(0.6, 3.0),
				Color(0.9, 0.88, 0.82), f["rot"])
	crossing_points.append({"pos": f["pos"], "dir": f["dir"], "right": right, "distance": distance})


# ------------------------------------------------------------- aceleradores

func _physics_process(dt: float) -> void:
	for b in riders:
		var cd: float = _pad_cooldown.get(b, 0.0)
		cd = maxf(0.0, cd - dt)
		if cd <= 0.0 and b.state == BikeController.State.RIDING:
			for a in attractors:
				if a["kind"] != "pad":
					continue
				var rel := b.global_position - (a["pos"] as Vector3)
				var s := circuit.sample(float(a["distance"]))
				var dir: Vector3 = s["dir"]
				var right := dir.cross(Vector3.UP)
				if absf(rel.dot(dir)) < PAD_SIZE.y * 0.5 and absf(rel.dot(right)) < PAD_SIZE.x * 0.5 + 0.2:
					b.pad_boost()
					cd = 2.0
					break
		_pad_cooldown[b] = cd
