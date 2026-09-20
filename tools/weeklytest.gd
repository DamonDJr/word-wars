extends SceneTree
## What the weekly missions promise, and the three ways that promise breaks.
##
## The set has to be the same four on every phone in the world for a given week.
## It has to change on Sunday and on no other day. And a mission has to be
## payable exactly once — a run that finishes one must not be able to finish it
## again, because the payout is XP and XP is the level ladder.
##
## None of those can be checked against `now`: a suite that reads the clock
## passes on a Tuesday and is untested on a Sunday. Everything below is run
## against fixed timestamps instead, which is also what makes the "two machines
## agree" claim testable at all.
##
##   godot --headless --script tools/weeklytest.gd

var fails := 0
var P: Node
const SECTIONS := 7
var done := 0


func _init() -> void:
	await process_frame
	P = get_root().get_node("Profile")
	# First, before anything touches `owned` or `prefs`. `set_pref` and the
	# recorders below all call `save()`, and a suite that poses a profile
	# without redirecting writes the pose into whoever's save is on this
	# machine. See the note in `shoptest.gd`.
	P.save_path = "user://profile-weekly-test.cfg"
	P.weekly = {}
	P.weekly_xp = 0
	P.weekly_cleared = 0

	_the_week_starts_on_sunday()
	_the_set_is_a_function_of_the_week()
	_a_week_asks_four_different_things()
	_counts_add_and_peaks_do_not()
	_a_mission_pays_once()
	_clearing_the_week_is_recorded()
	_every_mission_can_actually_be_finished()

	if done != SECTIONS:
		fails += 1
		print("!! %d of %d sections ran — one died on its first line" % [
			done, SECTIONS])
	print("--- %s ---" % ("weeklies behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## Every day of one week maps to the same Sunday, and the next day does not.
##
## Run over a fixed fortnight rather than off the clock. 2026-09-20 is a Sunday;
## the week it starts runs to 2026-09-26, and 2026-09-27 is the next one.
func _the_week_starts_on_sunday() -> void:
	print("--- the week rolls on Sunday ---")
	# Noon, so a timezone offset of up to twelve hours either way cannot push a
	# date over a boundary and make this suite depend on where it is run.
	var sunday := _at(2026, 9, 20)
	for d in 7:
		var key: String = Missions.week_key_at(sunday + d * 86400)
		_expect("day %d of the week keys to the Sunday (%s)" % [d, key],
			key == "2026-09-20")
	_expect("and the next Sunday starts a new one",
		Missions.week_key_at(sunday + 7 * 86400) == "2026-09-27")
	_expect("as does the Saturday before, backwards",
		Missions.week_key_at(sunday - 86400) == "2026-09-13")
	_expect("next_week walks forward a week",
		Missions.next_week("2026-09-20") == "2026-09-27")
	# Across a month boundary, which is where hand-rolled date arithmetic dies.
	_expect("and across the end of a month",
		Missions.next_week("2026-09-27") == "2026-10-04")
	# And across a year boundary.
	_expect("and across the end of a year",
		Missions.next_week("2026-12-27") == "2027-01-03")
	done += 1


## The claim the whole design rests on: two machines with no connection between
## them deal the same four missions.
##
## Proved by dealing the same week repeatedly with the global generators
## deliberately disturbed in between — which is what a machine that has just
## played a daily board looks like.
func _the_set_is_a_function_of_the_week() -> void:
	print("--- the set is a pure function of the week ---")
	var first: Array = Missions.for_week("2026-09-20")
	for i in 6:
		seed(i * 7717)
		randi()
		var WB := get_root().get_node("WordBank")
		WB.rng.seed = i * 31337
		WB.rng.randi()
		var again: Array = Missions.for_week("2026-09-20")
		var same := again.size() == first.size()
		if same:
			for n in first.size():
				var a: Dictionary = first[n]
				var b: Dictionary = again[n]
				if String(a["id"]) != String(b["id"]) \
						or int(a["target"]) != int(b["target"]):
					same = false
					break
		_expect("deal %d matches the first, whatever the RNG was doing" % i, same)

	# And a different week is a different set, or the seed is doing nothing.
	var other: Array = Missions.for_week("2026-09-27")
	var differs := false
	for n in first.size():
		if String((first[n] as Dictionary)["id"]) \
				!= String((other[n] as Dictionary)["id"]):
			differs = true
	_expect("and the following week is not the same set", differs)
	done += 1


func _a_week_asks_four_different_things() -> void:
	print("--- a week asks four different things ---")
	# Several weeks, because "no duplicates" is a property of the shuffle and a
	# single sample can pass by luck.
	var key := "2026-01-04"
	for w in 12:
		var set: Array = Missions.for_week(key)
		_expect_quiet(set.size() == Missions.PER_WEEK)
		var seen := {}
		var dupe := false
		for m: Dictionary in set:
			if seen.has(String(m["id"])):
				dupe = true
			seen[String(m["id"])] = true
		if dupe:
			_expect("week %s has no repeated mission" % key, false)
		# Every target has to be one the catalogue actually offers, or a tier
		# table could be edited to nothing and this would never notice.
		for m: Dictionary in set:
			var e: Dictionary = Missions.entry(String(m["id"]))
			_expect_quiet((e.get("tiers", []) as Array).has(int(m["target"])))
		key = Missions.next_week(key)
	_expect("twelve weeks all deal four distinct, valid missions", true)
	done += 1


## The two kinds of progress move differently, and getting them the wrong way
## round is silent: a peak that accumulated would finish "reach a x9 chain" on
## nine separate x1 chains.
func _counts_add_and_peaks_do_not() -> void:
	print("--- counts add, peaks take the best ---")
	var key := "2026-04-05"
	P.weekly = {}
	P.weekly_xp = 0

	P.note_mission_progress(key, "words", 100)
	P.note_mission_progress(key, "words", 50)
	_expect("a count adds up", P.weekly_progress(key, "words") == 150)

	P.note_mission_progress(key, "chain", 4)
	P.note_mission_progress(key, "chain", 7)
	_expect("a peak takes the better", P.weekly_progress(key, "chain") == 7)
	P.note_mission_progress(key, "chain", 3)
	_expect("and does not fall back down", P.weekly_progress(key, "chain") == 7)

	# Zero and negative are no-ops. A run with no salvos must not be able to
	# move a salvo mission, and nothing should ever be able to move one back.
	P.note_mission_progress(key, "words", 0)
	P.note_mission_progress(key, "words", -40)
	_expect("nothing moves on a zero or a negative",
		P.weekly_progress(key, "words") == 150)
	done += 1


## The one that costs real money if it is wrong: XP is the level ladder, and a
## mission that paid on every subsequent word typed would hand out levels.
func _a_mission_pays_once() -> void:
	print("--- a finished mission pays exactly once ---")
	var key := "2026-05-03"
	P.weekly = {}
	P.weekly_xp = 0
	P.weekly_cleared = 0

	# Take whatever this week actually asks for and finish its first mission,
	# rather than assuming a particular one is in the set.
	var set: Array = Missions.for_week(key)
	var first: Dictionary = set[0]
	var metric := String(first["metric"])
	var target := int(first["target"])

	var paid: int = int(P.note_mission_progress(key, metric, target))
	_expect("finishing one pays %d" % Missions.MISSION_XP,
		paid == Missions.MISSION_XP)
	_expect("and it is banked", P.weekly_xp == Missions.MISSION_XP)

	var again: int = int(P.note_mission_progress(key, metric, target * 4))
	_expect("overshooting it pays nothing more", again == 0)
	_expect("and the bank has not moved", P.weekly_xp == Missions.MISSION_XP)

	# The bar stops at the target rather than running past it.
	var state: Array = P.weekly_state(key)
	for m: Dictionary in state:
		if String(m["id"]) == String(first["id"]):
			_expect("the bar caps at the target", int(m["have"]) == target)
			_expect("and it reads as done", bool(m["done"]))

	# Mission XP reaches the level, or the payout is a number on a screen.
	var before: int = P.xp_total()
	P.note_mission_progress(key, String((set[1] as Dictionary)["metric"]),
		int((set[1] as Dictionary)["target"]))
	_expect("mission XP lands in the total",
		P.xp_total() == before + Missions.MISSION_XP)
	done += 1


func _clearing_the_week_is_recorded() -> void:
	print("--- clearing all four is recorded once ---")
	var key := "2026-06-07"
	P.weekly = {}
	P.weekly_xp = 0
	P.weekly_cleared = 0

	for m: Dictionary in Missions.for_week(key):
		P.note_mission_progress(key, String(m["metric"]), int(m["target"]))
	_expect("all four are done",
		P.weekly_done_count(key) == Missions.PER_WEEK)
	_expect("the week counts as cleared once", P.weekly_cleared == 1)
	_expect("and paid four times",
		P.weekly_xp == Missions.PER_WEEK * Missions.MISSION_XP)

	# Piling more on top must not clear it twice.
	for m: Dictionary in Missions.for_week(key):
		P.note_mission_progress(key, String(m["metric"]), int(m["target"]) * 3)
	_expect("and cannot be cleared twice", P.weekly_cleared == 1)
	_expect("nor paid twice",
		P.weekly_xp == Missions.PER_WEEK * Missions.MISSION_XP)

	# A new week starts from nothing without anything having to reset it.
	var next := Missions.next_week(key)
	_expect("next week starts empty", P.weekly_done_count(next) == 0)
	_expect("and last week is still on file",
		P.weekly_done_count(key) == Missions.PER_WEEK)
	done += 1


## Every metric the catalogue asks about has to be one the game reports, and
## every metric the game reports has to be one something asks about.
##
## This is the check that stops a mission being unfinishable. `record_week` is
## the single door every mode goes through, so the metrics it emits *are* the
## set the game can report — and a catalogue entry naming anything else is a
## mission that would sit at zero forever while the player wondered why.
func _every_mission_can_actually_be_finished() -> void:
	print("--- every mission is reachable ---")
	var key := "2026-07-05"
	P.weekly = {}
	P.weekly_xp = 0

	# One run carrying a value for everything a mode can report, pushed through
	# the real door rather than through `note_mission_progress` directly.
	var fat := {
		"won": true, "flawless": true, "words": 9999, "salvos": 999,
		"multi_clears": 999, "chain": 99, "combo": 99, "wpm": 999.0,
		"score": 999999, "longest": "ANTIDISESTABLISHMENTARIANISM",
		"seconds": 9999.0,
	}
	# Every mode's own contribution, so the per-mode metrics are covered too.
	for what in ["matches", "dailies", "survivals"]:
		P.record_week(key, fat, String(what))

	for metric: String in Missions.metrics():
		_expect("%s is something a run can report" % metric,
			P.weekly_progress(key, metric) > 0)

	# And the other direction: every week this catalogue can deal has to be
	# finishable by playing.
	#
	# A count mission wants the thing to happen N times, so one fat run cannot
	# clear "play 15 matches" however fat it is — the run is repeated enough
	# times to cover the largest tier in the table. That number is derived
	# rather than written down, so raising a tier cannot silently outrun it.
	var most := 1
	for m: Dictionary in Missions.CATALOGUE:
		if String(m["kind"]) == "count":
			for tier in (m["tiers"] as Array):
				most = maxi(most, int(tier))

	var walk := "2026-01-04"
	var stuck: Array = []
	for w in 8:
		P.weekly = {}
		P.weekly_xp = 0
		for n in most:
			# Every mode, because "play 5 survival runs" and "finish 5 dailies"
			# are only reachable through their own door.
			P.record_week(walk, fat, "matches")
			P.record_week(walk, fat, "dailies")
			P.record_week(walk, fat, "survivals")
			if P.weekly_done_count(walk) >= Missions.PER_WEEK:
				break
		if P.weekly_done_count(walk) < Missions.PER_WEEK:
			for m: Dictionary in P.weekly_state(walk):
				if not bool(m["done"]) and not stuck.has(String(m["id"])):
					stuck.append(String(m["id"]))
		walk = Missions.next_week(walk)
	_expect("eight weeks are all completable by playing (%s)" % (
		"none stuck" if stuck.is_empty() else ", ".join(stuck)), stuck.is_empty())
	done += 1


func _at(y: int, m: int, d: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": y, "month": m, "day": d,
		"hour": 12, "minute": 0, "second": 0}))


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-56s %s" % [what, "ok" if ok else "FAILED"])


## For assertions inside a loop that would otherwise print two hundred lines.
## Counts a failure but says nothing; the loop prints one summary line after.
func _expect_quiet(ok: bool) -> void:
	if not ok:
		fails += 1
