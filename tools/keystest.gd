extends SceneTree
## Every letter of the alphabet must reach the line you are typing.
##
## This exists because Q did not, for several releases, on every desktop build.
## `match` in GDScript does not fall through, so an arm like `KEY_Q:` claims the
## key whether or not its body does anything — and the body only did something
## while paused. Q was the sole letter with an arm of its own, so Q was the sole
## letter that vanished. Nothing else in the game could see it: the drawn
## keyboard on iOS calls `_press_key` and never goes near this code, so the
## phone build typed Q perfectly while the keyboard build could not.
##
## The lesson generalises past Q — any shortcut added to the play-phase match
## takes that letter out of the alphabet unless it is guarded. So the test is
## the whole alphabet rather than the one letter that went wrong.
##
##   godot --headless --script tools/keystest.gd

var game: Node
var fails := 0


func _init() -> void:
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	_every_letter_types()
	_shortcuts_still_work()

	print("--- %s ---" % ("keys behave" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)


## a to z, one at a time, each into an empty line.
func _every_letter_types() -> void:
	print("--- every letter reaches the line ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.paused = false

	var lost: Array = []
	for code in range(KEY_A, KEY_Z + 1):
		game.typed = ""
		var ch := String.chr(code).to_lower()
		_press(code, ch)
		if game.typed != ch:
			lost.append(ch)
	_expect("all 26 letters land in the typed line", lost.is_empty())
	if not lost.is_empty():
		print("      swallowed: %s" % ", ".join(lost))

	# Digits are targeting keys and are meant to be swallowed — the check above
	# would pass just as well if letters were being handled by accident, so pin
	# down that the exception is still an exception.
	game.typed = ""
	_press(KEY_1, "1")
	_expect("digits still pick a target rather than typing", game.typed == "")


## The shortcuts the letters were competing with have to survive the fix.
func _shortcuts_still_work() -> void:
	print("--- shortcuts still fire ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY

	game.paused = true
	_press(KEY_Q, "q")
	_expect("Q while paused leaves the match", game.phase != game.Phase.PLAY)

	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.paused = false
	game.typed = ""
	_press(KEY_Q, "q")
	_expect("Q while playing types instead", game.typed == "q")
	_expect("and does not leave the match", game.phase == game.Phase.PLAY)


func _press(code: int, ch: String) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.unicode = ch.unicode_at(0)
	game._unhandled_key_input(ev)


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-52s %s" % [what, "ok" if ok else "FAILED"])
