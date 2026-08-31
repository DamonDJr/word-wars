extends SceneTree
## Survival, and the ad cadence it forced open.
##
## The mode itself is the daily with the clock taken off, so most of what could
## break here is a branch that says `Mode.DAILY` where it means "a run alone" —
## the seat count, the solo scoring, the life that ends a run. Those are checked
## by playing one rather than by reading the source.
##
## The cadence is the part with teeth. Counting matches was the whole rule, and
## survival is one match that can run for half an hour: a player who only plays
## this mode would see one break a session. So there are two budgets now, spent
## in parallel, and the failure modes are (a) a long run that is never charged,
## (b) the same seconds charged twice, and (c) the match count quietly changing
## under normal play, which is tuned and shipping. All three are checked.
##
##   godot --headless --script tools/survivaltest.gd

const SCRATCH := "user://profile-survival-test.cfg"

var game: Node
var P: Node
## Autoload globals are not bound at compile time in a `--script` run, so the
## singletons are fetched off the root — the same way every suite here does it.
var WB: Node
var fails := 0


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	P = get_root().get_node("Profile")
	WB = get_root().get_node("WordBank")
	P.save_path = SCRATCH
	_wipe()

	_the_door_opens()
	_it_is_a_run_alone()
	_it_opens_calm_and_gets_worse()
	_three_top_outs_end_it()
	_a_run_banks_itself()
	_a_stub_of_a_run_banks_nothing()
	_the_summary_has_a_way_back_in()
	_the_budget_is_time_as_well_as_matches()
	_a_run_pays_as_it_goes()
	_a_break_stops_the_run_under_it()
	_premium_asks_for_nothing()
	_normal_play_is_untouched()

	_erase(SCRATCH)
	print("--- %s ---" % ("survival behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## A mode nobody can reach is not a mode. The plate has to be on the title
## screen, it has to be clickable where it is drawn, and the action behind it has
## to start a run — three separate things, and a new door can fail any of them
## while the other two look fine.
func _the_door_opens() -> void:
	print("--- the door ---")
	game.phase = game.Phase.TITLE

	var plate: Dictionary = {}
	for b: Dictionary in game._title_plates():
		if String(b.get("action", "")) == "survival":
			plate = b
	_expect("there is a survival plate on the title", not plate.is_empty())
	if not plate.is_empty():
		_expect("it is in the PLAY band", int(plate.get("band", -1)) == 1)
		# Hit-tested where it is drawn, which is the failure a new plate actually
		# has: the list that draws them and the list that answers a tap are the
		# same list, right up until one of them is filtered and the other is not.
		var r: Rect2 = plate["rect"]
		_expect("and a tap in the middle of it finds it",
			game._action_at(r.get_center()) == "survival")

	# The action itself, which is what both the plate and the summary's Again
	# button come down to.
	game._activate("survival")
	_expect("the door starts a survival run", game.mode == game.Mode.SURVIVAL)
	_expect("and puts it on the countdown", game.phase == game.Phase.COUNTDOWN)

	# The desktop shortcut, from the title screen it belongs to.
	game.phase = game.Phase.TITLE
	game.mode = game.Mode.NORMAL
	_press(KEY_S, "s")
	_expect("S opens it too", game.mode == game.Mode.SURVIVAL)


## One board, nobody on it but you, and nothing you fire goes anywhere.
func _it_is_a_run_alone() -> void:
	print("--- a run alone ---")
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY

	_expect("one seat is in the match", game.slots_in_play == 1)
	var others := 0
	for s in game.sides:
		if s.slot > 0 and s.in_match:
			others += 1
	_expect("and no second board is in it", others == 0)
	_expect("there is no bot", game.sides[1].bot == null)
	_expect("the summary would list one row", game._scoreboard_sides().size() == 1)
	_expect("the mode knows it is solo", game.solo_run())
	_expect("and knows it is a single board", game.single_board())
	# The daily's promise, which survival must not accidentally inherit: this one
	# is dealt fresh every time, so it must not be running off the seeded
	# generator that makes two machines agree. Fixed to a known seed first, so
	# "it changed" is evidence rather than a coincidence.
	WB.seed_run(4242)
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	_expect("it is dealt fresh, not from the daily's seed", WB.rng.seed != 4242)


## Empty at the start, unplayable at the end. The ramp is the whole design.
func _it_opens_calm_and_gets_worse() -> void:
	print("--- the ramp ---")
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY

	_expect("it opens on an empty board", game.player.board.blocks.is_empty())
	_expect("and opens calmer than the daily",
		game.SURVIVAL_PRESSURE_START > game.DAILY_PRESSURE_START)
	_expect("but closes harder than it",
		game.SURVIVAL_PRESSURE_MIN < game.DAILY_PRESSURE_MIN)

	# Run ten minutes of clock past it with nobody typing. The board is emptied
	# every step so a top-out cannot cut the count short.
	var step := 1.0 / 60.0
	var seeded := 0
	var to_floor := -1.0
	while game.match_time < 600.0:
		game.match_time += step
		var was: int = game.player.pending.size()
		game._tick_pressure(step)
		seeded += maxi(0, game.player.pending.size() - was)
		game.player.pending.clear()
		if to_floor < 0.0 and game.pressure_interval <= game.SURVIVAL_PRESSURE_MIN:
			to_floor = game.match_time
	_expect("the rate bottoms out where it was told to",
		is_equal_approx(game.pressure_interval, game.SURVIVAL_PRESSURE_MIN))
	print("    reached the floor at %s, dealt %d blocks in ten minutes" % [
		game._survival_clock(to_floor), seeded])
	# Not in the first thirty seconds — nobody should meet the hardest version of
	# this before they have settled into it — and not so late that a run ends
	# before the ramp has finished arriving.
	_expect("the floor is minutes away, not seconds",
		to_floor > 90.0 and to_floor < 300.0)

	# Once the rate is flat, weight is the only thing left to escalate, and it
	# has to keep going or the best players never finish a run.
	game.match_time = 0.0
	var opened: int = game._survival_tier()
	game.match_time = 200.0
	var middle: int = game._survival_tier()
	game.match_time = 900.0
	var late: int = game._survival_tier()
	_expect("it opens on the smallest block there is", opened == 0)
	_expect("gets heavier in the middle", middle > opened)
	_expect("and heavier again past the floor", late > middle)


## Three lives, and the third one is the end of it — there is no other exit.
func _three_top_outs_end_it() -> void:
	print("--- three lives and out ---")
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = 45.0

	game._lose_life(game.player)
	_expect("one top-out costs a life", game.player.lives == game.LIVES - 1)
	_expect("and does not end the run", game.phase == game.Phase.PLAY)
	_expect("the board is wiped", game.player.board.blocks.is_empty())

	game._lose_life(game.player)
	_expect("two does not end it either", game.phase == game.Phase.PLAY)
	game._lose_life(game.player)
	_expect("three does", game.phase == game.Phase.OVER)
	# The clock never rewinds on a life, which is what makes the third one played
	# under conditions the first never saw.
	_expect("and the run's clock was never reset", game.match_time >= 45.0)


## What a finished run is worth, and what it must not touch.
func _a_run_banks_itself() -> void:
	print("--- banking a run ---")
	_wipe()
	var was_xp: int = P.xp_total()

	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = 214.0
	game.player.score = 9600
	game.player.words_played = 58
	game.player.best_chain = 7
	game.player.longest_word = "shipments"
	game._finish_survival()

	_expect("the run is on the record", P.survival_runs == 1)
	_expect("the time is the record", is_equal_approx(P.survival_best_time, 214.0))
	_expect("so is the score", P.survival_best_score == 9600)
	_expect("it moved the level", P.xp_total() > was_xp)
	_expect("words carried into the lifetime total", P.words >= 58)
	_expect("and so did the chain", P.best_chain == 7)
	# The whole reason survival has its own banking function. Every run ends in
	# death, so counting one as a match would file it as a loss — and somebody
	# whose only crime is liking this mode would watch their win rate decay.
	_expect("it did not count as a match", P.matches == 0)
	_expect("and did not count as a loss", P.wins == 0)

	# Beating your own record is the only thing this mode can be won against, so
	# it is what the summary celebrates.
	_expect("taking both records reads as a win", game.winner == "YOU")

	# A worse run afterwards takes nothing and must not lower anything.
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = 60.0
	game.player.score = 100
	game._finish_survival()
	_expect("a worse run is still counted", P.survival_runs == 2)
	_expect("but takes no record", game.winner != "YOU")
	_expect("and leaves the best alone", is_equal_approx(P.survival_best_time, 214.0))
	_expect("both of them", P.survival_best_score == 9600)


## Starting a run and immediately dying is not a run.
func _a_stub_of_a_run_banks_nothing() -> void:
	print("--- a stub of a run ---")
	_wipe()
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = game.SURVIVAL_MIN_RUN - 1.0
	game.player.score = 40
	game._finish_survival()
	_expect("a run under the floor banks nothing", P.survival_runs == 0)
	_expect("and takes no record", P.survival_best_time == 0.0)
	_expect("so it cannot be farmed for levels", P.xp_total() == 0)


## The summary is where a survival player spends the moment they decide whether
## to go again, and the daily's summary — the one this is modelled on — has
## exactly one button on it. Getting the wrong branch would leave survival
## offering a Rematch, which routes into `_solo_lineup` and deals a CPU match:
## a button that says "again" and starts a different mode.
##
## Checked in both orientations, because the summary lays out from the design
## space and a phone's is twice as tall.
func _the_summary_has_a_way_back_in() -> void:
	print("--- the way back in ---")
	for shape: bool in [false, true]:
		var where := "portrait" if shape else "landscape"
		game.portrait = shape
		game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
		game.phase = game.Phase.PLAY
		game.match_time = 120.0
		game._finish_survival()
		_expect("%s: the run ends on the summary" % where,
			game.phase == game.Phase.OVER)

		var acts: PackedStringArray = []
		var rects: Array = []
		for b: Dictionary in game._menu_buttons():
			acts.append(String(b["action"]))
			rects.append(b["rect"])
		_expect("%s: it offers Again and Title" % where,
			acts.has("survival") and acts.has("title"))
		_expect("%s: and nothing else" % where, acts.size() == 2)
		# The one that would be wrong rather than merely missing.
		_expect("%s: it does not offer a rematch" % where, not acts.has("rematch"))

		# Reachable where they are drawn, and not on top of each other.
		var stray := ""
		for i in rects.size():
			var r: Rect2 = rects[i]
			if game._action_at(r.get_center()) != acts[i]:
				stray = acts[i]
			for j in range(i + 1, rects.size()):
				if r.intersects(rects[j] as Rect2):
					stray = "%s overlaps %s" % [acts[i], acts[j]]
		_expect("%s: both are clickable and apart%s" % [
			where, "" if stray == "" else " — " + stray], stray == "")

	game.portrait = false


## Either budget can call a break, and spending one spends both.
func _the_budget_is_time_as_well_as_matches() -> void:
	print("--- two budgets ---")
	_wipe()
	P.clear_ad()
	_expect("a fresh gap is three to five matches",
		P.ad_gap >= P.ADS_EVERY_MIN and P.ad_gap <= P.ADS_EVERY_MAX)
	_expect("and nine to fourteen minutes",
		P.ad_gap_seconds >= P.ADS_MINUTES_MIN * 60.0
		and P.ad_gap_seconds <= P.ADS_MINUTES_MAX * 60.0)
	_expect("nothing is due yet", not P.ad_due())

	# Every save written before the clock budget existed has a match gap it is
	# part-way through and no seconds at all. Filling the missing one in must not
	# re-roll the one that was already there, or the upgrade silently resets
	# where every existing player stands in their own cadence.
	P.ad_gap = 2
	P.ad_gap_seconds = 0.0
	P.since_ad = 0
	P.play_since_ad = 0.0
	var _ignored: bool = P.ad_due()
	_expect("an old save keeps the match gap it was part-way through",
		P.ad_gap == 2)
	_expect("and has the missing clock budget filled in",
		P.ad_gap_seconds >= P.ADS_MINUTES_MIN * 60.0)
	P.clear_ad()

	# The clock alone, with the match count untouched — which is exactly the
	# shape of somebody playing nothing but survival.
	P.note_time_for_ads(P.ad_gap_seconds + 1.0)
	_expect("a long enough run calls a break on time alone", P.ad_due())
	_expect("without any matches having been played", P.since_ad == 0)

	P.clear_ad()
	_expect("the break spends both budgets",
		P.since_ad == 0 and P.play_since_ad == 0.0)
	_expect("and rolls a fresh pair",
		P.ad_gap > 0 and P.ad_gap_seconds > 0.0)

	# And the other way round: short matches trip the count long before four of
	# them add up to nine minutes.
	for i in P.ADS_EVERY_MAX:
		P.note_match_for_ads()
		P.note_time_for_ads(30.0)
	_expect("short matches still call a break on the count", P.ad_due())
	_expect("with the clock nowhere near spent",
		P.play_since_ad < P.ad_gap_seconds)


## A run pays for the time it has used, once, as it uses it.
func _a_run_pays_as_it_goes() -> void:
	print("--- paying as it goes ---")
	_wipe()
	P.clear_ad()
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY

	game.match_time = 100.0
	game._bank_survival_time()
	_expect("the first hundred seconds are charged",
		is_equal_approx(P.play_since_ad, 100.0))

	# The failure this guards: handing over a running total rather than what is
	# owed, so every life re-charges the whole run so far.
	game._bank_survival_time()
	_expect("asking again charges nothing", is_equal_approx(P.play_since_ad, 100.0))

	game.match_time = 260.0
	game._bank_survival_time()
	_expect("only the new time is charged", is_equal_approx(P.play_since_ad, 260.0))

	# Finishing settles the rest of it, and no more than the rest of it.
	game.match_time = 300.0
	game.player.score = 500
	game._finish_survival()
	_expect("finishing settles the remainder",
		is_equal_approx(P.play_since_ad, 300.0))

	# A fresh run starts its meter at zero rather than carrying the last one's.
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	_expect("a new run starts its meter over", game.survival_banked == 0.0)

	# Walking out mid-life must not be a way to play for free. Nothing is banked
	# as a record — that is the price of quitting — but the time is still time.
	P.clear_ad()
	var runs_before: int = P.survival_runs
	var best_before: float = P.survival_best_time
	game.phase = game.Phase.PLAY
	game.match_time = 180.0
	game._activate("leave_match")
	_expect("abandoning a run still pays for the time",
		is_equal_approx(P.play_since_ad, 180.0))
	_expect("but banks no run", P.survival_runs == runs_before)
	_expect("and takes no record", is_equal_approx(P.survival_best_time, best_before))
	_expect("and lands back on the title", game.phase == game.Phase.TITLE)

	_expect("breaks are allowed in survival at all", game.mode == game.Mode.SURVIVAL
		and game._ad_allowed())


## Survival is the first mode where an ad can land over a live board, and a
## running match underneath one is a board the player did not bury.
func _a_break_stops_the_run_under_it() -> void:
	print("--- the run stops under a break ---")
	var ads: Node = get_root().get_node("Ads")
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = 50.0
	game.player.board.reset()
	game.player.pending.clear()

	ads._showing = true
	for i in 600:
		game._process(1.0 / 60.0)
	_expect("the clock does not run behind the ad",
		is_equal_approx(game.match_time, 50.0))
	_expect("and nothing is dealt onto the board",
		game.player.pending.is_empty() and game.player.board.blocks.is_empty())

	ads._showing = false
	for i in 600:
		game._process(1.0 / 60.0)
	_expect("and it picks up again once the break is over", game.match_time > 50.0)


## Somebody who paid to remove ads must not have their device asking for them.
##
## They were already never shown one — `ad_due` refuses before the cadence is
## consulted — but the requests went out anyway, at launch and at the start of
## every match, and were filled and counted. An install fetching inventory it can
## never display pushes the request count up and the fill it actually shows down,
## and it does it hardest for the people who paid the most.
func _premium_asks_for_nothing() -> void:
	print("--- premium asks for nothing ---")
	var ads: Node = get_root().get_node("Ads")
	_wipe()
	P.owned = {}

	var free_wants: bool = ads.wanted()
	_expect("a free player still wants ads (or has no plugin)",
		free_wants == ads.available())

	P.grant(P.PACK_PREMIUM)
	_expect("premium removes ads", P.ads_removed())
	_expect("and stops the game asking for them", not ads.wanted())
	_expect("so no break is ever due", not P.ad_due())

	# The call every match makes. It has to stay safe to call and has to do
	# nothing — `game.gd` should not have to know who paid for what.
	ads.fetch()
	_expect("a fetch on a premium install loads nothing",
		not ads._loading and ads._ad == null)
	_expect("and there is nothing it could show", not ads.has_ad())

	# A purchase that lands mid-session has to drop whatever was already in hand,
	# or the next match ends on an ad the player has just paid to be rid of.
	ads._ad = null
	ads._loading = true
	ads._on_profile_changed()
	_expect("buying mid-session drops anything in flight", not ads._loading)

	# Playing on changes nothing: a premium run banks its time like any other,
	# and none of it turns into a request.
	game.start_match("Survival", 0, [], game.Mode.SURVIVAL)
	game.phase = game.Phase.PLAY
	game.match_time = 400.0
	game._finish_survival()
	_expect("a premium run still ends cleanly", game.phase == game.Phase.OVER)
	_expect("and still asked for nothing", not ads._loading and ads._ad == null)

	P.owned = {}
	_expect("and it comes back for a free player", ads.wanted() == ads.available())


## The modes that were already tuned must come out the other side unchanged.
func _normal_play_is_untouched() -> void:
	print("--- everything else ---")
	game.start_match("Rookie", 1, [], game.Mode.NORMAL)
	game.phase = game.Phase.PLAY
	_expect("a normal match still has an opponent", game.slots_in_play >= 2)
	_expect("and is not a solo run", not game.solo_run())
	_expect("and still takes breaks", game._ad_allowed())

	game.start_match("Daily", 0, [], game.Mode.DAILY)
	_expect("the daily is still one seat", game.slots_in_play == 1)
	_expect("still solo", game.solo_run())
	_expect("and still takes no breaks", not game._ad_allowed())

	game.start_match("Rookie", 0, [], game.Mode.TUTORIAL)
	_expect("the lesson takes no breaks", not game._ad_allowed())
	_expect("and is not a solo run in the scoring sense", not game.solo_run())


func _wipe() -> void:
	P.matches = 0
	P.wins = 0
	P.flawless = 0
	P.words = 0
	P.chars = 0
	P.salvos = 0
	P.multi_clears = 0
	P.best_wpm = 0.0
	P.best_chain = 0
	P.best_combo = 0
	P.best_score = 0
	P.longest_word = ""
	P.powers = {}
	P.survival_best_time = 0.0
	P.survival_best_score = 0
	P.survival_runs = 0
	P.since_ad = 0
	P.play_since_ad = 0.0


func _press(code: int, ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.unicode = ch.unicode_at(0)
	game._unhandled_key_input(ev)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-54s %s" % [what, "ok" if ok else "FAILED"])


func _erase(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
