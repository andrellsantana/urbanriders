extends RefCounted
## Resistência física (energia) do ciclista.

enum Effort { REST, COAST, NORMAL, BOOST }

const MAX := 100.0

var value: float = MAX
var exhausted: bool = false

var recover_rest: float = 9.0 ## parado
var recover_coast: float = 3.5 ## sem pedalar, rodando
var drain_normal: float = 0.12 ## pedalada normal: ~7% por minuto (ritmo sustentável)
var drain_boost: float = 9.0 ## pedalada intensa (turbo máximo)
var exhausted_threshold: float = 10.0
var recovered_threshold: float = 30.0


func update(effort: Effort, boost_level: float, dt: float) -> void:
	match effort:
		Effort.REST:
			value += recover_rest * dt
		Effort.COAST:
			value += recover_coast * dt
		Effort.NORMAL:
			# Ritmo sustentável: gasta muito pouco. Pedalar NÃO recupera energia.
			value -= drain_normal * dt
		Effort.BOOST:
			value -= lerpf(drain_normal, drain_boost, clampf(boost_level, 0.0, 1.0)) * dt
	value = clampf(value, 0.0, MAX)
	if value <= exhausted_threshold:
		exhausted = true
	elif exhausted and value >= recovered_threshold:
		exhausted = false


func ratio() -> float:
	return value / MAX


const TIRED_LEVEL := 25.0

## Multiplicador de desempenho: 1.0 acima de 25% de energia, cai até 0.7 sem energia.
func performance() -> float:
	if value >= TIRED_LEVEL:
		return 1.0
	return lerpf(0.7, 1.0, value / TIRED_LEVEL)


func can_boost() -> bool:
	return not exhausted
