extends Node3D
## Bairro residencial de Red City (interior americano, anos 80), gerado por código.
## Grade de ruas, casas baixas com varanda/garagem, gramados, árvores de outono,
## postes com fios, carros estacionados, barreiras fora da rota e poças no circuito.

const MeshBatcher := preload("res://scripts/world/mesh_batcher.gd")
const Circuit := preload("res://scripts/race/circuit.gd")
const Layer := MeshBatcher.Layer

const STEP_X := 75.0
const STEP_Z := 90.0
const X0 := -75.0
const Z0 := 90.0
const NX := 8 ## linhas de ruas no eixo X (x = -75 … 450)
const NZ := 7 ## linhas de ruas no eixo Z (z = 90 … -450)
const ROAD_HALF := 5.5
const WALK_OUT := 7.5
const PARK_BLOCKS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(5, 1)]

const ASPHALT := Color(0.36, 0.35, 0.37) ## cinza (a luz vermelha do céu ainda tinge)
const LAWN := Color(0.3, 0.32, 0.13)
const FIELD := Color(0.36, 0.27, 0.14)
const SIDEWALK := Color(0.58, 0.5, 0.48)
const CONCRETE := Color(0.52, 0.48, 0.46)
const SIDINGS: Array[Color] = [Color(0.48, 0.44, 0.42), Color(0.55, 0.5, 0.4), Color(0.4, 0.43, 0.48),
	Color(0.6, 0.55, 0.38), Color(0.62, 0.6, 0.56), Color(0.5, 0.3, 0.25), Color(0.38, 0.42, 0.36)]
const ROOFS: Array[Color] = [Color(0.16, 0.14, 0.16), Color(0.25, 0.16, 0.12), Color(0.3, 0.12, 0.1),
	Color(0.2, 0.2, 0.22)]
const TRIMS: Array[Color] = [Color(0.85, 0.83, 0.78), Color(0.75, 0.72, 0.66)]
const DOORS: Array[Color] = [Color(0.45, 0.1, 0.08), Color(0.25, 0.15, 0.1), Color(0.15, 0.2, 0.3), Color(0.8, 0.78, 0.72)]
const FOLIAGE: Array[Color] = [Color(0.62, 0.2, 0.05), Color(0.7, 0.38, 0.07), Color(0.42, 0.12, 0.07),
	Color(0.55, 0.42, 0.12), Color(0.3, 0.22, 0.08)]
const CARS: Array[Color] = [Color(0.2, 0.45, 0.5), Color(0.72, 0.66, 0.5), Color(0.4, 0.22, 0.12),
	Color(0.45, 0.08, 0.08), Color(0.3, 0.32, 0.36)]
const LIT := Color(1.0, 0.72, 0.36)
const DARK_GLASS := Color(0.09, 0.07, 0.11)

var batcher := MeshBatcher.new()
var circuit := Circuit.new()
var house_tops: Array[float] = []
var barricades: Array[Vector3] = []
var puddles: Array[Vector3] = []
var parked_cars: Array[Vector3] = [] ## carros estacionados nas ruas da corrida (para o trânsito desviar)
var mesh_instance_count: int = 0
var _rng := RandomNumberGenerator.new()
var _bodies: Dictionary = {}
var _route_edges: Dictionary = {}


func _ready() -> void:
	_rng.seed = 1983
	_route_edges = circuit.route_edges(STEP_X, STEP_Z)
	_build_ground()
	_build_streets()
	for i in NX - 1:
		for j in NZ - 1:
			if PARK_BLOCKS.has(Vector2i(i, j)):
				_build_park(i, j)
			else:
				_build_block(i, j)
	_build_poles()
	_build_barricades()
	_build_puddles()
	_build_outskirts()
	_build_landmarks()
	mesh_instance_count = batcher.build(self)


static func grid_x(i: int) -> float:
	return X0 + STEP_X * i


static func grid_z(j: int) -> float:
	return Z0 - STEP_Z * j


static func bounds() -> Rect2:
	return Rect2(X0, grid_z(NZ - 1), STEP_X * (NX - 1), STEP_Z * (NZ - 1))


# ------------------------------------------------------------------- colisão

func _body(pos: Vector3) -> StaticBody3D:
	var key := Vector2i(floori(pos.x / 130.0), floori(pos.z / 130.0))
	if not _bodies.has(key):
		var b := StaticBody3D.new()
		b.name = "Colisao_%d_%d" % [key.x, key.y]
		add_child(b)
		_bodies[key] = b
	return _bodies[key]


func _col_box(center: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(Basis(Vector3.UP, rot_y), center)
	_body(center).add_child(cs)


func _col_cyl(base: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	cs.position = base + Vector3(0, h * 0.5, 0)
	_body(base).add_child(cs)


func _pick(list: Array) -> Variant:
	return list[_rng.randi() % list.size()]


# --------------------------------------------------------------- chão e ruas

func _build_ground() -> void:
	var b := bounds()
	var center := Vector3(b.get_center().x, 0, b.get_center().y)
	var ground := StaticBody3D.new()
	ground.name = "Chao"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(b.size.x + 600, 1, b.size.y + 600)
	cs.shape = box
	cs.position = center + Vector3(0, -0.5, 0)
	ground.add_child(cs)
	add_child(ground)
	batcher.add_flat(center + Vector3(0, -0.01, 0), Vector2(b.size.x + 600, b.size.y + 600), FIELD)
	batcher.add_flat(center, Vector2(b.size.x + 30, b.size.y + 30), LAWN)
	# Paredes invisíveis no limite do mundo.
	var m := 28.0
	_col_box(Vector3(b.position.x - m, 2, center.z), Vector3(2, 4, b.size.y + 2 * m))
	_col_box(Vector3(b.end.x + m, 2, center.z), Vector3(2, 4, b.size.y + 2 * m))
	_col_box(Vector3(center.x, 2, b.position.y - m), Vector3(b.size.x + 2 * m, 4, 2))
	_col_box(Vector3(center.x, 2, b.end.y + m), Vector3(b.size.x + 2 * m, 4, 2))


func _build_streets() -> void:
	var b := bounds()
	var zc := b.get_center().y
	var xc := b.get_center().x
	var dash := Color(0.9, 0.75, 0.35)
	for i in NX:
		var x := grid_x(i)
		batcher.add_flat(Vector3(x, 0.02, zc), Vector2(ROAD_HALF * 2, b.size.y + ROAD_HALF * 2), ASPHALT)
		for j in NZ - 1:
			var z := grid_z(j) - 10.0
			while z > grid_z(j + 1) + 10.0:
				batcher.add_flat(Vector3(x, 0.035, z - 1.5), Vector2(0.18, 3.0), dash)
				z -= 8.0
	for j in NZ:
		var z := grid_z(j)
		batcher.add_flat(Vector3(xc, 0.025, z), Vector2(b.size.x + ROAD_HALF * 2, ROAD_HALF * 2), ASPHALT)
		for i in NX - 1:
			var x := grid_x(i) + 10.0
			while x < grid_x(i + 1) - 10.0:
				batcher.add_flat(Vector3(x + 1.5, 0.035, z), Vector2(3.0, 0.18), dash)
				x += 8.0
	# Calçadas ao redor de cada quarteirão.
	for i in NX - 1:
		for j in NZ - 1:
			var x0 := grid_x(i) + ROAD_HALF
			var x1 := grid_x(i + 1) - ROAD_HALF
			var zt := grid_z(j) - ROAD_HALF
			var zb := grid_z(j + 1) + ROAD_HALF
			var w := WALK_OUT - ROAD_HALF
			batcher.add_flat(Vector3(x0 + w / 2, 0.03, (zt + zb) / 2), Vector2(w, zt - zb), SIDEWALK)
			batcher.add_flat(Vector3(x1 - w / 2, 0.03, (zt + zb) / 2), Vector2(w, zt - zb), SIDEWALK)
			batcher.add_flat(Vector3((x0 + x1) / 2, 0.031, zt - w / 2), Vector2(x1 - x0, w), SIDEWALK)
			batcher.add_flat(Vector3((x0 + x1) / 2, 0.031, zb + w / 2), Vector2(x1 - x0, w), SIDEWALK)


# ---------------------------------------------------------------- quarteirões

func _build_block(i: int, j: int) -> void:
	var ix0 := grid_x(i) + WALK_OUT
	var ix1 := grid_x(i + 1) - WALK_OUT
	var izt := grid_z(j) - WALK_OUT
	var izb := grid_z(j + 1) + WALK_OUT
	var w := ix1 - ix0
	var d := izt - izb
	if (i + j) % 2 == 0:
		var n := 4
		var lw := d / n
		for k in n:
			var z := izt - lw * (k + 0.5)
			_build_lot(Vector3(ix0, 0, z), Vector3.LEFT, lw, w / 2.0, true)
			_build_lot(Vector3(ix1, 0, z), Vector3.RIGHT, lw, w / 2.0, false)
	else:
		var n := 3
		var lw := w / n
		for k in n:
			var x := ix0 + lw * (k + 0.5)
			_build_lot(Vector3(x, 0, izt), Vector3.BACK, lw, d / 2.0, true)
			_build_lot(Vector3(x, 0, izb), Vector3.FORWARD, lw, d / 2.0, false)


## Um terreno com casa. front = centro da divisa com a calçada; f = direção da rua.
func _build_lot(front: Vector3, f: Vector3, lot_w: float, lot_d: float, back_fence: bool) -> void:
	var rot := atan2(f.x, f.z)
	var bs := Basis(Vector3.UP, rot)
	var L := func(x: float, y: float, z: float) -> Vector3: return front + bs * Vector3(x, y, z)
	var side_n := bs * Vector3.RIGHT

	var has_garage := _rng.randf() < 0.45
	var tall := _rng.randf() < 0.2
	var w := _rng.randf_range(8.5, minf(12.0, lot_w - 4.5))
	if has_garage:
		w = minf(w, lot_w - 10.6)
		if w < 7.0:
			has_garage = false
			w = _rng.randf_range(8.5, minf(12.0, lot_w - 4.5))
	var d := _rng.randf_range(7.5, 9.5)
	var wall_h := _rng.randf_range(4.3, 4.7) if tall else _rng.randf_range(2.7, 3.1)
	var roof_h := _rng.randf_range(1.4, 2.0)
	var setback := _rng.randf_range(6.5, 9.0)
	var hz := -(setback + d / 2.0)
	var zf := hz + d / 2.0
	var siding: Color = _pick(SIDINGS)
	var roof: Color = _pick(ROOFS)
	var trim: Color = _pick(TRIMS)
	var gs := -1.0 if _rng.randf() < 0.5 else 1.0

	# Corpo da casa.
	batcher.add_box(L.call(0, 0.2, hz), Vector3(w + 0.2, 0.4, d + 0.2), Color(0.33, 0.31, 0.31), rot)
	batcher.add_box(L.call(0, 0.4 + wall_h / 2, hz), Vector3(w, wall_h, d), siding, rot)
	batcher.add_roof(L.call(0, 0.4 + wall_h, hz), w + 0.9, d + 1.0, roof_h, roof, rot)
	house_tops.append(0.4 + wall_h + roof_h)
	_col_box(L.call(0, (0.4 + wall_h) / 2, hz), Vector3(w + 0.2, 0.4 + wall_h, d + 0.2), rot)
	if _rng.randf() < 0.5:
		var cx := (w / 2 - 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var ch := roof_h + 0.8
		batcher.add_box(L.call(cx, 0.4 + wall_h + ch / 2, hz - d * 0.18), Vector3(0.7, ch, 0.7), Color(0.42, 0.18, 0.13), rot)

	# Porta, varanda e janelas.
	var door_x := _rng.randf_range(-w / 5, w / 5)
	var porch := _rng.randf() < 0.65
	var door_col: Color = _pick(DOORS)
	batcher.add_box(L.call(door_x, 0.4 + 1.05, zf + 0.04), Vector3(1.0, 2.1, 0.1), door_col, rot)
	var walk_x := door_x
	var walk_from := zf
	if porch:
		var pw := minf(w * 0.65, 6.5)
		var px := clampf(door_x, -w / 2 + pw / 2, w / 2 - pw / 2)
		batcher.add_box(L.call(px, 0.2, zf + 1.1), Vector3(pw, 0.4, 2.2), Color(0.42, 0.36, 0.32), rot)
		batcher.add_box(L.call(px, 0.4 + 2.45, zf + 1.2), Vector3(pw + 0.3, 0.14, 2.5), roof, rot)
		for s: float in [-1.0, 1.0]:
			batcher.add_box(L.call(px + s * (pw / 2 - 0.15), 0.4 + 1.15, zf + 2.1), Vector3(0.14, 2.3, 0.14), trim, rot)
			var rail_len := pw / 2 - 0.85
			batcher.add_box(L.call(px + s * (0.75 + rail_len / 2), 0.4 + 0.85, zf + 2.1), Vector3(rail_len, 0.08, 0.06), trim, rot)
		batcher.add_box(L.call(door_x, 0.12, zf + 2.55), Vector3(1.4, 0.24, 0.6), Color(0.42, 0.36, 0.32), rot)
		_col_box(L.call(px, 0.6, zf + 1.2), Vector3(pw, 1.2, 2.4), rot)
		walk_from = zf + 2.85
		if _rng.randf() < 0.5:
			batcher.add_panel(L.call(door_x + 0.8, 0.4 + 2.0, zf + 0.12), 0.18, 0.25, f, LIT, Layer.GLOW)
	_windows_on_wall(L, f, side_n, w, zf, wall_h, door_x, tall, true)
	for s: float in [-1.0, 1.0]:
		var sn := side_n * s
		var c: Vector3 = L.call(s * (w / 2 + 0.06), 0.4 + 1.6, hz)
		var side_lit := _rng.randf() < 0.3
		batcher.add_panel(c, 1.0, 1.1, sn, LIT if side_lit else DARK_GLASS, Layer.GLOW if side_lit else Layer.FLAT)
	batcher.add_flat(L.call(walk_x, 0.03, walk_from / 2.0), Vector2(1.2, -walk_from), CONCRETE, rot)

	# Garagem e entrada de carro.
	var dw_x := INF
	if has_garage:
		var gx := gs * (w / 2 + 2.7)
		var gz := zf - 3.2
		batcher.add_box(L.call(gx, 0.2 + 1.35, gz), Vector3(5.2, 2.7, 6.4), siding, rot)
		batcher.add_roof(L.call(gx, 2.9, gz), 6.9, 5.8, 1.0, roof, rot + PI / 2)
		batcher.add_box(L.call(gx, 0.2 + 1.05, gz + 3.22), Vector3(4.2, 2.1, 0.08), trim, rot)
		_col_box(L.call(gx, 1.5, gz), Vector3(5.2, 3.0, 6.4), rot)
		dw_x = gx
		batcher.add_flat(L.call(gx, 0.032, (gz + 3.2 + 2.0) / 2), Vector2(3.6, 2.0 - gz - 3.2), CONCRETE, rot)
	elif lot_w / 2 - w / 2 >= 3.4 and _rng.randf() < 0.7:
		dw_x = gs * (w / 2 + 1.8)
		batcher.add_flat(L.call(dw_x, 0.032, (hz + 2.0) / 2), Vector2(3.0, 2.0 - hz), CONCRETE, rot)

	# Arbustos, árvores e caixa de correio.
	for k in _rng.randi_range(1, 3):
		var bx := _rng.randf_range(-w / 2 + 0.6, w / 2 - 0.6)
		if absf(bx - door_x) < 1.6:
			continue
		var bush_col := Color(0.16, 0.2, 0.09) if _rng.randf() < 0.6 else Color(0.35, 0.18, 0.07)
		batcher.add_blob(L.call(bx, 0.5, zf + 0.7), Vector3(0.7, 0.55, 0.6), bush_col, 6, 3)
	if _rng.randf() < 0.65:
		var tx := -gs * _rng.randf_range(lot_w / 2 - 3.5, lot_w / 2 - 2.0)
		if absf(tx - dw_x) > 3.0 and absf(tx - walk_x) > 2.5:
			_tree(L.call(tx, 0, _rng.randf_range(-4.5, -2.5)), _rng.randf_range(0.85, 1.15))
	if _rng.randf() < 0.5:
		_tree(L.call(_rng.randf_range(-lot_w / 2 + 3, lot_w / 2 - 3), 0, -lot_d + _rng.randf_range(3.0, 5.0)),
				_rng.randf_range(0.9, 1.3))
	if _rng.randf() < 0.8:
		var mx := walk_x + 1.3 if dw_x == INF else dw_x + gs * 2.2
		var mb: Vector3 = L.call(mx, 0, 1.6)
		batcher.add_box(mb + Vector3(0, 0.5, 0), Vector3(0.1, 1.0, 0.1), Color(0.3, 0.2, 0.12), rot)
		batcher.add_box(mb + Vector3(0, 1.1, 0), Vector3(0.28, 0.26, 0.5), Color(0.15, 0.25, 0.18), rot)
		_col_box(mb + Vector3(0, 0.6, 0), Vector3(0.3, 1.2, 0.5), rot)
	if _rng.randf() < 0.12:
		var tc: Vector3 = L.call(walk_x - 1.4, 0, 1.3)
		batcher.add_cylinder_y(tc, 0.3, 0.95, Color(0.45, 0.45, 0.47))
		_col_cyl(tc, 0.32, 1.0)

	# Cercas.
	if _rng.randf() < 0.25:
		_picket_fence(L, rot, lot_w, [walk_x, dw_x])
	if back_fence:
		batcher.add_box(L.call(0, 0.9, -lot_d), Vector3(lot_w, 1.8, 0.08), Color(0.32, 0.2, 0.12), rot)
		_col_box(L.call(0, 0.9, -lot_d), Vector3(lot_w, 1.8, 0.2), rot)

	# Carro estacionado junto ao meio-fio.
	var street_point: Vector3 = L.call(0, 0, WALK_OUT)
	var on_route := float(circuit.project(street_point)["lateral"]) < 2.0
	if _rng.randf() < 0.12:
		var cx := -gs * lot_w * 0.25
		if on_route:
			parked_cars.append(L.call(cx, 0, (WALK_OUT - ROAD_HALF) + (ROAD_HALF - 4.3)))
		_vehicle(L.call(cx, 0, (WALK_OUT - ROAD_HALF) + (ROAD_HALF - 4.3)), rot + PI / 2, _pick(CARS))


func _windows_on_wall(L: Callable, f: Vector3, _side_n: Vector3, w: float, zf: float, wall_h: float,
		door_x: float, tall: bool, _front: bool) -> void:
	var count := floori((w - 1.5) / 2.4)
	for k in count:
		var x := -w / 2 + (k + 0.5) * w / count
		var floors := [0.4 + 1.6]
		if tall:
			floors.append(0.4 + wall_h - 1.2)
		for y: float in floors:
			if y < 2.5 and absf(x - door_x) < 1.3:
				continue
			var lit := _rng.randf() < 0.4
			batcher.add_box(L.call(x, y, zf + 0.04), Vector3(1.3, 1.4, 0.1), Color(0.82, 0.8, 0.74), atan2(f.x, f.z))
			batcher.add_panel(L.call(x, y, zf + 0.1), 1.0, 1.1, f, LIT if lit else DARK_GLASS, Layer.GLOW if lit else Layer.FLAT)


func _picket_fence(L: Callable, rot: float, lot_w: float, gaps: Array) -> void:
	var white := Color(0.85, 0.83, 0.78)
	var x := -lot_w / 2 + 0.3
	var end := lot_w / 2 - 0.3
	var cuts: Array[Vector2] = []
	for g: float in gaps:
		if g != INF:
			cuts.append(Vector2(g - 1.9, g + 1.9))
	var seg_start := x
	var step := 0.25
	var in_gap := false
	while x <= end:
		var blocked := false
		for c in cuts:
			if x > c.x and x < c.y:
				blocked = true
		if blocked and not in_gap:
			_fence_segment(L, rot, seg_start, x, white)
			in_gap = true
		elif not blocked and in_gap:
			seg_start = x
			in_gap = false
		x += step
	if not in_gap:
		_fence_segment(L, rot, seg_start, end, white)


func _fence_segment(L: Callable, rot: float, a: float, b: float, col: Color) -> void:
	if b - a < 0.6:
		return
	var c: Vector3 = L.call((a + b) / 2, 0.45, -0.3)
	batcher.add_box(c, Vector3(b - a, 0.9, 0.06), col, rot)
	_col_box(c, Vector3(b - a, 0.9, 0.2), rot)


func _tree(base: Vector3, s: float = 1.0) -> void:
	var trunk_h := 3.0 * s
	batcher.add_cylinder_y(base, 0.22 * s, trunk_h + 0.6, Color(0.24, 0.15, 0.09), 6)
	_col_cyl(base, 0.3 * s, 3.0)
	var col: Color = _pick(FOLIAGE)
	var col2: Color = _pick(FOLIAGE)
	batcher.add_blob(base + Vector3(0, trunk_h + 1.4 * s, 0), Vector3(2.2, 1.7, 2.1) * s, col)
	batcher.add_blob(base + Vector3(0.9 * s, trunk_h + 0.8 * s, 0.5 * s), Vector3(1.5, 1.2, 1.4) * s, col2)
	batcher.add_blob(base + Vector3(-0.8 * s, trunk_h + 0.9 * s, -0.6 * s), Vector3(1.4, 1.2, 1.5) * s, col)


func _vehicle(center: Vector3, rot: float, col: Color) -> void:
	var bs := Basis(Vector3.UP, rot)
	var P := func(x: float, y: float, z: float) -> Vector3: return center + bs * Vector3(x, y, z)
	batcher.add_box(P.call(0, 0.78, 0), Vector3(2.0, 0.75, 5.1), col, rot)
	batcher.add_box(P.call(0, 1.55, 0.55), Vector3(1.9, 0.85, 1.9), col, rot)
	batcher.add_box(P.call(0, 1.28, -1.6), Vector3(2.0, 0.25, 1.8), col.darkened(0.2), rot)
	batcher.add_panel(P.call(0, 1.62, 1.52), 1.6, 0.6, bs * Vector3.BACK, DARK_GLASS, Layer.FLAT)
	batcher.add_box(P.call(0, 0.62, 2.6), Vector3(2.05, 0.22, 0.12), Color(0.75, 0.75, 0.75), rot)
	for s: float in [-1.0, 1.0]:
		for z: float in [-1.6, 1.6]:
			var t := Transform3D(bs * Basis(Vector3.BACK, -s * PI / 2), P.call(s * 0.8, 0.38, z))
			batcher.add_cylinder(t, 0.38, 0.3, Color(0.06, 0.06, 0.06), 8)
	_col_box(P.call(0, 1.0, 0), Vector3(2.1, 2.0, 5.2), rot)


# --------------------------------------------------------------------- parques

func _build_park(i: int, j: int) -> void:
	var x0 := grid_x(i) + WALK_OUT
	var x1 := grid_x(i + 1) - WALK_OUT
	var zt := grid_z(j) - WALK_OUT
	var zb := grid_z(j + 1) + WALK_OUT
	var c := Vector3((x0 + x1) / 2, 0, (zt + zb) / 2)
	batcher.add_flat(c + Vector3(0, 0.012, 0), Vector2(x1 - x0, zt - zb), Color(0.17, 0.21, 0.08))
	batcher.add_flat(c + Vector3(0, 0.03, 0), Vector2(2.0, zt - zb), CONCRETE)
	batcher.add_flat(c + Vector3(0, 0.032, 0), Vector2(x1 - x0, 2.0), CONCRETE)
	for k in 14:
		var p := Vector3(_rng.randf_range(x0 + 4, x1 - 4), 0, _rng.randf_range(zb + 4, zt - 4))
		if absf(p.x - c.x) < 4.0 or absf(p.z - c.z) < 4.0:
			continue
		_tree(p, _rng.randf_range(1.0, 1.4))
	for s: float in [-1.0, 1.0]:
		var bench := c + Vector3(s * 6.0, 0, 2.2)
		batcher.add_box(bench + Vector3(0, 0.45, 0), Vector3(1.8, 0.1, 0.5), Color(0.4, 0.25, 0.12))
		batcher.add_box(bench + Vector3(0, 0.75, -0.22), Vector3(1.8, 0.5, 0.08), Color(0.4, 0.25, 0.12))
		_col_box(bench + Vector3(0, 0.5, 0), Vector3(1.8, 1.0, 0.6))
	# Balanço.
	var sw := c + Vector3(12, 0, -12)
	for s: float in [-1.0, 1.0]:
		batcher.add_box(sw + Vector3(s * 1.8, 1.25, 0), Vector3(0.12, 2.5, 0.12), Color(0.55, 0.12, 0.1))
	batcher.add_box(sw + Vector3(0, 2.5, 0), Vector3(3.8, 0.12, 0.12), Color(0.55, 0.12, 0.1))
	_col_box(sw + Vector3(0, 1.25, 0), Vector3(3.9, 2.5, 0.4))


# ------------------------------------------------------------ postes e fios

func _build_poles() -> void:
	var b := bounds()
	var brown := Color(0.28, 0.17, 0.1)
	var wire := Color(0.05, 0.03, 0.04)
	for i in NX:
		var x := grid_x(i) + 6.3
		var prev := Vector3.INF
		var z := b.end.y - 14.0
		while z > b.position.y + 14.0:
			var near := absf(fposmod(Z0 - z + STEP_Z / 2, STEP_Z) - STEP_Z / 2) < 11.0
			if not near:
				var p := Vector3(x, 0, z)
				_pole(p, brown, false)
				if prev != Vector3.INF:
					for o: float in [-0.9, 0.9]:
						var a := prev + Vector3(o, 8.45, 0)
						var e := p + Vector3(o, 8.45, 0)
						batcher.add_box((a + e) / 2, Vector3(0.035, 0.035, a.distance_to(e)), wire)
				prev = p
			z -= 37.0
	for j in NZ:
		var z := grid_z(j) - 6.3
		var prev := Vector3.INF
		var x := b.position.x + 14.0
		while x < b.end.x - 14.0:
			var near := absf(fposmod(x - X0 + STEP_X / 2, STEP_X) - STEP_X / 2) < 11.0
			if not near:
				var p := Vector3(x, 0, z)
				_pole(p, brown, true)
				if prev != Vector3.INF:
					for o: float in [-0.9, 0.9]:
						var a := prev + Vector3(0, 8.45, o)
						var e := p + Vector3(0, 8.45, o)
						batcher.add_box((a + e) / 2, Vector3(a.distance_to(e), 0.035, 0.035), wire)
				prev = p
			x += 37.0


func _pole(p: Vector3, col: Color, along_x: bool) -> void:
	batcher.add_cylinder_y(p, 0.14, 9.0, col, 6)
	var arm := Vector3(0.14, 0.14, 2.2) if along_x else Vector3(2.2, 0.14, 0.14)
	batcher.add_box(p + Vector3(0, 8.4, 0), arm, col)
	if _rng.randf() < 0.3:
		batcher.add_cylinder_y(p + Vector3(0.35, 6.6, 0.0), 0.28, 0.8, Color(0.45, 0.45, 0.47), 8)
	_col_cyl(p, 0.2, 4.0)


# ----------------------------------------------------------------- barreiras

func _build_barricades() -> void:
	for i in NX:
		for j in NZ:
			var p := Vector3(grid_x(i), 0, grid_z(j))
			var dirs: Array[Vector3] = []
			var on_route := false
			for n: Array in [[Vector3.RIGHT, STEP_X, i < NX - 1], [Vector3.LEFT, STEP_X, i > 0],
					[Vector3.FORWARD, STEP_Z, j < NZ - 1], [Vector3.BACK, STEP_Z, j > 0]]:
				var dir: Vector3 = n[0]
				if not n[2]:
					continue
				var key := Circuit.edge_key(p, p + dir * float(n[1]))
				if _route_edges.has(key):
					on_route = true
				else:
					dirs.append(dir)
			if not on_route:
				continue
			for dir in dirs:
				_barricade(p + dir * 9.5, atan2(dir.x, dir.z))


func _barricade(c: Vector3, rot: float) -> void:
	barricades.append(c)
	var bs := Basis(Vector3.UP, rot)
	var width := WALK_OUT * 2.0
	var n := 7
	for k in n:
		var x := -width / 2 + (k + 0.5) * width / n
		var col := Color(1.0, 0.45, 0.05) if k % 2 == 0 else Color(0.9, 0.88, 0.82)
		batcher.add_box(c + bs * Vector3(x, 1.0, 0), Vector3(width / n, 0.32, 0.08), col, rot)
		batcher.add_box(c + bs * Vector3(x, 0.55, 0), Vector3(width / n, 0.26, 0.08), col.darkened(0.1), rot)
	for s: float in [-1.0, -0.33, 0.33, 1.0]:
		batcher.add_box(c + bs * Vector3(s * (width / 2 - 0.3), 0.6, 0), Vector3(0.1, 1.2, 0.6), Color(0.3, 0.2, 0.12), rot)
	_col_box(c + Vector3(0, 0.8, 0), Vector3(width + 1.0, 1.6, 0.6), rot)


# --------------------------------------------------------------------- poças

func _build_puddles() -> void:
	_puddle_zone(Vector3(136, 0, -270), Vector2(14, 9))
	_puddle_zone(Vector3(360, 0, -360), Vector2(14, 9))
	_puddle_zone(Vector3(375, 0, -215), Vector2(8, 16))


func _puddle_zone(c: Vector3, size: Vector2) -> void:
	puddles.append(c)
	var area := Area3D.new()
	area.position = c + Vector3(0, 0.5, 0)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 1.0, size.y)
	cs.shape = box
	area.add_child(cs)
	area.collision_mask = 3 # mundo + ciclistas
	area.body_entered.connect(func(b: Node3D) -> void:
		if b.has_method("enter_surface"):
			b.enter_surface(0.45, "asfalto molhado"))
	area.body_exited.connect(func(b: Node3D) -> void:
		if b.has_method("exit_surface"):
			b.exit_surface("asfalto molhado"))
	add_child(area)
	batcher.add_flat(c + Vector3(0, 0.036, 0), size * 0.95, Color(0.1, 0.08, 0.12))
	for k in 6:
		var p := c + Vector3(_rng.randf_range(-size.x, size.x) * 0.38, 0.04, _rng.randf_range(-size.y, size.y) * 0.38)
		batcher.add_flat(p, Vector2(_rng.randf_range(0.8, 2.0), _rng.randf_range(0.6, 1.4)),
				Color(0.36, 0.08, 0.08), _rng.randf_range(0, PI))


# ------------------------------------------------------- arredores e marcos

func _build_outskirts() -> void:
	var b := bounds()
	var m := 34.0
	var r := Rect2(b.position - Vector2(m, m), b.size + Vector2(m, m) * 2)
	var perimeter: Array[Array] = [[r.position, Vector2(r.end.x, r.position.y)],
		[Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)],
		[Vector2(r.position.x, r.end.y), r.position]]
	for edge in perimeter:
		var a: Vector2 = edge[0]
		var e: Vector2 = edge[1]
		var len := a.distance_to(e)
		var t := 0.0
		while t < len:
			var p := a.lerp(e, t / len)
			var jitter := Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
			_tree(Vector3(p.x + jitter.x, 0, p.y + jitter.y), _rng.randf_range(1.3, 1.9))
			t += _rng.randf_range(8.0, 13.0)
	for k in 40:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(60.0, 160.0)
		var cpos := b.get_center() + Vector2(cos(ang), sin(ang)) * (maxf(b.size.x, b.size.y) / 2 + dist)
		_tree(Vector3(cpos.x, 0, cpos.y), _rng.randf_range(1.4, 2.2))


func _build_landmarks() -> void:
	# Caixa d'água de Red City, além do limite oeste.
	var base := Vector3(-150, 0, -200)
	for corner: Vector2 in [Vector2(-3.5, -3.5), Vector2(3.5, -3.5), Vector2(-3.5, 3.5), Vector2(3.5, 3.5)]:
		batcher.add_cylinder_y(base + Vector3(corner.x, 0, corner.y), 0.35, 20.0, Color(0.5, 0.48, 0.5), 6)
	batcher.add_cylinder_y(base + Vector3(0, 20, 0), 7.0, 8.0, Color(0.72, 0.7, 0.7), 16)
	batcher.add_cylinder_y(base + Vector3(0, 28, 0), 4.0, 2.2, Color(0.55, 0.52, 0.52), 16)
	var label := Label3D.new()
	label.text = "RED CITY"
	label.font_size = 220
	label.pixel_size = 0.014
	label.outline_size = 18
	label.modulate = Color(0.18, 0.05, 0.05)
	label.position = base + Vector3(7.05, 24.2, 0)
	label.rotation.y = PI / 2
	add_child(label)
	# Placa de boas-vindas logo após a largada.
	var sign_pos := Vector3(-9.3, 0, -28)
	for s: float in [-1.3, 1.3]:
		batcher.add_box(sign_pos + Vector3(s, 1.0, 0), Vector3(0.14, 2.0, 0.14), Color(0.3, 0.18, 0.1))
	batcher.add_box(sign_pos + Vector3(0, 2.6, 0), Vector3(3.4, 1.6, 0.14), Color(0.16, 0.24, 0.17))
	_col_box(sign_pos + Vector3(0, 1.5, 0), Vector3(3.4, 3.0, 0.4))
	var sl := Label3D.new()
	sl.text = "BEM-VINDO A\nRED CITY"
	sl.font_size = 64
	sl.pixel_size = 0.006
	sl.outline_size = 10
	sl.modulate = Color(0.95, 0.92, 0.85)
	sl.position = sign_pos + Vector3(0, 2.6, 0.09)
	add_child(sl)
