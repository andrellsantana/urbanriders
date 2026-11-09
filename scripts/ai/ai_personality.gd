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
@export var rest_below: float = 18.0 ## abaixo desta energia, solta o pedal para recuperar (%)
@export var rest_until: float = 40.0 ## volta a pedalar quando a energia chega aqui (%)
@export var pulse_strategy: bool = false ## alterna turbo e pedal solto (descansa sempre que não pode acelerar)
@export_group("Comportamento")
@export var base_lane: float = 0.0 ## faixa preferida (m; + = direita)
@export var lane_change_speed: float = 1.6 ## m/s de deslocamento lateral
@export var erratic: bool = false ## muda de faixa e de ritmo sem aviso
@export var erratic_interval: Vector2 = Vector2(2.5, 6.0)
@export var aggressive: bool = false ## fecha e empurra rivais
@export var polite: bool = false ## evita contato
@export var hunts_player: bool = false ## persegue o jogador para fechar e empurrar
@export var cuts_corners: bool = false ## corta esquinas por dentro (pela calçada)
@export var hesitation_chance: float = 0.0 ## chance de hesitar a cada mudança errática
@export var pace_variation: float = 0.0 ## variação aleatória de ritmo entre corridas (km/h nas curvas)
@export var feminine: bool = false ## concordância nos avisos ("cansada")
@export var overtake_lookahead: float = 8.0
