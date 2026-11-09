extends Node
## Sons da corrida (não posicionais): contagem, largada, checkpoints, chegada, derrota e trovões.

const Synth := preload("res://scripts/audio/synth.gd")
const RaceManager := preload("res://scripts/race/race_manager.gd")

signal lightning ## relâmpago (o trovão chega logo depois)

var _ui: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _thunder_timer: float = 6.0
var _pending_thunder: float = -1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_ui = AudioStreamPlayer.new()
	add_child(_ui)
	_thunder = AudioStreamPlayer.new()
	_thunder.stream = Synth.get_sound("thunder")
	add_child(_thunder)
	_rng.randomize()


func setup(race: RaceManager) -> void:
	race.countdown_changed.connect(func(v: int) -> void:
		if v > 0:
			play("beep", -6.0))
	race.race_started.connect(func() -> void: play("go", -4.0))
	race.checkpoint_passed.connect(func(_i: int, _t: int) -> void: play("checkpoint", -6.0))
	race.race_finished.connect(func(_t: float, _b: float) -> void: play("finish", -3.0))
	race.race_lost.connect(func() -> void: play("lose", -4.0))


func play(sound: String, db: float) -> void:
	_ui.stream = Synth.get_sound(sound)
	_ui.volume_db = db
	_ui.play()


func _process(dt: float) -> void:
	# Trovoada distante de vez em quando (céu tempestuoso).
	_thunder_timer -= dt
	if _thunder_timer <= 0.0:
		_thunder_timer = _rng.randf_range(9.0, 22.0)
		lightning.emit()
		_pending_thunder = _rng.randf_range(0.3, 1.4) # luz antes do som
	if _pending_thunder >= 0.0:
		_pending_thunder -= dt
		if _pending_thunder < 0.0:
			_thunder.volume_db = _rng.randf_range(-9.0, -2.0)
			_thunder.pitch_scale = _rng.randf_range(0.75, 1.05)
			_thunder.play()
