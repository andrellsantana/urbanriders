extends Node3D
## Cena principal do protótipo: monta ambiente, pista, ciclista, câmera e HUD.

const InputSetup := preload("res://scripts/core/input_setup.gd")
const TestTrack := preload("res://scripts/world/test_track.gd")
const BikeController := preload("res://scripts/player/bike_controller.gd")
const CameraRig := preload("res://scripts/core/camera_rig.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const SKY_SHADER: Shader = preload("res://shaders/red_sky.gdshader")

var track: TestTrack
var player: BikeController
var camera_rig: CameraRig
var hud: Hud
var _perf_timer: float = 0.0


func _ready() -> void:
	InputSetup.ensure()
	_build_environment()
	track = TestTrack.new()
	add_child(track)
	player = BikeController.new()
	player.name = "AndrewMike"
	player.config = load("res://resources/bike_default.tres")
	player.position = TestTrack.SPAWN
	add_child(player)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.setup(player)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)


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
	env.fog_light_color = Color(0.55, 0.12, 0.08)
	env.fog_density = 0.004
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
