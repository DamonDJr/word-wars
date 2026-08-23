extends SceneTree
## The daily board makes two promises, and both fail quietly.
##
## "Everyone gets the same board" is only true if the letters come from a seeded
## generator — and the game draws randomness for sparks and grain every frame,
## at a rate that depends on framerate, so anything sharing the global generator
## can never be reproduced. A daily that quietly deals different boards still
## looks like a working daily; it just is not a contest.
##
## "One run a day" is the other. A crash, a reload, or a second trip through the
## door must not buy a second attempt at a board you have already seen.
##
## And a third, added when the daily became a sprint: it is a run alone against
## a clock. Nothing is sent, nothing is faced, and there is no second seat in
## the match — which the daily used to have, filled with an opponent labelled
## LESSON that a phone drew as a rival chip along the top of the screen.
##
##   godot --headless --script tools/dailytest.gd

var game: Node
var fails := 0
## Autoload globals are not bound at compile time in a `--script` run, so the
## singletons are fetched off the root — the same way every suite here does it.
var WB: Node


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	WB = get_root().get_node("WordBank")

	_the_seed_reproduces()
	_the_day_is_stable()
	_one_run_a_day()
	_a_broken_streak_knows_it()
	_the_board_ranks_every_run()
	_the_board_fits_the_screen()
	_the_day_is_the_players_own()
	_it_is_a_run_alone()
	_it_opens_part_buried()
	_damage_becomes_score()
	_the_minute_leans_on_you()

	print("--- %s ---" % ("daily behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The same seed has to deal the same letters, and — the part that actually
## broke things — has to keep dealing them while the cosmetic generator is being
## hammered, which is what happens every frame of a real run.
func _the_seed_reproduces() -> void:
	print("--- the same seed deals the same board ---")
	var first := _deal(4242)

	# Burn the global generator hard between the two runs. If anything the board
	# depends on is still reading from it, this is what exposes it.
	for i in 5000:
		randf()
		randi()

	var again := _deal(4242)
	_expect("the same seed deals the same letters", first == again)
	if first != again:
		print("      %s" % str(first).substr(0, 90))
		print("      %s" % str(again).substr(0, 90))

	var other := _deal(9999)
	_expect("a different seed deals a different board", first != other)


## Thirty draws off the seeded generator, which is what the board is made of.
func _deal(value: int) -> Array:
	WB.seed_run(value)
	var out: Array = []
	for i in 30:
		out.append(WB.random_common())
	return out


func _the_day_is_stable() -> void:
	print("--- a day is one board ---")
	var a: int = game.daily_seed()
	var b: int = game.daily_seed()
	_expect("the seed does not move between calls", a == b)
	_expect("the key is a date", game.daily_key().length() == 10)
	var kinds_a: Array = game.daily_kinds()
	var kinds_b: Array = game.daily_kinds()
	_expect("the block kinds are the same all day", kinds_a == kinds_b)
	_expect("two kinds are in play", kinds_a.size() == 2)


func _one_run_a_day() -> void:
	print("--- one run a day ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	p.save_path = "user://profile-daily-test.cfg"
	p.daily = {}
	p.daily_best = 0
	p.daily_best_streak = 0

	_expect("a fresh day is available", not p.daily_done("2026-05-01"))
	p.record_daily("2026-05-01", 5000, 40, 30, 6)
	_expect("and is spent once played", p.daily_done("2026-05-01"))

	# The important one: a second attempt must not overwrite the first, however
	# it arrives.
	p.record_daily("2026-05-01", 99999, 90, 99, 12)
	_expect("a second run cannot replace the first",
		int(p.daily_result("2026-05-01")["score"]) == 5000)
	_expect("and cannot inflate the best", p.daily_best == 5000)

	# Consecutive days build a streak; a gap starts over.
	p.record_daily("2026-05-02", 6000, 40, 30, 6)
	_expect("a day after yesterday continues the streak",
		p.daily_streak("2026-05-02") == 2)
	p.record_daily("2026-05-09", 100, 10, 5, 1)
	_expect("a gap starts the streak again", p.daily_streak("2026-05-09") == 1)
	_expect("the best is still the best", p.daily_best == 6000)
	_expect("and the longest run is remembered", p.daily_best_streak == 2)


## The streak is counted from the history rather than stored, because a stored
## one is only ever corrected by playing — which is the one thing somebody who
## has broken their streak has not done.
func _a_broken_streak_knows_it() -> void:
	print("--- a streak that lapses says so, before you play again ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	p.save_path = "user://profile-daily-test.cfg"
	p.daily = {}
	p.daily_best = 0
	p.daily_best_streak = 0

	for day in ["2026-05-01", "2026-05-02", "2026-05-03"]:
		p.record_daily(day, 1000, 40, 30, 6)
	_expect("three days running is a streak of three",
		p.daily_streak("2026-05-03") == 3)

	# Today, not yet played. The streak is not broken — there is still time.
	_expect("today being unplayed does not break it",
		p.daily_streak("2026-05-04") == 3)
	# Yesterday missed as well. Now it is gone, and nothing had to be played for
	# the count to notice.
	_expect("a missed day breaks it without being told",
		p.daily_streak("2026-05-05") == 0)
	_expect("and a long gap stays broken", p.daily_streak("2026-06-01") == 0)
	_expect("while the record survives it", p.daily_best_streak == 3)

	# Coming back starts a new one rather than resuming the old.
	p.record_daily("2026-05-20", 1000, 40, 30, 6)
	_expect("returning starts again at one", p.daily_streak("2026-05-20") == 1)
	_expect("and the record is untouched", p.daily_best_streak == 3)


## The board the daily summary ranks you on.
func _the_board_ranks_every_run() -> void:
	print("--- the leaderboard ranks every run on file ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	p.save_path = "user://profile-daily-test.cfg"
	p.daily = {}
	p.daily_best = 0
	p.daily_best_streak = 0

	p.record_daily("2026-05-01", 5000, 40, 30, 6)
	p.record_daily("2026-05-02", 9000, 40, 30, 6)
	p.record_daily("2026-05-03", 7000, 40, 30, 6)

	var rows: Array = p.daily_ranked()
	_expect("every run is on it", rows.size() == 3)
	_expect("best first", int(rows[0]["score"]) == 9000)
	_expect("worst last", int(rows[2]["score"]) == 5000)
	_expect("and each row knows its day", String(rows[0]["day"]) == "2026-05-02")
	_expect("a day can find its own place", p.daily_rank("2026-05-03") == 2)
	_expect("and a day never played has none", p.daily_rank("2026-05-04") == 0)

	# Matching a score you already set is not beating it.
	p.record_daily("2026-05-04", 9000, 40, 30, 6)
	_expect("a tie goes to whoever got there first",
		String(p.daily_ranked()[0]["day"]) == "2026-05-02")


## The summary is a composition, not a list — `_scrollable` leaves `Phase.OVER`
## out on purpose — so anything the leaderboard takes is taken from the buttons
## underneath it, which have nowhere to go. Landscape is half the height of
## portrait and is where that runs out.
##
## The headless display server will not go narrower than 1280, so the phone's
## design space only exists inside a SubViewport. `_daily_board_fit` measures
## whatever viewport the node sits under, which makes this a real test of the
## rule rather than a re-derivation of it here.
func _the_board_fits_the_screen() -> void:
	print("--- the leaderboard fits on the screen it is drawn on ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	p.save_path = "user://profile-daily-test.cfg"

	var stage := SubViewport.new()
	get_root().add_child(stage)
	var g = load("res://scenes/main.tscn").instantiate()
	stage.add_child(g)

	# Two shapes, because they fail differently. "worst" puts today far outside
	# the row cap; "middling" puts it *inside* the cap but outside the two rows a
	# landscape window has room for — which is the one that actually broke, and
	# which a test using only the first shape passes straight through.
	for shape in ["worst", "middling"]:
		for tall in [false, true]:
			_board_fits_at(p, g, stage, shape, tall)

	stage.queue_free()


func _board_fits_at(p, g, stage: SubViewport, shape: String, tall: bool) -> void:
	stage.size = g.PORTRAIT_SIZE if tall else g.LANDSCAPE_SIZE
	g.portrait = tall
	var where := "%s/%s" % [shape, "portrait" if tall else "landscape"]

	p.daily = {}
	p.daily_best = 0
	p.daily_best_streak = 0

	# The calendar comes from the game's own key, walked backwards with the same
	# function the streak counts with. Building the dates out of
	# `get_datetime_dict_from_unix_time` instead reads them in UTC, which is a
	# day ahead of `daily_key`'s local midnight for part of every evening — so
	# the run recorded as "today" was a day the game had never heard of, today's
	# row was correctly absent from the board, and the suite passed all morning
	# and failed after eight.
	var today: String = g.daily_key()
	var days: Array = [today]
	while days.size() < 12:
		days.append(p._day_before(days[days.size() - 1]))

	for i in range(days.size() - 1, -1, -1):
		# i == 0 is today: dead last, or fourth of twelve — inside the row cap
		# but outside the two rows a landscape window has room for.
		var score: int = (100 if shape == "worst" else 5250) if i == 0 \
			else 1000 + i * 500
		p.record_daily(String(days[i]), score, 40, 30, 6)

	g.start_match("Rookie", 1, [], g.Mode.DAILY)
	g.phase = g.Phase.OVER
	g.mode = g.Mode.DAILY
	g.winner = "YOU"
	g.earned = {}
	g.win_spoils = 0

	var rows: Array = g._daily_board_rows()
	_expect("%s: the board has rows to show" % where, rows.size() > 0)

	# The one row that must never be dropped. It went missing on a landscape
	# window: the squeeze was measured against the row cap rather than against
	# the space, so the summary ranked two old scores and said nothing at all
	# about the run just played.
	# Today's row can be inside the run of best scores or carried in underneath
	# it, depending on how it went and how much room there is — but wherever it
	# is, the rank against it has to be its real standing rather than the row it
	# happens to occupy.
	var mine := -1
	for i in rows.size():
		if String((rows[i] as Dictionary)["day"]) == today:
			mine = i
	_expect("%s: today is on it, however tight it is" % where, mine >= 0)
	if mine >= 0:
		_expect("%s: and at its real rank" % where,
			int((rows[mine] as Dictionary)["rank"]) == p.daily_rank(today))

	# Every other row is a placing too, and they have to read in order.
	var ordered := true
	for i in range(1, rows.size()):
		if int((rows[i] as Dictionary)["rank"]) <= int((rows[i - 1] as Dictionary)["rank"]):
			ordered = false
	_expect("%s: and the ranks down the column climb" % where, ordered)

	# Nothing below the board may fall off the bottom.
	var foot: float = g._over_foot()
	var buttons: float = 0.0
	for b in g._menu_buttons():
		buttons = maxf(buttons, (b["rect"] as Rect2).end.y)
	var bottom: float = maxf(foot, buttons) + 26.0
	var limit: float = float(stage.size.y) - g.safe_bottom
	_expect("%s: the buttons stay on screen (%.0f of %.0f)" % [
		where, bottom, limit], bottom <= limit)


## The board turns over at the player's midnight, and the date is the whole of
## the seed — those two together are what let a daily work with no server, no
## sync and no clock to agree on.
func _the_day_is_the_players_own() -> void:
	print("--- the day is the player's own ---")
	var loc := Time.get_datetime_dict_from_system(false)
	var want := "%04d-%02d-%02d" % [int(loc["year"]), int(loc["month"]), int(loc["day"])]
	_expect("the key follows local time, not UTC", game.daily_key() == want)

	# The seed is a pure function of the date string, which is the entire reason
	# two machines deal the same board without ever talking to each other.
	_expect("a date always seeds the same board",
		game.seed_for("2026-01-01") == game.seed_for("2026-01-01"))
	_expect("a different date seeds a different one",
		game.seed_for("2026-01-01") != game.seed_for("2026-01-02"))

	# Hashed rather than raw, so consecutive days are not near-identical boards.
	# Compared as the thing that actually matters — the letters dealt — rather
	# than as the seeds themselves.
	var a := _deal(game.seed_for("2026-03-04"))
	var b := _deal(game.seed_for("2026-03-05"))
	var shared := 0
	for i in a.size():
		if a[i] == b[i]:
			shared += 1
	_expect("consecutive days deal unrelated boards", shared < a.size() / 3)

	# And the settings travel with the date too, not just the letters.
	_expect("a date always picks the same block kinds",
		game.daily_kinds("2026-07-07") == game.daily_kinds("2026-07-07"))

	# The kinds are looked up by name in `KIND_NAMES` when a block is minted, so
	# a pool that spells them any other way is not a different flavour of
	# English, it is a dictionary miss on every block of that day.
	for kind: String in game.DAILY_KIND_POOL:
		_expect("the pool's \"%s\" is a kind the game knows" % kind,
			game.KIND_NAMES.has(kind))


## Nobody else is in the room. This is the one that regressed silently: the
## daily kept a second seat so the layouts had two sides to draw, and a phone
## drew that seat as a rival chip labelled LESSON — a solo run that looked
## exactly like a match against the tutorial bot.
func _it_is_a_run_alone() -> void:
	print("--- a run alone ---")
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY

	_expect("the run is a minute", game.DAILY_SECONDS == 60.0)
	_expect("one seat is in the match", game.slots_in_play == 1)
	var others := 0
	for s in game.sides:
		if s.slot > 0 and s.in_match:
			others += 1
	_expect("and no second board is in it", others == 0)
	_expect("there is no bot", game.sides[1].bot == null)
	_expect("and nothing is labelled LESSON", game.sides[1].label != "LESSON")
	_expect("the summary would list one row", game._scoreboard_sides().size() == 1)
	_expect("and the mode knows it is solo", game.solo_run())

	# The clock is what ends it, from the top of the run to the bottom.
	game.match_time = 0.0
	_expect("a fresh run has the whole minute", game.daily_left() == 60.0)
	game.match_time = 61.0
	_expect("and none of it once the clock is out", game.daily_left() == 0.0)


## A quarter to a half buried before the first word, and the same hole for
## everybody who sits down on the same date.
## `WWBoard` is deliberately not named here. Referring to the class by name from
## a `--script` suite pulls board.gd into this file's compilation, where the
## `WordBank` autoload it uses is not bound yet — which fails the whole suite
## before a single test runs, and takes game.gd down with it. Everything board
## comes off the live instance instead, constants included.
func _it_opens_part_buried() -> void:
	print("--- it opens part buried ---")
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	var board = game.player.board
	var room: int = int(board.COLS) * int(board.ROWS)
	var fill := float(board.cell_count()) / float(room)
	_expect("the board opens at least a quarter full", fill >= 0.25)
	_expect("and no more than half full", fill <= 0.55)
	_expect("with stamps on it to answer", not board.prefixes().is_empty())

	# Dealt, not dropped: the pile has to be sitting still when the countdown
	# starts, or the first thing the run does is rain twenty blocks onto a board
	# the player has not been given a chance to read.
	var falling := 0
	for b in board.blocks:
		if b.vis.y < b.gy * float(board.CELL):
			falling += 1
	_expect("and settled rather than still falling", falling == 0)

	# The same day is the same hole. Compared as the stamps in the order they
	# were dealt, since that is the whole of what the player is looking at.
	var deal_a := _opening_stamps()
	var deal_b := _opening_stamps()
	_expect("the same day deals the same opening", deal_a == deal_b)


## Restart the run and read back what was dealt.
func _opening_stamps() -> Array:
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	var out: Array = []
	for b in game.player.board.blocks:
		out.append("%s@%d,%d:%d" % [b.prefix, b.gx, b.gy, b.tier])
	return out


## Every rule about damage survives, paid in points. A daily that simply switched
## the attack rules off would be a thinner game than the one it is drawn from —
## and the score would stop measuring the chain ladder at all.
func _damage_becomes_score() -> void:
	print("--- damage is paid in score ---")
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY

	var before: int = game.player.score
	var paid: int = game._strike(game.player, null, "alignment", 3, 2.8, "ent")
	_expect("a strike pays rather than sends",
		paid == game._cells(3) * game.STRIKE_PAY)
	_expect("and the points are banked", game.player.score == before + paid)
	_expect("a bigger tier pays more",
		game._strike(game.player, null, "alignment", 5, 2.8)
		> game._strike(game.player, null, "alignment", 1, 2.8))

	# Nothing left the board, in flight or otherwise.
	var inbound := 0
	for s in game.sides:
		inbound += s.pending.size()
	_expect("nothing was sent anywhere", inbound == 0)
	_expect("and nothing is in the air", game.tracers.is_empty())

	# The powers are the part most likely to be quietly dropped, since three of
	# the four are defined by the block they send.
	before = game.player.score
	var powers: int = game._fire_powers(game.player, null, "alignment",
		["COUNTER", "COMBO", "PERFECT", "CLUTCH"], 2, 1)
	_expect("all four powers still fire", game.player.powers_fired == 4)
	_expect("and every one of them paid", powers > 0)
	_expect("the score agrees with what they paid",
		game.player.score == before + powers)
	_expect("COMBO still owes the next word a tier", game.player.tier_bonus == 1)
	_expect("CLUTCH still buys a reprieve", game.player.slowdown > 0.0)
	inbound = 0
	for s in game.sides:
		inbound += s.pending.size()
	_expect("and still nothing was sent", inbound == 0)

	# The whole path rather than its pieces. `_play_word` is where the missing
	# opponent actually bites: it asks `_pick_target_for` who to hit, and an
	# empty room answers with the shooter — so an unguarded solo run aims every
	# word you fire at your own board.
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY
	game.player.board.reset()
	game.player.board.add_garbage("al", 0, 1, 1)
	before = game.player.score
	game._play_word(game.player, "alignment")
	_expect("a word fired at nobody still scores", game.player.score > before)
	_expect("and clears what it answered", game.player.blocks_cleared >= 1)
	_expect("and lands nothing on your own board", game.player.pending.is_empty())
	_expect("and leaves the board it cleared clear", game.player.board.blocks.is_empty())

	# A salvo is the biggest thing in the game and has to stay the biggest.
	before = game.player.score
	game.player.chain = game.SALVO_AT
	game._fire_salvo(game.player, null, "alignment", 2)
	var salvo: int = game.player.score - before
	_expect("a salvo pays out", salvo > 0)
	_expect("and beats any single strike",
		salvo > game._cells(game.TIERS.size() - 1) * game.STRIKE_PAY)
	_expect("and still spends the chain", game.player.chain == 0)


## The pressure is the whole opponent, so it has to actually press. A minute
## under the standard match ramp — twenty-two seconds to the first block, then
## a step and a half off each time — deals two blocks and ends.
func _the_minute_leans_on_you() -> void:
	print("--- the minute leans on you ---")
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY
	game.player.board.reset()

	_expect("the first block is seconds away, not half a minute",
		game.pressure_timer <= 4.0)

	# Run the clock out with nobody typing and count what turned up. The board is
	# emptied each time so a top-out cannot cut the count short.
	var seeded := 0
	var step := 1.0 / 60.0
	while game.match_time < game.DAILY_SECONDS:
		game.match_time += step
		var was: int = game.player.pending.size()
		game._tick_pressure(step)
		seeded += maxi(0, game.player.pending.size() - was)
		game.player.pending.clear()
	_expect("a minute of it deals a run's worth of garbage", seeded >= 20)
	_expect("without turning into noise", seeded <= 45)
	_expect("and the rate bottoms out where it was told to",
		game.pressure_interval == game.DAILY_PRESSURE_MIN)

	# Rate alone runs out of room below about a second and a half, so the back
	# half of the run escalates by weight instead.
	game.match_time = 0.0
	var opened: int = game._daily_tier()
	game.match_time = game.DAILY_SECONDS - 1.0
	var closed: int = game._daily_tier()
	_expect("it opens on the smallest block there is", opened == 0)
	_expect("and closes on something heavier", closed > opened)

	# Lasting the minute and burning three lives are different runs, and the
	# summary has to be able to tell them apart — it reads `winner`, and `winner`
	# used to be "YOU" either way.
	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY
	game.match_time = game.DAILY_SECONDS
	game._finish_daily()
	_expect("lasting the minute counts as surviving it", game.winner == "YOU")

	game.start_match("Daily", 0, [], game.Mode.DAILY)
	game.phase = game.Phase.PLAY
	for i in game.LIVES:
		game._lose_life(game.player)
	_expect("three top-outs end the run early", game.phase == game.Phase.OVER)
	_expect("and that is not a run you survived", game.winner != "YOU")


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
