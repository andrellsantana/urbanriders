extends CanvasLayer
## Menus: inicial (Jogar / Configurações / Sair), pausa (Esc) e configurações gráficas e de volume.
## Navegação por teclado (setas + Enter) ou mouse.

const Settings := preload("res://scripts/core/settings.gd")

signal play_pressed
signal resume_pressed
signal restart_pressed
signal settings_changed

enum Mode { HIDDEN, MAIN, PAUSE, SETTINGS }

var mode: Mode = Mode.HIDDEN
var _root: Control
var _box: VBoxContainer
var _title: Label
var _subtitle: Label
var _return_to: Mode = Mode.MAIN
var _theme: Theme


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.0, 0.02, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 16)
	panel.add_child(_box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	_title.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.02))
	_title.add_theme_constant_override("outline_size", 14)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 28)
	_subtitle.add_theme_color_override("font_color", Color(0.95, 0.85, 0.8))
	hide_menu()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 32
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.12, 0.02, 0.04, 0.92)
	panel.border_color = Color(1.0, 0.7, 0.3)
	panel.set_border_width_all(4)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(36)
	t.set_stylebox("panel", "PanelContainer", panel)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(12)
		match state:
			"normal":
				sb.bg_color = Color(0.3, 0.06, 0.06)
			"hover":
				sb.bg_color = Color(0.55, 0.12, 0.08)
			"pressed":
				sb.bg_color = Color(0.75, 0.25, 0.08)
			"focus":
				sb.bg_color = Color(0, 0, 0, 0)
				sb.border_color = Color(1.0, 0.85, 0.4)
				sb.set_border_width_all(4)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", Color(1, 0.95, 0.9))
	t.set_color("font_color", "Label", Color(1, 0.95, 0.9))
	t.set_color("font_color", "CheckBox", Color(1, 0.95, 0.9))
	return t


func is_open() -> bool:
	return mode != Mode.HIDDEN


func hide_menu() -> void:
	mode = Mode.HIDDEN
	_root.visible = false


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		if c != _title and c != _subtitle:
			c.queue_free()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func open_main() -> void:
	mode = Mode.MAIN
	_root.visible = true
	_clear()
	_title.text = "URBAN RIDERS"
	_subtitle.text = "Red City · corrida de bicicletas"
	_box.add_child(_title)
	_box.add_child(_subtitle)
	var first := _button("Jogar", _on_play)
	_button("Configurações", func() -> void: open_settings(Mode.MAIN))
	_button("Sair", func() -> void: get_tree().quit())
	first.grab_focus()


func open_pause() -> void:
	mode = Mode.PAUSE
	_root.visible = true
	get_tree().paused = true
	_clear()
	_title.text = "PAUSA"
	_subtitle.text = "Esc para continuar"
	_box.add_child(_title)
	_box.add_child(_subtitle)
	var first := _button("Continuar", _on_resume)
	_button("Reiniciar corrida", _on_restart)
	_button("Configurações", func() -> void: open_settings(Mode.PAUSE))
	_button("Sair do jogo", func() -> void: get_tree().quit())
	first.grab_focus()


func open_settings(back_to: Mode) -> void:
	_return_to = back_to
	mode = Mode.SETTINGS
	_root.visible = true
	_clear()
	_title.text = "CONFIGURAÇÕES"
	_subtitle.text = ""
	_box.add_child(_title)
	var q := OptionButton.new()
	for n in Settings.QUALITY_NAMES:
		q.add_item("Qualidade gráfica: %s" % n)
	q.selected = Settings.quality
	q.custom_minimum_size = Vector2(0, 60)
	q.item_selected.connect(func(i: int) -> void:
		Settings.quality = i
		_changed())
	_box.add_child(q)
	var sh := CheckBox.new()
	sh.text = "Sombras"
	sh.button_pressed = Settings.shadows
	sh.toggled.connect(func(on: bool) -> void:
		Settings.shadows = on
		_changed())
	_box.add_child(sh)
	var fs := CheckBox.new()
	fs.text = "Tela cheia"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		_changed())
	_box.add_child(fs)
	var vl := Label.new()
	vl.text = "Volume"
	_box.add_child(vl)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Settings.volume
	vol.custom_minimum_size = Vector2(0, 40)
	vol.value_changed.connect(func(v: float) -> void:
		Settings.volume = v
		_changed())
	_box.add_child(vol)
	var back := _button("Voltar", _on_back)
	q.grab_focus()
	back.focus_neighbor_bottom = q.get_path()


func _changed() -> void:
	Settings.save_settings()
	settings_changed.emit()


func _on_back() -> void:
	if _return_to == Mode.PAUSE:
		open_pause()
	else:
		open_main()


func _on_play() -> void:
	hide_menu()
	play_pressed.emit()


func _on_resume() -> void:
	hide_menu()
	get_tree().paused = false
	resume_pressed.emit()


func _on_restart() -> void:
	get_tree().paused = false
	hide_menu()
	restart_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("sair"):
		return
	match mode:
		Mode.PAUSE:
			_on_resume()
			get_viewport().set_input_as_handled()
		Mode.SETTINGS:
			_on_back()
			get_viewport().set_input_as_handled()
