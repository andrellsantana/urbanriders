extends RefCounted
## Registra as ações de teclado do jogo (setas e letras).

const MAP: Dictionary = {
	"pedalar": [KEY_UP, KEY_W],
	"acelerar": [KEY_S],
	"frear": [KEY_DOWN, KEY_SPACE],
	"esquerda": [KEY_LEFT, KEY_A],
	"direita": [KEY_RIGHT, KEY_D],
	"reiniciar": [KEY_R],
	"sair": [KEY_ESCAPE],
}


static func ensure() -> void:
	for action: String in MAP:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in MAP[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
