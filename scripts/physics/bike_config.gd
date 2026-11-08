extends Resource
## Parâmetros de gameplay da bicicleta (valores iniciais, calibráveis em testes).

@export_group("Velocidade")
@export var cruise_speed_kmh: float = 24.0 ## Ritmo normal segurando só "pedalar".
@export var max_speed_kmh: float = 40.0 ## Teto absoluto com "acelerar" (S).
@export var acceleration: float = 3.0 ## m/s² de aceleração base.
@export var drive_gain: float = 0.5 ## Suavidade da aproximação da velocidade-alvo.
@export var boost_ramp_time: float = 4.0 ## Segundos segurando S até o turbo máximo.
@export var boost_decay_time: float = 2.0
@export var downhill_overspeed: float = 1.2 ## Multiplicador permitido em descidas.

@export_group("Resistências")
@export var rolling_resistance: float = 0.25 ## m/s²
@export var air_drag: float = 0.0045 ## coeficiente de v² (1/m)
@export var brake_decel: float = 7.0 ## m/s² com freio total
@export var brake_ramp_time: float = 0.35 ## Freio é progressivo enquanto segura.
@export var gravity: float = 9.8

@export_group("Direção e equilíbrio")
@export var wheelbase: float = 1.0
@export var max_steer_deg: float = 32.0 ## Esterço em baixa velocidade.
@export var high_speed_steer_deg: float = 7.0 ## Esterço na velocidade máxima.
@export var steer_response: float = 5.0
@export var assist_lateral_g: float = 0.75 ## Equilíbrio assistido: limite de curva pedido.
@export var grip_factor: float = 0.85 ## Aderência disponível = piso × fator × g.
@export var max_lean_deg: float = 30.0
@export var lean_response: float = 8.0

@export_group("Quedas")
@export var crash_impact_kmh: float = 14.0 ## Impacto frontal mínimo que derruba.
@export var hard_landing_speed: float = 8.0 ## m/s de queda vertical que derruba.
@export var grip_overload_time: float = 0.6 ## Tempo derrapando até cair.
@export var recovery_time: float = 2.5 ## Recuperação após a queda (2–3 s).
@export var recovery_grace: float = 1.0 ## Imunidade logo após levantar.
@export var max_hearts: int = 3 ## Quedas permitidas antes de perder a corrida.
