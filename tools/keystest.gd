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
	_the_lean_stays_bounded()

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


## The dictionary may lean the boundary between two letters. It may not lean it
## far enough to matter to somebody aiming properly, and it may not touch the
## three keys whose misfires are expensive.
##
## The whole defence of `_key_at` consulting what you are typing rests on those
## two limits, so they are pinned here rather than left to the comment. A lean
## that grew until it could take the centre of a key would be the unlearnable
## keyboard the function's own docstring argues against, and it would grow
## silently — every one of these assertions passes just as well with the feature
## switched off, which is the point: they bound it, they do not demand it.
func _the_lean_stays_bounded() -> void:
	print("--- the dictionary may lean a boundary, not move it ---")
	game.start_match("Rookie", 1)
	game.phase = game.Phase.PLAY
	game.paused = false

	# Reached through the tree rather than by name: naming an autoload here makes
	# it a compile-time dependency of a script that runs before the autoloads are
	# registered, and the file stops compiling. Same trap `emotetest.gd` explains
	# at length about `WWBoard`.
	var wb: Node = get_root().get_node("WordBank")

	# "qua" begins quality and quarter; "qus" begins nothing at all. A and S are
	# neighbours, so this is exactly the sideways miss the lean exists for.
	game.typed = "qu"
	_expect("QUA is a word beginning", wb.valid_prefix_count("qua") > 0)
	_expect("QUS is not", wb.valid_prefix_count("qus") == 0)

	var a := _rect("a")
	var s := _rect("s")
	_expect("A and S really are neighbours", absf(a.end.x - s.position.x) < 12.0)

	# Just inside S's left edge: a tap aimed at A that fell short.
	var edge := Vector2(s.position.x + 4.0, s.get_center().y)
	_expect("a tap on S's edge goes to A when S cannot continue",
		game._key_at(_lift(edge)) == "a")

	# The middle of S is S regardless of what the dictionary thinks. This is the
	# line that must never be crossed.
	_expect("the centre of S is still S", game._key_at(_lift(s.get_center())) == "s")
	for id in ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d",
			"f", "g", "h", "j", "k", "l", "z", "x", "c", "v", "b", "n", "m"]:
		if game._key_at(_lift(_rect(id).get_center())) != id:
			_expect("centre of %s types %s" % [id.to_upper(), id.to_upper()], false)
			return
	_expect("and every other key's centre types itself", true)

	# With nothing typed the whole alphabet is legal, so the lean cancels out and
	# the boundary is back where geometry put it.
	game.typed = ""
	_expect("an empty line leans nothing", game._key_at(_lift(edge)) == "s")

	# A line already misspelt has no legal continuation anywhere; that must
	# degrade to geometry too rather than to whichever key was checked first.
	game.typed = "zxq"
	_expect("a dead line leans nothing either", game._key_at(_lift(edge)) == "s")

	# CLR sits next to Z. Losing a letter is cheap; losing the typed word is not.
	game.typed = "qu"
	var clr := _rect("clear")
	_expect("CLR keeps its edge against a legal neighbour",
		game._key_at(_lift(Vector2(clr.end.x - 4.0, clr.get_center().y))) == "clear")
	var fire := _rect("fire")
	_expect("and FIRE keeps its own",
		game._key_at(_lift(Vector2(fire.get_center().x, fire.position.y + 4.0))) == "fire")


## `_key_at` lifts the sample before matching it, so a test naming a point on a
## key has to put it back or it is asking about the key above.
func _lift(at: Vector2) -> Vector2:
	return at + Vector2(0.0, game._touch_lift(game.get_viewport_rect().size))


func _rect(id: String) -> Rect2:
	for k in game._keyboard():
		if k["id"] == id:
			return k["rect"]
	return Rect2()


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
