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
	_the_day_is_the_players_own()

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
	p.daily_streak = 0

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
	_expect("a day after yesterday continues the streak", p.daily_streak == 2)
	p.record_daily("2026-05-09", 100, 10, 5, 1)
	_expect("a gap starts the streak again", p.daily_streak == 1)
	_expect("the best is still the best", p.daily_best == 6000)


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


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
