extends Resource
## Personalidade de um adversário controlado pela IA (valores de gameplay calibráveis).

@export var character_id: String = "mint"
@export_group("Curvas")
@export var corner_speed_kmh: float = 19.0 ## velocidade de entrada nas esquinas
@export var wet_corner_speed_kmh: float = 15.0 ## idem com poça perto da esquina
@export var knows_puddles: bool = true
@export var brake_decel_estimate: float = 5.5 ## m/s² que a IA assume ao planejar a frenagem
@export var brake_margin: float = 3.0 ## metros extras de frenagem (cautela)
@export var steer_gain: float = 2.5
@export_group("Turbo e energia")
@export var boost_min_straight: float = 40.0 ## só usa turbo com esta reta livre à frente (m)
@export var boost_stamina_min: float = 45.0 ## energia mínima para começar o turbo (%)
@export var boost_stamina_stop: float = 25.0 ## para o turbo abaixo desta energia (%)
@export var final_sprint_distance: float = 250.0 ## na reta final, usa toda a energia
@export_group("Comportamento")
@export var base_lane: float = 0.0 ## faixa preferida (m; + = direita)
@export var lane_change_speed: float = 1.6 ## m/s de deslocamento lateral
@export var erratic: bool = false ## muda de faixa e de ritmo sem aviso
@export var erratic_interval: Vector2 = Vector2(2.5, 6.0)
@export var aggressive: bool = false ## fecha e empurra rivais
@export var polite: bool = false ## evita contato
@export var overtake_lookahead: float = 8.0
