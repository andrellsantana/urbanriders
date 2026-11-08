extends CanvasLayer
## HUD: retrato, corações (quedas permitidas), energia, velocidade, turbo e mensagens.

const BikeController := preload("res://scripts/player/bike_controller.gd")

var player: BikeController
var canvas: Control
var font: Font
var message: String = ""
var message_timer: float = 0.0
var game_over: bool = false


func _ready() -> void:
	font = ThemeDB.fallback_font
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_on_draw)
	add_child(canvas)


func setup(p: BikeController) -> void:
	player = p
	player.crashed.connect(_on_crashed)
	player.recovered.connect(_on_recovered)
	player.out_of_hearts.connect(_on_out)


func _on_crashed(hearts_left: int, reason: String) -> void:
	if hearts_left > 0:
		message = "%s  Levantando..." % reason
		message_timer = 3.0


func _on_recovered() -> void:
	message = ""
	message_timer = 0.0


func _on_out() -> void:
	game_over = true
	message = "VOCÊ PERDEU A CORRIDA!\nTrês quedas. Pressione R para reiniciar."


func _process(dt: float) -> void:
	if message_timer > 0.0:
		message_timer -= dt
		if message_timer <= 0.0 and not game_over:
			message = ""
	canvas.queue_redraw()


func _text(pos: Vector2, text: String, size: int, color: Color = Color.WHITE,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	canvas.draw_string_outline(font, pos, text, align, width, size, maxi(4, size / 6), Color(0.05, 0.0, 0.02))
	canvas.draw_string(font, pos, text, align, width, size, color)


func _heart(c: Vector2, s: float, fill: Color) -> void:
	var outline := Color(0.08, 0.0, 0.02)
	for pass_i in 2:
		var g := s + (5.0 if pass_i == 0 else 0.0)
		var col := outline if pass_i == 0 else fill
		canvas.draw_circle(c + Vector2(-g * 0.48, -g * 0.2), g * 0.52, col)
		canvas.draw_circle(c + Vector2(g * 0.48, -g * 0.2), g * 0.52, col)
		canvas.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-g * 0.98, -g * 0.02), c + Vector2(g * 0.98, -g * 0.02), c + Vector2(0, g * 1.05)]), col)


func _portrait(c: Vector2, r: float) -> void:
	canvas.draw_circle(c, r + 6.0, Color(0.95, 0.92, 0.85))
	canvas.draw_circle(c, r, Color(0.45, 0.06, 0.06))
	var jacket := PackedVector2Array()
	for i in 17:
		var a := lerpf(0.2 * PI, 0.8 * PI, i / 16.0)
		jacket.append(c + Vector2(cos(a), sin(a)) * r)
	canvas.draw_colored_polygon(jacket, Color(0.1, 0.12, 0.3)) # jaqueta
	canvas.draw_circle(c + Vector2(0, -r * 0.12), r * 0.58, Color(0.36, 0.2, 0.1)) # cabelo
	for i in 7:
		var a := PI + i * PI / 6.0
		canvas.draw_circle(c + Vector2(cos(a), sin(a) * 0.8) * r * 0.5 + Vector2(0, -r * 0.12), r * 0.2, Color(0.36, 0.2, 0.1))
	canvas.draw_circle(c + Vector2(0, r * 0.08), r * 0.42, Color(0.9, 0.68, 0.52)) # rosto
	canvas.draw_circle(c + Vector2(-r * 0.15, r * 0.02), r * 0.05, Color(0.15, 0.08, 0.05))
	canvas.draw_circle(c + Vector2(r * 0.15, r * 0.02), r * 0.05, Color(0.15, 0.08, 0.05))
	canvas.draw_arc(c + Vector2(0, r * 0.14), r * 0.17, 0.3, PI - 0.3, 10, Color(0.4, 0.1, 0.08), 3.0)
	canvas.draw_arc(c, r + 3.0, 0, TAU, 48, Color(0.05, 0.0, 0.02), 4.0)


func _on_draw() -> void:
	if player == null:
		return
	var vp := canvas.size
	# Retrato + corações + energia.
	_portrait(Vector2(110, 110), 72.0)
	for i in player.config.max_hearts:
		var alive := i < player.hearts
		_heart(Vector2(230 + i * 62, 82), 24.0, Color(0.9, 0.08, 0.1) if alive else Color(0.25, 0.2, 0.22))
	var bar_pos := Vector2(200, 128)
	var bar_size := Vector2(330, 24)
	var e := player.stamina.ratio()
	canvas.draw_rect(Rect2(bar_pos - Vector2(4, 4), bar_size + Vector2(8, 8)), Color(0.05, 0.0, 0.02))
	canvas.draw_rect(Rect2(bar_pos, bar_size), Color(0.2, 0.18, 0.2))
	var bar_col := Color(0.3, 0.85, 0.35).lerp(Color(0.95, 0.8, 0.2), clampf((0.6 - e) / 0.3, 0.0, 1.0))
	if player.stamina.exhausted:
		bar_col = Color(0.95, 0.25, 0.15)
	canvas.draw_rect(Rect2(bar_pos, Vector2(bar_size.x * e, bar_size.y)), bar_col)
	_text(bar_pos + Vector2(0, 52), "ENERGIA %d%%" % roundi(e * 100.0), 22)
	if player.stamina.exhausted:
		_text(bar_pos + Vector2(170, 52), "CANSADO!", 22, Color(1, 0.4, 0.3))

	# Velocímetro e turbo.
	var right := vp.x - 60.0
	_text(Vector2(right - 300, vp.y - 110), "%d" % roundi(player.speed_kmh()), 96, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 220)
	_text(Vector2(right - 70, vp.y - 110), "km/h", 30)
	var tb := Vector2(right - 300, vp.y - 80)
	canvas.draw_rect(Rect2(tb - Vector2(3, 3), Vector2(306, 22)), Color(0.05, 0.0, 0.02))
	canvas.draw_rect(Rect2(tb, Vector2(300 * player.boost_level, 16)), Color(1.0, 0.55, 0.1))
	_text(tb + Vector2(0, 46), "TURBO (S)", 20, Color(1.0, 0.75, 0.5))
	_text(Vector2(right - 300, vp.y - 210), "Piso: %s" % player.surface_name, 22, Color(0.9, 0.85, 0.8))
	if player.sliding:
		_text(Vector2(vp.x * 0.5 - 200, vp.y * 0.72), "DERRAPANDO!", 44, Color(1, 0.75, 0.2), HORIZONTAL_ALIGNMENT_CENTER, 400)

	# FPS (desenvolvimento).
	_text(Vector2(vp.x - 200, 44), "%d FPS" % Engine.get_frames_per_second(), 22, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 160)

	# Ajuda de controles.
	_text(Vector2(40, vp.y - 40), "Cima/W pedalar  ·  S acelerar  ·  Baixo/Espaço frear  ·  Esq/Dir ou A/D curvas  ·  R reiniciar  ·  Esc sair", 20, Color(0.92, 0.88, 0.85))

	if message != "":
		var lines := message.split("\n")
		for i in lines.size():
			_text(Vector2(0, vp.y * 0.38 + i * 64), lines[i], 52 if i == 0 else 32,
					Color(1, 0.9, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
