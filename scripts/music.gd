extends Node
## Autoload `Music`. Owns the soundtrack and nothing else: `game.gd` says what
## the situation is, this decides what should be playing and crossfades to it.
##
## Two players swap back and forth so a change is a fade rather than a cut —
## switching tracks the instant a block lands would be jarring several times a
## minute, which is exactly how often the board crosses a danger threshold.

## Filenames as they actually sit on disk. Two carry typos from when they were
## added (`cluch`, `critcal`); the keys below are the spellings the game uses, so
## renaming the files later only means editing this table.
const TRACKS := {
	"menu": "res://music/menuBGM.mp3",
	"main": "res://music/mainTheme.mp3",
	"critical": "res://music/critcalTheme.mp3",
	"clutch": "res://music/cluchMoment.mp3",
	"death": "res://music/deathSound.mp3",
	"victory": "res://music/victoryTheme.mp3",
}

## The soundtrack is meant to sit under everything, not compete with it: the
## keystrokes and the block impacts are the feedback you actually play on, so the
## bed stays well below them and moves between tracks slowly enough that you
## notice the mood changed rather than hearing a cut.
const MUSIC_DB := -17.0
## Per-track trim, because the files are not mastered to the same loudness and a
## sting arriving 6 dB hotter than the bed is exactly the jolt we are avoiding.
const TRIM := {
	"menu": 0.0,
	"main": 0.0,
	"critical": -1.0,
	"clutch": -1.0,
	"death": 2.0,
	"victory": 1.0,
}
## Short enough that the new track is simply there. A long crossfade sounds
## indecisive between two beds that are both already playing — you spend it
## hearing neither properly. The stings keep their own timing.
const FADE := 0.8
const STING_FADE := 0.7

var muted := false
## 0..1 from the settings screen. Applied on top of MUSIC_DB and the per-track
## trim, so the mix between tracks is preserved at every volume.
var gain := 1.0

var _players: Array[AudioStreamPlayer] = []
var _live := 0
var _current := ""
var _after := ""
var _fade_t := 1.0
var _fade_len := FADE
var _streams: Dictionary = {}


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_players[0].finished.connect(_on_finished)
	_players[1].finished.connect(_on_finished)


## Switch to `key`. Repeating the current key does nothing, so this is safe to
## call every frame. `after` queues a looping track behind a one-shot.
func play(key: String, loop: bool = true, after: String = "") -> void:
	if key == _current:
		return
	var stream: AudioStream = _stream(key)
	if stream == null:
		return
	_current = key
	_after = after

	_fade_len = STING_FADE if not loop else FADE
	_live = 1 - _live
	var fresh := _players[_live]
	fresh.stream = stream
	fresh.volume_db = -80.0
	fresh.play()
	_fade_t = 0.0


func stop() -> void:
	_current = ""
	_after = ""
	for p in _players:
		p.stop()


func toggle_mute() -> bool:
	muted = not muted
	return muted


func _stream(key: String) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var path: String = TRACKS.get(key, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Music: missing track '%s' (%s)" % [key, path])
		_streams[key] = null
		return null
	var s: AudioStream = load(path)
	# Set looping here rather than in the import settings, so the behaviour is
	# visible in code and survives a reimport.
	if s is AudioStreamMP3:
		s.loop = key != "death" and key != "victory"
	_streams[key] = s
	return s


func set_gain(v: float) -> void:
	gain = clampf(v, 0.0, 1.0)


func _process(delta: float) -> void:
	_fade_t = minf(1.0, _fade_t + delta / maxf(_fade_len, 0.01))
	var trim := linear_to_db(maxf(gain, 0.0001))
	var ceiling := -80.0 if (muted or gain <= 0.001) else \
		MUSIC_DB + float(TRIM.get(_current, 0.0)) + trim
	for i in _players.size():
		var p := _players[i]
		if not p.playing:
			continue
		# The incoming track rises while the outgoing one falls. Fading in dB
		# rather than linear amplitude keeps the crossover from dipping.
		var mix: float = _fade_t if i == _live else 1.0 - _fade_t
		p.volume_db = lerpf(-80.0, ceiling if i == _live else MUSIC_DB + trim, mix)
		if i != _live and _fade_t >= 1.0:
			p.stop()


func _on_finished() -> void:
	# A one-shot has run out; hand back to whatever was queued behind it.
	if _after != "":
		var next := _after
		_after = ""
		_current = ""
		play(next)
