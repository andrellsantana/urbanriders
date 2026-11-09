extends SceneTree
## Testes automatizados (unidade + integração). Executar:
##   godot --headless --fixed-fps 60 -s res://tests/run_tests.gd

const BikeConfig := preload("res://scripts/physics/bike_config.gd")
const BikePhysics := preload("res://scripts/physics/bike_physics.gd")
const Stamina := preload("res://scripts/physics/stamina.gd")
const RiderVisual := preload("res://scripts/player/rider_visual.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const Circuit := preload("res://scripts/race/circuit.gd")
const RaceManager := preload("res://scripts/race/race_manager.gd")

var _passes: int = 0
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  OK     ", label)
	else:
		_fails += 1
		printerr("  FALHA  ", label)


func _run() -> void:
	print("\n== Testes de unidade ==")
	_test_stamina()
	_test_physics()
	_test_ik()
	print("\n== Testes de integração ==")
	await _test_integration()
	print("\n== Bairro e corrida ==")
	_test_circuit()
	await _test_neighborhood_race()
	print("\nResultado: %d ok, %d falhas\n" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------ unidade

func _test_stamina() -> void:
	var s := Stamina.new()
	for i in 60 * 60:
		s.update(Stamina.Effort.NORMAL, 0.0, 1.0 / 60.0)
	check(s.value > 20.0 and s.value < 100.0, "pedalada normal: consumo baixo (60 s → %.0f%%)" % s.value)

	var a := Stamina.new()
	var b := Stamina.new()
	for i in 600:
		a.update(Stamina.Effort.NORMAL, 0.0, 1.0 / 60.0)
		b.update(Stamina.Effort.BOOST, 1.0, 1.0 / 60.0)
	check(b.value < a.value - 50.0, "turbo gasta muito mais que pedalada normal")

	var c := Stamina.new()
	c.value = 50.0
	c.update(Stamina.Effort.COAST, 0.0, 1.0)
	check(c.value > 50.0, "sem pedalar: recupera energia")

	var d := Stamina.new()
	for i in 60 * 30:
		d.update(Stamina.Effort.BOOST, 1.0, 1.0 / 60.0)
	check(d.exhausted and not d.can_boost(), "energia esgotada: fica cansado e sem turbo")
	check(d.performance() < 0.8, "cansado: desempenho reduzido")
	for i in 60 * 3:
		d.update(Stamina.Effort.REST, 0.0, 1.0 / 60.0)
	check(d.exhausted, "histerese: não se recupera instantaneamente")
	for i in 60 * 5:
		d.update(Stamina.Effort.REST, 0.0, 1.0 / 60.0)
	check(not d.exhausted, "descansando: volta a poder usar turbo")


func _sim(cfg: BikeConfig, secs: float, pedal: bool, boost_hold: bool, brake: bool, start: float) -> float:
	var s := start
	var boost := 0.0
	var brake_l := 0.0
	var dt := 1.0 / 60.0
	for i in int(secs * 60.0):
		if boost_hold:
			boost = move_toward(boost, 1.0, dt / cfg.boost_ramp_time)
		if brake:
			brake_l = move_toward(brake_l, 1.0, dt / cfg.brake_ramp_time)
		var a := BikePhysics.longitudinal_accel(cfg, s, pedal or boost_hold, boost, brake_l, 1.0, 0.0)
		s = BikePhysics.step_speed(cfg, s, a, dt)
	return s


func _test_physics() -> void:
	var cfg := BikeConfig.new()
	var kmh := BikePhysics.KMH
	var cruise := _sim(cfg, 12.0, true, false, false, 0.0) * kmh
	check(absf(cruise - cfg.cruise_speed_kmh) < 1.0, "pedalando: chega ao ritmo de %.1f km/h" % cruise)
	var early := _sim(cfg, 1.0, true, false, false, 0.0) * kmh
	check(early > 5.0 and early < cruise - 5.0, "aceleração progressiva (1 s → %.1f km/h)" % early)
	var boosted := _sim(cfg, 15.0, false, true, false, 0.0) * kmh
	check(boosted >= 38.0 and boosted <= cfg.max_speed_kmh + 0.01, "S: sobe gradualmente até %.1f km/h (≤ 40)" % boosted)
	var boost_2s := _sim(cfg, 2.0, false, true, false, cfg.cruise_speed_kmh / kmh) * kmh
	check(boost_2s < boosted - 4.0, "turbo é gradual, não instantâneo (2 s → %.1f km/h)" % boost_2s)
	var braked := _sim(cfg, 2.0, false, false, true, 30.0 / kmh)
	check(braked == 0.0, "freio: para de 30 km/h em menos de 2 s")
	var coast := _sim(cfg, 3.0, false, false, false, 25.0 / kmh) * kmh
	check(coast < 25.0 and coast > 18.0, "inércia: sem pedalar perde velocidade aos poucos (%.1f km/h)" % coast)
	var climb := BikePhysics.longitudinal_accel(cfg, 6.0, true, 0.0, 0.0, 1.0, sin(deg_to_rad(8.0)))
	check(climb < 0.0, "subida: a gravidade reduz a velocidade")
	check(BikePhysics.target_speed(cfg, 1.0, 1.0) * kmh <= cfg.max_speed_kmh + 0.001, "velocidade-alvo nunca passa de 40 km/h")

	var max_lean := 0.0
	for spd: float in [2.0, 5.0, 8.0, 11.1]:
		for inp: float in [-1.0, 1.0]:
			var yaw := BikePhysics.yaw_rate_demand(cfg, spd, inp)
			max_lean = maxf(max_lean, absf(BikePhysics.lean_angle(cfg, spd, yaw)))
	check(max_lean <= deg_to_rad(30.0) + 0.0001, "inclinação máxima ≤ 30° (%.1f°)" % rad_to_deg(max_lean))
	check(BikePhysics.yaw_rate_demand(cfg, 6.0, 1.0) > 0.0, "esquerda gira para a esquerda (yaw +)")

	var v := 11.1
	var lat := absf(BikePhysics.yaw_rate_demand(cfg, v, 1.0)) * v
	check(lat <= BikePhysics.grip_limit(cfg, 1.0), "asfalto seco: curva fechada a 40 km/h não derrapa")
	var lat_wet := absf(BikePhysics.yaw_rate_demand(cfg, 8.0, 1.0)) * 8.0
	check(lat_wet > BikePhysics.grip_limit(cfg, 0.45), "asfalto molhado: curva fechada rápida derrapa")


func _test_ik() -> void:
	var hip := Vector3(0.1, RiderVisual.HIP_Y, RiderVisual.HIP_Z)
	var ok := true
	var forward_knees := true
	for i in 16:
		var ang := i * TAU / 16.0
		var foot := RiderVisual.BB + Vector3(0.14, RiderVisual.CRANK_LEN * sin(ang), -RiderVisual.CRANK_LEN * cos(ang))
		var knee := RiderVisual.solve_knee(hip, foot, RiderVisual.THIGH, RiderVisual.SHIN)
		if absf(knee.distance_to(hip) - RiderVisual.THIGH) > 0.001 or absf(knee.distance_to(foot) - RiderVisual.SHIN) > 0.01:
			ok = false
		if knee.z > hip.z:
			forward_knees = false
	check(ok, "IK das pernas: comprimentos de coxa e canela preservados na volta do pedal")
	check(forward_knees, "IK das pernas: joelhos apontam para frente")


# --------------------------------------------------------------- integração

func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _release_all() -> void:
	for a: String in ["pedalar", "acelerar", "frear", "esquerda", "direita"]:
		Input.action_release(a)


func _place(p: BikeController, pos: Vector3, yaw: float, spd: float) -> void:
	p.global_position = pos
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.speed = spd


func _wall(main: Node, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	main.add_child(body)


func _test_integration() -> void:
	var main: Node = load("res://scenes/test_track.tscn").instantiate()
	root.add_child(main)
	await _frames(15)
	var p: BikeController = main.get("player")
	check(p != null and p.is_on_floor(), "cena principal carrega com ciclista no chão")

	# Pedalar
	var z0 := p.global_position.z
	Input.action_press("pedalar")
	await _frames(180)
	check(p.speed_kmh() > 15.0, "Cima/W: começa a andar (3 s → %.1f km/h)" % p.speed_kmh())
	check(p.global_position.z < z0 - 10.0, "move-se para frente na avenida")
	check(p.stamina.value < 100.0, "pedalar consome energia")

	# Curva
	var yaw0 := p.rotation.y
	Input.action_press("esquerda")
	await _frames(40)
	check(p.rotation.y > yaw0 + 0.2, "Esquerda/A: vira para a esquerda")
	check(p.lean > 0.05 and p.lean <= deg_to_rad(30.0) + 0.001, "inclina na curva (%.1f°)" % rad_to_deg(p.lean))
	Input.action_release("esquerda")

	# Turbo
	_place(p, Vector3(0, 0.05, 25), 0.0, 24.0 / 3.6)
	Input.action_press("acelerar")
	await _frames(60 * 8)
	check(p.speed_kmh() > 34.0 and p.speed_kmh() <= 40.5, "S: acelera gradualmente (%.1f km/h)" % p.speed_kmh())
	Input.action_release("acelerar")

	# Freio
	Input.action_press("frear")
	await _frames(150)
	check(p.speed < 0.1, "Baixo: freia até parar")
	_release_all()

	# Colisão forte → queda
	_wall(main, Vector3(0, 1.5, -168), Vector3(10, 3, 1))
	_place(p, Vector3(0, 0.3, -160), 0.0, 8.0)
	Input.action_press("pedalar")
	await _frames(90)
	check(p.state == BikeController.State.CRASHED, "colisão forte derruba o ciclista")
	check(p.hearts == 2, "queda tira um coração")
	Input.action_release("pedalar")
	await _frames(int(p.config.recovery_time * 60.0) + 10)
	check(p.state == BikeController.State.RIDING, "recupera após %.1f s" % p.config.recovery_time)
	check(p.global_position.z > -167.0, "afastado da parede após levantar")

	# Batida leve não derruba
	_place(p, Vector3(0, 0.3, -165), 0.0, 1.5)
	await _frames(70)
	Input.action_press("pedalar")
	await _frames(40)
	Input.action_release("pedalar")
	check(p.state == BikeController.State.RIDING, "encostar devagar na parede não derruba")

	# Perda de controle no asfalto molhado
	_place(p, Vector3(-5, 0.3, -96), 0.0, 9.0)
	await _frames(3)
	check(p.surface_name == "asfalto molhado", "detecta piso molhado")
	Input.action_press("pedalar")
	Input.action_press("esquerda")
	await _frames(60)
	_release_all()
	check(p.hearts == 1 and p.last_crash_reason.contains("controle"), "curva fechada rápida no molhado causa queda")

	# Terceira queda → perde a corrida
	var lost := [false]
	p.out_of_hearts.connect(func() -> void: lost[0] = true)
	await _frames(int(p.config.recovery_time * 60.0) + 70)
	_place(p, Vector3(0, 0.3, -160), 0.0, 9.0)
	Input.action_press("pedalar")
	await _frames(90)
	_release_all()
	check(p.state == BikeController.State.OUT and lost[0], "três quedas: perde a corrida")
	var hud: Node = main.get("hud")
	check(String(hud.get("message")).contains("PERDEU"), "HUD mostra mensagem de derrota")

	# Câmera não atravessa paredes
	main.queue_free()
	await _frames(2)
	main = load("res://scenes/test_track.tscn").instantiate()
	root.add_child(main)
	p = main.get("player")
	await _frames(3)
	_wall(main, Vector3(0, 2, -157.5), Vector3(10, 4, 0.5))
	_place(p, Vector3(0, 0.3, -160), 0.0, 0.0)
	var rig: Node3D = main.get("camera_rig")
	rig.global_position = p.global_position + Vector3.UP
	await _frames(60)
	var arm: SpringArm3D = rig.get("arm")
	var cam: Camera3D = rig.get("camera")
	check(arm.get_hit_length() < arm.spring_length - 1.0, "câmera encurta o braço com parede atrás")
	check(cam.global_position.z < -157.7, "câmera fica do lado de dentro da parede")

	# Câmera mostra o ciclista inteiro (rodas e cabeça dentro da tela)
	_place(p, Vector3(0, 0.3, -140), 0.0, 0.0)
	rig.global_position = p.global_position + Vector3.UP
	await _frames(90)
	var pts := [p.global_position + Vector3(0, 0.0, 0.8), p.global_position + Vector3(0, 0.0, -0.8),
			p.global_position + Vector3(0, 1.65, 0)]
	var vp_size := Vector2(1920, 1080)
	var all_in := true
	for pt: Vector3 in pts:
		if cam.is_position_behind(pt):
			all_in = false
			continue
		var sp := cam.unproject_position(pt)
		var vr := cam.get_viewport().get_visible_rect().size
		if vr.x > 2.0:
			vp_size = vr
		if sp.x < 0 or sp.y < 0 or sp.x > vp_size.x or sp.y > vp_size.y:
			all_in = false
	check(all_in, "câmera enquadra o garoto e a bicicleta inteiros")
	main.queue_free()
	await _frames(2)


# ------------------------------------------------------- bairro e corrida

func _test_circuit() -> void:
	var c := Circuit.new()
	check(c.length > 1400.0 and c.length < 1600.0, "circuito com ~1,5 km (%.0f m)" % c.length)
	var gates := c.build_gates()
	check(gates.size() == Circuit.CHECKPOINT_COUNT + 1 and gates[-1]["finish"], "12 checkpoints + chegada")
	var ordered := true
	for i in range(1, gates.size() - 1):
		if gates[i]["distance"] <= gates[i - 1]["distance"]:
			ordered = false
	check(ordered, "checkpoints em ordem ao longo do percurso")
	var on_route := true
	for g in gates:
		if c.project(g["pos"])["lateral"] > 0.01:
			on_route = false
	check(on_route, "checkpoints sobre a rota")
	var p := c.project(Vector3(3, 0, -100))
	check(absf(p["distance"] - 100.0) < 0.01 and absf(p["lateral"] - 3.0) < 0.01, "projeção na rota (progresso e desvio)")
	check(RaceManager.format_time(83.456) == "1:23.46", "formato do cronômetro")


func _cross(p: BikeController, gate: Dictionary) -> void:
	var pos: Vector3 = gate["pos"]
	var dir: Vector3 = gate["dir"]
	_place(p, pos - dir * 2.0, atan2(-dir.x, -dir.z), 0.0)
	await _frames(3)
	_place(p, pos + dir * 2.0, atan2(-dir.x, -dir.z), 0.0)
	await _frames(3)


func _test_neighborhood_race() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)
	var p: BikeController = main.get("player")
	var race: RaceManager = main.get("race")
	var world: Node = main.get("world")
	race.save_records = false
	check(p.is_on_floor(), "ciclista no chão na largada do bairro")
	var load_ms: int = main.get("load_time_ms")
	check(load_ms < 10000, "bairro monta em menos de 10 s (%d ms)" % load_ms)

	var tops: Array[float] = world.get("house_tops")
	check(tops.size() >= 200, "bairro expandido: %d casas" % tops.size())
	check(tops.max() <= 8.0, "casas baixas: a mais alta tem %.1f m" % tops.max())
	var meshes: int = world.get("mesh_instance_count")
	check(meshes < 200, "cenário agrupado em poucas malhas (%d)" % meshes)
	var bars: Array[Vector3] = world.get("barricades")
	check(bars.size() > 10, "barreiras fecham ruas fora da rota (%d)" % bars.size())

	# Rota livre de obstáculos (faixa central ±2,5 m).
	var space := p.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.exclude = [p.get_rid()]
	var blocked := 0
	var d := 0.0
	while d < race.circuit.length:
		var s := race.circuit.sample(d)
		var right: Vector3 = (s["dir"] as Vector3).cross(Vector3.UP)
		for off: float in [-2.5, 0.0, 2.5]:
			q.transform = Transform3D(Basis.IDENTITY, (s["pos"] as Vector3) + right * off + Vector3(0, 0.8, 0))
			if space.intersect_shape(q, 1).size() > 0:
				blocked += 1
		d += 5.0
	check(blocked == 0, "rota do circuito livre de obstáculos (%d bloqueios)" % blocked)
	var side_hit := 0
	for b in bars:
		q.transform = Transform3D(Basis.IDENTITY, b + Vector3(0, 0.8, 0))
		if space.intersect_shape(q, 1).size() > 0:
			side_hit += 1
	check(side_hit == bars.size(), "barreiras têm colisão")

	# Contagem regressiva bloqueia a largada.
	check(race.phase == RaceManager.Phase.COUNTDOWN, "corrida começa em contagem regressiva")
	Input.action_press("pedalar")
	await _frames(60)
	check(p.speed < 0.1, "não anda durante a contagem")
	await _frames(int(RaceManager.COUNTDOWN_TIME * 60.0))
	check(race.phase == RaceManager.Phase.RACING, "largada após 3 s")
	await _frames(60)
	check(p.speed_kmh() > 5.0 and race.race_time > 0.5, "pedala e o cronômetro corre")
	Input.action_release("pedalar")

	# Pular checkpoint não conta.
	await _cross(p, race.gates[1])
	check(race.next_gate == 0, "atalho: pular o checkpoint 1 não conta")
	await _cross(p, race.gates[0])
	check(race.next_gate == 1, "checkpoint 1 registrado")
	await _cross(p, race.gates[race.gates.size() - 1])
	check(race.phase == RaceManager.Phase.RACING, "cruzar a chegada sem os checkpoints não termina a corrida")
	for i in range(1, race.gates.size() - 1):
		await _cross(p, race.gates[i])
	check(race.next_gate == race.gates.size() - 1, "todos os checkpoints em ordem")
	await _cross(p, race.gates[race.gates.size() - 1])
	check(race.phase == RaceManager.Phase.FINISHED and race.race_time > 0.0, "chegada encerra a corrida")
	var hud: Node = main.get("hud")
	var lines: PackedStringArray = hud.get("result_lines")
	check(lines.size() > 0 and lines[0] == "CHEGADA!", "HUD mostra resultado")
	check(not p.controls_enabled, "controles travados após a chegada")
	main.queue_free()
	await _frames(2)

	await _test_full_lap()

	# Três quedas = derrota na corrida.
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	p = main.get("player")
	race = main.get("race")
	race.save_records = false
	await _frames(int(RaceManager.COUNTDOWN_TIME * 60.0) + 5)
	for k in 3:
		p.call("_crash", "teste", Vector3.ZERO)
		await _frames(2)
	check(race.phase == RaceManager.Phase.LOST, "três quedas: corrida perdida")
	main.queue_free()
	await _frames(2)


## Piloto automático simples percorre a volta inteira pedalando (física real).
func _test_full_lap() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	var p: BikeController = main.get("player")
	var race: RaceManager = main.get("race")
	race.save_records = false
	p.use_player_input = false
	var c := race.circuit
	var max_frames := 60 * 60 * 6
	var f := 0
	while f < max_frames and race.phase != RaceManager.Phase.FINISHED and race.phase != RaceManager.Phase.LOST:
		var proj := c.project(p.global_position)
		var target: Vector3 = c.sample(proj["distance"] + 7.0)["pos"]
		var to := target - p.global_position
		to.y = 0.0
		var fwd := p.forward()
		var ang := atan2(fwd.cross(to).y, fwd.dot(to))
		p.in_steer = clampf(ang * 2.5, -1.0, 1.0)
		var to_corner := INF
		for i in c.points.size() + 1:
			var cd: float = c.cumulative[i] - float(proj["distance"])
			if cd > 0.0:
				to_corner = minf(to_corner, cd)
		var slow := to_corner < 14.0 and p.speed > 4.5
		p.in_brake = slow
		p.in_pedal = not slow
		await physics_frame
		f += 1
	check(race.phase == RaceManager.Phase.FINISHED, "volta completa pedalando pelo circuito (%s)" % RaceManager.format_time(race.race_time))
	check(race.race_time > 150.0 and race.race_time < 330.0, "duração da corrida dentro de 3–5 min (ritmo normal, sem turbo)")
	check(p.hearts == p.config.max_hearts, "piloto cuidadoso completa sem quedas")
	main.queue_free()
	await _frames(2)
