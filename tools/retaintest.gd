extends SceneTree
## The two things that ask a player for something: the rating prompt and the
## reminders. Neither can run here — both are native plugins — so what is checked
## is the policy in front of them, which is where the whole risk lives.
##
## A rating prompt has a budget of three per year that iOS spends silently and
## never reports on, and a reminder is the one thing this game can do to somebody
## who is not looking at it. Getting either wrong is not a visual bug that gets
## noticed and fixed; it is an uninstall, or a year of asks burnt in an afternoon.
##
## The clock assertions are deliberately relative. A test that pins
## `_seconds_until` to an absolute number passes all morning and fails every
## evening, which is a lesson this project has already paid for once — so what is
## asserted are the invariants that hold at any hour of any day.
##
##   godot --headless --script tools/retaintest.gd

var game: Node
var reviews: Node
var notify: Node
var profile: Node
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-58s %s" % [what, "ok" if ok else "FAILED"])


## Neither plugin exists here, and both must say so rather than half-working.
func _the_seams_are_shut() -> void:
	print("--- with no native plugins behind them ---")
	_expect("reviews report unavailable", not reviews.available())
	_expect("and say why: '%s'" % reviews.why_unavailable(),
		reviews.why_unavailable() != "")
	_expect("notify reports unavailable", not notify.available())
	_expect("and says why: '%s'" % notify.why_unavailable(),
		notify.why_unavailable() != "")

	_expect("nothing is permitted", not notify.permitted())
	_expect("so nothing is enabled", not notify.enabled())
	# These are called from a settings row and a match ending. They must not take
	# the game down when there is nothing behind them.
	notify.refresh()
	notify.set_enabled(true)
	notify.offer_after_daily()
	_expect("refresh, set_enabled and offer survive being called anyway",
		not notify.enabled())
	_expect("and asking for a review is refused", not reviews.allowed())


## The budget, which is the whole of the rating design.
func _the_review_budget_holds() -> void:
	print("--- the rating budget ---")
	profile.set_pref("review_asks", 0)
	profile.set_pref("review_last", 0)

	profile.matches = reviews.MIN_MATCHES - 1
	_expect("a player with %d matches is not asked" % profile.matches,
		not reviews.within_budget())
	profile.matches = reviews.MIN_MATCHES
	_expect("at %d they are" % profile.matches, reviews.within_budget())

	# Apple allows three a year and drops the fourth silently, so a fourth
	# attempt could only ever lose track of how many are left.
	profile.set_pref("review_asks", reviews.MAX_ASKS)
	_expect("one ask over the cap of %d is refused" % reviews.MAX_ASKS,
		not reviews.within_budget())
	profile.set_pref("review_asks", reviews.MAX_ASKS - 1)
	_expect("the last one under it is allowed", reviews.within_budget())

	# Just asked, so not again.
	var now := Time.get_unix_time_from_system()
	profile.set_pref("review_last", now)
	_expect("asking twice in a row is refused", not reviews.within_budget())
	_expect("and days_since_last reads ~0 (%.2f)" % reviews.days_since_last(),
		reviews.days_since_last() < 1.0)

	# One day short of the gap, then one day past it.
	var day := 86400.0
	profile.set_pref("review_last", now - (reviews.MIN_DAYS_BETWEEN - 1.0) * day)
	_expect("a day short of the gap is refused", not reviews.within_budget())
	profile.set_pref("review_last", now - (reviews.MIN_DAYS_BETWEEN + 1.0) * day)
	_expect("a day past it is allowed", reviews.within_budget())

	# A profile that has never been asked must not read as "asked at the epoch",
	# which would be true for any gap and is the classic zero-timestamp bug.
	profile.set_pref("review_last", 0)
	_expect("a never-asked profile is allowed", reviews.within_budget())
	_expect("and reports a large gap rather than 1970",
		reviews.days_since_last() > 1000.0)

	profile.set_pref("review_asks", 0)
	profile.set_pref("review_last", 0)


## The clock, asserted only through things that are true at every hour.
func _the_reminder_clock_is_local() -> void:
	print("--- when a reminder would land ---")
	var h: int = notify.DAILY_HOUR
	var today: int = notify._seconds_until(h, 0)
	var tomorrow: int = notify._seconds_until(h, 1)

	_expect("tomorrow at %02d:00 is always still ahead (%ds)" % [h, tomorrow],
		tomorrow > 0)
	_expect("and is exactly a day past today's (%d - %d)" % [tomorrow, today],
		tomorrow - today == notify.SECONDS_PER_DAY)
	_expect("tomorrow is inside 48 hours", tomorrow < 2 * notify.SECONDS_PER_DAY)
	# The streak warning is sent only when it is still ahead — `refresh` checks
	# for a positive wait — so an evening hour that has passed must go negative
	# rather than wrapping round to tomorrow.
	var s: int = notify._seconds_until(notify.STREAK_HOUR, 0)
	_expect("the evening warning is within a day either way (%ds)" % s,
		s > -notify.SECONDS_PER_DAY and s < notify.SECONDS_PER_DAY)
	# Midnight is the board's own boundary and must always be ahead of now,
	# because that is what decides whether a late warning is still worth sending.
	var midnight: int = notify._seconds_until(24, 0)
	_expect("midnight is always still ahead (%ds)" % midnight, midnight > 0)
	_expect("and never more than a day away",
		midnight <= notify.SECONDS_PER_DAY)

	# The board rolls at local midnight — `daily_key` reads the clock with UTC
	# off — so the reminder has to be computed the same way or it arrives at the
	# wrong end of the day for most of the world.
	_expect("notify's day key matches the game's", notify._today_key()
		== game.daily_key())


## The settings row may only be offered where it could do something.
func _the_switch_is_honest() -> void:
	print("--- the settings row ---")
	game.phase = game.Phase.SETTINGS
	var keys: PackedStringArray = []
	for row: Dictionary in game._settings_rows():
		keys.append(String(row["action"]))
	_expect("no reminders row without the plugin (%s)" % ", ".join(keys),
		not keys.has("set:notify"))


func _init() -> void:
	await process_frame
	reviews = root.get_node("Reviews")
	notify = root.get_node("Notify")
	profile = root.get_node("Profile")
	game = load("res://scenes/main.tscn").instantiate()
	var stage := SubViewport.new()
	stage.size = Vector2i(1280, 720)
	root.add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame

	_the_seams_are_shut()
	_the_review_budget_holds()
	_the_reminder_clock_is_local()
	_the_switch_is_honest()

	print("--- %s ---" % ("retention holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
