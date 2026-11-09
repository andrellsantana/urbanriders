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
const SKY_SHADER: Shader = preload("res://shaders/red_sky.gdshader")

## Verdadeiro: pista de testes da física (Fase 2). Falso: bairro + corrida.
@export var use_test_track: bool = false

var world: Node3D
var player: BikeController
var race: RaceManager
var camera_rig: CameraRig
var hud: Hud
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
		var spawn := circuit.sample(Circuit.SPAWN_DISTANCE)
		var dir: Vector3 = spawn["dir"]
		player.position = spawn["pos"] + (dir.cross(Vector3.UP) * 2.0)
		player.rotation.y = atan2(-dir.x, -dir.z)
		add_child(player)
		race = RaceManager.new()
		add_child(race)
		race.setup(player, circuit)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(player)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)
	if race != null:
		hud.setup_race(race)
	load_time_ms = Time.get_ticks_msec() - t0
	print("[perf] cena montada em %d ms" % load_time_ms)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
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

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.55, 0.4)
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-32.0, 25.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reiniciar"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("sair"):
		get_tree().quit()


func _process(dt: float) -> void:
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
