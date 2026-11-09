extends RefCounted
## Caminho fechado (laço) amostrável por distância. Usado pelas faixas dos carros.

var pts: Array[Vector3] = []
var cum: PackedFloat32Array = PackedFloat32Array()
var length: float = 0.0


func _init(points: Array[Vector3]) -> void:
	pts = points
	cum.append(0.0)
	for i in pts.size():
		length += pts[i].distance_to(pts[(i + 1) % pts.size()])
		cum.append(length)


func sample(distance: float) -> Dictionary:
	var d := fposmod(distance, length)
	for i in pts.size():
		if d <= cum[i + 1]:
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			var dir := (b - a).normalized()
			return {"pos": a + dir * (d - cum[i]), "dir": dir}
	return {"pos": pts[0], "dir": (pts[1] - pts[0]).normalized()}


## Direção suavizada (média entre um pouco antes e um pouco depois) para curvas sem "quinas".
func smooth_dir(distance: float, span: float = 4.0) -> Vector3:
	var a: Vector3 = sample(distance - span)["pos"]
	var b: Vector3 = sample(distance + span)["pos"]
	return (b - a).normalized()


## Desloca um laço lateralmente (+ = à direita do sentido), com esquinas em meia-esquadria.
static func offset_loop(points: Array[Vector3], lateral: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var n := points.size()
	for i in n:
		var p := points[i]
		var d_in := (p - points[(i - 1 + n) % n]).normalized()
		var d_out := (points[(i + 1) % n] - p).normalized()
		var r_in := d_in.cross(Vector3.UP)
		var r_out := d_out.cross(Vector3.UP)
		var m := (r_in + r_out).normalized()
		out.append(p + m * (lateral / maxf(m.dot(r_in), 0.3)))
	return out
