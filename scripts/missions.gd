extends RefCounted
class_name Missions
## The weekly set: four jobs, chosen by the week rather than by anybody, that
## reset every Sunday.
##
## Kept apart from `Profile` for the same reason `Cosmetics` is. One is a save
## file that has to stay readable across versions; this is a balance table that
## will get fiddled with constantly, and a target being retuned must never be
## able to break somebody's save.
##
## ## Why the week is a seed and not a download
##
## Exactly the trick the daily board uses. There is no server behind this game
## and there is not going to be one, so "everybody gets the same four missions"
## has to be something two phones can work out independently. They both compute
## the Sunday that starts the current week, hash it, and deal from the same
## table in the same order — so two players comparing notes on Wednesday are
## looking at the same four jobs, and nothing had to be fetched for that to be
## true.
##
## The consequence worth knowing is the same one the daily has: a player who
## moves their device clock forward gets next week's missions early. That is
## accepted. The prize is XP, which is already a pure function of their own
## record, and building a server to stop somebody cheating themselves out of a
## week of play would be the tail wagging the dog.


## How many run at once. Four is a set somebody can hold in their head and still
## have one of them be a stretch; six turns the screen into a chore list.
const PER_WEEK := 4

## What a week's missions are worth. Paid per mission as it completes rather
## than as a lump at the end, so a week somebody only half finishes still pays
## for the half they did.
##
## Scaled against the rest of the ladder: `XP["match"]` is 90 and `XP["win"]`
## is 240, so a mission is worth a few matches and a full week of four is worth
## a solid evening. Enough to notice on the level bar, not enough that missions
## become the only sensible way to play.
const MISSION_XP := 300


## Every job the week can ask for.
##
## `metric` is the name this mission counts, and it is the contract with
## `Profile.note_mission_progress` — a metric nothing ever reports is a mission
## that can never be finished, which is why `weeklytest` walks this table and
## checks every one of them against the list the recorders actually emit.
##
## `kind` is how the number moves:
##
##   "count"  adds up across the week. Play ten matches, type four hundred
##            words. Progress is the running total.
##   "peak"   the best single result in the week. Reach a x7 chain, hit 60wpm.
##            Progress is the highest one seen, because doing it twice is not
##            more impressive than doing it once.
##
## `tiers` are the targets the seed picks between, easiest first. Having three
## rather than one is most of what keeps a week from feeling like the last one:
## the same mission at a different number is a different evening.
const CATALOGUE := [
	{"id": "words", "kind": "count", "metric": "words",
		"tiers": [250, 400, 600], "text": "Type %d words"},
	{"id": "matches", "kind": "count", "metric": "matches",
		"tiers": [6, 10, 15], "text": "Play %d matches"},
	{"id": "wins", "kind": "count", "metric": "wins",
		"tiers": [3, 5, 8], "text": "Win %d matches"},
	{"id": "salvos", "kind": "count", "metric": "salvos",
		"tiers": [8, 14, 22], "text": "Land %d salvos"},
	{"id": "multi", "kind": "count", "metric": "multi_clears",
		"tiers": [10, 18, 28], "text": "Break 3+ blocks with one word %d times"},
	{"id": "dailies", "kind": "count", "metric": "dailies",
		"tiers": [3, 5, 7], "text": "Finish %d daily boards"},
	{"id": "survivals", "kind": "count", "metric": "survivals",
		"tiers": [3, 5, 8], "text": "Play %d survival runs"},
	{"id": "flawless", "kind": "count", "metric": "flawless",
		"tiers": [1, 2, 4], "text": "Win %d without losing a life"},
	{"id": "chain", "kind": "peak", "metric": "chain",
		"tiers": [5, 7, 9], "text": "Reach a x%d chain"},
	{"id": "combo", "kind": "peak", "metric": "combo",
		"tiers": [3, 4, 5], "text": "Break %d blocks with a single word"},
	{"id": "wpm", "kind": "peak", "metric": "wpm",
		"tiers": [35, 45, 55], "text": "Finish a run at %d wpm"},
	{"id": "longest", "kind": "peak", "metric": "longest",
		"tiers": [9, 11, 13], "text": "Play a %d-letter word"},
	{"id": "survive", "kind": "peak", "metric": "survive_seconds",
		"tiers": [120, 210, 300], "text": "Last %d seconds in survival"},
	{"id": "score", "kind": "peak", "metric": "score",
		"tiers": [9000, 15000, 24000], "text": "Score %d in a single run"},
]


## Every metric the catalogue can ask about. `weeklytest` holds this against
## what the recorders emit, in both directions — a metric nothing reports is an
## unfinishable mission, and a metric nothing asks for is a line of recording
## that does nothing.
static func metrics() -> Array:
	var out: Array = []
	for m: Dictionary in CATALOGUE:
		var name := String(m["metric"])
		if not out.has(name):
			out.append(name)
	return out


static func entry(id: String) -> Dictionary:
	for m: Dictionary in CATALOGUE:
		if String(m["id"]) == id:
			return m
	return {}


# ------------------------------------------------------------------- the week

## The Sunday that starts the week `unix` falls in, as "YYYY-MM-DD".
##
## Local time, like `daily_key`, and for the same reason: the day it is where
## the player is standing is the day they think it is, and a board that rolls
## over at what their phone calls seven in the evening is a board that is wrong.
## The cost is that two players in different zones change week at different
## moments, which is the same small untidiness the daily already carries and
## which nobody has ever noticed.
##
## Sunday because `Time`'s weekday is 0 for Sunday, so the arithmetic is a
## subtraction rather than a table.
static func week_key_at(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	var back := int(d["weekday"])
	var sunday := unix - back * 86400
	var s := Time.get_datetime_dict_from_unix_time(sunday)
	return "%04d-%02d-%02d" % [int(s["year"]), int(s["month"]), int(s["day"])]


## The current week, off the local clock.
##
## `get_unix_time_from_system` is UTC, and feeding it to a local-time reader
## would put anybody west of Greenwich on the wrong week for part of Saturday
## night. The offset is added first so the arithmetic above happens in the
## player's own day.
static func week_key() -> String:
	return week_key_at(int(Time.get_unix_time_from_system())
		+ int(Time.get_time_zone_from_system().get("bias", 0)) * 60)


## The Sunday after `key`, for "resets in" and for walking weeks in a test.
static func next_week(key: String) -> String:
	var parts := key.split("-")
	if parts.size() != 3:
		return key
	var at := int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 12, "minute": 0, "second": 0}))
	return week_key_at(at + 7 * 86400)


## Seconds until this week's set is replaced, for the countdown on the screen.
static func seconds_left(key: String) -> float:
	var parts := next_week(key).split("-")
	if parts.size() != 3:
		return 0.0
	var midnight := Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]),
		"hour": 0, "minute": 0, "second": 0})
	var now := int(Time.get_unix_time_from_system()) \
		+ int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return maxf(0.0, float(midnight) - float(now))


## Hashed rather than used raw, exactly as the daily is: consecutive Sundays are
## consecutive integers and consecutive seeds deal recognisably similar sets.
static func seed_for(key: String) -> int:
	return hash("wordwars-weekly-" + key)


## The four missions for a week, as `{"id", "target", "kind", "metric", "text"}`.
##
## Dealt with a local generator rather than the global one. `WordBank.rng` is
## the daily board's and is reseeded by every run; `randi` is whatever the last
## thing to touch it left behind. Either would make this function answer
## differently depending on what the player had just done, which for something
## every phone has to agree on is the one thing it may not do.
static func for_week(key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(key)

	# Drawn without replacement, so a week cannot ask for the same job twice
	# with two different numbers on it.
	var pool: Array = []
	for i in CATALOGUE.size():
		pool.append(i)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp

	var out: Array = []
	for n in mini(PER_WEEK, pool.size()):
		var m: Dictionary = CATALOGUE[pool[n]]
		var tiers: Array = m["tiers"]
		var target: int = int(tiers[rng.randi_range(0, tiers.size() - 1)])
		out.append({
			"id": String(m["id"]),
			"kind": String(m["kind"]),
			"metric": String(m["metric"]),
			"target": target,
			"text": String(m["text"]) % target,
		})
	return out
