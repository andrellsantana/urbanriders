extends Node3D
## Câmera em terceira pessoa: de costas, mostrando o garoto e a bicicleta inteiros.
## SpringArm3D impede que a câmera atravesse paredes.

@export var height: float = 1.0
@export var distance: float = 3.3
@export var pitch_deg: float = -11.0
@export var follow_sharpness: float = 12.0
@export var yaw_sharpness: float = 5.0
@export var base_fov: float = 68.0
@export var max_fov: float = 78.0

var target: CharacterBody3D
var trauma: float = 0.0 ## tremor (0–1), decai sozinho
var arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.1
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	arm.shape = probe
	arm.rotation.x = deg_to_rad(pitch_deg)
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = base_fov
	camera.far = 400.0
	arm.add_child(camera)
	camera.make_current()


func setup(new_target: CharacterBody3D) -> void:
	target = new_target
	arm.add_excluded_object(target.get_rid())
	global_position = target.global_position + Vector3.UP * height
	rotation.y = target.rotation.y


func _physics_process(dt: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * height
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_sharpness * dt))
	rotation.y = lerp_angle(rotation.y, target.rotation.y, 1.0 - exp(-yaw_sharpness * dt))
	var spd: float = target.get("speed")
	var t := clampf(spd / 11.1, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, lerpf(base_fov, max_fov, t), 1.0 - exp(-3.0 * dt))
	trauma = maxf(0.0, trauma - dt * 1.6)
	var k := trauma * trauma
	camera.h_offset = randf_range(-1.0, 1.0) * 0.25 * k
	camera.v_offset = randf_range(-1.0, 1.0) * 0.18 * k


func shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)
