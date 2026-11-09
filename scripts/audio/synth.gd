extends RefCounted
## Sintetizador de efeitos sonoros (gerados por código: sem arquivos externos, sem licença).
## Cada função devolve um AudioStreamWAV (16 bits, mono, 22 050 Hz). Resultados ficam em cache.

const RATE := 22050

static var _cache: Dictionary = {}


static func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var s: AudioStreamWAV
	match sound_name:
		"wind": s = _wind()
		"roll": s = _roll()
		"chain": s = _chain()
		"freewheel": s = _freewheel()
		"brake": s = _brake()
		"crash": s = _crash()
		"bump": s = _bump()
		"splash": s = _splash()
		"beep": s = _beep(660.0, 0.18)
		"go": s = _beep(990.0, 0.55)
		"checkpoint": s = _chime()
		"finish": s = _fanfare()
		"lose": s = _lose()
		"thunder": s = _thunder()
		"honk": s = _honk()
		"bark": s = _bark()
		"whoosh": s = _whoosh()
		"pedal": s = _pedal()
		_:
			push_error("Som desconhecido: %s" % sound_name)
			s = _beep(440.0, 0.1)
	_cache[sound_name] = s
	return s


const NAMES: Array[String] = ["wind", "roll", "chain", "freewheel", "brake", "crash", "bump", "splash",
	"beep", "go", "checkpoint", "finish", "lose", "thunder", "honk", "bark", "whoosh", "pedal"]


# ----------------------------------------------------------------- utilidades

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## Ruído com passa-baixa de um polo (alpha pequeno = mais grave).
static func _noise(seconds: float, alpha: float, seed_value: int, gain: float = 1.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b := _buf(seconds)
	var y := 0.0
	for i in b.size():
		y += alpha * (rng.randf_range(-1.0, 1.0) - y)
		b[i] = y * gain
	return b


static func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	for i in b.size():
		b[i] = b[i] / m * peak
	return b


## Suaviza a emenda do laço (evita estalo).
static func _seam(b: PackedFloat32Array, fade: int = 400) -> PackedFloat32Array:
	var n := b.size()
	for i in fade:
		var t := float(i) / fade
		b[i] = b[i] * t + b[n - fade + i] * (1.0 - t)
	return b


# --------------------------------------------------------------------- laços

static func _wind() -> AudioStreamWAV:
	var b := _noise(2.0, 0.035, 11)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= 0.7 + 0.3 * sin(t * TAU * 0.5)
	return _wav(_seam(_normalize(b, 0.7)), true)


static func _roll() -> AudioStreamWAV:
	var b := _noise(1.0, 0.012, 21)
	var hi := _noise(1.0, 0.25, 22, 0.08)
	for i in b.size():
		b[i] += hi[i]
	return _wav(_seam(_normalize(b, 0.6)), true)


## Corrente: estalos rápidos dos elos + chiado leve.
static func _chain() -> AudioStreamWAV:
	var b := _noise(0.5, 0.4, 31, 0.15)
	var period := RATE / 45
	for i in b.size():
		var k := i % period
		b[i] += exp(-float(k) / 18.0) * (0.6 if (i / period) % 2 == 0 else 0.4) * sin(float(k) * 1.9)
	return _wav(_seam(_normalize(b, 0.5)), true)


## Catraca livre ("tic-tic-tic" ao rodar sem pedalar).
static func _freewheel() -> AudioStreamWAV:
	var b := _buf(0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var period := RATE / 30
	for i in b.size():
		var k := i % period
		b[i] = exp(-float(k) / 9.0) * rng.randf_range(-1.0, 1.0)
	return _wav(_normalize(b, 0.55), true)


## Chiado de freio (agudo com vibrato).
static func _brake() -> AudioStreamWAV:
	var b := _buf(1.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 2300.0 + 60.0 * sin(t * TAU * 6.0)
		ph += TAU * f / RATE
		b[i] = sin(ph) * 0.5 + sin(ph * 1.5) * 0.2
	var n := _noise(1.0, 0.5, 51, 0.15)
	for i in b.size():
		b[i] += n[i]
	return _wav(_seam(_normalize(b, 0.4)), true)


# ------------------------------------------------------------------- eventos

## Queda: pancada grave + metal da bicicleta + chocalho.
static func _crash() -> AudioStreamWAV:
	var b := _noise(0.9, 0.06, 61)
	var rng := RandomNumberGenerator.new()
	rng.seed = 62
	for i in b.size():
		var t := float(i) / RATE
		var thump := b[i] * exp(-t * 14.0) * 2.5
		var metal := (sin(t * TAU * 523.0) * 0.5 + sin(t * TAU * 1347.0) * 0.35 + sin(t * TAU * 2791.0) * 0.25) * exp(-t * 6.0)
		var rattle := 0.0
		if rng.randf() < 0.004:
			rattle = rng.randf_range(-1.0, 1.0)
		b[i] = thump + metal * 0.5 + rattle * exp(-t * 3.0)
	return _wav(_normalize(b, 0.9), false)


static func _bump() -> AudioStreamWAV:
	var b := _noise(0.18, 0.08, 71)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = b[i] * exp(-t * 30.0) + sin(t * TAU * 110.0) * exp(-t * 25.0) * 0.5
	return _wav(_normalize(b, 0.7), false)


static func _splash() -> AudioStreamWAV:
	var b := _noise(0.45, 0.45, 81)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= exp(-t * 7.0) * (1.0 - exp(-t * 80.0))
	return _wav(_normalize(b, 0.5), false)


static func _beep(freq: float, dur: float) -> AudioStreamWAV:
	var b := _buf(dur)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 200.0) * minf(1.0, (dur - t) * 30.0)
		b[i] = (1.0 if sin(t * TAU * freq) >= 0.0 else -1.0) * 0.35 * env
	return _wav(b, false)


static func _chime() -> AudioStreamWAV:
	var b := _buf(0.6)
	for i in b.size():
		var t := float(i) / RATE
		var a := sin(t * TAU * 880.0) * exp(-t * 6.0)
		var c := 0.0
		if t > 0.12:
			c = sin((t - 0.12) * TAU * 1318.5) * exp(-(t - 0.12) * 5.0)
		b[i] = (a + c) * 0.4
	return _wav(b, false)


static func _fanfare() -> AudioStreamWAV:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var b := _buf(1.4)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in notes.size():
			var start := k * 0.15
			if t >= start:
				var lt := t - start
				var decay := 1.5 if k == notes.size() - 1 else 8.0
				var f: float = notes[k]
				v += (2.0 * absf(2.0 * fposmod(lt * f, 1.0) - 1.0) - 1.0) * exp(-lt * decay)
		b[i] = v * 0.22
	return _wav(b, false)


static func _lose() -> AudioStreamWAV:
	var b := _buf(1.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(440.0, 196.0, t) / RATE
		b[i] = sin(ph) * 0.35 * minf(1.0, (1.0 - t) * 4.0)
	return _wav(b, false)


static func _thunder() -> AudioStreamWAV:
	var b := _noise(3.5, 0.008, 91)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92
	var env := 0.0
	for i in b.size():
		var t := float(i) / RATE
		if rng.randf() < 0.0004:
			env = minf(1.0, env + 0.6)
		env *= 0.99993
		b[i] *= (env + 0.15) * exp(-t * 0.6) * minf(1.0, t * 8.0)
	return _wav(_normalize(b, 0.8), false)


## Buzina de carro dos anos 80 (duas notas).
static func _honk() -> AudioStreamWAV:
	var b := _buf(0.55)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 60.0) * minf(1.0, (0.55 - t) * 25.0)
		var v := (1.0 if sin(t * TAU * 392.0) >= 0.0 else -1.0) + (1.0 if sin(t * TAU * 494.0) >= 0.0 else -1.0)
		b[i] = v * 0.18 * env
	return _wav(b, false)


## Latido: dois "au!" curtos.
static func _bark() -> AudioStreamWAV:
	var b := _buf(0.5)
	var n := _noise(0.5, 0.3, 101, 0.4)
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for start: float in [0.0, 0.22]:
			var lt := t - start
			if lt >= 0.0 and lt < 0.16:
				var f := lerpf(620.0, 380.0, lt / 0.16)
				var env := minf(1.0, lt * 120.0) * exp(-lt * 14.0)
				v += (sin(lt * TAU * f) + 0.5 * sin(lt * TAU * f * 2.1) + n[i]) * env
		b[i] = v
	return _wav(_normalize(b, 0.8), false)


## Impulso do acelerador: chiado que sobe.
static func _whoosh() -> AudioStreamWAV:
	var b := _buf(0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 111
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var alpha := lerpf(0.03, 0.5, t / 0.7)
		y += alpha * (rng.randf_range(-1.0, 1.0) - y)
		b[i] = y * sin(PI * t / 0.7) + sin(t * TAU * lerpf(300.0, 900.0, t / 0.7)) * 0.15 * sin(PI * t / 0.7)
	return _wav(_normalize(b, 0.6), false)


## Pedalada: estalo do pedivela + roçar da corrente (um por meia volta).
static func _pedal() -> AudioStreamWAV:
	var b := _noise(0.16, 0.6, 121, 0.3)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = b[i] * exp(-t * 30.0) + sin(t * TAU * 180.0) * exp(-t * 45.0) * 0.6
	return _wav(_normalize(b, 0.5), false)
