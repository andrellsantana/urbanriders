extends Node3D
## Perigos móveis do bairro: carros indo e vindo, pedestres atravessando e o cão (a ¾ da corrida).

const Circuit := preload("res://scripts/race/circuit.gd")
const Polyline := preload("res://scripts/world/polyline.gd")
const Props := preload("res://scripts/world/props.gd")
const Synth := preload("res://scripts/audio/synth.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")

const CAR_LANE := 3.9 ## faixa dos carros (m da linha central); ciclistas ficam em ±2,4
const CAR_SPEED := 8.0 ## m/s (~29 km/h)
const PED_SPEED := 1.3
const DOG_FRACTION := 0.75 ## posição do cão no circuito (¾)
const CAR_COLORS: Array[Color] = [Color(0.2, 0.45, 0.5), Color(0.72, 0.66, 0.5), Color(0.45, 0.08, 0.08),
	Color(0.3, 0.32, 0.36), Color(0.5, 0.3, 0.15), Color(0.85, 0.82, 0.75)]

enum DogState { IDLE, DART, CHASE, RETURN }

var circuit: Circuit
var race: Node ## RaceManager (posições)
var riders: Array[BikeController] = []
var parked: Array[Vector3] = []
var swerves: int = 0 ## quantas vezes os carros desviaram (testes)
var cars: Array[Dictionary] = []
var peds: Array[Dictionary] = []
var dog: Node3D
var dog_state: DogState = DogState.IDLE
var dog_home: Vector3
var dog_distance: float = 0.0
var dog_target: BikeController
var dog_triggered: Dictionary = {}
var dog_events: Array[String] = [] ## registro para testes ("dart:Mint", "chase:Russ")
var _dog_timer: float = 0.0
var _dog_goal: Vector3
var _dog_hit: Dictionary = {}
var _dog_bark: AudioStreamPlayer3D
var _bark_timer: float = 0.0
var barks: int = 0
var _idle_bark: float = 0.0
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


func setup(c: Circuit, race_manager: Node, all_riders: Array[BikeController], crossings: Array[Dictionary],
		parked_cars: Array[Vector3] = []) -> void:
	circuit = c
	parked = parked_cars
	race = race_manager
	riders = all_riders
	_rng.randomize()
	var same := Polyline.new(Polyline.offset_loop(circuit.points, CAR_LANE))
	var opp := Polyline.new(Polyline.offset_loop(circuit.points, -CAR_LANE))
	for k in 3:
		_add_car(same, 1.0, same.length * (0.2 + k / 3.0))
		_add_car(opp, -1.0, opp.length * (0.05 + k / 3.0))
	for cr in crossings:
		_add_ped(cr)
	_build_dog()


# ------------------------------------------------------------------- carros

func _add_car(path: Polyline, sign_dir: float, start: float) -> void:
	var body := AnimatableBody3D.new()
	body.collision_layer = BikeController.LAYER_TRAFFIC
	body.collision_mask = 0
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.5, 4.6)
	cs.shape = box
	cs.position = Vector3(0, 0.75, 0)
	body.add_child(cs)
	body.add_child(Props.car(CAR_COLORS[_rng.randi() % CAR_COLORS.size()]))
	var honk := AudioStreamPlayer3D.new()
	honk.stream = Synth.get_sound("honk")
	honk.max_distance = 60.0
	body.add_child(honk)
	add_child(body)
	var car := {"body": body, "path": path, "sign": sign_dir, "d": start, "speed": CAR_SPEED,
		"cruise": CAR_SPEED * _rng.randf_range(0.85, 1.1), "honk": honk, "honk_cd": 0.0, "swerve": 0.0,
		"swerving": false}
	cars.append(car)
	_place_car(car)


func _car_dir(car: Dictionary) -> Vector3:
	var path: Polyline = car["path"]
	return path.smooth_dir(car["d"]) * float(car["sign"])


func _place_car(car: Dictionary) -> void:
	var path: Polyline = car["path"]
	var pos: Vector3 = path.sample(car["d"])["pos"]
	# Desvio de carro estacionado: puxa 2 m para o centro da rua.
	var race_right := path.smooth_dir(car["d"]).cross(Vector3.UP)
	pos -= race_right * float(car["sign"]) * 2.0 * float(car["swerve"])
	var dir := _car_dir(car)
	dir = (dir - race_right * float(car["sign"]) * float(car["swerve_rate"]) * 0.35).normalized() if car.has("swerve_rate") else dir
	var body: AnimatableBody3D = car["body"]
	body.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), pos)


func _update_cars(dt: float) -> void:
	for car in cars:
		var body: AnimatableBody3D = car["body"]
		var f := _car_dir(car)
		var right := f.cross(Vector3.UP)
		var target: float = car["cruise"]
		var blocked := false
		# Desacelera para ciclistas, pedestres e carros à frente na mesma faixa.
		for r in riders:
			var rel := r.global_position - body.global_position
			var ahead := rel.dot(f)
			if ahead > 0.0 and ahead < 11.0 and absf(rel.dot(right)) < 1.8:
				target = minf(target, maxf(0.0, r.velocity.dot(f)) * 0.9)
				blocked = true
		for p in peds:
			var rel2 := (p["node"] as Node3D).global_position - body.global_position
			var ahead2 := rel2.dot(f)
			if ahead2 > 0.0 and ahead2 < 12.0 and absf(rel2.dot(right)) < 2.0:
				target = 0.0
		for other in cars:
			if other == car or other["sign"] != car["sign"]:
				continue
			var rel3 := (other["body"] as Node3D).global_position - body.global_position
			var ahead3 := rel3.dot(f)
			if ahead3 > 0.0 and ahead3 < 10.0 and absf(rel3.dot(right)) < 2.0:
				target = minf(target, float(other["speed"]) * 0.9)
		# Não fica parado para sempre: depois de 2,5 s segue devagar (buzinando).
		car["wait"] = float(car.get("wait", 0.0)) + dt if target < 1.0 else 0.0
		if float(car["wait"]) > 2.5:
			target = maxf(target, 2.5)
		# Carro estacionado à frente na faixa: desvia (e diminui um pouco).
		var need := false
		for pc in parked:
			var relp := pc - body.global_position
			var ap := relp.dot(f)
			if ap > -4.0 and ap < 16.0 and absf(relp.dot(right)) < 1.8:
				need = true
		if need and not car["swerving"]:
			swerves += 1
		car["swerving"] = need
		var old_sw: float = car["swerve"]
		car["swerve"] = move_toward(old_sw, 1.0 if need else 0.0, dt * 0.9)
		car["swerve_rate"] = (float(car["swerve"]) - old_sw) / maxf(dt, 0.001)
		if need:
			target = minf(target, 6.0)
		var spd: float = car["speed"]
		spd = move_toward(spd, target, (6.0 if target < spd else 2.5) * dt)
		car["speed"] = spd
		car["d"] = float(car["d"]) + spd * dt * float(car["sign"])
		car["honk_cd"] = maxf(0.0, float(car["honk_cd"]) - dt)
		if blocked and spd < car["cruise"] * 0.7 and car["honk_cd"] <= 0.0:
			car["honk_cd"] = _rng.randf_range(3.0, 6.0)
			var honk: AudioStreamPlayer3D = car["honk"]
			honk.volume_db = -8.0
			honk.play()
		_place_car(car)


# ---------------------------------------------------------------- pedestres

const PED_LOOKS: Array[Array] = [
	[Color(0.25, 0.4, 0.6), Color(0.3, 0.28, 0.25), Color(0.9, 0.7, 0.55), Color(0.3, 0.2, 0.1)],
	[Color(0.7, 0.25, 0.3), Color(0.2, 0.22, 0.3), Color(0.55, 0.38, 0.25), Color(0.08, 0.06, 0.05)],
	[Color(0.85, 0.8, 0.55), Color(0.35, 0.3, 0.45), Color(0.95, 0.8, 0.7), Color(0.75, 0.6, 0.3)],
	[Color(0.3, 0.5, 0.3), Color(0.15, 0.15, 0.18), Color(0.4, 0.27, 0.18), Color(0.12, 0.1, 0.08)],
]


func _add_ped(crossing: Dictionary) -> void:
	var look: Array = PED_LOOKS[peds.size() % PED_LOOKS.size()]
	var node := Props.person(look[0], look[1], look[2], look[3], _rng.randf_range(0.9, 1.05))
	add_child(node)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var ped := {"node": node, "crossing": crossing, "lat": side * 7.0, "dir": -side, "state": "wait",
		"timer": _rng.randf_range(2.0, 8.0), "anim": 0.0, "distracted": _rng.randf() < 0.35}
	peds.append(ped)
	_place_ped(ped)


func _place_ped(ped: Dictionary) -> void:
	var cr: Dictionary = ped["crossing"]
	var right: Vector3 = cr["right"]
	var node: Node3D = ped["node"]
	node.global_position = (cr["pos"] as Vector3) + right * float(ped["lat"])
	var face := right * float(ped["dir"])
	node.rotation.y = atan2(-face.x, -face.z)


func _rider_approaching(cr: Dictionary, within: float) -> bool:
	for r in riders:
		if r.collision_layer == 0:
			continue
		var d: float = circuit.project(r.global_position)["distance"]
		var gap := fposmod(float(cr["distance"]) - d, circuit.length)
		if gap > 0.0 and gap < within:
			return true
	return false


func _update_peds(dt: float) -> void:
	for ped in peds:
		var node: Node3D = ped["node"]
		match String(ped["state"]):
			"wait":
				ped["timer"] = float(ped["timer"]) - dt
				if ped["timer"] <= 0.0:
					# Educado: espera os ciclistas passarem. Distraído: atravessa mesmo assim.
					if not ped["distracted"] and _rider_approaching(ped["crossing"], 22.0):
						ped["timer"] = 1.0
					else:
						ped["state"] = "walk"
						ped["distracted"] = _rng.randf() < 0.35
			"walk":
				ped["lat"] = float(ped["lat"]) + float(ped["dir"]) * PED_SPEED * dt
				ped["anim"] = float(ped["anim"]) + dt * 7.0
				if absf(float(ped["lat"])) >= 7.0:
					ped["lat"] = signf(float(ped["lat"])) * 7.0
					ped["dir"] = -float(ped["dir"])
					ped["state"] = "wait"
					ped["timer"] = _rng.randf_range(4.0, 10.0)
				_place_ped(ped)
			"stumble":
				ped["timer"] = float(ped["timer"]) - dt
				node.rotation.x = 0.35 * sin(float(ped["timer"]) * 6.0)
				if ped["timer"] <= 0.0:
					node.rotation.x = 0.0
					ped["state"] = "walk"
		var swing := sin(float(ped["anim"])) * 0.5 if ped["state"] == "walk" else 0.0
		(node.get_node("PernaE") as Node3D).rotation.x = swing
		(node.get_node("PernaD") as Node3D).rotation.x = -swing
		# Esbarrão com ciclista.
		if ped["state"] == "walk":
			for r in riders:
				if r.collision_layer == 0 or r.state != BikeController.State.RIDING:
					continue
				var rel := r.global_position - node.global_position
				rel.y = 0.0
				if rel.length() < 0.7 and r.speed > 1.5:
					r.hit_obstacle("Esbarrou num pedestre!")
					ped["state"] = "stumble"
					ped["timer"] = 1.5


# --------------------------------------------------------------------- cão

func _build_dog() -> void:
	dog_distance = circuit.length * DOG_FRACTION
	var s := circuit.sample(dog_distance)
	var right: Vector3 = (s["dir"] as Vector3).cross(Vector3.UP)
	dog_home = (s["pos"] as Vector3) - right * 9.0
	dog = Props.dog()
	add_child(dog)
	dog.global_position = dog_home
	_dog_bark = AudioStreamPlayer3D.new()
	_dog_bark.stream = Synth.get_sound("bark")
	_dog_bark.max_distance = 90.0
	_dog_bark.unit_size = 12.0
	dog.add_child(_dog_bark)


func _bark() -> void:
	_dog_bark.pitch_scale = _rng.randf_range(0.9, 1.15)
	_dog_bark.volume_db = 6.0
	_dog_bark.play()
	barks += 1


func _dog_run_to(goal: Vector3, speed: float, dt: float) -> bool:
	var to := goal - dog.global_position
	to.y = 0.0
	var step := speed * dt
	if to.length() <= step:
		dog.global_position = Vector3(goal.x, 0, goal.z)
		return true
	var dir := to.normalized()
	dog.global_position += dir * step
	dog.rotation.y = atan2(-dir.x, -dir.z)
	return false


func _update_dog(dt: float) -> void:
	var running := dog_state != DogState.IDLE
	var k := 0
	for c in dog.get_children():
		if c.name.begins_with("Pata"):
			(c as Node3D).rotation.x = sin(_t * 18.0 + k * PI * 0.5) * (0.7 if running else 0.0)
			k += 1
	(dog.get_node("Rabo") as Node3D).rotation.y = sin(_t * 14.0) * 0.6
	match dog_state:
		DogState.IDLE:
			_dog_check_triggers()
			# Late para quem passa perto.
			_idle_bark -= dt
			if _idle_bark <= 0.0:
				for r in riders:
					if r.global_position.distance_to(dog.global_position) < 22.0:
						_bark()
						_idle_bark = 0.9
						break
		DogState.DART:
			if _dog_run_to(_dog_goal, 9.0, dt):
				dog_state = DogState.RETURN
			_dog_contacts()
		DogState.CHASE:
			_dog_timer -= dt
			var r := dog_target
			var behind := r.global_position - r.forward() * 1.6 + r.forward().cross(Vector3.UP) * 0.7
			_dog_run_to(behind, maxf(r.speed + 2.0, 6.0), dt)
			var face := r.forward()
			dog.rotation.y = atan2(-face.x, -face.z)
			_bark_timer -= dt
			if _bark_timer <= 0.0:
				_bark_timer = 0.5
				_bark()
			if _dog_timer <= 0.0 or r.state != BikeController.State.RIDING:
				dog_state = DogState.RETURN
		DogState.RETURN:
			if _dog_run_to(dog_home, 7.0, dt):
				dog_state = DogState.IDLE


func _dog_check_triggers() -> void:
	if race == null:
		return
	for i in riders.size():
		var r := riders[i]
		if dog_triggered.has(r) or r.collision_layer == 0 or r.state != BikeController.State.RIDING:
			continue
		var d: float = circuit.project(r.global_position)["distance"]
		var gap := dog_distance - d
		if gap < 2.0 or gap > 24.0:
			continue
		dog_triggered[r] = true
		var pos: int = race.call("position_of", i)
		var total := riders.size()
		if pos == total and total > 1:
			# Último colocado: o cão corre atrás e o susto faz pedalar mais.
			dog_state = DogState.CHASE
			dog_target = r
			_dog_timer = 10.0
			_bark_timer = 0.0
			r.scare(10.0)
			dog_events.append("chase:%s" % r.name)
		elif pos <= 3:
			# Primeiros colocados: atravessa na frente.
			var s := circuit.sample(d + r.speed * 1.2 + 3.0)
			var right: Vector3 = (s["dir"] as Vector3).cross(Vector3.UP)
			_dog_goal = (s["pos"] as Vector3) + right * 7.5
			dog_state = DogState.DART
			_dog_hit.clear()
			_bark()
			dog_events.append("dart:%s" % r.name)
		return


func _dog_contacts() -> void:
	for r in riders:
		if _dog_hit.has(r) or r.collision_layer == 0:
			continue
		var rel := r.global_position - dog.global_position
		rel.y = 0.0
		if rel.length() < 0.9 and r.speed > 2.0:
			_dog_hit[r] = true
			r.stumble()
			_bark()


# ------------------------------------------------------------------- comum

func _physics_process(dt: float) -> void:
	_t += dt
	_update_cars(dt)
	_update_peds(dt)
	_update_dog(dt)


## Obstáculos móveis para a IA desviar: {"pos", "vel", "radius"}.
func obstacles_for_ai() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for car in cars:
		var body: Node3D = car["body"]
		var f := _car_dir(car)
		var v := f * float(car["speed"])
		for off: float in [-1.6, 0.0, 1.6]:
			out.append({"pos": body.global_position + f * off, "vel": v, "radius": 1.1})
	for ped in peds:
		if ped["state"] == "wait":
			continue
		var cr: Dictionary = ped["crossing"]
		var v2: Vector3 = (cr["right"] as Vector3) * float(ped["dir"]) * PED_SPEED
		out.append({"pos": (ped["node"] as Node3D).global_position, "vel": v2, "radius": 0.6})
	if dog_state == DogState.DART:
		out.append({"pos": dog.global_position, "vel": (_dog_goal - dog.global_position).normalized() * 9.0, "radius": 0.7})
	return out
