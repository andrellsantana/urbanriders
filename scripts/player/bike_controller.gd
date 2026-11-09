extends CharacterBody3D
## Controlador do ciclista: física híbrida com equilíbrio assistido,
## resistência física, quedas e recuperação.

const BikeConfig := preload("res://scripts/physics/bike_config.gd")
const BikePhysics := preload("res://scripts/physics/bike_physics.gd")
const Stamina := preload("res://scripts/physics/stamina.gd")
const RiderVisual := preload("res://scripts/player/rider_visual.gd")

signal crashed(hearts_left: int, reason: String)
signal recovered
signal out_of_hearts
signal bumped(strength: float)
signal special(kind: String) ## "acelerador", "susto", "tropeco"

enum State { RIDING, CRASHED, OUT }

@export var config: BikeConfig
@export var use_player_input: bool = true
## Falso durante a contagem regressiva e após a chegada (segura no freio).
var controls_enabled: bool = true
## Aparência (characters.gd); vazio = Andrew-Mike.
var look: Dictionary = {}

var state: State = State.RIDING
var speed: float = 0.0 ## m/s
var boost_level: float = 0.0
var brake_level: float = 0.0
var steer: float = 0.0 ## esterço suavizado (-1..1)
var yaw_rate: float = 0.0
var lean: float = 0.0
var hearts: int = 3
var grip: float = 1.0
var surface_name: String = "asfalto"
var sliding: bool = false
var pedaling: bool = false
var boosting: bool = false
var last_crash_reason: String = ""
var crash_count: int = 0
var stamina: Stamina = Stamina.new()
var visual: RiderVisual

## Entradas (lidas do teclado ou injetadas por IA/testes).
var in_pedal: bool = false
var in_boost: bool = false
var in_brake: bool = false
var in_steer: float = 0.0

var _overload_timer: float = 0.0
var _crash_timer: float = 0.0
var _grace_timer: float = 0.0
var _crash_normal: Vector3 = Vector3.ZERO
var _zones: Array[Dictionary] = []
var _spawn: Transform3D
var _bump: Vector3 = Vector3.ZERO
var _bump_cooldown: float = 0.0
var _pad_timer: float = 0.0
var _scare_timer: float = 0.0
const PAD_SPEED := 12.2 ## m/s (44 km/h) no acelerador
var _air_time: float = 0.0
## Impulso extra ao pousar de rampa (segundos), por personagem.
var ramp_bonus: float = 0.0
var ramp_boost_mult: float = 1.0 ## Russ: 1,1 (impulso de rampa 10% maior)
var knock_resistance_kmh: float = 20.0 ## batida relativa que derruba
var resistance_vs: Dictionary = {} ## multiplicador de resistência contra um rival específico
var recovery_mult: float = 1.0 ## tempo no chão (Mint: 1,05)
var pads_hit: int = 0
var ramps_hit: int = 0
var _pad_target: float = 12.2
var pad_speed: float = 12.2 ## m/s no acelerador do chão (Lucienne: 50 km/h)
const MAX_BUMP := 1.8 ## m/s máximos de empurrão acumulado

const LAYER_WORLD := 1
const LAYER_RIDERS := 2
const LAYER_TRAFFIC := 4


func _ready() -> void:
	if config == null:
		config = BikeConfig.new()
	hearts = config.max_hearts
	_spawn = global_transform
	floor_snap_length = 0.3 # baixo o bastante para decolar no topo das rampas
	floor_max_angle = deg_to_rad(40.0)
	floor_constant_speed = true
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.5
	shape.shape = capsule
	shape.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	shape.position = Vector3(0.0, 0.34, 0.0)
	add_child(shape)
	collision_layer = LAYER_RIDERS
	collision_mask = LAYER_WORLD | LAYER_RIDERS | LAYER_TRAFFIC
	visual = RiderVisual.new()
	visual.look = look
	add_child(visual)


func speed_kmh() -> float:
	return speed * BikePhysics.KMH


func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


## Chamado pelas zonas de piso (Area3D).
func enter_surface(zone_grip: float, zone_name: String) -> void:
	_zones.append({"grip": zone_grip, "name": zone_name})
	_apply_surface()


func exit_surface(zone_name: String) -> void:
	for i in range(_zones.size() - 1, -1, -1):
		if _zones[i]["name"] == zone_name:
			_zones.remove_at(i)
			break
	_apply_surface()


func _apply_surface() -> void:
	if _zones.is_empty():
		grip = 1.0
		surface_name = "asfalto"
	else:
		grip = _zones[-1]["grip"]
		surface_name = _zones[-1]["name"]


func _read_input() -> void:
	if not use_player_input:
		return
	in_pedal = Input.is_action_pressed("pedalar")
	in_boost = Input.is_action_pressed("acelerar")
	in_brake = Input.is_action_pressed("frear")
	in_steer = Input.get_axis("direita", "esquerda")


func _physics_process(dt: float) -> void:
	_read_input()
	if not controls_enabled:
		in_pedal = false
		in_boost = false
		in_brake = true
		in_steer = 0.0
	if state == State.RIDING:
		_ride(dt)
	else:
		_fallen(dt)
	if global_position.y < -30.0:
		_respawn()
	visual.tired = stamina.exhausted
	visual.update_pose(speed, lean, steer, pedaling, boost_level, dt)


func _ride(dt: float) -> void:
	var cfg := config
	_grace_timer = maxf(0.0, _grace_timer - dt)

	# Comandos: S também pedala (aumenta o ritmo gradualmente); freio corta a pedalada.
	boosting = in_boost and stamina.can_boost() and not in_brake
	pedaling = (in_pedal or in_boost) and not in_brake
	if boosting:
		boost_level = move_toward(boost_level, 1.0, dt / cfg.boost_ramp_time)
	else:
		boost_level = move_toward(boost_level, 0.0, dt / cfg.boost_decay_time)
	brake_level = move_toward(brake_level, 1.0, dt / cfg.brake_ramp_time) if in_brake else 0.0
	# Susto (cão correndo atrás): pedala forte sem gastar energia.
	_scare_timer = maxf(0.0, _scare_timer - dt)
	_pad_timer = maxf(0.0, _pad_timer - dt)
	var scared := _scare_timer > 0.0 and not in_brake
	if scared:
		pedaling = true
	var physics_boost := maxf(boost_level, 0.85) if scared else boost_level

	# Inclinação do piso.
	var fwd := forward()
	var on_floor := is_on_floor()
	var move_dir := fwd
	var slope_sin := 0.0
	if on_floor:
		move_dir = fwd.slide(get_floor_normal()).normalized()
		slope_sin = move_dir.y

	var accel := BikePhysics.longitudinal_accel(cfg, speed, pedaling, physics_boost, brake_level,
			1.0 if scared else stamina.performance(), slope_sin)
	speed = BikePhysics.step_speed(cfg, speed, accel, dt)
	if _pad_timer > 0.0 and speed < _pad_target:
		speed = move_toward(speed, _pad_target, 9.0 * dt * (_pad_target / PAD_SPEED))

	# Direção com equilíbrio assistido e limite de aderência do piso.
	steer = move_toward(steer, in_steer, cfg.steer_response * dt)
	var demand := BikePhysics.yaw_rate_demand(cfg, speed, steer)
	var limit := BikePhysics.grip_limit(cfg, grip)
	yaw_rate = demand
	sliding = false
	if speed > 0.5 and absf(demand) * speed > limit:
		sliding = true
		yaw_rate = signf(demand) * limit / speed
		speed = maxf(0.0, speed - 2.0 * dt)
		_overload_timer += dt
		if _overload_timer > cfg.grip_overload_time:
			_crash("Perdeu o controle na curva!", Vector3.ZERO)
			return
	else:
		_overload_timer = maxf(0.0, _overload_timer - 2.0 * dt)
	rotation.y = wrapf(rotation.y + yaw_rate * dt, -PI, PI)

	var target_lean := BikePhysics.lean_angle(cfg, speed, yaw_rate)
	lean = lerpf(lean, target_lean, 1.0 - exp(-cfg.lean_response * dt))

	# Resistência física.
	var effort: Stamina.Effort = Stamina.Effort.NORMAL
	if not pedaling:
		effort = Stamina.Effort.REST if speed < 0.3 else Stamina.Effort.COAST
	elif boosting:
		effort = Stamina.Effort.BOOST
	stamina.update(effort, boost_level, dt)

	# Movimento.
	if on_floor:
		velocity = move_dir * speed - get_floor_normal() * 0.5 + _bump # mantém contato com o piso
	else:
		var vy := velocity.y - cfg.gravity * dt
		velocity = fwd * speed + Vector3.UP * vy + _bump
	_bump = _bump.move_toward(Vector3.ZERO, 5.0 * dt)
	_bump_cooldown = maxf(0.0, _bump_cooldown - dt)
	var pre_velocity := velocity
	var was_airborne := not on_floor
	move_and_slide()
	if was_airborne and is_on_floor() and pre_velocity.y < -cfg.hard_landing_speed:
		_crash("Aterrissagem forte!", Vector3.ZERO)
		return
	if not on_floor:
		_air_time += dt
	if was_airborne and is_on_floor():
		if _air_time > 0.25 and speed > 4.0:
			# Pouso de rampa: impulso extra.
			_pad_timer = maxf(_pad_timer, 1.0 + ramp_bonus)
			_pad_target = PAD_SPEED * ramp_boost_mult
			ramps_hit += 1
			special.emit("rampa")
		_air_time = 0.0
	_check_impacts(pre_velocity)


func _check_impacts(pre_velocity: Vector3) -> void:
	var flat_pre := Vector3(pre_velocity.x, 0.0, pre_velocity.z)
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if n.y > 0.6:
			continue
		n.y = 0.0
		n = n.normalized()
		var other := col.get_collider()
		if other is CharacterBody3D and other.has_method("receive_bump"):
			var ov: Vector3 = (other as CharacterBody3D).velocity
			var rel := flat_pre - Vector3(ov.x, 0.0, ov.z)
			var hit := -rel.dot(n)
			if hit > 0.2 and _bump_cooldown <= 0.0:
				# Os dois sentem a batida; cada um cai conforme a própria resistência.
				other.call("receive_hit", hit, self, -n)
				_bump_cooldown = 0.0
				receive_hit(hit * 0.85, other as CharacterBody3D, n)
				if state != State.RIDING:
					return
				speed = maxf(0.0, speed - hit * 0.5)
			continue
		var impact := -flat_pre.dot(n)
		if impact > config.crash_impact_kmh / BikePhysics.KMH and _grace_timer <= 0.0:
			_crash("Colisão!", n)
			return
		if impact > 0.3:
			speed = Vector2(velocity.x, velocity.z).length()


## Batida de outro ciclista: abaixo da resistência só empurra; acima, derruba.
func receive_hit(hit: float, from: CharacterBody3D, push_dir: Vector3) -> void:
	if state != State.RIDING or _bump_cooldown > 0.0:
		return
	var res := knock_resistance_kmh / BikePhysics.KMH
	if from != null:
		res *= float(resistance_vs.get(String(from.name), 1.0))
	if hit > res and _grace_timer <= 0.0:
		var who := String(from.name) if from != null else "outro ciclista"
		_crash("Derrubado por %s!" % who if from != null else "Trombou!", push_dir)
		return
	receive_bump(push_dir * hit * 0.6)


## Empurrão recebido de outro ciclista (desequilibra um pouco).
func receive_bump(v: Vector3) -> void:
	if state != State.RIDING or _bump_cooldown > 0.0:
		return
	_bump_cooldown = 0.25
	_bump = (_bump + Vector3(v.x, 0.0, v.z)).limit_length(MAX_BUMP)
	bumped.emit(v.length())
	_overload_timer += v.length() * 0.03


## Acelerador no chão: impulso até 44 km/h sem gastar energia.
func pad_boost() -> void:
	if state != State.RIDING:
		return
	_pad_timer = 1.6
	_pad_target = pad_speed
	pads_hit += 1
	special.emit("acelerador")


func pad_active() -> bool:
	return _pad_timer > 0.0


## Susto: pedala forte por alguns segundos sem gastar energia.
func scare(seconds: float) -> void:
	if state != State.RIDING:
		return
	_scare_timer = seconds
	special.emit("susto")


func is_scared() -> bool:
	return _scare_timer > 0.0


## Esbarrou em algo que não é físico (pedestre): cai.
func hit_obstacle(reason: String) -> void:
	if state == State.RIDING and _grace_timer <= 0.0:
		_crash(reason, Vector3.ZERO)


## Tropeço (cão na frente): perde o embalo, sem cair.
func stumble() -> void:
	if state != State.RIDING:
		return
	speed *= 0.45
	_pad_timer = 0.0
	lean = 0.35 * (1.0 if randf() < 0.5 else -1.0)
	special.emit("tropeco")
	bumped.emit(2.0)


## Sem colisão com outros ciclistas (após a chegada ou derrota).
func set_ghost(on: bool) -> void:
	collision_layer = 0 if on else LAYER_RIDERS
	collision_mask = (LAYER_WORLD | LAYER_TRAFFIC) if on else (LAYER_WORLD | LAYER_RIDERS | LAYER_TRAFFIC)


## Reposiciona parado sobre a pista (recuperação da IA).
func teleport(pos: Vector3, dir: Vector3) -> void:
	global_position = pos
	rotation.y = atan2(-dir.x, -dir.z)
	velocity = Vector3.ZERO
	speed = 0.0
	steer = 0.0
	lean = 0.0
	_bump = Vector3.ZERO
	_grace_timer = config.recovery_grace


func _crash(reason: String, wall_normal: Vector3) -> void:
	last_crash_reason = reason
	crash_count += 1
	hearts = maxi(hearts - 1, 0)
	_crash_normal = wall_normal
	_crash_timer = config.recovery_time * recovery_mult
	_overload_timer = 0.0
	boost_level = 0.0
	brake_level = 0.0
	pedaling = false
	boosting = false
	sliding = false
	speed *= 0.35
	_bump = Vector3.ZERO
	visual.start_crash(lean)
	if hearts <= 0:
		state = State.OUT
		crashed.emit(hearts, reason)
		out_of_hearts.emit()
	else:
		state = State.CRASHED
		crashed.emit(hearts, reason)


func _fallen(dt: float) -> void:
	speed = move_toward(speed, 0.0, 9.0 * dt)
	lean = 0.0
	stamina.update(Stamina.Effort.REST, 0.0, dt)
	var vy := 0.0 if is_on_floor() else velocity.y - config.gravity * dt
	velocity = forward() * speed + Vector3.UP * vy
	move_and_slide()
	if state == State.CRASHED:
		_crash_timer -= dt
		if _crash_timer <= 0.0:
			_recover()


func _recover() -> void:
	state = State.RIDING
	speed = 0.0
	steer = 0.0
	lean = 0.0
	_grace_timer = config.recovery_grace
	if _crash_normal != Vector3.ZERO:
		# Afasta da parede e alinha com ela para poder seguir.
		global_position += _crash_normal * 0.6
		var along := forward().slide(_crash_normal)
		if along.length() < 0.2:
			along = _crash_normal
		along = along.normalized()
		rotation.y = atan2(-along.x, -along.z)
	visual.end_crash()
	recovered.emit()


func _respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	speed = 0.0
