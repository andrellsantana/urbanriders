extends Node3D
## Efeitos visuais baratos (CPUParticles3D): poeira e folhas nas quedas, respingos nas poças,
## folhas de outono caindo ao redor da câmera.

const BikeController := preload("res://scripts/player/bike_controller.gd")

var _mats: Dictionary = {}
var _watched: Array[BikeController] = []
var _splash_timers: Dictionary = {}


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


func watch(b: BikeController) -> void:
	_watched.append(b)
	b.crashed.connect(func(_h: int, _r: String) -> void: burst(b.global_position + Vector3(0, 0.4, 0), "crash"))
	b.bumped.connect(func(s: float) -> void:
		if s > 1.0:
			burst(b.global_position + Vector3(0, 0.6, 0), "bump"))


func _process(dt: float) -> void:
	for b in _watched:
		var t: float = _splash_timers.get(b, 0.0) - dt
		if b.state == BikeController.State.RIDING and b.surface_name.contains("molhado") and b.speed > 3.0 and t <= 0.0:
			t = 0.3
			burst(b.global_position + Vector3(0, 0.1, 0), "splash")
		_splash_timers[b] = t


## Explosão curta de partículas.
func burst(pos: Vector3, kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	var q := QuadMesh.new()
	match kind:
		"crash":
			p.amount = 32
			p.lifetime = 1.0
			q.size = Vector2(0.07, 0.07)
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.5
			p.color = Color(1, 1, 1)
			var g := Gradient.new()
			g.set_color(0, Color(0.55, 0.42, 0.32))
			g.set_color(1, Color(0.85, 0.35, 0.08, 0.0))
			p.color_ramp = g
		"splash":
			p.amount = 14
			p.lifetime = 0.6
			q.size = Vector2(0.07, 0.07)
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.0
			var g2 := Gradient.new()
			g2.set_color(0, Color(0.75, 0.25, 0.22))
			g2.set_color(1, Color(0.5, 0.1, 0.1, 0.0))
			p.color_ramp = g2
		_:
			p.amount = 8
			p.lifetime = 0.5
			q.size = Vector2(0.06, 0.06)
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.0
			var g3 := Gradient.new()
			g3.set_color(0, Color(0.9, 0.85, 0.7))
			g3.set_color(1, Color(0.9, 0.85, 0.7, 0.0))
			p.color_ramp = g3
	p.mesh = q
	p.material_override = _mat(Color.WHITE)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, -9.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.particle_flag_align_y = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
	return p


## Folhas de outono caindo ao redor de um alvo (segue a câmera).
func falling_leaves(follow: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.1)
	p.mesh = q
	p.material_override = _mat(Color.WHITE)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 1, 18)
	p.position = Vector3(0, 9, -6)
	p.direction = Vector3(0.6, -1, 0.2)
	p.spread = 25.0
	p.gravity = Vector3(0.4, -0.9, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.35, 0.06))
	g.set_color(1, Color(0.6, 0.15, 0.05))
	p.color_initial_ramp = g
	follow.add_child(p)
	return p
