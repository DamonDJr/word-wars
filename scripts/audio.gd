extends Node
## Autoload. Every sound in the game is synthesised here at startup — there are
## no audio files in the project.
##
## That is partly to keep the repo self-contained, but mostly because these
## sounds need to be *parameterised*. Firing pitches up with your chain, clears
## pitch up with your combo, and garbage thuds lower the bigger it is. Baking
## that into samples would mean a dozen near-identical files; generating one
## waveform per event and riding `pitch_scale` gives the whole thing a scale.
##
## Press F1 in game to mute — every letter key is spoken for by typing.

const MIX_RATE := 22050
const VOICES := 16
## A few milliseconds of fade at each end. Without it every sound starts and
## stops on a discontinuity and you hear a click instead of a note.
const EDGE_FADE := 0.004

var muted := false

var _bank: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_bank()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted:
		return
	var stream: AudioStreamWAV = _bank.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		for p in _players:
			p.stop()
	return muted


# ------------------------------------------------------------------- the bank

func _build_bank() -> void:
	# Typing. Deliberately tiny — it fires on every keystroke, so anything with
	# body to it becomes unbearable within a sentence.
	_bank["key"] = _tone(880.0, 700.0, 0.035, 3.0, 0.35, 0.05, 0.16)
	_bank["back"] = _tone(520.0, 340.0, 0.045, 3.0, 0.25, 0.05, 0.14)
	_bank["reject"] = _tone(210.0, 150.0, 0.20, 2.0, 0.65, 0.12, 0.30)

	# Firing a word. Pitched up by chain at the call site.
	_bank["fire"] = _tone(400.0, 660.0, 0.13, 2.6, 0.30, 0.04, 0.30)
	# Destroying a block, and shooting one down before it lands.
	_bank["clear"] = _tone(680.0, 1250.0, 0.24, 2.2, 0.10, 0.02, 0.30)
	_bank["zap"] = _tone(1500.0, 400.0, 0.17, 2.6, 0.20, 0.22, 0.28)
	# Garbage arriving. Pitched down by block size at the call site.
	_bank["land"] = _tone(170.0, 68.0, 0.22, 2.0, 0.15, 0.38, 0.42)
	# Losing the chain, and the board getting close to the ceiling.
	_bank["lapse"] = _tone(540.0, 190.0, 0.30, 1.8, 0.20, 0.03, 0.20)
	_bank["danger"] = _tone(700.0, 540.0, 0.34, 1.4, 0.45, 0.05, 0.24)

	# Cashing in a maxed chain: a fast rising run, then the rain of blocks.
	_bank["salvo"] = _arp([392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0], 0.055, 0.80, 2.6, 0.40)

	# A power word landing. A bright open fifth rather than a full run — it has
	# to be able to fire three times in a second when one word trips several,
	# and a fanfare that long would smear into the next one.
	_bank["power"] = _arp([659.0, 988.0, 1319.0], 0.045, 0.42, 3.0, 0.34)

	# Countdown ticks, rising toward the GO fanfare.
	_bank["count"] = _tone(520.0, 500.0, 0.16, 3.0, 0.20, 0.02, 0.30)

	_bank["start"] = _arp([440.0, 554.0, 659.0, 880.0], 0.075, 0.60, 2.2, 0.34)
	_bank["win"] = _arp([523.0, 659.0, 784.0, 1047.0], 0.095, 0.95, 1.8, 0.38)
	_bank["lose"] = _arp([440.0, 392.0, 330.0, 247.0], 0.110, 1.05, 1.6, 0.34)


# -------------------------------------------------------------------- synthesis

## One voice: a pitch glide from `f0` to `f1` blending sine, square and noise,
## under an exponential decay. Square adds bite, noise adds impact.
func _tone(f0: float, f1: float, dur: float, decay: float, square: float,
		noise: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0

	for i in n:
		var t := float(i) / float(n)
		phase += TAU * lerpf(f0, f1, t) / MIX_RATE
		var s := sin(phase)
		if square > 0.0:
			s = lerpf(s, 1.0 if s >= 0.0 else -1.0, square)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)
		var env := pow(1.0 - t, decay) * _edges(i, n)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))

	return _wrap(data)


## A run of notes, each entering `step` seconds after the last and ringing out.
func _arp(freqs: Array, step: float, dur: float, decay: float, vol: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := PackedFloat32Array()
	phases.resize(freqs.size())

	for i in n:
		var now := float(i) / MIX_RATE
		var mix := 0.0
		for k in freqs.size():
			var started: float = now - k * step
			if started < 0.0:
				continue
			phases[k] += TAU * float(freqs[k]) / MIX_RATE
			var ring: float = maxf(0.0, 1.0 - started / maxf(0.001, dur - k * step))
			mix += sin(phases[k]) * pow(ring, decay)
		mix /= maxf(1.0, freqs.size() * 0.55)
		var env := _edges(i, n)
		data.encode_s16(i * 2, int(clampf(mix * env * vol, -1.0, 1.0) * 32767.0))

	return _wrap(data)


func _edges(i: int, n: int) -> float:
	var fade := maxf(1.0, MIX_RATE * EDGE_FADE)
	return minf(1.0, minf(float(i) / fade, float(n - 1 - i) / fade))


func _wrap(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s
