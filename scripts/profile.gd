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

# ------------------------------------------------------------------ purchases
#
# What has been bought, as a set of pack ids. Kept as its own thing rather than
# as another unlock rule because it is not earned and never will be: no amount
# of play reaches it, and no change to the XP formula should ever hand it out by
# accident.
#
# There is no store here yet. `grant` is what a real purchase callback would
# call once a receipt validated, and the test button in settings calls the same
# function — so the thing being tested is the thing that will ship.

const PACK_PREMIUM := "premium"

var owned: Dictionary = {}
## Matches played since the last ad break. Counted here rather than in the match
## so it survives a restart — otherwise quitting to the title is a way to never
## see one.
var since_ad := 0

## How many matches this gap is worth, rolled fresh after every break.
##
## A number rather than a constant, because a break that lands on exactly every
## third match is a rhythm players learn to feel coming — and the match they
## learn to feel it on is the one they stop before. Three to five, rolled once
## per gap, is frequent enough to be worth selling against and irregular enough
## not to be counted.
##
## Saved alongside the counter. A gap re-rolled at every launch would let a
## restart shop for a longer one, which is the same hole as counting matches in
## the match rather than here.
var ad_gap := 0

const ADS_EVERY_MIN := 3
const ADS_EVERY_MAX := 5


## The next gap. Inclusive of both ends, so five is as reachable as three.
func roll_ad_gap() -> void:
	ad_gap = randi_range(ADS_EVERY_MIN, ADS_EVERY_MAX)


## Whether a break is due. Asked at the end of a match, before the summary is
## left, so the answer is about the match that just finished.
func ad_due() -> bool:
	if ads_removed():
		return false
	# A profile written before gaps existed, or a brand new one, has never rolled
	# one. Done here rather than at load so there is exactly one place that can
	# leave `ad_gap` at zero — and zero would make every match a break.
	if ad_gap <= 0:
		roll_ad_gap()
	return since_ad >= ad_gap


func note_match_for_ads() -> void:
	if ads_removed():
		return
	since_ad += 1
	save()


func clear_ad() -> void:
	since_ad = 0
	roll_ad_gap()
	save()


func owns(pack: String) -> bool:
	return bool(owned.get(pack, false))


## Ads are the other half of the pack. Nothing here shows one — this is the flag
## the ad break asks before it decides to exist.
func ads_removed() -> bool:
	return owns(PACK_PREMIUM)


## Hand over a pack. Idempotent, because a restore-purchases flow will call it
## again for something already owned and that must not be an error.
func grant(pack: String) -> void:
	if owns(pack):
		return
	owned[pack] = true
	save()
	changed.emit()


## For testing the flow more than once.
func revoke(pack: String) -> void:
	if not owns(pack):
		return
	owned.erase(pack)
	# Anything worn from that pack has to come off, or a revoked purchase stays
	# on screen until something else happens to re-equip.
	for slot: String in SLOTS:
		var id := String(equipped.get(slot, ""))
		if id != "" and not is_unlocked(slot, id):
			equipped.erase(slot)
	save()
	changed.emit()

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
	## Set once the tutorial has been finished, so the game only nags once.
	"taught": false,
	## Set the first time the game opens the tutorial by itself. Separate from
	## `taught` on purpose: a first-time player who backs out of the lesson has
	## answered the offer, and re-offering it on every launch would be a loop
	## they cannot leave. Offered once, then the title screen's own nag takes
	## over — which is a plate they can choose rather than a screen they land in.
	"tutorial_offered": false,
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
		{"id": "founder", "name": "FOUNDER", "need": {"buy": PACK_PREMIUM}},
	],
	"theme": [
		{"id": "midnight", "name": "Midnight", "need": {}},
		{"id": "ember", "name": "Ember", "need": {"level": 3}},
		{"id": "chlorophyll", "name": "Chlorophyll", "need": {"level": 6}},
		{"id": "vapor", "name": "Vapour", "need": {"level": 10}},
		{"id": "bone", "name": "Bone", "need": {"level": 16}},
		{"id": "prism", "name": "Prism", "need": {"buy": PACK_PREMIUM}},
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
		{"id": "supernova", "name": "Supernova", "need": {"buy": PACK_PREMIUM}},
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
		"buy":
			# `want` is unused here; owning it is the whole test.
			have = 1 if owns(String(need[key])) else 0
			want = 1
			what = "in the premium pack"
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
##
## 2: the premium pack stopped being something a button in Settings could hand
##    out. Saves written before that may carry a grant nobody paid for, and one
##    of the things it buys is silence from the ad break — so a forgotten test
##    tap reads, forever after, as a game whose ads are broken. See `_migrate`.
## 3: the daily streak stopped being stored and started being counted from the
##    history. The number that used to be on disk was the live streak; there is
##    now a best-streak record instead, and the old value is the only evidence
##    of it that an existing save carries.
const SCHEMA := 3

## The streak an older file had on disk, held between `_read` and `_migrate`.
## Nothing outside those two should look at it — after a migration it is a number
## about a schema that no longer exists.
var _legacy_streak := 0

# ---------------------------------------------------------------- the daily
#
# One run a day, and the record of it is what stops a second one. Kept as a map
# of date -> result rather than just "today", so the streak survives and there
# is something to look back at.

## How many days of history to keep. The streak is counted out of this, so it is
## also the longest streak that can be *proved* from the file — see
## `daily_best_streak`, which is what remembers anything longer.
const DAILY_KEPT := 60

## "YYYY-MM-DD" -> {"score", "wpm", "words", "chain"}.
var daily: Dictionary = {}
var daily_best := 0
## The longest run of consecutive days ever put together. Stored rather than
## counted, because the history it happened in gets trimmed away.
var daily_best_streak := 0


## Has today's run already been spent?
func daily_done(key: String) -> bool:
	return daily.has(key)


func daily_result(key: String) -> Dictionary:
	return daily.get(key, {})


## How many days in a row are behind you, as of `today`.
##
## Counted from the history every time it is asked for rather than kept as a
## number that `record_daily` increments. A stored streak is only ever corrected
## by playing, which is exactly the case it needs to be right about: miss three
## days and nothing runs, so the menu went on advertising a five-day streak that
## had been dead since Tuesday. The first thing it did on your return was
## congratulate you on a sixth consecutive day.
##
## A streak survives a day you have not played *yet* — today is still ahead of
## you until midnight — so the count starts at today if it is done and yesterday
## if it is not. Two missed days is a streak of nothing.
func daily_streak(today: String) -> int:
	var at := today
	if not daily.has(at):
		at = _day_before(at)
		if not daily.has(at):
			return 0
	var n := 0
	while daily.has(at) and n <= DAILY_KEPT:
		n += 1
		at = _day_before(at)
		if at == "":
			break
	return n


## Bank a finished run. Refuses to overwrite a day that already has one, so a
## crash, a rematch or a reload cannot buy a second attempt at the same board.
func record_daily(key: String, score: int, wpm: int, words: int, chain: int) -> void:
	if daily.has(key):
		return
	daily[key] = {"score": score, "wpm": wpm, "words": words, "chain": chain}
	daily_best = maxi(daily_best, score)
	# Read back out of the history this run has just joined, so the record and
	# the live count can never be two different opinions.
	daily_best_streak = maxi(daily_best_streak, daily_streak(key))
	# Trim, or a year of play turns the profile into a log file.
	if daily.size() > DAILY_KEPT:
		var keys: Array = daily.keys()
		keys.sort()
		while keys.size() > DAILY_KEPT:
			daily.erase(keys.pop_front())
	save()
	changed.emit()


## Every run on file, best first, for the leaderboard. Ties go to the older run:
## somebody matching a score they set last week has not beaten it.
##
## Each row is the stored result plus the `day` it belongs to, because the board
## needs to say *when* — a column of scores with no dates is not a history, and
## "today" has to be findable in it to be highlighted.
func daily_ranked() -> Array:
	var rows: Array = []
	for day: String in daily:
		var row: Dictionary = (daily[day] as Dictionary).duplicate()
		row["day"] = day
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return String(a["day"]) < String(b["day"]))
	return rows


## Where a day sits on that board, 1-based, or 0 if it was never played.
func daily_rank(key: String) -> int:
	var rows := daily_ranked()
	for i in rows.size():
		if String(rows[i]["day"]) == key:
			return i + 1
	return 0


## The day before a "YYYY-MM-DD", by going through unix time so month and year
## ends are somebody else's problem.
func _day_before(key: String) -> String:
	var bits := key.split("-")
	if bits.size() != 3:
		return ""
	var t := Time.get_unix_time_from_datetime_dict({
		"year": int(bits[0]), "month": int(bits[1]), "day": int(bits[2]),
		"hour": 12, "minute": 0, "second": 0,
	})
	var d := Time.get_datetime_dict_from_unix_time(int(t) - 86400)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

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
	owned = cfg.get_value("shop", "owned", {})
	since_ad = int(cfg.get_value("shop", "since_ad", 0))
	# Clamped rather than trusted. A hand-edited or older file could carry a gap
	# of six hundred, and the only symptom would be ads that never appear again.
	ad_gap = int(cfg.get_value("shop", "ad_gap", 0))
	if ad_gap < ADS_EVERY_MIN or ad_gap > ADS_EVERY_MAX:
		ad_gap = 0
	daily = cfg.get_value("daily", "runs", {})
	daily_best = int(cfg.get_value("daily", "best", 0))
	daily_best_streak = int(cfg.get_value("daily", "best_streak", 0))
	# Schema 2 and older kept the *live* streak here and had no record of the
	# best one. Read into the record: it is the only number in the old file that
	# says anything about a streak, and the alternative is telling somebody who
	# has played forty days running that their best is zero. `_migrate` decides
	# whether to keep it.
	_legacy_streak = int(cfg.get_value("daily", "streak", 0))
	equipped = cfg.get_value("worn", "equipped", {})
	prefs = cfg.get_value("worn", "prefs", {})
	# Last, so everything a migration might have to rewrite has been read first.
	# `equipped` in particular is loaded below `owned`, and dropping a pack means
	# taking off what was worn from it.
	_migrate(int(cfg.get_value("meta", "schema", 1)))
	return OK


## Bring an older file up to the current shape.
##
## Does not save. The next thing to write the profile stamps the new schema and
## the migration stops running; until then it re-runs on every launch, which is
## harmless because every step here has to be idempotent anyway — a half-applied
## migration and a twice-applied one are the same file.
func _migrate(from: int) -> void:
	if from >= SCHEMA:
		return

	# The premium pack used to be reachable from a two-tap test button in
	# Settings. Nobody ever paid for one, so every grant on disk is a tap
	# somebody made while looking at something else — and it silently switches
	# off the ad break, which is exactly how it was found.
	#
	# Written against `owned` directly rather than through `revoke`, which saves
	# and emits `changed` — neither is safe from inside a load, and the second
	# would repaint the board off a profile that is not finished reading itself.
	if from < 2 and owned.has(PACK_PREMIUM):
		owned.erase(PACK_PREMIUM)
		# And take off anything that was only wearable because of it, or a pack
		# that is gone stays on the screen until something re-equips.
		for slot: String in SLOTS:
			var id := String(equipped.get(slot, ""))
			if id != "" and not is_unlocked(slot, id):
				equipped.erase(slot)

	# The streak on an old file was the live one, which means it is a lower bound
	# on the best one and the only evidence the file has. Taken as the record if
	# it beats what the history can prove — a forty-day streak that has since
	# been trimmed out of `daily` is otherwise simply forgotten.
	if from < 3:
		daily_best_streak = maxi(daily_best_streak, _legacy_streak)
		for day: String in daily:
			daily_best_streak = maxi(daily_best_streak, daily_streak(day))


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
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "since_ad", since_ad)
	cfg.set_value("shop", "ad_gap", ad_gap)
	cfg.set_value("daily", "runs", daily)
	cfg.set_value("daily", "best", daily_best)
	cfg.set_value("daily", "best_streak", daily_best_streak)
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
