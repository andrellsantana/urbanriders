extends Node3D
## Regras da corrida: contagem regressiva, checkpoints em ordem, cronômetro, chegada e derrota.

const Circuit := preload("res://scripts/race/circuit.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const Toon := preload("res://scripts/core/toon_materials.gd")

signal countdown_changed(value: int)
signal race_started
signal checkpoint_passed(index: int, total: int)
signal race_finished(time: float, best: float)
signal race_lost

enum Phase { COUNTDOWN, RACING, FINISHED, LOST }

const COUNTDOWN_TIME := 3.0
const BEST_FILE := "user://recordes.cfg"

var circuit: Circuit
var player: BikeController
var gates: Array[Dictionary] = []
var phase: Phase = Phase.COUNTDOWN
var countdown: float = COUNTDOWN_TIME
var race_time: float = 0.0
var next_gate: int = 0
var best_time: float = 0.0
var wrong_way: bool = false
var save_records: bool = true

var _prev_side: float = -1.0
var _wrong_timer: float = 0.0
var _gate_nodes: Array[Node3D] = []
var _last_count: int = -1


func setup(p: BikeController, c: Circuit) -> void:
	player = p
	circuit = c
	gates = circuit.build_gates()
	player.out_of_hearts.connect(_on_out_of_hearts)
	player.controls_enabled = false
	best_time = _load_best()
	for i in gates.size():
		var node := _make_gate_visual(gates[i], i)
		add_child(node)
		_gate_nodes.append(node)
	_refresh_gate_visibility()
	_prev_side = _side_of(gates[0])


func gate_count() -> int:
	return gates.size()


func checkpoint_total() -> int:
	return gates.size() - 1


func next_gate_position() -> Vector3:
	return gates[mini(next_gate, gates.size() - 1)]["pos"]


func _physics_process(dt: float) -> void:
	if player == null:
		return
	match phase:
		Phase.COUNTDOWN:
			countdown -= dt
			var c := ceili(countdown)
			if c != _last_count:
				_last_count = c
				countdown_changed.emit(maxi(c, 0))
			if countdown <= 0.0:
				phase = Phase.RACING
				player.controls_enabled = true
				race_started.emit()
		Phase.RACING:
			race_time += dt
			_check_gate()
			_check_wrong_way(dt)


func _side_of(gate: Dictionary) -> float:
	return (player.global_position - (gate["pos"] as Vector3)).dot(gate["dir"])


func _check_gate() -> void:
	var gate := gates[next_gate]
	var side := _side_of(gate)
	var rel := player.global_position - (gate["pos"] as Vector3)
	var right := (gate["dir"] as Vector3).cross(Vector3.UP)
	var lateral := absf(rel.dot(right))
	if _prev_side < 0.0 and side >= 0.0 and lateral <= Circuit.GATE_HALF_WIDTH and absf(side) < 6.0:
		_pass_gate()
	else:
		_prev_side = side


func _pass_gate() -> void:
	var gate := gates[next_gate]
	if gate["finish"]:
		phase = Phase.FINISHED
		player.controls_enabled = false
		wrong_way = false
		if best_time <= 0.0 or race_time < best_time:
			best_time = race_time
			_save_best(best_time)
		_refresh_gate_visibility()
		race_finished.emit(race_time, best_time)
		return
	next_gate += 1
	checkpoint_passed.emit(next_gate, checkpoint_total())
	_prev_side = _side_of(gates[next_gate])
	_refresh_gate_visibility()


func _check_wrong_way(dt: float) -> void:
	var proj := circuit.project(player.global_position)
	var moving_back := player.speed > 2.0 and player.forward().dot(proj["dir"]) < -0.5
	_wrong_timer = _wrong_timer + dt if moving_back else 0.0
	wrong_way = _wrong_timer > 1.2


func _on_out_of_hearts() -> void:
	if phase == Phase.RACING or phase == Phase.COUNTDOWN:
		phase = Phase.LOST
		player.controls_enabled = false
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
		post.position = Vector3(side * Circuit.GATE_HALF_WIDTH, 2.25, 0)
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
		node.visible = is_finish or (i == next_gate and phase != Phase.FINISHED)
		var curtain := node.get_node("Curtain") as Node3D
		curtain.visible = i == next_gate and phase != Phase.FINISHED


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
