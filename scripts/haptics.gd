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
## But look at *which* dials, because the first version of this table was tuned
## against the wrong model of them and came out too faint to feel. The template
## emits `CHHapticEventTypeHapticContinuous` and nothing else — there is no
## transient event in it — and it sets intensity with no sharpness alongside.
##
## Two things follow, and they set every number below:
##
## - **These are rumbles, not clicks.** A continuous event has to spin the
##   actuator up, so anything under about 25ms is gone before it has started. The
##   9ms keystroke the first draft shipped with was, in practice, silence.
## - **Nothing here can be crisp.** Sharpness is what makes a tap feel like a
##   tap, and it is not exposed. So the only way to make an event register is
##   longer and harder, and the table leans on both accordingly.
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
	# Typing. The lightest thing here, but no longer the faintest possible thing
	# here — this is the one you feel hundreds of times a match, and it has to
	# read as the key having depth without becoming the texture of the game.
	# 30ms is roughly where a continuous event stops being imaginary.
	"key":      [30, 0.55, 0],
	"back":     [38, 0.65, 0],
	# A word that went nowhere. Long and hard enough to read as a stop rather
	# than as another letter.
	"reject":   [120, 0.90, 2],

	# Your own hits, scaled by how much you broke. `clear` takes an argument.
	"clear":    [60, 0.85, 3],
	"salvo":    [240, 1.00, 6],
	"power":    [160, 1.00, 5],
	"combo":    [95, 1.00, 4],

	# Things done to you. Deliberately heavier than anything you do yourself —
	# taking a hit should be the more physical of the two.
	"land":     [130, 1.00, 4],
	"life":     [400, 1.00, 7],
	"danger":   [80, 0.90, 3],

	# The bookends.
	"win":      [430, 1.00, 8],
	"lose":     [480, 1.00, 8],
	"level":    [280, 1.00, 6],
	# Menus. Firmly there, so a tap is acknowledged by the device and not only by
	# the speaker, which may well be muted.
	"tap":      [36, 0.70, 1],
}

## Below this, two events are one event as far as the hand is concerned, so the
## quieter of the pair is thrown away rather than made to wait. Grew with the
## table: the events themselves are two to three times longer now, so the window
## in which one masks the next is wider too. At 60ms a typist would have to pass
## 200wpm before it started eating their keystrokes.
const MERGE_MS := 60.0

## The ceiling on any single pulse, before and after scaling. There is no way to
## cancel one once it has started, so an over-long buzz cannot be taken back —
## it would still be running when the next thing happened.
const MAX_MS := 520.0

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

	var want: float = float(e[1]) * scale
	var strength: float = clampf(want, 0.05, 1.0)
	# Intensity stops at 1.0 and most of this table now sits on that ceiling, so
	# whatever `scale` cannot spend on strength is spent on duration instead.
	# Without this a three-block break and a one-block break would arrive in the
	# hand as exactly the same event, which is the thing the scaling exists to
	# prevent. Capped, because there is no way to cancel one of these.
	var ms: float = minf(float(e[0]) * maxf(1.0, want), MAX_MS)

	_last_ms = now
	_last_weight = weight
	# `vibrate_handheld(duration_ms, amplitude)` is the whole of the API.
	Input.vibrate_handheld(int(ms), strength)
	return true
