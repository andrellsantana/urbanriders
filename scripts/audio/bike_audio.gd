extends Node3D
## Sons de uma bicicleta (posicionais): pneus, corrente, catraca livre, freio, quedas, encostões e poças.

const Synth := preload("res://scripts/audio/synth.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")

var bike: BikeController
var is_player: bool = false
var _roll: AudioStreamPlayer3D
var _chain: AudioStreamPlayer3D
var _free: AudioStreamPlayer3D
var _brake: AudioStreamPlayer3D
var _event: AudioStreamPlayer3D
var _wind: AudioStreamPlayer
var _splash_timer: float = 0.0
var _pedal: AudioStreamPlayer3D
var _last_half: int = 0


func setup(b: BikeController, player: bool) -> void:
	bike = b
	is_player = player
	_roll = _loop("roll")
	_chain = _loop("chain")
	_free = _loop("freewheel")
	_brake = _loop("brake")
	_pedal = AudioStreamPlayer3D.new()
	_pedal.stream = Synth.get_sound("pedal")
	_pedal.max_distance = 30.0 if not is_player else 40.0
	_pedal.unit_size = 4.0
	add_child(_pedal)
	_event = AudioStreamPlayer3D.new()
	_event.max_distance = 60.0
	add_child(_event)
	if is_player:
		_wind = AudioStreamPlayer.new()
		_wind.stream = Synth.get_sound("wind")
		_wind.volume_db = -60.0
		add_child(_wind)
		_wind.play()
	bike.crashed.connect(func(_h: int, _r: String) -> void: _play_event("crash", 0.0))
	bike.bumped.connect(func(s: float) -> void: _play_event("bump", clampf(-14.0 + s * 4.0, -14.0, 0.0)))
	bike.special.connect(func(kind: String) -> void:
		if kind == "acelerador":
			_play_event("whoosh", -2.0))


func _loop(sound: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = Synth.get_sound(sound)
	p.volume_db = -80.0
	p.max_distance = 35.0 if not is_player else 50.0
	p.unit_size = 4.0
	add_child(p)
	p.play()
	return p


func _play_event(sound: String, db: float) -> void:
	_event.stream = Synth.get_sound(sound)
	_event.volume_db = db
	_event.pitch_scale = randf_range(0.92, 1.08)
	_event.play()


static func _db(on: bool, gain_db: float) -> float:
	return gain_db if on else -80.0


func _process(dt: float) -> void:
	if bike == null:
		return
	var v := bike.speed
	var t := clampf(v / 11.1, 0.0, 1.0)
	var riding := bike.state == BikeController.State.RIDING
	_roll.volume_db = _db(riding and v > 0.3, lerpf(-30.0, -12.0, t))
	_roll.pitch_scale = 0.7 + t * 0.6
	_chain.volume_db = _db(riding and bike.pedaling, -11.0 + t * 4.0)
	# Estalo a cada meia volta do pedivela.
	var half := floori(-bike.visual.crank_angle / PI)
	if half != _last_half:
		_last_half = half
		if riding and bike.pedaling:
			_pedal.volume_db = -9.0 if is_player else -12.0
			_pedal.pitch_scale = randf_range(0.9, 1.1)
			_pedal.play()
	_chain.pitch_scale = clampf(0.6 + v / 8.0, 0.6, 1.8)
	_free.volume_db = _db(riding and not bike.pedaling and v > 0.6, -20.0)
	_free.pitch_scale = clampf(v / 6.7, 0.3, 1.8)
	_brake.volume_db = _db(riding and bike.in_brake and v > 1.5, -18.0)
	if _wind != null:
		_wind.volume_db = lerpf(-40.0, -9.0, t)
		_wind.pitch_scale = 0.8 + t * 0.5
	# Respingos ao passar rápido por poça.
	_splash_timer -= dt
	if riding and bike.grip < 0.6 and bike.surface_name.contains("molhado") and v > 3.0 and _splash_timer <= 0.0:
		_splash_timer = 0.45
		_play_event("splash", -6.0)
