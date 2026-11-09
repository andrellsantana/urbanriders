extends Node
## Piloto da IA: lê a pista e os rivais e aciona os MESMOS comandos de um jogador
## (pedalar, acelerar, frear, virar) — a física é idêntica à do Andrew-Mike.

const Circuit := preload("res://scripts/race/circuit.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const AIPersonality := preload("res://scripts/ai/ai_personality.gd")

const MAX_LANE := 2.4 ## fora disso há carros estacionados e postes
const KMH := 3.6

var bike: BikeController
var circuit: Circuit
var personality: AIPersonality
var rivals: Array[BikeController] = []
var hazards: Array[Vector3] = [] ## poças conhecidas
var finished: bool = false
var respawn_count: int = 0
var tag: Label3D ## nome sobre a cabeça (mostra estado e provocações)
var features: Node ## CourseFeatures (aceleradores, rampas, obstáculos fixos)
var hazard_manager: Node ## Hazards (carros, pedestres, cão)
var hazard_brakes: int = 0
var race: Node ## RaceManager (para saber a distância até o líder)
var catching_up: bool = false
var _form: float = 0.0
var _hazard_brake_time: float = 0.0
var _ignore_hazards: float = 0.0
var _evading: float = 0.0 ## desviando: troca de faixa mais rápida
var _attractor_choice: Dictionary = {}
var player_bike: BikeController
var resting: bool = false ## soltou o pedal para recuperar energia
var rest_time: float = 0.0
var bumps_attempted: int = 0
var blocks: int = 0
var wait_time: float = 0.0
const MAX_WAIT := 20.0 ## tempo máximo esperando o jogador por corrida
var taunt: String = ""

var lane: float = 0.0
var desired_lane: float = 0.0
var boosting: bool = false
var _rng := RandomNumberGenerator.new()
var _erratic_timer: float = 3.0
var _hesitate_timer: float = 0.0
var _bump_cooldown: float = 0.0
var _stuck_timer: float = 0.0
var _avoid_timer: float = 0.0
var _corner_kmh: float = 0.0
var _taunt_timer: float = 0.0
var _was_ahead_of_player: bool = false
var _revenge_timer: float = 0.0
var _elapsed: float = 0.0


func setup(b: BikeController, c: Circuit, p: AIPersonality, all_riders: Array[BikeController],
		puddles: Array[Vector3], seed_value: int) -> void:
	bike = b
	circuit = c
	personality = p
	hazards = puddles
	for r in all_riders:
		if r != bike:
			rivals.append(r)
	player_bike = all_riders[0]
	_rng.seed = seed_value
	lane = c.signed_lateral(b.global_position)
	desired_lane = p.base_lane
	_corner_kmh = p.corner_speed_kmh + _rng.randf_range(-p.pace_variation, p.pace_variation)
	_form = _rng.randf_range(-p.form_variation, p.form_variation)
	b.stamina.drain_boost = 9.0 * p.boost_efficiency
	b.ramp_bonus = p.ramp_bonus
	b.config.max_speed_kmh = p.top_speed_kmh


func _physics_process(dt: float) -> void:
	if bike == null or bike.state != BikeController.State.RIDING:
		_stuck_timer = 0.0
		return
	_bump_cooldown = maxf(0.0, _bump_cooldown - dt)
	if bike.controls_enabled:
		_elapsed += dt
	var proj := circuit.project(bike.global_position)
	var dist: float = proj["distance"]
	var route_dir: Vector3 = proj["dir"]
	var my_lat := circuit.signed_lateral(bike.global_position)

	var to_corner := circuit.distance_to_next_corner(dist)
	var gap_player := _gap_to_player(dist)
	if finished:
		desired_lane = 2.2
	else:
		_decide_lane(dt, route_dir, my_lat)
		_hunt_player(dt, gap_player, my_lat)
		# Russ corta a esquina por dentro (passando pela calçada).
		if personality.cuts_corners and to_corner < 13.0:
			desired_lane = circuit.next_turn_sign(dist) * 4.3
		_seek_attractors(dist)
	var max_lane := 4.5 if personality.cuts_corners and to_corner < 16.0 else MAX_LANE
	desired_lane = clampf(desired_lane, -max_lane, max_lane)
	var hazard_brake := _avoid_hazards(route_dir, my_lat)
	_evading = maxf(0.0, _evading - dt)
	var lane_speed := maxf(personality.lane_change_speed, 4.0) if _evading > 0.0 else personality.lane_change_speed
	lane = move_toward(lane, desired_lane, lane_speed * dt)

	# Direção: mira um ponto à frente na faixa escolhida (mais perto ao desviar).
	var look := (4.0 + bike.speed * 0.3) if _evading > 0.0 else (5.0 + bike.speed * 0.45)
	var s := circuit.sample(dist + look)
	var right: Vector3 = (s["dir"] as Vector3).cross(Vector3.UP)
	var target: Vector3 = (s["pos"] as Vector3) + right * lane
	var to := target - bike.global_position
	to.y = 0.0
	var fwd := bike.forward()
	var ang := atan2(fwd.cross(to).y, fwd.dot(to))
	bike.in_steer = clampf(ang * personality.steer_gain, -1.0, 1.0)

	# Velocidade: planeja a frenagem para a próxima esquina.
	var corner_kmh := _corner_kmh
	if personality.knows_puddles and _puddle_near(dist + to_corner, 22.0):
		corner_kmh = personality.wet_corner_speed_kmh
	var vc := corner_kmh / KMH
	var v := bike.speed
	var brake_dist := (v * v - vc * vc) / (2.0 * personality.brake_decel_estimate) + personality.brake_margin
	var braking := v > vc and to_corner < brake_dist
	# Não atropela quem está logo à frente na mesma faixa.
	var ahead := _closest_ahead(route_dir, my_lat, 1.0)
	if ahead != null and not (personality.aggressive and _bump_cooldown <= 0.0):
		var gap := (ahead.global_position - bike.global_position).dot(route_dir)
		if gap < 2.6 and bike.speed > ahead.speed:
			braking = true
	_ignore_hazards = maxf(0.0, _ignore_hazards - dt)
	if hazard_brake and _ignore_hazards <= 0.0:
		_hazard_brake_time += dt
		if _hazard_brake_time > 2.0:
			_ignore_hazards = 1.5 # impasse: segue e contorna
			_hazard_brake_time = 0.0
		braking = true
		hazard_brakes += 1
	else:
		_hazard_brake_time = 0.0
	_hesitate_timer = maxf(0.0, _hesitate_timer - dt)
	var hesitate := _hesitate_timer > 0.0
	if finished:
		braking = braking or bike.speed > 5.0
	# Recuperação: solta o pedal (visivelmente) até a energia voltar.
	var remaining := _remaining_distance(dist)
	var energy := bike.stamina.value
	var dead_zone := personality.pulse_strategy and not boosting and energy < personality.boost_stamina_min \
			and to_corner > 25.0
	if not resting and (energy < personality.rest_below or dead_zone) and remaining > 150.0:
		resting = true
	elif resting and (energy >= personality.rest_until or remaining <= 150.0):
		resting = false
	if resting and not finished:
		rest_time += dt
	var coasting := hesitate or (resting and not finished)
	bike.in_brake = braking
	bike.in_pedal = not braking and not coasting
	var hunting := personality.hunts_player and player_bike.collision_layer != 0 and not finished
	var chase := hunting and gap_player > 0.0 and gap_player < 15.0 and energy > 55.0 and to_corner > 15.0
	# Espera o jogador chegar para fechar a frente dele (sem turbo, ritmo normal).
	var waiting := hunting and gap_player < -3.0 and gap_player > -45.0 and wait_time < MAX_WAIT
	if waiting:
		wait_time += dt
	bike.in_boost = not braking and not coasting and not finished and not waiting \
			and (_want_boost(to_corner, dist) or chase)


	_check_stuck(dt, proj)
	_update_tag(dt)
	if Engine.get_physics_frames() % 15 == 0:
		_update_catch_up()


## Mira aceleradores e rampas à frente (conforme a personalidade).
func _seek_attractors(dist: float) -> void:
	if features == null:
		return
	var best_gap := INF
	var best_lat := 0.0
	for a: Dictionary in features.get("attractors"):
		var gap := fposmod(float(a["distance"]) - dist, circuit.length)
		if gap < 2.0 or gap > 35.0 or gap >= best_gap:
			continue
		var key: int = int(a["distance"])
		if not _attractor_choice.has(key):
			var chance := personality.pad_chance if a["kind"] == "pad" else personality.ramp_chance
			_attractor_choice[key] = _rng.randf() < chance
		if _attractor_choice[key]:
			best_gap = gap
			best_lat = a["lateral"]
	if best_gap < INF:
		desired_lane = best_lat
		_avoid_timer = 0.4


## Desvia de obstáculos fixos e móveis (prevê a posição de quem se move). Devolve true se precisa frear.
func _avoid_hazards(route_dir: Vector3, my_lat: float) -> bool:
	var obs: Array[Dictionary] = []
	if features != null:
		for o: Dictionary in features.get("obstacles"):
			obs.append({"pos": o["pos"], "vel": Vector3.ZERO, "radius": o["radius"]})
	if hazard_manager != null:
		obs.append_array(hazard_manager.call("obstacles_for_ai"))
	if obs.is_empty():
		return false
	var window := 8.0 + bike.speed * 2.0
	var blocked: Array[Vector2] = []
	var nearest := INF
	for o in obs:
		var rel: Vector3 = (o["pos"] as Vector3) - bike.global_position
		var ahead := rel.dot(route_dir)
		if ahead < -1.5 or ahead > window:
			continue
		var t := clampf(maxf(ahead, 0.0) / maxf(bike.speed, 1.0), 0.0, 2.5)
		var pred: Vector3 = (o["pos"] as Vector3) + (o["vel"] as Vector3) * t
		var lat := circuit.signed_lateral(pred)
		if absf(lat) > 5.5:
			continue
		blocked.append(Vector2(lat, float(o["radius"]) + 0.75))
		if absf(lat - my_lat) < float(o["radius"]) + 0.75:
			nearest = minf(nearest, ahead)
	if blocked.is_empty():
		return false
	if not _lane_blocked(desired_lane, blocked) and not _lane_blocked(my_lat, blocked):
		return false
	var best := INF
	var best_cost := INF
	var c := -MAX_LANE
	while c <= MAX_LANE + 0.001:
		if not _lane_blocked(c, blocked):
			var cost := absf(c - desired_lane) + 0.5 * absf(c - my_lat)
			if cost < best_cost:
				best_cost = cost
				best = c
		c += 0.3
	if best < INF:
		desired_lane = best
		_avoid_timer = 0.6
		_evading = 0.8
		return nearest < 1.5 + bike.speed * 0.35 and _lane_blocked(my_lat, blocked)
	return nearest < 3.0 + bike.speed * 0.9


static func _lane_blocked(lat: float, blocked: Array[Vector2]) -> bool:
	for b in blocked:
		if absf(lat - b.x) < b.y:
			return true
	return false


## Distância percorrida na corrida (após a largada).
func _race_distance(r: BikeController) -> float:
	return fposmod(float(circuit.project(r.global_position)["distance"]) - Circuit.START_DISTANCE, circuit.length)


## Mais de ~3 s atrás do líder: arrisca mais no turbo para recuperar.
func _update_catch_up() -> void:
	catching_up = false
	if _elapsed < 20.0:
		return
	var mine := _race_distance(bike)
	var lead := mine
	for r in rivals:
		if r.collision_layer != 0:
			lead = maxf(lead, _race_distance(r))
	catching_up = lead - mine > bike.speed * 3.0 + 5.0


func _want_boost(to_corner: float, dist: float) -> bool:
	var energy := bike.stamina.value + _form + (10.0 if catching_up else 0.0)
	var remaining := _remaining_distance(dist)
	# Sprint final só quando a energia dá para chegar acelerando.
	var reach := maxf(0.0, energy - 12.0) / bike.stamina.drain_boost * 11.1 * 1.3
	if remaining < minf(personality.final_sprint_distance, reach) and energy > 15.0 and to_corner > 18.0:
		boosting = true
		return true
	if boosting:
		boosting = energy > personality.boost_stamina_stop and to_corner > 18.0
	else:
		boosting = energy > personality.boost_stamina_min and to_corner > personality.boost_min_straight
	if personality.aggressive and not boosting and energy > 30.0 and to_corner > 25.0:
		for r in rivals:
			if r.global_position.distance_to(bike.global_position) < 6.0:
				return true
	return boosting


func _remaining_distance(dist: float) -> float:
	# No início os ciclistas estão antes da linha: falta a volta inteira.
	if _elapsed < 20.0:
		return circuit.length
	return fposmod(Circuit.START_DISTANCE - dist, circuit.length)


func _puddle_near(at_distance: float, radius: float) -> bool:
	var p: Vector3 = circuit.sample(at_distance)["pos"]
	for h in hazards:
		if Vector2(h.x - p.x, h.z - p.z).length() < radius:
			return true
	return false


func _closest_ahead(route_dir: Vector3, my_lat: float, lane_tol: float) -> BikeController:
	var best: BikeController = null
	var best_gap := INF
	for r in rivals:
		if r.state != BikeController.State.RIDING and r.state != BikeController.State.CRASHED:
			continue
		if r.collision_layer == 0:
			continue
		var gap := (r.global_position - bike.global_position).dot(route_dir)
		if gap <= 0.0 or gap > personality.overtake_lookahead:
			continue
		var r_lat := circuit.signed_lateral(r.global_position)
		if absf(r_lat - my_lat) > lane_tol:
			continue
		if gap < best_gap:
			best_gap = gap
			best = r
	return best


func _decide_lane(dt: float, route_dir: Vector3, my_lat: float) -> void:
	# Imprevisível: muda de faixa e às vezes hesita, sem aviso.
	if personality.erratic:
		_erratic_timer -= dt
		if _erratic_timer <= 0.0:
			_erratic_timer = _rng.randf_range(personality.erratic_interval.x, personality.erratic_interval.y)
			desired_lane = _rng.randf_range(-MAX_LANE, MAX_LANE)
			if _rng.randf() < personality.hesitation_chance:
				_hesitate_timer = _rng.randf_range(0.3, 0.6)
	_avoid_timer = maxf(0.0, _avoid_timer - dt)

	for r in rivals:
		if r.collision_layer == 0:
			continue
		var rel := r.global_position - bike.global_position
		var along := rel.dot(route_dir)
		var r_lat := circuit.signed_lateral(r.global_position)
		var dlat := r_lat - my_lat
		# Trapaceiro: fecha quem vem atrás e joga a bike em cima de quem está do lado.
		if personality.aggressive:
			if along < -1.0 and along > -10.0 and absf(dlat) < 2.5:
				desired_lane = r_lat
				_avoid_timer = 0.8
				continue
			if absf(along) < 1.6 and absf(dlat) < 2.2 and _bump_cooldown <= 0.0:
				desired_lane = r_lat
				_avoid_timer = 0.6
				if absf(dlat) < 0.9:
					_bump_cooldown = 4.0
				continue
		# Educada: abre espaço para quem está ao lado.
		if personality.polite and absf(along) < 3.0 and absf(dlat) < 1.6:
			desired_lane = my_lat - signf(dlat if dlat != 0.0 else 1.0) * 1.8
			_avoid_timer = 0.8
		# Ultrapassagem: alguém mais lento à frente na mesma faixa → passa pelo lado com mais espaço.
		if along > 0.0 and along < personality.overtake_lookahead and absf(dlat) < 1.3 and bike.speed >= r.speed - 0.2:
			var side := -1.0 if r_lat > 0.0 else 1.0
			desired_lane = r_lat + side * 1.9
			_avoid_timer = 1.2
	if _avoid_timer <= 0.0 and not personality.erratic:
		desired_lane = move_toward(desired_lane, personality.base_lane, dt * 0.5)


## Distância ao longo da pista até o jogador (+ = jogador à frente).
func _gap_to_player(dist: float) -> float:
	if player_bike == null:
		return INF
	var pd: float = circuit.project(player_bike.global_position)["distance"]
	var g := pd - dist
	var half := circuit.length * 0.5
	if g > half:
		g -= circuit.length
	elif g < -half:
		g += circuit.length
	return g


## Trapaceiro: persegue o jogador, fecha a frente dele e devolve ultrapassagens com encostão.
func _hunt_player(dt: float, gap: float, my_lat: float) -> void:
	if not personality.hunts_player or player_bike == null or player_bike.collision_layer == 0:
		return
	_revenge_timer = maxf(0.0, _revenge_timer - dt)
	var ahead_now := gap < 0.0
	if _was_ahead_of_player and not ahead_now and absf(gap) < 6.0:
		_revenge_timer = 5.0
		_say("Volta aqui!")
	_was_ahead_of_player = ahead_now
	var p_lat := circuit.signed_lateral(player_bike.global_position)
	if gap < -1.0 and gap > -14.0:
		desired_lane = p_lat # fecha a frente do jogador
		_avoid_timer = 0.6
		if absf(p_lat - my_lat) < 1.0 and _taunt_timer <= 0.0:
			blocks += 1
			_say("Sai da frente!")
	elif gap > -2.0 and gap < 25.0:
		desired_lane = p_lat # vai para cima
		_avoid_timer = 0.6
		if absf(gap) < 1.8 and absf(p_lat - my_lat) < 1.3 and _bump_cooldown <= 0.0:
			_bump_cooldown = 3.0 if _revenge_timer > 0.0 else 4.5
			bumps_attempted += 1
			_say("Toma!" if _revenge_timer > 0.0 else "Abre!")


func _say(text: String) -> void:
	taunt = text
	_taunt_timer = 2.0


func _update_tag(dt: float) -> void:
	_taunt_timer = maxf(0.0, _taunt_timer - dt)
	if tag == null:
		return
	var nm: String = bike.name
	var line := nm
	if _taunt_timer > 0.0:
		line = "%s: %s" % [nm, taunt]
	elif bike.stamina.exhausted:
		line = "%s · %s" % [nm, "cansada" if personality.feminine else "cansado"]
	elif resting:
		line = "%s · recuperando" % nm
	tag.text = line


## Sem bloqueios permanentes: se ficar parado ou sair da pista, volta à rota.
func _check_stuck(dt: float, proj: Dictionary) -> void:
	if not bike.controls_enabled:
		_stuck_timer = 0.0
		return
	if bike.speed < 0.8:
		_stuck_timer += dt
	else:
		_stuck_timer = 0.0
	if _stuck_timer > 3.0 or float(proj["lateral"]) > 9.0:
		_stuck_timer = 0.0
		respawn_count += 1
		var s := circuit.sample(float(proj["distance"]) + 6.0)
		var right: Vector3 = (s["dir"] as Vector3).cross(Vector3.UP)
		var free_lane := 0.0
		for candidate: float in [0.0, 1.8, -1.8]:
			var ok := true
			for r in rivals:
				if r.global_position.distance_to((s["pos"] as Vector3) + right * candidate) < 1.5:
					ok = false
			if ok:
				free_lane = candidate
				break
		bike.teleport((s["pos"] as Vector3) + right * free_lane, s["dir"])
		lane = free_lane
		desired_lane = free_lane
