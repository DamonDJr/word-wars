extends Node
## The taptic engine, as a named vocabulary rather than a duration in milliseconds.
##
## Godot's iOS build drives this through Core Haptics — the export template
## carries `CHHapticEngine`, `CHHapticPattern` and the intensity parameter, with
## `AudioServicesPlaySystemSound` as the fallback on anything too old to have a
## taptic engine. That means duration *and* strength are both real dials rather
## than one fixed buzz, which is the whole reason this is worth doing properly:
## a game where every event feels identical in the hand is no better than one
## with no haptics at all.
##
## Everything here is a no-op on desktop. `Input.vibrate_handheld` does nothing
## without hardware, so there is no platform branch and no second code path — the
## calls sit in the same places on every build.
##
## Two rules run the whole file:
##
## 1. **Nothing may drown out anything.** The hand has far less resolution than
##    the ear. Two taps 30ms apart are one smeared tap, so a weaker event landing
##    on top of a stronger one is dropped rather than queued — it would arrive
##    late and blunt the one that mattered.
## 2. **Typing is the floor.** A letter is the most frequent event in the game by
##    an order of magnitude, so it is the lightest thing here and the first to be
##    suppressed. Haptics that fire forty times a minute at full strength stop
##    being feedback and become a texture you want to turn off.

## `[milliseconds, strength 0..1, weight]`.
##
## Weight is the pecking order, not the volume — it decides who wins when two
## land together. Tuned so the fight always beats the typing: losing a life must
## be felt through a burst of keystrokes, and a keystroke must never be felt
## through losing a life.
const EVENTS := {
	# Typing. Barely there on purpose — this is the one you feel hundreds of
	# times a match, and it is meant to read as the key having depth rather than
	# as the game telling you something.
	"key":      [9, 0.22, 0],
	"back":     [12, 0.30, 0],
	# A word that went nowhere. Longer and duller than a keystroke so a
	# rejection is felt as a stop rather than as another letter.
	"reject":   [55, 0.45, 2],

	# Your own hits, scaled by how much you broke. `clear` takes an argument.
	"clear":    [22, 0.45, 3],
	"salvo":    [140, 1.00, 6],
	"power":    [90, 0.85, 5],
	"combo":    [40, 0.70, 4],

	# Things done to you. Deliberately heavier than anything you do yourself —
	# taking a hit should be the more physical of the two.
	"land":     [70, 0.75, 4],
	"life":     [260, 1.00, 7],
	"danger":   [30, 0.55, 3],

	# The bookends.
	"win":      [320, 0.90, 8],
	"lose":     [420, 1.00, 8],
	"level":    [180, 0.80, 6],
	# Menus. One notch above nothing, so a tap is acknowledged by the device and
	# not only by the speaker, which may well be muted.
	"tap":      [14, 0.35, 1],
}

## Below this, two events are one event as far as the hand is concerned, so the
## quieter of the pair is thrown away rather than made to wait.
const MERGE_MS := 45.0

var enabled := true
var _last_ms := 0.0
var _last_weight := 0


func _ready() -> void:
	_apply()
	Profile.changed.connect(_apply)


func _apply() -> void:
	enabled = bool(Profile.pref("haptics"))


## Fire one. `scale` trims the strength for events that come in degrees — a
## three-block clear should not feel like a one-block clear.
##
## Returns whether it actually went out, which is the only way to check any of
## this without a phone in your hand: the hardware call reports nothing and does
## nothing on a desktop, so the decision is the part that can be tested.
func fire(name: String, scale: float = 1.0) -> bool:
	if not enabled or not EVENTS.has(name):
		return false
	var e: Array = EVENTS[name]
	var weight := int(e[2])
	var now := float(Time.get_ticks_msec())

	# A stronger event still in the hand wins; a weaker one is dropped outright.
	# Queueing it would only land it late, on top of the next thing.
	if now - _last_ms < MERGE_MS and weight <= _last_weight:
		return false

	var strength: float = clampf(float(e[1]) * scale, 0.05, 1.0)
	_last_ms = now
	_last_weight = weight
	# `vibrate_handheld(duration_ms, amplitude)` is the whole of the API — there
	# is no way to cancel one, which is the real reason nothing here runs long.
	# The heaviest event in the table is under half a second for that reason.
	Input.vibrate_handheld(int(e[0]), strength)
	return true
