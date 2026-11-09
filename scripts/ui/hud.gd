extends CanvasLayer
## HUD: retrato, corações (quedas permitidas), energia, velocidade, turbo e mensagens.

const BikeController := preload("res://scripts/player/bike_controller.gd")
const RaceManager := preload("res://scripts/race/race_manager.gd")
const Circuit := preload("res://scripts/race/circuit.gd")
const Neighborhood := preload("res://scripts/world/neighborhood.gd")

var player: BikeController
var canvas: Control
var font: Font
var message: String = ""
var message_timer: float = 0.0
var game_over: bool = false
var race: RaceManager
var big_text: String = ""
var big_timer: float = 0.0
var result_lines: PackedStringArray = PackedStringArray()
var cp_flash: float = 0.0
var energy_trend: float = 0.0 ## %/s suavizado (+ recuperando, - gastando)
var _last_energy: float = -1.0
var _hint_shown: bool = false


func _ready() -> void:
	font = ThemeDB.fallback_font
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_on_draw)
	add_child(canvas)


func setup(p: BikeController) -> void:
	player = p
	player.special.connect(_on_special)
	player.crashed.connect(_on_crashed)
	player.recovered.connect(_on_recovered)
	player.out_of_hearts.connect(_on_out)


func setup_race(r: RaceManager) -> void:
	race = r
	race.countdown_changed.connect(func(v: int) -> void:
		big_text = str(v) if v > 0 else ""
		big_timer = 1.0)
	race.race_started.connect(func() -> void:
		big_text = "JÁ!"
		big_timer = 1.0)
	race.checkpoint_passed.connect(func(_i: int, _t: int) -> void: cp_flash = 1.0)
	race.race_finished.connect(_on_finished)
	race.race_lost.connect(_on_out)


func _on_finished(time: float, best: float) -> void:
	game_over = true
	message = ""
	var record := absf(time - best) < 0.001
	result_lines = PackedStringArray(["CHEGADA!", "Tempo: %s" % RaceManager.format_time(time),
		("NOVO RECORDE!" if record else "Recorde: %s" % RaceManager.format_time(best)),
		"Pressione R para correr de novo"])


static func ordinal(n: int) -> String:
	return "%dº" % n


func _on_special(kind: String) -> void:
	match kind:
		"acelerador":
			message = "ACELERADOR!"
			message_timer = 1.2
		"susto":
			message = "O CACHORRO! PEDALA!"
			message_timer = 2.5
		"tropeco":
			message = "Cachorro na frente!"
			message_timer = 1.8


func _on_crashed(hearts_left: int, reason: String) -> void:
	if hearts_left > 0:
		message = "%s  Levantando..." % reason
		message_timer = 3.0


func _on_recovered() -> void:
	message = ""
	message_timer = 0.0


func _on_out() -> void:
	game_over = true
	if race != null:
		message = "" # o quadro de resultado mostra a derrota
	else:
		message = "VOCÊ PERDEU A CORRIDA!\nTrês quedas. Pressione R para reiniciar."


func _process(dt: float) -> void:
	big_timer = maxf(0.0, big_timer - dt)
	if player != null and dt > 0.0:
		var e := player.stamina.value
		if _last_energy >= 0.0:
			energy_trend = lerpf(energy_trend, (e - _last_energy) / dt, 1.0 - exp(-4.0 * dt))
		_last_energy = e
		if not _hint_shown and e < 30.0 and message == "":
			_hint_shown = true
			message = "Energia baixa! Solte o pedal para recuperar."
			message_timer = 3.5
	cp_flash = maxf(0.0, cp_flash - dt)
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
	# Seta: energia subindo (verde) ou descendo (laranja).
	var ax := bar_pos.x + bar_size.x + 26.0
	var ay := bar_pos.y + bar_size.y * 0.5
	if energy_trend > 0.3:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 14), Vector2(ax + 12, ay + 6), Vector2(ax - 12, ay + 6)]), Color(0.4, 1, 0.45))
		_text(Vector2(ax + 20, ay + 8), "recuperando", 18, Color(0.6, 1, 0.6))
	elif energy_trend < -0.5:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(ax, ay + 14), Vector2(ax + 12, ay - 6), Vector2(ax - 12, ay - 6)]), Color(1, 0.6, 0.2))

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

	# Linhas de velocidade no turbo.
	if (player.boosting or player.pad_active() or player.is_scared()) and player.speed > 8.0:
		var k := clampf((player.speed - 8.0) / 3.1, 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(Time.get_ticks_msec() / 50)
		var center := vp * Vector2(0.5, 0.45)
		for i in 26:
			var ang := rng.randf() * TAU
			var dir := Vector2(cos(ang), sin(ang))
			var r0 := rng.randf_range(0.42, 0.55) * vp.x
			var r1 := r0 + rng.randf_range(60.0, 180.0)
			canvas.draw_line(center + dir * r0 * Vector2(1, 0.6), center + dir * r1 * Vector2(1, 0.6),
					Color(1, 0.92, 0.8, 0.35 * k), 3.0)

	# FPS (desenvolvimento).
	_text(Vector2(vp.x - 200, 44), "%d FPS" % Engine.get_frames_per_second(), 22, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 160)

	# Ajuda de controles.
	_text(Vector2(40, vp.y - 40), "Cima/W pedalar  ·  S acelerar  ·  Baixo/Espaço frear  ·  Esq/Dir ou A/D curvas  ·  R reiniciar  ·  Esc pausa", 20, Color(0.92, 0.88, 0.85))

	if race != null:
		_draw_race(vp)

	if message != "":
		var lines := message.split("\n")
		for i in lines.size():
			_text(Vector2(0, vp.y * 0.38 + i * 64), lines[i], 52 if i == 0 else 32,
					Color(1, 0.9, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vp.x)


# ------------------------------------------------------------------- corrida

func _draw_race(vp: Vector2) -> void:
	var cx := vp.x * 0.5
	# Cronômetro e checkpoints.
	_text(Vector2(0, 70), RaceManager.format_time(race.race_time), 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	var cp_col := Color(1, 0.85, 0.3).lerp(Color.WHITE, 1.0 - cp_flash)
	var passed := mini(race.next_gate, race.checkpoint_total())
	_text(Vector2(0, 108), "CHECKPOINT %d/%d" % [passed, race.checkpoint_total()], 26, cp_col, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	if race.phase == RaceManager.Phase.RACING:
		_draw_arrow(Vector2(cx, 160), race.next_gate_position())
	if race.wrong_way and race.phase == RaceManager.Phase.RACING:
		_text(Vector2(0, vp.y * 0.3), "SENTIDO ERRADO!", 56, Color(1, 0.3, 0.2), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	if big_timer > 0.0 and big_text != "":
		var size := int(170 + 60 * (1.0 - big_timer))
		_text(Vector2(0, vp.y * 0.45), big_text, size, Color(1, 0.9, 0.4).lerp(Color.WHITE, big_timer),
				HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	if race.riders.size() > 1:
		_draw_standings(vp)
	if result_lines.size() > 0 or race.phase == RaceManager.Phase.LOST:
		_draw_results(vp)
	_draw_minimap(Vector2(vp.x - 170, 230), 125.0)


## Seta que aponta para o próximo checkpoint (relativa à direção do ciclista).
func _draw_arrow(c: Vector2, target: Vector3) -> void:
	var to := target - player.global_position
	var fwd := player.forward()
	var right := fwd.cross(Vector3.UP)
	var ang := atan2(to.dot(right), to.dot(fwd))
	var pts := PackedVector2Array([Vector2(0, -26), Vector2(18, 14), Vector2(0, 4), Vector2(-18, 14)])
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	for p in pts:
		fill.append(c + p.rotated(ang))
		outline.append(c + (p * 1.25).rotated(ang))
	canvas.draw_colored_polygon(outline, Color(0.05, 0.0, 0.02))
	canvas.draw_colored_polygon(fill, Color(1, 0.8, 0.25))
	var dist := Vector2(to.x, to.z).length()
	_text(Vector2(c.x - 100, c.y + 46), "%d m" % roundi(dist), 22, Color(1, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 200)


## Minimapa circular que gira com o ciclista (frente para cima).
func _draw_minimap(c: Vector2, r: float) -> void:
	var k := r / 210.0
	canvas.draw_circle(c, r + 6, Color(0.9, 0.86, 0.78))
	canvas.draw_circle(c, r, Color(0.12, 0.1, 0.08))
	var origin := player.global_position
	var fwd := player.forward()
	var right := fwd.cross(Vector3.UP)
	var to_map := func(w: Vector3) -> Vector2:
		var rel := w - origin
		return c + Vector2(rel.dot(right), -rel.dot(fwd)) * k
	var b := Neighborhood.bounds()
	for i in Neighborhood.NX:
		var x := Neighborhood.grid_x(i)
		_clip_line(c, r, to_map.call(Vector3(x, 0, b.position.y)), to_map.call(Vector3(x, 0, b.end.y)), Color(0.42, 0.38, 0.36), 7.0)
	for j in Neighborhood.NZ:
		var z := Neighborhood.grid_z(j)
		_clip_line(c, r, to_map.call(Vector3(b.position.x, 0, z)), to_map.call(Vector3(b.end.x, 0, z)), Color(0.42, 0.38, 0.36), 7.0)
	var pts := race.circuit.points
	for i in pts.size():
		_clip_line(c, r, to_map.call(pts[i]), to_map.call(pts[(i + 1) % pts.size()]), Color(0.95, 0.55, 0.15), 5.0)
	var ng: Vector2 = to_map.call(race.next_gate_position())
	if ng.distance_to(c) < r - 6:
		canvas.draw_circle(ng, 8, Color(1, 0.9, 0.3))
	for i in range(1, race.riders.size()):
		var rp: Vector2 = to_map.call(race.riders[i].global_position)
		if rp.distance_to(c) < r - 6:
			canvas.draw_circle(rp, 7, Color(0.05, 0.0, 0.02))
			canvas.draw_circle(rp, 5, race.rider_colors[i])
	var fin: Vector2 = to_map.call(race.gates[race.gates.size() - 1]["pos"])
	if fin.distance_to(c) < r - 6:
		canvas.draw_rect(Rect2(fin - Vector2(7, 7), Vector2(14, 14)), Color.WHITE)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(10, 10), c + Vector2(-10, 10)]), Color(1, 0.25, 0.2))
	var north: Vector2 = (to_map.call(origin + Vector3(0, 0, -1000)) - c).normalized() * (r - 2) + c
	canvas.draw_circle(north, 15, Color(0.9, 0.86, 0.78))
	_text(north + Vector2(-8, 9), "N", 24, Color(0.1, 0.05, 0.05))
	canvas.draw_arc(c, r + 3, 0, TAU, 64, Color(0.05, 0.0, 0.02), 4.0)


## Desenha só a parte do segmento dentro do círculo.
func _clip_line(c: Vector2, r: float, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var d := b - a
	var f := a - c
	var qa := d.dot(d)
	if qa < 0.0001:
		return
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - r * r
	var disc := qb * qb - 4.0 * qa * qc
	if disc <= 0.0:
		return
	var sq := sqrt(disc)
	var t0 := clampf((-qb - sq) / (2.0 * qa), 0.0, 1.0)
	var t1 := clampf((-qb + sq) / (2.0 * qa), 0.0, 1.0)
	if t1 - t0 <= 0.0:
		return
	canvas.draw_line(a + d * t0, a + d * t1, col, width)


## Posição do jogador e classificação ao vivo (lado esquerdo).
func _draw_standings(vp: Vector2) -> void:
	var order := race.standings()
	var pos := order.find(0) + 1
	if race.phase == RaceManager.Phase.RACING or race.phase == RaceManager.Phase.COUNTDOWN:
		_text(Vector2(40, 260), ordinal(pos), 84, Color(1, 0.85, 0.35))
		_text(Vector2(40 + (70 if pos < 10 else 100), 260), "/%d" % race.riders.size(), 40, Color(0.95, 0.9, 0.85))
	var y := 320.0
	for k in order.size():
		var i := order[k]
		var is_player := i == 0
		var row := Rect2(Vector2(36, y - 30), Vector2(380, 38))
		canvas.draw_rect(row, Color(0.05, 0.0, 0.03, 0.55 if not is_player else 0.85))
		canvas.draw_rect(Rect2(row.position, Vector2(8, row.size.y)), race.rider_colors[i])
		var label := "%s  %s" % [ordinal(k + 1), race.rider_names[i]]
		_text(Vector2(54, y), label, 26, Color(1, 0.9, 0.5) if is_player else Color.WHITE)
		var pr: Dictionary = race.progress[i]
		if pr["finished"]:
			_text(Vector2(36, y), RaceManager.format_time(pr["time"]), 22, Color(0.8, 1, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, 370)
		elif pr["lost"]:
			_text(Vector2(36, y), "fora", 22, Color(1, 0.5, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, 370)
		y += 44.0


## Quadro de resultado: classificação final com tempos.
func _draw_results(vp: Vector2) -> void:
	var cx := vp.x * 0.5
	var order := race.standings()
	var box := Rect2(Vector2(cx - 400, vp.y * 0.22), Vector2(800, 220 + order.size() * 58))
	canvas.draw_rect(box, Color(0.05, 0.0, 0.03, 0.86))
	canvas.draw_rect(box, Color(1, 0.75, 0.3), false, 4.0)
	var lost := race.phase == RaceManager.Phase.LOST
	var title := "VOCÊ PERDEU A CORRIDA" if lost else "CHEGADA! VOCÊ FICOU EM %s" % ordinal(order.find(0) + 1)
	_text(Vector2(box.position.x, box.position.y + 76), title, 52, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	var y := box.position.y + 150
	for k in order.size():
		var i := order[k]
		var pr: Dictionary = race.progress[i]
		var t := "correndo..."
		if pr["finished"]:
			t = RaceManager.format_time(pr["time"])
		elif pr["lost"]:
			t = "três quedas"
		elif race.complete:
			t = "não terminou"
		var col := Color(1, 0.9, 0.5) if i == 0 else Color.WHITE
		canvas.draw_rect(Rect2(Vector2(box.position.x + 80, y - 30), Vector2(10, 36)), race.rider_colors[i])
		_text(Vector2(box.position.x + 110, y), "%s  %s" % [ordinal(k + 1), race.rider_names[i]], 34, col)
		_text(Vector2(box.position.x, y), t, 34, col, HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 80)
		y += 58.0
	var foot := "Recorde: %s" % RaceManager.format_time(race.best_time) if race.best_time > 0.0 else ""
	if result_lines.size() > 2 and result_lines[2] == "NOVO RECORDE!":
		foot = "NOVO RECORDE!"
	_text(Vector2(box.position.x, y + 14), foot, 30, Color(1, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	_text(Vector2(box.position.x, y + 60), "Pressione R para correr de novo", 28, Color(0.9, 0.88, 0.85), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
