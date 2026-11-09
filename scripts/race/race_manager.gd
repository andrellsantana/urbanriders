extends Node3D
## Regras da corrida: contagem regressiva, checkpoints em ordem (por ciclista), cronômetro,
## classificação ao vivo, chegada de cada ciclista e derrota do jogador.

const Circuit := preload("res://scripts/race/circuit.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const Toon := preload("res://scripts/core/toon_materials.gd")

signal countdown_changed(value: int)
signal race_started
signal checkpoint_passed(index: int, total: int) ## somente o jogador
signal race_finished(time: float, best: float) ## somente o jogador
signal race_lost
signal rider_finished(rider_index: int, time: float, position: int)

enum Phase { COUNTDOWN, RACING, FINISHED, LOST } ## fase do JOGADOR

const COUNTDOWN_TIME := 3.0
const BEST_FILE := "user://recordes.cfg"
const AFTER_PLAYER_TIMEOUT := 120.0 ## tempo extra para os rivais terminarem

var circuit: Circuit
var player: BikeController
var riders: Array[BikeController] = [] ## [0] = jogador
var rider_names: Array[String] = []
var rider_colors: Array[Color] = []
var gates: Array[Dictionary] = []
var phase: Phase = Phase.COUNTDOWN
var countdown: float = COUNTDOWN_TIME
var race_time: float = 0.0 ## cronômetro do jogador (para na chegada)
var clock: float = 0.0 ## relógio geral da corrida
var best_time: float = 0.0
var wrong_way: bool = false
var save_records: bool = true
var finish_order: Array[int] = []
var complete: bool = false ## todos terminaram (ou acabou o tempo extra)
var hold: bool = false
## Estatísticas do jogador (mostradas na chegada).
var stats := {"dist": 0.0, "max": 0.0, "boost": 0.0, "offroad": 0.0, "fast_no_boost": 0.0} ## verdadeiro enquanto o menu inicial está aberto (contagem não começa)

## Estado por ciclista: next_gate, prev_side, finished, time, lost.
var progress: Array[Dictionary] = []

var next_gate: int:
	get:
		return progress[0]["next_gate"] if progress.size() > 0 else 0

var _wrong_timer: float = 0.0
var _gate_nodes: Array[Node3D] = []
var _last_count: int = -1
var _after_player: float = 0.0


func setup(p: BikeController, c: Circuit, player_name: String = "Andrew-Mike",
		player_color: Color = Color(1.0, 0.25, 0.2)) -> void:
	player = p
	circuit = c
	gates = circuit.build_gates()
	best_time = _load_best()
	add_rider(p, player_name, player_color)
	player.out_of_hearts.connect(_on_out_of_hearts)
	for i in gates.size():
		var node := _make_gate_visual(gates[i], i)
		add_child(node)
		_gate_nodes.append(node)
	_refresh_gate_visibility()


func add_rider(b: BikeController, rider_name: String, color: Color) -> int:
	riders.append(b)
	rider_names.append(rider_name)
	rider_colors.append(color)
	b.controls_enabled = false
	progress.append({"next_gate": 0, "prev_side": _side_of(b, gates[0]), "finished": false, "time": 0.0, "lost": false})
	var idx := riders.size() - 1
	if idx > 0:
		b.out_of_hearts.connect(func() -> void:
			if not progress[idx]["finished"]:
				progress[idx]["lost"] = true
				b.set_ghost(true))
	return idx


func gate_count() -> int:
	return gates.size()


func checkpoint_total() -> int:
	return gates.size() - 1


func next_gate_position() -> Vector3:
	return gates[mini(next_gate, gates.size() - 1)]["pos"]


func _physics_process(dt: float) -> void:
	if player == null:
		return
	if phase == Phase.COUNTDOWN:
		if hold:
			return
		countdown -= dt
		var c := ceili(countdown)
		if c != _last_count:
			_last_count = c
			countdown_changed.emit(maxi(c, 0))
		if countdown <= 0.0:
			phase = Phase.RACING
			for r in riders:
				r.controls_enabled = true
			race_started.emit()
		return
	if complete:
		return
	clock += dt
	if phase == Phase.RACING:
		race_time = clock
		_check_wrong_way(dt)
		var v := player.speed
		stats["dist"] = float(stats["dist"]) + v * dt
		stats["max"] = maxf(float(stats["max"]), v * 3.6)
		if player.boosting:
			stats["boost"] = float(stats["boost"]) + dt
		elif v * 3.6 > 25.0:
			stats["fast_no_boost"] = float(stats["fast_no_boost"]) + dt
		if float(circuit.project(player.global_position)["lateral"]) > 5.6:
			stats["offroad"] = float(stats["offroad"]) + dt
	for i in riders.size():
		if not progress[i]["finished"] and not progress[i]["lost"]:
			_check_gate(i)
	if phase != Phase.RACING:
		_after_player += dt
	var all_done := true
	for pr in progress:
		if not pr["finished"] and not pr["lost"]:
			all_done = false
	if all_done or _after_player > AFTER_PLAYER_TIMEOUT:
		complete = true


static func _side_of(b: BikeController, gate: Dictionary) -> float:
	return (b.global_position - (gate["pos"] as Vector3)).dot(gate["dir"])


func _check_gate(i: int) -> void:
	var b := riders[i]
	var pr := progress[i]
	var gate := gates[pr["next_gate"]]
	var side := _side_of(b, gate)
	var rel := b.global_position - (gate["pos"] as Vector3)
	var right := (gate["dir"] as Vector3).cross(Vector3.UP)
	var lateral := absf(rel.dot(right))
	if float(pr["prev_side"]) < 0.0 and side >= 0.0 and lateral <= Circuit.GATE_HALF_WIDTH and absf(side) < 6.0:
		_pass_gate(i)
	else:
		pr["prev_side"] = side


func _pass_gate(i: int) -> void:
	var pr := progress[i]
	var b := riders[i]
	if gates[pr["next_gate"]]["finish"]:
		pr["finished"] = true
		pr["time"] = clock
		finish_order.append(i)
		b.set_ghost(true)
		var pos := finish_order.size()
		if i == 0:
			phase = Phase.FINISHED
			race_time = clock
			player.controls_enabled = false
			wrong_way = false
			if best_time <= 0.0 or race_time < best_time:
				best_time = race_time
				_save_best(best_time)
			_refresh_gate_visibility()
			race_finished.emit(race_time, best_time)
		rider_finished.emit(i, clock, pos)
		return
	pr["next_gate"] = int(pr["next_gate"]) + 1
	pr["prev_side"] = _side_of(b, gates[pr["next_gate"]])
	if i == 0:
		checkpoint_passed.emit(next_gate, checkpoint_total())
		_refresh_gate_visibility()


## Pontuação de progresso: checkpoints passados e distância até o próximo.
func progress_score(i: int) -> float:
	var pr := progress[i]
	var g: Dictionary = gates[pr["next_gate"]]
	var d: float = circuit.project(riders[i].global_position)["distance"]
	var to_next := fposmod(float(g["distance"]) - d, circuit.length)
	if to_next > circuit.length - 50.0:
		to_next = 0.0 # já cruzou a linha mas o portal ainda não confirmou
	return float(pr["next_gate"]) * 100000.0 - to_next


## Índices dos ciclistas na ordem da classificação.
func standings() -> Array[int]:
	var order: Array[int] = finish_order.duplicate()
	var rest: Array[int] = []
	for i in riders.size():
		if not order.has(i):
			rest.append(i)
	rest.sort_custom(func(a: int, b: int) -> bool:
		var la: bool = progress[a]["lost"]
		var lb: bool = progress[b]["lost"]
		if la != lb:
			return lb
		return progress_score(a) > progress_score(b))
	order.append_array(rest)
	return order


func position_of(i: int) -> int:
	return standings().find(i) + 1


func _check_wrong_way(dt: float) -> void:
	var proj := circuit.project(player.global_position)
	var moving_back := player.speed > 2.0 and player.forward().dot(proj["dir"]) < -0.5
	_wrong_timer = _wrong_timer + dt if moving_back else 0.0
	wrong_way = _wrong_timer > 1.2


func _on_out_of_hearts() -> void:
	if phase == Phase.RACING or phase == Phase.COUNTDOWN:
		phase = Phase.LOST
		progress[0]["lost"] = true
		player.controls_enabled = false
		player.set_ghost(true)
		race_lost.emit()


# ------------------------------------------------------------------- visuais

func _make_gate_visual(gate: Dictionary, index: int) -> Node3D:
	var root := Node3D.new()
	root.position = gate["pos"]
	var dir: Vector3 = gate["dir"]
	root.rotation.y = atan2(dir.x, dir.z)
	var finish: bool = gate["finish"]
	var post_col := Color(0.95, 0.95, 0.9) if finish else Color(1.0, 0.6, 0.1)
	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.12
		cyl.height = 4.5
		cyl.radial_segments = 8
		post.mesh = cyl
		post.material_override = Toon.make(post_col)
		post.position = Vector3(side * 6.5, 2.25, 0)
		root.add_child(post)
	var banner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(Circuit.GATE_HALF_WIDTH * 2.0, 0.9, 0.1)
	banner.mesh = bm
	banner.material_override = Toon.make(Color(0.1, 0.1, 0.1) if finish else Color(0.85, 0.3, 0.05), Toon.Outline.BOX, 0.03)
	banner.position = Vector3(0, 4.2, 0)
	root.add_child(banner)
	var label := Label3D.new()
	label.text = "LARGADA / CHEGADA" if finish else "CHECKPOINT %d" % (index + 1)
	label.font_size = 96
	label.pixel_size = 0.006
	label.outline_size = 12
	label.position = Vector3(0, 4.2, -0.07)
	label.rotation.y = PI
	root.add_child(label)
	var curtain := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(Circuit.GATE_HALF_WIDTH * 2.0, 3.6)
	curtain.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.16)
	curtain.material_override = mat
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.position = Vector3(0, 1.9, 0)
	curtain.name = "Curtain"
	root.add_child(curtain)
	if finish:
		for i in 16:
			var sq := MeshInstance3D.new()
			var p := PlaneMesh.new()
			p.size = Vector2(Circuit.GATE_HALF_WIDTH * 2.0 / 16.0, 1.2)
			sq.mesh = p
			sq.material_override = Toon.make(Color.WHITE if i % 2 == 0 else Color(0.05, 0.05, 0.05), Toon.Outline.NONE)
			sq.position = Vector3(-Circuit.GATE_HALF_WIDTH + (i + 0.5) * Circuit.GATE_HALF_WIDTH * 2.0 / 16.0, 0.05, 0)
			root.add_child(sq)
	return root


func _refresh_gate_visibility() -> void:
	for i in _gate_nodes.size():
		var is_finish: bool = gates[i]["finish"]
		var node := _gate_nodes[i]
		node.visible = is_finish or (i == next_gate and phase == Phase.RACING) or (i == next_gate and phase == Phase.COUNTDOWN)
		var curtain := node.get_node("Curtain") as Node3D
		curtain.visible = i == next_gate and (phase == Phase.RACING or phase == Phase.COUNTDOWN)


# ------------------------------------------------------------------- recordes

func _load_best() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(BEST_FILE) != OK:
		return 0.0
	return float(cfg.get_value("circuito", "melhor_tempo", 0.0))


func _save_best(t: float) -> void:
	if not save_records:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("circuito", "melhor_tempo", t)
	cfg.save(BEST_FILE)


static func format_time(t: float) -> String:
	var m := floori(t / 60.0)
	var s := t - m * 60.0
	return "%d:%05.2f" % [m, s]
