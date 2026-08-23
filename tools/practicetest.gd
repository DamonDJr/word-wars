extends SceneTree
## The two promises practice makes: you cannot lose it, and it cannot be farmed.
## Both are easy to break by accident later — a mode flag missed in one branch is
## all it takes — and neither is visible until somebody has wasted an hour.
##
##   godot --headless --script tools/practicetest.gd

var game: Node
var fails := 0


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	_cannot_be_lost()
	_banks_nothing()
	_lesson_runs_through()
	_lesson_advances_on_touch()
	_normal_still_works()

	print("--- %s ---" % ("practice behaves" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## The tutorial is played on a phone, where the only fire control is the
## on-screen FIRE key. That key went straight to `_submit_player` while the
## keyboard checked for a lesson waiting to advance — so every step ending in
## "tap FIRE to continue" was unadvanceable, and the lesson could not be finished
## on the platform the game ships to.
func _lesson_advances_on_touch() -> void:
	print("--- the lesson advances by touch ---")
	game.start_match("Rookie", 0, [], game.Mode.TUTORIAL)
	game.phase = game.Phase.PLAY
	game.typed = ""
	game.lesson_done = true
	var before: int = game.lesson

	# Exactly what a thumb on the FIRE key does.
	game._press_key("fire")
	_expect("FIRE moves the lesson on (%d -> %d)" % [before, game.lesson],
		game.lesson == before + 1)

	# And the keyboard still agrees, since both go through one place now.
	game.lesson_done = true
	var mid: int = game.lesson
	game._fire_pressed()
	_expect("and so does the keyboard (%d -> %d)" % [mid, game.lesson],
		game.lesson == mid + 1)

	# Firing a real word must still fire it rather than skipping a step.
	game.lesson_done = false
	var held: int = game.lesson
	game.typed = "strike"
	game._press_key("fire")
	_expect("a typed word is still fired, not swallowed",
		game.lesson == held)

	# The phone wording must not name a key the phone has not got.
	var touch: Dictionary = Tutorial.step(0, true)
	var desk: Dictionary = Tutorial.step(0, false)
	_expect("touch copy avoids SPACE: '%s'" % String(touch.get("body", "")),
		not String(touch.get("body", "")).contains("SPACE"))
	_expect("desktop copy keeps it: '%s'" % String(desk.get("body", "")),
		String(desk.get("body", "")).contains("SPACE"))


func _cannot_be_lost() -> void:
	print("--- nothing can be lost ---")
	for how in [game.Mode.TUTORIAL, game.Mode.TRAINING]:
		game.start_match("Rookie", 0, [], how)
		game.phase = game.Phase.PLAY
		var lives: int = game.player.lives
		for i in 6:
			game._lose_life(game.player)
		_expect("topping out six times costs no lives", game.player.lives == lives)
		_expect("and the run is still going", game.player.alive)
		_expect("and the match has not ended", game.phase == game.Phase.PLAY)


func _banks_nothing() -> void:
	print("--- nothing is banked ---")
	var p = Engine.get_main_loop().root.get_node("Profile")
	p.save_path = "user://profile-practice-test.cfg"
	p.matches = 0
	p.words = 0
	p.salvos = 0

	for how in [game.Mode.TUTORIAL, game.Mode.TRAINING]:
		game.start_match("Rookie", 0, [], how)
		game.phase = game.Phase.PLAY
		game.player.words_played = 40
		game.player.salvos = 5
		game.winner = "YOU"
		game._end_match(game.sides[1])
		_expect("a finished practice run banks no match", p.matches == 0)
		_expect("and no words", p.words == 0)

	# And the ordinary path still does, or the guard is in the wrong place.
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.player.words_played = 12
	game.winner = "YOU"
	game._end_match(game.sides[1])
	_expect("a real match still banks", p.matches == 1 and p.words == 12)

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p.save_path + suffix))


## Every step has to be reachable, and the last one has to end the lesson —
## a step whose condition can never be met would trap somebody forever.
func _lesson_runs_through() -> void:
	print("--- the lesson runs to the end ---")
	game.start_match("Rookie", 0, [], game.Mode.TUTORIAL)
	game.phase = game.Phase.PLAY
	_expect("it starts at the first step", game.lesson == 0)

	var reached := 0
	for i in Tutorial.count():
		_expect("step %d has a title and a body" % (i + 1),
			String(Tutorial.step(i).get("title", "")) != ""
			and String(Tutorial.step(i).get("body", "")) != "")
		if game.lesson == i:
			reached += 1
		game._lesson_next()
	_expect("every step was visited", reached == Tutorial.count())
	_expect("and the last one finishes the lesson",
		game.phase == game.Phase.PRACTICE and game.mode == game.Mode.NORMAL)
	var p = Engine.get_main_loop().root.get_node("Profile")
	_expect("and it is remembered as taught", bool(p.pref("taught")))


## The guards must not have leaked into ordinary play.
func _normal_still_works() -> void:
	print("--- ordinary matches are untouched ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	_expect("there is an opponent", game.sides[1].bot != null)
	_expect("whose board is shown", game.sides[1].in_match)
	var lives: int = game.player.lives
	game._lose_life(game.player)
	_expect("and topping out still costs a life", game.player.lives == lives - 1)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
