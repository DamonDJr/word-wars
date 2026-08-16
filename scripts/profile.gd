extends Node
## Autoload `Profile`. What the player has done across every match they have
## ever played, what that has earned them, and what they are wearing.
##
## Nothing in here touches how the game plays. That is the whole point: mastery
## is worth showing off precisely because it cannot be cashed in for an
## advantage, so a level 30 player and a level 1 player meet on the same terms
## and the level is a claim about the person rather than the loadout.
##
## Everything is derived. XP is a pure function of the record, the level is a
## pure function of XP, and what is unlocked is a pure function of the record —
## so nothing can drift out of step, and changing a formula re-grades every
## existing profile on the next boot instead of stranding it.

## A variable rather than a constant purely so the tests can point it at a
## scratch file: a suite that overwrites the player's actual record to prove the
## record works would be a poor trade.
var save_path := "user://profile.cfg"

signal changed


# ------------------------------------------------------------------- the record

var matches := 0
var wins := 0
var flawless := 0          ## wins that cost no lives at all
var words := 0
var chars := 0
var salvos := 0
var multi_clears := 0      ## words that broke three or more at once
var best_wpm := 0.0
var best_chain := 0
var best_combo := 0
var best_score := 0
var longest_word := ""
## Power word name -> times earned.
var powers: Dictionary = {}

## Slot -> cosmetic id.
var equipped: Dictionary = {}

## Settings and remembered choices. Kept in the same file as the record because
## it is all "this player's stuff", and one file is one thing that can go wrong.
var prefs: Dictionary = {}

const PREF_DEFAULTS := {
	"music": 0.7,
	"sfx": 0.8,
	"texture": true,     ## film grain and vignette
	"hitstop": true,     ## the freeze-frame on heavy hits
	"censor": true,      ## mask profanity wherever a word is echoed back
	"fullscreen": false,
	"haptics": true,     ## the taptic engine; no-op on anything without one
	## Rival seats for a single-player match. "" is an empty seat, "?" is a
	## random personality rolled at the start of each match, anything else names
	## one from the roster.
	"solo": ["Duelist", "", ""],
	## Special block kinds switched on. Empty is the base game.
	"kinds": [],
	## Set once the tutorial has been finished, so the game only nags once.
	"taught": false,
}


func pref(key: String):
	return prefs.get(key, PREF_DEFAULTS.get(key))


func set_pref(key: String, value) -> void:
	prefs[key] = value
	save()
	changed.emit()


# ------------------------------------------------------------------------- xp
#
# Every line the request asked for is in here, weighted by how much work it
# represents rather than how big the number gets. Words typed is the grind and
# pays least per unit; a salvo is a nine-word run cashed in and pays like it.
# The `best_` figures are peaks rather than totals, so they pay once and pay
# well — they are a claim about your ceiling, not your patience.

const XP := {
	"match": 90,
	"win": 240,
	"flawless": 350,
	"word": 4,
	"salvo": 130,
	"multi_clear": 22,
	"wpm": 4,            ## per point of your best
	"chain": 12,         ## per link of your best, squared below
	"combo": 30,
	"longest": 5,        ## per letter of your longest, squared below
}


func xp_total() -> int:
	var n := 0
	n += matches * int(XP["match"])
	n += wins * int(XP["win"])
	n += flawless * int(XP["flawless"])
	n += words * int(XP["word"])
	n += salvos * int(XP["salvo"])
	n += multi_clears * int(XP["multi_clear"])
	n += int(best_wpm) * int(XP["wpm"])
	# Squared, because the difference between a five-chain and a nine-chain is
	# not four more words, it is four more words without a single mistake.
	n += best_chain * best_chain * int(XP["chain"])
	n += best_combo * best_combo * int(XP["combo"])
	n += longest_word.length() * longest_word.length() * int(XP["longest"])
	for key in powers:
		n += int(powers[key]) * 18
	return n


## Levels get further apart forever. The first few arrive inside one sitting so
## the system introduces itself; by level 20 you are being asked for real work.
const LEVEL_STEP := 300


func level() -> int:
	return 1 + int(sqrt(float(xp_total()) / float(LEVEL_STEP)))


func xp_for_level(n: int) -> int:
	var m := maxi(0, n - 1)
	return m * m * LEVEL_STEP


## How far through the current level, 0..1, plus the numbers either side of it.
func level_progress() -> Dictionary:
	var lv := level()
	var floor_xp := xp_for_level(lv)
	var next_xp := xp_for_level(lv + 1)
	var have := xp_total()
	return {
		"level": lv,
		"into": have - floor_xp,
		"need": next_xp - floor_xp,
		"frac": clampf(float(have - floor_xp) / float(maxi(1, next_xp - floor_xp)), 0.0, 1.0),
	}


# ------------------------------------------------------------------ cosmetics
#
# One table. The mastery screen builds itself from it, the unlock check reads
# the same rows, and adding a cosmetic means adding a row — there is nowhere for
# a "shown but not obtainable" entry to hide.
#
# `need` is empty for the ones you start with. Otherwise it names a single
# requirement, because "reach a nine-chain" is a thing somebody can go and do
# and "reach a nine-chain and 400 words and level 12" is a wall.

const SLOTS := ["title", "theme", "blocks", "typing", "attack", "cursor", "victory"]

const SLOT_NAMES := {
	"title": "TITLE",
	"theme": "BOARD THEME",
	"blocks": "BLOCK STYLE",
	"typing": "TYPING",
	"attack": "ATTACK",
	"cursor": "CURSOR",
	"victory": "VICTORY",
}

const COSMETICS := {
	"title": [
		{"id": "none", "name": "—", "need": {}},
		{"id": "rookie", "name": "Rookie", "need": {"matches": 3}},
		{"id": "dictionary", "name": "Dictionary", "need": {"words": 600}},
		{"id": "speed_demon", "name": "Speed Demon", "need": {"wpm": 65}},
		{"id": "chainbreaker", "name": "Chainbreaker", "need": {"chain": 8}},
		{"id": "wordsmith", "name": "Wordsmith", "need": {"longest": 12}},
		{"id": "no_looking_back", "name": "No Looking Back", "need": {"flawless": 1}},
		{"id": "counterpuncher", "name": "Counterpuncher", "need": {"power:COUNTER": 30}},
		{"id": "clutch", "name": "Ice Water", "need": {"power:CLUTCH": 10}},
		{"id": "perfectionist", "name": "Perfectionist", "need": {"power:PERFECT": 25}},
		{"id": "salvo_king", "name": "SALVO KING", "need": {"salvos": 12}},
		{"id": "undefeated", "name": "Undefeated", "need": {"wins": 15}},
		{"id": "centurion", "name": "Centurion", "need": {"matches": 100}},
	],
	"theme": [
		{"id": "midnight", "name": "Midnight", "need": {}},
		{"id": "ember", "name": "Ember", "need": {"level": 3}},
		{"id": "chlorophyll", "name": "Chlorophyll", "need": {"level": 6}},
		{"id": "vapor", "name": "Vapour", "need": {"level": 10}},
		{"id": "bone", "name": "Bone", "need": {"level": 16}},
	],
	"blocks": [
		{"id": "solid", "name": "Solid", "need": {}},
		{"id": "outline", "name": "Wireframe", "need": {"level": 4}},
		{"id": "glass", "name": "Glass", "need": {"combo": 4}},
		{"id": "circuit", "name": "Circuit", "need": {"level": 12}},
	],
	"typing": [
		{"id": "plain", "name": "Plain", "need": {}},
		{"id": "sparks", "name": "Sparks", "need": {"words": 250}},
		{"id": "ripple", "name": "Ripple", "need": {"level": 5}},
		{"id": "ghost", "name": "Afterimage", "need": {"wpm": 55}},
	],
	"attack": [
		{"id": "comet", "name": "Comet", "need": {}},
		{"id": "dart", "name": "Dart", "need": {"level": 2}},
		{"id": "swarm", "name": "Swarm", "need": {"salvos": 5}},
		{"id": "bolt", "name": "Bolt", "need": {"chain": 6}},
	],
	"cursor": [
		{"id": "bar", "name": "Bar", "need": {}},
		{"id": "block", "name": "Block", "need": {"matches": 8}},
		{"id": "pulse", "name": "Pulse", "need": {"level": 7}},
		{"id": "spark", "name": "Ember", "need": {"level": 14}},
	],
	"victory": [
		{"id": "plain", "name": "Plain", "need": {}},
		{"id": "confetti", "name": "Confetti", "need": {"wins": 3}},
		{"id": "rays", "name": "Sunburst", "need": {"wins": 8}},
		{"id": "shatter", "name": "Shatter", "need": {"flawless": 3}},
	],
}


func entries(slot: String) -> Array:
	return COSMETICS.get(slot, [])


func entry(slot: String, id: String) -> Dictionary:
	for e: Dictionary in entries(slot):
		if String(e["id"]) == id:
			return e
	var list: Array = entries(slot)
	return list[0] if not list.is_empty() else {}


## What the player is wearing in a slot, falling back to the first entry if the
## saved one has been renamed away or is not earned yet.
func worn(slot: String) -> String:
	var id := String(equipped.get(slot, ""))
	if id != "" and is_unlocked(slot, id):
		return id
	var list: Array = entries(slot)
	return String(list[0]["id"]) if not list.is_empty() else ""


func equip(slot: String, id: String) -> bool:
	if not is_unlocked(slot, id):
		return false
	equipped[slot] = id
	save()
	changed.emit()
	return true


func is_unlocked(slot: String, id: String) -> bool:
	return meets(entry(slot, id).get("need", {}))


## Where the player currently stands against a requirement, as have/want. The
## mastery screen shows this on locked entries so a lock is a target rather than
## a shrug.
func standing(need: Dictionary) -> Dictionary:
	if need.is_empty():
		return {"have": 1, "want": 1, "what": ""}
	var key := String(need.keys()[0])
	var want := int(need[key])
	var have := 0
	var what := ""
	match key:
		"level": have = level(); what = "reach level %d" % want
		"matches": have = matches; what = "play %d matches" % want
		"wins": have = wins; what = "win %d matches" % want
		"flawless": have = flawless; what = "win %d without losing a life" % want
		"words": have = words; what = "type %d words" % want
		"salvos": have = salvos; what = "land %d salvos" % want
		"wpm": have = int(best_wpm); what = "hit %d wpm" % want
		"chain": have = best_chain; what = "reach a x%d chain" % want
		"combo": have = best_combo; what = "break %d blocks with one word" % want
		"longest": have = longest_word.length(); what = "play a %d-letter word" % want
		_:
			if key.begins_with("power:"):
				var name := key.substr(6)
				have = int(powers.get(name, 0))
				what = "earn %d %s" % [want, name]
	return {"have": have, "want": want, "what": what}


func meets(need: Dictionary) -> bool:
	if need.is_empty():
		return true
	var s := standing(need)
	return int(s["have"]) >= int(s["want"])


## Everything currently earned, as slot -> [ids]. Used to work out what a match
## has just unlocked by diffing against the same call from before it.
func unlocked_set() -> Dictionary:
	var out := {}
	for slot: String in SLOTS:
		var got: Array = []
		for e: Dictionary in entries(slot):
			if meets(e.get("need", {})):
				got.append(String(e["id"]))
		out[slot] = got
	return out


# --------------------------------------------------------------------- recording

## Fold one finished match into the lifetime record. Peaks only move up.
func record_match(r: Dictionary) -> void:
	matches += 1
	if bool(r.get("won", false)):
		wins += 1
		if bool(r.get("flawless", false)):
			flawless += 1
	words += int(r.get("words", 0))
	chars += int(r.get("chars", 0))
	salvos += int(r.get("salvos", 0))
	multi_clears += int(r.get("multi_clears", 0))
	best_wpm = maxf(best_wpm, float(r.get("wpm", 0.0)))
	best_chain = maxi(best_chain, int(r.get("chain", 0)))
	best_combo = maxi(best_combo, int(r.get("combo", 0)))
	best_score = maxi(best_score, int(r.get("score", 0)))
	var lw := String(r.get("longest", ""))
	if lw.length() > longest_word.length():
		longest_word = lw
	for key in r.get("powers", {}):
		powers[key] = int(powers.get(key, 0)) + int(r["powers"][key])
	save()
	changed.emit()


# ------------------------------------------------------------------------ disk
#
# This file is somebody's entire history with the game, so the writing is more
# careful than the amount of data would suggest.
#
# The failure that matters is not "the save was lost", it is "the save was lost
# and then written over". `ConfigFile.save` is not atomic: a crash, a power cut
# or a kill signal partway through leaves a truncated file, and a truncated file
# does not parse. The old code returned quietly when a load failed, leaving every
# field at its default — and the next autosave then replaced a profile we had
# merely failed to *read* with a blank one. That turns a recoverable problem into
# a permanent one.
#
# So: writes go to a temp file and are moved into place, the previous file is
# kept as a backup, a failed load falls back to that backup, and if both are
# unreadable the profile refuses to save at all for the rest of the session
# rather than overwrite something it did not understand.

## Bumped only when the on-disk shape changes in a way that needs migrating.
## Stored so a future version can convert an old file instead of ignoring it.
const SCHEMA := 1

## True when something is on disk that we could not read. Saving stays off while
## this is set, because a profile that cannot be parsed might still be one that
## can be rescued by hand.
var read_failed := false


func _ready() -> void:
	load_profile()


func backup_path() -> String:
	return save_path + ".bak"


func load_profile() -> void:
	read_failed = false
	var main := _read(save_path)
	if main == OK:
		return

	# The backup exists for exactly this: a half-written main file.
	if _read(backup_path()) == OK:
		push_warning("Profile: %s was unreadable; recovered from the backup" % save_path)
		save()
		return

	if main == ERR_FILE_NOT_FOUND:
		return  # A new player. Defaults are correct, and saving is safe.

	read_failed = true
	push_error(("Profile: %s exists but could not be read (%d), and neither could "
		+ "the backup. Saving is disabled this session so the file is left alone "
		+ "— move it somewhere safe if you want it looked at.") % [save_path, main])


## Reads a file into this object. Returns OK, ERR_FILE_NOT_FOUND for a new
## player, or whatever went wrong.
func _read(path: String) -> Error:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		return err
	# Parsing is not the same as being a profile. ConfigFile shrugs at lines it
	# does not recognise, so a file full of rubbish loads "successfully" and then
	# every field falls back to its default — which is the silent reset again,
	# wearing a different hat. A real profile has always written this key.
	if not cfg.has_section_key("record", "matches"):
		return ERR_INVALID_DATA
	matches = int(cfg.get_value("record", "matches", 0))
	wins = int(cfg.get_value("record", "wins", 0))
	flawless = int(cfg.get_value("record", "flawless", 0))
	words = int(cfg.get_value("record", "words", 0))
	chars = int(cfg.get_value("record", "chars", 0))
	salvos = int(cfg.get_value("record", "salvos", 0))
	multi_clears = int(cfg.get_value("record", "multi_clears", 0))
	best_wpm = float(cfg.get_value("record", "best_wpm", 0.0))
	best_chain = int(cfg.get_value("record", "best_chain", 0))
	best_combo = int(cfg.get_value("record", "best_combo", 0))
	best_score = int(cfg.get_value("record", "best_score", 0))
	longest_word = String(cfg.get_value("record", "longest_word", ""))
	powers = cfg.get_value("record", "powers", {})
	equipped = cfg.get_value("worn", "equipped", {})
	prefs = cfg.get_value("worn", "prefs", {})
	return OK


func save() -> void:
	if read_failed:
		return

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "schema", SCHEMA)
	cfg.set_value("record", "matches", matches)
	cfg.set_value("record", "wins", wins)
	cfg.set_value("record", "flawless", flawless)
	cfg.set_value("record", "words", words)
	cfg.set_value("record", "chars", chars)
	cfg.set_value("record", "salvos", salvos)
	cfg.set_value("record", "multi_clears", multi_clears)
	cfg.set_value("record", "best_wpm", best_wpm)
	cfg.set_value("record", "best_chain", best_chain)
	cfg.set_value("record", "best_combo", best_combo)
	cfg.set_value("record", "best_score", best_score)
	cfg.set_value("record", "longest_word", longest_word)
	cfg.set_value("record", "powers", powers)
	cfg.set_value("worn", "equipped", equipped)
	cfg.set_value("worn", "prefs", prefs)

	# Written whole, somewhere else, before anything existing is touched.
	var tmp := save_path + ".tmp"
	if cfg.save(tmp) != OK:
		push_error("Profile: could not write %s — leaving the old save alone" % tmp)
		return

	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return
	var main := save_path.get_file()
	var back := backup_path().get_file()
	if dir.file_exists(main):
		dir.remove(back)
		dir.rename(main, back)
	dir.rename(tmp.get_file(), main)


## The name to show alongside yours, or "" if none is worn.
func title_text() -> String:
	var id := worn("title")
	if id == "" or id == "none":
		return ""
	return String(entry("title", id).get("name", ""))
