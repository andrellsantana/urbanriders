extends RefCounted
## Configurações do jogador (qualidade gráfica, sombras, tela cheia, volume), salvas em user://config.cfg.

const FILE := "user://config.cfg"
enum Quality { LOW, MEDIUM, HIGH }
const QUALITY_NAMES: Array[String] = ["Baixa", "Média", "Alta"]

static var quality: int = Quality.MEDIUM
static var shadows: bool = true
static var fullscreen: bool = false
static var volume: float = 0.8 ## 0–1
static var _loaded: bool = false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	quality = int(cfg.get_value("grafico", "qualidade", quality))
	shadows = bool(cfg.get_value("grafico", "sombras", shadows))
	fullscreen = bool(cfg.get_value("grafico", "tela_cheia", fullscreen))
	volume = float(cfg.get_value("audio", "volume", volume))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("grafico", "qualidade", quality)
	cfg.set_value("grafico", "sombras", shadows)
	cfg.set_value("grafico", "tela_cheia", fullscreen)
	cfg.set_value("audio", "volume", volume)
	cfg.save(FILE)


## Aplica as configurações à janela, ao áudio e ao sol da cena.
static func apply(viewport: Viewport, sun: DirectionalLight3D) -> void:
	match quality:
		Quality.LOW:
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.scaling_3d_scale = 0.75
		Quality.MEDIUM:
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.scaling_3d_scale = 1.0
		Quality.HIGH:
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.scaling_3d_scale = 1.0
	if sun != null:
		sun.shadow_enabled = shadows
		sun.directional_shadow_max_distance = 70.0 if quality == Quality.HIGH else 45.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
