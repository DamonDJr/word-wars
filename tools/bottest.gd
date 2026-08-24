extends SceneTree
## The CPU ladder, and the two things about it that are easy to get wrong.
##
## Every rate in `ai_opponent.gd` was tuned against a keyboard, and the game
## ships to thumbs. `configure` scales for that, so what has to hold is that the
## scaling actually happens, that it keeps the ladder in order, and that the
## number the roster *advertises* is the number the bot will actually type at —
## a phone quoting a desktop pace is promising a fight it will not have.
##
##   godot --headless --script tools/bottest.gd

var A
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-56s %s" % [what, "ok" if ok else "FAILED"])


func _init() -> void:
	await process_frame
	# `ai_opponent.gd` names the `WordBank` autoload, which does not exist at
	# parse time under `--script` — so the class is loaded rather than named.
	A = load("res://scripts/ai_opponent.gd")

	print("--- thumbs are slower than a keyboard ---")
	var faster := 0
	for n in A.ROSTER:
		var desk = A.new(); desk.configure(n, false)
		var touch = A.new(); touch.configure(n, true)
		if touch.wpm >= desk.wpm:
			faster += 1
			print("    %s did not slow down" % n)
		if touch.reaction <= desk.reaction:
			faster += 1
			print("    %s did not think longer" % n)
	_expect("every bot is slower and more hesitant on touch", faster == 0)

	print("--- the ladder keeps its order ---")
	# Scaling must not reshuffle who is hard. Rookie stays the floor and
	# Wordsmith the ceiling whichever input the player is using.
	for touch in [false, true]:
		var rates: Array = []
		for n in A.ROSTER:
			var b = A.new(); b.configure(n, touch)
			rates.append(b.wpm)
		var lo: float = rates.min()
		var hi: float = rates.max()
		var first = A.new(); first.configure(A.ROSTER[0], touch)
		var last = A.new(); last.configure(A.ROSTER[A.ROSTER.size() - 1], touch)
		_expect("%s: Rookie is the floor and Wordsmith the ceiling" % [
			"touch" if touch else "desktop"],
			is_equal_approx(first.wpm, lo) and is_equal_approx(last.wpm, hi))

	print("--- the roster advertises the truth ---")
	for n in A.ROSTER:
		for touch in [false, true]:
			var b = A.new(); b.configure(n, touch)
			_expect("%s on %s: says %d, types %d" % [
				n, "touch" if touch else "desktop",
				A.paced_wpm(n, touch), int(round(b.wpm))],
				A.paced_wpm(n, touch) == int(round(b.wpm)))

	print("--- long-word bots cannot reach the top tier for free ---")
	# Word length now sets a floor on block size, which quietly buffed every bot
	# that reaches for long words. Nothing on the roster may sit at or above the
	# second length step on every single word it plays.
	for n in A.ROSTER:
		var span: Vector2i = A.spec(n)["len"]
		_expect("%s never floors at the top step (%d-%d)" % [n, span.x, span.y],
			span.x < 10)

	print("--- %s ---" % ("the ladder holds up" if fails == 0
		else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
