extends Node
## Autoload `Awards`. The lifetime record, mirrored onto Game Center.
##
## This owns no state and decides nothing. Every number it reports is already
## being tracked for the cosmetics catalogue — `Profile.standing()` answers
## "how far along is this requirement" for anything expressible as a `need`, and
## an achievement is that same question with a different consumer. So the whole
## file is a table of ids, a loop, and the guards that keep Apple's half of it
## from ever mattering.
##
## ## Why it mirrors rather than replaces
##
## The unlocks stay local and stay authoritative. Game Center is a display
## surface here, not a source of truth: it can be signed out, unreachable, or
## refusing submissions, and none of that may change what the player has earned.
## Anything else would mean a player on a plane losing a cosmetic they unlocked
## an hour earlier.
##
## ## Why every failure is silent
##
## Same rule as `leaderboards.gd`. On a desktop build there is no Game Center at
## all; on a phone it can be signed out; and an achievement that fails to submit
## has cost the player nothing, because the thing it describes already happened
## and is already on the record screen. So there is no error path here that a
## player can see — just a `print` for the device log.

## The catalogue, as `id -> need`.
##
## `need` is exactly the shape `Profile.standing` takes, which is the whole point
## — these are the same requirements the cosmetics use, so a rule that changes in
## one place cannot drift in the other.
##
## Ids are reverse-DNS on the bundle id, matching the leaderboards and the
## purchase. They must exist in App Store Connect spelled exactly like this; one
## that does not is reported, refused and logged, and nothing else happens.
const AWARDS := {
	"first_win": {"wins": 1},
	"ten_matches": {"matches": 10},
	"hundred_matches": {"matches": 100},
	"fifteen_wins": {"wins": 15},
	"six_hundred_words": {"words": 600},
	# 65 was a keyboard number on a game that ships to thumbs. `TOUCH_PACE` in
	# `ai_opponent.gd` is 0.7 — a good phone typist runs about seven tenths of
	# their own keyboard speed, measured rather than guessed — which puts 65 on
	# a desk at 45.5 on a phone. 50 rather than 45 because **the icon says 50**:
	# the art carries the number, and a threshold that disagrees with the
	# picture is a bug the player can see. Still a real ask — Wordsmith, the
	# hardest bot, types at 41 on a touch build.
	#
	# Must match the Speed Demon title in `profile.gd`, which this is named
	# after; `tools/awardtest.gd` fails if the two drift apart.
	"speed_demon": {"wpm": 50},
	"chainbreaker": {"chain": 8},
	"wordsmith": {"longest": 12},
	"flawless": {"flawless": 1},
	"flawless_three": {"flawless": 3},
	"salvo_king": {"salvos": 12},
	"four_at_once": {"combo": 4},
	"level_ten": {"level": 10},
	"level_sixteen": {"level": 16},
	"counterpuncher": {"power:COUNTER": 30},
	"perfectionist": {"power:PERFECT": 25},
	"ice_water": {"power:CLUTCH": 10},
}

const PREFIX := "com.damonj.wordwars.ach."

## What was last sent for each id, so a session does not re-report a number Apple
## already has. Game Center ignores a percentage lower than the one on file, but
## it does not ignore the round trip — and `push` runs on every profile change,
## which during a match is often.
var _sent: Dictionary = {}
var _busy := false


func available() -> bool:
	if not (OS.get_name() in ["iOS", "macOS"]):
		return false
	return ClassDB.can_instantiate("GKAchievement")


func _ready() -> void:
	if not available():
		return
	# Pushed on every change rather than at chosen moments. The alternative is a
	# call at each of the dozen places that can move a statistic, which is a list
	# that will be incomplete the first time somebody adds a thirteenth.
	Profile.changed.connect(push)
	push()


## Report anything whose progress has moved since this session last said so.
##
## Cheap when nothing has changed, which is the common case: the percentages are
## computed locally from numbers already in memory, and the call to Apple only
## happens if at least one of them is new.
func push() -> void:
	if not available() or _busy:
		return
	# Same test `leaderboards.gd` uses. Signed out is the ordinary state on a
	# fresh device and for the whole of a desktop run, so it is a reason to do
	# nothing rather than a fault — and `_sent` is left alone, so everything
	# catches up in one batch the moment somebody signs in.
	if MultiplayerManager.local_player == null:
		return

	var batch: Array = []
	for id: String in AWARDS:
		var pct := _percent(AWARDS[id])
		# Only ever forward. A profile that was reset locally must not walk an
		# achievement backwards on somebody's Game Center account.
		if pct <= float(_sent.get(id, -1.0)):
			continue
		_sent[id] = pct
		var a = GKAchievement.make(PREFIX + id)
		if a == null:
			continue
		a.percent_complete = pct
		# Apple's own "achievement unlocked" banner, which is the entire reason
		# to mirror these at all — the game already tells the player on its own
		# record screen.
		a.shows_completion_banner = true
		batch.append(a)

	if batch.is_empty():
		return
	_busy = true
	GKAchievement.report_achievement(batch, _on_reported)


## Where one requirement stands, as a percentage.
##
## `Profile.standing` does the work and already knows every key in the catalogue,
## including the `power:` ones. Clamped because `have` runs past `want` the
## moment a player keeps playing, and Apple rejects anything over a hundred.
func _percent(need: Dictionary) -> float:
	# An empty need is nought here and a hundred in `standing`, and the
	# disagreement is deliberate. `standing` is answering "is this cosmetic
	# locked", and the ones you start with have no requirement — so empty means
	# yes, wear it. An *achievement* with no requirement is a typo, and taking
	# `standing`'s answer would report it complete on somebody's Game Center
	# account the first time the app launched, with a banner, for nothing.
	if need.is_empty():
		return 0.0
	var s := Profile.standing(need)
	var want := float(s.get("want", 0))
	if want <= 0.0:
		return 0.0
	return clampf(float(s.get("have", 0)) / want * 100.0, 0.0, 100.0)


func _on_reported(error) -> void:
	_busy = false
	if error == null:
		return
	# Forgotten rather than retried, and re-sent on the next change. A retry loop
	# against an id that does not exist in App Store Connect would run for the
	# life of the session and fill the log with the same line.
	_sent.clear()
	print("[Awards] report refused: %s" % error)
