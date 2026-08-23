extends SceneTree
## What is left of versus once Apple's screen owns the matchmaking.
##
## There is no versus screen any more — the title door opens Apple's sheet
## directly — so what used to be tested here (three doors, a friend picker, a
## layout that predicted its own height) went with it. What remains is the part
## the game still owns and can still get wrong:
##
##   * the door itself, which must not start a second search on top of one
##     already running, and must fail quietly rather than pretend;
##   * the rematch negotiation, which is ours end to end and may only exist
##     while there is somebody to negotiate with;
##   * the summary screen, whose foot is *measured* rather than drawn — so if
##     the rows grow and the measurement does not, the buttons land underneath
##     the table.
##
## Game Center is unavailable on Linux, which is the same shape as "not signed
## in" — the case every one of these still has to behave in.
##
##   godot --headless --script tools/versustest.gd

var game: Node
var mm: Node
## The headless display server will not go narrower than 1280, and `portrait` is
## decided by the window — so the phone's 720-wide design space only exists if
## we build one.
var stage: SubViewport
var fails := 0


func _expect(what: String, ok: bool) -> void:
	if not ok:
		fails += 1
	print("  %-56s %s" % [what, "ok" if ok else "FAILED"])


func _orient(tall: bool) -> void:
	stage.size = game.PORTRAIT_SIZE if tall else game.LANDSCAPE_SIZE
	game.portrait = tall


func _press(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	game._unhandled_key_input(ev)


## The door hands straight over to Apple. All this end has to do is not make
## things worse: no second search, no phase change, no silent pretence.
func _the_door() -> void:
	print("--- the versus door ---")
	game.phase = game.Phase.TITLE

	game._activate("versus")
	_expect("the door does not navigate anywhere of ours",
		game.phase == game.Phase.TITLE)
	_expect("and leaves no search running with Game Center off",
		mm.available() or not game._versus_busy())

	# The title keys are the other way in, and must agree with the plate.
	_press(KEY_4)
	_press(KEY_V)
	_expect("4 and V are still the door, and still harmless",
		game.phase == game.Phase.TITLE)

	var sub: String = game._versus_sub()
	_expect("the plate says something either way: '%s'" % sub, sub != "")


## Rematch asks the opponent you already have, so the button may only exist
## while there is one. With Game Center off `net_active()` is false, which is
## precisely the "they left" case the summary has to survive.
func _rematch_follows_the_opponent() -> void:
	print("--- rematch ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL

	game.difficulty = "Versus"
	_expect("a versus match with nobody left cannot rematch",
		not game._rematch_possible())
	var acts: PackedStringArray = []
	for b: Dictionary in game._menu_buttons():
		acts.append(String(b["action"]))
	_expect("so the summary offers only Title (%s)" % ", ".join(acts),
		not acts.has("rematch") and acts.has("title"))

	game.difficulty = "Rookie"
	_expect("a CPU match can always go again", game._rematch_possible())
	var acts2: PackedStringArray = []
	for b2: Dictionary in game._menu_buttons():
		acts2.append(String(b2["action"]))
	_expect("so the summary keeps Rematch", acts2.has("rematch"))

	# The card is a person asking a question. A CPU never asks, and neither does
	# an opponent who has already gone.
	game.rematch_offered = true
	game.rematch_asked = false
	_expect("no card for a CPU match", not game._rematch_popup())
	game.difficulty = "Versus"
	_expect("no card once the opponent has gone", not game._rematch_popup())
	game.rematch_offered = false

	game.rematch_asked = true
	game.rematch_offered = true
	game.start_match("Rookie", 1)
	_expect("starting a match clears a stale ask",
		not game.rematch_asked and not game.rematch_offered)

	# Leaving cancels, so the peer is not told that somebody already back at the
	# title screen still wants another game.
	game.phase = game.Phase.OVER
	game.rematch_asked = true
	game._activate("title")
	_expect("leaving to title cancels the ask",
		not game.rematch_asked and not game.rematch_offered)
	_expect("and lands on the title screen", game.phase == game.Phase.TITLE)


## The summary was laid out in a 720-tall landscape window and then handed a
## phone twice that height. Its foot is measured rather than drawn, so the rows
## and the measurement have to grow together.
func _summary_fits_a_phone() -> void:
	print("--- the summary fits a phone ---")
	game.phase = game.Phase.OVER
	game.mode = game.Mode.NORMAL
	game.difficulty = "Rookie"
	game.win_spoils = 0

	_orient(false)
	var land_row: float = game._score_row_h()
	var land_foot: float = game._over_foot()
	_orient(true)
	var tall_row: float = game._score_row_h()
	var tall_foot: float = game._over_foot()
	_expect("rows are taller in portrait (%.0f -> %.0f)" % [land_row, tall_row],
		tall_row > land_row)
	_expect("and the foot moves down with them (%.0f -> %.0f)" % [
		land_foot, tall_foot], tall_foot > land_foot)

	var rows: int = max(1, game._scoreboard_sides().size())
	var last_row_bottom: float = game._scoreboard_top() \
		+ game.SCORE_HEAD_H * game._over_fill() \
		+ float(rows) * (game._score_row_h() + 6.0)
	_expect("buttons start below the last row (%.0f >= %.0f)" % [
		tall_foot, last_row_bottom], tall_foot >= last_row_bottom)

	var plain: float = game._scoreboard_top()
	game.win_spoils = 1650
	_expect("a win bonus makes room above the table (%.0f -> %.0f)" % [
		plain, game._scoreboard_top()], game._scoreboard_top() > plain)
	game.win_spoils = 0

	_expect("WPM is a column in portrait", game._scoreboard_cols().has("WPM"))
	_orient(false)
	_expect("and in landscape", game._scoreboard_cols().has("WPM"))
	game.phase = game.Phase.TITLE


func _init() -> void:
	await process_frame
	mm = root.get_node("MultiplayerManager")
	# `--script` boots the autoloads but not the main scene, so put it up by hand.
	game = load("res://scenes/main.tscn").instantiate()
	stage = SubViewport.new()
	stage.size = Vector2i(1280, 720)
	root.add_child(stage)
	stage.add_child(game)
	await process_frame
	await process_frame
	_orient(false)

	_the_door()
	_rematch_follows_the_opponent()
	_summary_fits_a_phone()

	print("--- what the title says with Game Center off ---")
	print("  %s" % game._versus_sub())
	print("--- %s ---" % ("versus holds up" if fails == 0 else "%d FAILURES" % fails))
	quit(1 if fails > 0 else 0)
