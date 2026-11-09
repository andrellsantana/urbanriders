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

var lane: float = 0.0
var desired_lane: float = 0.0
var boosting: bool = false
var _rng := RandomNumberGenerator.new()
var _erratic_timer: float = 3.0
var _hesitate_timer: float = 0.0
var _bump_cooldown: float = 0.0
var _stuck_timer: float = 0.0
var _avoid_timer: float = 0.0


func setup(b: BikeController, c: Circuit, p: AIPersonality, all_riders: Array[BikeController],
		puddles: Array[Vector3], seed_value: int) -> void:
	bike = b
	circuit = c
	personality = p
	hazards = puddles
	for r in all_riders:
		if r != bike:
			rivals.append(r)
	_rng.seed = seed_value
	lane = c.signed_lateral(b.global_position)
	desired_lane = p.base_lane


func _physics_process(dt: float) -> void:
	if bike == null or bike.state != BikeController.State.RIDING:
		_stuck_timer = 0.0
		return
	_bump_cooldown = maxf(0.0, _bump_cooldown - dt)
	var proj := circuit.project(bike.global_position)
	var dist: float = proj["distance"]
	var route_dir: Vector3 = proj["dir"]
	var my_lat := circuit.signed_lateral(bike.global_position)

	if finished:
		desired_lane = 2.2
	else:
		_decide_lane(dt, route_dir, my_lat)
	lane = move_toward(lane, desired_lane, personality.lane_change_speed * dt)

	# Direção: mira um ponto à frente na faixa escolhida.
	var look := 5.0 + bike.speed * 0.45
	var s := circuit.sample(dist + look)
	var right: Vector3 = (s["dir"] as Vector3).cross(Vector3.UP)
	var target: Vector3 = (s["pos"] as Vector3) + right * lane
	var to := target - bike.global_position
	to.y = 0.0
	var fwd := bike.forward()
	var ang := atan2(fwd.cross(to).y, fwd.dot(to))
	bike.in_steer = clampf(ang * personality.steer_gain, -1.0, 1.0)

	# Velocidade: planeja a frenagem para a próxima esquina.
	var to_corner := circuit.distance_to_next_corner(dist)
	var corner_kmh := personality.corner_speed_kmh
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
	_hesitate_timer = maxf(0.0, _hesitate_timer - dt)
	var hesitate := _hesitate_timer > 0.0
	if finished:
		braking = braking or bike.speed > 5.0
	bike.in_brake = braking
	bike.in_pedal = not braking and not hesitate
	bike.in_boost = not braking and not hesitate and not finished and _want_boost(to_corner, dist)

	_check_stuck(dt, proj)


func _want_boost(to_corner: float, dist: float) -> bool:
	var energy := bike.stamina.value
	var remaining := _remaining_distance(dist)
	if remaining < personality.final_sprint_distance and energy > 3.0 and to_corner > 18.0:
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
			if _rng.randf() < 0.18:
				_hesitate_timer = _rng.randf_range(0.4, 1.0)
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
	desired_lane = clampf(desired_lane, -MAX_LANE, MAX_LANE)


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
		var s := circuit.sample(float(proj["distance"]) - 2.0)
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
