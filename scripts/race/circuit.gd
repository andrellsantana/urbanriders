extends RefCounted
## Circuito de Red City: laço fechado pelas ruas do bairro (~1,5 km).
## Fornece checkpoints, projeção de posição na rota (progresso) e direção da pista.

## Esquinas do laço (x, z) em metros, no sentido da corrida.
const CORNERS: Array[Vector2] = [
	Vector2(0, 0), Vector2(0, -270), Vector2(150, -270), Vector2(150, -360),
	Vector2(375, -360), Vector2(375, -90), Vector2(225, -90), Vector2(225, 0)]

const START_DISTANCE := 12.0 ## linha de largada/chegada (distância a partir de CORNERS[0])
const SPAWN_DISTANCE := 5.0
const CHECKPOINT_COUNT := 12
const GATE_HALF_WIDTH := 6.5

var points: Array[Vector3] = []
var cumulative: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0


func _init() -> void:
	for c in CORNERS:
		points.append(Vector3(c.x, 0.0, c.y))
	cumulative.append(0.0)
	for i in points.size():
		length += points[i].distance_to(points[(i + 1) % points.size()])
		cumulative.append(length)


func segment_count() -> int:
	return points.size()


## Ponto e direção a uma distância ao longo do laço.
func sample(distance: float) -> Dictionary:
	var d := fposmod(distance, length)
	for i in points.size():
		if d <= cumulative[i + 1]:
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			var dir := (b - a).normalized()
			return {"pos": a + dir * (d - cumulative[i]), "dir": dir, "segment": i}
	return {"pos": points[0], "dir": (points[1] - points[0]).normalized(), "segment": 0}


## Projeta uma posição no laço: distância percorrida, desvio lateral e direção local.
func project(pos: Vector3) -> Dictionary:
	var best := {"distance": 0.0, "lateral": INF, "dir": Vector3.FORWARD}
	var p := Vector3(pos.x, 0.0, pos.z)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q := a + ab * t
		var lat := p.distance_to(q)
		if lat < best["lateral"]:
			best = {"distance": cumulative[i] + ab.length() * t, "lateral": lat, "dir": ab.normalized()}
	return best


## Portais: checkpoints distribuídos pelo laço (afastados das esquinas) + chegada no fim.
func build_gates() -> Array[Dictionary]:
	var gates: Array[Dictionary] = []
	var step := length / float(CHECKPOINT_COUNT + 1)
	for k in range(1, CHECKPOINT_COUNT + 1):
		var d := START_DISTANCE + step * k
		d = _away_from_corners(d)
		var s := sample(d)
		gates.append({"pos": s["pos"], "dir": s["dir"], "distance": fposmod(d, length), "finish": false})
	var f := sample(START_DISTANCE)
	gates.append({"pos": f["pos"], "dir": f["dir"], "distance": START_DISTANCE, "finish": true})
	return gates


func _away_from_corners(d: float) -> float:
	var dm := fposmod(d, length)
	for i in range(points.size() + 1):
		var c := cumulative[i]
		if absf(dm - c) < 15.0:
			return c + 15.0
	return dm


## Arestas da grade (pares de interseções vizinhas) cobertas pela rota.
func route_edges(grid_step_x: float, grid_step_z: float) -> Dictionary:
	var edges := {}
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var dir := (b - a).normalized()
		var step := grid_step_x if absf(dir.x) > 0.5 else grid_step_z
		var n := roundi(a.distance_to(b) / step)
		for k in n:
			var p0 := a + dir * step * k
			var p1 := a + dir * step * (k + 1)
			edges[edge_key(p0, p1)] = true
	return edges


static func edge_key(p0: Vector3, p1: Vector3) -> String:
	var a := Vector2i(roundi(p0.x), roundi(p0.z))
	var b := Vector2i(roundi(p1.x), roundi(p1.z))
	if a.x > b.x or (a.x == b.x and a.y > b.y):
		var t := a
		a = b
		b = t
	return "%d,%d-%d,%d" % [a.x, a.y, b.x, b.y]
