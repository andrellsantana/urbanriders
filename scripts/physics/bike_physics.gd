extends RefCounted
## Funções puras da física híbrida da bicicleta (sem estado, testáveis sem cena).

const BikeConfig := preload("res://scripts/physics/bike_config.gd")
const KMH := 3.6


## Velocidade-alvo (m/s) conforme turbo (0–1) e desempenho físico (0–1).
static func target_speed(cfg: BikeConfig, boost_level: float, performance: float) -> float:
	var kmh := lerpf(cfg.cruise_speed_kmh, cfg.max_speed_kmh, clampf(boost_level, 0.0, 1.0))
	return minf(kmh * performance, cfg.max_speed_kmh) / KMH


## Desaceleração por rolamento e ar (m/s²).
static func resistance(cfg: BikeConfig, speed: float) -> float:
	if speed <= 0.0:
		return 0.0
	return cfg.rolling_resistance + cfg.air_drag * speed * speed


## Aceleração longitudinal (m/s²). slope_sin > 0 = subida.
static func longitudinal_accel(cfg: BikeConfig, speed: float, pedaling: bool, boost_level: float,
		brake_level: float, performance: float, slope_sin: float) -> float:
	var a := -resistance(cfg, speed)
	if pedaling:
		var target := target_speed(cfg, boost_level, performance)
		var drive := resistance(cfg, target) + cfg.acceleration * clampf((target - speed) * cfg.drive_gain, -1.0, 1.0)
		a += maxf(drive, 0.0)
	if speed > 0.0:
		a -= cfg.brake_decel * clampf(brake_level, 0.0, 1.0)
	a -= cfg.gravity * slope_sin
	return a


static func step_speed(cfg: BikeConfig, speed: float, accel: float, dt: float) -> float:
	var cap := cfg.max_speed_kmh / KMH * cfg.downhill_overspeed
	return clampf(speed + accel * dt, 0.0, cap)


## Ângulo de esterço (rad); diminui com a velocidade. input: -1 (direita) a 1 (esquerda).
static func steer_angle(cfg: BikeConfig, speed: float, input: float) -> float:
	var t := clampf(speed / (cfg.max_speed_kmh / KMH), 0.0, 1.0)
	return deg_to_rad(lerpf(cfg.max_steer_deg, cfg.high_speed_steer_deg, t)) * clampf(input, -1.0, 1.0)


## Taxa de giro pedida (rad/s), limitada pelo equilíbrio assistido.
static func yaw_rate_demand(cfg: BikeConfig, speed: float, input: float) -> float:
	var kinematic := speed / cfg.wheelbase * tan(steer_angle(cfg, speed, input))
	if speed < 0.1:
		return kinematic
	var cap := cfg.assist_lateral_g * cfg.gravity / speed
	return clampf(kinematic, -cap, cap)


## Aceleração lateral máxima suportada pelo piso (m/s²).
static func grip_limit(cfg: BikeConfig, grip: float) -> float:
	return grip * cfg.grip_factor * cfg.gravity


## Inclinação visual (rad) para equilibrar a curva, limitada a max_lean_deg.
static func lean_angle(cfg: BikeConfig, speed: float, yaw_rate: float) -> float:
	var max_lean := deg_to_rad(cfg.max_lean_deg)
	return clampf(atan(speed * yaw_rate / cfg.gravity), -max_lean, max_lean)
