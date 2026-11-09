extends Node3D
## Cena principal: monta ambiente, mundo (bairro de Red City ou pista de testes),
## ciclista, corrida, câmera e HUD.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const TestTrack := preload("res://scripts/world/test_track.gd")
const Neighborhood := preload("res://scripts/world/neighborhood.gd")
const Circuit := preload("res://scripts/race/circuit.gd")
const RaceManager := preload("res://scripts/race/race_manager.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const CameraRig := preload("res://scripts/core/camera_rig.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Characters := preload("res://scripts/core/characters.gd")
const AIRider := preload("res://scripts/ai/ai_rider.gd")
const AIPersonality := preload("res://scripts/ai/ai_personality.gd")
const Settings := preload("res://scripts/core/settings.gd")
const Menu := preload("res://scripts/ui/menu.gd")
const BikeAudio := preload("res://scripts/audio/bike_audio.gd")
const RaceAudio := preload("res://scripts/audio/race_audio.gd")
const Effects := preload("res://scripts/fx/effects.gd")
const CourseFeatures := preload("res://scripts/world/course_features.gd")
const Hazards := preload("res://scripts/world/hazards.gd")
const SKY_SHADER: Shader = preload("res://shaders/red_sky.gdshader")

## Verdadeiro: pista de testes da física (Fase 2). Falso: bairro + corrida.
@export var use_test_track: bool = false
## Adversários da IA (Fase 4).
@export var with_rivals: bool = true
## Menu inicial antes da largada (desligado automaticamente nos testes headless).
@export var show_menu: bool = true
## Trânsito, pedestres e cão.
@export var with_hazards: bool = true

## Grid de largada: (distância no laço, faixa lateral). [0] = jogador.
const GRID: Array[Vector2] = [Vector2(3.0, 1.3), Vector2(7.0, -1.3), Vector2(7.0, 1.3), Vector2(3.0, -1.3)]
const RIVAL_ORDER: Array[String] = ["russ", "mint", "lucienne"]

var world: Node3D
var player: BikeController
var race: RaceManager
var camera_rig: CameraRig
var hud: Hud
var rivals: Array[BikeController] = []
var ai_riders: Array[AIRider] = []
var menu: Menu
var effects: Effects
var race_audio: RaceAudio
var sun: DirectionalLight3D
var features: CourseFeatures
var hazards: Hazards
var env: Environment
var sky_mat: ShaderMaterial
var _flash: float = 0.0
var _flash_t: float = 0.0
var load_time_ms: int = 0
var _perf_timer: float = 0.0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	InputSetup.ensure()
	_build_environment()
	player = BikeController.new()
	player.name = "AndrewMike"
	player.config = load("res://resources/bike_default.tres")
	if use_test_track:
		world = TestTrack.new()
		add_child(world)
		player.position = TestTrack.SPAWN
		add_child(player)
	else:
		world = Neighborhood.new()
		add_child(world)
		var circuit := Circuit.new()
		_place_on_grid(player, circuit, GRID[0])
		add_child(player)
		race = RaceManager.new()
		add_child(race)
		race.setup(player, circuit)
		if with_rivals:
			_spawn_rivals(circuit)
		features = CourseFeatures.new()
		features.name = "ElementosDaPista"
		add_child(features)
		features.setup(circuit)
		features.riders = race.riders
		if with_hazards:
			hazards = Hazards.new()
			hazards.name = "Perigos"
			add_child(hazards)
			hazards.setup(circuit, race, race.riders, features.crossing_points, (world as Neighborhood).parked_cars)
		for ai in ai_riders:
			ai.features = features
			ai.hazard_manager = hazards
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(player)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)
	if race != null:
		hud.setup_race(race)
	_setup_audio_and_fx()
	Settings.load_settings()
	Settings.apply(get_viewport(), sun)
	menu = Menu.new()
	add_child(menu)
	menu.play_pressed.connect(func() -> void:
		if race != null:
			race.hold = false)
	menu.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	menu.settings_changed.connect(func() -> void: Settings.apply(get_viewport(), sun))
	if show_menu and DisplayServer.get_name() != "headless":
		if race != null:
			race.hold = true
		menu.open_main()
	load_time_ms = Time.get_ticks_msec() - t0
	print("[perf] cena montada em %d ms" % load_time_ms)


func _setup_audio_and_fx() -> void:
	effects = Effects.new()
	add_child(effects)
	effects.falling_leaves(camera_rig)
	var bikes: Array[BikeController] = [player]
	bikes.append_array(rivals)
	for b in bikes:
		var ba := BikeAudio.new()
		b.add_child(ba)
		ba.setup(b, b == player)
		effects.watch(b)
	player.crashed.connect(func(_h: int, _r: String) -> void: camera_rig.shake(0.8))
	player.bumped.connect(func(s: float) -> void: camera_rig.shake(clampf(s * 0.15, 0.1, 0.4)))
	if race != null:
		race_audio = RaceAudio.new()
		add_child(race_audio)
		race_audio.setup(race)
		race_audio.lightning.connect(func() -> void: _flash = 1.0)


func _place_on_grid(b: BikeController, circuit: Circuit, slot: Vector2) -> void:
	var s := circuit.sample(slot.x)
	var dir: Vector3 = s["dir"]
	b.position = (s["pos"] as Vector3) + dir.cross(Vector3.UP) * slot.y
	b.rotation.y = atan2(-dir.x, -dir.z)


func _spawn_rivals(circuit: Circuit) -> void:
	var all: Array[BikeController] = [player]
	var personalities: Array[AIPersonality] = []
	var tags: Array[Label3D] = []
	for k in RIVAL_ORDER.size():
		var id := RIVAL_ORDER[k]
		var look := Characters.look(id)
		var b := BikeController.new()
		b.name = String(look["name"])
		b.use_player_input = false
		b.look = look
		var cfg: Resource = load("res://resources/bike_default.tres").duplicate()
		cfg.set("max_hearts", 99) # rivais não são eliminados por quedas
		b.config = cfg
		_place_on_grid(b, circuit, GRID[k + 1])
		add_child(b)
		var tag := Label3D.new()
		tag.text = String(look["name"])
		tag.font_size = 40
		tag.pixel_size = 0.0012
		tag.fixed_size = true # tamanho constante na tela
		tag.visibility_range_begin = 3.5
		tag.outline_size = 10
		tag.modulate = look["color"]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 2.05, 0)
		tag.visibility_range_end = 45.0
		b.add_child(tag)
		tags.append(tag)
		race.add_rider(b, String(look["name"]), look["color"])
		rivals.append(b)
		all.append(b)
		personalities.append(load("res://resources/ai_%s.tres" % id))
	for k in rivals.size():
		var ai := AIRider.new()
		ai.name = "IA_" + rivals[k].name
		add_child(ai)
		ai.setup(rivals[k], circuit, personalities[k], all, (world as Neighborhood).puddles, randi())
		ai.tag = tags[k]
		ai_riders.append(ai)
	race.rider_finished.connect(func(i: int, _t: float, _p: int) -> void:
		if i > 0:
			ai_riders[i - 1].finished = true)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.16, 0.22)
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.12, 0.08)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.55, 0.4)
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-32.0, 25.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar") and not menu.is_open():
		get_tree().reload_current_scene()
	elif event.is_action_pressed("sair") and not menu.is_open():
		menu.open_pause()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	# Relâmpago: céu e cidade piscam; decai rápido.
	if _flash > 0.0 or _flash_t > 0.0:
		_flash_t += dt
		_flash = maxf(0.0, _flash - dt * 2.2)
		var f := _flash * (0.55 + 0.45 * absf(sin(_flash_t * 37.0)))
		sky_mat.set_shader_parameter("flash", f)
		env.ambient_light_energy = 0.42 + f * 1.3
		sun.light_energy = 1.05 + f * 1.2
		if _flash <= 0.0:
			_flash_t = 0.0
	# Métricas de desempenho no console (somente em desenvolvimento).
	if not OS.is_debug_build():
		return
	_perf_timer += dt
	if _perf_timer >= 10.0:
		_perf_timer = 0.0
		print("[perf] %d FPS | %.1f ms/frame | %d draw calls" % [
			Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
